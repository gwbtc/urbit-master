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
      =subs:nexus
  ==
```

- `ball` - tarball filesystem: `(axal lump)` where lump is `[=metadata neck=(unit neck) contents=(map @ta content)]`
- `pool` - running processes: `(axal pipe)` where pipe is `(map @ta proc:fiber)`
- `nexi` - compiled nexus definitions: `(map neck nexus)`
- `sand` - sandboxing filters: `(axal weir)`
- `born` - version tracking: `(axal [=cass:clay bags=(map @ta sack)])` where `sack = [proc=cass:clay file=cass:clay]`
- `subs` - internal subscriptions: `[fwd=(map lane (map rail wire)) rev=(jug rail lane)]`

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
      [%bond =wire err=(unit tang)]    :: subscription established/failed
      [%fell =wire]                    :: subscription canceled (weir change)
      [%news =wire what=(set lane) =view]  :: change notification
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
      [%keep ~]              :: subscribe to changes at dest
      [%drop ~]              :: unsubscribe from dest
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

### HTTP (Server Nexus)
- [x] Server nexus manages eyre bindings (register/unregister via `send-cards:io`)
- [x] Server routes requests by matching URL to binding map (progressively shorter paths)
- [x] Server authorizes responses via bend comparison (`=(p.from u.expected-bend)`)
- [x] Server tracks connections (`connections=(map @ta binding:eyre)`)
- [x] Server handles client disconnect (`%handle-http-cancel` from gall `on-leave`)
- [x] Server kicks orphaned connections on unbind
- [x] Gall agent is thin shell: forward HTTP to `/server/main`, relay on-leave
- [x] Removed connect/disconnect poke infrastructure from gall agent and fiberio
- [x] Counter app with self-contained UI sub-nexus (reference implementation)
- [x] Requests pattern: per-request files at `/requests/[eyre-id]` via `make:io`
- [x] SSE streaming with keep-alive timers (counter demo)
- [x] Response routing through `/main` for authorization (request → main → server)

### Internal Subscriptions
- [x] `subs` state with dual indices: `fwd` (target→watchers) and `rev` (watcher→targets)
- [x] `%keep` dart → `sub-put`, check peek permission, send `%bond`
- [x] `%drop` dart → `sub-del`, send `%fell`
- [x] `++notify` - send `%news` to watchers when lanes change
- [x] `bumped` set from `++bo` wired through `bump-file` and `diff-balls` to `notify`
- [x] `what` contains relative paths of changed descendants
- [x] `view` contains current state of watched location
- [x] `++sub-wipe` - clean up outgoing subscriptions when watcher dies
- [x] `++fell-sub` - forcibly end subscription + send `%fell`
- [x] `++audit-weir` - re-check subscriptions after weir change
- [x] Audit on `set-weir`, `reload`, and `reload-nexus`
- [x] Subscriptions persist through target deletion (watcher gets `%news` with `[%none ~]`)

### Name Uniqueness (Unix Semantics) - COMPLETE

Files and directories cannot share a name at the same level. In Unix, `/foo` can't be both a file and a directory.

**Enforcement in lib/tarball.hoon:**
- [x] `++put` - crashes if file name collides with existing directory
- [x] `++put` - crashes if creating directory path that collides with existing file
- [x] `++pub` - crashes if inserting subtree with internal name collisions
- [x] `++mkd` - crashes if directory name collides with existing file
- [x] `++validate-names` - walks entire ball, returns `%.n` on any collision

**Enforcement in app/mister.hoon:**
- [x] On reload: `?>  ~(validate-names ba:tarball ball)` after `validate-ball`
- [x] On `%make` subtree: `?>  ~(validate-names ba:tarball validated)` before final pub

**Implementation:**
- Set intersection check: `?^  (~(int in files) dirs)  %.n`
- Recursive walk via `^$(b i.kids)` to check all levels
- 13 tests covering collision prevention and detection

### HTTP Architecture (Server Nexus + Requests Pattern)

The gall agent (`app/mister.hoon`) is a thin shell. All HTTP logic lives in the tree.

**Server nexus** (`lib/nex/server.hoon`) owns all HTTP concerns:
- Eyre binding registration (via `send-cards:io` with `master:io`)
- Request routing (URL path → binding → nexus via bend)
- Response authorization (sender's bend must match binding's bend)
- Connection tracking (`connections=(map @ta binding:eyre)`)
- Client disconnect handling (`%handle-http-cancel` from `on-leave`)
- Orphan cleanup on unbind (kick connections for removed bindings)

**Gall agent** only does three things for HTTP:
1. Forwards `%handle-http-request` to `/server/main`
2. Forwards `on-leave [%http-response *]` as `%handle-http-cancel` to `/server/main`
3. Watches/kicks on `/http-response/[eyre-id]` paths (eyre plumbing)

**Requests pattern** — each HTTP request gets its own file and process:
1. Server receives request, looks up binding, forwards to bound nexus
2. Nexus `/main` receives request, creates file at `/requests/[eyre-id]` via `make:io`
3. Request file's process handles the request independently (can do SSE, long-poll, etc.)
4. Response flows: request file → poke `/main` → `/main` forwards to server → server emits cards
5. Server validates that response sender's bend matches the binding's bend

This solves the concurrency problem: SSE streams don't block new requests because each
request is its own process. The `/main` process just dispatches and forwards.

**Authorization flow:**
- Nexus binds via `(poke:io /bind server-road bind-action+!>([%bind binding]))` — server records `[binding bend-of-sender]`
- Responses route through the same `/main` that registered the binding
- Server checks `=(p.from u.expected-bend)` — only the nexus that claimed the binding can respond on it

**Reference implementation:** `lib/nex/counter.hoon` — self-contained counter app with:
- `counter` nexus at `/counter`: ticking state, responds to `%counter-start`
- `counter-ui` nexus at `/counter/ui`: HTTP handling, SSE streaming
- Roads: `server-road` (up 2 to `/server/main`), `req-counter-road` (up 2 to `/counter/main`), `main-road` (up 1 to `/counter/ui/main`)

## Not Yet Implemented

### Cleanup
- [ ] Handle outgoing keens

### Remote Scry
- [ ] `/c` permission scry - check if a ship can access a path (weir-aware)
- [ ] Keen tracking - track outgoing `%keen` per-process, `%yawn` on death/crash
- [ ] Versioning - may need custom scheme if historical versions need different permissions (coops apply to all versions)

### Internal Subscriptions (%keep) - COMPLETE

Process subscribes to tree locations, receives `%news` when content changes.

#### Types

```hoon
:: load (outgoing dart payload)
[%keep ~]   :: subscribe to changes at dest (file or directory)
[%drop ~]   :: unsubscribe from dest

