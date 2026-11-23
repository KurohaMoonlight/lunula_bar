/// Fungsi tinggi permukaan ombak Kanagawa h(x) (Single Source of Truth untuk ombak & akar!)
fn taskbar_wave_surface_y(
    px: f32,
    t: f32,
    bar_h: f32,
    anim_t: f32,
    surge: f32,
) -> f32 {
    let wave_amp = mix(3.0, 26.0, min(anim_t, 1.0)) + surge * 10.0;
    let sw = swell(px, t, 420.0, wave_amp, 0.022, 0.30);
    let rough = (fbm(vec2<f32>(px * 0.05, t * 0.10 + 3.7)) - 0.44) * mix(1.0, 3.8, min(anim_t, 1.0));
    let crest_base = mix(bar_h * 0.50, bar_h * 0.64, min(anim_t, 1.0));
    return max(crest_base - sw.x - sin(px * 0.07 - t * 0.9) * (0.8 + surge * 1.5) - rough, 1.5);
}

fn render_kanagawa_wave(
    px: f32,
    py: f32,
    t: f32,
    bar_w: f32,
    bar_h: f32,
    anim_t: f32,
    surge: f32,
    m_local: vec2<f32>,
) -> vec4<f32> {
    let sumi0       = hex(22.0, 22.0, 29.0);     // #16161D
    let sumi3       = hex(31.0, 31.0, 40.0);     // #1F1F28
    let wave1       = hex(34.0, 50.0, 73.0);     // #223249 waveBlue1
    let wave2       = hex(45.0, 79.0, 103.0);    // #2D4F67 waveBlue2
    let spring_blue = hex(127.0, 180.0, 202.0);  // #7FB4CA springBlue
    let aqua1       = hex(106.0, 149.0, 137.0);  // #6A9589 waveAqua1

    let gold_bright = hex(230.0, 195.0, 132.0);  // #E6C384
    let gold_deep   = hex(192.0, 163.0, 110.0);  // #C0A36E
    let gold_amber  = hex(220.0, 165.0, 97.0);   // #DCA561
    let gold_shimmer= hex(250.0, 230.0, 175.0);

    let p = vec2<f32>(px, py);
    let tree_pull = clamp(u.start_info.y, 0.0, 1.0);

    let wash = fbm(p * vec2<f32>(0.008, 0.035) + vec2<f32>(t * 0.015, 0.0));
    var col = mix(sumi0, sumi3, smoothstep(0.0, bar_h, py) * 0.45);
    col = mix(col, wave1, wash * 0.35);

    let far_amp = mix(2.5, 9.5, min(anim_t, 1.0)) + surge * 3.5;
    let far = swell(px, t, 560.0, far_amp, 0.012, 0.62);
    let far_y = bar_h * 0.54 - far.x - (fbm(vec2<f32>(px * 0.03, 2.0)) - 0.4) * 3.0;
    let far_dc = py - far_y;
    if (far_dc < 0.0) {
        col = mix(col, wave2, exp(far_dc / 4.0) * 0.35);
        col = mix(col, gold_deep, exp(far_dc / 2.0) * 0.20);
    } else {
        let far_depth = clamp(far_dc / max(bar_h * 0.3, 4.0), 0.0, 1.0);
        let far_col = mix(wave2, wave1, far_depth * 0.7);
        col = mix(col, far_col, smoothstep(0.0, 3.5, far_dc) * 0.80);
    }

    // Ombak Utama (Stabil, bebas patah/jitter)
    let wave_amp = mix(3.0, 26.0, min(anim_t, 1.0)) + surge * 10.0;
    let sw = swell(px, t, 420.0, wave_amp, 0.022, 0.30);
    let crest_y = taskbar_wave_surface_y(px, t, bar_h, anim_t, surge);
    let front = clamp(sw.y, 0.0, 1.0);
    let dc = py - crest_y;

    let root_suck = vec3<f32>(0.0, 0.0, 1e5);

    if (dc < 0.0) {
        col = mix(col, wave2, exp(dc / 5.0) * (0.22 + 0.18 * wash));
        col = mix(col, gold_bright, exp(dc / 3.5) * (0.35 + surge * 0.35));

        // ─────────────────────────────────────────────────────────────────────
        // GOLD DUST DISPERSION & ROOT SUCTION
        // (Partikel emas menyebar saat di-hover, namun TERSEDOT kuat ke sistem akar saat pohon aktif)
        // ─────────────────────────────────────────────────────────────────────
        let d_cursor = length(p - m_local);
        let disp_radius = 90.0;
        let wind_force = clamp(1.0 - d_cursor / disp_radius, 0.0, 1.0);
        let wind_dir = (p - m_local) / max(d_cursor, 1.0);
        let disp_offset = wind_dir * (wind_force * 18.0);

        let pull_eff = clamp(u.tree_params.z * u.start_fx.z, 0.45, 2.8);
        let d_root_real = root_suck.z;
        let root_pull_f = pow(clamp(1.0 - max(d_root_real, 0.0) / 96.0, 0.0, 1.0), 1.25) * tree_pull;
        let suction_dir = vec2<f32>(root_suck.x, root_suck.y);
        let swirl_perp = vec2<f32>(-suction_dir.y, suction_dir.x) * sin(p.x * 0.055 - t * 1.6) * 0.26;
        let pull_vec = (suction_dir + swirl_perp) * (root_pull_f * 36.0 * min(pull_eff, 1.9));

        let sp_ph1 = fract(t * 0.34);
        let sp_ph2 = fract(t * 0.34 + 0.5);
        let sp_w1 = sin(sp_ph1 * 3.14159265);
        let sp_w2 = sin(sp_ph2 * 3.14159265);

        let dust_pos1 = (sumi_gather_warp(p - disp_offset - pull_vec * sp_ph1, bar_w) - vec2<f32>(t * 10.4, 0.0)) / 2.6;
        let dust_pos2 = (sumi_gather_warp(p - disp_offset - pull_vec * sp_ph2, bar_w) - vec2<f32>(t * 10.4, 0.0)) / 2.6;

        let r1 = hash21(floor(dust_pos1));
        let dist1 = length(fract(dust_pos1) - vec2<f32>(0.5, 0.5)) * 2.6;
        let r2 = hash21(floor(dust_pos2));
        let dist2 = length(fract(dust_pos2) - vec2<f32>(0.5, 0.5)) * 2.6;

        let drop_thresh = mix(0.91, 0.82, min(anim_t, 1.0)) - (surge + wind_force * 0.5) * 0.08 - root_pull_f * 0.03;
        let d_on1 = step(drop_thresh, r1) * (1.0 - smoothstep(0.32, 1.05, dist1));
        let d_on2 = step(drop_thresh, r2) * (1.0 - smoothstep(0.32, 1.05, dist2));
        let drop_raw = select(d_on1, (d_on1 * sp_w1 + d_on2 * sp_w2) / max(sp_w1 + sp_w2, 0.001), root_pull_f > 0.01);

        // Partikel asli yang menyentuh akar energi cair langsung melebur terserap masuk
        let root_absorb = (1.0 - smoothstep(0.0, 8.0, d_root_real)) * tree_pull;
        let drop_on = drop_raw * (1.0 - root_absorb * 0.96);

        let spray_mask = front * smoothstep(-16.0 - wind_force * 10.0 - root_pull_f * 14.0, -1.0, dc);
        let drop_col = mix(gold_bright, gold_shimmer, clamp(r1 + root_pull_f * 0.45, 0.0, 1.0));
        col = mix(col, drop_col, clamp(drop_on * spray_mask * (0.95 + 0.35 * root_pull_f), 0.0, 1.0));
    } else {
        let depth = clamp(dc / max(bar_h * 0.35, 3.0), 0.0, 1.0);

        var body = mix(wave2, spring_blue, 0.30);
        body = mix(body, wave1, smoothstep(0.0, 0.75, depth));
        body = mix(body, sumi0, smoothstep(0.65, 1.0, depth) * 0.45);

        let flow = fbm(vec2<f32>(px * 0.03, dc * 0.20)) * 6.0;
        let streak = smoothstep(0.80, 1.0, sin(dc * 0.85 + flow - t * 0.4));
        body = mix(body, gold_bright, streak * 0.55 * (1.0 - depth * 0.35));

        body = body * (0.85 + 0.30 * fbm(vec2<f32>(px * 0.02, py * 0.08) + vec2<f32>(5.0, 5.0)));
        col = mix(col, body, smoothstep(0.0, 1.2, dc) * 0.98);

        let lw = 1.0 + 0.9 * front + 0.6 * vnoise(vec2<f32>(px * 0.2, 1.0));
        let line = (1.0 - smoothstep(lw * 0.4, lw, abs(dc - lw * 0.3)));
        col = mix(col, gold_amber, line * 0.85);

        let fd = dc - lw * 0.8;
        let foam_band = (1.0 - smoothstep(0.0, (2.8 + 4.5 * front) * (1.0 + surge * 0.5), fd)) * step(0.0, fd);
        let bn = fbm(vec2<f32>(px * 0.22, py * 0.60 + t * 0.15));
        let foam_a = foam_band * smoothstep(0.35, 0.65, bn + front * 0.25);
        let foam_gold = mix(gold_bright, gold_shimmer, bn);
        col = mix(col, foam_gold, foam_a * 0.95);
    }

    let r_y = bar_h * 0.90 + sin(px * 0.025 + t * 0.6) * 1.4;
    let r_line = (1.0 - smoothstep(0.2, 0.9, abs(py - r_y)));
    let r_break = smoothstep(0.35, 0.60, vnoise(vec2<f32>(px * 0.06, t * 0.05)));
    col = mix(col, mix(aqua1, gold_bright, 0.45), r_line * r_break * 0.30);

    // ─────────────────────────────────────────────────────────────────────────
    // THIN AMBIENT GOLD DUST (Taburan Sunago / Kin-paku Tipis di Area Biru Kosong)
    // ─────────────────────────────────────────────────────────────────────────
    // Hembusan angin halus kursor juga mempengaruhi debu di area biru
    let d_amb_cursor = length(p - m_local);
    let amb_wind = clamp(1.0 - d_amb_cursor / 120.0, 0.0, 1.0);
    let amb_wind_dir = (p - m_local) / max(d_amb_cursor, 1.0);
    let amb_wind_offset = amb_wind_dir * (amb_wind * 14.0);
    // Distorsi medan debu emas ASLI `ambient_dust` (`01_noise_sdf.wgsl`) memakai `root_suck` yang sudah dihitung
    let amb_suck = root_suck;
    let amb_pull_eff = clamp(u.tree_params.z * u.start_fx.z, 0.45, 2.8);
    let amb_d_root = amb_suck.z;
    let amb_pull_f = pow(clamp(1.0 - max(amb_d_root, 0.0) / 112.0, 0.0, 1.0), 1.18) * tree_pull;
    let amb_dir = vec2<f32>(amb_suck.x, amb_suck.y);
    let to_hub = normalize(vec2<f32>(78.0, 11.0) - p + vec2<f32>(0.001, 0.001));
    let amb_swirl = vec2<f32>(-amb_dir.y, amb_dir.x) * sin(p.x * 0.05 + p.y * 0.07 - t * 1.35) * 0.24;
    let advect_dir = amb_dir * 0.80 + to_hub * 0.20 + amb_swirl;

    // Velocity stretch halus searah aliran hisapan saat partikel sangat dekat ke akar (< 42px)
    let near_stretch = smoothstep(42.0, 2.0, amb_d_root) * amb_pull_f * 0.42;
    let p_base = p - amb_wind_offset;
    let p_proj = dot(p_base, amb_dir) * amb_dir;
    let p_stretched = p_base - p_proj * near_stretch;

    // Dual-phase advection kontinu agar serpihan `ambient_dust` mengalir mulus tanpa patah
    let ph1 = fract(t * 0.36);
    let ph2 = fract(t * 0.36 + 0.5);
    let w_ph1 = sin(ph1 * 3.14159265);
    let w_ph2 = sin(ph2 * 3.14159265);
    let pull_dist = amb_pull_f * 44.0 * min(amb_pull_eff, 1.85);
    let amb_p1 = sumi_gather_warp(p_stretched - advect_dir * (pull_dist * ph1), bar_w);
    let amb_p2 = sumi_gather_warp(p_stretched - advect_dir * (pull_dist * ph2), bar_w);

    // Sedikit turunkan threshold saat di zona hisapan agar lebih banyak serpihan asli terlihat mengalir masuk
    let suck_th = -0.022 * amb_pull_f;
    let d1 = ambient_dust(amb_p1, t, suck_th);
    let d2 = ambient_dust(amb_p2, t, suck_th);
    let amb_d = select(
        ambient_dust(sumi_gather_warp(p_base, bar_w), t, 0.0),
        (d1 * w_ph1 + d2 * w_ph2) / max(w_ph1 + w_ph2, 0.001),
        amb_pull_f > 0.01
    );

    // Masker: Terlihat anggun di langit biru gelap atas (termasuk dekat bibir akar) serta lembut di sela air
    let upper_blue_mask = smoothstep(14.0, -8.0, dc) * smoothstep(0.0, 8.0, py);
    let body_blue_mask  = smoothstep(-4.0, 16.0, dc) * (1.0 - smoothstep(bar_h - 10.0, bar_h, py)) * 0.35;
    let blue_dust_mask  = max(upper_blue_mask, body_blue_mask);

    // Debu emas asli berpendar lebih cerah saat tersedot mendekat lalu melebur hilang ke dalam akar energi cair
    let near_glint = smoothstep(38.0, 3.0, amb_d_root) * amb_pull_f * 0.85;
    let amb_gold_col = mix(gold_amber, gold_shimmer, clamp(amb_d.y + near_glint, 0.0, 1.0));
    let root_absorb_amb = (1.0 - smoothstep(0.0, 6.5, amb_d_root)) * tree_pull;
    let amb_dust_total = amb_d.x * blue_dust_mask * (1.0 + 1.2 * sumi_gather_m() + near_glint * 1.15) * (1.0 - root_absorb_amb * 0.96);
    col = mix(col, amb_gold_col, clamp(amb_dust_total * (0.80 + 0.30 * amb_pull_f), 0.0, 1.0));

    // Pendaran hisapan lembut tipis tepat di zona kontak partikel -> akar energi cair
    let siphon_haze = exp(-max(amb_d_root, 0.0) * 0.14) * amb_pull_f * 0.14 * blue_dust_mask;
    col = mix(col, gold_shimmer, siphon_haze);



    col = mix(col, sumi0, smoothstep(bar_h - 6.0, bar_h, py) * 0.45);
    return vec4<f32>(col, 0.96);
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGH-CONTRAST GLASS PILL & CRISP ICON RENDERING (WITH HOVER & LANTERN GLOW)
// ─────────────────────────────────────────────────────────────────────────────

struct WidgetPillResult {
    col: vec4<f32>,
    eff_center: vec2<f32>,
    hover: f32,
};

fn draw_widget_pill(
    base_col: vec3<f32>,
    p: vec2<f32>,
    center: vec2<f32>,
    half_size: vec2<f32>,
    r: f32,
    mouse_pos: vec2<f32>
) -> WidgetPillResult {
    // ─────────────────────────────────────────────────────────────────────────
    // WIDGET HOVER: LIQUID MAGNIFICATION & DYNAMIC LANTERN SPOTLIGHT
    // ─────────────────────────────────────────────────────────────────────────
    let d_mouse_box = sd_rounded_box(mouse_pos - center, half_size, r);
    // Smooth proximity falloff (~36px radius around pill)
    let hover_raw = clamp(1.0 - max(d_mouse_box, 0.0) / 36.0, 0.0, 1.0);
    let smooth_hover = hover_raw * hover_raw * (3.0 - 2.0 * hover_raw);

    // Subtle scale (+10%) & gentle vertical lift (-2.8px)
    let eff_half = half_size * (1.0 + 0.10 * smooth_hover);
    let eff_center = center - vec2<f32>(0.0, 2.8 * smooth_hover);
    let eff_r = r * (1.0 + 0.10 * smooth_hover);

    let d = sd_rounded_box(p - eff_center, eff_half, eff_r);
    
    // Dynamic Drop Shadow (deepens and drops lower as the pill lifts)
    let shadow_pos = eff_center + vec2<f32>(0.0, 3.0 + 2.5 * smooth_hover);
    let shadow_d = sd_rounded_box(p - shadow_pos, eff_half + vec2<f32>(1.5, 1.5), eff_r + 2.0);
    let shadow_a = (1.0 - smoothstep(-3.0, 5.0 + 3.0 * smooth_hover, shadow_d)) * (0.45 + 0.18 * smooth_hover);
    var out_col = mix(base_col, hex(10.0, 10.0, 14.0), shadow_a);

    let alpha = 1.0 - smoothstep(-0.8, 0.8, d);
    if (alpha <= 0.0) {
        return WidgetPillResult(vec4<f32>(out_col, 0.0), eff_center, smooth_hover);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ACRYLIC / MICA GLASSMORPHISM WITH FROSTED DIFFUSION
    // ─────────────────────────────────────────────────────────────────────────
    // Base acrylic/mica noise & subtle multi-tone frosted glass diffusion
    let glass_noise = fbm(p * 0.08 + vec2<f32>(u.time * 0.05, -u.time * 0.03));
    let mica_tint = mix(hex(28.0, 28.0, 38.0), hex(36.0, 38.0, 52.0), glass_noise * 0.6);
    var glass_body = mix(hex(32.0, 32.0, 44.0), mica_tint, 0.70);

    var rim_light  = hex(230.0, 195.0, 132.0);
    let rim_blue   = hex(127.0, 180.0, 202.0);

    // Titik fokus mengikuti kursor mouse di dalam pill
    let light_focus = clamp(
        mouse_pos,
        eff_center - eff_half + vec2<f32>(10.0, 10.0),
        eff_center + eff_half - vec2<f32>(10.0, 10.0)
    );
    let d_focus = length(p - light_focus);
    let aura_radius = max(eff_half.y * 1.6, 42.0);
    let aura_mask = (1.0 - smoothstep(0.0, aura_radius, d_focus)) * smooth_hover;

    // Kabut emas sangat tipis & lembut (tanpa lingkaran tajam)
    let subtle_mist = mix(glass_body, hex(225.0, 175.0, 95.0), aura_mask * 0.16);
    glass_body = mix(glass_body, subtle_mist, 0.5);

    // Partikel serpihan emas mikro (Gold Flakes) melayang di dalam kaca
    let flake_grid = (p - eff_center - vec2<f32>(u.time * 2.2, sin(p.x * 0.15 + u.time * 1.2) * 1.8)) / 3.4;
    let r_flake = hash21(floor(flake_grid));
    let cell_flake = fract(flake_grid) - vec2<f32>(0.5, 0.5);
    let dist_flake = length(cell_flake) * 3.4;
    let twinkle = 0.5 + 0.5 * sin(u.time * 4.0 + r_flake * 12.56);
    let flake_on = step(0.88, r_flake) * (1.0 - smoothstep(0.2, 1.0, dist_flake)) * twinkle;

    let gold_spark = mix(hex(255.0, 215.0, 125.0), hex(255.0, 245.0, 195.0), r_flake);
    glass_body = mix(glass_body, gold_spark, flake_on * aura_mask * 0.90);

    // ─────────────────────────────────────────────────────────────────────────
    // 1PX INNER BORDER (rgba(255, 255, 255, 0.12) / Pantulan Cahaya Kaca Mewah)
    // ─────────────────────────────────────────────────────────────────────────
    // Tepat di dalam tepi kapsul: d berada di antara -1.5 dan 0.0
    let inner_border_dist = abs(d + 0.75);
    let inner_border_mask = 1.0 - smoothstep(0.0, 0.85, inner_border_dist);
    // Gradient specular di bagian atas kapsul untuk refleksi kaca nyata
    let top_specular = smoothstep(eff_center.y + 4.0, eff_center.y - eff_half.y, p.y);
    let white_glass_edge = vec3<f32>(1.0, 1.0, 1.0);
    let inner_border_alpha = (0.12 + 0.18 * top_specular + 0.15 * smooth_hover) * inner_border_mask;
    glass_body = mix(glass_body, white_glass_edge, inner_border_alpha);

    // Crisp Gold Rim Flare saat di-hover
    let rim = smoothstep(1.8, 0.0, abs(d));
    rim_light = mix(rim_light, hex(255.0, 240.0, 175.0), smooth_hover * 0.85);
    let rim_tint = mix(rim_blue, rim_light, smoothstep(eff_center.y + 6.0, eff_center.y - 10.0, p.y));

    out_col = mix(out_col, glass_body, 0.86);
    out_col = mix(out_col, rim_tint, rim * (0.65 + 0.32 * smooth_hover));

    return WidgetPillResult(vec4<f32>(out_col, alpha), eff_center, smooth_hover);
}

fn draw_windows_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, hover: f32) -> vec3<f32> {
    let dp = abs(p - center);
    let gold_win = mix(hex(245.0, 210.0, 140.0), hex(255.0, 240.0, 180.0), hover);
    if (dp.x > 2.0 && dp.x < 11.5 && dp.y > 2.0 && dp.y < 11.5) {
        return gold_win;
    }
    return col;
}

fn draw_search_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, hover: f32) -> vec3<f32> {
    let d = length(p - (center + vec2<f32>(-3.0, -3.0)));
    let fg = mix(hex(240.0, 235.0, 215.0), hex(255.0, 252.0, 240.0), hover);
    if (abs(d - 8.0) < 2.0) {
        return fg;
    }
    let handle_p = p - (center + vec2<f32>(4.0, 4.0));
    if (abs(handle_p.x - handle_p.y) < 2.0 && handle_p.x > 0.0 && handle_p.x < 7.5) {
        return fg;
    }
    return col;
}

