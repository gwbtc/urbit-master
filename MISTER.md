# Mister: File-as-Process Application Model

## Vision

Mister is a meta-agent where **files are processes**. Each file in the tarball has an associated running fiber that handles events directed to it. Directories can have a "nexus" that defines how files within behave.

This is distinct from grubbery's per-poke model where each poke spawns a transient process. In mister, processes are **persistent** - they live as long as the file exists, handling many events over their lifetime.

## Core Principles

1. **File = Process**: Every file has exactly one running process. No file without process, no process without file.

2. **Process Lifecycle**:
   - `%done` → file is deleted (process completed its purpose)
   - `%fail` → process is restarted with `[%rise tang]`, queued pokes are nacked
   - `%wait` → process continues, waiting for next input
   - `%skip` → skip current intake, process it later

3. **State Recovery**: On agent load, all processes are rebuilt from their nexus `on-file` and restarted with `[%load ~]` input.

4. **Namespace Routing**: Events are routed by path. Wires encode the target path so responses find their way back.

5. **Poke Ack/Nack**: Every poke carries a `give` (return address). Consumed pokes are acked/nacked via `give-poke-sign`.

## Data Structures

### State
```hoon
+$  state-0
  $:  %0
      =nexi:nexus
      =ball:tarball
      =pool:nexus
      =sand:nexus
      =born:nexus
  ==
```

- `ball` - tarball filesystem: `(axal lump)` where lump is `[=metadata neck=(unit neck) contents=(map @ta content)]`
- `pool` - running processes: `(axal pipe)` where pipe is `(map @ta proc:fiber)`
- `nexi` - compiled nexus definitions: `(map neck nexus)`
- `sand` - sandboxing filters: `(axal weir)`
- `born` - version tracking: `(axal [=cass:clay bags=(map @ta sack)])` where `sack = [proc=cass:clay file=cass:clay]`

### Nexus
```hoon
++  nexus
  $_  ^|
  |%
  ++  on-load  |~  state=ball  *ball           :: initialize directory structure
  ++  on-file  |~  [path mark]  *spool:fiber   :: create spool (initializer) for file
  --
```

### Process Types (fiber monad)
```hoon
+$  input    [state=vase in=(unit intake)]
+$  process  $-(input output)
+$  spool    $-(prod process)   :: initializer - takes startup reason, returns process
+$  output   [darts=(list dart) state=vase next=$%([%wait ~] [%skip ~] [%cont self=process] [%fail err=tang] [%done ~])]
```

### Prod (process startup reasons)
```hoon
+$  prod
  $%  [%make ~]     :: new file created
      [%load ~]     :: agent on-init or on-load
      [%rise =tang] :: restarting after crash
  ==
```

### Proc (running process state)
```hoon
+$  proc
  $:  =process              :: continuation
      next=(qeu take)       :: pending inputs
      skip=(qeu take)       :: skipped inputs
  ==
```

### Take (queued input with return address)
```hoon
+$  take  [=give in=(unit intake)]   :: in fiber
+$  take  [here=path take:fiber]     :: at nexus level (includes destination)
```

### Give (return address for acking)
```hoon
+$  give  [=from =wire]
+$  from  (each path prov)           :: internal path or external [src=@p sap=path]
```

### Intake (inbound events to processes)
```hoon
+$  intake
  $%  [%poke =from =cage]              :: someone poked this file
      [%peek =wire =seen]              :: local read result (seen = view or error)
      [%made =wire err=(unit tang)]    :: response to %make
      [%gone =wire err=(unit tang)]    :: response to %cull
      [%pack =wire err=(unit tang)]    :: response to %poke (ack/nack)
      [%sand =wire err=(unit tang)]    :: response to %sand
      [%load =wire err=(unit tang)]    :: response to %load (nexus reload)
      [%veto =dart]                    :: dart was sandboxed
      [%scry =wire =vase]              :: scry result
      [%bowl =wire =bowl]              :: bowl result
      [%arvo =wire sign=sign-arvo]     :: arvo response
      [%agent =wire =sign:agent:gall]  :: agent response
      [%watch =path]                   :: subscription
      [%leave =path]                   :: unsubscription
  ==
```

### Dart (outbound effects from processes)
```hoon
+$  dart
  $%  [%sysc =card:agent:gall]         :: emit regular gall card
      [%node =wire =road =load]         :: send load to another path
      [%scry =wire scry=(unit scry)]    :: request scry (~ = get agent state)
      [%bowl =wire]                     :: request bowl
  ==
```

### Load (what you can send to a node)
```hoon
+$  load
  $%  [%poke =cage]
      [%make =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]              :: trigger nexus on-load (hot-reload)
      [%peek ~]
  ==
```

