local ffi = require("ffi")
ffi.cdef[[
  void* td_json_client_create();
  void td_json_client_send(void* client, const char* request);
  const char* td_json_client_receive(void* client, double timeout);
  void td_json_client_destroy(void* client);
  void td_set_log_file_path(const char* file_path);
  void td_set_log_verbosity_level(int verbosity_level);
]]
local lib = ffi.load("/mnt/mmc/MUOS/application/CTupe/bin/libs.aarch64/libtdjson.so")
print("lib loaded")
local client = lib.td_json_client_create()
lib.td_set_log_verbosity_level(1)
local req = [[{"@type":"setTdlibParameters","database_directory":"/tmp/test","files_directory":"/tmp/test_files","use_test_dc":false,"api_id":39311583,"api_hash":"cf10bc1f7475e0ceaf2d7e219455b6aa","system_language_code":"ru","device_model":"Anbernic","system_version":"muOS","application_version":"1.0","enable_storage_optimizer":true}]]
lib.td_json_client_send(client, req)
print("sent")
local resp = lib.td_json_client_receive(client, 10)
print("resp:", resp and ffi.string(resp) or "timeout")
