local root = assert(arg[1])
local factory = dofile(root .. "/src/bridge/diagnostics/feedback.lua")
local submissions, pending, accept = {}, nil, true
local feedback = factory({
    submit = function(description, mods, context)
        submissions[#submissions + 1] = { description, mods, context }
        if accept then
            return true, "Uploading…"
        end
        return false, "A previous feedback upload is still in progress"
    end,
    poll = function()
        local result = pending
        pending = nil
        if result then
            return table.unpack(result)
        end
    end,
    mods = function()
        return { "EID", "Stats+" }
    end,
    context = function()
        return "phase=running\nslot=1"
    end,
})
local replies = {}
local function sink(name)
    return function(message)
        replies[#replies + 1] = { name, message }
    end
end

-- Nothing is consumed before a request, and the sink sees only its own result.
feedback.poll()
assert(feedback.submit("The game is stuck", sink("chat")) == "Uploading…")
assert(submissions[1][1] == "The game is stuck" and submissions[1][2] == "EID\nStats+")
assert(submissions[1][3] == "phase=running\nslot=1")
feedback.poll()
assert(#replies == 0, "A running upload produced a reply")
pending = { true, "Feedback submitted. ID: 261021-K7Q3" }
feedback.poll()
feedback.poll()
assert(#replies == 1 and replies[1][1] == "chat" and replies[1][2]:find("261021-K7Q3", 1, true))

-- A rejected request keeps no sink; a later result is not delivered to it.
accept = false
assert(feedback.submit("又The game is stuck", sink("console")) == "A previous feedback upload is still in progress")
pending = { false, "stale" }
feedback.poll()
assert(#replies == 1 and pending ~= nil, "A rejected request consumed a result")
pending = nil

-- Failures reach the sink like successes.
accept = true
feedback.submit("Third test submission", sink("console"))
pending = { false, "Could not connect to the feedback server" }
feedback.poll()
assert(replies[2][1] == "console" and replies[2][2] == "Could not connect to the feedback server")
print("PASS feedback submit, poll and result routing")
