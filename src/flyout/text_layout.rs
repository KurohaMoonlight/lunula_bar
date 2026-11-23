use crate::platform::system_ctrl::{PowerMode, SoundOutput};
use crate::render::text::TextEntry;

use super::types::{smoothstep, ActiveFlyout, SubFlyoutKind, FLY_RISE};
use super::FlyoutManager;

impl FlyoutManager {
    pub fn build_text_entries(&self, fly_cx: f32, widget_y: f32, time: f32) -> Vec<TextEntry> {
        let mut out = Vec::with_capacity(36);
        if self.active == ActiveFlyout::None || self.current_open_t <= 0.01 {
            return out;
        }

        let open_t = self.current_open_t;
        let theme = self.active_theme();
        let (disp_sc, body_sc) = self.active_scales();

        let over_px = (open_t - 1.0).max(0.0) * 14.0;
        let pop_over = (open_t - 1.0).max(0.0) * 0.22;
        let (cc_y, pop, reveal) = if theme == 2 {
            let t_bg = (open_t / 0.72).clamp(0.0, 1.0);
            let smooth_bg = smoothstep(0.0, 1.0, t_bg);
            let fly_h = 40.0 + (FLY_RISE - 40.0) * smooth_bg + (open_t - 1.0).max(0.0) * 12.0;
            let t_content = ((open_t - 0.35) / 0.65).clamp(0.0, 1.0);
            let sc = smoothstep(0.0, 1.0, t_content);
            let rise_off = (1.0 - sc) * 16.0;
            (widget_y - fly_h + rise_off, 0.20 + 0.80 * sc + pop_over, sc)
        } else {
            let cnt = smoothstep(0.70, 1.0, open_t);
            (widget_y - FLY_RISE - over_px, 0.20 + 0.80 * cnt + pop_over, cnt)
        };

        if reveal <= 0.05 {
            return out;
        }

        let a = |alpha: f32| -> u8 { (alpha * reveal * 255.0).clamp(0.0, 255.0) as u8 };
        let gold_hi = [255, 238, 178, a(1.0)];
        let cream = [240, 235, 215, a(0.98)];
        let muted = [152, 160, 180, a(0.92)];
        let aqua = [138, 200, 224, a(1.0)];
        let green = [158, 208, 122, a(1.0)];
        let orange = [242, 134, 98, a(1.0)];
        let amber = [232, 182, 112, a(1.0)];

        match self.active {
            ActiveFlyout::Wifi => {
                let wifi_on = self.wifi_enabled && !self.flight_mode;
                let bt_on = self.bluetooth_enabled && !self.flight_mode;
                let spot_on = self.hotspot_enabled && !self.flight_mode;

                let active_net = &self.wifi_networks[self.active_wifi_idx.min(self.wifi_networks.len() - 1)];
                let ssid_label = if wifi_on {
                    active_net.ssid.clone()
                } else if self.flight_mode {
                    "Flight Mode".to_string()
                } else {
                    "Wi-Fi Off".to_string()
                };
                let sub_label = if wifi_on {
                    format!("Connected · {} · {}%", active_net.band, (self.wifi_signal * 100.0).round() as u32)
                } else {
                    "Click switch to enable".to_string()
                };

                out.push(TextEntry::left(ssid_label, fly_cx - 126.0 * pop, cc_y - 115.0 * pop, 204.0 * pop, 15.5 * pop * disp_sc, if wifi_on { gold_hi } else { muted }).semibold());
                out.push(TextEntry::left(sub_label, fly_cx - 126.0 * pop, cc_y - 91.0 * pop, 204.0 * pop, 11.5 * pop * body_sc, if wifi_on { green } else { muted }));

                let bt_sub = if !bt_on {
                    "Off".to_string()
                } else if let Some(conn) = self.bt_devices.iter().find(|d| d.connected) {
                    conn.name.clone()
                } else {
                    "On · Ready".to_string()
                };
                out.push(TextEntry::left("Bluetooth", fly_cx - 140.0 * pop, cc_y - 34.0 * pop, 96.0 * pop, 13.0 * pop * body_sc, if bt_on { cream } else { muted }).semibold());
                out.push(TextEntry::left(bt_sub, fly_cx - 140.0 * pop, cc_y - 14.0 * pop, 96.0 * pop, 10.5 * pop * body_sc, if bt_on { aqua } else { muted }));

                out.push(TextEntry::left("Hotspot", fly_cx + 64.0 * pop, cc_y - 34.0 * pop, 118.0 * pop, 13.0 * pop * body_sc, if spot_on { cream } else { muted }).semibold());
                out.push(TextEntry::left(if spot_on { "Active" } else { "Off" }, fly_cx + 64.0 * pop, cc_y - 14.0 * pop, 118.0 * pop, 10.5 * pop * body_sc, if spot_on { green } else { muted }));

                out.push(TextEntry::left("Flight Mode", fly_cx - 140.0 * pop, cc_y + 32.0 * pop, 118.0 * pop, 13.0 * pop * body_sc, if self.flight_mode { orange } else { cream }).semibold());
                out.push(TextEntry::left(if self.flight_mode { "Enabled" } else { "Off" }, fly_cx - 140.0 * pop, cc_y + 52.0 * pop, 118.0 * pop, 10.5 * pop * body_sc, if self.flight_mode { orange } else { muted }));

                out.push(TextEntry::left("Night Light", fly_cx + 64.0 * pop, cc_y + 32.0 * pop, 118.0 * pop, 13.0 * pop * body_sc, if self.night_light { amber } else { cream }).semibold());
                out.push(TextEntry::left(if self.night_light { "Warm Filter" } else { "Off" }, fly_cx + 64.0 * pop, cc_y + 52.0 * pop, 118.0 * pop, 10.5 * pop * body_sc, if self.night_light { amber } else { muted }));

                out.push(TextEntry::centered("Network & Internet Settings", fly_cx, cc_y + 103.0 * pop, 260.0 * pop, 12.5 * pop * body_sc, cream));
            }

            ActiveFlyout::Volume => {
                let vol_txt = if self.volume_muted {
                    "Muted".to_string()
                } else {
                    format!("{}%", (self.volume_level * 100.0).round() as u32)
                };
                out.push(TextEntry::centered(vol_txt, fly_cx + 150.0 * pop, cc_y - 104.0 * pop, 68.0 * pop, 15.5 * pop * disp_sc, if self.volume_muted { orange } else { gold_hi }).bold());

                let devs = [
                    ("Speakers (Realtek Audio)", SoundOutput::Speakers, -34.0),
                    ("Headphones (Studio DAC)", SoundOutput::Headphones, 12.0),
                    ("External / HDMI Audio", SoundOutput::External, 58.0),
                ];
                for (label, dev, dy_row) in devs {
                    let is_sel = self.sound_output == dev;
                    out.push(TextEntry::left(label, fly_cx - 128.0 * pop, cc_y + (dy_row - 9.0) * pop, 265.0 * pop, 13.0 * pop * body_sc, if is_sel { gold_hi } else { cream }).semibold());
                }

                out.push(TextEntry::left(if self.mic_muted { "Mic Off" } else { "Mic On" }, fly_cx - 152.0 * pop, cc_y + 101.0 * pop, 64.0 * pop, 12.0 * pop * body_sc, if self.mic_muted { orange } else { cream }).semibold());
                out.push(TextEntry::left("Mixer", fly_cx - 56.0 * pop, cc_y + 101.0 * pop, 64.0 * pop, 12.0 * pop * body_sc, if self.is_sub_open(SubFlyoutKind::AppMixer) { gold_hi } else { cream }).semibold());
                out.push(TextEntry::left(if self.spatial_sound { "3D FX" } else { "Sound FX" }, fly_cx + 62.0 * pop, cc_y + 101.0 * pop, 72.0 * pop, 12.0 * pop * body_sc, if self.is_sub_open(SubFlyoutKind::AudioFx) || self.spatial_sound { aqua } else { cream }).semibold());
            }

            ActiveFlyout::Battery => {
                let pct = (self.battery_info.percent * 100.0).round() as u32;
                out.push(TextEntry::left(format!("{}%", pct), fly_cx + 6.0 * pop, cc_y - 116.0 * pop, 120.0 * pop, 24.0 * pop * disp_sc, gold_hi).bold());
                let mins = self.battery_info.life_time_secs / 60;
                let bat_sub = if self.battery_info.is_charging {
                    if self.battery_care_80 { "Charging · 80% Care".to_string() } else { "Charging · AC Power".to_string() }
                } else if mins > 0 {
                    format!("{}h {}m remaining", mins / 60, mins % 60)
                } else {
                    "On Battery".to_string()
                };
                out.push(TextEntry::left(bat_sub, fly_cx + 6.0 * pop, cc_y - 83.0 * pop, 156.0 * pop, 11.2 * pop * body_sc, if self.battery_info.is_charging { green } else { muted }));

                let modes = [
                    ("Eco", PowerMode::PowerSaver, -135.0, green),
                    ("Balanced", PowerMode::Balanced, 0.0, gold_hi),
                    ("Perf", PowerMode::HighPerformance, 135.0, orange),
                ];
                for (label, mode, dx_col, col_on) in modes {
                    let is_sel = self.power_mode == mode;
                    out.push(TextEntry::centered(label, fly_cx + dx_col * pop, cc_y - 3.0 * pop, 104.0 * pop, 12.5 * pop * body_sc, if is_sel { col_on } else { cream }).semibold());
                }

                out.push(TextEntry::centered(format!("{}%", (self.brightness_level * 100.0).round() as u32), fly_cx + 150.0 * pop, cc_y + 41.0 * pop, 64.0 * pop, 14.0 * pop * disp_sc, gold_hi).bold());

                out.push(TextEntry::left(if self.energy_saver { "Saver · On" } else { "Eco Saver" }, fly_cx - 154.0 * pop, cc_y + 101.0 * pop, 84.0 * pop, 12.0 * pop * body_sc, if self.energy_saver { green } else { cream }).semibold());
                out.push(TextEntry::left("Health", fly_cx - 46.0 * pop, cc_y + 101.0 * pop, 64.0 * pop, 12.0 * pop * body_sc, if self.is_sub_open(SubFlyoutKind::BatteryHealth) { gold_hi } else { cream }).semibold());
                out.push(TextEntry::left("Display", fly_cx + 68.0 * pop, cc_y + 101.0 * pop, 64.0 * pop, 12.0 * pop * body_sc, if self.is_sub_open(SubFlyoutKind::DisplayPower) { aqua } else { cream }).semibold());
            }

            ActiveFlyout::None => {}
        }

        // Dual-Slot Chain Sub-Flyouts (berlaku untuk Wi-Fi, Volume, dan Battery!)
        if self.slot1_open_t > 0.05 && self.slot1_kind != SubFlyoutKind::None {
            let sub_t = self.slot1_open_t.clamp(0.0, 1.0);
            let sub_cx = fly_cx + self.slot1_offset_x * sub_t;
            let sub_pop = 0.20 + 0.80 * sub_t;
            self.append_sub_text_entries(&mut out, self.slot1_kind, sub_cx, cc_y, sub_pop, sub_t * reveal, disp_sc, body_sc, time);
        }

        if self.slot2_open_t > 0.05 && self.slot2_kind != SubFlyoutKind::None {
            let sub_t = self.slot2_open_t.clamp(0.0, 1.0);
            let sub_cx = if self.slot2_parent_is_main {
                fly_cx + self.slot2_offset_x * sub_t
            } else {
                let p1_cx = fly_cx + self.slot1_offset_x * self.slot1_open_t.clamp(0.0, 1.0);
                let rel = self.slot2_offset_x - self.slot1_offset_x;
                p1_cx + rel * sub_t
            };
            let sub_pop = 0.20 + 0.80 * sub_t;
            self.append_sub_text_entries(&mut out, self.slot2_kind, sub_cx, cc_y, sub_pop, sub_t * reveal, disp_sc, body_sc, time);
        }

        out
    }

