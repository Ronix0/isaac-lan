# Glitched Item Definitions and Inventory

Negative IDs for glitched items are valid only in the current process's dynamic registry. Synchronizing the base ID and ordinary inventory is not enough for a guest to reconstruct their effects. The synchronization contract therefore uses an ordered list of generation seeds to rebuild definitions before restoring rooms, entities, and inventory.

## J460 Native Boundary

Applicable game SHA-256: `7122ac28779925b24e23e2416f231322b1470388bd25e2c08665ad8d53b3ea4f`.

- `Game + 0x67758` is the pointer vector for generated definitions, with at most 1024 entries. The ID is `~index`, i.e. `-1…-1024`. Entry `+0` points to ItemConfig; `+8` stores the normalized seed. ItemConfig `+4` stores the ID.
- The generation function at RVA `0x5dcc70` is x86 thiscall and takes the registry, seed, and flags. Native save restoration calls it at RVA `0x5e036b` to rebuild a definition from its normalized seed with `flags=0`.
- [`generated_items.cpp`](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/versions/j460/generated_items.cpp) captures definitions through `generated_items()` and restores them through `generated_items(bytes)`. The payload is limited to 4096 bytes. Length, seeds, and the existing prefix are validated before native generation is called in order. Repeated snapshots do not generate duplicates; a conflicting snapshot terminates the session.
- Guest room initialization may draw its own items. The generation interception temporarily uses an ordinary item ID, then the authoritative snapshot overrides it; native save restoration remains enabled. The game creates and releases definitions, strings, effect lists, and textures. Pointers are not copied across processes, and the native registry is not manually cleaned up.
- Lua's item-pool API cannot restore a specified definition in native registry order, and the existing static inventory enumeration does not include negative IDs. The special-definition adapter is [`compat/items/glitched.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/compat/items/glitched.lua). Generic inventory captures and applies extra IDs through an injected list.
- In J460, `GetCollectibleNum` at VA `0x770cb3` returns 0 directly for every negative ID. The negative-ID branch of `HasCollectible` instead reads the native count tree at `Player + 0x1fcc` (size at `+0x1fd0`, node ID/count at `+0x10/+0x14`). `generated_item_count(sprite, id)` accepts only player sprites in the current native list, validates the negative ID, tree size, nodes, and traversal limit, then reads the actual count. It does not allocate, modify, or release tree nodes. Inventory differences are still applied through native `AddCollectible/RemoveCollectible` to prevent repeated passive effects when the same snapshot is received again.

## Synchronization and Lifecycle

Definitions must be restored before entities and inventory that reference negative IDs. The base generation rule is determined by the item-compatibility strategy. Restoration rebuilds the same definitions and counts without triggering pickup or use effects. Native saves own the save/continue lifecycle for generated definitions.

Shared effects and verification status for glitched items are listed in the [item catalog](https://github.com/BMingSY/isaac-lan/blob/main/docs/item-effect-compatibility.md). Native interfaces for other items are in the [backend reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/native-backend.md#items-and-effects); targeted entry points are in [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md#on-demand-targeted-tests).
