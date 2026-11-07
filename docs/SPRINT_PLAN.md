# Sprint Plan: Telegram Client for Anbernic RG35XX SP

## Sprint Goal
Fix media playback issues (GIFs, video notes, videos) and improve stability on device. 

---

## Current Issues

### 🔴 Critical (Blocking)
1. **GIFs/animations not playing** - `messageAnimation` not rendering
2. **Video notes (round videos) not loading** - `messageVideoNote` not downloading/playing
3. **Videos not loading** - `messageVideo` download/playback issues
2. **QR re-auth on network change** - Session invalidation on network switch
3. **Framebuffer double-buffering** - 640x960 fb0, only page 0 visible

### 🟡 High Priority
4. **Notifications don't auto-clear** (fixed - 15s timeout)
5. **Media album navigation** - Only first media in album accessible
6. **No media download progress** for user
7. **Emoji rendering** - missing NotoEmoji font
8. **Search exit** - Can't exit search with B button

### 🟢 Medium Priority
9. **Settings Scale** - Apply on Enter only
10. **Controls screen scroll** - Add scroll
11. **VPN settings** - Full integration
12. **Emoji keyboard** - Add emoji picker
13. **Reply/Forward UI** - Missing reply with quote
14. **Typing indicator** - sendChatAction
15. **Read receipts** - viewMessages

---

## Sprint Plan (3 days)

### Day 1: Media Playback Core
- [ ] Fix animation playback (`messageAnimation`)
- [ ] Fix video note download/playback (`messageVideoNote`)
- [ ] Fix video playback (`messageVideo`)
- [ ] Test on device

### Day 2: Media Navigation & Download
- [ ] Fix media album navigation (all items in album)
- [ ] Add download progress UI
- [ ] Fix media download retries
- [ ] Test on device

### Day 3: Stability & Polish
- [ ] Framebuffer page flipping (auto page flip)
- [ ] QR session persistence (investigate network change handling)
- [ ] Framebuffer double-buffering fix
- [ ] Performance optimization
- [ ] Full device test

---

## Technical Notes

### Media Playback Architecture
```
media_playback_core.lua  →  Core interface
media_playback_audio.lua →  Voice/audio
media_playback_video.lua →  Video/animation/video_note
media_videos.lua         →  ensure_video, ensure_video_note, ensure_animation
media_playback_video.lua →  request_video_playback, etc.
```

### Key Functions to Fix
- `ensure_animation()` in `media_videos.lua`
- `request_animation_playback()` in `media_playback_video.lua`
- `animation_image()` in `media_videos.lua`
- `animation_playback_state()` in `media_playback_video.lua`

### Framebuffer Issue
- Device has 640x960 fb0 (two 640x480 pages)
- Current: writes to page 0, displays page 0
- Need: Auto page flip or write to both pages

---

## Device Work Commands

```bash
# Deploy
adb push /tmp/Telegram.love /mnt/mmc/MUOS/application/Telegram/
adb shell "pkill -9 -f 'love Telegram'; cd /mnt/mmc/MUOS/application/Telegram && export LD_LIBRARY_PATH=/mnt/mmc/MUOS/application/CTupe/bin/libs.aarch64 && /mnt/mmc/MUOS/application/CTupe/bin/love . &"

# Logs
adb shell "cat /mnt/mmc/MUOS/application/Telegram/log.txt"
adb shell "cat /root/.local/share/love/Telegram/tdlib.log | tail -20"

# Framebuffer check
adb shell "dd if=/dev/fb0 bs=1 count=100 skip=0 2>&1 | xxd | head -3"
adb shell "cat /sys/class/graphics/fb0/pan"
```

---

## Definition of Done
- [ ] GIFs play in chat
- [ ] Video notes play (round videos)
- [ ] Videos play with controls
- [ ] Album navigation works (all media items)
- [ ] Framebuffer displays correctly
- [ ] App stable for 10+ min on device
