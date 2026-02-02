::  server nexus: HTTP request handling
::
/+  nexus, tarball, fiberio, server
|%
++  veb  |
+$  action
  $%  [%header eyre-id=@ta =response-header:http]
      [%data eyre-id=@ta data=(unit octs)]
      [%kick eyre-id=@ta]
      [%response eyre-id=@ta =simple-payload:http]
  ==
::
++  server-nexus
  ^-  nexus:nexus
  |%
  ++  on-load
    |~  =ball:nexus
    ^-  ball:nexus
    ::  Create /main and /requests directory
    =.  ball  (~(put ba:tarball ball) / %main [~ %sig !>(~)])
    (~(put of ball) /requests [~ ~ ~])
  ::
  ++  on-file
    |=  [=path name=@ta =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?+    [path name]
      ~?  veb  "%server on-file: unhandled {(spud path)}/{(trip name)}"
      stay:m
        ::  /main: HTTP gateway
        ::
        [~ %main]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%server /main: failed, staying inert" tang.prod)
        stay:m
      |-
      ;<  =cage  bind:m  take-poke:fiberio
      ?+    p.cage  $
          ::  Incoming HTTP request: create request file
          ::
          %handle-http-request
        ~?  veb  "%server /main: got handle-http-request"
        =/  [eyre-id=@ta req=inbound-request:eyre]
          !<([eyre-id=@ta inbound-request:eyre] q.cage)
        ::  Create request file at /requests/[eyre-id]
        =/  dest=(list @ta)  [%requests eyre-id ~]
        ~?  veb  "%server /main: creating request at /requests/{(trip eyre-id)}"
        ;<  ~  bind:m  (node-make:fiberio /make [%| 1 dest] |+[%http-request !>(req)])
        ~?  veb  "%server /main: request file created"
        $
          ::  Response from request file: send to eyre
          ::
          %server-action
        =/  act  !<(action q.cage)
        ?-    -.act
            %header
          ~?  veb  "%server /main: header -> {(trip eyre-id.act)}"
          ;<  ~  bind:m
            %-  send-cards:fiberio
            :~  :^  %give  %fact  ~[/http-response/[eyre-id.act]]
                http-response-header+!>(response-header.act)
            ==
          $
            %data
          ~?  veb  "%server /main: data -> {(trip eyre-id.act)}"
          ;<  ~  bind:m
            %-  send-cards:fiberio
            :~  [%give %fact ~[/http-response/[eyre-id.act]] http-response-data+!>(data.act)]
            ==
          $
            %kick
          ~?  veb  "%server /main: kick -> {(trip eyre-id.act)}"
          ;<  ~  bind:m
            %-  send-cards:fiberio
            :~  [%give %kick ~[/http-response/[eyre-id.act]] ~]
            ==
          $
            %response
          ~?  veb  "%server /main: response -> {(trip eyre-id.act)}"
          ;<  ~  bind:m
            %-  send-cards:fiberio
            (give-simple-payload:app:server eyre-id.act simple-payload.act)
          $
        ==
      ==
        ::  /requests/*: individual request handlers
        ::
        [[%requests ~] @]
      ~?  veb  "%server /requests/{(trip name)}: starting"
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%server /requests/{(trip name)}: failed" tang.prod)
        stay:m
      ::  Get request state (eyre-id is the filename)
      =/  eyre-id=@ta  name
      ;<  req=inbound-request:eyre  bind:m
        (get-state-as:fiberio ,inbound-request:eyre)
      ::  Build response
      =/  payload=simple-payload:http
        [[200 ~] `(as-octs:mimes:html 'Hello from request file!')]
      ::  Poke /main with response
      ~?  veb  "%server /requests/{(trip name)}: responding"
      ;<  ~  bind:m  (node-poke:fiberio /respond [%| 2 /main] server-action+!>([%response eyre-id payload]))
      ~?  veb  "%server /requests/{(trip name)}: done"
      ::  Done
      (pure:m ~)
    ==
  --
--
