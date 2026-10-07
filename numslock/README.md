# A numslock widget for awesome

This is a numslock widget that provides an indicator for the state of the numslock key.

The widget is clickable and will toggle the nums lock state when you click on it.

# requirements

This depends on xset to read the nusmlock status with the leds signal and on xdotool to toggle the
nusmlock status on click.

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
but currently follows the capslock widget from this very repo.
