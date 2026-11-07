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

## Оптимизация загрузки чатов (2026-11-07)

- [x] `HISTORY_PAGE_SIZE` увеличен с 10 до 50 в `src/shared/api/message_methods.lua` — меньше круговых запросов TDLib при загрузке истории, чаты с большой историей грузятся быстрее.
- [x] `MAX_MESSAGES_PER_CHAT = 500` с авто-обрезкой (`prune_messages`) в `message_methods.lua` — предотвращает неограниченный рост `self.messages[chat_id]` на длинных диалогах, снижает потребление памяти.
- [x] Рассмотреть Downscaling oversized фото/стикеров в `media_conversion.lua:load_image()` (макс. сторона 1024) — снизить расход VRAM на устройстве.
