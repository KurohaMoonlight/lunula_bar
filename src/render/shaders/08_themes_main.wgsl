// ─────────────────────────────────────────────────────────────────────────────
// LIQUID SPIRE: SDF cairan tunggal (Main + Slot 1 + Slot 2 Chain / Split-Wing)
// ─────────────────────────────────────────────────────────────────────────────
fn liquid_sdf(
    p: vec2<f32>,
    ax: f32,
    bar_top: f32,
    head_y: f32,
    tension: f32,
    rise: f32,
    head: f32,
    time: f32,
) -> f32 {
    let dx = p.x - ax;
    let gate = smoothstep(0.0, 0.6, tension);
    let flow_env = smoothstep(0.0, 0.3, rise) * gate;

    let peak_h = 15.0 * tension + 7.0 * rise;
    let wp = 20.0 + 8.0 * rise;
    let sr = sqrt(dx * dx + 1.0);
    let h = peak_h * exp(-sr / wp);
    let slope = h * dx / (wp * sr);
    let d_surf = ((bar_top - h) - p.y) / sqrt(1.0 + slope * slope);

    let tip_y = mix(bar_top - peak_h * 0.9, head_y, rise);
    let base_y = bar_top + 10.0;
    let col_len = max(base_y - tip_y, 1.0);
    let yy = clamp(p.y, tip_y, base_y);
    let s = (base_y - yy) / col_len;

    let sway = sin(s * 5.0 - time * 1.9) * 2.6 * sin(s * 3.14159) * flow_env;
    let bulge = sin(yy * 0.085 - time * 4.2) * 1.5 * flow_env * (1.0 - s * 0.5);
    let r_col = (5.4 + 3.8 * smoothstep(0.1, 0.9, rise) + bulge) * gate;
    let r_here = r_col * mix(1.0, 0.72, s * (1.0 - head));
    let d_col = length(vec2<f32>(dx - sway, p.y - yy)) - r_here;

    var d = smin_cubic(d_surf, d_col, 6.0 + 12.0 * tension);

    // Main Flyout Head (432x320 -> half 216x160)
    let breathe = sin(time * 1.6) * 2.0 * head;
    let head_sz = mix(vec2<f32>(r_col * 1.5, r_col * 1.7), vec2<f32>(216.0, 160.0), head);
    let head_hs = vec2<f32>(head_sz.x + breathe, max(head_sz.y - breathe * 0.5, 1.0));
    let head_rad = mix(max(min(head_hs.x, head_hs.y) * 0.85, 0.5), 36.0, head);
    let d_head = sd_rounded_box(p - vec2<f32>(ax, tip_y), head_hs, head_rad);
    d = smin_cubic(d, d_head, 14.0 + 24.0 * head);

    let is_wifi_mod = u.flyout_info.x > 0.5;

    // Sub-Flyout Slot 1 + Fluid Bridge to Main
    let s1_t = clamp(u.flyout_extra.w, 0.0, 1.0);
    let s1_off = u.chain_offsets.x;
    let s1_cx = ax + s1_off * s1_t;
    if (is_wifi_mod && u.chain_info.x > 0.5 && s1_t > 0.005) {
        let d_sub1 = sd_rounded_box(p - vec2<f32>(s1_cx, tip_y), vec2<f32>(172.0, 160.0) * s1_t, 34.0 * s1_t);
        let p0 = vec2<f32>(select(ax - 206.0 * head, ax + 206.0 * head, s1_off > 0.0), tip_y);
        let p1 = vec2<f32>(select(s1_cx + 162.0 * s1_t, s1_cx - 162.0 * s1_t, s1_off > 0.0), tip_y);
        let nr = (20.0 * s1_t + sin(p.x * 0.08 + time * 3.5) * 2.5 * s1_t) * head;
        let d_neck1 = sd_seg(p, p0, p1) - max(nr, 1.0);
        d = smin_cubic(d, smin_cubic(d_sub1, d_neck1, 18.0 * s1_t), 22.0 * s1_t);
    }

    // Sub-Flyout Slot 2 (Chain ke Slot 1 atau Split-Wing ke Main!)
    let s2_t = clamp(u.chain_info.z, 0.0, 1.0);
    let s2_off = u.chain_offsets.y;
    let parent_is_main = u.chain_offsets.z > 0.5;
    if (is_wifi_mod && u.chain_info.y > 0.5 && s2_t > 0.005) {
        var s2_cx = ax + s2_off * s2_t;
        var parent_x = ax;
        var parent_hw = 206.0 * head;
        if (!parent_is_main) {
            s2_cx = s1_cx + (s2_off - s1_off) * s2_t;
            parent_x = s1_cx;
            parent_hw = 162.0 * s1_t;
        }
        let d_sub2 = sd_rounded_box(p - vec2<f32>(s2_cx, tip_y), vec2<f32>(172.0, 160.0) * s2_t, 34.0 * s2_t);
        let going_right = s2_cx > parent_x;
        let p0 = vec2<f32>(select(parent_x - parent_hw, parent_x + parent_hw, going_right), tip_y);
        let p1 = vec2<f32>(select(s2_cx + 162.0 * s2_t, s2_cx - 162.0 * s2_t, going_right), tip_y);
        let nr = (20.0 * s2_t + sin(p.x * 0.08 - time * 3.2) * 2.5 * s2_t) * head;
        let d_neck2 = sd_seg(p, p0, p1) - max(nr, 1.0);
        d = smin_cubic(d, smin_cubic(d_sub2, d_neck2, 18.0 * s2_t), 22.0 * s2_t);
    }

    for (var i = 0; i < 3; i = i + 1) {
        let fi = f32(i);
        let prog = fract(time * (0.34 + 0.07 * fi) + fi * 0.33);
        let by = mix(base_y - 4.0, tip_y + 16.0, prog);
        let bs = clamp((base_y - by) / col_len, 0.0, 1.0);
        let bsway = sin(bs * 5.0 - time * 1.9) * 2.6 * sin(bs * 3.14159) * flow_env;
        let bside = select(-1.0, 1.0, (i % 2) == 0);
        let bx = ax + bsway + bside * r_col * 0.55;
        let br = (2.6 + 0.6 * fi) * sin(prog * 3.14159) * flow_env;
        d = smin_cubic(d, length(p - vec2<f32>(bx, by)) - br, 7.0);
    }

    return d;
}

