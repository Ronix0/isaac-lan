# Multiplayer Challenges

The host selects a multiplayer challenge in the lobby. Its run rules constrain characters, difficulty, goals, and gameplay effects. The network transmits a rule descriptor; challenge compatibility components implement the gameplay, while the interface reuses the original HUD.

## Current Rule: 1001 Demon Form

| Item | Behavior |
| --- | --- |
| Eligibility | Every player must have unlocked The Negative and Tainted Cain in their own save. Shared host progress does not count toward eligibility. |
| Start | Normal difficulty, Tainted Cain, 2–4 players. |
| Bag of Crafting | Fixed slots form a P1 → P2 → … → P1 observation cycle. The next player's materials and native preview are shown, but the actual materials and crafting action still belong to that player. |
| Identity changes | Death, disconnects, and reconnects do not reorder the observation cycle. The display is hidden if the target is missing, is a ghost, or has no bag. |
| Route and goal | Follow the original route to obtain The Negative and reach the Dark Room. After clearing The Lamb's room, an original trophy replaces the end-of-run chest. |
| Completion | An online, living, non-ghost character claims the trophy. The host publishes one reliable end event and the whole party returns to the menu. No original challenge unlock is written. |
| Saving | Temporary session only. The full run cannot be resumed, and existing normal multiplayer saves are not overwritten. Original guests can reconnect through the current-floor checkpoint. |

Non-final end chests, original endings, and victory-lap entrances are restricted by the rules. After The Lamb is defeated, Void entrances, floor trapdoors, and Heaven light beams that could bypass the goal are removed; ordinary room doors remain. Claiming the trophy is the only way to complete the challenge. Death and manually leaving can still end the session.

## Current Rule: 1002 Luck Game

| Item | Behavior |
| --- | --- |
| Start | Normal difficulty, 2–4 players. Characters are unrestricted, subject to each player's normal character-selection eligibility in their own save. |
| Starting trinket | Each player permanently swallows one No!, which does not occupy a trinket slot. Existing starting trinkets are preserved. The original rules for preventing active-item generation still apply. |
| Pickups | After the original game confirms a non-active pedestal pickup, every online, living, non-ghost player rolls D100 once. The player's current Luck is added to the result, and the highest total receives the item. |
| Ties | Tied players are ordered randomly. The highest and lowest players on a floor transition cannot be the same player. |
| Floor transitions | Each time the run advances to a deeper floor, players roll. The lowest player randomly gives one held item to the highest player. Starting a run, resetting on the same floor, or rewinding does not trigger a transfer. No transfer occurs if the lowest player has no item. |
| Item scope | Active items are picked up normally and are not rolled or announced. Passive items and duplicate copies participate in pickup allocation. Floor-transition transfers draw from actual held copies (including carried active items); pocket actives belonging to the character are excluded. Gifts preserve active charge and item-internal data, and do not grant first-pickup resources again. |
| Room clear | Each actual room-clear reward also spawns one free Luck Up pill, independently of the original reward and choice group. |
| Goal | After clearing the Boss Room containing Mom's Heart, a trophy appears and floor exits are removed. Claiming the trophy ends the challenge for the whole party. |
| Chat | Announces the pickup recipient, each player's original `/d100` result, and the winner after Luck modifiers. Floor transitions announce the rolls and item transfer. |

The starting trinket is initialized by the compatibility component when the host is ready and in the guest's first accepted view. A checkpoint that already contains the swallowed state is not initialized again; this does not depend on rerunning the item-allocation roll.

