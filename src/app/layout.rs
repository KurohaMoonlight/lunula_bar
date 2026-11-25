use crate::flyout::{
    ActiveFlyout, FlyoutManager, CHAIN_MAIN_TO_SUB, CHAIN_SUB_TO_SUB, FLY_HALF_H, FLY_HALF_W,
    FLY_RISE, SUB_HALF_H, SUB_HALF_W, SUB_OFFSET_Y,
};

/// Zona hit-test aktif yang dikirim ke Win32 click-through engine.
pub struct HitZones {
    pub flyout: Option<(i32, i32, i32, i32, i32, i32)>,
    /// `true` untuk Tray Flyout (Wi-Fi/Volume/Battery) yang punya leher/stalk cair ke taskbar;
    /// `false` untuk floating Zen Search Pill agar area di bawah pill 100% bolong & click-through.
    pub flyout_has_stalk: bool,
    pub sub1: Option<(i32, i32, i32, i32)>,
    pub sub2: Option<(i32, i32, i32, i32)>,
}

/// Tinggi dinamis jendela transparan: selalu muat untuk Pilar AOT 60% layar + margin aura atas.
pub fn dynamic_window_height(screen_h: u32) -> u32 {
    let target = ((screen_h as f32) * 0.88).round() as u32;
    target.max(760).min(screen_h)
}

pub fn tray_center_x(screen_w: u32) -> f32 {
    let cx = (screen_w as f32) * 0.5;
    let bar_width = (screen_w as f32) * 0.50;
    let bar_right = cx + bar_width * 0.5;
    bar_right - 196.0
}

#[allow(dead_code)]
pub fn win_button_x(screen_w: u32) -> f32 {
    let cx = (screen_w as f32) * 0.5;
    let bar_width = (screen_w as f32) * 0.50;
    (cx - bar_width * 0.5) + 54.0
}

pub fn active_flyout_center_x(screen_w: u32, active: ActiveFlyout) -> f32 {
    let tray_x = tray_center_x(screen_w);
    match active {
        ActiveFlyout::Wifi => tray_x - 40.0,
        ActiveFlyout::Volume => tray_x,
        ActiveFlyout::Battery => tray_x + 38.0,
        ActiveFlyout::None => tray_x,
    }
}

pub fn widget_y(window_h: u32) -> f32 {
    let area_h = window_h as f32;
    (area_h - 108.0) + 108.0 * 0.46
}

/// Koordinat pusat (cx, cy) lokal-window untuk Zen Search Pill (di dahan KANAN).
/// Berbentuk lampion besar (Chōchin) bercahaya hangat di dahan pohon sakura sisi kanan.
pub fn search_pill_center_local(screen_w: u32, window_h: u32, search_pill_t: f32) -> (f32, f32) {
    let cx = (screen_w as f32) * 0.5;
    let half_w = (screen_w as f32) * 0.25;
    let sx = (half_w / 450.0) * 1.28;
    let lip_center_y = (window_h as f32) - 108.0;
    let h_fork = (window_h as f32) * 0.42;
    let t = search_pill_t.clamp(0.0, 1.0);
    let t_sc = t * t * (3.0 - 2.0 * t);
    let expand_x = (t / 0.92).clamp(0.0, 1.0);
    let expand_x_s = expand_x * expand_x * (3.0 - 2.0 * expand_x);
    let anchor_shift_x = -(1.0 - expand_x_s) * 96.0;
    let rise = (1.0 - t_sc) * 14.0;
    let pill_cx = cx + (205.0 * sx).max(225.0) + anchor_shift_x;
    let pill_cy = lip_center_y - h_fork * 0.44 + rise;
    (pill_cx, pill_cy)
}

/// Koordinat pusat (cx, cy) lokal-window untuk Hasil Pencarian Tanzaku (di dahan KIRI).
/// Bertengger & menggantung anggun dari dahan sakura baru yang LEBIH TINGGI di sisi kiri.
pub fn search_results_center_local(screen_w: u32, window_h: u32, results_reveal_t: f32) -> (f32, f32) {
    let cx = (screen_w as f32) * 0.5;
    let half_w = (screen_w as f32) * 0.25;
    let sx = (half_w / 450.0) * 1.28;
    let lip_center_y = (window_h as f32) - 108.0;
    let h_fork = (window_h as f32) * 0.42;
    let t = results_reveal_t.clamp(0.0, 1.0);
    let t_sc = t * t * (3.0 - 2.0 * t);
    let rise = (1.0 - t_sc) * 12.0;
    let res_cx = cx - (195.0 * sx).max(215.0);
    // Dahan kiri dibangun lebih tinggi (0.76 * h_fork) agar kartu menggantung lega di atas taskbar
    let res_cy = lip_center_y - h_fork * 0.76 + rise;
    (res_cx, res_cy)
}

