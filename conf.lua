function love.conf(t)
    t.identity = "Telegram"
    t.version = "11.5"
    t.console = false

    t.window.title = "TGMUOS (LÖVE)"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.fullscreen = true
    t.window.vsync = 0
    t.window.msaa = 0
    t.window.highdpi = false

    t.modules.physics = false
    t.modules.video = false
    t.modules.audio = true
    t.modules.joystick = true
    t.modules.thread = true
end
