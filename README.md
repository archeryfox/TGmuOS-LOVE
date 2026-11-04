# TGMUOS (LÖVE port)

Telegram client for muOS on the PortMaster LÖVE 11.5 runtime. The active
entry point is `main.lua`, which loads the modular TDLib client in `src/`.
`legacy_main.lua` preserves the old mock UI and is not used by the launcher.

- 640×480 fullscreen; Eco (30 FPS) / Performance (60 FPS) modes and VSync toggle in Settings
- TDLib JSON client runs in a separate thread
- Credentials are read from `/root/.config/Telegram/telegram.conf` (legacy
  `/root/.config/tgmuos_love/telegram.conf` is used as fallback) or
  `TG_CONFIG`, `TG_API_ID`, and `TG_API_HASH`
- Telegram DC environment is selected with `environment=production` (default)
  or `environment=test` in the private config, or `TG_ENVIRONMENT`. Test DC
  data is stored separately from the production TDLib database.
- On the authorization screen, press Y on the gamepad or T on the keyboard to
  switch between Telegram test and production DCs; TDLib restarts with a
  separate database for the selected environment.
- The muOS launcher uses the ARM64 `lib/libtdjson.so` bundled with the app
- This is the app only; VPN functionality is not included

The private Telegram config can also set a native TDLib proxy:
`proxy_type=mtproto`, `proxy_server=...`, `proxy_port=...`,
`proxy_secret=...`. `t.me/proxy` MTProto links are supported. Changes are
read on app startup. `t.me/webproxy` links are a different browser relay
protocol and are not supported by the bundled TDLib 1.8.0.
TDLib supplies the official DC addresses and RSA public keys internally;
`use_test_dc` selects its test or production configuration.
The app generates a random 32-byte TDLib database key in its private LÖVE
save directory on first launch and supplies it to TDLib for database
encryption. During authorization, the UI shows the selected route, TDLib
connection state, configured proxy ping, and muVPN tunnel status with an
HTTPS latency probe through the system VPN route.

## Controls

| Button | Action |
| --- | --- |
| D-pad | Navigate |
| A | Select/Open |
| B | Back |
| X | Search (chat list) / message menu (chat) |
| Y | Chat menu (chat list) / select message (chat) |
| L1 / R1 | Scroll chat page / move five chats |
| L2 / R2 | Switch list: chats → folders → archive |
| START | Settings (Enter on the on-screen keyboard) |
| SELECT | Controls guide; on-screen keyboard in chat/search |
| MENU+A | Exit (MENU/guide key) |

SELECT (or Tab on a keyboard) opens the in-app controls guide. In an open chat
or search it toggles the gamepad on-screen keyboard instead.

On-screen keyboard: D-pad moves, A types, X toggles Shift, Y switches RU/EN,
B is Backspace, START is Enter, MENU hides it. The 😀 key opens six pages of
common emoji; L1/R1 switch emoji pages. Message menu → «Реакция» sends or
removes a reaction. Physical keyboard text input
continues to work through `love.textinput`.

## Runtime files

```text
conf.lua                         LÖVE configuration
main.lua                         Modular app entry point
src/                             TDLib client, features, and UI
threads/                         TDLib and media workers
lib/libtdjson.so                 AArch64 TDLib
glyph/                           muOS application icons
mux_launch.sh                    muOS launcher
gameinfo.xml                     muOS menu metadata
```

`docs/PORT_PLAN.md` tracks feature parity, device validation, and release
priorities. The desktop LÖVE AppImage cannot load the bundled ARM64 TDLib;
validate Telegram login on the target device.

Build a distributable muOS ZIP from the project root with
`./build_muOS.sh`; the archive contains only runtime files and does not include
the legacy mock entry point or local account/session data.
