use crate::platform::system_ctrl::{
    apply_brightness_async, apply_energy_saver_async, apply_power_mode_async,
    apply_wifi_toggle_async, open_windows_settings, query_wifi_status, PowerMode, SoundOutput,
};

use super::types::{
    hit_box, ActiveFlyout, DragTarget, SubFlyoutKind, FLY_HALF_H, FLY_HALF_W, SUB_HALF_H,
    SUB_HALF_W, SUB_OFFSET_Y,
};
use super::FlyoutManager;

impl FlyoutManager {
    fn close_slot(&mut self, slot_num: u8) {
        if slot_num == 1 {
            self.close_slot1();
        } else {
            self.close_slot2();
        }
    }

    fn handle_sub_click(&mut self, slot_num: u8, kind: SubFlyoutKind, sub_dx: f32, sub_dy: f32) -> bool {
        if sub_dx.abs() > SUB_HALF_W + 12.0 || sub_dy.abs() > SUB_HALF_H + 12.0 {
            return false;
        }

        match kind {
            SubFlyoutKind::WifiNetworks => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 126.0, -114.0, 28.0, 22.0) {
                    let (on, sig) = query_wifi_status();
                    if !self.flight_mode {
                        self.wifi_enabled = on;
                        self.wifi_signal = sig;
                    }
                    return true;
                }
                for (idx, &ny) in [-56.0, 2.0, 60.0].iter().enumerate() {
                    if hit_box(sub_dx, sub_dy, 0.0, ny, 150.0, 26.0) {
                        if !(idx == self.active_wifi_idx && self.wifi_enabled) {
                            self.open_wifi_password(idx);
                        }
                        return true;
                    }
                }
                if hit_box(sub_dx, sub_dy, 0.0, 116.0, 150.0, 20.0) {
                    open_windows_settings("ms-settings:network-wifi");
                    return true;
                }
                true
            }

