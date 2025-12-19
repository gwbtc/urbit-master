/+  default-agent, dbug, tarball, nexus
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
::
++  store-compiled
  |=  [b=ball:tarball compiled=(list [name=path core=vase]) base=path]
  ^-  ball:tarball
  %+  roll  compiled
  |=  [[file-path=path core=vase] acc=ball:tarball]
  ::  Extract just the filename from the full path
  =/  filename=@ta  (rear file-path)
  ::  Store as %temp cage with empty metadata
  (~(put ba:tarball acc) base filename [~ [%temp core]])
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
  ::  Store compiled vases as %temp cages
  =/  new-ball=ball:tarball
    =/  b1  (store-compiled *ball:tarball compiled-pros /temp/pro)
    (store-compiled b1 compiled-nexs /temp/nex)
  ~&  >  "on-init: stored compiled files as %temp cages"
  `this(ball new-ball)
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
  ::  Clear all %temp cages from previous session
  =/  clean-ball=ball:tarball  clear-temp:~(. ba:tarball ball.old)
  ~&  >  "on-load: cleared old %temp cages"
  ::  Validate and compile fresh
  =/  compiled-pros=(list [name=path core=vase])
    (validate-directory bowl /pro)
  =/  compiled-nexs=(list [name=path core=vase])
    (validate-directory bowl /nex)
  ~&  >  "on-load: validated {<(lent compiled-pros)>} pro files and {<(lent compiled-nexs)>} nex files"
  ::  Store compiled vases as %temp cages
  =/  new-ball=ball:tarball
    =/  b1  (store-compiled clean-ball compiled-pros /temp/pro)
    (store-compiled b1 compiled-nexs /temp/nex)
  ~&  >  "on-load: stored compiled files as %temp cages"
  ?-  -.old
    %0  `this(ball new-ball)
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
