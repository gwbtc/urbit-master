/+  *tarball, server, multipart, html-utils, hu=http-utils, default-agent
/=  x-  /mar/fiber-ack
|%
::
++  fiber
  |%
  +$  pipe
    $:  boar=(unit @ta)          :: who is hogging the pipe
        proc=(map @ta proc)
    ==
  ::
  +$  poke
     $:  =cage    :: actual poke contents
         src=ship :: source ship of poke
         sap=path :: provenance of poke
         fresh=?  :: original poke vs. +on-load reboot from scratch
     ==
  ::
  +$  proc
    $:  =process
        =poke                    :: keep initial poke
        next=(qeu (unit intake)) :: queue of held inputs
        skip=(qeu (unit intake)) :: queue of skipped inputs
    ==
  ::
  +$  intake
    $%  [%bump =cage] :: %fiber-bump
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
    ==
  ::
  +$  input
    $:  pid=@ta          :: fiber id
        =poke            :: the original poke
        =bowl:gall       :: the current bowl
        state=ball       :: state for which we are responsible
        in=(unit intake) :: command/response/data to ingest (null means start)
    ==
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ *ball %done *value]
    $:  cards=(list card) :: allows for %sse card
        state=ball
        $=  next
        $%  [%wait hold=?] :: process intake and optionally claim mutex (boar)
            [%skip hold=?] :: ignore intake and optionally claim mutex
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
        %wait  [%wait hold.next.b-res]
        %skip  [%skip hold.next.b-res]
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
      $%  [%next hold=?]
          [%fail err=tang]
          [%done ~]
      ==
    ::
    ++  take
      =|  cards=(list card) :: effects
      |=  [pid=@ta =bowl:gall state=ball =proc]
      ^-  [(list card) ball _proc result]
      =^  take=(unit intake)  next.proc  ~(get to next.proc)
      |-  :: recursion point so take can be replaced
      =/  res=(each output tang)
        (mule |.((process.proc pid poke.proc bowl state take)))
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
        [%next hold.next.output]
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
        [%next hold.next.output]
      ==
    --
  --
:: HTTP/SSE agent transformer library
::
::    Wraps a Gall agent to handle HTTP requests and SSE connections.
::    Similar to shoe for CLI apps, but for web apps.
::
++  keep-alive  ~s30
++  sse-timeout  ~m2
+$  parts  parts:hu
::  $card: standard gall cards plus SSE effects
::
+$  card
  $%  card:agent:gall
      [%sse site=(list @t) key=(unit sse-key:hu)]
      [%simple-payload payload=simple-payload:http]
  ==
::  +sailbox: gall agent core with extra arms for HTTP/SSE
::
++  sailbox
  $_  ^|
  |%
  ++  on-peek
    |~  [bowl:gall state=ball path]
    *(unit (unit cage))
  ::
  ++  initial  *ball
  ++  migrate  |~(ball *ball)
  ::
  ++  process  *process:fiber
  ::  +make-sse-event: generate SSE event content for a site/event
  ::
  ++  make-sse-event
    |~  $:  =bowl:gall
            state=ball
            site=(list @t)
            args=(list [key=@t value=@t])
            id=(unit @t)
            event=(unit @t)
        ==
    *wain
  ::  +first-sse-event: initial event when SSE connection opens
  ::
  ++  first-sse-event
    |~  $:  site=(list @t)
            args=(list [key=@t value=@t])
            last-event-id=(unit @t)
        ==
    *(unit sse-key:hu)
  --
