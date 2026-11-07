# TG Push/Background Service Design (muOS)

## Goal
Keep Telegram updates, VPN, and media prefetch working while UI is not running; show OS-level notifications.

## Components
1. `tg_background_service.sh` (daemon launcher)
   - Starts `threads/tdlib_worker.lua` headless via `love`? Or Lua interpreter with libtdjson.
   - Maintains pid file `/run/tgmuos_bg.pid`.
2. TDLib worker (headless)
   - Auth via existing config/DB key.
   - Polls updates, downloads media (priority low), writes queue to `/tmp/tgmuos_queue.json`.
3. VPN integration
   - Check `sing-box` config; start tunnel if configured; expose status file.
4. Notifier
   - Use `notify-send` or muOS notify binary; dedupe by chat/message id.
5. IPC with UI
   - Unix socket or file-based state; UI reads on launch to sync.

## Lifecycle
- Start on boot via init script or user toggle in Settings.
- Stop gracefully on SIGTERM, flush state.

## Security
- DB key from save dir; no secrets in logs.
- Rotate logs.

## Open questions
- Headless Lua runtime availability on muOS.
- Notify binary name.