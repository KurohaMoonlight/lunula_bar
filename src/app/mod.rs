pub mod layout;

use std::sync::Arc;
use std::time::{Duration, Instant};
use chrono::Timelike;
use winit::{
    application::ApplicationHandler,
    dpi::{PhysicalPosition, PhysicalSize},
    event::{ElementState, KeyEvent, MouseButton, WindowEvent},
    event_loop::ActiveEventLoop,
    keyboard::{KeyCode, PhysicalKey},
    window::{Window, WindowAttributes, WindowId, WindowLevel},
};

use crate::config::FlyoutTheme;
use crate::flyout::{ActiveFlyout, DragTarget, FlyoutManager, SubFlyoutKind, FLY_RISE};
use crate::platform;
use crate::render;

pub struct App {
    window: Option<Arc<Window>>,
    renderer: Option<render::glob::GlobRenderer>,
    screen_w: u32,
    screen_h: u32,
    window_h: u32,
    target_anim: f32,
    current_anim: f32,
    anim_velocity: f32,
    last_frame_time: Instant,
    leave_timer: Option<Instant>,
    pull_strength: f32,
    pull_velocity: f32,
    prev_mouse_pos: (f32, f32),
    mouse_speed: f32,
    mouse_slosh: f32,
    slosh_velocity: f32,
    flyout_mgr: FlyoutManager,
    is_exiting: bool,
    diagnose_mode: bool,
    diagnose_step: u32,
    diagnose_frame: u32,
}

impl App {
    pub fn new(diagnose_mode: bool) -> Self {
        Self {
            window: None,
            renderer: None,
            screen_w: 1440,
            screen_h: 900,
            window_h: 648,
            target_anim: 1.0,
            current_anim: 0.0,
            anim_velocity: 0.0,
            last_frame_time: Instant::now(),
            leave_timer: None,
            pull_strength: 0.0,
            pull_velocity: 0.0,
            prev_mouse_pos: (-1000.0, -1000.0),
            mouse_speed: 0.0,
            mouse_slosh: 0.0,
            slosh_velocity: 0.0,
            flyout_mgr: FlyoutManager::new(),
            is_exiting: false,
            diagnose_mode,
            diagnose_step: 0,
            diagnose_frame: 0,
        }
    }

    fn set_active_theme(&mut self, theme: FlyoutTheme) {
        match self.flyout_mgr.active {
            ActiveFlyout::Volume => self.flyout_mgr.config.volume.theme = theme,
            ActiveFlyout::Battery => self.flyout_mgr.config.battery.theme = theme,
            ActiveFlyout::Wifi => self.flyout_mgr.config.wifi.theme = theme,
            ActiveFlyout::None => self.flyout_mgr.config.volume.theme = theme,
        }
    }

    fn cursor_pos() -> (i32, i32) {
        let mut pt = windows::Win32::Foundation::POINT { x: 0, y: 0 };
        if unsafe { windows::Win32::UI::WindowsAndMessaging::GetCursorPos(&mut pt).is_ok() } {
            (pt.x, pt.y)
        } else {
            (-1, -1)
        }
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }

        let monitor = event_loop
            .primary_monitor()
            .or_else(|| event_loop.available_monitors().next());
        let (screen_w, screen_h) = monitor
            .map(|m| (m.size().width, m.size().height))
            .unwrap_or((1440, 900));

        self.screen_w = screen_w;
        self.screen_h = screen_h;
        self.window_h = layout::dynamic_window_height(screen_h);

        let pos_y = screen_h.saturating_sub(self.window_h);
        let window_attrs = WindowAttributes::default()
            .with_title("Lunula Bar")
            .with_decorations(false)
            .with_transparent(true)
            .with_visible(false)
            .with_inner_size(PhysicalSize::new(screen_w, self.window_h))
            .with_position(PhysicalPosition::new(0, pos_y as i32))
            .with_window_level(WindowLevel::AlwaysOnTop)
            .with_resizable(false);

        let window = Arc::new(
            event_loop
                .create_window(window_attrs)
                .expect("Failed to create window"),
        );

