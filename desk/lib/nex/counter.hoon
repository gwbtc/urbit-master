::  counter nexus: demo counter app with ticking state + UI
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather, nex-server
|%
++  counter
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    ::  Create /main file (the counter)
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %ud !>(0)])
    ::  Create /ui/main file (HTTP dispatcher)
    =.  ball  (~(put ba:tarball ball) [/ui %main] [~ %sig !>(~)])
    ::  Create /ui/requests directory for per-request processes
    =.  ball  (~(put of ball) /ui/requests [~ ~ ~])
    [sand ball]
  ::
  ++  on-file
    |=  [=rail:tarball =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?+    rail  stay:m
        ::  /main: counter process — ticks from 0 to 10
        ::
        [~ %main]
      ;<  ~  bind:m  ?.  ?=(%rise -.prod)  (pure:m ~)
        (trace:io leaf+"%counter /main: failed" tang.prod)
      ::  Wait for a poke to start ticking
      |-
      ;<  =cage  bind:m  take-poke:io
      ?.  =(%counter-start p.cage)
        ~&  [%counter %unknown-poke p.cage]
        $
      ::  Reset to 0 and tick
      ;<  ~  bind:m  (replace:io !>(0))
      |-
      ;<  count=@ud  bind:m  (get-state-as:io ,@ud)
      ?:  (gte count 10)
        ~&  [%counter %done count]
        ^$
      ;<  ~  bind:m  (sleep:io ~s1)
      ~&  [%counter %tick +(count)]
      ;<  ~  bind:m  (replace:io !>(+(count)))
      $
        ::  /ui/main: bind paths and dispatch requests
        ::
        [[%ui ~] %main]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%counter /ui/main: failed, staying inert" tang.prod)
        stay:m
      ~&  >  "%counter /ui/main: binding paths"
      ;<  ~  bind:m  (bind [~ /mister/counter])
      ;<  ~  bind:m  (bind [~ /mister/counter/stream])
      ~&  >  "%counter /ui/main: ready"
      |-
      ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
      ?+    p.cage  $
          %handle-http-request
        =/  [eyre-id=@ta req=inbound-request:eyre]
          !<([eyre-id=@ta inbound-request:eyre] q.cage)
        ~&  >  [%counter-dispatch eyre-id url.request.req]
        ;<  ~  bind:m  (make:io /make [%| 0 %& /requests eyre-id] |+http-request+!>(req))
        $
          %send-action
        ;<  ~  bind:m  (poke:io /send server-road cage)
        $
      ==
        ::  /ui/requests/*: individual request handlers
        ::
        [[%ui %requests ~] @]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%counter /ui/requests: failed" tang.prod)
        stay:m
      =/  eyre-id=@ta  name.rail
      ;<  req=inbound-request:eyre  bind:m  (get-state-as:io ,inbound-request:eyre)
      ~&  >  [%counter-request eyre-id url.request.req]
      =/  =request-line:server  (parse-request-line:server url.request.req)
      ?+    site.request-line
        ~&  >  [%counter-unknown site.request-line]
        ;<  ~  bind:m  (send-simple eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
        (pure:m ~)
      ::
          [%mister %counter ~]
        ?:  ?=(%'POST' method.request.req)
          ::  Start the counter
          ;<  ~  bind:m  (poke:io /start req-counter-road counter-start+!>(~))
          ;<  ~  bind:m  (send-simple eyre-id two-oh-four:http-utils)
          (pure:m ~)
        ::  Serve counter page
        =/  bod=octs  (manx-to-octs:server counter-page)
        ;<  ~  bind:m  (send-simple eyre-id (mime-response:http-utils [/text/html bod]))
        (pure:m ~)
      ::
          [%mister %counter %stream ~]
        ::  SSE stream: subscribe to counter and forward updates
        ?.  (is-sse-request:http-utils req)
          ;<  ~  bind:m  (send-simple eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
          (pure:m ~)
        ;<  ~  bind:m  (send-header eyre-id sse-header:http-utils)
        ;<  ~  bind:m  (keep:io /counter req-counter-road)
        ::  Start keep-alive timer
        ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
        ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
        |-
        ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /counter)
        ?-  -.nw
            %wake
          ;<  ~  bind:m  (send-data eyre-id `sse-keep-alive:http-utils)
          ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
          ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
          $
            %news
          =/  =sse-event:http-utils  [~ `'counter-update' (manx-to-wain:http-utils (counter-update [what view]:nw))]
          =/  data=octs  (sse-encode:http-utils ~[sse-event])
          ;<  ~  bind:m  (send-data eyre-id `data)
          $
        ==
      ==
    ==
  --
::  Road from /counter/ui/main to /server/main
::
++  server-road  `road:tarball`[%| 2 %& /server %main]
::  Road from /counter/ui/requests/* to /counter/main
::
++  req-counter-road  `road:tarball`[%| 2 %& ~ %main]
::  Road from /counter/ui/requests/* to /counter/ui/main
::
++  main-road  `road:tarball`[%| 1 %& ~ %main]
::
++  bind
  |=  =binding:eyre
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /bind server-road bind-action+!>([%bind binding]))
::
++  send
  |=  =send-action:nex-server
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /send main-road send-action+!>(send-action))
::
++  send-simple
  |=  [eyre-id=@ta =simple-payload:http]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send [eyre-id %simple simple-payload])
::
++  send-header
  |=  [eyre-id=@ta =response-header:http]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send [eyre-id %header response-header])
::
++  send-data
  |=  [eyre-id=@ta data=(unit octs)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send [eyre-id %data data])
::
++  send-kick
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send [eyre-id %kick ~])
::
++  counter-update
  |=  [what=(set lane:tarball) =view:nexus]
  ^-  manx
  =/  count=@ud
    ?.  ?=(%file -.view)  0
    !<(@ud q.cage.view)
  ;span: {(scow %ud count)}
::
++  counter-page
  ^-  manx
  ;html
    ;head
      ;title: Mister Counter
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;script(src "https://unpkg.com/htmx.org@2.0.3");
      ;script(src "https://unpkg.com/htmx-ext-sse@2.2.2/sse.js");
      ;+  feather:feather
    ==
    ;body.fc.g4.p5.ma.mw-page
      ;h1.s3: Mister Counter
      ;div.s6.bold.tc.p5.b1.br2(id "counter", hx-ext "sse", sse-connect "/mister/counter/stream", sse-swap "counter-update")
        ; Waiting...
      ==
      ;form(hx-post "/mister/counter")
        ;button.p-2.b1.br1.hover.pointer(type "submit"): Start Counter
      ==
    ==
  ==
--
