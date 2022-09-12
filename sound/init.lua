local sound = {}

local naughty = require("naughty")
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local slider = require("dash-widgets.base-widget.slider_drag")
local mouse = mouse
local mousegrabber = mousegrabber

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

    local CURRENT_ICO = ""
    local MUTED = ""
    local is_dragging = false
    local DEFAULT_DEVICE = ""
    local DEVICE_PORT = ""

    local pulse_device = {}
    if device_type == "sink" then
        pulse_device = { "sink", "SINK", "Sink" }
    elseif device_type == "source" then
        pulse_device = { "source", "SOURCE", "Source" }
    end

    local signal_name = string.format("volume::%s", device_type)
    local get_default_device = string.format("pactl info")
    local match_default_device = string.format("Default %s", pulse_device[3])
    local set_vol_cmd  = string.format("pactl set-%s-volume @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local set_mute_cmd = string.format("pactl set-%s-mute   @DEFAULT_%s@ ", pulse_device[1], pulse_device[2])
    local update_cmd = string.format("pactl list %ss", pulse_device[1])

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
    local icon_widget = wibox.widget {
        {
            id = "icon",
            image = icon_img.internal,
            forced_height = icon_img.height,
            halign = "center",
            valign = "center",
            widget = wibox.widget.imagebox
        },
        widget = wibox.container.place
    }

    local volume_widget = wibox.widget {
        {
            icon_widget,
            right = 5, widget = wibox.container.margin
        },
        vol_slide,
        forced_height = icon_img.height,
        layout = wibox.layout.align.horizontal,
    }

    -- callback that emits a signal
    local function update_callback_signal(stdout)
        local volume = vol_slide:get_value()
        local mute = MUTED
        local active_port = DEVICE_PORT
        local active = false
        local line = nil
        -- naughty.notify({ text = signal_name .. ": " .. tostring(is_dragging) })
        if not is_dragging then
            for line in stdout:gmatch("[^\n]+") do
                local k, v = line:match("^%s*([^:]*): (.*)")
                if k == "Name" then
                    if v == DEFAULT_DEVICE then
                        active = true
                    else
                        active = false
                    end
                end
                if active then
                    if k == "Volume" then
                        local percent = v:match("front.-([0-9]*)%%")
                        volume = tonumber(percent) or 0
                    elseif k == "Mute" then
                            mute = v
                    elseif k == "Active Port" then
                        active_port = v
                    end
                end
            end
            line = nil
            -- if (volume ~= vol_val) or (mute ~= MUTED) or (active_port ~= DEVICE_PORT) then
                awesome.emit_signal(signal_name, volume, mute, active_port)
                -- vol_val = volume
                -- MUTED = mute
                -- DEVICE_PORT = active_port
            -- end
        end
    end

    local function volume_info(cmd)
        awful.spawn.easy_async_with_shell(
            'LANG=C ' .. get_default_device,
            function(stdout)
                local line = nil
                for line in stdout:gmatch("[^\n]+") do
                    local k, v = line:match("^%s*([^:]*): (.*)")
                    if k == match_default_device then DEFAULT_DEVICE = v end
                end
                line = nil
                awful.spawn.easy_async_with_shell(
                    'LANG=C ' .. cmd,
                    function(stdout)
                        update_callback_signal(stdout)
                    end
                )
            end
        )
    end

    --- update
    -- gears.timer({
    --         timeout = 2,
    --         autostart = true,
    --         callback = function()
    --             volume_info(update_cmd)
    --         end
    --     })

    --- first update
    volume_info(update_cmd)

    local vol_daemon = string.format([[dash -c "LANG=C pactl --client-name=awesome-%s subscribe 2> /dev/null | grep --line-buffered \"Event 'change' on %s #\""]], pulse_device[1], pulse_device[1])

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
            awful.spawn(string.format("pkill --full 'pactl --client-name=awesome-%s subscribe'", pulse_device[1]), false)
        end
    )

    local drag_state_end = gears.timer({
            timeout = 2,
            -- autostart = true,
            callback = function()
                is_dragging = false
            end
        })

    vol_slide:connect_signal("property::value",
        function()
            if is_dragging then
            local volume_level = vol_slide:get_value()
            awful.spawn(set_vol_cmd .. volume_level .. "%", false)
            if drag_state_end.started then
                drag_state_end:again()
            else
                drag_state_end:start()
            end
            -- is_dragging = false
            -- vol_slide:emit_signal("drag_end")
            end
        end
    )

    vol_slide:connect_signal("drag_start",
        function()
            is_dragging = true
        end
    )

    -- vol_slide:connect_signal("drag",
    --     function()
    --         awful.spawn.with_shell(set_vol_cmd .. vol_slide.value .. '%')
    --     end
    -- )

    -- vol_slide:connect_signal("button::press",
    --     function()
    --         if not is_dragging then
    --             awful.spawn.with_shell(set_vol_cmd .. vol_slide.value .. '%')
    --         end
    --     end
    -- )

    vol_slide:connect_signal("drag_end",
        function()
            if drag_state_end.started then
                drag_state_end:again()
            else
                drag_state_end:start()
            end
    --         -- awful.spawn.easy_async_with_shell(
    --         --     'LANG=C sleep 0.8 && echo',
    --         --     function(stdout)
                    -- is_dragging = false
    --             -- end
    --         -- )
        end
    )

    awesome.connect_signal(signal_name,
        function(volume, mute, active_port)
            if vol_slide:get_value() ~= volume then
            vol_slide:set_value(volume)
            end
            if mute == "no" then
                vol_slide:set_bar_color(col_bg)
                vol_slide:set_bar_active_color(col_fg)
                vol_slide:set_handle_color(col_handle)
            elseif mute == "yes" then
                vol_slide:set_bar_color(col_mute)
                vol_slide:set_bar_active_color(col_mute)
                vol_slide:set_handle_color(col_mute)
            end
            if MUTED ~= mute then
                MUTED = mute
            end
            if CURRENT_ICO ~= active_port then
                CURRENT_ICO = active_port
            if active_port:find("internal") or active_port:find("analog") then
                icon_widget.icon:set_image(icon_img.internal)
            else
                icon_widget.icon:set_image(icon_img.external)
            end
            end
            volume = nil
            mute = nil
            active_port = nil
        end
    )

    volume_widget.set_volume = function(self, operation, value)
        vol_slide:emit_signal("drag_start")
        local volume = vol_slide:get_value()
        if operation == "+" then
            volume = math.min(volume + value, 100)
        elseif operation == "-" then
            volume = math.max(0, volume - value)
        end
        vol_slide:set_value(volume)
        -- awful.spawn.with_shell(set_vol_cmd .. volume .. '%')
        -- awful.spawn.easy_async_with_shell(
        --     'LANG=C sleep 0.8 && echo',
            -- function(stdout)
                -- is_dragging = false
                -- volume = nil
            -- end
        -- )
    end

    vol_slide:buttons(awful.util.table.join(
        awful.button({  }, 4, function() volume_widget:set_volume("+", 5) end),
        awful.button({  }, 5, function() volume_widget:set_volume("-", 5) end)
    ))

    -- Hover thingy
    vol_slide:connect_signal("mouse::enter", function(c)
        local wb = mouse.current_wibox
        old_cursor, old_wibox = wb.cursor, wb
        wb.cursor = "hand1"
    end)

    vol_slide:connect_signal("mouse::leave", function(c)
        if old_wibox then
            old_wibox.cursor = old_cursor
            old_wibox = nil
        end
    end)

    icon_widget:connect_signal("mouse::enter", function(c)
        local wb = mouse.current_wibox
        old_cursor, old_wibox = wb.cursor, wb
        wb.cursor = "hand1"
    end)

    icon_widget:connect_signal("mouse::leave", function(c)
        if old_wibox then
            old_wibox.cursor = old_cursor
            old_wibox = nil
        end
    end)

    volume_widget.toggle_mute = function(self)
        local setting = MUTED
        if setting == "yes" then
            setting = "no"
        elseif setting == "no" then
            setting = "yes"
        end
        MUTED = setting
        awful.spawn.with_shell(set_mute_cmd .. setting)
    end

    icon_widget:buttons(awful.util.table.join(
        awful.button({  }, 1, function() volume_widget:toggle_mute() end)
    ))

    return volume_widget
end

return sound
