/+  default-agent, dbug, tarball, nexus, nex-main
|%
+$  versioned-state
  $%  state-0
  ==
++  veb  &
+$  card  card:agent:gall
+$  state-0  [%0 =ball:tarball =pool:nexus =nexi:nexus]
++  default-nexi
  %-  ~(gas by *nexi:nexus)
  :~  [%example example:nex-main]
  ==
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
  =.  nexi  default-nexi
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
  =.  nexi  default-nexi
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
    =/  =give:nexus  [|+[src sap]:bowl /poke]
    =^  cards  state
      abet:(poke:hc give here cage)
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
  =^  [here=path =take:fiber:nexus]  takes  ~(get to takes)
  $(this (process-take here take))
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
  |=  [here=path =give:nexus in=(unit intake:fiber:nexus)]
  this(takes (~(put to takes) [here give in]))
::
::  Generate a system give (for internal system operations)
::
++  sys-give
  |=  =wire
  ^-  give:nexus
  [|+[our.bowl /gall/mister] wire]
::
++  store-proc
  |=  [here=path =proc:fiber:nexus]
  ^+  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =/  =pipe:nexus  (~(put by (fall (~(get of pool) dir) ~)) name proc)
  this(pool (~(put of pool) dir pipe))
::
++  delete
  |=  here=path
  ^+  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =.  ball  (~(lop ba:tarball ball) here)
  =/  =pipe:nexus  (~(del by (fall (~(get of pool) dir) ~)) name)
  this(pool (~(put of pool) dir pipe))
::
::  Send ack/nack back to poke source
::  - Internal (%&): enqueue %pack intake to source path
::  - External (%|): emit gall card (TODO)
::
++  give-poke-ack
  |=  [=from:nexus =wire err=(unit tang)]
  ^+  this
  ?-    -.from
      %&
    ::  Internal - send %pack intake to source process
    (enqu-take p.from (sys-give /pack) ~ %pack wire err)
    ::
      %|
    ::  External - TODO: emit gall card back to caller
    ::  For now just log if error
    ?~  err  this
    ((slog leaf+"external poke failed" u.err) this)
  ==
::
++  give-poke-sign
  |=  =took:eval:fiber:nexus
  ^+  this
  ?.  ?=([~ %poke *] in.take.took)  this
  (give-poke-ack from.u.in.take.took wire.give.take.took err.took)
::
++  give-poke-signs
  |=  done=(list took:eval:fiber:nexus)
  ^+  this
  ?~  done  this
  =.  this  (give-poke-sign i.done)
  $(done t.done)