::
++  grab-part  grab-part:hu
::  +agent: creates wrapper core that handles HTTP/SSE and calls sailbox arms
::
++  agent
  |=  app=sailbox
  ^-  agent:gall
  =>
    |%
    ++  kv  kv:html-utils
    +$  state-0
      $:  %0
          state=ball
          =pipe:fiber
          timers=(map wire @da)
          connections=(map @ta sse-connection:hu)
          requests=(set @ta)
      ==
    --
  =|  state-0
  =*  full-state  -
  ::
  =<
  ::
  |_  =bowl:gall
  +*  this  .
      def   ~(. (default-agent this %|) bowl)
      hc    ~(. +> bowl)
  ::
  ++  on-fail
    |=  [=term =tang]
    ^-  (quip card:agent:gall agent:gall)
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security (never happens)
    %-  (slog leaf+"error in {<dap.bowl>}" >term< tang)
    =^  cards  full-state
      abet:(kill-and-poke:hc %on-fail on-fail+!>([term tang]) %.y)
    [cards this]
  ::
  ++  on-init
    ^-  (quip card:agent:gall agent:gall)
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security (never happens)
    =.  state  initial:app
    =^  cards  full-state
      abet:(kill-and-poke:hc %on-init on-init+!>(~) %.y)
    =/  until=@da  (add now.bowl keep-alive)
    :_  this(timers (~(put by timers) /timer/sse until))
    %+  welp
      cards
    [%pass /timer/sse %arvo %b %wait until]~
  ::
  ++  on-save  !>(full-state)
  ::
  ++  on-load
    |=  old-state=vase
    ^-  (quip card:agent:gall agent:gall)
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security (never happens)
    =.  full-state  !<(state-0 old-state)
    =.  state  (migrate:app state)
    =^  cards  full-state
      abet:handle-on-load:hc
    [cards this]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card:agent:gall agent:gall)
    ?.  ?=(%handle-http-request mark)
      :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security
      ?+    mark  (on-poke:def mark vase)
          %fiber-bump
        =^  cards  full-state
          abet:(take-bump:hc !<([@ta cage] vase))
        [cards this]
        ::
          %fiber-poke
        =+  !<([pid=@ta =cage] vase)
        =^  cards  full-state
          abet:(handle-fiber-poke:hc pid cage %.y)
        [cards this]
        ::
          %fiber-kill
        =^  cards  full-state
          abet:(handle-fiber-kill:hc !<(@ta vase))
        [cards this]
      ==
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    =/  lin=request-line:server  (parse-request-line:server url.request.req)
    ::
    ::  HTTP/1.1 requires Host header - reject if missing (RFC 7230)
    ::
    =/  host-header=(unit @t)  (get-header:http 'host' header-list.request.req)
    ?~  host-header
      ~&  >>>  %missing-host-header
      :_  this
      %+  give-simple-payload:app:server
        eyre-id
      [[400 ~] `(as-octs:mimes:html '400 Bad Request - Missing Host header')]
    =/  host=@t  u.host-header
    ::
    :: ~&  >>  host+host
    :: ~&  >>  origin+(get-header:http 'origin' header-list.request.req)
    :: ~&  >>  referer+(get-header:http 'referer' header-list.request.req)
    :: ~&  >>  accept+(get-header:http 'accept' header-list.request.req)
    :: ~&  >>  connection+(get-header:http 'connection' header-list.request.req)
    :: ~&  >>  last-event-id+(get-header:http 'last-event-id' header-list.request.req)
    :: ~&  >>  range+(get-header:http 'range' header-list.request.req)
    :: ~&  >  "received {(trip method.request.req)} request for {<site.lin>}!"
    :: :: Eyre Security: Check for modern browser with fetch metadata
    :: ::
    :: =/  fetch-mode=(unit @t)  (get-header:http 'sec-fetch-mode' header-list.request.req)
    :: =/  fetch-site=(unit @t)  (get-header:http 'sec-fetch-site' header-list.request.req)
    :: ~&  >>  sec-fetch-mode+fetch-mode
    :: ~&  >>  sec-fetch-site+fetch-site
    ::
    ::  If either header is missing, reject (old/unsupported browser)
    ::
    :: ?:  |(?=(~ fetch-mode) ?=(~ fetch-site))
    ::   ~&  >>>  %security-violation-unsupported-browser
    ::   :_  this
    ::   %+  give-simple-payload:app:server
    ::     eyre-id
    ::   unsupported-browser
    :: ::
    :: ::  Check security policy: allow navigate OR same-origin
    :: ::
    :: ?.  |(?=([~ %navigate] fetch-mode) ?=([~ %same-origin] fetch-site))
    ::   ~&  >>>  %security-violation-cross-origin
    ::   :_  this
    ::   %+  give-simple-payload:app:server
    ::     eyre-id
    ::   (cross-origin-forbidden fetch-mode fetch-site)
    ::
    ?.  (is-sse-request:hu req)
      =.  requests  (~(put in requests) eyre-id)
      =^  cards  full-state
        =+  res=(mule |.(abet:(handle-fiber-poke:hc eyre-id handle-http-request+!>(req) %.y)))
        ?:  ?=(%& -.res)  p.res
        ((slog p.res) (mean p.res)) :: goes to dojo and browser
      [cards this]
    :: ~&  %sse-request
    =/  last-event-id=(unit @t)
      (get-header:http 'last-event-id' header-list.request.req)
    =/  first=(unit sse-key:hu)
      (first-sse-event:app site.lin args.lin last-event-id)
    =/  cards=(list card:agent:gall)
      %+  welp
        ~[(give-sse-header:hu eyre-id)]
      ?~  first
        ~
      :_  ~
      %+  give-sse-event:hu
        eyre-id
      :+  id.u.first  event.u.first
      %:  make-sse-event:app
        bowl
        state
        site.lin
        args.lin
        u.first
      ==
    :-  cards
    %=    this
        connections
      %+  ~(put by connections)
        eyre-id
      [now.bowl site.lin args.lin]
    ==
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card:agent:gall agent:gall)
    ?:  ?=([%http-response *] path)  [~ this]
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security
    ?+    path  (on-watch:def path)
        [%fiber-result @ ~]
      [~ this]
      ::
        [%fiber @ *]
      =^  cards  full-state
        abet:(take-watch:hc path)
      [cards this]
    ==
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card:agent:gall agent:gall)
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security
    ?.  ?=([%fiber @ *] path)
      (on-leave:def path)
    =^  cards  full-state
      abet:(take-leave:hc path)
    [cards this]
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security
    (on-peek:app bowl state path)
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card:agent:gall agent:gall)
    :: ?<  ?=([%eyre *] sap.bowl) :: Eyre Security
    ?.  ?=([%fiber @ *] wire)
      (on-agent:def wire sign)
    =^  cards  full-state
      abet:(take-agent:hc wire sign)
    [cards this]
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card:agent:gall agent:gall)
    :: Eyre Security: we can talk to %eyre and get responses
    ::
    ?+  wire  (on-arvo:def wire sign-arvo)
        [%fiber @ *]
      =^  cards  full-state
        abet:(take-arvo:hc wire sign-arvo)
      [cards this]
      ::
        [%timer %sse ~]
      ?+  sign-arvo  (on-arvo:def wire sign-arvo)
          [%behn %wake *]
        =|  cards=(list card:agent:gall)
        =/  conn=(list [eyre-id=@ta con=sse-connection:hu])
          ~(tap by connections)
        |-
        ?~  conn
          =/  until=@da  (add now.bowl keep-alive)
          :_  this(timers (~(put by timers) /timer/sse until))
          :_(cards [%pass /timer/sse %arvo %b %wait until])
        =.  cards
          :_  cards
          ?:  (gte now.bowl (add started.con.i.conn sse-timeout))
            (kick-eyre-sub:hu eyre-id.i.conn)
          (give-sse-keep-alive:hu eyre-id.i.conn)
        =?  connections  (gte now.bowl (add started.con.i.conn sse-timeout))
          (~(del by connections) eyre-id.i.conn)
        $(conn t.conn)
      ==
    ==
  --
  ::
  =|  cards=(list card:agent:gall)
  |_  =bowl:gall
  +*  this  .
  ++  emit-card   |=(=card:agent:gall this(cards [card cards]))
  ++  emit-cards  |=(cadz=(list card:agent:gall) this(cards (welp (flop cadz) cards)))
  ++  abet        [(flop cards) full-state]
  ++  deal
    |=  [pid=@ta cards=(list card)]
    ^+  this
    ?~  cards
      this
    ?:  ?=(%simple-payload -.i.cards)
      ?.  (~(has in requests) pid)
        ~&  >>>  "ignoring simple-payload for pid not in requests: {(trip pid)}"
        $(cards t.cards)
      =.  requests  (~(del in requests) pid)
      =.  this  (emit-cards (give-simple-payload:app:server pid payload.i.cards))
      $(cards t.cards)
    ?.  ?=(%sse -.i.cards)
      =.  this  (emit-card i.cards)
      $(cards t.cards)
    =/  conns=(list [eyre-id=@ta con=sse-connection:hu])
      ~(tap by connections)
    |-
    ?~  conns
      ^$(cards t.cards)
    ?.  =(site.i.cards site.con.i.conns)
      $(conns t.conns)
    ?~  key.i.cards
      =.  this  (emit-card (kick-eyre-sub:hu eyre-id.i.conns))
      =.  connections  (~(del by connections) eyre-id.i.conns)
      $(conns t.conns)
    =.  this
      %-  emit-card
      %+  give-sse-event:hu
        eyre-id.i.conns
      :+  id.u.key.i.cards
        event.u.key.i.cards
      %:  make-sse-event:app
        bowl
        state
        site.con.i.conns
        args.con.i.conns
        u.key.i.cards
      ==
    $(conns t.conns)
  ::
  ++  make-bowl
    |=  pid=@ta
    ^-  bowl:gall
    =.  wex.bowl
      %-  ~(gas by *boat:gall)
      %+  murn  ~(tap by wex.bowl)
      |=  [[=wire =ship =term] acked=? pat=path]
      ?.  ?=([%base @ *] wire)
        ~
      =/  [f=@ta w=path]  (unwrap-wire wire)
      ?.  =(f pid)
        ~
      [~ [w ship term] acked pat]
    =.  sup.bowl
      %-  ~(gas by *bitt:gall)
      %+  murn  ~(tap by sup.bowl)
      |=  [=duct =ship pat=path]
      ?.  ?=([%base @ *] pat)
        ~
      =/  [f=@ta w=path]  (unwrap-wire pat)
      ?.  =(f pid)
        ~
      [~ duct ship w]
    bowl
  ::
  ++  handle-fiber-poke
    |=  [pid=@ta =cage fresh=?]
    ^+  this
    ?<  (~(has by proc.pipe) pid)
    =/  =proc:fiber  [process:app [cage src.bowl sap.bowl fresh] ~ ~]
    =.  proc.pipe  (~(put by proc.pipe) pid proc)
    (process-take pid ~)
  ::
  ++  handle-fiber-kill
    |=  pid=@ta
    ^+  this
    =.  proc.pipe  (~(del by proc.pipe) pid)
    (fiber-ack pid ~ leaf+"killed" ~)
  ::
  ++  kill-and-poke
    |=  [pid=@ta =cage fresh=?]
    ^+  this
    =?  this  (~(has by proc.pipe) pid)
      (handle-fiber-kill pid)
    (handle-fiber-poke pid cage fresh)
  ::
  ++  fiber-kill-all
    ^+  this
    =/  pids=(list @ta)  ~(tap in ~(key by proc.pipe))
    |-
    ?~  pids
      this
    =.  this  (handle-fiber-kill i.pids)
    $(pids t.pids)
  ::
  ++  reboot-process
    |=  pid=@ta
    ^+  this
    ?~  proc=(~(get by proc.pipe) pid)
      this
    =.  proc.pipe
      %+  ~(put by proc.pipe)
        pid
      [process:app poke.u.proc(fresh %.n) ~ ~]
    (process-take pid ~)
  ::
  ++  reboot-all-processes
    ^+  this
    =/  pids=(list @ta)  ~(tap in ~(key by proc.pipe))
    |-
    ?~  pids
      this
    =.  this  (reboot-process i.pids)
    $(pids t.pids)
  ::
  ++  refresh-timers
    ^+  this
    %-  emit-cards
    %-  zing
    %+  turn  ~(tap by timers)
    |=  [=wire until=@da]
    :~  [%pass /timer/sse %arvo %b %rest until]
        [%pass /timer/sse %arvo %b %wait until]
    ==
  ::
  ++  handle-on-load
    ^+  this
    =.  this  reboot-all-processes
    =.  this  refresh-timers
    (kill-and-poke %on-load on-load+!>(~) %.y)
  ::
  ++  wrap-wire
    |=  [pid=@ta =wire]
    ^+  wire
    (weld /fiber/[pid] wire)
  ::
  ++  unwrap-wire
    |=  =wire
    ^-  [@ta ^wire]
    ?>  ?=([%fiber @ *] wire)
    [i.t.wire t.t.wire]
  ::
  ++  package-card
    |=  [pid=@ta =card]
    ^+  card
    ?+    card  card
        [%give ?(%fact %kick) *]
      =-  card(paths.p -)
      (turn paths.p.card |=(p=path (wrap-wire pid p)))
      ::
        [%pass * *]
      [%pass (wrap-wire pid p.card) q.card]
    ==
  ::
  ++  package-cards
    |=  [pid=@ta cards=(list card)]
    ^+  cards
    ?~  cards
      ~
    :-  (package-card pid i.cards)
    $(cards t.cards)
  ::
  ++  take-bump
    |=  [pid=@ta =cage]
    ^+  this
    (process-take pid ~ %bump cage)
  ::
  ++  take-arvo
    |=  [wir=wire sign=sign-arvo]
    ^+  this
    =/  [pid=@ta =wire]  (unwrap-wire wir)
    (process-take pid ~ %arvo wire sign)
  ::
  ++  take-agent
    |=  [wir=wire =sign:agent:gall]
    ^+  this
    =/  [pid=@ta =wire]  (unwrap-wire wir)
    (process-take pid ~ %agent wire sign)
  ::
  ++  take-watch
    |=  pat=path
    ^+  this
    =/  [pid=@ta =wire]  (unwrap-wire pat)
    (process-take pid ~ %watch wire)
  ::
  ++  take-leave
    |=  pat=path
    ^+  this
    =/  [pid=@ta =wire]  (unwrap-wire pat)
    (process-take pid ~ %leave wire)
  ::
  ++  claim
    |=  pid=@ta
    ^+  this
    ?>  |(=(~ boar.pipe) =([~ pid] boar.pipe))
    this(boar.pipe [~ pid])
  ::
  ++  relinquish
    ^+  this
    =.  boar.pipe  ~
    =/  pids=(list @ta)  ~(tap in ~(key by proc.pipe))
    |-
    ?~  pids
      this
    =.  this  (process-do-next i.pids)
    $(pids t.pids)
  ::
  ++  process-take
    |=  [pid=@ta take=(unit intake:fiber)]
    ^+  this
    ?.  (~(has by proc.pipe) pid)
      ~|("process {(trip pid)} does not exist" !!)
    =/  =proc:fiber  (~(got by proc.pipe) pid)
    =.  next.proc  (~(put to next.proc) take)
    =.  proc.pipe  (~(put by proc.pipe) pid proc)
    (process-do-next pid)
  ::
  ++  process-do-next
    |=  pid=@ta
    ^+  this
    =/  =proc:fiber  (~(got by proc.pipe) pid)
    ?.  |(=(~ boar.pipe) =([~ pid] boar.pipe))
      this
    ?:  =(~ next.proc)
      this
    =+  ^-
      $:  cards=(list card)
          new=ball
          =proc:fiber
          =result:eval:fiber
      ==
      (take:eval:fiber pid (make-bowl pid) state proc)
    =.  proc.pipe  (~(put by proc.pipe) pid proc)
    =.  state  new
    =.  this  (deal pid (package-cards pid cards))
    ?:  ?=(%next -.result)
      ?:  hold.result
        (claim pid)
      relinquish
    =.  proc.pipe  (~(del by proc.pipe) pid)
    =.  this  relinquish
    =?  this  (~(has in requests) pid)
      =/  authorized=?  =(our.bowl src.poke.proc)
      =/  payload=simple-payload:http
        ?-  -.result
          %done  two-oh-four:hu
          %fail  (internal-server-error:hu authorized "fiber crashed" err.result)
        ==
      =.  requests  (~(del in requests) pid)
      (emit-cards (give-simple-payload:app:server pid payload))
    %+  fiber-ack  pid
    ?-  -.result
      %done  ~
        %fail
      %-  (slog leaf+"{(trip dap.bowl)}: crash at {(trip pid)}" err.result)
      [~ err.result]
    ==
  ::
  ++  fiber-ack
    |=  [pid=@ta ack=(unit tang)]
    ^+  this
    %-  emit-cards
    :~  [%give %fact ~[/fiber-result/[pid]] %fiber-ack !>(ack)]
        [%give %kick ~[/fiber-result/[pid]] ~]
    ==
  --
--