        platform::win_utils::setup_transparent_window(&window);

        let font_family = self.flyout_mgr.config.typography.body_font.clone();
        let mut renderer =
            pollster::block_on(render::glob::GlobRenderer::new(window.clone(), &font_family));
        renderer.render();

        let bar_width = (screen_w as f32) * 0.50;
        let cx = (screen_w as f32) * 0.5;
        platform::win_utils::update_hittest_zones(
            screen_h as i32 - 108,
            (cx - bar_width * 0.5) as i32,
            (cx + bar_width * 0.5) as i32,
            pos_y as i32,
            screen_w as i32,
            self.window_h as i32,
            None,
            false,
            None,
            None,
        );

        window.set_visible(true);
        self.window = Some(window);
        self.renderer = Some(renderer);
        self.last_frame_time = Instant::now();
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => {
                platform::win_utils::cleanup_hooks();
                event_loop.exit();
            }
            WindowEvent::KeyboardInput {
                event:
                    KeyEvent {
                        physical_key,
                        state: ElementState::Pressed,
                        text,
                        ..
                    },
                ..
            } => {
                if self.flyout_mgr.is_password_active() {
                    match physical_key {
                        PhysicalKey::Code(KeyCode::Escape) => {
                            if self.flyout_mgr.slot2_kind == SubFlyoutKind::WifiPassword {
                                self.flyout_mgr.close_slot2();
                            } else {
                                self.flyout_mgr.close_slot1();
                            }
                        }
                        PhysicalKey::Code(KeyCode::Backspace) => {
                            self.flyout_mgr.handle_password_backspace();
                        }
                        PhysicalKey::Code(KeyCode::Enter)
                        | PhysicalKey::Code(KeyCode::NumpadEnter) => {
                            self.flyout_mgr.handle_password_submit();
                        }
                        _ => {
                            if let Some(txt) = text {
                                for ch in txt.chars() {
                                    self.flyout_mgr.handle_password_char(ch);
                                }
                            }
                        }
                    }
                    return;
                }

                // Input Keyboard untuk Zen Search Pill & Tanzaku Tags (Start Menu aktif)
                if self.flyout_mgr.start.is_active() && self.flyout_mgr.start.open {
                    match physical_key {
                        PhysicalKey::Code(KeyCode::Escape) => {
                            if !self.flyout_mgr.start.search_query.is_empty() {
                                self.flyout_mgr.start.clear_search();
                            } else {
                                self.flyout_mgr.start.close();
                            }
                            return;
                        }
                        PhysicalKey::Code(KeyCode::Backspace) => {
                            self.flyout_mgr.start.handle_search_backspace();
                            return;
                        }
                        PhysicalKey::Code(KeyCode::Enter)
                        | PhysicalKey::Code(KeyCode::NumpadEnter) => {
                            self.flyout_mgr.start.execute_selected();
                            return;
                        }
                        PhysicalKey::Code(KeyCode::ArrowDown) => {
                            self.flyout_mgr.start.select_next();
                            return;
                        }
                        PhysicalKey::Code(KeyCode::ArrowUp) => {
                            self.flyout_mgr.start.select_prev();
                            return;
                        }
                        PhysicalKey::Code(KeyCode::Tab) => {
                            self.flyout_mgr.start.select_next();
                            return;
                        }
                        _ => {
                            if let Some(txt) = text {
                                for ch in txt.chars() {
                                    self.flyout_mgr.start.handle_search_char(ch);
                                }
                                return;
                            }
                        }
                    }
                }

                match physical_key {
                    PhysicalKey::Code(KeyCode::Escape) => {
                        if self.flyout_mgr.start.open {
                            self.flyout_mgr.start.close();
                        } else if self.flyout_mgr.slot2_open {
                            self.flyout_mgr.close_slot2();
                        } else if self.flyout_mgr.slot1_open {
                            self.flyout_mgr.close_slot1();
                        } else if self.flyout_mgr.start.is_active() {
                            self.flyout_mgr.start.close();
                        } else if self.flyout_mgr.is_open() {
                            self.flyout_mgr.close();
                        } else if !self.is_exiting {
                            self.is_exiting = true;
                            self.target_anim = 0.0;
                        }
                    }
                    PhysicalKey::Code(KeyCode::Digit1) => self.set_active_theme(FlyoutTheme::LiquidSpire),
                    PhysicalKey::Code(KeyCode::Digit2) => self.set_active_theme(FlyoutTheme::SumiCloud),
                    PhysicalKey::Code(KeyCode::Digit3) => self.set_active_theme(FlyoutTheme::PureHud),
                    PhysicalKey::Code(KeyCode::KeyR) => {
                        self.flyout_mgr.reload_config();
                        if let Some(renderer) = self.renderer.as_mut() {
                            renderer.set_font_family(&self.flyout_mgr.config.typography.body_font);
                        }
                    }
                    _ => (),
                }
            }
            WindowEvent::MouseInput {
                state: ElementState::Released,
                button: MouseButton::Left,
                ..
            } => self.flyout_mgr.end_drag(),
            WindowEvent::MouseInput {
                state: ElementState::Pressed,
                button: MouseButton::Left,
                ..
            } => {
                let (mx, my) = Self::cursor_pos();
                let window_top_y = (self.screen_h.saturating_sub(self.window_h)) as f32;
                let local_x = mx as f32;
                let local_y = my as f32 - window_top_y;

                let wy = layout::widget_y(self.window_h);
                let tray_x = layout::tray_center_x(self.screen_w);
                let cx = (self.screen_w as f32) * 0.5;
                let bar_left = cx - ((self.screen_w as f32) * 0.50) * 0.5;
                let win_x = bar_left + 54.0;
                let search_x = bar_left + 126.0;

                if (local_x - win_x).abs() < 32.0 && (local_y - wy).abs() < 32.0 {
                    if self.flyout_mgr.is_open() {
                        self.flyout_mgr.close();
                    }
                    self.flyout_mgr.start.toggle();
                } else if !self.flyout_mgr.start.open && (local_x - search_x).abs() < 32.0 && (local_y - wy).abs() < 32.0 {
                    if self.flyout_mgr.is_open() {
                        self.flyout_mgr.close();
                    }
                    self.flyout_mgr.start.open_now();
                } else if (local_x - (tray_x - 40.0)).abs() < 18.0 && (local_y - wy).abs() < 22.0 {
                    self.flyout_mgr.start.close();
                    self.flyout_mgr.toggle(ActiveFlyout::Wifi);
                } else if (local_x - tray_x).abs() < 18.0 && (local_y - wy).abs() < 22.0 {
                    self.flyout_mgr.start.close();
                    self.flyout_mgr.toggle(ActiveFlyout::Volume);
                } else if (local_x - (tray_x + 38.0)).abs() < 20.0 && (local_y - wy).abs() < 22.0 {
                    self.flyout_mgr.start.close();
                    self.flyout_mgr.toggle(ActiveFlyout::Battery);
                } else if self.flyout_mgr.is_open() {
                    let fly_cx = layout::active_flyout_center_x(self.screen_w, self.flyout_mgr.active);
                    let dx = local_x - fly_cx;
                    let dy = local_y - (wy - FLY_RISE);
                    if !self.flyout_mgr.handle_click(dx, dy) {
                        self.flyout_mgr.close();
                    }
                } else if self.flyout_mgr.start.is_active() && self.flyout_mgr.start.open {
                    let (pill_cx, pill_cy) = layout::search_pill_center_local(
                        self.screen_w,
                        self.window_h,
                        self.flyout_mgr.start.search_pill_t,
                    );
                    let (res_cx, res_cy) = layout::search_results_center_local(
                        self.screen_w,
                        self.window_h,
                        self.flyout_mgr.start.results_reveal_t,
                    );
                    // Cek klik pada salah satu dari 5 slip Tanzaku di dahan KIRI
                    if self.flyout_mgr.start.results_reveal_t > 0.05 {
                        let tag_hw = 220.0;
                        let tag_hh = 21.0;
                        for i in 0..self.flyout_mgr.start.search_results.len().min(5) {
                            let tag_cy = res_cy + 18.0 + (i as f32) * 50.0 + 21.0;
                            if (local_x - res_cx).abs() <= tag_hw && (local_y - tag_cy).abs() <= tag_hh {
                                self.flyout_mgr.start.execute_index(i);
                                return;
                            }
                        }
                    }

                    // Cek klik pada Search Pill Lampion Besar itu sendiri di dahan KANAN (570x76 px)
                    if (local_x - pill_cx).abs() <= 285.0 && (local_y - pill_cy).abs() <= 38.0 {
                        let esc_x = pill_cx + 242.0;
                        if (local_x - esc_x).abs() <= 32.0 {
                            self.flyout_mgr.start.clear_search();
                        }
                        return;
                    }

                    // Cek klik pada Chōchin Lantern di kiri
                    let lantern_cx = pill_cx - 305.0;
                    let lantern_cy = pill_cy + 18.0;
                    if (local_x - lantern_cx).abs() <= 28.0 && (local_y - lantern_cy).abs() <= 32.0 {
                        // Mengetuk lampion memberikan denyut cahaya emas hangat
                        self.flyout_mgr.start.typing_pulse = 1.0;
                        return;
                    }

                    // Klik di luar area interaktif menutup Start Menu
                    self.flyout_mgr.start.close();
                }
            }
            WindowEvent::MouseWheel { delta, .. } => {
                if self.flyout_mgr.is_open() {
                    let change = match delta {
                        winit::event::MouseScrollDelta::LineDelta(_, y) => y * 0.05,
                        winit::event::MouseScrollDelta::PixelDelta(p) => (p.y as f32) * 0.001,
                    };
                    match self.flyout_mgr.active {
                        ActiveFlyout::Volume => {
                            self.flyout_mgr.volume_level =
                                (self.flyout_mgr.volume_level + change).clamp(0.0, 1.0);
                            if self.flyout_mgr.volume_level > 0.01 {
                                self.flyout_mgr.volume_muted = false;
                            }
                        }
                        ActiveFlyout::Battery => {
                            self.flyout_mgr.brightness_level =
                                (self.flyout_mgr.brightness_level + change).clamp(0.05, 1.0);
                            platform::system_ctrl::apply_brightness_async(
                                self.flyout_mgr.brightness_level,
                            );
                        }
                        _ => {}
                    }
                }
            }
            WindowEvent::Resized(new_size) => {
                self.screen_w = new_size.width;
                if let Some(renderer) = self.renderer.as_mut() {
                    renderer.resize(new_size.width, new_size.height);
                }
            }
            WindowEvent::ScaleFactorChanged { .. } => {
                if let Some(window) = self.window.as_ref() {
                    let s = window.inner_size();
                    self.screen_w = s.width;
                    if let Some(renderer) = self.renderer.as_mut() {
                        renderer.resize(s.width, s.height);
                    }
                }
            }
            WindowEvent::RedrawRequested => {
                if let Some(renderer) = self.renderer.as_mut() {
                    renderer.render();
                }
            }
            _ => (),
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        if self.is_exiting && self.current_anim <= 0.01 && self.anim_velocity.abs() < 0.05 {
            platform::win_utils::cleanup_hooks();
            event_loop.exit();
            return;
        }

