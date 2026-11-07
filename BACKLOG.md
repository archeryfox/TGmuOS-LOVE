# BACKLOG

## 2026-11-05 (WebM/стикеры, Управление)

- [x] **WebM runtime pipeline на экране Управление (3sticker.webm)**: `webm → png-кадры` напрямую в рантайме движка (без GIF), превью первого кадра, декод через `queue_media_decode`/`poll_media_decoder`, автостарт воспроизведения, стадия пайплайна в UI, L1 — пуск/пауза/перезапуск. Файл: `src/features/help/ui/controls_screen.lua`.
- [x] **Оптимизация webm-декода**: для `.webm` (в т.ч. `stickerFormatWebm`) FPS уменьшается вдвое при планировании кадров (меньше кадров/нагрузка). Файл: `threads/anim_decode.lua`.
- [x] **WebM-стикеры в диалогах (в т.ч. режим файла)**: `stickerFormatWebm` обрабатывается напрямую (`webm → png-кадры`, без GIF), превью через `convert_to_png`, fallback для TGS сохранён. Файл: `src/shared/api/media_stickers.lua`.
- [x] **UI: экран Управление** — иконка WebM, подпись о runtime-конвейере, отображение стадий загрузки/декода.

## Замечания / follow-up
- [ ] Проверить воспроизведение webm-стикеров в реальных диалогах (messageSticker/messageDocument webm) на устройстве.
- [ ] При необходимости добавить кэш-инвалидацию/лимит для `anim_animation_*` каталогов.
- [ ] Убедиться, что `convert_to_gif` больше не используется для webm в остальных путях (аудит).
