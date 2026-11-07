local ffi = require('ffi')

ffi.cdef[[
    int open(const char *pathname, int flags);
    int write(int fd, const void *buf, size_t count);
    int close(int fd);
]]

local fb_pageflip = {}
fb_pageflip.__index = fb_pageflip

local pan_fd = nil
local current_page = 0
local screen_height = 480

function fb_pageflip.init()
    if pan_fd then return true end
    
    pan_fd = ffi.C.open('/sys/class/graphics/fb0/pan', 1) -- O_WRONLY
    if pan_fd < 0 then
        return false
    end
    
    return true
end

function fb_pageflip.flip()
    if not pan_fd then
        if not fb_pageflip.init() then
            return false
        end
    end
    
    current_page = 1 - current_page
    local yoffset = current_page * screen_height
    
    local buf = '0,' .. yoffset .. '\n'
    ffi.C.write(pan_fd, buf, #buf)
    
    return true
end

function fb_pageflip.get_current_page()
    return current_page
end

function fb_pageflip.shutdown()
    if pan_fd then
        ffi.C.close(pan_fd)
        pan_fd = nil
    end
end

return fb_pageflip