Pickup and floor-transition allocation reuse the player grouping, D100 ordering, and native grant functionality in [loot_roll.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/rules/loot_roll.lua). The challenge supplies its own Luck modifier. The normal [item dice-roll room rule](https://github.com/BMingSY/isaac-lan/blob/main/docs/room-rules.md#item-dice-roll-allocation) does not supply a modifier. The challenge's own pickup strategy takes priority; enabling both options still settles an item only once.

The original game remains responsible for pickup eligibility, purchase costs, choice groups, and pedestal replacement. Allocation happens only after an item has been confirmed and entered into the pickup queue. Therefore, starting items, console grants, crafting, rerolls, and state restoration do not trigger pickup rolls. Original character behavior that converts a pedestal into materials is preserved. If the recipient already has an active item, the original drop is retained; a gift does not trigger a second roll.

## Current Rule: 1003 Battle Royale

| Item | Behavior |
| --- | --- |
| Start | Normal difficulty, 2–4 players, Isaac. The starting D6 is removed; active items acquired later are kept normally. Friendly Fire is fixed as the room rule, other optional rules are disabled, and neither host nor guests can change them. |
| Map | The first round uses the first floor of the normal route. Later rounds randomly select floors 1–5, preserving the normal floor variants. Available positions are expanded within a 13×13 grid using the original red-room rules, while retaining normal exploration resources. Players are assigned to different corners at random. Spawn rooms have enemies and obstacles cleared, but keep pickups and doors. Spawn assignment and fixed Boss teleportation are not redirected by the Curse of the Maze; ordinary exploration retains the original curse behavior. |
| Resource rooms | Existing rooms of each type count toward the target: 16 Treasure Rooms, 8 Shops, 4 Libraries, and 4 Arcades. Reachable Treasure Rooms near spawn are prioritized, with at least half the quota retained in the first ring; the rest are distributed across regions. Spawn rooms, the Boss Room, the starting room, and the final battle room are reserved. If templates or available positions are insufficient, original connections are preserved and additions are made only in compatible positions. |
| Room entrances | Treasure Rooms and Shops can be entered without keys. Items still cost their original prices. Combat doors remain locked until the room is cleared; after the safe zone shrinks, doors open according to the escape rules. |
| Survival | At 90, 180, and 240 seconds, the safe zone shrinks from the full map to 9×9, then 5×5, then one room. Each new zone is selected at random and must be fully contained within the previous zone. The final room is selected from existing normal 1×1 rooms, excluding Boss Rooms. After a shrink, players may leave uncleared rooms. Players outside the zone take continuous damage. After five minutes, the final room also begins to deal increasing environmental damage. Boss battles use a separate timer. |
| Death | The challenge removes the revival machine, but normal item-based revivals remain. Survivors are checked after revival resolution. The final death eliminates a player for that round. Clearing a Boss does not revive teammates, and reconnecting preserves elimination status. |
| Wins | Once the only survivor is confirmed, the survival phase ends immediately and the Boss phase begins; players do not need to wait for the full five minutes. Defeating the first normal Boss earns one win and advances to match point. After winning again, the player goes directly to Mom's Heart. Defeating it lets the winner claim the challenge trophy and end the run. |
| Boss entrance | Boss Rooms cannot normally be entered. Mom's Heart's room is reserved away from spawn points, preserving exploration routes near spawn. A portal appears under the survivor. After an approximately one-second transition, the player automatically enters the current round's normal Boss Room or the reserved original Mom's Heart room. On arrival, the player receives a temporary original Devil Deal item with its normal pickup effect. The temporary copy is removed during the next simulated floor transition; pre-existing copies are preserved. |
| Rewards and progression | Boss-clear pedestals use Chaos's original cross-pool selection. At least one pedestal has quality 3 or higher; additional pedestals have no guaranteed quality. This selection applies only to Boss rewards; exploration rooms use their own item pools. The winner of a normal Boss may claim or skip the reward. Only the winner can use the exit to advance. If standing on the exit's spawn position, the player must leave and re-enter it. |
| Next round | A simulated floor transition generates a new random map. Items, stats, and resources are preserved; eliminated players are revived. Everyone's current red-heart containers are refilled. Existing Soul Hearts and Black Hearts are preserved and are not granted again. If everyone dies or the Boss battle is lost, nobody earns a point; previous wins are kept and the challenge continues. |
| Display | A graphical win-progress indicator and match-point trophy appear above the health bar. Each player's map remains independent. The original map HUD draws the current safe zone as a solid line, previews the next zone with a dashed line, and marks the outside area in pale red. A progress bar below the map shows the time until the next shrink. The overlay follows the original minimap/expanded-map clipping, position, and opacity, and is hidden when survival ends. |

The gameplay component is [battle_royale.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/battle_royale.lua). Portable win, shrink, and quota rules are in [battle_royale_rules.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/battle_royale_rules.lua). The [map component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/battle_royale_map.lua) expands the map using the original red-room rules, reserves the original Mom's Heart room, and determines random safe-zone positions. The [resource distribution component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/battle_royale_resources.lua) then fills compatible templates and spawn-resource routes. Normal wins exclude Mom's Heart rooms on XL maps. The [reward component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/battle_royale_rewards.lua) temporarily borrows Chaos only during reward selection and removes the temporary copy on both normal return and error; existing Chaos copies are preserved. The host decides Bosses, exits, and round progression. Each player's map retains their own exploration and original map-reveal effects. This does not provide data confidentiality or anti-cheat guarantees.

## Rules and Lifecycle

Changing a challenge clears every player's ready state. Joining, choosing a character, becoming ready, and starting each validate local save eligibility and the current rule generation. Normal character selection uses the original menu catalog and eligibility checks, including Mod characters loaded locally. Consumable eligibility required at the start is not checked again when restoring an existing character.

Challenges are temporary sessions. They do not save a full run for resuming and do not overwrite normal multiplayer saves. Rule ID/version, original slot, and materials are restored with checkpoints and real-time views. The run rules remain active through the R key and Hourglass; leaving restores the protected single-player Continue state. The gameplay layer determines rewards and completion timing, while the runtime layer coordinates the original game exit.

## Presentation and Extension Points

The goal uses the original HUD's Destination branch. The Bag of Crafting reuses the original drawing and displays the observed target at the local lower-right corner, hiding the off-hand area of teammate mini-HUDs. Other local cards and pills display normally. Materials remain fully synchronized; display restrictions do not provide anti-cheat or data confidentiality.

| Responsibility | Entry point |
| --- | --- |
| IDs, versions, eligibility, and effect definitions | [compat/challenges/catalog.h](https://github.com/BMingSY/isaac-lan/blob/main/src/compat/challenges/catalog.h) |
| Rule descriptors and lobby transport | [core/run_rules.h](https://github.com/BMingSY/isaac-lan/blob/main/src/core/run_rules.h), [net/](https://github.com/BMingSY/isaac-lan/tree/main/src/net) |
| Lifecycle, reconnect, and completion | [bridge/runtime/challenges.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/challenges.lua), [runtime/session.cpp](https://github.com/BMingSY/isaac-lan/blob/main/src/runtime/session.cpp) |
| Goal and reward rules | [compat/routes/challenge_goal.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/routes/challenge_goal.lua) |
| Luck Game rules | [compat/challenges/luck_game.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/challenges/luck_game.lua) |
| Menu and local presentation | [presentation/menu.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/menu.lua), [J460 HUD capabilities](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#hud-and-local-input) |

Challenge maps can provide `onLayoutReady(info, level)` and `canEnter(ctx)` through `maps[id]`. The former runs after the authoritative layout is ready; the latter validates the source, destination, and teleport type before a transition is queued. Challenges 1001 and 1002 do not configure a map strategy. Challenge 1003 uses these callbacks to expand red rooms and restrict Boss entrances. Callbacks coordinate game APIs only; new rooms use the existing layout synchronization.

Challenges with dynamic progress transmit the rule ID, rule version, and component payload through the world field `challenge`. The graphical HUD is drawn after reconnect restoration. Challenge 1003 uses rule version 3. Its payload contains the round, phase, elapsed survival frames, winner, wins for all four slots, survivor mask, top-left grid indices for the four safe zones, and an optional portal position. Only the host selects the safe-zone position for each round. Boundaries and containment are validated for side lengths 13, 9, 5, and 1. Field positions are defined by the portable rules module, and gameplay state is cleared by the challenge component. The [per-player map component](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/map_visibility.lua) projects display and exploration fields per player without changing authoritative room clearing, drops, or layout.

Changing a rule updates the definition version; both startup and restoration validate the rule. The dedicated test entry point for Demon Form is [run_lan_challenges.py](https://github.com/BMingSY/isaac-lan/blob/main/tools/run_lan_challenges.py), and the Luck Game test entry point is [run_luck_game.py](https://github.com/BMingSY/isaac-lan/blob/main/tools/run_luck_game.py). See [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md#targeted-development-entry-points) for usage and execution scope.
