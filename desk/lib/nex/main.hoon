/+  nexus, tarball, fiberio, server, nex-server
|%
++  default-nexi
  %-  ~(gas by *nexi:nexus)
  :~  [%root root]
      [%server main:nex-server]
      [%requests requests:nex-server]
  ==
::
++  root
  ^-  nexus:nexus
  |%
  ++  on-load
    |~  =ball:nexus
    ^-  ball:nexus
    ::  Create /main file
    =.  ball  (~(put ba:tarball ball) / %main [~ %sig !>(~)])
    ::  Create /server directory with neck=%server
    (~(put of ball) /server [~ `%server ~])
  ::
  ++  on-file
    |=  [=path name=@ta =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?+    [path name]  !!
        [~ %main]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%root /main: failed, staying inert" tang.prod)
        stay:m
      ::  Bind eyre to /server/main
      ;<  ~  bind:m  (eyre-connect:fiberio /mister /server/main)
      stay:m
    ==
  --
--
