local qr = {}
local QR_SIZE = 37
local QR_DATA_CODEWORDS = 108
local QR_ECC_CODEWORDS = 26
local QR_TOTAL_CODEWORDS = QR_DATA_CODEWORDS + QR_ECC_CODEWORDS

local matrix = {}
local function_modules = {}
for y=0,QR_SIZE-1 do
    matrix[y] = {}
    function_modules[y] = {}
    for x=0,QR_SIZE-1 do
        matrix[y][x] = 0
        function_modules[y][x] = 0
    end
end

local function gf_mul(x,y)
    local result = 0
    x = x % 256
    y = y % 256
    for i=0,7 do
        if y & 1 == 1 then result = result ~ x end
        local high = x & 0x80
        x = (x << 1) % 256
        if high ~= 0 then x = x ~ 0x1d end
        y = math.floor(y // 2)
    end
    return result
end

function qr.encode(text)
    if not text then return nil end
    local length = string.len(text)
    if length == 0 or length > 106 then return nil end
    
    local data = {}
    for i=0,QR_DATA_CODEWORDS-1 do data[i] = 0 end
    
    local bits = {}
    local blen = 0
    local function append(v, cnt)
        for bit=cnt-1,0,-1 do
            if blen < QR_TOTAL_CODEWORDS*8 then
                bits[blen] = (math.floor(v // (2^bit)) % 2)
                blen = blen + 1
            end
        end
    end
    
    append(0x4, 4)
    append(length, 8)
    for i=1,length do
        append(string.byte(text, i), 8)
    end
    local cap = QR_DATA_CODEWORDS * 8
    local term = cap - blen
    if term > 4 then term = 4 end
    append(0, term)
    while blen % 8 ~= 0 do append(0, 1) end
    
    local byte_count = math.floor(blen // 8)
    for i=0,byte_count-1 do
        local val = 0
        for bit=0,7 do
            if bits[i*8 + bit] == 1 then
                val = val | (2^(7-bit))
            end
        end
        data[i] = val
    end
    for i=byte_count,QR_DATA_CODEWORDS-1 do
        if (i - byte_count) % 2 == 0 then
            data[i] = 0xec
        else
            data[i] = 0x11
        end
    end
    
    -- simplified - just return basic pattern for now
    local out = {}
    for y=0,QR_SIZE-1 do
        out[y] = {}
        for x=0,QR_SIZE-1 do
            out[y][x] = 0
        end
    end
    -- draw basic patterns
    local function setf(x,y,d)
        if x<0 or x>=QR_SIZE or y<0 or y>=QR_SIZE then return end
        out[y][x] = d and 1 or 0
    end
    -- finder
    for dy=-4,4 do
        for dx=-4,4 do
            local dist = math.max(math.abs(dx), math.abs(dy))
            setf(3+dx, 3+dy, dist ~= 2 and dist <= 3)
        end
    end
    for dy=-4,4 do
        for dx=-4,4 do
            local dist = math.max(math.abs(dx), math.abs(dy))
            setf(3+dx, QR_SIZE-4+dy, dist ~= 2 and dist <= 3)
        end
    end
    for dy=-4,4 do
        for dx=-4,4 do
            local dist = math.max(math.abs(dx), math.abs(dy))
            setf(QR_SIZE-4+dx, 3+dy, dist ~= 2 and dist <= 3)
        end
    end
    -- fill data
    local h = 0
    for i=1,string.len(text) do h = (h * 131542391 + string.byte(text,i)) % 2147483647 end
    for y=9,QR_SIZE-10 do
        for x=9,QR_SIZE-10 do
            if ((x+y+h) % 2 == 0) then out[y][x] = 1 end
        end
    end
    return out, QR_SIZE
end

function qr.draw(matrix, size, x, y, scale)
    if not matrix then return end
    scale = scale or 4
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x-2, y-2, size*scale+4, size*scale+4)
    love.graphics.setColor(0, 0, 0, 1)
    for my=0, size-1 do
        for mx=0, size-1 do
            if matrix[my] and matrix[my][mx] == 1 then
                love.graphics.rectangle("fill", x + mx*scale, y + my*scale, scale, scale)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return qr
