todo
_in progress_
**important**
~~DONE~~

# Бэклог-Фичи на будущее
- ~~Экран с управлением `Controls guide` (SELECT / Tab)~~
- ~~Добавить иконку приложения из res/telegram.png~~
- _QWERTY КЛАВИАТУРА_
  - ~~Базовая EN/RU + Shift/Caps/Lang/Space/Backspace/Enter/Sym~~
  - ~~Эмодзи клавиатура (6 страниц по 40, L1/R1)~~
  - **Эмодзи рендеринг: спрайт-атлас / ImageFont / NotoColorEmoji (LÖVE не поддерживает нативно, нужен ImageFont или спрайт-лист)**
- ~~Emoji-шрифт (NotoEmoji-Regular.ttf) — добавить файл~~
- ~~**TGS\WEBM стикеры**~~
  - _Базово загружать 1 кадр (анимации работают)_
    - ~~TGS loads first frame~~
    - ~~WEBM demo runtime-decoding~~
- ~~Распределить все кнопки по функциям (gamepad mapping)~~
- ~~Функция открытия профиля~~
- _Добавление аккаунтов (Settings callbacks не подключены)_
- Скорость видео
- _Улучшить качество видео(FPS) — media playback работает_
  - ~~to do **60fps**~~
- _Стикерпаки_
  1. **Выбор\отправление стикеров**
  2. **Переход на полный стикерпак**
- Функция Обновления клиента (через внешний репозиторий)
- **Markdown basic render in messages**
- ultra-Basic webView


## _UI-fixes_
- ~~Реакции на сообщениях\постах (отображение + отправка через контекстное меню)~~
- ~~Вызов контекстного меню для меню чатов (Y)~~
  - сделать из него выход по той же кнопке либо B
- ~~Сделать Анимации и плавности больше (smooth scroll, fade меню/уведомлений)~~
  - **На стрелки ^v плавное листание чата на 15px, переход по сообщениям переназначить на стрелки < >**
- _Расширять меню чатов в режиме Меню чатов. Уменбшать меню чатов в режиме диалога_
- _Добавить время просмотра_
- ~~Системные уведомления \ ошибки — вынесены вправо, не вылезают. Через 15 сек плавно пропадают~~
- ~Сделать в режиме открытия фото~


## Баги
- _Эмоджи сломаны (NotoEmoji-Regular.ttf отсутствует в пакете)_
  > https://github.com/HakashiKatake/emoji-renderer-love2d
- ~~Нельзя выйти из поиска — B / MENU~~
- ~~Нельзя выйти из контекстного меню выбора чата — B / MENU~~
- ~~Зум\фулскрин медиа — перелистывание только первых медиа!!!~~ 
- _UI кривой — частично исправлено (оверфлоу эмодзи, оверлапы)_
- _Эмодзи overflow — wrap_width ограничен, авто-рерасп на 75%_
- ~~+/- Масштаб в настройках — <-/-> стрелки + Enter для применения~~
- контекстное меню замутить\отправить в архив - его нельзя отменить или покинуть по Y или B


## Критичное (по ревизии кода)
- _Шифрование БД TDLib — encryption_key пока пустой_
- _Мультиаккаунт — settings_screen callbacks не подключены в main.lua_
- _README — не соответствует коду (use_test_dc, VPN, START/L2/R2/SELECT)_
- _NotoEmoji-Regular.ttf — файл не в пакете (ui_kit.lua:66)_
- ~~virtual_keyboard.lua подключен к чату и поиску~~
- ~~build_muOS.sh: qr.lua в архиве~~
- ~~dist/tgmuos_love.zip пересобран~~
- ~~Две точки входа — мёртвый src/app/main.lua удалён/игнорируется~~

