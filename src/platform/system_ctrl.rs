use std::process::Command;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

/// Mode daya Windows (Power Plan / Power Mode)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerMode {
    PowerSaver = 0,
    Balanced = 1,
    HighPerformance = 2,
}

impl PowerMode {
    pub fn as_f32(self) -> f32 {
        self as u32 as f32
    }

    #[allow(dead_code)]
    pub fn label(self) -> &'static str {
        match self {
            PowerMode::PowerSaver => "Power Saver (Eco)",
            PowerMode::Balanced => "Balanced",
            PowerMode::HighPerformance => "Best Performance",
        }
    }

    fn scheme_guid(self) -> &'static str {
        match self {
            PowerMode::PowerSaver => "a1841308-3541-4fab-bc81-f71556f20b4a",
            PowerMode::Balanced => "381b4222-f694-41f0-9685-ff5bb260df2e",
            PowerMode::HighPerformance => "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
        }
    }
}

/// Pilihan perangkat output audio (Sound Output)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SoundOutput {
    Speakers = 0,
    Headphones = 1,
    External = 2, // Bluetooth / HDMI
}

impl SoundOutput {
    pub fn as_f32(self) -> f32 {
        self as u32 as f32
    }

    #[allow(dead_code)]
    pub fn label(self) -> &'static str {
        match self {
            SoundOutput::Speakers => "Speakers",
            SoundOutput::Headphones => "Headphones",
            SoundOutput::External => "BT / HDMI Audio",
        }
    }
}

fn hidden_cmd(program: &str) -> Command {
    let mut cmd = Command::new(program);
    #[cfg(windows)]
    {
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    cmd
}

/// Membaca power plan aktif Windows lewat `powercfg /getactivescheme`
pub fn query_active_power_mode() -> PowerMode {
    let output = hidden_cmd("powercfg").arg("/getactivescheme").output();
    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout).to_lowercase();
        if text.contains("a1841308") || text.contains("saver") {
            return PowerMode::PowerSaver;
        }
        if text.contains("8c5e7fda") || text.contains("performance") {
            return PowerMode::HighPerformance;
        }
    }
    PowerMode::Balanced
}

/// Mengubah power plan aktif Windows secara asinkron agar tidak memblokir render 60fps
pub fn apply_power_mode_async(mode: PowerMode) {
    let guid = mode.scheme_guid().to_string();
    std::thread::spawn(move || {
        let _ = hidden_cmd("powercfg").args(["/setactive", &guid]).status();
    });
}

/// Mengaktifkan/menonaktifkan Energy Saver threshold pada scheme aktif
pub fn apply_energy_saver_async(enabled: bool) {
    let threshold = if enabled { "100" } else { "20" };
    std::thread::spawn(move || {
        let _ = hidden_cmd("powercfg")
            .args([
                "/setdcvalueindex",
                "SCHEME_CURRENT",
                "SUB_ENERGYSAVER",
                "ESBATTTHRESHOLD",
                threshold,
            ])
            .status();
        let _ = hidden_cmd("powercfg")
            .args(["/setactive", "SCHEME_CURRENT"])
            .status();
    });
}

/// Mengatur kecerahan layar laptop (0..=100) via WMI PowerShell di background thread
pub fn apply_brightness_async(level: f32) {
    let pct = (level.clamp(0.05, 1.0) * 100.0).round() as u32;
    std::thread::spawn(move || {
        let script = format!(
            "(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, {})",
            pct
        );
        let _ = hidden_cmd("powershell")
            .args(["-NoProfile", "-WindowStyle", "Hidden", "-Command", &script])
            .status();
    });
}

/// Membaca status dan kekuatan sinyal Wi-Fi saat ini via `netsh wlan show interfaces`
pub fn query_wifi_status() -> (bool, f32) {
    let output = hidden_cmd("netsh")
        .args(["wlan", "show", "interfaces"])
        .output();
    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout);
        let mut connected = false;
        let mut signal = 0.0f32;
        for line in text.lines() {
            let trimmed = line.trim();
            let lower = trimmed.to_lowercase();
            if lower.starts_with("state") && lower.contains("connected") && !lower.contains("disconnected") {
                connected = true;
            } else if lower.starts_with("signal") {
                if let Some(val_part) = trimmed.split(':').nth(1) {
                    let digits: String = val_part.chars().filter(|c| c.is_ascii_digit()).collect();
                    if let Ok(pct) = digits.parse::<u32>() {
                        signal = (pct as f32 / 100.0).clamp(0.0, 1.0);
                    }
                }
            }
        }
        if connected {
            return (true, if signal > 0.01 { signal } else { 0.85 });
        }
    }
    (true, 0.88)
}

/// Toggle adapter Wi-Fi Windows secara asinkron
pub fn apply_wifi_toggle_async(enabled: bool) {
    let state = if enabled { "enabled" } else { "disabled" };
    std::thread::spawn(move || {
        let _ = hidden_cmd("netsh")
            .args([
                "interface",
                "set",
                "interface",
                "name=Wi-Fi",
                &format!("admin={}", state),
            ])
            .status();
    });
}

/// Membuka halaman Windows Settings (ms-settings:...) secara asinkron
pub fn open_windows_settings(uri: &'static str) {
    std::thread::spawn(move || {
        let _ = hidden_cmd("cmd").args(["/C", "start", "", uri]).status();
    });
}