    #[allow(clippy::too_many_arguments)]
    fn append_sub_text_entries(
        &self,
        out: &mut Vec<TextEntry>,
        kind: SubFlyoutKind,
        sub_cx: f32,
        sub_cy: f32,
        pop: f32,
        reveal: f32,
        disp_sc: f32,
        body_sc: f32,
        time: f32,
    ) {
        if reveal <= 0.05 {
            return;
        }
        let a = |alpha: f32| -> u8 { (alpha * reveal * 255.0).clamp(0.0, 255.0) as u8 };
        let gold_hi = [255, 238, 178, a(1.0)];
        let cream = [240, 235, 215, a(0.98)];
        let muted = [152, 160, 180, a(0.92)];
        let aqua = [138, 200, 224, a(1.0)];
        let green = [158, 208, 122, a(1.0)];
        let orange = [242, 134, 98, a(1.0)];
        let amber = [232, 182, 112, a(1.0)];

        match kind {
            SubFlyoutKind::WifiNetworks => {
                out.push(TextEntry::centered("Available Networks", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                let ys = [-56.0, 2.0, 60.0];
                let wifi_on = self.wifi_enabled && !self.flight_mode;
                for (idx, net) in self.wifi_networks.iter().take(3).enumerate() {
                    let y = sub_cy + ys[idx] * pop;
                    let is_active = wifi_on && idx == self.active_wifi_idx;
                    out.push(TextEntry::left(&net.ssid, sub_cx - 92.0 * pop, y - 18.0 * pop, 194.0 * pop, 13.5 * pop * body_sc, if is_active { gold_hi } else { cream }).semibold());
                    let sub_txt = if is_active { format!("Connected · {}", net.band) } else if net.secured { format!("Secured · {}", net.band) } else { format!("Open · {}", net.band) };
                    out.push(TextEntry::left(sub_txt, sub_cx - 92.0 * pop, y + 2.0 * pop, 194.0 * pop, 10.8 * pop * body_sc, if is_active { green } else { muted }));
                }
                out.push(TextEntry::centered("More Wi-Fi Settings", sub_cx, sub_cy + 107.0 * pop, 200.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::BluetoothDevices => {
                out.push(TextEntry::centered("Bluetooth Devices", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                let ys = [-56.0, 2.0, 60.0];
                let bt_on = self.bluetooth_enabled && !self.flight_mode;
                for (idx, dev) in self.bt_devices.iter().take(3).enumerate() {
                    let y = sub_cy + ys[idx] * pop;
                    let is_conn = bt_on && dev.connected;
                    out.push(TextEntry::left(&dev.name, sub_cx - 92.0 * pop, y - 18.0 * pop, 194.0 * pop, 13.5 * pop * body_sc, if is_conn { gold_hi } else { cream }).semibold());
                    let status = if is_conn {
                        if let Some(bat) = dev.battery_pct { format!("Connected · {}% Battery", bat) } else { format!("Connected · {}", dev.kind_label) }
                    } else if !bt_on {
                        "Bluetooth Off".to_string()
                    } else {
                        format!("{} · Click to connect", dev.kind_label)
                    };
                    out.push(TextEntry::left(status, sub_cx - 92.0 * pop, y + 2.0 * pop, 194.0 * pop, 10.8 * pop * body_sc, if is_conn { aqua } else { muted }));
                }
                out.push(TextEntry::centered("Bluetooth Settings", sub_cx, sub_cy + 107.0 * pop, 200.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::WifiPassword => {
                out.push(TextEntry::centered("Wi-Fi Security", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                let target_net = &self.wifi_networks[self.pw_target_idx.min(self.wifi_networks.len() - 1)];
                out.push(TextEntry::left(&target_net.ssid, sub_cx - 92.0 * pop, sub_cy - 74.0 * pop, 210.0 * pop, 14.0 * pop * body_sc, gold_hi).semibold());
                out.push(TextEntry::left(format!("WPA2 / WPA3 · {}", target_net.band), sub_cx - 92.0 * pop, sub_cy - 54.0 * pop, 210.0 * pop, 10.8 * pop * body_sc, muted));
                let caret = if ((time * 2.2) as u32) % 2 == 0 && !self.pw_connecting { "|" } else { "" };
                let (field_text, field_col) = if self.pw_input.is_empty() {
                    (format!("Enter network key...{}", caret), muted)
                } else if self.pw_show {
                    (format!("{}{}", self.pw_input, caret), cream)
                } else {
                    (format!("{}{}", "•".repeat(self.pw_input.chars().count()), caret), gold_hi)
                };
                out.push(TextEntry::left(field_text, sub_cx - 134.0 * pop, sub_cy - 2.0 * pop, 224.0 * pop, 13.5 * pop * body_sc, field_col));
                out.push(TextEntry::centered(&self.pw_status, sub_cx, sub_cy + 44.0 * pop, 280.0 * pop, 11.2 * pop * body_sc, if self.pw_connecting { aqua } else { muted }));
                out.push(TextEntry::centered("Cancel", sub_cx - 76.0 * pop, sub_cy + 89.0 * pop, 126.0 * pop, 13.0 * pop * body_sc, cream).semibold());
                out.push(TextEntry::centered(if self.pw_connecting { "..." } else { "Connect" }, sub_cx + 76.0 * pop, sub_cy + 89.0 * pop, 126.0 * pop, 13.0 * pop * body_sc, gold_hi).semibold());
            }

            SubFlyoutKind::AppMixer => {
                out.push(TextEntry::centered("Volume Mixer", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                let ys = [-52.0, 8.0, 68.0];
                for (idx, app) in self.app_volumes.iter().take(3).enumerate() {
                    let y = sub_cy + ys[idx] * pop;
                    out.push(TextEntry::left(&app.name, sub_cx - 92.0 * pop, y - 20.0 * pop, 150.0 * pop, 12.0 * pop * body_sc, if app.muted { muted } else { cream }).semibold());
                    let pct_str = if app.muted { "Mute".to_string() } else { format!("{}%", (app.level * 100.0).round() as u32) };
                    out.push(TextEntry::centered(pct_str, sub_cx + 120.0 * pop, y - 1.0 * pop, 46.0 * pop, 11.5 * pop * disp_sc, if app.muted { orange } else { gold_hi }).semibold());
                }
                out.push(TextEntry::centered("App Volume Settings", sub_cx, sub_cy + 109.0 * pop, 210.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::AudioFx => {
                out.push(TextEntry::centered("Sound & Mic FX", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                out.push(TextEntry::left("Spatial Audio", sub_cx - 94.0 * pop, sub_cy - 76.0 * pop, 160.0 * pop, 13.0 * pop * body_sc, if self.spatial_sound { gold_hi } else { cream }).semibold());
                out.push(TextEntry::left(if self.spatial_sound { "Windows Sonic · On" } else { "Off · Stereo" }, sub_cx - 94.0 * pop, sub_cy - 57.0 * pop, 160.0 * pop, 10.5 * pop * body_sc, if self.spatial_sound { aqua } else { muted }));

                for (label, id, dx_col) in [("Flat", 0u8, -104.0), ("Warm", 1u8, 0.0), ("Studio", 2u8, 104.0)] {
                    out.push(TextEntry::centered(label, sub_cx + dx_col * pop, sub_cy - 11.0 * pop, 86.0 * pop, 12.5 * pop * body_sc, if self.eq_preset == id { gold_hi } else { cream }).semibold());
                }

                out.push(TextEntry::left("Microphone Gain", sub_cx - 92.0 * pop, sub_cy + 36.0 * pop, 160.0 * pop, 12.0 * pop * body_sc, if self.mic_muted { muted } else { cream }).semibold());
                let mic_str = if self.mic_muted { "Mute".to_string() } else { format!("{}%", (self.mic_gain * 100.0).round() as u32) };
                out.push(TextEntry::centered(mic_str, sub_cx + 120.0 * pop, sub_cy + 55.0 * pop, 46.0 * pop, 11.5 * pop * disp_sc, if self.mic_muted { orange } else { gold_hi }).semibold());
                out.push(TextEntry::centered("Sound Control Panel", sub_cx, sub_cy + 109.0 * pop, 210.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::BatteryHealth => {
                out.push(TextEntry::centered("Battery Health", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                // Card 1: Condition
                out.push(TextEntry::left("Condition: 94% · Good", sub_cx - 94.0 * pop, sub_cy - 74.0 * pop, 210.0 * pop, 13.0 * pop * body_sc, green).semibold());
                out.push(TextEntry::left("42,800 / 45,500 mWh · 142 cycles", sub_cx - 94.0 * pop, sub_cy - 54.0 * pop, 224.0 * pop, 10.5 * pop * body_sc, muted));
                // Card 2: Battery Care 80% Limit
                out.push(TextEntry::left("Battery Care (80%)", sub_cx - 94.0 * pop, sub_cy - 16.0 * pop, 160.0 * pop, 13.0 * pop * body_sc, if self.battery_care_80 { gold_hi } else { cream }).semibold());
                out.push(TextEntry::left(if self.battery_care_80 { "Active · Lifespan guard" } else { "Off · Full 100% charge" }, sub_cx - 94.0 * pop, sub_cy + 3.0 * pop, 160.0 * pop, 10.5 * pop * body_sc, if self.battery_care_80 { green } else { muted }));
                // Card 3: Power State
                let pwr_title = if self.battery_info.is_charging { "AC Adapter · Connected" } else { "Discharging · Battery" };
                let pwr_sub = if self.battery_info.is_charging { "Optimal thermal profile" } else { "Estimated draw · ~11.4 W" };
                out.push(TextEntry::left(pwr_title, sub_cx - 94.0 * pop, sub_cy + 42.0 * pop, 210.0 * pop, 13.0 * pop * body_sc, cream).semibold());
                out.push(TextEntry::left(pwr_sub, sub_cx - 94.0 * pop, sub_cy + 62.0 * pop, 210.0 * pop, 10.5 * pop * body_sc, aqua));
                out.push(TextEntry::centered("Power & Battery Settings", sub_cx, sub_cy + 109.0 * pop, 210.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::DisplayPower => {
                out.push(TextEntry::centered("Display & Sleep", sub_cx, sub_cy - 124.0 * pop, 196.0 * pop, 14.0 * pop * disp_sc, cream).semibold());
                // Card 1: Night Light
                out.push(TextEntry::left("Night Light", sub_cx - 94.0 * pop, sub_cy - 76.0 * pop, 160.0 * pop, 13.0 * pop * body_sc, if self.night_light { amber } else { cream }).semibold());
                out.push(TextEntry::left(if self.night_light { "Warm 3400K · Active" } else { "Off · Daylight" }, sub_cx - 94.0 * pop, sub_cy - 57.0 * pop, 160.0 * pop, 10.5 * pop * body_sc, if self.night_light { amber } else { muted }));
                // Section 2: Screen Timeout
                for (label, id, dx_col) in [("5 min", 0u8, -104.0), ("15 min", 1u8, 0.0), ("Never", 2u8, 104.0)] {
                    out.push(TextEntry::centered(label, sub_cx + dx_col * pop, sub_cy - 11.0 * pop, 86.0 * pop, 12.5 * pop * body_sc, if self.screen_timeout_idx == id { gold_hi } else { cream }).semibold());
                }
                // Card 3: Adaptive Brightness
                out.push(TextEntry::left("Adaptive Bright", sub_cx - 94.0 * pop, sub_cy + 42.0 * pop, 160.0 * pop, 13.0 * pop * body_sc, if self.adaptive_brightness { aqua } else { cream }).semibold());
                out.push(TextEntry::left(if self.adaptive_brightness { "Auto-adjust · On" } else { "Manual control" }, sub_cx - 94.0 * pop, sub_cy + 61.0 * pop, 160.0 * pop, 10.5 * pop * body_sc, if self.adaptive_brightness { aqua } else { muted }));
                out.push(TextEntry::centered("Display Settings", sub_cx, sub_cy + 109.0 * pop, 210.0 * pop, 12.0 * pop * body_sc, cream));
            }

            SubFlyoutKind::None => {}
        }
    }
}
