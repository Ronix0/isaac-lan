# Third-Party Mod Compatibility

Built-in adapters identify mods by their source and the interfaces they actually expose. They do not pin the reference versions or source hashes listed below. If an upstream interface is missing, only the relevant adapter is paused; the mod itself is still allowed to load.

| Mod | Compatibility behavior |
| --- | --- |
| Stats+ 2.1.3 | The stat panel displays only the local character while preserving the dual-character layout. During multiplayer, the fire-rate cap and historical D8 multiplier are hidden. |
| GoodTrip (original) 1.2.8 | Teleportation is initiated using the local map and moves only the requesting player. The host does not need GoodTrip installed. Teleportation retains restrictions such as room-clearing requirements, visited-room checks, secret-room paths, and Curse Room costs. Quick restart is disabled during multiplayer. |
| EID 5.24 / 5.25 | Basic descriptions use the local character and room. Missing nearby-entity queries on guests are supplemented, first-frame descriptions for replicas are supported, and descriptions refresh after room changes, floor changes, and Hourglass rewinds. Local language and settings are preserved. Flip hidden information, dynamic descriptions, crafting, and random predictions are not fully covered. |
