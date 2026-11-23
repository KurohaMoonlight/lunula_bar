struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct GlobUniforms {
    screen_size: vec2<f32>,   // window size (width, height)
    bar_width: f32,           // main bar width (50% screen)
    bar_height: f32,          // max height (108.0)
    corner_radius: f32,       // 42.0
    fillet_radius: f32,       // 130.0
    time: f32,
    srgb_target: f32,         // 1.0 if srgb
    anim_t: f32,              // 0.0 = peeking crest, 1.0 = fully open
    wave_surge: f32,          // kinetic surge energy from motion
    mouse_pos: vec2<f32>,     // window cursor coordinate (x, y)
    pull_strength: f32,       // 0.0 .. 1.0 magnetic pull intensity
    mouse_speed: f32,         // kecepatan gerak mouse
    mouse_slosh: f32,         // unused / reserved
    _pad0: f32,
    clock_time: vec4<f32>,    // [hour, minute, second, 0.0]
    flyout_info: vec4<f32>,   // [module (0=none, 1=vol, 2=bat, 3=wifi), open_t (0..1), theme (0..2), value]
    flyout_meta: vec4<f32>,   // [center_x, center_y, is_charging, bat_percent]
    flyout_state: vec4<f32>,  // [flags_bitmask, power_mode, sound_output, brightness]
    flyout_extra: vec4<f32>,  // [bat_mins, wifi_signal, volume_level, sub_open_t]
    font_scales: vec4<f32>,   // [display_scale, body_scale, dpi_factor, 0.0]
    texture_params: vec4<f32>, // [texture_intensity, texture_fade_px, sub1_offset_x, backdrop_alpha]
    chain_info: vec4<f32>,     // [slot1_kind, slot2_kind, slot2_open_t, wifi_toggle_t]
    chain_offsets: vec4<f32>,  // [sub1_offset_x, sub2_offset_x, slot2_parent_is_main, spatial_toggle_t]
    audio_levels: vec4<f32>,   // [app0_vol, app1_vol, app2_vol, mic_gain]
};

@group(0) @binding(0)
var<uniform> u: GlobUniforms;

@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;
    var positions = array<vec2<f32>, 4>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>(-1.0,  1.0),
        vec2<f32>( 1.0,  1.0)
    );

    let indices = array<u32, 6>(0u, 1u, 2u, 2u, 1u, 3u);
    let p = positions[indices[in_vertex_index]];
    out.position = vec4<f32>(p, 0.0, 1.0);
    out.uv = vec2<f32>((p.x + 1.0) * 0.5, (1.0 - p.y) * 0.5);
    return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
// ─────────────────────────────────────────────────────────────────────────────
fn s2l(c: vec3<f32>) -> vec3<f32> {
    let lo = c / 12.92;
    let hi = pow((c + vec3<f32>(0.055)) / 1.055, vec3<f32>(2.4));
    return select(hi, lo, c <= vec3<f32>(0.04045));
}

fn hex(r: f32, g: f32, b: f32) -> vec3<f32> {
    let c = vec3<f32>(r, g, b) / 255.0;
    if (u.srgb_target > 0.5) {
        return s2l(c);
    }
    return c;
}

// ─────────────────────────────────────────────────────────────────────────────
// Noise & Waves
// ─────────────────────────────────────────────────────────────────────────────
fn hash21(p: vec2<f32>) -> f32 {
    var q = fract(p * vec2<f32>(123.34, 456.21));
    q = q + dot(q, q + vec2<f32>(45.32, 45.32));
    return fract(q.x * q.y);
}

fn vnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let sm = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, sm.x), mix(c, d, sm.x), sm.y);
}

fn fbm(p: vec2<f32>) -> f32 {
    var v = 0.0;
    var a = 0.5;
    var q = p;
    for (var i = 0; i < 3; i = i + 1) {
        v = v + a * vnoise(q);
        q = q * 2.03 + vec2<f32>(17.0, 9.0);
        a = a * 0.5;
    }
    return v;
}

fn swell(x: f32, t: f32, period: f32, amp: f32, speed: f32, phase0: f32) -> vec2<f32> {
    let s = fract(x / period - t * speed + phase0);
    let rise = pow(s, 2.2);
    let fallen = 1.0 - smoothstep(0.86, 0.99, s);
    let h = rise * fallen * amp;
    let front = smoothstep(0.68, 0.88, s) * fallen;
    return vec2<f32>(h, front);
}

fn sd_rounded_box(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = abs(p) - b + vec2<f32>(r, r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2<f32>(0.0, 0.0))) - r;
}

