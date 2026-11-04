return function(telegram)
    function telegram:ensure_user_photo(user_id)
        if not user_id then return nil end
        local file_id = self.user_photo_by_id[user_id]
        if file_id then
            return self.user_photos[file_id]
        end
        local user = self.users[user_id]
        if not user then
            self:ensure_user(user_id)
            return nil
        end
        local photo = user.profile_photo
        if not photo then return nil end
        local size = photo.big or photo.small
        if not size or not size.id then return nil end
        file_id = size.id
        self.user_photo_by_id[user_id] = file_id
        local entry = self.user_photos[file_id]
        if not entry then
            entry = {status = "downloading"}
            self.user_photos[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "user_photo:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:user_photo_image(user_id)
        if not user_id then return nil end
        local file_id = self.user_photo_by_id[user_id]
        local entry = file_id and self.user_photos[file_id]
        if entry and entry.image then
            return entry.image, entry.width, entry.height
        end
        return nil
    end

    function telegram:ensure_chat_photo(chat_id)
        if not chat_id then return nil end
        local file_id = self.chat_photo_by_id[chat_id]
        if file_id then
            return self.chat_photos[file_id]
        end
        local chat = self.chats_by_id[chat_id]
        if not chat then return nil end
        local photo = chat.photo
        if not photo then return nil end
        local size = photo.big or photo.small
        if not size or not size.id then return nil end
        file_id = size.id
        self.chat_photo_by_id[chat_id] = file_id
        local entry = self.chat_photos[file_id]
        if not entry then
            entry = {status = "downloading"}
            self.chat_photos[file_id] = entry
            self:send({
                ["@type"] = "downloadFile",
                file_id = file_id,
                priority = 1,
                offset = 0,
                limit = 0,
                synchronous = false,
            }, "chat_photo:" .. tostring(file_id))
        end
        return entry
    end

    function telegram:chat_photo_image(chat_id)
        if not chat_id then return nil end
        self:ensure_chat_photo(chat_id)
        local file_id = self.chat_photo_by_id[chat_id]
        local entry = file_id and self.chat_photos[file_id]
        if entry and entry.image then
            return entry.image, entry.width, entry.height
        end
        local chat = self.chats_by_id[chat_id] or self.archive_chats_by_id[chat_id]
        local user_id = self:private_chat_user_id(chat)
        if user_id then
            self:ensure_user_photo(user_id)
            return self:user_photo_image(user_id)
        end
        return nil
    end

    function telegram:load_user_photo(file_id, path)
        local entry = self.user_photos[file_id]
        if not entry or entry.image then
            return
        end
        self:load_image(file_id, path, self.user_photos)
        local entry2 = self.user_photos[file_id]
        if entry2 and not entry2.image then
            local converted = self:convert_to_png(path)
            if converted then
                self:load_image(file_id, converted, self.user_photos)
            end
        end
    end

    function telegram:load_chat_photo(file_id, path)
        local entry = self.chat_photos[file_id]
        if not entry or entry.image then
            return
        end
        self:load_image(file_id, path, self.chat_photos)
        local entry2 = self.chat_photos[file_id]
        if entry2 and not entry2.image then
            local converted = self:convert_to_png(path)
            if converted then
                self:load_image(file_id, converted, self.chat_photos)
            end
        end
    end
end
