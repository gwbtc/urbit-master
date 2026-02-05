::  server nexus: HTTP bindings manager
::
::  Manages eyre bindings and authorizes HTTP responses.
::  Other nexuses poke to bind/unbind paths, receive forwarded
::  requests, and poke back with responses.
::
/+  nexus, tarball, io=fiberio, server, http-utils
|%
::  Binding actions
::
+$  bind-action
  $%  [%bind =binding:eyre]
      [%unbind =binding:eyre]
  ==
::  Response actions: eyre-id + update
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
::
++  main
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    =/  init=server-state  [~ ~]
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %server-state !>(init)])
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
    ?:  ?=(%rise -.prod)
      %-  (slog leaf+"%server /main: failed, staying inert" tang.prod)
      stay:m
    ~&  >  "%server /main: ready"
    |-
    ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
    ~&  >  [%server-poke p.cage]
    ?+    p.cage  $
        ::  Binding management
        ::
        %bind-action
      =/  act  !<(bind-action q.cage)
      ?.  ?=(%& -.from)  $
      ;<  st=server-state  bind:m  (get-state-as:io server-state)
      ?-    -.act
          %bind
        ~&  >  [%server-bind binding.act p.from]
        =.  bindings.st  (~(put by bindings.st) binding.act p.from)
        ;<  ~  bind:m  (replace:io !>(st))
        ::  Register with eyre
        ;<  ~  bind:m
          %-  send-cards:io
          [%pass /eyre-bind %arvo %e %connect binding.act master:io]~
        $
          %unbind
        ~&  >  [%server-unbind binding.act]
        ::  Kick orphaned connections for this binding
        =/  orphans=(list @ta)
          %+  murn  ~(tap by connections.st)
          |=  [eid=@ta =binding:eyre]
          ?.  =(binding binding.act)  ~
          `eid
        ;<  ~  bind:m
          %-  send-cards:io
          %+  turn  orphans
          |=  eid=@ta
          [%give %kick ~[/http-response/[eid]] ~]
        =.  connections.st
          %-  ~(gas by *(map @ta binding:eyre))
          %+  skip  ~(tap by connections.st)
          |=  [eid=@ta =binding:eyre]
          =(binding binding.act)
        =.  bindings.st  (~(del by bindings.st) binding.act)
        ;<  ~  bind:m  (replace:io !>(st))
        $
      ==
        ::  Incoming HTTP request from eyre
        ::
        %handle-http-request
      =/  [eyre-id=@ta req=inbound-request:eyre]
        !<([eyre-id=@ta inbound-request:eyre] q.cage)
      ~&  >  [%server-request eyre-id url.request.req]
      =/  =request-line:server  (parse-request-line:server url.request.req)
      =/  =binding:eyre  [~ site.request-line]
      ::  Look up binding (try progressively shorter paths)
      ;<  st=server-state  bind:m  (get-state-as:io server-state)
      =/  target=(unit bend:fiber:nexus)
        =/  pax=(list @t)  path.binding
        |-
        ^-  (unit bend:fiber:nexus)
        ?~  pax  ~
        =/  found  (~(get by bindings.st) [site.binding pax])
        ?^  found  found
        $(pax (snip `path`pax))
      ?~  target
        ~&  >  [%server-no-binding binding]
        ;<  ~  bind:m
          %-  send-cards:io
          (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
        $
      ~&  >  [%server-found-binding binding u.target]
      =.  connections.st  (~(put by connections.st) eyre-id binding)
      ;<  ~  bind:m  (replace:io !>(st))
      ::  Convert bend to road: [%| steps %& rail]
      =/  =road:tarball  [%| p.u.target %& q.u.target]
      ;<  ~  bind:m  (poke:io /forward road handle-http-request+!>([eyre-id req]))
      $
        ::  Response from handler
        ::
        %send-action
      =/  [eyre-id=@ta upd=eyre-update]  !<(send-action q.cage)
      ;<  st=server-state  bind:m  (get-state-as:io server-state)
      ::  Validate sender
      =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id)
      ?~  conn-binding
        ~&  >  [%server-unknown-connection eyre-id]
        $
      =/  expected-bend=(unit bend:fiber:nexus)  (~(get by bindings.st) u.conn-binding)
      ?~  expected-bend
        ~&  >  [%server-binding-gone u.conn-binding]
        $
      ?.  ?=(%& -.from)
        ~&  >  [%server-external-from eyre-id]
        $
      ?.  =(p.from u.expected-bend)
        ~&  >  [%server-unauthorized eyre-id p.from u.expected-bend]
        $
      ~&  >  [%server-send -.upd eyre-id]
      ?-    -.upd
          %header
        ;<  ~  bind:m
          %-  send-cards:io
          :~  :^  %give  %fact  ~[/http-response/[eyre-id]]
              http-response-header+!>(response-header.upd)
          ==
        $
          %data
        ;<  ~  bind:m
          %-  send-cards:io
          :~  [%give %fact ~[/http-response/[eyre-id]] http-response-data+!>(data.upd)]
          ==
        $
          %kick
        =.  connections.st  (~(del by connections.st) eyre-id)
        ;<  ~  bind:m  (replace:io !>(st))
        ;<  ~  bind:m
          %-  send-cards:io
          :~  [%give %kick ~[/http-response/[eyre-id]] ~]
          ==
        $
          %simple
        =.  connections.st  (~(del by connections.st) eyre-id)
        ;<  ~  bind:m  (replace:io !>(st))
        ;<  ~  bind:m
          %-  send-cards:io
          (give-simple-payload:app:server eyre-id simple-payload.upd)
        $
      ==
        ::  Client disconnected (eyre on-leave)
        ::
        %handle-http-cancel
      =/  eyre-id=@ta  !<(@ta q.cage)
      ;<  st=server-state  bind:m  (get-state-as:io server-state)
      ~&  >  [%server-cancel eyre-id]
      =.  connections.st  (~(del by connections.st) eyre-id)
      ;<  ~  bind:m  (replace:io !>(st))
      $
    ==
  --
--
