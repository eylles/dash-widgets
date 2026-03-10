local awesome = awesome
local awful = require("awful")
local wibox = require("wibox")

local capslock = wibox.widget {
  widget = wibox.widget.textbox,
  align = "center",
  valign = "center",
  forced_width = 15,
}

capslock.activated = "<b>A</b>"
capslock.deactivated = "<b>a</b>"

local tooltip = awful.tooltip({})

tooltip:add_to_object(capslock)

function capslock:check(c)
    local status = c
    tooltip.text = "Caps Lock " .. status
    if status == "on" then
        self.markup = self.activated
    else
        self.markup = self.deactivated
    end
end

capslock:check("off")

awesome.connect_signal("leds::capslock", function(s)
    capslock:check(s)
end)

return capslock