fn draw_wifi_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, mouse_pos: vec2<f32>) -> vec3<f32> {
    let d_mouse = length(mouse_pos - center);
    let hover_item = clamp(1.0 - d_mouse / 18.0, 0.0, 1.0);
    let fg = mix(hex(240.0, 235.0, 215.0), hex(255.0, 252.0, 240.0), hover_item);

    let origin = center + vec2<f32>(0.0, 6.0);
    let d = length(p - origin);

    // Center bottom dot
    let dot_a = 1.0 - smoothstep(1.7, 2.5, d);

    // Smooth angular cone mask opening upwards (~75 degrees cone)
    let angle_diff = abs(p.x - origin.x) - (origin.y - p.y) * 1.05;
    let cone_mask = smoothstep(1.2, -0.2, angle_diff) * step(p.y, origin.y - 1.2);

    // Inner arc (radius ~7.5) and Outer arc (radius ~12.5)
    let arc1_d = abs(d - 7.5);
    let arc1_a = (1.0 - smoothstep(0.7, 1.6, arc1_d)) * cone_mask;

    let arc2_d = abs(d - 12.8);
    let arc2_a = (1.0 - smoothstep(0.7, 1.6, arc2_d)) * cone_mask;

    let wifi_a = max(dot_a, max(arc1_a, arc2_a));
    let flags_m = u32(max(u.flyout_state.x, 0.0) + 0.5);
    let is_flight = (flags_m & 4u) != 0u;
    let is_wifi_on = (flags_m & 1u) != 0u;
    var w_tint = fg;
    var w_vis = wifi_a;
    if (is_flight) {
        w_tint = hex(235.0, 120.0, 85.0);
        w_vis = wifi_a * 0.55;
    } else if (!is_wifi_on) {
        w_vis = wifi_a * 0.35;
    }
    return mix(col, w_tint, w_vis);
}

