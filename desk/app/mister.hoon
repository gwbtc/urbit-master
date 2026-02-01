/+  default-agent, dbug, tarball, nexus, nex-main
/=  m-  /mar/tree
/=  m-  /mar/sand
/=  m-  /mar/kids
/=  m-  /mar/mister-action
/=  m-  /mar/mister-ack
|%
+$  versioned-state
  $%  state-0
  ==
++  veb  &
+$  card  card:agent:gall
+$  state-0
  $:  %0
      =nexi:nexus
      =ball:tarball
      =pool:nexus
      =sand:nexus
      =born:nexus
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
  =.  nexi  default-nexi:nex-main
  =^  cards  state
    abet:(reload:hc *pool:nexus *ball:tarball *sand:nexus *born:nexus)
  [cards this]
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-state)
  =.  nexi  default-nexi:nex-main
  ?-    -.old
      %0
    =^  cards  state
      abet:(reload:hc [pool ball sand born]:old)
    [cards this]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %mister-action
    =+  !<(=action:nexus vase)
    ?-    +<.action
        %poke
      :: anyone can poke; process handles gatekeeping
      =/  =give:nexus  [|+[src sap]:bowl wire.action]
      =^  cards  state
        abet:(poke:hc give [here cage]:action)
      [cards this]
      ::
        %make
      ?>  =(src our):bowl
      =^  cards  state
        abet:(make:hc [here make]:action)
      [cards this]
      ::
        %cull
      ?>  =(src our):bowl
      =^  cards  state
        abet:(cull:hc here.action)
      [cards this]
      ::
        %sand
      ?>  =(src our):bowl
      =^  cards  state
        abet:(set-weir:hc [here weir]:action)
      [cards this]
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%poke @ *]
    ?>  =(src.bowl (slav %p i.t.path))
    [~ this]
      [%proc @ *]
    =^  cards  state
      abet:(take-watch:hc path)
    [cards this]
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-leave:def path)
      [%poke @ *]
    [~ this]
      [%proc @ *]
    =^  cards  state
      abet:(take-leave:hc path)
    [cards this]
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %peek %file *]
    ::  Single file's cage with its actual mark
    =/  here=^path  t.t.t.path
    ?~  here  ~
    =/  dir=^path  (snip `^path`here)
    =/  name=@ta  (rear here)
    =/  content=(unit content:tarball)
      (~(get ba:tarball ball) dir name)
    ?~  content  [~ ~]
    ``cage.u.content
    ::
      [%x %peek %kids *]
    ::  File names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((~(lis ba:tarball ball) here))
    ::
      [%x %peek %subs *]
    ::  Subdirectory names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((~(lss ba:tarball ball) here))
    ::
      [%x %peek %tree *]
    ::  Tree structure with marks, no content
    =/  here=^path  t.t.t.path
    =/  sub=ball:tarball  (~(dip ba:tarball ball) here)
    ``tree+!>((ball-to-tree:tarball sub))
    ::
      [%x %peek %sand *]
    ::  Sand (filter) subtree
    =/  here=^path  t.t.t.path
    ``sand+!>((~(dip of sand) here))
  ==
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
::  Generate a system give (for internal system operations)
::
++  sys-give
  |=  =wire
  ^-  give:nexus
  [|+[our.bowl /gall/mister] wire]
