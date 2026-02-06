::  usergroups nexus: role-based weir management via tree state
::
/+  nexus, tarball
|%
++  usergroups
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    ::  Create /main file (weir manager process)
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
    ::  Create /who - group membership sets
    =.  ball  (~(put of ball) /who [~ ~ ~])
    ::  Create /how - weir templates per group
    =.  ball  (~(put of ball) /how [~ ~ ~])
    ::  Create /src - per-ship group index (bidirectional)
    =.  ball  (~(put of ball) /src [~ ~ ~])
    ::  Create /pub - public weir template
    =.  ball  (~(put of ball) /pub [~ ~ ~])
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
        %-  (slog leaf+"%usergroups /main: failed, staying inert" tang.prod)
        stay:m
      stay:m
    ==
  --
--
