# 2026-11-03 — Troubleshooting: Telegram (LÖVE 11.5 + TDLib) на RG35XX SP

Статус: частично решено. Авторизация доходит до экрана пароля, но ввод с
кнопок A/B на экране пароля не работает; процессы Telegram закрываются, но
требуют аккуратной остановки.

## Среда

- Устройство: Anbernic RG35XX SP, muOS 2601.x, aarch64.
- IP устройства: `192.168.43.182` (динамический, не считать постоянным).
- Приложение: `/mnt/mmc/MUOS/application/Telegram`.
- Runtime: `/mnt/mmc/MUOS/PortMaster/runtimes/love_11.5/love.aarch64`.
  Нужен `LD_LIBRARY_PATH=$RUNTIME/libs.aarch64`.
- TDLib: нативный `libtdjson.so` 1.8.0,
  `/root/.local/share/love/Telegram/native/libtdjson.so`.
- Конфиг: `/root/.config/Telegram/telegram.conf` (права `600`).
- Прокси: SOCKS5 на хосте `192.168.43.126:10808`. Прямой выход на
  `api.telegram.org` у провайдера заблокирован.

## Симптомы

1. Авторизация зависала на `authorizationStateWaitEncryptionKey`.
2. QR-авторизация уходила в цикл с ошибкой
   `Another authorization query has started`.
3. Прокси не поднимался, приложение не могло подключиться к Telegram.
4. На экране пароля стрелки работают, а A/B не меняют состояние клавиатуры.
5. После выхода/убийства процесса `frontend.sh` не возвращался в launcher.

## Что нашли и исправили

### TDLib 1.8.0: схема запросов

Встроенная TDLib 1.8.0 не принимает схему от более новых версий:

- `setTdlibParameters` — нужен вложенный объект `parameters`, а не поля
  верхнего уровня. Иначе `400 Parameters aren't specified`.
- `addProxy` — нужны плоские `server`/`port`/`type`, а не вложенный `proxy`.
  Иначе `400 Proxy type must be non-empty`.
- `addProxy` возвращает объект `proxy`, а не `ok`; без обработки этого типа
  `proxy_ready` не выставлялся и QR не запрашивался.

Исправлено в `src/shared/api/tdlib_client.lua` адаптивной схемой
(flat → nested при ошибке) и обработкой `authorizationStateWaitEncryptionKey`.
Подробности: `docs/aichat/2026-11-03-tdlib-schema-fix.md`.

### QR: ложная ошибка и повторные запросы

Ошибка `Another authorization query has started` для запроса с `@extra="qr"`
не является фатальной: предыдущий QR-запрос ещё выполняется. Раньше она
показывалась как ошибка и провоцировала новый запрос.

Исправлено:

- такая ошибка считается штатной: `qr_request_pending = true`,
  `auth_error` очищается;
- повторный QR-запрос ограничен 30 секундами;
- `request_qr()` не отправляет запрос, если `qr_request_pending` уже выставлен.

Результат: QR-экран появляется, авторизация доходит до ввода пароля.

### Прокси и путь к конфигу

Прокси на хосте проверен вручную:

```sh
curl --socks5-hostname 192.168.43.126:10808 https://api.telegram.org
```

Ожидаемый ответ — редирект (302), а не таймаут.

Важный нюанс: `mux_launch.sh` на устройстве создаёт
`/root/.config/tgmuos_love`, а активный `main.lua` читает
`/root/.config/Telegram/telegram.conf`. README тоже упоминает
`tgmuos_love`. Из-за расхождения конфиг может выглядеть «не найденным».
Для текущей сборки используйте `/root/.config/Telegram/telegram.conf`;
в перспективе пути нужно унифицировать.

Если поднят `muvpn_love`/sing-box с TUN на весь трафик, он может уводить
host-proxy в сломанный туннель. На время отладки sing-box нужно остановить
или настроить split-route.

### Раскладка A/BXY

В `main.lua` добавлено автоопределение раскладки:

- `TG_ABXY=retro|modern` — явное переопределение;
- `/tmp/con_go` — текущая схема muOS;
- `/opt/muos/config/settings/advanced/swap` — `1` = modern, `0` = retro;
- по умолчанию — modern.

Для retro `SELECT_BUTTON="b"`, `BACK_BUTTON="a"`; для modern — наоборот.
Физическая A = `BTN_SOUTH`, B = `BTN_EAST`; в retro-раскладке muOS
физическая A приходит в приложение как логическая `b`.

Текущий дефект: на экране пароля d-pad двигает выбор, но A/B не
обрабатываются. Проверить:

- доходят ли `love.gamepadpressed` события до приложения (временный лог);
- совпадает ли mapping `muOS-Keys` в
  `/opt/muos/share/info/gamecontrollerdb/{retro,modern}.txt`;
- обрабатывает ли экран пароля `return`/`backspace` в режиме виртуальной
  клавиатуры, а не только `textinput`.

