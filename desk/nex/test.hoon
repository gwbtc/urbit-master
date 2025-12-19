/+  nexus
|%
++  on-load
  |=  [=bowl:gall =ball:nexus]
  ^-  [(list dart:nexus) ball:nexus]
  [~ ball]
++  on-poke
  |=  [=bowl:gall =cage]
  ^-  [(list dart:nexus) path (unit ball:nexus)]
  [~ / ~]
++  on-file
  |=  [pax=path =mark]
  ^-  proc:nexus
  mark
++  on-diff
  |=  [pax=path =cage]
  ^-  (list dart:nexus)
  ~
++  on-done
  |=  [pax=path =cage ack=(unit tang)]
  ^-  (list dart:nexus)
  ~
++  on-take
  |=  take=intake:fiber:nexus
  ^-  (list dart:nexus)
  ~
--
