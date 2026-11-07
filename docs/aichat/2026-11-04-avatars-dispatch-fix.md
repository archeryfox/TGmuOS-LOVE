# 2026-11-04 — фикс потерянного media-dispatch + A/B раскладка

## Что выяснено

- **Аватарки пропали** из-за неполного сплита `media_methods` (REFACTOR_PLAN п.4):
  новый `handle_file` (`src/shared/api/tdlib_client.lua:689`, в сборке 18:50)
  только помечал `entry.status = "downloaded"` — вызовов `load_user_photo` /
  `load_chat_photo` / `load_photo` не осталось (в старой сборке они были в
  `media_methods.lua:513–534`). Файлы скачивались, но `entry.image` никогда
  не создавался → `chat_item.lua` рисовал кружок-заглушку.
- Той же поломкой накрыло фото сообщений, видео/гифки (queue_media_decode
  без `source_path`), голосовые/аудио. Стикеры выжили — у `ensure_sticker`
  (`media_stickers.lua:44`) осталась inline-проверка `file["local"]`.
- **A/B раскладка** («кнопка А всё ещё кнопка B»): в новой сборке появилась
  автоопределение (`main.lua:31–80`, muOS swap / `/tmp/con_go` / controls.conf,
  тумблер в настройках). Точная причина неработоспособности не подтверждена на
  устройстве (консоль была офлайн); кандидаты: инверсия семантики
  `swap=1` (qa-док писал 1=modern), сохранённый `controls.conf` перекрывает
  muOS, статичные подписи в controls_screen. Требует проверки на консоли.

## Изменения кода (2026-11-04)

- `src/shared/api/tdlib_client.lua` — `handle_file` восстановлен по образцу
  старого `media_methods.lua`: ветки `user_photos`/`chat_photos`/`photos`/
  `stickers`/`animations`/`videos`/`voice`/`audio`, `source_path`, progress,
  autoplay-очередь decode.
- `src/shared/api/media_videos.lua` — добавлены `load_video`, `load_animation`.
- `src/shared/api/media_audio.lua` — добавлены `load_voice_note`, `load_audio`.
- Сборка `dist/Telegram.zip` пересобрана.

## Деплой по adb (2026-11-04)

- Серийник `bc001080a5104871f12`, приложение `/mnt/mmc/MUOS/application/Telegram`.
- Остановка `pkill -TERM -x love.aarch64`, бэкап каталога
  `Telegram.backup-<ts>`, unzip `Telegram.zip` поверх, удалён стейл
  `src/features/auth/ui/tdlib_client.lua`.
- Перед остановкой левого процесса: только our own LÖVE Telegram (PID 11280),
  TGMUOS/sing-boxCVE не трогали.

## 2026-11-05 — продолжение: GIF/видео регрессия + превью + fullscreen

- **Главная причина «GIF/видео не грузятся»**: в `choose_animation_size` /
  `choose_video_size` потерялся уровень вложенности TDLib (`content.animation.animation`
  и `content.video.video`). Файл-объект всегда **вложен**: `content.video` = объект
  `video { file: {...}, thumbnail: {...}, minithumbnail: {...} }` — `animation` там
  же сам содержит файл в поле `animation`. Проверено дампом content в `ensure_animation`.
- **Webm-стикеры**: `ensure_sticker` (media_stickers) для `stickerFormatWebm/Tgs` теперь
  конвертирует первый кадр (ffmpeg `-frames:v 1` через `convert_to_png`) → статический
  `entry.image`.
- **Fullscreen для GIF**: `chat_screen_input.activate_focused_message` для
  `messageAnimation` открывает `fullscreen_media = {kind="animation"}` + `request_media_playback`;
  `media_renderer` добавлена ветка `fullscreen.kind == "animation"`.
- **Autoplay GIF off**: `ensure_animation` ставит `entry.autoplay = false`; autoplay
  включается только через `request_media_playback` (A / fullscreen / toggle).
- **Decode retry**: при `MEDIA: decode fail` (ffmpeg «moov atom not found» и т.п.) для
  video/animation/sticker: `deleteFile` + повторный `downloadFile` (2 попытки), и человекочитаемое
  сообщение об ошибке.
- **Производительность**: `display.conf` принудительно `mode=performance` (60 FPS) при деплое
  (`TG_PERF_MODE=performance`, vsync=1). Eco 30 FPS — причина «очень туго работает».

## Проблемы окружения (кейс дня)

- «LÖVE runtime not found: /bin/love» — писали не лаунчеры, а **muOS frontend loop**: он читает
  `/tmp/act_go` каждую итерацию и при `app` перезапускает приложение; при гонках с нашими launch-ами
  вылезало то, что видел `sh -x` — настоящий source: не лаунчер. (Решено: ставить `/tmp/act_go`
  в `launcher` и одерживать единственный люб-инстанс.)
- TDLib `messageUnsupported` — у части GIF-сообщений (content пустой) — обход через
  превью thumbnail, full-file download + frames decode.
