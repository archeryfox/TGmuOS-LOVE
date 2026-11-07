# BACKLOG (единый)

## 2026-11-05 (WebM/стикеры, Управление)
- [x] WebM runtime pipeline на экране Управление (3sticker.webm)
- [x] Оптимизация webm-декода (FPS вдвое)
- [x] WebM-стикеры в диалогах
- [x] UI: экран Управление
- [ ] Проверить воспроизведение webm-стикеров в реальных диалогах
- [ ] Кэш-инвалидация/лимит для `anim_animation_*`
- [ ] Аудит `convert_to_gif` для webm

## Оптимизация загрузки чатов (2026-11-07)
- [x] HISTORY_PAGE_SIZE 10→50
- [x] MAX_MESSAGES_PER_CHAT = 500 с авто-обрезкой
- [ ] Downscaling oversized фото/стикеров в media_conversion.lua (макс. сторона 1024)

## Фичи на будущее
- Экран управления (Controls guide) — done
- Иконка приложения из res/telegram.png — done
- QWERTY клавиатура (EN/RU, Shift/Caps/Lang/Space/Backspace/Enter/Sym) — done
- Эмодзи клавиатура (6 страниц по 40, L1/R1) — done
- Эмодзи рендеринг: спрайт-атлас / ImageFont / NotoColorEmoji
- Emoji-шрифт (NotoEmoji-Regular.ttf) — добавить файл
- TGS/WEBM стикеры — базово 1 кадр, анимации работают
- Распределить все кнопки по функциям (gamepad mapping) — done
- Функция открытия профиля — done
- Добавление аккаунтов (Settings callbacks не подключены)
- Скорость видео
- Улучшить качество видео (FPS) — media playback работает
- Стикерпаки (выбор/отправление, полный стикерпак)
- Функция обновления клиента (через внешний репозиторий)
- Markdown basic render in messages
- ultra-Basic webView

## UI-fixes
- Реакции на сообщениях/постах — done
- Вызов контекстного меню для меню чатов (Y) — done; выход по той же кнопке либо B
- Анимации и плавности больше — done; на стрелки ^v плавное листание чата на 15px, переход по сообщениям на < >
- Расширять меню чатов в режиме Меню чатов, уменьшать в режиме диалога
- Добавить время просмотра
- Системные уведомления/ошибки — done
- Режим открытия фото

## Баги
- Эмоджи сломаны (NotoEmoji-Regular.ttf отсутствует в пакете)
- Нельзя выйти из поиска — B / MENU — done
- Нельзя выйти из контекстного меню выбора чата — B / MENU — done
- Зум/фулскрин медиа — перелистывание только первых медиа — done
- UI кривой — частично исправлено
- Эмодзи overflow — wrap_width ограничен, авто-рерасп на 75%
- +/- Масштаб в настройках — done
- Контекстное меню замутить/отправить в архив — нельзя отменить/покинуть по Y/B

## Критичное (по ревизии кода)
- Шифрование БД TDLib — encryption_key пока пустой
- Мультиаккаунт — settings_screen callbacks не подключены в main.lua
- README — не соответствует коду
- NotoEmoji-Regular.ttf — файл не в пакете

## Sprint Plan: Telegram Client for Anbernic RG35XX SP
### Критичное (блокирующее)
1. GIFs/animations не играют — messageAnimation не рендерится
2. Video notes (round videos) не грузятся
3. Videos не грузятся
4. QR re-auth при смене сети
5. Framebuffer double-buffering — 640x960 fb0, видна только страница 0

### Высокий приоритет
6. Уведомления не авто-очищаются — done (15s timeout)
7. Навигация по media album — только первый медиа
8. Нет прогресса загрузки медиа
9. Emoji rendering — missing NotoEmoji font
10. Выход из поиска по B — done

### Средний приоритет
11. Settings Scale — apply on Enter only
12. Controls screen scroll
13. VPN settings — полная интеграция
14. Emoji keyboard
15. Reply/Forward UI
16. Typing indicator — sendChatAction
17. Read receipts — viewMessages
