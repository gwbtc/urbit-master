/+  nexus, tarball, fiberio
|%
++  default-nexi
  %-  ~(gas by *nexi:nexus)
  :~  [%root root]
  ==
::
++  root
  ^-  nexus:nexus
  |%
  ++  on-load
    |~  =ball:nexus
    ^-  ball:nexus
    (~(put ba:tarball ball) / %main [~ %sig !>(~)])
  ::
  ++  on-file
    |=  [=path =mark]
    ^-  spool:fiber:nexus
    |=  =prod:fiber:nexus
    =/  m  (fiber:fiber:nexus ,~)
    ^-  process:fiber:nexus
    ?+    path  !!
        [%main ~]
      ?:  ?=(%rise -.prod)
        %-  (slog leaf+"%root /main: failed, staying inert" tang.prod)
        stay:m
      ;<  ~  bind:m  (eyre-connect:fiberio /mister /main)
      |-
      ;<  =cage  bind:m  take-poke:fiberio
      $
    ==
  --
--
