local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local inspect = require("inspect")

local Audio = {
    mt = {}
}

function Audio:watch()
    local comm = [[bash -c "LANG= pactl subscribe"]]
    local pid = awful.spawn.with_line_callback(comm, {
            stdout = function(line)
                if string.match(line, "sink #(%d+)") ~= nil then -- Should match a sink number
                    --naughty.notify { title = "Audio", text = line }
                    self:update()
                end
            end,
            stderr = function(line)
                naughty.notify { title = "Audio error", text = line }
            end,
        })
    if type(pid) == "number" then
        awesome.connect_signal("exit", function()
            awesome.kill(pid, awesome.unix_signal.SIGKILL)
        end)
    elseif type(pid) == "string" then
        naughty.notify { title = "Audio error", text = pid }
    end
end

local running = false
function Audio:update()
    local comm = [[bash -c "LANG= pactl list sinks | sed -n -e 's/^[ \t]*//p'"]]
    awful.spawn.easy_async(comm, function(stdout)
        if running == true then
            return
        end
        running = true

        local first_sink_pos = string.find(stdout, "Sink #(%S+)")
        local sink_pos = 1
        while sink_pos ~= nil do
            local state = string.match(stdout, "State: (%S+)", sink_pos) or "SUSPEND"
            if state == "RUNNING" then
                break
            end
            sink_pos = string.find(stdout, "Sink #(%d+)", sink_pos + 1)
        end
        if sink_pos == nil and first_sink_pos == nil then
            running = false
            naughty.notify {
                title = "Audio error",
                text = "Couldn't find any running sink"
            }
            return
        elseif sink_pos == nil and first_sink_pos ~= nil then
            sink_pos = first_sink_pos
        end

        local next_sink_pos = string.find(stdout, "Sink #(%d+)", sink_pos + 1)
        if next_sink_pos ~= nil then
            stdout = string.sub(stdout, sink_pos, next_sink_pos)
        else
            stdout = string.sub(stdout, sink_pos)
        end

        local muted = string.match(stdout, "Mute: (%S+)") or "N/A"
        local index = string.match(stdout, "Sink #(%d+)") or "N/A"
        local name = string.match(stdout, "Name: (%S+)") or "N/A"

        local channels = {}
        local i = 1
        for v in string.gmatch(stdout, ":.-(%d+)%%") do
            channels[i] = tonumber(v)
            i = i + 1
        end

        local ports_index = string.find(stdout, "Ports:\n")
        local active_p_index = string.find(stdout, "Active Port:")
        local ports_str = string.sub(stdout, ports_index, active_p_index - 1)

        local active_port_str = string.match(stdout, "Active Port: (%S+)") or "N/A"
        local active_port = 1
        local ports = {}

        i = 1
        for v in string.gmatch(ports_str, "([^\n]*)\n?") do
            if v ~= "Ports:" then
                for n, d, t, p, a in string.gmatch(v,
                    "(%S+): (%w+) %(type: (%w+), priority: (%d+), ([%w%s]*)%)"
                ) do
                    ports[i] = {
                        name = n, desc = d,
                        type = t, priority = p,
                        availability = a
                    }
                    if active_port_str == n then active_port = i end
                end
                i = i + 1
            end
        end

        --naughty.notify { title = "Audio ports", text = inspect(ports), timeout = 0 }

        self.muted = muted == "yes"
        self.index = tonumber(index) or 0
        self.name = name
        self.ports = ports
        self.active_port = active_port
        self.volume.left = channels[1] or nil
        self.volume.right = channels[2] or nil
        self:emit_signal("update")
        running = false
    end)
end

function Audio:set(left, right)
    if running == true then return end
    right = right or left

    if left > 100 then left = 100
    elseif left < 0 then left = 0 end
    if right > 100 then right = 100
    elseif right < 0 then right = 0 end

    local comm = string.format([[pactl set-sink-volume %s %d%% %d%%]],
        self.name, left, right)
    awful.spawn.easy_async(comm, function() end)
end

function Audio:inc(left, right)
    right = right or left
    self:set(self.volume.left + left, self.volume.right + right)
end

function Audio:dec(left, right)
    right = right or left
    self:set(self.volume.left - left, self.volume.right - right)
end

function Audio:mute(value)
    local mute = "toggle"
    if value == true then
        mute = "true"
    elseif value == false then
        mute = "false"
    end

    local comm = string.format([[pactl set-sink-mute %s %s]],
        self.name, mute)
    awful.spawn.easy_async(comm, function() end)
end

function Audio:new()
    if Audio._instance then
        return Audio._instance
    end

    local gobj = gears.object {}
    gears.table.crush(gobj, Audio, true)

    self.__index = self
    setmetatable(gobj, self)

    gobj.index = 0
    gobj.muted = false
    gobj.name = ""
    gobj.volume = { left = 0, right = 0 }

    gobj:update()
    gobj:watch()

    Audio._instance = gobj
    return gobj
end

function Audio.mt:__call()
    return Audio:new()
end

return setmetatable(Audio, Audio.mt)

-- vim: tabstop=4: shiftwidth=4
