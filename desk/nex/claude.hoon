::  claude nexus
::
/+  nexus, tarball, io=fiberio, claude-lib=nex-claude
!:
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /main file with default claude-state
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %claude-state !>(*claude-state:claude-lib)])
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
    ;<  ~  bind:m  (rise-wait:io prod "%claude /main: failed, poke to restart")
    |-
    ;<  =cage  bind:m  take-poke:io
    ;<  state=claude-state:claude-lib  bind:m  (get-state-as:io ,claude-state:claude-lib)
    ?+    p.cage
      ~&  [%claude %unknown-poke p.cage]
      $
    ::
        %claude-state
      =/  new=claude-state:claude-lib  !<(claude-state:claude-lib q.cage)
      ;<  ~  bind:m  (replace:io !>(new))
      $
    ==
  ==
--