fn draw_battery_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, mouse_pos: vec2<f32>) -> vec3<f32> {
    let d_mouse = length(mouse_pos - center);
    let hover_item = clamp(1.0 - d_mouse / 20.0, 0.0, 1.0);
    let fg = mix(hex(240.0, 235.0, 215.0), hex(255.0, 252.0, 240.0), hover_item);

    // Dynamic battery percentage from uniforms (0.0 .. 1.0)
    var bat_lvl = u.flyout_meta.w;
    if (bat_lvl <= 0.01) {
        bat_lvl = 0.85; // fallback
    }
    let is_charging = u.flyout_meta.z > 0.5;

    // Palette: Kin-paku gold for normal, soft Kanagawa moss/spring green if charging, lantern amber if low
    var fill_color = mix(hex(230.0, 195.0, 132.0), hex(255.0, 235.0, 175.0), hover_item);
    if (is_charging) {
        fill_color = mix(hex(152.0, 187.0, 108.0), hex(180.0, 215.0, 130.0), hover_item); // Kanagawa springGreen
    } else if (bat_lvl <= 0.20) {
        fill_color = mix(hex(235.0, 120.0, 85.0), hex(255.0, 150.0, 110.0), hover_item); // Kanagawa surimiOrange
    }

    // Battery outer casing (smooth rounded rectangle SDF)
    let body_half = vec2<f32>(12.0, 6.8);
    let d_body = abs(sd_rounded_box(p - (center - vec2<f32>(1.5, 0.0)), body_half, 2.2));
    let casing_a = 1.0 - smoothstep(0.8, 1.8, d_body);

    // Battery terminal tip (+)
    let tip_d = sd_rounded_box(p - (center + vec2<f32>(12.5, 0.0)), vec2<f32>(1.5, 3.5), 1.0);
    let tip_a = 1.0 - smoothstep(0.0, 1.0, tip_d);

    var out_col = mix(col, fg, max(casing_a, tip_a));

    // Refined charge level fill inside casing (anchored to left side)
    let max_fill_w = 18.0;
    let cur_fill_w = max_fill_w * clamp(bat_lvl, 0.08, 1.0);
    let fill_h = 4.4;
    let inner_left = (center.x - 1.5) - 9.8;
    let cur_fill_center_x = inner_left + cur_fill_w * 0.5;
    let fill_d = sd_rounded_box(p - vec2<f32>(cur_fill_center_x, center.y), vec2<f32>(cur_fill_w * 0.5, fill_h), 1.2);
    let fill_a = 1.0 - smoothstep(0.0, 1.0, fill_d);

    out_col = mix(out_col, fill_color, fill_a * 0.92);

    return out_col;
}

