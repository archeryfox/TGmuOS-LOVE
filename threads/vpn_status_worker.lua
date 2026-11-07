local json = require("dkjson")
local timer = require("love.timer")
local in_channel = love.thread.getChannel("vpn_status_in")
local out_channel = love.thread.getChannel("vpn_status_out")
local init = in_channel:demand()

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run(action, argument)
    local command = "MUVPN_CONFIG_DIR=" .. shell_quote(init.config_dir)
        .. " " .. shell_quote(init.python)
        .. " " .. shell_quote(init.script)
        .. " " .. shell_quote(action)
    if argument then
        command = command .. " " .. shell_quote(argument)
    end
    command = command .. " 2>/dev/null"

    local pipe = io.popen(command, "r")
    if not pipe then return nil, false end
    local output = pipe:read("*a")
    local ok = pipe:close()
    return output, ok
end

local function decode(action)
    local output, command_ok = run(action)
    if not command_ok then return nil end
    local decoded, value = pcall(json.decode, output or "")
    if decoded and type(value) == "table" then return value end
    return nil
end

local function send_snapshot(operation, action_ok, message)
    local status = decode("health") or {
        connected = false,
        unavailable = true,
    }
    local server_data = decode("servers") or {servers = {}}
    out_channel:push({
        kind = "snapshot",
        status = status,
        servers = server_data.servers or {},
        selected = server_data.selected,
        operation = operation,
        action_ok = action_ok,
        message = message,
    })
end

local function handle(command)
    if command == "probe" or command == "list" then
        send_snapshot(command, true)
        return
    end

    local action, argument = command:match("^([%w_]+):([%w]+)$")
    if action then
        if action ~= "apply" or (argument ~= "auto"
            and (#argument ~= 16 or not argument:match("^[0-9a-f]+$"))) then
            send_snapshot(command, false, "Некорректный выбор сервера")
            return
        end
    else
        action = command
        if action ~= "start" and action ~= "stop" then
            send_snapshot(command, false, "Неизвестная команда")
            return
        end
    end

    local _, ok = run(action, argument)
    send_snapshot(command, ok == true,
        ok and "Операция выполнена" or "Не удалось выполнить операцию VPN")
end

while true do
    local command = in_channel:pop()
    if command == "quit" then break end
    if type(command) == "string" then
        handle(command)
    end
    timer.sleep(0.05)
end