fn smin_cubic(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sumi Cloud fase 1: debu emas ASLI taskbar bergeser menyusuri taskbar ke tombol.
// Medan debu di-sampel dengan koordinat x yang dimampatkan menuju titik tombol,
// jadi serpihan yang sama (bukan partikel tambahan) terlihat tersedot memusat.
// ─────────────────────────────────────────────────────────────────────────────
fn sumi_gather_m() -> f32 {
    let on = u.flyout_info.x > 0.5 && u.flyout_info.z > 0.5 && u.flyout_info.z < 1.5;
    if (!on) {
        return 0.0;
    }
    let g = smoothstep(0.0, 0.36, u.flyout_info.y);
    return 0.72 * g * g * (3.0 - 2.0 * g);
}

fn sumi_gather_warp(q: vec2<f32>, bar_w: f32) -> vec2<f32> {
    let m = sumi_gather_m();
    if (m <= 0.001) {
        return q;
    }
    let a_loc = u.flyout_meta.x - (u.screen_size.x * 0.5 - bar_w * 0.5);
    return vec2<f32>(a_loc + (q.x - a_loc) / (1.0 - m), q.y);
}

// Medan debu emas ambient taskbar (dua grid). Dipakai taskbar DAN aliran flyout.
// return: (intensitas, variasi warna)
fn ambient_dust(eff_p: vec2<f32>, t: f32, th_off: f32) -> vec2<f32> {
    let amb_pos1 = (eff_p - vec2<f32>(t * 2.0, sin(eff_p.x * 0.015 + t * 0.4) * 2.5)) / 4.4;
    let amb_r1 = hash21(floor(amb_pos1));
    let amb_cell1 = fract(amb_pos1) - vec2<f32>(0.5, 0.5);
    let amb_dist1 = length(amb_cell1) * 4.4;
    let amb_twinkle1 = 0.50 + 0.50 * sin(t * 1.8 + amb_r1 * 12.56);
    let amb_flake1 = step(0.925 + th_off, amb_r1) * (1.0 - smoothstep(0.20, 1.10, amb_dist1)) * amb_twinkle1;

    let amb_pos2 = (eff_p + vec2<f32>(t * 1.2, -t * 0.6 + 47.1)) / 3.0;
    let amb_r2 = hash21(floor(amb_pos2));
    let amb_cell2 = fract(amb_pos2) - vec2<f32>(0.5, 0.5);
    let amb_dist2 = length(amb_cell2) * 3.0;
    let amb_twinkle2 = 0.45 + 0.55 * cos(t * 2.4 + amb_r2 * 8.0);
    let amb_flake2 = step(0.940 + th_off, amb_r2) * (1.0 - smoothstep(0.15, 0.90, amb_dist2)) * amb_twinkle2;

    return vec2<f32>(amb_flake1 * 0.60 + amb_flake2 * 0.40, amb_r1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanagawa Wave with Gold Dust Dispersion
// Ombak mengalir tenang alami (tanpa sloshing), namun partikel debu emas
// menyebar buyar lembut (dispersi angin) saat kursor mouse melintas
// ─────────────────────────────────────────────────────────────────────────────
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
    let rough = (fbm(vec2<f32>(px * 0.05, t * 0.10 + 3.7)) - 0.44) * mix(1.0, 3.8, min(anim_t, 1.0));
    
    let crest_base = mix(bar_h * 0.50, bar_h * 0.64, min(anim_t, 1.0));
    let crest_y = max(crest_base - sw.x - sin(px * 0.07 - t * 0.9) * (0.8 + surge * 1.5) - rough, 1.5);
    let front = clamp(sw.y, 0.0, 1.0);
    let dc = py - crest_y;

    if (dc < 0.0) {
        col = mix(col, wave2, exp(dc / 5.0) * (0.22 + 0.18 * wash));
        col = mix(col, gold_bright, exp(dc / 3.5) * (0.35 + surge * 0.35));

        // ─────────────────────────────────────────────────────────────────────
        // GOLD DUST DISPERSION (Partikel emas menyebar buyar tertiup kursor)
        // ─────────────────────────────────────────────────────────────────────
        // Hitung jarak ke kursor mouse lokal
        let d_cursor = length(p - m_local);
        let disp_radius = 90.0;
        let wind_force = clamp(1.0 - d_cursor / disp_radius, 0.0, 1.0);
        
        // Vektor hembusan angin dari mouse
        let wind_dir = (p - m_local) / max(d_cursor, 1.0);
        // Partikel emas bergeser perlahan menjauhi titik mouse
        let disp_offset = wind_dir * (wind_force * 18.0);
        let dust_pos = (sumi_gather_warp(p - disp_offset, bar_w) - vec2<f32>(t * 10.4, 0.0)) / 2.6;

        let r = hash21(floor(dust_pos));
        let cell = fract(dust_pos) - vec2<f32>(0.5, 0.5);
        let dist = length(cell) * 2.6;

        // Saat tertiup kursor, kerapatan serbuk emas menyebar meluas
        let drop_thresh = mix(0.91, 0.82, min(anim_t, 1.0)) - (surge + wind_force * 0.5) * 0.08;
        let drop_on = step(drop_thresh, r) * (1.0 - smoothstep(0.35, 1.0, dist));
        
        let spray_mask = front * smoothstep(-14.0 - wind_force * 10.0, -1.0, dc);
        let drop_col = mix(gold_bright, gold_shimmer, r);
        col = mix(col, drop_col, drop_on * spray_mask * 0.95);
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
    let eff_p = sumi_gather_warp(p - amb_wind_offset, bar_w);
    let amb_d = ambient_dust(eff_p, t, 0.0);

    // Masker: Terlihat paling anggun di area atas yang biru kosong (dc < 0.0), serta lembut di sela air
    let upper_blue_mask = smoothstep(14.0, -8.0, dc) * smoothstep(0.0, 18.0, py);
    let body_blue_mask  = smoothstep(-4.0, 16.0, dc) * (1.0 - smoothstep(bar_h - 10.0, bar_h, py)) * 0.35;
    let blue_dust_mask  = max(upper_blue_mask, body_blue_mask);

    let amb_gold_col = mix(gold_amber, gold_shimmer, amb_d.y);
    let amb_dust_total = amb_d.x * blue_dust_mask * (1.0 + 1.2 * sumi_gather_m());
    col = mix(col, amb_gold_col, clamp(amb_dust_total * 0.70, 0.0, 1.0));

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

const FLY_RISE: f32 = 280.0;   // jarak pusat kepala flyout di atas titik tombol (sama dengan src/flyout/mod.rs)

struct FlyoutRenderResult {
    col: vec3<f32>,
    alpha: f32,
};

fn fly_hash1(n: f32) -> f32 {
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// Komposit "over" (non-premultiplied) -> (rgb, alpha)
fn fly_over(dst_c: vec3<f32>, dst_a: f32, src_c: vec3<f32>, src_a: f32) -> vec4<f32> {
    let out_a = src_a + dst_a * (1.0 - src_a);
    let out_c = (src_c * src_a + dst_c * dst_a * (1.0 - src_a)) / max(out_a, 0.0001);
    return vec4<f32>(out_c, out_a);
}

fn fly_flag(bit: u32) -> bool {
    let mask = u32(max(u.flyout_state.x, 0.0) + 0.5);
    return (mask & (1u << bit)) != 0u;
}

// Layer partikel organik (jittered grid) yang mengalir naik
fn sumi_particle_layer(
    pos: vec2<f32>,
    cell_size: f32,
    speed_y: f32,
    thresh: f32,
    radius_px: f32,
    time: f32,
    seed_off: vec2<f32>,
) -> vec2<f32> {
    let sp = (pos + vec2<f32>(0.0, time * speed_y) + seed_off) / cell_size;
    let cell_id = floor(sp);
    let f = fract(sp) - vec2<f32>(0.5, 0.5);

    let r1 = hash21(cell_id + seed_off * 0.13);
    let r2 = hash21(cell_id * 1.73 + vec2<f32>(19.4, 7.1) + seed_off * 0.07);
    let r3 = hash21(cell_id * 2.41 + vec2<f32>(3.7, 29.3));

    let jitter = (vec2<f32>(r2, r3) - vec2<f32>(0.5, 0.5)) * 0.62;
    let drift_x = sin(time * (1.8 + r2 * 2.2) + r1 * 12.56) * 0.12;
    let dist_px = length(f - jitter - vec2<f32>(drift_x, 0.0)) * cell_size;

    let twinkle = 0.45 + 0.55 * sin(time * (2.6 + r3 * 3.4) + r1 * 18.84);
    let eff_r = radius_px * (0.65 + 0.65 * r2);
    let dot_a = step(thresh, r1) * (1.0 - smoothstep(eff_r * 0.25, eff_r, dist_px)) * twinkle;
    return vec2<f32>(dot_a, r1);
}

fn icon_chevron_sdf(p: vec2<f32>, c: vec2<f32>, s: f32, is_left: bool) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let sgn = select(1.0, -1.0, is_left);
    let s1 = sd_seg(q, vec2<f32>(-2.4 * sgn, -4.5), vec2<f32>(2.4 * sgn, 0.0));
    let s2 = sd_seg(q, vec2<f32>(2.4 * sgn, 0.0), vec2<f32>(-2.4 * sgn, 4.5));
    let d = min(s1, s2) - 0.9;
    return 1.0 - smoothstep(0.0, 1.2, d);
}

fn icon_lock_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let body = sd_rounded_box(q - vec2<f32>(0.0, 1.8), vec2<f32>(4.2, 3.2), 1.2);
    let shackle_r = length(q - vec2<f32>(0.0, -1.8));
    let shackle = abs(shackle_r - 2.8) - 0.85;
    let shackle_mask = step(q.y, 0.2);
    let d = min(body, max(shackle, 1.0 - shackle_mask));
    return 1.0 - smoothstep(0.0, 1.0, d);
}

fn icon_refresh_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q);
    let arc = abs(r - 4.5) - 0.95;
    let ang = atan2(q.y, q.x);
    let arc_cut = step(0.6, abs(ang - 1.57));
    let arrow_tip = sd_seg(q, vec2<f32>(4.5, -0.5), vec2<f32>(1.8, -3.2));
    let arrow_tip2 = sd_seg(q, vec2<f32>(4.5, -0.5), vec2<f32>(7.2, -3.2));
    let d = min(max(arc, 1.0 - arc_cut), min(arrow_tip, arrow_tip2) - 0.8);
    return 1.0 - smoothstep(0.0, 1.1, d);
}

// ─────────────────────────────────────────────────────────────────────────────
// SMOOTH VECTOR SDF TYPOGRAPHY (Anti-aliased, Crisp, Professional Native UI)
// ─────────────────────────────────────────────────────────────────────────────
const CH_A: u32 = 65u;
const CH_B: u32 = 66u;
const CH_C: u32 = 67u;
const CH_D: u32 = 68u;
const CH_E: u32 = 69u;
const CH_F: u32 = 70u;
const CH_G: u32 = 71u;
const CH_H: u32 = 72u;
const CH_I: u32 = 73u;
const CH_K: u32 = 75u;
const CH_L: u32 = 76u;
const CH_M: u32 = 77u;
const CH_N: u32 = 78u;
const CH_O: u32 = 79u;
const CH_P: u32 = 80u;
const CH_R: u32 = 82u;
const CH_S: u32 = 83u;
const CH_T: u32 = 84u;
const CH_U: u32 = 85u;
const CH_V: u32 = 86u;
const CH_W: u32 = 87u;
const CH_0: u32 = 48u;
const CH_1: u32 = 49u;
const CH_2: u32 = 50u;
const CH_3: u32 = 51u;
const CH_4: u32 = 52u;
const CH_5: u32 = 53u;
const CH_6: u32 = 54u;
const CH_7: u32 = 55u;
const CH_8: u32 = 56u;
const CH_9: u32 = 57u;

fn sd_vector_char(q: vec2<f32>, code: u32) -> f32 {
    var d = 999.0;

    // 'A' (65u) - Space Grotesk geometric flat apex
    if (code == 65u) {
        let apex = sd_seg(q, vec2<f32>(-0.8, -6.0), vec2<f32>(0.8, -6.0));
        let leg_l = sd_seg(q, vec2<f32>(-0.8, -6.0), vec2<f32>(-3.6, 6.0));
        let leg_r = sd_seg(q, vec2<f32>(0.8, -6.0), vec2<f32>(3.6, 6.0));
        let bar = sd_seg(q, vec2<f32>(-2.1, 1.5), vec2<f32>(2.1, 1.5));
        d = min(min(apex, min(leg_l, leg_r)), bar);
    }
    // 'B' (66u)
    else if (code == 66u) {
        let spine = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(1.0, -6.0));
        let top_r = sd_seg(q, vec2<f32>(1.0, -6.0), vec2<f32>(3.4, -3.2));
        let top_d = sd_seg(q, vec2<f32>(3.4, -3.2), vec2<f32>(1.0, -0.4));
        let mid_b = sd_seg(q, vec2<f32>(-3.4, -0.4), vec2<f32>(1.0, -0.4));
        let bot_r = sd_seg(q, vec2<f32>(1.0, -0.4), vec2<f32>(3.4, 2.8));
        let bot_d = sd_seg(q, vec2<f32>(3.4, 2.8), vec2<f32>(1.0, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(-3.4, 6.0), vec2<f32>(1.0, 6.0));
        d = min(min(min(spine, min(top_b, top_r)), min(top_d, mid_b)), min(min(bot_r, bot_d), bot_b));
    }
    // 'C' (67u)
    else if (code == 67u) {
        let top_b = sd_seg(q, vec2<f32>(3.4, -3.6), vec2<f32>(1.2, -6.0));
        let top_c = sd_seg(q, vec2<f32>(1.2, -6.0), vec2<f32>(-1.2, -6.0));
        let spine = sd_seg(q, vec2<f32>(-1.2, -6.0), vec2<f32>(-3.4, -2.6));
        let mid_l = sd_seg(q, vec2<f32>(-3.4, -2.6), vec2<f32>(-3.4, 2.6));
        let bot_c = sd_seg(q, vec2<f32>(-3.4, 2.6), vec2<f32>(-1.2, 6.0));
        let bot_m = sd_seg(q, vec2<f32>(-1.2, 6.0), vec2<f32>(1.2, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(1.2, 6.0), vec2<f32>(3.4, 3.6));
        d = min(min(min(min(top_b, top_c), spine), min(mid_l, bot_c)), min(bot_m, bot_b));
    }
    // 'D' (68u)
    else if (code == 68u) {
        let spine = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(0.8, -6.0));
        let arc_t = sd_seg(q, vec2<f32>(0.8, -6.0), vec2<f32>(3.5, -2.6));
        let arc_m = sd_seg(q, vec2<f32>(3.5, -2.6), vec2<f32>(3.5, 2.6));
        let arc_b = sd_seg(q, vec2<f32>(3.5, 2.6), vec2<f32>(0.8, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(-3.4, 6.0), vec2<f32>(0.8, 6.0));
        d = min(min(min(spine, top_b), min(arc_t, arc_m)), min(arc_b, bot_b));
    }
    // 'E' (69u)
    else if (code == 69u) {
        let spine = sd_seg(q, vec2<f32>(-3.0, -6.0), vec2<f32>(-3.0, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.0, -6.0), vec2<f32>(3.2, -6.0));
        let mid_b = sd_seg(q, vec2<f32>(-3.0, 0.0), vec2<f32>(2.0, 0.0));
        let bot_b = sd_seg(q, vec2<f32>(-3.0, 6.0), vec2<f32>(3.2, 6.0));
        d = min(min(spine, top_b), min(mid_b, bot_b));
    }
    // 'F' (70u)
    else if (code == 70u) {
        let spine = sd_seg(q, vec2<f32>(-3.0, -6.0), vec2<f32>(-3.0, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.0, -6.0), vec2<f32>(3.2, -6.0));
        let mid_b = sd_seg(q, vec2<f32>(-3.0, 0.0), vec2<f32>(2.0, 0.0));
        d = min(min(spine, top_b), mid_b);
    }
    // 'G' (71u) - Space Grotesk open circular G with clean spur
    else if (code == 71u) {
        let t_tip = sd_seg(q, vec2<f32>(3.2, -3.6), vec2<f32>(1.4, -6.0));
        let t_bar = sd_seg(q, vec2<f32>(1.4, -6.0), vec2<f32>(-1.4, -6.0));
        let spine = sd_seg(q, vec2<f32>(-1.4, -6.0), vec2<f32>(-3.4, -2.6));
        let mid_l = sd_seg(q, vec2<f32>(-3.4, -2.6), vec2<f32>(-3.4, 2.6));
        let bot_c = sd_seg(q, vec2<f32>(-3.4, 2.6), vec2<f32>(-1.4, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(-1.4, 6.0), vec2<f32>(1.4, 6.0));
        let bot_r = sd_seg(q, vec2<f32>(1.4, 6.0), vec2<f32>(3.4, 3.6));
        let r_leg = sd_seg(q, vec2<f32>(3.4, 3.6), vec2<f32>(3.4, 0.2));
        let r_bar = sd_seg(q, vec2<f32>(0.6, 0.2), vec2<f32>(3.4, 0.2));
        d = min(min(min(min(t_tip, t_bar), min(spine, mid_l)), min(min(bot_c, bot_b), bot_r)), min(r_leg, r_bar));
    }
    // 'H' (72u)
    else if (code == 72u) {
        let leg_l = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let leg_r = sd_seg(q, vec2<f32>(3.4, -6.0), vec2<f32>(3.4, 6.0));
        let bar   = sd_seg(q, vec2<f32>(-3.4, 0.0), vec2<f32>(3.4, 0.0));
        d = min(min(leg_l, leg_r), bar);
    }
    // 'I' (73u) - Space Grotesk pure vertical stem, sans-serif
    else if (code == 73u) {
        d = sd_seg(q, vec2<f32>(0.0, -6.0), vec2<f32>(0.0, 6.0));
    }
    // 'K' (75u) - Space Grotesk clean branching diagonals
    else if (code == 75u) {
        let spine = sd_seg(q, vec2<f32>(-3.2, -6.0), vec2<f32>(-3.2, 6.0));
        let diag1 = sd_seg(q, vec2<f32>(-0.8, -0.6), vec2<f32>(3.4, -6.0));
        let diag2 = sd_seg(q, vec2<f32>(-0.6, -1.0), vec2<f32>(3.4, 6.0));
        d = min(min(spine, diag1), diag2);
    }
    // 'L' (76u)
    else if (code == 76u) {
        let spine = sd_seg(q, vec2<f32>(-2.8, -6.0), vec2<f32>(-2.8, 6.0));
        let foot  = sd_seg(q, vec2<f32>(-2.8, 6.0), vec2<f32>(2.8, 6.0));
        d = min(spine, foot);
    }
    // 'M' (77u) - Wide geometric vertices
    else if (code == 77u) {
        let leg_l = sd_seg(q, vec2<f32>(-4.2, 6.0), vec2<f32>(-4.2, -6.0));
        let diag1 = sd_seg(q, vec2<f32>(-4.2, -6.0), vec2<f32>(0.0, 1.8));
        let diag2 = sd_seg(q, vec2<f32>(0.0, 1.8), vec2<f32>(4.2, -6.0));
        let leg_r = sd_seg(q, vec2<f32>(4.2, -6.0), vec2<f32>(4.2, 6.0));
        d = min(min(leg_l, diag1), min(diag2, leg_r));
    }
    // 'N' (78u) - Sharp diagonal leg, strictly distinct from M
    else if (code == 78u) {
        let leg_l = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let diag  = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(3.4, 6.0));
        let leg_r = sd_seg(q, vec2<f32>(3.4, -6.0), vec2<f32>(3.4, 6.0));
        d = min(min(leg_l, diag), leg_r);
    }
    // 'O' (79u) - Space Grotesk wide rounded curve
    else if (code == 79u) {
        d = abs(sd_rounded_box(q, vec2<f32>(3.6, 5.8), 3.2));
    }
    // 'P' (80u)
    else if (code == 80u) {
        let spine = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(1.0, -6.0));
        let top_r = sd_seg(q, vec2<f32>(1.0, -6.0), vec2<f32>(3.4, -2.8));
        let top_d = sd_seg(q, vec2<f32>(3.4, -2.8), vec2<f32>(1.0, 0.4));
        let mid_b = sd_seg(q, vec2<f32>(-3.4, 0.4), vec2<f32>(1.0, 0.4));
        d = min(min(spine, min(top_b, top_r)), min(top_d, mid_b));
    }
    // 'R' (82u) - Space Grotesk clean leg branch
    else if (code == 82u) {
        let spine = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 6.0));
        let top_b = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(1.0, -6.0));
        let top_r = sd_seg(q, vec2<f32>(1.0, -6.0), vec2<f32>(3.4, -2.8));
        let top_d = sd_seg(q, vec2<f32>(3.4, -2.8), vec2<f32>(1.0, 0.4));
        let mid_b = sd_seg(q, vec2<f32>(-3.4, 0.4), vec2<f32>(1.0, 0.4));
        let leg   = sd_seg(q, vec2<f32>(0.5, 0.4), vec2<f32>(3.4, 6.0));
        d = min(min(min(spine, min(top_b, top_r)), min(top_d, mid_b)), leg);
    }
    // 'S' (83u) - Space Grotesk balanced geometric curves (tidak patah-patah)
    else if (code == 83u) {
        let t_top = sd_seg(q, vec2<f32>(3.2, -4.6), vec2<f32>(1.6, -6.0));
        let t_bar = sd_seg(q, vec2<f32>(1.6, -6.0), vec2<f32>(-1.4, -6.0));
        let t_arc = sd_seg(q, vec2<f32>(-1.4, -6.0), vec2<f32>(-3.4, -3.6));
        let t_in  = sd_seg(q, vec2<f32>(-3.4, -3.6), vec2<f32>(-1.4, -1.0));
        let diag  = sd_seg(q, vec2<f32>(-1.4, -1.0), vec2<f32>(1.4, 1.0));
        let b_in  = sd_seg(q, vec2<f32>(1.4, 1.0), vec2<f32>(3.4, 3.6));
        let b_arc = sd_seg(q, vec2<f32>(3.4, 3.6), vec2<f32>(1.4, 6.0));
        let b_bar = sd_seg(q, vec2<f32>(1.4, 6.0), vec2<f32>(-1.6, 6.0));
        let b_bot = sd_seg(q, vec2<f32>(-1.6, 6.0), vec2<f32>(-3.2, 4.6));
        d = min(min(min(min(t_top, t_bar), min(t_arc, t_in)), diag), min(min(b_in, b_arc), min(b_bar, b_bot)));
    }
    // 'T' (84u)
    else if (code == 84u) {
        let bar  = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(3.4, -6.0));
        let stem = sd_seg(q, vec2<f32>(0.0, -6.0), vec2<f32>(0.0, 6.0));
        d = min(bar, stem);
    }
    // 'U' (85u)
    else if (code == 85u) {
        let leg_l = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, 2.5));
        let arc_l = sd_seg(q, vec2<f32>(-3.4, 2.5), vec2<f32>(-1.0, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(-1.0, 6.0), vec2<f32>(1.0, 6.0));
        let arc_r = sd_seg(q, vec2<f32>(1.0, 6.0), vec2<f32>(3.4, 2.5));
        let leg_r = sd_seg(q, vec2<f32>(3.4, 2.5), vec2<f32>(3.4, -6.0));
        d = min(min(leg_l, leg_r), min(min(arc_l, arc_r), bot_b));
    }
    // 'V' (86u)
    else if (code == 86u) {
        let leg_l = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(0.0, 6.0));
        let leg_r = sd_seg(q, vec2<f32>(0.0, 6.0), vec2<f32>(3.4, -6.0));
        d = min(leg_l, leg_r);
    }
    // 'W' (87u)
    else if (code == 87u) {
        let s1 = sd_seg(q, vec2<f32>(-4.6, -6.0), vec2<f32>(-2.4, 6.0));
        let s2 = sd_seg(q, vec2<f32>(-2.4, 6.0), vec2<f32>(0.0, -1.0));
        let s3 = sd_seg(q, vec2<f32>(0.0, -1.0), vec2<f32>(2.4, 6.0));
        let s4 = sd_seg(q, vec2<f32>(2.4, 6.0), vec2<f32>(4.6, -6.0));
        d = min(min(s1, s2), min(s3, s4));
    }
    // Digits: '0'..'9' (48u..57u)
    else if (code == 48u) {
        d = abs(sd_rounded_box(q, vec2<f32>(3.4, 5.6), 2.8));
    }
    else if (code == 49u) {
        let stem = sd_seg(q, vec2<f32>(0.0, -6.0), vec2<f32>(0.0, 6.0));
        let flag = sd_seg(q, vec2<f32>(-2.4, -3.2), vec2<f32>(0.0, -6.0));
        let foot = sd_seg(q, vec2<f32>(-2.6, 6.0), vec2<f32>(2.6, 6.0));
        d = min(stem, min(flag, foot));
    }
    else if (code == 50u) {
        let arc_t = sd_seg(q, vec2<f32>(-3.0, -4.2), vec2<f32>(0.0, -6.0));
        let arc_r = sd_seg(q, vec2<f32>(0.0, -6.0), vec2<f32>(3.4, -3.2));
        let diag  = sd_seg(q, vec2<f32>(3.4, -3.2), vec2<f32>(-3.4, 6.0));
        let base  = sd_seg(q, vec2<f32>(-3.4, 6.0), vec2<f32>(3.6, 6.0));
        d = min(min(arc_t, arc_r), min(diag, base));
    }
    else if (code == 51u) {
        let top_b = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(3.4, -6.0));
        let diag  = sd_seg(q, vec2<f32>(3.4, -6.0), vec2<f32>(0.6, -0.6));
        let mid_b = sd_seg(q, vec2<f32>(0.6, -0.6), vec2<f32>(3.4, 2.6));
        let bot_c = sd_seg(q, vec2<f32>(3.4, 2.6), vec2<f32>(0.0, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(0.0, 6.0), vec2<f32>(-3.2, 4.6));
        d = min(min(top_b, diag), min(mid_b, min(bot_c, bot_b)));
    }
    else if (code == 52u) {
        let stem = sd_seg(q, vec2<f32>(1.8, -6.0), vec2<f32>(1.8, 6.0));
        let diag = sd_seg(q, vec2<f32>(1.8, -6.0), vec2<f32>(-3.6, 1.6));
        let bar  = sd_seg(q, vec2<f32>(-3.6, 1.6), vec2<f32>(3.6, 1.6));
        d = min(stem, min(diag, bar));
    }
    else if (code == 53u) {
        let top_b = sd_seg(q, vec2<f32>(3.4, -6.0), vec2<f32>(-3.4, -6.0));
        let stem  = sd_seg(q, vec2<f32>(-3.4, -6.0), vec2<f32>(-3.4, -0.6));
        let arc_t = sd_seg(q, vec2<f32>(-3.4, -0.6), vec2<f32>(3.4, 1.4));
        let arc_r = sd_seg(q, vec2<f32>(3.4, 1.4), vec2<f32>(1.2, 6.0));
        let bot_b = sd_seg(q, vec2<f32>(1.2, 6.0), vec2<f32>(-3.2, 4.8));
        d = min(min(top_b, stem), min(arc_t, min(arc_r, bot_b)));
    }
    else if (code == 54u) {
        let lp = abs(sd_rounded_box(q - vec2<f32>(0.0, 1.8), vec2<f32>(3.4, 3.8), 2.2));
        let stem = sd_seg(q, vec2<f32>(-3.4, 1.8), vec2<f32>(1.4, -6.0));
        d = min(lp, stem);
    }
    else if (code == 55u) {
        let bar  = sd_seg(q, vec2<f32>(-3.6, -6.0), vec2<f32>(3.6, -6.0));
        let diag = sd_seg(q, vec2<f32>(3.6, -6.0), vec2<f32>(-1.2, 6.0));
        d = min(bar, diag);
    }
    else if (code == 56u) {
        let loop_t = abs(sd_rounded_box(q - vec2<f32>(0.0, -2.6), vec2<f32>(3.0, 2.8), 1.6));
        let loop_b = abs(sd_rounded_box(q - vec2<f32>(0.0, 2.8), vec2<f32>(3.4, 2.8), 1.6));
        d = min(loop_t, loop_b);
    }
    else if (code == 57u) {
        let lp = abs(sd_rounded_box(q - vec2<f32>(0.0, -1.8), vec2<f32>(3.4, 3.8), 2.2));
        let stem = sd_seg(q, vec2<f32>(3.4, -1.8), vec2<f32>(-1.4, 6.0));
        d = min(lp, stem);
    }

    return d;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACE GROTESK PROPORTIONAL ADVANCE METRICS & OPTICAL KERNING
