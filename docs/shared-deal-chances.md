# Shared Devil Room and Angel Room Chances

Devil Room and Angel Room chances belong to the party as a whole. The host calculates them using the party's original items, trinkets, damage taken, deals, and floor history. Guests use the host's result, including when players are in different rooms. Increases and decreases affect the same shared chance; HUD percentages from multiple players are not added directly.

Original stacking and priority are preserved. For example, multiple Pentagrams can increase the extra chance allowed by the original game, while duplicate Goat Heads and identical key pieces do not stack arbitrarily. Sacred Heart, Book of Virtues, Book of Belial, and floor-specific Angel modifiers retain their original rules. Once the original game has determined a room type, it is not rerolled or rewritten. Planetarium chance is not part of this shared system.

## Modules and Synchronization Contract

- [`src/bridge/sync/deals.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/sync/deals.lua) captures, validates, and applies the party-wide chances; [`app/world.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/app/world.lua) only assembles the component. Top-level field 19 is `deals = { total, angel }`. `total` is the original total door chance and may exceed 1; `angel` is the original conditional Angel Room chance, in the range 0–1. The usual displayed Devil/Angel chances are `min(total, 1) * (1 - angel)` and `min(total, 1) * angel`, respectively. The original game still handles floors where a door cannot appear and duality display.
- [`src/compat/items/deal_chances.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/compat/items/deal_chances.h) receives ordinary floating-point values from original queries and combines effects across rooms. The same party inventory and floor penalty are not accumulated repeatedly when querying multiple rooms.
- Guests store the result after inventory application. Both original HUD chance queries read the same applied result; guests do not recalculate it from local damage history or inventory-restoration side effects. Floor barriers, new runs, and native floor cleanup clear the cache; state from an old generation cannot be applied to a new floor.
- Only two floating-point values are synchronized. Chance-granting items are not synchronized one by one or copied to the host. Protocol, schema, and fingerprint requirements are defined in the [Synchronization Contract](https://github.com/BMingSY/isaac-lan/blob/main/docs/synchronization.md#validation-and-failure-boundaries).

## Required Native Capabilities

The existing Lua API cannot temporarily expose the complete player list for a split-room simulation when an actual Devil/Angel Room is generated, nor can it override the internal conditional Angel chance used by the original Found HUD. The J460 backend therefore provides named `deal_chances()` query/application and `deal_chances_reset()` cleanup capabilities. Original queries execute in a bounded context; the original game still manages the formula and combat-simulation player list.

This applies to J460; see the [backend reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md) for the game identity. Native entry points:

| Entry point | RVA | Purpose and ABI |
| --- | --- | --- |
| `Room::GetDevilRoomChance` | `0x3f92b0` | Shared by public Lua query, HUD, and actual door generation; `thiscall`, x87 return |
| Original conditional Angel chance query | `0x3f96f0` | Shared by HUD and room-type initialization; no arguments, returns in XMM0 |
| `Level::InitializeDevilAngelRoom` | `0x3499a0` | Determines the actual generated room type; `thiscall(bool, bool)` |
| `Room::TrySpawnDevilRoomDoor` | `0x3f83b0` | Original room-clear door generation and public API; `thiscall(bool, bool)` |

All four entry points are protected by startup signature validation. The conditional Angel query's SSE return convention is bridged by the backend. Ordinary C++/Lua floating-point interfaces use the normal ABI; x87 and XMM0 return values must be converted correctly.

The named query, HUD, and actual room generation use the same native calculation entry point. Outside an active multiplayer session, single-player behavior is unchanged.

Chance queries and room-type initialization temporarily borrow the complete player list through the existing `TeamScope`, then restore the original in-room list. They do not move characters, run extra entity updates, or allocate/free native objects. Actual door generation runs only on the host.

The original extra red-heart damage penalty in Boss Rooms depends on the current room. During a query, if the original final Boss Room for the current floor is already loaded, its Room pointer, room index, and dimension are temporarily borrowed and then restored. This ensures that leaving the Boss Room does not hide the penalty. Only an existing room is read; the Boss Room is not loaded, generation RNG is not consumed, and damage records are not rewritten. Other floor state, such as damage taken, deals, beggars, and donations, uses the host's existing global original-game state.

Some temporary original effects that guarantee a door are stored in the Room. The same party/Boss-penalty context queries existing room objects and reads the maximum total chance already calculated by the original game. This lets a guarantee in another room apply to the whole party without adding the same effect twice, copying the effect, or extending the original object's lifetime. This handling applies only to room effects already recognized by the original total-chance query.

The API allows guests to write only a finite, non-negative total chance representable as a float and a conditional Angel chance from 0 to 1. Both values are validated together before the pair is updated. The host does not accept guest-provided chances. The cache stores numbers only, never native pointers. The rules follow the actual J460 call chain. The [Room Lua API documentation](https://wofsauge.github.io/IsaacDocs/rep/Room.html#getdevilroomchance) is used to verify the public query's meaning; example formulas from older Repentance versions are not copied directly into Repentance+.
