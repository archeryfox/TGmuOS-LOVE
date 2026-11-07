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

## Tools (`tools/`)

| Tool | Description |
| ---- | ----------- |
| `monitor.sh` | **Крутой инструмент мониторинга** в реальном времени для Telegram клиента на Anbernic RG35XX SP. Показывает процессы (Telegram, LÖVE, sing-box), потребление памяти/CPU, состояние TDLib авторизации, последнии логи, сетевое соединение и прокси. Запуск: `./tools/monitor.sh` локально на устройстве или `ssh root@DEVICE "./tools/monitor.sh"` удалённо. Опции: `--once`, `--interval N`, `--follow`. |
| `tgkill.sh` / `tgclose.sh` | Жёсткая остановка Telegram клиента и связанных процессов. |
| `ssh_tgkill.sh` | Убить Telegram на удалённом устройстве по SSH. |

### Пример вывода `monitor.sh`

```
===============================================================================
  TGmuOS MONITOR  —  2026-11-07 08:15:32
===============================================================================

--- PROCESSES ---
root      1234  0.0  2.1  54321  12345 ?        S    08:10   0:00 love Telegram
root      1235  0.5  1.2  23456   5432 ?        S    08:10   0:00 sing-box
Telegram PID: 1234
VmRSS:    45672 kB
VmSize:   89012 kB
Threads:  8
State:    S (sleeping)

--- MEMORY ---
              total        used        free      shared  buff/cache   available
Mem:           256M        120M         40M         10M         96M         110M

--- TDLIB AUTH STATE ---
authorizationStateWaitPhoneNumber
WaitPhoneNumber: введите номер телефона

--- NETWORK & PROXY ---
inet 192.168.0.151/24 brd 192.168.0.255 scope global wlan0
Telegram API: 200
Via Proxy: 200

--- CONFIG ---
api_id=123456
api_hash=...
environment=production

--- RECENT LOGS (последние 12 строк) ---
[TDLib] Received updateAuthorizationState
[TDLib] Sending code to ...
...

Нажмите Ctrl+C для остановки | интервал: 2s
```

## Running (PC / development)

Use `run.sh` to launch the client with Telegram credentials supplied as
runtime environment variables (preferred) or from a config file:

```sh
# Environment variables
TG_API_ID=12345 TG_API_HASH=abcdef ./run.sh

# Or from a config file
TG_CONFIG=/path/to/telegram.conf ./run.sh

# Or place credentials in ~/.config/love_tg_native/telegram.conf:
#   api_id=12345
#   api_hash=abcdef
./run.sh
```

Supported environment variables: `TG_API_ID`, `TG_API_HASH`, `TG_CONFIG`,
`TG_ENVIRONMENT` (production/test), `TG_PROXY_TYPE`, `TG_PROXY_SERVER`,
`TG_PROXY_PORT`, `TG_PROXY_SECRET`, `TG_PROXY_USER`, `TG_PROXY_PASSWORD`,
`LOVE_BIN`. Proxy settings can also be stored in the config file.

On muOS the launcher `mux_launch.sh` auto-selects the first available config
file from `/root/.config/Telegram/telegram.conf`,
`/root/.config/tgmuos_love/telegram.conf` or
`/root/.config/love_tg_native/telegram.conf`.
