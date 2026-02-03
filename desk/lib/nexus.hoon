/+  tarball
:: exploring the possibility of a directory-specific orchestrator agent
::
|%
+$  card  card:agent:gall
::  Nexus-specific types
::
+$  prov  [src=@p sap=path]         :: external provenance
+$  from  (each rail:tarball prov)  :: source: [%& rail] internal file or [%| prov] external
+$  give  [=from =wire]             :: return address (from is always a file)
+$  scry  [=mold =path]
+$  take  [here=rail:tarball take:fiber]  :: localized input (here is always a file)
::  SANDBOXING
::
::  Darts are conceptually emitted by processes and travel up the tree
::  to the nearest common ancestor with their destination, then down to
::  the destination. Downward movement is always legal. Upward movement
::  (or darts to self) must pass through weir filters at each directory.
::
::  Each weir specifies allowed destination prefixes for make/poke/peek.
::  If a dart's destination matches any allowed prefix, it passes.
::  If no weir exists at a directory, there's no filter (permissive).
::  Any weir can veto a dart; vetoed darts become %veto intakes.
::
::  filt results:
::    ~       no filter at this level (permissive)
::    [~ &]   filtered and allowed (should clam vases)
::    [~ |]   filtered and blocked (veto the dart)
::
+$  weir
  $:  make=(set road:tarball)  :: allowed destinations for %make, %cull, %sand
      poke=(set road:tarball)  :: allowed destinations for %poke
      peek=(set road:tarball)  :: allowed destinations for %peek
  ==
+$  sand  (axal weir)   :: weir at each directory in the tree
+$  filt  (unit ?)      :: filter result (see above)
+$  jump  ?(%sysc %make %poke %peek)  :: dart category for filtering
::
+$  bowl
  $:  now=@da
      our=@p
      eny=@uvJ
      wex=boat:gall
      sup=bitt:gall
      here=rail:tarball
  ==
::
+$  make  (each [=sand =ball:tarball] cage)
+$  view
  $%  [%ball =sand ball=ball:tarball]
      [%file =cage]
      [%none ~]
  ==
+$  seen  (each view tang)
:: dart payload
::
+$  load
  $%  [%poke =cage]
      [%make =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]  :: trigger on-load for a nexus (folds only)
      [%peek ~]
  ==
::
+$  dart
  $%  [%sysc =card:agent:gall]  :: regular card
      [%node =wire road=road:tarball =load]
      [%scry =wire scry=(unit scry)]
      [%bowl =wire]
  ==
