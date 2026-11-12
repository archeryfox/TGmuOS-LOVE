// screen-editor — desktop layout/theme editor for the Telegram LÖVE client screens.
// Renders mock previews of chats / chat / settings / auth (640x480) using egui painter,
// with a live theme + layout editor and export to Lua.

use eframe::egui;
use egui::{Color32, Pos2, Rect, Rounding, Stroke, Vec2};

const SCREEN_W: f32 = 640.0;
const SCREEN_H: f32 = 480.0;
const HEADER_H: f32 = 56.0;
const CHAT_HEADER_H: f32 = 64.0;
const INPUT_H: f32 = 72.0;
const ITEM_H: f32 = 76.0;

#[derive(Clone, Debug)]
struct Theme {
    name: String,
    bg: [f32; 3],
    panel: [f32; 3],
    panel_alt: [f32; 3],
    header: [f32; 3],
    accent: [f32; 3],
    accent_dark: [f32; 3],
    text: [f32; 3],
    muted: [f32; 3],
    green: [f32; 3],
    red: [f32; 3],
    yellow: [f32; 3],
}

impl Theme {
    fn c(&self, which: &str) -> [f32; 3] {
        match which {
            "bg" => self.bg,
            "panel" => self.panel,
            "panel_alt" => self.panel_alt,
            "header" => self.header,
            "accent" => self.accent,
            "accent_dark" => self.accent_dark,
            "text" => self.text,
            "muted" => self.muted,
            "green" => self.green,
            "red" => self.red,
            "yellow" => self.yellow,
            _ => self.text,
        }
    }
    fn set(&mut self, which: &str, v: [f32; 3]) {
        match which {
            "bg" => self.bg = v,
            "panel" => self.panel = v,
            "panel_alt" => self.panel_alt = v,
            "header" => self.header = v,
            "accent" => self.accent = v,
            "accent_dark" => self.accent_dark = v,
            "text" => self.text = v,
            "muted" => self.muted = v,
            "green" => self.green = v,
            "red" => self.red = v,
            "yellow" => self.yellow = v,
            _ => {}
        }
    }
    fn to_lua(&self) -> String {
        let f = |a: [f32; 3]| format!("{{{:.2}, {:.2}, {:.2}}}", a[0], a[1], a[2]);
        format!(
            "    {} = {{\n        bg = {},\n        panel = {},\n        panel_alt = {},\n        header = {},\n        accent = {},\n        accent_dark = {},\n        text = {},\n        muted = {},\n        green = {},\n        red = {},\n        yellow = {},\n        white = {{1, 1, 1}},\n    }},",
            self.name, f(self.bg), f(self.panel), f(self.panel_alt), f(self.header),
            f(self.accent), f(self.accent_dark), f(self.text), f(self.muted),
            f(self.green), f(self.red), f(self.yellow)
        )
    }
    fn to_color32(&self, which: &str) -> Color32 {
        let v = self.c(which);
        color32(v)
    }
}

fn color32(v: [f32; 3]) -> Color32 {
    Color32::from_rgb((v[0] * 255.0) as u8, (v[1] * 255.0) as u8, (v[2] * 255.0) as u8)
}
fn color32a(v: [f32; 3], a: f32) -> Color32 {
    let c = color32(v);
    c.gamma_multiply(a.clamp(0.0, 1.0))
}

