::  lib/nex/server: shared types + helpers for the server nexus protocol
::
::  Used by nexuses that communicate with the server nexus
::  (binding HTTP paths, sending responses, dispatching requests).
::
/+  nexus, tarball, io=fiberio
|%
::  Binding actions: sent to server nexus to register/unregister eyre paths
::
+$  bind-action
  $%  [%bind =binding:eyre]
      [%unbind =binding:eyre]
  ==
::  Response actions: eyre-id + update, sent back through server nexus
::
+$  send-action  (pair @ta eyre-update)
::
+$  eyre-update
  $%  [%header =response-header:http]
      [%data data=(unit octs)]
      [%kick ~]
      [%simple =simple-payload:http]
  ==
::  Server state (versioned for migration)
::
+$  server-state
  $:  %0
      bindings=(map binding:eyre bend:fiber:nexus)
      connections=(map @ta binding:eyre)
  ==
::  Absolute road to /server/main
::
++  server-road  `road:tarball`[%& %& /server %main]
::  Register an eyre binding with the server nexus
::
++  bind-http
  |=  =binding:eyre
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /bind server-road bind-action+!>([%bind binding]))
::  HTTP response helpers, parameterized on dispatcher road.
::  Usage: =/  srv  ~(. res:nex-server [%| 1 %& ~ %main])
::         (send-simple:srv eyre-id payload)
::
++  res
  |_  main=road:tarball
  ++  send
    |=  =send-action
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (poke:io /send main send-action+!>(send-action))
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
  --
::  Standard HTTP dispatcher loop for nexuses with /requests/ sub-dir.
::  Spawns per-request processes, forwards responses, handles cancels.
::
++  http-dispatch
  |=  label=@tas
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
  ?+    p.cage  $
      %handle-http-request
    =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
      !<([eyre-id=@ta @p inbound-request:eyre] q.cage)
    ~&  >  [label %dispatch eyre-id url.request.req]
    ;<  ~  bind:m  (make:io /make [%| 0 %& /requests eyre-id] |+http-request+!>([src req]))
    $
      %send-action
    ;<  ~  bind:m  (poke:io /send server-road cage)
    $
      %handle-http-cancel
    =/  eyre-id=@ta  !<(@ta q.cage)
    ~&  >  [label %cancel eyre-id]
    ;<  ~  bind:m  (cull:io /cancel [%| 0 %& /requests eyre-id])
    $
  ==
--