        let (mouse_x, mouse_y) = Self::cursor_pos();
        let now = Instant::now();
        let dt = (now - self.last_frame_time).as_secs_f32().clamp(0.001, 0.05);
        self.last_frame_time = now;

        let bar_width = (self.screen_w as f32) * 0.50;
        let cx = (self.screen_w as f32) * 0.5;
        let bar_left = cx - bar_width * 0.5;
        let bar_right = cx + bar_width * 0.5;

        let flyout_center_x = layout::active_flyout_center_x(self.screen_w, self.flyout_mgr.active);

        if self.flyout_mgr.dragging != DragTarget::None {
            self.flyout_mgr.handle_drag((mouse_x as f32) - flyout_center_x);
        }

        // Mouse velocity & slosh dynamics
        let dx_m = (mouse_x as f32) - self.prev_mouse_pos.0;
        let dy_m = (mouse_y as f32) - self.prev_mouse_pos.1;
        self.prev_mouse_pos = (mouse_x as f32, mouse_y as f32);

        let raw_speed = ((dx_m * dx_m + dy_m * dy_m).sqrt() / (dt * 1200.0)).clamp(0.0, 1.5);
        self.mouse_speed += (raw_speed - self.mouse_speed) * (dt * 12.0).min(1.0);

        let slosh_target = (-dx_m / 35.0).clamp(-1.2, 1.2);
        self.slosh_velocity += ((slosh_target - self.mouse_slosh) * 140.0 - self.slosh_velocity * 14.0) * dt;
        self.mouse_slosh = (self.mouse_slosh + self.slosh_velocity * dt).clamp(-1.0, 1.0);

