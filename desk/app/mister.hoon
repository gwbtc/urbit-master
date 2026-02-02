/+  default-agent, dbug, tarball, nexus, nex-main, server
/=  m-  /mar/tree
/=  m-  /mar/sand
/=  m-  /mar/kids
/=  m-  /mar/mister-action
/=  m-  /mar/mister-ack
|%
+$  versioned-state
  $%  state-0
  ==
+$  card  card:agent:gall
+$  state-0
  $:  %0
      =nexi:nexus
      =ball:tarball
      =pool:nexus
      =sand:nexus
      =born:nexus
      =bindings:nexus
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
  =.  nexi  default-nexi:nex-main
  ::  Create empty ball with %root nexus at root
  =/  init-ball=ball:tarball  [`[~ `%root ~] ~]  :: lump with neck=%root
  =^  cards  state
    abet:(reload:hc *pool:nexus init-ball *sand:nexus *born:nexus *bindings:nexus)
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
    ::  Ensure neck at root is %root (nexus on-load will create main.sig)
    =/  new-ball=ball:tarball
      =/  lmp=lump:tarball  (fall fil.ball.old [~ ~ ~])
      ball.old(fil `lmp(neck `%root))
    =^  cards  state
      abet:(reload:hc pool.old new-ball sand.old born.old bindings.old)
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
        abet:(set-weir:hc [path.here weir]:action)
      [cards this]
    ==
    ::  Eyre binding: bind URL path to file path
    ::
      %connect
    ?>  =(src our):bowl
    =+  !<([url=path here=rail:tarball] vase)
    ::  Encode rail in wire: [%connect len ...path... name]
    =/  wir=wire  [%connect (scot %ud (lent path.here)) (snoc path.here name.here)]
    :_  this
    [%pass wir %arvo %e %connect `url dap.bowl]~
    ::  Eyre unbinding
    ::
      %disconnect
    ?>  =(src our):bowl
    =+  !<(url=path vase)
    :_  this(bindings (~(del by bindings) url))
    [%pass / %arvo %e %disconnect `url]~
    ::  HTTP request from eyre: route to bound file
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    =/  lin=request-line:server  (parse-request-line:server url.request.req)
    ::  Find binding by progressively extending URL prefix
    ::
    =/  prefix=(list @t)  (scag 1 site.lin)
    |-
    ?~  here=(~(get by bindings) prefix)
      ?:  (lth (lent prefix) (lent site.lin))
        $(prefix (scag +((lent prefix)) site.lin))
      ::  No binding found
      ::
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[404 ~] `(as-octs:mimes:html 'Not Found')]
    ::  Poke the bound file with the request
    ::
    =/  =give:nexus  [|+[src sap]:bowl /[eyre-id]]
    =^  cards  state
      abet:(poke:hc give u.here handle-http-request+!>([eyre-id req]))
    [cards this]
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%poke @ *]
    ?>  =(src.bowl (slav %p i.t.path))
    [~ this]
      [%http-response *]
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
      [%proc ^]
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
  ?+    wire
    =^  cards  state
      abet:(take-arvo:hc wire sign)
    [cards this]
    ::  Eyre binding response
    ::
      [%connect *]
    ?>  ?=([%eyre %bound *] sign)
    ?.  accepted.sign
      %-  (slog leaf+"eyre bind failed: {(spud path.binding.sign)}" ~)
      [~ this]
    ::  Decode rail from wire: [len ...path... name]
    ?>  ?=([@ @ *] t.wire)
    =/  len=@ud  (slav %ud i.t.wire)
    =/  rest=path  t.t.wire
    =/  here=rail:tarball  [(scag len rest) (snag len rest)]
    %-  (slog leaf+"eyre bound: {(spud path.binding.sign)} -> {(spud (snoc path.here name.here))}" ~)
    [~ this(bindings (~(put by bindings) path.binding.sign here))]
  ==
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
    [(flop cards) state]
  =^  [here=rail:tarball =take:fiber:nexus]  takes  ~(get to takes)
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
  |=  [here=rail:tarball =give:nexus in=(unit intake:fiber:nexus)]
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
::  Clam a cage at sandbox boundary
::  Like validate-cage but always forces (no nest optimization) and
::  doesn't need path context. Used when data crosses a weir filter.
::
++  clam-cage
  |=  =cage
  ^-  (each ^cage tang)
  ::  Reject %temp mark - no dais, can't validate untrusted data
  ?:  =(%temp p.cage)
    |+~[leaf+"clam: cannot validate %temp mark from untrusted source"]
  ::  Get dais for the mark
  =/  dais-path=path
    /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/[p.cage]
  =/  dais-result=(each dais:clay tang)
    (mule |.(.^(dais:clay %cb dais-path)))
  ?:  ?=(%| -.dais-result)
    |+[leaf+"clam: no dais for mark {<p.cage>}" p.dais-result]
  ::  Validate using vale - returns vase with mark's canonical type
  =/  vale-result=(each vase tang)
    (mule |.((vale:p.dais-result q.q.cage)))
  ?:  ?=(%| -.vale-result)
    |+[leaf+"clam: validation failed for {<p.cage>}" p.vale-result]
  &+[p.cage p.vale-result]
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
  |=  [here=fold:tarball sub=ball:tarball]
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
  |=  [here=rail:tarball =proc:fiber:nexus]
  ^+  this
  =/  =pipe:nexus  (~(put by (fall (~(get of pool) path.here) ~)) name.here proc)
  this(pool (~(put of pool) path.here pipe))
::  Delete a file from pool and ball (NOT born - it's a high-water mark)
::
++  delete
  |=  [dir=path name=@ta]
  ^+  this
  =.  ball  (~(del ba:tarball ball) dir name)
  =/  =pipe:nexus  (~(del by (fall (~(get of pool) dir) ~)) name)
  this(pool (~(put of pool) dir pipe))
::  Send ack/nack back to poke source
::  - Internal (%&): enqueue %pack intake to source path
::  - External (%|): emit gall card
::
::  For internal pokes, sanitizes error if source can't peek target.
::
++  give-poke-ack
  |=  [here=rail:tarball =from:nexus =wire err=(unit tang)]
  ^+  this
  ::  Sanitize error if internal poke without peek permission
  =/  err=(unit tang)
    ?.  ?=(%& -.from)  err  :: external pokes see full error
    ?:  ?=([~ %|] (allowed p.from %peek `[%& here]))
      ?~(err ~ `~[leaf+"poke failed"])  :: no peek = generic error
    err
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
  |=  [here=rail:tarball =took:eval:fiber:nexus]
  ^+  this
  ?.  ?=([~ %poke *] in.take.took)  this
  (give-poke-ack here from.give.take.took wire.give.take.took err.took)
::
++  give-poke-signs
  |=  [here=rail:tarball done=(list took:eval:fiber:nexus)]
  ^+  this
  ?~  done  this
  =.  this  (give-poke-sign here i.done)
  $(done t.done)
::
++  nack-poke-takes
  |=  [here=rail:tarball takes=(qeu take:fiber:nexus) err=tang]
  ^+  this
  ?:  =(~ takes)  this
  =^  =take:fiber:nexus  takes  ~(get to takes)
  =.  this  (give-poke-sign here [take `err])
  $(takes takes)
