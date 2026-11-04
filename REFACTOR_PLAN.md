# FSD Refactoring Plan

## Large Files to Split (>300 lines)

### 1. chat_screen.lua (1154 lines)
**Split into:**
- `src/features/chat/ui/chat_screen.lua` (main ~200 lines) - imports and composes
- `src/features/chat/ui/chat_list_renderer.lua` (~300 lines) - draw_chat_list
- `src/features/chat/ui/conversation_renderer.lua` (~400 lines) - draw_conversation, draw_message
- `src/features/chat/ui/media_renderer.lua` (~200 lines) - draw_fullscreen_media
- `src/features/chat/ui/input_renderer.lua` (~100 lines) - draw_input

### 2. chat_screen_input.lua (893 lines)
**Split into:**
- `src/features/chat/ui/input_handler.lua` (~300 lines) - keypressed, keyreleased
- `src/features/chat/ui/cursor_nav.lua` (~150 lines) - cursor navigation
- `src/features/chat/ui/media_nav.lua` (~150 lines) - media navigation
- `src/features/chat/ui/context_menu_handler.lua` (~150 lines) - context menus
- `src/features/chat/ui/search_handler.lua` (~100 lines) - search logic

### 3. tdlib_client.lua (806 lines)
**Split into:**
- `src/shared/api/tdlib_client.lua` (core ~200 lines)
- `src/shared/api/tdlib_auth.lua` (~150 lines) - auth flow
- `src/shared/api/tdlib_chats.lua` (~150 lines) - chat operations
- `src/shared/api/tdlib_messages.lua` (~150 lines) - message operations
- `src/shared/api/tdlib_proxy.lua` (~100 lines) - proxy management

### 4. media_methods.lua (636 lines)
**Split into:**
- `src/shared/api/media_photos.lua` (~150 lines)
- `src/shared/api/media_videos.lua` (~150 lines)
- `src/shared/api/media_audio.lua` (~150 lines)
- `src/shared/api/media_stickers.lua` (~100 lines)

### 5. chat_methods.lua (523 lines)
**Split into:**
- `src/shared/api/chats_list.lua`
- `src/shared/api/chats_settings.lua`

### 6. message_methods.lua (517 lines)
**Split into:**
- `src/shared/api/messages_send.lua`
- `src/shared/api/messages_edit.lua`
- `src/shared/api/messages_delete.lua`

### 6. media_playback.lua (412 lines) — DONE
**Split into:**
- `src/shared/api/media_playback_core.lua` — decoder/thread infrastructure: ensure_media_decoder, media_entry, queue_media_decode, queue_audio_decode, ensure_animated_sticker, load_decoded_frame/load_audio_source (locals), poll_media_decoder
- `src/shared/api/media_playback.lua` — playback controls: request/pause/resume/seek/stop, media_playback_state, media_download_state

Both modules follow the project convention `return function(telegram) ... end`.
Resolved 2026-11-03: the previously drafted per-kind fragments (old media_playback_audio.lua /
media_playback_video.lua with a flat table API) were incompatible with the aggregator and crashed
startup (`attempt to call a table value`); they were replaced by the factory-style split above and
removed. Obsolete tdlib_auth/chats/messages/proxy drafts remain unwired — see item 3.

### 7. auth_screen.lua (374 lines)
**Split into:**
- `src/features/auth/ui/auth_qr.lua`
- `src/features/auth/ui/auth_2fa.lua`
- `src/features/auth/ui/auth_vpn.lua`

### 8. chat_model.lua / message_model.lua - add to entities

## Migration Steps
1. Create new files with extracted logic
2. Update imports in main files
3. Test each module
4. Delete old large files