fn draw_volume_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, mouse_pos: vec2<f32>) -> vec3<f32> {
    let d_mouse = length(mouse_pos - center);
    let hover_item = clamp(1.0 - d_mouse / 18.0, 0.0, 1.0);
    let fg = mix(hex(240.0, 235.0, 215.0), hex(255.0, 252.0, 240.0), hover_item);

    let dx = p.x - center.x;
    let dy = abs(p.y - center.y);

    // Speaker base box
    let box_d = sd_rounded_box(p - (center + vec2<f32>(-4.5, 0.0)), vec2<f32>(2.6, 4.2), 0.8);
    let box_a = 1.0 - smoothstep(0.0, 1.0, box_d);

    // Speaker horn cone (trapezoid flare)
    var horn_a = 0.0;
    if (dx >= -3.5 && dx <= 3.5) {
        let max_y = (dx + 3.5) * 0.95 + 4.0;
        let d_edge = dy - max_y;
        horn_a = 1.0 - smoothstep(0.0, 1.0, d_edge);
    }

    // Sound waves (outer arc)
    let wave_d = abs(length(p - (center + vec2<f32>(-1.0, 0.0))) - 9.2);
    let wave_cone = smoothstep(6.8, 5.0, dy) * step(dx, 8.5) * step(4.0, dx);
    let wave_a = (1.0 - smoothstep(0.7, 1.6, wave_d)) * wave_cone;

    let flags_v = u32(max(u.flyout_state.x, 0.0) + 0.5);
    let is_muted = (flags_v & 32u) != 0u;
    let eff_wave = select(wave_a, 0.0, is_muted);
    let spk_a = max(max(box_a, horn_a), eff_wave);
    var v_col = mix(col, fg, spk_a);
    if (is_muted) {
        let d_slash = sd_seg(p, center + vec2<f32>(3.0, -5.0), center + vec2<f32>(10.0, 5.0));
        let slash_a = 1.0 - smoothstep(0.7, 1.5, d_slash);
        v_col = mix(v_col, hex(235.0, 120.0, 85.0), slash_a);
    }
    return v_col;
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL DIGITAL CLOCK (7-Segment Font in Authentic Kanagawa Gold)
// ─────────────────────────────────────────────────────────────────────────────

fn sd_seg(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Immune to DX12/HLSL jump-table optimization bugs
fn get_digit_bits(val: u32) -> u32 {
    if (val == 0u) { return 63u; }   // 0: abcdef
    if (val == 1u) { return 6u; }    // 1: bc
    if (val == 2u) { return 91u; }   // 2: abdeg
    if (val == 3u) { return 79u; }   // 3: abcdg
    if (val == 4u) { return 102u; }  // 4: bcfg
    if (val == 5u) { return 109u; }  // 5: acdfg
    if (val == 6u) { return 125u; }  // 6: acdefg
    if (val == 7u) { return 7u; }    // 7: abc
    if (val == 8u) { return 127u; }  // 8: abcdefg
    if (val == 9u) { return 111u; }  // 9: abcdfg
    return 0u;
}

fn draw_digit(p: vec2<f32>, center: vec2<f32>, digit: u32) -> f32 {
    let hw = 4.8;
    let hh = 8.5;
    let my = 0.0;
    var d = 999.0;

    // Tabular digit 1: Centered stem so it never shifts or looks misaligned!
    if (digit == 1u) {
        let stem = sd_seg(p, center + vec2<f32>(0.0, -hh + 0.8), center + vec2<f32>(0.0, hh - 0.8));
        let flag = sd_seg(p, center + vec2<f32>(-2.8, -hh + 3.4), center + vec2<f32>(0.0, -hh + 0.8));
        let foot = sd_seg(p, center + vec2<f32>(-3.2, hh - 0.8), center + vec2<f32>(3.2, hh - 0.8));
        d = min(stem, min(flag, foot));
    } else {
        let bits = get_digit_bits(digit);
        // Segment 0: Top (a)
        if ((bits & 1u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(-hw + 0.8, -hh), center + vec2<f32>(hw - 0.8, -hh)));
        }
        // Segment 1: Top-Right (b)
        if ((bits & 2u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(hw, -hh + 0.8), center + vec2<f32>(hw, my - 0.8)));
        }
        // Segment 2: Bottom-Right (c)
        if ((bits & 4u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(hw, my + 0.8), center + vec2<f32>(hw, hh - 0.8)));
        }
        // Segment 3: Bottom (d)
        if ((bits & 8u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(-hw + 0.8, hh), center + vec2<f32>(hw - 0.8, hh)));
        }
        // Segment 4: Bottom-Left (e)
        if ((bits & 16u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(-hw, my + 0.8), center + vec2<f32>(-hw, hh - 0.8)));
        }
        // Segment 5: Top-Left (f)
        if ((bits & 32u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(-hw, -hh + 0.8), center + vec2<f32>(-hw, my - 0.8)));
        }
        // Segment 6: Middle (g)
        if ((bits & 64u) != 0u) {
            d = min(d, sd_seg(p, center + vec2<f32>(-hw + 0.8, my), center + vec2<f32>(hw - 0.8, my)));
        }
    }

    let thickness = 1.15;
    return 1.0 - smoothstep(thickness * 0.75, thickness + 0.75, d);
}

