# Isaac LAN

A LAN multiplayer extension for **The Binding of Isaac: Repentance+**, supporting 2–4 players on the Windows version **v1.9.7.17.J460**.

## Features

- Shared floors with room-by-room exploration and combat; join teammates in their rooms at any time.
- Load other mods while retaining the original multiplayer UI and official online entry point.
- View player locations on the minimap, display pings, and reconnect after disconnections.

## Installation

1. Extract the complete installation package and run `Install.cmd`.
2. Make sure the game is closed, then select `isaac-ng.exe` in the game directory.
3. Launch the game normally through Steam, select a save slot, then choose **Online → LAN Multiplayer**.

All players must use the same game version and the same version of this multiplayer extension.

### Linux / Steam Deck (Proton)

Requires the Windows build J460 and Proton 11.0-2 or later.

Set `ISAAC_GAME_DIRECTORY` to the game installation directory, then run:

```sh
python3 install.py --game-directory "$ISAAC_GAME_DIRECTORY"
```

Set the following Steam launch option:

```text
WINEDLLOVERRIDES="winmm=n,b" %command%
```

To upgrade, run the installation command again using the new package. To uninstall, use the same command with `--mode Uninstall` and remove the launch option above. Configuration, multiplayer saves, and historical logs are preserved.

## Configuration and Logs

On first launch, the game directory will contain `isaac-lan/config.ini`:

```ini
; Isaac LAN: Changes take effect after restarting the game.
[network]
; Guest input send rate: 30 or 60; default is 60. Each player can use a different value.
; 30 reduces input traffic but may add one render frame of delay. Host simulation and local display rates are unchanged.
input_hz = 60

[logging]
; Logs are stored alongside the original log.txt in the game data directory, organized by launch and run.
; startup.log records startup and shutdown; runtime.log records in-game events.
; Historical logs can be deleted manually.
; Log levels: DEBUG / INFO / WARN / ERROR. Default: INFO.
level = INFO

[diagnostics]
; Performance statistics: true or false. Default: false. Enable this when investigating stuttering.
; When enabled, performance.jsonl is created in the same log directory.
performance = false
; Performance sampling interval in milliseconds: 100–60000. Default: 1000.
sample_interval_ms = 1000

[chat]
; Chat background opacity: 0–100. 0 is fully transparent; 100 is opaque.
background_opacity = 70
; Custom background image: PNG, JPG/JPEG, or BMP. Use a path relative to config.ini or an absolute path.
; Leave empty to use a solid color. The image is scaled to fit the frame, transparency is preserved, and the original file is not modified.
background_image =
; Solid background, borders/dividers, and general UI text colors: six-digit RGB hex values, without #.
background_color = 231B18
border_color = 79604C
text_color = E8DFCB
```

## Creating and Joining a Room

1. The host sets the port and clicks **Create Room**, then shares their IPv4 address or domain name and port with teammates.
2. Other players enter the host's IP address/domain and port, then click **Join Room**.
3. Everyone selects a character and gets ready. The host starts the game.

The extension uses **UDP** by default on port **29506**. The port can be changed in the interface.

## Uninstallation

Close the game, run `Uninstall.cmd`, and select the same `isaac-ng.exe`. Uninstallation preserves multiplayer saves.

## Technical Documentation

- [Architecture and Development Documentation](https://github.com/Ronix0/isaac-lan/tree/main/docs)
- [Third-Party Mod API](https://github.com/Ronix0/isaac-lan/blob/main/docs/third-party-mod-integration.md)

## Building from Source

Requires CMake, Ninja, 32-bit MinGW-w64, and the source code for Dear ImGui v1.92.6 and MinHook v1.3.4.

Set `ISAAC_IMGUI_SOURCE` and `ISAAC_MINHOOK_SOURCE` to the corresponding dependency source directories, then run:

```sh
cmake -S . -B build-win32 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-x86.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DIMGUI_SOURCE_DIR="$ISAAC_IMGUI_SOURCE" \
  -DMINHOOK_SOURCE_DIR="$ISAAC_MINHOOK_SOURCE"
cmake --build build-win32
python3 tools/build_package.py --build build-win32 --output dist/Isaac-LAN-J460
```

## Issues and Feedback

You can submit feedback directly in the game: while playing online, enter `/feedback describe your issue` in chat. The extension uploads the current and previous launch logs, the original `log.txt`, and `config.ini` to the author's server. A feedback ID is displayed after a successful upload; include that ID when reporting the issue. Only the author can view the logs, and Windows usernames in file paths are replaced. If the upload fails, the extension displays the location of the locally saved feedback package. See [Feedback Upload](https://github.com/Ronix0/isaac-lan/blob/main/docs/feedback.md) for details about collected data.

You can also open an [Issue](https://github.com/Ronix0/isaac-lan/issues). Include your game version, whether you are the host or a guest, reproduction steps, and any other mods you are using. For multiplayer issues, you can attach the complete log archive from the relevant launch.
