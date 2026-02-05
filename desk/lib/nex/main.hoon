/+  nexus, tarball, server, nex-server, nex-counter
|%
++  default-nexi
  %-  ~(gas by *nexi:nexus)
  :~  [%root root]
      [%server main:nex-server]
      [%counter counter:nex-counter]
      [%counter-ui counter-ui:nex-counter]
  ==
::
++  root
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    ::  Create /main file
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
    ::  Create /server directory with neck=%server
    =.  ball  (~(put of ball) /server [~ `%server ~])
    ::  Create /counter directory with neck=%counter
    =.  ball  (~(put of ball) /counter [~ `%counter ~])
    ::  Create /public directory - entry point for external pokes
    ::  Blocking weir [~ ~ ~] until explicitly configured
    =.  ball  (~(put of ball) /public [~ ~ ~])
    =.  sand  (~(put of sand) /public [~ ~ ~])
    ::  Create /peers directory - entry point for per-ship external pokes
    ::  Blocking weir [~ ~ ~] until explicitly configured
    =.  ball  (~(put of ball) /peers [~ ~ ~])
    =.  sand  (~(put of sand) /peers [~ ~ ~])
    [sand ball]
  ::
  ++  on-file
    |=  [=rail:tarball =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?+    rail  stay:m
        [~ %main]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%root /main: failed, staying inert" tang.prod)
        stay:m
      stay:m
    ==
  --
--
