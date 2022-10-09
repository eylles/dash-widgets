local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi

local audio_controller = require("utils.audio"):new {}

local Audio_popup = {
    mt = {}
}

function Audio_popup:show()
    if not self.can_show then
        return
    end
    self.popup.visible = true

    self.timer:again()
end

function Audio_popup:new()
    if Audio_popup._instance then
        return Audio_popup._instance
    end

    local progress_bar = wibox.widget {
        widget = wibox.widget.progressbar,
        max_value = 100,
        min_value = 0,
        value = audio_controller.volume.left or 0,
        forced_width = dpi(100),
        forced_height = dpi(10),
        shape = gears.shape.rounded_rect,

        color = beautiful.colors.light_purple,
        background_color = beautiful.colors.bg2,
    }

    local icon_text = wibox.widget {
        widget = wibox.widget.textbox,
        align = "center",
        font = "MesloLGS NF Bold 64",
        markup = " 墳 ",
    }

    local audio_text = wibox.widget {
        widget = wibox.widget.textbox,
        font = "MesloLGS NF Bold 12",
        align = "center",
    }

    local popup = awful.popup {
        widget = {
            widget = wibox.container.background,
            bg = beautiful.colors.bg1 .. "aa",
            forced_width = dpi(220),
            {
                widget = wibox.container.margin,
                margins = dpi(20),
                {
                    layout = wibox.layout.fixed.vertical,
                    spacing = dpi(10),
                    icon_text,
                    audio_text,
                    progress_bar,
                }
            }
        },
        screen = screen.primary,
        bg = "#00000000",
        type = "notification",
        ontop = true,
        visible = false,
        shape = gears.shape.rounded_rect,
        placement = awful.placement.centered,
        input_passthrough = true,
    }

    local gobj = gears.object {}
    gears.table.crush(gobj, Audio_popup, true)

    gobj.popup = popup
    gobj.can_show = false
    gobj.timer = gears.timer {
        timeout = 2,
        call_now = false,
        autostart = false,
        single_shot = true,
        callback = function()
            gobj.popup.visible = false
        end
    }

    self.__index = self
    setmetatable(gobj, self)

    audio_controller:connect_signal("update", function()
        audio_text.markup = " Audio: " .. audio_controller.volume.left .. " "
        progress_bar.value = audio_controller.volume.left

        if audio_controller.ports[audio_controller.active_port].type == "Headphones" then
            if audio_controller.muted then icon_text.markup = " ﳌ "
            else icon_text.markup = "  " end
        else
            if audio_controller.muted then icon_text.markup = " 婢 "
            else icon_text.markup = " 墳 " end
        end

        --gobj:show()
    end)

    gears.timer {
        timeout = 5,
        call_now = false,
        autostart = true,
        single_shot = true,
        callback = function()
            gobj.can_show = true
        end
    }

    Audio_popup._instance = gobj

    return gobj
end


function Audio_popup.mt:__call()
    return Audio_popup:new()
end

return setmetatable(Audio_popup, Audio_popup.mt)

-- vim: shiftwidth=4: tabstop=4