// ─────────────────────────────────────────────────────────────────────────────
fn char_advance(code: u32) -> f32 {
    if (code == 73u) { return 3.4; }                     // 'I' (clean stem, narrow advance)
    if (code == 76u) { return 6.2; }                     // 'L'
    if (code == 69u || code == 70u) { return 6.4; }       // 'E', 'F'
    if (code == 83u) { return 6.8; }                     // 'S'
    if (code == 66u || code == 80u || code == 82u || code == 84u) { return 7.0; } // 'B', 'P', 'R', 'T'
    if (code == 67u || code == 68u || code == 71u || code == 75u || code == 78u || code == 79u || code == 85u || code == 86u) { return 7.4; } // 'C', 'D', 'G', 'K', 'N', 'O', 'U', 'V'
    if (code == 65u) { return 7.6; }                     // 'A'
    if (code == 77u) { return 9.4; }                     // 'M'
    if (code == 87u) { return 10.2; }                    // 'W'
    if (code >= 48u && code <= 57u) { return 7.2; }       // '0'..'9'
    return 7.0;
}

fn draw_vector_char(p: vec2<f32>, center: vec2<f32>, scale: f32, code: u32) -> f32 {
    let q = (p - center) / max(scale, 0.05);
    let d = sd_vector_char(q, code);
    let d_px = d * scale;
    // Solid, sharp Space Grotesk stroke weight with smooth anti-aliased edge
    let stroke_r = max(1.02 * scale, 0.80);
    return 1.0 - smoothstep(stroke_r - 0.70, stroke_r + 0.70, d_px);
}

fn draw_vword2(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let tot = (w0 + w1 + trk) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    return max(a0, a1);
}

fn draw_vword3(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let tot = (w0 + w1 + w2 + trk * 2.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    return max(max(a0, a1), a2);
}

fn draw_vword4(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let tot = (w0 + w1 + w2 + w3 + trk * 3.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, center.y), scale, c3);
    return max(max(a0, a1), max(a2, a3));
}

fn draw_vword5(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let tot = (w0 + w1 + w2 + w3 + w4 + trk * 4.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, center.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, center.y), scale, c4);
    return max(max(max(a0, a1), max(a2, a3)), a4);
}

fn draw_vword6(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32, c5: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let w5 = char_advance(c5);
    let tot = (w0 + w1 + w2 + w3 + w4 + w5 + trk * 5.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let x5 = x4 + (w4 * 0.5 + trk + w5 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, center.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, center.y), scale, c4);
    let a5 = draw_vector_char(p, vec2<f32>(x5, center.y), scale, c5);
    return max(max(max(a0, a1), max(a2, a3)), max(a4, a5));
}

fn draw_vword7(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32, c5: u32, c6: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let w5 = char_advance(c5);
    let w6 = char_advance(c6);
    let tot = (w0 + w1 + w2 + w3 + w4 + w5 + w6 + trk * 6.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let x5 = x4 + (w4 * 0.5 + trk + w5 * 0.5) * scale;
    let x6 = x5 + (w5 * 0.5 + trk + w6 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, center.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, center.y), scale, c4);
    let a5 = draw_vector_char(p, vec2<f32>(x5, center.y), scale, c5);
    let a6 = draw_vector_char(p, vec2<f32>(x6, center.y), scale, c6);
    return max(max(max(max(a0, a1), max(a2, a3)), max(a4, a5)), a6);
}

fn draw_vword8(p: vec2<f32>, center: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32, c5: u32, c6: u32, c7: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let w5 = char_advance(c5);
    let w6 = char_advance(c6);
    let w7 = char_advance(c7);
    let tot = (w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7 + trk * 7.0) * scale;
    let x0 = center.x - tot * 0.5 + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let x5 = x4 + (w4 * 0.5 + trk + w5 * 0.5) * scale;
    let x6 = x5 + (w5 * 0.5 + trk + w6 * 0.5) * scale;
    let x7 = x6 + (w6 * 0.5 + trk + w7 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, center.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, center.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, center.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, center.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, center.y), scale, c4);
    let a5 = draw_vector_char(p, vec2<f32>(x5, center.y), scale, c5);
    let a6 = draw_vector_char(p, vec2<f32>(x6, center.y), scale, c6);
    let a7 = draw_vector_char(p, vec2<f32>(x7, center.y), scale, c7);
    return max(max(max(max(a0, a1), max(a2, a3)), max(a4, a5)), max(a6, a7));
}

// Left-aligned string rendering (pos_left is starting baseline x, center y)
fn draw_vword_left2(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    return max(a0, a1);
}

fn draw_vword_left3(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, pos_left.y), scale, c2);
    return max(max(a0, a1), a2);
}

fn draw_vword_left4(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, pos_left.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, pos_left.y), scale, c3);
    return max(max(a0, a1), max(a2, a3));
}

fn draw_vword_left5(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, pos_left.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, pos_left.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, pos_left.y), scale, c4);
    return max(max(max(a0, a1), max(a2, a3)), a4);
}

fn draw_vword_left6(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32, c5: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let w5 = char_advance(c5);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let x5 = x4 + (w4 * 0.5 + trk + w5 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, pos_left.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, pos_left.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, pos_left.y), scale, c4);
    let a5 = draw_vector_char(p, vec2<f32>(x5, pos_left.y), scale, c5);
    return max(max(max(a0, a1), max(a2, a3)), max(a4, a5));
}

