# A numslock widget for awesome

This is a numslock widget that provides an indicator for the state of the numslock key.

# requirements

This depends on xset

# Usage

``` lua
-- numslock widget
local numslock = require("dash-widgets.numslock")
-- you can configure the displayed text for activated and deactivated
-- with pango markup
numslock.activated = "<b>9</b>"
numslock.deactivated = "<span foreground="purple">9</span>"
-- the width of the textbox is configurable too
numslock.forced_width = 30


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
        numslock
        wibox.widget.systray(),
        mytextclock,
        s.mylayoutbox,
    },
}
```

# Notes

This widget inspired by [awesome-capslock_widget](https://github.com/stefano-m/awesome-capslock_widget)
