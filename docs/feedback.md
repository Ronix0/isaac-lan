# Feedback Upload

Players can submit an issue description in-game. The extension packages recent logs and uploads them to the author's server, then returns a feedback ID. Feedback is private and can only be viewed by the author. Uploads run on a background thread and do not block the game.

## How to Submit

In the multiplayer lobby, during a multiplayer run, or while waiting, enter `/feedback issue description` (alias: `/fb`) in [multiplayer chat](https://github.com/BMingSY/isaac-lan/blob/main/docs/chat-console.md). The original game console does not provide this command, and `/c feedback` does not trigger an upload.

The command runs locally on the submitting player's instance and is not sent to other players. The description cannot be empty and is limited to 4096 UTF-8 bytes. Only one upload can be active at a time, and submissions must be at least 30 seconds apart.

## What Is Collected

| Content | Path inside the package |
| --- | --- |
| Multiplayer log directories from the current and previous launches (`startup.log`, each run's `runtime.log`, and `performance.jsonl`) | `logs/<launch>/...` |
| Original `log.txt` | `game/log.txt` |
| `isaac-lan/config.ini` | `config/config.ini` |
| Description, timestamp, extension and game versions, session phase, loaded mod names, and file manifest | `feedback.json` |

The previous launch is included so that logs from a crash are still available if the player submits feedback after restarting. For each file, only the latest 8 MiB are retained. If the compressed package exceeds the limit, the retained portion is reduced by half at a time, down to a minimum of 256 KiB. Truncated files are marked at the beginning with the number of discarded bytes.

Windows user-directory paths in text files are replaced with `%USERPROFILE%`. This covers long paths and 8.3 short paths, `\\` and `/` separators, and case-insensitive matches. Steam paths of the form `userdata\\<number>` are replaced with `userdata\\<steamid>`. Host addresses, ports, player names, and save seeds are retained to help diagnose multiplayer issues.

## Upload

The request is a `POST` to `https://lzh-qwq.top/isaac-lan/feedback/v1/submit`, with a ZIP file as the body. It includes `X-Feedback-Submission` (a UUID for each feedback submission, reused for retries), `X-Feedback-Install` (a UUID for each installation, stored in `isaac-lan/feedback/install-id`), and `X-Feedback-Client` (`isaac-lan/<version>`). WinHTTP prefers the system proxy settings.

| Result | Handling |
| --- | --- |
| Accepted by the server | Display the feedback ID and delete the local copy. |
| Connection failure or server 5xx response | Retry twice with the same idempotency key, after 5 seconds and then 20 seconds. |
| Invalid format, package too large, rate limit exceeded, or uploads paused | Do not retry. Display the corresponding reason; when uploads are paused, display the explanation provided by the server. |

If the server does not accept the package, it is kept in `isaac-lan/feedback/` next to the log directory. The message includes the full path so the player can send it directly to the author. The upload result is written to the current launch log (`feedback_submitted` or `feedback_upload_failure`); the description itself is not logged.

## Experimental Environments

Uploads are disabled by default in isolated test configurations. To test uploads with a fixture, add `[feedback] endpoint = <address>` to `config.ini`; this setting is not included in the default template. The address must use `https://`, or point to a local `http://127.0.0.1:port/...` or `http://localhost:port/...` endpoint. Other values produce a configuration warning and disable uploads.

## Code Locations

| Responsibility | Location |
| --- | --- |
| ZIP creation, truncation, redaction, manifest, and response parsing (offline-testable) | [core/feedback.cpp](https://github.com/BMingSY/isaac-lan/blob/main/src/core/feedback.cpp) |
| File collection, background upload, and Lua binding | [diagnostics/feedback.cpp](https://github.com/BMingSY/isaac-lan/blob/main/src/diagnostics/feedback.cpp) |
| Submission and result delivery | [bridge/diagnostics/feedback.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/diagnostics/feedback.lua) |
| Chat command | [bridge/runtime/chat.lua](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/runtime/chat.lua) |