:: intake (incoming to process)
[%bond =wire err=(unit tang)]  :: subscription established/failed
[%fell =wire]                  :: subscription canceled (weir change only)
[%news =wire what=(set lane:tarball) =view]  :: change notification
```

#### State

```hoon
+$  subs
  $:  fwd=(map lane:tarball (map rail:tarball wire))  :: target → watchers
      rev=(jug rail:tarball lane:tarball)             :: watcher → targets
  ==
```

Dual-indexed for fast lookup both ways:
- `fwd`: "who is watching this lane?" - for sending notifications
- `rev`: "what is this process watching?" - for cleanup on death

#### Key Semantics

**Subscriptions are to locations, not contents:**
- If target is deleted, watcher gets `%news` with `view=[%none ~]`
- Subscription persists - watcher will see when new content appears
- Only permission changes (`%fell`) forcibly end subscriptions

**Notification flow:**
1. Content changes → `++bo` tracks in `bumped=(set lane:tarball)`
2. `bump-file` / `diff-balls` call `++notify` with bumped set
3. `notify` finds watchers, relativizes paths, sends `%news`

**`what` set in `%news`:**
- For file subscription: always empty (nothing changes "inside" a file)
- For directory subscription: relative paths of changed descendants

#### Management Arms (app/mister.hoon)

- `++sub-put` - add subscription (target → watcher)
- `++sub-del` - remove subscription
- `++sub-wipe` - remove all outgoing subs from a watcher (on death)
- `++notify` - send `%news` to watchers when lanes change
- `++fell-sub` - remove subscription + send `%fell`
- `++audit-weir` - re-check subs after weir change, fell blocked ones

#### Integration Points

| Event | Handler | Action |
|-------|---------|--------|
| `%keep` dart | `++handle-dart` | `sub-put`, send `%bond` |
| `%drop` dart | `++handle-dart` | `sub-del`, send `%fell` |
| File changes | `++bump-file` | `notify` via bumped set |
| Bulk changes | `++diff-balls` | `notify` via bumped set |
| Watcher dies | `++delete` | `sub-wipe` |
| Weir changes | `++set-weir` | `audit-weir` |
| Reload | `++reload` | `audit-weir /` |
| Nexus reload | `++reload-nexus` | `audit-weir dest` |

## Mark Validation (COMPLETE)

Validation lives in app/mister.hoon, not lib/tarball.hoon. Tarball is a pure data structure; mister is the runtime that can scry for daises.

### Validation Stack

```hoon
++  validate-vase   :: pure - takes dais, handles nest optimization
  |=  [=dais:clay old=(unit vase) new=vase force=?]
  ^-  (each vase tang)

