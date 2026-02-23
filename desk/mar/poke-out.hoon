::  poke-out: outbound poke to agent on foreign ship
::
::  Target agent name + cage payload. The gateway at
::  /peers/ships/~ship/main sends the poke via Gall.
::
!: :: turn on stack trace
|_  [=dude:gall =cage]
++  grab
  |%
  ++  noun  ,[dude:gall ^cage]
  --
++  grow
  |%
  ++  noun  [dude cage]
  --
++  grad  %noun
--
