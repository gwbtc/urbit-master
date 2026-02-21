::  lib/nex/claude.hoon: Claude API client for nexus (ported from lib/claude.hoon)
::
/-  claude
/+  nexus, io=fiberio, tools=nex-tools, chat-index, pytz, hu=http-utils, time, iso-8601
|%
+$  claude-state  claude-state-0
+$  claude-state-0
  $:  %0
      api-key=@t
      model=$~('claude-sonnet-4-5-20250929' @t)
      timezone=$~('UTC' @t)
      active-chat=(unit @ux)
  ==
::  Maximum characters for context window (as proxy for tokens)
::
++  max-context-chars  100.000
::
::  Count characters in a message's JSON representation
::
++  count-message-chars
  |=  msg=message:claude
  ^-  @ud
  =/  msg-json=json
    %-  pairs:enjs:format
    :~  ['role' s+role.msg]
        ['content' content.msg]
    ==
  =/  json-text=@t  (en:json:html msg-json)
  (met 3 json-text)
::
::  Apply sliding window to message list based on character limit
::
++  apply-sliding-window
  |=  history=(list message:claude)
  ^-  (list message:claude)
  =/  reversed=(list message:claude)  (flop history)
  =/  accumulated=@ud  0
  =/  result=(list message:claude)  ~
  |-
  ?~  reversed
    result
  =/  msg-chars=@ud  (count-message-chars i.reversed)
  =/  new-total=@ud  (add accumulated msg-chars)
  ?:  (gth new-total max-context-chars)
    result
  $(reversed t.reversed, accumulated new-total, result [i.reversed result])
::
::  Build chat range string from message list
::
++  build-chat-ranges
  |=  messages=(list message:claude)
  ^-  tape
  ?~  messages  ""
  =/  result=tape  ""
  =/  current-chat=@ux  chat-id.i.messages
  =/  start-idx=@ud  index.i.messages
  =/  last-idx=@ud  index.i.messages
  =/  start-char=@ud  cumulative-chars.i.messages
  =/  last-msg=message:claude  i.messages
  =/  remaining=(list message:claude)  t.messages
  |-
  ?~  remaining
    =/  end-char=@ud  (add cumulative-chars.last-msg chars.last-msg)
    (weld result "[{(scow %ux current-chat)}:{(a-co:co start-idx)}-{(a-co:co last-idx)}:{(a-co:co start-char)}-{(a-co:co end-char)}]")
  =/  msg=message:claude  i.remaining
  ?:  =(chat-id.msg current-chat)
    $(remaining t.remaining, last-idx index.msg, last-msg msg)
  =/  end-char=@ud  (add cumulative-chars.last-msg chars.last-msg)
  =/  new-result=tape  (weld result "[{(scow %ux current-chat)}:{(a-co:co start-idx)}-{(a-co:co last-idx)}:{(a-co:co start-char)}-{(a-co:co end-char)}]")
  $(result new-result, current-chat chat-id.msg, start-idx index.msg, last-idx index.msg, start-char cumulative-chars.msg, last-msg msg, remaining t.remaining)
