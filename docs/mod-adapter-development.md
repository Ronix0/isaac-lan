# Third-Party Mod Auto-Adapters

Automatic compatibility lets older Mods that have not explicitly integrated the API use supported features in LAN sessions. Wrappers are installed when the target Mod loads and initializes, and remain active in later single-player and LAN sessions. Therefore, methods call their original functions when multiplayer is inactive and use the local view or host actions only in LAN sessions. Preserving single-player behavior is a runtime requirement for these wrappers. Installation is based on target identity and the interfaces actually needed; version/source restrictions are used only when an interface difference makes them necessary.

`IsaacLAN:RegisterAdapter(definition)` returns a disable function. Disabling cleans up this installation's UI and independent capabilities but retains the registered definition. The same `id` cannot be registered twice in one Lua environment; use the compatibility toggle to re-enable it. Definition:

| Field/callback | Contract |
| --- | --- |
| `id` | Unique namespace, using the same character and 64-byte limit as integration IDs |
| `adapterVersion` | Positive integer identifying the adapter implementation; it does not replace the upstream version/fingerprint |
| `modName` | Exact name of the target's actual `RegisterMod` instance |
| `targets` | Array of supported target configurations. Each entry must have `workshopId`; `metadataVersion` and `sourceHash` are optional |
| `probe(target)` | Returns `"ready"`, `"pending"`, or `"unsupported", reason`; wait while exports are incomplete and reject incompatible interfaces |
| `install(target, api)` | Installs after a successful probe; must return a cleanup function and must not modify upstream source files on disk |
| `authority(api)` | Optional registration of independent host actions; must also return a cleanup function and must not depend on a local UI Mod being installed |
| `dispatch(target, record, ...)` | Optional target-callback wrapper; preserves arguments and return values. Paths it does not handle must call and return `record.original(...)` |

Each target must provide a `workshopId`. `metadataVersion` and `sourceHash` are optional restrictions chosen by the adapter. Built-in EID, Stats+, and GoodTrip adapters probe the interfaces they actually need and do not lock to a release version or source hash. The load observer confirms the target using the actual `RegisterMod` instance, source directory, enabled state, and source fingerprint. A directory alone, a Mod with the same name, or a leftover global is not a match. `target` contains `mod`, directory/version/fingerprint information, and module exports loaded from that source. The second argument to `RegisterMod` is not the Mod release version.

`workshopId` must be a non-empty string. If provided, `metadataVersion` must also be a non-empty string, and `sourceHash` must contain exactly 64 lowercase hexadecimal characters. Public fields on the observed `target` are `mod`, `directory`, `workshopId`, `metadataVersion`, `sourceHash`, and `modules`. `modules` maps actual `require` names to observed module exports from that directory. During installation, `target.addCleanup(fn)` is also available. When using `dispatch`, `record` contains `id` (game callback ID), `original`, `param`, `priority`, and the wrapper function `wrapper`.

The source fingerprint is SHA-256. It first hashes `Isaac LAN/compat-source-v1` and a zero byte, then processes every `.lua` file in relative-path order: relative path, zero byte, lowercase hexadecimal file SHA-256, and zero byte. `gtconfig.lua` and `eid_config.lua` are configuration files and are excluded from source identity. Other Lua files, including language and service implementations, are included. Version and source changes may still be used for diagnostics; they affect target matching only when the adapter explicitly provides the corresponding restriction.

`probe` returns `ready`, `pending`, or `unsupported` and a reason. Installation occurs once, only after `ready`. A `pending` probe is retried after initialization and before the first callback. During `install`, `api:Attach(target.mod, definition.id)` obtains a handle owned by this adapter and does not trigger the priority rule for explicit integration. The target Mod takes priority only when it actively registers outside the adapter's installation callback. `install` must return a cleanup function and call `lan:Close()` to release its handle. Use `target.addCleanup(fn)` to register cleanup for partially completed installation so failures can roll back. `authority` registers independent host capabilities during loading and is not skipped just because a run has not started or a local UI Mod is absent.

Registered cleanup functions run in last-in, first-out order and should restore only methods and resources still owned by this adapter. A compatibility module can be disabled and re-enabled, so cleanup must tolerate repeated calls. Reinstallation must not duplicate subscriptions or stack wrappers. An exception in `probe` or `install`, or an installation that fails to return a function, enters `error`. Review logs before re-enabling; do not force reinstall every frame. Independent-capability cleanup and target-UI cleanup are managed separately. Explicit target integration takes priority only for that instance; it does not automatically determine whether independent capabilities should remain active.

Callback wrappers preserve priority, arguments, original order, and return values. Calling the original `RemoveCallback` still removes the wrapper. Existing callbacks are replaced in their original list positions; they are not removed and re-added in a way that changes ordering. Method cleanup reverts only modifications that still belong to this module. Reconnecting does not install wrappers again.

## Compatibility State and Toggles

`IsaacLAN:GetAdapters()` returns an array sorted by `id`. Each entry has the following fields and contains no native objects:

| Field | Meaning |
| --- | --- |
| `id`, `adapterVersion` | Adapter ID and implementation version |
| `state`, `reason` | Current state and reason string |
| `authority` | Boolean indicating whether independent-capability installation returned a cleanup function. It does not mean "this side is currently the host" and does not indicate that every action has been enabled. |
| `target` | Matched target as `{workshopId, metadataVersion, sourceHash, directory}`; `nil` until a target is bound. No Mod handle is included. |

| `state` | Meaning/common reasons |
| --- | --- |
| `not_detected` | Waiting for the actual target to load, e.g. `waiting_for_mod` |
| `pending` | Identity matched; waiting for runtime exports or initialization, e.g. `initializing` |
| `active` | Probe and installation completed, `installed`; this does not mean every feature has passed acceptance testing |
| `unsupported` | Name observed, but version/source mismatch, duplicate target instance, or runtime interface incompatibility |
| `disabled` | Configuration disabled, disable function called, or target explicitly integrated, e.g. `configuration`, `unregistered`, `native_integration` |
| `error` | Exception during probing, installation, or independent-capability installation; full error is in the log |

When a version is not matched, `target` may still be `nil`. Use `state/reason` to determine the result; do not rely only on whether `target` exists.

Independent toggles are persisted in the game's Mod integration configuration file, `integrations.ini`, through `IsaacLAN:SetAdapterEnabled(id, enabled)`. They are enabled by default. To retain the host's own GoodTrip UI while preventing anyone from teleporting, the host can call `IsaacLAN:SetActionEnabled("isaac-lan.compat.goodtrip", "travel", false)`. This action toggle applies only to the current Lua environment. To permanently disable the built-in host capability, disable the corresponding compatibility module.

`enabled` must be a boolean. A successful compatibility toggle returns `true`. Unknown IDs return `false, "compatibility_not_registered"`; a configuration-write failure returns `false, "configuration_write_failed"`; and a failed independent-capability installation when re-enabling returns `false, "authority_install_failed"`. `true` means only that the toggle operation completed; query the adapter state to confirm whether the UI was actually installed. An action toggle applies only to the local registration definition. Whether the party can execute it is determined by capabilities published by the host; a guest cannot authorize a host action using its own toggle.

Mods that integrate explicitly should use the [SDK Quick Start](https://github.com/BMingSY/isaac-lan/blob/main/docs/third-party-mod-integration.md) and do not need to register an auto-adapter.
