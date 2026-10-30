# Chat and Console

Chat uses a single chronological message history that distinguishes party messages from system output. There are no channel switches. Appearance settings are documented in the [README configuration options](https://github.com/BMingSY/isaac-lan/blob/main/README.md#configuration-and-logs).

The updated chat console is enabled only in the multiplayer lobby, during multiplayer runs, and while waiting in multiplayer. Single-player continues to use the original console and key behavior. After leaving multiplayer, the extension stops capturing input and drawing the chat interface.

After creating or joining a room, press `~` in the lobby to open chat. Press Enter to send, and `~` or Esc to close it. On a controller, use L3 to toggle chat. The address-entry page does not enable party chat before a session has been established. While editing an address, port, or seed, the keyboard is reserved for editing the field and does not trigger game shortcuts or the chat toggle. Enter confirms, Esc ends editing, and controller confirm/back inputs remain available.

## Responsibilities and Data Flow

- [core/chat.h](https://github.com/BMingSY/isaac-lan/blob/main/src/core/chat.h) owns character/byte limits, UTF-8 editing, and history. The Win32 input adapter is in the version backend and handles `~`, the clipboard, and IME. During editing it isolates local gameplay input; when editing closes, any held action keys must be released.
- [runtime/chat.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/chat.lua) owns the command queue, message history, output ownership, recipient scope, and deduplication. Text after `/console` or `/c` is passed directly to the original parser; the extension does not maintain an allowlist of original commands. `/e` is handled locally. Dice rolls are generated once by the host using an independent random source. [chat_dice.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/chat_dice.lua) parses, validates, and evaluates dice expressions. It receives the random source as a parameter and does not read game state.
- [runtime/teleport.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/teleport.lua) handles `/tp` arguments, room lookup, and arrival transactions. The host selects an existing destination within the sender's character scope, and the native room component performs the transition. After arrival, the room and character identities are checked before placing the player near the destination.
- [presentation/chat.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/presentation/chat.lua) handles only local input state, layout, scrolling, and rendering. Text bubbles are drawn only for characters in the same room, using translucent original game bubble assets. Emote selection, animation, and bubbles reuse the game's existing wheel and character-emote components. Original assets are loaded from the game and are not redistributed. Background settings are injected during startup and do not participate in network consistency.
- [chat_wire.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/chat_wire.lua) encodes and decodes requests, output, and emotes. The underlying `communication` channel is a reliable byte-message channel independent of mod actions and world snapshots. The network layer does not parse chat content. The protocol version is defined by [protocol.h](https://github.com/BMingSY/isaac-lan/blob/main/src/net/protocol.h); players can connect only when their extension versions match.

The transport layer determines the sender's connection slot. Original game commands and `/tp` execute at a safe host update boundary, using the sender's character and room context. The queue records the run, world generation, room, and dimension; if they no longer match before execution, the request is cancelled. `rewind` uses the existing rewind transaction. There is no player permission hierarchy; synchronization does not change which members are allowed to use commands.

After a slash command is parsed and submitted, it is first written to the local chat history. It appears as `system: /c g c333`, is not broadcast, and does not create a bubble. The record is retained even if the original command produces no output. It represents the submitted command; execution errors are sent only to the submitting player. Leading whitespace does not affect command recognition. Text beginning with `lua`, `luarun`, or containing `dofile(...)` or `loadfile(...)` without the console prefix produces a local error and is not sent as ordinary chat. Dice results include the player number, expression, individual dice results, and total; for example, `1P rolled: 2D6 = [3 + 5] = 8`. A single die omits a redundant total. The recipient's chat history and corresponding character bubble use the same text.

Text chat and dice rolls are shared with the whole party by default. Adding the separate trailing argument `--room` limits the message to the current room. This argument is not parsed from original console commands or from `/e` arguments. When the host handles a room message, it checks the sender's run, world generation, room, and dimension as recorded at submission time. If the context is invalid or the game is not ready, only the sender is notified; the message is not rolled or forwarded. Recipients are selected using their room and dimension at processing time, excluding disconnected members. The host does not add the message to its local history if it is not in that room. Room output is prefixed with `[Room]` and uses the existing text-message format. Queued output retains the recipients selected when it was distributed.

`/h` and `/help` list commands, aliases, and dice limits in the local history. They are not broadcast and do not create bubbles. `/c` does not add commands that are absent from the original game; `/c help` continues to behave according to the current game and loaded mods.

`/feedback` and `/fb` package and upload logs locally on the submitting player's instance. The result is written only to local history and does not pass through the host. See [Feedback Upload](https://github.com/BMingSY/isaac-lan/blob/main/docs/feedback.md) for the collection scope and upload results.

Messages and bubbled command results from P1–P4 use red, blue, gold, and green text respectively. The dark chat panel uses brighter values; light bubbles use darker text from the same color family. Local command records and system output without bubbles use the configured text color. Text on custom image backgrounds receives a dark shadow to improve readability over light areas.

The chat background defaults to a solid color with 70% opacity. Color and opacity are configurable; the installation package does not include background images. When a custom image is configured, [chat_background.cpp](https://github.com/BMingSY/isaac-lan/blob/main/src/presentation/chat_background.cpp) prepares it at startup. The path may be relative to `config.ini` or absolute. PNG, JPG/JPEG, and BMP are supported; the format is detected from file contents rather than the extension. GIF is not supported. The original image is read-only. PNG files are validated and cached unchanged; other formats are decoded and cached as PNG, preserving the selected image's pixels and transparency. The image is scaled to the expanded panel and moves with it. When the panel is collapsed or fewer recent messages are shown, only the upper part of the image is cropped; the bottom position and scale remain unchanged. Configured opacity is multiplied by the image's own transparency. Input images are limited to 16 MiB, 4096 pixels on either side, and 8 megapixels total. After decoding and validation, the PNG cache and animation description are written to `isaac-lan/cache/chat`. Lua loads the image through the regular Sprite API; no disk access occurs during a frame. No cache is created when no image is configured. If the image is missing, damaged, or its cache is unavailable, the interface falls back to a solid color and logs the issue without adding an on-screen message.

By default, the panel reserves margins based on the stat bar, item bar, and HUD offset. While input is open, the message-history area can be dragged; the input row does not initiate dragging. A manually positioned panel is constrained only by screen boundaries and no longer avoids the HUD. Its position is retained during the current run when collapsed, reopened, or when the session changes. HUD setting changes do not move a manually positioned panel. When the screen size changes, the panel is kept within the screen and text is wrapped to its width. Automatic layout is restored after leaving the game. Dragging ends when input closes or the window loses focus. Empty or whitespace-only input submitted with Enter or controller confirm is ignored; it does not create a record, clear the draft, close the input, or reset the scroll position.

When input is open, a copy button appears to the right of the last visible line of each message. Clicking it copies the entire original message, including content outside the current scroll range, without adding a player number or display prefixes such as `system:`. The button area does not initiate dragging. Copying occurs only when the pointer is pressed and released on the button for the same message. It does not change the draft or send a message. On success, the icon briefly changes to a check mark; on failure, it briefly turns red. The button is hidden when the panel is collapsed.

## Teleport Command

`/tp` targets the sender and the bodies controlled by that sender. Existing follower handling and route-entry rules remain in effect. Arguments are case-insensitive. `/tp`, `/tp help`, and `/tp h` show usage locally. Other operations require a ready multiplayer game. Results are visible only to the sender and do not create bubbles.

| Syntax | Meaning |
| --- | --- |
| `/tp r x y`, `/tp room x y` | Select a map cell in the current dimension, using the starting room as `(0, 0)`, with positive X to the right and positive Y upward. |
| `/tp start`, `/tp st` | Equivalent to `/tp r 0 0`. |
| `/tp 1p`–`/tp 4p` | Move to the online player's room and dimension, choosing a walkable cell near their current position. This also works when both players are already in the same room. |
| `/tp list`, `/tp l` | List generated rooms in the current dimension, along with existing off-map shop/trade rooms and error rooms. Show type, coordinates, and visited/cleared state. |
| `/tp boss`, `/tp b` | Boss Room. |
| `/tp shop`, `/tp sh` | Shop. |
| `/tp treasure`, `/tp t` | Treasure Room. |
| `/tp secret`, `/tp s` | Secret Room. |
| `/tp supersecret`, `/tp ss` | Super Secret Room. |
| `/tp ultrasecret`, `/tp us` | Ultra Secret Room. |
| `/tp angel`, `/tp a` | Angel Room. |
| `/tp devil`, `/tp d` | Devil Room. |
| `/tp error`, `/tp e` | Error Room. |

Coordinates count map cells, not the number of doors crossed. Any occupied cell of a large room points to the same room. Missing corners of L-shaped rooms, empty map cells, and out-of-bounds coordinates are not valid destinations. Large rooms in the list use their valid anchor coordinate. If multiple rooms of the same type exist, the command returns candidate coordinates instead of choosing randomly. Off-map special rooms use their room-type command.

A destination must already have been generated and still exist. Unvisited rooms, unopened doors, and disconnected entrances do not prevent teleportation. Ultra Secret Rooms and already-created red rooms can be entered; a red room that has not yet been created remains an empty cell. The command does not use cards, generate, reset, or replace rooms, or change the floor's Angel/Devil Room selection. A targeted transition bypasses the Chaos Curse's random redirection, while the original room-entry effects still run normally.

Each participant can have at most one pending teleport at a time; duplicate requests are handled by chat deduplication. Success is reported only after arrival is confirmed. If it is not confirmed within 3 seconds, the pending request is cancelled. Character replacement, an unexpected change of source room, the target player leaving or disconnecting, or a change of run/floor generation invalidates the transaction. It does not send a player back after they have already arrived, and a cancellation from an old floor cannot affect a new floor. Leaving or rebuilding the chat session clears transactions.

## Output Contract

The internal `chat.output(text, options)` API expresses visibility and bubble display separately. During command execution on the host, an omitted `owner` inherits the executor. The startup assembly exposes `_IsaacLanChatOutput` for synchronous calls such as original `/console lua ...`; this is not a stable third-party API.

Gameplay components can call `chat.roll(owner, sides)`. It shares the evaluation and output path with chat commands, still returns the numeric result of a single die, and broadcasts the result to the party. Only the host can roll for a connected member; failure returns `nil`.

| Field | Default | Meaning |
| --- | --- | --- |
| `audience` | `"self"` | `"self"` sends only to the executor; `"party"` sends to all connected members; `"room"` sends to connected members in the executor's room and dimension. |
| `owner` | Current executor, otherwise local slot | Character owner, using a zero-based slot. Determines which character the bubble follows. |
| `bubble` | `false` | Whether to also display the message above the character's head. |
| `kind` | `"system"` | `"system"` for system output, `"team"` for party messages. |

```lua
chat.output("Shared result", { audience = "party", bubble = true })
chat.output("Room result", { audience = "room", bubble = true })
chat.output("Local notice", { audience = "self" })
```

Broadcast and remote-targeted output originate from the host. Guests submit command requests and cannot choose another player's identity. `"room"` output filters recipients using the room currently occupied by `owner`; it returns `false` if the game is not ready or the character has no valid room. Synchronous `Console.Print` output produced during original command execution is returned to the executor. Output from asynchronous callbacks is not automatically attributed to a command that has already finished. Commands that need to share results must explicitly call the output interface, rather than broadcasting all original game logs.

## Lifecycle and Limits

Text chat is limited to 60 Unicode scalar values per message, including a trailing scope argument. Commands are limited to 2048 UTF-8 bytes. Dice may have 1–999 sides; one expression can contain at most 20 base dice and 20 terms, with addition/subtraction constants from 0–9999. Each percentile die can have 1–2 bonus or penalty dice attached. Bonus and penalty dice share the units digit and independently generate tens-digit candidates. A result of `00` is converted to 100 before the bonus takes the lower result or the penalty takes the higher result. The entire expression is validated before random numbers are generated. If the random source fails at any point, the entire result is cancelled and only the sender is notified. The room marker counts toward the output byte limit; exceeding it returns `false`.

Newlines in a single paste are converted to spaces; the paste is not split into multiple submissions. Message history retains 200 entries and input history retains 64. Both exist only in memory and are not written to multiplayer logs or chat saves. The original game's own logging behavior is unchanged. Synchronous output from original commands is collected up to 16 KiB, split into lines, and packetized at UTF-8 boundaries.

Each request includes a random session token and an increasing sequence number, preventing duplicate execution or duplicate dice rolls. Transport messages are limited to 3072 bytes. Each sender can have up to 32 pending received messages and 64 messages per second; the command queue holds up to 16 commands. Temporarily queued output preserves order per recipient, retries for at most 5 seconds, and holds up to 64 pending messages. Closing a connection removes its transport messages. Closing or rejoining a session clears local history, drafts, bubbles, and commands. Changing floors clears temporary bubbles but does not clear text history.

Bubbles display at most three lines; longer messages are truncated with an ellipsis. The complete content remains in text history. Display duration is 4–8 seconds depending on message length. Bubbles near screen edges are constrained to the visible area, and adjacent bubbles are preferentially shifted to nearby free positions. Emotes do not enter text history, and importing user images is not supported. A controller can operate the chat toggle, confirm, cancel, and emote selection. Text editing requires a keyboard; there is no controller soft keyboard.
