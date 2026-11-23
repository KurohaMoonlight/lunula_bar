pub mod chain;
pub mod start_menu;
pub mod start_roots;
pub mod hit_test;
pub mod text_layout;
pub mod types;

pub use types::{
    ActiveFlyout, AppVolumeItem, BluetoothDeviceItem, DragTarget, SubFlyoutKind, WifiNetworkItem,
    CHAIN_MAIN_TO_SUB, CHAIN_SUB_TO_SUB, FLY_HALF_H, FLY_HALF_W, FLY_RISE,
    SUB_HALF_H, SUB_HALF_W, SUB_OFFSET_Y,
};

use crate::config::{FlyoutTheme, ModulesConfig};
use crate::platform::power::{get_battery_info, BatteryInfo};
use crate::platform::system_ctrl::{
    query_active_power_mode, query_wifi_status, PowerMode, SoundOutput,
};
use types::*;

pub struct FlyoutManager {
    pub config: ModulesConfig,
    pub active: ActiveFlyout,
    pub current_open_t: f32,
    pub open_velocity: f32,
    pub target_open: f32,
    pub pending: Option<ActiveFlyout>,

    // Audio / Volume state
    pub volume_level: f32,
    pub volume_muted: bool,
    pub sound_output: SoundOutput,
    pub mic_muted: bool,
    pub mic_gain: f32,
    pub spatial_sound: bool,
    pub spatial_toggle_t: f32,
    pub eq_preset: u8,
    pub app_volumes: Vec<AppVolumeItem>,

    // Battery / Power / Display state
    pub battery_info: BatteryInfo,
    pub power_mode: PowerMode,
    pub brightness_level: f32,
    pub energy_saver: bool,
    pub battery_care_80: bool,
    pub care_toggle_t: f32,
    pub adaptive_brightness: bool,
    pub adaptive_toggle_t: f32,
    pub screen_timeout_idx: u8, // 0 = 5m, 1 = 15m, 2 = Never

    // Connectivity / Quick Settings state
    pub wifi_enabled: bool,
    pub wifi_toggle_t: f32,
    pub wifi_signal: f32,
    pub wifi_networks: Vec<WifiNetworkItem>,
    pub active_wifi_idx: usize,
    pub bluetooth_enabled: bool,
    pub bt_devices: Vec<BluetoothDeviceItem>,
    pub flight_mode: bool,
    pub hotspot_enabled: bool,
    pub night_light: bool,
    pub night_toggle_t: f32,

    // Dual-Slot Chain Sub-Flyout Engine
    pub slot1_kind: SubFlyoutKind,
    pub slot1_open: bool,
    pub slot1_open_t: f32,
    pub slot1_velocity: f32,
    pub slot1_offset_x: f32,

    pub slot2_kind: SubFlyoutKind,
    pub slot2_open: bool,
    pub slot2_open_t: f32,
    pub slot2_velocity: f32,
    pub slot2_offset_x: f32,
    pub slot2_parent_is_main: bool,

    // Wi-Fi Password sub-flyout state
    pub pw_target_idx: usize,
    pub pw_input: String,
    pub pw_show: bool,
    pub pw_status: String,
    pub pw_connecting: bool,
    pub pw_connect_timer: f32,

    // Start Menu (Fase 1)
    pub start: start_menu::StartMenuState,

    // Active drag state
    pub dragging: DragTarget,
}

