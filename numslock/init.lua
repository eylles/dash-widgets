local awesome = awesome
local awful = require("awful")
local wibox = require("wibox")

local numslock = wibox.widget {
  widget = wibox.widget.textbox,
  align = "center",
  valign = "center",
  forced_width = 15,
}

numslock:buttons(
    awful.util.table.join(
        awful.button({}, 1, function()
            awful.spawn.with_shell("xdotool key Num_Lock")
        end)
    )
)

numslock.activated = "<b><span foreground="darkgray">9</span></b>"
numslock.deactivated = "<b><span foreground="white">9</span></b>"

local tooltip = awful.tooltip({})

tooltip:add_to_object(numslock)

function numslock:check(c)
    local status = c
    tooltip.text = "Nums Lock " .. status
    if status == "on" then
        self.markup = self.activated
    else
        self.markup = self.deactivated
    end
end

numslock:check("off")

awesome.connect_signal("leds::numslock", function(s)
    numslock:check(s)
end)

return numslock