::  Nack all queued pokes in a pool subtree
::
++  nack-pool
  |=  [here=fold:tarball =pool:nexus err=tang]
  ^+  this
  ::  Nack pokes in procs at this level
  =.  this
    ?~  fil.pool  this
    =/  procs=(list [name=@ta =proc:fiber:nexus])  ~(tap by u.fil.pool)
    |-
    ?~  procs  this
    =/  proc-rail=rail:tarball  [here name.i.procs]
    =.  this  (nack-poke-takes proc-rail next.proc.i.procs err)
    =.  this  (nack-poke-takes proc-rail skip.proc.i.procs err)
    $(procs t.procs)
  ::  Recurse into subdirectories
  =/  kids=(list [@ta pool:nexus])  ~(tap by dir.pool)
  |-
  ?~  kids  this
  =.  this  ^$(here (snoc here -.i.kids), pool +.i.kids)
  $(kids t.kids)
::  Run nexus on-loads top-down recursively
::
++  run-on-loads
  |=  [here=fold:tarball sub=ball:tarball]
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
  |=  [here=fold:tarball sub=ball:tarball]
  ^+  this
  ::  Spawn processes for files in this directory's contents
  =.  this
    ?~  fil.sub  this
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.sub)
    |-
    ?~  files  this
    =/  file-rail=rail:tarball  [here -.i.files]
    =.  this  (spawn-proc file-rail [%load ~])
    =.  this  (enqu-take file-rail (sys-give /load) ~)
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
          old-bindings=bindings:nexus
      ==
  ^+  this
  ::  Nack pokes in old proc queues
  =.  this  (nack-pool / old-pool ~[leaf+"agent [re]loaded"])
  ::  Restore state (pool will be rebuilt)
  =.  ball  old-ball
  =.  sand  old-sand
  =.  born  old-born
  =.  bindings  old-bindings
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
    =/  [proc-rail=rail:tarball @ ^path]  (unwrap-wire wire)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
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
  =/  [proc-rail=rail:tarball sub=^path]  (unwrap-watch-path pat)
  =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
  ?.  ?-  mode
        %file  =(proc-path path)
        %tree  =((scag (lent path) proc-path) path)
      ==
    ~
  [~ %give %kick ~[pat] ~]