impl FlyoutManager {
    pub fn new() -> Self {
        let config = ModulesConfig::load();
        let start = start_menu::StartMenuState::new(&config.start);
        let battery_info = get_battery_info();
        let power_mode = query_active_power_mode();
        let (wifi_enabled, wifi_signal) = query_wifi_status();

        Self {
            config,
            active: ActiveFlyout::None,
            current_open_t: 0.0,
            open_velocity: 0.0,
            target_open: 0.0,
            pending: None,

            volume_level: 0.72,
            volume_muted: false,
            sound_output: SoundOutput::Speakers,
            mic_muted: false,
            mic_gain: 0.80,
            spatial_sound: false,
            spatial_toggle_t: 0.0,
            eq_preset: 0,
            app_volumes: vec![
                AppVolumeItem { name: "Lunula Audio".into(), level: 0.86, muted: false },
                AppVolumeItem { name: "Browser".into(), level: 0.64, muted: false },
                AppVolumeItem { name: "Discord".into(), level: 0.90, muted: false },
            ],

            battery_info,
            power_mode,
            brightness_level: 0.78,
            energy_saver: false,
            battery_care_80: true,
            care_toggle_t: 1.0,
            adaptive_brightness: false,
            adaptive_toggle_t: 0.0,
            screen_timeout_idx: 1,

            wifi_enabled,
            wifi_toggle_t: if wifi_enabled { 1.0 } else { 0.0 },
            wifi_signal,
            wifi_networks: vec![
                WifiNetworkItem { ssid: "Lintang Sukma 5G".into(), band: "5 GHz".into(), signal: wifi_signal, secured: true },
                WifiNetworkItem { ssid: "Guest_Network".into(), band: "2.4 GHz".into(), signal: 0.68, secured: true },
                WifiNetworkItem { ssid: "Office_Wlan_6".into(), band: "6 GHz".into(), signal: 0.48, secured: true },
            ],
            active_wifi_idx: 0,
            bluetooth_enabled: true,
            bt_devices: vec![
                BluetoothDeviceItem { name: "WH-1000XM5".into(), kind_label: "Audio".into(), connected: true, battery_pct: Some(85) },
                BluetoothDeviceItem { name: "Keychron K2 Pro".into(), kind_label: "Keyboard".into(), connected: false, battery_pct: Some(92) },
                BluetoothDeviceItem { name: "AirPods Pro".into(), kind_label: "Audio".into(), connected: false, battery_pct: None },
            ],
            flight_mode: false,
            hotspot_enabled: false,
            night_light: false,
            night_toggle_t: 0.0,

            slot1_kind: SubFlyoutKind::None,
            slot1_open: false,
            slot1_open_t: 0.0,
            slot1_velocity: 0.0,
            slot1_offset_x: -CHAIN_MAIN_TO_SUB,

            slot2_kind: SubFlyoutKind::None,
            slot2_open: false,
            slot2_open_t: 0.0,
            slot2_velocity: 0.0,
            slot2_offset_x: -(CHAIN_MAIN_TO_SUB + CHAIN_SUB_TO_SUB),
            slot2_parent_is_main: false,

            pw_target_idx: 1,
            pw_input: String::new(),
            pw_show: false,
            pw_status: "Press Enter or click Connect".into(),
            pw_connecting: false,
            pw_connect_timer: 0.0,

            start,
            dragging: DragTarget::None,
        }
    }

    pub fn reload_config(&mut self) {
        self.config = ModulesConfig::load();
        self.start.sync_config(&self.config.start);
    }

    pub fn audio_levels_uniform(&self) -> [f32; 4] {
        [
            self.app_volumes.get(0).map(|a| a.level).unwrap_or(0.8),
            self.app_volumes.get(1).map(|a| a.level).unwrap_or(0.6),
            self.app_volumes.get(2).map(|a| a.level).unwrap_or(0.9),
            self.mic_gain,
        ]
    }

    pub fn power_extra_uniform(&self) -> [f32; 4] {
        [
            self.screen_timeout_idx as f32,
            self.care_toggle_t,
            self.night_toggle_t,
            self.adaptive_toggle_t,
        ]
    }

    pub fn toggle(&mut self, target: ActiveFlyout) {
        self.dragging = DragTarget::None;
        let visible = self.current_open_t > 0.05 && self.active != ActiveFlyout::None;
        if self.active == target && self.target_open > 0.5 {
            self.target_open = 0.0;
            self.pending = None;
            self.close_all_subs();
        } else if visible && self.active != target {
            self.pending = Some(target);
            self.close_all_subs();
            self.target_open = 0.0;
        } else {
            self.close_all_subs();
            self.activate(target);
        }
    }

    fn activate(&mut self, target: ActiveFlyout) {
        self.active = target;
        self.pending = None;
        self.close_all_subs();
        self.target_open = 1.0;
        match target {
            ActiveFlyout::Battery => {
                self.battery_info = get_battery_info();
                self.power_mode = query_active_power_mode();
            }
            ActiveFlyout::Wifi => {
                let (on, sig) = query_wifi_status();
                if !self.flight_mode {
                    self.wifi_enabled = on;
                    self.wifi_signal = sig;
                    if let Some(first) = self.wifi_networks.first_mut() {
                        first.signal = sig;
                    }
                }
            }
            _ => {}
        }
    }

