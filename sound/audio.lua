local wibox = require("wibox")
local naughty = require("naughty")
local audio_controller = require("utils.audio")
local inspect = require("inspect")

local Audio = {}

function Audio:update()
    self.volume = self.controller.volume
    self.index = self.controller.index
    self.muted = self.controller.muted
    self.ports = self.controller.ports
    self.active_port = self.controller.active_port
    --naughty.notify { title = "Audio", text = "Update: " .. inspect(self.volume) }
    self:settings()
end

function Audio:settings()
end

function Audio:new(o)
    local b = {}
    b.settings = o.settings
    b.widget = o.widget or wibox.widget {
        widget = wibox.container.background,
        {
            widget = wibox.widget.textbox,
            id = "text"
        }
    }

    b.controller = audio_controller()
    b.volume = b.controller.volume
    b.muted = b.controller.muted
    b.index = b.controller.index
    b.ports = b.controller.ports
    b.active_port = b.controller.active_port

    self.__index = self
    setmetatable(b, self)

    b.controller:connect_signal("update", function()
        b:update()
    end)

    return b
end

return Audio
-- vim: shiftwidth=4: tabstop=4
