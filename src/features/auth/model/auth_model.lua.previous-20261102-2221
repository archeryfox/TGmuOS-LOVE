-- src/features/auth/model/auth_model.lua — состояние авторизации
local auth_model = {}

local STATE_TEXT = {
    starting = "Запуск TDLib...",
    authorizationStateWaitTdlibParameters = "Инициализация параметров...",
    authorizationStateWaitPhoneNumber = "Запрос QR-кода...",
    authorizationStateWaitOtherDeviceConfirmation = "Ожидание сканирования QR-кода",
    authorizationStateWaitPassword = "Введите пароль двухфакторной аутентификации",
    authorizationStateReady = "Готово",
    authorizationStateClosed = "Соединение закрыто",
}

function auth_model.new(tg)
    local self = {}
    self.tg = tg
    self.qr_link = nil
    self.qr_image = nil
    self.qr_size = 0
    self.password_mode = false
    self.password = ""
    return setmetatable(self, {__index = auth_model})
end

function auth_model:get_status_text()
    return STATE_TEXT[self.tg.auth_state] or self.tg.auth_state or "Подключение..."
end

function auth_model:has_error()
    return self.tg.auth_error and self.tg.auth_error ~= ""
end

function auth_model:get_error()
    return self.tg.auth_error or ""
end

function auth_model:is_qr_ready()
    return self.qr_image ~= nil
end

function auth_model:is_password_mode()
    return self.tg.auth_state == "authorizationStateWaitPassword"
end

function auth_model:get_password_hint()
    return self.tg.password_hint or ""
end

return auth_model