        // Taskbar auto-hide proximity
        let in_trigger_zone = mouse_y >= (self.screen_h as i32) - 42
            && mouse_y <= (self.screen_h as i32 + 20)
            && mouse_x >= (bar_left - 60.0) as i32
            && mouse_x <= (bar_right + 60.0) as i32;

        let open_box_top = if self.flyout_mgr.is_open() || self.flyout_mgr.start.is_active() {
            (self.screen_h as i32) - (self.window_h as i32)
        } else {
            (self.screen_h as i32) - 170
        };
        let in_open_zone = mouse_y >= open_box_top
            && mouse_y <= (self.screen_h as i32 + 20)
            && mouse_x >= (bar_left - 80.0) as i32
            && mouse_x <= (bar_right + 120.0) as i32;

        if self.is_exiting {
            self.target_anim = 0.0;
        } else if self.target_anim < 0.5 {
            if in_trigger_zone {
                self.target_anim = 1.0;
                self.leave_timer = None;
            }
        } else if in_open_zone || self.flyout_mgr.is_open() || self.flyout_mgr.start.is_active() {
            self.leave_timer = None;
        } else if self.leave_timer.is_none() {
            self.leave_timer = Some(Instant::now());
        } else if let Some(start) = self.leave_timer {
            if start.elapsed() > Duration::from_millis(1200) {
                self.target_anim = 0.0;
            }
        }

