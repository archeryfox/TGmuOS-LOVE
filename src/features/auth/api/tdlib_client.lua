-- src/features/auth/api/tdlib_client.lua — TDLib клиент (части, относящиеся к auth)
local auth_api = {}

function auth_api.request_qr(tg)
    tg.qr_requested_at = love.timer.getTime()
    tg:send({
        ["@type"] = "requestQrCodeAuthentication",
        other_user_ids = {},
    }, "qr")
end

function auth_api.submit_password(tg, password)
    if not password or password == "" then return end
    tg:send({
        ["@type"] = "checkAuthenticationPassword",
        password = password,
    }, "password")
end

return auth_api
