-- src/shared/api/tdlib_auth.lua
-- Extracted from tdlib_client.lua - authentication flow

local tdlib_auth = {}

function tdlib_auth.setup(tdlib)
    tdlib.auth_state = "authorizationStateWaitTdlibParameters"
    tdlib.auth_error = ""
    tdlib.qr_link = ""
    tdlib.qr_request_pending = false
    tdlib.qr_requested_at = 0
    tdlib.ready = false
    tdlib.current_chat_id = nil
    tdlib.me = nil
    tdlib.chats_by_id = {}
    tdlib.archive_chats_by_id = {}
    tdlib.chat_filters = {}
    tdlib.proxy_added = false
    tdlib.proxy_ready = false
    tdlib.proxy_ready_at = 0
    tdlib.connection_state = "connectionStateWaitingForNetwork"
    tdlib.download_state_cache = {}
end

function tdlib_auth.request_qr(tdlib)
    if tdlib.auth_state ~= "authorizationStateWaitPhoneNumber" then return false end
    tdlib.qr_request_pending = true
    tdlib.qr_requested_at = love.timer.getTime()
    tdlib:send({
        ["@type"] = "requestQrCodeAuthentication",
        other_user_ids = {},
    }, "qr")
    return true
end

function tdlib_auth.handle_authorization(tdlib, state)
    tdlib.auth_state = state["@type"]
    
    if state["@type"] == "authorizationStateWaitTdlibParameters" then
        tdlib:send_tdlib_parameters()
        
    elseif state["@type"] == "authorizationStateWaitEncryptionKey" then
        tdlib:send({
            ["@type"] = "checkDatabaseEncryptionKey",
            encryption_key = "",
        }, "encryption_key")
        
    elseif state["@type"] == "authorizationStateWaitPhoneNumber" then
        -- QR will be requested via request_qr()
        
    elseif state["@type"] == "authorizationStateWaitOtherDeviceConfirmation" then
        tdlib.qr_link = state.link or ""
        tdlib.qr_request_pending = false
        
    elseif state["@type"] == "authorizationStateWaitCode" then
        -- Handle 2FA code input
        
    elseif state["@type"] == "authorizationStateWaitPassword" then
        -- Handle 2FA password input
        
    elseif state["@type"] == "authorizationStateReady" then
        tdlib.ready = true
        tdlib.auth_error = ""
        tdlib:send({["@type"] = "getMe"}, "me")
        tdlib:send({["@type"] = "getChats", chat_list = {["@type"] = "chatListMain"}, limit = 15}, "loadChats")
        tdlib:send({["@type"] = "getChatFilters"}, "chatFilters")
        
    elseif state["@type"] == "authorizationStateClosed" then
        tdlib.ready = false
        
    elseif state["@type"] == "authorizationStateLoggingOut" then
        tdlib.auth_error = "Выходим из аккаунта..."
        
    elseif state["@type"] == "authorizationStateWaitRegistration" then
        tdlib.auth_error = "Требуется регистрация"
    end
end

function tdlib_auth.submit_code(tdlib, code)
    if tdlib.auth_state ~= "authorizationStateWaitCode" then return false end
    tdlib:send({
        ["@type"] = "checkAuthenticationCode",
        code = code,
    }, "auth_code")
    return true
end

function tdlib_auth.submit_password(tdlib, password)
    if tdlib.auth_state ~= "authorizationStateWaitPassword" then return false end
    tdlib:send({
        ["@type"] = "checkAuthenticationPassword",
        password = password,
    }, "auth_password")
    return true
end

function tdlib_auth.handle_qr_result(tdlib, object)
    if object["@type"] == "error" then
        tdlib.qr_request_pending = false
        tdlib.auth_error = object.message or "QR error"
    elseif object["@type"] == "ok" then
        tdlib.qr_request_pending = false
    end
end

function tdlib_auth.update_qr_polling(tdlib, dt)
    if tdlib.auth_state ~= "authorizationStateWaitPhoneNumber" then return end
    local has_proxy = tdlib.options and tdlib.options.proxy
    if not has_proxy or tdlib.proxy_ready then
        if tdlib.qr_request_pending and love.timer.getTime() - tdlib.qr_requested_at >= 30 then
            tdlib.qr_request_pending = false
        end
        if not tdlib.qr_request_pending and love.timer.getTime() - tdlib.qr_requested_at >= 3 then
            tdlib:request_qr()
        end
    end
end

return tdlib_auth