# Grubbery: Grub-as-Process Application Model

## Vision

Grubbery is a meta-agent where **grubs are the fundamental entity**. A grub is the unified concept of a file and its running process — the living thing at a rail. Directories hold grubs and other directories, have a "nexus" that defines how grubs within behave, and may have a weir (sandbox rules).

Grubs are **persistent** — they live as long as they exist in the tree, handling many events over their lifetime. When the distinction matters, "file" means the data (content + metadata) and "process" means the running fiber.

## Core Principles

1. **Grub = File + Process**: Every grub has exactly one running process alongside its file content. No file without process, no process without file.

2. **Process Lifecycle**:
   - `%done` → grub is deleted (process completed its purpose)
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

- `ball` — tarball filesystem: `(axal lump)` where lump is `[=metadata neck=(unit neck) contents=(map @ta content)]`
- `pool` — running processes: `(axal pipe)` where pipe is `(map @ta proc:fiber)`
- `nexi` — compiled nexus definitions: `(map neck nexus)`
- `sand` — sandboxing filters: `(axal weir)`
- `born` — version tracking: `(axal [=tote bags=(map @ta sack)])` where `tote = [weir=cass:clay fold=cass:clay]` and `sack = [proc=cass:clay file=cass:clay]`
- `subs` — internal subscriptions: `[fwd=(map lane (map rail wire)) rev=(jug rail lane)]`

### Nexus
```hoon
++  nexus
  $_  ^|
  |%
  ++  on-load  |~  state=ball  *ball           :: initialize directory structure
  ++  on-file  |~  [path mark]  *spool:fiber   :: create spool (initializer) for grub
  --
```

### Process Types (fiber monad)
```hoon
+$  input    [state=vase in=(unit intake)]
+$  process  $-(input output)
+$  spool    $-(prod process)   :: initializer — takes startup reason, returns process
+$  output   [darts=(list dart) state=vase next=$%([%wait ~] [%skip ~] [%cont self=process] [%fail err=tang] [%done ~])]
```

### Prod (process startup reasons)
```hoon
+$  prod
  $%  [%make ~]     :: new grub created
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
  $%  [%poke =from =cage]              :: someone poked this grub
      [%peek =wire =seen]              :: local read result (seen = view or error)
      [%made =wire err=(unit tang)]    :: response to %make
      [%gone =wire err=(unit tang)]    :: response to %cull
      [%pack =wire err=(unit tang)]    :: response to %poke (ack/nack)
      [%sand =wire err=(unit tang)]    :: response to %sand
      [%load =wire err=(unit tang)]    :: response to %load (nexus reload)
      [%bond =wire err=(unit tang)]    :: subscription established/failed
      [%fell =wire]                    :: subscription canceled (weir change)
      [%news =wire =view]             :: change notification
      [%veto =dart]                    :: dart was sandboxed
      [%scry =wire =vase]             :: scry result
      [%bowl =wire =bowl]             :: bowl result
      [%arvo =wire sign=sign-arvo]    :: arvo response
      [%agent =wire =sign:agent:gall] :: agent response
      [%watch =path]                  :: subscription
      [%leave =path]                  :: unsubscription
  ==
```

### Dart (outbound effects from processes)
```hoon
+$  dart
  $%  [%sysc =card:agent:gall]         :: emit regular gall card
      [%node =wire =road =load]        :: send load to another path
      [%scry =wire scry=(unit scry)]   :: request scry (~ = get agent state)
      [%bowl =wire]                    :: request bowl
  ==
```

