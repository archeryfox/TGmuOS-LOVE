local fb = io.open(/dev/fb0, rb)
if fb then
    fb:seek(set, 0)
    local data = fb:read(640*480*4)
    fb:close()
    print(Framebuffer size:, #data)
    -- Check if there's non-zero data
    local non_zero = 0
    for i = 1, #data do
        if data:byte(i) > 0 then non_zero = non_zero + 1 end
    end
    print(Non-zero pixels:, non_zero)
else
    print(Cannot open fb0)
end
