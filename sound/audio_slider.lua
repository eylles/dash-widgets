local wibox = require("wibox")
local slider_widget = require("dash-widgets.base-widget.slider_drag")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi
local audio_utils = require("base-utils.audio")

local audio_controller = audio_utils {}

local Audio_slider = {
    mt = {}
}

-- from the theme.lua file
local function mix(color1, color2, ratio)
    local hex_color_match = "[a-fA-F0-9][a-fA-F0-9]"
    local ratio = ratio or 0.5
    local result = "#"
    local channels1 = color1:gmatch(hex_color_match)
    local channels2 = color2:gmatch(hex_color_match)
    for _ = 1,3 do
        local bg_numeric_value = math.ceil(
            tonumber("0x"..channels1())*ratio +
            tonumber("0x"..channels2())*(1-ratio)
        )
        if bg_numeric_value < 0 then bg_numeric_value = 0 end
        if bg_numeric_value > 255 then bg_numeric_value = 255 end
        result = result .. string.format("%02x", bg_numeric_value)
    end
    return result
end

function Audio_slider:new(o)
    local col_mute = o and o.col_mute or "#ff0000"
    local col_fg = o and o.col_fg or "#00ffff"
    local col_handle = mix(col_fg, "#ffffff", 0.4)
    local handle_vars = { o.col_handle }
    for _, var in pairs(handle_vars) do
        col_handle = var
    end
    local col_fg_darker = mix(col_fg, "#000000", 0.4)
    local col_bg = o and o.col_bg or col_fg_darker or "#006666"

    local slider = wibox.widget {
        bar_shape = gears.shape.rectangle,
        bar_height = dpi(4),
        background_color = col_bg,
        bar_color = col_bg,
        bar_active_color = col_fg,
        handle_shape = gears.shape.circle,
        handle_width = dpi(10),
        handle_color = col_handle,
        handle_border_color = col_fg,
        handle_border_width = dpi(2),
        value = audio_controller.volume.left or 0,
        forced_width = dpi(80),
        forced_height = dpi(15),
        minimum = 0,
        maximum = 100,
        widget = slider_widget,
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
            bg = col_bg,
            border_width = dpi(1),
            border_color = col_fg,
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
