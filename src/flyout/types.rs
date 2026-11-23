/// Tinggi area window bar transparan (px). HARUS sama dengan main.rs.
#[allow(dead_code)]
pub const BAR_AREA_HEIGHT: u32 = 640;

/// Jarak pusat kepala flyout di atas titik tombol (px). HARUS sama dengan FLY_RISE di shader.
pub const FLY_RISE: f32 = 280.0;

/// Setengah ukuran panel konten Main Flyout (432x320 px)
pub const FLY_HALF_W: f32 = 216.0;
pub const FLY_HALF_H: f32 = 160.0;

/// Setengah ukuran panel Sub-Flyout (344x320 px) — ramping agar muat 3-panel Chain di 1440px & 1920px
pub const SUB_HALF_W: f32 = 172.0;
pub const SUB_HALF_H: f32 = 160.0;
pub const SUB_OFFSET_Y: f32 = 0.0;

/// Jarak celah jembatan organik antar panel dalam Chain Sub-Flyout
pub const CHAIN_GAP: f32 = 20.0;
pub const CHAIN_MAIN_TO_SUB: f32 = FLY_HALF_W + CHAIN_GAP + SUB_HALF_W; // 408.0
pub const CHAIN_SUB_TO_SUB: f32 = SUB_HALF_W + CHAIN_GAP + SUB_HALF_W; // 364.0

// Bitmask flags untuk uniform `flyout_state.x` (24-bit exact integer di f32)
pub const FLAG_WIFI_ON: u32 = 1 << 0;
pub const FLAG_BLUETOOTH_ON: u32 = 1 << 1;
pub const FLAG_FLIGHT_MODE: u32 = 1 << 2;
pub const FLAG_HOTSPOT_ON: u32 = 1 << 3;
pub const FLAG_NIGHT_LIGHT: u32 = 1 << 4;
pub const FLAG_VOLUME_MUTED: u32 = 1 << 5;
pub const FLAG_MIC_MUTED: u32 = 1 << 6;
pub const FLAG_SPATIAL_SOUND: u32 = 1 << 7;
pub const FLAG_ENERGY_SAVER: u32 = 1 << 8;
pub const FLAG_BATTERY_CHARGING: u32 = 1 << 9;
pub const FLAG_PW_SHOW: u32 = 1 << 10;
pub const FLAG_PW_CONNECTING: u32 = 1 << 11;
pub const FLAG_BT_DEV0_CONN: u32 = 1 << 12;
pub const FLAG_BT_DEV1_CONN: u32 = 1 << 13;
pub const FLAG_BT_DEV2_CONN: u32 = 1 << 14;
pub const FLAG_WIFI_ACTIVE_BIT0: u32 = 1 << 15;
pub const FLAG_WIFI_ACTIVE_BIT1: u32 = 1 << 16;
pub const FLAG_APP0_MUTED: u32 = 1 << 17;
pub const FLAG_APP1_MUTED: u32 = 1 << 18;
pub const FLAG_APP2_MUTED: u32 = 1 << 19;
pub const FLAG_EQ_BIT0: u32 = 1 << 20;
pub const FLAG_EQ_BIT1: u32 = 1 << 21;
pub const FLAG_BATTERY_CARE_80: u32 = 1 << 22;
pub const FLAG_ADAPTIVE_BRIGHT: u32 = 1 << 23;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActiveFlyout {
    None = 0,
    Volume = 1,
    Battery = 2,
    Wifi = 3,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubFlyoutKind {
    None = 0,
    WifiNetworks = 1,
    BluetoothDevices = 2,
    WifiPassword = 3,
    AppMixer = 4,
    AudioFx = 5,
    BatteryHealth = 6,
    DisplayPower = 7,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DragTarget {
    None,
    VolumeSlider,
    BrightnessSlider,
    AppSlider { slot: u8, app_idx: usize },
    MicGainSlider { slot: u8 },
}

#[derive(Debug, Clone)]
pub struct WifiNetworkItem {
    pub ssid: String,
    pub band: String,
    pub signal: f32,
    pub secured: bool,
}

#[derive(Debug, Clone)]
pub struct BluetoothDeviceItem {
    pub name: String,
    pub kind_label: String,
    pub connected: bool,
    pub battery_pct: Option<u8>,
}

#[derive(Debug, Clone)]
pub struct AppVolumeItem {
    pub name: String,
    pub level: f32,
    pub muted: bool,
}

#[inline]
pub fn hit_box(dx: f32, dy: f32, cx: f32, cy: f32, hw: f32, hh: f32) -> bool {
    (dx - cx).abs() <= hw && (dy - cy).abs() <= hh
}

#[inline]
pub fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = ((x - edge0) / (edge1 - edge0).max(1e-6)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}
