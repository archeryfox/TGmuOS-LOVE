-- src/shared/api/html_render.lua
-- HTML parser for the in-app HTML viewer.
-- parse() returns styled blocks: text runs (color/bold/italic/code) + images,
-- with block background and alignment. convert() returns plain text.

local html_render = {}

local NAMED = {
    red = {1,0.27,0.27}, green = {0.29,0.87,0.5}, blue = {0.24,0.63,0.9},
    white = {1,1,1}, black = {0,0,0}, gray = {0.5,0.5,0.5}, grey = {0.5,0.5,0.5},
    yellow = {1,0.85,0.3}, orange = {1,0.6,0.2}, purple = {0.65,0.3,0.95},
    pink = {1,0.5,0.7}, cyan = {0.3,0.9,0.9}, magenta = {1,0.3,1},
    silver = {0.75,0.75,0.75}, maroon = {0.5,0,0}, navy = {0,0,0.5},
}

local function parse_color(s)
    if not s then return nil end
    s = s:match("^%s*(.-)%s*$"):lower()
    if s == "transparent" or s == "inherit" or s == "none" then return nil end
    local hex6 = s:match("^#(%x%x%x%x%x%x)$")
    if hex6 then
        return {tonumber(hex6:sub(1,2),16)/255, tonumber(hex6:sub(3,4),16)/255, tonumber(hex6:sub(5,6),16)/255}
    end
    local hex3 = s:match("^#(%x%x%x)$")
    if hex3 then
        local r = tonumber(hex3:sub(1,1):rep(2),16)/255
        local g = tonumber(hex3:sub(2,2):rep(2),16)/255
        local b = tonumber(hex3:sub(3,3):rep(2),16)/255
        return {r,g,b}
    end
    local r,g,b = s:match("^rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
    if r then return {tonumber(r)/255, tonumber(g)/255, tonumber(b)/255} end
    return NAMED[s]
end

local function parse_style(s)
    local out = {}
    if not s then return out end
    for decl in s:gmatch("([^;]+)") do
        local k, v = decl:match("([^:]+):(.+)")
        if k and v then
            k = k:match("^%s*(.-)%s*$"):lower()
            v = v:match("^%s*(.-)%s*$")
            out[k] = v
        end
    end
    return out
end

-- Parse CSS rules ".cls { prop: val; }" into class -> declarations map.
local function parse_css(css)
    local classes = {}
    if not css then return classes end
    for selector, body in css:gmatch("([^{}]+)%n?{([^}]*)}") do
        for cls in selector:gmatch("%.([%w_%-]+)") do
            local decls = parse_style(body)
            classes[cls] = classes[cls] or {}
            for k, v in pairs(decls) do classes[cls][k] = v end
        end
    end
    return classes
end

local function decode_entities(s)
    s = s:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
    s = s:gsub("&#39;", "'"):gsub("&apos;", "'"):gsub("&hellip;", "…")
    s = s:gsub("&mdash;", "—"):gsub("&ndash;", "–"):gsub("&copy;", "©"):gsub("&reg;", "®"):gsub("&trade;", "™")
    s = s:gsub("&#%d+;", ""):gsub("&%w+;", "")
    return s
end

local BLOCK = { p=1, div=1, section=1, article=1, tr=1, header=1, footer=1, table=1, ul=1, ol=1, li=1, blockquote=1, pre=1, h1=1, h2=1, h3=1, h4=1, h5=1, h6=1 }
local HEADING = { h1=1, h2=1, h3=1, h4=1, h5=1, h6=1 }

-- Parse HTML into styled blocks.
-- Block = { type="text", style=..., runs={{text,color,bold,italic,code}}, bg=color, align=... }
--      or { type="image", src=... }
--      or { type="hr" }
function html_render.parse(html)
    local blocks = {}
    if not html or html == "" then return blocks end

    local i, len = 1, #html
    local skip = nil
    local cur_block = nil      -- current block table
    local block_style = "p"
    local block_bg = nil
    local block_align = "left"
    local inline = {}          -- stack of inline styles {color,bold,italic,code,bg}
    local block_stack = {}     -- stack of block styles {bg, align}
    local runs = {}
    local css_classes = {}     -- class name -> declarations
    local style_buf = nil      -- capture <style> content

    local function cur_bg()
        for i = #block_stack, 1, -1 do
            if block_stack[i].bg then return block_stack[i].bg end
        end
        return nil
    end
    local function cur_align()
        for i = #block_stack, 1, -1 do
            if block_stack[i].align and block_stack[i].align ~= "left" then return block_stack[i].align end
        end
        return "left"
    end
    local function push_block(bg, align) block_stack[#block_stack + 1] = { bg = bg, align = align } end
    local function pop_block() if #block_stack > 0 then table.remove(block_stack) end end

    local function cur_inline()
        local c, b, it, code, bg = nil, false, false, false, nil
        for _, s in ipairs(inline) do
            if s.color then c = s.color end
            if s.bold then b = true end
            if s.italic then it = true end
            if s.code then code = true end
            if s.bg then bg = s.bg end
        end
        return c, b, it, code, bg
    end

    local function flush()
        if cur_block then
            if #runs > 0 then
                cur_block.runs = runs
                blocks[#blocks + 1] = cur_block
            end
        end
        runs = {}
        cur_block = nil
    end

    local function start_block(style, bg, align, color)
        flush()
        cur_block = { type = "text", style = style or "p",
            bg = bg or cur_bg(),
            align = (align and align ~= "left") and align or cur_align(),
            color = color }
    end

    local function add_run(text)
        if not text or text == "" then return end
        text = decode_entities(text):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return end
        local c, b, it, code, _ = cur_inline()
        runs[#runs + 1] = { text = text, color = c, bold = b, italic = it, code = code }
    end

    while i <= len do
        local lt = html:find("<", i)
        if not lt then
            if skip == "style" then
                if style_buf then style_buf[#style_buf + 1] = html:sub(i) end
            elseif not skip then
                add_run(html:sub(i))
            end
            break
        end
        if lt > i then
            if skip == "style" then
                if style_buf then style_buf[#style_buf + 1] = html:sub(i, lt - 1) end
            elseif not skip then
                add_run(html:sub(i, lt - 1))
            end
        end
        local gt = html:find(">", lt + 1)
        if not gt then break end
        local tag = html:sub(lt + 1, gt - 1)
        local is_close = tag:sub(1, 1) == "/"
        local name = tag:match("^/?([%w]+)")
        if name then name = name:lower() end
        local style_attr = tag:match('style%s*=%s*["\']([^"\']*)["\']') or tag:match("style%s*=%s*([^%s>]+)")
        local class_attr = tag:match('class%s*=%s*["\']([^"\']*)["\']') or tag:match("class%s*=%s*([^%s>]+)")
        -- effective style = class declarations merged with inline (inline wins)
        local st = {}
        if class_attr then
            for cls in class_attr:gmatch("([%w_%-]+)") do
                local cs = css_classes[cls]
                if cs then for k, v in pairs(cs) do st[k] = v end end
            end
        end
        for k, v in pairs(parse_style(style_attr)) do st[k] = v end

        if skip then
            if is_close and name == skip then
                if skip == "style" then
                    css_classes = parse_css(table.concat(style_buf or {}))
                    style_buf = nil
                end
                skip = nil
            end
            i = gt + 1
        elseif name == "script" then
            flush(); skip = "script"; i = gt + 1
        elseif name == "style" then
            flush(); skip = "style"; style_buf = {}; i = gt + 1
        elseif name == "img" and not is_close then
            flush()
            local src = tag:match('src%s*=%s*["\']([^"\']*)["\']') or tag:match("src%s*=%s*([^%s>]+)")
            if src and src ~= "" then blocks[#blocks + 1] = { type = "image", src = src } end
            i = gt + 1
        elseif name == "br" then
            runs[#runs + 1] = { text = "\n" }
            i = gt + 1
        elseif name == "hr" then
            flush(); blocks[#blocks + 1] = { type = "hr" }; i = gt + 1
        elseif HEADING[name] and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            local al = st["text-align"]
            push_block(bg, al); start_block(name, bg, al, parse_color(st["color"]))
            block_style = name; block_bg = bg; block_align = al or "left"
            i = gt + 1
        elseif HEADING[name] and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "li" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("li", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "li" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "blockquote" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("quote", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "blockquote" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "pre" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("code", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "pre" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "div" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("div", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "div" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "p" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("p", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "p" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif name == "table" or name == "tr" then
            flush(); i = gt + 1
        elseif name == "td" and not is_close then
            local bg = parse_color(st["background-color"] or st["background"])
            push_block(bg, st["text-align"]); start_block("td", bg, st["text-align"], parse_color(st["color"]))
            i = gt + 1
        elseif name == "td" and is_close then
            flush(); pop_block(); i = gt + 1
        elseif BLOCK[name] then
            flush(); i = gt + 1
        elseif (name == "b" or name == "strong") and not is_close then
            inline[#inline + 1] = { bold = st["font-weight"] ~= "normal" }
            i = gt + 1
        elseif (name == "b" or name == "strong") and is_close then
            table.remove(inline); i = gt + 1
        elseif (name == "i" or name == "em") and not is_close then
            inline[#inline + 1] = { italic = true }
            i = gt + 1
        elseif (name == "i" or name == "em") and is_close then
            table.remove(inline); i = gt + 1
        elseif name == "code" and not is_close then
            inline[#inline + 1] = { code = true }
            i = gt + 1
        elseif name == "code" and is_close then
            table.remove(inline); i = gt + 1
        elseif name == "mark" and not is_close then
            inline[#inline + 1] = { bg = parse_color(st["background-color"]) or {1,0.9,0.3} }
            i = gt + 1
        elseif name == "mark" and is_close then
            table.remove(inline); i = gt + 1
        elseif name == "span" and not is_close then
            inline[#inline + 1] = { color = parse_color(st["color"]), bold = st["font-weight"] == "bold", italic = st["font-style"] == "italic" }
            i = gt + 1
        elseif name == "span" and is_close then
            table.remove(inline); i = gt + 1
        elseif name == "a" and not is_close then
            inline[#inline + 1] = { color = parse_color(st["color"]) }
            i = gt + 1
        elseif name == "a" and is_close then
            table.remove(inline); i = gt + 1
        else
            i = gt + 1
        end
    end
    flush()
    return blocks
end

function html_render.convert(html_text, max_width)
    local blocks = html_render.parse(html_text)
    local out = {}
    for _, b in ipairs(blocks) do
        if b.type == "text" then
            local line = ""
            for _, r in ipairs(b.runs or {}) do line = line .. r.text end
            if b.style == "li" then line = "• " .. line end
            if b.style == "quote" then line = "│ " .. line end
            out[#out + 1] = line
        elseif b.type == "image" then
            out[#out + 1] = "[изображение]"
        elseif b.type == "hr" then
            out[#out + 1] = "────────────────"
        end
    end
    return table.concat(out, "\n")
end

return html_render