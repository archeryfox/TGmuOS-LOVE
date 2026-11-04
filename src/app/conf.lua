-- src/app/conf.lua — конфигурация LÖVE (FSD)
function love.conf(t)
    t.identity = "love_tg_native"
    t.version = "11.5"
    t.console = false

    t.window.title = "Telegram (LÖVE / TDLib)"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.fullscreen = false
    t.window.vsync = 0
    t.window.msaa = 0
    t.window.highdpi = false

    t.modules.audio = true
    t.modules.physics = false
    t.modules.video = false
    t.modules.joystick = true
    t.modules.thread = true
    t.modules.image = true
    t.modules.font = true
    t.modules.http = false
end
