::  claude nexus: AI chat interface
::
/-  claude
/+  nexus, tarball, io=fiberio, server, hu=http-utils, feather, nex-server, html-utils,
    claude-lib=nex-claude, chat-index, tools=nex-tools
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      ::  Create /main file (config as json) if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
        (~(put ba:tarball ball) [/ %main] [~ %json !>(default-config)])
      ::  Create /ui/main file (HTTP dispatcher) if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ui %main]))
        (~(put ba:tarball ball) [/ui %main] [~ %sig !>(~)])
      ::  Create /ui/requests directory if not present
      =?  ball  =(~ (~(get of ball) /ui/requests))
        (~(put of ball) /ui/requests [~ ~ ~])
      ::  Create /chats directory for storing conversations
      =?  ball  =(~ (~(get of ball) /chats))
        (~(put of ball) /chats [~ ~ ~])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main: config holder — receives update pokes
          ::
          [~ %main]
        ;<  ~  bind:m  (rise-wait:io prod "%claude /main: failed, poke to restart")
        |-
        ;<  =cage  bind:m  take-poke:io
        ;<  cfg=json  bind:m  (get-state-as:io ,json)
        ?+    p.cage
          ~&  [%claude %unknown-poke p.cage]
          $
        ::
            %json
          =/  updates=json  !<(json q.cage)
          =/  new=json  (merge-json cfg updates)
          ~&  >  "%claude: config updated"
          ;<  ~  bind:m  (replace:io !>(new))
          $
        ==
          ::  /ui/main: bind paths and dispatch requests
          ::
          [[%ui ~] %main]
        ;<  ~  bind:m  (rise-wait:io prod "%claude /ui/main: failed, poke to restart")
        ~&  >  "%claude /ui/main: binding paths"
        ;<  ~  bind:m  (bind-http:nex-server [~ /mister/claude])
        ;<  ~  bind:m  (bind-http:nex-server [~ /mister/claude/settings])
        ;<  ~  bind:m  (bind-http:nex-server [~ /mister/claude/config])
        ;<  ~  bind:m  (bind-http:nex-server [~ /mister/claude/new])
        ;<  ~  bind:m  (bind-http:nex-server [~ /mister/claude/stream])
        ~&  >  "%claude /ui/main: ready"
        (http-dispatch:nex-server %claude)
          ::  /chats/*: chat data files (state machine, no fiber)
          ::
          [[%chats ~] @]
        chat-file
          ::  /ui/requests/*: individual request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%claude /ui/requests: failed, poke to restart")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  =request-line:server  (parse-request-line:server url.request.req)
        ?+    site.request-line
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
          (pure:m ~)
        ::
            [%mister %claude ~]
          (handle-root-get eyre-id)
        ::
            [%mister %claude %new ~]
          (handle-new-chat eyre-id)
        ::
            [%mister %claude %settings ~]
          ?:  ?=(%'POST' method.request.req)
            (handle-settings-post eyre-id req)
          (handle-settings-get eyre-id)
        ::
            [%mister %claude %config ~]
          ?:  ?=(%'POST' method.request.req)
            (handle-config-post eyre-id req)
          (handle-config-get eyre-id)
        ::
            [%mister %claude %stream @ ~]
          =/  chat-id=@ux  (rash i.t.t.t.site.request-line hex)
          (handle-stream eyre-id chat-id req)
        ::
            [%mister %claude @ %delete ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          (handle-chat-delete eyre-id chat-id)
        ::
            [%mister %claude @ %rename ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          (handle-chat-rename eyre-id chat-id req)
        ::
            [%mister %claude @ %approve-tool @ ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          =/  tool-id=@t  (crip (trip i.t.t.t.site.request-line))
          (handle-approve-tool eyre-id chat-id tool-id)
        ::
            [%mister %claude @ %deny-tool @ ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          =/  tool-id=@t  (crip (trip i.t.t.t.site.request-line))
          (handle-deny-tool eyre-id chat-id tool-id)
        ::
            [%mister %claude @ %always-allow @ ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          =/  tool-name=@t  (crip (trip i.t.t.t.site.request-line))
          (handle-always-allow eyre-id chat-id tool-name)
        ::
            [%mister %claude @ ~]
          =/  chat-id=@ux  (rash i.t.t.site.request-line hex)
          ?:  ?=(%'POST' method.request.req)
            (handle-chat-post eyre-id chat-id req)
          (handle-chat-page eyre-id chat-id)
        ==
      ==
    --
|%
::  Chat data file process (raw state machine, like who-file in peers)
::  On poke with %claude-chat mark: replace state with poke payload.
::
++  chat-file
  |=  =input:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  output:m
  ?+  in.input  [~ state.input %skip ~]
      ~  [~ state.input %wait ~]
      [~ %poke * *]
    ?.  =(%claude-chat p.cage.u.in.input)
      [~ state.input %skip ~]
    [~ q.cage.u.in.input %wait ~]
  ==
::
++  default-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['api-key' s+'']
      ['model' s+'claude-sonnet-4-5-20250929']
      ['timezone' s+'UTC']
  ==
::  Merge two json objects (updates override base)
::
++  merge-json
  |=  [base=json updates=json]
  ^-  json
  ?.  ?=([%o *] base)  updates
  ?.  ?=([%o *] updates)  base
  [%o (~(uni by p.base) p.updates)]
::  HTTP response door (road from /claude/ui/requests/* to /claude/ui/main)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
::  Road from /claude/ui/requests/* to /claude/main
::
++  main-road  `road:tarball`[%| 2 %& ~ %main]
::  Road from /claude/ui/requests/* to a chat file
::
++  chat-road
  |=  chat-id=@ux
  ^-  road:tarball
  [%| 2 %& /chats (crip "{(hexn:hu chat-id)}.claude-chat")]
::  Road from /claude/ui/requests/* to the /chats/ directory
::
++  chats-dir-road  `road:tarball`[%| 2 %| /chats]
::  Get a single chat from tarball
::
++  get-chat
  |=  chat-id=@ux
  =/  m  (fiber:fiber:nexus ,(unit chat:claude))
  ^-  form:m
  ;<  seen=seen:nexus  bind:m  (peek:io /peek (chat-road chat-id))
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  =/  result  (mule |.(!<(chat:claude q.cage.p.seen)))
  ?.  ?=(%& -.result)
    (pure:m ~)
  (pure:m `p.result)
::  Save an existing chat
::
++  put-chat
  |=  [chat-id=@ux =chat:claude]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /poke (chat-road chat-id) claude-chat+!>(chat))
::  Create a new chat file
::
++  create-chat
  |=  [chat-id=@ux =chat:claude]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (make:io /make (chat-road chat-id) |+[%claude-chat !>(chat)])
::  Delete a chat file
::
++  del-chat
  |=  chat-id=@ux
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (cull:io /cull (chat-road chat-id))
::  Build a new empty chat with default params
::
++  new-chat
  |=  [chat-id=@ux =@da]
  ^-  chat:claude
  :*  %3
      chat-id
      'New Chat'
      da
      ::  API parameters (use defaults)
      'claude-sonnet-4-5-20250929'  ::  model
      1.024  ::  max-tokens
      .~1.0  ::  temperature
      .~1.0  ::  top-p
      0      ::  top-k
      ''     ::  system-instructions
      ~      ::  stop-sequences
      ~      ::  tool-choice
      ::  Messages (empty)
      ~      ::  messages-by-time
      ~      ::  messages-by-index
      ~      ::  messages-by-chars
      0      ::  next-index
      0      ::  total-chars
      ::  Branching
      ~      ::  parent
      ~      ::  children
      ::  Runtime state
      ~      ::  api-request-pid
      ~      ::  pending-tools
      ~      ::  allowed-tools
      ::  Agent safety
      ~      ::  max-iterations
      0      ::  iteration-count
  ==
::  Get all chats from the /chats/ directory
::
++  get-all-chats
  =/  m  (fiber:fiber:nexus ,(map @ux chat:claude))
  ^-  form:m
  ;<  seen=seen:nexus  bind:m  (peek:io /chats chats-dir-road)
  ?.  ?=([%& %ball *] seen)
    (pure:m ~)
  =/  filenames=(list @ta)  (~(lis ba:tarball ball.p.seen) /)
  %-  pure:m
  %-  malt
  %+  murn  filenames
  |=  name=@ta
  ^-  (unit [@ux chat:claude])
  =/  name-tape=tape  (trip name)
  =/  ext-tape=tape  ".claude-chat"
  =/  ext-len=@ud  (lent ext-tape)
  =/  name-len=@ud  (lent name-tape)
  ?.  (gte name-len ext-len)  ~
  ?.  =((flop (scag ext-len (flop name-tape))) ext-tape)  ~
  =/  id-tape=tape  (scag (sub name-len ext-len) name-tape)
  =/  parsed-id=(unit @ux)  (rush (crip id-tape) hex)
  ?~  parsed-id  ~
  =/  maybe-content=(unit content:tarball)
    (~(get ba:tarball ball.p.seen) / name)
  ?~  maybe-content  ~
  =/  =cage  cage.u.maybe-content
  ?.  =(p.cage %claude-chat)  ~
  =/  result  (mule |.(!<(chat:claude q.cage)))
  ?.  ?=(%& -.result)  ~
  `[u.parsed-id p.result]
::  Read config by peeking at the claude root ball
::
++  get-config
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  seen=seen:nexus  bind:m  (peek:io /peek [%| 2 %| ~])
  ?.  ?=([%& %ball *] seen)
    (pure:m default-config)
  =/  main-content  (~(get ba:tarball ball.p.seen) [/ %main])
  ?~  main-content
    (pure:m default-config)
  (pure:m !<(json q.cage.u.main-content))
::  Extract a cord from a json object, with fallback
::
++  get-key
  |=  [key=@t fallback=@t cfg=json]
  ^-  @t
  ?.  ?=([%o *] cfg)  fallback
  =/  val  (~(get by p.cfg) key)
  ?~  val  fallback
  ?.  ?=([%s *] u.val)  fallback
  p.u.val
::
++  handle-root-get
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  =/  active-id=(unit @t)
    ?.  ?=([%o *] cfg)  ~
    =/  val  (~(get by p.cfg) 'active-chat')
    ?~  val  ~
    ?.  ?=([%s *] u.val)  ~
    ?:  =('' p.u.val)  ~
    `p.u.val
  ?^  active-id
    =/  redirect=@t  (crip "/mister/claude/{(trip u.active-id)}")
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' redirect]]] ~])
    (pure:m ~)
  ::  No active chat — show welcome page
  =/  model=@t  (get-key 'model' 'claude-sonnet-4-5-20250929' cfg)
  ;<  all-chats=(map @ux chat:claude)  bind:m  get-all-chats
  =/  bod=octs  (manx-to-octs:server (welcome-page (trip model) all-chats))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/text/html bod]))
  (pure:m ~)
::
++  handle-new-chat
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  chat-id=@ux  `@ux`(sham eny.bowl)
  =/  =chat:claude  (new-chat chat-id now.bowl)
  ;<  ~  bind:m  (create-chat chat-id chat)
  =/  id-text=tape  (hexn:hu chat-id)
  ;<  ~  bind:m
    =/  updates=json
      %-  pairs:enjs:format
      ~[['active-chat' s+(crip id-text)]]
    (poke:io /config main-road json+!>(updates))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[303 ~[['location' (crip "/mister/claude/{id-text}")]]] ~])
  (pure:m ~)
::
++  handle-chat-delete
  |=  [eyre-id=@ta chat-id=@ux]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  ::  Check if this is the active chat
  =/  active-text=@t  (get-key 'active-chat' '' cfg)
  =/  active-id=(unit @ux)
    ?:  =('' active-text)  ~
    (rush active-text hex)
  =/  was-active=?  =(`chat-id active-id)
  ::  Delete the chat file
  ;<  ~  bind:m  (del-chat chat-id)
  ::  Clear active-chat if it was the deleted one
  ?:  was-active
    ;<  ~  bind:m
      (poke:io /config main-road json+!>((pairs:enjs:format ~[['active-chat' s+'']])))
    =/  res=octs  (as-octs:mimes:html 'OK')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `res])
    (pure:m ~)
  =/  res=octs  (as-octs:mimes:html 'OK')
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `res])
  (pure:m ~)
::
++  handle-chat-rename
  |=  [eyre-id=@ta chat-id=@ux req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=@t  q:(need body.request.req)
  =/  req-json=json  (need (de:json:html bod))
  =/  new-name=@t
    ?.  ?=([%o *] req-json)  ''
    =/  val  (~(get by p.req-json) 'name')
    ?~  val  ''
    ?.  ?=([%s *] u.val)  ''
    p.u.val
  ?:  =('' new-name)
    =/  err=octs  (as-octs:mimes:html 'Missing name')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `err])
    (pure:m ~)
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    =/  err=octs  (as-octs:mimes:html 'Chat not found')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `err])
    (pure:m ~)
  =.  name.u.maybe-chat  new-name
  ;<  ~  bind:m  (put-chat chat-id u.maybe-chat)
  =/  res=octs  (as-octs:mimes:html 'OK')
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `res])
  (pure:m ~)
::  SSE stream: subscribe to chat file and push updates
::
++  handle-stream
  |=  [eyre-id=@ta chat-id=@ux req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:hu req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:hu)
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat  (pure:m ~)
  =/  chat-id-text=tape  (hexn:hu chat-id)
  =/  prev-next-index=@ud  next-index.u.maybe-chat
  =/  prev-pid=(unit @ta)  api-request-pid.u.maybe-chat
  =/  prev-pending=?  ?=(^ pending-tools.u.maybe-chat)
  ;<  ~  bind:m  (keep:io /chat (chat-road chat-id))
  ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
  ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /chat)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:hu)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    $
      %news
    ?.  ?=([%file *] view.nw)  $
    =/  =cage  cage.view.nw
    ?.  =(p.cage %claude-chat)  $
    =/  result  (mule |.(!<(chat:claude q.cage)))
    ?.  ?=(%& -.result)  $
    =/  =chat:claude  p.result
    =/  old-next-index=@ud  prev-next-index
    =/  has-new=?  (gth next-index.chat old-next-index)
    =/  pid-changed=?  !=(api-request-pid.chat prev-pid)
    =/  pending-changed=?  !=(?=(^ pending-tools.chat) prev-pending)
    ::  Update tracking state before processing
    =.  prev-next-index  next-index.chat
    =.  prev-pid  api-request-pid.chat
    =.  prev-pending  ?=(^ pending-tools.chat)
    ::  Send tool-approval event if pending state changed
    =*  send-tool-approval
      ?.  pending-changed  (pure:m ~)
      =/  input-html=manx
        ?^  pending-tools.chat
          (render-approval-bar u.pending-tools.chat chat-id-text)
        ;form#chat-form
          ;textarea#prompt(rows "1", placeholder "Send a message...");
          ;button#send-btn(type "submit"): Send
        ==
      =/  html-wain=wain  (manx-to-wain:hu input-html)
      =/  =sse-event:hu  [~ `%tool-approval html-wain]
      =/  data=octs  (sse-encode:hu ~[sse-event])
      (send-data:srv eyre-id `data)
    ?.  has-new
      ::  No new messages — check for state/tool change
      ?.  &(pid-changed pending-changed)
        ?:  pid-changed
          =/  state-json=@t
            %-  en:json:html
            %-  pairs:enjs:format
            ~[['thinking' b+?=(^ api-request-pid.chat)]]
          =/  =sse-event:hu  [~ `%state-update ~[state-json]]
          =/  data=octs  (sse-encode:hu ~[sse-event])
          ;<  ~  bind:m  (send-data:srv eyre-id `data)
          $
        ?:  pending-changed
          ;<  ~  bind:m  send-tool-approval
          $
        $
      ::  Both changed
      =/  state-json=@t
        %-  en:json:html
        %-  pairs:enjs:format
        ~[['thinking' b+?=(^ api-request-pid.chat)]]
      =/  =sse-event:hu  [~ `%state-update ~[state-json]]
      =/  data=octs  (sse-encode:hu ~[sse-event])
      ;<  ~  bind:m  (send-data:srv eyre-id `data)
      ;<  ~  bind:m  send-tool-approval
      $
    ::  New messages — send each as HTML
    =/  lower=(unit @ud)
      ?:(=(0 old-next-index) ~ `(dec old-next-index))
    =/  new-msgs=(list [@ud message:claude])
      %-  tap:((on @ud message:claude) lth)
      %+  lot:((on @ud message:claude) lth)
      messages-by-index.chat
      [lower `next-index.chat]
    |-
    ?~  new-msgs
      ::  After messages, send state-update and tool-approval if changed
      ?.  pid-changed
        ?.  pending-changed  ^$
        ;<  ~  bind:m  send-tool-approval
        ^$
      =/  state-json=@t
        %-  en:json:html
        %-  pairs:enjs:format
        ~[['thinking' b+?=(^ api-request-pid.chat)]]
      =/  =sse-event:hu  [~ `%state-update ~[state-json]]
      =/  data=octs  (sse-encode:hu ~[sse-event])
      ;<  ~  bind:m  (send-data:srv eyre-id `data)
      ?.  pending-changed  ^$
      ;<  ~  bind:m  send-tool-approval
      ^$
    =/  [idx=@ud msg=message:claude]  i.new-msgs
    =/  html-wain=wain  (manx-to-wain:hu (render-message msg))
    =/  =sse-event:hu  [~ `%message-update html-wain]
    =/  data=octs  (sse-encode:hu ~[sse-event])
    ;<  ~  bind:m  (send-data:srv eyre-id `data)
    $(new-msgs t.new-msgs)
  ==
::
++  handle-chat-page
  |=  [eyre-id=@ta chat-id=@ux]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Chat not found')])
    (pure:m ~)
  =/  =chat:claude  u.maybe-chat
  ;<  all-chats=(map @ux chat:claude)  bind:m  get-all-chats
  ::  Save as active chat
  ;<  ~  bind:m
    =/  updates=json
      %-  pairs:enjs:format
      ~[['active-chat' s+(crip (hexn:hu chat-id))]]
    (poke:io /config main-road json+!>(updates))
  =/  bod=octs  (manx-to-octs:server (chat-page cfg chat-id chat all-chats))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/text/html bod]))
  (pure:m ~)
::
++  handle-settings-get
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  =/  bod=octs  (manx-to-octs:server (settings-page cfg))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/text/html bod]))
  (pure:m ~)
::
++  handle-settings-post
  |=  [eyre-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
  =/  api-key=(unit @t)  (get-key:kv:html-utils 'api-key' args)
  =/  mdl=(unit @t)  (get-key:kv:html-utils 'model' args)
  =/  updates=json
    %-  pairs:enjs:format
    %+  murn  ~[['api-key' api-key] ['model' mdl]]
    |=  [key=@t val=(unit @t)]
    ?~  val  ~
    ?:  =('' u.val)  ~
    `[key s+u.val]
  ;<  ~  bind:m  (poke:io /config main-road json+!>(updates))
  ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' '/mister/claude/settings']]] ~])
  (pure:m ~)
::
++  handle-config-get
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  =/  bod=octs  (as-octs:mimes:html (en:json:html cfg))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json bod]))
  (pure:m ~)
::
++  handle-config-post
  |=  [eyre-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=@t  q:(need body.request.req)
  =/  updates=json  (need (de:json:html bod))
  ;<  ~  bind:m  (poke:io /config main-road json+!>(updates))
  =/  res=octs  (as-octs:mimes:html (en:json:html [%o (malt ~[['ok' b+&]])]))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json res]))
  (pure:m ~)
::
++  handle-chat-post
  |=  [eyre-id=@ta chat-id=@ux req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  =/  api-key=@t  (get-key 'api-key' '' cfg)
  =/  model=@t  (get-key 'model' 'claude-sonnet-4-5-20250929' cfg)
  =/  user-tz=@t  (get-key 'timezone' 'UTC' cfg)
  ?:  =('' api-key)
    =/  err  (as-octs:mimes:html (en:json:html [%o (malt ~[['error' s+'API key not configured']])]))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json err]))
    (pure:m ~)
  ::  Parse prompt from request body
  =/  bod=@t  q:(need body.request.req)
  =/  req-json=json  (need (de:json:html bod))
  =/  prompt=@t
    ?.  ?=([%o *] req-json)  ''
    =/  val  (~(get by p.req-json) 'prompt')
    ?~  val  ''
    ?.  ?=([%s *] u.val)  ''
    p.u.val
  ?:  =('' prompt)
    =/  err  (as-octs:mimes:html (en:json:html [%o (malt ~[['error' s+'Missing prompt']])]))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json err]))
    (pure:m ~)
  ::  Load the chat
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    =/  err  (as-octs:mimes:html (en:json:html [%o (malt ~[['error' s+'Chat not found']])]))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json err]))
    (pure:m ~)
  =/  =chat:claude  u.maybe-chat
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  ::  Override model from config
  =.  model.chat  model
  ::  Build user message
  =/  user-content=json
    :-  %a
    :~  %-  pairs:enjs:format
        :~  ['type' s+'text']
            ['text' s+prompt]
        ==
    ==
  =/  user-timestamp=@ud  (unm:chrono:userlib now.bowl)
  =/  user-msg=message:claude
    ['user' user-content %normal chat-id 0 0 0 0]
  ::  Add user message to chat
  =/  updated-chat=chat:claude
    (add-message:chat-index chat user-timestamp user-msg)
  ::  Set thinking flag and save (SSE pushes user message + thinking state)
  =.  api-request-pid.updated-chat  `eyre-id
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ::  Call Claude with full context
  ~&  >  "%claude: sending message to chat {(scow %ux chat-id)}"
  ;<  [response=@t final-chat=chat:claude]  bind:m
    (send-message:claude-lib api-key model updated-chat ~ user-tz)
  ::  Clear thinking flag and save (SSE pushes assistant message + thinking off)
  =.  api-request-pid.final-chat  ~
  ;<  ~  bind:m  (put-chat chat-id final-chat)
  ~&  >  "%claude: saved chat {(scow %ux chat-id)}"
  ::  Return success (SSE handles message display)
  =/  res=octs  (as-octs:mimes:html (en:json:html [%o (malt ~[['ok' b+&]])]))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:hu [/application/json res]))
  (pure:m ~)
::
++  handle-approve-tool
  |=  [eyre-id=@ta chat-id=@ux tool-id=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Chat not found')])
    (pure:m ~)
  ?~  pending-tools.u.maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'No pending tools')])
    (pure:m ~)
  =/  =chat:claude  u.maybe-chat
  =/  pts=pending-tools-state:claude  u.pending-tools.u.maybe-chat
  ::  Find tool in pending list
  =/  tool-idx=(unit @ud)
    =/  idx=@ud  0
    =/  pend=(list tool-request:claude)  pending.pts
    |-  ^-  (unit @ud)
    ?~  pend  ~
    ?:  =(tool-id id.i.pend)  `idx
    $(pend t.pend, idx +(idx))
  ?~  tool-idx
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Tool not found')])
    (pure:m ~)
  =/  approved-tool=tool-request:claude  (snag u.tool-idx pending.pts)
  =/  remaining=(list tool-request:claude)  (oust [u.tool-idx 1] pending.pts)
  ::  Update pending state immediately (SSE will push UI update)
  =.  pending.pts  remaining
  =.  pending-tools.chat  `pts
  ;<  ~  bind:m  (put-chat chat-id chat)
  ::  Execute the tool
  =/  tool-core=(unit tool:tools)  (~(get by built-ins:tools) name.approved-tool)
  ?~  tool-core
    ::  Unknown tool — build error result
    =/  tr=tool-result:claude  [approved-tool [%error (crip "Unknown tool '{(trip name.approved-tool)}'")]]
    =/  updated-approved=(list tool-result:claude)  (snoc approved.pts tr)
    ?.  =(~ remaining)
      =.  approved.pts  updated-approved
      =.  pending-tools.chat  `pts
      ;<  ~  bind:m  (put-chat chat-id chat)
      =/  res=octs  (as-octs:mimes:html 'OK')
      ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `res])
      (pure:m ~)
    (finish-tool-execution eyre-id chat-id chat pts updated-approved)
  =/  args=(map @t json)
    ?.  ?=([%o *] input.approved-tool)  ~
    p.input.approved-tool
  ;<  =tool-result:tools  bind:m  (handler:u.tool-core args)
  =/  tr=tool-result:claude
    ?-  -.tool-result
      %text   [approved-tool [%success text.tool-result]]
      %error  [approved-tool [%error message.tool-result]]
    ==
  ~&  >  "%claude: tool '{(trip name.approved-tool)}' done"
  =/  updated-approved=(list tool-result:claude)  (snoc approved.pts tr)
  ::  If more pending, just respond OK — user approves next
  ?.  =(~ remaining)
    =.  approved.pts  updated-approved
    =.  pending-tools.chat  `pts
    ;<  ~  bind:m  (put-chat chat-id chat)
    =/  res=octs  (as-octs:mimes:html 'OK')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `res])
    (pure:m ~)
  ::  All approved — send results back to Claude
  (finish-tool-execution eyre-id chat-id chat pts updated-approved)
::
++  handle-deny-tool
  |=  [eyre-id=@ta chat-id=@ux tool-id=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Chat not found')])
    (pure:m ~)
  ?~  pending-tools.u.maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'No pending tools')])
    (pure:m ~)
  =/  =chat:claude  u.maybe-chat
  =/  pts=pending-tools-state:claude  u.pending-tools.u.maybe-chat
  ::  Find tool in pending list
  =/  tool-idx=(unit @ud)
    =/  idx=@ud  0
    =/  pend=(list tool-request:claude)  pending.pts
    |-  ^-  (unit @ud)
    ?~  pend  ~
    ?:  =(tool-id id.i.pend)  `idx
    $(pend t.pend, idx +(idx))
  ?~  tool-idx
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Tool not found')])
    (pure:m ~)
  =/  denied-tool=tool-request:claude  (snag u.tool-idx pending.pts)
  =/  remaining=(list tool-request:claude)  (oust [u.tool-idx 1] pending.pts)
  =.  pending.pts  remaining
  ::  Build denial result
  =/  tr=tool-result:claude  [denied-tool [%error 'Tool use denied by user']]
  =/  updated-approved=(list tool-result:claude)  (snoc approved.pts tr)
  ?.  =(~ remaining)
    =.  approved.pts  updated-approved
    =.  pending-tools.chat  `pts
    ;<  ~  bind:m  (put-chat chat-id chat)
    =/  res=octs  (as-octs:mimes:html 'OK')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `res])
    (pure:m ~)
  (finish-tool-execution eyre-id chat-id chat pts updated-approved)
::
++  handle-always-allow
  |=  [eyre-id=@ta chat-id=@ux tool-name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  maybe-chat=(unit chat:claude)  bind:m  (get-chat chat-id)
  ?~  maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Chat not found')])
    (pure:m ~)
  ?~  pending-tools.u.maybe-chat
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'No pending tools')])
    (pure:m ~)
  ::  Add to allowed-tools set
  =/  =chat:claude  u.maybe-chat
  =.  allowed-tools.chat  (~(put in allowed-tools.chat) tool-name)
  ;<  ~  bind:m  (put-chat chat-id chat)
  ::  Find and approve the matching pending tool
  =/  pts=pending-tools-state:claude  u.pending-tools.u.maybe-chat
  =/  matching=(unit tool-request:claude)
    =/  pend=(list tool-request:claude)  pending.pts
    |-  ^-  (unit tool-request:claude)
    ?~  pend  ~
    ?:  =(tool-name name.i.pend)  `i.pend
    $(pend t.pend)
  ?~  matching
    =/  res=octs  (as-octs:mimes:html 'OK')
    ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `res])
    (pure:m ~)
  (handle-approve-tool eyre-id chat-id id.u.matching)
::  Finish tool execution: all tools approved/denied, send results to Claude
::
++  finish-tool-execution
  |=  [eyre-id=@ta chat-id=@ux =chat:claude pts=pending-tools-state:claude results=(list tool-result:claude)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  get-config
  =/  api-key=@t  (get-key 'api-key' '' cfg)
  =/  model=@t  (get-key 'model' 'claude-sonnet-4-5-20250929' cfg)
  =/  user-tz=@t  (get-key 'timezone' 'UTC' cfg)
  ::  Build tool_result user message
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  last-timestamp=@ud
    =/  all-ts=(list @ud)
      (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
    ?~  all-ts  (unm:chrono:userlib now.bowl)
    (add (snag 0 (flop all-ts)) 1)
  =/  results-json=(list json)
    %+  turn  results
    |=  tr=tool-result:claude
    =/  content-text=@t
      ?-  -.result.tr
        %success  text.result.tr
        %error    message.result.tr
      ==
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+id.request.tr]
        ['content' s+content-text]
    ==
  =/  result-content=json  [%a results-json]
  =/  user-msg=message:claude  ['user' result-content %normal id.chat 0 0 0 0]
  =.  iteration-count.chat  +(iteration-count.chat)
  =/  updated-chat=chat:claude
    (add-message:chat-index chat last-timestamp user-msg)
  ::  Clear pending tools, set thinking flag
  =.  pending-tools.updated-chat  ~
  =.  api-request-pid.updated-chat  `eyre-id
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ::  Call Claude again with tool results
  ;<  [response=@t final-chat=chat:claude]  bind:m
    (send-message:claude-lib api-key model updated-chat ~ user-tz)
  =.  api-request-pid.final-chat  ~
  ;<  ~  bind:m  (put-chat chat-id final-chat)
  =/  res=octs  (as-octs:mimes:html 'OK')
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `res])
  (pure:m ~)
::
::  Parse content JSON into typed blocks [type text]
::
++  content-blocks
  |=  content=json
  ^-  (list [type=@t text=tape])
  ?+  -.content  ~[['text' ""]]
    %s  ~[['text' (trip p.content)]]
    %a
      %+  turn  p.content
      |=  block=json
      ^-  [type=@t text=tape]
      ?.  ?=([%o *] block)  ['text' ""]
      =/  typ=(unit json)  (~(get by p.block) 'type')
      ?~  typ  ['text' ""]
      ?.  ?=([%s *] u.typ)  ['text' ""]
      ?:  =(p.u.typ 'tool_use')
        =/  name=(unit json)  (~(get by p.block) 'name')
        =/  tname=tape
          ?~  name  "unknown"
          ?.  ?=([%s *] u.name)  "unknown"
          (trip p.u.name)
        ['tool_use' "[using tool: {tname}]"]
      ?:  =(p.u.typ 'tool_result')
        =/  ctn=(unit json)  (~(get by p.block) 'content')
        =/  txt=tape
          ?~  ctn  ""
          ?.  ?=([%s *] u.ctn)  ""
          (trip p.u.ctn)
        ['tool_result' txt]
      =/  txt=(unit json)  (~(get by p.block) 'text')
      ?~  txt  [p.u.typ ""]
      ?.  ?=([%s *] u.txt)  [p.u.typ ""]
      ['text' (trip p.u.txt)]
  ==
::  Extract only text from content blocks
::
++  text-only
  |=  blocks=(list [type=@t text=tape])
  ^-  tape
  %-  zing
  %+  murn  blocks
  |=  [type=@t text=tape]
  ^-  (unit tape)
  ?.  =(type 'text')  ~
  `text
::  Render a single message as HTML (used for SSE events and page render)
::
++  render-message
  |=  msg=message:claude
  ^-  manx
  ?:  =(%error type.msg)
    =/  txt=tape  (text-only (content-blocks content.msg))
    ;div.msg.msg-error
      ;div.markdown-content: {txt}
    ==
  =/  blocks=(list [type=@t text=tape])  (content-blocks content.msg)
  ?:  =(role.msg 'user')
    ::  Check if tool_result message
    =/  has-tool-result=?
      (lien blocks |=([type=@t text=tape] =(type 'tool_result')))
    ?:  has-tool-result
      ;div.msg.msg-tool-result
        ;*  %+  turn  blocks
            |=  [type=@t text=tape]
            ^-  manx
            ?:  =(type 'tool_result')
              ;div.tool-result-text: {text}
            ;div: {text}
      ==
    ;div.msg.msg-user: {(text-only blocks)}
  ::  Assistant — may have tool_use blocks
  =/  has-tool-use=?
    (lien blocks |=([type=@t text=tape] =(type 'tool_use')))
  ?.  has-tool-use
    ;div.msg.msg-assistant
      ;div.markdown-content: {(text-only blocks)}
    ==
  ;div.msg.msg-assistant
    ;*  %+  turn  blocks
        |=  [type=@t text=tape]
        ^-  manx
        ?:  =(type 'tool_use')
          ;div.tool-use-block: {text}
        ;div.markdown-content: {text}
  ==
::  Tool approval bar — replaces input form when tools are pending
::
++  render-approval-bar
  |=  [pts=pending-tools-state:claude chat-id-text=tape]
  ^-  manx
  =/  pending-count=@ud  (lent pending.pts)
  ?:  =(0 pending-count)
    ;div.approval-bar
      ;div.approval-info: Processing tools...
    ==
  =/  first=tool-request:claude  (snag 0 pending.pts)
  =/  tname=tape  (trip name.first)
  =/  tid=tape  (trip id.first)
  ;div.approval-bar
    ;div.approval-info
      ;div.approval-title: Claude wants to use a tool
      ;div.approval-detail: {tname} ({(a-co:co pending-count)} pending)
    ==
    ;div.approval-actions
      ;div.tool-name-badge: {tname}
      ;button.btn-approve(onclick "approveTool('{tid}')"):  Approve
      ;button.btn-deny(onclick "denyTool('{tid}')"):  Deny
      ;button.btn-allow(onclick "alwaysAllowTool('{tname}')"):  Always Allow
    ==
  ==
::  Sidebar component: chat list with edit/delete buttons
::
++  render-sidebar
  |=  [chat-list=(list [@ux chat:claude]) active-id=(unit @ux) model-display=tape]
  ^-  manx
  ;div#sidebar.b1
    ;div#sidebar-head
      ;div.fr.jb.ac
        ;h2.s2: Mister Claude
        ;a.f3.s-1(href "/mister/claude/settings"): settings
      ==
      ;p.f3.s-1.mt-1: {model-display}
    ==
    ;div.p2
      ;a.chat-item.fr.ac.g1(href "/mister/claude/new")
        ;span.f3: + New Chat
      ==
    ==
    ;div(style "display: flex; flex-direction: column; gap: 0.5rem; padding: 8px;")
      ;*  %+  turn  chat-list
          |=  [cid=@ux ch=chat:claude]
          ^-  manx
          =/  id-text=tape  (hexn:hu cid)
          =/  is-active=?  ?~(active-id | =(cid u.active-id))
          =/  bg-style=tape
            ?:  is-active  "background: var(--b2);"
            "background: var(--b0);"
          =/  cname=tape  (trip name.ch)
          =/  escaped-name=tape
            %-  zing
            %+  turn  cname
            |=  c=@tD
            ?:  =(c '\'')  ~['\\' '\'']
            ~[c]
          ;div(style "display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem; {bg-style} border-radius: 6px; border: 1px solid var(--b2);")
            ;a(href "/mister/claude/{id-text}", title "{cname}", style "flex: 1; text-decoration: none; color: var(--f0); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 0.9rem;")
              ; {cname}
            ==
            ;button(onclick "editChat('{id-text}', '{escaped-name}')", style "background: none; border: none; padding: 0.25rem; cursor: pointer; color: var(--f0); opacity: 0.6; display: flex; align-items: center;", onmouseover "this.style.opacity='1'", onmouseout "this.style.opacity='0.6'")
              ;svg(xmlns "http://www.w3.org/2000/svg", width "16", height "16", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
                ;path(d "M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7");
                ;path(d "M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z");
              ==
            ==
            ;button(onclick "deleteChat('{id-text}', '{escaped-name}')", style "background: none; border: none; padding: 0.25rem; cursor: pointer; color: var(--red, #e55); opacity: 0.6; display: flex; align-items: center;", onmouseover "this.style.opacity='1'", onmouseout "this.style.opacity='0.6'")
              ;svg(xmlns "http://www.w3.org/2000/svg", width "16", height "16", viewBox "0 0 24 24", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
                ;polyline(points "3 6 5 6 21 6");
                ;path(d "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2");
              ==
            ==
          ==
    ==
  ==
::  Sidebar JS: delete and rename functions (include in pages with sidebar)
::
++  sidebar-js
  ^-  tape
  """
  function deleteChat(id, name) \{
    if (confirm('Delete "' + name + '"? Cannot be undone.')) \{
      fetch('/mister/claude/' + id + '/delete', \{ method: 'POST' })
      .then(function(r) \{
        if (r.ok) \{
          if (location.pathname.includes(id)) \{
            location.href = '/mister/claude';
          } else \{
            location.reload();
          }
        } else \{
          alert('Failed to delete chat');
        }
      });
    }
  }
  function editChat(id, name) \{
    var newName = prompt('Rename chat:', name);
    if (newName && newName !== name) \{
      fetch('/mister/claude/' + id + '/rename', \{
        method: 'POST',
        headers: \{'Content-Type': 'application/json'},
        body: JSON.stringify(\{name: newName})
      })
      .then(function(r) \{
        if (r.ok) \{ location.reload(); }
        else \{ alert('Failed to rename chat'); }
      });
    }
  }
  """
::  Common sidebar CSS
::
++  sidebar-css
  ^-  tape
  """
  html, body \{ height: 100%; overflow: hidden; }
  #layout \{ display: flex; height: 100vh; }
  #sidebar \{ width: 280px; flex-shrink: 0; display: flex;
              flex-direction: column; border-right: 1px solid var(--b3); }
  #sidebar-head \{ padding: 16px; border-bottom: 1px solid var(--b3); }
  #main \{ flex: 1; display: flex; flex-direction: column;
           min-width: 0; }
  .chat-item \{ padding: 8px 12px; border-radius: 6px;
                cursor: pointer; }
  .chat-item:hover \{ background: var(--b2); }
  """
::  Welcome page: shown when no active chat
::
++  welcome-page
  |=  [model-display=tape all-chats=(map @ux chat:claude)]
  ^-  manx
  =/  chat-list=(list [@ux chat:claude])  ~(tap by all-chats)
  =.  chat-list
    %+  sort  chat-list
    |=  [a=[@ux chat:claude] b=[@ux chat:claude]]
    (gth created.+.a created.+.b)
  ;html
    ;head
      ;title: Mister Claude
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", href "data:,");
      ;+  feather:feather
      ;style
        ;+  ;/  %-  trip
        %-  crip
        ;:  weld
          sidebar-css
          """
          .welcome \{ flex: 1; display: flex; flex-direction: column;
                      align-items: center; justify-content: center; gap: 1rem; }
          .new-chat-btn \{ padding: 12px 24px; background: var(--f0);
                           color: var(--b0); border-radius: 8px;
                           text-decoration: none; font-size: 1rem; }
          .new-chat-btn:hover \{ opacity: 0.8; }
          """
        ==
      ==
    ==
    ;body
      ;div#layout
        ;+  (render-sidebar chat-list ~ model-display)
        ;div#main
          ;div.welcome
            ;h1.s3.f3: Start a conversation
            ;a.new-chat-btn(href "/mister/claude/new"): New Chat
          ==
        ==
      ==
      ;script
        ;+  ;/  sidebar-js
      ==
    ==
  ==
::
++  chat-page
  |=  [cfg=json active-id=@ux =chat:claude all-chats=(map @ux chat:claude)]
  ^-  manx
  =/  model=@t  (get-key 'model' 'claude-sonnet-4-5-20250929' cfg)
  =/  model-display=tape  (trip model)
  =/  server-tz=tape  (trip (get-key 'timezone' 'UTC' cfg))
  =/  chat-id-text=tape  (hexn:hu active-id)
  =/  chat-name=tape  (trip name.chat)
  ::  Build sorted chat list (newest first)
  =/  chat-list=(list [@ux chat:claude])  ~(tap by all-chats)
  =.  chat-list
    %+  sort  chat-list
    |=  [a=[@ux chat:claude] b=[@ux chat:claude]]
    (gth created.+.a created.+.b)
  ::  Get messages in order
  =/  msg-list=(list [@ud message:claude])
    (tap:((on @ud message:claude) lth) messages-by-index.chat)
  ;html
    ;head
      ;title: Mister Claude
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", href "data:,");
      ;+  feather:feather
      ;script(src "https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js");
      ;style
        ;+  ;/  %-  trip
        %-  crip
        ;:  weld
          sidebar-css
          """
          #header \{ padding: 16px 24px; border-bottom: 1px solid var(--b3); }
          #messages \{ flex: 1; overflow-y: auto; padding: 24px;
                       display: flex; flex-direction: column; gap: 16px; }
          .msg \{ max-width: 80%; padding: 12px 16px; border-radius: 12px;
                  line-height: 1.5; }
          .msg-user \{ align-self: flex-end; background: var(--b-4);
                       color: #fff; }
          .msg-assistant \{ align-self: flex-start; background: var(--b1); }
          .msg-assistant .markdown-content \{ line-height: 1.6; }
          .msg-assistant .markdown-content p \{ margin: 0.5rem 0; }
          .msg-assistant .markdown-content p:first-child \{ margin-top: 0; }
          .msg-assistant .markdown-content p:last-child \{ margin-bottom: 0; }
          .msg-assistant .markdown-content ul,
          .msg-assistant .markdown-content ol \{ margin: 0.5rem 0; padding-left: 1.5rem; }
          .msg-assistant .markdown-content li \{ margin: 0.25rem 0; }
          .msg-assistant .markdown-content strong \{ font-weight: bold; }
          .msg-assistant .markdown-content em \{ font-style: italic; }
          .msg-assistant .markdown-content code \{ background: var(--b2);
                  padding: 0.125rem 0.25rem; border-radius: 3px;
                  font-family: monospace; font-size: 0.9em; }
          .msg-assistant .markdown-content pre \{ background: var(--b2);
                  padding: 0.75rem; border-radius: 6px;
                  overflow-x: auto; margin: 0.5rem 0; }
          .msg-assistant .markdown-content pre code \{ background: none; padding: 0; }
          .msg-assistant .markdown-content h1,
          .msg-assistant .markdown-content h2,
          .msg-assistant .markdown-content h3 \{ margin: 1rem 0 0.5rem 0; font-weight: bold; }
          .msg-assistant .markdown-content h1 \{ font-size: 1.5em; }
          .msg-assistant .markdown-content h2 \{ font-size: 1.3em; }
          .msg-assistant .markdown-content h3 \{ font-size: 1.1em; }
          .msg-error \{ align-self: center; background: var(--b-1);
                        color: #fff; font-size: 0.9em; }
          #thinking \{ padding: 8px 24px; color: var(--f3);
                       font-style: italic; display: none; }
          #input-area \{ padding: 16px 24px; border-top: 1px solid var(--b3); }
          #chat-form \{ display: flex; gap: 8px; align-items: flex-end; }
          #prompt \{ flex: 1; resize: none; min-height: 44px;
                     max-height: 200px; padding: 10px 14px;
                     border: 1px solid var(--b3); border-radius: 8px;
                     font-size: 1rem; line-height: 1.4;
                     background: var(--b0); color: var(--f0);
                     font-family: inherit; }
          #send-btn \{ padding: 10px 16px; border-radius: 8px;
                       background: var(--f0); color: var(--b0);
                       cursor: pointer; font-size: 1rem;
                       border: none; flex-shrink: 0; }
          #send-btn:hover \{ opacity: 0.8; }
          #send-btn:disabled \{ opacity: 0.4; cursor: default; }
          .tool-use-block \{ background: var(--b2); font-style: italic;
                             opacity: 0.8; font-size: 0.9rem; padding: 8px 12px;
                             border-radius: 6px; margin: 4px 0; }
          .msg-tool-result \{ align-self: flex-start; max-width: 80%;
                              padding: 8px 12px; font-size: 0.85rem;
                              opacity: 0.7; }
          .tool-result-text \{ background: var(--b2); border-left: 3px solid var(--b3);
                               padding: 8px 12px; border-radius: 4px;
                               white-space: pre-wrap; }
          .approval-bar \{ display: flex; gap: 0.75rem; align-items: center;
                           background: var(--b1); border: 2px solid #3498db;
                           border-radius: 8px; padding: 0.75rem; }
          .approval-info \{ flex: 1; }
          .approval-title \{ font-weight: 600; }
          .approval-detail \{ font-size: 0.875rem; opacity: 0.8; }
          .approval-actions \{ display: flex; gap: 0.5rem; align-items: center; }
          .tool-name-badge \{ padding: 0.5rem 0.75rem; background: var(--b2);
                              border-radius: 6px; font-family: monospace;
                              font-size: 0.875rem; }
          .btn-approve \{ padding: 0.5rem 1rem; background: #27ae60; color: white;
                          border: none; border-radius: 6px; cursor: pointer;
                          font-weight: 600; }
          .btn-deny \{ padding: 0.5rem 1rem; background: #e74c3c; color: white;
                       border: none; border-radius: 6px; cursor: pointer;
                       font-weight: 600; }
          .btn-allow \{ padding: 0.5rem 1rem; background: var(--b2);
                        color: var(--f0); border: 1px solid var(--b3);
                        border-radius: 6px; cursor: pointer; font-size: 0.875rem; }
          """
        ==
      ==
    ==
    ;body
      ;div#layout
        ;+  (render-sidebar chat-list `active-id model-display)
        ::  Main area
        ;div#main
          ;div#header
            ;h1.s2: {chat-name}
          ==
          ;div#messages
            ;*  %+  turn  msg-list
                |=  [idx=@ud msg=message:claude]
                (render-message msg)
          ==
          ;div#thinking: Claude is thinking...
          ;div#input-area
            ;+  ?^  pending-tools.chat
                  (render-approval-bar u.pending-tools.chat chat-id-text)
                ;form#chat-form
                  ;textarea#prompt(rows "1", placeholder "Send a message...");
                  ;button#send-btn(type "submit"): Send
                ==
          ==
        ==
      ==
      ;script
        ;+  ;/  %-  trip
        %-  crip
        ;:  weld
          sidebar-js
          """
          var messages = document.getElementById('messages');
          var thinking = document.getElementById('thinking');
          function renderMarkdown() \{
            document.querySelectorAll('.markdown-content').forEach(function(el) \{
              if (!el.dataset.rendered && window.marked) \{
                el.innerHTML = marked.parse(el.textContent);
                el.dataset.rendered = 'true';
              }
            });
          }
          renderMarkdown();
          var es = new EventSource('/mister/claude/stream/{chat-id-text}');
          es.addEventListener('message-update', function(e) \{
            messages.insertAdjacentHTML('beforeend', e.data);
            messages.scrollTop = messages.scrollHeight;
            renderMarkdown();
          });
          es.addEventListener('state-update', function(e) \{
            var state = JSON.parse(e.data);
            thinking.style.display = state.thinking ? 'block' : 'none';
            var sb = document.getElementById('send-btn');
            if (sb) sb.disabled = state.thinking;
          });
          es.addEventListener('tool-approval', function(e) \{
            var ia = document.getElementById('input-area');
            if (ia) ia.innerHTML = e.data;
          });
          window.addEventListener('beforeunload', function() \{ es.close(); });
          function approveTool(toolId) \{
            fetch('/mister/claude/{chat-id-text}/approve-tool/' + encodeURIComponent(toolId), \{
              method: 'POST'
            }).then(function(r) \{ if (!r.ok) alert('Failed to approve tool'); });
          }
          function denyTool(toolId) \{
            fetch('/mister/claude/{chat-id-text}/deny-tool/' + encodeURIComponent(toolId), \{
              method: 'POST'
            }).then(function(r) \{ if (!r.ok) alert('Failed to deny tool'); });
          }
          function alwaysAllowTool(toolName) \{
            fetch('/mister/claude/{chat-id-text}/always-allow/' + encodeURIComponent(toolName), \{
              method: 'POST'
            }).then(function(r) \{ if (!r.ok) alert('Failed to allow tool'); });
          }
          function sendMessage() \{
            var p = document.getElementById('prompt');
            var sb = document.getElementById('send-btn');
            if (!p) return;
            var text = p.value.trim();
            if (!text) return;
            p.value = '';
            p.style.height = 'auto';
            if (sb) sb.disabled = true;
            thinking.style.display = 'block';
            fetch('/mister/claude/{chat-id-text}', \{
              method: 'POST',
              headers: \{'Content-Type': 'application/json'},
              body: JSON.stringify(\{prompt: text})
            })
            .then(function(r) \{ return r.json(); })
            .then(function(data) \{
              if (data.error) \{
                thinking.style.display = 'none';
                if (sb) sb.disabled = false;
                var div = document.createElement('div');
                div.className = 'msg msg-error';
                div.textContent = data.error;
                messages.appendChild(div);
                messages.scrollTop = messages.scrollHeight;
              }
            })
            .catch(function(err) \{
              thinking.style.display = 'none';
              if (sb) sb.disabled = false;
              var div = document.createElement('div');
              div.className = 'msg msg-error';
              div.textContent = 'Request failed: ' + err.message;
              messages.appendChild(div);
              messages.scrollTop = messages.scrollHeight;
            });
          }
          /* Event delegation for form submit and textarea */
          document.getElementById('input-area').addEventListener('submit', function(e) \{
            e.preventDefault();
            sendMessage();
          });
          document.getElementById('input-area').addEventListener('input', function(e) \{
            if (e.target.id === 'prompt') \{
              e.target.style.height = 'auto';
              e.target.style.height = Math.min(e.target.scrollHeight, 200) + 'px';
            }
          });
          document.getElementById('input-area').addEventListener('keydown', function(e) \{
            if (e.target.id === 'prompt' && e.key === 'Enter' && !e.shiftKey) \{
              e.preventDefault();
              sendMessage();
            }
          });
          /* Keyboard shortcuts for tool approval */
          document.addEventListener('keydown', function(e) \{
            var approveBtn = document.querySelector('.btn-approve');
            var denyBtn = document.querySelector('.btn-deny');
            if (!approveBtn || !denyBtn) return;
            if (e.key === 'Enter' && !e.shiftKey && !e.ctrlKey) \{
              e.preventDefault(); approveBtn.click();
            }
            if (e.key === 'Escape') \{
              e.preventDefault(); denyBtn.click();
            }
          });
          messages.scrollTop = messages.scrollHeight;
          var p = document.getElementById('prompt');
          if (p) p.focus();
          (function() \{
            try \{
              var serverTz = '{server-tz}';
              var browserTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
              if (browserTz && browserTz !== serverTz) \{
                if (confirm('Server timezone is ' + serverTz + '. Update to browser timezone ' + browserTz + ' and reload?')) \{
                  fetch('/mister/claude/config', \{
                    method: 'POST',
                    headers: \{'Content-Type': 'application/json'},
                    body: JSON.stringify(\{timezone: browserTz})
                  }).then(function(response) \{
                    if (response.ok) \{ location.reload(); }
                  });
                }
              }
            } catch(e) \{
              console.error('Failed to detect timezone:', e);
            }
          })();
          """
        ==
      ==
    ==
  ==
::
++  settings-page
  |=  cfg=json
  ^-  manx
  =/  api-key=@t  (get-key 'api-key' '' cfg)
  =/  model=@t  (get-key 'model' 'claude-sonnet-4-5-20250929' cfg)
  =/  has-key=?  !=('' api-key)
  =/  key-display=tape
    ?.  has-key  "not set"
    =/  kt=tape  (trip api-key)
    ?:  (lth (lent kt) 12)  "configured"
    "{(scag 7 kt)}...{(slag (sub (lent kt) 4) kt)}"
  =/  model-display=tape  (trip model)
  ;html
    ;head
      ;title: Mister Claude - Settings
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", href "data:,");
      ;+  feather:feather
    ==
    ;body.fc.g4.p5.ma.mw-page
      ;div.fr.jb.ac
        ;h1.s3: Settings
        ;a.f3(href "/mister/claude"): back to chat
      ==
      ;div.p4.b1.br2.fc.g2.mt2
        ;h2.s5: Status
        ;+  ?:  has-key
              ;p.f-3: API key: {key-display}
            ;p.f-1: API key: not set
        ;p: Model: {model-display}
      ==
      ;form.fc.g3.mt4(method "POST", action "/mister/claude/settings")
        ;div.fc.g1
          ;label(for "api-key"): Anthropic API Key
          ;input.p-2.b1.br1(type "password", name "api-key", id "api-key", placeholder "sk-ant-...");
        ==
        ;div.fc.g1
          ;label(for "model"): Model
          ;input.p-2.b1.br1(type "text", name "model", id "model", value model-display);
        ==
        ;button.p-2.b1.br1.hover.pointer(type "submit"): Save
      ==
    ==
  ==
--
