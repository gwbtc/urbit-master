/-  nexus, claude
/+  dbug, sailbox, io=sailboxio, server,
    ui-master, ui-claude, ui-ball, telegram,
    sse=sse-helpers, tarball, alarms, tools, open-loops
/=  master-routes  /lib/routes/master
/=  telegram-routes  /lib/routes/telegram
/=  s3-routes  /lib/routes/s3
/=  claude-routes  /lib/routes/claude
/=  t-  /tests/tarball
/=  m-  /mar/eyre/bindings
/=  m-  /mar/claude/chat
/=  m-  /mar/open-loops
/=  m-  /mar/road
=>
  |%
  +$  card  card:sailbox
  --
^-  agent:gall
%-  agent:dbug
%-  agent:sailbox
^-  sailbox:sailbox
|%
++  initial
  ^-  ball:tarball
  *ball:tarball
::
++  migrate
  |=  old=ball:tarball
  ^-  ball:tarball
  old
::
++  on-peek
  |=  [=bowl:gall state=ball:tarball =path]
  ~|  "unexpected scry into {<dap.bowl>} on path {<path>}"
  :: [~ ~]
  ?+  path  [~ ~]
    [%x %dbug %state ~]  ``ball+!>(state)
  ==
::
++  process
  =/  m  (fiber:io ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  src=@p  bind:m  get-poke-guest:io
  ~&  our+our
  ~&  src+src
  ?.  =(our src)  (fiber-fail:io leaf+"not us" ~)
  ;<  [=mark =vase]  bind:m  get-poke:io
  ?+    mark  !!
      %on-fail :: sent by sailbox
    =+  !<([=term =tang] vase)
    (pure:m ~)
    ::
      %on-init :: sent by sailbox
    ;<  ball=ball:tarball  bind:m  get-state:io
    ;<  =bowl:gall  bind:m  get-bowl:io
    ::  Create /config and /config/creds directories
    ;<  ~  bind:m  (mkd:io /config)
    ;<  ~  bind:m  (mkd:io /config/creds)
    ::  Set default timezone to UTC with correct type (wain)
    ;<  ~  bind:m  (put-cage:io /config 'timezone.txt' [%txt !>(~['UTC'])])
    ::  Set default eyre bindings
    =/  default-bindings=(list binding:eyre)  ~[[~ /master]]
    ;<  ~  bind:m  (put-cage:io /config 'bindings.eyre-bindings' [%eyre-bindings !>(default-bindings)])
    ::  Create /state directory and initialize counter
    ;<  ~  bind:m  (mkd:io /state)
    ;<  ~  bind:m  (put-cage:io /state 'counter.ud' [%ud !>(0)])
    ::  Create /processes/commits and /processes/alarms directories
    ;<  ~  bind:m  (mkd:io /processes)
    ;<  ~  bind:m  (mkd:io /processes/commits)
    ;<  ~  bind:m  (mkd:io /processes/alarms)
    ::  Create /claude directory for chats and active chat
    ;<  ~  bind:m  (mkd:io /claude)
    ;<  ~  bind:m  (mkd:io /claude/chats)
    ::  Initialize active-chat as empty (no active chat)
    ;<  ~  bind:m  (put-cage:io /claude 'active-chat.txt' [%txt !>(~)])
    ::  Set bindings (just use the default we created)
    (set-bindings:io default-bindings)
    ::
      %on-load :: sent by sailbox
    ;<  ball=ball:tarball  bind:m  get-state:io
    ::  Read bindings from config and set them (with fallback if not found)
    =/  bindings=(list binding:eyre)
      =/  maybe-bindings=(unit (list binding:eyre))
        (~(get-cage-as ba:tarball ball) /config 'bindings.eyre-bindings' ,(list binding:eyre))
      ?~  maybe-bindings
        ~[[~ /master]]  ::  fallback to default
      u.maybe-bindings
    ;<  ~  bind:m  (set-bindings:io bindings)
    ::  Explicitly migrate old chat versions to chat-3
    =/  chat-files=(list @ta)
      (~(lis ba:tarball ball) /claude/chats)
    |-
    ?~  chat-files
      (pure:m ~)
    ::  Skip non-.claude-chat files
    =/  filename=tape  (trip i.chat-files)
    =/  ext-length=@ud  12
    ?.  ?&  (gte (lent filename) ext-length)
            =(".claude-chat" (slag (sub (lent filename) ext-length) filename))
        ==
      $(chat-files t.chat-files)
    ::  Read as noun and check version
    =/  maybe-noun=(unit *)
      (~(get-cage-as ba:tarball ball) /claude/chats i.chat-files *)
    ?~  maybe-noun
      $(chat-files t.chat-files)
    ::  Check version tag and migrate if needed
    =/  tagged  ;;([version=?(%0 %1 %2 %3) *] u.maybe-noun)
    ?:  =(version.tagged %3)
      $(chat-files t.chat-files)  ::  Already migrated
    ::  Migrate to chat-3
    =/  migrated=chat:claude
      ?-  version.tagged
          %3  !!  ::  Never happens, already filtered above
          %2
        =/  old  ;;(chat-2:claude u.maybe-noun)
        (chat-2-to-3:claude old)
          %1
        =/  old  ;;(chat-1:claude u.maybe-noun)
        =/  v2=chat-2:claude
          :*  %2
              id.old  name.old  parent.old  children.old
              messages-by-time.old  messages-by-index.old  messages-by-chars.old
              next-index.old  total-chars.old  api-request-pid.old
              ~  ::  pending-tools empty
              allowed-tools.old  created.old
          ==
        (chat-2-to-3:claude v2)
          %0
        =/  old  ;;(chat-0:claude u.maybe-noun)
        =/  v2=chat-2:claude
          :*  %2
              id.old  name.old  parent.old  children.old
              messages-by-time.old  messages-by-index.old  messages-by-chars.old
              next-index.old  total-chars.old  api-request-pid.old
              ~  ::  pending-tools empty
              allowed-tools.old  created.old
          ==
        (chat-2-to-3:claude v2)
      ==
    ::  Write back as chat-3
    ;<  ~  bind:m
      (put-cage:io /claude/chats i.chat-files [%claude-chat !>(migrated)])
    $(chat-files t.chat-files)
    ::
      %set-binding
    =+  !<(new-binding=binding:eyre vase)
    ;<  ball=ball:tarball  bind:m  get-state:io
    ::  Read current bindings from config
    =/  current-bindings=(list binding:eyre)
      (~(got-cage-as ba:tarball ball) /config 'bindings.eyre-bindings' ,(list binding:eyre))
    ::  Add new binding if not already present
    =/  updated-bindings=(list binding:eyre)
      ?:  (lien current-bindings |=(b=binding:eyre =(b new-binding)))
        current-bindings
      [new-binding current-bindings]
    ::  Write updated bindings back to config
    ;<  ~  bind:m  (put-cage:io /config 'bindings.eyre-bindings' [%eyre-bindings !>(updated-bindings)])
    (set-bindings:io updated-bindings)
    ::
      %execute-scheduled-tool
    =+  !<([tool-name=@t tool-arguments=json] vase)
    =/  args-map=(map @t json)
      ?:  ?=([%o *] tool-arguments)  p.tool-arguments
      ~
    ;<  result=tool-result:tools  bind:m  (execute-tool:tools tool-name args-map)
    ~&  >>  "Scheduled tool {<tool-name>} executed: {<result>}"
    (pure:m ~)
    ::
      %set-alarm
    =+  !<([wake-time=@da tool-name=@t tool-arguments=json repeat-count=@ud interval=@dr] vase)
    =/  rule=recurrence-rule:alarms  [wake-time repeat-count interval %.y]
    (run-alarm:alarms rule tool-name tool-arguments)
    ::
      %handle-http-request
    =+  !<(req=inbound-request:eyre vase)
    ;<  =bowl:gall  bind:m  get-bowl:io
    =/  lin=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.lin
    ::  Route based on HTTP method
    ?:  ?=(%'GET' method.request.req)
      (handle-get-request:master-routes req bowl)
    ::  Parse POST content-type
    =/  content-type=(unit @t)
      (get-header:http 'content-type' header-list.request.req)
    ::  Route JSON POSTs
    ?:  ?=([~ %'application/json'] content-type)
      (handle-json-request:master-routes req site)
    ::  Route multipart POSTs (file uploads)
    ?:  ?&  ?=(^ content-type)
            =('multipart/form-data; boundary=' (end 3^30 u.content-type))
        ==
      (handle-multipart-request:master-routes req site)
    ::  Route form-encoded POSTs
    (handle-form-request:master-routes req site)
  ==
::
++  first-sse-event
  |=  $:  site=(list @t)
          args=(list [key=@t value=@t])
          last-event-id=(unit @t)
      ==
  ^-  (unit sse-key:sailbox)
  ?+    site  ~
    [%master %test-sse ~]          `[~ `'/test/counter']
    [%master %claude %stream @ ~]  ~
  ==
::
++  make-sse-event
  |=  $:  =bowl:gall
          state=ball:tarball
          site=(list @t)
          args=(list [key=@t value=@t])
          id=(unit @t)
          event=(unit @t)
      ==
  ^-  wain
  ?+    site  !!
      [%master %test-sse ~]
    (handle-simple-sse:ui-master bowl state args id event)
    ::
      [%master %claude %stream @ ~]
    =/  chat-id=@ux  (rash i.t.t.t.site hex)
    (handle-claude-sse:ui-claude bowl state chat-id args id event)
  ==
--
