# Session and State Recovery

The runtime coordinator manages startup, floor transactions, saves, and exit. The network layer provides ordered delivery; the game backend owns native loading and object lifetimes. Network connected, bridge ready, and native world ready for application are separate boundaries.

## Lobby and Starting a Run

The guest handshake carries the protocol version, extension fingerprint, player identity, and Mod fingerprint. Protocol and extension versions must match; Mod differences are warnings only. The host publishes the seed, difficulty, character order, and run rules. Each player's character eligibility comes from that player's own save. Changing rules clears ready states, and ready requests from an older rule generation are invalid.

Room options are an independent bit set within the run rules. The lobby displays a one-line summary. The host can edit options in a rules submenu; guests can view the list read-only. Each toggle is synchronized immediately and does not wait for the menu to close. The [Room Rules](https://github.com/BMingSY/isaac-lan/blob/main/docs/room-rules.md) component defines their meaning; the network carries only the bit set. Continuing a previous multiplayer run uses the saved rules. If they differ from the lobby, load the saved rules and ready up again. Rules persist through startup, saving, reconnecting, and restarting.

Character-card completion marks are generated from each player's personal progress, submitted with the character selection, and forwarded by the host. The current character preview is also published when first entering the lobby. A standalone preview refresh carries the rule generation and character ID; it can update only the sender's current character and does not change ready state. Expired previews and previews arriving after the run starts are ignored. Shared in-game progress does not replace the lobby's personal records. Cards show only three states: incomplete, normal, or hard.

```mermaid
sequenceDiagram
    participant C as Guest
    participant H as Host
    C->>H: hello: version, identity, and fingerprints
    H->>C: welcome / lobby: slots and lobby state
    C->>H: choice: character and ready state
    H->>C: start: settings and optional checkpoint
    C->>C: Native start / Continue; bind characters and rooms
    C->>H: ready: engine initialized
    H->>H: Advance after initial players are ready
    loop During gameplay
        C->>H: Input and requests
        H->>C: Local-room view
        C->>H: applied: restoration completed
    end
```

[`bridge/runtime/session.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/session.lua) manages `idle → starting → initializing → preparing → ready`. Once the native virtual controller is ready, each startup generation issues only one start request. The [character-binding component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/party.lua) validates each slot's independent character and controller ownership. Character creation, room activation, synchronization barriers, and room restoration all run during `preparing`; nested callbacks cannot create characters twice. Before the first native input update, Continue passes through a protected character-binding step and restores slots in save order rather than inferring ownership from physical controller IDs. Shutdown invalidates the generation, so stale callbacks cannot advance it. A preparation error tells the runtime coordinator to end the current game instead of retrying a partially completed operation every frame. The front end can still handle reconnecting or leaving.

Network `loading` means only that checkpoint transfer is incomplete. After transfer, native loading and engine readiness are still required. Initial startup waits for all initial players; each loading request has a maximum wait of 60 seconds. Reconnecting during a run does not block players who are already online.

If an error occurs before a startup request is handed to the native engine, no game-exit callback will occur. The runtime coordinator immediately restores single-player save protection, discards the incomplete checkpoint, and tells the bridge to release the startup generation. The guest retains the failed session identity and can retry or leave. If the native game has already started, cleanup still waits for actual exit completion.

## Native Floor Transitions and Rebuilds

When the host starts a native floor transition, it publishes a reliable `Stage` transaction containing the source floor, type, animation, seed, route marker, source room, and new `floorEpoch`. Each client executes native route selection using the same source context; the host's choice is not inferred from the guest's current viewport.

The transaction runs in this order:

1. Accept the new generation and reject duplicate or expired transactions.
2. Clear old views, delta baselines, prediction, and entity mappings.
3. Execute the native transition animation, floor change, or rebuild.
4. After floor preparation, re-enter the room context and apply the new-generation view.

Ordinary online floor transitions do not rebuild through a full Continue. Same-floor reset and the R Key item synchronize the native seed and layout; the host confirms a victory lap before running the native flow. Special routes provide strategies through compatibility components; the network layer does not identify routes. See the [backend reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#transitions-and-pause) for native source context and transition capabilities.

## Pause and Exit

Any online player can initiate a party-wide pause; the initiator resumes it. If the initiator leaves, the host resumes. Views synchronize the paused state and initiator. Each client handles menu pages, cursor, Items, and Options through local input.

Resume and host save-and-exit are reliable session commands. A guest leaving from the menu closes its connection voluntarily; the host parks the character according to the offline lifecycle. The pause menu does not send directional or confirm actions to the host. Held shooting input is retained while paused. Options are saved to local configuration before closing, and Switch Controller cannot rewrite multiplayer controller bindings.

Only the host can save and end the session. When a guest leaves alone, its character is parked and its main state is retained. Offline characters do not count toward combat or reward-player totals. Exit, floor transition, and migration execute at safe update boundaries. Single-player save and progress protection remains active until native exit completes. At the end of exit, personal progress is merged and saved before returning to the menu, so the next run reads the merged counters.

Party death and victory are confirmed by the host's native ending flow and sent to guests through a reliable end event. Reaching zero health, delayed death during a transformation, and a revivable state do not themselves trigger settlement. After receiving the event, a guest stops applying gameplay snapshots and enters the original death-settlement or ending flow. The same end event is applied only once; a later close message does not discard a pending ending animation. Death does not count as challenge completion.

After victory, the multiplayer room is retained while each client plays its own ending. Once the ending finishes and the native menu is rebuilt, the multiplayer interface appears automatically. The host returns to character selection and ready state after receiving native exit receipts from all online members. If a member has not completed exit cleanup, the interface shows a waiting state. Disconnected members do not block the return; remaining members retain their identities and connections, and empty slots are compacted. Character selections and run rules are retained, but ready states are cleared. Each player readies again after returning to the interface, then the host can start the next run. A new run uses a new run identity and rebuilds the engine-readiness barrier; input, snapshots, and inventory from the previous run are not inherited. Personal save protection remains active through the native exit tail.

## Party Restart

The restart button on the results screen, holding R in-game, and the original controller restart combination submit each player's consent. The runtime collects votes through a separate reliable lifecycle channel. At the bottom of the screen, the original R Key item icon, segmented outer ring, and consent count are displayed. Each player corresponds to one ring segment; it lights up after consent. No new page opens, and one player's vote does not pause gameplay. Once every online member agrees, the host generates a new seed, retains connections, player identities, slots, starting characters, difficulty, and challenge rules, clears this run's items and progress, and starts the party together.

Votes belong to the current run identity and vote generation. Repeated consent does not add another vote. If the group does not reach agreement within 20 seconds or the online roster changes, the current vote round is cleared. Messages from an old generation cannot be counted again. A restart transaction is temporarily deferred while a reconnect checkpoint is being transferred; a newly joined online member must confirm again.

The restart transaction first advances the world generation and clears input, end events, snapshots, and delta baselines. Each client then exits the old run at a safe boundary. After the native exit tail completes personal-save and progress restoration, the bridge repeats the full startup flow. Connections and slots remain, while the game destroys and rebuilds native objects. Engine-ready acknowledgements include the run identity, so an acknowledgement from the old run cannot release the new-run barrier. The host advances simulation after the new run's online players are ready. The R Key item still uses the floor-transition compatibility flow.

## Reconnecting on the Current Floor

```mermaid
sequenceDiagram
    participant C as Guest
    participant H as Host
    H->>H: Park disconnected character and continue
    C->>H: Reconnect with original player identity
    H->>H: Capture current-floor checkpoint at a safe boundary
    H->>H: Compress and validate independent save bytes in background
    H->>C: start + compressed snapshot chunks
    C->>C: Validate and decompress in background
    C->>H: loaded: fully received and restored
    C->>C: Native Continue; prepare character and room
    C->>H: ready: engine initialized
    H->>H: Activate retained character in host's room
    H->>C: Latest floor transaction and real-time view
```

The original character during a run is identified by `player-id.txt`. The checkpoint is captured after all loaded rooms have been saved, temporarily including the parked character in the serialization list without allowing it to participate in combat. Until the guest is ready, it cannot submit valid gameplay input and does not count toward the online-player total.

The complete checkpoint is compressed and transferred; the guest's old save is not used as a delta baseline. The compressed result is immutable and can be shared by multiple guests waiting to reconnect. Native-state capture and restoration never run on background threads. Startup or floor barriers are not released until compression/decompression completes. Results from cancelled or replaced transactions are discarded.

The host continues simulation during loading and retains the latest floor transaction for the connection. Once the guest is ready, it processes that transaction before receiving real-time views. Waiting and loading screens use the party's character list supplied by the host.

The guest menu offers **Reconnect to Game** and **Leave Game**. A manual reconnect first releases the old connection, waits for native exit to finish, then reconnects using the original address, port, and player identity. An unexpected disconnect automatically tries once. Recovery state is retained across native exit and ends after the first real-time view is applied successfully; the menu closes and input is released. If connection or recovery fails, the retry entry remains available; failed character state is not rebuilt in an automatic loop. Leaving cancels pending reconnect work and cleans up the session.

The checkpoint uses original save/continue semantics. Main state such as items and health is restored, while temporary entities and some timers may be rebuilt. Adding new players mid-run and migrating the host are not supported.

## Multiplayer Saves and Continue

[`session_archive.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/session_archive.h) defines the save container: extension fingerprint, startup settings, run rules, party positions, native GameState, and integrity hash. `IsaacLAN/save/4` stores room options; reading also supports `save/3`, which has no options field and defaults all options to off. The format and fingerprint must match. The complete file is limited to 8 MiB.

The host's three save slots use `session-1.bin`, `session-2.bin`, and `session-3.bin`, managed separately from single-player Continue. Writes use temporary-file replacement. On failure, the old file and in-memory pending snapshot are retained. Retries always use the original save slot, and a new multiplayer run cannot start until the save succeeds.

Continuing after the entire session has closed requires the original host, original save slot, original player count, and original join order. Reconnecting during a run is validated separately by player identity and does not use the full-session Continue slot requirements. Temporary challenges do not overwrite existing multiplayer saves and support only reconnecting during the run; see [Multiplayer Challenges](https://github.com/BMingSY/isaac-lan/blob/main/docs/lan-challenges.md).

## Party Rewind

The Glowing Hourglass stores a full native party checkpoint and positions for each controller when that player enters a room. The host performs the original route decision in the user's source room and sends the result through a reliable transaction; guests replay that result rather than selecting a route again locally.

When the native choice is rewind, the checkpoint and party positions are restored. When the choice is Home or another room transition, the corresponding original behavior is retained and old positions are not forcibly restored. Without a checkpoint, only transitions allowed by the original rules are available. Rewind may cross floors. State sequence numbers continue increasing, the world generation advances, and views from before the rewind cannot be applied again.

## Failure Boundaries

| Failure point | Handling |
| --- | --- |
| One guest has a protocol error or connection timeout | The host removes that connection and continues the run. |
| Guest state application or bridge error | The guest ends the current game and returns to the lobby; it can reconnect if the original session and identity remain valid. |
| Host bridge or native-adapter error | Session-level failure; the entire game may end. |
| Multiplayer save write failure | Retain the old file and pending snapshot, then wait for a retry. |

Integrity hashes validate transfer and saves; they do not compare the two sides' random sequences. Native-state application has no transactional rollback, and a failure cannot be hidden by sending a completion acknowledgement.
