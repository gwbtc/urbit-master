/-  claude
/+  io=sailboxio, hu=http-utils, server, ui-claude, claude-lib=claude, chat-index,
    sse=sse-helpers, *html-utils, tarball, json-utils, tools
|%
::  Helper: Get all chats from ball as a map
::
++  get-all-chats
  |=  =ball:tarball
  ^-  (map @ux chat:claude)
  =/  ba-core  ~(. ba:tarball ball)
  =/  filenames=(list @ta)  (lis:ba-core /claude/chats)
  %-  malt
  %+  murn  filenames
  |=  name=@ta
  ^-  (unit [@ux chat:claude])
  ::  Only process .chat:claude files
  =/  name-tape=tape  (trip name)
  =/  ext-tape=tape  ".claude-chat"
  =/  ext-len=@ud  (lent ext-tape)
  =/  name-len=@ud  (lent name-tape)
  ?.  (gte name-len ext-len)  ~
  ?.  =((flop (scag ext-len (flop name-tape))) ext-tape)  ~
  ::  Parse hex ID from filename (everything before .chat:claude)
  =/  id-tape=tape  (slag 0 (scag (sub name-len ext-len) name-tape))
  =/  parsed-id=(unit @ux)  (rush (crip id-tape) hex)
  ?~  parsed-id  ~
  ::  Get the content
  =/  maybe-content=(unit content:tarball)  (get:ba-core /claude/chats name)
  ?~  maybe-content  ~
  ::  Extract cage from content
  =/  =cage  cage.u.maybe-content
  ::  Must have chat:claude mark
  ?.  =(p.cage %claude-chat)  ~
  ::  Try to extract the chat
  =/  result  (mule |.(!<(chat:claude q.cage)))
  ?.  ?=(%& -.result)  ~
  `[u.parsed-id p.result]
::
::  Helper: Get active chat ID from ball
::
++  get-active-chat
  |=  =ball:tarball
  ^-  (unit @ux)
  =/  txt=(unit wain)
    (~(get-cage-as ba:tarball ball) [/claude 'active-chat.txt'] wain)
  ?~  txt  ~
  ?~  u.txt  ~
  (rush i.u.txt hex)
::
::  Helper: Get a single chat from ball
::
++  get-chat
  |=  [=ball:tarball chat-id=@ux]
  ^-  (unit chat:claude)
  (~(get-cage-as ba:tarball ball) [/claude/chats (crip "{(hexn:hu chat-id)}.claude-chat")] chat:claude)
::
::  Helper: Put a chat to ball
::
++  put-chat
  |=  [chat-id=@ux =chat:claude]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ;<  ~  bind:m
    (put-cage:io /claude/chats (crip "{(hexn:hu chat-id)}.claude-chat") [%claude-chat !>(chat)])
  (pure:m ~)
::
::  Helper: Delete a chat from ball
::
++  del-chat
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  (del:io /claude/chats (crip "{(hexn:hu chat-id)}.claude-chat"))
::
::  Helper: Set active chat in ball
::
++  set-active-chat
  |=  chat-id=(unit @ux)
  =/  m  (fiber:io ,~)
  ^-  form:m
  =/  =wain
    ?~  chat-id  ~
    ~[(crip (hexn:hu u.chat-id))]
  (put-cage:io /claude 'active-chat.txt' [%txt !>(wain)])
::
::  POST /master/claude/{id} - Send message to Claude chat
::
++  handle-message
  |=  [chat-id=@ux message=@t api-key=@t ai-model=@t user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Block message sending if API request is in flight or tools are pending
  ?.  &(=(~ api-request-pid.u.chat) =(~ pending-tools.u.chat))
    %+  give-simple-payload:io
      :-  409
      ~[['content-type' 'text/plain']]
    `(as-octs:mimes:html '409 Cannot send message while request is in progress or tools are pending')
  ::  Validation passed - now get PID for this request
  ;<  pid=@ta  bind:m  get-pid:io
  ::  Build and save user message
  =/  user-content=json
    :-  %a
    :~  %-  pairs:enjs:format
        :~  ['type' s+'text']
            ['text' s+message]
        ==
    ==
  =/  user-msg=message:claude  ['user' user-content %normal chat-id 0 0 0 0]
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  user-timestamp=@ud  (unm:chrono:userlib now.bowl)
  ::  Reset iteration count for new user message
  =.  iteration-count.u.chat  0
  ::  Add user message to chat (THE SINGLE SOURCE OF TRUTH)
  ;<  updated-chat=chat:claude  bind:m  (add-message-to-chat:sse chat-id user-timestamp u.chat user-msg)
  =.  u.chat  updated-chat
  ;<  ~  bind:m  (set-active-chat `chat-id)
  ::  Call Claude and get response
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[200 ~] ~])
  ::  Store PID in chat before API call
  =.  api-request-pid.u.chat  `pid
  ;<  ~  bind:m  (put-chat chat-id u.chat)
  ::  Send SSE to update UI (show thinking indicator and stop button)
  ;<  ~  bind:m  (notify-chat-state:sse chat-id)
  ::  Return HTTP response immediately so HTMX doesn't hang
  ;<  ~  bind:m  (give-simple-payload:io [[200 ~] ~])
  ::  Now continue with Claude API call in background
  =/  messages-before=((mop @ud message:claude) lth)  messages-by-time.u.chat
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  ::  Wrap send-message in retry with exponential backoff for rate limits
  ;<  [response=@t updated-chat=chat:claude]  bind:m
    %+  (retry:io ,[response=@t updated-chat=chat:claude])
      [~ 5]  ::  max 5 retries (~1s, ~2s, ~4s, ~8s, ~16s backoff)
    (send-message:claude-lib api-key ai-model u.chat all-chats user-timezone)
  ::  Check if there are pending tools awaiting approval
  ?.  =(~ pending-tools.updated-chat)
    ~&  >  "Tools pending approval, saving chat and notifying user"
    ::  Clear API PID since we're pausing for approval
    =.  updated-chat  updated-chat(api-request-pid ~)
    ;<  ~  bind:m  (put-chat chat-id updated-chat)
    ::  Send SSE to show tool approval UI and hide thinking indicator
    ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
    (notify-chat-state:sse chat-id)
  ::  Get fresh state after Claude call (tools may have modified it)
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat-after=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat-after
    (give-simple-payload:io [[200 ~] ~])
  ~&  >  "MERGE: Chat from state has name: '{<name.u.chat-after>}'"
  ~&  >  "MERGE: Chat from send-message has name: '{<name.updated-chat>}'"
  ::  Use the chat from state (which has tool modifications) but update with new messages and clear PID
  ::  The updated-chat from send-message has the new assistant+tool_result messages
  ::  We need to merge them into the state version
  =.  updated-chat
    %=  u.chat-after
      messages-by-time    messages-by-time.updated-chat
      messages-by-index   messages-by-index.updated-chat
      messages-by-chars   messages-by-chars.updated-chat
      next-index          next-index.updated-chat
      total-chars         total-chars.updated-chat
      api-request-pid     ~
    ==
  ~&  >  "MERGE: Final merged chat has name: '{<name.updated-chat>}'"
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ~&  >  "MERGE: Chat written to state"
  ::  Send state update SSE to hide thinking indicator and stop button
  ;<  ~  bind:m  (notify-chat-state:sse chat-id)
  (pure:m ~)
::
::  POST /master/claude/{id}/interrupt - Interrupt an in-flight API request
::
++  handle-interrupt
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Check if there's an API request in flight
  ?~  api-request-pid.u.chat
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 No API request in flight')])
  ::  Kill the fiber with the stored PID
  ;<  ~  bind:m  (fiber-kill:io u.api-request-pid.u.chat)
  ::  Add a system message indicating the interruption
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  interrupt-timestamp=@ud  (unm:chrono:userlib now.bowl)
  =/  interrupt-content=json
    :-  %a
    :~  %-  pairs:enjs:format
        :~  ['type' s+'text']
            ['text' s+'[Request interrupted by user]']
        ==
    ==
  =/  interrupt-msg=message:claude  ['assistant' interrupt-content %error chat-id 0 0 0 0]
  ::  Clear the PID from the chat BEFORE adding message
  =/  chat-without-pid=chat:claude  u.chat(api-request-pid ~)
  ::  Add interrupt message to chat (THE SINGLE SOURCE OF TRUTH)
  ;<  updated-chat=chat:claude  bind:m
    (add-message-to-chat:sse chat-id interrupt-timestamp chat-without-pid interrupt-msg)
  ::  Send state update SSE
  ;<  ~  bind:m  (notify-chat-state:sse chat-id)
  ::  Return success
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/rename - Rename a chat
::
++  handle-rename
  |=  [chat-id=@ux new-name=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Update the chat name
  =.  name.u.chat  new-name
  ;<  ~  bind:m  (put-chat chat-id u.chat)
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/delete - Delete a chat
::
++  handle-delete
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Check if this is the active chat before deleting
  =/  active=(unit @ux)  (get-active-chat ball)
  =/  was-active=?  =(`chat-id active)
  ::  Delete the chat
  ;<  ~  bind:m  (del-chat chat-id)
  ::  Clear active chat if it was the deleted one
  ?:  was-active
    ;<  ~  bind:m  (set-active-chat ~)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/branch - Branch from a message
::
++  handle-branch
  |=  [parent-chat-id=@ux branch-point=@ud]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Verify parent chat exists
  =/  parent-chat=(unit chat:claude)  (get-chat ball parent-chat-id)
  ?~  parent-chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Parent Chat Not Found')])
  ::  Verify branch point is a valid message index in parent
  =/  branch-msg=(unit message:claude)
    (get:((on @ud message:claude) lth) messages-by-index.u.parent-chat branch-point)
  ?~  branch-msg
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 Invalid branch point')])
  ::  Generate unique child chat ID
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  =/  child-chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by all-chats) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  ::  Build new child chat (empty, will reference parent for history)
  =/  child-chat=chat:claude
    :*  %3
        child-chat-id
        (crip "Branch from {(trip name.u.parent-chat)}")
        now.bowl
        ::  API parameters (use defaults)
        'claude-sonnet-4-5-20250929'  :: model
        1.024 :: max-tokens
        .~1.0 :: temperature
        .~1.0 :: top-p
        0     :: top-k
        ''    :: system-instructions
        ~     :: stop-sequences
        ~     :: tool-choice
        ::  Messages (empty)
        ~     :: messages-by-time
        ~     :: messages-by-index
        ~     :: messages-by-chars
        0     :: next-index
        0     :: total-chars
        ::  Branching
        `[parent-chat-id branch-point]  :: parent link
        ~     :: children (empty)
        ::  Runtime state
        ~     :: api-request-pid
        ~     :: pending-tools
        ~     :: allowed-tools (empty set)
        ::  Agent safety
        ~     :: max-iterations
        0     :: iteration-count
    ==
  ::  Update parent chat to add this child to its children map
  =.  children.u.parent-chat  (~(put by children.u.parent-chat) branch-point child-chat-id)
  ::  Save both chats
  ;<  ~  bind:m  (put-chat parent-chat-id u.parent-chat)
  ;<  ~  bind:m  (put-chat child-chat-id child-chat)
  ;<  ~  bind:m  (set-active-chat `child-chat-id)
  ::  Return the child chat ID as plain text
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html (crip (hexn:hu child-chat-id)))])
::
::  GET /master/claude - Redirect to active chat or new chat
::
++  handle-get-root
  |=  ~
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  active=(unit @ux)  (get-active-chat ball)
  ?^  active
    (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:hu u.active)}")]]] ~])
  (give-simple-payload:io [[303 ~[['location' '/master/claude/new']]] ~])
::
::  GET /master/claude/new - Create new chat and redirect
::
++  handle-get-new
  |=  ~
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ;<  =bowl:gall  bind:m  get-bowl:io
  ::  Generate unique chat ID
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  =/  chat-id=@ux  |-
    =/  candidate=@ux  `@ux`(sham eny.bowl)
    ?:  (~(has by all-chats) candidate)
      $(eny.bowl +(eny.bowl))
    candidate
  =/  new-chat=chat:claude
    :*  %3
        chat-id
        'New Chat'
        now.bowl
        ::  API parameters (use defaults)
        'claude-sonnet-4-5-20250929'  :: model
        1.024 :: max-tokens
        .~1.0 :: temperature
        .~1.0 :: top-p
        0     :: top-k
        ''    :: system-instructions
        ~     :: stop-sequences
        ~     :: tool-choice
        ::  Messages (empty)
        ~     :: messages-by-time
        ~     :: messages-by-index
        ~     :: messages-by-chars
        0     :: next-index
        0     :: total-chars
        ::  Branching
        ~     :: parent
        ~     :: children
        ::  Runtime state
        ~     :: api-request-pid
        ~     :: pending-tools
        ~     :: allowed-tools (empty set)
        ::  Agent safety
        ~     :: max-iterations
        0     :: iteration-count
    ==
  ;<  ~  bind:m  (put-chat chat-id new-chat)
  ;<  ~  bind:m  (set-active-chat `chat-id)
  (give-simple-payload:io [[303 ~[['location' (crip "/master/claude/{(hexn:hu chat-id)}")]]] ~])
::
::  GET /master/claude/{id} - Render chat page
::
++  handle-get-chat
  |=  [chat-id=@ux user-timezone=@t creds-jon=(unit json)]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Extract creds for UI display (use defaults if not configured)
  =/  [api-key=@t ai-model=@t]
    ?~  creds-jon
      ['' 'claude-sonnet-4-20250514']
    :*  (~(dog jo:json-utils u.creds-jon) /api-key so:dejs:format)
        (~(dog jo:json-utils u.creds-jon) /ai-model so:dejs:format)
    ==
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  (give-simple-payload:io (mime-response:hu [/text/html (manx-to-octs:server (chat-page:ui-claude u.chat all-chats user-timezone api-key ai-model))]))
::
::  GET /master/claude/{id}/messages - Get paginated messages
::
++  handle-get-messages
  |=  [chat-id=@ux args=(list [key=@t value=@t]) user-timezone=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Parse query parameters
  =/  before-timestamp=(unit @ud)
    =/  before-str=(unit @t)  (~(get by (malt args)) 'before')
    ?~  before-str  ~
    `(rash u.before-str dem)
  =/  limit=@ud
    =/  limit-str=(unit @t)  (~(get by (malt args)) 'limit')
    ?~  limit-str  3
    (rash u.limit-str dem)
  ::  Get paginated messages using helper
  =/  message-list=(list [@ud message:claude])
    (get-messages-page:claude-lib messages-by-time.u.chat before-timestamp limit)
  ::  Render as HTML using render-message from ui-master
  =/  rendered-messages=(list manx)
    %-  zing
    %+  turn  message-list
    |=  [timestamp=@ud msg=message:claude]
    (render-message:ui-claude timestamp msg user-timezone)
  ::  Return fragments directly without wrapper div
  =/  html-text=@t
    %-  crip
    %-  zing
    %+  turn  rendered-messages
    |=(m=manx (en-xml:html m))
  (give-simple-payload:io [[200 ~] `(as-octs:mimes:html html-text)])
::
::  POST /master/update-claude-creds - Update Claude credentials
::
++  handle-update-creds
  |=  args=(list [key=@t value=@t])
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  ::  Get existing creds from ball
  =/  existing=(unit json)
    (~(get-cage-as ba:tarball ball) [/config/creds 'claude.json'] json)
  ::  Use existing values if not provided
  =/  api-key=@t
    ?~  existing
      (need (get-key:kv 'api-key' args))
    %.  (get-key:kv 'api-key' args)
    (curr fall (dog:~(. jo:json-utils u.existing) /api-key so:dejs:format))
  =/  ai-model=@t
    ?~  existing
      (fall (get-key:kv 'model' args) 'claude-sonnet-4-20250514')
    %.  (get-key:kv 'model' args)
    (curr fall (dog:~(. jo:json-utils u.existing) /ai-model so:dejs:format))
  ::  Build json directly
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['api-key' s+api-key]
        ['ai-model' s+ai-model]
    ==
  ::  Put with validation
  ;<  ~  bind:m  (put-cage:io /config/creds 'claude.json' [%json !>(jon)])
  (pure:m ~)
::
::  POST /master/claude/{id}/approve-tool/{tool-id} - Approve a pending tool
::
++  handle-approve-tool
  |=  [chat-id=@ux tool-id=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Check if there's a pending tools state
  ?~  pending-tools.u.chat
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 No pending tools')])
  ::  Find the tool in pending list
  =/  tool-idx=(unit @ud)
    =/  idx=@ud  0
    |-  ^-  (unit @ud)
    ?~  pending.u.pending-tools.u.chat  ~
    ?:  =(tool-id id.i.pending.u.pending-tools.u.chat)  `idx
    $(pending.u.pending-tools.u.chat t.pending.u.pending-tools.u.chat, idx +(idx))
  ?~  tool-idx
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Tool Not Found')])
  ::  Get the tool and remove it from pending list
  =/  approved-tool=tool-request:claude  (snag u.tool-idx pending.u.pending-tools.u.chat)
  =/  remaining-pending=(list tool-request:claude)
    (oust [u.tool-idx 1] pending.u.pending-tools.u.chat)
  ::  Update UI immediately
  =/  temp-state=pending-tools-state:claude
    [assistant-timestamp.u.pending-tools.u.chat remaining-pending approved.u.pending-tools.u.chat]
  =/  temp-chat=chat:claude
    u.chat(pending-tools `temp-state)
  ;<  ~  bind:m  (put-chat chat-id temp-chat)
  ::  Send SSE immediately so UI updates while tool executes
  ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
  ::  Execute the approved tool (this can take time, but UI already updated)
  =/  arguments=(map @t json)
    ?.  ?=([%o *] input.approved-tool)  ~
    p.input.approved-tool
  ;<  exec-result=tool-result:tools  bind:m
    (execute-tool:tools name.approved-tool arguments)
  ::  Extract text from result
  =/  result-text=@t
    ?-  -.exec-result
      %text   text.exec-result
      %error  message.exec-result
    ==
  ::  Build tool-result structure
  =/  new-result=tool-result:claude
    [approved-tool [%success result-text]]
  ::  Add to approved list
  =/  updated-approved=(list tool-result:claude)
    (snoc approved.u.pending-tools.u.chat new-result)
  ::  Check if all tools are decided (pending list is empty)
  ?.  =(~ remaining-pending)
    ::  More tools to approve - update state with results
    =/  updated-state=pending-tools-state:claude
      [assistant-timestamp.u.pending-tools.u.chat remaining-pending updated-approved]
    =/  updated-chat=chat:claude
      u.chat(pending-tools `updated-state)
    ;<  ~  bind:m  (put-chat chat-id updated-chat)
    ::  Send SSE to update UI with new approved count
    ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  ::  All tools decided - send all results to Claude
  ::  Build tool_result JSON array
  =/  tool-results-json=(list json)
    %+  turn  updated-approved
    |=  tr=tool-result:claude
    =/  content-text=@t
      ?-  -.result.tr
        %success  text.result.tr
        %error    message.result.tr
      ==
    =/  is-error=?
      ?-  -.result.tr
        %success  %.n
        %error    %.y
      ==
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+id.request.tr]
        ['content' s+content-text]
        ['is_error' b+is-error]
    ==
  ::  Add user message with all tool results
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  result-timestamp=@ud
    (add assistant-timestamp.u.pending-tools.u.chat 1)
  =/  result-msg=message:claude
    ['user' [%a tool-results-json] %normal chat-id 0 0 0 0]
  ::  Reload chat from state before adding messages (tools may have modified it)
  ~&  >  "BEFORE TOOL RESULTS: Reloading chat from state"
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat-reloaded=(unit chat:claude)  (get-chat ball chat-id)
  =/  chat-base=chat:claude  ?~(chat-reloaded u.chat u.chat-reloaded)
  ~&  >  "BEFORE TOOL RESULTS: Chat name from state: '{<name.chat-base>}'"
  =/  chat-with-results=chat:claude
    %=  chat-base
      pending-tools  ~
    ==
  ::  Add tool result message to chat (THE SINGLE SOURCE OF TRUTH)
  ~&  >  "BEFORE TOOL RESULTS: Writing chat with name: '{<name.chat-with-results>}'"
  ;<  chat-final=chat:claude  bind:m
    (add-message-to-chat:sse chat-id result-timestamp chat-with-results result-msg)
  ::  Continue conversation with Claude
  =/  creds-jon=json
    (~(got-cage-as ba:tarball ball) [/config/creds 'claude.json'] json)
  =/  api-key=@t  (~(dog jo:json-utils creds-jon) /api-key so:dejs:format)
  =/  ai-model=@t  (~(dog jo:json-utils creds-jon) /ai-model so:dejs:format)
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball) [/config 'timezone.txt'] wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  ::  Save message timestamps before send-message
  =/  messages-before-continuation=((mop @ud message:claude) lth)  messages-by-time.chat-final
  ;<  [response=@t updated-chat=chat:claude]  bind:m
    (send-message:claude-lib api-key ai-model chat-final all-chats user-timezone)
  ::  Save new timestamps before merging
  =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.updated-chat) head)
  =/  before-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-before-continuation) head)
  =/  new-timestamps=(list @ud)
    %+  skip  all-timestamps
    |=(t=@ud (~(has in (silt before-timestamps)) t))
  ::  Reload chat from state to get any tool modifications
  ~&  >  "APPROVE CONTINUATION: About to reload chat from state"
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat-from-state=(unit chat:claude)  (get-chat ball chat-id)
  ~&  >  "APPROVE CONTINUATION: Chat from state: {<chat-from-state>}"
  ~&  >  "APPROVE CONTINUATION: Chat from send-message name: '{<name.updated-chat>}'"
  ::  Merge: take name and other fields from state, messages from send-message
  =.  updated-chat
    ?~  chat-from-state
      ~&  >  "APPROVE CONTINUATION: No chat from state, using send-message result"
      updated-chat
    ~&  >  "APPROVE CONTINUATION: Chat from state name: '{<name.u.chat-from-state>}'"
    %=  u.chat-from-state
      messages-by-time   messages-by-time.updated-chat
      messages-by-index  messages-by-index.updated-chat
      messages-by-chars  messages-by-chars.updated-chat
      next-index         next-index.updated-chat
      total-chars        total-chars.updated-chat
      pending-tools      pending-tools.updated-chat
      api-request-pid    api-request-pid.updated-chat
    ==
  ~&  >  "APPROVE CONTINUATION: Merged chat name: '{<name.updated-chat>}'"
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ~&  >  "APPROVE CONTINUATION: Chat written to state"
  ::  Messages already sent their own SSEs via add-message-to-chat
  ::  Check if new pending tools were added
  ?.  =(~ pending-tools.updated-chat)
    ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  ::  No pending tools - conversation continued, restore input form
  ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
  ;<  ~  bind:m  (notify-chat-state:sse chat-id)
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/deny-tool/{tool-id} - Deny a pending tool
::
++  handle-deny-tool
  |=  [chat-id=@ux tool-id=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Check if there's a pending tools state
  ?~  pending-tools.u.chat
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 No pending tools')])
  ::  Find the tool in pending list
  =/  tool-idx=(unit @ud)
    =/  idx=@ud  0
    |-  ^-  (unit @ud)
    ?~  pending.u.pending-tools.u.chat  ~
    ?:  =(tool-id id.i.pending.u.pending-tools.u.chat)  `idx
    $(pending.u.pending-tools.u.chat t.pending.u.pending-tools.u.chat, idx +(idx))
  ?~  tool-idx
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Tool Not Found')])
  ::  Get the tool and remove it from pending list
  =/  denied-tool=tool-request:claude  (snag u.tool-idx pending.u.pending-tools.u.chat)
  =/  remaining-pending=(list tool-request:claude)
    (oust [u.tool-idx 1] pending.u.pending-tools.u.chat)
  ::  Update UI immediately
  =/  temp-state=pending-tools-state:claude
    [assistant-timestamp.u.pending-tools.u.chat remaining-pending approved.u.pending-tools.u.chat]
  =/  temp-chat=chat:claude
    u.chat(pending-tools `temp-state)
  ;<  ~  bind:m  (put-chat chat-id temp-chat)
  ::  Send SSE immediately so UI updates
  ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
  ::  Build error tool-result
  =/  error-result=tool-result:claude
    [denied-tool [%error 'Tool use denied by user']]
  ::  Add to approved list (with error)
  =/  updated-approved=(list tool-result:claude)
    (snoc approved.u.pending-tools.u.chat error-result)
  ::  Check if all tools are decided
  ?.  =(~ remaining-pending)
    ::  More tools to decide - update state and notify
    =/  updated-state=pending-tools-state:claude
      [assistant-timestamp.u.pending-tools.u.chat remaining-pending updated-approved]
    =/  updated-chat=chat:claude
      u.chat(pending-tools `updated-state)
    ;<  ~  bind:m  (put-chat chat-id updated-chat)
    ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  ::  All tools decided - send all results to Claude (same as approve-tool)
  =/  tool-results-json=(list json)
    %+  turn  updated-approved
    |=  tr=tool-result:claude
    =/  content-text=@t
      ?-  -.result.tr
        %success  text.result.tr
        %error    message.result.tr
      ==
    =/  is-error=?
      ?-  -.result.tr
        %success  %.n
        %error    %.y
      ==
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+id.request.tr]
        ['content' s+content-text]
        ['is_error' b+is-error]
    ==
  ;<  =bowl:gall  bind:m  get-bowl:io
  =/  result-timestamp=@ud
    (add assistant-timestamp.u.pending-tools.u.chat 1)
  =/  result-msg=message:claude
    ['user' [%a tool-results-json] %normal chat-id 0 0 0 0]
  =/  chat-with-results=chat:claude
    u.chat(pending-tools ~)
  ::  Add tool result message to chat (THE SINGLE SOURCE OF TRUTH)
  ;<  chat-final=chat:claude  bind:m
    (add-message-to-chat:sse chat-id result-timestamp chat-with-results result-msg)
  ::  Continue conversation with Claude
  =/  creds-jon=json
    (~(got-cage-as ba:tarball ball) [/config/creds 'claude.json'] json)
  =/  api-key=@t  (~(dog jo:json-utils creds-jon) /api-key so:dejs:format)
  =/  ai-model=@t  (~(dog jo:json-utils creds-jon) /ai-model so:dejs:format)
  =/  user-timezone=@t
    =/  tz-result  (mule |.((~(get-cage-as ba:tarball ball) [/config 'timezone.txt'] wain)))
    ?:  ?=(%| -.tz-result)  'UTC'
    =/  tz-wain=(unit wain)  p.tz-result
    ?~  tz-wain  'UTC'
    ?~  u.tz-wain  'UTC'
    i.u.tz-wain
  =/  all-chats=(map @ux chat:claude)  (get-all-chats ball)
  ::  Save message timestamps before send-message
  =/  messages-before-continuation=((mop @ud message:claude) lth)  messages-by-time.chat-final
  ;<  [response=@t updated-chat=chat:claude]  bind:m
    (send-message:claude-lib api-key ai-model chat-final all-chats user-timezone)
  ::  Save new timestamps before merging
  =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.updated-chat) head)
  =/  before-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-before-continuation) head)
  =/  new-timestamps=(list @ud)
    %+  skip  all-timestamps
    |=(t=@ud (~(has in (silt before-timestamps)) t))
  ::  Reload chat from state to get any tool modifications
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat-from-state=(unit chat:claude)  (get-chat ball chat-id)
  ::  Merge: take name and other fields from state, messages from send-message
  =.  updated-chat
    ?~  chat-from-state  updated-chat
    %=  u.chat-from-state
      messages-by-time   messages-by-time.updated-chat
      messages-by-index  messages-by-index.updated-chat
      messages-by-chars  messages-by-chars.updated-chat
      next-index         next-index.updated-chat
      total-chars        total-chars.updated-chat
      pending-tools      pending-tools.updated-chat
      api-request-pid    api-request-pid.updated-chat
    ==
  ;<  ~  bind:m  (put-chat chat-id updated-chat)
  ::  Messages already sent their own SSEs via add-message-to-chat
  ?.  =(~ pending-tools.updated-chat)
    ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
    (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
  ::  No pending tools - restore input form
  ;<  ~  bind:m  (notify-tool-approval:sse chat-id)
  ;<  ~  bind:m  (notify-chat-state:sse chat-id)
  (give-simple-payload:io [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html 'OK')])
