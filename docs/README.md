# Documentation Index

For installation and multiplayer instructions, see the [Project README](https://github.com/Ronix0/isaac-lan/blob/main/README.md). For common questions, see the [FAQ](https://github.com/Ronix0/isaac-lan/blob/main/docs/faq.md). Documentation ownership and review rules are described in [AGENTS.md](https://github.com/Ronix0/isaac-lan/blob/main/AGENTS.md#documentation-boundaries-and-in-game-ui).

## Current Architecture and Design

| Topic | Documentation |
| --- | --- |
| Overall design and key trade-offs | [Architecture Overview](https://github.com/Ronix0/isaac-lan/blob/main/docs/architecture.md) |
| Dependencies, ownership, and extension points | [Layers and Compatibility](https://github.com/Ronix0/isaac-lan/blob/main/docs/layers-and-compatibility.md) |
| Input, state flow, transport, and backpressure | [Networking and State Synchronization](https://github.com/Ronix0/isaac-lan/blob/main/docs/synchronization.md) |
| Game startup, saves, reconnection, and floor transitions | [Session Lifecycle](https://github.com/Ronix0/isaac-lan/blob/main/docs/session-lifecycle.md) |
| Room separation, prediction, HUD, and audiovisual presentation | [Rooms and Presentation](https://github.com/Ronix0/isaac-lan/blob/main/docs/rooms-and-presentation.md) |
| Text input, commands, output, and chat bubbles | [Chat and Console](https://github.com/Ronix0/isaac-lan/blob/main/docs/chat-console.md) |
| Bot observation, planning, and input | [LANBOT Design](https://github.com/Ronix0/isaac-lan/blob/main/docs/lanbot-design.md) |

## Features, APIs, and Compatibility References

| Topic | Documentation |
| --- | --- |
| Native capabilities, ABI, and ownership | [J460 Backend](https://github.com/Ronix0/isaac-lan/blob/main/docs/native-backend.md) |
| Compatibility behavior and current verification status | [Characters](https://github.com/Ronix0/isaac-lan/blob/main/docs/character-compatibility.md), [Items](https://github.com/Ronix0/isaac-lan/blob/main/docs/item-effect-compatibility.md), [Third-Party Mods](https://github.com/Ronix0/isaac-lan/blob/main/docs/mod-compatibility.md) |
| Specialized feature contracts | [Generated Item Definitions](https://github.com/Ronix0/isaac-lan/blob/main/docs/generated-item-definitions.md), [Shared Deal Chances](https://github.com/Ronix0/isaac-lan/blob/main/docs/shared-deal-chances.md) |
| Challenge rules and integration | [LAN Challenges](https://github.com/Ronix0/isaac-lan/blob/main/docs/lan-challenges.md) |
| Third-party interfaces and examples | [Mod API](https://github.com/Ronix0/isaac-lan/blob/main/docs/third-party-mod-integration.md) |
| Hosted bot commands and scope | [Using LANBOT](https://github.com/Ronix0/isaac-lan/blob/main/docs/lanbot.md) |
| In-game feedback, collected data, and uploads | [Feedback Upload](https://github.com/Ronix0/isaac-lan/blob/main/docs/feedback.md) |

## Development and Validation

| Topic | Documentation |
| --- | --- |
| Builds, checks, and default release scope | [Development and Testing](https://github.com/Ronix0/isaac-lan/blob/main/docs/development-and-testing.md) |
| Workshop preparation, updates, and download verification | [Steam Workshop Release Process](https://github.com/Ronix0/isaac-lan/blob/main/docs/steam-workshop-release.md) |
| Logs, performance metrics, and heap anomalies | [Diagnostics Reference](https://github.com/Ronix0/isaac-lan/blob/main/docs/diagnostics-and-resource-testing.md) |

Design documents describe the current architecture. Specialized APIs and behavior are documented in their respective reference documents. Raw logs and screenshots are kept in test artifacts or CI attachments.
