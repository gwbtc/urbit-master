::  server/main nexus: HTTP gateway
::
/+  nexus, tarball, fiberio, server
|%
+$  action
  $%  [%header eyre-id=@ta =response-header:http]
      [%data eyre-id=@ta data=(unit octs)]
      [%kick eyre-id=@ta]
      [%response eyre-id=@ta =simple-payload:http]
  ==
::
++  main
  ^-  nexus:nexus
  |%
  ++  on-load
    |~  =ball:nexus
    ^-  ball:nexus
    ::  Create /main file
    =.  ball  (~(put ba:tarball ball) / %main [~ %sig !>(~)])
    ::  Create /requests directory with neck=%requests
    (~(put of ball) /requests [~ `%requests ~])
  ::
  ++  on-file
    |=  [=path name=@ta =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?.  ?=([~ %main] [path name])
      stay:m
    ::  /main: HTTP gateway
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%server /main: failed, staying inert" tang.prod)
      stay:m
    |-
    ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:fiberio
    ?+    p.cage  $
        ::
        ::  Incoming HTTP request from eyre: create request file
        ::
        %handle-http-request
      =/  [eyre-id=@ta req=inbound-request:eyre]
        !<([eyre-id=@ta inbound-request:eyre] q.cage)
      ::  Create request file at /requests/[eyre-id]
      =/  dest=(list @ta)  [%requests eyre-id ~]
      ;<  ~  bind:m  (node-make:fiberio /make [%| 1 dest] |+[%http-request !>(req)])
      $
        ::
        ::  Response from request file: send to eyre
        ::
        ::  Security: verify the poke comes from the matching request file.
        ::  Only /requests/[eyre-id] may send responses for that eyre-id.
        ::
        %server-action
      =/  act  !<(action q.cage)
      =/  eyre-id=@ta
        ?-  -.act
          %header    eyre-id.act
          %data      eyre-id.act
          %kick      eyre-id.act
          %response  eyre-id.act
        ==
      ::  Validate source: must be internal from /requests/[eyre-id]
      ::
      ::  From /server/main's perspective, /server/requests/[eyre-id] is:
      ::    [1 /requests/[eyre-id]] - go up 1, then down /requests/[eyre-id]
      ::
      ::  Validate: must be internal from [1 /requests/[eyre-id]]
      ::
      ?>  ?=([%& %1 %requests @ ~] from)
      ?>  =(i.t.q.p.from eyre-id)
      ?-    -.act
          %header
        ;<  ~  bind:m
          %-  send-cards:fiberio
          :~  :^  %give  %fact  ~[/http-response/[eyre-id.act]]
              http-response-header+!>(response-header.act)
          ==
        $
          %data
        ;<  ~  bind:m
          %-  send-cards:fiberio
          :~  [%give %fact ~[/http-response/[eyre-id.act]] http-response-data+!>(data.act)]
          ==
        $
          %kick
        ;<  ~  bind:m
          %-  send-cards:fiberio
          :~  [%give %kick ~[/http-response/[eyre-id.act]] ~]
          ==
        $
          %response
        ;<  ~  bind:m
          %-  send-cards:fiberio
          (give-simple-payload:app:server eyre-id.act simple-payload.act)
        $
      ==
    ==
  --
++  requests
  ^-  nexus:nexus
  |%
  ++  on-load
    |~  =ball:nexus
    ball
  ::
  ++  on-file
    |=  [=path name=@ta =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?.  ?=([~ @] [path name])
      stay:m
    ::  Individual request handler
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%requests/{(trip name)}: failed" tang.prod)
      stay:m
    ::  Get request state (eyre-id is the filename)
    =/  eyre-id=@ta  name
    ;<  req=inbound-request:eyre  bind:m
      (get-state-as:fiberio ,inbound-request:eyre)
    ::  Build response
    =/  payload=simple-payload:http
      [[200 ~] `(as-octs:mimes:html 'Hello from request file!!!')]
    ::  Poke /main with response
    ;<  ~  bind:m  (node-poke:fiberio /respond [%| 2 /main] server-action+!>([%response eyre-id payload]))
    ::  Done
    (pure:m ~)
  --
--
