# Character Compatibility

| Character | Compatibility behavior |
| --- | --- |
| Tainted Keeper | If a Tainted Keeper is in the party, all players' shops use Tainted Keeper's layout and pricing. This applies on the first floor and after players split into separate rooms. |
| Tainted Lost | The party shares its item filtering, rerolls for low-quality items, and Holy Card generation behavior. These effects continue to work when players are in separate rooms. |
| The Forgotten / The Soul | Current and hidden-form health is synchronized, including Soul Hearts, Black Hearts, and Bone Hearts. |
| Tainted Lazarus | The shadow of the other side's items in Flip is synchronized with the original sprite, textures, and display state. Flipping and shadow disappearance follow the host's updates. |
| Tainted Lilith | The familiar's cord uses synchronized native geometry and materials. It is drawn locally on guests, without running guest-side familiar attack logic. |
| Tainted Forgotten | The Soul retains local movement prediction, while the skeleton follows the host's movement trajectory and does not drift in response to the Soul's directional input. |
| Multiplayer ghosts | A ghost moves with the party when no living online teammate remains in its current room, landing at the position of a living teammate in the destination room. If a living teammate is still in the same room, the ghost retains free movement. Guest prediction allows it to fly over pits and ground obstacles. |

The original J460 generation rules for Tainted Lost are preserved: only offensive candidates are kept, and quality 0/1 items have an additional one-in-five chance to be rerolled. When special cards are allowed, there is a one-in-ten chance of replacing one with a Holy Card. The backend temporarily borrows the complete list only during generation queries, preserving the original seed and algorithm. Personal health, flight, and starting inventory are not shared. See [`entrypoints.h`](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/versions/j460/entrypoints.h) and [`signatures.inc`](https://github.com/BMingSY/isaac-lan/blob/main/src/engine/versions/j460/signatures.inc) for entry points and signatures.