::
++  process-darts
  |=  [here=rail:tarball darts=(list dart:nexus)]
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
  |=  here=rail:tarball
  ^-  (unit (pair path neck:tarball))
  =/  here-path=path  (snoc path.here name.here)
  |-
  ?~  lump=(~(get of ball) here-path)
    ?~  here-path  ~
    $(here-path (snip `path`here-path))
  ?^  neck.u.lump
    `[here-path u.neck.u.lump]
  ?~  here-path  ~
  $(here-path (snip `path`here-path))
::
++  build-spool
  |=  here=rail:tarball
  ^-  (unit spool:fiber:nexus)
  ::  Get the file from the ball - must exist
  =/  file-data=(unit content:tarball)  (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  ~
  ::  Extract mark from the cage
  =/  =mark  p.cage.u.file-data
  ::  Find the nearest parent nexus
  =/  nex-info=(unit (pair path neck:tarball))  (find-nearest-nexus here)
  ?~  nex-info  ~
  ::  Build the nexus from the neck
  =/  nex=(unit nexus:nexus)  (build-nexus q.u.nex-info)
  ?~  nex  ~
  ::  Calculate the subpath (directory relative to nexus)
  =/  subpath=path  (slag (lent p.u.nex-info) path.here)
  ::  Call on-file with subpath, name, and mark
  `(on-file:u.nex subpath name.here mark)
