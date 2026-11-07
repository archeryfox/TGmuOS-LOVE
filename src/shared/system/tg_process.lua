-- src/shared/system/tg_process.lua — остановка всех процессов Telegram на устройстве
local tg_process = {}

local FALLBACK_DIR = "/mnt/mmc/MUOS/application/Telegram"

local function app_dir()
    local ok, source = pcall(love.filesystem.getSource)
    if ok and type(source) == "string" and source ~= "" then
        return source:gsub("/+$", "")
    end
    return FALLBACK_DIR
end

function tg_process.kill_all()
    local script = app_dir() .. "/tools/tgkill.sh"
    local command = string.format(
        "setsid sh %q >/dev/null 2>&1 &", script)
    local ok, result = pcall(os.execute, command)
    if not ok then
        return false, tostring(result)
    end
    return true
end

return tg_process