### Weir (sandbox filter)
```hoon
+$  weir
  $:  make=(set road)   :: allowed destinations for %make/%cull/%sand
      poke=(set road)   :: allowed destinations for %poke
      peek=(set road)   :: allowed destinations for %peek
  ==
+$  sand  (axal weir)   :: tree of filters
```

## Wire and Path Formats

Both outgoing wires and incoming watch paths use the `%proc` prefix:

**Outgoing wires (wex):** `/proc/{len}/{here...}/{born}/{wire...}`
- `len` - length of `here` path
- `here` - path to the file that owns this subscription
- `born` - process instance timestamp (for stale detection)
- `wire` - the original wire from the process

**Watch paths (sup):** `/proc/{len}/{here...}/{subpath...}`
- `len` - length of `here` path
- `here` - path to the file being watched
- `subpath` - sub-path within that file's namespace

**Poke subscriptions:** `/poke/{src}/...`
- Used for external poke ack/nack delivery

## Implemented

### Core Infrastructure
- [x] Fiber monad with %wait/%skip/%cont/%fail/%done
- [x] Process storage (ball + pool + nexi)
- [x] Event routing via wrapped wires with `%proc` prefix
- [x] Bowl creation with filtered wex/sup (`make-bowl`)
- [x] Nexus lookup from compiled map
- [x] Default spool for files without governing nexus
- [x] Unified `%mister-action` mark for all external pokes

### Process Lifecycle
- [x] `++process-take` - queue intake and run process
- [x] `++process-do-next` - evaluate process, handle result
- [x] `++store-proc` / `++delete` - manage pool
- [x] `++build-spool` - find nexus, call on-file
- [x] %done → delete file and proc, clean subscriptions
- [x] %fail → nack queued pokes, restart with `[%rise tang]`

### On-Load Recovery
- [x] `++reload` - orchestrates full reload on agent load/init
- [x] `++nack-pool` - nack pokes in old proc queues before rebuild
- [x] `++run-on-loads` - top-down recursive nexus on-load execution
- [x] `++spawn-all-files` - recursive walk spawning processes with `[%load ~]`
- [x] `++load-ball-changes` - spawn processes then diff-balls for version bumps
- [x] `++cull-ball-changes` - diff-balls against empty ball for deletion bumps
- [x] `++sync-metadata` (lib/tarball) - preserve mtime for unchanged files, update for changed

### Version Tracking (++bo door in lib/nexus.hoon)
- [x] `born=(axal [=cass:clay bags=(map @ta sack)])` - version tree (high-water mark, never shrinks)
- [x] `sack=[proc=cass:clay file=cass:clay]` - per-file version info
- [x] `proc.cass` bumped on process spawn/restart (stale response detection)
- [x] `file.cass` bumped on content change (subscription notifications)
- [x] Directory `cass` propagates up from file changes to root
- [x] `++bo` door: `get`, `put`, `init`, `bump-proc`, `bump-file`, `bump-dir`, `diff-balls`
- [x] `++diff-balls` - unified change detection: new/changed/deleted files + empty dir edge cases
- [x] `bumped=(set lane:tarball)` tracks what changed for subscription notifications
- [x] Instance ID (`proc.cass`) included in wrapped wires
- [x] `++take-arvo` / `++take-agent` - check instance ID, discard stale responses
- [x] Comprehensive tests in tests/nexus.hoon (40+ test cases)

### Dart Handling
- [x] `++process-dart` / `++process-darts`
- [x] %sysc → emit gall card with wrapped wire, wrap %give %fact/%kick paths
- [x] %node/%poke → enqueue take at destination with return address
- [x] %node/%make → create file/directory
- [x] %node/%cull → delete file at path
- [x] %node/%sand → set weir at path
- [x] %node/%peek → return ball and sand subtrees at path
- [x] %scry → synchronous scry (or agent state if ~), enqueue result
- [x] %bowl → build bowl, enqueue result

### Poke Ack/Nack
- [x] `took` type - `[=take err=(unit tang)]` tracks consumed takes
- [x] Evaluator returns `done=(list took)` of consumed takes
- [x] `++give-poke-sign` - ack/nack single took (only if poke)
- [x] `++give-poke-signs` - iterate done list
- [x] `++nack-poke-takes` - nack remaining queue on failure
- [x] `++give-poke-ack` - route ack to internal path or external caller
- [x] External ack: emit fact on `/poke/~ship/wire`, then kick
- [x] `%poke` action includes wire for response routing
- [x] `/poke/~ship/...` subscription handling in on-watch/on-leave

### Event Handlers
- [x] `++take-arvo` / `++take-agent` - unwrap wire, check born, enqueue intake
- [x] `++take-watch` / `++take-leave` - subscription handling with `%proc` prefix

