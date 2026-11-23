/// Single source of truth for 2D SDF geometry shared conceptually between CPU hit-test/SetWindowRgn
/// and GPU rendering (`src/render/shaders/glob.wgsl`).
/// All coordinates are in virtual screen-space pixels (relative to the bottom-anchored bar canvas).

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TaskbarShapeParams {
    pub canvas_w: f32,
    pub canvas_h: f32,
    pub bar_width: f32,
    pub bar_height: f32,
    pub corner_radius: f32,
    pub fillet_radius: f32,
    pub anim_t: f32,
    pub pull_strength: f32,
    pub mouse_x: f32,
    pub mouse_y: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FlyoutShapeParams {
    pub module_id: u32, // 0=none, 1=volume, 2=battery, 3=wifi
    pub theme_id: u32,  // 0=LiquidSpire, 1=SumiCloud, 2=PureHud
    pub open_t: f32,
    pub sub_open_t: f32,
    pub anchor_x: f32,
    pub anchor_y: f32,
    pub bar_top: f32,
    pub fly_rise: f32,
    pub dpi_scale: f32,
    pub time: f32,
}

#[inline]
pub fn clamp(x: f32, lo: f32, hi: f32) -> f32 {
    x.max(lo).min(hi)
}

#[inline]
pub fn mix(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

#[inline]
pub fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = clamp((x - edge0) / (edge1 - edge0).max(1e-6), 0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

#[inline]
pub fn sd_rounded_box(px: f32, py: f32, bx: f32, by: f32, r: f32) -> f32 {
    let qx = px.abs() - bx + r;
    let qy = py.abs() - by + r;
    let mx = qx.max(0.0);
    let my = qy.max(0.0);
    qx.max(qy).min(0.0) + (mx * mx + my * my).sqrt() - r
}

#[inline]
pub fn sd_seg(px: f32, py: f32, ax: f32, ay: f32, bx: f32, by: f32) -> f32 {
    let pax = px - ax;
    let pay = py - ay;
    let bax = bx - ax;
    let bay = by - ay;
    let denom = (bax * bax + bay * bay).max(1e-6);
    let h = clamp((pax * bax + pay * bay) / denom, 0.0, 1.0);
    let dx = pax - bax * h;
    let dy = pay - bay * h;
    (dx * dx + dy * dy).sqrt()
}

#[inline]
pub fn smin_cubic(a: f32, b: f32, k: f32) -> f32 {
    if k <= 1e-5 {
        return a.min(b);
    }
    let h = (k - (a - b).abs()).max(0.0) / k;
    a.min(b) - h * h * h * k * (1.0 / 6.0)
}

/// Evaluates the exact taskbar glob SDF matching `fs_main` in `glob.wgsl`.
pub fn eval_taskbar_sdf(px: f32, py: f32, p: &TaskbarShapeParams) -> f32 {
    let cx = p.canvas_w * 0.5;
    let bottom_y = p.canvas_h;

    let t_anim = clamp(p.anim_t, 0.0, 1.15);
    let smooth_t = smoothstep(0.0, 1.0, t_anim.min(1.0));
    let overshoot = (t_anim - 1.0).max(0.0) * 14.0;

    let half_w = p.bar_width * 0.5;
    let norm_x = clamp((px - cx).abs() / half_w.max(1.0), 0.0, 1.0);

    let surge_front = smoothstep(norm_x * 0.55, 1.0, smooth_t);
    let bulge_factor = (smooth_t * std::f32::consts::PI).sin() * (1.0 - norm_x * norm_x) * 22.0;

    let base_height = mix(8.0, p.bar_height, surge_front) + bulge_factor + overshoot;
    let half_h_base = base_height * 0.5;
    let bar_center_y = bottom_y - half_h_base;

    let dx_m = px - p.mouse_x;
    let dy_m = py - p.mouse_y;
    let dist_p_to_mouse = (dx_m * dx_m + dy_m * dy_m).sqrt();
    let influence_radius = 260.0;
    let norm_dist = clamp(dist_p_to_mouse / influence_radius, 0.0, 1.0);
    let soft_bell = (norm_dist * std::f32::consts::FRAC_PI_2).cos();

    let max_warp = 26.0 * p.pull_strength * smoothstep(0.25, 1.0, p.anim_t);
    let inv_d = 1.0 / dist_p_to_mouse.max(1.0);
    let pull_vx = (p.mouse_x - px) * inv_d;
    let pull_vy = (p.mouse_y - py) * inv_d;
    let warp_s = soft_bell * soft_bell * max_warp;
    let wx = px - pull_vx * warp_s;
    let wy = py - pull_vy * warp_s;

    let eff_corner = mix(4.0, p.corner_radius, surge_front);
    let eff_fillet = mix(28.0, p.fillet_radius, surge_front);

    let d_box = sd_rounded_box(wx - cx, wy - bar_center_y, half_w, half_h_base, eff_corner);
    let d_floor = bottom_y - py;
    let d_glob = smin_cubic(d_box, d_floor, eff_fillet);
    d_glob.max(-d_floor)
}

/// Evaluates the exact LiquidSpire SDF (meniscus + vertical column + head + sub-flyout + Organic Glob Bridge).
pub fn eval_liquid_sdf(px: f32, py: f32, f: &FlyoutShapeParams) -> f32 {
    let s = f.dpi_scale.max(0.5);
    let open_t = f.open_t;
    let tension = smoothstep(0.0, 0.22, open_t);
    let rise = smoothstep(0.14, 0.66, open_t);
    let head = smoothstep(0.52, 0.80, open_t);

    let over_px = (open_t - 1.0).max(0.0) * 14.0 * s;
    let head_y = f.anchor_y - f.fly_rise * s - over_px;
    let ax = f.anchor_x;
    let bar_top = f.bar_top;

    let dx = px - ax;
    let gate = smoothstep(0.0, 0.6, tension);
    let flow_env = smoothstep(0.0, 0.3, rise) * gate;

    let peak_h = (15.0 * tension + 7.0 * rise) * s;
    let wp = (20.0 + 8.0 * rise) * s;
    let sr = (dx * dx + s * s).sqrt();
    let h = peak_h * (-sr / wp.max(1.0)).exp();
    let slope = h * dx / (wp * sr).max(1.0);
    let d_surf = ((bar_top - h) - py) / (1.0 + slope * slope).sqrt();

    let tip_y = mix(bar_top - peak_h * 0.9, head_y, rise);
    let base_y = bar_top + 10.0 * s;
    let col_len = (base_y - tip_y).max(1.0);
    let yy = clamp(py, tip_y, base_y);
    let prog_s = (base_y - yy) / col_len;

    let sway = (prog_s * 5.0 - f.time * 1.9).sin() * 2.6 * s * (prog_s * std::f32::consts::PI).sin() * flow_env;
    let bulge = (yy / s * 0.085 - f.time * 4.2).sin() * 1.5 * s * flow_env * (1.0 - prog_s * 0.5);
    let r_col = ((5.4 + 3.8 * smoothstep(0.1, 0.9, rise)) * s + bulge) * gate;
    let r_here = r_col * mix(1.0, 0.72, prog_s * (1.0 - head));
    let d_col = ((dx - sway).powi(2) + (py - yy).powi(2)).sqrt() - r_here;

    let mut d = smin_cubic(d_surf, d_col, (6.0 + 12.0 * tension) * s);

    let breathe = (f.time * 1.6).sin() * 2.2 * s * head;
    let head_sz_x = mix(r_col * 1.5, 245.0 * s, head);
    let head_sz_y = mix(r_col * 1.7, 155.0 * s, head);
    let head_hs_x = head_sz_x + breathe;
    let head_hs_y = (head_sz_y - breathe * 0.5).max(1.0);
    let head_rad = mix((head_hs_x.min(head_hs_y) * 0.85).max(0.5), 44.0 * s, head);
    let d_head = sd_rounded_box(px - ax, py - tip_y, head_hs_x, head_hs_y, head_rad);
    d = smin_cubic(d, d_head, (14.0 + 24.0 * head) * s);

    // Sub-flyout chamber & Organic Glob Bridge
    if f.module_id == 3 && f.sub_open_t > 0.005 {
        let sub_t = clamp(f.sub_open_t, 0.0, 1.0);
        let sub_cx = ax - 530.0 * s * sub_t;
        let d_sub = sd_rounded_box(px - sub_cx, py - tip_y, 245.0 * s * sub_t, 155.0 * s * sub_t, 42.0 * s * sub_t);

        let neck_p0x = ax - 235.0 * s * head;
        let neck_p1x = sub_cx + 235.0 * s * sub_t;
        let neck_d = sd_seg(px, py, neck_p0x, tip_y, neck_p1x, tip_y);
        let neck_ripple = (px / s * 0.08 + f.time * 3.5).sin() * 3.0 * s * sub_t;
        let neck_r = (22.0 * s * sub_t + neck_ripple) * head;
        let d_neck = neck_d - neck_r.max(1.0);

        let d_sub_branch = smin_cubic(d_sub, d_neck, 18.0 * s * sub_t);
        d = smin_cubic(d, d_sub_branch, 24.0 * s * sub_t);
    }

    // Clip below taskbar top surface so flyout region doesn't overlap bar unnecessarily
    let d_above_bar = py - (bar_top + 4.0 * s);
    d.max(d_above_bar)
}

/// Evaluates the unified flyout SDF across all 3 themes (`LiquidSpire`, `SumiCloud`, `PureHud`).
/// Negative values are inside the clickable shape; positive values are transparent click-through.
pub fn eval_flyout_sdf(px: f32, py: f32, f: &FlyoutShapeParams) -> f32 {
    if f.open_t <= 0.005 || f.module_id == 0 {
        return 1e6;
    }

    let s = f.dpi_scale.max(0.5);
    match f.theme_id {
        0 => eval_liquid_sdf(px, py, f),
        1 => {
            // SumiCloud: organic rounded cloud envelope around main content (+ sub-flyout & bridge)
            let over_px = (f.open_t - 1.0).max(0.0) * 14.0 * s;
            let head_y = f.anchor_y - f.fly_rise * s - over_px;
            let blm = smoothstep(0.52, 0.86, f.open_t);
            let rx = (110.0 + 142.0 * blm) * s;
            let ry = (76.0 + 88.0 * blm) * s;
            let mut d = sd_rounded_box(px - f.anchor_x, py - head_y, rx, ry, 46.0 * s * blm.max(0.2));

            if f.module_id == 3 && f.sub_open_t > 0.01 {
                let sub_t = clamp(f.sub_open_t, 0.0, 1.0);
                let sub_cx = f.anchor_x - 530.0 * s * sub_t;
                let d_sub = sd_rounded_box(px - sub_cx, py - head_y, 245.0 * s * sub_t, 158.0 * s * sub_t, 44.0 * s * sub_t);
                let d_bridge = sd_seg(px, py, f.anchor_x - 220.0 * s, head_y, sub_cx + 220.0 * s * sub_t, head_y) - 24.0 * s * sub_t;
                d = smin_cubic(d, smin_cubic(d_sub, d_bridge, 16.0 * s), 18.0 * s);
            }
            d
        }
        _ => {
            // PureHud: tight card envelope around floating controls (+ sub-flyout)
            let t_bg = clamp(f.open_t / 0.72, 0.0, 1.0);
            let smooth_bg = smoothstep(0.0, 1.0, t_bg);
            let fly_h = (40.0 + (f.fly_rise - 40.0) * smooth_bg + (f.open_t - 1.0).max(0.0) * 12.0) * s;
            let t_content = clamp((f.open_t - 0.35) / 0.65, 0.0, 1.0);
            let sc = smoothstep(0.0, 1.0, t_content);
            if sc <= 0.01 {
                return 1e6;
            }
            let pop = 0.20 + 0.80 * sc + (f.open_t - 1.0).max(0.0) * 0.22;
            let rise_off = (1.0 - sc) * 16.0 * s;
            let cy = f.anchor_y - fly_h + rise_off;
            let hw = match f.module_id {
                3 => 226.0 * pop * s,
                _ => 176.0 * pop * s,
            };
            let hh = match f.module_id {
                3 => 142.0 * pop * s,
                _ => 126.0 * pop * s,
            };
            let mut d = sd_rounded_box(px - f.anchor_x, py - cy, hw, hh, 20.0 * s);
            if f.module_id == 3 && f.sub_open_t > 0.01 {
                let sub_t = clamp(f.sub_open_t, 0.0, 1.0);
                let sub_cx = f.anchor_x - 530.0 * s * sub_t;
                let sub_pop = 0.20 + 0.80 * sub_t;
                let d_sub = sd_rounded_box(px - sub_cx, py - cy, 226.0 * sub_pop * s, 142.0 * sub_pop * s, 20.0 * s);
                d = d.min(d_sub);
            }
            d
        }
    }
}

/// Computes the tight physical bounding box `(left, top, width, height)` in canvas coordinates
/// for the flyout window so it only covers the active flyout (+ sub-flyout if open).
pub fn flyout_bounding_box(f: &FlyoutShapeParams, canvas_w: u32, canvas_h: u32) -> (i32, i32, u32, u32) {
    let s = f.dpi_scale.max(0.5);
    let pad = (32.0 * s).ceil() as i32;
    let head_y = f.anchor_y - f.fly_rise * s;

    let mut min_x = (f.anchor_x - 252.0 * s) as i32 - pad;
    let max_x = (f.anchor_x + 252.0 * s) as i32 + pad;
    if f.module_id == 3 && f.sub_open_t > 0.005 {
        let sub_cx = f.anchor_x - 530.0 * s * clamp(f.sub_open_t, 0.0, 1.0);
        min_x = min_x.min((sub_cx - 252.0 * s) as i32 - pad);
    }

    let min_y = (head_y - 175.0 * s) as i32 - pad;
    let max_y = (f.bar_top + 16.0 * s) as i32;

    let left = min_x.clamp(0, canvas_w.saturating_sub(1) as i32);
    let top = min_y.clamp(0, canvas_h.saturating_sub(1) as i32);
    let right = max_x.clamp(left + 1, canvas_w as i32);
    let bottom = max_y.clamp(top + 1, canvas_h as i32);

    (left, top, (right - left) as u32, (bottom - top) as u32)
}

/// Builds coalesced `(left, top, right, bottom)` rectangles in local window coordinates
/// from a CPU SDF evaluator. `margin_px` adds a small outward margin (e.g., +2.0px) so
/// antialiased edges are never clipped by `SetWindowRgn`.
pub fn build_scanline_rects<F>(
    win_w: u32,
    win_h: u32,
    origin_x: f32,
    origin_y: f32,
    margin_px: f32,
    step_y: u32,
    eval_sdf: F,
) -> Vec<(i32, i32, i32, i32)>
where
    F: Fn(f32, f32) -> f32,
{
    let step = step_y.max(1) as i32;
    let w = win_w as i32;
    let h = win_h as i32;
    let mut rects: Vec<(i32, i32, i32, i32)> = Vec::with_capacity(128);

    // Track previous row's runs for vertical coalescing
    let mut prev_runs: Vec<(i32, i32, usize)> = Vec::new();
    let mut curr_runs: Vec<(i32, i32, usize)> = Vec::new();

    let mut y = 0;
    while y < h {
        let y_end = (y + step).min(h);
        let sample_y = origin_y + (y as f32) + (step as f32) * 0.5;
        curr_runs.clear();

        let mut x = 0;
        let mut in_run = false;
        let mut run_start = 0;

        // Sample horizontally every 2px for speed, snapping exact edges
        while x < w {
            let sample_x = origin_x + (x as f32) + 1.0;
            let inside = eval_sdf(sample_x, sample_y) <= margin_px;
            if inside && !in_run {
                in_run = true;
                run_start = x;
            } else if !inside && in_run {
                in_run = false;
                let run_end = x;
                // Try coalescing with previous scanline band
                if let Some(&(_, _, idx)) = prev_runs
                    .iter()
                    .find(|&&(pl, pr, _)| pl == run_start && pr == run_end)
                {
                    rects[idx].3 = y_end;
                    curr_runs.push((run_start, run_end, idx));
                } else {
                    let idx = rects.len();
                    rects.push((run_start, y, run_end, y_end));
                    curr_runs.push((run_start, run_end, idx));
                }
            }
            x += 2;
        }
        if in_run {
            let run_end = w;
            if let Some(&(_, _, idx)) = prev_runs
                .iter()
                .find(|&&(pl, pr, _)| pl == run_start && pr == run_end)
            {
                rects[idx].3 = y_end;
                curr_runs.push((run_start, run_end, idx));
            } else {
                let idx = rects.len();
                rects.push((run_start, y, run_end, y_end));
                curr_runs.push((run_start, run_end, idx));
            }
        }

        std::mem::swap(&mut prev_runs, &mut curr_runs);
        y += step;
    }

    rects
}