::
++  process-dart
  |=  [here=rail:tarball =dart:nexus]
  ^+  this
  =/  [=jump:nexus dest=(unit lane:tarball)]  (dart-to-dest here dart)
  =/  =filt:nexus  (allowed here jump dest)
  ?+    filt  (handle-dart here dart)
      [~ %|]
    ::  Vetoed - send %veto intake back to source
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Allowed but should clam poke vases
    ::  (make darts don't need clamming - they go through validate-cage anyway)
    ?.  ?=([%node * * %poke *] dart)
      (handle-dart here dart)
    =/  clammed=(each cage tang)  (clam-cage cage.load.dart)
    ?:  ?=(%| -.clammed)
      ~&  [%clam-failed here p.clammed]
      (enqu-take here (sys-give /veto) ~ %veto dart)
    (handle-dart here dart(cage.load p.clammed))
  ==
::  Extract jump category and destination from a dart for weir filtering.
::  Returns [jump dest] where:
::    - jump: the filter category (%sysc, %make, %poke, %peek)
::    - dest: absolute destination path, or ~ for syscalls
::
++  dart-to-dest
  |=  [here=rail:tarball =dart:nexus]
  ^-  [jump:nexus (unit lane:tarball)]
  ?+    -.dart  [%sysc ~]          :: %sysc, %scry, %bowl target system
      %node                        :: %node darts target a file/dir
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    :_  dest-lane
    ?-  -.load.dart
      %peek                 %peek
      %poke                 %poke
      ?(%make %cull %sand)  %make  :: all modify tree structure
    ==
  ==
::
++  handle-dart
  |=  [here=rail:tarball =dart:nexus]
  ^+  this
  ?-    -.dart
      %sysc
    ::  Emit gall card directly (with wrapped wire/paths)
    ::  Exception: /http-response/ paths go to eyre unwrapped
    =/  =card  card.dart
    ?+    card  (emit-card card)
        [%pass *]
      (emit-card card(p (wrap-wire here p.card)))
        [%give ?(%fact %kick) *]
      =/  wrapped=(list path)
        %+  turn  paths.p.card
        |=  p=path
        ?:  ?=([%http-response *] p)
          p  :: don't wrap http-response paths
        (wrap-watch-path here p)
      (emit-card card(paths.p wrapped))
    ==
    ::
      %node
    ::  Send load to another path
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    ?~  dest-lane
      ~&  [%node-bad-road here road.dart]
      this
    ?-    -.load.dart
        %poke
      ::  Poke destination must be a file
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      ::  Poke with return address (relativize source for fiber intake)
      =/  rel=from:fiber:nexus  (relativize-from:nexus dest &+here)
      (enqu-take dest [&+here wire.dart] ~ %poke rel cage.load.dart)
      ::
        %make
      ::  Create file/dir at dest (lane can be file or dir based on make type)
      ?>  ?=(%& -.u.dest-lane)  ::  for now, make always targets a rail
      =/  dest=rail:tarball  p.u.dest-lane
      =.  this  (make dest make.load.dart)
      ::  Send %made ack back to source
      (enqu-take here (sys-give /made) ~ %made wire.dart ~)
      ::
        %cull
      ::  Delete file at dest (must be a file)
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =.  this  (cull dest)
      ::  Send %gone ack back to source
      (enqu-take here (sys-give /gone) ~ %gone wire.dart ~)
      ::
        %sand
      ::  Set weir at dest (must be a directory)
      ?>  ?=(%| -.u.dest-lane)
      =/  dest=fold:tarball  p.u.dest-lane
      (edit-weir here wire.dart dest weir.load.dart)
      ::
        %peek
      ::  Peek at dest - return ball+sand subtree or single file
      ?-    kind.load.dart
          %ball
        ::  Ball peek targets a directory
        ?>  ?=(%| -.u.dest-lane)
        =/  dest=fold:tarball  p.u.dest-lane
        =/  sub-ball=ball:tarball  (~(dip ba:tarball ball) dest)
        =/  sub-sand=sand:nexus  (~(dip of sand) dest)
        (enqu-take here (sys-give /peek) ~ %peek wire.dart &+%ball^sub-ball^sub-sand)
        ::
          %file
        ::  File peek targets a file
        ?>  ?=(%& -.u.dest-lane)
        =/  dest=rail:tarball  p.u.dest-lane
        =/  content=(unit content:tarball)
          (~(get ba:tarball ball) path.dest name.dest)
        ?~  content
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        (enqu-take here (sys-give /peek) ~ %peek wire.dart &+%file^cage.u.content)
      ==
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
  |=  [here=rail:tarball =prod:fiber:nexus]
  ^+  this
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
  |=  [here=rail:tarball =take:fiber:nexus]
  ^+  this
  ::  Get pipe at directory, or empty map
  =/  =pipe:nexus  (fall (~(get of pool) path.here) ~)
  ::  Get proc for this file - must exist
  =/  prc=(unit proc:fiber:nexus)  (~(get by pipe) name.here)
  ?~  prc  this
  ::  Add take to queue, store, and run
  =/  =proc:fiber:nexus  u.prc
  =.  proc  proc(next (~(put to next.proc) take))
  =.  this  (store-proc here proc)
  (process-do-next here)
::
++  process-do-next
  |=  here=rail:tarball
  ^+  this
  ::  Get proc from pool
  =/  =pipe:nexus  (fall (~(get of pool) path.here) ~)
  =/  =proc:fiber:nexus  (~(got by pipe) name.here)
  ::  Get file state from ball
  =/  file-data=(unit content:tarball)
    (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  this  :: file doesn't exist
  =/  fil-state=vase  q.cage.u.file-data
  ::  Build bowl for this process (with filtered wex/sup)
  =/  =bowl:nexus  (make-bowl here)
  ::  Run the evaluator
  =/  [darts=(list dart:nexus) done=(list took:eval:fiber:nexus) new-state=vase new-proc=_proc res=result:eval:fiber:nexus]
    (take:eval:fiber:nexus bowl fil-state proc)
  ::  Process darts (emit cards or enqueue takes)
  =.  this  (process-darts here darts)
  ::  Ack consumed pokes
  =.  this  (give-poke-signs here done)
  ::  Validate new state before handling result (runtime, no force)
  =/  validated=(each vase tang)
    (validate-state path.here name.here p.cage.u.file-data new-state %.n)
  ?:  ?=(%| -.validated)
    ::  Validation failed - treat as crash
    =.  this  (nack-poke-takes here next.new-proc p.validated)
    =.  this  (nack-poke-takes here skip.new-proc p.validated)
    =.  this  (spawn-proc here [%rise p.validated])
    (enqu-take here (sys-give /rise) ~)
  ::  Validation passed - handle result normally
  ?-    -.res
      %next
    ::  Update state in ball and proc in pool
    =.  ball  (~(put ba:tarball ball) here [metadata.u.file-data p.cage.u.file-data p.validated])
    ::  Touch file to update mtime/size and propagate up
    =.  ball  (~(touch ba:tarball ball) here now.bowl)
    (store-proc here new-proc)
      %done
    ::  State was valid, now delete
    =/  err=tang  ~[leaf+"process completed"]
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    =.  ball  (~(touch ba:tarball ball) here now.bowl)
    =.  this  (clean (snoc path.here name.here) %file)
    (delete path.here name.here)
      %fail
    ::  Process failed - don't save state, restart
    =.  this  (nack-poke-takes here next.new-proc err.res)
    =.  this  (nack-poke-takes here skip.new-proc err.res)
    =.  this  (spawn-proc here [%rise err.res])
    (enqu-take here (sys-give /rise) ~)
  ==
::
++  poke
  |=  [=give:nexus here=rail:tarball =cage]
  ^+  this
  =/  rel-from=from:fiber:nexus  (relativize-from:nexus here from.give)
  (enqu-take here give ~ %poke rel-from cage)
::
++  make
  |=  [here=rail:tarball =make:nexus]
  ^+  this
  ?-  -.make
      %&
    ::  Assert nothing exists at path
    =/  here-path=path  (snoc path.here name.here)
    =/  existing=ball:tarball  (~(dip ba:tarball ball) here-path)
    ?:  |(?=(^ fil.existing) !=(~ dir.existing))
      ~|("path is not empty" !!)
    ::  Put new ball at path
    =.  ball  (~(pub ba:tarball ball) here-path p.make)
    ::  Get the subtree we just put (for running on-loads)
    =/  new-sub=ball:tarball  (~(dip ba:tarball ball) here-path)
    ::  Run on-loads top-down
    =/  loaded=ball:tarball  (run-on-loads here-path new-sub)
    ::  Validate all cages in loaded ball
    =/  validated=(each ball:tarball tang)  (validate-ball here-path loaded)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  sync-metadata: set mtime for all new files
    =/  synced=ball:tarball  (sync-metadata:tarball *ball:tarball p.validated now.bowl)
    ::  Put the synced subtree back
    =.  ball  (~(pub ba:tarball ball) here-path synced)
    ::  Spawn all file processes
    (spawn-all-files here-path synced)
    ::
      %|
    ::  Assert file doesn't already exist
    =/  existing-file=(unit content:tarball)
      (~(get ba:tarball ball) path.here name.here)
    ?^  existing-file
      ~|("file already exists at path" !!)
    ::  Validate the cage before storing (runtime, no force)
    =/  validated=(each cage tang)
      (validate-cage path.here name.here p.make %.n)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Store validated cage
    =.  ball  (~(put ba:tarball ball) here [~ p.validated])
    ::  Spawn the process and start it with ~ input
    =.  this  (spawn-proc here [%make ~])
    (enqu-take here (sys-give /make) ~)
  ==
::
++  cull
  |=  here=rail:tarball
  ^+  this
  =/  here-path=path  (snoc path.here name.here)
  ::  Nack all queued pokes in subtree
  =.  this  (nack-pool here-path (~(dip of pool) here-path) ~[leaf+"culled"])
  ::  Clean subscriptions for subtree
  =.  this  (clean here-path %tree)
  ::  Remove from pool and ball (NOT born - it's a high-water mark)
  =.  pool  (~(lop of pool) here-path)
  this(ball (~(lop ba:tarball ball) here-path))
::
++  set-weir
  |=  [dest=path weir=(unit weir:nexus)]
  ^+  this
  ?>  ?=(^ dest)  :: root should always have system access
  this(sand ?~(weir (~(del of sand) dest) (~(put of sand) dest u.weir)))
::
++  edit-weir
  |=  [src=rail:tarball =wire dest=fold:tarball weir=(unit weir:nexus)]
  ^+  this
  =.  this  (set-weir dest weir)
  ::  Send ack back to source
  (enqu-take src (sys-give /sand) ~ %sand wire ~)
::
++  make-bowl
  |=  here=rail:tarball
  ^-  bowl:nexus
  ::  Filter wex to only include outgoing subscriptions for this process
  =/  here-path=path  (snoc path.here name.here)
  =/  filtered-wex=boat:gall
    %-  ~(gas by *boat:gall)
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] acked=? =path]
    ?.  ?=([%proc @ *] wire)  ~
    =/  [proc-rail=rail:tarball @ orig-wire=^wire]  (unwrap-wire wire)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  =(proc-path here-path)  ~
    [~ [orig-wire ship term] acked path]
  ::  Filter sup to only include incoming subscriptions for this process
  =/  filtered-sup=bitt:gall
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship =path]
    ?.  ?=([%proc @ *] path)  ~
    =/  [proc-rail=rail:tarball sub=^path]  (unwrap-watch-path path)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  =(proc-path here-path)  ~
    [~ duct ship sub]
  [now our eny filtered-wex filtered-sup here]:[bowl .]
