::  lib/nex/server: shared types for the server nexus protocol
::
::  Used by nexuses that communicate with the server nexus
::  (binding HTTP paths, sending responses).
::
/+  nexus
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
::  Server state
::
+$  server-state
  $:  bindings=(map binding:eyre bend:fiber:nexus)
      connections=(map @ta binding:eyre)
  ==
--
