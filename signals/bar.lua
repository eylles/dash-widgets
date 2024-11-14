local awful = require("awful")

local currentPath = debug.getinfo(1, "S").source:sub(2):match("(.*/)")

local bar_daemon = currentPath .. "awesome-dynabar"

local pid = awful.spawn(bar_daemon, false)

awesome.connect_signal("exit",
    function()
        awful.spawn.with_shell(string.format("kill %s", pid), false)
    end
)

