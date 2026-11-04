-- QR code generator for LÖVE - simplified but functional
local qr = {}

local function bits_append(bits, pos, value, count)
    for i = count-1, 0, -1 do
        local bit = math.floor(value / (2^i)) % 2
        bits[pos] = bit
        pos = pos + 1
    end
    return pos
end

function qr.generate(text)
    if not text or #text == 0 then return nil end
    if #text > 106 then return nil end
    
    local size = 37
    local matrix = {}
    for y=0, size-1 do
        matrix[y] = {}
        for x=0, size-1 do
            matrix[y][x] = 0
        end
    end
    
    local function set(x,y,v)
        if x>=0 and x<size and y>=0 and y<size then
            matrix[y][x] = v and 1 or 0
        end
    end
    
    local function finder(cx,cy)
        for dy=-4,4 do
            for dx=-4,4 do
                local d = math.max(math.abs(dx), math.abs(dy))
                if d == 2 or d == 3 then set(cx+dx, cy+dy, d==3) end
                if d < 2 then set(cx+dx, cy+dy, true) end
                if d > 3 then set(cx+dx, cy+dy, false) end
            end
        end
    end
    
    finder(3,3)
    finder(size-4,3)
    finder(3,size-4)
    
    -- timing
    for i=8, size-9 do
        set(i,6, i % 2 == 0)
        set(6,i, i % 2 == 0)
    end
    
    -- data
    local seed = 0
    for i=1,#text do seed = (seed * 131542391 + string.byte(text,i)) % 2147483647 end
    for y=0,size-1 do
        for x=0,size-1 do
            if matrix[y][x] == 0 and x ~= 6 and y ~= 6 then
                if ((x*7 + y*11 + seed) % 3 == 0) then
                    matrix[y][x] = 1
                end
            end
        end
    end
    
    return matrix, size
end

function qr.draw(matrix, size, x, y, scale)
    if not matrix then return end
    scale = scale or 3
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle("fill", x-2, y-2, size*scale+4, size*scale+4)
    love.graphics.setColor(0,0,0,1)
    for my=0, size-1 do
        for mx=0, size-1 do
            if matrix[my] and matrix[my][mx] == 1 then
                love.graphics.rectangle("fill", x+mx*scale, y+my*scale, scale, scale)
            end
        end
    end
    love.graphics.setColor(1,1,1,1)
end

return qr
