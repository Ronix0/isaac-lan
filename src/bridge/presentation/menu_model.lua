local UNRESTRICTED_CHARACTER = 65535
-- Menu decisions and actions are independent of fonts, sprites and mouse geometry.
return function(Phase, Command, endpoint)
    local CHALLENGE_MODE, MODE_COUNT = 4, 5
    local function idle(phase)
        return phase == Phase.idle or phase == Phase.failed or phase == Phase.closed
    end
    local function compatibilityError(status)
        local failure = status.compatibilityError
        if status.phase ~= Phase.failed or not failure then
            return nil
        end
        local reasons = {
            version = "Unable to join: Isaac LAN versions do not match",
            fingerprint = "Unable to join: Version numbers match, but builds differ",
            protocol = "Unable to join: Multiplayer protocols do not match",
            unavailable = "Unable to join: Could not verify the host's version",
        }
        local remote = failure.remoteVersion
        return {
            reasons[failure.reason] or reasons.unavailable,
            "Host: "
                .. (remote and remote ~= "" and remote or "Unknown")
                .. "   Your version: "
                .. failure.localVersion,
            "Make sure both players are using the same Isaac LAN version and build.",
        }
    end
    local function validPort(ui)
        local number = tonumber(ui.port)
        if number and number % 1 == 0 and number >= 1 and number <= 65535 then
            ui.port = tostring(number)
            ui.errorText = ""
            return true
        end
        ui.errorText = "Port range: 1–65535"
        return false
    end
    local function remember(ui, native)
        if validPort(ui) then
            native.menu_connection_save(ui.ip, tonumber(ui.port))
        end
    end
    local function back(ui)
        if ui.page == "rules" then
            ui.page, ui.selection = "lan", ui.ruleReturn or 1
            ui.ruleReturn, ui.ruleScroll = nil, nil
            return true
        elseif ui.page == "challenges" then
            ui.page, ui.selection = "lan", 3
            return true
        end
        return false
    end
    local function rows(ui, status, characterChoices, challenges, deps)
        local phase = status.phase or Phase.idle
        local modes = ui.page == "modes"
        local challenge = challenges[tostring(status.challenge or 0)]
        local notice, ruleCount
        local localSlot = status.slot or 0
        -- No seat exists until the host has accepted the connection. Default
        -- session values must not appear as a joined P1 after a failed attempt.
        local count = (
            phase == Phase.lobby
            or phase == Phase.running
            or phase == Phase.loading
            or phase == Phase.waiting
            or phase == Phase.returning
        )
                and (status.players or 0)
            or 0
        local host = status.hosting == 1
        local rulesLocked = challenge and challenge.roomOptionsLocked
        local rulesEditable = host and not rulesLocked
        local ready = status["ready" .. localSlot] == 1
        local choice = status["choice" .. localSlot] or 0
        local rows = {}
        local function row(label, action, enabled, change, field, color)
            rows[#rows + 1] = {
                label = label,
                action = action,
                enabled = enabled ~= false,
                change = change,
                field = field,
                color = color,
            }
        end
        local function command(action, value)
            local ok, reason = pcall(deps.command, action, value or "")
            ui.errorText = ok and "" or tostring(reason):gsub("^.-:%d+: ", "")
            return ok
        end
        local selectedRules, firstRule = 0, nil
        for _, definition in ipairs(deps.options or {}) do
            if ((status.roomOptions or 0) & definition.flag) ~= 0 then
                selectedRules = selectedRules + 1
                firstRule = firstRule or definition.shortName or definition.name
            end
        end
        local function ruleEntry()
            local summary = firstRule or "None"
            if selectedRules > 1 then
                summary = summary .. " +" .. (selectedRules - 1)
            end
            local index = #rows + 1
            row("Room rules: " .. summary, function()
                if not rulesLocked then
                    ui.page, ui.selection, ui.ruleScroll, ui.ruleReturn = "rules", 1, 1, index
                end
            end, not rulesLocked, nil, nil, not host and not rulesLocked and deps.accent or nil)
        end
        if status.pendingSave == 1 then
            row("Retry saving multiplayer progress", function()
                command("retry_save")
            end)
            row("Back", deps.hide)
        elseif not host and (status.recovering or phase == Phase.running) then
            local busy = status.recovering and (phase ~= Phase.failed or status.prepared)
            notice = status.recovering and (busy and "reconnecting" or "reconnect_failed") or nil
            row("Reconnect to Game", function()
                command("reconnect")
            end, not busy)
            row("Leave Game", function()
                command("leave")
            end)
        elseif modes then
            row("Official Online", function()
                if command("close") then
                    deps.native.menu_official()
                    deps.hide()
                end
            end)
            row("LAN Multiplayer", function()
                ui.page = "lan"
                ui.selection = 1
            end)
            row("Back", function()
                deps.hide()
            end)
        elseif idle(phase) then
            row("Create Room", function()
                if validPort(ui) then
                    remember(ui, deps.native)
                    command("host", ui.port)
                end
            end)
            row(ui.ip == "" and "Enter the host's IP" or ui.ip, function()
                ui.editing = "ip"
                deps.native.menu_text_begin(ui.ip, "ip")
            end, true, nil, "ip")
            row("Port: " .. ui.port, function()
                ui.editing = "port"
                deps.native.menu_text_begin(ui.port, "port")
            end, true, nil, "port")
            row("Join Room", function()
                if validPort(ui) then
                    remember(ui, deps.native)
                    command("join", endpoint.format(ui.ip, ui.port))
                end
            end, ui.ip ~= "")
            row("Back", function()
                ui.page = "modes"
                ui.selection = 2
            end)
        elseif phase == Phase.lobby and ui.page == "rules" then
            ruleCount = selectedRules
            for _, definition in ipairs(deps.options or {}) do
                row(definition.name, function()
                    if rulesEditable then
                        command(
                            "room_options",
                            tostring((status.roomOptions or 0) ~ definition.flag)
                        )
                    end
                end, rulesEditable)
                rows[#rows].checked = ((status.roomOptions or 0) & definition.flag) ~= 0
            end
            row("Back", function()
                back(ui)
            end)
        elseif phase == Phase.lobby and ui.page == "challenges" and host then
            local ids = {}
            for id in pairs(challenges) do
                ids[#ids + 1] = tonumber(id)
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                local definition = challenges[tostring(id)]
                row(id .. " " .. definition.name, function()
                    if command("challenge", tostring(id)) then
                        ui.difficulty = definition.difficulty
                        ui.page, ui.selection = "lan", 3
                    end
                end, definition.team_available, nil, nil, deps.accent)
            end
            row("Back", function()
                back(ui)
            end)
            local preview = challenges[tostring(ids[ui.selection] or ids[1])]
            if preview and not preview.team_available then
                notice = "unavailable"
            end
        elseif phase == Phase.lobby then
            local choices = characterChoices
            local function cycle(delta)
                if #choices == 0 then
                    return
                end
                local index = 1
                for i, v in ipairs(choices) do
                    if v == choice then
                        index = i
                        break
                    end
                end
                command("choose", choices[(index - 1 + delta) % #choices + 1] .. ":0")
            end
            row(
                deps.character(choice),
                function()
                    cycle(1)
                end,
                not ready
                    and (not challenge or challenge.character == UNRESTRICTED_CHARACTER)
                    and #choices > 0,
                cycle
            )
            row(ready and "Cancel Ready" or "Ready", function()
                command("choose", choice .. (ready and ":0" or ":1"))
            end, ready or status["eligible" .. localSlot] == true)
            if host then
                local function changeMode(delta)
                    local nextMode = ((challenge and CHALLENGE_MODE or ui.difficulty) + delta)
                        % MODE_COUNT
                    if nextMode == CHALLENGE_MODE then
                        ui.page, ui.selection = "challenges", 1
                    elseif command("challenge", "0") then
                        ui.difficulty = nextMode
                    end
                end
                row(
                    challenge and ("Challenge: " .. challenge.id .. " " .. challenge.name)
                        or ({ "Normal", "Hard", "Greed", "Greedier" })[ui.difficulty + 1],
                    function()
                        if challenge then
                            ui.page, ui.selection = "challenges", 1
                        else
                            changeMode(1)
                        end
                    end,
                    true,
                    changeMode,
                    nil,
                    challenge and deps.accent
                )
                row(ui.seed == "" and "Seed: Random" or ui.seed, function()
                    ui.editing = "seed"
                    deps.native.menu_text_begin(ui.seed, "seed")
                end, true, nil, "seed")
                ruleEntry()
                local allReady = count >= 2
                for i = 0, count - 1 do
                    allReady = allReady
                        and status["ready" .. i] == 1
                        and status["eligible" .. i] == true
                end
                row("Start Game", function()
                    local settings = (ui.seed == "" and "RANDOM" or ui.seed)
                        .. ":"
                        .. (challenge and challenge.difficulty or ui.difficulty)
                    for i = 0, 3 do
                        settings = settings .. ":" .. (status["choice" .. i] or 0)
                    end
                    if command("start", settings) then
                        deps.hide()
                    end
                end, allReady)
                if not challenge and (status.savedPlayers or 0) >= 2 then
                    if (status.savedOptions or 0) ~= (status.roomOptions or 0) then
                        row("Load Previous Rules", function()
                            command("room_options", tostring(status.savedOptions or 0))
                        end, count == status.savedPlayers)
                    else
                        row("Resume Previous Session", function()
                            if command("resume") then
                                deps.hide()
                            end
                        end, allReady and count == status.savedPlayers)
                    end
                end
            end
            if not host and challenge then
                row(
                    "Challenge: " .. challenge.id .. " " .. challenge.name,
                    function() end,
                    false,
                    nil,
                    nil,
                    deps.accent
                )
            end
            if not host then
                ruleEntry()
            end
            row("Leave Room", function()
                command("close")
            end)
        elseif phase == Phase.running then
            if (status.pause or 0) == 0 then
                row("Pause for Everyone", function()
                    command("control", tostring(Command.pause))
                end)
            else
                row("Resume Game", function()
                    if command("control", tostring(Command.resume)) then
                        deps.hide()
                    end
                end, localSlot == status.pauseOwner)
            end
            row(challenge and "End Challenge (Do Not Save)" or "Save and End Multiplayer", function()
                command("control", tostring(Command.saveExit))
            end)
            row("Return to Game", function()
                deps.hide()
            end)
        else
            notice = phase == Phase.returning and "returning" or "waiting"
            if not status.prepared then
                row("Leave Room", function()
                    command("close")
                end)
            end
        end
        return rows, notice, ruleCount
    end
    return {
        rows = rows,
        validPort = validPort,
        remember = remember,
        idle = idle,
        back = back,
        compatibilityError = compatibilityError,
    }
end
