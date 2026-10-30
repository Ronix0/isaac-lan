# LANBOT

LANBOT takes control of the local player's movement and shooting through normal game inputs. It is useful for testing with an AI-controlled host and a human-controlled guest. It can be used by either the host or a guest and requires no additional mod, agent, or API key.

## Enable

Start a LAN game, then enter `/lanbot on` in [multiplayer chat](https://github.com/BMingSY/isaac-lan/blob/main/docs/chat-console.md). The original game console does not provide this command. The default configuration is `run + balanced` and affects only the player controlled by the local instance. If two instances on the same computer need to keep running in the background, set `PauseOnFocusLost=0` in `options.ini` in the save directory.

## Commands

| Command | Behavior |
| --- | --- |
| `/lanbot on` | Start or resume control. Repeating the command does not add another controller. |
| `/lanbot mode run` | Collect free resources, explore normally reachable branches on the current floor, then look for a regular exit. |
| `/lanbot mode explore` | Explore the current floor, then wait without automatically changing floors. |
| `/lanbot mode hold` | Fight and recover in the current room, then stay there after clearing it. |
| `/lanbot style aggressive` | More actively seek positions for dealing damage. |
| `/lanbot style balanced` | Balance danger, distance, and progress. |
| `/lanbot style cautious` | Keep a larger safety margin and prefer effective firing positions farther away. |
| `/lanbot pause` / `/lanbot resume` | Release controls for a human player / resume control while preserving settings. |
| `/lanbot off` | Clear the task and return control to the human player while preserving this session's settings. |
| `/lanbot next` | In `run` / `explore` modes, follow the normal route to a known exit and skip the current teammate wait. Rejected in `hold` mode. |
| `/lanbot status` | Show the task, reason for waiting, current phase, and decision statistics. |
| `/lanbot help` or `/lanbot` | Show help. |

Modes and styles can be configured in advance; configuring them does not start the bot. `on` / `resume` require an active LAN run. If control is off, use `on` first. Before changing floors, the bot normally waits for living teammates to enter the exit room. `next` does not create an exit or bypass the original game's restrictions.

`pause` pauses only the bot, not the entire party. Actions that have already happened or been sent cannot be undone. Leaving, disconnecting, or starting a new run disables control and restores the default settings. After reconnecting, enable it again.

## Supported Scenarios

| Scenario | Behavior and limitations |
| --- | --- |
| Input | Controls movement and shooting. Map, pause menu, console, bombs, active items, and cards remain under human control. |
| Normal routes | Uses regular doors, free resources and items, and at most one reward per Boss Room. It does not repeatedly swap an active item when one is already held, automatically shop, or solve special ending puzzles. |
| Greed mode | Waits for teammates before starting waves, avoids the stop button during combat, restocks after Boss waves, collects items in item rooms, and changes floors. Optional Devil reward waves are skipped. |
| Greed Shop | Reserves a budget for missing keys or health, then buys passive items or familiars based on expected value. Items are distributed according to teammates' equipment. It does not automatically buy active items, unknown items, or items with negative costs. |
| Terrain | Shoots obstacles such as blocking poop and regular/red fires, handles ordinary pressure plates and alternating spikes when a safe timing window can be identified, and avoids dangerous floors and blue/purple fires. Complex obstacles are left to the human player. |
| Combat | Includes pathfinding, short-term threat avoidance, normal shooting, and strategies for some charge weapons. Dual characters use the existing shared input and are not independently controlled. |

Old inputs are cleared when the menu opens, rooms change or are rebuilt, the player dies, or the view is not ready. If a guest's view has not updated for more than 250 ms, the bot waits with `stale_view`. Decision errors switch it to a paused state. Common wait reasons include `wait_for_party`, `exploration_complete`, `resource_missing`, `route_blocked`, `wait_for_trap`, and `needs_manual`.

In `status`, `frames` is the number of decisions, `hits` is the number of health decreases between valid observations, `blocked` is the number of blocked actions, and `max_ms` is the peak observation and decision time. The 2 ms figure is a design target, not a real-time guarantee. `run` describes a progress goal; it does not guarantee completion for every seed, character, or weapon.

See the [design document](https://github.com/BMingSY/isaac-lan/blob/main/docs/lanbot-design.md) for implementation details and lifecycle constraints.
