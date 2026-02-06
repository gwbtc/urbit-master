/+  nexus, tarball
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /main file if not present
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
  ::  Create /server directory with neck=%server
  =?  ball  =(~ (~(get of ball) /server))
    (~(put of ball) /server [~ `%server ~])
  ::  Create /counter directory with neck=%counter
  =?  ball  =(~ (~(get of ball) /counter))
    (~(put of ball) /counter [~ `%counter ~])
  ::  Create /explorer directory with neck=%explorer
  =?  ball  =(~ (~(get of ball) /explorer))
    (~(put of ball) /explorer [~ `%explorer ~])
  ::  Create /public directory - entry point for external pokes
  ::  Blocking weir [~ ~ ~] until explicitly configured
  =?  ball  =(~ (~(get of ball) /public))
    (~(put of ball) /public [~ ~ ~])
  =?  sand  =(~ (~(get of sand) /public))
    (~(put of sand) /public [~ ~ ~])
  ::  Create /peers directory - entry point for per-ship external pokes
  ::  Blocking weir [~ ~ ~] until explicitly configured
  =?  ball  =(~ (~(get of ball) /peers))
    (~(put of ball) /peers [~ ~ ~])
  =?  sand  =(~ (~(get of sand) /peers))
    (~(put of sand) /peers [~ ~ ~])
  ::  Create /groups directory with neck=%usergroups
  =?  ball  =(~ (~(get of ball) /groups))
    (~(put of ball) /groups [~ `%usergroups ~])
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
