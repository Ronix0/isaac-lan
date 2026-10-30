# Steam Workshop Updates

Update the existing [Isaac LAN / LAN Multiplayer](https://steamcommunity.com/sharedfiles/filedetails/?id=3817760679) item using the official GitHub Release package and approved copy. App ID: `250900`. Item ID: `3817760679`. Do not create a new item for a new version.

By default, the tool updates only the content and version update notes, preserving the title, descriptions in all languages, cover image, tags, and visibility. With `--prepend-notes`, it places the version heading and approved update notes before the default-language and Simplified Chinese descriptions, separated from the original description by `-----`. `--replace-notes-version` replaces the notes for the specified version at the top of the description. `--preview` specifies the cover for this update and also updates `preview.png` in the content. Existing group numbers, feedback links, and similar information in the descriptions are preserved.

## Prepare the Environment

- Steam is signed in on Windows with the account that owns the item, and Isaac is installed. The game does not need to be launched, and game acceptance testing does not need to be repeated.
- The GitHub Release is published, and the checked-out release notes match the target tag. Copy is reviewed according to [AGENTS.md](https://github.com/BMingSY/isaac-lan/blob/main/AGENTS.md#release-copy-conventions); reuse previously approved, unchanged wording.
- The Python environment has the [tool dependencies](https://github.com/BMingSY/isaac-lan/blob/main/tools/requirements-ci.txt), `gh` is authenticated, and the Windows x86 build environment is configured as described in [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md).

Build the release helper. It is not included in the player installation package:

```sh
cmake --build build-win32 --target isaac_lan_workshop
```

Run the following commands in WSL Bash. Set three variables first: `ISAAC_GAME_DIR` to the game directory, `WORKSHOP_ASSETS` to the current download directory, and `WORKSHOP_OUTPUT` to the preparation directory. Use WSL paths. The preparation directory must be on a Windows drive and must not already exist. The tool also supports Windows Python, in which case use Windows paths.

## Prepare the Package and Copy

```sh
tag="v$(cat VERSION)"
gh release download "$tag" --repo BMingSY/isaac-lan \
  --dir "$WORKSHOP_ASSETS" --pattern '*.zip' --pattern '*.sha256'

python tools/workshop_release.py prepare \
  --helper build-win32/isaac_lan_workshop.exe --game "$ISAAC_GAME_DIR" \
  --archive "$WORKSHOP_ASSETS/Isaac-LAN-$tag-windows-x86.zip" \
  --notes ".github/release-notes/$tag.md" \
  --tag "$tag" --output "$WORKSHOP_OUTPUT"
```

`prepare` does not publish. It validates the package, queries the existing item, downloads its current content, preserves the original Lua entry point, preview image, and installation instructions, updates the version in `metadata.xml`, and includes only the current ZIP and checksum file. Update notes are converted to Steam BBCode heading format without changing their wording.

To place the update notes at the beginning of the description and change the cover, append `--prepend-notes --preview docs/assets/steam-workshop-cover.png` to the `prepare` command. Use this only when explicitly requested by the user. The preparation result also includes the full descriptions in each language and the cover hash. Before publishing, verify that they match the approved copy, original descriptions, and specified image. This operation adds one new section before the existing description; it does not automatically remove historical version sections.

To replace an older version's notes at the top, use `--replace-notes-version v0.5.0`. The version must match the existing section, and this option cannot be used together with `--prepend-notes`. The tool checks that both the default-language and Simplified Chinese descriptions start with that version heading and contain the `-----` separator before the item description. Only the notes before the separator are replaced. If either language has a different version or structure, preparation stops; it does not publish a partial change.

The Steam page cover must be smaller than 1 MB. If the original image exceeds this limit, create a compressed copy and pass it with `--preview-upload`. Keep the original image in `--preview` so it remains in the downloaded content. The release tool validates the uploaded copy and the content image separately.

Review `reviewed-notes.md`, `steam-change-notes.txt`, and `preparation.json` in the output. Copy should describe only player-visible changes. Omit a category when there are no new features; do not list debugging causes, internal synchronization mechanisms, or step-by-step troubleshooting.

## Publish and Verify

After receiving authorization for this publication and approval of the copy, run:

```sh
python tools/workshop_release.py publish \
  --helper build-win32/isaac_lan_workshop.exe --game "$ISAAC_GAME_DIR" \
  --output "$WORKSHOP_OUTPUT"
```

Before publishing, recheck local file and copy hashes and whether the remote item has changed. A successful upload requires a Steam success receipt and no pending agreement acceptance. The tool then downloads the item, verifies every file, and checks the default-language and Simplified Chinese titles, descriptions, and visibility. An old installation package must not remain.

Descriptions are submitted separately by language. The first submission includes content, update notes, and the optional cover; later language submissions update only the description and do not resubmit update notes. Each language has its own receipt. If any submission fails or does not return success, the entire publication is not considered complete. When a cover is specified, the tool downloads the preview image from Steam's returned address and verifies its hash.

Keep the full output directory, including the preparation manifest, upload receipts, and `verify-*/verification.json`. Finally, inspect the Workshop page and update notes to confirm that the existing title is preserved and the description uses the approved copy. A log that only says "submitted" is not proof of a completed publication.

## Interrupted or Failed Updates

To verify the published content without uploading again:

```sh
python tools/workshop_release.py verify \
  --helper build-win32/isaac_lan_workshop.exe --game "$ISAAC_GAME_DIR" \
  --output "$WORKSHOP_OUTPUT"
```

- After an upload timeout or process exit, preserve `upload-started.json`, run `verify`, and inspect the remote update record first. Do not immediately submit again. If the upload is confirmed unsuccessful, prepare and retry in a new directory.
- If only some languages completed, preserve their success receipts and compare completed and pending remote fields. Do not re-upload completed content or prepend the same version section again.
- If Steam requires agreement acceptance, the account owner must handle it. If the package, copy, or remote item changes, prepare again; changed wording requires a new review.
- When the Steam webpage is rate-limited, Steam API and download hashes can verify content, but distinguish those results from verification of the web update record. An empty Simplified Chinese title may simply mean no separate title was set for that language; preserve the pre-publication snapshot and do not rename it automatically.

Implementation entry points: [Python release tool](https://github.com/BMingSY/isaac-lan/blob/main/tools/workshop_release.py) and [Steam API tool](https://github.com/BMingSY/isaac-lan/blob/main/tools/workshop.cpp). The interface follows the [Steamworks UGC documentation](https://partner.steamgames.com/doc/api/ISteamUGC): wait for the submission result callback, then read the installation directory after download completion. Development regression uses a simulated Steam interface. The tool may query/download the existing item during validation, but tests must not publish repeated updates.