fn draw_vword_left7(p: vec2<f32>, pos_left: vec2<f32>, scale: f32, c0: u32, c1: u32, c2: u32, c3: u32, c4: u32, c5: u32, c6: u32) -> f32 {
    let trk = 1.0;
    let w0 = char_advance(c0);
    let w1 = char_advance(c1);
    let w2 = char_advance(c2);
    let w3 = char_advance(c3);
    let w4 = char_advance(c4);
    let w5 = char_advance(c5);
    let w6 = char_advance(c6);
    let x0 = pos_left.x + w0 * 0.5 * scale;
    let x1 = x0 + (w0 * 0.5 + trk + w1 * 0.5) * scale;
    let x2 = x1 + (w1 * 0.5 + trk + w2 * 0.5) * scale;
    let x3 = x2 + (w2 * 0.5 + trk + w3 * 0.5) * scale;
    let x4 = x3 + (w3 * 0.5 + trk + w4 * 0.5) * scale;
    let x5 = x4 + (w4 * 0.5 + trk + w5 * 0.5) * scale;
    let x6 = x5 + (w5 * 0.5 + trk + w6 * 0.5) * scale;
    let a0 = draw_vector_char(p, vec2<f32>(x0, pos_left.y), scale, c0);
    let a1 = draw_vector_char(p, vec2<f32>(x1, pos_left.y), scale, c1);
    let a2 = draw_vector_char(p, vec2<f32>(x2, pos_left.y), scale, c2);
    let a3 = draw_vector_char(p, vec2<f32>(x3, pos_left.y), scale, c3);
    let a4 = draw_vector_char(p, vec2<f32>(x4, pos_left.y), scale, c4);
    let a5 = draw_vector_char(p, vec2<f32>(x5, pos_left.y), scale, c5);
    let a6 = draw_vector_char(p, vec2<f32>(x6, pos_left.y), scale, c6);
    return max(max(max(max(a0, a1), max(a2, a3)), max(a4, a5)), a6);
}

fn draw_num_u32(p: vec2<f32>, center: vec2<f32>, scale: f32, val_in: u32) -> f32 {
    let val = min(val_in, 100u);
    if (val >= 100u) {
        return draw_vword3(p, center, scale * 0.45, 49u, 48u, 48u); // 100
    }
    if (val >= 10u) {
        let d0 = 48u + (val / 10u);
        let d1 = 48u + (val % 10u);
        return draw_vword2(p, center, scale * 0.45, d0, d1);
    }
    return draw_vector_char(p, center, scale * 0.45, 48u + val);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2D SDF VECTOR ICONS (Windows Quick Settings: Wi-Fi, BT, Airplane, Power, Audio)
// ─────────────────────────────────────────────────────────────────────────────
fn icon_wifi_sdf(p: vec2<f32>, c: vec2<f32>, s: f32, level: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let org = vec2<f32>(0.0, 5.5);
    let d = length(q - org);
    let dot_a = 1.0 - smoothstep(1.3, 2.1, d);
    let ang = abs(q.x - org.x) - (org.y - q.y) * 1.15;
    let cone = (1.0 - smoothstep(0.0, 1.2, ang)) * step(q.y, org.y - 1.0);
    let a1 = (1.0 - smoothstep(0.6, 1.4, abs(d - 5.5))) * cone * select(0.25, 1.0, level > 0.15);
    let a2 = (1.0 - smoothstep(0.6, 1.4, abs(d - 9.2))) * cone * select(0.25, 1.0, level > 0.45);
    let a3 = (1.0 - smoothstep(0.6, 1.4, abs(d - 12.8))) * cone * select(0.25, 1.0, level > 0.72);
    return max(max(dot_a, a1), max(a2, a3));
}

fn icon_bluetooth_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let s1 = sd_seg(q, vec2<f32>(0.0, -7.5), vec2<f32>(0.0, 7.5));
    let s2 = sd_seg(q, vec2<f32>(0.0, -7.5), vec2<f32>(4.8, -3.5));
    let s3 = sd_seg(q, vec2<f32>(4.8, -3.5), vec2<f32>(-4.2, 3.5));
    let s4 = sd_seg(q, vec2<f32>(0.0, 7.5), vec2<f32>(4.8, 3.5));
    let s5 = sd_seg(q, vec2<f32>(4.8, 3.5), vec2<f32>(-4.2, -3.5));
    let d = min(min(min(s1, s2), min(s3, s4)), s5);
    return 1.0 - smoothstep(0.75, 1.55, d);
}

fn icon_airplane_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    // Fuselage vertikal
    let body = sd_seg(q, vec2<f32>(0.0, -7.5), vec2<f32>(0.0, 6.8)) - 1.1;
    // Sayap utama menyapu ke belakang
    let wing_l = sd_seg(q, vec2<f32>(0.0, -2.0), vec2<f32>(-7.8, 2.2)) - 1.05;
    let wing_r = sd_seg(q, vec2<f32>(0.0, -2.0), vec2<f32>(7.8, 2.2)) - 1.05;
    // Ekor
    let tail = sd_seg(q, vec2<f32>(-3.4, 6.2), vec2<f32>(3.4, 6.2)) - 0.85;
    let d = min(min(body, tail), min(wing_l, wing_r));
    return 1.0 - smoothstep(0.0, 1.0, d);
}

fn icon_hotspot_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let d = length(q);
    let dot_a = 1.0 - smoothstep(1.4, 2.2, d);
    let side_cone = smoothstep(0.35, 0.65, abs(q.x) / max(d, 0.001));
    let r1 = (1.0 - smoothstep(0.65, 1.4, abs(d - 5.2))) * side_cone;
    let r2 = (1.0 - smoothstep(0.65, 1.4, abs(d - 8.8))) * side_cone;
    return max(dot_a, max(r1, r2));
}

fn icon_moon_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let d_out = length(q) - 5.6;
    let d_cut = length(q - vec2<f32>(2.7, -1.8)) - 4.8;
    let d = max(d_out, -d_cut);
    return 1.0 - smoothstep(-0.3, 0.9, d);
}

fn icon_gear_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q);
    let ang = atan2(q.y, q.x);
    let teeth = cos(ang * 6.0) * 1.1;
    let ring = abs(r - (4.6 + teeth * 0.45)) - 1.15;
    let hole = 2.0 - r;
    let d = max(ring, hole);
    return 1.0 - smoothstep(-0.2, 0.85, d);
}

fn icon_leaf_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let d_stem = sd_seg(q, vec2<f32>(-4.5, 4.5), vec2<f32>(4.5, -4.5));
    let d_c1 = length(q - vec2<f32>(-1.5, -1.5)) - 5.2;
    let d_c2 = length(q - vec2<f32>(1.5, 1.5)) - 5.2;
    let leaf = abs(max(d_c1, d_c2)) - 0.7;
    let d = min(leaf, d_stem - 0.55);
    return 1.0 - smoothstep(0.0, 1.0, d);
}

fn icon_gauge_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q - vec2<f32>(0.0, 2.0));
    let arc_mask = step(q.y, 3.0);
    let arc = (1.0 - smoothstep(0.6, 1.4, abs(r - 6.0))) * arc_mask;
    let needle = 1.0 - smoothstep(0.55, 1.3, sd_seg(q, vec2<f32>(0.0, 2.0), vec2<f32>(3.8, -2.5)));
    let hub = 1.0 - smoothstep(1.1, 1.9, r);
    return max(arc, max(needle, hub));
}

fn icon_flame_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    // Petir tajam performa tinggi
    let s1 = sd_seg(q, vec2<f32>(1.5, -6.8), vec2<f32>(-3.6, 0.4));
    let s2 = sd_seg(q, vec2<f32>(-3.6, 0.4), vec2<f32>(2.4, 0.4));
    let s3 = sd_seg(q, vec2<f32>(2.4, 0.4), vec2<f32>(-1.8, 6.8));
    let d = min(min(s1, s2), s3);
    return 1.0 - smoothstep(0.75, 1.6, d);
}

fn icon_sun_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q);
    let core = 1.0 - smoothstep(2.6, 3.4, r);
    let ang = atan2(q.y, q.x);
    let ray_ang = abs(sin(ang * 4.0));
    let ray_r = step(4.6, r) * (1.0 - smoothstep(6.8, 7.6, r));
    let rays = (1.0 - smoothstep(0.18, 0.36, ray_ang)) * ray_r;
    return max(core, rays);
}

fn icon_speaker_sdf(p: vec2<f32>, c: vec2<f32>, s: f32, muted: bool) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let box_d = sd_rounded_box(q - vec2<f32>(-4.2, 0.0), vec2<f32>(2.1, 3.1), 0.6);
    let box_a = 1.0 - smoothstep(0.0, 0.9, box_d);
    var horn_a = 0.0;
    if (q.x >= -3.2 && q.x <= 2.2) {
        let max_y = (q.x + 3.2) * 0.85 + 2.8;
        horn_a = 1.0 - smoothstep(0.0, 0.9, abs(q.y) - max_y);
    }
    var extra = 0.0;
    if (!muted) {
        let wd = abs(length(q - vec2<f32>(-0.8, 0.0)) - 6.8);
        let wc = smoothstep(5.4, 3.8, abs(q.y)) * step(q.x, 6.8) * step(2.6, q.x);
        extra = (1.0 - smoothstep(0.6, 1.4, wd)) * wc;
    } else {
        let sl = sd_seg(q, vec2<f32>(3.2, -3.5), vec2<f32>(7.8, 3.5));
        let sl2 = sd_seg(q, vec2<f32>(7.8, -3.5), vec2<f32>(3.2, 3.5));
        extra = 1.0 - smoothstep(0.65, 1.4, min(sl, sl2));
    }
    return max(max(box_a, horn_a), extra);
}

fn icon_headphones_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q - vec2<f32>(0.0, 1.0));
    let band = (1.0 - smoothstep(0.65, 1.4, abs(r - 6.2))) * step(q.y, 1.5);
    let cup_l = 1.0 - smoothstep(0.0, 0.9, sd_rounded_box(q - vec2<f32>(-5.8, 2.8), vec2<f32>(1.7, 3.0), 0.9));
    let cup_r = 1.0 - smoothstep(0.0, 0.9, sd_rounded_box(q - vec2<f32>(5.8, 2.8), vec2<f32>(1.7, 3.0), 0.9));
    return max(band, max(cup_l, cup_r));
}

fn icon_monitor_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let frame = 1.0 - smoothstep(0.55, 1.35, abs(sd_rounded_box(q - vec2<f32>(0.0, -1.2), vec2<f32>(6.4, 4.2), 1.0)));
    let stand = 1.0 - smoothstep(0.6, 1.3, sd_seg(q, vec2<f32>(0.0, 3.2), vec2<f32>(0.0, 5.8)));
    let base = 1.0 - smoothstep(0.6, 1.3, sd_seg(q, vec2<f32>(-3.2, 5.8), vec2<f32>(3.2, 5.8)));
    return max(frame, max(stand, base));
}

fn icon_mic_sdf(p: vec2<f32>, c: vec2<f32>, s: f32, muted: bool) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let cap = 1.0 - smoothstep(0.0, 0.9, sd_rounded_box(q - vec2<f32>(0.0, -2.0), vec2<f32>(2.1, 3.6), 1.8));
    let cradle = (1.0 - smoothstep(0.55, 1.3, abs(length(q - vec2<f32>(0.0, -0.5)) - 4.4))) * step(-0.5, q.y);
    let stem = 1.0 - smoothstep(0.55, 1.25, sd_seg(q, vec2<f32>(0.0, 4.0), vec2<f32>(0.0, 6.4)));
    let foot = 1.0 - smoothstep(0.55, 1.25, sd_seg(q, vec2<f32>(-2.8, 6.4), vec2<f32>(2.8, 6.4)));
    var a = max(max(cap, cradle), max(stem, foot));
    if (muted) {
        let sl = 1.0 - smoothstep(0.65, 1.4, sd_seg(q, vec2<f32>(-5.5, -5.5), vec2<f32>(5.5, 5.5)));
        a = max(a, sl);
    }
    return a;
}

