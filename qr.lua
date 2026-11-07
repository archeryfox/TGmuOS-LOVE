local bit = require("bit")

local qr = {}

local SIZE = 37
local DATA_CODEWORDS = 108
local ECC_CODEWORDS = 26
local TOTAL_CODEWORDS = DATA_CODEWORDS + ECC_CODEWORDS

local matrix = {}
local function_modules = {}

local function new_grid()
    local grid = {}
    for y = 0, SIZE - 1 do
        grid[y] = {}
        for x = 0, SIZE - 1 do
            grid[y][x] = 0
        end
    end
    return grid
end

local function reset_grids()
    matrix = new_grid()
    function_modules = new_grid()
end

local function append_bits(buffer, value, count)
    for i = count - 1, 0, -1 do
        buffer.n = buffer.n + 1
        buffer[buffer.n] = bit.band(bit.rshift(value, i), 1)
    end
end

local function gf_multiply(x, y)
    local result = 0
    for _ = 1, 8 do
        if bit.band(y, 1) == 1 then
            result = bit.bxor(result, x)
        end
        local high = bit.band(x, 0x80)
        x = bit.band(bit.lshift(x, 1), 0xff)
        if high ~= 0 then
            x = bit.bxor(x, 0x1d)
        end
        y = bit.rshift(y, 1)
    end
    return result
end

local function reed_solomon_remainder(data)
    local divisor = {}
    for i = 0, ECC_CODEWORDS - 1 do
        divisor[i] = 0
    end
    divisor[ECC_CODEWORDS - 1] = 1

    local root = 1
    for _ = 0, ECC_CODEWORDS - 1 do
        for j = 0, ECC_CODEWORDS - 1 do
            divisor[j] = gf_multiply(divisor[j], root)
            if j + 1 < ECC_CODEWORDS then
                divisor[j] = bit.bxor(divisor[j], divisor[j + 1])
            end
        end
        root = gf_multiply(root, 2)
    end

    local result = {}
    for i = 0, ECC_CODEWORDS - 1 do
        result[i] = 0
    end

    for i = 0, DATA_CODEWORDS - 1 do
        local factor = bit.bxor(data[i], result[0])
        for j = 0, ECC_CODEWORDS - 2 do
            result[j] = result[j + 1]
        end
        result[ECC_CODEWORDS - 1] = 0
        for j = 0, ECC_CODEWORDS - 1 do
            result[j] = bit.bxor(result[j], gf_multiply(divisor[j], factor))
        end
    end
    return result
end

local function set_function_module(x, y, dark)
    if x < 0 or x >= SIZE or y < 0 or y >= SIZE then
        return
    end
    matrix[y][x] = dark and 1 or 0
    function_modules[y][x] = 1
end

local function draw_finder(cx, cy)
    for dy = -4, 4 do
        for dx = -4, 4 do
            local distance = math.max(math.abs(dx), math.abs(dy))
            set_function_module(cx + dx, cy + dy, distance ~= 2 and distance <= 3)
        end
    end
end

local function draw_alignment(cx, cy)
    for dy = -2, 2 do
        for dx = -2, 2 do
            local distance = math.max(math.abs(dx), math.abs(dy))
            set_function_module(cx + dx, cy + dy, distance ~= 1)
        end
    end
end

local function format_bits()
    local value = 8
    local remainder = value
    for _ = 1, 10 do
        remainder = bit.bxor(bit.lshift(remainder, 1), bit.band(bit.rshift(remainder, 9), 1) * 0x537)
    end
    return bit.bxor(bit.bor(bit.lshift(value, 10), remainder), 0x5412)
end

local function draw_format()
    local bits = format_bits()
    for i = 0, 5 do
        set_function_module(8, i, bit.band(bit.rshift(bits, i), 1) == 1)
    end
    set_function_module(8, 7, bit.band(bit.rshift(bits, 6), 1) == 1)
    set_function_module(8, 8, bit.band(bit.rshift(bits, 7), 1) == 1)
    set_function_module(7, 8, bit.band(bit.rshift(bits, 8), 1) == 1)
    for i = 9, 14 do
        set_function_module(14 - i, 8, bit.band(bit.rshift(bits, i), 1) == 1)
    end

    for i = 0, 7 do
        set_function_module(SIZE - 1 - i, 8, bit.band(bit.rshift(bits, i), 1) == 1)
    end
    for i = 8, 14 do
        set_function_module(8, SIZE - 15 + i, bit.band(bit.rshift(bits, i), 1) == 1)
    end
    set_function_module(8, SIZE - 8, true)
