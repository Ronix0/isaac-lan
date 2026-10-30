# Separate-Room Simulation and Local Presentation

The host advances every room with active players in sequence on the same thread. A guest displays the room containing its local character. Gameplay and presentation contexts are managed separately; the display list does not change controller identity or save order.

## Room Context and Ownership

The native game uses a process-wide current room. With separate-room simulation, a room is identified by `(dimension, roomIndex)`. [J460 Room Scope](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/versions/j460/rooms.cpp) temporarily switches the room, player list, render resources, and audio context, then restores the outer context on exit.

- The host updates every room with online players. After the last player leaves, the room is saved and unloaded through the native `RoomDescriptor`; entering it again follows native initialization.
- When a room is paused for an entrance animation, its room age is paused too; other rooms continue advancing. The first update after resuming retains native first-frame semantics. Repeated updates in the same game frame do not apply the time compensation more than once.
- A room's render buffer transfers complete reference ownership with the context. The game owns native containers, sprites, and cameras; they must not be destroyed by an incompatible C++ runtime.
- A character transformation may replace a body or the player list. On scope exit, native changes are merged. Callers must not keep using invalidated references.
- A guest loads only the background and entities for its local room. Teammates in other rooms use non-simulating storage shells that retain party state and multiplayer HUD data.

Nested scopes and stack-unwinding order are described in [Layers and Ownership](https://github.com/BMingSY/isaac-lan/blob/main/docs/layers-and-compatibility.md#room-scope).

## Transitions and Regrouping

1. A native door or teleport produces a destination request. The host validates the source, destination, and gameplay permissions.
2. After the current scope exits, character departure cleanup runs at a safe update boundary. If native route selection is needed, the final destination and entrance are resolved first; room ownership is then registered and the character and attached entities are moved.
3. If the final destination is not loaded, native initialization continues. If players are already there, existing room entities are retained and only the entering player's room-entry effects run. Native large-room sub-grid indices are normalized through the descriptor into a multiplayer room identity, while the original entrance context is retained. The room scope switches to the final destination within the same transaction, preserving the player list and outer restoration boundary.
4. Place the character at the native entrance, restore the foreground context, and unload empty rooms.

Extra door-entry invulnerability applies only when entering a room where a teammate is already fighting. Party regrouping and special routes are selected by compatibility strategies; the room runtime component performs the transition. Guest door state includes the slot, destination, type, lock state, and sprite. The destination comes from authoritative state.

Floor curses are maintained by the host. Curse of the Maze redirection and entrance selection reuse the native room-transition flow and are evaluated once per request. Guest replay, save-position restoration, ghost following, and party regrouping use the already determined destination; they skip route selection again and preserve the shared curse state. Original room-content swapping applies only to rooms without an active instance or an offline retained instance, preventing replacement of a teammate's entities or room descriptor. See [Native Transition Capabilities](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#transitions-and-pause) for integration boundaries.

## Local View and HUD

Characters in multiplayer LAN sessions use the original multiplayer outline. Colors are fixed by player: P1 red, P2 blue, P3 yellow, and P4 green. A color follows the controller's player identity, not local HUD ordering, body replacement, or room changes. Two bodies belonging to the same player share a color. Outlines are drawn with the native body, head, and costume, retaining visibility, damage flicker, and normal tinting. No extra player number is shown. The presentation strategy is in [player_outlines.h](https://github.com/BMingSY/isaac-lan/blob/main/src/presentation/player_outlines.h); drawing boundaries are in [Native Outline Capability](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#player-outlines).

`withView` temporarily switches to the local room and places the local controller's character near the front of the display list. During a floor transition, when no valid room exists yet, local HUD ownership is still retained. The original list is restored after drawing. After a guest accepts an ordinary downward-floor event, the native jump animation starts for its living local character, then the native floor-transition flow advances. Same-floor resets, upward transitions, and transitions owned by compatibility components retain their own animations.

| Content | Ownership |
| --- | --- |
| Background, camera, and map focus | Room containing the local character |
| Health, cards, and active-item slots | Original multiplayer HUD, matching characters by controller |
| Stat panel, item list, and pickup notifications | Local controller's character |
| Ping | HUD for the corresponding online guest, using RTT measured by the host; unknown is shown as `—`; the host does not display its own ping |
| Map and Mod interface input | Local physical input |

HUD coordinates are read through named backend capabilities. Lua presentation components receive only identity and position; they do not hold native objects. See [Native Capability Reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#hud-and-local-input) for the boundary.

Character chat bubbles are drawn after the room scene. After converting world position to screen position, the horizontal coordinate is reflected according to the local room's mirror state; text and emotes remain upright.

## Movement Prediction and Camera

For each walkable body associated with the local controller, every render queries the latest input direction through the native movement interface and maintains an independent display trajectory. Authoritative confirmation uses both the state tick and input sequence. A newer tick with the same input sequence still restores the authoritative position and velocity, then predicts again using the directions, durations, and control locks of unacknowledged inputs. An acknowledgement sequence represents a sampled input state, not the number of host simulation steps. This recalculation is a display approximation and does not replay authoritative gameplay. Up to 120 rendered input samples are retained.

Ordinary walking prediction uses MoveSpeed for direction projection, turn damping, and reverse acceleration; releasing a key decays independently. Each half-tick applies current friction first, then advances position and updates velocity, matching the original integration order. Grid collision samples the body radius and sweeps along the movement path in steps, sliding along a traversable axis when blocked. Teleports do not sweep obstacles along the old path. If an old display position already overlaps a collision boundary, correction starts from the host-accepted position so each correction is not rejected by the same wall; normal prediction still checks each grid segment.

Flying characters and multiplayer ghosts can cross pits and ordinary obstacles but remain blocked by solid walls. Ghost identity does not depend on `CanFly`. Animations that permit walking, such as pickups, item use, lifting/putting away an item, pills, and ordinary damage reactions, retain movement prediction. Control state, body state, and additional animation are considered together; an unfinished additional animation alone does not mean movement is locked.

Character and route compatibility components determine whether a body uses ordinary walking prediction. Otherwise, the authoritative movement trajectory is used and previous walking offsets are cleared, while the actual input acknowledgement sequence is retained. Basement ladders, gravity, and platform collisions use the original platforming movement model; guests do not apply free movement from ordinary rooms. See the [Character Compatibility Catalog](https://github.com/BMingSY/isaac-lan/blob/main/docs/character-compatibility.md) for character differences.

A true control lock pauses new movement and clears prediction velocity while retaining pending trajectories and the real acknowledgement sequence. Late authoritative corrections continue to be smoothed. Local input responds immediately when control resumes. Room changes, floor changes, and body replacement clear trajectories. After reaching the door threshold, the guest waits for the host to confirm the destination and starts a short local fade-out. Fade-in begins after confirmation. Reverse movement, rejection, pause, or state reset cancels the presentation; it does not select a room early.

For an ordinary single-lock or double-lock door, when the local player has enough keys or a Golden Key, a door-front movement preview of up to 250 ms is allowed. Position remains inside the source room. No unlock interface is called and no key is consumed; door fade-out begins only after the host confirms the door opened. On rejection or timeout, collision is restored and the character is corrected. Holding the direction cannot repeatedly start the same preview.

Approaching a small Basement ladder also starts a transition fade. Turning or releasing the input can cancel it; the host still determines the entrance and return position. During guest fade-in at the destination, movement prediction and movement-input sending are both stopped. Distance is not accumulated for a catch-up movement after the fade. Fade-in time starts with the first frame actually drawn at the destination; room loading cannot consume an animation that has not yet appeared on screen.

After the host's complete update and a half-frame room-switch check, input is validated against its owning room. Input from the old room retains only same-floor held shooting state and cannot move a character in the new room. Once fade-in ends, prediction and sending resume immediately in the current direction.

Local walking animation is applied after snapshot appearance restoration, using the current direction. Fractional frame progress is retained independently and loops according to the actual animation length for each body/costume. Stopping, control lock, and special actions retain the authoritative pose. Head aiming and extra actions do not advance with the walking clock.

Weapons attached to a body retain their authoritative relative positions and receive the same display offset after body prediction. Laser paths, endpoints, and hit effects are translated together. Carried entities and their weapons share the carrier's display offset; after being dropped or thrown, they return to their own trajectories. Attachment relationships are determined by authoritative carry links, entity type/subtype, parent reference, and the native follow flag. A spawner reference alone does not imply attachment. Free-flying attacks retain their own trajectories. When a relationship becomes invalid, the entity falls back to its own trajectory; room changes and body replacement clear old trajectories. See [attachments.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/attachments.lua).

Independent entities share the host capture-clock mapping and extrapolate from estimated capture-to-render age, capped at 100 ms. Packet-arrival time is not treated as simulation time. [Timeline mapping](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/timeline.lua) combines recent minimum arrival difference and half the minimum RTT to filter queue jitter. One-way time on an asymmetric link remains an estimate. When new state arrives, the current display position is retained and the difference converges smoothly from the receive time. When successive authoritative NPC states show clear deceleration in the same direction, the display estimates velocity decay from actual tick intervals and converges the braking correction faster. The correction starts from the position actually displayed in the previous frame; it no longer advances again using an invalid old velocity. This decay estimate is not reused for turning, acceleration, or long gaps without packets. Ordinary projectiles and characters continue to use their own display models; guests do not run NPC AI or predict target tracking.

Creation, disappearance, animation, and game properties are submitted with the same complete authoritative view. Motion extrapolation advances display position only; hit presentation is managed by a separate event component. Repeated ticks do not restart trajectories. A jump greater than 96 coordinate units is treated as a teleport. Room changes, floor changes, and entity replacement clear old trajectories. An abrupt stop or turn that has not yet arrived may still require correction. The guest camera updates after the predicted position is determined.

Movement prediction affects only local presentation; special forces and complex movement may still be corrected. Implementation: [prediction.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/prediction.lua).

## Attack Presentation Prediction

The local body obtains its current aim direction through the native shooting-input query. After authoritative appearance restoration, it updates the direction of the head and costume. Supported charge weapons replay unacknowledged input from authoritative weapon state, using the limit calculated by the native weapon. Only the charge value required for drawing is replaced; charge is not estimated by multiplying the firing interval by a fixed factor. A late charge snapshot cannot override a release that already cancelled charging. Weapon differences are selected by the [Attack Presentation Strategy](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/items/attack_preview.lua); supported scope is listed in the [Item Compatibility Catalog](https://github.com/BMingSY/isaac-lan/blob/main/docs/item-effect-compatibility.md#attack-presentation).

Tears that meet ordinary single-shot conditions are drawn as short-lived independent sprites according to the local cooldown clock. They do not create game entities, call the firing function, or use random numbers. Cooldown is checked on native simulation steps and retains fractional remainder. The weapon clock continues advancing even before the appearance is available. Appearance is taken from a confirmed tear fired by the local character; Isaac's original starting tear can be displayed directly.

Initial tear velocity combines the firing direction with predicted body movement inertia. Tear speed scales both components and the spawn offset. Range uses the tear height, falling speed, and acceleration already calculated in the character cache, advancing them in native damping/gravity order; range is not treated as a fixed lifetime. Initial random spread uses a mean approximation, while authoritative entities retain their actual random result. Authoritative tears are matched by shooter, firing velocity including inertia, age, and input acknowledgement. Only one prediction sprite is taken over. During correction, deceleration relative to projectile speed is limited. Unacknowledged sprites are limited by count, lifetime, landing, and grid collision. Unsupported trajectories, combinations, and unknown appearances continue waiting for authoritative state. Ordinary projectile calculations are in [tear_motion.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/tear_motion.lua).

Attack-presentation state belongs to the current view. Control lock cancels unacknowledged sprites. Pause, door transitions, floor changes, disconnects, and character/weapon changes clear the corresponding prediction. Attacks are not continuously generated when snapshots stop advancing. Independent sprites in mirror rooms are drawn using the local screen-mirror state. Preview sprites do not pass through the full native room shading and water-reflection pipeline, so their color/reflection may change when authoritative state takes over.

The host decides authoritative hits, damage, collision-effect entities, sounds, pickups, and item effects. Local hit presentation for ordinary tears uses the event confirmation described below. Implementation: [attacks.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/attacks.lua) and [attack_prediction.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/attack_prediction.lua).

## Hit Presentation Prediction

After entity-position prediction, the [hit component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/hits.lua) performs continuous circular-contact detection between local ordinary tears and hittable NPCs, using relative movement. It selects the earliest contact and checks the path against grids. On the contact frame, the target is drawn with the original hit appearance and the tear expected to be consumed is temporarily hidden. It does not call damage, death, AI, native entity updates, or random numbers. A short flash overrides drawing only within the room render scope; the sprite color is restored immediately after drawing and is not stored as a persistent snapshot property.

The [event ledger](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/event_ledger.lua) matches predictions using host source/target IDs. When confirmed, it retains the original playback clock; duplicate or late events do not replay. If the host rejects the prediction or confirms a different target, the incorrect presentation is reverted. If no result arrives within 350 ms, the hidden projectile is restored. Pause, door entry, floor changes, disconnects, and invalid views all clear the relevant state. Prediction stops when no new state has arrived for 250 ms. Room changes clear effects but retain event sequence numbers to prevent old events from replaying after returning. A new floor or session can establish a new sequence context.

Authoritative hits that were not predicted play only their remaining flash duration. The host's own hit display also uses the original hit appearance and duration, restoring the original value after drawing. Normal color, tint, and other Mod calls to SetColor retain their original semantics.

This contact prediction applies to ordinary blue/red tears for which a host entity ID has been received, including ordinary multi-shot tears that can be identified individually. Firing previews without a host identity, lasers, melee, piercing, explosions, and tears with special TearFlags use authoritative event presentation. This does not claim that arbitrary items or monster AI are simulated locally. Native impact sounds and collision-effect entities are still displayed from host events/state to avoid duplicate triggers.

## Audio-Visual Events and Resources

Sounds and Boss announcements are filtered by room viewers. Cards, pills, item notifications, and full-screen animations are filtered by the triggering controller. Events use sequence numbers and floor generations for deduplication. Guests restore presentation only; they do not call original item-use methods.

Music requests are managed by `(floorEpoch, dimension, roomIndex)` and include the current track and queued follow-up tracks. For rooms with no recorded request, the native selector is used. Each room has an independent virtual track ID, while the actual playback channel belongs only to the local view. Players who remain in a room hear the intro/end track and follow-up tracks in original order; players who enter later join the follow-up track directly. Repeated snapshots do not replay an already received request. Payload and scope boundaries are described in [Audio Capabilities](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#room-music).

The host captures animations during each room update. Guests restore character costumes, charge, shadows, laser paths, and sprite-layer state at the render boundary.

Each controller owns an independent native ItemOverlay. The host advances it and synchronizes its state, delay, and sprite. Guests do not run native Overlay updates that could cause healing or transition side effects. Additional presentation objects are managed through the game's own construction/destruction entry points. Background baking and render-resource cleanup also follow the local-room lifecycle.

Purely local effects receive no synchronization ID only when they are explicitly known to have no gameplay impact. Other entities and effects are restored from authoritative views. Temporary changes to process-wide render state in background rooms must be restored before local presentation.

## Mod Callbacks and Input

Global `MC_POST_NEW_ROOM` and `MC_POST_UPDATE` callbacks run in the local-room context. Host-side entity, damage, and other gameplay callbacks run in the corresponding authoritative room. Rendering and UI use local physical input through `input::ViewScope`; character combat consumes the corresponding controller input received by the host.

Third-party interfaces express intent through the [Host Actions API](https://github.com/BMingSY/isaac-lan/blob/main/docs/third-party-mod-integration.md#host-actions-and-receipts) or restricted room requests. They cannot submit arbitrary world state. Gameplay Mods that depend on global callbacks need explicit adapters. Private state belonging to arbitrary Mods is not copied automatically; see the [Mod Compatibility Catalog](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-compatibility.md) for supported scope.