::  Sandboxing / weir filtering
::
::  System destination (~): walk up through ALL weirs to root
::  File destination ([~ path]): walk up to common ancestor only
::  Downward movement is always free.
::
++  allowed
  |=  [here=rail:tarball =jump:nexus dest=(unit lane:tarball)]
  ^-  filt:nexus
  ?~  dest
    ::  System: walk all the way up to root
    =|  =filt:nexus
    |-
    =/  next=filt:nexus
      (next-filt:nexus filt (filter:nexus / jump path.here (~(get of sand) path.here)))
    ?:  ?=([~ %|] next)  next
    ?~  path.here  next
    $(filt next, path.here (snip `fold:tarball`path.here))
  ::  Destination: walk up to common ancestor
  =/  dest-dir=fold:tarball  (fold-from-lane:tarball u.dest)
  =/  pref=path  (prefix:tarball path.here dest-dir)
  =/  steps=@ud  (sub (lent path.here) (lent pref))
  =|  =filt:nexus
  |-
  ?:  =(0 steps)  filt
  =/  next=filt:nexus
    (next-filt:nexus filt (filter:nexus dest-dir jump path.here (~(get of sand) path.here)))
  ?:  ?=([~ %|] next)  next
  $(filt next, path.here (snip `fold:tarball`path.here), steps (dec steps))
