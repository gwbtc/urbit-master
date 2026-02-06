::  server nexus: HTTP bindings manager
::
::  Manages eyre bindings and authorizes HTTP responses.
::  Other nexuses poke to bind/unbind paths, receive forwarded
::  requests, and poke back with responses.
::
/+  nexus, tarball, io=fiberio, server, http-utils, nex-server
=>  |%
    ::  +find-suffix: returns [~ /tail] if :full is (weld :prefix /tail)
    ::
    ++  find-suffix
      |=  [prefix=path full=path]
      ^-  (unit path)
      ?~  prefix  `full
      ?~  full    ~
      ?.  =(i.prefix i.full)  ~
      $(prefix t.prefix, full t.full)
    --
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    =/  init=server-state:nex-server  [~ ~]
    (~(put ba:tarball ball) [/ %main] [~ %server-state !>(init)])
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
  ?+    p.cage  $
      ::  Binding management
      ::
      %bind-action
    =/  act  !<(bind-action:nex-server q.cage)
    ?.  ?=(%& -.from)  $
    ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
    ?-    -.act
        %bind
      ~&  >  [%server-bind binding.act p.from]
      =.  bindings.st  (~(put by bindings.st) binding.act p.from)
      ;<  ~  bind:m  (replace:io !>(st))
      ::  Register with eyre
      ;<  =dude:gall  bind:m  get-agent:io
      ;<  ~  bind:m
        %-  send-cards:io
        [%pass /eyre-bind %arvo %e %connect binding.act dude]~
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
    =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
      !<([eyre-id=@ta @p inbound-request:eyre] q.cage)
    ~&  >  [%server-request eyre-id url.request.req]
    =/  =request-line:server  (parse-request-line:server url.request.req)
    ::  Look up binding (prefix match, most specific wins)
    ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
    =/  match=(unit [=binding:eyre =bend:fiber:nexus])
      =|  best=(unit [=binding:eyre =bend:fiber:nexus])
      =/  entries=(list [=binding:eyre =bend:fiber:nexus])
        ~(tap by bindings.st)
      |-
      ?~  entries  best
      ?~  (find-suffix path.binding.i.entries site.request-line)
        $(entries t.entries)
      ?~  best  $(best `i.entries, entries t.entries)
      ?:  (gth (lent path.binding.i.entries) (lent path.binding.u.best))
        $(best `i.entries, entries t.entries)
      $(entries t.entries)
    ?~  match
      ~&  >  [%server-no-binding site.request-line]
      ;<  ~  bind:m
        %-  send-cards:io
        (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
      $
    ~&  >  [%server-found-binding binding.u.match bend.u.match]
    =.  connections.st  (~(put by connections.st) eyre-id binding.u.match)
    ;<  ~  bind:m  (replace:io !>(st))
    ::  Convert bend to road: [%| steps %& rail]
    =/  =road:tarball  [%| p.bend.u.match %& q.bend.u.match]
    ;<  ~  bind:m  (poke:io /forward road handle-http-request+!>([eyre-id src req]))
    $
      ::  Response from handler
      ::
      %send-action
    =/  [eyre-id=@ta upd=eyre-update:nex-server]  !<(send-action:nex-server q.cage)
    ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
    ::  Validate sender
    =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id)
    ?~  conn-binding
      ~&  >  [%server-unknown-connection eyre-id]
      ::  Forward cancel to sender so it can clean up
      ?.  ?=(%& -.from)  $
      =/  =road:tarball  [%| p.p.from %& q.p.from]
      ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id))
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
    ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
    ~&  >  [%server-cancel eyre-id]
    =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id)
    =.  connections.st  (~(del by connections.st) eyre-id)
    ;<  ~  bind:m  (replace:io !>(st))
    ::  Forward cancel to bound nexus
    ?~  conn-binding  $
    =/  =bend:fiber:nexus  (fall (~(get by bindings.st) u.conn-binding) *bend:fiber:nexus)
    =/  =road:tarball  [%| p.bend %& q.bend]
    ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id))
    $
  ==
--
