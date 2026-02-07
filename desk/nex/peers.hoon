::  peers nexus: external ship gateway + role-based access control
::
::  All foreign ship interaction enters through /peers. Each ship gets
::  a gateway process at /ships/~ship/main that receives pokes as pages,
::  converts them to cages, and forwards them into the tree. Usergroups
::  provide role-based weir management: group membership determines what
::  each ship can reach.
::
::  /peers/
::    /main          poke router + weir manager
::    /usergroups/   role-based access data
::      /who/        group → members: /who/admins → (set @p)
::      /how/        group → weir template: /how/admins → weir
::                     /how/public weir is applied to ALL ships
::    /ships/        per-ship directories, created lazily on first poke
::                     our own ship lives here too, with full tree access
::                     (skips usergroup lookup entirely)
::      /~zod/       weir derived from union of group weir templates
::        /main      gateway: page → cage, forward to destination
::
::  Poke flow:
::    1. Poke arrives at mister with [dest =page]
::    2. Mister forwards peer-poke to /peers/main
::    3. /peers/main creates /ships/~src/ dir+gateway if absent
::    4. /peers/main forwards peer-poke to /ships/~src/main
::    5. Gateway converts page to cage: [p.page !>(q.page)]
::    6. Forwards to dest — weir controls reachability, clams at boundary
::
::  Weir strategy:
::    /peers/ has a permissive weir (full tree, no syscalls). Anything
::    leaving /peers/ gets clammed. Ship dirs have tighter weirs derived
::    from usergroup membership. /peers/main watches /who, /how, and
::    /ships, recalculating and %sand'ing weirs reactively.
::
/+  nexus, tarball, io=fiberio
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      ::  Create /main file (weir manager) if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
        (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
      ::  Create /usergroups directory (role-based access data)
      =?  ball  =(~ (~(get of ball) /usergroups))
        (~(put of ball) /usergroups [~ ~ ~])
      ::  Create /usergroups/who - group membership sets
      =?  ball  =(~ (~(get of ball) /usergroups/who))
        (~(put of ball) /usergroups/who [~ ~ ~])
      ::  Create /usergroups/how - weir templates per group
      =?  ball  =(~ (~(get of ball) /usergroups/how))
        (~(put of ball) /usergroups/how [~ ~ ~])
      ::  Create /ships directory (ship dirs created lazily)
      ::  Permissive weir: ships can reach the full tree from here.
      ::  Per-ship weirs narrow access for each foreign ship.
      =?  ball  =(~ (~(get of ball) /ships))
        (~(put of ball) /ships [~ ~ ~])
      =/  root-roads=(set road:tarball)  (sy [%& %| /]~)
      =.  sand  (~(put of sand) /ships [root-roads root-roads root-roads])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ::  NOTE: we switch on rail alone because ?+ [rail mark] doesn't
      ::  narrow rail's subfaces (path.rail stays (list @ta), breaks
      ::  i.t.path.rail). Mark is asserted inside each case instead.
      ::
      ?+    rail  stay:m
        ::  /main: poke router + weir manager
        ::  Routes incoming peer-pokes to per-ship gateways,
        ::  lazily creating ship directories on first contact.
        ::  Watches /who, /how, and /ships for changes, re-syncs all
        ::  ship weirs on any change. /ships is watched to prevent
        ::  rogue weir manipulation — any unauthorized weir change
        ::  gets immediately overwritten with the correct computed
        ::  weir. set-weir is idempotent (no-op if weir unchanged),
        ::  so our own sanding triggers a second no-op sync.
        ::  TODO: consider making this more granular (e.g. use
        ::  diff-born to scope work to changed ships only) to avoid
        ::  the redundant pass.
        ::
          [~ %main]
        ?>  ?=(%sig mark)
        ;<  ~  bind:m  (rise-wait:io prod "%peers /main: failed, poke to restart")
        ~&  >  "%peers /main: starting"
        ;<  ~  bind:m  (keep:io /watch-who [%| 0 %| /usergroups/who])
        ;<  ~  bind:m  (keep:io /watch-how [%| 0 %| /usergroups/how])
        ;<  ~  bind:m  (keep:io /watch-ships [%| 0 %| /ships])
        |-
        ;<  =main-event  bind:m  take-main-event
        ?-    -.main-event
            %poke
          =/  =from:fiber:nexus  from.main-event
          =/  =cage  cage.main-event
          ?+    p.cage  $
              %peers-sync
            ~&  >  [%peers-main %sync]
            ;<  ~  bind:m  sync-all-weirs
            $
              %peer-poke
            ?.  ?=(%| -.from)
              ~&  >  [%peers-main %internal-poke-rejected]
              $
            =/  src=@p  src.p.from
            ~&  >  [%peers-main %routing (scot %p src)]
            ;<  ~  bind:m  (ensure-ship-dir src)
            ;<  ~  bind:m
              (poke:io /forward [%| 0 %& [/ships/[(scot %p src)] %main]] cage)
            $
          ==
        ::
            %news
          ~&  >  [%peers-main %change-detected wire.main-event]
          ;<  ~  bind:m  sync-all-weirs
          $
        ::
            %fell
          ~&  >  [%peers-main %fell-resubscribe wire.main-event]
          ;<  ~  bind:m
            %+  keep:io  wire.main-event
            ?:  =(/watch-who wire.main-event)  [%| 0 %| /usergroups/who]
            ?:  =(/watch-how wire.main-event)  [%| 0 %| /usergroups/how]
            [%| 0 %| /ships]
          $
        ==
        ::  /ships/*/main: per-ship gateway
        ::  Receives peer-poke [dest=rail =page], forwards cage to dest.
        ::  Weir handles auth and clamming at boundary.
        ::
          [[%ships @ ~] %main]
        ?>  ?=(%sig mark)
        ;<  ~  bind:m  (rise-wait:io prod "%peers /ships/*/main: failed, poke to restart")
        =/  ship-name=@ta  i.t.path.rail
        ~&  >  [%peers-gateway ship-name %ready]
        |-
        ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
        ?.  ?=(%peer-poke p.cage)
          ~&  >  [%peers-gateway ship-name %unknown-mark p.cage]
          $
        =/  [dest=rail:tarball =page]
          !<([rail:tarball page] q.cage)
        ~&  >  [%peers-gateway ship-name %forward dest p.page]
        =/  payload=^cage  [p.page !>(q.page)]
        ;<  ~  bind:m  (poke:io /forward [%& %& dest] payload)
        $
          [[%usergroups %who ~] @]
        ?>  ?=(%ships mark)  who-file
          [[%usergroups %how ~] @]
        ?>  ?=(%weir mark)  how-file
      ==
    --