        // Magnetic pull & spring physics
        let eff_h = 8.0 + (108.0 - 8.0) * self.current_anim.clamp(0.0, 1.0);
        let taskbar_top_y = (self.screen_h as f32) - eff_h;
        let is_inside_taskbar = (mouse_y as f32) >= (taskbar_top_y - 2.0)
            && (mouse_y as f32) <= (self.screen_h as f32 + 20.0)
            && (mouse_x as f32) >= (bar_left - 10.0)
            && (mouse_x as f32) <= (bar_right + 10.0);

        let target_pull = if is_inside_taskbar || self.flyout_mgr.is_open() {
            0.0
        } else if self.current_anim > 0.4 {
            let cx_c = (mouse_x as f32).clamp(bar_left, bar_right);
            let cy_c = (mouse_y as f32).clamp(taskbar_top_y, self.screen_h as f32);
            let dist = ((mouse_x as f32 - cx_c).powi(2) + (mouse_y as f32 - cy_c).powi(2)).sqrt();
            if dist <= 80.0 { (1.0 - dist / 80.0).clamp(0.0, 1.0) } else { 0.0 }
        } else {
            0.0
        };

        self.anim_velocity += ((self.target_anim - self.current_anim) * 110.0 - self.anim_velocity * 13.5) * dt;
        self.current_anim += self.anim_velocity * dt;
        if self.current_anim < 0.0 {
            self.current_anim = 0.0;
            self.anim_velocity = self.anim_velocity.max(0.0);
        }

        let wave_surge = (self.anim_velocity.abs() * 0.18).min(1.5);
        self.pull_velocity += ((target_pull - self.pull_strength) * 320.0 - self.pull_velocity * 18.0) * dt;
        self.pull_strength = (self.pull_strength + self.pull_velocity * dt).clamp(0.0, 1.2);

        self.flyout_mgr.update(dt);

