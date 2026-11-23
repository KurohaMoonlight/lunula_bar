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

// ─────────────────────────────────────────────────────────────────────────────
// KANAGAWA SOLAR HORIZON BRIGHTNESS SLIDER (Warm Gold-Amber Sunrise Tide)
// Pembeda dari Sound Slider: palet fajar Kanagawa (Indigo -> Amber -> Solar Gold)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_kanagawa_solar_slider(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    half_sz: vec2<f32>,
    radius: f32,
    level: f32,
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

    let sh_d = sd_rounded_box(p - (eff_c + vec2<f32>(0.0, 2.2)), half_sz + vec2<f32>(0.8, 0.8), radius + 1.0);
    let sh_a = (1.0 - smoothstep(-2.0, 5.0, sh_d)) * 0.34 * reveal;
    if (sh_a > 0.001) {
        col = mix(col, hex(8.0, 9.0, 14.0), sh_a * (1.0 - alpha * 0.35));
        alpha = max(alpha, sh_a);
    }

    let a_sld = (1.0 - smoothstep(-0.7, 0.7, d_sld)) * reveal;
    if (a_sld > 0.001) {
        let sumi0       = hex(16.0, 18.0, 26.0);
        let indigo_dusk = hex(30.0, 38.0, 62.0);
        let amber_deep  = hex(156.0, 96.0, 48.0);
        let gold_amber  = hex(224.0, 166.0, 92.0);
        let gold_bright = hex(246.0, 214.0, 144.0);
        let solar_ivory = hex(255.0, 246.0, 206.0);

        let w = max(half_sz.x * 2.0, 1.0);
        let h = max(half_sz.y * 2.0, 1.0);
        let lx = p.x - (eff_c.x - half_sz.x);
        let ly = p.y - (eff_c.y - half_sz.y);

        let wash = fbm(vec2<f32>(lx * 0.03, ly * 0.07) + vec2<f32>(time * 0.03, 0.0));
        var scol = mix(sumi0, indigo_dusk, smoothstep(0.0, h, ly) * 0.50 + wash * 0.20);

        let eff_lvl = clamp(level, 0.05, 1.0);
        let fill_w = w * eff_lvl;
        let front_wobble = sin(ly * 0.30 - time * 2.4) * 1.4;
        let dx_front = (fill_w + front_wobble) - lx;

        let in_fill = smoothstep(-1.2, 1.8, dx_front);
        if (in_fill > 0.001) {
            let tx = clamp(lx / max(fill_w, 1.0), 0.0, 1.0);
            let sw = swell(lx, time, 128.0, mix(1.5, h * 0.28, eff_lvl), 0.10, 0.40);
            let crest_y = clamp(h * 0.56 - sw.x - sin(lx * 0.11 - time * 1.6) * 1.2, 2.5, h - 2.5);
            let dc = ly - crest_y;

            var wcol = mix(indigo_dusk, amber_deep, tx * 0.65);
            if (dc < 0.0) {
                wcol = mix(wcol, gold_bright, exp(dc / 4.0) * (0.45 + 0.35 * tx));
            } else {
                let depth = clamp(dc / max(h * 0.55, 3.0), 0.0, 1.0);
                var body = mix(gold_amber, amber_deep, depth * 0.72);
                body = mix(body, gold_bright, tx * 0.48 * (1.0 - depth * 0.35));
                let flow = fbm(vec2<f32>(lx * 0.05, dc * 0.25)) * 4.5;
                let streak = smoothstep(0.76, 1.0, sin(dc * 1.1 + flow - time * 0.8));
                body = mix(body, solar_ivory, streak * 0.45);
                wcol = mix(wcol, body, smoothstep(0.0, 1.2, dc) * 0.96);

                let line = 1.0 - smoothstep(0.4, 1.4, abs(dc));
                wcol = mix(wcol, solar_ivory, line * 0.80);
            }

            let edge_glow = (1.0 - smoothstep(0.0, 4.5, abs(dx_front))) * smoothstep(-1.0, 1.0, dx_front + 1.5);
            wcol = mix(wcol, solar_ivory, edge_glow * 0.72);

            // Sunago solar dust sparkles
            let sp_p = (vec2<f32>(lx, ly) - vec2<f32>(time * 8.0, 0.0)) / 2.8;
            let r_sp = hash21(floor(sp_p));
            let d_sp = length(fract(sp_p) - vec2<f32>(0.5, 0.5)) * 2.8;
            let sp_on = step(0.88, r_sp) * (1.0 - smoothstep(0.2, 1.0, d_sp));
            wcol = mix(wcol, solar_ivory, sp_on * 0.65);

            scol = mix(scol, wcol, in_fill);
        }

        let inner_b = 1.0 - smoothstep(0.0, 0.85, abs(d_sld + 0.75));
        let top_sp = smoothstep(eff_c.y + 4.0, eff_c.y - half_sz.y, p.y);
        scol = mix(scol, vec3<f32>(1.0, 1.0, 1.0), (0.08 + 0.12 * top_sp + 0.10 * smooth_h) * inner_b);

        let rim = smoothstep(1.5, 0.0, abs(d_sld));
        let rim_grad = smoothstep(eff_c.y + 6.0, eff_c.y - 6.0, p.y);
        let rim_col = mix(hex(127.0, 180.0, 202.0), mix(gold_bright, solar_ivory, smooth_h), rim_grad);
        scol = mix(scol, rim_col, rim * (0.55 + 0.35 * smooth_h));

        col = mix(col, scol, a_sld * 0.94);
        alpha = max(alpha, a_sld * 0.96);
    }

    return FlyoutRenderResult(col, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// KANAGAWA ENERGY TIDE BATTERY TANK (Hero Card)
// Ombak Jade-Emerald saat Charging, Solar Gold saat Normal, Vermilion saat Low
// ─────────────────────────────────────────────────────────────────────────────
fn draw_kanagawa_battery_tank(
    p: vec2<f32>,
    tank_c: vec2<f32>,
    pop: f32,
    bat_lvl: f32,
    is_charging: bool,
    time: f32,
    reveal: f32,
    in_col: vec3<f32>,
    in_alpha: f32,
) -> FlyoutRenderResult {
    var col = in_col;
    var alpha = in_alpha;

    let cream  = hex(240.0, 235.0, 215.0);
    let gold   = hex(230.0, 195.0, 132.0);
    let green  = hex(136.0, 204.0, 134.0);
    let orange = hex(235.0, 114.0, 82.0);

    var tide_hi = gold;
    var tide_lo = hex(142.0, 102.0, 52.0);
    if (is_charging) {
        tide_hi = green;
        tide_lo = hex(42.0, 108.0, 86.0);
    } else if (bat_lvl <= 0.20) {
        tide_hi = orange;
        tide_lo = hex(136.0, 44.0, 38.0);
    }

    let tank_h = vec2<f32>(58.0, 20.0) * pop;
    let d_tank = sd_rounded_box(p - tank_c, tank_h, 7.0 * pop);
    let tip_d = sd_rounded_box(p - (tank_c + vec2<f32>(62.0, 0.0) * pop), vec2<f32>(3.0, 8.0) * pop, 1.8 * pop);

    let a_tank = (1.0 - smoothstep(-0.6, 0.7, d_tank)) * reveal;
    if (a_tank > 0.001) {
        var tcol = hex(14.0, 16.0, 25.0);
        let t_left = tank_c.x - tank_h.x + 3.0 * pop;
        let t_span = max(tank_h.x * 2.0 - 6.0 * pop, 1.0);
        let t_w = t_span * clamp(bat_lvl, 0.05, 1.0);
        let lx = p.x - t_left;
        let ly = p.y - (tank_c.y - tank_h.y);
        let wave_edge = sin(ly * 0.34 - time * 3.4) * 1.8 * pop;

        if (lx >= 0.0 && lx <= t_w + wave_edge && abs(p.y - tank_c.y) <= tank_h.y - 3.0 * pop) {
            let sw = swell(lx, time, 75.0, 4.0 * pop, 0.16, 0.3);
            let crest_y = tank_h.y * 0.85 - sw.x;
            let dc = ly - crest_y;
            let vy = clamp(ly / max(tank_h.y * 2.0, 1.0), 0.0, 1.0);
            var wcol = mix(tide_hi, tide_lo, vy * 0.75);
            let streak = smoothstep(0.75, 1.0, sin(dc * 0.9 + fbm(vec2<f32>(lx * 0.07, ly * 0.12)) * 4.0 - time * 1.4));
            wcol = mix(wcol, hex(255.0, 248.0, 214.0), streak * 0.45);
            let front_g = 1.0 - smoothstep(0.0, 3.8 * pop, abs((t_w + wave_edge) - lx));
            wcol = mix(wcol, hex(255.0, 248.0, 214.0), front_g * 0.65);
            tcol = mix(tcol, wcol, 0.94);
        }

        if (is_charging) {
            let bolt = icon_flame_sdf(p, tank_c, 1.55 * pop);
            tcol = mix(tcol, hex(255.0, 252.0, 224.0), bolt * (0.78 + 0.22 * sin(time * 4.5)));
        }

        let trim = smoothstep(1.5, 0.0, abs(d_tank));
        let rim_c = mix(hex(127.0, 180.0, 202.0), tide_hi, smoothstep(tank_c.y + 8.0, tank_c.y - 8.0, p.y));
        tcol = mix(tcol, rim_c, trim * 0.78);
        col = mix(col, tcol, a_tank);
        alpha = max(alpha, a_tank);
    }

    let tip_a = (1.0 - smoothstep(-0.5, 0.7, tip_d)) * reveal;
    col = mix(col, mix(cream, tide_hi, 0.45), tip_a * 0.88);
    alpha = max(alpha, tip_a);

    return FlyoutRenderResult(col, alpha);
}
