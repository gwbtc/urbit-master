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
+$  chat  chat-2
--
