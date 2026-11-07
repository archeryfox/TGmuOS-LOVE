-- src/features/chat/ui/renderers/input_renderer.lua
-- Extracted from chat_screen.lua - draws the input area

local ui = require("src.shared.ui.ui_kit")

local input_renderer = {}

function input_renderer.draw(ms, panel_x, panel_w, h)
    local f = ms.fonts
    local colors = ui.colors
    local input_x = panel_x + 16
    local input_y = h - INPUT_HEIGHT + 16
    local send_w = 96
    local input_w = panel_w - 32 - send_w - 12

    ui.rect(panel_x, h - INPUT_HEIGHT, panel_w, INPUT_HEIGHT, colors.header)
    ui.rect(input_x, input_y, input_w, 42, colors.panel_alt, 8)
    ui.outline(input_x, input_y, input_w, 42, colors.accent_dark, 8)

    local shown = ms.model.input
    if shown == "" then shown = "Сообщение..." end
    ui.text(ui.fit(shown, f.normal, input_w - 24), input_x + 12, input_y + 11, f.normal, ms.model.input == "" and colors.muted or colors.text)

    ui.rect(input_x + input_w + 12, input_y, send_w, 42, colors.accent, 8)
    ui.printf("Отправить", input_x + input_w + 12, input_y + 11, send_w, "center", f.small, colors.text)
end

return input_renderer