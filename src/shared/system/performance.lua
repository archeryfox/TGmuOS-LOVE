local performance = {}

local MODES = {
    eco = {fps = 30, smooth = 8},
    performance = {fps = 60, smooth = 20},
}

local current = "performance"
local vsync = true
local last_frame = nil

local function normalize(mode)
    if MODES[mode] then return mode end
    return "performance"
end

function performance.get_mode()
    return current
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

function performance.toggle()
    return performance.set_mode(current == "performance" and "eco" or "performance", true)
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