        // Chain offsets & Win32 hit-test zones
        let (sub1_off_x, sub2_off_x, slot2_parent_is_main) =
            layout::calculate_chain_offsets(self.screen_w, flyout_center_x);
        self.flyout_mgr.slot1_offset_x = sub1_off_x;
        self.flyout_mgr.slot2_offset_x = sub2_off_x;
        self.flyout_mgr.slot2_parent_is_main = slot2_parent_is_main;

        if platform::win_utils::SHOULD_DISMISS_FLYOUT
            .swap(false, std::sync::atomic::Ordering::Relaxed)
            && self.flyout_mgr.is_open()
        {
            self.flyout_mgr.close();
        }

        let hit_zones = layout::compute_hit_zones(
            self.screen_w,
            self.screen_h,
            self.window_h,
            flyout_center_x,
            sub1_off_x,
            sub2_off_x,
            &self.flyout_mgr,
        );

        let window_top_screen = self.screen_h.saturating_sub(self.window_h) as i32;
        platform::win_utils::update_hittest_zones(
            (self.screen_h as f32 - eff_h - self.pull_strength * 26.0) as i32,
            (bar_left - 35.0) as i32,
            (bar_right + 35.0) as i32,
            window_top_screen,
            self.screen_w as i32,
            self.window_h as i32,
            hit_zones.flyout,
            hit_zones.flyout_has_stalk,
            hit_zones.sub1,
            hit_zones.sub2,
        );

        // Deteksi hover mouse untuk 5 slip Tanzaku Start Menu di dahan KIRI
        if self.flyout_mgr.start.is_active() && self.flyout_mgr.start.open && self.flyout_mgr.start.results_reveal_t > 0.10 {
            let (res_cx, res_cy) = layout::search_results_center_local(
                self.screen_w,
                self.window_h,
                self.flyout_mgr.start.results_reveal_t,
            );
            let local_mx = mouse_x as f32;
            let local_my = mouse_y as f32 - window_top_screen as f32;
            let tag_hw = 220.0;
            let tag_hh = 21.0;
            let mut hovered = None;
            for i in 0..self.flyout_mgr.start.search_results.len().min(5) {
                let tag_cy = res_cy + 18.0 + (i as f32) * 50.0 + 21.0;
                if (local_mx - res_cx).abs() <= tag_hw && (local_my - tag_cy).abs() <= tag_hh {
                    hovered = Some(i);
                    break;
                }
            }
            if let Some(h_idx) = hovered {
                if self.flyout_mgr.start.hovered_result_idx != Some(h_idx) {
                    self.flyout_mgr.start.hovered_result_idx = Some(h_idx);
                    self.flyout_mgr.start.selected_result_idx = h_idx;
                }
            } else {
                self.flyout_mgr.start.hovered_result_idx = None;
            }
        }

