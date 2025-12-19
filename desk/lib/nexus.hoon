/+  sailbox, tarball
:: exploring the possibility of a directory-specific orchestrator agent
::
|%
+$  bowl  bowl:gall             :: to be replaced with local version
+$  ball  ball:tarball
+$  proc  @tas                  :: like a mark but for a process
+$  bend  (pair @ud path)                 :: relative path
+$  road  (each path bend)                :: absolute or relative path
+$  prov  [src=@p sap=path]               :: external provenance
+$  from  (each path prov)                :: absolute source
+$  give  [=from =wire]                   :: return address
+$  scry  [=mold =path]
:: a filter or net
::
+$  weir
  $:  poke=(set road) :: %poke or %bump
      peek=(set road)
  ==
+$  sand  (axal weir)
+$  dart
  $%  [%sysc =card:agent:gall]  :: regular card
      [%poke =wire =road =cage] :: results in file creation
      [%bump =wire =road =cage] :: a message to a running process
      [%sand =wire =road weir=(unit weir)] :: manage sandboxing
      [%scry =wire scry=(unit scry)]
      [%bowl =wire]
  ==
::
++  fiber
  |%
  +$  proc
    $:  =process
        next=(qeu (unit intake)) :: queue of held inputs
        skip=(qeu (unit intake)) :: queue of skipped inputs
    ==
  ::
  +$  intake
    $%  [%bump =from =cage] :: command for a running process
        [%peek =wire =path =ball:tarball =sand] :: local read
        [%sand =wire err=(unit tang)] :: response to sand
        [%pack =wire err=(unit tang)] :: response from poke
        [%back =wire err=(unit tang)] :: response from bump
        [%veto =dart] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =path =vase]
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
  ++  output-raw
    |*  value=mold
    $~  [~ *vase %done *value]
    $:  cards=(list card) :: allows for %sse card
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
    ::
    ++  bind
      |*  b=mold
      |=  [m-b=(form-raw b) fun=$-(b form)]
      ^-  form
      |=  =input
      =/  b-res=(output-raw b)  (m-b input)
      ^-  output
      :-  cards.b-res
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
    ++  take
      =|  cards=(list card) :: effects
      |=  [=bowl:gall state=vase =proc]
      ^-  [(list card) vase _proc result]
      =^  take=(unit intake)  next.proc  ~(get to next.proc)
      |-  :: recursion point so take can be replaced
      =/  res=(each output tang)
        (mule |.((process.proc state take)))
      ?:  ?=(%| -.res)
        =/  =tang  [leaf+"crash" p.res]
        :-  cards :: no output cards on failure
        :-  state :: no output state on failure
        :-  proc
        [%fail tang]
      =/  =output  p.res
      ?-    -.next.output
          %fail
        :-  cards :: no output cards on failure
        :-  state :: no output state on failure
        :-  proc
        [%fail err.next.output]
        ::
          %done
        :-  (weld cards cards.output)
        :-  state.output
        :-  proc
        [%done ~]
        ::
          %cont
        %=  $
          cards         (weld cards cards.output)
          state         state.output
          next.proc     (~(gas to next.proc) ~(tap to skip.proc))
          skip.proc     ~
          process.proc  self.next.output
          take          ~
        ==
        ::
          %wait
        =.  cards  (weld cards cards.output)
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
        :-  cards
        :-  state.output
        :-  proc
        [%next ~]
        ::
          %skip
        ?:  =(~ take)
          :: can't %skip a ~ input
          ::
          =/  =tang  [leaf+"cannot skip null input" ~]
          :-  cards :: no output cards on failure
          :-  state :: no output state on failure
          :-  proc
          [%fail tang]
        :: skip input
        ::
        =.  skip.proc  (~(put to skip.proc) take)
        ?.  =(~ next.proc)
          :: recurse on queued input
          ::
          =^  top  next.proc  ~(get to next.proc)
          $(take top)
        :-  cards :: %skips can't send effects
        :-  state :: %skips can't change state
        :-  proc
        [%next ~]
      ==
    --
  --
:: ++  process  process:fiber:sailbox :: to be replaced with local version
:: NOTES:
::  - there shouldn't really be a difference between
::    the runner's +on-init and +on-load 
::  - in the +on-load, we recursively run nexus +on-loads in a top-down manner,
::    accumulating effects
::  - +on-load assumes all processes are being restarted
::  - we generate the process for every leaf node (file) and run it with ~,
::    accumulating effects
::
++  nexus
  $_  ^|
  |%
  :: top-down reconsideration of directory structure in +on-load
  ::
  ++  on-load
    |~  [bowl ball]
    *[(list dart) ball]
  :: all pokes result in file/directory creation/deletion
  ::
  ++  on-poke
    |~  [bowl cage]
    *[(list dart) path (unit ball)]
  :: all files have an associated running process
  :: all running processes should be able to recover proper
  ::   operation based on state alone, even when restarted.
  ::   this is not guaranteed and is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [path mark]
    :: define process separately in /pro? so /mar, /pro and /nex?
    *proc :: *process :: define process corresponding to file
  :: can send effects when the state of a file/process changes
  ::
  ++  on-diff
    |~  [path cage]
    *(list dart)
  :: can send effects when a process has completed
  ::
  ++  on-done
    |~  [path cage ack=(unit tang)]
    *(list dart)
  ::
  ++  on-take
    |~  take=intake:fiber
    *(list dart)
  --
--
