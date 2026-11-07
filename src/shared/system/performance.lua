local performance = {}

local MODES = {
    minimum = {fps = 20, smooth = 4},
    balance = {fps = 30, smooth = 8},
    performance = {fps = 45, smooth = 12},
    maximum = {fps = 60, smooth = 20},
}

local current = "balance"
local compress_level = 5
local vsync = true
local last_frame = nil

local function normalize(mode)
    if MODES[mode] then return mode end
    return "performance"
end

function performance.get_mode()
    return current
end

function performance.get_compress_level()
    return compress_level
end
function performance.set_compress_level(v)
    v = tonumber(v) or 5
    if v < 1 then v = 1 end
    if v > 10 then v = 10 end
    compress_level = v
    return compress_level
end

function performance.get_fps()
    return MODES[current].fps
end

function performance.smooth_speed()
    return MODES[current].smooth
end

function performance.set_mode(mode, persist)
    current = normalize(mode)
    last_frame = nil
    if persist then performance.save() end
    return current
end

local ORDER = {"minimum","balance","performance","maximum"}
function performance.toggle()
    local idx = 1
    for i,m in ipairs(ORDER) do if m == current then idx = i end end
    idx = idx % #ORDER + 1
    return performance.set_mode(ORDER[idx], true)
end

function performance.get_vsync()
    return vsync
end

function performance.set_vsync(enabled, persist)
    vsync = enabled == true
    if love and love.window and love.window.setVSync then
        pcall(love.window.setVSync, vsync and 1 or 0)
    end
    last_frame = nil
    if persist then performance.save() end
    return vsync
end

function performance.toggle_vsync()
    return performance.set_vsync(not vsync, true)
end

function performance.load()
    local mode = os.getenv("TG_PERF_MODE")
    local saved_vsync = nil
    local ok, data = pcall(love.filesystem.read, "display.conf")
    if ok and data then
        saved_vsync = data:match("vsync%s*=%s*([01])")
        if not mode or mode == "" then
            mode = data:match("mode%s*=%s*([%w_]+)")
        end
    end
    performance.set_mode(mode or "performance", false)
    performance.set_vsync(saved_vsync == nil or saved_vsync == "1", false)
end

function performance.save()
    pcall(love.filesystem.write, "display.conf",
        "mode=" .. current .. "\nvsync=" .. (vsync and "1" or "0") .. "\n")
end

function performance.limit_frame()
    local now = love.timer.getTime()
    if last_frame then
        local target = 1 / MODES[current].fps
        local elapsed = now - last_frame
        if elapsed < target then
            love.timer.sleep(target - elapsed)
        end
    end
    last_frame = love.timer.getTime()
end

return performance
