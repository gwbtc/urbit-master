::  counter nexus: demo of ticking state + subscriptions
::
/+  nexus, tarball, fiberio
|%
++  counter
  ^-  nexus:nexus
  |%
  ++  on-load
    |=  [=sand:nexus =ball:tarball]
    ^-  [sand:nexus ball:tarball]
    ::  Create /main file (the counter)
    =.  ball  (~(put ba:tarball ball) [/ %main] [~ %ud !>(0)])
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
      :: pretty print error
      ;<  ~  bind:m  ?.  ?=(%rise -.prod)  (pure:m ~)
        (trace:fiberio leaf+"%counter /main: failed" tang.prod)
      ::  Wait for a poke to start ticking
      |-
      ;<  =cage  bind:m  take-poke:fiberio
      ?.  =(%counter-start p.cage)
        ~&  [%counter %unknown-poke p.cage]
        $
      ::  Reset to 0 and tick
      ;<  ~  bind:m  (replace:fiberio !>(0))
      |-
      ;<  count=@ud  bind:m  (get-state-as:fiberio ,@ud)
      ?:  (gte count 10)
        ~&  [%counter %done count]
        ^$
      ;<  ~  bind:m  (sleep:fiberio ~s1)
      ~&  [%counter %tick +(count)]
      ;<  ~  bind:m  (replace:fiberio !>(+(count)))
      $
    ==
  --
--