|%
+$  main-event
  $%  [%poke =from:fiber:nexus =cage]
      [%news =wire =view:nexus]
      [%fell =wire]
  ==
::
++  take-main-event
  =/  m  (fiber:fiber:nexus ,main-event)
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in.input)]
      [~ %poke * *]
    [%done %poke [from cage]:u.in.input]
      [~ %news * *]
    [%done %news [wire view]:u.in.input]
      [~ %fell *]
    [%done %fell wire.u.in.input]
  ==
::  /usergroups/who/*: group membership
::  State: (set @p). Pokes: %put-members, %add-member, %del-member
::
++  who-file
  |=  =input:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  output:m
  ?+  in.input  [~ state.input %skip ~]
      ~  [~ state.input %wait ~]
      [~ %poke * *]
    ?+  p.cage.u.in.input  [~ state.input %skip ~]
        %put-members  [~ q.cage.u.in.input %wait ~]
        %add-member
      =/  members  !<((set @p) state.input)
      [~ !>((~(put in members) !<(@p q.cage.u.in.input))) %wait ~]
        %del-member
      =/  members  !<((set @p) state.input)
      [~ !>((~(del in members) !<(@p q.cage.u.in.input))) %wait ~]
    ==
  ==
::  /usergroups/how/*: weir templates
::  State: weir:nexus. Pokes: %put-weir
::
++  how-file
  |=  =input:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  output:m
  ?+  in.input  [~ state.input %skip ~]
      ~  [~ state.input %wait ~]
      [~ %poke * *]
    ?.  =(%put-weir p.cage.u.in.input)
      [~ state.input %skip ~]
    [~ q.cage.u.in.input %wait ~]
  ==
::  Ensure /ships/~ship/ directory exists with gateway process.
::  Our ship: no weir (full tree access).
::  Foreign ship: weir computed from current usergroups.
::
++  ensure-ship-dir
  |=  src=@p
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  =/  ship-ta=@ta  (scot %p src)
  =/  ship-dir=path  /ships/[ship-ta]
  ;<  exists=?  bind:m  (peek-exists:io /check-ship [%| 0 %| ship-dir])
  ?:  exists  (pure:m ~)
  =/  ship-ball=ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %main] [~ %sig !>(~)])
  ?:  =(src our)
    (make:io /create-ship [%| 0 %| ship-dir] &+[*sand:nexus ship-ball])
  ;<  [who=(map @ta (set @p)) how=(map @ta weir:nexus)]  bind:m
    read-usergroups
  =/  =weir:nexus  (compute-ship-weir src (build-src who) how)
  =/  ship-sand=sand:nexus  (~(put of *sand:nexus) / weir)
  (make:io /create-ship [%| 0 %| ship-dir] &+[ship-sand ship-ball])
::  Sand weirs for all foreign ship directories from pre-built data.
::
++  sand-all-ships
  |=  $:  src=(map @p (set rail:tarball))
          how=(map @ta weir:nexus)
          ships-ball=ball:tarball
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  =/  ship-names=(list @ta)  ~(tap in ~(key by dir.ships-ball))
  |-
  ?~  ship-names  (pure:m ~)
  =/  ship-ta=@ta  i.ship-names
  =/  ship-p=(unit @p)  (slaw %p ship-ta)
  ?~  ship-p
    $(ship-names t.ship-names)
  ?:  =(u.ship-p our)
    ;<  ~  bind:m  (sand:io /sand-weir [%| 0 %| /ships/[ship-ta]] ~)
    $(ship-names t.ship-names)
  =/  =weir:nexus  (compute-ship-weir u.ship-p src how)
  ~&  >  [%peers-main %sand-weir ship-ta]
  ;<  ~  bind:m  (sand:io /sand-weir [%| 0 %| /ships/[ship-ta]] `weir)
  $(ship-names t.ship-names)
::  Full sync: read usergroups, sand all ship weirs.
::
++  sync-all-weirs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [who=(map @ta (set @p)) how=(map @ta weir:nexus)]  bind:m
    read-usergroups
  ;<  ships-seen=seen:nexus  bind:m
    (peek:io /read-ships [%| 0 %| /ships])
  ?.  ?&(?=(%& -.ships-seen) ?=(%ball -.p.ships-seen))
    ~&  >  [%peers-main %no-ships-data]
    (pure:m ~)
  =/  src=(map @p (set rail:tarball))  (build-src who)
  (sand-all-ships src how ball.p.ships-seen)
::  Peek /usergroups and return parsed who + how data
::
++  read-usergroups
  =/  m  (fiber:fiber:nexus ,[(map @ta (set @p)) (map @ta weir:nexus)])
  ^-  form:m
  ;<  ug-seen=seen:nexus  bind:m
    (peek:io /read-usergroups [%| 0 %| /usergroups])
  ?.  ?&(?=(%& -.ug-seen) ?=(%ball -.p.ug-seen))
    (pure:m [~ ~])
  =/  ug-ball=ball:tarball  ball.p.ug-seen
  (pure:m [(read-sub ug-ball %who (set @p)) (read-sub ug-ball %how weir:nexus)])
::  Extract typed files from a sub-directory of a ball
::
++  read-sub
  |*  [ug=ball:tarball dir=@ta =mold]
  ^-  (map @ta mold)
  =/  sub=ball:tarball  (~(gut by dir.ug) dir *ball:tarball)
  ?~  fil.sub  ~
  %-  ~(gas by *(map @ta mold))
  %+  murn  ~(tap by contents.u.fil.sub)
  |=  [name=@ta =content:tarball]
  ^-  (unit [@ta mold])
  =/  res  (mule |.(!<(mold q.cage.content)))
  ?:(?=(%| -.res) ~ `[name p.res])
::  Build reverse index: ship → group rails from who map
::
++  build-src
  |=  who=(map @ta (set @p))
  ^-  (map @p (set rail:tarball))
  =/  groups=(list [@ta (set @p)])  ~(tap by who)
  =|  acc=(map @p (set rail:tarball))
  |-
  ?~  groups  acc
  =/  [group=@ta members=(set @p)]  i.groups
  =/  =rail:tarball  [/ group]
  =/  ships=(list @p)  ~(tap in members)
  =.  acc
    |-
    ?~  ships  acc
    =/  existing=(set rail:tarball)  (fall (~(get by acc) i.ships) ~)
    $(ships t.ships, acc (~(put by acc) i.ships (~(put in existing) rail)))
  $(groups t.groups)
::  Union two weirs (merge road sets)
::
++  union-weirs
  |=  [a=weir:nexus b=weir:nexus]
  ^-  weir:nexus
  :+  (~(uni in make.a) make.b)
    (~(uni in poke.a) poke.b)
  (~(uni in peek.a) peek.b)
::  Compute the weir for a single ship from pre-built data
::
++  compute-ship-weir
  |=  $:  =ship
          src=(map @p (set rail:tarball))
          how=(map @ta weir:nexus)
      ==
  ^-  weir:nexus
  =/  public-weir=weir:nexus
    (fall (~(get by how) %public) *weir:nexus)
  =/  ship-rails=(set rail:tarball)
    (fall (~(get by src) ship) ~)
  =/  ship-weir=weir:nexus
    %+  roll  ~(tap in ship-rails)
    |=  [=rail:tarball acc=weir:nexus]
    (union-weirs acc (fall (~(get by how) name.rail) *weir:nexus))
  (union-weirs ship-weir public-weir)
--