### Load (what you can send to a node)
```hoon
+$  load
  $%  [%poke =cage]             :: poke a grub
      [%make =make]             :: create grub or directory
      [%cull ~]                 :: delete grub or directory
      [%sand weir=(unit weir)]  :: set weir
      [%load ~]                 :: trigger nexus on-load (hot-reload)
      [%peek ~]                 :: read a grub
      [%keep ~]                 :: subscribe to changes at dest (grub or ball per road)
      [%drop ~]                 :: unsubscribe from dest
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

### Path Types
```hoon
:: lib/tarball.hoon
+$  rail  [=path name=@ta]         :: address of a grub (directory + name)
+$  fold  path                     :: address of a directory
+$  lane  (each rail fold)         :: [%& rail] grub or [%| fold] directory
+$  bend  (pair @ud lane)          :: relative: steps up + destination lane
+$  road  (each lane bend)         :: [%& lane] absolute or [%| bend] relative

:: lib/nexus.hoon
+$  from  (each rail:tarball prov)  :: source: internal grub or external

:: inside ++fiber (sandboxed view)
+$  bend  (pair @ud rail:tarball)   :: fiber bends always target grubs
+$  from  (each bend prov)          :: relative grub source or external
```

Helpers: `rail-from-path`, `path-from-lane`, `dir-from-lane`, `lane-from-bend`, `lane-from-road`

## Wire and Path Formats

Both outgoing wires and incoming watch paths use the `%proc` prefix:

**Outgoing wires (wex):** `/proc/{len}/{here...}/{born}/{wire...}`
- `len` — length of `here` path
- `here` — path to the grub that owns this subscription
- `born` — process instance timestamp (for stale detection)
- `wire` — the original wire from the process

**Watch paths (sup):** `/proc/{len}/{here...}/{subpath...}`
- `len` — length of `here` path
- `here` — path to the grub being watched
- `subpath` — sub-path within that grub's namespace

**Poke subscriptions:** `/poke/{src}/...`
- Used for external poke ack/nack delivery

## What's Built

### Core Infrastructure
- Fiber monad with %wait/%skip/%cont/%fail/%done
- Process storage (ball + pool + nexi)
- Event routing via wrapped wires with `%proc` prefix
- Bowl creation with filtered wex/sup (`make-bowl`)
- Nexus lookup from compiled map
- Default spool for grubs without governing nexus
- Unified `%grubbery-action` mark for all external pokes

### Process Lifecycle
- `++process-take` — queue intake and run process
- `++process-do-next` — evaluate process, handle result
- `++store-proc` / `++delete` — manage pool
- `++build-spool` — find nexus, call on-file
- %done → delete grub, clean subscriptions
- %fail → nack queued pokes, restart with `[%rise tang]`

### On-Load Recovery
- `++reload` — orchestrates full reload on agent load/init
- `++nack-pool` — nack pokes in old proc queues before rebuild
- `++run-on-loads` — top-down recursive nexus on-load execution
- `++spawn-all-files` — recursive walk spawning processes with `[%load ~]`
- `++load-ball-changes` — spawn processes then diff-balls for version bumps
- `++cull-ball-changes` — diff-balls against empty ball for deletion bumps
- `++sync-metadata` (lib/tarball) — preserve mtime for unchanged files, update for changed

### Version Tracking (++bo door in lib/nexus.hoon)
- `born=(axal [=tote bags=(map @ta sack)])` — version tree (high-water mark, never shrinks)
- `tote=[weir=cass:clay fold=cass:clay]` — per-directory version info (weir changes + content changes)
- `sack=[proc=cass:clay file=cass:clay]` — per-grub version info
- `proc.cass` bumped on process spawn/restart (stale response detection)
- `file.cass` bumped on content change (subscription notifications)
- `fold.tote` propagates up from changes to root
- `weir.tote` bumped on weir changes (via `++bump-weir`), propagates up
- `++bo` door: `get`, `put`, `init`, `bump-proc`, `bump-file`, `bump-dir`, `bump-weir`, `diff-balls`, `diff-born`
- `++diff-balls` — unified change detection: new/changed/deleted grubs + empty dir edge cases
- `++diff-born` — compare old and new born trees, return set of changed lanes
- Instance ID (`proc.cass`) included in wrapped wires for stale detection
- Comprehensive tests in tests/nexus.hoon (40+ test cases)

### Dart Handling
- `++process-dart` / `++process-darts`
- %sysc → emit gall card with wrapped wire, wrap %give %fact/%kick paths
- %node/%poke → enqueue take at destination with return address
- %node/%make → create grub or directory
- %node/%cull → delete grub or directory
- %node/%sand → set weir at path
- %node/%peek → return ball and sand subtrees at path
- %scry → synchronous scry (or agent state if ~), enqueue result
- %bowl → build bowl, enqueue result

### Poke Ack/Nack
- `took` type — `[=take err=(unit tang)]` tracks consumed takes
- Evaluator returns `done=(list took)` of consumed takes
- `++give-poke-sign` — ack/nack single took (only if poke)
- `++nack-poke-takes` — nack remaining queue on failure
- `++give-poke-ack` — route ack to internal path or external caller
- External ack: emit fact on `/poke/~ship/wire`, then kick
- `/poke/~ship/...` subscription handling in on-watch/on-leave

### Weir Sandboxing
- `sand` in state — tree of weirs
- Path helpers: `decap`, `prefix`, `path-from-bend`, `path-from-road`, `make-bend`
- Filter helpers: `raw-filter`, `filter-roads`, `filter`, `next-filt`
- `++nearest-governor` — find nearest directory strictly above both source and destination
- `++allowed` — walk up from source to governor, checking weirs (lane-aware)
- `++process-dart` checks filter, vetos if blocked
- `%veto` intake sent back with blocked dart
- `++edit-weir` — set/clear weir at path
- `++clam-cage` — validate poke cages at sandbox boundary via dais/vale
- Clam pokes when `filt=[~ %&]`, veto on failure (rejects %temp marks)
- Poke ack error sanitization — if poker can't peek target, nack with generic error
- `%load` dart for nexus hot-reload with mule error handling
- Graceful error acks for all make-category darts (%make, %cull, %sand, %load)

### External Entry Gate
- External pokes gated to `/public/*` or `/peers/~src/*` entry points
- `/public` and `/peers` directories created with blocking weirs `[~ ~ ~]`
- External ships "exist" in the tree at their designated locations
- Uniform sandboxing applies — external ships are tree citizens with weirs

### HTTP (Server Nexus)

The gall agent (`app/grubbery.hoon`) is a thin shell. All HTTP logic lives in the tree.

**Note:** HTTP requests go directly to `/server/main`, bypassing `/peers`. Eyre gestures at treating them as "from a ship" via `src.bowl` — this feels misleading.

**Server nexus** (`nex/server.hoon`) owns all HTTP concerns:
- Eyre binding registration
- Request routing (URL path → binding → handler rail)
- Response authorization (sender rail must match binding's handler rail)
- Connection tracking (`connections=(map @ta binding:eyre)`)
- Client disconnect handling (`%handle-http-cancel`)
- Orphan cleanup on unbind

**Gall agent** only does three things for HTTP:
1. Forwards `%handle-http-request` to `/server/main`
2. Forwards `on-leave [%http-response *]` as `%handle-http-cancel` to `/server/main`
3. Watches/kicks on `/http-response/[eyre-id]` paths (eyre plumbing)

**Requests pattern** — each HTTP request becomes its own grub:
1. Server receives request, looks up binding, forwards to handler
2. Handler `/main` creates grub at `/requests/[eyre-id]` via `make:io`
3. Request grub handles the request independently (SSE, long-poll, etc.)
4. Response flows back through `/main` → server → eyre
5. Server validates sender rail matches the binding's handler rail

**Reference:** `nex/counter.hoon` — self-contained counter app with HTTP UI and SSE streaming.

### Internal Subscriptions
- `subs` state with dual indices: `fwd` (target→watchers) and `rev` (watcher→targets)
- `%keep` dart → `sub-put`, check peek permission, send `%bond`
- `%drop` dart → `sub-del`, send `%fell`
- `++notify` — send `%news` to watchers when lanes change (via `diff-born`)
- Subscriptions persist through target deletion (watcher gets `%news` with `[%none ~]`)
- `++audit-weir` — re-check subscriptions after weir change, fell blocked ones
- `set-weir` is idempotent (no-op if sand unchanged, prevents notification cascades)

### Usergroups (Peers Nexus)

Role-based weir management via tree state. Implemented in `nex/peers.hoon`.

```
/peers/
  /main              poke router + weir manager
  /usergroups/
    /who/            group → members (hierarchical paths supported)
      /admins                  (set @p)
      /acme/eng/leads          (set @p)
    /how/            group → weir template (matches who structure)
      /admins                  weir:nexus
      /acme/eng/leads          weir:nexus
      /public                  weir applied to ALL ships
  /ships/            per-ship directories, created lazily
    /~zod/           weir = union of templates from all groups ~zod belongs to
      /main          gateway: page → cage, forward to dest
```

- Hierarchical group paths
- `compute-ship-weir` unions weir templates from all groups + `/how/public`
- Reactive sync: `/main` watches `/who`, `/how`, and `/ships`, re-syncs all weirs on change
- Our ship gets no weir (full tree access), foreign ships get computed weirs
- Groups have no inheritance — membership is explicit per group

### Explorer (nex/explorer.hoon)

Web UI for browsing the tree at `/grubbery/ball/...`.

- Directory listing with sortable table (grubs + subdirectories)
- File download/upload (single, multi, directory)
- Folder/symlink creation, grub/folder deletion
- Sandbox (weir) display per directory: "unrestricted" at root, detailed roads elsewhere
- Weir management: add/remove individual roads, clear entire weir
- Live updates via SSE — directory contents and weir changes push to the browser
- Breadcrumb navigation with nexus neck display

### Process Recovery (rise-wait)
- `rise-wait:io` helper in `lib/fiberio.hoon`
- On `%rise`: logs error, waits for any poke, then continues
- Applied to all nexus processes (peers, server, counter, explorer, root)

### Name Uniqueness (Unix Semantics)
- Grubs and directories cannot share a name at the same level
- Enforced in lib/tarball.hoon (`++put`, `++pub`, `++mkd`) and app/grubbery.hoon (`validate-names`)

### Mark Validation

Validation lives in app/grubbery.hoon, not lib/tarball.hoon. Tarball is a pure data structure; grubbery is the runtime that can scry for daises.

```hoon
++  validate-vase   :: pure — takes dais, handles nest optimization
++  validate-file   :: impure — scries for dais, handles %temp/empty-mime
++  clam-cage       :: trust boundary — rejects %temp, delegates to validate-file
++  validate-ball   :: whole tree — takes ball, returns ball, crashes on failure
```

| Context | Function | Force | On Failure |
|---------|----------|-------|------------|
| Process state after eval | `validate-file` | `%.n` | Restart with `%rise` |
| `%make` single grub | `validate-file` | `%.n` | Crash with error |
| `%make` subtree | `validate-ball` | `%.y` | Crash with error |
| Reload after on-loads | `validate-ball` | `%.y` | Crash with error |
| Poke crossing weir | `clam-cage` | `%.y` | Veto with error |

## Weir Sandboxing (Design)

Sandboxing controls what processes can reach.

**Governor Model:** The "governor" is the nearest directory strictly ABOVE both source and destination. Filtering walks from source up to the governor, checking weirs at each step.

- **Grub destinations**: Governor is the common prefix of source and dest paths. Siblings talk freely.
- **Directory destinations**: Governor is strictly above both. Can't escape your own sandbox.
- **Syscalls**: No governor — walk all the way up to root, checking every weir.

**Rules:**
- Darts moving DOWN the tree → always allowed (below governor)
- Darts moving UP the tree → checked against weirs at each directory until governor
- Weirs are lane-aware: grub rules vs directory rules
- %sysc (gall cards) → blocked by ANY weir (full walk to root)
- %make/%poke/%peek → checked against respective weir sets

**Filter results (`filt`):**
- `~` → no filter at this level (permissive)
- `[~ &]` → allowed but clam vases (validate via mark's dais)
- `[~ |]` → vetoed, send `%veto` intake back

## External Entry Gate

External ships can only poke into designated entry points:

- `/public/*` — shared public area, anyone can poke
- `/peers/~ship/*` — per-ship namespace, only that ship can poke

Once inside at their designated location, external ships become tree citizens subject to uniform weir sandboxing. Control external access by configuring weirs at `/public` or `/peers/~ship`.

**Default state**: Both `/public` and `/peers` have blocking weirs `[~ ~ ~]` (empty sets = block everything).

## Not Yet Implemented

### Small Items
- [ ] Handle outgoing keens — track per-process, `%yawn` on death/crash
- [ ] Explorer cleanup — consolidate `cage-to-mime` with `gen:tarball`'s version
- [ ] End-to-end testing — exercise the full flows

### Remote Scry
- [ ] `/c` permission scry — check if a ship can access a path (weir-aware)
- [ ] Keen tracking
- [ ] Versioning — may need custom scheme if historical versions need different permissions

## Future Ideas

### Nexuses and Marks in the Tree

Currently nexuses are compiled code in `nexi=(map neck nexus)` and marks come from Clay. What if they lived in the tree as source files?

- Store `.hoon` source as `%hoon` cages in the tree (e.g., `/sys/nex/server.hoon`)
- Compile to `%temp` vases during `on-load` (ephemeral, not persisted)
- Nexus lookup becomes tree lookup + grab from `%temp` cache
- Marks could work similarly — `/sys/mar/json.hoon` compiled on load

Benefits:
- Self-contained: app = tree, no external dependencies
- Versioning: nexus/mark changes are tree changes, tracked like any grub
- Hot reload: `%load` dart recompiles, no agent restart needed
- Sandboxing: weirs could control who can modify `/sys/nex/*`

Questions:
- Performance: recompiling on every load vs caching compiled cores
- Bootstrap: how does the root nexus compile itself?
- Clay integration: still need some marks for external I/O (eyre, etc.)

### Build System for Hoon in the Tree

If nexuses/marks live in the tree, we need a build system:

- Parse `/+` and `/-` ford runes from source files
- Build dependency graph between files
- Topological sort for compilation order
- Compile each file with its dependencies as subject
- Cache compiled cores as `%temp` vases

```
/sys
  /lib
    tarball.hoon
    nexus.hoon
  /nex
    server.hoon
    root.hoon
  /mar
    json.hoon
```

On load: scan `/sys` for `.hoon` files, parse imports, build dep graph, compile in order, store compiled cores. The tree becomes a self-building application package.

### Code Sharing Over the Network

If apps are self-contained trees of source, distribution becomes simple:

- **Export**: tarball the tree (already implemented)
- **Import**: untar into a path, run build system, go
- **Sync**: `%keep` subscribe to a remote ship's tree
- **Updates**: remote changes → `%news` → rebuild affected grubs

Benefits:
- Source-level sharing: you can read/audit what you're running
- Reactive updates: `%keep` makes sync automatic
- Selective sync: subscribe to subtrees, not whole apps
- Fork-friendly: copy tree, modify, your version

Questions:
- Trust: how do you verify source hasn't been tampered with?
- Versioning: semantic versions vs tree state?
- Rollback: keep old versions in tree history?

### LLM Process Architecture

The LLM API call is a universal primitive: send context, get back text or tool calls. Chat, agent, sub-agent, AI-powered tool — all the same thing: a grub that accumulates context, thinks (API call), and acts (tool calls into the tree).

**Core Idea:** An LLM process is a grub that watches a message tree, thinks when appropriate, and writes back. It doesn't own the messages — they live in a separate shared data structure. Multiple participants (human or LLM) can share a tree.

**Message Tree:** Conversations are stored as a tree (not a flat list). Each message has exactly one parent. Branching is free — "chats" are just named head pointers. Shared history is shared, no duplication.

**Tool Call Branches:** Tool use/result exchanges live on private branches off the main conversation. The main branch stays clean text. Tool branches preserved for auditing.

**Think Loop:**
1. New message appears (not from me)
2. Walk from head, build flat context with sliding window
3. Call API
4. Text response → append to tree
5. Tool use → validate, poke target grub, wait for response, loop back to API
6. Final text on main branch, wait for next message

**Tools as Tree Pokes:** Tool names encode destination path + mark. The LLM process decodes, runs JSON through a tube, pokes the target. Target grub receives a normal poke — doesn't know an LLM is calling.

**Multi-Agent:** Multiple LLM processes watch the same tree. Each has its own config and tools. `from` field identifies who said what. "Ack" response = silent pass, no message written.

**Composition:** An LLM grub calling another LLM grub is identical to any tool call. Sub-agents fall out naturally.

**Library Layers:**
1. `sur/llm.hoon` — fundamental types (provider-agnostic)
2. `lib/llm.hoon` — sliding window, context serialization, think loop (provider-agnostic)
3. `lib/llm/claude.hoon` — Claude-specific adapter
4. Application layer

### Tools & MCP Nexus

Port tool execution and MCP server from the old sailbox system.

**Tree Layout:**
```
/claude/          chats, conversation state, UI
  /main           HTTP dispatcher
  /config/
    /main         API key, model, system instructions
  /chats/
    /{chat-id}    per-chat grub (messages, pending-tools, title)
  /ui/
    /main         HTTP dispatcher for /grubbery/claude/*
    /requests/
      /{eyre-id}  per-request handler

/tools/           tool execution
  /{tool-name}/
    /main         tool manager (config, schema, approval policy)
    /requests/
      /{call-id}  active execution (ephemeral, %done when finished)

/mcp/             JSON-RPC 2.0 endpoint (external access)
  /main           HTTP dispatcher, binds /grubbery/mcp
  /requests/
    /{eyre-id}    per-request handler
```

**Per-Tool Manager:** Each tool has its own subtree. `/tools/{name}/main` holds config and dispatches. Request grubs do the actual work, then `%done`.

**SSE Flow:** Tools never touch SSE directly. Tool modifies chat state → chat SSE stream watches via `keep:io` → pushes event to client.

**Agentic Loop:**
1. User message → save to chat → call Claude API
2. `tool_use` → save as pending-tools → SSE approval event
3. User approves → poke to `/tools/{name}/main`
4. Tool grub executes, writes result back
5. All tools resolved → continue conversation
6. Repeat until text-only response

**MCP Nexus:** Thin JSON-RPC 2.0 adapter at `/grubbery/mcp`. Routes `tools/list` and `tools/call`. This is how external MCP clients access tools.

**Port Checklist:**
- [ ] Create `/tools/` tree structure in root nexus on-load
- [ ] Port tool definitions to per-tool manager nexus
- [ ] Create tool request process pattern (fiberio)
- [ ] Create `/mcp/` nexus with JSON-RPC handler
- [ ] Add agentic loop to `/claude/` (tool_use, pending-tools, approval)
- [ ] Add tool approval endpoints
- [ ] Add interrupt support (kill in-flight API requests)
- [ ] SSE stream: detect pending-tools changes, push approval events
- [ ] Port alarms (scheduled tool execution)

## Resolved Design Decisions

1. **Directories don't have processes.** Only grubs have processes. Directories can have a nexus that defines behavior for grubs within.

2. **The pipe map**: `pipe` is `(map @ta proc:fiber)` — one proc per grub in a directory. Map key is the filename.

3. **Inter-process communication**: Pokes carry a `give` with return address. Grub A pokes grub B, B's response routes back via `give-poke-ack` → `%pack` intake at A.

4. **%cull handles all deletion**: Since grub = file + process, `%cull` (delete at path) handles everything. No separate `%kill`.

5. **Subscriptions**: Watch paths use `%proc` prefix like wires. `%give %fact` and `%give %kick` paths wrapped automatically.
