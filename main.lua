-- main.lua — точка входа LÖVE для Telegram (полная копия love_tg_native с адаптацией)
local ui = require("src.shared.ui.ui_kit")
local json = require("dkjson")
local telegram = require("src.shared.api.tdlib_client")
local auth_screen = require("src.features.auth.ui.auth_screen")
local messenger_screen = require("src.features.chat.ui.chat_screen")
local profile_screen = require("src.features.auth.ui.profile_screen")
local settings_screen = require("src.features.auth.ui.settings_screen")
local controls_screen = require("src.features.help.ui.controls_screen")
local tg_process = require("src.shared.system.tg_process")
local performance = require("src.shared.system.performance")

local tg
local current
local screens
local fonts
local settings_scale = 1.0
local settings_open = false
local controls_return = nil

local handle_key

local function read_first_line(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local value = handle:read("*l")
    handle:close()
    return value and value:gsub("%s+$", "")
end

local function detect_abxy_layout()
    local mode = os.getenv("TG_ABXY")
    if mode == "modern" or mode == "retro" then return mode end
    local con = read_first_line("/tmp/con_go")
    if con == "modern" or con == "retro" then return con end
    local swap = read_first_line("/opt/muos/config/settings/advanced/swap")
    if swap == "1" then return "modern" end
    if swap == "0" then return "retro" end
    return "modern"
end

local ABXY_LAYOUT = "modern"
local SELECT_BUTTON, BACK_BUTTON
local DIRECTION_KEYS = {up = true, down = true, left = true, right = true}
local GAMEPAD_KEYS = {}

local function rebuild_gamepad_keys()
    local retro = ABXY_LAYOUT == "retro"
    SELECT_BUTTON = retro and "b" or "a"
    BACK_BUTTON = retro and "a" or "b"
    GAMEPAD_KEYS = {
        dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
        b = retro and "return" or "escape",
        a = retro and "escape" or "return",
        x = retro and "y" or "x",
        y = retro and "x" or "y",
        leftshoulder = "pageup", rightshoulder = "pagedown",
        lefttrigger = "l2", righttrigger = "r2",
        start = "f1", back = "tab", guide = "escape",
    }
end
rebuild_gamepad_keys()

local function load_saved_abxy()
    local env = os.getenv("TG_ABXY")
    if env == "modern" or env == "retro" then return env end
    local ok, data = pcall(love.filesystem.read, "controls.conf")
    if ok and data then
        local saved = data:match("abxy%s*=%s*([%w_]+)")
        if saved == "modern" or saved == "retro" then return saved end
    end
    return detect_abxy_layout()
end

local function toggle_abxy()
    ABXY_LAYOUT = ABXY_LAYOUT == "retro" and "modern" or "retro"
    rebuild_gamepad_keys()
    pcall(love.filesystem.write, "controls.conf", "abxy=" .. ABXY_LAYOUT .. "\n")
end
local dir_state = {up = false, down = false, left = false, right = false}
local gamepad_held = {}
local trigger_held = {triggerleft = false, triggerright = false}
local last_dir_source = {}
local repeat_timer = 0
local REPEAT_DELAY = 0.35
local REPEAT_RATE = 0.09

local function should_dispatch_dir(key, source)
    local now = love.timer.getTime()
    local last = last_dir_source[key]
    if last and last.source ~= source and (now - last.time) < 0.06 then
        return false
    end
    last_dir_source[key] = {source = source, time = now}
    return true
end

local function emergency_close()
    tg_process.kill_all()
    love.event.quit()
end

local function show_profile(chat_id, user_id)
    if not screens then return end
    if screens.messenger and screens.messenger.keyboard then
        screens.messenger.keyboard.visible = false
    end
    local profile = screens.profile
    profile.chat_id = chat_id
    profile.user_id = user_id
    profile.is_me = false
    current = profile
    profile:enter()
end

local function parse_conf(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local values = {}
    for line in handle:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key then values[key] = value end
    end
    handle:close()
    return values
end

local function load_settings()
    local path = os.getenv("TG_CONFIG")
    if not path or path == "" then
        local home = os.getenv("HOME") or ""
        path = home .. "/.config/Telegram/telegram.conf"
        local legacy = home .. "/.config/tgmuos_love/telegram.conf"
        local handle = io.open(path, "r")
        if handle then
            handle:close()
        else
            local legacy_handle = io.open(legacy, "r")
            if legacy_handle then
                legacy_handle:close()
                path = legacy
            end
        end
    end
    local config = parse_conf(path) or {}

    local api_id = tonumber(os.getenv("TG_API_ID") or config.api_id)
    local api_hash = os.getenv("TG_API_HASH") or config.api_hash
    if not api_id or not api_hash or api_hash == "" then
        return nil, nil, nil
    end

    local proxy_type = os.getenv("TG_PROXY_TYPE") or config.proxy_type
    local proxy = nil
    if proxy_type and proxy_type ~= "" then
        local port = tonumber(os.getenv("TG_PROXY_PORT") or config.proxy_port)
        local server = os.getenv("TG_PROXY_SERVER") or config.proxy_server
        if port and server and server ~= "" then
            proxy = {
                type = proxy_type,
                server = server,
                port = port,
                username = os.getenv("TG_PROXY_USER") or config.proxy_user or "",
                password = os.getenv("TG_PROXY_PASSWORD") or config.proxy_password or "",
                secret = os.getenv("TG_PROXY_SECRET") or config.proxy_secret or "",
                path = os.getenv("TG_PROXY_PATH") or config.proxy_path or "",
            }
        end
    end

    return api_id, api_hash, proxy
end

local function extract_native(relative_path)
    local info = love.filesystem.getInfo(relative_path)
    if not info then return nil, "не найден " .. relative_path end
    local data = love.filesystem.read(relative_path)
    if not data then return nil, "не удалось прочитать " .. relative_path end
    love.filesystem.createDirectory("native")
    local filename = relative_path:match("([^/]+)$")
    local destination = "native/" .. filename
    local existing = love.filesystem.getInfo(destination)
    if not existing or existing.size ~= #data then
        local ok, error_message = love.filesystem.write(destination, data)
        if not ok then
            return nil, tostring(error_message)
        end
    end
    return love.filesystem.getSaveDirectory() .. "/" .. destination
end

local logged_messages = {}
local logged_count = 0
local logged_max = 1000
local function app_log(kind, message)
    if not message or message == "" then return end
    local key = kind .. ":" .. tostring(message)
    if logged_messages[key] then return end
    logged_messages[key] = true
    logged_count = logged_count + 1
    if logged_count > logged_max then
        -- Удаляем ~10% старейших записей чтобы не расти бесконечно
        local n = 0
        for k in pairs(logged_messages) do
            logged_messages[k] = nil
            n = n + 1
            if n >= math.ceil(logged_max * 0.1) then break end
        end
        logged_count = 0
        for _ in pairs(logged_messages) do logged_count = logged_count + 1 end
        logged_messages[key] = true
        logged_count = logged_count + 1
    end
    local ok, source = pcall(love.filesystem.getSource)
    if not ok or type(source) ~= "string" then return end
    local handle = io.open(source:gsub("/+$", "") .. "/log.txt", "a")
    if not handle then return end
    handle:write(os.date("[%Y-%m-%d %H:%M:%S] "), kind, ": ", tostring(message), "\n")
    handle:close()
end

local function start_account()
    tg = telegram.new()
    local library, library_error = extract_native("lib/libtdjson.so")
    local api_id, api_hash, proxy = load_settings()
    if not library then
        tg.auth_error = "TDLib: " .. tostring(library_error)
    elseif not api_id then
        tg.auth_error = "Не заданы api_id/api_hash. Укажите TG_API_ID и TG_API_HASH или ~/.config/Telegram/telegram.conf"
    else
        local save_directory = love.filesystem.getSaveDirectory()
        tg:start({
            lib = library,
            db = save_directory .. "/tdlib",
            files = save_directory .. "/tdlib_files",
            log = save_directory .. "/tdlib.log",
            api_id = api_id,
            api_hash = api_hash,
            proxy = proxy,
        })
    end
    tg.on_me = function(user)
        -- User info received
    end
    tg.on_logged_out = function()
        -- Handle logout
    end
    return tg
end

function love.load()
    love.graphics.setBackgroundColor(ui.colors.bg)
    performance.load()
    ABXY_LAYOUT = load_saved_abxy()
    rebuild_gamepad_keys()
    fonts = ui.load_fonts(settings_scale)
    love.mouse.setVisible(true)
    love.mouse.setRelativeMode(false)

    start_account()

    screens = {
        auth = auth_screen.new(fonts, tg),
        messenger = messenger_screen.new(fonts, tg),
        profile = profile_screen.new(fonts, tg),
        settings = settings_screen.new(fonts, tg, {
            abxy_layout = function() return ABXY_LAYOUT end,
            toggle_abxy = toggle_abxy,
            restart_vpn = function(callback)
                os.execute('pkill -9 sing-box 2>/dev/null')
                -- Reset TDLib proxy state so it re-confirms with the new sing-box instance
                if tg then
                    tg.proxy_confirmed = false
                    tg.proxy_ready = false
                    if tg.options and tg.options.proxy then
                        tg:add_proxy(tg.options.proxy)
                    end
                end
                os.execute('ulimit -n 65536; nohup /mnt/mmc/MUOS/application/muvpn_love/libexec/sing-box run -c /root/.config/muvpn/sing-box.json >/dev/null 2>&1 &')
                if callback then callback() end
            end,
        }),
        controls = controls_screen.new(fonts, tg),
    }
    current = screens.auth
    current:enter()
end

function love.update(dt)
    if tg then
        tg:update(dt)
        if tg.auth_error and tg.auth_error ~= "" then
            app_log("auth", tg.auth_error)
        end
        if tg.action_error and tg.action_error ~= "" then
            app_log("action", tg.action_error)
        end
    end

    if tg.ready and current ~= screens.messenger and current ~= screens.profile
        and current ~= screens.settings and current ~= screens.controls then
        current = screens.messenger
        current:enter()
    elseif not tg.ready and current ~= screens.auth and current ~= screens.controls then
        current = screens.auth
        current:enter()
    end

    if settings_open then
        current = screens.settings
        settings_open = false
        current:enter()
        screens.messenger.wants_settings = false
    end

    if current.update then current:update(dt) end

    if current == screens.messenger then
        local ms = screens.messenger
        if ms.wants_profile_user_id then
            local user_id = ms.wants_profile_user_id
            ms.wants_profile_user_id = nil
            show_profile(tg.current_chat_id, user_id)
        elseif ms.wants_profile_chat_id then
            local chat_id = ms.wants_profile_chat_id
            ms.wants_profile_chat_id = nil
            show_profile(chat_id)
        end
    end

    local current_scale = ui.get_scale()
    if current_scale ~= settings_scale then
        settings_scale = current_scale
        fonts = ui.load_fonts(settings_scale)
    love.mouse.setVisible(true)
    love.mouse.setRelativeMode(false)
        for _, s in pairs(screens) do
            if s.fonts then s.fonts = fonts end
        end
    end

    local held_dir = nil
    for _, direction in ipairs({"up", "down", "left", "right"}) do
        if dir_state[direction] then held_dir = direction break end
    end
    if held_dir then
        repeat_timer = repeat_timer - dt
        if repeat_timer <= 0 then
            repeat_timer = REPEAT_RATE
            handle_key(held_dir, true)
        end
    else
        repeat_timer = REPEAT_DELAY
    end

    performance.limit_frame()
end

local function open_controls()
    if not screens or current == screens.controls then return end
    controls_return = current
    current = screens.controls
    current:enter()
end

local function close_controls()
    if current ~= screens.controls then return end
    current = controls_return or screens.messenger
    controls_return = nil
    if current and current.enter then current:enter() end
end

function love.draw()
    if current and current.draw then current:draw() end
    -- Global mouse cursor icon
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", mx, my, mx + 12, my + 4, mx + 4, my + 12)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.polygon("line", mx, my, mx + 12, my + 4, mx + 4, my + 12)
end

handle_key = function(key, from_gamepad)
    if key == "tab" then
        if current == screens.messenger and current.keyboard then
            if current.keyboard.visible then
                current.keyboard.visible = false
                return
            elseif tg.current_chat_id or current.search_active or current.edit_mode then
                current.context_menu = nil
                current.keyboard.visible = true
                return
            end
        end
        if current == screens.controls then close_controls() else open_controls() end
        return
    end
    if key == "f1" and current == screens.messenger and current.keyboard
        and current.keyboard.visible then
        current:keypressed("return")
        return
    end
    if current == screens.controls and (key == "escape" or key == "return" or key == "kpenter") then
        close_controls()
        return
    end
    if key == "escape" and current == screens.auth then
        if from_gamepad then return end
        love.event.quit()
        return
    end
    if key == "escape" and current == screens.messenger and not tg.current_chat_id then
        if from_gamepad then return end
        love.event.quit()
        return
    end
    if key == "escape" and current == screens.settings then
        settings_open = false
        current = screens.messenger
        current:enter()
        return
    end

    if key == "escape" and current == screens.profile then
        current = screens.messenger
        current:enter()
        return
    end

    if key == "escape" and current == screens.messenger then
        local ms = screens.messenger
        if ms.context_menu or ms.forward_mode or ms.edit_mode or ms.fullscreen_media
            or ms.player_controls or tg.sticker_set_viewer or ms.search_active then
            ms.context_menu = nil
            ms.forward_mode = false
            ms.forward_from_chat_id = nil
            ms.edit_mode = false
            ms.edit_message = nil
            ms.edit_input = ""
            ms.fullscreen_media = nil
            ms.player_controls = nil
            ms.fullscreen_zoom = 1
            ms.fullscreen_pan_x = 0
            ms.fullscreen_pan_y = 0
            tg.sticker_set_viewer = nil
            if ms.search_active then
                ms.search_active = false
                ms:set_search_query("", false)
            end
            if ms.keyboard then ms.keyboard.visible = false end
            return
        end
        if next(ms.selected_messages) then
            ms.selected_messages = {}
            return
        end
    end

    if key == "f1" and current == screens.messenger then
        settings_open = true
        return
    end

    if key == "p" and current == screens.messenger then
        local chat_id, _, user_id = screens.messenger:get_profile_target()
        if chat_id then
            show_profile(chat_id, user_id)
        end
        return
    end

    if (key == "v" and love.keyboard.isDown("lctrl", "rctrl")) and current.textinput then
        current:textinput(love.system.getClipboardText())
        return
    end

    if current.keypressed then current:keypressed(key) end

    if current == screens.messenger and screens.messenger.wants_settings then
        screens.messenger.wants_settings = false
        settings_open = true
    end
end

function love.keypressed(key)
    if DIRECTION_KEYS[key] then
        if not should_dispatch_dir(key, "keyboard") then return end
        dir_state[key] = true
        repeat_timer = REPEAT_DELAY
    end
    handle_key(key, false)
end

function love.keyreleased(key)
    if DIRECTION_KEYS[key] then dir_state[key] = false end
    if current.keyreleased then current:keyreleased(key) end
end

function love.gamepadpressed(_, button)
    gamepad_held[button] = true

    if gamepad_held.leftshoulder and gamepad_held.rightshoulder and gamepad_held.start then
        emergency_close()
        return
    end

    if current == screens.messenger and button == SELECT_BUTTON and gamepad_held.back then
        local chat_id, _, user_id = screens.messenger:get_profile_target()
        if chat_id then show_profile(chat_id, user_id) end
        return
    end

    if button == BACK_BUTTON and current == screens.auth and current.model
        and current.model.is_password_mode and current.model:is_password_mode() then
        handle_key("backspace", true)
        return
    end

    if button == BACK_BUTTON and current == screens.messenger and current.keyboard
        and current.keyboard.visible then
        handle_key("backspace", true)
        return
    end

    if button == "start" and current == screens.messenger and current.keyboard
        and current.keyboard.visible then
        handle_key("return", true)
        return
    end

    local key = GAMEPAD_KEYS[button]
    if not key then return end
    if DIRECTION_KEYS[key] then
        if not should_dispatch_dir(key, "gamepad") then return end
        dir_state[key] = true
        repeat_timer = REPEAT_DELAY
    end
    handle_key(key, true)
end

function love.gamepadreleased(_, button)
    gamepad_held[button] = nil
    local key = GAMEPAD_KEYS[button]
    if key and DIRECTION_KEYS[key] then dir_state[key] = false end
end

function love.gamepadaxis(_, axis, value)
    if axis ~= "triggerleft" and axis ~= "triggerright" then return end
    local key = axis == "triggerleft" and "l2" or "r2"
    if value > 0.5 then
        if not trigger_held[axis] then
            trigger_held[axis] = true
            handle_key(key, true)
        end
    elseif value < 0.35 then
        trigger_held[axis] = false
        if current.keyreleased then current:keyreleased(key) end
    end
end

function love.textinput(text)
    if current.textinput then current:textinput(text) end
end

function love.wheelmoved(x, y)
    if current.wheelmoved then current:wheelmoved(x, y) end
end

function love.mousepressed(x, y, button)
    if current.mousepressed then current:mousepressed(x, y, button) end
    if current == screens.messenger then
        local ms = screens.messenger
        if ms.wants_profile_user_id then
            local user_id = ms.wants_profile_user_id
            ms.wants_profile_user_id = nil
            show_profile(tg.current_chat_id, user_id)
        elseif ms.wants_profile_chat_id then
            local chat_id = ms.wants_profile_chat_id
            ms.wants_profile_chat_id = nil
            show_profile(chat_id)
        end
    end
end

function love.quit()
    if tg then tg:shutdown() end
    return false
end

function love.conf(t)
    t.identity = "Telegram"
    t.version = "11.5"
    t.console = false

    t.window.title = "TGMUOS (LÖVE)"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.fullscreen = true
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.highdpi = false

    t.modules.physics = false
    t.modules.video = false
    t.modules.audio = true
    t.modules.joystick = true
    t.modules.thread = true
    t.modules.image = true
    t.modules.font = true
end

-- Custom error handler that allows quitting on error
function love.errorhandler(msg)
    msg = tostring(msg)
    app_log("fatal", msg)
    
    -- Load error font
    local error_font = love.graphics.newFont(16)
    local small_font = love.graphics.newFont(12)
    
    local function draw_error()
        love.graphics.setBackgroundColor(0.1, 0.1, 0.12)
        love.graphics.clear()
        
        local w, h = love.graphics.getDimensions()
        
        -- Title
        love.graphics.setFont(error_font)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf("ОШИБКА ПРИЛОЖЕНИЯ", 0, 40, w, "center")
        
        -- Error message
        love.graphics.setFont(small_font)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(msg, 20, 100, w - 40, "left")
        
        -- Instructions
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.printf("MENU / B / ESC — Выйти из приложения", 0, h - 40, w, "center")
        love.graphics.printf("HOME / SELECT — Перезагрузить", 0, h - 20, w, "center")
    end
    
    local function handle_input()
        -- Check for quit keys
        if love.keyboard.isDown("escape") or love.keyboard.isDown("guide") or love.keyboard.isDown("b") then
            return true  -- quit
        end
        -- Check for restart keys
        if love.keyboard.isDown("home") or love.keyboard.isDown("back") then
            love.event.quit("restart")
            return true
        end
        return false
    end
    
    -- Main error loop
    love.graphics.reset()
    love.event.pump()
    
    while true do
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "keypressed" then
                if a == "escape" or a == "guide" or a == "b" then
                    return  -- quit
                elseif a == "home" or a == "back" then
                    love.event.quit("restart")
                    return
                end
            end
        end
        
        draw_error()
        love.graphics.present()
        love.timer.sleep(0.016)
    end
end