# Frequently Asked Questions (FAQ)

## Q: Can players with different host and guest progress play together?

A: Yes. The host's in-run route and item unlocks are authoritative. Character selection and challenge eligibility are checked against each player's own save.

## Q: Can multiplayer unlock achievements?

A: In-game unlocks earned during the current run are preserved. Unlocks the host already had before the run are not granted to guests. The extension does not actively award Steam achievements.

## Q: Will this overwrite personal progress or single-player saves?

A: Existing unlocks are preserved, and counters only merge changes from the current run. Single-player Continue data and multiplayer saves are managed separately.

## Q: Do multiplayer challenges grant the rewards from the original challenges?

A: No.

## Q: Can I save and resume a multiplayer run?

A: Yes. You must use the original host, save slot, player count, join order, and a matching extension build. Temporary challenges cannot be resumed.

## Q: Can a guest reconnect after disconnecting?

A: Yes. As long as the host's session is still active, reconnect using the original `player-id.txt`. The guest's original character is restored, and they return to the host's current room.

## Q: Can new players join mid-run, or can the host be changed?

A: These features are not currently supported.

## Q: Can players explore separately?

A: Yes. Players can explore separate rooms on the same floor. The whole party moves together when changing floors.

## Q: Do all players need the same mods?

A: Content mods must match across all players. Supported UI mods may be installed independently; see the [compatibility list](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-compatibility.md).

## Q: What should I do if I cannot connect?

A: Make sure everyone has installed the same extension build and restarted the game. Check the host address, port (UDP 29506 by default), and firewall settings. Connections across different networks may also require port mapping or forwarding.
