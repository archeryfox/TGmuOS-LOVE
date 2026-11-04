-- Decode Telegram animations and videos into PNG frames.
-- Runs in a love.thread so ffmpeg does not block the UI.
local json = require("dkjson")

local in_channel = love.thread.getChannel("anim_in")
local out_channel = love.thread.getChannel("anim_out")

local MAX_FRAMES = 180
local MAX_EDGE = 360
local MAX_FPS = 60
local MIN_FPS = 30
local MAX_DURATION = 60
local MAX_TGS_FILE_BYTES = 1024 * 1024

local function sh_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function file_size(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local size = handle:seek("end")
    handle:close()
    return size
end

local function run(command)
    local ok, why, code = os.execute(command)
    if ok == true or ok == 0 then
        return true
    end
    return false, tostring(why or code or ok)
end

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end
    local data = handle:read("*a")
    handle:close()
    return data
end

local function file_exists(path)
    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end

local function which(bin)
    local handle = io.popen("command -v " .. bin .. " 2>/dev/null")
    if not handle then
        return nil
    end
    local path = handle:read("*l")
    handle:close()
    if path and path ~= "" then
        return path
    end
    return nil
end

local ffmpeg = which("ffmpeg")
local ffprobe = which("ffprobe")
local lottie_converter = os.getenv("LOTTIE_CONVERTER")
    or which("lottie_convert.py")
    or which("lottie_convert")
local home = os.getenv("HOME")
if not lottie_converter and home and home ~= "" then
    local user_converter = home .. "/.local/bin/lottie_convert.py"
    if file_exists(user_converter) then lottie_converter = user_converter end
end
local clean_env = "env -u LD_LIBRARY_PATH "

local function probe(path)
    if not ffprobe then
        return nil
    end
    local tmp = os.tmpname()
    local command = string.format(
        "%s%s -v error -select_streams v:0 -show_entries stream=width,height,duration:format=duration -of json %s > %s 2>/dev/null",
        clean_env,
        sh_quote(ffprobe),
        sh_quote(path),
        sh_quote(tmp)
    )
    local ok = run(command)
    local raw = read_file(tmp)
    os.remove(tmp)
    if not ok or not raw or raw == "" then
        return nil
    end
    local decoded_ok, meta = pcall(json.decode, raw)
    if not decoded_ok or type(meta) ~= "table" then
        return nil
    end
    local stream = meta.streams and meta.streams[1] or {}
    local format = meta.format or {}
    return tonumber(stream.width), tonumber(stream.height), tonumber(stream.duration) or tonumber(format.duration)
end

local function plan(width, height, duration, min_fps)
    if not duration or duration <= 0 then
        duration = 2
    end
    if duration > MAX_DURATION then
        duration = MAX_DURATION
    end
    local fps = math.min(MAX_FPS, math.max(min_fps or MIN_FPS, MAX_FRAMES / duration))
    local count = math.max(1, math.min(MAX_FRAMES, math.floor(duration * fps + 0.5)))
    local frame_dt = 1 / fps
    local target_w, target_h = width, height
    if not target_w or not target_h or target_w < 2 or target_h < 2 then
        return count, frame_dt, MAX_EDGE, nil
    end
    local edge = math.max(target_w, target_h)
    if edge > MAX_EDGE then
        local scale = MAX_EDGE / edge
        target_w = math.max(2, math.floor(target_w * scale + 0.5))
        target_h = math.max(2, math.floor(target_h * scale + 0.5))
    end
    return count, frame_dt, target_w, target_h
end

local function collect_paths(out_dir, count)
    local paths = {}
    for index = 1, count do
        local path = string.format("%s/f_%03d.png", out_dir, index)
        local handle = io.open(path, "rb")
        if not handle then
            break
        end
        handle:close()
        paths[#paths + 1] = path
    end
    return paths
end

local function extract_audio(path, out_dir, duration, channels)
    local candidate = out_dir .. "/audio.wav"
    local limit = duration and math.max(1, math.min(900, tonumber(duration) or 900)) or 12
    local command = string.format(
        "%s%s -y -v error -threads 2 -i %s -map 0:a:0 -vn -t %.3f -c:a pcm_s16le -ar 44100 -ac %d %s > %s 2>&1",
        clean_env,
        sh_quote(ffmpeg),
        sh_quote(path),
        limit,
        channels or 2,
        sh_quote(candidate),
        sh_quote(out_dir .. "/audio.log")
    )
    if run(command) and file_exists(candidate) then
        return candidate
    end
    return nil
end

local function decode_audio_job(job)
    if not ffmpeg then
        return {ok = false, kind = job.kind, file_id = job.file_id, audio_error = "ffmpeg not found"}
    end
    local made = run("mkdir -p " .. sh_quote(job.out_dir))
    if not made then
        return {ok = false, kind = job.kind, file_id = job.file_id, audio_error = "cannot create audio directory"}
    end
    local duration = job.duration or (job.kind == "voice" and 300 or job.kind == "audio" and 900 or nil)
    local audio_path = extract_audio(job.path, job.out_dir, duration, job.kind == "voice" and 1 or 2)
    if not audio_path then
        local err = read_file(job.out_dir .. "/audio.log") or "ffmpeg could not decode audio"
        return {ok = false, kind = job.kind, file_id = job.file_id, audio_error = tostring(err):sub(1, 300)}
    end
    return {ok = true, kind = job.kind, file_id = job.file_id, audio_path = audio_path}
end

local function finish(kind, file_id, paths, width, height, frame_dt, cached, first_frame, audio_path)
    return {
        ok = true,
        kind = kind,
        file_id = file_id,
        first_frame = first_frame == true,
        paths = paths,
        width = width,
        height = height,
        frame_dt = frame_dt,
        cached = cached or false,
        audio_path = audio_path,
    }
end

local function decode_job(job)
    if not ffmpeg then
        return {ok = false, kind = job.kind, file_id = job.file_id, first_frame = job.first_frame == true, error = "ffmpeg not found"}
    end
    local out_dir = job.out_dir
    local meta_raw = read_file(out_dir .. "/meta.json")
    if meta_raw then
        local ok, meta = pcall(json.decode, meta_raw)
        if ok and type(meta) == "table" and meta.version == 2
            and tonumber(meta.count) and tonumber(meta.frame_dt)
            and meta.first_frame == (job.first_frame == true) then
            local paths = collect_paths(out_dir, meta.count)
            if #paths == meta.count and #paths > 0 then
                local audio_path = meta.audio_path
                if audio_path and (not file_exists(audio_path) or not audio_path:match("%.wav$")) then audio_path = nil end
                if job.kind == "video" and not job.first_frame and not audio_path then
                    audio_path = extract_audio(job.path, out_dir)
                    meta.audio_path = audio_path
                    local meta_file = io.open(out_dir .. "/meta.json", "w")
                    if meta_file then
                        meta_file:write(json.encode(meta))
                        meta_file:close()
                    end
                end
                return finish(job.kind, job.file_id, paths, tonumber(meta.width), tonumber(meta.height), tonumber(meta.frame_dt), true, job.first_frame, audio_path)
            end
        end
    end

    run("rm -rf " .. sh_quote(out_dir))
    local made = run("mkdir -p " .. sh_quote(out_dir))
    if not made then
        return {ok = false, kind = job.kind, file_id = job.file_id, first_frame = job.first_frame == true, error = "cannot create frame directory"}
    end

    local input_path = job.path
    if job.kind == "sticker" and job.sticker_format == "stickerFormatTgs" then
        if not lottie_converter then
            return {
                ok = false,
                kind = job.kind,
                file_id = job.file_id,
                first_frame = job.first_frame == true,
                error = "Не найден lottie_convert.py. Установите python3 -m pip install -r requirements-media.txt; при ошибке DNS восстановите доступ к PyPI",
            }
        end
        local size = file_size(job.path)
        if not size or size > MAX_TGS_FILE_BYTES then
            return {
                ok = false,
                kind = job.kind,
                file_id = job.file_id,
                first_frame = job.first_frame == true,
                error = "TGS-файл имеет недопустимый размер",
            }
        end
        input_path = out_dir .. "/tgs.gif"
        local log_path = out_dir .. "/lottie.log"
        local command = string.format(
            "%s%s %s %s > %s 2>&1",
            clean_env,
            sh_quote(lottie_converter),
            sh_quote(job.path),
            sh_quote(input_path),
            sh_quote(log_path)
        )
        if not run(command) or (file_size(input_path) or 0) == 0 then
            local err = read_file(log_path)
            if not err or err == "" then err = "python-lottie could not convert this TGS" end
            return {
                ok = false,
                kind = job.kind,
                file_id = job.file_id,
                first_frame = job.first_frame == true,
                error = ("Не удалось преобразовать TGS: " .. tostring(err)):sub(1, 300),
            }
        end
    end

    local width, height, duration = probe(input_path)
    local count, frame_dt, target_w, target_h = plan(width, height, duration, job.kind == "video" and 2 or MIN_FPS)
    if job.first_frame then count = 1 end
    local filter
    if target_h then
        filter = string.format("fps=%.4f,scale=%d:%d:flags=lanczos", 1 / frame_dt, target_w, target_h)
    else
        filter = string.format("fps=%.4f,scale=%d:-2:flags=lanczos", 1 / frame_dt, target_w)
    end
    local log_path = out_dir .. "/ffmpeg.log"
    local command = string.format(
        "%s%s -y -v error -an -threads 2 -i %s -vf %s -start_number 1 -frames:v %d %s > %s 2>&1",
        clean_env,
        sh_quote(ffmpeg),
        sh_quote(input_path),
        sh_quote(filter),
        count,
        sh_quote(out_dir .. "/f_%03d.png"),
        sh_quote(log_path)
    )
    run(command)
    local paths = collect_paths(out_dir, count)
    if #paths == 0 then
        local err = read_file(log_path) or "ffmpeg produced no frames"
        return {ok = false, kind = job.kind, file_id = job.file_id, first_frame = job.first_frame == true, error = tostring(err):sub(1, 300)}
    end

    local audio_path
    if job.kind == "video" and not job.first_frame then
        audio_path = extract_audio(job.path, out_dir)
    end

    local actual_dt = frame_dt
    local meta = {
        version = 2,
        count = #paths,
        width = target_w,
        height = target_h or 0,
        frame_dt = actual_dt,
        first_frame = job.first_frame == true,
        audio_path = audio_path,
    }
    local meta_file = io.open(out_dir .. "/meta.json", "w")
    if meta_file then
        meta_file:write(json.encode(meta))
        meta_file:close()
    end
    return finish(job.kind, job.file_id, paths, target_w, target_h, actual_dt, false, job.first_frame, audio_path)
end

while true do
    local job = in_channel:demand()
    if type(job) ~= "table" or job.type == "quit" then
        break
    end
    if (job.type == "decode" or job.type == "decode_audio") and job.path and job.out_dir and job.file_id then
        local decoder = job.type == "decode_audio" and decode_audio_job or decode_job
        local ok, result = pcall(decoder, job)
        if not ok then
            if job.type == "decode_audio" then
                out_channel:push({
                    ok = false,
                    kind = job.kind,
                    file_id = job.file_id,
                    audio_error = tostring(result):sub(1, 300),
                })
            else
                out_channel:push({
                    ok = false,
                    kind = job.kind,
                    file_id = job.file_id,
                    first_frame = job.first_frame == true,
                    error = tostring(result),
                })
            end
        else
            out_channel:push(result)
        end
    end
end
