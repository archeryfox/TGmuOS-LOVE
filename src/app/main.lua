-- src/app/main.lua — точка входа LÖVE (FSD структура)
local ui = require("src.shared.ui.ui_kit")
local json = require("dkjson")
local telegram = require("src.shared.api.tdlib_client")
local auth_screen = require("src.features.auth.ui.auth_screen")
local messenger_screen = require("src.features.chat.ui.chat_screen")
local profile_screen = require("src.features.auth.ui.profile_screen")
local settings_screen = require("src.features.auth.ui.settings_screen")

local tg
local current
local screens
local fonts
local settings_scale = 1.0
local settings_open = false
local account_store = {active_key = "account_1", accounts = {}}
local pending_account_key
local library_path
local library_error
local api_id
local api_hash
local proxy
local transition_from
local transition_canvas
local transition_progress = 1
local transition_duration = 0.22

local function account_key_valid(key)
    return type(key) == "string" and key:match("^account_%d+$") ~= nil
end

local function find_account(key)
    for _, account in ipairs(account_store.accounts) do
        if account.key == key then return account end
    end
end

local function save_account_store()
    local encoded = json.encode(account_store)
    if not encoded then return false end
    return love.filesystem.write("accounts.json", encoded)
end

local function load_account_store()
    local contents = love.filesystem.read("accounts.json")
    if contents then
        local ok, stored = pcall(json.decode, contents)
        if ok and type(stored) == "table" then
            account_store.accounts = {}
            local accounts = type(stored.accounts) == "table" and stored.accounts or {}
            for _, account in ipairs(accounts) do
                if type(account) == "table" and account_key_valid(account.key) then
                    account_store.accounts[#account_store.accounts + 1] = {
                        key = account.key,
                        title = type(account.title) == "string" and account.title or "Аккаунт",
                        user_id = tonumber(account.user_id),
                        authorized = account.authorized == true,
                    }
                end
            end
            if account_key_valid(stored.active_key) then account_store.active_key = stored.active_key end
        end
    end
    if #account_store.accounts == 0 then
        account_store.accounts[1] = {key = "account_1", title = "Основной аккаунт", authorized = false}
    end
    if not find_account(account_store.active_key) then
        account_store.active_key = account_store.accounts[1].key
    end
    save_account_store()
end

local function next_account_key()
    local index = 1
    while find_account("account_" .. index) do index = index + 1 end
    local key = "account_" .. index
    account_store.accounts[#account_store.accounts + 1] = {
        key = key,
        title = "Новый аккаунт",
        authorized = false,
    }
    return key
end

local function transition_to(screen, enter)
    if screen == current then
        if enter and screen.enter then screen:enter() end
        return
    end
    transition_from = current
    transition_progress = 0
    current = screen
    if enter and current and current.enter then current:enter() end
end