::
++  nack-poke-takes
  |=  [takes=(qeu take:fiber:nexus) err=tang]
  ^+  this
  ?:  =(~ takes)  this
  =^  =take:fiber:nexus  takes  ~(get to takes)
  =.  this  (give-poke-sign [take `err])
  $(takes takes)
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
  (~(get by nexi) neck)
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
++  build-spool
  |=  here=path
  ^-  (unit spool:fiber:nexus)
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
  ::  Call on-file to get the spool (initializer)
  `(on-file:u.nex subpath mark)
::
++  process-dart
  |=  [here=path =dart:nexus]
  ^+  this
  ?-    -.dart
      %sysc
    ::  Emit gall card directly (with wrapped wire)
    =/  =card  card.dart
    =?  card  ?=([%pass *] card)
      card(p (wrap-wire here p.card))
    (emit-card card)
    ::
      %cull
    ::  Delete self - enqueue a cull for this file
    ::  The actual deletion happens via the %done result
    ::  For now just note it - process should return %done
    this
    ::
      %node
    ::  Send load to another path
    =/  dest=path
      ?-  -.road.dart
        %&  p.road.dart  :: absolute path
        %|  (weld (scag p.p.road.dart here) q.p.road.dart)  :: relative path
      ==
    ?-    -.load.dart
        %poke
      ::  Poke with return address
      (enqu-take dest [&+here wire.dart] ~ %poke &+here cage.load.dart)
      ::
        %make
      ::  Create file/dir at dest
      (make dest make.load.dart)
      ::
        %cull
      ::  Delete file at dest
      (cull dest)
      ::
        %sand
      ::  Sandbox - not implemented yet
      this
      ::
        %kill
      ::  Kill process at dest - not implemented yet
      this
      ::
        %peek
      ::  Peek at dest - enqueue as intake
      ::  TODO: implement peek handling
      this
    ==
    ::
      %scry
    ::  Request scry - for now just do it synchronously
    ?~  scry.dart
      ::  Null scry means "get my path" - return here
      (enqu-take here (sys-give /scry) ~ %scry wire.dart here !>(here))
    ::  Do the scry and enqueue result
    ::  Path format: /vane/desk/rest... -> /vane/~ship/desk/~date/rest...
    =/  pat=path  path.u.scry.dart
    ?>  ?=([@ @ *] pat)
    =/  res=vase
      !>(.^(mold.u.scry.dart i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
    (enqu-take here (sys-give /scry) ~ %scry wire.dart path.u.scry.dart res)
    ::
      %bowl
    ::  Request bowl - build and enqueue
    (enqu-take here (sys-give /bowl) ~ %bowl wire.dart (make-bowl here))
  ==
::
++  process-take
  |=  [here=path =take:fiber:nexus]
  ^+  this
  ?~  here  this  :: can't process empty path
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  ::  Get pipe at directory, or empty map
  =/  =pipe:nexus  (fall (~(get of pool) dir) ~)
  ::  Get proc for this file, or create one
  =/  =proc:fiber:nexus
    ?^  prc=(~(get by pipe) name)
      u.prc
    =/  =spool:fiber:nexus  (need (build-spool here))
    =/  =process:fiber:nexus  (spool [%make ~])
    [process ~ ~]
  ::  Add take to queue, store, and run
  =.  proc  proc(next (~(put to next.proc) take))
  =.  this  (store-proc here proc)
  (process-do-next here)
::
++  process-do-next
  |=  here=path
  ^+  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  ::  Get proc from pool
  =/  =pipe:nexus  (fall (~(get of pool) dir) ~)
  =/  =proc:fiber:nexus  (~(got by pipe) name)
  ::  Get file state from ball
  =/  file-data=(unit content:tarball)
    (~(get ba:tarball ball) dir name)
  ?~  file-data  this  :: file doesn't exist
  =/  fil-state=vase  q.cage.u.file-data
  ::  Build bowl for this process (with filtered wex/sup)
  =/  =bowl:nexus  (make-bowl here)
  ::  Run the evaluator
  =/  [dartz=(list dart:nexus) done=(list took:eval:fiber:nexus) new-state=vase new-proc=_proc res=result:eval:fiber:nexus]
    (take:eval:fiber:nexus bowl fil-state proc)
  ::  Process darts (emit cards or enqueue takes)
  =.  this  (process-darts here dartz)
  ::  Ack consumed pokes
  =.  this  (give-poke-signs done)
  ::  Handle result
  ?-    -.res
      %next
    ::  Update state in ball and proc in pool
    =.  ball  (~(put ba:tarball ball) dir name [metadata.u.file-data p.cage.u.file-data new-state])
    (store-proc here new-proc)
    ::
      %done
    ::  Delete file and proc
    (delete here)
    ::
      %fail
    ::  Nack queued pokes and restart process with %rise
    =.  this  (nack-poke-takes next.new-proc err.res)
    =.  this  (nack-poke-takes skip.new-proc err.res)
    =/  =spool:fiber:nexus  (need (build-spool here))
    =/  =process:fiber:nexus  (spool [%rise err.res])
    =.  this  (store-proc here [process ~ ~])
    (enqu-take here (sys-give /rise) ~)
  ==
::
++  poke
  |=  [=give:nexus here=path =cage]
  ^+  this
  (enqu-take here give ~ %poke from.give cage)
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
    =.  ball  (put:ba (snip `path`here) (rear here) [~ p.make])
    ::  Start the process with ~ input
    (enqu-take here (sys-give /make) ~)
  ==
::
++  cull
  |=  here=path
  ^+  this
  ::  TODO: Check weir permissions
  ::  Delete from ball
  this(ball (~(lop ba:tarball ball) here))
::
++  make-bowl
  |=  here=path
  ^-  bowl:nexus
  ::  Filter wex to only include outgoing subscriptions for this process
  =/  filtered-wex=boat:gall
    %-  ~(gas by *boat:gall)
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] acked=? pat=path]
    =/  res=(unit [path ^wire])
      (mole |.((unwrap-wire wire)))
    ?~  res  ~
    ?.  =(-.u.res here)  ~
    [~ [+.u.res ship term] acked pat]
  ::  Filter sup to only include incoming subscriptions for this process
  =/  filtered-sup=bitt:gall
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship pat=path]
    =/  res=(unit [path wire])
      (mole |.((unwrap-wire pat)))
    ?~  res  ~
    ?.  =(-.u.res here)  ~
    [~ duct ship +.u.res]
  [now our eny filtered-wex filtered-sup here]:[bowl .]
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
  (enqu-take here (sys-give /arvo) ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=path =wire]  (unwrap-wire wir)
  (enqu-take here (sys-give /agent) ~ %agent wire sign)
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=path =wire]  (unwrap-wire pat)
  (enqu-take here (sys-give /watch) ~ %watch wire)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=path =wire]  (unwrap-wire pat)
  (enqu-take here (sys-give /leave) ~ %leave wire)
--
