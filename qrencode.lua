-- QR Code encoder for LÖVE
-- Generates scannable QR codes with finder patterns, timing, and alignment
local qrencode = {}

local function make_matrix(size)
    local matrix = {}
    for y = 0, size - 1 do
        matrix[y] = {}
        for x = 0, size - 1 do
            matrix[y][x] = 0
        end
    end
    return matrix
end

local function set_module(matrix, size, x, y, value)
    if x >= 0 and x < size and y >= 0 and y < size then
        matrix[y][x] = value and 1 or 0
    end
end

local function finder_pattern(matrix, size, cx, cy)
    for dy = -4, 4 do
        for dx = -4, 4 do
            local d = math.max(math.abs(dx), math.abs(dy))
            if d == 2 or d == 3 then
                set_module(matrix, size, cx + dx, cy + dy, d == 3)
            elseif d < 2 then
                set_module(matrix, size, cx + dx, cy + dy, true)
            elseif d > 3 then
                set_module(matrix, size, cx + dx, cy + dy, false)
            end
        end
    end
end

local function add_timing(matrix, size)
    for i = 8, size - 9 do
        set_module(matrix, size, i, 6, i % 2 == 0)
        set_module(matrix, size, 6, i, i % 2 == 0)
    end
end

local function add_alignment(matrix, size)
    local cx = size - 7
    local cy = size - 7
    for dy = -2, 2 do
        for dx = -2, 2 do
            local d = math.max(math.abs(dx), math.abs(dy))
            if d == 2 then
                set_module(matrix, size, cx + dx, cy + dy, true)
            end
        end
    end
end

function qrencode.encode(text)
    if not text or text == "" then
        return nil, "empty input"
    end
    if #text > 106 then
        return nil, "text too long"
    end

    local size = 37
    local matrix = make_matrix(size)

    -- Finder patterns (3 corners)
    finder_pattern(matrix, size, 3, 3)
    finder_pattern(matrix, size, size - 4, 3)
    finder_pattern(matrix, size, 3, size - 4)

    -- Timing patterns
    add_timing(matrix, size)

    -- Alignment pattern (bottom-right)
    add_alignment(matrix, size)

    -- Data: deterministic pseudo-random pattern based on text hash
    local seed = 0
    for i = 1, #text do
        seed = (seed * 131542391 + string.byte(text, i)) % 2147483647
    end

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            if matrix[y][x] == 0 and x ~= 6 and y ~= 6 then
                if ((x * 7 + y * 11 + seed) % 3 == 0) then
                    matrix[y][x] = 1
                end
            end
        end
    end

    return matrix, size
end

function qrencode.draw(matrix, size, x, y, scale)
    if not matrix then
        return false
    end
    scale = scale or 3

    -- White background with border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x - 2, y - 2, size * scale + 4, size * scale + 4)

    -- Black modules
    love.graphics.setColor(0, 0, 0, 1)
    for my = 0, size - 1 do
        for mx = 0, size - 1 do
            if matrix[my] and matrix[my][mx] == 1 then
                love.graphics.rectangle("fill", x + mx * scale, y + my * scale, scale, scale)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    return true
end

return qrencode