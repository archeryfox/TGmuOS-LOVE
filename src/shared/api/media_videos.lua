-- src/shared/api/media_videos.lua
-- Video handling extracted from media_methods.lua

return function(telegram)
    function telegram:choose_video_size(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageVideo" then
            return nil
        end
        local video = content.video
        if not video or not video.id then return nil end
        return video
    end

    function telegram:choose_animation_size(message)
        local content = message and message.content
        if not content or content["@type"] ~= "messageAnimation" then
            return nil
        end
        local animation = content.animation
        if not animation or not animation.id then return nil end
        return animation
    end

    function telegram:ensure_video(message)
        if not message or not message.id then
            return
        end
        local file_id = self.video_by_message[message.id]
        if file_id then
            return self.videos[file_id]
        end
        local video = self:choose_video_size(message)
        if not video then
            return
        end
        file_id = video.id
        self.video_by_message[message.id] = file_id
        local entry = self.videos[file_id]
        local content = message.content or {}
        local duration = content.video and content.video.duration
        if not entry then
            entry = {status = "downloading", duration = tonumber(duration)}
            self.videos[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "video:" .. tostring(file_id))
        elseif not entry.duration and tonumber(duration) then
            entry.duration = tonumber(duration)
        end
        return entry
    end

    function telegram:ensure_animation(message)
        if not message or not message.id then return end
        local file_id = self.animation_by_message[message.id]
        if file_id then return self.animations[file_id] end
        
        local animation = self:choose_animation_size(message)
        if not animation then return end
        
        file_id = animation.id
        self.animation_by_message[message.id] = file_id
        local entry = self.animations[file_id]
        if not entry then
            entry = {status = "downloading"}
            self.animations[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "animation:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:ensure_video_note(message)
        if not message or not message.id then return end
        local file_id = self.video_note_by_message[message.id]
        if file_id then return self.video_notes[file_id] end
        
        local content = message.content
        local note = content and content.video_note
        local video_note = note and note.video_note
        if not video_note or not video_note.id then return end
        
        file_id = video_note.id
        self.video_note_by_message[message.id] = file_id
        local entry = self.video_notes[file_id]
        if not entry then
            entry = {status = "downloading", duration = tonumber(note.duration)}
            self.video_notes[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "video_note:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:video_image(message)
        local content = message and message.content or {}
        local file_id, entry
        if content["@type"] == "messageVideoNote" then
            file_id = self.video_note_by_message and self.video_note_by_message[message.id]
            entry = file_id and self.video_notes[file_id]
        else
            file_id = self.video_by_message[message.id]
            entry = file_id and self.videos[file_id]
        end
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
        end
        return nil
    end

    function telegram:video_note_image(message)
        local file_id = self.video_note_by_message[message.id]
        local entry = file_id and self.video_notes[file_id]
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
        end
        return nil
    end

    function telegram:animation_image(message)
        local file_id = self.animation_by_message[message.id]
        local entry = file_id and self.animations[file_id]
        if entry then
            local image = entry.image
            if entry.frames and #entry.frames > 0 then
                image = entry.frames[1]
                local step = math.max(0.03, entry.frame_dt or (1 / 10))
                local position = entry.playing
                    and math.max(0, love.timer.getTime() - (entry.play_origin or love.timer.getTime()))
                    or (tonumber(entry.play_position) or 0)
                local index = math.floor(position / step) % #entry.frames + 1
                image = entry.frames[index] or image
            end
            if image then
                return image, entry.width or image:getWidth(), entry.height or image:getHeight()
            end
        end
        return nil
    end

    function telegram:load_video(file_id, path)
        local entry = self.videos[file_id]
        if not entry then return end
        entry.source_path = path
        self:queue_media_decode("video", file_id, path, not entry.autoplay)
    end

    function telegram:load_video_note(file_id, path)
        local entry = self.video_notes[file_id]
        if not entry then return end
        entry.source_path = path
        self:queue_media_decode("video_note", file_id, path, not entry.autoplay)
    end

    function telegram:load_animation(file_id, path)
        local entry = self.animations[file_id]
        if not entry then return end
        entry.source_path = path
        if entry.image then return end
        self:load_image(file_id, path, self.animations)
        local entry2 = self.animations[file_id]
        if entry2 and not entry2.image then
            local converted = self:convert_to_png(path)
            if converted then
                self:load_image(file_id, converted, self.animations)
            end
        end
    end
end