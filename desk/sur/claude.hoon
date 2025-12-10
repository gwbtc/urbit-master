|%
+$  message
  $:  role=@t
      content=json  ::  Can be string or array of content blocks
      type=?(%normal %error)  ::  Message type for UI styling
      chat-id=@ux  ::  Which chat this message belongs to
      index=@ud  ::  Sequential index in this chat
      timestamp=@ud  ::  When message was created
      cumulative-chars=@ud  ::  Cumulative character count at beginning of this message
      chars=@ud  ::  Character count of this message
  ==
::
:: Conversation Branching Strategy:
::
:: Each chat can be branched from any message, creating a tree of conversations.
:: When a chat is branched:
::   1. New chat is created with parent link (chat-id + message index of branch point)
::   2. Parent chat adds child's ID to its children map (doubly-linked)
::   3. Child conversation inherits context from all ancestors up to branch points
::
:: Context Building for API Calls:
::   - Walk up parent chain: current -> parent -> grandparent -> ...
::   - For each ancestor, include messages from start up to branch point
::   - Concatenate: ancestor[0..branch1] + parent[0..branch2] + current[all]
::   - Apply character cap (~50k chars / ~12k tokens) to fit in context window
::   - If over cap: trim oldest ancestor messages first, always keep current chat
::   - Use messages-by-chars mop to efficiently find trim points
::
:: UI Elements:
::   - Each message has "Branch from here" button
::   - Sidebar shows conversation tree with parent/child relationships
::   - Branch icon/indicator shows which message was branched from
::   - Children map shows: message-index -> chat-id (which message spawned which child)
::
:: MCP Integration:
::   - Tools can traverse conversation tree
::   - Query sibling branches, alternative approaches
::   - Access full conversation history across tree
::
+$  tool-request
  $:  id=@t        ::  Claude's tool_id (e.g., "toolu_abc123")
      name=@t      ::  Tool name (e.g., "web_search")
      input=json   ::  Tool arguments
  ==
::
+$  tool-result
  $:  request=tool-request
      result=$%([%success text=@t] [%error message=@t])
  ==
::
+$  pending-tools-state
  $:  assistant-timestamp=@ud           ::  Timestamp of assistant message with tool_use blocks
      pending=(list tool-request)       ::  Tools awaiting user approval/denial
      approved=(list tool-result)       ::  Tools approved and executed, results ready
  ==
::
+$  chat-0
  $:  %0
      id=@ux
      name=@t
      parent=(unit [chat-id=@ux branch-point=@ud])  :: (unit [parent-chat-id branch-message-index])
      children=(map @ud @ux)                         :: map from message-index to child-chat-id
      messages-by-time=((mop @ud message) lth)     :: keyed by Unix ms timestamp
      messages-by-index=((mop @ud message) lth)    :: keyed by sequential index
      messages-by-chars=((mop @ud message) lth)    :: keyed by cumulative character count
      next-index=@ud                                       :: next message index to assign
      total-chars=@ud                                      :: total character count so far
      api-request-pid=(unit @ta)                            :: fiber PID of in-flight API request
      pending-tools=(list tool-request)                     :: queue of tools awaiting approval
      allowed-tools=(set @t)                                :: tool names that are auto-approved
      created=@da
  ==
::
+$  chat-1
  $:  %1
      id=@ux
      name=@t
      parent=(unit [chat-id=@ux branch-point=@ud])
      children=(map @ud @ux)
      messages-by-time=((mop @ud message) lth)
      messages-by-index=((mop @ud message) lth)
      messages-by-chars=((mop @ud message) lth)
      next-index=@ud
      total-chars=@ud
      api-request-pid=(unit @ta)
      pending-tools=(list tool-request)
      allowed-tools=(set @t)
      pending-assistant-response=(unit [timestamp=@ud content=json])  :: assistant response awaiting tool approval
      created=@da
  ==
::
+$  chat-2
  $:  %2
      id=@ux
      name=@t
      parent=(unit [chat-id=@ux branch-point=@ud])
      children=(map @ud @ux)
      messages-by-time=((mop @ud message) lth)
      messages-by-index=((mop @ud message) lth)
      messages-by-chars=((mop @ud message) lth)
      next-index=@ud
      total-chars=@ud
      api-request-pid=(unit @ta)
      pending-tools=(unit pending-tools-state)  :: All tools from one assistant message
      allowed-tools=(set @t)
      created=@da
  ==
::
+$  tool-choice
  $%  [%auto ~]           ::  Claude decides whether to use tools
      [%any ~]            ::  Claude MUST use a tool (but can pick which)
      [%tool name=@t]     ::  Claude MUST use THIS specific tool
  ==
::
+$  chat-3
  $:  %3
      ::  Identity
      id=@ux
      name=@t
      created=@da

      ::  === CLAUDE API PARAMETERS ===
      ::  These map directly to the API request body

      model=$~('claude-sonnet-4-5-20250929' @t)
      max-tokens=$~(1.024 @ud)
      temperature=$~(.~1.0 @rd)
      top-p=$~(.~1.0 @rd)
      top-k=@ud
      system-instructions=@t              ::  Custom instructions (appended to live info)
      stop-sequences=(list @t)            ::  Stop generation triggers
      tool-choice=(unit tool-choice)      ::  How to select tools (~ = auto)

      ::  === MESSAGES ===
      ::  The conversation history

      messages-by-time=((mop @ud message) lth)
      messages-by-index=((mop @ud message) lth)
      messages-by-chars=((mop @ud message) lth)
      next-index=@ud
      total-chars=@ud

      ::  === BRANCHING ===
      ::  Conversation tree structure

      parent=(unit [chat-id=@ux branch-point=@ud])
      children=(map @ud @ux)

      ::  === RUNTIME STATE ===
      ::  Current execution state

      api-request-pid=(unit @ta)
      pending-tools=(unit pending-tools-state)
      allowed-tools=(set @t)              ::  Which tools auto-approve (empty = chat mode)

      ::  === AGENT SAFETY ===
      ::  Loop control

      max-iterations=(unit @ud)           ::  ~ = unlimited, `N = stop after N loops
      iteration-count=@ud                 ::  Current loop count
  ==
::
+$  chat  chat-3
::
::  Migration helpers
::
++  chat-2-to-3
  |=  old=chat-2
  ^-  chat-3
  :*  %3
      id.old
      name.old
      created.old
      ::  API parameters (use defaults)
      'claude-sonnet-4-5-20250929'  ::  model
      1.024 ::  max-tokens
      .~1.0 ::  temperature
      .~1.0 ::  top-p
      0 ::  top-k
      '' ::  system-instructions (empty)
      ~ ::  stop-sequences (empty list)
      ~ ::  tool-choice (auto)
      ::  Messages (preserve)
      messages-by-time.old
      messages-by-index.old
      messages-by-chars.old
      next-index.old
      total-chars.old
      ::  Branching (preserve)
      parent.old
      children.old
      ::  Runtime state (preserve)
      api-request-pid.old
      pending-tools.old
      allowed-tools.old
      ::  Agent safety (new fields)
      ~ ::  max-iterations (unlimited)
      0 ::  iteration-count (start at 0)
  ==
--