pub fn calculate_chain_offsets(screen_w: u32, fly_cx: f32) -> (f32, f32, bool) {
    let margin = 16.0;
    let sw = screen_w as f32;

    let left1_ok = (fly_cx - CHAIN_MAIN_TO_SUB - SUB_HALF_W) >= margin;
    let right1_ok = (fly_cx + CHAIN_MAIN_TO_SUB + SUB_HALF_W) <= (sw - margin);

    let sub1_off = if left1_ok {
        -CHAIN_MAIN_TO_SUB
    } else if right1_ok {
        CHAIN_MAIN_TO_SUB
    } else {
        let clamped_cx =
            (fly_cx - CHAIN_MAIN_TO_SUB).clamp(SUB_HALF_W + margin, sw - SUB_HALF_W - margin);
        clamped_cx - fly_cx
    };

    let chain_left_off = sub1_off - CHAIN_SUB_TO_SUB;
    if sub1_off < 0.0 && (fly_cx + chain_left_off - SUB_HALF_W) >= margin {
        return (sub1_off, chain_left_off, false);
    }

    if sub1_off < 0.0 && right1_ok {
        return (sub1_off, CHAIN_MAIN_TO_SUB, true);
    }

    let chain_right_off = sub1_off + CHAIN_SUB_TO_SUB;
    if sub1_off > 0.0 && (fly_cx + chain_right_off + SUB_HALF_W) <= (sw - margin) {
        return (sub1_off, chain_right_off, false);
    }

    let fallback_cx =
        (fly_cx + CHAIN_MAIN_TO_SUB).clamp(SUB_HALF_W + margin, sw - SUB_HALF_W - margin);
    (sub1_off, fallback_cx - fly_cx, true)
}

pub fn compute_hit_zones(
    screen_w: u32,
    screen_h: u32,
    window_h: u32,
    flyout_center_x: f32,
    sub1_off_x: f32,
    sub2_off_x: f32,
    mgr: &FlyoutManager,
) -> HitZones {
    let window_top = (screen_h.saturating_sub(window_h)) as f32;
    let wy = widget_y(window_h);

    let (flyout, flyout_has_stalk) = if mgr.is_open() {
        let head_y_screen = window_top + wy - FLY_RISE * mgr.current_open_t.min(1.0);
        (
            Some((
                (head_y_screen - FLY_HALF_H - 16.0) as i32,
                (head_y_screen + FLY_HALF_H + 16.0) as i32,
                (flyout_center_x - FLY_HALF_W - 16.0) as i32,
                (flyout_center_x + FLY_HALF_W + 16.0) as i32,
                flyout_center_x as i32,
                head_y_screen as i32,
            )),
            true,
        )
    } else if mgr.start.is_active() && mgr.start.search_pill_t > 0.05 {
        // Hit-test khusus untuk Search Bar di dahan KANAN (Lampion Besar 570x76 px).
        // `flyout_has_stalk = false`: area di sekitarnya 100% click-through!
        let (pill_cx, pill_cy_local) =
            search_pill_center_local(screen_w, window_h, mgr.start.search_pill_t);
        let pill_cy = window_top + pill_cy_local;
        (
            Some((
                (pill_cy - 40.0) as i32,
                (pill_cy + 40.0) as i32,
                (pill_cx - 290.0) as i32,
                (pill_cx + 290.0) as i32,
                pill_cx as i32,
                pill_cy as i32,
            )),
            false,
        )
    } else {
        // Area pohon sakura di luar pill bersifat ambient transparan (100% click-through)
        (None, false)
    };

    let sub_cy_screen = window_top + wy - FLY_RISE + SUB_OFFSET_Y;

    let sub1 = if mgr.is_open() && (mgr.slot1_open || mgr.slot1_open_t > 0.005) {
        let sub_cx = flyout_center_x + sub1_off_x;
        Some((
            (sub_cy_screen - SUB_HALF_H - 16.0) as i32,
            (sub_cy_screen + SUB_HALF_H + 16.0) as i32,
            (sub_cx - SUB_HALF_W - 16.0) as i32,
            (sub_cx + SUB_HALF_W + 16.0) as i32,
        ))
    } else if mgr.start.is_active() && mgr.start.results_reveal_t > 0.05 {
        // Hit-test presisi untuk 5 Tanzaku Result Tags di dahan KIRI (Dahan lebih tinggi).
        let (res_cx, res_cy_local) =
            search_results_center_local(screen_w, window_h, mgr.start.results_reveal_t);
        let res_cy = window_top + res_cy_local;
        let card_reach = 5.0 * 50.0 * mgr.start.results_reveal_t;
        Some((
            (res_cy + 12.0) as i32,
            (res_cy + 18.0 + card_reach) as i32,
            (res_cx - 235.0) as i32,
            (res_cx + 235.0) as i32,
        ))
    } else {
        None
    };

    let sub2 = if mgr.is_open() && (mgr.slot2_open || mgr.slot2_open_t > 0.005) {
        let sub_cx = flyout_center_x + sub2_off_x;
        Some((
            (sub_cy_screen - SUB_HALF_H - 16.0) as i32,
            (sub_cy_screen + SUB_HALF_H + 16.0) as i32,
            (sub_cx - SUB_HALF_W - 16.0) as i32,
            (sub_cx + SUB_HALF_W + 16.0) as i32,
        ))
    } else {
        None
    };

    HitZones {
        flyout,
        flyout_has_stalk,
        sub1,
        sub2,
    }
}