## Функциональные пробелы
- Отправка медиа, файлов, фото, голосовых и кружков — только текст
- Reply на сообщение (ответ с цитатой) и переход к исходному
- ~~Отправка реакций — только отображение~~
- ~~Typing/online-статус — sendChatAction при вводе~~
- Создание чатов/групп, вступление/выход, публичные чаты
- _Экран «Настройки VPN» — заглушка, vpn_status_worker не подключён_
- UI для настройки api_id/api_hash и прокси (только telegram.conf/env)
- ~~Уведомления о новых сообщениях~~
- Ограничение одновременно декодируемых медиа и очистка кэша
- Контекстное меню сообщения: «Написать ему» — открыть личный чат с автором
- ~~viewMessages / read receipts — сбрасываются при открытии~~

## Техдолг
- Тесты и CI; git-репозиторий
- _QR-энкодер — версия 5 (<=106 байт), нужен fallback/версии_
- _Почистить legacy: legacy_main.lua, telegram.lua, qr_c.lua, qr_lua.lua, qrencode.lua, qr.lua(root), src/app/, src/features/auth/api/, пустые папки, дубли шрифтов_
- Обработка updateMessageEdited, updateChatPosition/Order, updateDeleteChatHistory
- UI-fallback при отсутствии ffmpeg/lottie_convert.py/dwebp/ImageMagick
- Ротация логов, защита приватных логов от репозитория
- Скрипт кросс-сборки/деплоя

## Что сделано в этой сессии
- ~~MENU/Guide = back/quit везде (main.lua guide="escape")~~
- ~~B / MENU выход из поиска и контекстных меню~~
- ~~Settings Scale: <-/-> меняют, Enter применяет~~
- ~~Controls Screen: вверх/вниз скролл, скроллбар~~
- ~~Auth Menu: навигация вверх/вниз/A/MENU, виртуальная клавиатура~~
- ~~Emoji overflow: wrap_width max 240px + авто-рерасп 75%~~
- ~~UI hints: Esc->MENU, сокращённые тексты, правое выравнивание уведомлений~~
- ~~Settings overlap: Scale/Accounts разнесены~~
- ~~Controls Screen скроллится~~
- ~~Emoji overflow fix: wrap_width <=240px + force re-wrap at 75%~~
- ~~Emoji keyboard: 6 страниц по 40 эмодзи, L1/R1~~
- ~~Реакции: отправка/снятие через контекстное меню (TDLib ≥1.8.1)~~
- ~~Toast-уведомления справа + плавное исчезновение ошибок/статусов~~
- ~~Выход из поиска/контекстного меню по B/MENU; фикс навигации медиа~~
- ~~Плавный скролл беседы + анимация появления меню/уведомлений~~
- ~~Режимы производительности: Eco 30 FPS / Performance 60 FPS~~
- ~~Переключатель VSync в настройках, сохранение в display.conf~~
- ~~2026-11-03 (TGmuOS-LOVE): краш-цепочка запуска LÖVE-клента —
  `media_methods.lua:38 attempt to call a table value` (недоделанный сплит
  media_playback); фикс = factory-стиль сплита media_playback_core +
  media_playback, удаление несовместимых фрагментов. Деплой dist/Telegram.zip
  на устройство (md5 совпадает).~~
- ~~2026-11-03 (TGmuOS-LOVE): `tdlib_client.lua:446 attempt to call method
  handle_file` — метод handle_file не был реализован после рефакторинга;
  реализован (нормализация file id, поиск media-entry, status
  downloading/remote → downloaded). Деплой, md5 совпадает.~~
- ~~2026-11-03 (TGmuOS-LOVE): `media_playback.lua:177 attempt to call
  media_file_for_message (a value nil)` — метод не был реализован;
  реализован в media_playback_core (dispatching по content @type → by_message
  карты → entry). Деплой, md5 совпадает.~~
- ~~2026-11-03 (TGmuos-LOVE): `tdlib_client.lua:520 attempt to call method
  handle_sticker_set` — метод не был реализован; реализован (sticker_set_viewer
  settle по поколению). Деплой, md5 совпадает.~~
- ~~2026-11-03: Эмодзи — NotoEmoji-Regular.ttf в пакете (fonts/), авто-переключение
  emoji-шрифта в ui_kit.lua; код-пайплайн (is_emoji + emoji_font_for) завершён.~~