::
::  POST /master/claude/{id}/always-allow/{tool-name} - Add tool to allowed set
::
++  handle-always-allow
  |=  [chat-id=@ux tool-name=@t]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  ball=ball:tarball  bind:m  get-state:io
  =/  chat=(unit chat:claude)  (get-chat ball chat-id)
  ?~  chat
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Chat Not Found')])
  ::  Add tool name to allowed-tools set for future auto-approval
  =.  allowed-tools.u.chat  (~(put in allowed-tools.u.chat) tool-name)
  ;<  ~  bind:m  (put-chat chat-id u.chat)
  ::  Now find and approve the current pending tool with this name
  ?~  pending-tools.u.chat
    (give-simple-payload:io [[400 ~] `(as-octs:mimes:html '400 No pending tools')])
  =/  matching-tool=(unit tool-request:claude)
    |-  ^-  (unit tool-request:claude)
    ?~  pending.u.pending-tools.u.chat  ~
    ?:  =(tool-name name.i.pending.u.pending-tools.u.chat)
      `i.pending.u.pending-tools.u.chat
    $(pending.u.pending-tools.u.chat t.pending.u.pending-tools.u.chat)
  ?~  matching-tool
    (give-simple-payload:io [[404 ~] `(as-octs:mimes:html '404 Tool Not Found')])
  ::  Found the tool - now approve it using the same flow as handle-approve-tool
  (handle-approve-tool chat-id id.u.matching-tool)
--
