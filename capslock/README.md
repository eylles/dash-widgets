# A capslock widget for awesome

This is a capslock widget that provides an indicator for the state of the capslock key.

The widget is clickable and will toggle the caps lock state when you click on it.

# requirements

This depends on xset to read the capslock status with the leds signal and on xdotool to toggle the
casplock status on click.

# Usage

``` lua
-- capslock widget
local capslock = require("dash-widgets.capslock")
-- you can configure the displayed text for activated and deactivated
-- with pango markup
capslock.activated = "<b>A</b>"
capslock.deactivated = "a"
-- the width of the textbox is configurable too
capslock.forced_width = 30


-- LEDS signal from awesome-leds
require("dash-widgets.signals.leds")

-- you can add the widget to your statusbar like this
s.mywibox:setup {
    layout = wibox.layout.align.horizontal,
    { -- Left widgets
        layout = wibox.layout.fixed.horizontal,
        mylauncher,
        s.mytaglist,
        s.mypromptbox,
    },
    s.mytasklist, -- Middle widget
    { -- Right widgets
        layout = wibox.layout.fixed.horizontal,
        mykeyboardlayout,
        capslock
        wibox.widget.systray(),
        mytextclock,
        s.mylayoutbox,
    },
}
```

# Notes

This widget was made as a replacement to [awesome-capslock_widget](https://github.com/stefano-m/awesome-capslock_widget)
