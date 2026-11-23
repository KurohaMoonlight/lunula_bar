// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 1: AVAILABLE NETWORKS (344x320 px, SUB_HALF_W = 172)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_networks_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    wifi_on: bool,
    sig: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold      = hex(230.0, 195.0, 132.0);
    let gold_hi   = hex(255.0, 238.0, 178.0);
    let muted_txt = hex(145.0, 152.0, 172.0);
    let aqua      = hex(127.0, 180.0, 202.0);

    let act_idx = (select(0u, 1u, fly_flag(15u)) | select(0u, 2u, fly_flag(16u)));

    // Header: Back (-126, -114) & Refresh (+126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, back_c, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    let ref_c = center + vec2<f32>(126.0, -114.0) * pop;
    let t_ref = draw_fly_tile(p, mouse_pos, ref_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_ref.col;
    fg_alpha = t_ref.alpha;
    let ref_ic = icon_refresh_sdf(p, ref_c, 1.38 * pop);
    fg_col = mix(fg_col, aqua, ref_ic * reveal);
    fg_alpha = max(fg_alpha, ref_ic * reveal);

    // 3 Network Rows (y = -56, +2, +60; half 150x26)
    var ys = array<f32, 3>(-56.0, 2.0, 60.0);
    var sigs = array<f32, 3>(sig, 0.68, 0.48);
    for (var i = 0u; i < 3u; i = i + 1u) {
        let nc = center + vec2<f32>(0.0, ys[i]) * pop;
        let is_act = wifi_on && (act_idx == i);
        let t_n = draw_fly_tile(p, mouse_pos, nc, vec2<f32>(150.0, 26.0) * pop, 13.0 * pop, select(0.0, 1.0, is_act), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_n.col;
        fg_alpha = t_n.alpha;

        let nic = icon_wifi_sdf(p, t_n.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.45 * pop, select(0.0, sigs[i], wifi_on));
        fg_col = mix(fg_col, select(muted_txt, aqua, is_act), nic * reveal);
        fg_alpha = max(fg_alpha, nic * reveal);

        let nlock = icon_lock_sdf(p, t_n.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.30 * pop);
        fg_col = mix(fg_col, select(muted_txt, gold, is_act), nlock * reveal);
        fg_alpha = max(fg_alpha, nlock * reveal);
    }

    // Bottom Settings Bar (0, +116, half 150x18)
    let st_bar = center + vec2<f32>(0.0, 116.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, st_bar + vec2<f32>(-120.0, 0.0) * pop, 1.28 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, st_bar + vec2<f32>(122.0, 0.0) * pop, 1.25 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 2: BLUETOOTH DEVICES (344x320 px, SUB_HALF_W = 172)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_bluetooth_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold      = hex(230.0, 195.0, 132.0);
    let gold_hi   = hex(255.0, 238.0, 178.0);
    let muted_txt = hex(145.0, 152.0, 172.0);
    let aqua      = hex(127.0, 180.0, 202.0);
    let green     = hex(152.0, 187.0, 108.0);

    // Header: Back & Refresh
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, back_c, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    let ref_c = center + vec2<f32>(126.0, -114.0) * pop;
    let t_ref = draw_fly_tile(p, mouse_pos, ref_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_ref.col;
    fg_alpha = t_ref.alpha;
    let ref_ic = icon_refresh_sdf(p, ref_c, 1.38 * pop);
    fg_col = mix(fg_col, aqua, ref_ic * reveal);
    fg_alpha = max(fg_alpha, ref_ic * reveal);

    // 3 Bluetooth Device Rows
    var ys = array<f32, 3>(-56.0, 2.0, 60.0);
    var conns = array<bool, 3>(fly_flag(12u), fly_flag(13u), fly_flag(14u));
    for (var i = 0u; i < 3u; i = i + 1u) {
        let dc = center + vec2<f32>(0.0, ys[i]) * pop;
        let is_conn = conns[i];
        let t_d = draw_fly_tile(p, mouse_pos, dc, vec2<f32>(150.0, 26.0) * pop, 13.0 * pop, select(0.0, 1.0, is_conn), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_d.col;
        fg_alpha = t_d.alpha;

        var dic = 0.0;
        if (i == 1u) {
            dic = icon_monitor_sdf(p, t_d.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.35 * pop);
        } else {
            dic = icon_headphones_sdf(p, t_d.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.38 * pop);
        }
        fg_col = mix(fg_col, select(muted_txt, aqua, is_conn), dic * reveal);
        fg_alpha = max(fg_alpha, dic * reveal);

        // Connection status LED dot on right (+122)
        let dot_d = length(p - (t_d.eff_center + vec2<f32>(122.0, 0.0) * pop));
        let dot_a = (1.0 - smoothstep(3.6 * pop, 5.0 * pop, dot_d)) * reveal;
        fg_col = mix(fg_col, select(hex(62.0, 70.0, 88.0), green, is_conn), dot_a);
        fg_alpha = max(fg_alpha, dot_a);
    }

    // Bottom Settings Bar
    let st_bar = center + vec2<f32>(0.0, 116.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, st_bar + vec2<f32>(-120.0, 0.0) * pop, 1.28 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, st_bar + vec2<f32>(122.0, 0.0) * pop, 1.25 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 3: WI-FI PASSWORD INPUT (344x320 px, SUB_HALF_W = 172)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_password_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold      = hex(230.0, 195.0, 132.0);
    let gold_hi   = hex(255.0, 238.0, 178.0);
    let muted_txt = hex(145.0, 152.0, 172.0);
    let aqua      = hex(127.0, 180.0, 202.0);
    let pw_show   = fly_flag(10u);

    // Header: Back (-126, -114) & Lock emblem (+126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, back_c, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    let lk_ic = icon_lock_sdf(p, center + vec2<f32>(126.0, -114.0) * pop, 1.45 * pop);
    fg_col = mix(fg_col, gold, lk_ic * reveal);
    fg_alpha = max(fg_alpha, lk_ic * reveal);

    // Target Network Info Card (0, -56, half 150x26)
    let info_c = center + vec2<f32>(0.0, -56.0) * pop;
    let t_info = draw_fly_tile(p, mouse_pos, info_c, vec2<f32>(150.0, 26.0) * pop, 13.0 * pop, 0.65, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_info.col;
    fg_alpha = t_info.alpha;
    let w_ic = icon_wifi_sdf(p, info_c + vec2<f32>(-120.0, 0.0) * pop, 1.48 * pop, 0.85);
    fg_col = mix(fg_col, aqua, w_ic * reveal);
    fg_alpha = max(fg_alpha, w_ic * reveal);

    // Recessed Obsidian Password Input Box (0, +8, half 150x24) with glowing Kintsugi Gold focus rim
    let inp_c = center + vec2<f32>(0.0, 8.0) * pop;
    let inp_h = vec2<f32>(150.0, 24.0) * pop;
    let d_inp = sd_rounded_box(p - inp_c, inp_h, 12.0 * pop);
    let inp_a = (1.0 - smoothstep(-0.7, 0.7, d_inp)) * reveal;
    if (inp_a > 0.001) {
        let vy = clamp((p.y - (inp_c.y - inp_h.y)) / max(inp_h.y * 2.0, 1.0), 0.0, 1.0);
        var icol = mix(hex(10.0, 12.0, 19.0), hex(16.0, 19.0, 29.0), vy);
        let irim = 1.0 - smoothstep(0.0, 1.4, abs(d_inp));
        let pulse = 0.72 + 0.28 * sin(u.time * 2.4);
        icol = mix(icol, mix(gold, gold_hi, pulse), irim * 0.90);
        fg_col = mix(fg_col, icol, inp_a * 0.98);
        fg_alpha = max(fg_alpha, inp_a * 0.98);
    }

    // Show / Hide Password Eye Icon (+122, +8)
    let eye_c = center + vec2<f32>(122.0, 8.0) * pop;
    let eye_ic = icon_eye_sdf(p, eye_c, 1.65 * pop, !pw_show);
    fg_col = mix(fg_col, select(muted_txt, gold_hi, pw_show), eye_ic * reveal);
    fg_alpha = max(fg_alpha, eye_ic * reveal);

    // Action Buttons: Cancel (-76, +98) & Connect (+76, +98)
    let can_c = center + vec2<f32>(-76.0, 98.0) * pop;
    let t_can = draw_fly_tile(p, mouse_pos, can_c, vec2<f32>(68.0, 22.0) * pop, 12.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_can.col;
    fg_alpha = t_can.alpha;

    let con_c = center + vec2<f32>(76.0, 98.0) * pop;
    let t_con = draw_fly_tile(p, mouse_pos, con_c, vec2<f32>(68.0, 22.0) * pop, 12.0 * pop, 1.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_con.col;
    fg_alpha = t_con.alpha;

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
