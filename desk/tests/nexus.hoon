/+  *test, nexus, tarball
|%
::  ==========================================
::  +relativize-from tests
::  ==========================================
::
++  test-relativize-from-external-passthrough
  ::  External source passes through unchanged
  =/  here=rail:tarball  [/a/b %file]
  =/  =from:nexus  [%| [src=~zod sap=/some/path]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%| [src=~zod sap=/some/path]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-same-dir
  ::  Source in same directory - 0 steps
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [%& [/a/b %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [0 [/ %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-sibling-dir
  ::  Source in sibling directory - 1 step up
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [%& [/a/c %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [1 [/c %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-parent-dir
  ::  Source in parent directory - 2 steps up
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [%& [/a %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [2 [/ %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-child-dir
  ::  Source in child directory - 0 steps (going down)
  =/  here=rail:tarball  [/a %dest]
  =/  =from:nexus  [%& [/a/b/c %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [0 [/b/c %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-distant
  ::  Source far away - multiple steps
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [%& [/x/y/z %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [3 [/x/y/z %src]]]
  !>  (relativize-from:nexus here from)
::
::  ==========================================
::  +raw-filter tests
::  ==========================================
::
++  test-raw-filter-empty
  ::  Empty allowed list returns false
  %+  expect-eq
    !>  %.n
  !>  (raw-filter:nexus /a/b/c ~)
::
++  test-raw-filter-allowed
  ::  Dest under allowed prefix returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus /a/b/c ~[/a/b])
::
++  test-raw-filter-exact-match
  ::  Dest exactly matches allowed returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus /a/b ~[/a/b])
::
++  test-raw-filter-not-allowed
  ::  Dest not under any allowed prefix returns false
  %+  expect-eq
    !>  %.n
  !>  (raw-filter:nexus /a/b/c ~[/x/y])
::
++  test-raw-filter-multiple-prefixes
  ::  Multiple allowed prefixes - matches second
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus /x/y/z ~[/a/b /x/y])
::
++  test-raw-filter-root-allows-all
  ::  Root prefix allows everything
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus /a/b/c ~[/])
::
::  ==========================================
::  +filter-roads tests
::  ==========================================
::
++  test-filter-roads-absolute
  ::  Absolute road resolves and filters
  =/  here=fold:tarball  /somewhere
  =/  dest=path  /a/b/c
  =/  roads=(list road:tarball)  ~[[%& [%| /a/b]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-relative
  ::  Relative road resolves from here
  =/  here=fold:tarball  /a/b
  =/  dest=path  /a/c/d
  ::  From /a/b, go up 1 to /a, then /c allows /a/c/*
  =/  roads=(list road:tarball)  ~[[%| [1 [%| /c]]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-not-allowed
  ::  Dest not under any resolved road
  =/  here=fold:tarball  /a/b
  =/  dest=path  /x/y/z
  =/  roads=(list road:tarball)  ~[[%& [%| /a]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-exact-match
  ::  File (rail) requires exact match - dest equals file path
  =/  here=fold:tarball  /somewhere
  =/  dest=path  /a/b/file
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-no-prefix-match
  ::  File (rail) does NOT allow prefix matching - child path rejected
  =/  here=fold:tarball  /somewhere
  =/  dest=path  /a/b/file/child
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-not-exact
  ::  File (rail) rejects different file in same dir
  =/  here=fold:tarball  /somewhere
  =/  dest=path  /a/b/other
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-dir-prefix-match
  ::  Directory (fold) allows prefix matching
  =/  here=fold:tarball  /somewhere
  =/  dest=path  /a/b/c/d/e
  =/  roads=(list road:tarball)  ~[[%& [%| /a/b]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
::  ==========================================
::  +filter tests
::  ==========================================
::
++  test-filter-no-weir
  ::  No weir means no filter (permissive)
  %+  expect-eq
    !>  `filt:nexus`~
  !>  (filter:nexus /a/b/c %poke /here ~)
::
++  test-filter-syscall-blocked
  ::  Syscalls are always blocked by any weir
  =/  =weir:nexus  [make=~ poke=~ peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (filter:nexus /a/b/c %sysc /here `weir)
::
++  test-filter-poke-allowed
  ::  Poke to allowed destination
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /a/b]]]) peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (filter:nexus /a/b/c %poke /here `weir)
::
++  test-filter-poke-blocked
  ::  Poke to disallowed destination
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /x/y]]]) peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (filter:nexus /a/b/c %poke /here `weir)
::
++  test-filter-make-allowed
  ::  Make to allowed destination
  =/  =weir:nexus  [make=(sy ~[[%& [%| /a]]]) poke=~ peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (filter:nexus /a/b/c %make /here `weir)
::
++  test-filter-peek-blocked
  ::  Peek to disallowed destination
  =/  =weir:nexus  [make=~ poke=~ peek=(sy ~[[%& [%| /other]]])]
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (filter:nexus /a/b/c %peek /here `weir)
::
::  ==========================================
::  +next-filt tests
::  ==========================================
::
++  test-next-filt-both-permissive
  ::  Both ~ returns ~
  %+  expect-eq
    !>  `filt:nexus`~
  !>  (next-filt:nexus ~ ~)
::
++  test-next-filt-first-permissive
  ::  First ~ returns second
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus ~ [~ &])
::
++  test-next-filt-second-permissive
  ::  Second ~ returns first
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus [~ &] ~)
::
++  test-next-filt-first-veto
  ::  First veto wins
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ |] [~ &])
::
++  test-next-filt-second-veto
  ::  Second veto wins
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ &] [~ |])
::
++  test-next-filt-both-allow
  ::  Both allow returns allow
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus [~ &] [~ &])
::
++  test-next-filt-both-veto
  ::  Both veto returns veto
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ |] [~ |])
::
--
