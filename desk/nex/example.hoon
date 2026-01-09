/+  nexus
|_  =bowl:nexus
++  on-load
  |=  state=ball:nexus
  ^-  ball:nexus
  ::  Create main.sig file to handle nexus API
  ::  The %sig mark indicates this is a "signal handler" process
  (~(put ba:tarball state) ~ %main [~ %sig !>(~)])
::
++  on-file
  |=  [=path =mark]
  ^-  process:fiber:nexus
  ::  Route based on path
  ?+    path  !!
      [%main ~]
    ::  Main process - handles the nexus API
    ::  This runs as an event loop, processing intakes
    |=  =input:fiber:nexus
    ^-  output:fiber:nexus
    :+  ~  state.input
    ?+  in.input  [%skip ~]
        ~  [%wait ~]  :: Start - just wait for input
      ::
        [~ %poke @ *]
      ::  Handle a poke to this nexus
      ::  For now, just acknowledge it
      ~&  >  "example nexus got poke: {<cage.u.in.input>}"
      [%wait ~]
      ::
        [~ %watch *]
      ::  Handle a subscription
      ~&  >  "example nexus got watch: {<path.u.in.input>}"
      [%wait ~]
      ::
        [~ %leave *]
      ::  Handle unsubscribe
      ~&  >  "example nexus got leave: {<path.u.in.input>}"
      [%wait ~]
    ==
  ==
--
