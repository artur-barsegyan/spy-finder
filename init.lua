#!/usr/bin/env tarantool

local console = require('console')

local work_dir = os.getenv("TARANTOOL_WORK_DIR") or '.'
local instance_name = os.getenv("TARANTOOL_INSTANCE_NAME")
local console_sock = os.getenv("TARANTOOL_CONSOLE_SOCK")

local base_listen = os.getenv("TARANTOOL_BASE_LISTEN") or 3300
local listen = os.getenv("TARANTOOL_LISTEN") or 3301

-- When starting multiple instances of the app from systemd,
-- instance_name will contain the part after the "@". e.g.  for
-- myapp@instance_1, instance_name will contain "instance_1".
-- Then we use the suffix to assign port number, so that
-- listen port will be base_listen + suffix
if instance_name ~= nil then
    print("Instance name: " .. instance_name)

    local instance_no = string.match(instance_name, "_(%d+)$")
    if instance_no ~= nil then
        listen = base_listen + tonumber(instance_no)
    end
end

box.cfg({
        work_dir = work_dir,
        listen = listen
})

if console_sock ~= nil then
    console.listen('unix/:' .. console_sock)
end