### Закрытие процессов и возврат в launcher

Штатные средства:

- `/mnt/mmc/MUOS/application/Telegram/tools/tgkill.sh`;
- пункт «Закрыть все процессы ТГ» в меню приложения
  (`tg_process.kill_all()`).

Ручная остановка:

```sh
pkill -TERM -x love.aarch64
sleep 1
pkill -KILL -x love.aarch64
pkill -KILL -x sing-box
```

Не используйте `pgrep -f "love.aarch64 .*/application/Telegram"`: шаблон
совпадает с командной строкой самой SSH-сессии, и `kill` обрывает вашу же
команду. Надёжнее `pkill -x love.aarch64` или `pgrep -x love.aarch64`.

`frontend.sh` запускает приложение через `mux_launch.sh` (тот делает
`exec love.aarch64`). После выхода приложения frontend выставляет
`/tmp/act_go=appmenu`. Чтобы вернуться в launcher:

```sh
echo launcher >/tmp/act_go
: >/tmp/safe_quit
```

Важно: в `func.sh` переменная называется `SAFE_QUIT`, но путь —
`/tmp/safe_quit` (нижний регистр). Файл `/tmp/SAFE_QUIT` ничего не делает;
`frontend.sh` продолжает ждать в `while [ ! -f "$SAFE_QUIT" ]`.

Проверка, что процессов Telegram не осталось:

```sh
ps -eo pid,ppid,stat,comm,args | grep -E "[l]ove\.aarch64|[s]ing-box|[t]dlib"
```

## Проверка на устройстве

Скриншоты:

```sh
fbgrab -a -w 640 -h 480 -l 640 /tmp/x.png
scp root@192.168.43.182:/tmp/x.png .
tesseract x.png stdout -l eng
```

Смотреть обе страницы framebuffer (`--page 0` и `--page 1`): живой процесс
не гарантирует, что на экране нужный кадр.

Синтаксис Lua перед выкладкой:

```sh
luajit -e "assert(loadfile('main.lua'))"
luajit -e "assert(loadfile('src/shared/api/tdlib_client.lua'))"
```

Подтверждено: QR-экран появляется, экран
«Двухфакторная аутентификация / введи ещё один пароль» и сетка клавиатуры
отображаются.

## Осталось

- P0: `reset_account_state()` не сбрасывает `encryption_key_sent`
  (`src/shared/api/tdlib_client.lua:189`). После logout/смены аккаунта
  `checkDatabaseEncryptionKey` может не отправиться, и авторизация зависнет
  на `WaitEncryptionKey`.
- Ввод A/B на экране пароля.
- Унифицировать путь конфига (`Telegram` vs `tgmuos_love`) в `main.lua`,
  `mux_launch.sh` и README.
- Добавить запись ошибок TDLib в `log.txt` рядом с приложением (сейчас
  `log.txt` пустой, диагностика идёт только через stdout/tdlib.log).

## Затронутые файлы

- `main.lua` — `detect_abxy_layout()`, `SELECT_BUTTON`/`BACK_BUTTON`.
- `src/shared/api/tdlib_client.lua` — схема TDLib, QR, прокси, авторизация.
- `src/features/auth/ui/auth_screen.lua` — экран пароля и клавиатура.
- `src/shared/ui/virtual_keyboard.lua` — экранная клавиатура.
- `mux_launch.sh` — запуск LÖVE и путь конфига.
- `tools/tgkill.sh`, `tools/tgclose.sh` — остановка процессов.

---

## 2026-11-08 — Выход из этапа ввода 2FA-пароля

### Симптом

После успешного QR-сканирования TDLib запрашивает 2FA-пароль
(`authorizationStateWaitPassword`). Пользователь не хочет входить в эту
учётку, но выйти с этапа ввода пароля нельзя: TDLib не поддерживает возврат
к предыдущему этапу, кнопка «Назад» на клавиатуре не сбрасывала состояние.

### Причина

`restart_account` (ранее) просто перезапускал TDLib для того же аккаунта
(`pending_account_key = active_key`). Но TDLib восстанавливал сессию из БД и
снова уходил в `authorizationStateWaitPassword`, поэтому этап ввода пароля
возвращался.

### Исправление

В `main.lua` callback `restart_account` теперь:

1. помечает аккаунт как неавторизованный (`account.authorized = false`);
2. удаляет каталог БД аккаунта (`rm -rf .../tdlib`);
3. вызывает `save_account_store()`;
4. ставит `pending_account_key = key`, чтобы TDLib запустился заново.

Результат: TDLib стартует с чистой БД, доходит до QR-этапа, пользователь
может войти в другую учётку или отменить вход. Добавлена видимая кнопка
«Назад» (правый верхний угол) и клавиша «Назад» на виртуальной клавиатуре.

### Файлы

- `main.lua` — `restart_account` callback.
- `src/features/auth/ui/auth_screen.lua` — кнопка «Назад» и обработка `back`.