fn render_non_border_flyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    time: f32,
    module_id: f32,
    open_t: f32,
    theme_id: f32,
    value: f32,
    anchor_center: vec2<f32>,
    extra_meta: vec2<f32>,
    bar_top: f32
) -> FlyoutRenderResult {
    var res = FlyoutRenderResult(vec3<f32>(0.0), 0.0);
    if (open_t <= 0.005 || module_id < 0.5) {
        return res;
    }

    let over_px = max(open_t - 1.0, 0.0) * 14.0;
    let head_y = anchor_center.y - FLY_RISE - over_px;
    let ax = anchor_center.x;
    let open_c = min(open_t, 1.0);
    let pop_over = max(open_t - 1.0, 0.0) * 0.22;

    let is_wifi_mod = module_id > 0.5;
    let s1_kind = u.chain_info.x;
    let s2_kind = u.chain_info.y;
    let s1_t = clamp(u.flyout_extra.w, 0.0, 1.0);
    let s2_t = clamp(u.chain_info.z, 0.0, 1.0);
    let s1_off = u.chain_offsets.x;
    let s2_off = u.chain_offsets.y;
    let s2_parent_main = u.chain_offsets.z > 0.5;

    let s1_cx = ax + s1_off * s1_t;
    let s2_cx = select(s1_cx + (s2_off - s1_off) * s2_t, ax + s2_off * s2_t, s2_parent_main);

    var bg_col = hex(18.0, 19.0, 26.0);
    var bg_alpha = 0.0;
    var fg_col = bg_col;
    var fg_alpha = 0.0;

    // ─────────────────────────────────────────────────────────────────────────
    // STYLE 0: LIQUID SPIRE
    // ─────────────────────────────────────────────────────────────────────────
    if (theme_id < 0.5) {
        let tension = smoothstep(0.0, 0.22, open_t);
        let rise = smoothstep(0.14, 0.66, open_t);
        let head = smoothstep(0.52, 0.80, open_t);
        let cnt = smoothstep(0.70, 1.0, open_t);

        let d_comb = liquid_sdf(p, ax, bar_top, head_y, tension, rise, head, time);
        let d_flat = bar_top - p.y;
        let cov_c = 1.0 - smoothstep(-0.9, 0.9, d_comb);
        let cov_f = 1.0 - smoothstep(-0.9, 0.9, d_flat);
        let extra = clamp(cov_c - cov_f, 0.0, 1.0);

        let shadow_a = (1.0 - smoothstep(0.0, 16.0, d_comb)) * 0.38 * (1.0 - cov_f) * open_c;
        bg_col = hex(10.0, 11.0, 16.0);
        bg_alpha = shadow_a;

        if (extra > 0.001) {
            let eps = 1.6;
            let gx = liquid_sdf(p + vec2<f32>(eps, 0.0), ax, bar_top, head_y, tension, rise, head, time)
                   - liquid_sdf(p - vec2<f32>(eps, 0.0), ax, bar_top, head_y, tension, rise, head, time);
            let gy = liquid_sdf(p + vec2<f32>(0.0, eps), ax, bar_top, head_y, tension, rise, head, time)
                   - liquid_sdf(p - vec2<f32>(0.0, eps), ax, bar_top, head_y, tension, rise, head, time);
            let n = normalize(vec2<f32>(gx, gy) + vec2<f32>(0.0001, 0.0001));

            let sumi_deep    = hex(16.0, 18.0, 26.0);
            let sumi_body    = hex(24.0, 28.0, 40.0);
            let prussian_ink = hex(32.0, 48.0, 72.0);
            let gold_bright  = hex(230.0, 195.0, 132.0);
            let gold_amber   = hex(220.0, 165.0, 97.0);
            let gold_shimmer = hex(255.0, 238.0, 175.0);

            let ink_wash1 = fbm(p * 0.028 + vec2<f32>(time * 0.03, time * 0.30));
            let ink_wash2 = fbm(p * 0.055 + vec2<f32>(-time * 0.05, time * 0.45));

            let depth_in = clamp(-d_comb / 26.0, 0.0, 1.0);
            var liq_col = mix(sumi_deep, sumi_body, smoothstep(0.0, 0.85, depth_in));
            liq_col = mix(liq_col, prussian_ink, ink_wash1 * 0.42 * depth_in);

            let edge_dist = -d_comb;
            let fade_dist = max(u.texture_params.y, 6.0);
            let intensity = u.texture_params.x;
            let gold_edge_fade = (1.0 - smoothstep(1.5, fade_dist, edge_dist)) * intensity;

            let gold_stream = sin(p.y * 0.075 + time * 2.6 + ink_wash2 * 4.5);
            let gold_vein = smoothstep(0.85, 0.99, gold_stream) * (0.55 + 0.45 * (1.0 - depth_in));
            liq_col = mix(liq_col, gold_amber, gold_vein * 0.42 * gold_edge_fade);

            let dust_sp = (p + vec2<f32>(sin(p.y * 0.04 + time * 1.5) * 3.5, time * 28.0)) / 3.4;
            let r_dust = hash21(floor(dust_sp));
            let c_dust = fract(dust_sp) - vec2<f32>(0.5, 0.5);
            let dist_dust = length(c_dust) * 3.4;
            let twinkle = 0.5 + 0.5 * sin(time * 3.5 + r_dust * 12.56);
            let dust_flake = step(0.91, r_dust) * (1.0 - smoothstep(0.2, 1.1, dist_dust)) * twinkle;
            let dust_col = mix(gold_bright, gold_shimmer, r_dust);
            liq_col = mix(liq_col, dust_col, dust_flake * gold_edge_fade * 0.92);

            let light_dir = normalize(vec2<f32>(-0.58, -0.81));
            let ndl = clamp(dot(n, light_dir), 0.0, 1.0);
            let rim_w = smoothstep(0.2, 5.0, d_flat);
            let meniscus = (1.0 - smoothstep(0.0, 2.5, abs(d_comb))) * rim_w;
            let rim_gold = mix(gold_amber, gold_bright, 0.45 + 0.55 * ndl);
            liq_col = mix(liq_col, rim_gold, meniscus * 0.80);

            let inner_band = smoothstep(0.5, 3.5, -d_comb) * (1.0 - smoothstep(3.5, 9.0, -d_comb));
            let spec_glint = ndl * ndl * ndl * inner_band * rim_w;
            liq_col = mix(liq_col, gold_shimmer, spec_glint * 0.40 * intensity);

            let backdrop_a = clamp(u.texture_params.w, 0.0, 1.0);
            let solid_dark = mix(hex(12.0, 14.0, 22.0), prussian_ink, ink_wash1 * 0.28);
            let content_solid = smoothstep(10.0, fade_dist + 8.0, edge_dist) * (backdrop_a * 0.86);
            liq_col = mix(liq_col, solid_dark, content_solid);

            bg_col = mix(bg_col, liq_col, extra);
            bg_alpha = max(bg_alpha, extra * 0.98);
        }

        fg_col = bg_col;
        fg_alpha = bg_alpha;

        if (cnt > 0.001) {
            let pop = 0.20 + 0.80 * cnt + pop_over;
            let hc = vec2<f32>(ax, head_y);
            let wob = (fbm(p * 0.07 + vec2<f32>(time * 0.3, -time * 0.4)) - 0.5) * 26.0;
            let reveal_r = 260.0 * cnt;
            let reveal_m = 1.0 - smoothstep(reveal_r - 20.0, reveal_r + 2.0, length(p - hc) + wob);
            let p_c = p + vec2<f32>(sin(p.y * 0.2 + time * 3.0) * 2.2 * (1.0 - cnt), 0.0);
            let cres = draw_flyout_content(p_c, mouse_pos, module_id, hc, pop, cnt, value, extra_meta, time, fg_col, fg_alpha, 0.0);
            fg_col = mix(fg_col, cres.col, reveal_m);
            fg_alpha = mix(fg_alpha, cres.alpha, reveal_m);

            if (is_wifi_mod && s1_kind > 0.5 && s1_t > 0.01) {
                let s1_pop = 0.20 + 0.80 * s1_t;
                let s1_c = vec2<f32>(s1_cx, head_y);
                let s1_rev = 1.0 - smoothstep(240.0 * s1_t - 20.0, 240.0 * s1_t + 2.0, length(p - s1_c) + wob);
                let s1res = draw_subflyout_by_kind(s1_kind, p_c, mouse_pos, s1_c, s1_pop, s1_t, fly_flag(0u), value, time, fg_col, fg_alpha, 0.0);
                fg_col = mix(fg_col, s1res.col, s1_rev);
                fg_alpha = mix(fg_alpha, s1res.alpha, s1_rev);
            }
            if (is_wifi_mod && s2_kind > 0.5 && s2_t > 0.01) {
                let s2_pop = 0.20 + 0.80 * s2_t;
                let s2_c = vec2<f32>(s2_cx, head_y);
                let s2_rev = 1.0 - smoothstep(240.0 * s2_t - 20.0, 240.0 * s2_t + 2.0, length(p - s2_c) + wob);
                let s2res = draw_subflyout_by_kind(s2_kind, p_c, mouse_pos, s2_c, s2_pop, s2_t, fly_flag(0u), value, time, fg_col, fg_alpha, 0.0);
                fg_col = mix(fg_col, s2res.col, s2_rev);
                fg_alpha = mix(fg_alpha, s2res.alpha, s2_rev);
            }
        }
    }
    // ─────────────────────────────────────────────────────────────────────────
    // STYLE 1: SUMI CLOUD
    // ─────────────────────────────────────────────────────────────────────────
    else if (theme_id < 1.5) {
        let gth = smoothstep(0.0, 0.36, open_t);
        let ers = smoothstep(0.30, 0.74, open_t);
        let blm = smoothstep(0.52, 0.86, open_t);
        let cnt = smoothstep(0.70, 1.0, open_t);

        var min_x = ax - 260.0;
        var max_x = ax + 260.0;
        if (is_wifi_mod && s1_kind > 0.5 && s1_t > 0.005) {
            min_x = min(min_x, s1_cx - 220.0);
            max_x = max(max_x, s1_cx + 220.0);
        }
        if (is_wifi_mod && s2_kind > 0.5 && s2_t > 0.005) {
            min_x = min(min_x, s2_cx - 220.0);
            max_x = max(max_x, s2_cx + 220.0);
        }

        let in_region = p.x >= min_x && p.x <= max_x && p.y > head_y - 230.0 && p.y < bar_top + 70.0;
        if (in_region) {
            let base_y = bar_top + 10.0;
            let span = max(base_y - head_y, 1.0);
            let s = (base_y - p.y) / span;
            let s_c = clamp(s, 0.0, 1.0);

            let wash = fbm(p * 0.034 + vec2<f32>(sin(time * 0.3) * 0.4, time * 0.42));
            let detail = fbm(p * 0.07 + vec2<f32>(-time * 0.12, time * 0.66));

            let w_plume = mix(10.0, 36.0, pow(s_c, 0.7)) * (0.5 + 0.5 * smoothstep(0.0, 0.3, ers));
            let swirl = (wash - 0.5) * 26.0 * s_c;
            let dxp = abs(p.x - ax - swirl);
            let fronts = ers * 1.04;
            let front_m = 1.0 - smoothstep(fronts - 0.12, fronts + 0.02, s);
            let plume = (1.0 - smoothstep(w_plume * 0.15, w_plume * 1.25, dxp)) * front_m * smoothstep(-0.05, 0.12, s);

            let cloud_gate = smoothstep(0.55, 0.95, ers);
            let cr = vec2<f32>(115.0 + 165.0 * blm, 85.0 + 130.0 * blm);
            let cr_sub = vec2<f32>(95.0 + 125.0 * blm, 85.0 + 125.0 * blm);
            var dcl = length((p - vec2<f32>(ax, head_y)) / cr);
            if (is_wifi_mod && s1_kind > 0.5 && s1_t > 0.01) {
                let dcl1 = length((p - vec2<f32>(s1_cx, head_y)) / (cr_sub * s1_t));
                let neck1 = sd_seg(p, vec2<f32>(ax, head_y), vec2<f32>(s1_cx, head_y)) / (80.0 * s1_t);
                dcl = min(dcl, min(dcl1, neck1));
            }
            if (is_wifi_mod && s2_kind > 0.5 && s2_t > 0.01) {
                let p_anchor_x = select(s1_cx, ax, s2_parent_main);
                let dcl2 = length((p - vec2<f32>(s2_cx, head_y)) / (cr_sub * s2_t));
                let neck2 = sd_seg(p, vec2<f32>(p_anchor_x, head_y), vec2<f32>(s2_cx, head_y)) / (80.0 * s2_t);
                dcl = min(dcl, min(dcl2, neck2));
            }
            dcl = dcl + (wash - 0.5) * 0.28 + (detail - 0.5) * 0.12;
            let cloud = (1.0 - smoothstep(0.12, 1.06, dcl)) * cloud_gate;

            let seam = 1.0 - smoothstep(bar_top - 4.0, bar_top + 14.0, p.y);
            let dens_raw = clamp(max(plume * 0.80, cloud) * seam, 0.0, 1.0);
            let dens_n = clamp(dens_raw + (detail - 0.5) * 0.38 * smoothstep(0.0, 0.2, dens_raw), 0.0, 1.0);
            let dens = smoothstep(0.04, 0.90, dens_n);

            let ink_dark = hex(12.0, 13.0, 20.0);
            let ink_mid = hex(28.0, 36.0, 52.0);
            let ink_blue = hex(45.0, 79.0, 103.0);
            var mist_col = mix(ink_dark, ink_mid, wash * 0.7 + detail * 0.3);
            mist_col = mix(mist_col, ink_blue, (1.0 - dens) * 0.30 * detail);
            let haze_a = dens * 0.92 * min(open_t * 4.0, 1.0);

            var lc = mist_col;
            var la = haze_a;

            let gold_amber = hex(235.0, 185.0, 95.0);
            let btn = vec2<f32>(ax, bar_top + 14.0);
            let gq = length((p - btn) / vec2<f32>(46.0, 30.0));
            let glow = exp(-gq * gq * 1.6) * gth * gth * (1.0 - 0.55 * ers);
            let o1 = fly_over(lc, la, gold_amber, clamp(glow * 0.75, 0.0, 1.0));
            lc = o1.xyz;
            la = o1.w;

            let bar_left_x = u.screen_size.x * 0.5 - u.bar_width * 0.5;
            let a_loc = ax - bar_left_x;
            let x_loc = p.x - bar_left_x;
            let h_up = btn.y - p.y;
            let reach = max(btn.y - head_y, 1.0);
            let hn = clamp(h_up / reach, 0.0, 1.0);
            let speed = ers * (1.0 - ers) * 4.0;
            let sy = 1.0 + 2.2 * speed;
            let kst = mix(2.2, 1.0, hn);
            let ps = vec2<f32>(a_loc + (x_loc - a_loc - swirl) * kst, -h_up / sy + time * 34.0);
            let ad = ambient_dust(ps, time, -0.13);
            let cloud_part = (1.0 - smoothstep(0.10, 1.15, dcl)) * cloud_gate;
            let stream_edge = (1.0 - smoothstep(w_plume * 0.3, w_plume * 1.5, dxp)) * front_m;
            let stream_m = clamp(max(stream_edge, cloud_part), 0.0, 1.0)
                         * smoothstep(-4.0, 6.0, h_up) * smoothstep(0.02, 0.15, ers);
            let dust_i = clamp(ad.x * 1.5, 0.0, 1.0) * stream_m;
            let dust_col = mix(hex(235.0, 185.0, 95.0), hex(255.0, 242.0, 182.0), ad.y);
            let o2 = fly_over(lc, la, dust_col, dust_i * 0.95);
            lc = o2.xyz;
            la = o2.w;

            bg_col = lc;
            bg_alpha = la;
        }

        fg_col = bg_col;
        fg_alpha = bg_alpha;

        if (cnt > 0.001) {
            let pop = 0.20 + 0.80 * cnt + pop_over;
            let hc = vec2<f32>(ax, head_y);
            let wob = (fbm(p * 0.07 + vec2<f32>(time * 0.3, -time * 0.4)) - 0.5) * 26.0;
            let reveal_r = 260.0 * cnt;
            let reveal_m = 1.0 - smoothstep(reveal_r - 20.0, reveal_r + 2.0, length(p - hc) + wob);
            let p_c = p + vec2<f32>(sin(p.y * 0.2 + time * 3.0) * 2.2 * (1.0 - cnt), 0.0);
            let cres = draw_flyout_content(p_c, mouse_pos, module_id, hc, pop, cnt, value, extra_meta, time, fg_col, fg_alpha, 0.0);
            fg_col = mix(fg_col, cres.col, reveal_m);
            fg_alpha = max(fg_alpha, cres.alpha * reveal_m);

            if (is_wifi_mod && s1_kind > 0.5 && s1_t > 0.01) {
                let s1_pop = 0.20 + 0.80 * s1_t;
                let s1_c = vec2<f32>(s1_cx, head_y);
                let s1_rev = 1.0 - smoothstep(240.0 * s1_t - 20.0, 240.0 * s1_t + 2.0, length(p - s1_c) + wob);
                let s1res = draw_subflyout_by_kind(s1_kind, p_c, mouse_pos, s1_c, s1_pop, s1_t, fly_flag(0u), value, time, fg_col, fg_alpha, 0.0);
                fg_col = mix(fg_col, s1res.col, s1_rev);
                fg_alpha = max(fg_alpha, s1res.alpha * s1_rev);
            }
            if (is_wifi_mod && s2_kind > 0.5 && s2_t > 0.01) {
                let s2_pop = 0.20 + 0.80 * s2_t;
                let s2_c = vec2<f32>(s2_cx, head_y);
                let s2_rev = 1.0 - smoothstep(240.0 * s2_t - 20.0, 240.0 * s2_t + 2.0, length(p - s2_c) + wob);
                let s2res = draw_subflyout_by_kind(s2_kind, p_c, mouse_pos, s2_c, s2_pop, s2_t, fly_flag(0u), value, time, fg_col, fg_alpha, 0.0);
                fg_col = mix(fg_col, s2res.col, s2_rev);
                fg_alpha = max(fg_alpha, s2res.alpha * s2_rev);
            }
        }
    }
    // ─────────────────────────────────────────────────────────────────────────
    // STYLE 2: PURE HUD (kontrol mengambang minimalis dengan Kintsugi cyber link)
    // ─────────────────────────────────────────────────────────────────────────
    else {
        let t_bg = clamp(open_t / 0.72, 0.0, 1.0);
        let smooth_bg = smoothstep(0.0, 1.0, t_bg);
        let fly_h = 40.0 + (FLY_RISE - 40.0) * smooth_bg + max(open_t - 1.0, 0.0) * 12.0;
        let t_content = clamp((open_t - 0.35) / 0.65, 0.0, 1.0);
        let smooth_content = smoothstep(0.0, 1.0, t_content);
        let pop = 0.20 + 0.80 * smooth_content + pop_over;
        let rise_off = (1.0 - smooth_content) * 16.0;
        let cc = vec2<f32>(ax, anchor_center.y - fly_h + rise_off);
        if (smooth_content > 0.001) {
            let cres = draw_flyout_content(p, mouse_pos, module_id, cc, pop, smooth_content, value, extra_meta, time, bg_col, 0.0, 1.0);
            fg_col = cres.col;
            fg_alpha = cres.alpha;

            if (is_wifi_mod && s1_kind > 0.5 && s1_t > 0.01) {
                let s1_pop = 0.20 + 0.80 * s1_t;
                let s1_c = vec2<f32>(s1_cx, cc.y);
                let p_start = cc + vec2<f32>(select(-206.0, 206.0, s1_off > 0.0), 0.0);
                let p_end = s1_c + vec2<f32>(select(162.0, -162.0, s1_off > 0.0), 0.0);
                let link_a = (1.0 - smoothstep(0.0, 1.8, sd_seg(p, p_start, p_end))) * s1_t * 0.85;
                let pulse = fract(p.x * 0.03 - time * 2.5);
                let link_col = mix(hex(127.0, 180.0, 202.0), hex(255.0, 238.0, 178.0), pulse);
                fg_col = mix(fg_col, link_col, link_a);
                fg_alpha = max(fg_alpha, link_a);

                let s1res = draw_subflyout_by_kind(s1_kind, p, mouse_pos, s1_c, s1_pop, s1_t, fly_flag(0u), value, time, bg_col, 0.0, 1.0);
                fg_col = mix(fg_col, s1res.col, s1res.alpha * s1_t);
                fg_alpha = max(fg_alpha, s1res.alpha * s1_t);
            }

            if (is_wifi_mod && s2_kind > 0.5 && s2_t > 0.01) {
                let s2_pop = 0.20 + 0.80 * s2_t;
                let s2_c = vec2<f32>(s2_cx, cc.y);
                let parent_x = select(s1_cx, ax, s2_parent_main);
                let parent_hw = select(162.0, 206.0, s2_parent_main);
                let going_right = s2_cx > parent_x;
                let p_start = vec2<f32>(select(parent_x - parent_hw, parent_x + parent_hw, going_right), cc.y);
                let p_end = vec2<f32>(select(s2_cx + 162.0, s2_cx - 162.0, going_right), cc.y);
                let link_a = (1.0 - smoothstep(0.0, 1.8, sd_seg(p, p_start, p_end))) * s2_t * 0.85;
                let pulse = fract(p.x * 0.03 + time * 2.5);
                let link_col = mix(hex(127.0, 180.0, 202.0), hex(255.0, 238.0, 178.0), pulse);
                fg_col = mix(fg_col, link_col, link_a);
                fg_alpha = max(fg_alpha, link_a);

                let s2res = draw_subflyout_by_kind(s2_kind, p, mouse_pos, s2_c, s2_pop, s2_t, fly_flag(0u), value, time, bg_col, 0.0, 1.0);
                fg_col = mix(fg_col, s2res.col, s2res.alpha * s2_t);
                fg_alpha = max(fg_alpha, s2res.alpha * s2_t);
            }
        }
    }

    res.col = fg_col;
    res.alpha = fg_alpha;
    return res;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let p = in.uv * u.screen_size;
    let cx = u.screen_size.x * 0.5;
    let bottom_y = u.screen_size.y;

    let t_anim = clamp(u.anim_t, 0.0, 1.15);
    let smooth_t = smoothstep(0.0, 1.0, min(t_anim, 1.0));
    let overshoot = max(t_anim - 1.0, 0.0) * 14.0;

    let half_w = u.bar_width * 0.5;
    let norm_x = clamp(abs(p.x - cx) / half_w, 0.0, 1.0);

    let surge_front = smoothstep(norm_x * 0.55, 1.0, smooth_t);
    let bulge_factor = sin(smooth_t * 3.14159) * (1.0 - norm_x * norm_x) * 22.0;

    let base_height = mix(8.0, u.bar_height, surge_front) + bulge_factor + overshoot;

    // ─────────────────────────────────────────────────────────────────────────
    // WIDE & SOFT ORGANIC MAGNETIC PERIMETER (Atas, Kiri, & Kanan)
    // ─────────────────────────────────────────────────────────────────────────
    let half_h_base = base_height * 0.5;
    let bar_center_base = vec2<f32>(cx, bottom_y - half_h_base);

    let dist_p_to_mouse = length(p - u.mouse_pos);
    let influence_radius = 260.0;
    let norm_dist = clamp(dist_p_to_mouse / influence_radius, 0.0, 1.0);
    let soft_bell = cos(norm_dist * 3.14159265 * 0.5);

    let max_warp = 26.0 * u.pull_strength * smoothstep(0.25, 1.0, u.anim_t);
    let pull_vector = (u.mouse_pos - p) / max(dist_p_to_mouse, 1.0);
    let warped_p = p - pull_vector * (soft_bell * soft_bell * max_warp);

    let eff_corner = mix(4.0, u.corner_radius, surge_front);
    let eff_fillet = mix(28.0, u.fillet_radius, surge_front);

    // 1. SDF Glob Taskbar (Single Source of Truth)
    let d_box = sd_rounded_box(warped_p - bar_center_base, vec2<f32>(half_w, half_h_base), eff_corner);
    let d_floor = bottom_y - p.y;
    let d_glob = smin_cubic(d_box, d_floor, eff_fillet);
    let d_taskbar = max(d_glob, -d_floor);



    let d = d_taskbar;
    var color = hex(16.0, 16.0, 24.0);
    var wave_a = 0.0;

    let aa_tb = max(fwidth(d_taskbar), 0.75);
    let alpha = 1.0 - smoothstep(-aa_tb, aa_tb, d_taskbar);
    if (alpha > 0.001) {
        let bar_left = cx - half_w;
        let bar_top = bottom_y - base_height;
        let local_x = p.x - bar_left;
        let local_y = p.y - bar_top;

        let mouse_local = vec2<f32>(u.mouse_pos.x - bar_left, u.mouse_pos.y - bar_top);

        // Render ombak Kanagawa dengan Gold Dust Dispersion (Alami & Halus)
        let wave_res = render_kanagawa_wave(
            local_x,
            local_y,
            u.time,
            u.bar_width,
            base_height,
            u.anim_t,
            u.wave_surge,
            mouse_local,
        );
        color = wave_res.rgb;
        wave_a = wave_res.a;

        // Pendaran emas lembut di bibir yang tertarik
        if (u.pull_strength > 0.05) {
            let edge_d = abs(d);
            let pull_glow = smoothstep(4.5, 0.0, edge_d) * soft_bell * u.pull_strength;
            let gold_glow = hex(250.0, 225.0, 145.0);
            color = mix(color, gold_glow, pull_glow * 0.65);
        }

        // ─────────────────────────────────────────────────────────────────────────
        // WIDGET RENDERING: 100% STABIL & KOKOH
        // ─────────────────────────────────────────────────────────────────────────
        let widget_alpha = smoothstep(0.40, 0.90, u.anim_t);
        if (widget_alpha > 0.01) {
            let rise_offset = (1.0 - widget_alpha) * 18.0;
            let widget_y = bar_top + base_height * 0.46 + rise_offset;

            // === GROUP 1: KIRI (Start & Search — Fase 1 Liquid Gold-Sumi Absorption) ===
            let win_center = vec2<f32>(bar_left + 54.0, widget_y);
            let search_center = vec2<f32>(bar_left + 126.0, widget_y);
            color = draw_start_search_phase1(color, p, win_center, search_center, u.mouse_pos, widget_alpha);

            // === GROUP 2: TENGAH (Dock App Icons - 60x60px) ===
            let app1 = vec2<f32>(cx - 96.0, widget_y);
            let pill_app1 = draw_widget_pill(color, p, app1, vec2<f32>(28.0, 28.0), 15.0, u.mouse_pos);
            if (pill_app1.col.a > 0.0) {
                let c = draw_dock_app_icon(pill_app1.col.rgb, p, pill_app1.eff_center, 0u, true, pill_app1.hover);
                color = mix(color, c, widget_alpha);
            }

            let app2 = vec2<f32>(cx - 32.0, widget_y);
            let pill_app2 = draw_widget_pill(color, p, app2, vec2<f32>(28.0, 28.0), 15.0, u.mouse_pos);
            if (pill_app2.col.a > 0.0) {
                let c = draw_dock_app_icon(pill_app2.col.rgb, p, pill_app2.eff_center, 1u, true, pill_app2.hover);
                color = mix(color, c, widget_alpha);
            }

            let app3 = vec2<f32>(cx + 32.0, widget_y);
            let pill_app3 = draw_widget_pill(color, p, app3, vec2<f32>(28.0, 28.0), 15.0, u.mouse_pos);
            if (pill_app3.col.a > 0.0) {
                let c = draw_dock_app_icon(pill_app3.col.rgb, p, pill_app3.eff_center, 2u, false, pill_app3.hover);
                color = mix(color, c, widget_alpha);
            }

            let app4 = vec2<f32>(cx + 96.0, widget_y);
            let pill_app4 = draw_widget_pill(color, p, app4, vec2<f32>(28.0, 28.0), 15.0, u.mouse_pos);
            if (pill_app4.col.a > 0.0) {
                let c = draw_dock_app_icon(pill_app4.col.rgb, p, pill_app4.eff_center, 3u, false, pill_app4.hover);
                color = mix(color, c, widget_alpha);
            }

            // === GROUP 3: KANAN (Status Tray & Jam) ===
            let bar_right = cx + half_w;

            let tray_center = vec2<f32>(bar_right - 196.0, widget_y);
            let pill_tray = draw_widget_pill(color, p, tray_center, vec2<f32>(66.0, 30.0), 16.0, u.mouse_pos);
            if (pill_tray.col.a > 0.0) {
                var c = pill_tray.col.rgb;
                c = draw_wifi_icon(c, p, pill_tray.eff_center + vec2<f32>(-40.0, 0.0), u.mouse_pos);
                c = draw_volume_icon(c, p, pill_tray.eff_center + vec2<f32>(0.0, 0.0), u.mouse_pos);
                c = draw_battery_icon(c, p, pill_tray.eff_center + vec2<f32>(38.0, 0.0), u.mouse_pos);
                color = mix(color, c, widget_alpha);
            }

            let clock_center = vec2<f32>(bar_right - 70.0, widget_y);
            let pill_clock = draw_widget_pill(color, p, clock_center, vec2<f32>(46.0, 30.0), 16.0, u.mouse_pos);
            if (pill_clock.col.a > 0.0) {
                let c = draw_digital_clock(pill_clock.col.rgb, p, pill_clock.eff_center, pill_clock.hover);
                color = mix(color, c, widget_alpha);
            }
        }
    }

    let glob_alpha = alpha * wave_a;

    // Bibir atas panel taskbar pada kondisi anim_t saat ini (untuk pangkal jalur flyout)
    let fly_bar_top = bottom_y - (mix(8.0, u.bar_height, smooth_t) + overshoot);

    // Render Flyout Non-Border di atas tray
    let fly_res = render_non_border_flyout(
        p,
        u.mouse_pos,
        u.time,
        u.flyout_info.x,
        u.flyout_info.y,
        u.flyout_info.z,
        u.flyout_info.w,
        vec2<f32>(u.flyout_meta.x, u.flyout_meta.y),
        vec2<f32>(u.flyout_meta.z, u.flyout_meta.w),
        fly_bar_top
    );

    // ─────────────────────────────────────────────────────────────────────────
    // LAYER COMPOSITING 3D:
    // Layer 1 (Paling Belakang): Stump Batang Utama Sakura
    // Layer 2 (Tengah): Ombak Taskbar Kanagawa & Widget Icons
    // Layer 3 (Paling Depan): Seed Tracer & Akar Nebari Berserabut
    // ─────────────────────────────────────────────────────────────────────────

    // 1. STUMP SAKURA (Z-index di BELAKANG Taskbar)
    let g_stump = clamp(u.tree_style.x, 0.0, 1.05);
    var bg_col = hex(16.0, 16.0, 24.0);
    var bg_alpha = 0.0;
    let stump_res = render_sakura_stump(
        p,
        cx,
        half_w,
        u.bar_width,
        bottom_y,
        u.screen_size.y,
        smooth_t,
        overshoot,
        g_stump,
        u.time,
        bg_col,
        bg_alpha
    );

    // 2. TASKBAR OMBAK (Di DEPAN Stump, sehingga bibir ombak menutupi bagian bawah stump)
    var mid_col = stump_res.rgb;
    var mid_alpha = stump_res.a;
    if (glob_alpha > 0.001) {
        mid_col = mix(mid_col, color, glob_alpha);
        mid_alpha = max(mid_alpha, glob_alpha);
    }

    // 3. SEED TRACER & AKAR NEBARI (Di PALING DEPAN, memeluk bibir ombak dan pangkal batang dari depan)
    let bar_left = cx - half_w;
    let p2_c = clamp(u.start_info.y, 0.0, 1.05);
    let win_center_tracer = vec2<f32>(bar_left + 54.0, bottom_y - base_height * 0.54);
    let seed_res = render_sakura_seed_tracer(
        p,
        cx,
        half_w,
        bar_left,
        bottom_y,
        smooth_t,
        overshoot,
        win_center_tracer,
        p2_c,
        u.time,
        mid_col,
        mid_alpha
    );

    let g_root = clamp(u.start_info.z, 0.0, 1.05);
    let root_res = render_sakura_roots(
        p,
        cx,
        half_w,
        bar_left,
        bottom_y,
        smooth_t,
        overshoot,
        g_root,
        u.time,
        seed_res.rgb,
        seed_res.a
    );

    let tracer_col = root_res.rgb;
    let tracer_alpha = root_res.a;

    let final_alpha = max(tracer_alpha, fly_res.alpha);
    if (final_alpha <= 0.001) {
        discard;
    }

    var final_color = tracer_col;
    if (fly_res.alpha > 0.0) {
        final_color = mix(final_color, fly_res.col, fly_res.alpha);
    }

    // Premultiplied alpha output: RGB harus dikalikan dengan final_alpha
    return vec4<f32>(final_color * final_alpha, final_alpha);
}