fn default_themes() -> Vec<Theme> {
    vec![
        Theme { name: "dark".into(), bg: [0.09,0.12,0.17], panel: [0.13,0.17,0.23], panel_alt: [0.16,0.21,0.28], header: [0.11,0.15,0.21], accent: [0.20,0.58,0.90], accent_dark: [0.14,0.42,0.68], text: [0.93,0.95,0.97], muted: [0.58,0.65,0.73], green: [0.35,0.90,0.48], red: [0.98,0.35,0.35], yellow: [1.00,0.80,0.25] },
        Theme { name: "light".into(), bg: [0.95,0.96,0.98], panel: [1.00,1.00,1.00], panel_alt: [0.92,0.93,0.96], header: [0.88,0.90,0.94], accent: [0.15,0.45,0.85], accent_dark: [0.10,0.32,0.62], text: [0.12,0.14,0.18], muted: [0.45,0.48,0.55], green: [0.15,0.60,0.30], red: [0.85,0.20,0.20], yellow: [0.80,0.60,0.10] },
        Theme { name: "redwine".into(), bg: [0.12,0.06,0.08], panel: [0.18,0.09,0.12], panel_alt: [0.22,0.12,0.16], header: [0.14,0.07,0.10], accent: [0.85,0.25,0.35], accent_dark: [0.60,0.18,0.25], text: [0.95,0.90,0.92], muted: [0.65,0.50,0.55], green: [0.40,0.85,0.50], red: [1.00,0.30,0.30], yellow: [1.00,0.75,0.30] },
        Theme { name: "bluemoon".into(), bg: [0.05,0.08,0.16], panel: [0.08,0.12,0.22], panel_alt: [0.10,0.16,0.28], header: [0.06,0.10,0.18], accent: [0.30,0.60,1.00], accent_dark: [0.20,0.45,0.80], text: [0.90,0.95,1.00], muted: [0.50,0.60,0.75], green: [0.30,0.85,0.55], red: [0.95,0.35,0.40], yellow: [1.00,0.85,0.30] },
        Theme { name: "xmas".into(), bg: [0.05,0.12,0.08], panel: [0.08,0.18,0.12], panel_alt: [0.10,0.22,0.16], header: [0.06,0.14,0.10], accent: [0.90,0.20,0.20], accent_dark: [0.65,0.15,0.15], text: [0.95,1.00,0.95], muted: [0.55,0.70,0.60], green: [0.30,0.85,0.40], red: [0.95,0.25,0.25], yellow: [1.00,0.85,0.30] },
        Theme { name: "hackers".into(), bg: [0.02,0.06,0.02], panel: [0.04,0.10,0.04], panel_alt: [0.05,0.13,0.05], header: [0.03,0.08,0.03], accent: [0.20,0.95,0.30], accent_dark: [0.12,0.70,0.20], text: [0.30,1.00,0.40], muted: [0.25,0.60,0.30], green: [0.20,0.95,0.30], red: [0.95,0.25,0.25], yellow: [0.95,0.95,0.20] },
        Theme { name: "violet".into(), bg: [0.10,0.06,0.16], panel: [0.14,0.09,0.22], panel_alt: [0.18,0.12,0.28], header: [0.12,0.07,0.18], accent: [0.65,0.30,0.95], accent_dark: [0.45,0.20,0.70], text: [0.95,0.92,1.00], muted: [0.60,0.55,0.70], green: [0.40,0.85,0.55], red: [0.95,0.30,0.45], yellow: [1.00,0.80,0.30] },
    ]
}

#[derive(Clone, Copy, PartialEq)]
enum Screen { Chats, Chat, Settings, Auth }

struct App {
    themes: Vec<Theme>,
    theme_idx: usize,
    screen: Screen,
    // layout
    header_h: f32,
    chat_header_h: f32,
    input_h: f32,
    item_h: f32,
    scale: f32,
    export: String,
}

impl Default for App {
    fn default() -> Self {
        Self {
            themes: default_themes(),
            theme_idx: 0,
            screen: Screen::Chats,
            header_h: HEADER_H,
            chat_header_h: CHAT_HEADER_H,
            input_h: INPUT_H,
            item_h: ITEM_H,
            scale: 1.0,
            export: String::new(),
        }
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::TopBottomPanel::top("top").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading("Telegram Screen Editor");
                ui.separator();
                ui.label("Screen:");
                ui.selectable_value(&mut self.screen, Screen::Chats, "Chats");
                ui.selectable_value(&mut self.screen, Screen::Chat, "Chat");
                ui.selectable_value(&mut self.screen, Screen::Settings, "Settings");
                ui.selectable_value(&mut self.screen, Screen::Auth, "Auth");
                ui.separator();
                ui.label("Theme:");
                egui::ComboBox::from_id_salt("theme")
                    .selected_text(&self.themes[self.theme_idx].name)
                    .show_ui(ui, |ui| {
                        for (i, t) in self.themes.iter().enumerate() {
                            ui.selectable_value(&mut self.theme_idx, i, &t.name);
                        }
                    });
                if ui.button("Export Lua").clicked() {
                    self.export = self.themes[self.theme_idx].to_lua();
                }
            });
        });

        egui::SidePanel::right("props").default_width(280.0).show(ctx, |ui| {
            self.theme_editor_ui(ui);
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            self.preview_ui(ui);
        });

        if !self.export.is_empty() {
            egui::Window::new("Lua theme export").show(ctx, |ui| {
                ui.set_width(420.0);
                ui.label("Paste into src/shared/ui/ui_kit.lua ui.themes:");
                ui.add(egui::TextEdit::multiline(&mut self.export).desired_rows(12).code_editor());
                if ui.button("Copy").clicked() {
                    ctx.copy_text(self.export.clone());
                }
                if ui.button("Close").clicked() {
                    self.export.clear();
                }
            });
        }
    }
}

