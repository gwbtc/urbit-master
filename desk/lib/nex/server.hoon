::  server/main nexus: HTTP gateway
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather
|%
++  counter-road  `road:tarball`[%| 2 %& /counter %main]
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
::
++  main
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    ::  Create /main file
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
    ::  Create /requests directory with neck=%requests
    =.  ball  (~(put of ball) /requests [~ `%requests ~])
    [sand ball]
  ::
  ++  on-file
    |=  [=rail:tarball =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?.  ?=([~ %main] rail)
      stay:m
    ::  /main: HTTP gateway
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%server /main: failed, staying inert" tang.prod)
      stay:m
    ~&  >  "%server /main: ready, waiting for pokes"
    |-
    ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
    ~&  >  [%server-main-poke p.cage]
    ?+    p.cage  $
        ::
        ::  Incoming HTTP request from eyre: create request file
        ::
        %handle-http-request
      =/  [eyre-id=@ta req=inbound-request:eyre]
        !<([eyre-id=@ta inbound-request:eyre] q.cage)
      ~&  >  [%server-main-request eyre-id url.request.req]
      ::  Create request file at /requests/[eyre-id]
      =/  dest=lane:tarball  [%& /requests eyre-id]  :: file: dir=/requests, name=eyre-id
      ~&  >  [%server-main-making dest]
      ;<  ~  bind:m  (make:io /make [%| 0 dest] |+[%http-request !>(req)])
      ~&  >  [%server-main-made dest]
      $
    ==
  --
++  requests
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    [sand ball]
  ::
  ++  on-file
    |=  [=rail:tarball =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ~&  >  [%requests-on-file rail -.prod]
    ?.  ?=([~ @] rail)
      stay:m
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%requests/{(trip name.rail)}: failed" tang.prod)
      stay:m
    =/  eyre-id=@ta  name.rail
    ~&  >  [%request-file-start eyre-id]
    ;<  req=inbound-request:eyre  bind:m
      (get-state-as:io ,inbound-request:eyre)
    ~&  >  [%request-file-url url.request.req method.request.req]
    =/  =request-line:server  (parse-request-line:server url.request.req)
    ~&  >  [%request-file-site site.request-line]
    ?+    site.request-line
      ~&  >  [%request-file-404 site.request-line]
      ::  404
      ;<  ~  bind:m
        (give-simple-payload:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
      (pure:m ~)
    ::
        [%mister %counter ~]
      ?:  ?=(%'POST' method.request.req)
        ::  Start the counter
        ;<  ~  bind:m  (poke:io /start counter-road counter-start+!>(~))
        ;<  ~  bind:m  (give-simple-payload:io eyre-id two-oh-four:http-utils)
        (pure:m ~)
      ::  Serve counter page
      =/  bod=octs  (manx-to-octs:server counter-page)
      ;<  ~  bind:m
        (give-simple-payload:io eyre-id (mime-response:http-utils [/text/html bod]))
      (pure:m ~)
    ::
        [%mister %counter %stream ~]
      ::  SSE stream: subscribe to counter and forward updates
      ?.  (is-sse-request:http-utils req)
        ;<  ~  bind:m
          (give-simple-payload:io eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
        (pure:m ~)
      ;<  ~  bind:m  (give-sse-header:io eyre-id)
      ;<  ~  bind:m  (keep:io /counter counter-road)
      ::  Start keep-alive timer
      ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
      ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /counter)
      ?-  -.nw
          %wake
        ;<  ~  bind:m  (give-sse-keep-alive:io eyre-id)
        ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
        ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
        $
          %news
        =/  data=wain  (manx-to-wain:http-utils (counter-update [what view]:nw))
        ;<  ~  bind:m  (give-sse-event:io eyre-id [~ `'counter-update' data])
        $
      ==
    ==
  --
--
