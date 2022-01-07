# Sound widget slider

This is a slider widget that provides a pulse device control for the default source or sink.
The backend uses pactl exclusively wiht the intention it is also compatible with pipewire.

the wdiget used called slider_drag is an (at the time) open Pull Request on the awesome wm github
repo https://github.com/awesomeWM/awesome/pull/3533, however this repo targets the stable release
of awesome (awesome v4.3) fortunately the slider from the master branch and more important the one
from the PR is compatible with v4.3 without any issue, so for the time being i'm just providing the
base widget on this repo straight from the PR, as soon as awesome v4.4 is out i'm changing this to
the proper widget.

Mind you this widget still ain't on it's final form, still need to implement a check for the default
sink/source so the widget can know to use the icons for sinks/sources on external cards when one of
those is the default (ie when the default sink is on a bluetooth device change the icon to external)

# configuration

## config options

| Variable        | Description                                                        | Type         | Default Value |
| ---             | ---                                                                | ------       | ------        |
| `col_mute`      | color of the bar and handle when mute                              | string (hex) | "#ff0000"     |
| `col_fg`        | the active color of the slider and border of the handle            | string (hex) | "#00ffff"     |
| `col_bg`[1]     | the background color of the bar,                                   | string (hex) | "#006666"     |
| `col_handle`[2] | the color of the handle when not mute                              | string (hex) | "#ffffff"     |
| `bar_height`    | the height of the slider bar                                       | integer      | 5             |
| `device_type`   | the type of pulse device to control (sink or source)               | string       | "sink"        |
| `icon_img`      | table that contains the height, internal and external icon (paths) | table        | nil           |

[1] note: if you don't set col_bg then a darker shade of col_fg will be calculated

[2] note: if you don't set col_handle then a lighter shade of col_fg will be calculated

## config examples

<img src="../sliders.png">

to set up like the ones from the screenshot do like this into your rc.lua (or the sub .lua where you
define your dashboard wibox)

```lua
-- define this before your dashboard wibox

-- volume
local sound = require("dash-widgets.sound")
-- i'm using icons from a local theme which is just recolored papirus

local speakerimg = {
    internal = os.getenv("HOME") .. "/.icons/pywal/symbolic/devices/audio-speakers-symbolic.svg",
    external = os.getenv("HOME") .. "/.icons/pywal/symbolic/devices/audio-headphones-symbolic.svg",
    height = 22,
}
local speaker_widget = sound.new({bar_height = 5, col_mute = "#454345", col_fg = "#697EC2", icon_paths = speakerimg})

local micimg = {
    internal = os.getenv("HOME") .. "/.icons/pywal/symbolic/devices/audio-input-microphone-symbolic.svg",
    external = os.getenv("HOME") .. "/.icons/pywal/symbolic/devices/audio-input-microphone-symbolic.svg",
    height = 22,
}
local mic_widget = sound.new({bar_height = 5, col_mute = "#454345", col_fg = "#697EC2", device_type = "source", icon_paths = micimg})

-- sum configs here

globalkeys = gears.table.join(
-- sum bindings here

    awful.key({ }, "XF86AudioRaiseVolume", function() speaker_widget:set_volume("+", 5) end),
    awful.key({ }, "XF86AudioLowerVolume", function() speaker_widget:set_volume("-", 5) end),
    awful.key({ }, "XF86AudioMute",        function() speaker_widget:toggle_mute() end),
    -- fallbacks if media keys not physically present
    awful.key({ modkey }, "F7", function() speaker_widget:set_volume("+", 5) end, {description = "Raise Audio Volume", group = "volume"}),
    awful.key({ modkey }, "F6", function() speaker_widget:set_volume("-", 5) end, {description = "Lower Audio Volume", group = "volume"}),
    awful.key({ modkey }, "F5", function() speaker_widget:toggle_mute() end, {description = "Mute Audio", group = "volume"}),

    awful.key({ "Shift" }, "XF86AudioRaiseVolume", function() mic_widget:set_volume("+", 5) end),
    awful.key({ "Shift" }, "XF86AudioLowerVolume", function() mic_widget:set_volume("-", 5) end),
    awful.key({ }, "XF86AudioMicMute",     function() mic_widget:toggle_mute() end),
    -- fallbacks if media keys not physically present
    awful.key({ modkey, "Shift" }, "F7", function() mic_widget:set_volume("+", 5) end, {description = "Raise Microphone Volume", group = "volume"}),
    awful.key({ modkey, "Shift" }, "F6", function() mic_widget:set_volume("-", 5) end, {description = "Lower Microphone Volume", group = "volume"}),
    awful.key({ modkey }, "F8", function() mic_widget:toggle_mute() end, {description = "Mute Microphone", group = "volume"}),

-- sum bindings here
)
```

# License

having used and contributed some PRs to https://github.com/gobolinux/gobo-awesome-sound ideas from
there stuck with me and quite an amount of the internals of this widget were taken from or heavily
inspired by it as such i'm licensing this widget under the same license, even tho the repo as a
whole is under the gpl v2 license, the code of the widget is covered under the terms of the MIT
license.
