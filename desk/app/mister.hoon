/+  default-agent, dbug, tarball, nexus
|%
+$  versioned-state
  $%  state-0
  ==
++  veb  &
+$  card  card:agent:gall
+$  state-0  [%0 =ball:tarball =pool:nexus]
--
::
=|  state-0
=*  state  -
::
=<
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%mister initialized'
  `this
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-state)
  ?-  -.old
    %0  `this(ball ball.old, pool pool.old)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %make
    =+  !<([=path =make:nexus] vase)
    =^  cards  state
      abet:(make:hc path make)
    [cards this]
    ::
      %cull
    =+  !<(=path vase)
    =^  cards  state
      abet:(cull:hc path)
    [cards this]
    ::
      %poke
    =+  !<([here=path =cage] vase)
    =^  cards  state
      abet:(poke:hc |+[src sap]:bowl here cage)
    [cards this]
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  =^  cards  state
    abet:(take-watch:hc path)
  [cards this]
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  =^  cards  state
    abet:(take-leave:hc path)
  [cards this]
::
++  on-peek   on-peek:def
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  =^  cards  state
    abet:(take-agent:hc wire sign)
  [cards this]
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  =^  cards  state
    abet:(take-arvo:hc wire sign)
  [cards this]
::
++  on-fail   on-fail:def
--
::
::  helper core for routing events to processes
::
=|  cards=(list card)
=|  takes=(qeu take:nexus)
|_  =bowl:gall
+*  this  .
::
++  abet
  |-
  ?:  =(~ takes)
    ~?  >  veb  "done-abet!"
    [(flop cards) state]
  =^  =take:nexus  takes  ~(get to takes)
  $(this (process-take take))
::
++  emit-card
  |=  =card
  this(cards [card cards])
::
++  emit-cards
  |=  cadz=(list card)
  this(cards (welp (flop cadz) cards))
::
++  enqu-take
  |=  [here=path in=(unit intake:fiber:nexus)]
  this(takes (~(put to takes) [here in]))
::
++  process-darts
  |=  [here=path darts=(list dart:nexus)]
  ^+  this
  ?~  darts  this
  =.  this  (process-dart here i.darts)
  $(darts t.darts)
::
++  process-dart
  |=  [here=path =dart:nexus]
  ^+  this
  !!
::
++  process-take
  |=  [here=path in=(unit intake:fiber:nexus)]
  ^+  this
  !!
::
++  poke
  |=  [=from:nexus here=path =cage]
  ^+  this
  (enqu-take here ~ %poke from cage)
::
++  make
  |=  [here=path =make:nexus]
  ^+  this
  ?-  -.make
      %&
    this(ball (~(mkd ba:tarball ball) here ~ p.make))
      %|
    ?~  here
      ~|("cannot create file at root" !!)
    ::  TODO: Build dais for mark validation via scry
    ::  For now, use empty dais map (validation will crash if needed)
    =/  ba  (~(das ba:tarball ball) ~)
    this(ball (put:ba (snip `path`here) (rear here) [~ p.make]))
  ==
::
++  cull
  |=  here=path
  ^+  this
  ::  TODO: Check weir permissions
  ::  Delete from ball
  this(ball (~(lop ba:tarball ball) here))
::
++  wrap-wire
  |=  [here=path =wire]
  ^+  wire
  ;:  weld
    /(scot %ud (lent here))
    here  wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [path ^wire]
  ?>  ?=([@ *] wire)
  =/  len=@ud  (slav %ud i.wire)
  :-  (scag len t.wire)
  (slag len t.wire)
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=path =wire]  (unwrap-wire wir)
  (enqu-take here ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=path =wire]  (unwrap-wire wir)
  (enqu-take here ~ %agent wire sign)
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=path =wire]  (unwrap-wire pat)
  (enqu-take here ~ %watch pat)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=path =wire]  (unwrap-wire pat)
  (enqu-take here ~ %leave pat)
--