fn draw_digital_clock(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, hover: f32) -> vec3<f32> {
    let hour_val = u32(clamp(u.clock_time.x, 0.0, 23.0));
    let min_val  = u32(clamp(u.clock_time.y, 0.0, 59.0));

    let h_tens = hour_val / 10u;
    let h_ones = hour_val % 10u;
    let m_tens = min_val / 10u;
    let m_ones = min_val % 10u;

    // Fixed tabular monospaced slots inside the pill
    let p_h1 = center + vec2<f32>(-27.0, 0.0);
    let p_h2 = center + vec2<f32>(-11.0, 0.0);
    let p_m1 = center + vec2<f32>(11.0, 0.0);
    let p_m2 = center + vec2<f32>(27.0, 0.0);

    var alpha = 0.0;
    alpha = max(alpha, draw_digit(p, p_h1, h_tens));
    alpha = max(alpha, draw_digit(p, p_h2, h_ones));
    alpha = max(alpha, draw_digit(p, p_m1, m_tens));
    alpha = max(alpha, draw_digit(p, p_m2, m_ones));

    // Colon dots (two glowing circular dots with smooth anti-aliasing)
    let dot1 = length(p - (center + vec2<f32>(0.0, -4.2)));
    let dot2 = length(p - (center + vec2<f32>(0.0, 4.2)));
    let d_colon = min(dot1, dot2);
    let colon_a = 1.0 - smoothstep(0.8, 1.8, d_colon);
    alpha = max(alpha, colon_a);

    let gold_clock = mix(hex(245.0, 210.0, 140.0), hex(255.0, 242.0, 185.0), hover);
    return mix(col, gold_clock, alpha);
}

