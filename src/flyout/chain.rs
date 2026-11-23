use super::types::SubFlyoutKind;
use super::FlyoutManager;

impl FlyoutManager {
    pub fn is_password_active(&self) -> bool {
        (self.slot1_open && self.slot1_kind == SubFlyoutKind::WifiPassword)
            || (self.slot2_open && self.slot2_kind == SubFlyoutKind::WifiPassword)
    }

    pub fn is_sub_open(&self, kind: SubFlyoutKind) -> bool {
        (self.slot1_open && self.slot1_kind == kind) || (self.slot2_open && self.slot2_kind == kind)
    }

    /// Buka atau toggle sub-flyout dalam sistem Dual-Slot Chain (Slot 1 & Slot 2).
    pub fn toggle_sub_flyout(&mut self, kind: SubFlyoutKind) {
        if kind == SubFlyoutKind::None {
            return;
        }
        if self.slot1_open && self.slot1_kind == kind {
            self.close_slot1();
            return;
        }
        if self.slot2_open && self.slot2_kind == kind {
            self.slot2_open = false;
            return;
        }
        if !self.slot1_open && self.slot1_open_t < 0.05 {
            self.slot1_kind = kind;
            self.slot1_open = true;
            return;
        }
        self.slot2_kind = kind;
        self.slot2_open = true;
    }

    /// Buka form password Wi-Fi untuk jaringan tertentu (merantai di Slot 2 bila Wi-Fi Networks di Slot 1).
    pub fn open_wifi_password(&mut self, net_idx: usize) {
        self.pw_target_idx = net_idx.min(self.wifi_networks.len().saturating_sub(1));
        self.pw_input.clear();
        self.pw_show = false;
        self.pw_connecting = false;
        self.pw_connect_timer = 0.0;
        self.pw_status = "Press Enter or click Connect".into();

        if self.slot1_open && self.slot1_kind == SubFlyoutKind::WifiNetworks {
            self.slot2_kind = SubFlyoutKind::WifiPassword;
            self.slot2_open = true;
        } else if !self.slot1_open {
            self.slot1_kind = SubFlyoutKind::WifiPassword;
            self.slot1_open = true;
        } else {
            self.slot2_kind = SubFlyoutKind::WifiPassword;
            self.slot2_open = true;
        }
    }

    pub fn close_slot1(&mut self) {
        if self.slot1_kind == SubFlyoutKind::WifiNetworks
            && self.slot2_open
            && self.slot2_kind == SubFlyoutKind::WifiPassword
        {
            self.slot2_open = false;
        }
        self.slot1_open = false;
    }

    pub fn close_slot2(&mut self) {
        self.slot2_open = false;
    }

    pub fn close_all_subs(&mut self) {
        self.slot1_open = false;
        self.slot2_open = false;
    }

    pub fn handle_password_char(&mut self, ch: char) {
        if !self.is_password_active() || self.pw_connecting {
            return;
        }
        if !ch.is_control() && self.pw_input.len() < 63 {
            self.pw_input.push(ch);
            self.pw_status = format!("{} characters", self.pw_input.len());
        }
    }

    pub fn handle_password_backspace(&mut self) {
        if !self.is_password_active() || self.pw_connecting {
            return;
        }
        self.pw_input.pop();
        if self.pw_input.is_empty() {
            self.pw_status = "Press Enter or click Connect".into();
        } else {
            self.pw_status = format!("{} characters", self.pw_input.len());
        }
    }

    pub fn handle_password_submit(&mut self) {
        if !self.is_password_active() || self.pw_connecting {
            return;
        }
        if self.pw_input.len() < 8 {
            self.pw_status = "Minimum 8 characters required".into();
            return;
        }
        self.pw_connecting = true;
        self.pw_connect_timer = 0.85;
        let ssid = self.wifi_networks[self.pw_target_idx].ssid.clone();
        self.pw_status = format!("Connecting to {}...", ssid);
    }
}
