local ffi = require("ffi")
local json = require("dkjson")

ffi.cdef[[
  void* td_json_client_create();
  void td_json_client_send(void* client, const char* request);
  const char* td_json_client_receive(void* client, double timeout);
  void td_json_client_destroy(void* client);
  void td_set_log_file_path(const char* file_path);
  void td_set_log_max_file_size(long long max_log_file_size);
  void td_set_log_verbosity_level(int verbosity_level);
]]

local lib = ffi.load("/mnt/mmc/MUOS/application/tgmuos_love/lib/libtdjson.so")
print("lib loaded")
local client = lib.td_json_client_create()
print("client created:", client)

lib.td_set_log_verbosity_level(1)

local req = [[{"@type":"setTdlibParameters","database_directory":"/tmp/test_worker","files_directory":"/tmp/test_worker_files","use_test_dc":false,"api_id":39311583,"api_hash":"cf10bc1f7475e0ceaf2d7e219455b6aa","system_language_code":"ru","device_model":"Anbernic","system_version":"muOS","application_version":"1.0","enable_storage_optimizer":true}]]
lib.td_json_client_send(client, req)
print("sent setTdlibParameters")

for i = 1, 60 do
  local resp = lib.td_json_client_receive(client, 1)
  if resp then
    local str = ffi.string(resp)
    if str:match("authorizationStateWaitPhoneNumber") then
      print("QR state reached!")
      -- Request QR
      local req2 = [[{"@type":"requestQrCodeAuthentication","other_user_ids":[]}]]
      lib.td_json_client_send(client, req2)
      print("sent requestQrCodeAuthentication")
      for j = 1, 30 do
        local resp2 = lib.td_json_client_receive(client, 1)
        if resp2 then
          local str = ffi.string(resp2)
          if str:match("authorizationStateWaitOtherDeviceConfirmation") then
            print("QR LINK FOUND!")
            print(str)
            break
          end
        end
      end
      break
    elseif str:match("authorizationStateWaitOtherDeviceConfirmation") then
      print("QR LINK:", str)
      break
    end
  end
end

print("done")
love.event.quit()