fn draw_dock_app_icon(col: vec3<f32>, p: vec2<f32>, center: vec2<f32>, app_id: u32, is_active: bool, hover: f32) -> vec3<f32> {
    let fg = mix(hex(238.0, 232.0, 215.0), hex(255.0, 250.0, 242.0), hover);
    let gold_glow = hex(255.0, 230.0, 150.0);
    let active_blue = hex(127.0, 195.0, 235.0);

    var icon_d = 999.0;

    // App 0: Terminal / Console (>_)
    if (app_id == 0u) {
        let chev1 = sd_seg(p, center + vec2<f32>(-6.5, -5.2), center + vec2<f32>(-1.8, -0.6));
        let chev2 = sd_seg(p, center + vec2<f32>(-1.8, -0.6), center + vec2<f32>(-6.5, 4.0));
        let cur = sd_seg(p, center + vec2<f32>(0.5, 4.2), center + vec2<f32>(6.5, 4.2));
        let fr = abs(sd_rounded_box(p - center, vec2<f32>(10.5, 8.5), 3.0));
        icon_d = min(min(min(chev1, chev2), cur), fr);
    }
    // App 1: Code Editor (</>)
    else if (app_id == 1u) {
        let lb1 = sd_seg(p, center + vec2<f32>(-3.2, -6.5), center + vec2<f32>(-7.5, 0.0));
        let lb2 = sd_seg(p, center + vec2<f32>(-7.5, 0.0), center + vec2<f32>(-3.2, 6.5));
        let slash = sd_seg(p, center + vec2<f32>(1.6, -7.0), center + vec2<f32>(-1.6, 7.0));
        let rb1 = sd_seg(p, center + vec2<f32>(3.2, -6.5), center + vec2<f32>(7.5, 0.0));
        let rb2 = sd_seg(p, center + vec2<f32>(7.5, 0.0), center + vec2<f32>(3.2, 6.5));
        icon_d = min(min(min(lb1, lb2), slash), min(rb1, rb2));
    }
    // App 2: Web Browser (Globe)
    else if (app_id == 2u) {
        let r = length(p - center);
        let rim = abs(r - 8.2);
        let eq_seg = sd_seg(p, center + vec2<f32>(-8.2, 0.0), center + vec2<f32>(8.2, 0.0));
        let meridian = abs(length((p - center) * vec2<f32>(2.2, 1.0)) - 8.2);
        let mer_clip = select(999.0, meridian, r <= 8.5);
        icon_d = min(min(rim, eq_seg), mer_clip);
    }
    // App 3: File Explorer (Folder)
    else {
        let tab = sd_rounded_box(p - (center + vec2<f32>(-4.0, -5.2)), vec2<f32>(4.2, 2.5), 1.2);
        let body = abs(sd_rounded_box(p - (center + vec2<f32>(0.0, 1.5)), vec2<f32>(9.5, 6.2), 2.2));
        let line = sd_seg(p, center + vec2<f32>(-8.0, -1.0), center + vec2<f32>(8.0, -1.0));
        icon_d = min(min(tab, body), line);
    }

    let icon_a = 1.0 - smoothstep(0.75, 1.75, icon_d);
    var out_col = mix(col, fg, icon_a * (0.90 + 0.10 * hover));

    // Active App Indicator Bar underneath icon
    if (is_active) {
        let ind_c = center + vec2<f32>(0.0, 17.5);
        let half_w = select(5.5, 8.5, hover > 0.05);
        let ind_d = sd_rounded_box(p - ind_c, vec2<f32>(half_w, 1.4), 1.0);
        let ind_a = 1.0 - smoothstep(0.0, 1.0, ind_d);

        let halo_dist = length(p - ind_c);
        let halo_a = (1.0 - smoothstep(1.5, 7.5, halo_dist)) * (0.35 + 0.45 * hover);

        let ind_tint = mix(active_blue, gold_glow, hover * 0.65);
        out_col = mix(out_col, ind_tint, max(ind_a * 0.95, halo_a));
    }

    return out_col;
}

