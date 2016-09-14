# Resty Minecraft Query
Library to query Minecraft servers for [OpenResty][1]

OpenResty 的 Minecraft 服务器信息查询工具


There is only a 'ping' method to query basic infomation for Minecraft version newer than 1.7 now. Developing is ongoing.

只实现了一个 ping 的功能，用来查询服务器的基本信息，而且还不支持老版本服务器。有空持续更新:P
```lua
local mcq = require 'mcquery.ping'

--[[ local server = mcq:new(
    host,    ip 地址，字符串
    port,    端口，数字，可选，默认 25565
    timeout  超时时间，毫秒，数字，可选，默认 1000
    )
]]--
local server, err = mcq:new('192.168.123.222')

if not server then
    ngx.say(err)
    return
end

local json, err = server:ping()

if not json then
    ngx.say(err)
    return
end

ngx.say(json)
```


  [1]: http://openresty.org/