::
++  get-born
  |=  here=rail:tarball
  ^-  (unit @da)
  =/  m=(unit (map @ta @da))  (~(get of born) path.here)
  ?~  m  ~
  (~(get by u.m) name.here)
::
++  put-born
  |=  [here=rail:tarball b=@da]
  ^+  this
  =/  m=(map @ta @da)  (fall (~(get of born) path.here) ~)
  this(born (~(put of born) path.here (~(put by m) name.here b)))
::
++  make-born
  |=  here=rail:tarball
  ^-  @da
  =/  last=(unit @da)  (get-born here)
  ?~  last  now.bowl
  ?:((lth u.last now.bowl) now.bowl +(u.last))
::
++  wrap-wire
  |=  [here=rail:tarball =wire]
  ^+  wire
  =/  b=@da  (need (get-born here))
  =/  here-path=path  (snoc path.here name.here)
  ;:  weld
    /proc/(scot %ud (lent here-path))
    here-path
    /(scot %da b)
    wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [rail:tarball @da ^wire]
  ?>  ?=([%proc @ *] wire)
  =/  len=@ud  (slav %ud i.t.wire)
  =/  here-path=path  (scag len t.t.wire)
  ?>  ?=(^ here-path)
  =/  here=rail:tarball  [(snip `path`here-path) (rear here-path)]
  =/  rest=^wire  (slag len t.t.wire)
  ?>  ?=([@ *] rest)
  =/  b=@da  (slav %da i.rest)
  [here b t.rest]
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=rail:tarball b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit @da)  (get-born here)
  ?.  ?&(?=(^ cur) =(b u.cur))  this
  (enqu-take here (sys-give /arvo) ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=rail:tarball b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit @da)  (get-born here)
  ?.  ?&(?=(^ cur) =(b u.cur))  this
  (enqu-take here (sys-give /agent) ~ %agent wire sign)
::  Unwrap incoming watch/leave paths
::
++  unwrap-watch-path
  |=  pat=path
  ^-  [rail:tarball path]
  ?>  ?=([%proc @ *] pat)
  =/  len=@ud  (slav %ud i.t.pat)
  =/  here-path  (scag len t.t.pat)
  ?>  ?=(^ here-path)
  =/  here=rail:tarball  [(snip `(list @ta)`here-path) (rear here-path)]
  [here (slag len t.t.pat)]
::
++  wrap-watch-path
  |=  [here=rail:tarball =path]
  ^+  path
  =/  here-path=^path  (snoc path.here name.here)
  (weld /proc/(scot %ud (lent here-path)) (weld here-path path))
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=rail:tarball sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /watch) ~ %watch sub)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=rail:tarball sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /leave) ~ %leave sub)
--