### Weir Sandboxing
- [x] `sand` in state - tree of weirs
- [x] Path helpers: `decap`, `prefix`, `path-from-bend`, `path-from-road`, `make-bend`
- [x] Filter helpers: `raw-filter`, `filter-roads`, `filter`, `next-filt`
- [x] `++nearest-governor` - find nearest directory strictly above both source and destination
- [x] `++allowed` - walk up from source to governor, checking weirs (lane-aware)
- [x] Lane-aware filtering - `raw-filter` and `filter` take `lane:tarball` (file vs directory)
- [x] `++process-dart` checks filter, vetos if blocked
- [x] `%veto` intake sent back with blocked dart
- [x] `++edit-weir` - set/clear weir at path
- [x] Guards instead of mole for wire/path validation
- [x] `++clam-cage` - validate poke cages at sandbox boundary via dais/vale
- [x] Clam pokes when `filt=[~ %&]`, veto on failure (rejects %temp marks)
- [x] Poke ack error sanitization - if poker can't peek target, nack with generic error
- [x] `%load` dart for nexus hot-reload with mule error handling
- [x] Graceful error acks for all make-category darts (%make, %cull, %sand, %load)

### External Entry Gate
- [x] External pokes gated to `/public/*` or `/peers/~src/*` entry points
- [x] `/public` and `/peers` directories created with blocking weirs `[~ ~ ~]`
- [x] External ships "exist" in the tree at their designated locations
- [x] Uniform sandboxing applies - external ships are tree citizens with weirs

### Directory Existence
- [x] `+dap` in `+ba` checks `fil.b` - returns `~` for structural-only directories
- [x] `%peek` on directories uses `+dap`, returns `%none` for non-existent

### Cleanup
- [x] Cancel wex entries when process dies (%done)
- [x] Kick sup entries when process dies (%done)

## Not Yet Implemented

### Name Uniqueness (Unix Semantics)

Files and directories cannot share a name at the same level. In Unix, `/foo` can't be both a file and a directory.

**Enforcement points in tarball:**
- [ ] `++put` - creating/updating a file: check no directory exists with same name
- [ ] Directory creation (implicit via path): check no file exists with same name
- [ ] `++put` with subtree (`%&` case): recursive check at every level
- [ ] Rename operations (if we add them): check target name is unique

**Ball validator:**
- [ ] `++validate-names` - walk entire ball, verify no collisions at any level
- [ ] Call on load to catch corrupted state
- [ ] Call on `%make` with subtree before merge

**Implementation:**
- At each `axal` node, the keys in `dir` (subdirectories) and keys in `contents` of `fil` (files) must be disjoint sets
- `?<((~(has in ~(key by dir.node)) name) ...)` before file insert
- `?<((~(has in ~(key by contents.fil.node)) name) ...)` before dir insert

### Cleanup
- [ ] Handle outgoing keens

### Remote Scry
- [ ] `/c` permission scry - check if a ship can access a path (weir-aware)
- [ ] Keen tracking - track outgoing `%keen` per-process, `%yawn` on death/crash
- [ ] Versioning - may need custom scheme if historical versions need different permissions (coops apply to all versions)

### Internal Subscriptions (%keep)

Process-to-process subscriptions for tree changes.

#### Types

```hoon
:: load (outgoing dart payload)
[%keep kind=?(%ball %file)]   :: subscribe to changes at dest
[%drop ~]                      :: unsubscribe from dest

:: intake (incoming to process)
[%bond =wire err=(unit tang)]  :: subscription established/failed
[%fell =wire]                  :: subscription canceled (weir change, deletion, etc)
[%news =wire what=(set lane:tarball) =view]  :: state notification with changed lanes
```

The `what` set contains all lanes (files and directories) that changed.
Subscribers receive the full set of changes in one notification.

The `view` type (already exists):
```hoon
+$  view
  $%  [%ball =ball =sand]
      [%file =cage]
      [%none ~]              :: deleted / doesn't exist
  ==
```

#### State

**Subscriptions** - need to track who's subscribed to what:
- Index by target path (for sending updates when file changes)
- Index by subscriber path (for cleanup when process dies)
- Probably need both - a jug or double-indexed structure

```hoon
+$  bind  [subscriber=path =wire kind=?(%ball %file) sent=@ud]
+$  subs  ???  :: TBD - needs efficient lookup both ways
```

The `sent` field tracks the last `file.cass` delivered to this subscriber.
Only send if `file.cass > sent`, then update `sent := file.cass`.

**Revisions** - version tracking via `born` (already implemented):
- `file.cass` in each `sack` serves as the revision counter
- Bumped on every content change via `++bump-file`
- Directory `cass` propagates up, enabling subtree subscriptions
- `bumped=(set lane:tarball)` from `++diff-balls` identifies what changed

