local sound = {}

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local slider = require("dash-widgets.base-widget.slider_drag")
local mouse = mouse
local mousegrabber = mousegrabber
local naughty = require("naughty")

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

function sound.new(options)
    local col_mute = options and options.col_mute or "#ff0000"
    local col_fg = options and options.col_fg or "#00ffff"
    local col_handle = mix(col_fg, "#ffffff", 0.4)
    local handle_vars = { options.col_handle }
    for _, var in pairs(handle_vars) do
        col_handle = var
    end
    local col_fg_darker = mix(col_fg, "#000000", 0.4)
    local col_bg = options and options.col_bg or col_fg_darker or "#006666"
    local bar_height = options and options.bar_height or 5
    local device_type = options and options.device_type or "sink"
    local icon_img = options and options.icon_paths or {}
    local MUTED = "no"
    local vol_val = 0
    local is_dragging = false
    local default_device = ""

    local pulse_device = {}
    if device_type == "sink" then
        pulse_device = { "sink", "SINK" }
    elseif device_type == "source" then
        pulse_device = { "source", "SOURCE" }
    end

    local signal_name = string.format("volume::%s", device_type)

    local get_default_device = string.format("pactl get-default-%s", pulse_device[1])

    local get_vol_cmd  = string.format("pactl get-%s-volume @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local get_mute_cmd = string.format("pactl get-%s-mute   @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local set_vol_cmd  = string.format("pactl set-%s-volume @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local set_mute_cmd = string.format("pactl set-%s-mute   @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local update_cmd = get_vol_cmd .. " ; " .. get_mute_cmd

    -- the slider itself
    local vol_slide = wibox.widget {
        max_value = 100,
        value = 0,
        background_color = col_bg,
        bar_color = col_bg,
        bar_shape = gears.shape.rounded_bar,
        bar_height = bar_height,
        bar_active_color = col_fg,
        handle_color = col_handle,
        handle_border_color = col_fg,
        handle_border_width = 1,
        handle_shape = gears.shape.circle,
        handle_width = bar_height * 2.5,
        widget = slider,
    }

    -- icon widget
    local icon = wibox.widget {
        {
            image = icon_img.internal,
            forced_height = icon_img.height,
            halign = "center",
            valign = "center",
            widget = wibox.widget.imagebox
        },
        widget = wibox.container.place
    }

    -- callback that emits a signal
    local function update_callback_signal(stdout)
        local volume = vol_val
        local mute = MUTED
        if not is_dragging then
            for line in stdout:gmatch("[^\n]+") do
                local k, v = line:match("^%s*([^:]*): (.*)")
                -- if k == "Name" then
                if k == "Volume" then
                    local percent = v:match("front.-([0-9]*)%%")
                    volume = tonumber(percent) or 0
                elseif k == "Mute" then
                    if v == "yes" then
                        mute = v
                    elseif v == "no" then
                        mute = v
                    end
                -- elseif k == "Active Port" then
                end
            end
            if (volume ~= vol_val) or (mute ~= MUTED) then
                awesome.emit_signal(signal_name, volume, mute)
                vol_val = volume
                MUTED = mute
            end
        end
    end

    local function volume_info(cmd)
        awful.spawn.easy_async_with_shell(
            'LANG=C ' .. get_default_device,
            function(stdout)
                for line in stdout:gmatch("[^\n]+") do
                    if default_device ~= line then
                        default_device = line
                    end
                end
            end
        )
        awful.spawn.easy_async_with_shell(
            'LANG=C ' .. cmd,
            function(stdout)
                update_callback_signal(stdout)
            end
        )
    end

    --- first update
    volume_info(update_cmd)

    local vol_daemon = string.format([[bash -c "LANG=C pactl subscribe 2> /dev/null | grep --line-buffered \"Event 'change' on %s #\""]], pulse_device[1])

    awful.spawn.with_line_callback(
        vol_daemon,
        {
            stdout = function(line)
                volume_info(update_cmd)
            end
        }
    )

    awesome.connect_signal("exit",
        function()
            awful.spawn.with_shell("pkill --full 'pactl subscribe'")
        end
    )

    local widget = wibox.widget {
        { icon, right = 5, widget = wibox.container.margin },
        vol_slide,
        forced_height = icon_img.height,
        layout = wibox.layout.align.horizontal,
    }

    vol_slide:connect_signal("drag_start",
        function()
            is_dragging = true
        end
    )

    vol_slide:connect_signal("drag",
        function()
            awful.spawn.with_shell(set_vol_cmd .. vol_slide.value .. '%')
        end
    )

    vol_slide:connect_signal("drag_end",
        function()
            awful.spawn.easy_async_with_shell(
                'LANG=C sleep 4 && echo',
                function(stdout)
                    is_dragging = false
                end
            )
        end
    )
    awesome.connect_signal(signal_name,
        function(volume, mute)
            vol_slide.value = volume
            if mute == "no" then
                vol_slide.bar_color = col_bg
                vol_slide.bar_active_color = col_fg
                vol_slide.handle_color = col_handle
            elseif mute == "yes" then
                vol_slide.bar_color = col_mute
                vol_slide.bar_active_color = col_mute
                vol_slide.handle_color = col_mute
            end
        end
    )

    widget.set_volume = function(self, operation, value)
        is_dragging = true
        local volume = vol_slide.value
        if operation == "+" then
            volume = math.min(volume + value, 100)
        elseif operation == "-" then
            volume = math.max(0, volume - value)
        end
        vol_slide.value = volume
        awful.spawn.with_shell(set_vol_cmd .. volume .. '%')
        awful.spawn.easy_async_with_shell(
            'LANG=C sleep 2 && echo',
            function(stdout)
                is_dragging = false
            end
        )
    end

    vol_slide:buttons(awful.util.table.join(
        awful.button({  }, 4, function() widget:set_volume("+", 5) end),
        awful.button({  }, 5, function() widget:set_volume("-", 5) end)
    ))

    widget.toggle_mute = function(self)
        local setting = MUTED
        if setting == "yes" then
            setting = "no"
        elseif setting == "no" then
            setting = "yes"
        end
        awful.spawn.with_shell(set_mute_cmd .. setting)
    end

    icon:buttons(awful.util.table.join(
        awful.button({  }, 1, function() widget:toggle_mute() end)
    ))

    return widget
end

return sound