// ─────────────────────────────────────────────────────────────────────────────
// NON-BORDER MODULAR FLYOUT RENDERING
// Tanpa border, jadi bentuk flyout harus mengikuti karakter materialnya:
//   LiquidSpire : cairan tinta kental. Meniscus -> kolom memanjat -> kepala tetes -> konten
//   SumiCloud   : partikel emas berkumpul -> erupsi + haze tinta -> konten
//   PureHud     : kontrol mengambang tanpa latar
// Semua fase digerakkan oleh open_t (pegas). Saat open_t turun, urutan fase
// otomatis berjalan mundur (animasi keluar).
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// START MENU FASE 1: SEARCH PILL LIQUID GOLD-SUMI ABSORPTION INTO START BUTTON
//   - st = 0.00..0.30 : Search pill mencair jadi blob tinta emas Kanagawa
//   - st = 0.20..0.88 : Blob meluncur & tersedot masuk ke tombol Windows via smin_cubic
//   - st = 0.65..1.00 : Search lenyap bersih, tombol Windows terisi energi tinta emas
// ─────────────────────────────────────────────────────────────────────────────
fn draw_start_search_phase1(
    in_col: vec3<f32>,
    p: vec2<f32>,
    win_center: vec2<f32>,
    search_center: vec2<f32>,
    mouse_pos: vec2<f32>,
    widget_alpha: f32,
) -> vec3<f32> {
    var color = in_col;
    let st = clamp(u.start_info.x, 0.0, 1.08);
    let st_c = clamp(st, 0.0, 1.0);

    // Kondisi normal (Start tertutup): render tombol Windows & Search standar
    if (st_c <= 0.002) {
        let pill_win = draw_widget_pill(color, p, win_center, vec2<f32>(30.0, 30.0), 16.0, mouse_pos);
        if (pill_win.col.a > 0.0) {
            let win_col = draw_windows_icon(pill_win.col.rgb, p, pill_win.eff_center, pill_win.hover);
            color = mix(color, win_col, widget_alpha);
        }
        let pill_search = draw_widget_pill(color, p, search_center, vec2<f32>(30.0, 30.0), 16.0, mouse_pos);
        if (pill_search.col.a > 0.0) {
            let search_col = draw_search_icon(pill_search.col.rgb, p, pill_search.eff_center, pill_search.hover);
            color = mix(color, search_col, widget_alpha);
        }
        return color;
    }

    // Tahap animasi Fase 1
    let melt = smoothstep(0.0, 0.34, st_c);
    let travel = smoothstep(0.18, 0.88, st_c);
    let travel_arc = sin(travel * 3.14159265);
    let charge = smoothstep(0.62, 1.0, st_c);
    let icon_fade = 1.0 - smoothstep(0.02, 0.24, st_c);

    // Posisi & deformasi blob Search yang mencair lalu meluncur ke tombol Windows
    let blob_pos = mix(search_center, win_center, travel)
                 + vec2<f32>(0.0, -sin(travel * 3.14159265) * 4.5);
    let wobble = (fbm(p * 0.075 + vec2<f32>(u.time * 1.4, -u.time * 0.9)) - 0.5) * 5.0 * melt * (1.0 - charge * 0.65);

    // Bentuk Search pill -> tetesan tinta lonjong horizontal saat tersedot
    let base_hw = mix(30.0, 22.0, melt) + travel_arc * 12.0 - charge * 18.0;
    let base_hh = mix(30.0, 20.0, melt) - travel_arc * 5.5 - charge * 16.0;
    let blob_half = max(vec2<f32>(base_hw, base_hh), vec2<f32>(2.0, 2.0));
    let blob_r = min(min(blob_half.x, blob_half.y), mix(16.0, 20.0, melt));
    var d_blob = sd_rounded_box(p - blob_pos, blob_half, blob_r) + wobble;

    // 3 tetesan emas mikro yang terlepas di belakang blob lalu ikut tersedot masuk
    if (travel > 0.05 && travel < 0.95) {
        for (var i = 0; i < 3; i = i + 1) {
            let fi = f32(i);
            let lag = clamp(travel - (0.08 + fi * 0.06), 0.0, 1.0);
            let drop_p = mix(search_center, win_center, lag)
                       + vec2<f32>(6.0 + fi * 4.5, sin(u.time * 4.5 + fi * 2.1) * 4.5 * travel_arc);
            let drop_r = (5.2 - fi * 1.1) * travel_arc * (1.0 - charge);
            let d_drop = length(p - drop_p) - max(drop_r, 0.5);
            d_blob = smin_cubic(d_blob, d_drop, 8.0 * travel_arc);
        }
    }

    // SDF tombol Windows (sedikit membesar saat menelan blob)
    let swallow_pulse = sin(smoothstep(0.55, 1.0, st_c) * 3.14159265) * 2.6;
    let win_half = vec2<f32>(30.0 + swallow_pulse, 30.0 + swallow_pulse * 0.8);
    let d_win_shape = sd_rounded_box(p - win_center, win_half, 16.0);

    // Jembatan metaball cairan kental antara blob Search dan tombol Windows
    let bridge_k = 24.0 * travel_arc + 10.0 * melt * (1.0 - charge);
    let d_merged = smin_cubic(d_win_shape, d_blob, max(bridge_k, 1.0));

    // Area cairan emas-tinta yang berada di luar kotak Windows murni (atau menyelimuti tepi)
    let merged_mask = (1.0 - smoothstep(-0.8, 0.8, d_merged)) * widget_alpha;
    let blob_only_mask = (1.0 - smoothstep(-0.8, 0.8, d_blob)) * widget_alpha;

    // 1. Render lapisan cairan tinta emas Kanagawa (Metaball Blob + Bridge)
    if (merged_mask > 0.001) {
        let sumi_deep   = hex(18.0, 20.0, 30.0);
        let prussian    = hex(34.0, 56.0, 82.0);
        let gold_amber  = hex(220.0, 165.0, 97.0);
        let gold_bright = hex(238.0, 204.0, 138.0);
        let gold_shim   = hex(255.0, 242.0, 185.0);

        let ink_w = fbm(p * 0.055 + vec2<f32>(u.time * 0.65, -u.time * 0.35));
        let vein_n = fbm(p * 0.11 - vec2<f32>(u.time * 1.1, u.time * 0.4));

        // Inti cairan tinta sumi + pusaran emas Kintsugi
        var liq_col = mix(sumi_deep, prussian, ink_w * 0.65);
        let gold_vein = smoothstep(0.46, 0.82, vein_n);
        liq_col = mix(liq_col, gold_amber, gold_vein * (0.45 + 0.35 * melt));
        liq_col = mix(liq_col, gold_bright, smoothstep(0.68, 0.94, vein_n) * 0.72);

        // Serpihan emas mikro berkilau di dalam cairan
        let fg = (p - vec2<f32>(-u.time * 18.0 * travel_arc, u.time * 4.0)) / 3.0;
        let rf = hash21(floor(fg));
        let df = length(fract(fg) - vec2<f32>(0.5, 0.5)) * 3.0;
        let tw = 0.5 + 0.5 * sin(u.time * 5.0 + rf * 12.56);
        let flk = step(0.84, rf) * (1.0 - smoothstep(0.2, 1.0, df)) * tw;
        liq_col = mix(liq_col, gold_shim, flk * 0.90);

        // Meniscus tepi emas bercahaya
        let rim = smoothstep(2.4, 0.0, abs(d_merged));
        liq_col = mix(liq_col, mix(gold_bright, gold_shim, 0.5), rim * 0.88);

        // Transisi halus dari kaca Search awal ke cairan tinta emas
        let liq_alpha = merged_mask * clamp(melt * 0.96 + travel_arc * 0.25, 0.0, 0.96);
        // Hanya gambar cairan penuh pada area blob & jembatan (jangan timpa tombol Windows sebelum digambar)
        let outside_win = smoothstep(-2.0, 3.5, d_win_shape);
        let blend_liq = max(outside_win * liq_alpha, blob_only_mask * (1.0 - charge) * 0.88);
        color = mix(color, liq_col, clamp(blend_liq, 0.0, 0.95));
    }

    // 2. Jika masih awal fase melt, sisa kaca Search pill + ikon Search memudar keemasan
    if (icon_fade > 0.01) {
        let search_ic = draw_search_icon(color, p, blob_pos, 0.6 + 0.4 * melt);
        color = mix(color, search_ic, icon_fade * widget_alpha);
    }

    // 3. TOMBOL WINDOWS TERJERAT SULUR EMAS CAIR + RETAKAN KINTSUGI (2-LAYER)
    let p2_c = clamp(u.start_info.y, 0.0, 1.0);
    let win_cinch = clamp(u.start_info.w, -0.22, 1.0);
    let win_flash = clamp(u.start_fx.x, 0.0, 1.0);
    let win_ripple = clamp(u.start_fx.y, 0.0, 1.0);
    let d_m_win = sd_rounded_box(mouse_pos - win_center, win_half, 16.0);
    let win_hov_raw = clamp(1.0 - max(d_m_win, 0.0) / 36.0, 0.0, 1.0);
    let win_hov = win_hov_raw * win_hov_raw * (3.0 - 2.0 * win_hov_raw);

    // LAYER A: Sulur Lilitan BELAKANG (di belakang tombol Windows, energi cair lembut yang menyatu dengan nebari)
    if (p2_c > 0.12) {
        let back_r = eval_win_entangle_layer(p, win_center, p2_c, win_hov, win_cinch, u.time, false);
        let aa_b = 1.05;
        let aura_b = exp(-max(back_r.x, 0.0) * 0.22) * 0.28 * widget_alpha;
        if (aura_b > 0.002) {
            color = mix(color, hex(226.0, 170.0, 82.0), aura_b);
        }
        let m_b = (1.0 - smoothstep(-aa_b, aa_b, back_r.x)) * widget_alpha;
        if (m_b > 0.001) {
            let b_rad = mix(2.5, 0.95, back_r.y);
            let b_col = shade_liquid_energy_root(
                p, back_r.x, b_rad, back_r.z, back_r.w, back_r.y, 5.0, 0.35, 0.42 + win_hov * 0.45 + win_flash * 0.5, u.time
            ) * 0.80;
            color = mix(color, b_col, m_b * 0.94);
        }
    }

    // LAYER B: Tombol Windows + Ikon (ikon 4-kotak tetap 100% terbaca) + Retakan Kintsugi Emas Cair
    let pill_win = draw_widget_pill(color, p, win_center, win_half, 16.0, mouse_pos);
    if (pill_win.col.a > 0.0) {
        var wc = pill_win.col.rgb;
        let charge_glow = clamp(charge + travel_arc * 0.45, 0.0, 1.0);
        if (charge_glow > 0.01) {
            let gold_bright = hex(238.0, 204.0, 138.0);
            let gold_shim = hex(255.0, 242.0, 185.0);
            let swirl_n = fbm((p - pill_win.eff_center) * 0.09 + vec2<f32>(u.time * 0.5, -u.time * 0.7));
            wc = mix(wc, hex(36.0, 54.0, 78.0), charge_glow * 0.28 * swirl_n);
            wc = mix(wc, gold_bright, smoothstep(0.60, 0.92, swirl_n) * charge_glow * 0.25);

            let d_w = sd_rounded_box(p - pill_win.eff_center, win_half, 16.0);
            let w_rim = smoothstep(2.0, 0.0, abs(d_w));
            let pulse = 0.75 + 0.25 * sin(u.time * 1.57);
            wc = mix(wc, mix(gold_bright, gold_shim, pulse), w_rim * charge_glow * 0.85);
        }

        // LAYER B.1: Retakan Kintsugi Emas Cair di permukaan kaca tombol (di bawah ikon Windows agar ikon selalu tajam!)
        if (p2_c > 0.18 || win_flash > 0.005 || win_ripple < 0.99) {
            let kintsugi = eval_win_kintsugi_cracks(p, pill_win.eff_center, p2_c, win_hov, win_flash, win_ripple, u.time);
            if (kintsugi.a > 0.001) {
                wc = mix(wc, kintsugi.rgb, kintsugi.a);
            }
        }

        let win_col = draw_windows_icon(wc, p, pill_win.eff_center, max(pill_win.hover, charge * 0.85));
        color = mix(color, win_col, widget_alpha);
    } else if (win_ripple < 0.99) {
        // Riak cahaya tunggal saat tombol Windows diklik bisa menyebar lembut melewati tepi tombol
        let k_rip = eval_win_kintsugi_cracks(p, win_center, p2_c, win_hov, win_flash, win_ripple, u.time);
        if (k_rip.a > 0.001) {
            color = mix(color, k_rip.rgb, k_rip.a * widget_alpha);
        }
    }

    // LAYER C: Sulur Lilitan DEPAN 3D (energi cair lembut tersambung langsung dari nebari L3 + bayangan kontak)
    if (p2_c > 0.12) {
        let front_r = eval_win_entangle_layer(p, pill_win.eff_center, p2_c, win_hov, win_cinch, u.time, true);
        let sh_sample = eval_win_entangle_layer(p - vec2<f32>(1.5, 2.4), pill_win.eff_center, p2_c, win_hov, win_cinch, u.time, true);
        let aa_f = 1.05;
        // Bayangan kontak lembut jatuh di kaca tombol tepat di bawah sulur depan
        let sh_f = (1.0 - smoothstep(-0.6, 3.8, sh_sample.x)) * 0.42 * widget_alpha;
        color = mix(color, hex(8.0, 10.0, 16.0), sh_f);

        // Aura energi cair lembut di sekeliling lilitan depan
        let aura_f = exp(-max(front_r.x, 0.0) * 0.22) * (0.28 + 0.22 * win_hov + 0.35 * win_flash) * widget_alpha;
        if (aura_f > 0.002) {
            color = mix(color, hex(238.0, 186.0, 96.0), aura_f);
        }

        let m_f = (1.0 - smoothstep(-aa_f, aa_f, front_r.x)) * widget_alpha;
        if (m_f > 0.001) {
            let f_rad = mix(2.75, 0.45, front_r.y);
            var f_col = shade_liquid_energy_root(
                p, front_r.x, f_rad, front_r.z, front_r.w, front_r.y, 4.0, 0.18, 0.52 + win_hov * 0.45 + win_flash * 0.60, u.time
            );
            f_col = mix(f_col, hex(255.0, 248.0, 212.0), clamp(win_hov * 0.26 + win_flash * 0.52, 0.0, 0.72));
            let tip_soft = 1.0 - smoothstep(0.78, 1.0, front_r.y) * 0.28;
            color = mix(color, f_col, m_f * tip_soft * 0.96);
        }
    }

    return color;
}