::
++  fiber
  |%
  +$  proc
    $:  =process                 :: running fiber
        next=(qeu take)          :: queue of held inputs
        skip=(qeu take)          :: queue of skipped inputs
    ==
  ::  Relative source path for pokes
  ::
  ::  Fibers see only relative paths so they don't know their absolute location.
  ::  [%& bend] = internal source (relative path to a file)
  ::  [%| prov] = external source (ship + path)
  ::
  ::  Fiber bends always target files (rail), not directories.
  ::  Pokes come from files (processes), pokes go to files (processes).
  ::
  +$  bend  (pair @ud rail:tarball)   :: fiber-relative: steps up + target file
  +$  from  (each bend prov)
  ::
  +$  intake
    $%  [%poke =from =cage] :: command for a running process (from is relative)
        [%peek =wire =seen] :: local read result
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to cull
        [%pack =wire err=(unit tang)] :: response from poke; tang is generic if not allowed to peek
        [%sand =wire err=(unit tang)] :: response to sand
        [%load =wire err=(unit tang)] :: response to load
        [%veto =dart] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =vase]
        [%bowl =wire =bowl]
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
    ==
  ::
  +$  input
    $:  state=vase       :: state for which we are responsible
        in=(unit intake) :: command/response/data to ingest (null means start)
    ==
  ::
  +$  take  [=give in=(unit intake)]
  :: Three situations for process initialization
  ::
  +$  prod
    $%  [%make ~]     :: making new file
        [%load ~]     :: gall on-init or on-load
        [%rise =tang] :: failed while running
    ==
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ *vase %done *value]
    $:  darts=(list dart)
        state=vase
        $=  next
        $%  [%wait ~] :: process intake and await next
            [%skip ~] :: queue intake and await next
            [%cont self=(form-raw value)] :: continue to next computation
            [%fail err=tang] :: return failure
            [%done =value]   :: return result
        ==
    ==
  ::
  ++  form-raw
    |*  value=mold
    $-(input (output-raw value))
  ::
  +$  process  _*form:(fiber ,~)
  +$  spool    $-(prod process)    :: initializer - takes prod, returns process
  ::
  ++  fiber
    |*  value=mold
    |%
    ++  output  (output-raw value)
    ++  form    (form-raw value)
    :: give value; leave state unchanged
    ::
    ++  pure
      |=  =value
      ^-  form
      |=  input
      ^-  output
      [~ state %done value]
    :: do nothing - forever
    ::
    ++  stay
      ^-  form
      |=  input
      ^-  output
      [~ state %wait ~]
    ::
    ++  bind
      |*  b=mold
      |=  [m-b=(form-raw b) fun=$-(b form)]
      ^-  form
      |=  =input
      =/  b-res=(output-raw b)  (m-b input)
      ^-  output
      :-  darts.b-res
      :-  state.b-res
      ?-    -.next.b-res
        %wait  [%wait ~]
        %skip  [%skip ~]
        %cont  [%cont ..$(m-b self.next.b-res)]
        %fail  [%fail err.next.b-res]
        %done  [%cont (fun value.next.b-res)]
      ==
    --
  :: evaluation engine for the main state and continuation monad
  ::
  ++  eval
    |%
    ++  output  (output-raw ,~)
    ::
    +$  result
      $%  [%next ~]
          [%fail err=tang]
          [%done ~]
      ==
    ::
    +$  took  [=^take err=(unit tang)]
    ::
    ++  take
      =|  darts=(list dart) :: effects
      =|  done=(list took)  :: consumed takes for acking
      |=  [=bowl state=vase =proc]
      ^-  [(list dart) (list took) vase _proc result]
      =^  =^take  next.proc  ~(get to next.proc)
      |-  :: recursion point so take can be replaced
      =/  res=(each output tang)
        :: TODO: jet +hoss? 
        ::       should use hoss
        ::       but double compute and double slogs sucks
        ::
        (mule |.((process.proc state in.take)))
      ?:  ?=(%| -.res)
        =/  =tang  [leaf+"crash" p.res]
        :-  darts :: no output darts on failure
        :-  :_(done [take `tang])
        :-  state :: no output state on failure
        :-  proc
        [%fail tang]
      =/  =output  p.res
      ?-    -.next.output
          %fail
        :-  darts :: no output darts on failure
        :-  :_(done [take `err.next.output])
        :-  state :: no output state on failure
        :-  proc
        [%fail err.next.output]
        ::
          %done
        :-  (weld darts darts.output)
        :-  :_(done [take ~])
        :-  state.output
        :-  proc
        [%done ~]
        ::
          %cont
        %=  $
          darts         (weld darts darts.output)
          done          :_(done [take ~])
          state         state.output
          next.proc     (~(gas to next.proc) ~(tap to skip.proc))
          skip.proc     ~
          process.proc  self.next.output
          take          [give.take ~]
        ==
        ::
          %wait
        =.  darts  (weld darts darts.output)
        =.  done   :_(done [take ~])
        ?.  =(~ next.proc)
          :: recurse on queued input
          ::
          =^  top  next.proc  ~(get to next.proc)
          %=  $
            take       top
            state      state.output
          ==
        :: await input
        ::
        :-  darts
        :-  done
        :-  state.output
        :-  proc
        [%next ~]
        ::
          %skip
        ?:  =(~ in.take)
          :: can't %skip a ~ input
          ::
          =/  =tang  [leaf+"cannot skip null input" ~]
          :-  darts :: no output darts on failure
          :-  :_(done [take `tang])
          :-  state :: no output state on failure
          :-  proc
          [%fail tang]
        :: skip input - NOT added to done
        ::
        =.  skip.proc  (~(put to skip.proc) take)
        ?.  =(~ next.proc)
          :: recurse on queued input
          ::
          =^  top  next.proc  ~(get to next.proc)
          $(take top)
        :-  darts :: %skips can't send effects
        :-  done
        :-  state :: %skips can't change state
        :-  proc
        [%next ~]
      ==
    --
  --
::
+$  pipe  (map @ta proc:fiber)
+$  pool  (axal pipe)
+$  nexi  (map neck:tarball nexus)
::  Eyre bindings: URL path → file path in the tree
::
+$  bindings  (map path rail:tarball)
::  Process instance IDs - NEVER deleted, even when files are deleted.
::  Acts as high-water mark so recreated files get higher IDs,
::  preventing stale responses from being delivered to new processes.
::
+$  born  (axal (map @ta @da))
::  External action type for pokes
::
+$  action
  $:  [=wire dest=lane:tarball]
      $%  [%make =make]
          [%cull ~]
          [%sand weir=(unit weir)]
          [%load ~]
          [%poke =cage]
      ==
  ==
+$  ack  (unit tang)
::
++  deaf
  |=  tap=(trap)
  ^-  (each * (list tank))
  =/  ton  (mock [tap %9 2 %0 1] |=((pair) ~))
  ?-  -.ton
    %0  [%& p.ton]
  ::
    %1  =/  sof=(unit path)  ((soft path) p.ton)
        [%| ?~(sof leaf+"deaf.hunk" (smyt u.sof)) ~]
  ::
    %2  [%| p.ton]
  ==
::  Scry-free mule: like +mule but blocks .^ calls
::  FSCK: Runs the code twice, including slogs, etc.
::        +mule doesn't do that because it's jetted.
::
++  hoss
  |*  tap=(trap)
  =/  mud  (deaf tap)
  ?-  -.mud
    %&  [%& p=$:tap]
    %|  [%| p=p.mud]
  ==
::  Convert absolute from (rail) to relative from (fiber bend)
::
::  External sources pass through unchanged.
::  Internal sources get relativized to a fiber bend (always targets rail).
::
++  relativize-from
  |=  [here=rail:tarball =from]
  ^-  from:fiber
  ?.  ?=(%& -.from)
    from  :: external passes through
  =/  src=rail:tarball  p.from
  =/  pref=path  (prefix:tarball path.here path.src)
  =/  here-tail=path  (need (decap:tarball pref path.here))
  =/  src-tail=path  (need (decap:tarball pref path.src))
  &+[(lent here-tail) [src-tail name.src]]
::  Check if dest lane is permitted by an allowed lane.
::
++  raw-filter
  |=  [dest=lane:tarball allow=lane:tarball]
  ^-  ?
  ?-    -.dest
      ::  Destination is a file
      %&
    ?-  -.allow
      ::  Allowed lane is a file: must be the exact same file
      %&  =(p.dest p.allow)
      ::  Allowed lane is a dir: file must be somewhere under that dir
      %|  ?=(^ (decap:tarball p.allow path.p.dest))
    ==
      ::  Destination is a directory
      %|
    ?-  -.allow
      ::  Allowed lane is a file: a file rule can't permit directory operations
      %&  |
      ::  Allowed lane is a dir: dest dir must be under (or equal to) allowed dir
      %|  ?=(^ (decap:tarball p.allow p.dest))
    ==
  ==
::  Convert roads to absolute lanes, then check if dest is allowed.
::  `fold` is the directory whose weir we're checking
::
++  filter-roads
  |=  [=fold:tarball dest=lane:tarball roads=(list road:tarball)]
  ^-  ?
  ::  Convert relative roads to absolute lanes (murn filters out invalid roads)
  =/  lanes=(list lane:tarball)  (murn roads (cury lane-from-road:tarball [%| fold]))
  |-
  ?~  lanes  |
  ?:  (raw-filter dest i.lanes)  &
  $(lanes t.lanes)
::  Check a single weir: is this jump to dest allowed from here?
::  `fold` is the directory whose weir we're checking
::
++  filter
  |=  [=jump =fold:tarball dest=lane:tarball weir=(unit weir)]
  ^-  filt
  ?~  weir  ~                       :: no weir = no filter (permissive)
  ?:  ?=(%sysc jump)
    [~ |]                           :: weirs always block syscalls
  :-  ~
  ?-  jump
    %make  (filter-roads fold dest ~(tap in make.u.weir))
    %poke  (filter-roads fold dest ~(tap in poke.u.weir))
    %peek  (filter-roads fold dest ~(tap in peek.u.weir))
  ==
::  Combine two filter results. Veto wins; otherwise allow+clam wins.
::
++  next-filt
  |=  [cur=filt nex=filt]
  ^-  filt
  ?~  cur  nex
  ?~  nex  cur
  ?:  ?=([~ %|] cur)  [~ |]
  ?:  ?=([~ %|] nex)  [~ |]
  [~ &]
:: NOTES:
::  - in the +on-load, we recursively run nexus +on-loads in a top-down manner
::  - +on-load assumes all processes are being restarted
::  - we generate the process for every leaf node (file) and run it with ~,
::    accumulating effects
::  - each nexus should create a main process to handle its API
::
++  nexus
  $_  ^|
  |%
  :: top-down reconsideration of directory structure in +on-load and whenever
  :: this nexus is initially created
  ::
  ++  on-load
    |~  [sand ball:tarball]
    [*sand *ball:tarball]
  :: all files have an associated running process
  :: all running processes should be able to recover proper
  ::   operation based on state alone, even when restarted.
  ::   this is not guaranteed and is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [rail:tarball mark]
    *spool:fiber :: define spool (initializer) for file at rail
  --
--