impl App {
    fn theme(&self) -> &Theme { &self.themes[self.theme_idx] }

    fn theme_editor_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading("Theme");
        let names = ["bg","panel","panel_alt","header","accent","accent_dark","text","muted","green","red","yellow"];
        let mut updates: Vec<(String,[f32;3])> = Vec::new();
        for name in names {
            let col = self.themes[self.theme_idx].c(name);
            let mut rgb = [
                (col[0].powf(1.0/2.2) * 255.0) as u8,
                (col[1].powf(1.0/2.2) * 255.0) as u8,
                (col[2].powf(1.0/2.2) * 255.0) as u8,
            ];
            ui.horizontal(|ui| {
                ui.label(name);
                if ui.color_edit_button_srgb(&mut rgb).changed() {
                    let lin = [
                        (rgb[0] as f32 / 255.0).powf(2.2),
                        (rgb[1] as f32 / 255.0).powf(2.2),
                        (rgb[2] as f32 / 255.0).powf(2.2),
                    ];
                    updates.push((name.to_string(), lin));
                }
            });
        }
        for (n, v) in updates {
            self.themes[self.theme_idx].set(&n, v);
        }

        ui.separator();
        ui.heading("Layout");
        ui.add(egui::Slider::new(&mut self.header_h, 40.0..=80.0).text("Header height"));
        ui.add(egui::Slider::new(&mut self.chat_header_h, 48.0..=88.0).text("Chat header height"));
        ui.add(egui::Slider::new(&mut self.input_h, 56.0..=96.0).text("Input height"));
        ui.add(egui::Slider::new(&mut self.item_h, 60.0..=100.0).text("Item height"));
        ui.add(egui::Slider::new(&mut self.scale, 0.5..=2.0).text("Preview zoom"));

