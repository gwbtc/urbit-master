::  fiberio: helper functions for nexus fibers
::
/+  nexus
|%
++  fiber   fiber:fiber:nexus
+$  input   input:fiber:nexus
+$  intake  intake:fiber:nexus
+$  dart    dart:nexus
::
++  veto-error
  |=  =dart
  ^-  tang
  ?-  -.dart
    %sysc  ~[leaf+"vetoed syscall"]
    %scry  ~[leaf+"vetoed scry on wire {(spud wire.dart)}"]
    %bowl  ~[leaf+"vetoed bowl request on wire {(spud wire.dart)}"]
    %node  ~[leaf+"vetoed node operation on wire {(spud wire.dart)}"]
  ==
::
++  send-darts
  |=  darts=(list dart)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  [darts state %done ~]
::
++  send-dart
  |=  =dart
  =/  m  (fiber ,~)
  ^-  form:m
  (send-darts dart ~)
::
++  send-card
  |=  =card:agent:gall
  =/  m  (fiber ,~)
  ^-  form:m
  (send-dart %sysc card)
::
++  send-cards
  |=  cards=(list card:agent:gall)
  =/  m  (fiber ,~)
  ^-  form:m
  (send-darts (turn cards |=(=card:agent:gall [%sysc card])))
::
++  fiber-fail
  |=  err=tang
  |=  input
  [~ state %fail err]
::
++  get-state
  =/  m  (fiber ,vase)
  ^-  form:m
  |=  input
  [~ state %done state]
::
++  get-state-as
  |*  a=mold
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  [~ state %done ;;(a q.state)]
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  =/  res  (mule |.(;;(a q.state)))
  ?-  -.res
    %&  [~ state %done p.res]
    %|  [~ state %done (gut p.res)]
  ==
::
++  replace
  |=  new=vase
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ new %done ~]
::
++  transform
  |=  f=$-(vase vase)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ (f state) %done ~]
::  Wait for any input and return it for manual switching
::
++  get-input
  =/  m  (fiber ,(unit intake))
  ^-  form:m
  |=  input
  [~ state %done in]
::
++  get-bowl
  |=  =wire
  =/  m  (fiber ,bowl:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %bowl wire)
  (take-bowl wire)
::
++  take-bowl
  |=  =wire
  =/  m  (fiber ,bowl:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %bowl * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done bowl.u.in]
  ==
::
++  take-poke
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done cage.u.in]
  ==
::  Take a poke and return both its source and payload
::
::  Returns [from cage] where:
::    from: %.y bend for internal (relative), %.n prov for external
::    cage: the poke payload
::
::  The from is relative to the current file's location.
::  Use this when you need to verify the poke source for security.
::
++  take-poke-from
  =/  m  (fiber ,[from:fiber:nexus cage])
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done [from cage]:u.in]
  ==
::
++  take-watch
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %watch *]
    [%done path.u.in]
  ==
::
++  take-leave
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %leave *]
    [%done path.u.in]
  ==
::
++  take-arvo
  |=  =wire
  =/  m  (fiber ,sign-arvo)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done sign.u.in]
  ==
::
++  take-agent
  |=  =wire
  =/  m  (fiber ,sign:agent:gall)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done sign.u.in]
  ==
::
++  take-made
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %made * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %make-failed u.err.u.in]
  ==
::
++  take-pack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %pack * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %poke-failed u.err.u.in]
  ==
::
++  take-peek
  |=  =wire
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %peek * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done seen.u.in]
  ==
::  Node operations: make, poke, peek, cull, sand
::
++  node-make
  |=  [=wire =road:nexus =make:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %make make)
  (take-made wire)
::
++  node-poke
  |=  [=wire =road:nexus =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %poke cage)
  (take-pack wire)
::
++  node-peek
  |=  [=wire =road:nexus kind=?(%ball %file)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %peek kind)
  (take-peek wire)
::
++  node-cull
  |=  [=wire =road:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %cull ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %cull-failed u.err.u.in]
  ==
::
++  node-sand
  |=  [=wire =road:nexus weir=(unit weir:nexus)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %sand weir)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %sand * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %sand-failed u.err.u.in]
  ==
::  Scry helper
::
++  do-scry
  |*  [=mold =wire =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %scry wire `[mold path])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %scry * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done !<(mold vase.u.in)]
  ==
::  Gall agent operations (via syscalls)
::
++  poke
  |=  [=wire =dock =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %poke cage]
  ;<  ~  bind:m  (send-card card)
  (take-poke-ack wire)
::
++  take-poke-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%poke-ack -.sign.u.in)
      [%skip ~]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %poke-failed u.p.sign.u.in]
  ==
::
++  watch
  |=  [=wire =dock =path]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %watch path]
  ;<  ~  bind:m  (send-card card)
  (take-watch-ack wire)
::
++  take-watch-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%watch-ack -.sign.u.in)
      [%skip ~]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %watch-failed u.p.sign.u.in]
  ==
::
++  take-fact
  |=  =wire
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%fact -.sign.u.in)
      [%skip ~]
    [%done cage.sign.u.in]
  ==
::
++  take-kick
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%kick -.sign.u.in)
      [%skip ~]
    [%done ~]
  ==
::
++  leave
  |=  [=wire =dock]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %leave ~]
  (send-card card)
::  Timer helpers
::
++  send-wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall
    [%pass /wait/(scot %da until) %arvo %b %wait until]
  (send-card card)
::
++  take-wake
  |=  until=(unit @da)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  |(?=(~ until) =(`u.until (slaw %da i.t.wire.u.in)))
      [%skip ~]
    ?~  error.sign.u.in
      [%done ~]
    [%fail %timer-error u.error.sign.u.in]
  ==
::
++  wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-wait until)
  (take-wake `until)
::
++  sleep
  |=  for=@dr
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /sleep)
  (wait (add now.bowl for))
::  Convenience bowl accessors
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-our)
  (pure:m our.bowl)
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-time)
  (pure:m now.bowl)
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-entropy)
  (pure:m eny.bowl)
::
++  get-here
  =/  m  (fiber ,path)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-here)
  (pure:m here.bowl)
::  Poke our own ship
::
++  poke-our
  |=  [=dude:gall =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (poke /poke [our dude] cage)
::  Eyre binding helpers
::
++  eyre-connect
  |=  [url=path dest=path]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (poke-our %mister connect+!>([url dest]))
  (pure:m ~)
::
++  eyre-disconnect
  |=  url=path
  =/  m  (fiber ,~)
  ^-  form:m
  (poke-our %mister disconnect+!>(url))
--
