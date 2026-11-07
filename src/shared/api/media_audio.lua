-- src/shared/api/media_audio.lua
-- Audio/voice handling extracted from media_methods.lua

return function(telegram)
    function telegram:ensure_voice_note(message)
        if not message or not message.id then return end
        local file_id = self.voice_by_message[message.id]
        if file_id then return self.voice_notes[file_id] end
        
        local content = message.content
        local note = content and content.voice_note
        local voice = note and note.voice
        if not voice or not voice.id then return end
        
        local file_id = voice.id
        self.voice_by_message[message.id] = file_id
        local entry = self.voice_notes[file_id]
        if not entry then
            entry = {status = "downloading", duration = tonumber(note.duration)}
            self.voice_notes[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "voice:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:ensure_audio(message)
        if not message or not message.id then return end
        local file_id = self.audio_by_message[message.id]
        if file_id then return self.audios[file_id] end
        
        local content = message.content
        local audio = content and content.audio
        if not audio or not audio.audio or not audio.audio.id then return end
        
        local file_id = audio.audio.id
        self.audio_by_message[message.id] = file_id
        local entry = self.audios[file_id]
        if not entry then
            entry = {status = "downloading", duration = tonumber(audio.duration)}
            self.audios[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "audio:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:load_voice_note(file_id, path)
        local entry = self.voice_notes[file_id]
        if not entry then return end
        entry.source_path = path
        entry.status = "downloaded"
    end

    function telegram:load_audio(file_id, path)
        local entry = self.audios[file_id]
        if not entry then return end
        entry.source_path = path
        entry.status = "downloaded"
    end

    function telegram:voice_image(message)
        -- Voice notes don't have images, return nil
        return nil
    end

    function telegram:audio_image(message)
        -- Audio messages don't have images, return nil
        return nil
    end
end