        ui.separator();
        if ui.button("Reset layout").clicked() {
            self.header_h = HEADER_H; self.chat_header_h = CHAT_HEADER_H;
            self.input_h = INPUT_H; self.item_h = ITEM_H; self.scale = 1.0;
        }
        ui.label("Screen: 640×480 (RG35XX SP native)");
    }

    fn preview_ui(&mut self, ui: &mut egui::Ui) {
        let avail = ui.available_size();
        let scale = self.scale.min(avail.x / SCREEN_W).min(avail.y / SCREEN_H);
        let draw_w = SCREEN_W * scale;
        let draw_h = SCREEN_H * scale;
        let (rect, _resp) = ui.allocate_exact_size(Vec2::new(draw_w, draw_h), egui::Sense::hover());
        let painter = ui.painter_at(rect);
        let ox = rect.min.x;
        let oy = rect.min.y;
        // map screen coords (0..640, 0..480) to rect
        let map = |x: f32, y: f32| Pos2::new(ox + x * scale, oy + y * scale);
        let srect = |x: f32, y: f32, w: f32, h: f32| Rect::from_min_max(map(x, y), map(x + w, y + h));
        let th = self.theme().clone();

        // background
        painter.rect_filled(srect(0.0, 0.0, SCREEN_W, SCREEN_H), Rounding::ZERO, color32(th.bg));

        match self.screen {
            Screen::Chats => self.draw_chats(&painter, &th, &map, &srect, scale),
            Screen::Chat => self.draw_chat(&painter, &th, &map, &srect, scale),
            Screen::Settings => self.draw_settings(&painter, &th, &map, &srect, scale),
            Screen::Auth => self.draw_auth(&painter, &th, &map, &srect, scale),
        }

        // border
        painter.rect_stroke(srect(0.0, 0.0, SCREEN_W, SCREEN_H), Rounding::ZERO, Stroke::new(1.0, Color32::GRAY));
    }

    fn text(&self, p: &egui::Painter, map: &impl Fn(f32,f32)->Pos2, x: f32, y: f32, s: &str, size: f32, col: Color32, scale: f32) {
        let pos = map(x, y);
        p.text(pos, egui::Align2::LEFT_TOP, s, egui::FontId::proportional(size * scale), col);
    }

    fn draw_chats(&self, p: &egui::Painter, th: &Theme, map: &impl Fn(f32,f32)->Pos2, srect: &impl Fn(f32,f32,f32,f32)->Rect, scale: f32) {
        // header
        p.rect_filled(srect(0.0, 0.0, SCREEN_W, self.header_h), Rounding::ZERO, color32(th.header));
        self.text(p, map, 16.0, (self.header_h - 20.0)/2.0, "Telegram", 18.0, color32(th.text), scale);
        // search pill
        p.rect_filled(srect(SCREEN_W - 160.0, 14.0, 144.0, 28.0), Rounding::same(14.0*scale), color32(th.panel_alt));
        self.text(p, map, SCREEN_W - 150.0, 20.0, "🔍 Поиск", 12.0, color32(th.muted), scale);

        // chat list
        let chats = [
            ("Алиса", "Привет! Как дела?", "12:30", true, 2),
            ("Работа", "Отчёт готов, проверь", "11:02", true, 0),
            ("Мама", "Позвони вечером", "Вчера", false, 1),
            ("Друзья", "Кто идёт в пятницу?", "Вчера", false, 5),
            ("Канал Новости", "Срочные новости дня", "Пн", false, 12),
        ];
        let mut y = self.header_h;
        for (i, (name, msg, time, unread, badge)) in chats.iter().enumerate() {
            let selected = i == 0;
            if selected {
                p.rect_filled(srect(0.0, y, SCREEN_W, self.item_h), Rounding::ZERO, color32(th.panel_alt));
            }
            // avatar
            let av = 48.0;
            let ax = 12.0; let ay = y + (self.item_h - av)/2.0;
            p.rect_filled(srect(ax, ay, av, av), Rounding::same((av/2.0)*scale), color32a(th.accent, if *unread {1.0} else {0.5}));
            self.text(p, map, ax + av/2.0 - 6.0, ay + av/2.0 - 10.0, &name.chars().next().unwrap().to_string(), 16.0, color32(th.text), scale);
            // name
            self.text(p, map, ax + av + 12.0, y + 12.0, name, 14.0, color32(th.text), scale);
            // time
            self.text(p, map, SCREEN_W - 70.0, y + 12.0, time, 11.0, color32(th.muted), scale);
            // message
            self.text(p, map, ax + av + 12.0, y + 36.0, msg, 12.0, color32(th.muted), scale);
            // unread badge
            if *badge > 0 {
                let bx = SCREEN_W - 34.0; let by = y + self.item_h - 26.0;
                p.rect_filled(srect(bx, by, 22.0, 18.0), Rounding::same(9.0*scale), color32(th.accent));
                self.text(p, map, bx + 6.0, by + 2.0, &badge.to_string(), 10.0, color32(th.text), scale);
            }
            // divider
            if i < chats.len() - 1 {
                p.line_segment([map(ax + av + 12.0, y + self.item_h), map(SCREEN_W - 12.0, y + self.item_h)], Stroke::new(1.0, color32a(th.muted, 0.2)));
            }
            y += self.item_h;
            if y > SCREEN_H { break; }
        }
    }

    fn draw_chat(&self, p: &egui::Painter, th: &Theme, map: &impl Fn(f32,f32)->Pos2, srect: &impl Fn(f32,f32,f32,f32)->Rect, scale: f32) {
        // chat header
        p.rect_filled(srect(0.0, 0.0, SCREEN_W, self.chat_header_h), Rounding::ZERO, color32(th.header));
        self.text(p, map, 16.0, (self.chat_header_h-20.0)/2.0, "‹", 22.0, color32(th.accent), scale);
        self.text(p, map, 48.0, 12.0, "Алиса", 16.0, color32(th.text), scale);
        self.text(p, map, 48.0, 34.0, "в сети", 11.0, color32(th.muted), scale);
        // avatar
        p.rect_filled(srect(SCREEN_W-52.0, 12.0, 40.0, 40.0), Rounding::same(20.0*scale), color32a(th.accent, 0.6));

        // messages
        let msgs = [
            (false, "Привет! Как дела?"),
            (true,  "Привет! Всё отлично, работаю."),
            (false, "Что нового?"),
            (true,  "Да всё по плану, скоро отчёт."),
        ];
        let mut y = self.chat_header_h + 12.0;
        for (out, txt) in msgs {
            let bw = 320.0; let bh = 44.0;
            let bx = if out { SCREEN_W - bw - 16.0 } else { 16.0 };
            let bg = if out { th.accent_dark } else { th.panel_alt };
            p.rect_filled(srect(bx, y, bw, bh), Rounding::same(12.0*scale), color32(bg));
            self.text(p, map, bx + 12.0, y + 12.0, txt, 13.0, color32(th.text), scale);
            y += bh + 8.0;
        }

        // input bar
        let iy = SCREEN_H - self.input_h;
        p.rect_filled(srect(0.0, iy, SCREEN_W, self.input_h), Rounding::ZERO, color32(th.header));
        p.rect_filled(srect(12.0, iy + 16.0, SCREEN_W - 80.0, 40.0), Rounding::same(20.0*scale), color32(th.panel_alt));
        self.text(p, map, 28.0, iy + 28.0, "Сообщение…", 13.0, color32(th.muted), scale);
        // send button
        p.rect_filled(srect(SCREEN_W - 56.0, iy + 16.0, 40.0, 40.0), Rounding::same(20.0*scale), color32(th.accent));
        self.text(p, map, SCREEN_W - 44.0, iy + 24.0, "➤", 16.0, color32(th.text), scale);
    }

    fn draw_settings(&self, p: &egui::Painter, th: &Theme, map: &impl Fn(f32,f32)->Pos2, srect: &impl Fn(f32,f32,f32,f32)->Rect, scale: f32) {
        // header
        p.rect_filled(srect(0.0, 0.0, SCREEN_W, self.header_h), Rounding::ZERO, color32(th.header));
        self.text(p, map, 16.0, (self.header_h-20.0)/2.0, "Настройки", 18.0, color32(th.text), scale);

        let rows = [
            ("Тема", "dark", true),
            ("VPN / Прокси", "Выключено", false),
            ("Автоплей видео", "Вкл", true),
            ("Автоплей стикеров", "Вкл", true),
            ("Прокси", "127.0.0.1:10808", false),
            ("Масштаб", "0.9", true),
            ("Обои", "Выкл", true),
        ];
        let mut y = self.header_h + 8.0;
        for (label, val, _toggle) in rows {
            let ry = y;
            p.rect_filled(srect(8.0, ry, SCREEN_W - 16.0, 52.0), Rounding::same(8.0*scale), color32a(th.panel, 0.6));
            self.text(p, map, 20.0, ry + 8.0, label, 13.0, color32(th.text), scale);
            self.text(p, map, 20.0, ry + 28.0, val, 11.0, color32(th.muted), scale);
            // toggle pill
            p.rect_filled(srect(SCREEN_W - 68.0, ry + 16.0, 44.0, 22.0), Rounding::same(11.0*scale), color32(if _toggle { th.green } else { th.muted }));
            y += 56.0;
        }
    }

    fn draw_auth(&self, p: &egui::Painter, th: &Theme, map: &impl Fn(f32,f32)->Pos2, srect: &impl Fn(f32,f32,f32,f32)->Rect, scale: f32) {
        // title
        self.text(p, map, SCREEN_W/2.0 - 100.0, 30.0, "Telegram", 26.0, color32(th.text), scale);
        self.text(p, map, SCREEN_W/2.0 - 90.0, 66.0, "Авторизация", 14.0, color32(th.muted), scale);

        // QR code (fake)
        let qr = 180.0;
        let qx = (SCREEN_W - qr)/2.0; let qy = 100.0;
        p.rect_filled(srect(qx, qy, qr, qr), Rounding::same(8.0*scale), Color32::WHITE);
        // draw fake QR modules
        let mut seed: u32 = 12345;
        let cell = qr / 21.0;
        for gy in 0..21 {
            for gx in 0..21 {
                seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
                if (seed >> 16) & 1 == 1 {
                    let cx = qx + gx as f32 * cell;
                    let cy = qy + gy as f32 * cell;
                    p.rect_filled(srect(cx, cy, cell, cell), Rounding::ZERO, Color32::BLACK);
                }
            }
        }

        // VPN button
        let by = qy + qr + 24.0;
        p.rect_filled(srect(qx, by, qr, 44.0), Rounding::same(8.0*scale), color32(th.accent));
        self.text(p, map, qx + qr/2.0 - 60.0, by + 12.0, "Настройки VPN", 14.0, color32(th.text), scale);

        self.text(p, map, 20.0, SCREEN_H - 24.0, "↑↓ — выбор   A — выбрать   MENU — выход", 10.0, color32(th.muted), scale);
    }
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1000.0, 640.0])
            .with_title("Telegram Screen Editor"),
        ..Default::default()
    };
    eframe::run_native(
        "Telegram Screen Editor",
        options,
        Box::new(|_cc| Ok(Box::new(App::default()))),
    )
}