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
    |=  =ball:tarball
    ^-  ball:tarball
    ::  Create /main file
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
    ::  Create /requests directory with neck=%requests
    (~(put of ball) /requests [~ `%requests ~])
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
      =/  dest=lane:tarball  [%& /requests eyre-id]  :: file: dir=/requests, name=eyre-id
      ;<  ~  bind:m  (node-make:fiberio /make [%| 0 dest] |+[%http-request !>(req)])
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
      ::    bend=[0 rail=[path=/requests name=eyre-id]]
      ::  (0 steps because both are under /server)
      ::
      ?>  ?=([%& %0 [%requests ~] @] from)
      ?>  =(name.q.p.from eyre-id)
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
    |~  =ball:tarball
    ball
  ::
  ++  on-file
    |=  [=rail:tarball =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?.  ?=([~ @] rail)
      stay:m
    ::  Individual request handler
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%requests/{(trip name.rail)}: failed" tang.prod)
      stay:m
    ::  Get request state (eyre-id is the filename)
    =/  eyre-id=@ta  name.rail
    ;<  req=inbound-request:eyre  bind:m
      (get-state-as:fiberio ,inbound-request:eyre)
    ::  Build response
    =/  payload=simple-payload:http
      [[200 ~] `(as-octs:mimes:html 'Hello from request file!!!')]
    ::  Poke /main with response
    ::  From /server/requests/[id], up 1 to /server, then ./main
    =/  dest=road:tarball  [%| 1 [%& / %main]]
    ;<  ~  bind:m  (node-poke:fiberio /respond dest server-action+!>([%response eyre-id payload]))
    ::  Done
    (pure:m ~)
  --
--