::  Validate a cage, checking nest or scrying for dais
::  Returns validated cage or error tang
::
::  NOTE: The returned vase type is always exactly as specific as the
::  mark demands - no more, no less. This is achieved two ways:
::    1. Via ++vale: returns a fresh vase with the mark's canonical type
::    2. Via nest optimization: inherits type from previously validated cage
::  This prevents type inflation (overly specific runtime types) and type
::  deflation (vases typed as * when they should be the mark's type).
::
::  force=%.n: use nest optimization if same mark + types nest (for incremental
::    updates like fiber state changes where we can skip dais scries)
::  force=%.y: always scry for dais (for bulk validation via validate-ball)
::
++  validate-cage
  |=  [pax=path name=@ta new-cage=cage force=?]
  ^-  (each cage tang)
  ::  Skip validation for %temp mark - ephemeral
  ?:  =(%temp p.new-cage)
    &+new-cage
  ::  Reject empty mime files
  ?:  ?&  =(%mime p.new-cage)
          =(0 p.q:!<(mime q.new-cage))
      ==
    |+~[leaf+"empty file at {(spud (snoc pax name))}"]
  ::  Check if there's existing content at this location
  =/  old=(unit content:tarball)  (~(get ba:tarball ball) pax name)
  ::  Same-mark update with nesting types: canonicalize without dais
  ::  Skip this optimization if force=%.y (on-load when type of $type may have changed)
  ::  Result vase type comes from old cage (already validated to mark's type)
  ?:  ?&  !force
          ?=(^ old)
          =(p.cage.u.old p.new-cage)
          (~(nest ut p.q.cage.u.old) | p.q.new-cage)
      ==
    &+[p.new-cage p.q.cage.u.old q.q.new-cage]
  ::  Need dais - scry for it
  =/  dais-path=path
    /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/[p.new-cage]
  =/  dais-result=(each dais:clay tang)
    (mule |.(.^(dais:clay %cb dais-path)))
  ?:  ?=(%| -.dais-result)
    |+[leaf+"no dais for mark {<p.new-cage>}" p.dais-result]
  ::  Validate using vale - passes noun, returns vase with mark's canonical type
  =/  vale-result=(each vase tang)
    (mule |.((vale:p.dais-result q.q.new-cage)))
  ?:  ?=(%| -.vale-result)
    |+[leaf+"validation failed for {<p.new-cage>}" p.vale-result]
  &+[p.new-cage p.vale-result]
::  Validate process state after evaluation
::
++  validate-state
  |=  [pax=path name=@ta =mark new-state=vase force=?]
  ^-  (each vase tang)
  =/  res=(each cage tang)  (validate-cage pax name [mark new-state] force)
  ?:  ?=(%| -.res)  res
  &+q.p.res
::  Validate all cages in a ball subtree
::  Returns validated ball or first error
::
::  Always forces full dais validation (no nest optimization). This is correct
::  because validate-ball is only called when installing a fresh subtree:
::    - reload: type of $type may have changed, must re-validate
::    - make subtree: files don't exist in ball yet, optimization wouldn't help
::  For incremental updates where nest optimization matters, use validate-cage.
::
++  validate-ball
  |=  [here=path sub=ball:tarball]
  ^-  (each ball:tarball tang)
  ::  Validate files at this level
  =/  validated-contents=(each (map @ta content:tarball) tang)
    ?~  fil.sub  &+~
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.sub)
    =|  out=(map @ta content:tarball)
    |-
    ?~  files  &+out
    =/  [name=@ta =content:tarball]  i.files
    =/  res=(each cage tang)  (validate-cage here name cage.content %.y)
    ?:  ?=(%| -.res)  res
    $(files t.files, out (~(put by out) name content(cage p.res)))
  ?:  ?=(%| -.validated-contents)
    validated-contents
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  =|  validated-dir=(map @ta ball:tarball)
  |-
  ?~  kids
    ::  Build validated ball - update fil contents if fil exists
    :-  %&
    :_  validated-dir
    ?~  fil.sub  ~
    `u.fil.sub(contents p.validated-contents)
  =/  [name=@ta kid=ball:tarball]  i.kids
  =/  res=(each ball:tarball tang)  ^$(here (snoc here name), sub kid)
  ?:  ?=(%| -.res)  res
  $(kids t.kids, validated-dir (~(put by validated-dir) name p.res))
::
++  store-proc
  |=  [here=path =proc:fiber:nexus]
  ^+  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =/  =pipe:nexus  (~(put by (fall (~(get of pool) dir) ~)) name proc)
  this(pool (~(put of pool) dir pipe))
::
::  Delete a file from pool and ball (NOT born - it's a high-water mark)
::
++  delete
  |=  here=path
  ^+  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =.  ball  (~(lop ba:tarball ball) here)
  =/  =pipe:nexus  (~(del by (fall (~(get of pool) dir) ~)) name)
  this(pool (~(put of pool) dir pipe))
::  Send ack/nack back to poke source
::  - Internal (%&): enqueue %pack intake to source path
::  - External (%|): emit gall card
::
++  give-poke-ack
  |=  [=from:nexus =wire err=(unit tang)]
  ^+  this
  ?-    -.from
      %&
    ::  Internal - send %pack intake to source path
    (enqu-take p.from (sys-give /pack) ~ %pack wire err)
    ::
      %|
    ::  External - send fact on caller's subscription path, then kick
    =/  src=@ta  (scot %p src.p.from)
    =/  pat=path  (weld /poke/[src] wire)
    =.  this  (emit-card %give %fact ~[pat] mister-ack+!>(err))
    (emit-card %give %kick ~[pat] ~)
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
::  Nack all queued pokes in a pool subtree
::
++  nack-pool
  |=  [=pool:nexus err=tang]
  ^+  this
  ::  Nack pokes in procs at this level
  =.  this
    ?~  fil.pool  this
    =/  procs=(list [@ta proc:fiber:nexus])  ~(tap by u.fil.pool)
    |-
    ?~  procs  this
    =.  this  (nack-poke-takes next.+.i.procs err)
    =.  this  (nack-poke-takes skip.+.i.procs err)
    $(procs t.procs)
  ::  Recurse into subdirectories
  =/  kids=(list [@ta pool:nexus])  ~(tap by dir.pool)
  |-
  ?~  kids  this
  =.  this  ^$(pool +.i.kids)
  $(kids t.kids)
::  Run nexus on-loads top-down recursively
::
++  run-on-loads
  |=  [here=path sub=ball:tarball]
  ^-  ball:tarball
  ::  Check if this node has a nexus
  =/  nex=(unit nexus:nexus)
    ?~  fil.sub  ~
    ?~  neck.u.fil.sub  ~
    (~(get by nexi) u.neck.u.fil.sub)
  ::  Run on-load if nexus exists
  =?  sub  ?=(^ nex)
    (on-load:u.nex sub)
  ::  Recurse into subdirectories
  %=  sub
    dir  %-  ~(urn by dir.sub)
         |=  [name=@ta kid=ball:tarball]
         ^$(here (snoc here name), sub kid)
  ==
::  Spawn processes for all files in ball
::
++  spawn-all-files
  |=  [here=path sub=ball:tarball]
  ^+  this
  ::  Spawn processes for files in this directory's contents
  =.  this
    ?~  fil.sub  this
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.sub)
    |-
    ?~  files  this
    =/  file-path=path  (snoc here -.i.files)
    =.  this  (spawn-proc file-path [%load ~])
    =.  this  (enqu-take file-path (sys-give /load) ~)
    $(files t.files)
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  |-
  ?~  kids  this
  =.  this  ^$(here (snoc here -.i.kids), sub +.i.kids)
  $(kids t.kids)
::
++  reload
  |=  $:  old-pool=pool:nexus
          old-ball=ball:tarball
          old-sand=sand:nexus
          old-born=born:nexus
      ==
  ^+  this
  ::  Nack pokes in old proc queues
  =.  this  (nack-pool old-pool ~[leaf+"agent [re]loaded"])
  ::  Restore state (pool will be rebuilt)
  =.  ball  old-ball
  =.  sand  old-sand
  =.  born  old-born
  ::  Clear ephemeral %temp cages - they shouldn't survive reload
  =.  ball  ~(clear-temp ba:tarball ball)
  ::  Run nexus on-loads top-down (may modify ball)
  =/  pre-ball=ball:tarball  ball
  =.  ball  (run-on-loads / ball)
  ::  Force-validate entire ball (type of $type may have changed since state was saved)
  =/  validated=(each ball:tarball tang)  (validate-ball / ball)
  ?:  ?=(%| -.validated)
    ~|("validation failed on reload" (mean p.validated))
  =.  ball  p.validated
  ::  Sync metadata: preserve old mtime where unchanged, update where changed
  =.  ball  (sync-metadata:tarball pre-ball ball now.bowl)
  ::  Spawn all file processes
  (spawn-all-files / ball)
:: TODO: handle outgoing keens
::
::  Clean up subscriptions for a file (%file) or subtree (%tree)
::
++  clean
  |=  [=path mode=?(%file %tree)]
  ^+  this
  ::  Leave outgoing subscriptions (wex)
  ::
  =.  this
    %-  emit-cards
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] *]
    ^-  (unit card)
    ?.  ?=([%proc @ *] wire)  ~
    =/  [proc-path=^path @ ^path]  (unwrap-wire wire)
    ?.  ?-  mode
          %file  =(proc-path path)
          %tree  =((scag (lent path) proc-path) path)
        ==
      ~
    [~ %pass wire %agent [ship term] %leave ~]
  ::  Kick incoming subscribers (sup)
  ::
  %-  emit-cards
  %+  murn  ~(tap by sup.bowl)
  |=  [=duct =ship pat=^path]
  ^-  (unit card)
  ?.  ?=([%proc @ *] pat)  ~
  =/  [proc-path=^path sub=^path]  (unwrap-watch-path pat)
  ?.  ?-  mode
        %file  =(proc-path path)
        %tree  =((scag (lent path) proc-path) path)
      ==
    ~
  [~ %give %kick ~[pat] ~]
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
  =/  [=jump:nexus dest=(unit path)]  (dart-to-jump-here here dart)
  =/  =filt:nexus  (allowed here jump dest)
  ?+    filt  (handle-dart here dart)
      [~ %|]
    ::  Vetoed - send %veto intake back to source
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Allowed but should clam vases - for now just handle
    ::  TODO: implement clamming
    (handle-dart here dart)
  ==
::  Extract jump category and destination from a dart for weir filtering.
::  Returns [jump dest] where:
::    - jump: the filter category (%sysc, %make, %poke, %peek)
::    - dest: absolute destination path, or ~ for syscalls
::
++  dart-to-jump-here
  |=  [here=path =dart:nexus]
  ^-  [jump:nexus (unit path)]
  ?+    -.dart  [%sysc ~]          :: %sysc, %scry, %bowl have no dest
      %node                        :: %node darts target another path
    :_  (path-from-road:nexus here road.dart)
    ?-  -.load.dart
      %peek                 %peek
      %poke                 %poke
      ?(%make %cull %sand)  %make  :: all modify tree structure
    ==
  ==
::
++  handle-dart
  |=  [here=path =dart:nexus]
  ^+  this
  ?-    -.dart
      %sysc
    ::  Emit gall card directly (with wrapped wire/paths)
    =/  =card  card.dart
    ?+    card  (emit-card card)
        [%pass *]
      (emit-card card(p (wrap-wire here p.card)))
        [%give ?(%fact %kick) *]
      =/  wrapped=(list path)
        (turn paths.p.card |=(p=path (wrap-watch-path here p)))
      (emit-card card(paths.p wrapped))
    ==
    ::
      %node
    ::  Send load to another path
    =/  dest=(unit path)  (path-from-road:nexus here road.dart)
    ?~  dest
      ~&  [%node-bad-road here road.dart]
      this
    ?-    -.load.dart
        %poke
      ::  Poke with return address
      (enqu-take u.dest [&+here wire.dart] ~ %poke &+here cage.load.dart)
      ::
        %make
      ::  Create file/dir at dest
      (make u.dest make.load.dart)
      ::
        %cull
      ::  Delete file at dest
      (cull u.dest)
      ::
        %sand
      ::  Set weir at dest
      (edit-weir here wire.dart u.dest weir.load.dart)
      ::
        %peek
      ::  Peek at dest - return ball and sand subtrees
      =/  sub-ball=ball:tarball  (~(dip ba:tarball ball) u.dest)
      =/  sub-sand=sand:nexus  (~(dip of sand) u.dest)
      (enqu-take here (sys-give /peek) ~ %peek wire.dart u.dest sub-ball sub-sand)
    ==
    ::
      %scry
    ?~  scry.dart
      ::  Null scry returns agent state
      (enqu-take here (sys-give /scry) ~ %scry wire.dart !>(state))
    ::  Do the scry and enqueue result
    ::  Path format: /vane/desk/rest... -> /vane/~ship/desk/~date/rest...
    =/  pat=path  path.u.scry.dart
    ?>  ?=([@ @ *] pat)
    =/  res=vase
      !>(.^(mold.u.scry.dart i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
    (enqu-take here (sys-give /scry) ~ %scry wire.dart res)
    ::
      %bowl
    ::  Request bowl - build and enqueue
    (enqu-take here (sys-give /bowl) ~ %bowl wire.dart (make-bowl here))
  ==
::
++  spawn-proc
  |=  [here=path =prod:fiber:nexus]
  ^+  this
  ?~  here  this
  ::  Generate and store born
  =/  b=@da  (make-born here)
  =.  this  (put-born here b)
  ::  Build and store proc - use default spool if no nexus
  =/  =spool:fiber:nexus
    (fall (build-spool here) default-spool)
  =/  =process:fiber:nexus  (spool prod)
  (store-proc here [process ~ ~])
::
++  default-spool
  ^-  spool:fiber:nexus
  |=  prod:fiber:nexus
  stay:(fiber:fiber:nexus ,~)
::
++  process-take
  |=  [here=path =take:fiber:nexus]
  ^+  this
  ?~  here  this  :: can't process empty path
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  ::  Get pipe at directory, or empty map
  =/  =pipe:nexus  (fall (~(get of pool) dir) ~)
  ::  Get proc for this file - must exist
  =/  prc=(unit proc:fiber:nexus)  (~(get by pipe) name)
  ?~  prc
    ~?  veb  "no process at {(spud here)}"
    this
  ::  Add take to queue, store, and run
  =/  =proc:fiber:nexus  u.prc
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
  ::  Validate new state before handling result (runtime, no force)
  =/  validated=(each vase tang)
    (validate-state dir name p.cage.u.file-data new-state %.n)
  ?:  ?=(%| -.validated)
    ::  Validation failed - treat as crash
    =.  this  (nack-poke-takes next.new-proc p.validated)
    =.  this  (nack-poke-takes skip.new-proc p.validated)
    =.  this  (spawn-proc here [%rise p.validated])
    (enqu-take here (sys-give /rise) ~)
  ::  Validation passed - handle result normally
  ?-    -.res
      %next
    ::  Update state in ball and proc in pool
    =.  ball  (~(put ba:tarball ball) dir name [metadata.u.file-data p.cage.u.file-data p.validated])
    (store-proc here new-proc)
      %done
    ::  State was valid, now delete
    =/  err=tang  ~[leaf+"process completed"]
    =.  this  (nack-poke-takes next.new-proc err)
    =.  this  (nack-poke-takes skip.new-proc err)
    =.  this  (clean here %file)
    (delete here)
      %fail
    ::  Process failed - don't save state, restart
    =.  this  (nack-poke-takes next.new-proc err.res)
    =.  this  (nack-poke-takes skip.new-proc err.res)
    =.  this  (spawn-proc here [%rise err.res])
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
    ::  Assert nothing exists at path
    =/  existing=ball:tarball  (~(dip ba:tarball ball) here)
    ?:  |(?=(^ fil.existing) !=(~ dir.existing))
      ~|("path is not empty" !!)
    ::  Put new ball at path
    =.  ball  (~(pub ba:tarball ball) here p.make)
    ::  Get the subtree we just put (for running on-loads)
    =/  new-sub=ball:tarball  (~(dip ba:tarball ball) here)
    ::  Run on-loads top-down
    =/  loaded=ball:tarball  (run-on-loads here new-sub)
    ::  Validate all cages in loaded ball
    =/  validated=(each ball:tarball tang)  (validate-ball here loaded)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  sync-metadata: set mtime for all new files
    =/  synced=ball:tarball  (sync-metadata:tarball *ball:tarball p.validated now.bowl)
    ::  Put the synced subtree back
    =.  ball  (~(pub ba:tarball ball) here synced)
    ::  Spawn all file processes
    (spawn-all-files here synced)
    ::
      %|
    ::  Assert file doesn't already exist
    =/  existing-file=(unit content:tarball)
      ?~  here  ~
      (~(get ba:tarball ball) (snip `path`here) (rear here))
    ?^  existing-file
      ~|("file already exists at path" !!)
    ::  Validate the cage before storing (runtime, no force)
    =/  validated=(each cage tang)
      (validate-cage (snip `path`here) (rear here) p.make %.n)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Store validated cage
    =.  ball  (~(put ba:tarball ball) (snip `path`here) (rear here) [~ p.validated])
    ::  Spawn the process and start it with ~ input
    =.  this  (spawn-proc here [%make ~])
    (enqu-take here (sys-give /make) ~)
  ==
::
++  cull
  |=  here=path
  ^+  this
  ::  Nack all queued pokes in subtree
  =.  this  (nack-pool (~(dip of pool) here) ~[leaf+"culled"])
  ::  Clean subscriptions for subtree
  =.  this  (clean here %tree)
  ::  Remove from pool and ball (NOT born - it's a high-water mark)
  =.  pool  (~(lop of pool) here)
  this(ball (~(lop ba:tarball ball) here))
::
++  set-weir
  |=  [dest=path weir=(unit weir:nexus)]
  ^+  this
  ?>  ?=(^ dest)  :: root should always have system access
  this(sand ?~(weir (~(del of sand) dest) (~(put of sand) dest u.weir)))
::
++  edit-weir
  |=  [src=path =wire dest=path weir=(unit weir:nexus)]
  ^+  this
  =.  this  (set-weir dest weir)
  ::  Send ack back to source
  (enqu-take src (sys-give /sand) ~ %sand wire ~)
::
++  make-bowl
  |=  here=path
  ^-  bowl:nexus
  ::  Filter wex to only include outgoing subscriptions for this process
  =/  filtered-wex=boat:gall
    %-  ~(gas by *boat:gall)
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] acked=? =path]
    ?.  ?=([%proc @ *] wire)  ~
    =/  [proc-path=^path @ orig-wire=^path]  (unwrap-wire wire)
    ?.  =(proc-path here)  ~
    [~ [orig-wire ship term] acked path]
  ::  Filter sup to only include incoming subscriptions for this process
  =/  filtered-sup=bitt:gall
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship =path]
    ?.  ?=([%proc @ *] path)  ~
    =/  [proc-path=^path sub=^path]  (unwrap-watch-path path)
    ?.  =(proc-path here)  ~
    [~ duct ship sub]
  [now our eny filtered-wex filtered-sup here]:[bowl .]
::  Sandboxing / weir filtering
::
::  Check weirs on the upward path from source dir to dest dir.
::  Downward movement is always free, so we only check weirs while
::  walking UP - we stop at the common ancestor without checking it.
::
++  allowed
  |=  [here=path =jump:nexus dest=(unit path)]
  ^-  filt:nexus
  ?~  dest  [~ |]
  ?~  here  [~ |]
  ?~  u.dest  [~ |]
  ::  Work at directory level (files are always the last path segment)
  ::
  =/  here-dir=path  (snip `path`here)
  =/  dest-dir=path  (snip `path`u.dest)
  =/  =bend:nexus  (make-bend:nexus here-dir dest-dir)
  =/  steps=@ud  p.bend
  =|  =filt:nexus
  |-
  ?:  =(0 steps)  filt             :: done - at common ancestor
  =/  next=filt:nexus
    %+  next-filt:nexus
      filt
    (filter:nexus dest-dir jump here-dir (~(get of sand) here-dir))
  ?:  ?=([~ %|] next)  next        :: early exit on veto
  %=  $
    filt      next
    here-dir  (snip here-dir)
    steps     (dec steps)
  ==
::
++  get-born
  |=  here=path
  ^-  (unit @da)
  ?~  here  ~
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =/  m=(unit (map @ta @da))  (~(get of born) dir)
  ?~  m  ~
  (~(get by u.m) name)
::
++  put-born
  |=  [here=path b=@da]
  ^+  this
  ?~  here  this
  =/  dir=path  (snip `path`here)
  =/  name=@ta  (rear here)
  =/  m=(map @ta @da)  (fall (~(get of born) dir) ~)
  this(born (~(put of born) dir (~(put by m) name b)))
::
++  make-born
  |=  here=path
  ^-  @da
  =/  last=(unit @da)  (get-born here)
  ?~  last  now.bowl
  ?:((lth u.last now.bowl) now.bowl +(u.last))
::
++  wrap-wire
  |=  [here=path =wire]
  ^+  wire
  =/  b=@da  (need (get-born here))
  ;:  weld
    /proc/(scot %ud (lent here))
    here
    /(scot %da b)
    wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [path @da ^wire]
  ?>  ?=([%proc @ *] wire)
  =/  len=@ud  (slav %ud i.t.wire)
  =/  here=path  (scag len t.t.wire)
  =/  rest=^wire  (slag len t.t.wire)
  ?>  ?=([@ *] rest)
  =/  b=@da  (slav %da i.rest)
  [here b t.rest]
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=path b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit @da)  (get-born here)
  ?.  ?&(?=(^ cur) =(b u.cur))
    ~?  veb  "stale arvo response for {(spud here)}"
    this
  (enqu-take here (sys-give /arvo) ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=path b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit @da)  (get-born here)
  ?.  ?&(?=(^ cur) =(b u.cur))
    ~?  veb  "stale agent response for {(spud here)}"
    this
  (enqu-take here (sys-give /agent) ~ %agent wire sign)
::  Unwrap incoming watch/leave paths
::
++  unwrap-watch-path
  |=  pat=path
  ^-  [path path]
  ?>  ?=([%proc @ *] pat)
  =/  len=@ud  (slav %ud i.t.pat)
  [(scag len t.t.pat) (slag len t.t.pat)]
::
++  wrap-watch-path
  |=  [here=path =path]
  ^+  path
  (weld /proc/(scot %ud (lent here)) (weld here path))
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=path sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /watch) ~ %watch sub)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=path sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /leave) ~ %leave sub)
--