end

local function draw_function_patterns()
    reset_grids()
    draw_finder(3, 3)
    draw_finder(SIZE - 4, 3)
    draw_finder(3, SIZE - 4)

    for i = 8, SIZE - 9 do
        set_function_module(6, i, i % 2 == 0)
        set_function_module(i, 6, i % 2 == 0)
    end
    draw_alignment(30, 30)
    draw_format()
end

local function draw_codewords(codewords)
    local bit_index = 0
    local upward = true
    local right = SIZE - 1

    while right >= 1 do
        if right == 6 then
            right = 5
        end

        for offset = 0, SIZE - 1 do
            local y = upward and (SIZE - 1 - offset) or offset
            for side = 0, 1 do
                local x = right - side
                if function_modules[y][x] == 0 then
                    local dark = 0
                    if bit_index < TOTAL_CODEWORDS * 8 then
                        local codeword = codewords[math.floor(bit_index / 8)]
                        dark = bit.band(bit.rshift(codeword, 7 - (bit_index % 8)), 1)
                        bit_index = bit_index + 1
                    end
                    if (x + y) % 2 == 0 then
                        dark = 1 - dark
                    end
                    matrix[y][x] = dark
                end
            end
        end

        upward = not upward
        right = right - 2
    end
end

function qr.encode(text)
    if type(text) ~= "string" or #text == 0 or #text > 106 then
        return nil
    end

    local data = {}
    for i = 0, DATA_CODEWORDS - 1 do
        data[i] = 0
    end

    local buffer = {n = 0}
    append_bits(buffer, 0x4, 4)
    append_bits(buffer, #text, 8)
    for i = 1, #text do
        append_bits(buffer, string.byte(text, i), 8)
    end

    local capacity = DATA_CODEWORDS * 8
    local terminator = capacity - buffer.n
    if terminator > 4 then
        terminator = 4
    end
    append_bits(buffer, 0, terminator)
    while buffer.n % 8 ~= 0 do
        append_bits(buffer, 0, 1)
    end

    local byte_count = math.floor(buffer.n / 8)
    for i = 0, byte_count - 1 do
        local value = 0
        for b = 0, 7 do
            if buffer[i * 8 + b + 1] == 1 then
                value = value + 2 ^ (7 - b)
            end
        end
        data[i] = value
    end
    for i = byte_count, DATA_CODEWORDS - 1 do
        data[i] = ((i - byte_count) % 2 == 1) and 0x11 or 0xec
    end

    local ecc = reed_solomon_remainder(data)
    local codewords = {}
    for i = 0, DATA_CODEWORDS - 1 do
        codewords[i] = data[i]
    end
    for i = 0, ECC_CODEWORDS - 1 do
        codewords[DATA_CODEWORDS + i] = ecc[i]
    end

    draw_function_patterns()
    draw_codewords(codewords)
    return matrix, SIZE
end

function qr.make_image(matrix, size)
    if not matrix or not size then
        return nil
    end
    local image_data = love.image.newImageData(size, size)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            if matrix[y] and matrix[y][x] == 1 then
                image_data:setPixel(x, y, 0, 0, 0, 1)
            else
                image_data:setPixel(x, y, 1, 1, 1, 1)
            end
        end
    end
    local image = love.graphics.newImage(image_data)
    image:setFilter("nearest", "nearest")
    return image
end

function qr.draw(image, x, y, scale, quiet_zone)
    if not image then
        return
    end
    quiet_zone = quiet_zone or 4
    local size = image:getWidth()
    local total = (size + quiet_zone * 2) * scale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, total, total)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x + quiet_zone * scale, y + quiet_zone * scale, 0, scale, scale)
end

return qr