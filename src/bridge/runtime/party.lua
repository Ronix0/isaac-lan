-- Bind a complete native party before opening the simulation gate. Physical
-- controller IDs from Continue are not identities; only its saved head order is.
return function(native, player)
    return function(status, continued, restoredOrder)
        if continued then
            local heads = restoredOrder and native.rooms_heads(1) or native.rooms_heads()
            for slot = 0, status.players - 1 do
                local index = assert(heads[tostring(slot)], "Missing multiplayer character")
                assert(native.input_assign(index, slot + 1), "Failed to assign multiplayer character")
            end
        else
            assert(native.input_assign(0, 1), "Failed to assign host character")
            for slot = 1, status.players - 1 do
                assert(
                    native.players_spawn(status["character" .. slot], slot + 1),
                    "Failed to create guest character"
                )
            end
        end
        local heads, seen = native.rooms_heads(), {}
        for slot = 0, status.players - 1 do
            local index = assert(heads[tostring(slot)], "Missing multiplayer character")
            assert(not seen[index], "Duplicate multiplayer character")
            seen[index] = true
            local p = assert(player(index))
            assert(p.ControllerIndex == slot + 1, "Multiplayer character controller ownership mismatch")
        end
    end
end
