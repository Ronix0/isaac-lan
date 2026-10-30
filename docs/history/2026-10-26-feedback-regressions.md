# Feedback Regression Round — 2026-10-26

## Scope

This round addresses the feedback and regressions collected after the previous acceptance run. It is a targeted development regression, not a new release-acceptance result. The original scope and conclusions of earlier rounds remain unchanged.

## Changes and Verification

- Corrected the character-state restoration path so a replacement body cannot retain stale native references.
- Fixed a room-transition case in which a guest could apply a view from the previous room after the host had already advanced.
- Tightened cleanup for pending presentation events when the room or world generation changes.
- Rechecked the affected host/guest scenarios with the same isolated fixtures and candidate build.
- Preserved the original failure evidence and recorded the retest separately.

## Result

The targeted scenarios completed with the expected host and guest state. This round does not establish acceptance for every item, character, third-party Mod, or performance-stress scenario. Those remain outside this round's scope unless separately tested and recorded.
