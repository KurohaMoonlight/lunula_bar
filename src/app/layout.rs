use crate::flyout::{
    ActiveFlyout, FlyoutManager, CHAIN_MAIN_TO_SUB, CHAIN_SUB_TO_SUB, FLY_HALF_H, FLY_HALF_W,
    FLY_RISE, SUB_HALF_H, SUB_HALF_W, SUB_OFFSET_Y,
};

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

/// Koordinat pusat (cx, cy) lokal-window untuk Zen Search Pill.
/// Rumus identik 1:1 dengan `get_search_pill_rest_center` & `render_zen_search_pill` di `09_start_roots.wgsl`.
pub fn search_pill_center_local(screen_w: u32, window_h: u32, search_pill_t: f32) -> (f32, f32) {
    let cx = (screen_w as f32) * 0.5;
    let half_w = (screen_w as f32) * 0.25; // bar_width = screen_w * 0.50 -> half_w = screen_w * 0.25
    let sx = (half_w / 450.0) * 1.28;
    let lip_center_y = (window_h as f32) - 108.0;
    let h_fork = (window_h as f32) * 0.42;
    let t = search_pill_t.clamp(0.0, 1.0);
    let t_sc = t * t * (3.0 - 2.0 * t); // smoothstep(0.0, 1.0, t)
    let rise = (1.0 - t_sc) * 16.0;
    let pill_cx = cx + (185.0 * sx).max(205.0);
    let pill_cy = lip_center_y - h_fork * 0.28 + rise;
    (pill_cx, pill_cy)
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
    } else if mgr.start.is_active() && mgr.start.search_pill_t > 0.05 {
        // Hit-test khusus untuk Tinted Sumi Search Pill di dahan kanan (500x56 px)
        // Sinkron 1:1 dengan shader via search_pill_center_local; area luar tetap HTTRANSPARENT!
        let (pill_cx, pill_cy_local) =
            search_pill_center_local(screen_w, window_h, mgr.start.search_pill_t);
        let pill_cy = window_top + pill_cy_local;
        Some((
            (pill_cy - 30.0) as i32,
            (pill_cy + 30.0) as i32,
            (pill_cx - 256.0) as i32,
            (pill_cx + 256.0) as i32,
            pill_cx as i32,
            pill_cy as i32,
        ))
    } else {
        // Area pohon sakura di luar pill bersifat ambient transparan (100% click-through)
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
