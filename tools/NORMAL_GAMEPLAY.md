# Normal-Input Two-Client Regression

Run this in WSL using the two independent game copies created by [prepare_lab.py](https://github.com/BMingSY/isaac-lan/blob/main/tools/prepare_lab.py) with the tool's default configuration. Both copies must have the `.isaac-lan-lab` marker. If a game process is already running, the script refuses to reuse these copies. In the examples, `ISAAC_RUN_OUTPUT` and `ISAAC_FFMPEG` specify the output directory for this run and the recording tool.

Adding `--latency-ms 75` introduces 75 ms of delay in each UDP direction within the same workflow. The guest changes the address in the original input field to the isolated proxy port `29507`; the host continues to listen on `29506`. The proxy runs only during the script's complete `run` and is shut down when it exits.

This simulates approximately 150 ms RTT. It is not a substitute for testing with real frp networking.

Use a new output directory for every run. The workflow uses the fixed seed `LBCD 0G4M`, Normal difficulty, two Azazels, no extra Mods, and a direct connection to `127.0.0.1:29506`.

The tool navigates from the title screen through the save and Online menus to the LAN menu, enters the IP, selects characters, readies up, and starts. It then uses normal doors, collects items, uses The Fool card, shoots to clear rooms, explores separate rooms, fights a Boss, verifies that the party receives two rewards, pauses and resumes, enters the next floor, and checks the guest's first door transition. After entering a large room on the next floor, the guest continues normal shooting. The test checks that the camera is stable and the character remains visible.

The original game allows one player to collect two rewards in succession. The test checks the increase in the party's total item count. The gameplay assistant uses only directional and shooting buttons. Character death, failed door transitions, callback errors, and similar events are recorded as failures.

For simultaneous door transitions, both players first use directional input. The tool then moves anyone who has not arrived based on their actual position. If the original transition animation consumes the button hold time, a player still waiting at the door is not counted as having transitioned.

The test does not call interfaces that change rooms, spawn items, restore health, kill enemies, or modify network frames. The observer only reads state. Input follows the normal native controller-processing and network-sending path.

Combat on a fixed route still depends on the game state. When a run fails, inspect the records; a failed result must not be reported as a pass.

## Automatically Saved Output

- `tested-probe.dll`, `observer.lua`, `controller.py`: frozen copies of the DLL, observer, and control script actually used for this run.
- `actions.jsonl`: action timestamps, buttons, hold durations, and milestone state.
- `*-host.png`, `*-client.png`, and matching JSON files: actual screenshots and each side's room state.
- Continuous frame archives for host and guest: rendered frames and the `frames.csv` time index.
- `*-game-before-close.log`, `*-probe-before-close.log`: both sides' logs frozen before either side is closed.
- `*-probe-this-run.log`: native logs from this launch only, so errors from earlier runs in the isolated directory are not mistaken for current failures.
- `report.json`: workflow result, errors, and verification scope. Screenshots still require visual review.
- `*-final-observer.json`: final state for both sides frozen before either client is closed, so closing the host cannot leave only the guest lobby state to inspect.
- `*-recording.mkv`: when `--ffmpeg` is specified, a lossless continuous recording archived automatically after both sides close.
- `*-filmstrip.png` and matching JSON: continuous frames from this side while a teammate passes through a door, including frame numbers and timestamps.
- `visual-candidates.json`: automatic screening results for abnormal black frames while this side remains in the same room.
- `*-floor-hud.jsonl` and `floor-hud-result.json`: continuous reads of multiplayer HUD ownership from before the floor transition until the original animation finishes. The local slot must continue to represent the same player; checking only after arrival on the next floor is insufficient.

Frames are captured directly before `SwapBuffers` in the isolated process, then encoded by a background thread. This can record a client obscured by another window. Recording is enabled only in a marked isolated copy when `visual-capture.test` exists. Full gameplay defaults to approximately 10 fps and records dropped frames. Targeted flicker tests can use a 16 ms sampling interval; actual intervals and dropped frames are written to the time index.

This is useful for checking characters, cameras, shadows, and persistent flicker. It cannot prove that a flicker lasting only one rendered frame never occurs. A local direct connection also cannot replace an frp latency test.

Black-frame screening is advisory and does not replace visual inspection. A normal room-transition fade is not classified as a teammate door-transition flicker. Compare the host screenshots for `large-room-clear`, `shop-separated`, and `client-door-1`: when the guest enters and leaves a small Shop, the host's large room must not display the small-room wall-shadow border. Also inspect `second-floor` and `second-floor-arrival-settled`: both sides must retain original multiplayer health, cards, and active-item slots, with each camera and stat panel assigned to the local player.

Without `--ffmpeg`, continuous PNG frames are retained. After both clients close, run `archive_gameplay.py` and `review_gameplay.py` separately; both accept `--ffmpeg`.

After a run, use `archive_gameplay.py RUN_DIRECTORY --ffmpeg "$ISAAC_FFMPEG"` to convert continuous PNGs into a lossless RGB video and verify the frame count and first-frame pixels. Key screenshots, state, and time indices are retained. The complete continuous recording is stored as `*-recording.mkv`, avoiding large collections of PNGs after every run.

## Step-by-Step Manual Inspection

When the route needs to be adjusted based on screenshots, use the same output directory and operate in steps:

```bash
python3 tools/manual_gameplay.py capture --name CHECKPOINT --output "$ISAAC_RUN_OUTPUT"
```

Directional inputs are `u/d/l/r`. Shooting buttons `a/b/x/y` correspond to down/right/left/up. `rb` uses a card; `start` pauses or resumes. Combine buttons with `+`. Continuous frames are always saved automatically. Door transitions and completed combat also save milestone screenshots for both sides.

## Fixed Regression Workflow

The full fixed regression can be run in one command.

The default `gameplay` suite starts one pair of clients from the menu and connects once. In the same run it checks movement prediction; White Fire changes and native room-clear recovery; conditional door-entry protection; active-item input and Battery Plug; Collar and Nine Lives revival; Brimstone charge bars; split-room Boss announcements; the Glowing Hourglass on host and guest, including cross-floor rewind; Devil Room doors; Rerun, the five-pip Dice Room, and the R key; and finally Mirror Room direction and large-room camera behavior. Fixture state is cleared between cases, but the same multiplayer session and game processes are kept alive. Network frame numbers continue increasing; the game is not restarted. Logs must show exactly one run start per side and a completion record for every check.

Only while waiting between targeted cases that have already completed may the idle character receive temporary protection. The next case restores normal damage cooldowns and checks that no dead or ghost character remains. The ordinary one-floor workflow does not use this protection.

The Dice Room fixture prepares the original five-pip floor and lets the character step on it, allowing the original collision logic to trigger the reset. White Fire first uses an unexplored combat room. During a room clear, it handles child enemies created by original enemy deaths. The test White Fire is removed before returning to avoid repeated contact at the doorway.

`gameplay-suite.lua` and the matching JSON freeze the original cases, relative timestamps, source hashes, and checkpoints. To run only these continuous cases, add `--cases gameplay`. Existing individual case names can still be used to isolate a failure.

Save/resume, unexpected disconnects, and floor changes during loading affect connection lifecycle and remain separate tests. Installation/loading and HUD ownership, the first Boss reward and revival, and host flicker recording also retain their own explicit setup requirements.

Finally, run the one-floor workflow completed through the normal menu and controller inputs. Targeted fixtures do not replace normal gameplay testing. `check_mirror_camera.py` checks character movement and camera offset on every render; original animations, character bodies, and charge bars still need visual review in the recording.

Each run freezes one DLL hash, saves per-case logs, and writes an overall result. Screenshots must still be reviewed as described above. Continuous regression automatically saves key frames to the checkpoint archive, with actual frame numbers and network timestamps in the index.

Continuous cases record both host and guest screens. If `--ffmpeg` is specified, after both clients exit the recordings are automatically archived as lossless `host-recording.mkv` and `client-recording.mkv`, retaining checkpoints and `frames.csv`; otherwise all PNGs are kept. Rerun, Dice Room, and the R key are checked on both sides for floor state and preserved items, health, and resources. Missing logs or recordings cause the test to fail.

Adding `--goodtrip "$ISAAC_GOODTRIP_MOD"` copies that Mod unchanged into both isolated clients. It additionally checks map-input/cursor isolation during simultaneous use, local room caches, and host-side execution of guest teleport requests. The normal installation directory is not modified. This targeted fixture first prepares two visited and cleared rooms, then uses the original controller map and directional shooting input to select a destination. It does not replace Good Trip's teleport function.

The targeted flicker test uses `run_network_engine.py --native-record-view 0 --frame-ms 16` to save actual back-buffer frames. `check_peer_flash.py OUTPUT_DIRECTORY --ffmpeg "$ISAAC_FFMPEG"` checks only game frames where the host has not changed rooms and reports brightness-anomaly candidates, sample intervals, and dropped frames. It can reproduce a one-frame full-black image caused by original background-room loading, but it cannot prove that no shorter visual issue occurred between samples.