    pub fn close(&mut self) {
        self.target_open = 0.0;
        self.pending = None;
        self.close_all_subs();
        self.dragging = DragTarget::None;
    }

    pub fn is_open(&self) -> bool {
        self.current_open_t > 0.01 || self.target_open > 0.01 || self.pending.is_some()
    }

    pub fn active_theme(&self) -> u32 {
        let theme = match self.active {
            ActiveFlyout::Volume => self.config.volume.theme,
            ActiveFlyout::Battery => self.config.battery.theme,
            ActiveFlyout::Wifi => self.config.wifi.theme,
            ActiveFlyout::None => FlyoutTheme::LiquidSpire,
        };
        theme as u32
    }

    pub fn active_scales(&self) -> (f32, f32) {
        match self.active {
            ActiveFlyout::Volume => (self.config.volume.typography.display_scale, self.config.volume.typography.body_scale),
            ActiveFlyout::Battery => (self.config.battery.typography.display_scale, self.config.battery.typography.body_scale),
            ActiveFlyout::Wifi => (self.config.wifi.typography.display_scale, self.config.wifi.typography.body_scale),
            ActiveFlyout::None => (1.0, 1.0),
        }
    }

    pub fn packed_flags(&self) -> f32 {
        let mut bits = 0u32;
        if self.wifi_enabled && !self.flight_mode { bits |= FLAG_WIFI_ON; }
        if self.bluetooth_enabled && !self.flight_mode { bits |= FLAG_BLUETOOTH_ON; }
        if self.flight_mode { bits |= FLAG_FLIGHT_MODE; }
        if self.hotspot_enabled && !self.flight_mode { bits |= FLAG_HOTSPOT_ON; }
        if self.night_light { bits |= FLAG_NIGHT_LIGHT; }
        if self.volume_muted { bits |= FLAG_VOLUME_MUTED; }
        if self.mic_muted { bits |= FLAG_MIC_MUTED; }
        if self.spatial_sound { bits |= FLAG_SPATIAL_SOUND; }
        if self.energy_saver { bits |= FLAG_ENERGY_SAVER; }
        if self.battery_info.is_charging { bits |= FLAG_BATTERY_CHARGING; }
        if self.pw_show { bits |= FLAG_PW_SHOW; }
        if self.pw_connecting { bits |= FLAG_PW_CONNECTING; }
        if self.bt_devices.get(0).map(|d| d.connected).unwrap_or(false) && self.bluetooth_enabled { bits |= FLAG_BT_DEV0_CONN; }
        if self.bt_devices.get(1).map(|d| d.connected).unwrap_or(false) && self.bluetooth_enabled { bits |= FLAG_BT_DEV1_CONN; }
        if self.bt_devices.get(2).map(|d| d.connected).unwrap_or(false) && self.bluetooth_enabled { bits |= FLAG_BT_DEV2_CONN; }
        if (self.active_wifi_idx & 1) != 0 { bits |= FLAG_WIFI_ACTIVE_BIT0; }
        if (self.active_wifi_idx & 2) != 0 { bits |= FLAG_WIFI_ACTIVE_BIT1; }
        if self.app_volumes.get(0).map(|a| a.muted).unwrap_or(false) { bits |= FLAG_APP0_MUTED; }
        if self.app_volumes.get(1).map(|a| a.muted).unwrap_or(false) { bits |= FLAG_APP1_MUTED; }
        if self.app_volumes.get(2).map(|a| a.muted).unwrap_or(false) { bits |= FLAG_APP2_MUTED; }
        if (self.eq_preset & 1) != 0 { bits |= FLAG_EQ_BIT0; }
        if (self.eq_preset & 2) != 0 { bits |= FLAG_EQ_BIT1; }
        if self.battery_care_80 { bits |= FLAG_BATTERY_CARE_80; }
        if self.adaptive_brightness { bits |= FLAG_ADAPTIVE_BRIGHT; }
        bits as f32
    }

