local ffi = require('ffi')

ffi.cdef[[
    int open(const char *pathname, int flags);
    int write(int fd, const void *buf, size_t count);
    int close(int fd);
    int usleep(useconds_t usec);
]]

local function flip_page(yoffset)
    local fd = ffi.C.open('/sys/class/graphics/fb0/pan', 1) -- O_WRONLY
    if fd >= 0 then
        local buf = '0,' .. yoffset .. '\n'
        ffi.C.write(fd, buf, #buf)
        ffi.C.close(fd)
    end
end

local page = 0
while true do
    flip_page(page * 480)
    page = 1 - page
    ffi.C.usleep(16666) -- ~60fps page flip
end