local function start_account(key)
    account_store.active_key = key
    save_account_store()
    tg = telegram.new()
    tg.log_path = (arg and arg[1] or "") .. "/log.txt"
    local save_directory = love.filesystem.getSaveDirectory()
    if not library_path then
        tg.auth_error = "TDLib: " .. tostring(library_error)
    elseif not api_id then
        tg.auth_error = "Не заданы api_id/api_hash. Укажите TG_API_ID и TG_API_HASH или ~/.config/love_tg_native/telegram.conf"
    else
        local db_directory, files_directory
        if key == "account_1" then
            db_directory = save_directory .. "/tdlib"
            files_directory = save_directory .. "/tdlib_files"
        else
            local account_directory = "accounts/" .. key
            love.filesystem.createDirectory(account_directory)
            db_directory = save_directory .. "/" .. account_directory .. "/tdlib"
            files_directory = save_directory .. "/" .. account_directory .. "/tdlib_files"
        end
        tg:start({
            lib = library_path,
            db = db_directory,
            files = files_directory,
            log = save_directory .. "/tdlib_" .. key .. ".log",
            api_id = api_id,
            api_hash = api_hash,
            proxy = proxy,
        })
    end
    tg.on_me = function(user)
        local account = find_account(key)
        if not account then
            account = {key = key}
            account_store.accounts[#account_store.accounts + 1] = account
        end
        local name = ((user.first_name or "") .. " " .. (user.last_name or "")):gsub("^%s+", ""):gsub("%s+$", "")
        account.title = name ~= "" and name or user.username or ("Аккаунт " .. tostring(user.id))
        account.user_id = user.id
        account.authorized = true
        save_account_store()
    end
    tg.on_logged_out = function()
        local account = find_account(key)
        if account then
            account.authorized = false
            account.user_id = nil
            save_account_store()
        end
    end
    return tg
end

local function build_screens()
    screens = {
        auth = auth_screen.new(fonts, tg),
        messenger = messenger_screen.new(fonts, tg),
        profile = profile_screen.new(fonts, tg),
        settings = settings_screen.new(fonts, tg, {
            accounts = function() return account_store.accounts, account_store.active_key end,
            switch_account = function(key) pending_account_key = key end,
            add_account = function() pending_account_key = next_account_key() end,
        }),
    }
end

local function show_profile(chat_id, user_id)
    if not screens then return end
    local profile = screens.profile
    profile.chat_id = chat_id
    profile.user_id = user_id
    profile.is_me = false
    transition_to(profile, true)
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
        path = home .. "/.config/love_tg_native/telegram.conf"
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

function love.load()
    love.graphics.setBackgroundColor(ui.colors.bg)
    fonts = ui.load_fonts(settings_scale)

    library_path, library_error = extract_native("lib/libtdjson.so")
    api_id, api_hash, proxy = load_settings()
    load_account_store()
    start_account(account_store.active_key)
    build_screens()
    current = screens.auth
    current:enter()
end

function love.update(dt)
    if pending_account_key then
        local key = pending_account_key
        pending_account_key = nil
        if account_key_valid(key) and key ~= account_store.active_key then
            local old_tg = tg
            if old_tg then
                local stopped, reason = old_tg:shutdown()
                if not stopped then
                    old_tg.action_error = "Не удалось остановить TDLib для переключения: " .. tostring(reason)
                    return
                end
            end
            start_account(key)
            build_screens()
            transition_to(screens.auth, true)
            settings_open = false
            return
        end
    end

    if tg then tg:update(dt) end

    if tg.ready and current ~= screens.messenger and current ~= screens.profile and current ~= screens.settings then
        transition_to(screens.messenger, true)
    elseif not tg.ready and current ~= screens.auth then
        transition_to(screens.auth, true)
    end

    if settings_open then
        transition_to(screens.settings, true)
        settings_open = false
        screens.messenger.wants_settings = false
    end

    if transition_progress < 1 then
        transition_progress = math.min(1, transition_progress + dt / transition_duration)
        if transition_progress >= 1 then transition_from = nil end
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

    -- Reapply fonts if scale changed
    local current_scale = ui.get_scale()
    if current_scale ~= settings_scale then
        settings_scale = current_scale
        fonts = ui.load_fonts(settings_scale)
        for _, s in pairs(screens) do
            if s.fonts then s.fonts = fonts end
        end
    end
end

function love.draw()
    if not current or not current.draw then return end
    if transition_from and transition_progress < 1 then
        local width, height = love.graphics.getDimensions()
        if not transition_canvas or transition_canvas:getWidth() ~= width or transition_canvas:getHeight() ~= height then
            transition_canvas = love.graphics.newCanvas(width, height)
        end
        love.graphics.push("all")
        love.graphics.setCanvas(transition_canvas)
        love.graphics.clear(0, 0, 0, 0)
        if transition_from.draw then transition_from:draw() end
        love.graphics.setCanvas()
        love.graphics.pop()
    end

    current:draw()
    if transition_from and transition_progress < 1 then
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 1 - transition_progress)
        love.graphics.draw(transition_canvas, 0, 0)
        love.graphics.pop()
    end
end

function love.keypressed(key)
    if key == "escape" and tg and tg.sticker_set_viewer then
        if current and current.sticker_fullscreen_image then current.sticker_fullscreen_image = nil; return end
        tg.sticker_set_viewer = nil
        return
    end
    if key == "escape" and current == screens.auth then
        love.event.quit()
        return
    end
    if key == "escape" and current == screens.messenger and not tg.current_chat_id then
        love.event.quit()
        return
    end
    if key == "escape" and current == screens.settings then
        settings_open = false
        transition_to(screens.messenger, true)
        return
    end

    if key == "escape" and current == screens.profile then
        transition_to(screens.messenger, true)
        return
    end

    if key == "escape" and current == screens.messenger then
        local ms = screens.messenger
        ms.context_menu = nil
        ms.forward_mode = false
        ms.forward_from_chat_id = nil
        ms.edit_mode = false
        ms.edit_message = nil
        ms.edit_input = ""
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

function love.textinput(text)
    if current.textinput then current:textinput(text) end
end

function love.wheelmoved(x, y)
    if current.wheelmoved then current:wheelmoved(x, y) end
end

function love.gamepadpressed(joystick, button)
    if button == "start" and current == screens.messenger then
        local ms = screens.messenger
        if ms.keypressed then ms:keypressed("f1") end
    end
end

function love.mousepressed(x, y, button)
    if current.mousepressed then current:mousepressed(x, y, button) end
    if current == screens.messenger then
        local ms = screens.messenger
        if ms.wants_settings then
            ms.wants_settings = false
            settings_open = true
        elseif ms.wants_profile_user_id then
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