            SubFlyoutKind::BluetoothDevices => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 126.0, -114.0, 28.0, 22.0) {
                    return true;
                }
                for (idx, &dy_row) in [-56.0, 2.0, 60.0].iter().enumerate() {
                    if hit_box(sub_dx, sub_dy, 0.0, dy_row, 150.0, 26.0) {
                        if !self.bluetooth_enabled {
                            self.bluetooth_enabled = true;
                            self.flight_mode = false;
                        }
                        if let Some(dev) = self.bt_devices.get_mut(idx) {
                            dev.connected = !dev.connected;
                        }
                        return true;
                    }
                }
                if hit_box(sub_dx, sub_dy, 0.0, 116.0, 150.0, 20.0) {
                    open_windows_settings("ms-settings:bluetooth");
                    return true;
                }
                true
            }

            SubFlyoutKind::WifiPassword => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 122.0, 8.0, 24.0, 22.0) {
                    self.pw_show = !self.pw_show;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, -76.0, 98.0, 68.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 76.0, 98.0, 68.0, 22.0) {
                    self.handle_password_submit();
                    return true;
                }
                true
            }

            SubFlyoutKind::AppMixer => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 126.0, -114.0, 28.0, 22.0) {
                    for app in &mut self.app_volumes {
                        app.level = 1.0;
                        app.muted = false;
                    }
                    return true;
                }
                for (idx, &ry) in [-52.0, 8.0, 68.0].iter().enumerate() {
                    if hit_box(sub_dx, sub_dy, -124.0, ry, 20.0, 20.0) {
                        if let Some(app) = self.app_volumes.get_mut(idx) {
                            app.muted = !app.muted;
                        }
                        return true;
                    }
                    if hit_box(sub_dx, sub_dy, -2.0, ry + 6.0, 94.0, 20.0) {
                        self.dragging = DragTarget::AppSlider {
                            slot: slot_num,
                            app_idx: idx,
                        };
                        self.update_app_volume_from_sub_dx(idx, sub_dx);
                        return true;
                    }
                }
                if hit_box(sub_dx, sub_dy, 0.0, 118.0, 150.0, 18.0) {
                    open_windows_settings("ms-settings:apps-volume");
                    return true;
                }
                true
            }

            SubFlyoutKind::AudioFx => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, -60.0, 150.0, 24.0) {
                    self.spatial_sound = !self.spatial_sound;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, -104.0, -2.0, 46.0, 22.0) {
                    self.eq_preset = 0;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, -2.0, 46.0, 22.0) {
                    self.eq_preset = 1;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 104.0, -2.0, 46.0, 22.0) {
                    self.eq_preset = 2;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, -124.0, 58.0, 20.0, 22.0) {
                    self.mic_muted = !self.mic_muted;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, -4.0, 62.0, 92.0, 20.0) {
                    self.dragging = DragTarget::MicGainSlider { slot: slot_num };
                    self.mic_muted = false;
                    self.update_mic_gain_from_sub_dx(sub_dx);
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, 118.0, 150.0, 18.0) {
                    open_windows_settings("ms-settings:sound");
                    return true;
                }
                true
            }

            SubFlyoutKind::BatteryHealth => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                // Card 2: Battery Care 80% Limit Toggle (0, +2, half 150x24)
                if hit_box(sub_dx, sub_dy, 0.0, 2.0, 150.0, 24.0) {
                    self.battery_care_80 = !self.battery_care_80;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, 118.0, 150.0, 18.0) {
                    open_windows_settings("ms-settings:batterysaver");
                    return true;
                }
                true
            }

            SubFlyoutKind::DisplayPower => {
                if hit_box(sub_dx, sub_dy, -126.0, -114.0, 28.0, 22.0) {
                    self.close_slot(slot_num);
                    return true;
                }
                // Card 1: Night Light toggle (0, -60, half 150x24)
                if hit_box(sub_dx, sub_dy, 0.0, -60.0, 150.0, 24.0) {
                    self.night_light = !self.night_light;
                    return true;
                }
                // Section 2: Screen Timeout pills (-104, 0, +104; y = -2)
                if hit_box(sub_dx, sub_dy, -104.0, -2.0, 46.0, 22.0) {
                    self.screen_timeout_idx = 0;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, -2.0, 46.0, 22.0) {
                    self.screen_timeout_idx = 1;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 104.0, -2.0, 46.0, 22.0) {
                    self.screen_timeout_idx = 2;
                    return true;
                }
                // Card 3: Adaptive Brightness toggle (0, +58, half 150x24)
                if hit_box(sub_dx, sub_dy, 0.0, 58.0, 150.0, 24.0) {
                    self.adaptive_brightness = !self.adaptive_brightness;
                    return true;
                }
                if hit_box(sub_dx, sub_dy, 0.0, 118.0, 150.0, 18.0) {
                    open_windows_settings("ms-settings:display");
                    return true;
                }
                true
            }

            SubFlyoutKind::None => false,
        }
    }

    pub fn handle_click(&mut self, dx: f32, dy: f32) -> bool {
        if self.current_open_t < 0.65 {
            return false;
        }

        if self.slot2_open && self.slot2_open_t > 0.3 {
            if self.handle_sub_click(2, self.slot2_kind, dx - self.slot2_offset_x, dy - SUB_OFFSET_Y) {
                return true;
            }
        }
        if self.slot1_open && self.slot1_open_t > 0.3 {
            if self.handle_sub_click(1, self.slot1_kind, dx - self.slot1_offset_x, dy - SUB_OFFSET_Y) {
                return true;
            }
        }

        if dx.abs() > FLY_HALF_W + 15.0 || dy.abs() > FLY_HALF_H + 15.0 {
            return false;
        }

        match self.active {
            ActiveFlyout::Wifi => {
                if hit_box(dx, dy, 150.0, -94.0, 34.0, 24.0) {
                    if self.flight_mode {
                        self.flight_mode = false;
                        self.wifi_enabled = true;
                    } else {
                        self.wifi_enabled = !self.wifi_enabled;
                    }
                    apply_wifi_toggle_async(self.wifi_enabled);
                    return true;
                }
                if hit_box(dx, dy, -42.0, -94.0, 154.0, 36.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::WifiNetworks);
                    return true;
                }
                if hit_box(dx, dy, -27.0, -16.0, 21.0, 28.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::BluetoothDevices);
                    return true;
                }
                if hit_box(dx, dy, -121.0, -16.0, 75.0, 28.0) {
                    if self.flight_mode {
                        self.flight_mode = false;
                        self.bluetooth_enabled = true;
                    } else {
                        self.bluetooth_enabled = !self.bluetooth_enabled;
                    }
                    return true;
                }
                if hit_box(dx, dy, 102.0, -16.0, 94.0, 28.0) {
                    if !self.flight_mode {
                        self.hotspot_enabled = !self.hotspot_enabled;
                    }
                    return true;
                }
                if hit_box(dx, dy, -102.0, 50.0, 94.0, 28.0) {
                    self.flight_mode = !self.flight_mode;
                    if self.flight_mode {
                        self.hotspot_enabled = false;
                    }
                    return true;
                }
                if hit_box(dx, dy, 102.0, 50.0, 94.0, 28.0) {
                    self.night_light = !self.night_light;
                    return true;
                }
                if hit_box(dx, dy, 0.0, 112.0, 196.0, 20.0) {
                    open_windows_settings("ms-settings:network-wifi");
                    return true;
                }
                true
            }

            ActiveFlyout::Battery => {
                // Row 1: Hero Battery Card -> buka Battery Health sub-flyout
                if hit_box(dx, dy, 0.0, -90.0, 194.0, 36.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::BatteryHealth);
                    return true;
                }
                // Row 2: Power Mode 3-way selector (dy = -12, half 59x28)
                if hit_box(dx, dy, -135.0, -12.0, 59.0, 28.0) {
                    self.power_mode = PowerMode::PowerSaver;
                    apply_power_mode_async(self.power_mode);
                    return true;
                }
                if hit_box(dx, dy, 0.0, -12.0, 59.0, 28.0) {
                    self.power_mode = PowerMode::Balanced;
                    apply_power_mode_async(self.power_mode);
                    return true;
                }
                if hit_box(dx, dy, 135.0, -12.0, 59.0, 28.0) {
                    self.power_mode = PowerMode::HighPerformance;
                    apply_power_mode_async(self.power_mode);
                    return true;
                }
                // Row 3: Quick Brightness Dim/Full button (-162, +50) + Kanagawa Solar Brightness Slider (-8, +50)
                if hit_box(dx, dy, -162.0, 50.0, 26.0, 20.0) {
                    self.brightness_level = if self.brightness_level > 0.45 { 0.30 } else { 0.85 };
                    apply_brightness_async(self.brightness_level);
                    return true;
                }
                if hit_box(dx, dy, -8.0, 50.0, 112.0, 22.0) {
                    self.dragging = DragTarget::BrightnessSlider;
                    self.update_brightness_from_dx(dx, true);
                    return true;
                }
                // Row 4: Energy Saver (-132) | Health > (-6) | Display > (+106) | Gear (+179)
                if hit_box(dx, dy, -132.0, 110.0, 62.0, 20.0) {
                    self.energy_saver = !self.energy_saver;
                    apply_energy_saver_async(self.energy_saver);
                    return true;
                }
                if hit_box(dx, dy, -6.0, 110.0, 56.0, 20.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::BatteryHealth);
                    return true;
                }
                if hit_box(dx, dy, 106.0, 110.0, 48.0, 20.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::DisplayPower);
                    return true;
                }
                if hit_box(dx, dy, 179.0, 110.0, 20.0, 20.0) {
                    open_windows_settings("ms-settings:powersleep");
                    return true;
                }
                true
            }

            ActiveFlyout::Volume => {
                if hit_box(dx, dy, -162.0, -94.0, 26.0, 22.0) {
                    self.volume_muted = !self.volume_muted;
                    return true;
                }
                if hit_box(dx, dy, -8.0, -94.0, 112.0, 24.0) {
                    self.dragging = DragTarget::VolumeSlider;
                    self.volume_muted = false;
                    self.update_volume_from_dx(dx);
                    return true;
                }
                if hit_box(dx, dy, 0.0, -34.0, 194.0, 20.0) {
                    self.sound_output = SoundOutput::Speakers;
                    return true;
                }
                if hit_box(dx, dy, 0.0, 12.0, 194.0, 20.0) {
                    self.sound_output = SoundOutput::Headphones;
                    return true;
                }
                if hit_box(dx, dy, 0.0, 58.0, 194.0, 20.0) {
                    self.sound_output = SoundOutput::External;
                    return true;
                }
                if hit_box(dx, dy, -140.0, 110.0, 54.0, 20.0) {
                    self.mic_muted = !self.mic_muted;
                    return true;
                }
                if hit_box(dx, dy, -20.0, 110.0, 58.0, 20.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::AppMixer);
                    return true;
                }
                if hit_box(dx, dy, 100.0, 110.0, 54.0, 20.0) {
                    self.toggle_sub_flyout(SubFlyoutKind::AudioFx);
                    return true;
                }
                if hit_box(dx, dy, 179.0, 110.0, 20.0, 20.0) {
                    open_windows_settings("ms-settings:sound");
                    return true;
                }
                true
            }

            ActiveFlyout::None => false,
        }
    }

    pub fn handle_drag(&mut self, dx: f32) {
        match self.dragging {
            DragTarget::VolumeSlider => self.update_volume_from_dx(dx),
            DragTarget::BrightnessSlider => self.update_brightness_from_dx(dx, false),
            DragTarget::AppSlider { slot, app_idx } => {
                let off_x = if slot == 1 { self.slot1_offset_x } else { self.slot2_offset_x };
                self.update_app_volume_from_sub_dx(app_idx, dx - off_x);
            }
            DragTarget::MicGainSlider { slot } => {
                let off_x = if slot == 1 { self.slot1_offset_x } else { self.slot2_offset_x };
                self.update_mic_gain_from_sub_dx(dx - off_x);
            }
            DragTarget::None => {}
        }
    }

    pub fn end_drag(&mut self) {
        if self.dragging == DragTarget::BrightnessSlider {
            apply_brightness_async(self.brightness_level);
        }
        self.dragging = DragTarget::None;
    }

    fn update_volume_from_dx(&mut self, dx: f32) {
        let norm = ((dx + 118.0) / 220.0).clamp(0.0, 1.0);
        self.volume_level = norm;
        if norm > 0.01 {
            self.volume_muted = false;
        }
    }

    fn update_brightness_from_dx(&mut self, dx: f32, apply_now: bool) {
        // Track center -8.0, half 110.0 -> -118.0 .. +102.0 (width 220.0)
        let norm = ((dx + 118.0) / 220.0).clamp(0.05, 1.0);
        self.brightness_level = norm;
        if apply_now {
            apply_brightness_async(self.brightness_level);
        }
    }

    fn update_app_volume_from_sub_dx(&mut self, app_idx: usize, sub_dx: f32) {
        let norm = ((sub_dx + 92.0) / 180.0).clamp(0.0, 1.0);
        if let Some(app) = self.app_volumes.get_mut(app_idx) {
            app.level = norm;
            if norm > 0.01 {
                app.muted = false;
            }
        }
    }

    fn update_mic_gain_from_sub_dx(&mut self, sub_dx: f32) {
        let norm = ((sub_dx + 92.0) / 176.0).clamp(0.0, 1.0);
        self.mic_gain = norm;
        if norm > 0.01 {
            self.mic_muted = false;
        }
    }
}
