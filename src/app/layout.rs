use crate::flyout::start_menu::StartMenuState;
use crate::flyout::{
    ActiveFlyout, FlyoutManager, CHAIN_MAIN_TO_SUB, CHAIN_SUB_TO_SUB, FLY_HALF_H, FLY_HALF_W,
    FLY_RISE, SUB_HALF_H, SUB_HALF_W, SUB_OFFSET_Y,
};

/// Tinggi dinamis jendela transparan: selalu muat untuk Pilar AOT 60% layar + margin aura atas.
pub fn dynamic_window_height(screen_h: u32) -> u32 {
    let target = ((screen_h as f32) * 0.72).round() as u32;
    target.max(640).min(screen_h)
}

pub fn tray_center_x(screen_w: u32) -> f32 {
    let cx = (screen_w as f32) * 0.5;
    let bar_width = (screen_w as f32) * 0.50;
    let bar_right = cx + bar_width * 0.5;
    bar_right - 196.0
}

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

#[allow(clippy::type_complexity)]
pub fn compute_hit_zones(
    screen_w: u32,
    screen_h: u32,
    window_h: u32,
    flyout_center_x: f32,
    sub1_off_x: f32,
    sub2_off_x: f32,
    mgr: &FlyoutManager,
) -> (
    Option<(i32, i32, i32, i32, i32, i32)>,
    Option<(i32, i32, i32, i32)>,
    Option<(i32, i32, i32, i32)>,
) {
    let window_top = (screen_h.saturating_sub(window_h)) as f32;
    let wy = widget_y(window_h);

    let flyout_zone = if mgr.is_open() {
        let head_y_screen = window_top + wy - FLY_RISE * mgr.current_open_t.min(1.0);
        Some((
            (head_y_screen - FLY_HALF_H - 16.0) as i32,
            (head_y_screen + FLY_HALF_H + 16.0) as i32,
            (flyout_center_x - FLY_HALF_W - 16.0) as i32,
            (flyout_center_x + FLY_HALF_W + 16.0) as i32,
            flyout_center_x as i32,
            head_y_screen as i32,
        ))
    } else if mgr.start.is_active() && mgr.start.phase2_t > 0.005 {
        // Region mengikuti bentuk pohon Fukinagashi yang condong ke kanan + padding luas (> glow radius)
        // agar TIDAK PERNAH ada tepi kotak/glow terpotong.
        let wx = win_button_x(screen_w);
        let bar_top_screen = (screen_h as f32) - 108.0;
        let full_rise = StartMenuState::pillar_rise_px(screen_h);
        let cur_rise = full_rise * mgr.start.phase2_t.clamp(0.0, 1.05);
        let lean_right = full_rise * 0.44 + 135.0;
        let top_screen = (bar_top_screen - cur_rise - 96.0).max(window_top);
        let bot_screen = bar_top_screen + 16.0;
        let mid_y = (top_screen + bot_screen) * 0.5;
        Some((
            top_screen as i32,
            bot_screen as i32,
            (wx - 95.0).max(0.0) as i32,
            (wx + lean_right).min(screen_w as f32) as i32,
            (wx + lean_right * 0.35) as i32,
            mid_y as i32,
        ))
    } else {
        None
    };

    let sub_cy_screen = window_top + wy - FLY_RISE + SUB_OFFSET_Y;

    let sub1_zone = if mgr.is_open() && (mgr.slot1_open || mgr.slot1_open_t > 0.005) {
        let sub_cx = flyout_center_x + sub1_off_x;
        Some((
            (sub_cy_screen - SUB_HALF_H - 16.0) as i32,
            (sub_cy_screen + SUB_HALF_H + 16.0) as i32,
            (sub_cx - SUB_HALF_W - 16.0) as i32,
            (sub_cx + SUB_HALF_W + 16.0) as i32,
        ))
    } else {
        None
    };

    let sub2_zone = if mgr.is_open() && (mgr.slot2_open || mgr.slot2_open_t > 0.005) {
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

    (flyout_zone, sub1_zone, sub2_zone)
}