::
::  Build full conversation history by walking up parent chain
::
++  build-ancestor-context
  |=  [chat=chat:claude chats=(map @ux chat:claude)]
  ^-  (list message:claude)
  =/  ancestor-messages=(list message:claude)
    ?~  parent.chat  ~
    =/  parent-chat=(unit chat:claude)  (~(get by chats) chat-id.u.parent.chat)
    ?~  parent-chat  ~
    =/  parent-msgs-by-index=((mop @ud message:claude) lth)  messages-by-index.u.parent-chat
    =/  parent-msgs-list=(list [@ud message:claude])
      (tap:((on @ud message:claude) lth) (lot:((on @ud message:claude) lth) parent-msgs-by-index ~ `(add branch-point.u.parent.chat 1)))
    =/  grandparent-msgs=(list message:claude)
      (build-ancestor-context u.parent-chat chats)
    (weld grandparent-msgs (turn parent-msgs-list tail))
  =/  own-messages=(list message:claude)
    (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) tail)
  (weld ancestor-messages own-messages)
::
::  Get paginated messages from a chat
::
++  get-messages-page
  |=  [messages=((mop @ud message:claude) lth) before=(unit @ud) limit=@ud]
  ^-  (list [@ud message:claude])
  =/  messages-to-return=((mop @ud message:claude) lth)
    ?~  before
      messages
    (lot:((on @ud message:claude) lth) messages ~ `u.before)
  =/  message-list=(list [@ud message:claude])
    (scag limit (flop (tap:((on @ud message:claude) lth) messages-to-return)))
  (flop message-list)
::
::  Claude tool definitions
::
++  param-type-to-json
  |=  type=parameter-type:tools
  ^-  @t
  ?-  type
    %string   'string'
    %number   'number'
    %boolean  'boolean'
    %array    'array'
    %object   'object'
  ==
::
++  tool-to-claude-json
  |=  =tool:tools
  ^-  json
  =/  properties=(map @t json)
    %-  ~(run by parameters:tool)
    |=  param=parameter-def:tools
    %-  pairs:enjs:format
    :~  ['type' s+(param-type-to-json type.param)]
        ['description' s+description.param]
    ==
  =/  required-array=(list json)
    (turn required:tool |=(f=@t s+f))
  %-  pairs:enjs:format
  :~  ['name' s+name:tool]
      ['description' s+description:tool]
      :-  'input_schema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o properties]]
          ['required' [%a required-array]]
      ==
  ==
::
++  claude-tools
  ^-  (list json)
  %+  turn  ~(val by built-ins:tools)
  tool-to-claude-json
::
::  THE SINGLE SOURCE OF TRUTH FOR ADDING MESSAGES
::  (merged from lib/sse-helpers.hoon)
::
::  For now, saves chat and returns updated chat.
::  TODO: wire up SSE notifications once SSE is implemented in grubbery
::
++  add-message-to-chat
  |=  $:  chat-id=@ux
          timestamp=@ud
          chat=chat:claude
          msg=message:claude
      ==
  =/  m  (fiber:fiber:nexus ,chat:claude)
  ^-  form:m
  ~&  >  "Adding message to chat {<chat-id>} at {<timestamp>}"
  =/  updated-chat=chat:claude
    (add-message:chat-index chat timestamp msg)
  ::  TODO: save chat to tarball
  ::  TODO: send SSE notification
  (pure:m updated-chat)
::
::  Call Claude Messages API with conversation history
::
++  send-message
  |=  [api-key=@t ai-model=@t chat=chat:claude chats=(map @ux chat:claude) user-timezone=@t]
  =/  m  (fiber:fiber:nexus ,[response=@t updated-chat=chat:claude])
  ^-  form:m
  ::  Build full history including ancestors
  =/  full-history=(list message:claude)
    (build-ancestor-context chat chats)
  ::  Apply sliding window to limit context size
  =/  history=(list message:claude)
    (apply-sliding-window full-history)
  ~&  >  "send-message: {<(lent full-history)>} total messages, using {<(lent history)>} after sliding window"
  ::  Convert message history to JSON format
  =/  messages-json=(list json)
    %+  turn  history
    |=  msg=message:claude
    ^-  json
    %-  pairs:enjs:format
    :~  ['role' s+role.msg]
        ['content' content.msg]
    ==
  ::  Get current time in user's timezone
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  tz-time=(unit dext:pytz)
    (utc-to-tz:~(. zn:pytz user-timezone) now.bowl)
  =/  current-time=@t
    ?~  tz-time
      'Unknown'
    =/  tz-struct=date  (yore d.u.tz-time)
    =/  year=tape  (a-co:co y.tz-struct)
    =/  month=tape  (a-co:co m.tz-struct)
    =/  day=tape  (a-co:co d.t.tz-struct)
    =/  dow=@ud  (get-weekday:time d.u.tz-time)
    =/  weekday=tape
      ?+  dow  "???"
        %0  "Mon"
        %1  "Tue"
        %2  "Wed"
        %3  "Thu"
        %4  "Fri"
        %5  "Sat"
        %6  "Sun"
      ==
    =/  hour-24=@ud  h.t.tz-struct
    =/  minute=@ud   m.t.tz-struct
    =/  is-pm=?      (gte hour-24 12)
    =/  hour-12=@ud  ?:  =(hour-24 0)  12
                     ?:  (lte hour-24 12)  hour-24
                     (sub hour-24 12)
    =/  minute-str=tape
      ?:  (lth minute 10)
        (weld "0" (numb:hu minute))
      (numb:hu minute)
    (crip "{weekday} {year}-{month}-{day} {(numb:hu hour-12)}:{minute-str}{?:(is-pm "pm" "am")} {(trip user-timezone)}")
  ::  Build system prompt
  =/  ship-name=@t  (scot %p our.bowl)
  =/  total-messages=@ud  (lent full-history)
  =/  context-messages=@ud  (lent history)
  =/  context-chars=@ud
    %-  roll  :_  add
    %+  turn  history
    |=(msg=message:claude (count-message-chars msg))
  =/  context-truncated=?  !=(total-messages context-messages)
  =/  chat-id-text=@t  (crip (hexn:hu id.chat))
  =/  chat-ranges=tape
    ?~  history  "no messages"
    (build-chat-ranges history)
  =/  time-range=tape
    ?~  history  ""
    =/  first-time=@ud  timestamp.i.history
    =/  last-time=@ud  timestamp:(rear history)
    =/  first-da=@da  (from-unix-ms:chrono:userlib first-time)
    =/  last-da=@da  (from-unix-ms:chrono:userlib last-time)
    "{(en:datetime-local:iso-8601 first-da)} to {(en:datetime-local:iso-8601 last-da)} UTC"
  =/  open-loops-guide=@t
    %+  rap  3
    :~  '\0a\0a'
        'OPEN LOOPS SYSTEM: '
        'You have access to an "open loops" task tracking system with two key purposes:\0a'
        '1. FOR YOURSELF: Track your own intentions, planned work, open questions, and things to circle back to. Use your chat-id ('
        chat-id-text
        ') as your context name for all loops you create for yourself.\0a'
        '2. FOR THE USER: Proactively capture the user\'s stated intentions, goals, or duties as open loops. When you notice the user mentioning something they need to do, offer to track it.\0a'
        'Label liberally but judiciously. Capture rich implied context about various aspects of the open loop using labels.'
        '\0a'
        'LABEL TAXONOMY (use colon-separated namespaces):\0a'
        '- energy:low / energy:medium / energy:high - cognitive load required\0a'
        '- focus:shallow / focus:deep - attention depth needed\0a'
        '- time:5m / time:30m / time:2h / time:1d / time:1w - estimated duration\0a'
        '- type:bug / type:feature / type:refactor / type:docs / type:research / type:admin\0a'
        '- status:blocked / status:waiting - for tasks that cannot proceed\0a'
        '- domain:hoon / domain:urbit / domain:web / domain:learning / etc. - subject area\0a'
        'You can invent new fields and evolve these patterns as needed. Multiple labels are encouraged.\0a'
        '\0a'
        'BEST-BY vs URGENCY: Instead of labeling something "urgent", ask the user "When would you like this done by?" and set a best-by date if they provide one.\0a'
        '\0a'
        'CONTEXT NAMING: Use meaningful context names - typically the username for user tasks, your chat-id for your own work, or project/domain names for shared work.'
    ==
  =/  system-prompt=@t
    %+  rap  3
    :~  'REAL-TIME SYSTEM INFORMATION (updated with every message): '
        'You are '
        ai-model
        ', a helpful AI assistant integrated with Urbit ship '
        ship-name
        '. '
        'Urbit is a peer-to-peer operating system and network. This integration runs as a native Hoon application on the user\'s personal server (their "ship"), which calls your API. '
        'Through this integration, you have access to tools that can interact with their Urbit system and other Urbit applications and ships on the network. '
        'The user is interacting with you through a web interface served by their ship. '
        'Current time: '
        current-time
        ' (LIVE - this is the actual current time right now). '
        'Chat ID: '
        chat-id-text
        '. '
        'Context: '
        (crip (a-co:co context-messages))
        '/'
        (crip (a-co:co total-messages))
        ' messages, '
        (crip (a-co:co context-chars))
        '/'
        (crip (a-co:co max-context-chars))
        ' chars'
        ?:(context-truncated ' [TRUNCATED]' '')
        '. '
        'Messages in context (format [chat-id:msg-index-range:char-range] (ISO-8601-start to ISO-8601-end UTC)): '
        (crip chat-ranges)
        ?~(history '' (crip " ({time-range})"))
        '. '
        'INSTRUCTIONS: '
        'Use the rename_chat tool ONCE after the first message to give this conversation a descriptive 3-5 word title, and then only use it again at the user\'s explicit request thereafter.'
        open-loops-guide
        ?:(=('' system-instructions.chat) '' (cat 3 ' ' system-instructions.chat))
    ==
  ::  Build request params
  =/  request-params=(list [cord json])
    %-  zing
    :~  :~  ['model' s+model.chat]
            ['max_tokens' n+(crip (a-co:co max-tokens.chat))]
            ['system' s+system-prompt]
            ['messages' a+messages-json]
            ['tools' a+claude-tools]
        ==
        ?:  =(stop-sequences.chat ~)  ~
        ~[['stop_sequences' a+(turn stop-sequences.chat |=(s=@t s+s))]]
        ?~  tool-choice.chat  ~
        =/  tc-json=json
          ?-  -.u.tool-choice.chat
            %auto  (pairs:enjs:format ~[['type' s+'auto']])
            %any   (pairs:enjs:format ~[['type' s+'any']])
            %tool  (pairs:enjs:format ~[['type' s+'tool'] ['name' s+name.u.tool-choice.chat]])
          ==
        ~[['tool_choice' tc-json]]
    ==
  =/  body=@t
    %-  en:json:html
    (pairs:enjs:format request-params)
  =/  body-octs=octs  (as-octs:mimes:html body)
  =/  =request:http
    :*  %'POST'
        'https://api.anthropic.com/v1/messages'
        :~  ['x-api-key' api-key]
            ['anthropic-version' '2023-06-01']
            ['content-type' 'application/json']
        ==
        `body-octs
    ==
  ;<  response-body=@t  bind:m  (fetch:io request)
  ::  Parse JSON response
  =/  jon=(unit json)  (de:json:html response-body)
  ?~  jon
    (pure:m [(crip "Error: Could not parse Claude response: {(trip response-body)}") chat])
  ::  Check if response is an error
  =/  error-check
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['type' so:dejs:format]
    ==
  ?:  ?&  ?=(%& -.error-check)
          =(p.error-check 'error')
      ==
    =/  error-msg
      %-  mule
      |.
      %.  u.jon
      %-  ot:dejs:format
      :~  :-  'error'
          %-  ot:dejs:format
          :~  ['message' so:dejs:format]
              ['type' so:dejs:format]
          ==
      ==
    =/  [err-text=@t is-rate-limit=?]
      ?:  ?=(%| -.error-msg)
        ['Claude API error (could not parse details)' %.n]
      =/  [msg=@t typ=@t]  p.error-msg
      :-  (crip "Claude API {(trip typ)}: {(trip msg)}")
      =(typ 'rate_limit_error')
    ?.  is-rate-limit
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl-err)
      =/  error-timestamp=@ud
        =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
        ?~  all-timestamps  (unm:chrono:userlib now.bowl)
        (add (snag 0 (flop all-timestamps)) 1)
      =/  error-content=json
        :-  %a
        :~  %-  pairs:enjs:format
            :~  ['type' s+'text']
                ['text' s+err-text]
            ==
        ==
      =/  error-msg=message:claude  ['assistant' error-content %error id.chat 0 0 0 0]
      ;<  chat-with-error=chat:claude  bind:m
        (add-message-to-chat id.chat error-timestamp chat error-msg)
      (pure:m [err-text chat-with-error])
    (fiber-fail:io %rate-limit-error err-text ~)
  ::  Check stop_reason
  =/  stop-reason
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['stop_reason' so:dejs:format]
    ==
  ?:  ?=(%| -.stop-reason)
    ~&  >  'Failed to parse stop_reason'
    ~&  >  p.stop-reason
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error parsing stop_reason. Full JSON: {(trip json-dump)}") chat])
  ::  Handle tool_use
  ?:  =(p.stop-reason 'tool_use')
    =/  content-array
      %-  mule
      |.
      %.  u.jon
      %-  ot:dejs:format
      :~  ['content' same]
      ==
    ?:  ?=(%| -.content-array)
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: Could not parse content array. Full JSON: {(trip json-dump)}") chat])
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl-tool)
    =/  last-timestamp=@ud
      =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
      ?~  all-timestamps  (unm:chrono:userlib now.bowl)
      (add (snag 0 (flop all-timestamps)) 1)
    =/  assistant-timestamp=@ud  last-timestamp
    =/  content-blocks
      %-  mule
      |.
      %.  p.content-array
      %-  ar:dejs:format
      |=  block=json
      ^-  [type=@t data=json]
      =/  block-type
        %.  block
        %-  ot:dejs:format
        :~  ['type' so:dejs:format]
        ==
      [block-type block]
    ?:  ?=(%| -.content-blocks)
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: Could not parse content blocks. Full JSON: {(trip json-dump)}") chat])
    =/  tool-calls=(list [@t @t json])
      %+  murn  p.content-blocks
      |=  [type=@t block=json]
      ^-  (unit [@t @t json])
      ?.  =(type 'tool_use')  ~
      =/  parsed
        %-  mule
        |.
        %.  block
        %-  ot:dejs:format
        :~  ['id' so:dejs:format]
            ['name' so:dejs:format]
            ['input' same]
        ==
      ?:  ?=(%| -.parsed)  ~
      `p.parsed
    ?:  =(~ tool-calls)
      =/  json-dump=@t  (en:json:html u.jon)
      (pure:m [(crip "Error: No tool calls found in tool_use response. Full JSON: {(trip json-dump)}") chat])
    =/  allowed-calls=(list [@t @t json])
      %+  skim  tool-calls
      |=  [tool-id=@t tool-name=@t tool-input=json]
      (~(has in allowed-tools.chat) tool-name)
    =/  pending-calls=(list [@t @t json])
      %+  skip  tool-calls
      |=  [tool-id=@t tool-name=@t tool-input=json]
      (~(has in allowed-tools.chat) tool-name)
    =/  assistant-msg=message:claude  ['assistant' p.content-array %normal id.chat 0 0 0 0]
    ;<  chat-with-assistant=chat:claude  bind:m
      (add-message-to-chat id.chat assistant-timestamp chat assistant-msg)
    =/  pending-requests=(list tool-request:claude)
      %+  turn  pending-calls
      |=  [tool-id=@t tool-name=@t tool-input=json]
      [tool-id tool-name tool-input]
    ?.  =(~ pending-requests)
      ~&  >  "Added {<(lent pending-requests)>} tools to approval queue"
      =/  pending-state=pending-tools-state:claude
        [assistant-timestamp pending-requests ~]
      =/  chat-with-pending=chat:claude
        chat-with-assistant(pending-tools `pending-state)
      (pure:m ['' chat-with-pending])
    =|  tool-results=(list json)
    =/  remaining-tools=(list [@t @t json])  allowed-calls
    =/  current-chat=chat:claude  chat-with-assistant
    |-  ^-  form:m
    ?~  remaining-tools
      =/  last-timestamp=@ud
        =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.current-chat) head)
        ?~  all-timestamps  *@ud
        (snag 0 (flop all-timestamps))
      =/  tool-result-timestamp=@ud  (add last-timestamp 1)
      =/  tool-result-content=json  [%a (flop tool-results)]
      =/  user-msg=message:claude  ['user' tool-result-content %normal id.current-chat 0 0 0 0]
      =.  iteration-count.current-chat  +(iteration-count.current-chat)
      ;<  chat-with-result=chat:claude  bind:m
        (add-message-to-chat id.current-chat tool-result-timestamp current-chat user-msg)
      ?.  ?~  max-iterations.chat-with-result  %.y
          (lth iteration-count.chat-with-result u.max-iterations.chat-with-result)
        ~&  >  "Hit max-iterations limit ({<iteration-count.chat-with-result>}), stopping agentic loop"
        =/  limit-timestamp=@ud  (add tool-result-timestamp 1)
        =/  limit-msg=message:claude
          :-  'assistant'
          :-  s+'[Stopped: Hit max-iterations limit of {(scow %ud u.max-iterations.chat-with-result)}]'
          [%error id.chat-with-result 0 0 0 0]
        ;<  final-chat=chat:claude  bind:m
          (add-message-to-chat id.chat-with-result limit-timestamp chat-with-result limit-msg)
        (pure:m ['Max iterations reached' final-chat])
      ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 10))
      (send-message api-key ai-model chat-with-result chats user-timezone)
    =/  [tool-id=@t tool-name=@t tool-input=json]  i.remaining-tools
    ~&  >  "Calling tool '{<tool-name>}' for chat-id: {<id.current-chat>}"
    =/  tool-core=(unit tool:tools)  (~(get by built-ins:tools) tool-name)
    ?~  tool-core
      =/  err-json=json
        %-  pairs:enjs:format
        :~  ['type' s+'tool_result']
            ['tool_use_id' s+tool-id]
            ['content' s+(crip "Error: unknown tool '{(trip tool-name)}'")]
        ==
      $(remaining-tools t.remaining-tools, tool-results [err-json tool-results])
    =/  args=(map @t json)
      ?.  ?=([%o *] tool-input)  ~
      p.tool-input
    ;<  =tool-result:tools  bind:m  (handler:u.tool-core args)
    =/  content-text=@t
      ?-  -.tool-result
        %text   text.tool-result
        %error  (crip "Error: {(trip message.tool-result)}")
      ==
    ~&  >  "Tool '{<tool-name>}' result: {(trip content-text)}"
    =/  tr-json=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-id]
          ['content' s+content-text]
      ==
    $(remaining-tools t.remaining-tools, tool-results [tr-json tool-results], current-chat current-chat)
  ::  Normal text response
  =/  content-array
    %-  mule
    |.
    %.  u.jon
    %-  ot:dejs:format
    :~  ['content' same]
    ==
  ?:  ?=(%| -.content-array)
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Could not parse content array. Full JSON: {(trip json-dump)}") chat])
  =/  parsed
    %-  mule
    |.
    %.  p.content-array
    %-  ar:dejs:format
    %-  ot:dejs:format
    :~  ['text' so:dejs:format]
    ==
  ?:  ?=(%| -.parsed)
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Could not parse text content. Full JSON: {(trip json-dump)}") chat])
  =/  texts=(list @t)  p.parsed
  ?~  texts
    =/  json-dump=@t  (en:json:html u.jon)
    (pure:m [(crip "Error: Empty content array. Full JSON: {(trip json-dump)}") chat])
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl-resp)
  =/  last-timestamp=@ud
    =/  all-timestamps=(list @ud)  (turn (tap:((on @ud message:claude) lth) messages-by-time.chat) head)
    ?~  all-timestamps  (unm:chrono:userlib now.bowl)
    (add (snag 0 (flop all-timestamps)) 1)
  =/  assistant-timestamp=@ud  last-timestamp
  =/  assistant-msg=message:claude  ['assistant' p.content-array %normal id.chat 0 0 0 0]
  ;<  updated-chat=chat:claude  bind:m
    (add-message-to-chat id.chat assistant-timestamp chat assistant-msg)
  (pure:m [i.texts updated-chat])
--
