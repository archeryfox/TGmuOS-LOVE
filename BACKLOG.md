# BACKLOG (единый)

## 2026-11-05 (WebM/стикеры, Управление)
- [x] WebM runtime pipeline на экране Управление (3sticker.webm)
- [x] Оптимизация webm-декода (FPS вдвое)
- [x] WebM-стикеры в диалогах
- [x] UI: экран Управление
- [x] Проверить воспроизведение webm-стикеров в реальных диалогах
- [x] Кэш-инвалидация/лимит для `anim_animation_*`
- [x] Аудит `convert_to_gif` для webm

## Оптимизация загрузки чатов (2026-11-07)
- [x] HISTORY_PAGE_SIZE 10→50
- [x] MAX_MESSAGES_PER_CHAT = 500 с авто-обрезкой
- [ ] Downscaling oversized фото/стикеров в media_conversion.lua (макс. сторона 1024)

## Фичи на будущее
- [x] Экран управления (Controls guide) — done
- [x] Иконка приложения из res/telegram.png — done
- [x] QWERTY клавиатура (EN/RU, Shift/Caps/Lang/Space/Backspace/Enter/Sym) — done
- [x] Эмодзи клавиатура (6 страниц по 40, L1/R1) — done
- [x] Эмодзи рендеринг: спрайт-атлас / ImageFont / NotoColorEmoji
- [x] Emoji-шрифт (NotoEmoji-Regular.ttf) — добавить файл
- [x] TGS/WEBM стикеры — базово 1 кадр, анимации работают
- [ ] Распределить все кнопки по функциям (gamepad mapping) — done
- [x] Функция открытия профиля — done
- [x] Добавление аккаунтов — подключены в настройках (переключение аккаунтов)
- [x] Скорость видео
- [x] Улучшить качество видео (FPS) — media playback работает
- [x] Стикерпаки (выбор/отправление, полный стикерпак)
- [x] Функция обновления клиента (через внешний репозиторий)
- [ ] Markdown basic render in messages
- [ ] ultra-Basic webView

## UI-fixes
- [x] Реакции на сообщениях/постах — done
- [x] Вызов контекстного меню для меню чатов (Y) — done; выход по той же кнопке либо B
- [x] Анимации и плавности больше — done; на стрелки ^v плавное листание чата на 15px, переход по сообщениям на < >
- [x] Расширять меню чатов в режиме Меню чатов, уменьшать в режиме диалога
- [ ] Добавить время просмотра
- [x] Системные уведомления/ошибки — done
- [ ] Режим открытия фото

## Баги
- [ ] Эмоджи сломаны (NotoEmoji-Regular.ttf отсутствует в пакете)
- [ ] Нельзя выйти из поиска — B / MENU — done
- [x] Нельзя выйти из контекстного меню выбора чата — B / MENU — done
- [x] Зум/фулскрин медиа — перелистывание только первых медиа — done
- [ ] UI кривой — частично исправлено
- [ ] Эмодзи overflow — wrap_width ограничен, авто-рерасп на 75%
- [ ] +/- Масштаб в настройках — done
- [ ] Контекстное меню замутить/отправить в архив — нельзя отменить/покинуть по Y/B

## Критичное (по ревизии кода)
- Шифрование БД TDLib — encryption_key пока пустой
- [x] Мультиаккаунт — подключён аккаунт переключение в настройках
- README — не соответствует коду
- NotoEmoji-Regular.ttf — файл не в пакете

## Sprint Plan: Telegram Client for Anbernic RG35XX SP
### Критичное (блокирующее)
1. [x] GIFs/animations не играют — messageAnimation не рендерится
2. [x] Video notes (round videos) не грузятся
3. [x] Videos не грузятся
4. [ ] QR re-auth при смене сети
5. [x] Framebuffer double-buffering — 640x960 fb0, видна только страница 0

### Высокий приоритет
6. [ ] Уведомления не авто-очищаются — done (15s timeout)
7. [x] Стикеры не отправлялись — исправлено (pending_sticker_send при загрузке файла)
8. [x] Стикерпаки не грузятся (Request aborted / proxy) — исправлено через getInstalledStickerSets + searchStickerSet fallback
9. [x] Навигация по media album — только первый медиа
10. [x] Нет прогресса загрузки медиа
11. [ ] Emoji rendering — missing NotoEmoji font
12. [x] Выход из поиска по B — done

### Средний приоритет
11. [x] Settings Scale — apply on Enter only
12. [x] Controls screen scroll
13. [ ] VPN settings — полная интеграция
14. [x] Emoji keyboard
15. [ ] Reply/Forward UI
16. [ ] Typing indicator — sendChatAction
17. [x] Read receipts — viewMessages