#### Flows

**1. Subscribe**
- Process A sends `[%node =wire =road [%keep kind]]`
- Check peek permission (reuse existing weir check)
- Store subscription
- Send `[%bond wire ~]` on success
- Send `[%bond wire [~ tang]]` on failure (no permission, etc)

**2. File changes**
- File at `/foo/bar` changes (via `++process-do-next` saving state, or `++make`)
- Increment rev for that file
- Find all `%file` subscribers to `/foo/bar`
- Find all `%ball` subscribers to ancestors (`/foo`, `/`)
- For each subscriber, send notification with `sub=<relative-path> rev view`
- Relative path: `/bar` for subscriber at `/foo`, `/foo/bar` for subscriber at `/`

**3. Process completes (%done)**
- Send notification with final state view (so subscribers see last state)
- Then send notification with `view=[%none ~]` (so subscribers know it's gone)
- Delete the file
- Also cancel any subscriptions TO the deleted path

**4. File deleted (%cull)**
- Send notification with `view=[%none ~]`
- Cancel any subscriptions TO the deleted path

**5. Weir changes**
- Weir at `/foo` changes via `++set-weir`
- Check all subscriptions crossing through `/foo`
- For any that no longer pass `++allowed`, send `[%fell wire]` and remove

**6. Voluntary unsubscribe**
- Process A sends `[%node =wire =road [%drop ~]]`
- Remove subscription
- Send `[%fell wire]` as ack (or separate `[%left wire]`?)

**7. Subscriber dies/crashes**
- Process at `/foo/bar` terminates (%done or %fail)
- Clean up all its outgoing subscriptions (no notification needed - it's dead)

**8. Reload**
- On agent reload, all subscriptions are lost (processes restart fresh)
- Processes re-subscribe as needed after `[%load ~]`

#### Open Questions

- ~~Should weir have separate `keep=(set road)` or reuse `peek` permission?~~
  **Resolved:** Reuse `peek`. Subscribing is just ongoing peek access.
- For `%ball` subscription at `/foo`, if `/foo/bar/baz` changes:
  - Send one diff with `sub=/bar/baz view=[%file cage]`?
  - Or send multiple diffs bubbling up (bar's parent changed too)?
  - Probably just the leaf change with relative path
- Should subscriptions survive across the subscription target's restart?

#### Implementation Order

1. [x] Add types to nexus.hoon - `%news` intake with `what=(set lane:tarball)`
2. [x] Version tracking infrastructure - `++bo` door with `bumped` set
3. [x] Handle empty directories - `++diff-balls` detects empty dir appear/disappear
4. [ ] Add subscription state to mister - index by target and subscriber
5. [ ] Handle `%keep` dart - check permission, store, send `%bond`
6. [ ] Handle `%drop` dart - remove, send `%fell`
7. [ ] Wire `bumped` set to `%news` notifications in `++load-ball-changes` / `++cull-ball-changes`
8. [ ] Notify on file change in `++process-do-next` / `++save-file`
9. [ ] Cancel subscriptions when weir changes in `++set-weir`
10. [ ] Clean up subscriptions when process dies

## Mark Validation Refactoring (COMPLETE)

Moving dais/mark validation from lib/tarball.hoon to app/mister.hoon.

### Why Move?
- Tarball should be a pure data structure (just store cages)
- Mister is the runtime that can scry for daises
- Mister knows the context (poke vs make, permissions)
- Validation is runtime policy, not data structure concern

### What Stays in Tarball
- `conversions=(map mars:clay tube:clay)` - for mime↔cage I/O
- `mime-to-cage` / `cage-to-mime` - tube conversions for tar format
- `from-parts` - multipart upload parsing (but without dais validation)

### What Moves to Mister
- `d=(map mark dais:clay)` - remove from `++ba` door
- `++das` - remove
- `++validate-cage` / `++validate-ball` - reimplement in mister with scry
- `++put` in tarball becomes dumb storage (no validation)

### Validation Logic (from tarball, to replicate)
```hoon
1. %temp mark → skip validation entirely (ephemeral)
2. Same mark + types nest → canonicalize (old type, new value) - no dais
3. Otherwise → scry for dais, call vale
```

### Where Validation Happens in Mister

**`++process-do-next`** - after evaluator returns:
- Validate `new-state` before handling result
- If validation fails → treat as `%fail`, restart with `[%rise tang]`
- Applies to `%next`, `%done`, and implicitly `%fail` (no save)

**`++make`** - creating files:
- `%|` (single file): validate cage before storing
- `%&` (subtree): validate all cages in ball before storing

**`++run-on-loads`** - nexus modifies ball:
- Validate all cages in returned ball
- If validation fails → crash loudly, don't boot

### Error Handling by Context
- **External input (poke/make)** → nack with validation error
- **Process state output** → treat as crash, restart with `%rise`
- **Load-time (nexus)** → crash, don't boot (programmer error)

### Code Already Added to app/mister.hoon

Located after `++sys-give`, before `++store-proc`:

```hoon
::  Validate a cage, checking nest or scrying for dais
::  Returns validated cage or error tang
::
++  validate-cage
  |=  [pax=path name=@ta new-cage=cage]
  ^-  (each cage tang)
  ::  Skip validation for %temp mark - ephemeral
  ?:  =(%temp p.new-cage)
    &+new-cage
  ::  Check if there's existing content at this location
  =/  old=(unit content:tarball)  (~(get ba:tarball ball) pax name)
  ::  Same-mark update with nesting types: canonicalize without dais
  ?:  ?&  ?=(^ old)
          =(p.cage.u.old p.new-cage)
          (~(nest ut p.q.cage.u.old) | p.q.new-cage)
      ==
    &+[p.new-cage p.q.cage.u.old q.q.new-cage]
  ::  Need dais - scry for it
  =/  dais-path=path
    /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/[p.new-cage]
  =/  dais-result=(each dais:clay tang)
    (mule |.(.^(dais:clay %cb dais-path)))
  ?:  ?=(%| -.dais-result)
    |+[leaf+"no dais for mark {<p.new-cage>}" p.dais-result]
  ::  Validate using vale
  =/  vale-result=(each vase tang)
    (mule |.((vale:p.dais-result q.q.new-cage)))
  ?:  ?=(%| -.vale-result)
    |+[leaf+"validation failed for {<p.new-cage>}" p.vale-result]
  &+[p.new-cage p.vale-result]
::  Validate process state after evaluation
::
++  validate-state
  |=  [pax=path name=@ta =mark new-state=vase]
  ^-  (each vase tang)
  =/  res=(each cage tang)  (validate-cage pax name [mark new-state])
  ?:  ?=(%| -.res)  res
  &+q.p.res
```

### Next: Integrate into ++process-do-next

Current code (around line 617-640):
```hoon
::  Handle result
?-    -.res
    %next
  ::  Update state in ball and proc in pool
  =.  ball  (~(put ba:tarball ball) dir name [metadata.u.file-data p.cage.u.file-data new-state])
  (store-proc here new-proc)
  ::
    %done
  ::  Nack any remaining queued pokes...
  ...
    %fail
  ::  Nack queued pokes and restart...
  ...
==
```

Should become:
```hoon
::  Validate new state before handling result
=/  validated=(each vase tang)
  (validate-state dir name p.cage.u.file-data new-state)
?:  ?=(%| -.validated)
  ::  Validation failed - treat as crash
  =.  this  (nack-poke-takes next.new-proc p.validated)
  =.  this  (nack-poke-takes skip.new-proc p.validated)
  =.  this  (spawn-proc here [%rise p.validated])
  (enqu-take here (sys-give /rise) ~)
::  Validation passed - handle result normally
?-    -.res
    %next
  =.  ball  (~(put ba:tarball ball) dir name [metadata.u.file-data p.cage.u.file-data p.validated])
  (store-proc here new-proc)
    %done
  ::  State was valid, now delete
  =/  err=tang  ~[leaf+"process completed"]
  =.  this  (nack-poke-takes next.new-proc err)
  =.  this  (nack-poke-takes skip.new-proc err)
  =.  this  (clean here %file)
  (delete here)
    %fail
  ::  Process failed - don't save state, restart
  =.  this  (nack-poke-takes next.new-proc err.res)
  =.  this  (nack-poke-takes skip.new-proc err.res)
  =.  this  (spawn-proc here [%rise err.res])
  (enqu-take here (sys-give /rise) ~)
==
```

### Next: Integrate into ++make

For `%|` (single file) case around line 669-682:
```hoon
::  Current:
=/  ba  (~(das ba:tarball ball) ~)
=.  ball  (put:ba (snip `path`here) (rear here) [~ p.make])

::  Should become:
=/  validated=(each cage tang)
  (validate-cage (snip `path`here) (rear here) p.make)
?:  ?=(%| -.validated)
  ~|("make failed: validation error" (mean p.validated))
=.  ball  (~(put ba:tarball ball) (snip `path`here) (rear here) [~ p.validated])
```

For `%&` (subtree) case - need `++validate-ball` helper to validate all cages in a ball:
```hoon
++  validate-ball
  |=  [here=path sub=ball:tarball]
  ^-  (each ball:tarball tang)
  ::  Validate all files in contents at this level
  ::  Recurse into subdirectories
  ::  Return validated ball or first error
  ...
```

### What to Remove from lib/tarball.hoon After

1. Remove `d=(map mark dais:clay)` from `++ba` door (line ~460)
2. Remove `++das` arm (lines ~465-468)
3. Remove `++validate-cage` arm (lines ~495-519)
4. Remove `++validate-ball` arm (lines ~666-678)
5. Simplify `++put` to just store without validation (lines ~480-494)
6. Update `from-parts` to not take dais-map parameter

### Implementation Status
- [x] Added `++validate-cage` helper (scries for dais)
- [x] Added `++validate-state` helper (for process state)
- [x] Add `++validate-ball` helper for subtree validation
- [x] Added `force=?` flag to skip nest optimization on load
- [x] Integrate into `++process-do-next` (force=%.n, runtime)
- [x] Integrate into `++make` (`%|` case, force=%.n)
- [x] Integrate into `++make` (`%&` case, force=%.n)
- [x] Single force-validation pass in `++reload` after on-loads complete
- [x] Clear `%temp` cages on reload
- [x] Reject empty mime files
- [x] Remove dais logic from lib/tarball.hoon
- [x] Update `from-parts` signature
- [x] Update callers (routes/ball, sailboxio, tools)
- [ ] Test

### Force Flag Rationale
- **Runtime** (`force=%.n`): The type of `$type` for each mark hasn't changed since agent loaded. Nest optimization is safe - if same mark and types nest, canonicalize without dais.
- **Load time** (`force=%.y`): Mark `.hoon` files may have been updated, so the type of `$type` may have changed. Must re-clam everything through current dais to pick up new type definitions.

### Future Work
- [ ] Sailbox integration (depends on %keep) - incorporate SSE and HTTP logic from sailbox

  Sailbox's `++make-sse-event` generates SSE content from `state=ball` - updates are
  **state-derived**. Currently you manually emit `%sse` cards. With `%keep`:

  1. Request handler subscribes to files/dirs via `%keep`
  2. Files change → mister sends `%news` intake automatically
  3. Handler receives `%news` → emits SSE event to client

  This makes SSE updates reactive (state-driven) rather than imperative (manually triggered).
  The `/server` request handler would `%keep` subscribe to relevant tree locations and
  forward `%news` as SSE events.

- [ ] Nexuses and marks in the tree - could nexuses and marks live inside the ball?

  Currently nexuses are compiled code in `nexi=(map neck nexus)` and marks come from
  Clay. What if they lived in the tree as source files?

  - Store `.hoon` source as `%hoon` cages in the tree (e.g., `/sys/nex/server.hoon`)
  - Compile to `%temp` vases during `on-load` (ephemeral, not persisted)
  - Nexus lookup becomes tree lookup + grab from `%temp` cache
  - Marks could work similarly - `/sys/mar/json.hoon` compiled on load

  Benefits:
  - Self-contained: app = tree, no external dependencies
  - Versioning: nexus/mark changes are tree changes, tracked like any file
  - Hot reload: `%load` dart recompiles, no agent restart needed
  - Sandboxing: weirs could control who can modify `/sys/nex/*`

  Questions:
  - Performance: recompiling on every load vs caching compiled cores
  - Bootstrap: how does the root nexus compile itself?
  - Clay integration: still need some marks for external I/O (eyre, etc.)

- [ ] Build system for hoon in the tree - compile a ball of `.hoon` files

  If nexuses/marks live in the tree, we need a build system:

  - Parse `/+` and `/-` ford runes from source files
  - Build dependency graph between files
  - Topological sort for compilation order
  - Compile each file with its dependencies as subject
  - Cache compiled cores as `%temp` vases

  Could work like:
  ```
  /sys
    /lib
      tarball.hoon    :: /+  tarball
      nexus.hoon      :: /+  tarball, nexus
    /sur
      mister.hoon     :: /-  mister
    /nex
      server.hoon     :: nexus source
      root.hoon
    /mar
      json.hoon
  ```

  On load:
  1. Scan `/sys` for `.hoon` files
  2. Parse imports, build dependency graph
  3. Compile in dependency order
  4. Store compiled cores as `%temp` at same path
  5. Nexus/mark lookup grabs from `%temp` cache

  This makes the tree a self-building application package.

- [ ] Code sharing over the network - distribute apps as trees of source

  If apps are self-contained trees of `.hoon` source, distribution becomes simple:

  - **Export**: tarball the tree (already implemented)
  - **Import**: untar into a path, run build system, go
  - **Sync**: `%keep` subscribe to a remote ship's `/apps/foo` tree
  - **Updates**: remote changes → `%news` → rebuild affected files

  Could work like:
  ```
  :: Subscribe to ~dev's app
  [%node /sync/dev-app [%keep %ball] [%| 0 [%| /apps/foo]] ~dev]

  :: Receive updates as %news
  [%news /sync/dev-app /lib/utils.hoon 42 [%file %hoon !>(source)]]

  :: Trigger rebuild of affected files
  ```

  Benefits:
  - **Source-level sharing**: you can read/audit what you're running
  - **Reactive updates**: `%keep` makes sync automatic
  - **Selective sync**: subscribe to subtrees, not whole apps
  - **Fork-friendly**: copy tree, modify, your version

  Questions:
  - Trust: how do you verify source hasn't been tampered with?
  - Versioning: semantic versions vs tree state?
  - Rollback: keep old versions in tree history?

- [ ] Usergroup pattern - role-based weir management via tree state

  Usergroups are a **weir management layer** built on mister primitives, not core changes.
  Groups control what weirs get applied to `/peers/~ship` and `/public`.

  ```
  /grp
    /main      :: weir manager process (keeps everything in sync)
    /who
      /admins              :: (set @p) - global admins
      /acme
        /engineering       :: (set @p) - acme engineering team
        /engineering
          /leads           :: (set @p) - acme engineering leads
    /how
      /admins              :: weir - what admins can do
      /acme
        /engineering       :: weir - what acme engineers can do
        /engineering
          /leads           :: weir - what leads can do
    /src
      /~zod    :: (set path) - {/admins /acme/engineering/leads}
      /~bus    :: (set path) - {/acme/engineering}
    /pub       :: weir - what public (non-grouped) can do
  ```

  **Groups are paths, no inheritance:**
  - Paths provide organizational structure: `/acme/engineering/leads`
  - No automatic inheritance - membership is explicit
  - Being in `/acme/engineering/leads` does NOT imply `/acme/engineering`
  - If you want both, add to both explicitly

  **Bidirectional index:**
  - `/grp/who/acme/engineering` → "who is in this group?" (for management UI)
  - `/grp/src/~zod` → "what groups is this ship in?" (set of paths, for fast weir lookup)

  **The `/grp/main` process:**
  1. `%keep` subscribes to `/grp` (ball subscription)
  2. Receives `%news` when membership or templates change
  3. Keeps `/who/*` and `/src/*` in sync (bidirectional index)
  4. Recalculates weirs:
     - For each ship with a `/peers/~ship` entry:
       - Peek `/grp/src/~ship` → get group set
       - Peek `/grp/how/[group]` for each group
       - Union the weirs
       - `%sand` to `/peers/~ship`
     - Apply `/grp/pub` to `/public` via `%sand`

  **Benefits:**
  - No core changes - pure application pattern
  - Reactive - weirs update automatically when groups change
  - Auditable - group membership and permissions are tree state
  - Composable - ships can be in multiple groups, weirs union

  **Example flow:**
  1. Admin adds `~zod` to leads: poke `/grp/who/acme/engineering/leads` to add `~zod`
  2. `/grp/main` receives `%news`, updates `/grp/src/~zod` to include `/acme/engineering/leads`
  3. `/grp/main` recalculates weir for `~zod`: union of weirs from all groups in `/grp/src/~zod`
  4. `/grp/main` sends `%sand` to `/peers/~zod` with new weir
  5. `~zod`'s next dart is filtered with updated permissions

  This is role-based access control as tree structure, managed reactively.

- [ ] Testing - exercise the flows end-to-end

## Open Questions (Resolved)

1. **What about directories?** Directories don't have processes. Only files have processes. Directories can have a nexus that defines behavior for files within.

2. **The pipe map**: `pipe` is `(map @ta proc:fiber)` - one proc per file in a directory. The map key is the filename.

3. **Inter-process communication**: Pokes carry a `give` with return address. When process A pokes B, B's response (ack/nack) is routed back via `give-poke-ack` which enqueues a `%pack` intake at A's path.

4. **%kill vs %cull**: Removed `%kill` - since file=process, `%cull` (delete file at path) handles all cases. The `%cull` dart means "delete myself", while `%node [%cull ~]` means "delete file at this path".

5. **Subscriptions**: Watch paths use `%proc` prefix like wires. `%give %fact` and `%give %kick` paths are wrapped automatically.

## Planned: Explicit File/Directory Type Distinction

Make the file vs directory distinction explicit at the type level throughout the codebase.

### Current Types
```hoon
+$  rail  [=path name=@ta]         :: always a file
+$  fold  path                     :: always a directory
+$  lane  [=path file=(unit @ta)]  :: file or directory (implicit)
+$  bend  (pair @ud path)          :: relative: steps + subpath
+$  road  (each path bend)         :: absolute or relative path
+$  from  (each path prov)         :: source location
```

### Proposed Types
```hoon
+$  rail  [=path name=@ta]         :: always a file
+$  fold  path                     :: always a directory
+$  lane  (each rail fold)         :: explicit discrimination: [%& rail] or [%| fold]
+$  bend  (pair @ud lane)          :: relative: steps + lane (file or dir)
+$  road  (each lane bend)         :: absolute or relative lane
+$  from  (each rail prov)         :: source is always a file (pokes come from processes)
```

Inside `++fiber` (sandboxed view):
```hoon
+$  bend  (pair @ud rail)          :: fiber bends always target files
+$  from  (each bend prov)         :: relative file source or external
```

### Rationale

1. **Type safety** - can't accidentally pass a directory where a file is expected
2. **Self-documenting** - clearer what each path represents
3. **Compiler catches errors** - e.g., pokes must target files, not directories
4. **Explicit discrimination** - `lane = (each rail fold)` makes the choice visible

### Validation at Dispatch

Keep destination in `road` (single source of truth), validate per operation:
- `%poke` → must resolve to `rail`
- `%make` → `lane` ok (can create file or dir)
- `%cull` → `lane` ok (can delete file or dir)
- `%peek` → must resolve to `rail` (peek file state)

### Implementation Strategy

1. Update type definitions in `lib/nexus.hoon`
2. Update path helpers (`make-bend`, `path-from-bend`, `relativize-from`, etc.)
3. Propagate changes through `app/mister.hoon`
4. Update `lib/fiberio.hoon`
5. Update nexuses (`lib/nex/*.hoon`)
6. Update server validation pattern in `nex/server.hoon`:
   ```hoon
   ::  Old: ?>  ?=([%& %1 %requests @ ~] from)
   ::  New: ?>  ?=([%& %1 [%requests ~] @] from)
   ::       ?>  =(name.q.p.from eyre-id)
   ```

### Implementation Notes

**Key principle: File paths are always `rail`, never bare `path`.**

Every function that deals with a file location should use `rail = [=path name=@ta]`, not `path`. This means:

1. `here` parameters throughout mister.hoon become `here=rail`
2. `++enqu-take`, `++process-dart`, `++handle-dart`, etc. all take `rail`
3. `take:nexus` has `here=rail` (already done)
4. `from:nexus` is `(each rail prov)` (already done)
5. Pool indexing may need adjustment

Only use bare `path` for:
- Directory references (`fold`)
- Intermediate computations where you genuinely need just the directory portion

### Helpers Added

- `++rail-from-path` - convert file path to rail: `/a/b/c` → `[path=/a/b name=%c]`
- `++path-from-lane` - get full path from lane
- `++dir-from-lane` - get directory path from lane
- `++lane-from-bend` - resolve relative bend to absolute lane
- `++lane-from-road` - resolve road to absolute lane

## Weir Sandboxing (Design Notes)

Sandboxing controls what processes can reach:

**Governor Model:**
The "governor" is the nearest directory strictly ABOVE both source and destination.
Filtering walks from source up to the governor, checking weirs at each step.

- **File destinations**: Governor is the common prefix of source and dest paths.
  Siblings talk freely (e.g., `/a/x` → `/a/y` has governor `/a`, no weirs checked).
- **Directory destinations**: Governor is strictly above both source and dest.
  Can't escape your own sandbox (e.g., `/a/x` → `/a` checks `/a`'s weir).
- **Syscalls**: No governor - walk all the way up to root, checking every weir.

**Rules:**
- Darts moving DOWN the tree → always allowed (below governor)
- Darts moving UP the tree → checked against weirs at each directory until governor
- Weirs are lane-aware: file rules vs directory rules
- %sysc (gall cards) → blocked by ANY weir (no governor, full walk)
- %make/%poke/%peek → checked against respective weir sets

**Filter results (`filt`):**
- `~` → no filter at this level (permissive)
- `[~ &]` → allowed but clam vases (validate via mark's dais)
- `[~ |]` → vetoed, send `%veto` intake back

**Algorithm:**
1. Determine dart category (jump): %sysc/%make/%poke/%peek
2. Calculate destination lane from road
3. Find governor via `++nearest-governor`
4. Walk UP from source-dir, checking weir at each step
5. Stop when we reach the governor
6. Combine filter results (any veto wins, otherwise allow+clam wins)
7. Act: allow, allow+clam, or veto

## External Entry Gate

External ships can only poke into designated entry points:

- `/public/*` - shared public area, anyone can poke
- `/peers/~ship/*` - per-ship namespace, only that ship can poke

This gates WHERE external entities "exist" in the tree. Once inside at their
designated location, external ships become tree citizens subject to uniform
weir sandboxing. You control external access by configuring weirs at `/public`
or `/peers/~ship` to allow specific operations.

**Default state**: Both `/public` and `/peers` have blocking weirs `[~ ~ ~]`
(empty sets = block everything). Configure them to enable external access.
