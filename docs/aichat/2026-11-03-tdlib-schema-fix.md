# 2026-11-03 — TDLib JSON schema fix (QR/auth)

Статус: в работе. Приложение `tgmuos_love` (порт `love_tg_native`) использует
встроенный `libtdjson.so` 1.8.0, а клиент отправлял схему от более новой TDLib.

Найдено на устройстве (192.168.0.151):

- `setTdlibParameters` с полями верхнего уровня → `400 Parameters aren't specified`.
  Для 1.8.0 нужен вложенный `parameters` (проверено).
- `addProxy` с вложенным `proxy` → `400 Proxy type must be non-empty`.
  Для 1.8.0 нужны плоские `server`/`port`/`type` (проверено).
- `authorizationStateWaitEncryptionKey` не обрабатывался → авторизация зависала.
- Прокси: рабочий путь — host `192.168.0.178:10808` (SOCKS5), прямой выход на
  `api.telegram.org` у провайдера заблокирован.

Сделано в `src/shared/api/tdlib_client.lua`: адаптивная схема (flat → nested при
ошибке), обработка `WaitEncryptionKey`, QR запрашивается после успешного addProxy.
Важно: `addProxy` возвращает объект `proxy`, а не `ok` — без обработки этого типа
`proxy_ready` не выставлялся и QR не запрашивался. Проверено на устройстве:
запрос 6 = `requestQrCodeAuthentication`, состояние
`authorizationStateWaitOtherDeviceConfirmation`.

UI: экран авторизации переверстан под 640×480 (меню из 3 кнопок раньше вылезало
за нижнюю границу; теперь 349–460 px, всё влезает).

Маршрутизация: локальный `muvpn_love` sing-box поднимает `muvpn0` и уводит
192.168.0.178 в сломанный туннель (`Connection reset`). Для работы через host-proxy
его пришлось остановить; при необходимости VPN нужен split-route/исключение
host-proxy. Секреты в заметке не приводятся.
