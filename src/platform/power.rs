use windows::Win32::System::Power::{GetSystemPowerStatus, SYSTEM_POWER_STATUS};

#[derive(Debug, Clone, Copy)]
pub struct BatteryInfo {
    pub percent: f32,       // 0.0 .. 1.0
    pub is_charging: bool,
    #[allow(dead_code)]
    pub has_battery: bool,
    pub life_time_secs: u32,
}

pub fn get_battery_info() -> BatteryInfo {
    let mut status = SYSTEM_POWER_STATUS::default();
    if unsafe { GetSystemPowerStatus(&mut status).is_ok() } {
        let percent = if status.BatteryLifePercent == 255 {
            1.0
        } else {
            (status.BatteryLifePercent as f32) / 100.0
        };
        let is_charging = (status.BatteryFlag & 8) != 0 || status.ACLineStatus == 1;
        let has_battery = status.BatteryFlag != 128 && status.BatteryLifePercent != 255;
        let life_time_secs = if status.BatteryLifeTime == u32::MAX {
            0
        } else {
            status.BatteryLifeTime
        };
        BatteryInfo {
            percent,
            is_charging,
            has_battery,
            life_time_secs,
        }
    } else {
        BatteryInfo {
            percent: 1.0,
            is_charging: true,
            has_battery: false,
            life_time_secs: 0,
        }
    }
}
