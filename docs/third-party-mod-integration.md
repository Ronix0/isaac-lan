# Third-Party Mod Integration

Isaac LAN API 2 provides a local view, per-frame local UI, host actions, and lifecycle notifications. The same SDK supports both single-player and LAN; there is no need to access `_IsaacLan` directly or branch on host/guest role. The DLL publishes the API before third-party Mods initialize.

## Quick Start

Copy [`src/bridge/api/sdk.lua`](https://github.com/BMingSY/isaac-lan/blob/main/src/bridge/api/sdk.lua) into your Mod directory as `isaac_lan.lua`. The file includes LuaLS type annotations and is also the implementation used inside the DLL. Attach once during loading:

```lua
local mod = RegisterMod("My Mod", 1)
local lan = include("isaac_lan").attach(mod, "author.my-mod")
```

When LAN is not installed, the SDK uses the game's single-player interfaces. During LAN session preparation, it waits for the local view to become ready and does not bypass the host for gameplay operations. An integration that requires LAN can also call `IsaacLAN:Attach(mod, "author.my-mod")` directly.

| Goal | Interface |
| --- | --- |
| Local UI such as stat panels, maps, and descriptions | `lan:OnLocalRender(fn)`; read `view.players` inside the callback |
| Check whether a callback character belongs to this client | `lan:IsLocalPlayer(player)` |
| Request a world-changing operation from the UI | `lan:Action(name, definition)`, then `action:Request(...)` |
| Clear caches across rooms/floors | `lan:On(event, fn)`; see the [API Reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-api-reference.md) for all events |
| Adapt a third-party Mod that has not explicitly integrated | [Auto-Adapters](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-adapter-development.md) |

## Local UI

```lua
local cancel = lan:OnLocalRender(function(view)
    for i, player in ipairs(view.players) do
        Isaac.RenderText(string.format("P%d damage %.2f", i, player.Damage),
            50, 55 + i * 12, 1, 1, 1, 1)
    end
end)
```

The callback runs on game render frames and does not wait for a new network snapshot. The SDK automatically enters the local room and character scope. Existing UI calls such as `Game():GetRoom()`, `Game():GetNumPlayers()`, and `Isaac.GetPlayer(i)` also read the local view. Drawing is skipped during preparation. An error disables only the failing callback and restores the scope. `cancel()` can be called repeatedly; `lan:Close()` performs unified cleanup.

This interface is for reading the world and drawing UI. Operations such as dealing damage, granting items, and teleporting must use host actions. Global script caches remain the Mod's responsibility. Retrieve native character objects again from the current view.

## Request a Gameplay Action

The following teaching example gives one coin to the selected character each time. A production Mod can replace the business conditions and effect with its own:

```lua
local coin = lan:Action("coin", {
    cooldownTicks = 30,
    execute = function(context)
        context.player:AddCoins(1)
        return {status = "applied", code = "coin_added",
            data = {coins = context.player:GetNumCoins()}}
    end,
})

-- Trigger from your own button or input callback.
-- The player argument is optional; by default, the first local character is selected.
local request = coin:Request(nil, {
    player = lan:GetLocalPlayers()[1],
    onResult = function(result)
        Isaac.DebugString(result.status .. ":" .. result.code)
    end,
})
```

In single-player, `execute` is called directly. In LAN, only the host executes it in the participant's room and deduplicates by request ID. `context.player` is the body selected for this request; the host verifies its participant ownership again and does not trust a player number from the payload. The UI can use `coin:IsAvailable()` to check host capability. The result callback runs once on success or rejection and may run synchronously before `Request` returns.

For requests with parameters, provide `validate(payload)`; by default, only `nil` is accepted. The host must check current gameplay conditions inside `execute`; the payload expresses intent only. Asynchronous LAN operations use `context:Wait(...)` or `context:MoveTo(...)`. Provide `solo(context, payload)` to call the Mod's own single-player logic. See [Action Reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-api-reference.md#actions-and-completion-results) for details.

## Runnable Example

[`examples/mod-api/main.lua`](https://github.com/BMingSY/isaac-lan/blob/main/examples/mod-api/main.lua) is a complete Mod. It displays the local character's coin count and requests one coin when F6 is pressed. Generate a standalone directory containing the SDK, then place it in the isolated game's `mods` folder:

```sh
python tools/export_mod_example.py /tmp/isaac_lan_api_example
```

The example is for development and includes an operation that grants coins. The same entry point is used without LAN, in single-player, and by both host and guest. For multiplayer verification, install the example on both clients so that each can provide the host handler.

## Installation Scope

Only the user of a local UI needs to install it; Stats+ and EID do not require the host to install their corresponding UI. GoodTrip's host action is provided by LAN itself, while its map UI can still be installed only by the user. New items, characters, entities, rooms, or resources still require the same content on every client.

The API does not automatically copy `GetData()`, arbitrary custom state, source code, configuration, or resources. It does not provide a third-party prediction-event channel. Code that runs only through the local UI interface does not become host gameplay logic. See the [Mod Compatibility Catalog](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-compatibility.md) for the current built-in compatibility scope.

See the [API 2 Reference](https://github.com/BMingSY/isaac-lan/blob/main/docs/mod-api-reference.md) for all methods, identity rules, action limits, and cleanup conventions.
