-- src/shared/api/media_methods.lua
-- Main media methods module - aggregates all media sub-modules

return function(telegram)
    -- Initialize tables
    telegram.photos = telegram.photos or {}
    telegram.photo_by_message = telegram.photo_by_message or {}
    telegram.videos = telegram.videos or {}
    telegram.video_by_message = telegram.video_by_message or {}
    telegram.video_notes = telegram.video_notes or {}
    telegram.video_note_by_message = telegram.video_note_by_message or {}
    telegram.animations = telegram.animations or {}
    telegram.animation_by_message = telegram.animation_by_message or {}
    telegram.voice_notes = telegram.voice_notes or {}
    telegram.voice_by_message = telegram.voice_by_message or {}
    telegram.audios = telegram.audios or {}
    telegram.audio_by_message = telegram.audio_by_message or {}
    telegram.stickers = telegram.stickers or {}
    telegram.sticker_by_message = telegram.sticker_by_message or {}
    telegram.sticker_format_by_file = telegram.sticker_format_by_file or {}

    -- Load sub-modules
    require("src.shared.api.media_photos")(telegram)
    require("src.shared.api.media_videos")(telegram)
    require("src.shared.api.media_audio")(telegram)
    require("src.shared.api.media_stickers")(telegram)
    require("src.shared.api.media_conversion")(telegram)
    require("src.shared.api.media_playback_core")(telegram)
end