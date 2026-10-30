# Targeted Feedback Verification — 2026-10-26

The candidate uses `2c15c8a` as its baseline and includes the room-context, regrouping-destination, and Lazarus's Flip shadow changes from this PR. In the final round, `feedback-fixed-06`, host/guest assertions, floor-transition completion, save and exit, and data restoration all passed. This record covers only these feedback items and their directly affected lifecycle; it does not mean that every item or third-party Mod has been verified.

- **Game:** Repentance+ J460, SHA-256 `7122ac28779925b24e23e2416f231322b1470388bd25e2c08665ad8d53b3ea4f`.
- **Candidate DLL:** `1f2d72861bff9b9a8985327527bdd9c9b9df76335b98dddce405671b43fe289a`.
- **Final fixture:** `state_feedback_regressions.lua`, SHA-256 `8f8c1c05672c72bdf3037a10ccec1c6a421124685abaaa8bf89bacdd1234cf99`.
- **Previous baseline DLL:** `99bada285acd30976616f78806ea693cf4063b4d8b1b89dfa10a7b2cb5df3784`.
- One isolated host and one isolated guest were used, with 40 ms one-way latency, no third-party Mods loaded, and native visual recording and heap checks enabled on both sides.

## Findings and Results

| Feedback | Previous-build evidence and diagnosis | Candidate verification |
| --- | --- | --- |
| Guest crashes when in the same room as a player holding Blood Bag | The reported call stack was character-stat recalculation → grid collision query → empty room descriptor; fault RVA `0x3f0806`. Ordinary Blood Bag same-room/split-room probes did not crash directly. `blood-cache-baseline-01` crashed in the guest's `RemoveCollectible` restoration path after the Blood Bag holder was placed in another room and the flight item was removed. This exposed the same grid-size issue caused by an uninitialized room context. The additional forced stat recalculation had not run before the crash. | The native Blood Bag tear sequence was generated. Both split-room/rejoin cases for the holder, removing flight, remote-character native `EvaluateItems`, and cleanup passed. The empty shell borrows a valid descriptor and initializes its empty grid dimensions; when promoted to a visible room, its background is initialized again. |
| Regrouping after entering the Basement sends the party to the wrong room | `dungeon-outside-baseline-01`: the entering player reached `-4`, while the teammate remained near source-room horizontal coordinate 570; the teammate then entered `-2` from the Basement, and regrouping moved the whole party into the wrong room. | The teammate was regrouped from the right side of the source room to the teammate's position inside the Basement. Remaining there, returning to the original room through the native ladder, and entering again through a teleport initiated by the host all passed. |
| Lazarus cannot see the Flip shadow | The native second Sprite on the base was not included in the previous replica state, and the guest does not execute the base AI. The host/guest visual comparison in `flip-baseline-01` confirmed that the shadow was missing. The fixture's completion marker meant only that the scene had completed, not that the shadow was correct. | Guest shadow visibility, path, and complete native Sprite bytes match the authoritative snapshot. They remain consistent after using Flip, and the shadow becomes hidden after the effect is removed. Both sides' visuals were checked for the visible shadow and its cleanup. |

The original Mod combination and Continue save from the Blood Bag report were not fully replayed. Therefore, the conclusion is **not** that Blood Bag itself necessarily causes the crash. The fix is based on the reported native call chain, code evidence that a remote room object lacked initialization, and an in-game reproduction of the same inventory-restoration failure through an independent trigger. For Flip, acceptance covers shadow display only; it does not extend to the still-unconfirmed dual-sided pickup behavior in the original item list.

## Checks Performed

- All 65 targeted Linux CTest cases passed, covering room migration/scope, regrouping, collectible cache, layered state, native encoding, and special appearance. New offline cases cover layout deduplication/cleanup for rooms outside the occupied map, as well as shadow changes, repeated application, an empty base, and hiding.
- The Windows x86 build passed. These four tests passed: `native.lua_api`, `core.room-map`, `core.room-scope-ownership`, and `core.fixed-state-fields`.
- `tools/format.py --check`, `tools/check_scripts.py`, and `git diff --check` passed.
- Final live-game verification used [run_teleport.py](https://github.com/BMingSY/isaac-lan/blob/main/tools/run_teleport.py) with `--feedback-regressions --heap-check --record`. All fixtures ran consecutively using the same host/guest process pair.
- Both sides recorded `floor_transaction=COMPLETE stage=2` in `feedback-fixed-06`. The host save completed; both processes exited with code 0; both heap checks exited with code 0 and produced zero dumps. Candidate DLL and fixture hashes match the final source artifacts.
- Visuals from `feedback-fixed-05`, using the same DLL, were checked on both sides: host frame 229 and guest frame 172 show the same shadow; guest frame 188 is after using Flip, and frame 202 is after removing the effect. Original visuals, logs, and reports remain in isolated test artifacts; player logs and raw attachments are not committed.

## Failures, Retests, and Restoration

| Round | Result and follow-up |
| --- | --- |
| Initial injected probe | Startup failed before gameplay began; switched to automatic loading from an isolated directory. |
| `feedback-fixed-01`, `02` | Initial Basement landing and ladder return passed, but the second approach to the artificial ladder did not trigger the expected entrance and the fixture aborted; this cannot count as a complete pass. Re-entry was changed to an explicit room teleport, still covering a second initiator and the regrouping destination. |
| `feedback-fixed-03` | Basement checks passed, but the Blood Bag movement probe stepped onto a ladder left behind by the previous case, invalidating the tear-sequence precondition. Added entrance cleanup between cases. |
| `feedback-fixed-04` | Blood Bag tear sequence, split-room/rejoin, and native stat recalculation passed. A background-rendering issue occurred when an empty shell became a visible room. After correcting the empty shell's drawing-cache initialization boundary, the build was recreated. The native rendering anomaly at the same address observed during the earlier aborted failure was retained as evidence. |
| `feedback-fixed-05` | Assertions, visuals, and clean exit for all three feedback items passed. Log review found that the completion marker occurred before the native floor transaction had completed, so the floor-transition check could not count as passed. The original report was retained, and the fixture was changed to wait until both the room and authoritative view were ready. |
| `feedback-fixed-06` | All targeted checks, floor-transition completion, save, and exit passed. |

A restart was performed only after startup failure, abnormal abort, a build change, or a revision to the verification fixture. Within each round, the same host/guest connection was reused. Each round used `ProtectedLabs` to back up and restore configuration, saves, and logs, then verified restoration with per-file hashes. The user's manually played game directory was not touched.
