local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi
local utils = require("utils")

local audio_controller = utils.audio {}

local Audio_slider = {
    mt = {}
}

function Audio_slider:new(o)
    local slider = wibox.widget {
        bar_shape = gears.shape.rectangle,
        bar_height = dpi(4),
        bar_color = beautiful.colors.bg1,
        bar_active_color = beautiful.colors.light_purple,
        handle_shape = gears.shape.circle,
        handle_width = dpi(10),
        handle_color = beautiful.colors.light_purple,
        value = audio_controller.volume.left or 0,
        forced_width = dpi(80),
        forced_height = dpi(15),
        minimum = 0,
        maximum = 100,
        widget = wibox.widget.slider,
    }
    slider:connect_signal("property::value", function(_, value)
        audio_controller:set(value)
    end)
    audio_controller:connect_signal("update", function()
        slider.value = audio_controller.volume.left
    end)

    local popup = awful.popup {
        widget = {
            widget = wibox.container.background,
            bg = beautiful.colors.bg,
            border_width = dpi(1),
            border_color = beautiful.colors.bg1,
            {
                slider,
                margins = dpi(5),
                widget = wibox.container.margin,
            }
        },
        bg = "#00000000",
        type = "popup_menu",
        ontop = true,
        visible = false,
        width = dpi(35),
        height = dpi(35),
    }

    o.parent:connect_signal("button::press", function()
        if not popup.visible then
            awful.placement.next_to(popup, {
                    preferred_anchors = "middle",
                    mode = "cursor",
                })
        end
        popup.visible = not popup.visible
    end)
end

return Audio_slider

-- vim: shiftwidth=4: tabstop=4