        // Push uniforms & Space Grotesk text entries to GPU
        if let Some(renderer) = self.renderer.as_mut() {
            if self.flyout_mgr.start.roots_dirty {
                renderer.update_root_segments(&self.flyout_mgr.start.root_segs);
                self.flyout_mgr.start.roots_dirty = false;
            }
            let local_mouse = [mouse_x as f32, mouse_y as f32 - window_top_screen as f32];
            let now_local = chrono::Local::now();
            let clock_time = [
                now_local.hour() as f32,
                now_local.minute() as f32,
                now_local.second() as f32,
                self.flyout_mgr.start.results_reveal_t,
            ];
            let wy = layout::widget_y(self.window_h);

            let flyout_value = match self.flyout_mgr.active {
                ActiveFlyout::Volume => self.flyout_mgr.volume_level,
                ActiveFlyout::Battery => self.flyout_mgr.battery_info.percent,
                ActiveFlyout::Wifi => self.flyout_mgr.wifi_signal,
                ActiveFlyout::None => 0.0,
            };

            let (disp_scale, body_scale) = self.flyout_mgr.active_scales();
            let text_entries = if self.flyout_mgr.is_open() {
                let elapsed = renderer.elapsed_secs();
                self.flyout_mgr.build_text_entries(flyout_center_x, wy, elapsed)
            } else if self.flyout_mgr.start.is_active() && self.flyout_mgr.start.search_pill_t > 0.01 {
                let elapsed = renderer.elapsed_secs();
                let (pill_cx, pill_cy) = layout::search_pill_center_local(
                    self.screen_w,
                    self.window_h,
                    self.flyout_mgr.start.search_pill_t,
                );
                let (res_cx, res_cy) = layout::search_results_center_local(
                    self.screen_w,
                    self.window_h,
                    self.flyout_mgr.start.results_reveal_t,
                );
                self.flyout_mgr.start.build_search_text_entries(pill_cx, pill_cy, res_cx, res_cy, elapsed)
            } else {
                Vec::new()
            };

            renderer.uniforms._padding0 = if self.flyout_mgr.start.open { 1.0 } else { 0.0 };
            renderer.update_animation(
                self.current_anim,
                wave_surge,
                local_mouse,
                self.pull_strength,
                self.mouse_speed,
                self.mouse_slosh,
                clock_time,
                [self.flyout_mgr.active as u32 as f32, self.flyout_mgr.current_open_t, self.flyout_mgr.active_theme() as f32, flyout_value],
                [flyout_center_x, wy, if self.flyout_mgr.battery_info.is_charging { 1.0 } else { 0.0 }, self.flyout_mgr.battery_info.percent],
                [self.flyout_mgr.packed_flags(), self.flyout_mgr.power_mode.as_f32(), self.flyout_mgr.sound_output.as_f32(), self.flyout_mgr.brightness_level],
                [(self.flyout_mgr.battery_info.life_time_secs / 60) as f32, self.flyout_mgr.wifi_signal, self.flyout_mgr.volume_level, self.flyout_mgr.slot1_open_t],
                [disp_scale, body_scale, self.flyout_mgr.start.selected_result_idx as f32, self.flyout_mgr.start.search_energy()],
                [self.flyout_mgr.config.visual.texture_intensity, self.flyout_mgr.config.visual.texture_fade_px, sub1_off_x, self.flyout_mgr.config.visual.content_backdrop_alpha],
                [self.flyout_mgr.slot1_kind as u32 as f32, self.flyout_mgr.slot2_kind as u32 as f32, self.flyout_mgr.slot2_open_t, self.flyout_mgr.wifi_toggle_t],
                [sub1_off_x, sub2_off_x, if slot2_parent_is_main { 1.0 } else { 0.0 }, self.flyout_mgr.spatial_toggle_t],
                self.flyout_mgr.audio_levels_uniform(),
                self.flyout_mgr.power_extra_uniform(),
                self.flyout_mgr.start.uniform_vec(self.screen_h),
                self.flyout_mgr.start.tree_params_vec(&self.flyout_mgr.config.start),
                self.flyout_mgr.start.start_fx_vec(),
                self.flyout_mgr.start.tree_style_vec(&self.flyout_mgr.config.start),
                text_entries,
            );
        }

        if let Some(window) = self.window.as_ref() {
            window.request_redraw();
        }

        if self.diagnose_mode {
            self.diagnose_frame += 1;
            if self.diagnose_frame == 5 && self.diagnose_step == 0 {
                self.flyout_mgr.toggle(ActiveFlyout::Battery);
                self.diagnose_step = 1;
            } else if self.diagnose_step == 1 && self.flyout_mgr.current_open_t >= 0.98 {
                self.flyout_mgr.toggle_sub_flyout(SubFlyoutKind::BatteryHealth);
                self.flyout_mgr.toggle_sub_flyout(SubFlyoutKind::DisplayPower);
                self.diagnose_step = 2;
            } else if self.diagnose_step == 2 && self.flyout_mgr.slot2_open_t >= 0.98 {
                println!(">>> [DIAG] Battery Chain OK: Slot1={:?}, Slot2={:?}", self.flyout_mgr.slot1_kind, self.flyout_mgr.slot2_kind);
                platform::win_utils::cleanup_hooks();
                event_loop.exit();
            }
        }
    }
}
