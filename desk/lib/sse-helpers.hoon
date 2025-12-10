/-  claude
/+  io=sailboxio, sailbox, chat-index
|%
::  THE SINGLE SOURCE OF TRUTH FOR ADDING MESSAGES
::
::  This is the ONLY function that should be used to add messages to chat history.
::  It handles:
::    1. Adding message to chat (via chat-index)
::    2. Saving chat to state
::    3. Sending SSE notification
::
++  add-message-to-chat
  |=  $:  chat-id=@ux
          timestamp=@ud
          chat=chat:claude
          msg=message:claude
      ==
  =/  m  (fiber:io ,chat:claude)
  ^-  form:m
  ~&  >  "Adding message to chat {<chat-id>} at {<timestamp>}"
  ::  1. Add message to chat
  =/  updated-chat=chat:claude
    (add-message:chat-index chat timestamp msg)
  ::  2. Save to state FIRST
  ;<  ~  bind:m
    (put-cage:io /claude/chats (crip "{(hexn:sailbox chat-id)}.claude-chat") [%claude-chat !>(updated-chat)])
  ::  3. THEN send SSE (so message is available when UI reads it)
  ;<  ~  bind:m  (notify-chat-message chat-id timestamp)
  ::  4. Return updated chat
  (pure:m updated-chat)
::
::  Helper functions for sending Server-Sent Events (SSE)
::
++  notify-chat-message
  |=  [chat-id=@ux timestamp=@ud]
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for message at {<timestamp>} to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    `(scot %ud timestamp)
    `%message-update
  ==
::
++  notify-chat-state
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for state update to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    ~
    `%state-update
  ==
::
++  notify-tool-approval
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for tool approval to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    ~
    `%tool-approval
  ==
::
++  notify-chat-title
  |=  chat-id=@ux
  =/  m  (fiber:io ,~)
  ^-  form:m
  ~&  >  "Sending SSE event for title update to chat {<chat-id>}"
  %:  send-sse-event:io
    /master/claude/stream/(crip (hexn:sailbox chat-id))
    ~
    `%title-update
  ==
--