fn icon_spatial_sdf(p: vec2<f32>, c: vec2<f32>, s: f32) -> f32 {
    let q = (p - c) / max(s, 0.05);
    let r = length(q);
    let dot_a = 1.0 - smoothstep(1.2, 2.0, r);
    let r1 = 1.0 - smoothstep(0.55, 1.3, abs(r - 4.2));
    let r2 = 1.0 - smoothstep(0.55, 1.3, abs(r - 6.8));
    return max(dot_a, max(r1 * 0.85, r2 * 0.65));
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE LUXURY KANAGAWA LACQUER TILE / CARD (Obsidian Glass + Wave Sheen + Kintsugi Gold)
// ─────────────────────────────────────────────────────────────────────────────
struct TileDrawRes {
    col: vec3<f32>,
    alpha: f32,
    hover: f32,
    eff_center: vec2<f32>,
};

fn icon_eye_sdf(p: vec2<f32>, c: vec2<f32>, s: f32, slashed: bool) -> f32 {
    let q = (p - c) / s;
    let top_arc = abs(length(q - vec2<f32>(0.0, 5.2)) - 7.8);
    let bot_arc = abs(length(q - vec2<f32>(0.0, -5.2)) - 7.8);
    let mask_x = step(abs(q.x), 5.6);
    var d = min(top_arc, bot_arc) + (1.0 - mask_x) * 10.0;
    let pupil = length(q) - 1.75;
    d = min(d, abs(pupil));
    if (slashed) {
        let slash = sd_seg(q, vec2<f32>(-4.8, 3.8), vec2<f32>(4.8, -3.8)) - 0.55;
        d = min(d, slash);
    }
    return 1.0 - smoothstep(0.35, 1.05, d);
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED TASKBAR-STYLE KANAGAWA SUMI-INK & FROSTED MICA TILE
// Identik dengan `draw_widget_pill`: flat frosted mica, organic sumi ink wash,
// gentle lift + magnification hover, dynamic lantern spotlight, & gold flakes!
// ─────────────────────────────────────────────────────────────────────────────
fn draw_fly_tile(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    half_sz: vec2<f32>,
    radius: f32,
    is_active: f32,
    accent: vec3<f32>,
    reveal: f32,
    halo_gain: f32,
    in_col: vec3<f32>,
    in_alpha: f32,
) -> TileDrawRes {
    var col = in_col;
    var alpha = in_alpha;

    // 1. Taskbar-matched smooth proximity hover + gentle liquid lift & magnification
    let d_m = sd_rounded_box(mouse_pos - center, half_sz, radius);
    let hover_raw = clamp(1.0 - max(d_m, 0.0) / 14.0, 0.0, 1.0);
    let smooth_hover = hover_raw * hover_raw * (3.0 - 2.0 * hover_raw) * reveal;

    // Gentle lift (-2.0px) & subtle scale (+1.8% width, +3.5% height) so cards feel alive like taskbar pills
    let eff_half = half_sz * vec2<f32>(1.0 + 0.018 * smooth_hover, 1.0 + 0.035 * smooth_hover);
    let eff_center = center - vec2<f32>(0.0, 2.0 * smooth_hover);
    let eff_r = radius * (1.0 + 0.03 * smooth_hover);

    let d = sd_rounded_box(p - eff_center, eff_half, eff_r);

    // 2. Dynamic Drop Shadow (deepens and drops lower as the card lifts, matching taskbar)
    let shadow_pos = eff_center + vec2<f32>(0.0, 2.4 + 2.2 * smooth_hover);
    let shadow_d = sd_rounded_box(p - shadow_pos, eff_half + vec2<f32>(1.0, 1.0), eff_r + 1.5);
    let shadow_a = (1.0 - smoothstep(-2.5, 5.5 + 3.0 * smooth_hover, shadow_d)) * (0.36 + 0.20 * smooth_hover + 0.24 * halo_gain) * reveal;
    if (shadow_a > 0.001) {
        col = mix(col, hex(9.0, 10.0, 15.0), shadow_a * (1.0 - alpha * 0.35));
        alpha = max(alpha, shadow_a);
    }

    let mask = (1.0 - smoothstep(-0.75, 0.75, d)) * reveal;
    if (mask > 0.001) {
        // 3. Flat Frosted Sumi-Mica Base (NO heavy 3D emboss!)
        let glass_noise = fbm(p * 0.065 + vec2<f32>(u.time * 0.04, -u.time * 0.025));
        let ink_flow = fbm(p * 0.038 + vec2<f32>(-u.time * 0.06, u.time * 0.05));
        let mica_tint = mix(hex(22.0, 24.0, 34.0), hex(32.0, 36.0, 50.0), glass_noise * 0.65);
        var glass_body = mix(hex(26.0, 28.0, 39.0), mica_tint, 0.72);

        // 4. Organic Kanagawa Sumi-e Ink Wash when active (Prussian indigo + ink bleed, flat & atmospheric)
        if (is_active > 0.01) {
            let sumi_deep = hex(18.0, 26.0, 40.0);
            let prussian_wash = mix(hex(26.0, 48.0, 70.0), accent, 0.24);
            let ink_bleed = smoothstep(0.22, 0.82, ink_flow);
            var active_ink = mix(sumi_deep, prussian_wash, ink_bleed * 0.85);
            // Subtle paper-grain ink texture
            let grain = hash21(floor(p * 0.65)) * 0.04;
            active_ink = active_ink + vec3<f32>(grain * 0.4, grain * 0.5, grain * 0.7);
            glass_body = mix(glass_body, active_ink, is_active * 0.90);
        }

        // 5. Dynamic Lantern Spotlight following cursor inside card (identical to taskbar pill!)
        let light_focus = clamp(
            mouse_pos,
            eff_center - eff_half + vec2<f32>(12.0, 10.0),
            eff_center + eff_half - vec2<f32>(12.0, 10.0)
        );
        let d_focus = length(p - light_focus);
        let aura_radius = max(eff_half.y * 2.1, 56.0);
        let aura_mask = (1.0 - smoothstep(0.0, aura_radius, d_focus)) * smooth_hover;

        // Soft warm golden lantern mist
        let subtle_mist = mix(glass_body, hex(225.0, 175.0, 95.0), aura_mask * 0.18);
        glass_body = mix(glass_body, subtle_mist, 0.55);

        // Micro Gold Flakes twinkling inside the glass under cursor (or faintly in active ink)
        let flake_grid = (p - eff_center - vec2<f32>(u.time * 2.2, sin(p.x * 0.14 + u.time * 1.1) * 1.6)) / 3.4;
        let r_flake = hash21(floor(flake_grid));
        let cell_flake = fract(flake_grid) - vec2<f32>(0.5, 0.5);
        let dist_flake = length(cell_flake) * 3.4;
        let twinkle = 0.5 + 0.5 * sin(u.time * 4.0 + r_flake * 12.56);
        let flake_on = step(0.89, r_flake) * (1.0 - smoothstep(0.2, 1.0, dist_flake)) * twinkle;
        let gold_spark = mix(hex(255.0, 215.0, 125.0), hex(255.0, 245.0, 195.0), r_flake);
        let flake_vis = max(aura_mask * 0.88, is_active * 0.22 * smoothstep(0.55, 0.95, ink_flow));
        glass_body = mix(glass_body, gold_spark, flake_on * flake_vis);

        // 6. Subtle 1px Glass Inner Edge (matching taskbar draw_widget_pill, NO heavy bevel)
        let inner_border_dist = abs(d + 0.75);
        let inner_border_mask = 1.0 - smoothstep(0.0, 0.85, inner_border_dist);
        let top_specular = smoothstep(eff_center.y + 4.0, eff_center.y - eff_half.y, p.y);
        let inner_border_alpha = (0.08 + 0.12 * top_specular + 0.12 * smooth_hover) * inner_border_mask;
        glass_body = mix(glass_body, vec3<f32>(1.0, 1.0, 1.0), inner_border_alpha);

        // 7. Signature Taskbar Two-Tone Kanagawa Rim (Prussian blue bottom -> Kintsugi gold top, flares on hover)
        let rim = smoothstep(1.6, 0.0, abs(d));
        let rim_gold = mix(hex(230.0, 195.0, 132.0), hex(255.0, 240.0, 175.0), smooth_hover * 0.85);
        let rim_blue = mix(hex(110.0, 152.0, 178.0), accent, is_active * 0.55);
        let rim_grad = smoothstep(eff_center.y + 8.0, eff_center.y - 10.0, p.y);
        let rim_tint = mix(rim_blue, rim_gold, rim_grad);
        let rim_strength = mix(0.46, 0.78, max(is_active * 0.65, smooth_hover));

        col = mix(col, glass_body, mask * 0.86);
        col = mix(col, rim_tint, rim * rim_strength * mask);
        alpha = max(alpha, mask * 0.94);
    }

    return TileDrawRes(col, alpha, smooth_hover, eff_center);
}

// ─────────────────────────────────────────────────────────────────────────────
// FLAT-LUMINOUS KANAGAWA SUMI-INK TOGGLE SWITCH (54x26 px, ZERO EMBOSS)
// Menyatu sempurna dengan bahasa kaca mica & tinta sumi taskbar
// ─────────────────────────────────────────────────────────────────────────────
fn draw_kanagawa_toggle(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    t_on: f32,
    time: f32,
    reveal: f32,
    in_col: vec3<f32>,
    in_alpha: f32,
) -> FlyoutRenderResult {
    var col = in_col;
    var alpha = in_alpha;

    let gold = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 242.0, 185.0);
    let rim_blue = hex(127.0, 180.0, 202.0);

    let half_sz = vec2<f32>(27.0, 13.0) * pop;
    let rad = 13.0 * pop;
    let d_m = sd_rounded_box(mouse_pos - center, half_sz, rad);
    let hover = (1.0 - smoothstep(-1.0, 10.0, d_m)) * reveal;

    // Gentle lift matching taskbar pills on hover
    let eff_c = center - vec2<f32>(0.0, 1.4 * hover);
    let d_tr = sd_rounded_box(p - eff_c, half_sz, rad);

    let tr_mask = (1.0 - smoothstep(-0.7, 0.7, d_tr)) * reveal;
    if (tr_mask > 0.001) {
        // Organic Sumi-e ink wash inside the track (no 3D emboss, no heavy bevel)
        let ink_n = fbm(p * 0.09 + vec2<f32>(-time * 0.16, time * 0.06));
        let off_col = mix(hex(20.0, 22.0, 32.0), hex(28.0, 31.0, 44.0), ink_n * 0.6);
        let on_col = mix(hex(24.0, 52.0, 76.0), hex(48.0, 96.0, 124.0), smoothstep(0.2, 0.85, ink_n));
        var track_col = mix(off_col, on_col, t_on);

        // Delicate gold dust micro-flakes drifting inside when ON or hovered
        let fg = (p - eff_c - vec2<f32>(time * 2.4, 0.0)) / 3.0;
        let rf = hash21(floor(fg));
        let df = length(fract(fg) - vec2<f32>(0.5, 0.5)) * 3.0;
        let tw = 0.5 + 0.5 * sin(time * 3.8 + rf * 12.56);
        let flake = step(0.88, rf) * (1.0 - smoothstep(0.2, 1.0, df)) * tw;
        track_col = mix(track_col, gold_hi, flake * (0.65 * t_on + 0.45 * hover));

        // Subtle taskbar-style two-tone rim (blue bottom -> gold top)
        let rim = smoothstep(1.5, 0.0, abs(d_tr));
        let rim_grad = smoothstep(eff_c.y + 6.0 * pop, eff_c.y - 6.0 * pop, p.y);
        let rim_col = mix(rim_blue, mix(gold, gold_hi, hover), rim_grad);
        track_col = mix(track_col, rim_col, rim * (0.48 + 0.42 * max(t_on, hover)));

        col = mix(col, track_col, tr_mask * 0.90);
        alpha = max(alpha, tr_mask * 0.95);
    }

    // Flat-luminous Ivory-Gold Thumb Disc (ZERO 3D metallic ball emboss!)
    let knob_x = mix(-13.5, 13.5, t_on) * pop;
    let knob_c = eff_c + vec2<f32>(knob_x, 0.0);
    let knob_r = (8.8 + 0.6 * hover) * pop;

    // Soft warm glow halo behind disc when ON
    let glow_d = length(p - knob_c) - knob_r;
    let glow_a = (1.0 - smoothstep(0.0, 6.5 * pop, glow_d)) * (0.35 * t_on + 0.15 * hover) * tr_mask;
    col = mix(col, gold, glow_a);

    let knob_a = (1.0 - smoothstep(-0.65, 0.65, glow_d)) * reveal;
    if (knob_a > 0.001) {
        let k_off = hex(175.0, 182.0, 200.0);
        let k_on = hex(250.0, 236.0, 196.0);
        var kcol = mix(k_off, k_on, t_on);
        // Subtle crisp gold hairline edge
        let krim = smoothstep(1.1, 0.0, abs(glow_d));
        kcol = mix(kcol, gold_hi, krim * (0.35 + 0.45 * t_on));
        col = mix(col, kcol, knob_a);
        alpha = max(alpha, knob_a);
    }

    return FlyoutRenderResult(col, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// KANAGAWA ACOUSTIC WAVE AUDIO SLIDER
// Adaptasi shader ombak Kanagawa taskbar dengan pembeda akustik:
//   - Amplitudo & kecepatan ombak responsif terhadap level suara (vol)
//   - Bioluminescent WaveAqua + Kintsugi Gold crest foam & breaking wave-front
//   - Taburan sunago gold dust di ruang sumi gelap di atas puncak ombak
// ─────────────────────────────────────────────────────────────────────────────
fn draw_kanagawa_audio_slider(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    half_sz: vec2<f32>,
    radius: f32,
    level: f32,
    is_muted: bool,
    time: f32,
    reveal: f32,
    in_col: vec3<f32>,
    in_alpha: f32,
) -> FlyoutRenderResult {
    var col = in_col;
    var alpha = in_alpha;

    let d_m = sd_rounded_box(mouse_pos - center, half_sz, radius);
    let hover = clamp(1.0 - max(d_m, 0.0) / 14.0, 0.0, 1.0) * reveal;
    let smooth_h = hover * hover * (3.0 - 2.0 * hover);

    let eff_c = center - vec2<f32>(0.0, 1.5 * smooth_h);
    let d_sld = sd_rounded_box(p - eff_c, half_sz, radius);

    // Subtle drop shadow
    let sh_d = sd_rounded_box(p - (eff_c + vec2<f32>(0.0, 2.2)), half_sz + vec2<f32>(0.8, 0.8), radius + 1.0);
    let sh_a = (1.0 - smoothstep(-2.0, 5.0, sh_d)) * 0.34 * reveal;
    if (sh_a > 0.001) {
        col = mix(col, hex(8.0, 9.0, 14.0), sh_a * (1.0 - alpha * 0.35));
        alpha = max(alpha, sh_a);
    }

    let a_sld = (1.0 - smoothstep(-0.7, 0.7, d_sld)) * reveal;
    if (a_sld > 0.001) {
        let sumi0       = hex(16.0, 18.0, 26.0);
        let sumi3       = hex(26.0, 29.0, 40.0);
        let wave1       = hex(28.0, 46.0, 72.0);
        let wave2       = hex(42.0, 78.0, 108.0);
        let spring_blue = hex(118.0, 184.0, 208.0);
        let aqua_glow   = hex(116.0, 206.0, 198.0); // Pembeda akustik: bioluminescent seafoam-aqua
        let gold_bright = hex(230.0, 195.0, 132.0);
        let gold_amber  = hex(220.0, 165.0, 97.0);
        let gold_shim   = hex(255.0, 240.0, 182.0);
        let orange      = hex(235.0, 120.0, 85.0);

        let w = max(half_sz.x * 2.0, 1.0);
        let h = max(half_sz.y * 2.0, 1.0);
        let lx = p.x - (eff_c.x - half_sz.x);
        let ly = p.y - (eff_c.y - half_sz.y);

        // Background Sumi sky inside track
        let wash = fbm(vec2<f32>(lx * 0.025, ly * 0.06) + vec2<f32>(time * 0.04, 0.0));
        var scol = mix(sumi0, sumi3, smoothstep(0.0, h, ly) * 0.55);
        scol = mix(scol, wave1, wash * 0.22);

        // Faint ambient sunago gold dust even in unfilled sky
        let sky_dust_p = (vec2<f32>(lx, ly) - vec2<f32>(time * 5.0, 0.0)) / 3.2;
        let r_sky = hash21(floor(sky_dust_p));
        let d_sky = length(fract(sky_dust_p) - vec2<f32>(0.5, 0.5)) * 3.2;
        let sky_tw = 0.5 + 0.5 * sin(time * 3.2 + r_sky * 12.56);
        let sky_dot = step(0.93, r_sky) * (1.0 - smoothstep(0.2, 1.0, d_sky)) * sky_tw;
        scol = mix(scol, gold_bright, sky_dot * 0.38);

        let eff_lvl = select(clamp(level, 0.0, 1.0), 0.0, is_muted);
        let fill_w = w * eff_lvl;

        // Organic breaking wave front at x = fill_w
        let front_wobble = sin(ly * 0.34 - time * (3.2 + 2.0 * eff_lvl)) * (1.6 + 1.4 * eff_lvl)
                         + cos(ly * 0.62 + time * 2.1) * 0.8;
        let dx_front = (fill_w + front_wobble) - lx;

        if (!is_muted && eff_lvl > 0.005) {
            // 1. Filled Kanagawa Acoustic Wave Ocean
            let in_fill = smoothstep(-1.2, 1.8, dx_front);
            if (in_fill > 0.001) {
                // Far background swell
                let far_amp = mix(1.2, h * 0.16, eff_lvl);
                let far = swell(lx, time, 140.0, far_amp, 0.08, 0.55);
                let far_y = h * 0.44 - far.x;
                let far_dc = ly - far_y;
                var wcol = scol;
                if (far_dc > 0.0) {
                    wcol = mix(wcol, wave1, smoothstep(0.0, 2.5, far_dc) * 0.82);
                } else {
                    wcol = mix(wcol, wave2, exp(far_dc / 4.0) * 0.35);
                }

                // Primary acoustic Kanagawa wave (amplitude & harmonic speed scale with volume!)
                let main_amp = mix(h * 0.10, h * 0.34, eff_lvl);
                let sw = swell(lx, time, 112.0, main_amp, 0.14 + 0.10 * eff_lvl, 0.20);
                // Acoustic harmonic modulation (pembeda dari taskbar!)
                let harm = sin(lx * 0.16 - time * (2.8 + 2.2 * eff_lvl)) * (0.7 + 1.8 * eff_lvl);
                let rough = (fbm(vec2<f32>(lx * 0.08, time * 0.22 + 2.1)) - 0.45) * 2.2;
                let crest_base = mix(h * 0.62, h * 0.48, eff_lvl);
                let crest_y = clamp(crest_base - sw.x - harm - rough, 2.5, h - 3.0);
                let front = clamp(sw.y, 0.0, 1.0);
                let dc = ly - crest_y;

                if (dc < 0.0) {
                    // Acoustic bioluminescent sky mist + sunago gold spray above crest
                    wcol = mix(wcol, wave2, exp(dc / 5.0) * 0.38);
                    wcol = mix(wcol, mix(aqua_glow, gold_bright, 0.55), exp(dc / 2.8) * (0.35 + 0.30 * eff_lvl));
                    let sp_p = (vec2<f32>(lx, ly) - vec2<f32>(time * 14.0, -time * 4.0)) / 2.6;
                    let r_sp = hash21(floor(sp_p));
                    let d_sp = length(fract(sp_p) - vec2<f32>(0.5, 0.5)) * 2.6;
                    let sp_on = step(0.84, r_sp) * (1.0 - smoothstep(0.25, 1.0, d_sp));
                    let sp_mask = smoothstep(-10.0, -0.5, dc) * (0.45 + 0.55 * front);
                    wcol = mix(wcol, mix(aqua_glow, gold_shim, r_sp), sp_on * sp_mask * 0.90);
                } else {
                    // Deep Prussian ocean body with flowing aqua-gold acoustic contour streaks
                    let depth = clamp(dc / max(h * 0.55, 4.0), 0.0, 1.0);
                    var body = mix(wave2, spring_blue, 0.34);
                    body = mix(body, wave1, smoothstep(0.0, 0.72, depth));
                    body = mix(body, sumi0, smoothstep(0.68, 1.0, depth) * 0.40);

                    let flow = fbm(vec2<f32>(lx * 0.06, dc * 0.25)) * 5.0;
                    let streak = smoothstep(0.76, 1.0, sin(dc * 1.15 + flow - time * 1.1));
                    let streak_col = mix(aqua_glow, gold_bright, clamp(lx / max(fill_w, 1.0), 0.0, 1.0));
                    body = mix(body, streak_col, streak * 0.55 * (1.0 - depth * 0.30));

                    wcol = mix(wcol, body, smoothstep(0.0, 1.2, dc) * 0.98);

                    // Glowing crest line + acoustic seafoam band
                    let lw = 0.9 + 0.8 * front;
                    let line = 1.0 - smoothstep(lw * 0.35, lw, abs(dc - lw * 0.25));
                    wcol = mix(wcol, mix(gold_amber, aqua_glow, 0.38), line * 0.88);

                    let fd = dc - lw * 0.7;
                    let foam_b = (1.0 - smoothstep(0.0, 2.4 + 3.2 * front, fd)) * step(0.0, fd);
                    let bn = fbm(vec2<f32>(lx * 0.25, ly * 0.55 + time * 0.25));
                    let foam_a = foam_b * smoothstep(0.32, 0.65, bn + front * 0.25);
                    wcol = mix(wcol, mix(aqua_glow, gold_shim, 0.58), foam_a * 0.92);
                }

                // Glowing breaking tide meniscus right at fill_w edge
                let edge_glow = (1.0 - smoothstep(0.0, 4.5, abs(dx_front))) * smoothstep(-1.0, 1.0, dx_front + 1.5);
                wcol = mix(wcol, mix(aqua_glow, gold_shim, 0.65), edge_glow * 0.78);

                scol = mix(scol, wcol, in_fill);
            }

            // Tiny spray mist jumping slightly ahead of fill_w
            if (dx_front < 0.0 && dx_front > -12.0) {
                let ahead_p = (vec2<f32>(lx, ly) - vec2<f32>(time * 16.0, 0.0)) / 2.8;
                let r_a = hash21(floor(ahead_p));
                let d_a = length(fract(ahead_p) - vec2<f32>(0.5, 0.5)) * 2.8;
                let spr = step(0.87, r_a) * (1.0 - smoothstep(0.2, 1.0, d_a)) * (1.0 - smoothstep(0.0, 12.0, -dx_front));
                scol = mix(scol, mix(aqua_glow, gold_shim, r_a), spr * 0.82);
            }
        } else if (is_muted) {
            // Calm desaturated sumi slate when muted
            scol = mix(scol, hex(30.0, 32.0, 42.0), 0.35);
        }

        // Subtle 1px top glass reflection
        let inner_b = 1.0 - smoothstep(0.0, 0.85, abs(d_sld + 0.75));
        let top_sp = smoothstep(eff_c.y + 4.0, eff_c.y - half_sz.y, p.y);
        scol = mix(scol, vec3<f32>(1.0, 1.0, 1.0), (0.08 + 0.12 * top_sp + 0.10 * smooth_h) * inner_b);

        // Taskbar-style two-tone Kanagawa rim (or vermilion when muted)
        let rim = smoothstep(1.5, 0.0, abs(d_sld));
        let rim_grad = smoothstep(eff_c.y + 6.0, eff_c.y - 6.0, p.y);
        let rim_col = select(
            mix(spring_blue, mix(gold_bright, gold_shim, smooth_h), rim_grad),
            orange,
            is_muted
        );
        scol = mix(scol, rim_col, rim * (0.55 + 0.35 * smooth_h));

        col = mix(col, scol, a_sld * 0.94);
        alpha = max(alpha, a_sld * 0.96);
    }

    return FlyoutRenderResult(col, alpha);
}

// KONTEN MAIN FLYOUT (Teks dirender oleh glyphon Space Grotesk di pass yang sama)
//   1 = Volume & Sound Output
//   2 = Battery & Power
//   3 = Wi-Fi & Connectivity
// ─────────────────────────────────────────────────────────────────────────────
fn draw_flyout_content(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    module_id: f32,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    value: f32,
    extra_meta: vec2<f32>,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold      = hex(230.0, 195.0, 132.0);
    let gold_hi   = hex(255.0, 238.0, 178.0);
    let cream     = hex(240.0, 235.0, 215.0);
    let muted_txt = hex(145.0, 152.0, 172.0);
    let aqua      = hex(127.0, 180.0, 202.0);
    let green     = hex(152.0, 187.0, 108.0);
    let orange    = hex(235.0, 120.0, 85.0);
    let amber     = hex(220.0, 165.0, 97.0);

    // ═════════════════════════════════════════════════════════════════════════
    // 1. VOLUME & SOUND OUTPUT (Kanagawa Acoustic Wave Slider + Complete Controls)
    // ═════════════════════════════════════════════════════════════════════════
    if (abs(module_id - 1.0) < 0.1) {
        let is_muted = fly_flag(5u);
        let mic_muted = fly_flag(6u);
        let spatial_on = fly_flag(7u);
        let out_idx = u32(clamp(u.flyout_state.z + 0.5, 0.0, 2.0));
        let vol = clamp(value, 0.0, 1.0);
        let mixer_open = (abs(u.chain_info.x - 4.0) < 0.1 && u.flyout_extra.w > 0.1)
                      || (abs(u.chain_info.y - 4.0) < 0.1 && u.chain_info.z > 0.1);
        let fx_open = (abs(u.chain_info.x - 5.0) < 0.1 && u.flyout_extra.w > 0.1)
                   || (abs(u.chain_info.y - 5.0) < 0.1 && u.chain_info.z > 0.1);

        // Row 1: Mute Button (-162, -94) + Kanagawa Acoustic Wave Slider (-8, -94)
        let mute_c = center + vec2<f32>(-162.0, -94.0) * pop;
        let t_mute = draw_fly_tile(
            p, mouse_pos, mute_c, vec2<f32>(26.0, 22.0) * pop, 12.0 * pop,
            select(0.0, 1.0, is_muted), orange, reveal, halo_gain, fg_col, fg_alpha
        );
        fg_col = t_mute.col;
        fg_alpha = t_mute.alpha;
        let mute_ic = icon_speaker_sdf(p, t_mute.eff_center, 1.38 * pop, is_muted);
        fg_col = mix(fg_col, select(cream, orange, is_muted), mute_ic * reveal);
        fg_alpha = max(fg_alpha, mute_ic * reveal);

        let sld_res = draw_kanagawa_audio_slider(
            p, mouse_pos,
            center + vec2<f32>(-8.0, -94.0) * pop,
            vec2<f32>(110.0, 20.0) * pop,
            12.0 * pop,
            vol, is_muted, time, reveal,
            fg_col, fg_alpha
        );
        fg_col = sld_res.col;
        fg_alpha = sld_res.alpha;

        // Row 2: Sound Output Device Selector (3 rows: -34, +12, +58; half 194x20)
        let r0_c = center + vec2<f32>(0.0, -34.0) * pop;
        let t_r0 = draw_fly_tile(p, mouse_pos, r0_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 0u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r0.col;
        fg_alpha = t_r0.alpha;
        let r0_ic = icon_speaker_sdf(p, t_r0.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop, false);
        let r0_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r0.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 0u), r0_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 0u), r0_dot * reveal);
        fg_alpha = max(fg_alpha, max(r0_ic, r0_dot) * reveal);

        let r1_c = center + vec2<f32>(0.0, 12.0) * pop;
        let t_r1 = draw_fly_tile(p, mouse_pos, r1_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 1u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r1.col;
        fg_alpha = t_r1.alpha;
        let r1_ic = icon_headphones_sdf(p, t_r1.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop);
        let r1_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r1.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 1u), r1_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 1u), r1_dot * reveal);
        fg_alpha = max(fg_alpha, max(r1_ic, r1_dot) * reveal);

        let r2_c = center + vec2<f32>(0.0, 58.0) * pop;
        let t_r2 = draw_fly_tile(p, mouse_pos, r2_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 2u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r2.col;
        fg_alpha = t_r2.alpha;
        let r2_ic = icon_monitor_sdf(p, t_r2.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop);
        let r2_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r2.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 2u), r2_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 2u), r2_dot * reveal);
        fg_alpha = max(fg_alpha, max(r2_ic, r2_dot) * reveal);

        // Row 3: Mic (-140) | Mixer > (-20) | Sound FX > (+100) | Gear (+179)
        let mic_c = center + vec2<f32>(-140.0, 110.0) * pop;
        let t_mic = draw_fly_tile(p, mouse_pos, mic_c, vec2<f32>(54.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, mic_muted), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_mic.col;
        fg_alpha = t_mic.alpha;
        let mic_ic = icon_mic_sdf(p, t_mic.eff_center + vec2<f32>(-32.0, 0.0) * pop, 1.22 * pop, mic_muted);
        fg_col = mix(fg_col, select(cream, orange, mic_muted), mic_ic * reveal);
        fg_alpha = max(fg_alpha, mic_ic * reveal);

        let mix_c = center + vec2<f32>(-20.0, 110.0) * pop;
        let t_mix = draw_fly_tile(p, mouse_pos, mix_c, vec2<f32>(58.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, mixer_open), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_mix.col;
        fg_alpha = t_mix.alpha;
        let mix_chv = icon_chevron_sdf(p, t_mix.eff_center + vec2<f32>(38.0, 0.0) * pop, 1.22 * pop, false);
        fg_col = mix(fg_col, select(gold, gold_hi, mixer_open), mix_chv * reveal);
        fg_alpha = max(fg_alpha, mix_chv * reveal);

        let fx_c = center + vec2<f32>(100.0, 110.0) * pop;
        let t_fx = draw_fly_tile(p, mouse_pos, fx_c, vec2<f32>(54.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, fx_open || spatial_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_fx.col;
        fg_alpha = t_fx.alpha;
        let fx_chv = icon_chevron_sdf(p, t_fx.eff_center + vec2<f32>(36.0, 0.0) * pop, 1.22 * pop, false);
        fg_col = mix(fg_col, select(gold, aqua, fx_open || spatial_on), fx_chv * reveal);
        fg_alpha = max(fg_alpha, fx_chv * reveal);

        let sg_c = center + vec2<f32>(179.0, 110.0) * pop;
        let t_sg = draw_fly_tile(p, mouse_pos, sg_c, vec2<f32>(17.0, 20.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_sg.col;
        fg_alpha = t_sg.alpha;
        let sg_ic = icon_gear_sdf(p, t_sg.eff_center, 1.22 * pop);
        fg_col = mix(fg_col, gold_hi, sg_ic * reveal);
        fg_alpha = max(fg_alpha, sg_ic * reveal);
    }
    // ═════════════════════════════════════════════════════════════════════════
    // 2. BATTERY & POWER MODE
    // ═════════════════════════════════════════════════════════════════════════
    else if (abs(module_id - 2.0) < 0.1) {
        let is_charging = extra_meta.x > 0.5 || fly_flag(9u);
        let energy_saver = fly_flag(8u);
        let pmode = u32(clamp(u.flyout_state.y + 0.5, 0.0, 2.0));
        let bright = clamp(u.flyout_state.w, 0.05, 1.0);
        let bat_lvl = clamp(value, 0.0, 1.0);

        var bat_accent = gold;
        if (is_charging) {
            bat_accent = green;
        } else if (bat_lvl <= 0.20) {
            bat_accent = orange;
        }

        // Row 1: Hero Battery Card (0, -88, half 192x36)
        let hero_c = center + vec2<f32>(0.0, -88.0) * pop;
        let t_hero = draw_fly_tile(p, mouse_pos, hero_c, vec2<f32>(192.0, 36.0) * pop, 15.0 * pop, 0.45, bat_accent, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hero.col;
        fg_alpha = t_hero.alpha;

        let tank_c = hero_c + vec2<f32>(-84.0, 0.0) * pop;
        let tank_h = vec2<f32>(58.0, 20.0) * pop;
        let d_tank = sd_rounded_box(p - tank_c, tank_h, 6.5 * pop);
        let tip_d = sd_rounded_box(p - (tank_c + vec2<f32>(62.0, 0.0) * pop), vec2<f32>(3.2, 8.5) * pop, 1.8 * pop);
        let a_tank = (1.0 - smoothstep(-0.6, 0.7, d_tank)) * reveal;
        if (a_tank > 0.0) {
            var tcol = hex(14.0, 16.0, 25.0);
            let t_left = tank_c.x - tank_h.x + 3.5 * pop;
            let t_w = (tank_h.x * 2.0 - 7.0 * pop) * clamp(bat_lvl, 0.05, 1.0);
            let fill_x = t_left + t_w;
            let wave_b = sin(p.y * 0.3 + time * 3.5) * 1.6 * reveal;
            if (p.x >= t_left && p.x <= fill_x + wave_b && abs(p.y - tank_c.y) <= tank_h.y - 3.2 * pop) {
                tcol = mix(tcol, bat_accent, 0.92);
            }
            if (is_charging) {
                let bolt = icon_flame_sdf(p, tank_c, 1.60 * pop);
                tcol = mix(tcol, hex(255.0, 250.0, 220.0), bolt * (0.75 + 0.25 * sin(time * 4.5)));
            }
            let trim = 1.0 - smoothstep(0.0, 1.5, abs(d_tank));
            tcol = mix(tcol, cream, trim * 0.75);
            fg_col = mix(fg_col, tcol, a_tank);
            fg_alpha = max(fg_alpha, a_tank);
        }
        let tip_a = (1.0 - smoothstep(-0.5, 0.7, tip_d)) * reveal;
        fg_col = mix(fg_col, cream, tip_a * 0.85);
        fg_alpha = max(fg_alpha, tip_a);

        // Row 2: Power Mode 3-Way Selector (dy = -12, half 58x28)
        let e_c = center + vec2<f32>(-130.0, -12.0) * pop;
        let t_eco = draw_fly_tile(p, mouse_pos, e_c, vec2<f32>(58.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 0u), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_eco.col;
        fg_alpha = t_eco.alpha;
        let e_ic = icon_leaf_sdf(p, e_c + vec2<f32>(0.0, -11.0) * pop, 1.25 * pop);
        fg_col = mix(fg_col, select(cream, green, pmode == 0u), e_ic * reveal);
        fg_alpha = max(fg_alpha, e_ic * reveal);

        let b_c = center + vec2<f32>(0.0, -12.0) * pop;
        let t_bal = draw_fly_tile(p, mouse_pos, b_c, vec2<f32>(58.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 1u), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_bal.col;
        fg_alpha = t_bal.alpha;
        let b_ic = icon_gauge_sdf(p, b_c + vec2<f32>(0.0, -11.0) * pop, 1.25 * pop);
        fg_col = mix(fg_col, select(cream, gold_hi, pmode == 1u), b_ic * reveal);
        fg_alpha = max(fg_alpha, b_ic * reveal);

        let f_c = center + vec2<f32>(130.0, -12.0) * pop;
        let t_prf = draw_fly_tile(p, mouse_pos, f_c, vec2<f32>(58.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 2u), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_prf.col;
        fg_alpha = t_prf.alpha;
        let f_ic = icon_flame_sdf(p, f_c + vec2<f32>(0.0, -11.0) * pop, 1.25 * pop);
        fg_col = mix(fg_col, select(cream, orange, pmode == 2u), f_ic * reveal);
        fg_alpha = max(fg_alpha, f_ic * reveal);

        // Row 3: Screen Brightness Slider (0, +50, half 192x20)
        let br_row = center + vec2<f32>(0.0, 50.0) * pop;
        let t_br = draw_fly_tile(p, mouse_pos, br_row, vec2<f32>(192.0, 20.0) * pop, 11.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_br.col;
        fg_alpha = t_br.alpha;
        let sun_a = icon_sun_sdf(p, br_row + vec2<f32>(-160.0, 0.0) * pop, 1.30 * pop);
        fg_col = mix(fg_col, gold_hi, sun_a * reveal);
        fg_alpha = max(fg_alpha, sun_a * reveal);

        let btr_c = br_row + vec2<f32>(-6.0, 0.0) * pop;
        let btr_h = vec2<f32>(114.0, 7.0) * pop;
        let d_btr = sd_rounded_box(p - btr_c, btr_h, 6.0 * pop);
        let a_btr = (1.0 - smoothstep(-0.6, 0.6, d_btr)) * reveal;
        if (a_btr > 0.0) {
            var bcol = hex(14.0, 16.0, 25.0);
            let bl = btr_c.x - btr_h.x;
            let fx = bl + (btr_h.x * 2.0) * bright;
            if (p.x <= fx) {
                bcol = mix(amber, gold_hi, clamp((p.x - bl) / max(btr_h.x * 2.0, 1.0), 0.0, 1.0));
            }
            fg_col = mix(fg_col, bcol, a_btr);
            fg_alpha = max(fg_alpha, a_btr);
        }

        // Row 4: Energy Saver (-52, +108) & Gear (+144, +108)
        let sv_c = center + vec2<f32>(-52.0, 108.0) * pop;
        let t_sv = draw_fly_tile(p, mouse_pos, sv_c, vec2<f32>(138.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, energy_saver), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_sv.col;
        fg_alpha = t_sv.alpha;
        let sv_ic = icon_leaf_sdf(p, sv_c + vec2<f32>(-104.0, 0.0) * pop, 1.25 * pop);
        fg_col = mix(fg_col, select(cream, green, energy_saver), sv_ic * reveal);
        fg_alpha = max(fg_alpha, sv_ic * reveal);

        let pg_c = center + vec2<f32>(144.0, 108.0) * pop;
        let t_pg = draw_fly_tile(p, mouse_pos, pg_c, vec2<f32>(46.0, 20.0) * pop, 11.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_pg.col;
        fg_alpha = t_pg.alpha;
        let pg_ic = icon_gear_sdf(p, pg_c, 1.35 * pop);
        fg_col = mix(fg_col, gold_hi, pg_ic * reveal);
        fg_alpha = max(fg_alpha, pg_ic * reveal);
    }
    // ═════════════════════════════════════════════════════════════════════════
    // 3. WI-FI & CONNECTIVITY (Luxury Kanagawa Wave Cards + Toggle + BT Split)
    // ═════════════════════════════════════════════════════════════════════════
    else if (abs(module_id - 3.0) < 0.1) {
        let wifi_on = fly_flag(0u);
        let bt_on = fly_flag(1u);
        let flight_on = fly_flag(2u);
        let spot_on = fly_flag(3u);
        let night_on = fly_flag(4u);
        let sig = clamp(value, 0.0, 1.0);
        let wifi_t = clamp(u.chain_info.w, 0.0, 1.0);

        // --- Row 1: Hero Wi-Fi Card (0, -94, half 196x36) ---
        let hero_c = center + vec2<f32>(0.0, -94.0) * pop;
        let t_hero = draw_fly_tile(p, mouse_pos, hero_c, vec2<f32>(196.0, 36.0) * pop, 15.0 * pop, select(0.0, 0.72, wifi_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hero.col;
        fg_alpha = t_hero.alpha;

        // Glowing Wi-Fi Icon on Left (-158, -94)
        let w_ic = icon_wifi_sdf(p, t_hero.eff_center + vec2<f32>(-158.0, 0.0) * pop, 1.75 * pop, select(0.0, sig, wifi_on));
        fg_col = mix(fg_col, select(muted_txt, aqua, wifi_on), w_ic * reveal);
        fg_alpha = max(fg_alpha, w_ic * reveal);

        // Chevron Arrow to open Wi-Fi Networks Sub-Flyout (+92, -94)
        let chev_c = t_hero.eff_center + vec2<f32>(92.0, 0.0) * pop;
        let chev_ic = icon_chevron_sdf(p, chev_c, 1.45 * pop, false);
        fg_col = mix(fg_col, gold_hi, chev_ic * reveal);
        fg_alpha = max(fg_alpha, chev_ic * reveal);

        // Luxury Kanagawa Wave & Kintsugi Gold Toggle Switch (+150, -94)
        let sw_res = draw_kanagawa_toggle(
            p, mouse_pos, t_hero.eff_center + vec2<f32>(150.0, 0.0) * pop,
            pop, wifi_t, time, reveal, fg_col, fg_alpha
        );
        fg_col = sw_res.col;
        fg_alpha = sw_res.alpha;

        // --- Row 2: Bluetooth Split Card (-102, -16) & Hotspot (+102, -16) ---
        let bt_c = center + vec2<f32>(-102.0, -16.0) * pop;
        let t_bt = draw_fly_tile(p, mouse_pos, bt_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, bt_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_bt.col;
        fg_alpha = t_bt.alpha;
        let bt_ic = icon_bluetooth_sdf(p, t_bt.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.55 * pop);
        fg_col = mix(fg_col, select(muted_txt, aqua, bt_on), bt_ic * reveal);
        fg_alpha = max(fg_alpha, bt_ic * reveal);

        // Subtle vertical split-divider + gold chevron on right of Bluetooth card to open BT sub-flyout!
        let div_x = t_bt.eff_center.x + 56.0 * pop;
        let d_div = sd_seg(p, vec2<f32>(div_x, t_bt.eff_center.y - 16.0 * pop), vec2<f32>(div_x, t_bt.eff_center.y + 16.0 * pop));
        let div_a = (1.0 - smoothstep(0.0, 1.1, d_div)) * 0.35 * reveal;
        fg_col = mix(fg_col, gold, div_a);
        let bt_chv = icon_chevron_sdf(p, t_bt.eff_center + vec2<f32>(74.0, 0.0) * pop, 1.30 * pop, false);
        fg_col = mix(fg_col, select(muted_txt, gold_hi, bt_on), bt_chv * reveal);
        fg_alpha = max(fg_alpha, bt_chv * reveal);

        let hs_c = center + vec2<f32>(102.0, -16.0) * pop;
        let t_hs = draw_fly_tile(p, mouse_pos, hs_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, spot_on), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hs.col;
        fg_alpha = t_hs.alpha;
        let hs_ic = icon_hotspot_sdf(p, t_hs.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.48 * pop);
        fg_col = mix(fg_col, select(cream, green, spot_on), hs_ic * reveal);
        fg_alpha = max(fg_alpha, hs_ic * reveal);

        // --- Row 3: Flight Mode (-102, +50) & Night Light (+102, +50) ---
        let fl_c = center + vec2<f32>(-102.0, 50.0) * pop;
        let t_fl = draw_fly_tile(p, mouse_pos, fl_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, flight_on), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_fl.col;
        fg_alpha = t_fl.alpha;
        let fl_ic = icon_airplane_sdf(p, t_fl.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.52 * pop);
        fg_col = mix(fg_col, select(cream, orange, flight_on), fl_ic * reveal);
        fg_alpha = max(fg_alpha, fl_ic * reveal);

        let nl_c = center + vec2<f32>(102.0, 50.0) * pop;
        let t_nl = draw_fly_tile(p, mouse_pos, nl_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, night_on), amber, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_nl.col;
        fg_alpha = t_nl.alpha;
        let nl_ic = icon_moon_sdf(p, t_nl.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.45 * pop);
        fg_col = mix(fg_col, select(cream, amber, night_on), nl_ic * reveal);
        fg_alpha = max(fg_alpha, nl_ic * reveal);

        // --- Row 4: Network & Internet Settings Footer (0, +112, half 196x20) ---
        let st_bar = center + vec2<f32>(0.0, 112.0) * pop;
        let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(196.0, 20.0) * pop, 11.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_stb.col;
        fg_alpha = t_stb.alpha;
        let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-166.0, 0.0) * pop, 1.32 * pop);
        fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
        fg_alpha = max(fg_alpha, stb_ic * reveal);
        let stb_chv = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(166.0, 0.0) * pop, 1.28 * pop, false);
        fg_col = mix(fg_col, gold, stb_chv * reveal);
        fg_alpha = max(fg_alpha, stb_chv * reveal);
    }

    return FlyoutRenderResult(fg_col, fg_alpha);
}

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
// SUB-FLYOUT 4: APP VOLUME MIXER (Mini Kanagawa Wave Sliders per App)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_app_mixer_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let orange  = hex(235.0, 120.0, 85.0);

    // Header: Back (-126, -114) & Reset (+126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    let ref_c = center + vec2<f32>(126.0, -114.0) * pop;
    let t_ref = draw_fly_tile(p, mouse_pos, ref_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_ref.col;
    fg_alpha = t_ref.alpha;
    let ref_ic = icon_refresh_sdf(p, t_ref.eff_center, 1.38 * pop);
    fg_col = mix(fg_col, aqua, ref_ic * reveal);
    fg_alpha = max(fg_alpha, ref_ic * reveal);

    // 3 App Volume Rows (y = -52, +8, +68)
    var ys = array<f32, 3>(-52.0, 8.0, 68.0);
    var lvls = array<f32, 3>(u.audio_levels.x, u.audio_levels.y, u.audio_levels.z);
    var mutes = array<bool, 3>(fly_flag(17u), fly_flag(18u), fly_flag(19u));

    for (var i = 0u; i < 3u; i = i + 1u) {
        let rc = center + vec2<f32>(0.0, ys[i]) * pop;
        let is_m = mutes[i];

        // Mute mini tile on left (-124, y)
        let mc = rc + vec2<f32>(-124.0, 0.0) * pop;
        let t_m = draw_fly_tile(p, mouse_pos, mc, vec2<f32>(18.0, 18.0) * pop, 9.0 * pop, select(0.0, 1.0, is_m), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_m.col;
        fg_alpha = t_m.alpha;
        let mic = icon_speaker_sdf(p, t_m.eff_center, 1.12 * pop, is_m);
        fg_col = mix(fg_col, select(cream, orange, is_m), mic * reveal);
        fg_alpha = max(fg_alpha, mic * reveal);

        // Mini Kanagawa Acoustic Wave Slider (-2, y + 8, half 90x10)
        let sres = draw_kanagawa_audio_slider(
            p, mouse_pos,
            rc + vec2<f32>(-2.0, 8.0) * pop,
            vec2<f32>(90.0, 10.0) * pop,
            7.0 * pop,
            lvls[i], is_m, time + f32(i) * 0.7, reveal,
            fg_col, fg_alpha
        );
        fg_col = sres.col;
        fg_alpha = sres.alpha;
    }

    // Bottom Settings Bar
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 5: SOUND & MIC FX (Spatial Audio, EQ Presets, Mic Gain Kanagawa Slider)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_audio_fx_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let orange  = hex(235.0, 120.0, 85.0);

    let spatial_on = fly_flag(7u);
    let mic_muted = fly_flag(6u);
    let eq_idx = select(0u, 1u, fly_flag(20u)) | select(0u, 2u, fly_flag(21u));
    let sp_t = clamp(u.chain_offsets.w, 0.0, 1.0);

    // Header: Back (-126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    // Section 1: Spatial Audio Card (0, -60, half 150x24) + Flat-Luminous Toggle
    let sp_c = center + vec2<f32>(0.0, -60.0) * pop;
    let t_sp = draw_fly_tile(p, mouse_pos, sp_c, vec2<f32>(150.0, 24.0) * pop, 13.0 * pop, select(0.0, 0.85, spatial_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_sp.col;
    fg_alpha = t_sp.alpha;
    let sp_ic = icon_spatial_sdf(p, t_sp.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.38 * pop);
    fg_col = mix(fg_col, select(cream, aqua, spatial_on), sp_ic * reveal);
    fg_alpha = max(fg_alpha, sp_ic * reveal);

    let sw_res = draw_kanagawa_toggle(
        p, mouse_pos, t_sp.eff_center + vec2<f32>(108.0, 0.0) * pop,
        pop * 0.92, sp_t, time, reveal, fg_col, fg_alpha
    );
    fg_col = sw_res.col;
    fg_alpha = sw_res.alpha;

    // Section 2: EQ Presets (Flat -104, Warm 0, Studio +104; y = -2, half 46x22)
    var eq_xs = array<f32, 3>(-104.0, 0.0, 104.0);
    for (var i = 0u; i < 3u; i = i + 1u) {
        let ec = center + vec2<f32>(eq_xs[i], -2.0) * pop;
        let t_eq = draw_fly_tile(p, mouse_pos, ec, vec2<f32>(46.0, 22.0) * pop, 11.0 * pop, select(0.0, 1.0, eq_idx == i), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_eq.col;
        fg_alpha = t_eq.alpha;
    }

    // Section 3: Microphone Gain Row (y = +58)
    let mc = center + vec2<f32>(-124.0, 58.0) * pop;
    let t_mc = draw_fly_tile(p, mouse_pos, mc, vec2<f32>(18.0, 18.0) * pop, 9.0 * pop, select(0.0, 1.0, mic_muted), orange, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_mc.col;
    fg_alpha = t_mc.alpha;
    let mic_ic = icon_mic_sdf(p, t_mc.eff_center, 1.18 * pop, mic_muted);
    fg_col = mix(fg_col, select(cream, orange, mic_muted), mic_ic * reveal);
    fg_alpha = max(fg_alpha, mic_ic * reveal);

    let mg_res = draw_kanagawa_audio_slider(
        p, mouse_pos,
        center + vec2<f32>(-4.0, 64.0) * pop,
        vec2<f32>(88.0, 10.0) * pop,
        7.0 * pop,
        u.audio_levels.w, mic_muted, time + 1.3, reveal,
        fg_col, fg_alpha
    );
    fg_col = mg_res.col;
    fg_alpha = mg_res.alpha;

    // Footer
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

fn draw_subflyout_by_kind(
    kind: f32,
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    wifi_on: bool,
    sig: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    if (abs(kind - 1.0) < 0.1) {
        return draw_networks_subflyout(p, mouse_pos, center, pop, reveal, wifi_on, sig, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 2.0) < 0.1) {
        return draw_bluetooth_subflyout(p, mouse_pos, center, pop, reveal, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 3.0) < 0.1) {
        return draw_password_subflyout(p, mouse_pos, center, pop, reveal, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 4.0) < 0.1) {
        return draw_app_mixer_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 5.0) < 0.1) {
        return draw_audio_fx_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    }
    return FlyoutRenderResult(base_col, base_alpha);
}

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

    let is_wifi_mod = (abs(u.flyout_info.x - 3.0) < 0.1) || (abs(u.flyout_info.x - 1.0) < 0.1);

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

    let is_wifi_mod = (abs(module_id - 3.0) < 0.1) || (abs(module_id - 1.0) < 0.1);
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

    // 1. SDF Glob
    let d_box = sd_rounded_box(warped_p - bar_center_base, vec2<f32>(half_w, half_h_base), eff_corner);
    let d_floor = bottom_y - p.y;
    let d_glob = smin_cubic(d_box, d_floor, eff_fillet);
    let d = max(d_glob, -d_floor);

    var color = hex(16.0, 16.0, 24.0);
    var wave_a = 0.0;

    let alpha = 1.0 - smoothstep(-0.8, 0.8, d);
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

            // === GROUP 1: KIRI (Start & Search) ===
            let win_center = vec2<f32>(bar_left + 54.0, widget_y);
            let pill_win = draw_widget_pill(color, p, win_center, vec2<f32>(30.0, 30.0), 16.0, u.mouse_pos);
            if (pill_win.col.a > 0.0) {
                let win_col = draw_windows_icon(pill_win.col.rgb, p, pill_win.eff_center, pill_win.hover);
                color = mix(color, win_col, widget_alpha);
            }

            let search_center = vec2<f32>(bar_left + 126.0, widget_y);
            let pill_search = draw_widget_pill(color, p, search_center, vec2<f32>(30.0, 30.0), 16.0, u.mouse_pos);
            if (pill_search.col.a > 0.0) {
                let search_col = draw_search_icon(pill_search.col.rgb, p, pill_search.eff_center, pill_search.hover);
                color = mix(color, search_col, widget_alpha);
            }

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

    let final_alpha = max(glob_alpha, fly_res.alpha);
    if (final_alpha <= 0.001) {
        discard;
    }

    var final_color = color;
    if (fly_res.alpha > 0.0) {
        final_color = mix(final_color, fly_res.col, fly_res.alpha);
    }

    // Premultiplied alpha output: RGB harus dikalikan dengan final_alpha
    return vec4<f32>(final_color * final_alpha, final_alpha);
}
