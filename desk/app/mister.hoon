/+  default-agent, dbug, tarball
|%
+$  versioned-state
  $%  state-0
  ==
+$  state-0  [%0 =ball:tarball]
+$  card  card:agent:gall
::
++  validate-directory
  |=  [=bowl:gall dir=path]
  ^-  (list [name=path core=vase])
  ::  1. List all files in directory (recursive)
  =/  all-files=(list path)
    .^((list path) %ct (weld /(scot %p our.bowl)/master/(scot %da now.bowl) dir))
  ::  2. Filter for .hoon files only
  =/  hoon-files=(list path)
    %+  skim  all-files
    |=(p=path =((rear p) %hoon))
  ::  3. Build each hoon file into a vase
  %+  turn  hoon-files
  |=  file-path=path
  =/  scry-path=path
    %+  weld
      /(scot %p our.bowl)/master/(scot %da now.bowl)
    file-path
  ~|  "mister: failed to compile {<file-path>} in {<dir>} - fix syntax errors to commit"
  =/  result=vase  .^(vase %ca scry-path)
  :-  file-path
  result
--
%-  agent:dbug
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%mister initialized with validation v2'
  =/  compiled-pros=(list [name=path core=vase])
    (validate-directory bowl /pro)
  =/  compiled-nexs=(list [name=path core=vase])
    (validate-directory bowl /nex)
  ~&  >  "on-init: validated {<(lent compiled-pros)>} pro files and {<(lent compiled-nexs)>} nex files"
  `this(ball *ball:tarball)
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  ~&  >  "on-load: starting"
  =/  old  !<(versioned-state old-state)
  ~&  >  "on-load: unpacked old state"
  =/  compiled-pros=(list [name=path core=vase])
    (validate-directory bowl /pro)
  =/  compiled-nexs=(list [name=path core=vase])
    (validate-directory bowl /nex)
  ~&  >  "on-load: validated {<(lent compiled-pros)>} pro files and {<(lent compiled-nexs)>} nex files"
  ?-  -.old
    %0  `this(state old)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %noun
    ~&  >  "mister poked with: {<vase>}"
    `this
  ==
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
