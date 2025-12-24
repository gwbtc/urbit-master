/+  nexus
^-  nexus:nexus
|%
++  on-load
  |=  =ball:nexus
  ^-  [(list dart:nexus) ball:nexus]
  [~ ball]
++  on-poke
  |=  [=ball:nexus =from:nexus =cage]
  ^-  [(list dart:nexus) ball:nexus]
  [~ ball]
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