    pub fn update(&mut self, dt: f32) {
        let rate = (dt * 14.0).min(1.0);
        let lerp_to = |cur: &mut f32, on: bool| {
            let tgt = if on { 1.0 } else { 0.0 };
            *cur += (tgt - *cur) * rate;
        };
        lerp_to(&mut self.wifi_toggle_t, self.wifi_enabled && !self.flight_mode);
        lerp_to(&mut self.spatial_toggle_t, self.spatial_sound);
        lerp_to(&mut self.care_toggle_t, self.battery_care_80);
        lerp_to(&mut self.night_toggle_t, self.night_light);
        lerp_to(&mut self.adaptive_toggle_t, self.adaptive_brightness);
        self.start.update(dt, &self.config.start);

        if self.pw_connecting {
            self.pw_connect_timer -= dt;
            if self.pw_connect_timer <= 0.0 {
                self.pw_connecting = false;
                self.wifi_enabled = true;
                self.flight_mode = false;
                self.active_wifi_idx = self.pw_target_idx;
                self.wifi_signal = self.wifi_networks[self.active_wifi_idx].signal;
                self.pw_status = "Connected!".into();
                if self.slot2_kind == SubFlyoutKind::WifiPassword {
                    self.slot2_open = false;
                } else if self.slot1_kind == SubFlyoutKind::WifiPassword {
                    self.slot1_open = false;
                }
            }
        }

        let (spring_k, damping) = match self.active {
            ActiveFlyout::Volume => (self.config.volume.spring.stiffness, self.config.volume.spring.damping),
            ActiveFlyout::Battery => (self.config.battery.spring.stiffness, self.config.battery.spring.damping),
            ActiveFlyout::Wifi => (self.config.wifi.spring.stiffness, self.config.wifi.spring.damping),
            ActiveFlyout::None => (150.0, 14.0),
        };

        let force = (self.target_open - self.current_open_t) * spring_k;
        self.open_velocity += (force - self.open_velocity * damping) * dt;
        self.current_open_t += self.open_velocity * dt;
        if self.current_open_t < 0.0 {
            self.current_open_t = 0.0;
            self.open_velocity = self.open_velocity.max(0.0);
        }

        let s1_target = if self.slot1_open && self.current_open_t > 0.5 { 1.0 } else { 0.0 };
        self.slot1_velocity += ((s1_target - self.slot1_open_t) * 145.0 - self.slot1_velocity * 15.5) * dt;
        self.slot1_open_t += self.slot1_velocity * dt;
        if self.slot1_open_t < 0.0 {
            self.slot1_open_t = 0.0;
            self.slot1_velocity = self.slot1_velocity.max(0.0);
        }
        if !self.slot1_open && self.slot1_open_t < 0.01 && self.slot1_velocity.abs() < 0.2 {
            self.slot1_open_t = 0.0;
            self.slot1_velocity = 0.0;
            if self.slot2_open && self.slot2_kind != SubFlyoutKind::None {
                self.slot1_kind = self.slot2_kind;
                self.slot1_open = true;
                self.slot1_open_t = 0.15;
                self.slot2_kind = SubFlyoutKind::None;
                self.slot2_open = false;
                self.slot2_open_t = 0.0;
                self.slot2_velocity = 0.0;
            } else {
                self.slot1_kind = SubFlyoutKind::None;
            }
        }

        let s2_target = if self.slot2_open && self.current_open_t > 0.5 { 1.0 } else { 0.0 };
        self.slot2_velocity += ((s2_target - self.slot2_open_t) * 145.0 - self.slot2_velocity * 15.5) * dt;
        self.slot2_open_t += self.slot2_velocity * dt;
        if self.slot2_open_t < 0.0 {
            self.slot2_open_t = 0.0;
            self.slot2_velocity = self.slot2_velocity.max(0.0);
        }
        if !self.slot2_open && self.slot2_open_t < 0.01 && self.slot2_velocity.abs() < 0.2 {
            self.slot2_open_t = 0.0;
            self.slot2_velocity = 0.0;
            self.slot2_kind = SubFlyoutKind::None;
        }

        if self.target_open == 0.0 && self.current_open_t < 0.004 && self.open_velocity.abs() < 0.3 {
            self.current_open_t = 0.0;
            self.open_velocity = 0.0;
            self.slot1_open_t = 0.0;
            self.slot1_velocity = 0.0;
            self.slot1_kind = SubFlyoutKind::None;
            self.slot2_open_t = 0.0;
            self.slot2_velocity = 0.0;
            self.slot2_kind = SubFlyoutKind::None;
            match self.pending.take() {
                Some(next) => self.activate(next),
                None => self.active = ActiveFlyout::None,
            }
        }
    }
}
