return function(telegram)
    local converted_cache = {}
    local next_convert_idx = 0

    local function detect_format(input_path)
        local f = io.open(input_path, "rb")
        if not f then
            return nil
        end
        local head = f:read(16)
        f:close()
        if not head then
            return nil
        end
        if head:sub(1, 4) == "RIFF" and head:sub(9, 12) == "WEBP" then
            return "webp"
        end
        if head:sub(1, 6) == "GIF87a" or head:sub(1, 6) == "GIF89a" then
            return "gif"
        end
        if head:sub(1, 8) == "\137PNG\r\n\026\n" then
            return "png"
        end
        if head:sub(1, 2) == "\255\216" then
            return "jpeg"
        end
        if head:sub(5, 8) == "ftyp" then
            return "video"
        end
        if head:sub(1, 4) == "\026\069\223\163" then
            return "video"
        end
        if head:sub(1, 2) == "\031\139" then
            return "tgs"
        end
        return "unknown"
    end

    function telegram:detect_media_format(path)
        return detect_format(path)
    end

    function telegram:convert_to_png(input_path)
        if not input_path then
            return nil
        end
        if converted_cache[input_path] ~= nil then
            return converted_cache[input_path]
        end

        local save_dir = love.filesystem.getSaveDirectory()
        next_convert_idx = next_convert_idx + 1
        local out_name = "conv_" .. tostring(next_convert_idx) .. ".png"
        local out_path = save_dir .. "/" .. out_name

        local fmt = detect_format(input_path)
        if not fmt then
            converted_cache[input_path] = nil
            return nil
        end
        if fmt == "png" or fmt == "jpeg" then
            converted_cache[input_path] = nil
            return nil
        end
        if fmt == "unknown" then
            converted_cache[input_path] = nil
            return nil
        end

        local function shell_quote(value)
            return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
        end

        local quoted_input = shell_quote(input_path)
        local quoted_output = shell_quote(out_path)
        local clean_env = "env -u LD_LIBRARY_PATH "
        local converters = {}
        if fmt == "webp" then
            table.insert(converters,
                clean_env .. "ffmpeg -y -v error -threads 1 -i " .. quoted_input ..
                " -frames:v 1 -f image2 " .. quoted_output .. " 2>/dev/null")
            table.insert(converters, clean_env .. "dwebp " .. quoted_input .. " -o " .. quoted_output .. " 2>/dev/null")
            table.insert(converters, clean_env .. "magick " .. shell_quote(input_path .. "[0]") .. " " .. quoted_output .. " 2>/dev/null")
        end
        if fmt == "gif" or fmt == "video" then
            table.insert(converters,
                clean_env .. "ffmpeg -y -v error -threads 1 -i " .. quoted_input ..
                " -frames:v 1 -f image2 " .. quoted_output .. " 2>/dev/null")
        end
        if fmt == "tgs" then
            local lottie = "lottie_convert.py"
            table.insert(converters,
                clean_env .. lottie .. " --frame 0 " .. quoted_input .. " " .. quoted_output .. " 2>/dev/null")
            local gif_path = save_dir .. "/conv_" .. tostring(next_convert_idx) .. ".gif"
            table.insert(converters,
                clean_env .. lottie .. " " .. quoted_input .. " " .. shell_quote(gif_path) .. " 2>/dev/null && " ..
                clean_env .. "ffmpeg -y -v error -threads 1 -i " .. shell_quote(gif_path) ..
                " -frames:v 1 -f image2 " .. quoted_output .. " 2>/dev/null")
        end
        if fmt == "gif" then
            table.insert(converters, clean_env .. "magick " .. shell_quote(input_path .. "[0]") .. " " .. quoted_output .. " 2>/dev/null")
            local script = 'from PIL import Image; import sys; im = Image.open(sys.argv[1]); im.seek(0); im.convert("RGBA").save(sys.argv[2])'
            table.insert(converters,
                clean_env .. "python3 -c " .. shell_quote(script) .. " " .. quoted_input .. " " .. quoted_output .. " 2>/dev/null")
        end

        for _, command in ipairs(converters) do
            os.remove(out_path)
            local ret = os.execute(command)
            if ret == 0 or ret == true then
                local check = io.open(out_path, "rb")
                if check then
                    local size = check:seek("end")
                    check:close()
                    if size and size > 0 then
                        converted_cache[input_path] = out_path
                        return out_path
                    end
                end
            end
        end

        converted_cache[input_path] = nil
        return nil
    end

    function telegram:load_image(file_id, path, storage)
        local entry = storage[file_id]
        if not entry or entry.image then
            return
        end
        local input = io.open(path, "rb")
        if not input then
            entry.status = "error"
            return
        end
        local data = input:read("*a")
        input:close()
        if not data or data == "" then
            entry.status = "error"
            return
        end
        local ok, file_data = pcall(love.filesystem.newFileData, data, "file_" .. tostring(file_id))
        if not ok or not file_data then
            entry.status = "error"
            return
        end
        local ok2, image_data = pcall(love.image.newImageData, file_data)
        if not ok2 or not image_data then
            entry.status = "error"
            return
        end
        local ok3, image = pcall(love.graphics.newImage, image_data)
        if not ok3 or not image then
            entry.status = "error"
            return
        end
        entry.image = image
        entry.width = image:getWidth()
        entry.height = image:getHeight()
        entry.status = "ready"
    end

    function telegram:load_photo(file_id, path)
        self:load_image(file_id, path, self.photos)
    end

    function telegram:load_sticker(file_id, path)
        local entry = self.stickers[file_id]
        if not entry then
            return
        end
        entry.source_path = path
        if entry.image then return end
        self:load_image(file_id, path, self.stickers)
        local entry2 = self.stickers[file_id]
        if entry2 and not entry2.image then
            local converted = self:convert_to_png(path)
            if converted then
                self:load_image(file_id, converted, self.stickers)
            end
        end
    end

    function telegram:convert_to_gif(input_path)
        if not input_path then return nil end
        local save_dir = love.filesystem.getSaveDirectory()
        next_convert_idx = next_convert_idx + 1
        local gif_name = "conv_" .. tostring(next_convert_idx) .. ".gif"
        local gif_path = save_dir .. "/" .. gif_name

        local fmt = detect_format(input_path)
        if not fmt or (fmt ~= "tgs" and fmt ~= "video") then
            return nil
        end

        local function shell_quote(value)
            return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
        end
        local clean_env = "env -u LD_LIBRARY_PATH "
        local quoted_input = shell_quote(input_path)
        local quoted_gif = shell_quote(gif_path)

        local converters = {}
        if fmt == "tgs" then
            local lottie = "lottie_convert.py"
            table.insert(converters, clean_env .. lottie .. " " .. quoted_input .. " " .. quoted_gif .. " 2>/dev/null")
        elseif fmt == "video" then
            table.insert(converters, clean_env .. "ffmpeg -y -v error -threads 1 -i " .. quoted_input .. " " .. quoted_gif .. " 2>/dev/null")
        end

        for _, command in ipairs(converters) do
            os.remove(gif_path)
            local ret = os.execute(command)
            if ret == 0 or ret == true then
                local check = io.open(gif_path, "rb")
                if check then
                    local size = check:seek("end")
                    check:close()
                    if size and size > 0 then
                        return gif_path
                    end
                end
            end
        end
        return nil
    end

    function telegram:load_sticker_thumbnail(file_id, path, sticker_file_id)
        self:load_sticker(file_id, path)
        local thumbnail = self.stickers[file_id]
        local sticker = self.stickers[sticker_file_id]
        if thumbnail and thumbnail.image and sticker and not sticker.image then
            sticker.image = thumbnail.image
            sticker.width = thumbnail.width
            sticker.height = thumbnail.height
            sticker.status = "ready"
        end
    end
end
