# Layers and Gameplay Compatibility

Choose the place to make a change by responsibility. See the [Architecture Overview](https://github.com/BMingSY/isaac-lan/blob/main/docs/architecture.md) for architecture choices and [AGENTS.md](https://github.com/BMingSY/isaac-lan/blob/main/AGENTS.md) for collaboration conventions.

## Directories and Dependencies

| Location | Responsibility and boundary |
| --- | --- |
| [`src/app/`](https://github.com/BMingSY/isaac-lan/tree/main/src/app), [`src/bridge/app/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/app) | Loading, component registration, and call assembly; gameplay and state rules belong to their owning components. |
| [`src/net/`](https://github.com/BMingSY/isaac-lan/tree/main/src/net) | Protocol, UDP, queues, compression, and reliable transport; no access to game objects. |
| [`src/runtime/`](https://github.com/BMingSY/isaac-lan/tree/main/src/runtime), [`src/bridge/runtime/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/runtime) | Session progression, saves, startup, room/floor lifecycle, and invalidation boundaries. |
| [`src/bridge/sync/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/sync) | Fields, capture generations, replica restoration, and inventory/entity/grid consistency. |
| [`src/compat/`](https://github.com/BMingSY/isaac-lan/tree/main/src/compat), [`src/bridge/compat/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/compat) | Rules for Bosses, characters, items, routes, and challenges. C++ strategies receive plain values; Lua adapters use game APIs or named native capabilities. |
| [`src/bridge/compat/mods/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/compat/mods) | Third-party Mod source identification, interface detection, integration, and unloading; built-in adapters do not restrict usable interfaces by release version/source hash. |
| [`src/bridge/api/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/api) | Public contracts for third parties; no native pointers or arbitrary memory access. |
| [`src/presentation/`](https://github.com/BMingSY/isaac-lan/tree/main/src/presentation), [`src/bridge/presentation/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/presentation) | Menus, prediction, camera, appearance, audio, and visuals; no authoritative gameplay decisions. |
| [`src/bridge/lanbot.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/lanbot.lua), [`src/bridge/lanbot/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/lanbot) | Reads existing views and synthesizes normal input. |
| [`src/core/`](https://github.com/BMingSY/isaac-lan/tree/main/src/core), [`src/bridge/core/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/core) | Offline-capable data rules and shared geometry independent of game layouts and Hooks. |
| [`src/engine/`](https://github.com/BMingSY/isaac-lan/tree/main/src/engine), [`src/engine/versions/j460/`](https://github.com/BMingSY/isaac-lan/tree/main/src/engine/versions/j460) | Capability interfaces, version detection, native calls, layouts, Hooks, and object ownership. |
| [`src/diagnostics/`](https://github.com/BMingSY/isaac-lan/tree/main/src/diagnostics) | Logs, performance data, isolated capture, and feedback uploads; diagnostic switches do not control gameplay. |
| [`tests/`](https://github.com/BMingSY/isaac-lan/tree/main/tests), [`tools/`](https://github.com/BMingSY/isaac-lan/tree/main/tools) | Regression fixtures, builds, and acceptance tools; they must not become production gameplay dependencies. |

The assembly layer injects runtime, synchronization, compatibility, and presentation components. The runtime coordinator calls named capabilities through [`engine/session_backend.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/session_backend.h). The J460 backend installs Hooks; callbacks pass only plain values and original-game operations restricted to synchronization calls. Native objects are not exposed to the runtime layer. Lua ABI declarations and symbol loading are shared through [`engine/lua_api.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/lua_api.h).

Session views, startup requests, and save protection are owned by state components in [`session_state.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/session_state.h); file operations are managed by [`session_store.cpp`](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/session_store.cpp). Session protocol state stays on the main thread in `net/session.cpp` and `net/peer.h`. `net/socket.h` handles bounded data handoff. The network thread in `net/network_io.cpp` and `net/udp_io.cpp` exclusively owns connections, sending/receiving, and real-time compression contexts. `net/world_transfer.h` manages real-time view baselines and fragments; `net/reliable_transfer.h` and `net/reliable_receiver.h` manage reliable large-data fragmentation and assembly; `net/byte_worker.cpp` handles save-data byte tasks; hostname resolution is in `net/host_resolution.cpp`.

The embedded Lua manifest is [`modules.txt`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/modules.txt). Components define functions only when loaded; dependencies are injected after all components have loaded. [`app/main.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/app/main.lua), [`app/world.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/app/world.lua), the menu, and prediction entry points are assembled separately.

## State Ownership

| State | Owner | Invalidation boundary |
| --- | --- | --- |
| UDP queues, fragments, view baselines | Network thread | Shutdown, connection change, or reliable-transaction switch |
| Save compression/decompression tasks and completion results | Bulk-data worker and main-thread result tickets | Cancellation, session exit, or floor-transaction replacement; stale results cannot enter a new session |
| Session identity, input acknowledgement, floor generation | Runtime coordinator | New session, floor transition, rebuild, and rewind |
| Bridge startup phase and readiness generation | [`bridge/runtime/session.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/session.lua) | Shutdown or cancellation; native errors move the session to a failed phase |
| Room binding, depth, and borrowed complete player list | [`runtime/room_scope.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/room_scope.h) and J460 `Scope` | Native restoration and cleanup must complete in stack order |
| Rooms, characters, sprites, and MSVC containers | J460 backend and game | Native replacement, unloading, or destruction |
| Entity `ID → EntityPtr` and inventory-application cache | [`sync/replica.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/replica.lua) | Entity deletion, character replacement, or new run |
| Public fields, character state, and encoded-fragment cache | [`sync/capture.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/capture.lua) | Tick/floor generation change, transition, or new run |
| Movement and prediction trajectories | Replica and movement-presentation components | Room change, transition, or new run |
| Predicted hits and confirmations | Hit-presentation component and event ledger | Pause, invalid view, room/floor change, or session reset; deduplication sequence survives room changes |
| Sound sequence numbers, costumes, and presentation caches | Corresponding presentation components | New run; floor-related caches also invalidate by epoch |
| Per-player Hourglass checkpoint | Hourglass strategy and backend | Replaced when that player enters a room; cleared on a new run |

Character identity, controller identity, and native addresses serve different purposes. After a character body is replaced, the backend maintains the player list and ownership while the replica clears stale references. Compatibility modules do not create separate connections or maintain a second floor generation.

## Room Scope

[`ScopeStack`](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/room_scope.h) manages logical bindings only; it does not read game memory. Re-entering the same room and nesting across different rooms both increase depth and borrow the complete list saved by the outermost scope. Bindings cannot be copied or moved. Out-of-order restoration or destruction terminates the process.

The J460 `Scope` selects a separate temporary list by depth. It restores native scalars and the list, restores the parent room identity first, and removes the depth barrier only after shared-state exchange and temporary-allocation cleanup are complete. `TeamScope` temporarily switches only the complete list. Native layouts, Hooks, and MSVC allocation/release remain in the version backend. Logical stack-unwinding tests do not replace live-game resource acceptance. See [Rooms and Presentation](https://github.com/BMingSY/isaac-lan/blob/main/docs/rooms-and-presentation.md) for room transitions and render ownership.

## Capture and Replica Restoration

[`sync/capture.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/capture.lua) identifies each immutable capture generation by `(epoch, tick)`; gameplay must not advance while a view for that generation is being published. Public fields are captured once. Character base state and full presentation are cached separately. [`sync/room.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/room.lua) reuses entity/grid views per room. Sound, presentation, and item visuals are still captured per guest. Capture caches do not cross ticks. The synchronization layer projects fields; the network layer decides transmission only from the contents and revision numbers of two opaque byte sequences. Low-frequency dependencies are still captured every tick, sent reliably when changed, and included in any unacknowledged new view for recovery. The guest restores the complete state when the corresponding dependencies are available.

The restoration order in [`sync/replica.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/replica.lua) is:

1. Wait for floor readiness, decode the view, and validate the top-level schema, tick, and epoch.
2. Restore runtime item definitions through item-compatibility components, register the layout, and synchronize character rooms. Clear old movement records before changing rooms.
3. Resolve character identity and restore inventory, entities, and character-specific state within the corresponding character scope.
4. Restore shared pills, curses, waves, and door probabilities, overriding native side effects from inventory setters.
5. Update the map, then restore environment, entities, grids, and room state within the local room scope.
6. Apply input acknowledgements, sound, and presentation; commit the completed tick and character display records only after success.

Schema and owning components validate fields. This process does not provide native rollback: failures propagate to the runtime coordinator, the completed tick is not committed, and writes that already occurred are not automatically undone. See [Synchronization Contract](https://github.com/BMingSY/isaac-lan/blob/main/docs/synchronization.md) for field and transport limits, and [Session Recovery](https://github.com/BMingSY/isaac-lan/blob/main/docs/session-lifecycle.md) for startup and floor-transition order.

## Extension Boundaries

Generic fields and consistency belong to synchronization components; special gameplay belongs to the corresponding compatibility component. Strategies receive plain values, Lua adapters call game APIs or named backend capabilities, and the assembly layer only registers and connects components. Special gameplay must not leak game objects or matching rules into the network layer.

Field positions are defined centrally by [`fields.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/fields.lua) and the schema. Game IDs use enums or [`game_ids.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/compat/game_ids.h). See the [J460 reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md) for native capabilities, validation, and object ownership; see [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md#modified-contract-checks) for required checks after changes.

Current effects and support scope are maintained separately in the [character](https://github.com/BMingSY/isaac-lan/blob/main/docs/character-compatibility.md), [item](https://github.com/BMingSY/isaac-lan/blob/main/docs/item-effect-compatibility.md), [third-party Mod](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-compatibility.md), and [challenge](https://github.com/BMingSY/isaac-lan/blob/main/docs/lan-challenges.md) references. Public capabilities for third parties follow the separate [API contract](https://github.com/BMingSY/isaac-lan/blob/main/docs/third-party-mod-integration.md).