++  validate-file   :: impure - scries for dais, handles %temp/empty-mime
  |=  [=mark old=(unit vase) new=vase force=?]
  ^-  (each vase tang)

++  clam-cage       :: trust boundary - rejects %temp, delegates to validate-file
  |=  =cage
  ^-  (each cage tang)

++  validate-ball   :: whole tree - takes ball, returns ball, crashes on failure
  |=  =ball:tarball
  ^-  ball:tarball
```

### Separation of Concerns

| Function | Responsibility |
|----------|----------------|
| `validate-vase` | Pure: nest check or vale. No scrying, no mark knowledge. |
| `validate-file` | Impure: scries for dais, handles %temp (allow) and empty-mime (reject). |
| `clam-cage` | Trust boundary: rejects %temp from untrusted sources, delegates rest. |
| `validate-ball` | Bulk: validate whole tree, crash on failure (precondition check). |

### Nest Optimization

If `old` vase exists and types nest, reuse old type without scrying for dais:
```hoon
?:  ?&  !force
        ?=(^ old)
        (~(nest ut p.u.old) | p.new)
    ==
  &+[p.u.old q.new]
```

### Force Flag

- `force=%.n` (runtime): Nest optimization enabled. Type of `$type` hasn't changed.
- `force=%.y` (load time): Skip nest optimization. Mark files may have changed.

### Where Validation Happens

| Context | Function | Force | On Failure |
|---------|----------|-------|------------|
| Process state after eval | `validate-file` | `%.n` | Treat as crash, restart with `%rise` |
| `%make` single file | `validate-file` | `%.n` | Crash with error |
| `%make` subtree | `validate-ball` | `%.y` | Crash with error |
| Reload after on-loads | `validate-ball` | `%.y` | Crash with error |
| Poke crossing weir | `clam-cage` | `%.y` | Veto with error |

### Error Handling

- Dotket scry (missing mark): crashes - can't catch with mule
- Vale failure (bad data): returns tang - mule catches hoon-level errors
- `validate-ball`: crashes on any failure (precondition, not graceful)
- `clam-cage`: returns error tang (trust boundary, graceful rejection)

## Future Work
- [ ] Tarball explorer — universal tree browser and structural editor

  A nexus that serves an HTML UI for browsing and manipulating any part of the
  tarball tree. Like the explorer in `app/master.hoon`, but built as a nexus using
  the server/requests pattern.

  **Key insight: the tree is the app.** The explorer doesn't need to understand what
  any nexus does. It operates at the structural level using three primitives:

  - `peek:io` — read any node. Returns `view:nexus`: `[%ball =sand ball=ball:tarball]`
    for directories, `[%file =cage]` for files, `[%none ~]` for absent nodes.
  - `make:io` — create a file or entire subtree anywhere. The nexus at that location
    handles the rest via `on-file`. `make` takes `(each [=sand =ball:tarball] cage)`,
    so a single make can drop a full directory tree with files, permissions, and necks.
  - `cull:io` — delete a file or directory. Process dies, subscriptions clean up.

  The explorer becomes the universal admin UI for any mister app. No custom admin pages
  needed. Want to start the counter? Make a file at the right path. Kill an SSE
  connection? Cull its request file. Unbind a URL? Poke the server to unbind it. It's
  all tree operations.

  **Architecture:** Same pattern as counter-ui:
  - Explorer nexus at `/explorer/ui`, bind URL paths (e.g. `/mister/ball/**`)
  - Each request gets its own file at `/explorer/ui/requests/[eyre-id]`
  - Request process peeks the target path based on URL, renders HTML
  - Road from request file to target: up N to root, down to target path

  **Phases:**
  1. Read-only browser: directory listing, file display, tarball download
  2. Structural writes: make (create files/dirs), cull (delete), upload
  3. Guardrails: sand/weir already controls what's allowed where

  **File uploads** work naturally: upload a file → explorer does `make:io` at the
  target path → nexus `on-file` handles it. Upload a tarball → unpack → `make:io`
  with the full subtree.

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

- [ ] Explorer cleanup: consolidate `cage-to-mime` in explorer with `gen:tarball`'s version (avoid duplicating tube-building logic)
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
