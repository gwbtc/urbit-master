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
++  build-nexus
  |=  neck=@tas
  ^-  (unit nexus:nexus)
  =/  all-files=(set path)
    (~(gas in *(set path)) .^((list path) %ct (weld /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl) /nex)))
  =/  paths=(list path)  (segments:clay neck)
  =/  matching-path=(unit path)
    |-
    ?~  paths  ~
    =/  pax=path  (weld /nex (snoc i.paths %hoon))
    ?:  (~(has in all-files) pax)
      `pax
    $(paths t.paths)
  ?~  matching-path
    ~
  =/  scry-path=path
    (weld /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl) u.matching-path)
  (mole |.(!<(nexus:nexus .^(vase %ca scry-path))))
::
++  find-nearest-nexus
  |=  here=path
  ^-  (unit (pair path neck:tarball))
  ?~  lump=(~(get of ball) here)
    ?~  here  ~
    $(here (snip `path`here))
  ?^  neck.u.lump
    `[here u.neck.u.lump]
  ?~  here  ~
  $(here (snip `path`here))
::
++  build-process
  |=  here=path
  ^-  (unit process:fiber:nexus)
  ::  Must have at least one element in path (the filename)
  ?~  here  ~
  ::  Get the file from the ball - must exist
  =/  file-data=(unit content:tarball)
    (~(get ba:tarball ball) (snip `path`here) (rear here))
  ?~  file-data  ~
  ::  Extract mark from the cage
  =/  =mark  p.cage.u.file-data
  ::  Find the nearest parent nexus
  =/  nex-info=(unit (pair path neck:tarball))  (find-nearest-nexus here)
  ?~  nex-info  ~
  ::  Build the nexus from the neck
  =/  nex=(unit nexus:nexus)  (build-nexus q.u.nex-info)
  ?~  nex  ~
  ::  Calculate the subpath relative to the nexus
  =/  subpath=path  (slag (lent p.u.nex-info) `path`here)
  ::  Call on-file to build the process
  `(on-file:u.nex subpath mark)
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
    ?^  (~(get of ball) here)
      ~|("directory already exists at path" !!)
    ?~  p.make
      this(ball (~(mkd ba:tarball ball) here ~ p.make))
    ?~  nex=(build-nexus u.p.make)
      this
    this(ball (~(pub ba:tarball ball) here (on-load:u.nex *ball:tarball)))
    ::
      %|
    ::  Assert file doesn't already exist
    =/  existing-file=(unit content:tarball)
      ?~  here  ~
      (~(get ba:tarball ball) (snip `path`here) (rear here))
    ?^  existing-file
      ~|("file already exists at path" !!)
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
