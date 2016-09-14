local bit = require 'bit'
local tcp = ngx.socket.tcp
local byte = string.byte
local char = string.char

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local function _read_varint(sock)
    local int = 0
    for i = 0, 4 do
        local data, err = sock:receive(1)
        if not data then
            return nil, err
        end
        data = byte(data)
        local last = data < 0x80
        data = data % 0x80
        if i > 0 then
            for j = 1, i do
                data = data * 0x80
            end
        end
        int = int + data
        if last then
            int = bit.band(int, 0xffffffff)
            if int > 0x7fffffff then
                return int - 0x100000000
            else
                return int
            end
        end
    end
    return nil, 'varint overflow'
end

local function _varint(number)
    if number > 0x7fffffff or number < -0x80000000 then
        return nil, 'number overflow'
    end
    if number < 0 then
        number = number + 0x100000000
    end
    local c = ''
    repeat
        local part = number % 0x80
        number = bit.rshift(number, 7)
        if number > 0 then
            part = part + 0x80
        end
        c = c .. char(part)
    until 0 == number
    return c
end

local function _ushort(number)
    if number > 0xffff or number < 0 then
        return nil, 'number overflow'
    end
    local part = number % 256
    local c = char(part)
    part = bit.rshift(number, 8)
    c = char(part) .. c
    return c
end

local function _read_reply(sock)
    local length, err = _read_varint(sock)
    if not length then
        sock:close()
        return nil, err
    end

    local packet_id , err = _read_varint(sock)
    if not packet_id then
        sock:close()
        return nil, err
    end

    local json_length, err = _read_varint(sock)
    if not json_length then
        sock:close()
        return nil, err
    end

    local data, err = sock:receive(json_length)
    if not data then
        sock:close()
        return nil, err
    end

    sock:close()
    return data
end

local _M = new_tab(0, 8)
_M._VERSION = '0.10'

local mt = { __index = _M }

function _M.new(self, host, port, timeout)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    if not host then
        return nil, 'host ip address required'
    end
    port = port or 25565
    timeout = timeout or 1000
    return setmetatable({
        sock = sock,
        host = host,
        port = port,
        timeout = timeout,
    }, mt)
end

function _M.ping(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    
    local timeout = self.timeout
    sock:settimeout(timeout)
    
    local host, port = self.host, self.port
    ok, err = sock:connect(host, port)
    if not ok then
        return nil, err
    end
    
    local data = string.rep('%s', 5):format(
        _varint(0x00),-- Packat ID (Hnadshake)
        _varint(0x04),-- Protocol Version
        --String data must follow a varint describing its length
        _varint(#self.host) .. self.host,
        _ushort(self.port),
        _varint(0x01)-- Next state (1 for status request)
    )
    --All sent data must follow a varint describing its length
    data = _varint(#data) .. data
    local bytes, err = sock:send(data)
    if not bytes then
        sock:close()
        return nil, err
    end
    -- Packet ID 0 (type: status request) with a prefixed varint of length
    bytes, err = sock:send(char(0x01) .. char(0x00))
    if not bytes then
        sock:close()
        return nil, err
    end
    return _read_reply(sock)
end

return _M