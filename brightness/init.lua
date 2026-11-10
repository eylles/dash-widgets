local brightness = {}

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

function brightness.new(options)
    local col_fg = options and options.col_fg or "#00ffff"
    local col_handle = mix(col_fg, "#ffffff", 0.4)
    local handle_vars = { options.col_handle }
    for _, var in pairs(handle_vars) do
        col_handle = var
    end
    local col_fg_darker = mix(col_fg, "#000000", 0.4)
    local col_bg = options and options.col_bg or col_fg_darker or "#006666"
    local bar_height = options and options.bar_height or 5
    local bar_shape  = options and options.bar_shape or gears.shape.rounded_bar
    local icon_img = options and options.icon_paths or {}

    local is_dragging = false

    local signal_volume = "brightness::level"
    local set_vol_cmd  = "blight s"

    -- the slider itself
    local vol_slide = wibox.widget {
        max_value = 100,
        value = 0,
        background_color = col_bg,
        bar_color = col_bg,
        bar_shape = bar_shape,
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

    local drag_state_end = gears.timer({
            timeout = 2,
            single_shot = true,
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
            end
        end
    )

    vol_slide:connect_signal("drag_start",
        function()
            is_dragging = true
        end
    )

    vol_slide:connect_signal("drag_end",
        function()
            if drag_state_end.started then
                drag_state_end:again()
            else
                drag_state_end:start()
            end
        end
    )

    awesome.connect_signal(signal_volume,
        function(volume)
            volume = tonumber(volume) or 0
            local widget_volue = vol_slide:get_value()
            if volume ~= widget_volue then
                vol_slide:set_value(volume)
            end
            volume = nil
            collectgarbage("collect")
        end)

    volume_widget.set_volume = function (self, operation, value)
        is_dragging = true
        local volume = vol_slide:get_value()
        if operation == "+" then
            volume = math.min(volume + value, 100)
        elseif operation == "-" then
            volume = math.max(0, volume - value)
        end
        vol_slide:set_value(volume)
        volume = nil
        collectgarbage("collect")
    end

    vol_slide:buttons(awful.util.table.join(
        awful.button({  }, 4, function() volume_widget:set_volume("+", 1) end),
        awful.button({  }, 5, function() volume_widget:set_volume("-", 1) end)
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
            collectgarbage("collect")
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
            collectgarbage("collect")
        end
    end)

    return volume_widget
end

return brightness
