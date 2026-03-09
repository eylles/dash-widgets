local awful = require("awful")

local currentPath = debug.getinfo(1, "S").source:sub(2):match("(.*/)")

local leds_daemon = currentPath .. "awesome-leds"

local pid = awful.spawn(leds_daemon, false)

awesome.connect_signal("exit",
    function()
        awful.spawn.with_shell(string.format("kill %s", pid), false)
    end
)
