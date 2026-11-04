-- src/shared/api/tdlib_proxy.lua
-- Extracted from tdlib_client.lua - proxy management

local tdlib_proxy = {}

function tdlib_proxy.setup(tdlib)
    tdlib.proxy_added = false
    tdlib.proxy_ready = false
    tdlib.proxy_ready_at = 0
end

function tdlib_proxy.add_proxy(tdlib, proxy)
    if not proxy or not proxy.type or not proxy.server or not proxy.port then
        tdlib.auth_error = "Invalid proxy configuration"
        return false
    end
    
    tdlib:send({
        ["@type"] = "addProxy",
        server = proxy.server,
        port = proxy.port,
        enable = true,
        proxy_type = tdlib_proxy.get_proxy_type(proxy.type),
    }, "add_proxy")
    
    tdlib.proxy_added = true
    return true
end

function tdlib_proxy.get_proxy_type(type_str)
    local types = {
        mtproto = {["@type"] = "proxyTypeMtproto", secret = ""},
        socks5 = {["@type"] = "proxyTypeSocks5", username = "", password = ""},
        http = {["@type"] = "proxyTypeHttp", username = "", password = ""},
    }
    return types[type_str] or {["@type"] = "proxyTypeSocks5"}
end

function tdlib_proxy.enable_proxy(tdlib, proxy_id)
    tdlib:send({
        ["@type"] = "enableProxy",
        proxy_id = proxy_id,
    }, "enableProxy")
end

function tdlib_proxy.disable_proxy(tdlib, proxy_id)
    tdlib:send({
        ["@type"] = "disableProxy",
        proxy_id = proxy_id,
    }, "disableProxy")
end

function tdlib_proxy.remove_proxy(tdlib, proxy_id)
    tdlib:send({
        ["@type"] = "removeProxy",
        proxy_id = proxy_id,
    }, "removeProxy")
end

function tdlib_proxy.get_proxies(tdlib)
    tdlib:send({
        ["@type"] = "getProxies",
    }, "getProxies")
end

function tdlib_proxy.handle_proxy(tdlib, object)
    if object["@type"] == "proxy" then
        if object.is_enabled then
            tdlib.proxy_ready = true
            tdlib.proxy_ready_at = love.timer.getTime()
        end
    end
end

return tdlib_proxy