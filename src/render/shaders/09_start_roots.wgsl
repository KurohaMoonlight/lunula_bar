// ─────────────────────────────────────────────────────────────────────────────
// START MENU / WINDOWS BUTTON KINTSUGI & ABSORPTION EFFECTS
// ─────────────────────────────────────────────────────────────────────────────

/// Kapsul meruncing dari \\ (radius 0\) ke \\ (radius 1\).
fn sd_tapered_capsule(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, r0: f32, r1: f32) -> vec2<f32> {
    let pa = p - a;
    let ba = b - a;
    let denom = max(dot(ba, ba), 1e-5);
    let h = clamp(dot(pa, ba) / denom, 0.0, 1.0);
    let d = length(pa - ba * h) - mix(r0, r1, h);
    return vec2<f32>(d, h);
}

/// Shading Lilitan Sulur Emas Kintsugi pada Tombol Windows
fn shade_liquid_energy_root(
    p: vec2<f32>,
    d: f32,
    r: f32,
    nx: f32,
    ny: f32,
    arc: f32,
    root_id: f32,
    depth_layer: f32,
    energy: f32,
    time: f32,
) -> vec3<f32> {
    let radial = clamp(-d / max(r, 0.8), 0.0, 1.0);

    let gold_deep    = hex(142.0, 88.0, 32.0);
    let gold_warm    = hex(232.0, 178.0, 88.0);
    let energy_core  = hex(255.0, 244.0, 206.0);
    let sky_refract  = hex(92.0, 142.0, 184.0);
    let rim_glow     = hex(255.0, 250.0, 226.0);

    let flow_speed = 1.35 + root_id * 0.14;
    let flow_phase = arc * 14.0 - time * flow_speed;
    let flow_pulse = 0.5 + 0.5 * sin(flow_phase);
    let micro_vein = sin(flow_phase * 2.8 + nx * 3.5) * 0.5 + 0.5;

    let n3 = vec3<f32>(nx * radial, ny * radial, sqrt(max(1.0 - radial * radial, 0.0)));
    let light_dir = normalize(vec3<f32>(-0.45, -0.75, 0.65));
    let diff = clamp(dot(n3, light_dir), 0.0, 1.0);
    let view_dir = vec3<f32>(0.0, 0.0, 1.0);
    let half_v = normalize(light_dir + view_dir);
    let spec = pow(clamp(dot(n3, half_v), 0.0, 1.0), 16.0);

    var col = mix(gold_deep, gold_warm, smoothstep(0.08, 0.62, radial));
    let core_glow = pow(radial, 1.35) * (0.65 + 0.35 * flow_pulse) * (0.75 + 0.35 * energy);
    col = mix(col, energy_core, clamp(core_glow, 0.0, 0.92));
    col = col * (0.90 + 0.20 * micro_vein);

    let upper_rim = clamp(-n3.y, 0.0, 1.0) * smoothstep(0.42, 0.90, radial);
    col = mix(col, rim_glow, upper_rim * (0.34 + 0.22 * flow_pulse));

    let lower_bounce = clamp(n3.y, 0.0, 1.0) * smoothstep(0.36, 0.90, radial);
    col = mix(col, sky_refract, lower_bounce * 0.26);
    col = mix(col, energy_core, clamp(spec * (0.36 + 0.20 * energy), 0.0, 0.58));

    return col;
}

/// Evaluasi lilitan akar energi cair 3D (Ishizuki / root-over-rock) yang tersambung langsung
/// dari akar nebari `L3` di atas tombol Windows, melilit mulus DEPAN & BELAKANG dengan kurva halus
/// (ZERO sudut poligon kaku & ZERO benjolan sambungan) sambil menjaga ikon 4-kotak 100% bersih.
fn eval_win_entangle_layer(
    p: vec2<f32>,
    win_center: vec2<f32>,
    p2_c: f32,
    hover: f32,
    cinch: f32,
    time: f32,
    is_front: bool,
) -> vec4<f32> {
    let g = smoothstep(0.12, 0.88, p2_c);
    if (g <= 0.005) {
        return vec4<f32>(1e5, 0.0, 0.0, -1.0);
    }
    let q_box = abs(p - win_center);
    if (q_box.x > 46.0 || q_box.y > 46.0) {
        return vec4<f32>(1e5, 0.0, 0.0, -1.0);
    }

    // Hover: melonggar lembut (+1.8px); Klik: mengencang sesaat (-3.0px) lalu rileks via pegas YAML
    let c_off = -1.2 * g - cinch * 3.0 + hover * 1.8;
    let breath = sin(time * 1.57) * 0.45;
    let q_raw = p - win_center;
    // Distorsi organik cair sangat halus agar lilitan terasa hidup & tidak kaku
    let qw = q_raw + vec2<f32>(
        sin(q_raw.x * 0.08 + q_raw.y * 0.07 - time * 0.9) * 0.50,
        cos(q_raw.x * 0.07 - q_raw.y * 0.08 + time * 0.8) * 0.50
    ) * g;

    var d_min = 1e5;
    var best_arc = 0.0;
    var best_cl = vec2<f32>(0.0, -28.0);

    if (!is_front) {
        // ─────────────────────────────────────────────────────────────────────
        // BACK LAYER: Lilitan akar yang menyusup ke BELAKANG tombol Windows (kedalaman 3D)
        // ─────────────────────────────────────────────────────────────────────
        let g1 = smoothstep(0.10, 0.65, g);
        let g2 = smoothstep(0.32, 0.92, g);

        // Back Strand B: Masuk dari akar nebari kiri-atas L3 (-26, -18), melingkar di BELAKANG
        // sisi kiri tombol hingga muncul ke depan di kiri-bawah (-23, +21)
        var bl = array<vec2<f32>, 7>(
            vec2<f32>(-26.0, -18.0),
            vec2<f32>(-30.5 + c_off * 0.35, -10.5),
            vec2<f32>(-32.8 + c_off * 0.40, -1.0),
            vec2<f32>(-32.5 + c_off * 0.40,  8.5),
            vec2<f32>(-29.5 + c_off * 0.35, 16.5),
            vec2<f32>(-24.5 + c_off * 0.25, 22.0),
            vec2<f32>(-18.0, 25.0 - c_off * 0.25)
        );
        var bl_r = array<f32, 7>(2.70, 2.45, 2.25, 2.10, 1.95, 1.85, 1.70);
        var d_bl = 1e5;
        for (var i = 0; i < 6; i = i + 1) {
            let fi = f32(i) / 6.0;
            let sg = smoothstep(fi * 0.45, min(fi * 0.45 + 0.45, 1.0), g1);
            if (sg <= 0.01) { continue; }
            let a = bl[i];
            let b = mix(a, bl[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, bl_r[i] * sg, bl_r[i + 1] * sg);
            if (cap.x < d_bl) {
                d_bl = cap.x;
                best_cl = mix(a, b, cap.y);
                best_arc = (f32(i) + cap.y) / 6.0;
            }
        }
        d_min = d_bl;

        // Back Strand A: Kelanjutan Strand A depan yang menyelip ke BELAKANG sudut kanan-bawah
        // dan melingkar di belakang tepi bawah tombol
        var br = array<vec2<f32>, 6>(
            vec2<f32>( 25.5 - c_off * 0.30,  11.0),
            vec2<f32>( 27.5 - c_off * 0.35,  19.5),
            vec2<f32>( 22.0 - c_off * 0.30,  27.5 - c_off * 0.35),
            vec2<f32>( 11.5,                 32.2 - c_off * 0.40),
            vec2<f32>( -2.0,                 32.5 - c_off * 0.40),
            vec2<f32>(-15.5,                 29.5 - c_off * 0.30)
        );
        var br_r = array<f32, 6>(2.25, 2.00, 1.75, 1.45, 1.15, 0.80);
        var d_br = 1e5;
        var br_cl = best_cl;
        var br_arc = 0.0;
        for (var i = 0; i < 5; i = i + 1) {
            let fi = f32(i) / 5.0;
            let sg = smoothstep(fi * 0.45, min(fi * 0.45 + 0.45, 1.0), g2);
            if (sg <= 0.01) { continue; }
            let a = br[i];
            let b = mix(a, br[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, br_r[i] * sg, br_r[i + 1] * sg);
            if (cap.x < d_br) {
                d_br = cap.x;
                br_cl = mix(a, b, cap.y);
                br_arc = (f32(i) + cap.y) / 5.0;
            }
        }
        if (d_br < d_min) {
            best_cl = br_cl;
            best_arc = br_arc;
        }
        d_min = smin_cubic(d_min, d_br, 2.2);
    } else {
        // ─────────────────────────────────────────────────────────────────────
        // FRONT LAYER: 4 Sulur Akar Energi Cair Melilit Halus di DEPAN Tombol Windows
        // Tersambung tepat ke akar nebari L3 (ZERO sudut poligon & ZERO ujung tumpul!)
        // ─────────────────────────────────────────────────────────────────────
        let g1 = smoothstep(0.05, 0.62, g);
        let g2 = smoothstep(0.24, 0.88, g);
        let g3 = smoothstep(0.42, 1.00, g);

        // Front Strand A: Mengalir langsung dari nebari kanan-atas (+19, -34) -> memeluk bahu kanan
        // -> melengkung halus di sisi kanan -> menyusup mulus ke Back Strand A (+25.5, +11)
        var fa = array<vec2<f32>, 7>(
            vec2<f32>(19.0,                 -34.0),
            vec2<f32>(22.5 - c_off * 0.20,  -25.5),
            vec2<f32>(26.2 - c_off * 0.30,  -16.0),
            vec2<f32>(28.0 - c_off * 0.35,   -6.0 + breath * 0.4),
            vec2<f32>(28.2 - c_off * 0.35,    3.5),
            vec2<f32>(26.5 - c_off * 0.30,   12.0),
            vec2<f32>(23.0 - c_off * 0.25,   19.0)
        );
        var fa_r = array<f32, 7>(3.35, 3.00, 2.70, 2.45, 2.25, 2.05, 1.65);
        var d_fa = 1e5;
        var fa_cl = best_cl;
        var fa_arc = 0.0;
        for (var i = 0; i < 6; i = i + 1) {
            let fi = f32(i) / 6.0;
            let sg = smoothstep(fi * 0.42, min(fi * 0.42 + 0.48, 1.0), g1);
            if (sg <= 0.01) { continue; }
            let a = fa[i];
            let b = mix(a, fa[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, fa_r[i] * sg, fa_r[i + 1] * sg);
            if (cap.x < d_fa) {
                d_fa = cap.x;
                fa_cl = mix(a, b, cap.y);
                fa_arc = (f32(i) + cap.y) / 6.0;
            }
        }
        d_min = d_fa;
        best_cl = fa_cl;
        best_arc = fa_arc;

        // Front Strand B: Muncul dari Back Strand B di kiri-bawah (-24, +20) -> melingkar anggun
        // menyusuri bibir bawah -> naik meruncing tipis di sudut kanan-bawah
        var fb = array<vec2<f32>, 8>(
            vec2<f32>(-24.5 + c_off * 0.25,  19.5),
            vec2<f32>(-18.5 + c_off * 0.25,  24.5 - c_off * 0.30),
            vec2<f32>( -9.5,                 27.0 - c_off * 0.35 - breath * 0.5),
            vec2<f32>(  1.5,                 27.2 - c_off * 0.35),
            vec2<f32>( 12.0,                 25.0 - c_off * 0.30),
            vec2<f32>( 20.5 - c_off * 0.25,  19.5),
            vec2<f32>( 26.0 - c_off * 0.25,  11.0),
            vec2<f32>( 27.0 - c_off * 0.20,   1.5)
        );
        var fb_r = array<f32, 8>(2.10, 2.00, 1.88, 1.72, 1.48, 1.15, 0.78, 0.38);
        var d_fb = 1e5;
        var fb_cl = best_cl;
        var fb_arc = 0.0;
        for (var i = 0; i < 7; i = i + 1) {
            let fi = f32(i) / 7.0;
            let sg = smoothstep(fi * 0.45, min(fi * 0.45 + 0.45, 1.0), g2);
            if (sg <= 0.01) { continue; }
            let a = fb[i];
            let b = mix(a, fb[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, fb_r[i] * sg, fb_r[i + 1] * sg);
            if (cap.x < d_fb) {
                d_fb = cap.x;
                fb_cl = mix(a, b, cap.y);
                fb_arc = (f32(i) + cap.y) / 7.0;
            }
        }
        if (d_fb < d_min) {
            best_cl = fb_cl;
            best_arc = fb_arc;
        }
        d_min = smin_cubic(d_min, d_fb, 2.2);

        // Front Strand C: Sulur bulan sabit memeluk sudut kiri-atas langsung dari L3 (+6, -28.5)
        // hingga meruncing halus di sepanjang tepi kiri tombol (ikon 4-kotak tetap 100% bersih!)
        var fc = array<vec2<f32>, 7>(
            vec2<f32>(  6.5,                 -28.5),
            vec2<f32>( -3.0,                 -27.2 + c_off * 0.30 + breath * 0.4),
            vec2<f32>(-13.0,                 -24.8 + c_off * 0.30),
            vec2<f32>(-21.2 + c_off * 0.25,  -19.5),
            vec2<f32>(-26.0 + c_off * 0.30,  -11.0),
            vec2<f32>(-27.2 + c_off * 0.30,   -1.0),
            vec2<f32>(-25.0 + c_off * 0.25,    8.5)
        );
        var fc_r = array<f32, 7>(2.75, 2.45, 2.15, 1.80, 1.38, 0.90, 0.38);
        var d_fc = 1e5;
        var fc_cl = best_cl;
        var fc_arc = 0.0;
        for (var i = 0; i < 6; i = i + 1) {
            let fi = f32(i) / 6.0;
            let sg = smoothstep(fi * 0.42, min(fi * 0.42 + 0.48, 1.0), g1);
            if (sg <= 0.01) { continue; }
            let a = fc[i];
            let b = mix(a, fc[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, fc_r[i] * sg, fc_r[i + 1] * sg);
            if (cap.x < d_fc) {
                d_fc = cap.x;
                fc_cl = mix(a, b, cap.y);
                fc_arc = (f32(i) + cap.y) / 6.0;
            }
        }
        if (d_fc < d_min) {
            best_cl = fc_cl;
            best_arc = fc_arc;
        }
        d_min = smin_cubic(d_min, d_fc, 2.2);

        // Front Strand D: Serabut halus bercabang dari Strand B di kiri-bawah memeluk sudut kiri-bawah
        var fd = array<vec2<f32>, 5>(
            vec2<f32>(-17.5 + c_off * 0.25,  24.2 - c_off * 0.25),
            vec2<f32>(-23.0 + c_off * 0.25,  17.5),
            vec2<f32>(-26.0 + c_off * 0.25,   9.0),
            vec2<f32>(-25.5 + c_off * 0.25,   0.5),
            vec2<f32>(-22.5 + c_off * 0.20,  -6.5)
        );
        var fd_r = array<f32, 5>(1.45, 1.15, 0.85, 0.55, 0.30);
        var d_fd = 1e5;
        var fd_cl = best_cl;
        var fd_arc = 0.0;
        for (var i = 0; i < 4; i = i + 1) {
            let fi = f32(i) / 4.0;
            let sg = smoothstep(fi * 0.40, min(fi * 0.40 + 0.50, 1.0), g3);
            if (sg <= 0.01) { continue; }
            let a = fd[i];
            let b = mix(a, fd[i + 1], sg);
            let cap = sd_tapered_capsule(qw, a, b, fd_r[i] * sg, fd_r[i + 1] * sg);
            if (cap.x < d_fd) {
                d_fd = cap.x;
                fd_cl = mix(a, b, cap.y);
                fd_arc = (f32(i) + cap.y) / 4.0;
            }
        }
        if (d_fd < d_min) {
            best_cl = fd_cl;
            best_arc = fd_arc;
        }
        d_min = smin_cubic(d_min, d_fd, 1.8);
    }

    let diff = qw - best_cl;
    let dlen = length(diff);
    let best_n = select(vec2<f32>(0.0, -1.0), diff / dlen, dlen > 0.001);
    return vec4<f32>(d_min, best_arc, best_n.x, best_n.y);
}

/// Evaluasi retakan Kintsugi emas cair prosedural pada tombol Windows.
fn eval_win_kintsugi_cracks(
    p: vec2<f32>,
    win_center: vec2<f32>,
    p2_c: f32,
    win_hov: f32,
    win_flash: f32,
    win_ripple: f32,
    time: f32,
) -> vec4<f32> {
    let progress = smoothstep(0.20, 0.90, p2_c);
    if (progress <= 0.005 && win_flash <= 0.005 && win_ripple >= 0.995) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }

    let q = p - win_center;
    let d_box = sd_rounded_box(q, vec2<f32>(29.5, 29.5), 15.5);
    let inside_box = 1.0 - smoothstep(-0.5, 2.0, d_box);

    let ripple_col = hex(255.0, 238.0, 180.0);
    var ripple_a = 0.0;
    if (win_ripple < 0.99) {
        let rr = 6.0 + win_ripple * 36.0;
        let dist_c = length(q);
        let ring = (1.0 - smoothstep(0.0, 2.2, abs(dist_c - rr))) * (1.0 - win_ripple);
        ripple_a = ring * 0.72 * (1.0 - smoothstep(-1.0, 10.0, d_box));
    }

    if (progress <= 0.005 || inside_box <= 0.002) {
        return vec4<f32>(ripple_col, ripple_a);
    }

    let w1 = sin(q.x * 0.24 + q.y * 0.19) * 1.1 + cos(q.x * 0.44 - q.y * 0.32) * 0.5;
    let w2 = sin(q.y * 0.27 - q.x * 0.21) * 1.0 + cos(q.y * 0.46 + q.x * 0.30) * 0.45;
    let wq = q + vec2<f32>(w1, w2) * 0.68;

    let g1 = vec2<f32>(18.0, -21.0);
    let g2 = vec2<f32>(-18.0, 20.5);
    let g3 = vec2<f32>(-20.0, -17.0);
    let g4 = vec2<f32>(20.5, 16.5);

    var d_crack = 1e5;
    var crack_arc = 0.0;

    let p1a = clamp(progress * 1.45, 0.0, 1.0);
    let p1b = clamp(progress * 1.55 - 0.28, 0.0, 1.0);
    let p1c = clamp(progress * 1.65 - 0.52, 0.0, 1.0);
    let k1_0 = vec2<f32>(12.0, -13.0);
    let k1_1 = vec2<f32>(5.5, -10.5);
    let k1_2 = vec2<f32>(-4.0, -15.0);

    let s1a = sd_tapered_capsule(wq, g1, mix(g1, k1_0, p1a), 1.35 * p1a, 0.95 * p1a);
    let s1b = sd_tapered_capsule(wq, k1_0, mix(k1_0, k1_1, p1b), 0.95 * p1b, 0.65 * p1b);
    let s1c = sd_tapered_capsule(wq, k1_1, mix(k1_1, k1_2, p1c), 0.62 * p1c, 0.32 * p1c);
    let s1_br = sd_tapered_capsule(wq, k1_0, mix(k1_0, vec2<f32>(16.5, -3.5), p1b), 0.78 * p1b, 0.34 * p1b);

    d_crack = min(min(s1a.x, s1b.x), min(s1c.x, s1_br.x));
    crack_arc = clamp(length(q - g1) / 34.0, 0.0, 1.0);

    let p2a = clamp(progress * 1.38 - 0.08, 0.0, 1.0);
    let p2b = clamp(progress * 1.52 - 0.36, 0.0, 1.0);
    let k2_0 = vec2<f32>(-11.5, 13.5);
    let k2_1 = vec2<f32>(-2.5, 16.5);
    let s2a = sd_tapered_capsule(wq, g2, mix(g2, k2_0, p2a), 1.30 * p2a, 0.88 * p2a);
    let s2b = sd_tapered_capsule(wq, k2_0, mix(k2_0, k2_1, p2b), 0.85 * p2b, 0.38 * p2b);
    let s2_br = sd_tapered_capsule(wq, k2_0, mix(k2_0, vec2<f32>(-16.0, 4.5), p2b), 0.68 * p2b, 0.30 * p2b);
    let d2 = min(min(s2a.x, s2b.x), s2_br.x);
    if (d2 < d_crack) {
        d_crack = d2;
        crack_arc = clamp(length(q - g2) / 32.0, 0.0, 1.0);
    }

    if (progress > 0.24) {
        let p3 = clamp((progress - 0.24) * 1.55, 0.0, 1.0);
        let k3_0 = vec2<f32>(-13.5, -10.5);
        let s3a = sd_tapered_capsule(wq, g3, mix(g3, k3_0, p3), 1.18 * p3, 0.72 * p3);
        let s3b = sd_tapered_capsule(wq, k3_0, mix(k3_0, vec2<f32>(-17.0, -1.5), clamp(p3 * 1.3 - 0.3, 0.0, 1.0)), 0.68 * p3, 0.28 * p3);
        let d3 = min(s3a.x, s3b.x);
        if (d3 < d_crack) {
            d_crack = d3;
            crack_arc = clamp(length(q - g3) / 28.0, 0.0, 1.0);
        }
    }

    if (progress > 0.34) {
        let p4 = clamp((progress - 0.34) * 1.60, 0.0, 1.0);
        let k4_0 = vec2<f32>(12.5, 13.0);
        let s4a = sd_tapered_capsule(wq, g4, mix(g4, k4_0, p4), 1.15 * p4, 0.68 * p4);
        let s4b = sd_tapered_capsule(wq, k4_0, mix(k4_0, vec2<f32>(5.0, 17.5), clamp(p4 * 1.35 - 0.35, 0.0, 1.0)), 0.65 * p4, 0.30 * p4);
        let d4 = min(s4a.x, s4b.x);
        if (d4 < d_crack) {
            d_crack = d4;
            crack_arc = clamp(length(q - g4) / 26.0, 0.0, 1.0);
        }
    }

    let icon_guard = smoothstep(8.5, 14.5, length(q));

    let bronze_groove = hex(46.0, 26.0, 12.0);
    let gold_fill     = hex(228.0, 172.0, 82.0);
    let core_hot      = hex(255.0, 245.0, 206.0);

    let hover_pulse = 0.5 + 0.5 * sin(time * 4.2 - crack_arc * 6.0);
    let flow_wave = pow(0.5 + 0.5 * sin(crack_arc * 9.0 - time * 3.5), 2.4);
    let glow_boost = clamp(flow_wave * 0.42 + win_hov * (0.35 + 0.35 * hover_pulse) + win_flash * 0.95, 0.0, 1.2);

    let groove_m = (1.0 - smoothstep(0.0, 1.55, d_crack)) * progress;
    let fill_m   = (1.0 - smoothstep(-0.15, 0.80, d_crack)) * progress;
    let core_m   = (1.0 - smoothstep(-0.35, 0.30, d_crack)) * progress;
    let aura_m   = exp(-max(d_crack, 0.0) * 0.45) * (0.18 + 0.30 * win_hov + 0.42 * win_flash) * progress;

    var c_col = mix(bronze_groove, gold_fill, clamp(fill_m / max(groove_m, 0.01), 0.0, 1.0));
    c_col = mix(c_col, core_hot, clamp(core_m * 0.80 + glow_boost * 0.42 * fill_m, 0.0, 0.95));

    let crack_a = clamp(max(max(groove_m * 0.84, fill_m * 0.95), aura_m) * inside_box * (0.30 + 0.70 * icon_guard), 0.0, 0.96);

    let out_col = mix(c_col, ripple_col, clamp(ripple_a / max(crack_a + ripple_a, 0.001), 0.0, 1.0));
    let out_a = clamp(max(crack_a, ripple_a), 0.0, 0.98);
    return vec4<f32>(out_col, out_a);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAKURA SEED OUTLINE TRACER (Meluncur Menyusuri Bibir Ombak ke Tengah Layar)
// ─────────────────────────────────────────────────────────────────────────────

fn get_taskbar_lip_y(x: f32, cx: f32, half_w: f32, bottom_y: f32, smooth_t: f32, overshoot: f32) -> f32 {
    let nx = clamp(abs(x - cx) / half_w, 0.0, 1.0);
    let surge = smoothstep(nx * 0.55, 1.0, smooth_t);
    let bulge = sin(smooth_t * 3.14159) * (1.0 - nx * nx) * 22.0;
    let h = mix(8.0, u.bar_height, surge) + bulge + overshoot;
    return bottom_y - h;
}

fn render_sakura_seed_tracer(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    bar_left: f32,
    bottom_y: f32,
    smooth_t: f32,
    overshoot: f32,
    win_center: vec2<f32>,
    p2_c: f32,
    time: f32,
    in_col: vec3<f32>,
    in_a: f32,
) -> vec4<f32> {
    if (p2_c <= 0.003) {
        return vec4<f32>(in_col, in_a);
    }

    let s = clamp(p2_c, 0.0, 1.0);
    let s_eased = smoothstep(0.0, 1.0, s);

    let start_x = win_center.x;
    let end_x = cx;
    let cur_x = mix(start_x, end_x, s_eased);

    // Ketinggian Y bibir atas taskbar di posisi X seed
    let lip_y = get_taskbar_lip_y(cur_x, cx, half_w, bottom_y, smooth_t, overshoot);

    // Guard batas vertikal: seed tracer hanya meluncur di sekitar bibir ombak (maks 25px di atas bibir)
    if (p.y < lip_y - 25.0) {
        return vec4<f32>(in_col, in_a);
    }

    var col = in_col;
    var alpha = in_a;
    let lip_wave = (sin((cur_x - bar_left) * 0.034 + time * 2.8) * 0.65 + sin((cur_x - bar_left) * 0.072 - time * 1.5) * 0.35) * 2.4;

    // Saat awal meluncur (s < 0.22), ada sedikit busur lompatan (arc lift) dari tombol Windows ke bibir taskbar
    let launch_prog = smoothstep(0.0, 0.22, s);
    let base_y = mix(win_center.y, lip_y + lip_wave, launch_prog);
    let arc_hop = sin(launch_prog * 3.14159265) * 7.5;
    let seed_pos = vec2<f32>(cur_x, base_y - arc_hop);

    // Palet Warna Sakura Kintsugi
    let gold_core   = hex(255.0, 252.0, 240.0); // Putih emas ultra terang
    let gold_warm   = hex(255.0, 208.0, 102.0); // Emas cair bercahaya
    let sakura_pink = hex(255.0, 172.0, 192.0); // Pink sakura anggun

    // ─────────────────────────────────────────────────────────────────────────
    // 1. JEJAK ALIRAN EMAS DI BIBIR OUTLINE TASKBAR (Molten Trail along Lip)
    // ─────────────────────────────────────────────────────────────────────────
    if (p.x >= start_x - 12.0 && p.x <= cur_x + 8.0) {
        let lip_at_p = get_taskbar_lip_y(p.x, cx, half_w, bottom_y, smooth_t, overshoot);
        let wave_p = (sin((p.x - bar_left) * 0.034 + time * 2.8) * 0.65 + sin((p.x - bar_left) * 0.072 - time * 1.5) * 0.35) * 2.4;
        let d_lip = abs(p.y - (lip_at_p + wave_p));

        // Panjang ekor jejak mengalir di belakang seed
        let trail_dx = max(cur_x - p.x, 0.0);
        let trail_fade = exp(-trail_dx / 110.0) * smoothstep(0.04, 0.18, s);

        // Pita emas tipis di garis outline (lebar 1.5 - 3.2px)
        let ribbon_w = mix(3.2, 1.2, clamp(trail_dx / 120.0, 0.0, 1.0));
        let ribbon_mask = (1.0 - smoothstep(0.0, ribbon_w, d_lip)) * trail_fade;
        let ribbon_glow = pow(clamp(1.0 - d_lip / 14.0, 0.0, 1.0), 2.2) * trail_fade * 0.75;

        let trail_col = mix(gold_warm, sakura_pink, clamp(trail_dx / 160.0, 0.0, 0.55));
        let trail_bright = mix(trail_col, gold_core, smoothstep(0.5, 0.0, d_lip) * 0.85);

        col = mix(col, trail_bright, ribbon_mask * 0.96);
        col = mix(col, trail_col, ribbon_glow * 0.55);
        alpha = max(alpha, max(ribbon_mask * 0.95, ribbon_glow * 0.65));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. KEPALA BENIH BERPIJAR (Luminous Seed Head & Pulsing Halo)
    // ─────────────────────────────────────────────────────────────────────────
    let d_seed = length(p - seed_pos);
    let pulse = 0.5 + 0.5 * sin(time * 8.5);

    // Inti benih bulat padat
    let r_core = 3.8 + 0.7 * pulse;
    let core_mask = 1.0 - smoothstep(r_core * 0.25, r_core, d_seed);

    // Halo hangat sekitar benih
    let r_halo = 26.0 + 5.0 * pulse;
    let halo_factor = pow(clamp(1.0 - d_seed / r_halo, 0.0, 1.0), 2.2);

    let seed_glow_col = mix(gold_warm, sakura_pink, 0.35 + 0.15 * sin(time * 4.0));
    col = mix(col, seed_glow_col, halo_factor * 0.70);
    col = mix(col, gold_core, core_mask);
    alpha = max(alpha, max(core_mask, halo_factor * 0.75));

    // ─────────────────────────────────────────────────────────────────────────
    // 3. PERCIKAN EMAS / KELOPAK SAKURA MIKRO (Sparkles & Shimmer Flakes)
    // ─────────────────────────────────────────────────────────────────────────
    for (var i = 0u; i < 6u; i = i + 1u) {
        let fi = f32(i);
        let cyc = fract(time * 0.92 + fi * 0.1666);
        let lag_x = cur_x - cyc * 56.0 - fi * 5.0;

        if (lag_x >= start_x) {
            let lip_sp = get_taskbar_lip_y(lag_x, cx, half_w, bottom_y, smooth_t, overshoot);
            let bob = sin(time * 4.2 + fi * 2.3) * 5.0 - cyc * 3.0;
            let sp_pos = vec2<f32>(lag_x, lip_sp - 3.0 + bob);

            let d_sp = length(p - sp_pos);
            let sp_life = sin(cyc * 3.14159265);
            let sp_mask = (1.0 - smoothstep(0.3, 2.2, d_sp)) * sp_life * smoothstep(0.08, 0.25, s);

            let sp_col = mix(gold_warm, sakura_pink, fi / 6.0);
            col = mix(col, sp_col, sp_mask * 0.85);
            alpha = max(alpha, sp_mask * 0.85);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. KILATAN SAAT TIBA DI TENGAH (Arrival Pulse & Ring Flare at Center)
    // ─────────────────────────────────────────────────────────────────────────
    let arrive = smoothstep(0.85, 1.0, s);
    if (arrive > 0.02) {
        let ring_r = arrive * 24.0;
        let ring_d = abs(d_seed - ring_r);
        let ring_fade = (1.0 - arrive) * arrive * 3.5;
        let ring_mask = (1.0 - smoothstep(0.0, 2.4, ring_d)) * ring_fade;

        let flare_col = mix(gold_core, sakura_pink, 0.45);
        col = mix(col, flare_col, ring_mask * 0.80);
        alpha = max(alpha, ring_mask * 0.80);
    }

    return vec4<f32>(col, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAKURA NEBARI ROOTS (Pangkal Gendut di Tengah + Bentangan Berserabut Dinamis Prosedural)
// ─────────────────────────────────────────────────────────────────────────────

fn hash11_root(p: f32) -> f32 {
    let x = sin(p * 127.1 + 311.7) * 43758.5453;
    return fract(x);
}

fn hash21_root(p: f32) -> vec2<f32> {
    let x = sin(p * 127.1 + 311.7) * 43758.5453;
    let y = sin(p * 269.5 + 183.3) * 43758.5453;
    return vec2<f32>(fract(x), fract(y));
}

/// Perlindungan tabrakan untuk 4 icon dock tengah: akar dilarang menabrak kotak dock
fn eval_dock_keepout_dist(p: vec2<f32>, cx: f32, dock_y: f32) -> f32 {
    let box_half = vec2<f32>(31.5, 31.5); // 28px widget pill + 3.5px margin keselamatan
    let d1 = sd_rounded_box(p - vec2<f32>(cx - 96.0, dock_y), box_half, 15.0);
    let d2 = sd_rounded_box(p - vec2<f32>(cx - 32.0, dock_y), box_half, 15.0);
    let d3 = sd_rounded_box(p - vec2<f32>(cx + 32.0, dock_y), box_half, 15.0);
    let d4 = sd_rounded_box(p - vec2<f32>(cx + 96.0, dock_y), box_half, 15.0);
    return min(min(d1, d2), min(d3, d4));
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIMITIF CABANG MELENGKUNG ORGANIK + NORMAL ANALITIK 1-PASS + STAGED UNFURL
// ─────────────────────────────────────────────────────────────────────────────

/// Titik persis pada tulang punggung kurva cabang di parameter `h` (0.0..1.0).
fn curved_branch_pt(
    a: vec2<f32>,
    b: vec2<f32>,
    bend: f32,
    s_wave: f32,
    h: f32,
) -> vec2<f32> {
    let ba = b - a;
    let len2 = max(dot(ba, ba), 1e-4);
    let dir = ba * inverseSqrt(len2);
    let perp = vec2<f32>(-dir.y, dir.x);
    let arch = 4.0 * h * (1.0 - h);
    let sw = sin(h * 6.2831853) * (1.0 - h * 0.25);
    return a + ba * h + perp * (bend * arch + s_wave * sw);
}

/// SDF cabang melengkung meruncing — versi cepat untuk akar.
fn sd_curved_branch(
    p: vec2<f32>,
    a: vec2<f32>,
    b: vec2<f32>,
    bend: f32,
    s_wave: f32,
    r0: f32,
    r1: f32,
) -> vec2<f32> {
    let pa = p - a;
    let ba = b - a;
    let len2 = max(dot(ba, ba), 1e-4);
    let dir = ba * inverseSqrt(len2);
    let perp = vec2<f32>(-dir.y, dir.x);
    let h = clamp(dot(pa, ba) / len2, 0.0, 1.0);
    let arch = 4.0 * h * (1.0 - h);
    let sw = sin(h * 6.2831853) * (1.0 - h * 0.25);
    let spine = a + ba * h + perp * (bend * arch + s_wave * sw);
    let taper_h = pow(max(h, 0.0001), 0.78);
    let r = mix(r0, r1, taper_h);
    let d = length(p - spine) - r;
    return vec2<f32>(d, h);
}

/// SDF cabang melengkung + normal silinder analitik 2D dengan pertumbuhan progresif `g_seg` (0..1).
/// Saat `g_seg` bergerak dari 0 -> 1 (IN) atau 1 -> 0 (OUT), cabang memanjang/menguncup
/// persis mengikuti tulang punggung kurvanya sendiri (botanical unfurl)!
fn sd_curved_branch_g(
    p: vec2<f32>,
    a: vec2<f32>,
    b: vec2<f32>,
    bend: f32,
    s_wave: f32,
    r0: f32,
    r1: f32,
    g_seg: f32,
) -> vec3<f32> {
    if (g_seg <= 0.005) {
        return vec3<f32>(1e5, 0.0, 0.0);
    }
    let pa = p - a;
    let ba = b - a;
    let len2 = max(dot(ba, ba), 1e-4);
    let dir = ba * inverseSqrt(len2);
    let perp = vec2<f32>(-dir.y, dir.x);
    // Batasi progres h hanya sampai ujung pertumbuhan saat ini (`g_seg`)
    let h = clamp(dot(pa, ba) / len2, 0.0, g_seg);
    let arch = 4.0 * h * (1.0 - h);
    let sw = sin(h * 6.2831853) * (1.0 - h * 0.25);
    // Saat masih muda, lengkungan sedikit lebih kuncup lalu mekar penuh
    let curl_scale = mix(0.62, 1.0, g_seg);
    let spine = a + ba * h + perp * (bend * arch + s_wave * sw) * curl_scale;

    let h_rel = h / max(g_seg, 0.001);
    let taper_h = pow(max(h_rel, 0.0001), 0.78);
    let r_grow = smoothstep(0.0, 0.45, g_seg);
    let r = mix(r0 * r_grow, r1 * g_seg, taper_h);

    let diff = p - spine;
    let dist = length(diff);
    let inv_r = 1.0 / max(r, 1.4);
    let n2 = diff * inv_r;
    let n_len = length(n2);
    let n_clamped = select(n2, n2 / max(n_len, 1e-4), n_len > 1.0);
    return vec3<f32>(dist - r, n_clamped.x, n_clamped.y);
}

/// Smooth minimum kubik untuk cabang sekaligus memadukan normal silinder 2D secara mulus.
fn smin_branch(a: vec3<f32>, b: vec3<f32>, k: f32) -> vec3<f32> {
    let kk = max(k, 0.001);
    let diff = a.x - b.x;
    let h = max(kk - abs(diff), 0.0) / kk;
    let d = min(a.x, b.x) - h * h * h * kk * (1.0 / 6.0);
    let blend = clamp(0.5 + 0.5 * diff / kk, 0.0, 1.0);
    let n = mix(a.yz, b.yz, blend);
    return vec3<f32>(d, n.x, n.y);
}

fn render_sakura_roots(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    bar_left: f32,
    bottom_y: f32,
    smooth_t: f32,
    overshoot: f32,
    g_root: f32,
    time: f32,
    in_col: vec3<f32>,
    in_a: f32,
) -> vec4<f32> {
    if (g_root <= 0.003) {
        return vec4<f32>(in_col, in_a);
    }

    let lip_center_y = get_taskbar_lip_y(cx, cx, half_w, bottom_y, smooth_t, overshoot);

    if (p.y < lip_center_y - 46.0 || p.y > bottom_y + 4.0) {
        return vec4<f32>(in_col, in_a);
    }

    var col = in_col;
    var alpha = in_a;

    let g = clamp(g_root, 0.0, 1.0);
    let g_hub = smoothstep(0.00, 0.42, g);
    let g_span = smoothstep(0.08, 0.96, g);
    let g_branch = smoothstep(0.22, 1.00, g);

    let max_span = half_w * 0.82;
    let cur_span = max_span * g_span;
    let dx = abs(p.x - cx);
    if (dx > cur_span + 44.0) {
        return vec4<f32>(col, alpha);
    }

    // Resonansi kursor pada akar: saat kursor mendekati akar/pangkal, aliran emas menyala lembut
    let m_dist_r = length(p - u.mouse_pos);
    let m_prox_r = exp(-(m_dist_r * m_dist_r) / 14000.0);

    let bark_deep    = hex(58.0, 38.0, 24.0);
    let gold_body    = hex(232.0, 178.0, 84.0);
    let gold_core    = hex(255.0, 244.0, 208.0);
    let sakura_blush = hex(242.0, 164.0, 184.0);

    let r_base_stump = half_w * 2.0 * 0.044;
    let flare_t = clamp(1.0 - abs(dx - r_base_stump * 0.85) / max(r_base_stump * 0.85, 1.0), 0.0, 1.0);
    let nebari_lift = pow(max(clamp(1.0 - dx / max(r_base_stump * 1.25, 1.0), 0.0, 1.0), 0.0001), 1.6) * 7.5 * g_hub;

    // 1. SAYAP AKAR NEBARI TERPILIN ORGANIK
    var d_wings = 1e5;
    if (dx <= cur_span + 30.0) {
        let span_norm = clamp(dx / max(max_span, 1.0), 0.0, 1.0);
        let sample_x = select(cx + sign(p.x - cx) * min(dx, cur_span), p.x, dx <= cur_span);
        let lip_y_x = get_taskbar_lip_y(sample_x, cx, half_w, bottom_y, smooth_t, overshoot);

        let wave_ripple = (sin((sample_x - bar_left) * 0.034 + time * 2.8) * 0.65
                         + sin((sample_x - bar_left) * 0.072 - time * 1.5) * 0.35) * 2.2;
        let lip_runner_y = lip_y_x + wave_ripple;

        let r_warp = (vnoise(vec2<f32>(sample_x * 0.032 + 2.1, p.y * 0.045 + 6.3)) - 0.5) * 6.0
                   * smoothstep(0.04, 0.48, span_norm);

        let meander_a = sin(min(dx, cur_span) * 0.038 - time * 0.65) * 2.6 * smoothstep(0.06, 0.70, span_norm);
        let root_y_a = lip_runner_y + r_warp + meander_a - nebari_lift;

        let taper = pow(max(clamp(1.0 - span_norm, 0.0, 1.0), 0.0001), 0.90);
        let wing_r = mix(0.60, 8.5 + flare_t * 2.6, taper) * min(g_span * 1.15, 1.0);

        let cap_dx = max(dx - cur_span, 0.0);
        let d_trunk_a = length(vec2<f32>(cap_dx, p.y - root_y_a)) - wing_r;

        let meander_b = cos(min(dx, cur_span) * 0.054 + time * 0.55 + 1.15) * 3.6 * smoothstep(0.04, 0.75, span_norm);
        let root_y_b = lip_runner_y - r_warp * 0.65 + meander_b - nebari_lift * 0.62 + 1.4;
        let r_b = max(wing_r * 0.58, 0.55);
        let d_trunk_b = length(vec2<f32>(cap_dx, p.y - root_y_b)) - r_b;

        let dorsal_off = sin(min(dx, cur_span) * 0.095 - time * 0.9 + 0.6) * (wing_r * 0.42 + 1.1);
        let d_dorsal = length(vec2<f32>(cap_dx, p.y - (root_y_a - dorsal_off))) - max(wing_r * 0.34, 0.50);

        let k_braid = 2.6 * taper + 0.75;
        d_wings = smin_cubic(smin_cubic(d_trunk_a, d_trunk_b, k_braid), d_dorsal, k_braid * 0.75);
    }

    // 2. SERABUT CABANG AKAR MELENGKUNG (Dengan Spatial Pruning)
    var d_branches = 1e5;
    let dock_y = lip_center_y + 28.0;

    if (g_branch > 0.02 && p.y >= lip_center_y - 26.0 && p.y <= lip_center_y + 52.0) {
        var d_proc_branches = 1e5;

        if (dx < 82.0) {
            let d_div_c0 = sd_curved_branch(
                p,
                vec2<f32>(cx - 0.5, lip_center_y + 1.0),
                vec2<f32>(cx + 0.5, lip_center_y + 34.0 * g_branch),
                2.2, 2.8, 3.2 * g_branch, 0.55 * g_branch,
            ).x;
            let d_div_c1 = sd_curved_branch(
                p,
                vec2<f32>(cx - 64.0, lip_center_y + 1.5),
                vec2<f32>(cx - 63.0, lip_center_y + 24.0 * g_branch),
                -2.4, 1.4, 2.2 * g_branch, 0.50 * g_branch,
            ).x;
            let d_div_c2 = sd_curved_branch(
                p,
                vec2<f32>(cx + 64.0, lip_center_y + 1.5),
                vec2<f32>(cx + 65.0, lip_center_y + 25.0 * g_branch),
                2.4, -1.4, 2.2 * g_branch, 0.50 * g_branch,
            ).x;
            d_proc_branches = min(d_div_c0, min(d_div_c1, d_div_c2));
        }

        let max_len = 42.0;
        let low_q = u.tree_params.w > 0.5;
        let n_roots: i32 = select(8i, 5i, low_q);
        let is_left = p.x <= cx;

        for (var i: i32 = 0i; i < n_roots; i = i + 1i) {
            let fi = f32(i);
            if (is_left) {
                let rnd_l1 = hash21_root(fi * 17.3 + 3.1);
                let dist_x_l = mix(42.0, cur_span * 0.94, (fi + rnd_l1.x * 0.72) / f32(n_roots));
                let origin_x_l = cx - dist_x_l;
                if (dist_x_l <= cur_span + 4.0 && abs(p.x - origin_x_l) < 54.0) {
                    let rnd_l2 = hash21_root(fi * 31.7 + 7.9);
                    let origin_y_l = get_taskbar_lip_y(origin_x_l, cx, half_w, bottom_y, smooth_t, overshoot);
                    let taper_l = clamp(1.0 - dist_x_l / max(max_span, 1.0), 0.15, 1.0);

                    let branch_type_l = i % 3i;
                    var ang_l = 0.0;
                    var len_l = mix(15.0, max_len * taper_l + 10.0, rnd_l1.y) * g_branch;
                    if (branch_type_l == 0i) {
                        ang_l = mix(-2.45, -2.05, rnd_l2.x);
                        len_l = min(len_l, 20.0);
                    } else {
                        ang_l = mix(0.85, 2.25, rnd_l2.x);
                    }

                    let p0_l = vec2<f32>(origin_x_l, origin_y_l + 0.8);
                    let p2_l = p0_l + vec2<f32>(cos(ang_l), sin(ang_l)) * len_l;
                    let bend_l = (rnd_l2.y - 0.5) * 11.0;
                    let r0_l = mix(1.6, 3.0, rnd_l1.x) * taper_l * g_branch;

                    let d_b_l = sd_curved_branch(p, p0_l, p2_l, bend_l, bend_l * 0.25, r0_l, 0.42 * g_branch).x;
                    d_proc_branches = smin_cubic(d_proc_branches, d_b_l, 1.6 * g_branch);

                    if (!low_q && rnd_l2.x > 0.48 && len_l > 20.0) {
                        let mid_l = curved_branch_pt(p0_l, p2_l, bend_l, bend_l * 0.25, 0.52);
                        let sub_ang_l = ang_l + mix(0.42, 0.82, rnd_l1.y);
                        let sub_end_l = mid_l + vec2<f32>(cos(sub_ang_l), sin(sub_ang_l)) * (len_l * 0.45);
                        let d_sub_l = sd_curved_branch(p, mid_l, sub_end_l, -bend_l * 0.45, 0.0, r0_l * 0.52, 0.35 * g_branch).x;
                        d_proc_branches = smin_cubic(d_proc_branches, d_sub_l, 1.2 * g_branch);
                    }
                }
            } else {
                let rnd_r1 = hash21_root(fi * 23.9 + 5.7);
                let dist_x_r = mix(42.0, cur_span * 0.94, (fi + rnd_r1.x * 0.72) / f32(n_roots));
                let origin_x_r = cx + dist_x_r;
                if (dist_x_r <= cur_span + 4.0 && abs(p.x - origin_x_r) < 54.0) {
                    let rnd_r2 = hash21_root(fi * 41.1 + 11.3);
                    let origin_y_r = get_taskbar_lip_y(origin_x_r, cx, half_w, bottom_y, smooth_t, overshoot);
                    let taper_r = clamp(1.0 - dist_x_r / max(max_span, 1.0), 0.15, 1.0);

                    let branch_type_r = (i + 1i) % 3i;
                    var ang_r = 0.0;
                    var len_r = mix(15.0, max_len * taper_r + 10.0, rnd_r1.y) * g_branch;
                    if (branch_type_r == 0i) {
                        ang_r = mix(-1.05, -0.65, rnd_r2.x);
                        len_r = min(len_r, 20.0);
                    } else {
                        ang_r = mix(0.85, 2.25, rnd_r2.x);
                    }

                    let p0_r = vec2<f32>(origin_x_r, origin_y_r + 0.8);
                    let p2_r = p0_r + vec2<f32>(cos(ang_r), sin(ang_r)) * len_r;
                    let bend_r = (rnd_r2.y - 0.5) * 11.0;
                    let r0_r = mix(1.6, 3.0, rnd_r1.x) * taper_r * g_branch;

                    let d_b_r = sd_curved_branch(p, p0_r, p2_r, bend_r, bend_r * 0.25, r0_r, 0.42 * g_branch).x;
                    d_proc_branches = smin_cubic(d_proc_branches, d_b_r, 1.6 * g_branch);

                    if (!low_q && rnd_r2.x > 0.48 && len_r > 20.0) {
                        let mid_r = curved_branch_pt(p0_r, p2_r, bend_r, bend_r * 0.25, 0.52);
                        let sub_ang_r = ang_r + mix(-0.82, -0.42, rnd_r1.y);
                        let sub_end_r = mid_r + vec2<f32>(cos(sub_ang_r), sin(sub_ang_r)) * (len_r * 0.45);
                        let d_sub_r = sd_curved_branch(p, mid_r, sub_end_r, -bend_r * 0.45, 0.0, r0_r * 0.52, 0.35 * g_branch).x;
                        d_proc_branches = smin_cubic(d_proc_branches, d_sub_r, 1.2 * g_branch);
                    }
                }
            }
        }

        let d_dock_keepout = eval_dock_keepout_dist(p, cx, dock_y);
        d_branches = max(d_proc_branches, -d_dock_keepout + 1.5);
    }

    let d_all_roots = smin_cubic(d_wings, d_branches, 2.6 * g_branch + 0.5);

    if (d_all_roots > 15.0) {
        return vec4<f32>(col, alpha);
    }

    let aa = 1.05;
    let root_mask = 1.0 - smoothstep(-aa, aa, d_all_roots);
    let aura_raw = pow(max(clamp(1.0 - max(d_all_roots, 0.0) / 11.5, 0.0, 1.0), 0.0001), 2.4)
                 * (0.28 + 0.10 * sin(time * 2.0) + m_prox_r * 0.28);

    // Ujung pertumbuhan akar berpijar hangat saat animasi IN/OUT berlangsung
    let grow_front_glow = exp(-abs(dx - cur_span) * 0.08) * sin(g * 3.14159265) * 0.55;
    let tip_gradient = 1.0 - smoothstep(cur_span - 24.0, cur_span + 12.0, dx);
    let aura_glow = aura_raw * tip_gradient;
    let eff_root_mask = root_mask * tip_gradient;

    let norm_depth = clamp(-d_all_roots / 7.5, 0.0, 1.0);
    let core_highlight = pow(max(norm_depth, 0.0001), 1.45);
    let bark_n = vnoise(vec2<f32>(p.x * 0.055 + 1.4, p.y * 0.085 + 3.2));
    let flow = sin(p.x * 0.075 - time * (2.1 + m_prox_r * 1.4) + bark_n * 2.4) * 0.5 + 0.5;

    let r_trunk_base = 38.0 * clamp(u.tree_style.y, 0.75, 1.65);
    let inter_x = 1.0 - smoothstep(r_trunk_base * 0.65, r_trunk_base + 18.0, dx);
    let inter_y = smoothstep(lip_center_y + 14.0, lip_center_y - 24.0, p.y);
    let trunk_inter = inter_x * inter_y * clamp(u.tree_style.x, 0.0, 1.0);

    let eff_bark = mix(bark_deep, gold_body, trunk_inter * 0.72);
    var r_col = mix(eff_bark, gold_body, smoothstep(0.04, 0.52, norm_depth) * (0.78 + 0.22 * bark_n));
    r_col = mix(r_col, gold_core, clamp(core_highlight * (0.58 + 0.34 * flow) + m_prox_r * 0.35 + grow_front_glow, 0.0, 0.96));
    r_col = mix(r_col, sakura_blush, smoothstep(0.42, 0.96, dx / max(max_span, 1.0)) * 0.32);
    r_col = mix(r_col, col, trunk_inter * 0.42);

    let in_water = smoothstep(0.0, 6.0, p.y - lip_center_y);
    let dive_fade = clamp((p.y - lip_center_y) / 48.0, 0.0, 1.0);
    let water_tint = hex(22.0, 48.0, 74.0);
    r_col = mix(r_col, water_tint, in_water * dive_fade * 0.52);

    let aura_col = mix(gold_body, sakura_blush, 0.24);
    col = mix(col, aura_col, aura_glow * 0.48 * g);
    col = mix(col, r_col, eff_root_mask * 0.96);
    alpha = max(alpha, max(eff_root_mask * 0.98, aura_glow * 0.55) * g);

    return vec4<f32>(col, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAKURA TREE TRUNK & FULL WOOD CROWN
// - Staged Botanical Unfurl IN/OUT (Batang -> Primer -> Sekunder -> Ranting)
// - Living Idle Breeze (Gust Propagation + Breathing + Traveling Sap + Pollen)
// - Cursor-Proximity Interaction (Elastic Repulsion Bend + Brush Sway + Kintsugi Awakening)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// DOMAIN TRANSFORMASI DINAMIS POHON SAKURA (ANGIN LIVING IDLE + KURSOR + WARP)
// ─────────────────────────────────────────────────────────────────────────────

fn get_sakura_tree_q(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    lip_center_y: f32,
    h_total: f32,
    time: f32,
) -> vec2<f32> {
    let h_norm = clamp((lip_center_y - p.y) / max(h_total, 1.0), 0.0, 1.25);
    let h_sway = clamp(h_norm, 0.0, 1.0);
    let reach_w = clamp(abs(p.x - cx) / max(half_w, 1.0), 0.0, 1.0);
    let sway_pow = h_sway * sqrt(max(h_sway, 0.0001));
    let tip_flex = sway_pow * (0.65 + 0.55 * reach_w);

    // 1. Multi-layer Living Idle Wind (Breeze + Traveling Gust Wave + Twig Flutter + Breathing)
    let slow_breeze = sin(time * 0.58 + h_sway * 1.6) * 4.6;
    let gust_wave   = sin(time * 1.18 - (p.x - cx) * 0.0055 + h_sway * 2.1) * 2.8;
    let twig_flut   = cos(time * 2.45 + p.x * 0.022 + p.y * 0.015) * 1.1 * reach_w;
    let breath_y    = (sin(time * 0.85 + (p.x - cx) * 0.004) * 1.4 + cos(time * 1.55 + p.x * 0.012) * 0.6) * sway_pow;
    let idle_disp   = vec2<f32>((slow_breeze + gust_wave + twig_flut) * tip_flex, breath_y);

    // 2. Interaksi Kursor Mendekat ke Batang & Dahan (Elastic Bend + Tangential Brush Sway)
    let to_mouse = p - u.mouse_pos;
    let m_dist = length(to_mouse);
    let m_prox = exp(-(m_dist * m_dist) / 18500.0);
    let m_dir = to_mouse / max(m_dist, 1.0);
    let anchor_flex = smoothstep(0.03, 0.28, h_norm) * (0.45 + 0.85 * h_sway + 0.35 * reach_w);
    let elastic_push = m_dir * (11.5 * m_prox * anchor_flex);
    let brush_sway = vec2<f32>(
        u.mouse_slosh * (8.5 + 5.5 * u.mouse_speed) * m_prox * anchor_flex,
        -abs(u.mouse_slosh) * 2.2 * m_prox * anchor_flex,
    );

    // 3. Domain Warp Organik Kayu
    let warp_scale = smoothstep(0.02, 0.32, h_norm);
    let gnarl_x = (vnoise(p * 0.013 + vec2<f32>(3.1, 7.4)) - 0.5) * 12.5 * warp_scale;
    let gnarl_y = (vnoise(p * 0.013 + vec2<f32>(19.3, 2.7)) - 0.5) * 8.5 * warp_scale;
    let bark_w = (vnoise(p * 0.055 + vec2<f32>(1.7, 4.3)) - 0.5) * 2.1 * smoothstep(0.0, 0.14, h_norm);

    return p - idle_disp - elastic_push - brush_sway
         + vec2<f32>(gnarl_x + bark_w * 0.65, gnarl_y + bark_w * 0.45);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAKURA BLOSSOM CANOPY CLUSTERS (Bunga Sakura Asli Sangat Lebat & Rimbun)
// ─────────────────────────────────────────────────────────────────────────────

struct BlossomClusterResult {
    d_back: f32,
    inner_back: f32,
    stage_back: f32,
    rot_back: f32,

    d_front: f32,
    inner_front: f32,
    stage_front: f32,
    rot_front: f32,
};

/// Evaluasi analitis 5 kelopak sakura mekar bertakik halus (sakura cleft)
fn sd_sakura_single(p_rel: vec2<f32>, r_base: f32, rot: f32, open_ratio: f32) -> vec2<f32> {
    let r = length(p_rel);
    let ang = atan2(p_rel.y, p_rel.x) - rot;
    let petal = cos(5.0 * ang);
    let notch = abs(sin(10.0 * ang)) * 0.16;
    let petal_sc = mix(0.12, 0.32, open_ratio);
    let r_flower = r_base * (0.80 + petal_sc * petal - notch * open_ratio);
    return vec2<f32>(r - r_flower, r / max(r_flower, 0.01));
}

/// Evaluasi satu klaster buket bunga sakura super lebat (10 kuntum bertumpuk 2.5D)
fn eval_sakura_blossom_cluster(
    q: vec2<f32>,
    anchor: vec2<f32>,
    cluster_seed: f32,
    g_bloom: f32,
    time: f32,
    cur: BlossomClusterResult,
) -> BlossomClusterResult {
    let rel = q - anchor;
    if (abs(rel.x) > 42.0 || abs(rel.y) > 42.0) {
        return cur;
    }

    var res = cur;
    let rnd = hash21(anchor * 0.08 + vec2<f32>(cluster_seed, cluster_seed * 2.37));

    // 10 kuntum bertumpuk per klaster (radius 6.5px - 14.5px, buket padat melebar):
    let offsets = array<vec2<f32>, 10>(
        vec2<f32>(0.0, 0.0),
        vec2<f32>(14.5, -8.0),
        vec2<f32>(-13.5, 9.5),
        vec2<f32>(8.5, 14.0),
        vec2<f32>(-15.0, -10.5),
        vec2<f32>(16.5, 8.2),
        vec2<f32>(5.2, -16.0),
        vec2<f32>(-8.5, -15.5),
        vec2<f32>(19.5, -3.5),
        vec2<f32>(-18.0, 3.2)
    );
    let base_rads = array<f32, 10>(14.5, 12.8, 12.0, 11.2, 11.5, 10.2, 8.8, 8.2, 7.5, 6.5);
    let stages = array<f32, 10>(1.0, 0.95, 0.92, 0.88, 0.90, 0.85, 0.78, 0.75, 0.45, 0.38);

    for (var i = 0; i < 10; i = i + 1) {
        let f_seed = fract(rnd * (f32(i) + 1.25) * 5.41);
        let g_fl = smoothstep(0.0, 0.40 + 0.60 * stages[i], g_bloom);
        if (g_fl <= 0.01) {
            continue;
        }

        let fl_pos = rel - offsets[i] * g_fl;
        let r_sz = base_rads[i] * g_fl * (0.88 + 0.24 * f_seed);
        let max_r = r_sz * 1.22;
        // Bounding lingkaran instan: lewati komputasi trigonometri jika piksel di luar jangkauan kuntum
        if (dot(fl_pos, fl_pos) > max_r * max_r) {
            continue;
        }

        let rot = f_seed * 6.2831 + sin(time * 1.5 + f_seed * 8.0) * 0.16;
        let fl_stage = clamp(g_bloom * 1.25 - 0.25, 0.0, 1.0) * stages[i];
        let eval_pt = sd_sakura_single(fl_pos, r_sz, rot, fl_stage);
        let d = eval_pt.x;
        let inner = eval_pt.y;

        let is_front = (i % 2 == 0);
        if (is_front) {
            if (d < res.d_front) {
                res.d_front = d;
                res.inner_front = inner;
                res.stage_front = fl_stage;
                res.rot_front = rot;
            }
        } else {
            if (d < res.d_back) {
                res.d_back = d;
                res.inner_back = inner;
                res.stage_back = fl_stage;
                res.rot_back = rot;
            }
        }
    }

    return res;
}

/// Evaluasi 68 jangkar klaster bunga lebat di seluruh kanopi pohon (Mekar Penuh / Mankai)
/// Koordinat pusat istirahat (t=1) Zen Search Pill — sumber kebenaran tunggal
/// bagi dahan penopang, klaster bunga pembingkai, dan kapsul kaca Search Pill.
fn get_search_pill_rest_center(cx: f32, half_w: f32, lip_center_y: f32, win_h: f32) -> vec2<f32> {
    let sx = (half_w / 450.0) * 1.28;
    let h_fork = win_h * 0.42;
    let pill_cx = cx + max(215.0, 195.0 * sx);
    let pill_cy = lip_center_y - h_fork * 0.44;
    return vec2<f32>(pill_cx, pill_cy);
}

fn get_search_results_rest_center(cx: f32, half_w: f32, lip_center_y: f32, win_h: f32) -> vec2<f32> {
    let sx = (half_w / 450.0) * 1.28;
    let h_fork = win_h * 0.42;
    let res_cx = cx - max(215.0, 195.0 * sx);
    let res_cy = lip_center_y - h_fork * 0.76;
    return vec2<f32>(res_cx, res_cy);
}

fn eval_all_sakura_blossoms(
    q: vec2<f32>,
    cx: f32,
    sx: f32,
    half_w: f32,
    y_fork: f32,
    h_crown: f32,
    h_fork: f32,
    g_raw: f32,
    time: f32,
) -> BlossomClusterResult {
    var res: BlossomClusterResult;
    res.d_back = 1e5;
    res.inner_back = 1.0;
    res.stage_back = 1.0;
    res.rot_back = 0.0;
    res.d_front = 1e5;
    res.inner_front = 1.0;
    res.stage_front = 1.0;
    res.rot_front = 0.0;

    let density = u.tree_style.w;
    let g_bloom = smoothstep(0.60, 0.98, g_raw) * density;
    if (g_bloom <= 0.005) {
        return res;
    }

    // 0. Bounding Kanopi Vertikal (Y): Jangan evaluasi bunga jika di luar kanopi mahkota (margin ekstra luas)
    if (q.y < (y_fork - h_crown * 1.25) || q.y > (y_fork + h_fork * 0.88)) {
        return res;
    }

    // Partisi Spasial 3 Dahan Utama (Left Bough, Apex Dome, Right Windswept Bough)
    // Dengan overlap margin luas (>45px) sehingga kuntum bunga TIDAK PERNAH terpotong vertikal/horizontal!
    let x_rel = q.x - cx;

    // 1. DAHAN MAHKOTA KIRI JAUH (Clusters 1..15, x_rel < -140px)
    if (x_rel < -140.0 * sx) {
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - half_w * 0.95, y_fork - h_crown * 0.48), 1.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 394.0 * sx, y_fork - h_crown * 0.62), 2.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 382.0 * sx, y_fork - h_crown * 0.22), 3.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 362.0 * sx, y_fork - h_crown * 0.43), 4.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 340.0 * sx, y_fork - h_crown * 0.55), 5.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 322.0 * sx, y_fork - h_crown * 0.67), 6.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 290.0 * sx, y_fork - h_crown * 0.32), 7.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 278.0 * sx, y_fork - h_crown * 0.46), 8.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 250.0 * sx, y_fork - h_crown * 0.58), 9.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 232.0 * sx, y_fork - h_crown * 0.44), 10.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 228.0 * sx, y_fork - h_crown * 0.88), 11.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 228.0 * sx, y_fork - h_crown * 0.12), 12.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 222.0 * sx, y_fork - h_crown * 0.79), 13.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 200.0 * sx, y_fork - h_crown * 0.62), 14.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 186.0 * sx, y_fork - h_crown * 0.93), 15.0, g_bloom, time, res);
    }

    // 2. DAHAN MAHKOTA KIRI TENGAH (Clusters 16..24, -185px <= x_rel < -40px)
    if (x_rel >= -185.0 * sx && x_rel < -40.0 * sx) {
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 182.0 * sx, y_fork - h_crown * 0.43), 16.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 165.0 * sx, y_fork - h_crown * 0.82), 17.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 150.0 * sx, y_fork - h_crown * 0.32), 18.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 144.0 * sx, y_fork - h_crown * 0.72), 19.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 130.0 * sx, y_fork + 12.0), 20.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 114.0 * sx, y_fork - h_crown * 0.96), 21.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 114.0 * sx, y_fork - h_crown * 0.26), 22.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 85.0 * sx, y_fork - h_crown * 0.38), 23.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 65.0 * sx, y_fork - h_crown * 0.22), 24.0, g_bloom, time, res);
    }

    // 3. DAHAN MAHKOTA PUNCAK DOME (Clusters 25..40, -90px <= x_rel < 60px, q.y di mahkota atas)
    if (x_rel >= -90.0 * sx && x_rel < 60.0 * sx && q.y < (y_fork - h_crown * 0.28)) {
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 6.0 * sx, y_fork - h_crown * 1.00), 25.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 26.0 * sx, y_fork - h_crown * 0.97), 26.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 42.0 * sx, y_fork - h_crown * 0.94), 27.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 80.0 * sx, y_fork - h_crown * 0.88), 28.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 36.0 * sx, y_fork - h_crown * 0.88), 29.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 2.0 * sx, y_fork - h_crown * 0.86), 30.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 30.0 * sx, y_fork - h_crown * 0.78), 31.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 10.0 * sx, y_fork - h_crown * 0.74), 32.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 50.0 * sx, y_fork - h_crown * 0.72), 33.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 24.0 * sx, y_fork - h_crown * 0.65), 34.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 70.0 * sx, y_fork - h_crown * 0.58), 35.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 25.0 * sx, y_fork - h_crown * 0.62), 36.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 15.0 * sx, y_fork - h_crown * 0.50), 37.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 40.0 * sx, y_fork - h_crown * 0.48), 38.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx - 45.0 * sx, y_fork - h_crown * 0.42), 39.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 5.0 * sx, y_fork - h_crown * 0.36), 40.0, g_bloom, time, res);
    }

    // 4. DAHAN MAHKOTA KANAN TENGAH (Clusters 55..67, 35px <= x_rel < 225px)
    if (x_rel >= 35.0 * sx && x_rel < 225.0 * sx) {
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 44.0 * sx, y_fork - h_crown * 0.24), 66.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 52.0 * sx, y_fork - h_crown * 0.78), 65.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 68.0 * sx, y_fork - h_crown * 0.58), 64.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 80.0 * sx, y_fork - h_crown * 0.35), 63.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 92.0 * sx, y_fork - h_crown * 0.84), 62.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 106.0 * sx, y_fork + 8.0), 61.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 118.0 * sx, y_fork - h_crown * 0.92), 60.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 130.0 * sx, y_fork - h_crown * 0.52), 59.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 150.0 * sx, y_fork - h_crown * 0.22), 58.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 156.0 * sx, y_fork - h_crown * 0.66), 57.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 170.0 * sx, y_fork - h_crown * 0.82), 67.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 185.0 * sx, y_fork - h_crown * 0.42), 56.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 198.0 * sx, y_fork - h_crown * 0.90), 55.0, g_bloom, time, res);
    }

    // 5. DAHAN MAHKOTA KANAN LUAR (Clusters 41..54, x_rel >= 200px)
    if (x_rel >= 200.0 * sx) {
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 220.0 * sx, y_fork + 2.0), 53.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 220.0 * sx, y_fork - h_crown * 0.24), 54.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 236.0 * sx, y_fork - h_crown * 0.71), 52.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 245.0 * sx, y_fork - h_crown * 0.54), 51.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 266.0 * sx, y_fork - h_crown * 0.25), 50.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 285.0 * sx, y_fork - h_crown * 0.38), 49.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 310.0 * sx, y_fork - h_crown * 0.16), 48.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 330.0 * sx, y_fork - h_crown * 0.49), 47.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 340.0 * sx, y_fork - h_crown * 0.08), 68.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 356.0 * sx, y_fork - h_crown * 0.22), 46.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 360.0 * sx, y_fork - h_crown * 0.35), 45.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 376.0 * sx, y_fork - h_crown * 0.03), 44.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 398.0 * sx, y_fork - h_crown * 0.44), 43.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + 420.0 * sx, y_fork - h_crown * 0.25), 42.0, g_bloom, time, res);
        res = eval_sakura_blossom_cluster(q, vec2<f32>(cx + half_w * 0.94, y_fork - h_crown * 0.29), 41.0, g_bloom, time, res);
    }

    // 6. KUNTUM BUNGA SAKURA PEMBINGKAI DAHAN KANAN (Search Bar Lampion) & DAHAN KIRI (Hasil Search)
    let lip_y_bl = y_fork + h_fork;
    let pill_cx_bl = cx + max(215.0, 195.0 * sx);
    let pill_cy_bl = lip_y_bl - h_fork * 0.44;
    let pill_bot_bl = pill_cy_bl + 28.0;
    if (abs(q.x - pill_cx_bl) < 360.0 && abs(q.y - pill_cy_bl) < 85.0) {
        // 70: Buket sakura mekar di ujung ranting kanan melengkung ke atas
        res = eval_sakura_blossom_cluster(q, vec2<f32>(pill_cx_bl + 298.0, pill_cy_bl - 22.0), 70.0, g_bloom, time, res);
        // 71: Buket sakura di bawah siku kiri dahan penopang
        res = eval_sakura_blossom_cluster(q, vec2<f32>(pill_cx_bl - 240.0, pill_bot_bl + 22.0), 71.0, g_bloom, time, res);
        // 72: Buket kecil aksen di bawah ujung kanan dahan penopang
        res = eval_sakura_blossom_cluster(q, vec2<f32>(pill_cx_bl + 258.0, pill_bot_bl + 20.0), 72.0, g_bloom, time, res);
    }
    let res_cx_bl = cx - max(215.0, 195.0 * sx);
    let res_cy_bl = pill_cy_bl;
    if (abs(q.x - res_cx_bl) < 360.0 && abs(q.y - res_cy_bl) < 85.0) {
        // 73: Buket sakura di ujung ranting kiri melengkung ke atas
        res = eval_sakura_blossom_cluster(q, vec2<f32>(res_cx_bl - 258.0, res_cy_bl - 18.0), 73.0, g_bloom, time, res);
        // 74: Buket sakura di atas dahan kiri
        res = eval_sakura_blossom_cluster(q, vec2<f32>(res_cx_bl + 160.0, res_cy_bl - 16.0), 74.0, g_bloom, time, res);
    }

    return res;
}

/// Shading ringan khusus kuntum sakura gugur melayang (Hanafubuki)
fn shade_falling_sakura(d_sdf: f32, inner: f32) -> vec4<f32> {
    if (d_sdf > 1.0) {
        return vec4<f32>(0.0);
    }
    let aa = 0.85;
    let petal_mask = 1.0 - smoothstep(-aa, aa, d_sdf);
    let sumi_contour = smoothstep(-1.20, -0.20, d_sdf) * (1.0 - smoothstep(-0.20, aa, d_sdf));
    var c = mix(hex(212.0, 48.0, 92.0), hex(252.0, 184.0, 208.0), smoothstep(0.18, 0.65, inner));
    c = mix(c, hex(255.0, 240.0, 246.0), smoothstep(0.65, 0.95, inner));
    if (inner < 0.28) {
        c = mix(c, hex(255.0, 242.0, 172.0), 1.0 - smoothstep(0.06, 0.26, inner));
    }
    c = mix(c, hex(18.0, 14.0, 18.0), sumi_contour * 0.70);
    return vec4<f32>(c * petal_mask, petal_mask);
}

/// Shading mewah bunga sakura: Sentuhan Kuas Kaligrafi Sumi-e (墨絵) + Emas Murni 24K (金箔/金継ぎ) + Sutra Mawar Mutiara
fn shade_sakura_blossom(
    d_sdf: f32,
    inner: f32,
    stage: f32,
    rot: f32,
    time: f32,
    m_prox: f32,
) -> vec4<f32> {
    if (d_sdf > 1.0) {
        return vec4<f32>(0.0);
    }

    let aa = 0.85;
    let petal_mask = 1.0 - smoothstep(-aa, aa, d_sdf);

    // Palet Warna: Sumi-e Ink + Emas 24K + Kelopak Sutra Sakura Pink
    let sumi_black    = hex(18.0, 14.0, 18.0);      // Tinta sumi pekat (Deep charcoal ink)
    let sumi_wash     = hex(46.0, 24.0, 36.0);      // Sapuan sumi basah keunguan (ink wash)
    let gold_24k      = hex(255.0, 242.0, 172.0);   // Emas murni terang berkilau (Kinpun)
    let gold_kintsugi = hex(238.0, 182.0, 68.0);    // Urat emas kintsugi hangat
    let gold_deep     = hex(198.0, 142.0, 42.0);    // Emas tembaga antik
    let rose_throat   = hex(212.0, 48.0, 92.0);     // Pangkal kelopak merah mawar pekat
    let sakura_pink   = hex(252.0, 184.0, 208.0);   // Pink sakura klasik berkelas
    let sakura_pale   = hex(255.0, 240.0, 246.0);   // Ujung kelopak sutra mutiara lembut

    var col = sakura_pink;

    if (stage < 0.55) {
        // Kuncup muda (Tsubomi): dominasi kuncup merah sumi dengan sentuhan emas
        let bud_dark = mix(sumi_wash, rose_throat, 0.45);
        col = mix(bud_dark, sakura_pink, smoothstep(0.12, 0.88, inner));
        col = mix(col, gold_kintsugi, clamp(1.0 - inner * 1.8, 0.0, 0.70));
    } else {
        // Bunga mekar penuh (Mankai):
        // Gradasi botani: Pangkal dalam crimson -> tubuh pink sakura -> tepi mutiara
        col = mix(rose_throat, sakura_pink, smoothstep(0.16, 0.48, inner));
        col = mix(col, sakura_pale, smoothstep(0.48, 0.86, inner));

        // 1. ESENSI SUMI-INK PADA PANGKAL & VEIN KELOPAK
        // Urat kuas sumi halus (sumi brush striations) menjalar dari tengah
        let vein_ang = rot * 5.0 + inner * 16.0;
        let sumi_vein = smoothstep(0.68, 0.94, abs(sin(vein_ang))) * smoothstep(0.20, 0.65, inner) * (1.0 - smoothstep(0.65, 0.92, inner));
        col = mix(col, sumi_wash, sumi_vein * 0.42);

        // Titik pangkal sumi (Sumi-damari / kelopak menempel pada tangkai)
        let sumi_base = (1.0 - smoothstep(0.04, 0.18, inner));
        col = mix(col, sumi_black, sumi_base * 0.65);

        // 2. ESENSI EMAS 24K (KINTSUGI VEINING & KINPUN SPARKLE)
        // Putik & Benang Sari (Stamen): Gemerlap butiran emas 24K di inti bunga
        if (inner < 0.28) {
            let stamen_hash = fract(sin(inner * 64.0 + rot * 12.0) * 43758.5453);
            let stamen_glitter = mix(gold_kintsugi, gold_24k, stamen_hash);
            let stamen_mask = (1.0 - smoothstep(0.05, 0.26, inner)) * (0.65 + 0.35 * sin(time * 2.2 + rot * 4.0));
            col = mix(col, stamen_glitter, stamen_mask * 0.95);
        }

        // Urat Emas Kintsugi (Golden hairline kintsugi veins) pada lekukan kelopak
        let kintsugi_pat = smoothstep(0.82, 0.96, sin(inner * 32.0 - rot * 7.0 + sin(inner * 14.0))) * smoothstep(0.25, 0.85, inner);
        let gold_spark = mix(gold_deep, gold_24k, 0.65 + 0.35 * sin(time * 3.0 + rot));
        col = mix(col, gold_spark, kintsugi_pat * 0.78);

        // 3. SENTUHAN KINPAKU (SERPIHAN EMAS TIPIS DI TEPI LEKUK KELOPAK)
        let rim_gold = smoothstep(0.86, 0.99, inner) * smoothstep(0.35, 0.85, sin(rot * 5.0 + time * 1.2));
        col = mix(col, gold_24k, rim_gold * 0.45);
    }

    // 4. GARIS KONTUR KUAS SUMI-E (Calligraphic Brushstroke Outline)
    // Tinta sumi mengitari tepi luar kelopak seperti goresan kuas lukisan Jepang kuno
    let sumi_weight = clamp(u.tree_style.z, 0.0, 2.5);
    let sumi_stroke = smoothstep(-1.20, -0.20, d_sdf) * (1.0 - smoothstep(-0.20, aa, d_sdf));
    col = mix(col, sumi_black, sumi_stroke * 0.72 * sumi_weight);

    // Resonansi kursor (aura emas halus saat kursor mendekati bunga)
    col = mix(col, gold_24k, m_prox * 0.22);

    let out_a = petal_mask;
    return vec4<f32>(col * out_a, out_a);
}

fn eval_sakura_tree_sdf_n(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    lip_center_y: f32,
    h_fork: f32,
    h_total: f32,
    thick: f32,
    g_raw: f32,
    time: f32,
) -> vec3<f32> {
    let q = get_sakura_tree_q(p, cx, half_w, lip_center_y, h_total, time);

    let h_crown = max(h_total - h_fork, 1.0);
    // Staged Botanical Unfurl (IN: Batang -> Primer -> Sekunder -> Ranting; OUT: Ranting -> Sekunder -> Primer -> Batang)
    let is_opening = (u._pad0 > 0.5);
    let g_trunk = select(smoothstep(0.00, 0.52, g_raw), smoothstep(0.00, 0.40, g_raw), is_opening);
    let g_prim  = select(smoothstep(0.24, 0.72, g_raw), smoothstep(0.20, 0.62, g_raw), is_opening);
    let g_sec   = select(smoothstep(0.46, 0.86, g_raw), smoothstep(0.42, 0.80, g_raw), is_opening);
    let g_twigs = select(smoothstep(0.66, 0.98, g_raw), smoothstep(0.58, 0.96, g_raw), is_opening);

    let sx = (half_w / 450.0) * 1.28;
    let tg = thick;
    let y_fork = lip_center_y - h_fork;

    let p_base = vec2<f32>(cx + 16.0 * sx, lip_center_y + 20.0);
    let p_fork = vec2<f32>(cx - 52.0 * sx, y_fork);
    let r_base = 42.0 * tg;
    let r_fork = 22.0 * tg;
    let k_tw = 1.6 * tg;

    var res = vec3<f32>(1e5, 0.0, 0.0);

    // 1. BATANG UTAMA + FLARE NEBARI + DAHAN PENOPANG KANAN (LAMPION BESAR) & KIRI (HASIL SEARCH LEBIH TINGGI)
    let pill_cx_tr = cx + max(215.0, 195.0 * sx);
    let pill_cy_tr = lip_center_y - h_fork * 0.44;
    let pill_bot_tr = pill_cy_tr + 38.0;

    let res_cx_tr = cx - max(215.0, 195.0 * sx);
    let res_cy_tr = lip_center_y - h_fork * 0.76;
    let res_bot_tr = res_cy_tr + 18.0;

    let min_shelf_x = min(cx - 380.0 * sx, res_cx_tr - 315.0);
    let max_shelf_x = max(cx + 380.0 * sx, pill_cx_tr + 345.0);
    if (g_trunk > 0.005 && q.x > min_shelf_x && q.x < max_shelf_x && q.y > y_fork - 54.0) {
        let d_trunk = sd_curved_branch_g(q, p_base, p_fork, -14.0 * sx, 6.0 * sx, r_base, r_fork, g_trunk);
        var d_main = d_trunk;
        if (q.y > lip_center_y - h_fork * 0.46) {
            let g_fl = smoothstep(0.00, 0.34, g_raw);
            let d_fl_l = sd_curved_branch_g(
                q,
                vec2<f32>(cx - 68.0 * sx, lip_center_y + 10.0),
                vec2<f32>(cx - 10.0 * sx, lip_center_y - h_fork * 0.30),
                12.0 * sx, 0.0, 7.0 * tg, 18.0 * tg, g_fl,
            );
            let d_fl_r = sd_curved_branch_g(
                q,
                vec2<f32>(cx + 76.0 * sx, lip_center_y + 10.0),
                vec2<f32>(cx + 10.0 * sx, lip_center_y - h_fork * 0.26),
                -12.0 * sx, 0.0, 6.8 * tg, 17.5 * tg, g_fl,
            );
            let d_fl_c = sd_curved_branch_g(
                q,
                vec2<f32>(cx - 22.0 * sx, lip_center_y + 12.0),
                vec2<f32>(cx - 4.0 * sx, lip_center_y - h_fork * 0.20),
                5.0 * sx, 0.0, 10.0 * tg, 15.0 * tg, g_fl,
            );
            let d_flares = smin_branch(smin_branch(d_fl_l, d_fl_r, 4.0 * tg), d_fl_c, 7.0 * tg);
            d_main = smin_branch(d_trunk, d_flares, 12.0 * tg);
        }

        // A. Dahan Penopang Search Bar di Sisi KANAN (Shinboku Uro Kanan — Lampion Besar 570x76px)
        let p_b_origin     = curved_branch_pt(p_base, p_fork, -14.0 * sx, 6.0 * sx, 0.28);
        let p_brace_root   = curved_branch_pt(p_base, p_fork, -14.0 * sx, 6.0 * sx, 0.12);
        let p_cradle_l_cup = vec2<f32>(pill_cx_tr - 285.0, pill_bot_tr - 2.0);
        let p_cradle_l_rim = vec2<f32>(pill_cx_tr - 292.0, pill_cy_tr - 14.0);
        let p_cradle_mid   = vec2<f32>(pill_cx_tr + 6.0,   pill_bot_tr - 2.0);
        let p_cradle_r_cup = vec2<f32>(pill_cx_tr + 282.0, pill_bot_tr - 2.0);
        let p_cradle_r_rim = vec2<f32>(pill_cx_tr + 294.0, pill_cy_tr - 12.0);
        let p_shelf_tip    = vec2<f32>(pill_cx_tr + 338.0, pill_cy_tr - 26.0);
        let p_brace_join   = vec2<f32>(pill_cx_tr - 110.0, pill_bot_tr + 14.0);
        let p_sprop_end    = vec2<f32>(pill_cx_tr + 294.0, pill_bot_tr + 22.0);

        let d_sh0 = sd_curved_branch_g(q, p_b_origin, p_cradle_l_cup, 8.5, 2.0, 15.0 * tg, 11.0 * tg, g_trunk);
        let d_sh_lcup = sd_curved_branch_g(q, p_cradle_l_cup, p_cradle_l_rim, -5.0, -1.0, 11.0 * tg, 6.5 * tg, g_trunk);
        let d_sh1 = sd_curved_branch_g(q, p_cradle_l_cup, p_cradle_mid, 1.2, 0.4, 11.0 * tg, 9.2 * tg, g_trunk);
        let d_sh2 = sd_curved_branch_g(q, p_cradle_mid, p_cradle_r_cup, 1.2, -0.4, 9.2 * tg, 8.0 * tg, g_trunk);
        let d_sh_rcup = sd_curved_branch_g(q, p_cradle_r_cup, p_cradle_r_rim, 4.5, -1.0, 8.0 * tg, 5.2 * tg, g_trunk);
        let d_sbrace = sd_curved_branch_g(q, p_brace_root, p_brace_join, -5.0, 1.0, 9.0 * tg, 4.8 * tg, g_trunk);

        var d_shelf = smin_branch(d_sh0, d_sh_lcup, 6.0 * tg);
        d_shelf = smin_branch(d_shelf, d_sh1, 6.5 * tg);
        d_shelf = smin_branch(d_shelf, d_sh2, 5.5 * tg);
        d_shelf = smin_branch(d_shelf, d_sh_rcup, 5.5 * tg);
        d_shelf = smin_branch(d_shelf, d_sbrace, 6.0 * tg);

        if (g_twigs > 0.005) {
            let d_stip  = sd_curved_branch_g(q, p_cradle_r_rim, p_shelf_tip, 9.5, -2.0, 5.2 * tg, 1.3 * tg, g_twigs);
            let d_sprop = sd_curved_branch_g(q, p_cradle_r_cup, p_sprop_end, -3.5, 0.6, 3.0 * tg, 0.9 * tg, g_twigs);
            d_shelf = smin_branch(d_shelf, smin_branch(d_stip, d_sprop, k_tw), 3.2 * tg);
        }

        // B. DAHAN PENOPANG HASIL SEARCH DI SISI KIRI (Shinboku Uro Kiri — Batang Kiri Lebih Tinggi)
        let p_lb_origin     = curved_branch_pt(p_base, p_fork, -14.0 * sx, 6.0 * sx, 0.58);
        let p_lb_brace      = curved_branch_pt(p_base, p_fork, -14.0 * sx, 6.0 * sx, 0.32);
        let p_lcradle_r_cup = vec2<f32>(res_cx_tr + 215.0, res_bot_tr);
        let p_lcradle_mid   = vec2<f32>(res_cx_tr,         res_cy_tr - 8.0);
        let p_lcradle_l_cup = vec2<f32>(res_cx_tr - 215.0, res_bot_tr);
        let p_lcradle_l_rim = vec2<f32>(res_cx_tr - 228.0, res_cy_tr - 10.0);
        let p_lshelf_tip    = vec2<f32>(res_cx_tr - 264.0, res_cy_tr - 24.0);
        let p_lbrace_join   = vec2<f32>(res_cx_tr + 65.0,  res_bot_tr + 14.0);

        let d_lsh0 = sd_curved_branch_g(q, p_lb_origin, p_lcradle_r_cup, -10.5, 3.0, 14.0 * tg, 9.8 * tg, g_trunk);
        let d_lsh1 = sd_curved_branch_g(q, p_lcradle_r_cup, p_lcradle_mid, -2.0, 0.4, 9.8 * tg, 8.2 * tg, g_trunk);
        let d_lsh2 = sd_curved_branch_g(q, p_lcradle_mid, p_lcradle_l_cup, -2.0, -0.4, 8.2 * tg, 6.8 * tg, g_trunk);
        let d_lsh_lcup = sd_curved_branch_g(q, p_lcradle_l_cup, p_lcradle_l_rim, -5.0, -1.0, 6.8 * tg, 4.6 * tg, g_trunk);
        let d_lsbrace = sd_curved_branch_g(q, p_lb_brace, p_lbrace_join, 7.0, 1.2, 8.0 * tg, 4.2 * tg, g_trunk);

        var d_lshelf = smin_branch(d_lsh0, d_lsh1, 6.0 * tg);
        d_lshelf = smin_branch(d_lshelf, d_lsh2, 5.5 * tg);
        d_lshelf = smin_branch(d_lshelf, d_lsh_lcup, 5.0 * tg);
        d_lshelf = smin_branch(d_lshelf, d_lsbrace, 5.5 * tg);

        if (g_twigs > 0.005) {
            let d_lstip = sd_curved_branch_g(q, p_lcradle_l_rim, p_lshelf_tip, -9.0, -2.0, 4.6 * tg, 1.1 * tg, g_twigs);
            d_lshelf = smin_branch(d_lshelf, d_lstip, 3.0 * tg);
        }

        d_main = smin_branch(d_main, d_shelf, 8.5 * tg);
        d_main = smin_branch(d_main, d_lshelf, 8.5 * tg);
        res = d_main;
    }

    if (g_prim <= 0.005 || q.y > y_fork + 48.0) {
        return res;
    }

    let pl1 = vec2<f32>(cx - 114.0 * sx, y_fork - h_crown * 0.26);
    let pl_split = vec2<f32>(cx - 182.0 * sx, y_fork - h_crown * 0.43);
    let pl_out = vec2<f32>(cx - 278.0 * sx, y_fork - h_crown * 0.46);
    let pr1 = vec2<f32>(cx + 44.0 * sx, y_fork - h_crown * 0.24);
    let pr_elbow = vec2<f32>(cx + 150.0 * sx, y_fork - h_crown * 0.22);
    let pr_out = vec2<f32>(cx + 266.0 * sx, y_fork - h_crown * 0.25);

    let g_p0 = smoothstep(0.00, 0.56, g_prim);
    let g_p1 = smoothstep(0.36, 1.00, g_prim);

    // 2. DAHAN KIRI UTAMA (Continuous SDF tanpa micro-clipping)
    if (q.x < cx + 45.0 * sx) {
        let d_l0 = sd_curved_branch_g(q, p_fork, pl1, -8.0 * sx, 2.5 * sx, r_fork * 0.86, 12.2 * tg, g_p0);
        let d_l1 = sd_curved_branch_g(q, pl1, pl_split, -6.0 * sx, -2.0 * sx, 12.2 * tg, 8.8 * tg, g_p1);
        res = smin_branch(res, smin_branch(d_l0, d_l1, 6.5 * tg), 8.5 * tg);

        if (g_sec > 0.005) {
            let d_ls1 = sd_curved_branch_g(q, pl_split, pl_out, -8.0 * sx, 5.5 * sx, 8.2 * tg, 4.2 * tg, g_sec);
            res = smin_branch(res, d_ls1, 5.0 * tg);

            let pl_up_orig = curved_branch_pt(pl1, pl_split, -6.0 * sx, -2.0 * sx, 0.72);
            let pl_up = vec2<f32>(cx - 144.0 * sx, y_fork - h_crown * 0.72);
            var d_lu = sd_curved_branch_g(q, pl_up_orig, pl_up, -12.0 * sx, 3.0 * sx, 7.2 * tg, 3.5 * tg, g_sec);

            if (g_twigs > 0.005) {
                let g_tw1 = smoothstep(0.00, 0.65, g_twigs);
                let g_tw2 = smoothstep(0.35, 1.00, g_twigs);
                let pl_far1 = vec2<f32>(cx - 362.0 * sx, y_fork - h_crown * 0.43);
                let pl_far2 = vec2<f32>(cx - half_w * 0.95, y_fork - h_crown * 0.48);
                var d_lw = sd_curved_branch_g(q, pl_out, pl_far1, 6.5 * sx, -3.0 * sx, 4.1 * tg, 2.1 * tg, g_tw1);
                d_lw = smin_branch(d_lw, sd_curved_branch_g(q, pl_far1, pl_far2, 5.0 * sx, 0.0, 2.1 * tg, 0.65 * tg, g_tw2), k_tw);
                let pl_s1 = curved_branch_pt(pl_split, pl_out, -8.0 * sx, 5.5 * sx, 0.72);
                d_lw = smin_branch(d_lw, sd_curved_branch_g(q, pl_s1, vec2<f32>(cx - 322.0 * sx, y_fork - h_crown * 0.67), -8.0 * sx, 2.5 * sx, 3.0 * tg, 0.70 * tg, g_tw1), k_tw);
                let pl_s2 = curved_branch_pt(pl_out, pl_far1, 6.5 * sx, -3.0 * sx, 0.64);
                d_lw = smin_branch(d_lw, sd_curved_branch_g(q, pl_s2, vec2<f32>(cx - 394.0 * sx, y_fork - h_crown * 0.62), -6.0 * sx, 0.0, 2.0 * tg, 0.60 * tg, g_tw2), k_tw);
                let pl_s3 = curved_branch_pt(pl_out, pl_far1, 6.5 * sx, -3.0 * sx, 0.78);
                d_lw = smin_branch(d_lw, sd_curved_branch_g(q, pl_s3, vec2<f32>(cx - 382.0 * sx, y_fork - h_crown * 0.22), 7.0 * sx, -2.5 * sx, 1.9 * tg, 0.60 * tg, g_tw2), k_tw);
                res = smin_branch(res, d_lw, 2.8 * tg);

                let lu_a = curved_branch_pt(pl_up_orig, pl_up, -12.0 * sx, 3.0 * sx, 0.62);
                d_lu = smin_branch(d_lu, sd_curved_branch_g(q, lu_a, vec2<f32>(cx - 222.0 * sx, y_fork - h_crown * 0.79), -7.0 * sx, 2.0 * sx, 3.1 * tg, 0.70 * tg, g_twigs), k_tw);
                let lu_tip = vec2<f32>(cx - 186.0 * sx, y_fork - h_crown * 0.93);
                d_lu = smin_branch(d_lu, sd_curved_branch_g(q, pl_up, lu_tip, -8.0 * sx, 2.5 * sx, 3.3 * tg, 0.75 * tg, g_twigs), k_tw);
                let lu_b = curved_branch_pt(pl_up_orig, pl_up, -12.0 * sx, 3.0 * sx, 0.82);
                d_lu = smin_branch(d_lu, sd_curved_branch_g(q, lu_b, vec2<f32>(cx - 114.0 * sx, y_fork - h_crown * 0.96), 7.0 * sx, -2.0 * sx, 2.9 * tg, 0.65 * tg, g_twigs), k_tw);
                let lu_c = curved_branch_pt(pl_up, lu_tip, -8.0 * sx, 2.5 * sx, 0.52);
                d_lu = smin_branch(d_lu, sd_curved_branch_g(q, lu_c, vec2<f32>(cx - 228.0 * sx, y_fork - h_crown * 0.88), -5.0 * sx, 0.0, 1.6 * tg, 0.55 * tg, smoothstep(0.30, 1.0, g_twigs)), k_tw);

                let wp_l1 = curved_branch_pt(p_fork, pl1, -8.0 * sx, 2.5 * sx, 0.88);
                let d_wl1 = sd_curved_branch_g(q, wp_l1, vec2<f32>(cx - 130.0 * sx, y_fork + 12.0), -8.0 * sx, 3.0 * sx, 2.6 * tg, 0.60 * tg, g_twigs);
                let wp_l2 = curved_branch_pt(pl_split, pl_out, -8.0 * sx, 5.5 * sx, 0.22);
                let d_wl2 = sd_curved_branch_g(q, wp_l2, vec2<f32>(cx - 228.0 * sx, y_fork - h_crown * 0.12), -7.0 * sx, 3.0 * sx, 2.4 * tg, 0.60 * tg, g_twigs);
                res = smin_branch(res, smin_branch(d_wl1, d_wl2, k_tw), 2.5 * tg);
            }
            res = smin_branch(res, d_lu, 4.0 * tg);
        }
    }

    // 3. DAHAN PUNCAK DOME TENGAH (Continuous SDF tanpa micro-clipping)
    if (g_sec > 0.005 && q.x > cx - 160.0 * sx && q.x < cx + 120.0 * sx) {
        let pl_ap_orig = curved_branch_pt(p_fork, pl1, -8.0 * sx, 2.5 * sx, 0.76);
        let pl_ap = vec2<f32>(cx - 24.0 * sx, y_fork - h_crown * 0.65);
        var d_ap = sd_curved_branch_g(q, pl_ap_orig, pl_ap, -12.0 * sx, 4.0 * sx, 7.6 * tg, 3.8 * tg, g_sec);

        if (g_twigs > 0.005) {
            let ap_a = curved_branch_pt(pl_ap_orig, pl_ap, -12.0 * sx, 4.0 * sx, 0.68);
            let ap_a_end = vec2<f32>(cx - 80.0 * sx, y_fork - h_crown * 0.88);
            d_ap = smin_branch(d_ap, sd_curved_branch_g(q, ap_a, ap_a_end, -8.0 * sx, 2.0 * sx, 3.4 * tg, 0.70 * tg, g_twigs), k_tw);
            let ap_top = vec2<f32>(cx - 6.0 * sx, y_fork - h_crown * 1.00);
            d_ap = smin_branch(d_ap, sd_curved_branch_g(q, pl_ap, ap_top, 7.0 * sx, -2.5 * sx, 3.6 * tg, 0.75 * tg, g_twigs), k_tw);
            let ap_b = curved_branch_pt(pl_ap_orig, pl_ap, -12.0 * sx, 4.0 * sx, 0.84);
            d_ap = smin_branch(d_ap, sd_curved_branch_g(q, ap_b, vec2<f32>(cx + 36.0 * sx, y_fork - h_crown * 0.88), -7.0 * sx, 2.5 * sx, 3.1 * tg, 0.70 * tg, g_twigs), k_tw);
            let g_sub = smoothstep(0.30, 1.0, g_twigs);
            let ap_c = curved_branch_pt(pl_ap, ap_top, 7.0 * sx, -2.5 * sx, 0.55);
            d_ap = smin_branch(d_ap, sd_curved_branch_g(q, ap_c, vec2<f32>(cx + 26.0 * sx, y_fork - h_crown * 0.97), -5.0 * sx, 0.0, 1.8 * tg, 0.55 * tg, g_sub), k_tw);
            let ap_d = curved_branch_pt(ap_a, ap_a_end, -8.0 * sx, 2.0 * sx, 0.54);
            d_ap = smin_branch(d_ap, sd_curved_branch_g(q, ap_d, vec2<f32>(cx - 42.0 * sx, y_fork - h_crown * 0.94), 4.0 * sx, 0.0, 1.7 * tg, 0.55 * tg, g_sub), k_tw);
        }
        res = smin_branch(res, d_ap, 4.5 * tg);
    }

    // 4. DAHAN KANAN MEKAR JAUH (Continuous SDF tanpa micro-clipping)
    if (q.x > cx - 60.0 * sx) {
        let d_r0 = sd_curved_branch_g(q, p_fork, pr1, -16.0 * sx, 3.0 * sx, r_fork * 0.82, 11.8 * tg, g_p0);
        let d_r1 = sd_curved_branch_g(q, pr1, pr_elbow, -8.0 * sx, 4.5 * sx, 11.8 * tg, 8.4 * tg, g_p1);
        res = smin_branch(res, smin_branch(d_r0, d_r1, 6.5 * tg), 8.5 * tg);

        if (g_sec > 0.005) {
            let d_rs1 = sd_curved_branch_g(q, pr_elbow, pr_out, 10.0 * sx, -6.5 * sx, 7.8 * tg, 4.0 * tg, g_sec);
            res = smin_branch(res, d_rs1, 5.0 * tg);

            let pr_up_orig = curved_branch_pt(pr1, pr_elbow, -8.0 * sx, 4.5 * sx, 0.62);
            let pr_up = vec2<f32>(cx + 156.0 * sx, y_fork - h_crown * 0.66);
            var d_ru = sd_curved_branch_g(q, pr_up_orig, pr_up, 13.0 * sx, -3.5 * sx, 6.8 * tg, 3.4 * tg, g_sec);

            let pr_in_orig = curved_branch_pt(p_fork, pr1, -16.0 * sx, 3.0 * sx, 0.92);
            let pr_in = vec2<f32>(cx + 68.0 * sx, y_fork - h_crown * 0.58);
            d_ru = smin_branch(d_ru, sd_curved_branch_g(q, pr_in_orig, pr_in, -9.0 * sx, 3.0 * sx, 5.8 * tg, 2.8 * tg, g_sec), 4.0 * tg);

            if (g_twigs > 0.005) {
                let g_tw1 = smoothstep(0.00, 0.65, g_twigs);
                let g_tw2 = smoothstep(0.35, 1.00, g_twigs);
                let pr_far1 = vec2<f32>(cx + 356.0 * sx, y_fork - h_crown * 0.22);
                let pr_far2 = vec2<f32>(cx + half_w * 0.94, y_fork - h_crown * 0.29);
                var d_rw = sd_curved_branch_g(q, pr_out, pr_far1, -7.0 * sx, 3.5 * sx, 3.9 * tg, 2.0 * tg, g_tw1);
                d_rw = smin_branch(d_rw, sd_curved_branch_g(q, pr_far1, pr_far2, 6.0 * sx, 0.0, 2.0 * tg, 0.65 * tg, g_tw2), k_tw);
                let pr_s1 = curved_branch_pt(pr_elbow, pr_out, 10.0 * sx, -6.5 * sx, 0.76);
                d_rw = smin_branch(d_rw, sd_curved_branch_g(q, pr_s1, vec2<f32>(cx + 330.0 * sx, y_fork - h_crown * 0.49), 8.5 * sx, -2.5 * sx, 2.9 * tg, 0.70 * tg, g_tw1), k_tw);
                let pr_s2 = curved_branch_pt(pr_out, pr_far1, -7.0 * sx, 3.5 * sx, 0.68);
                d_rw = smin_branch(d_rw, sd_curved_branch_g(q, pr_s2, vec2<f32>(cx + 398.0 * sx, y_fork - h_crown * 0.44), 6.0 * sx, 0.0, 1.9 * tg, 0.60 * tg, g_tw2), k_tw);
                let pr_s3 = curved_branch_pt(pr_out, pr_far1, -7.0 * sx, 3.5 * sx, 0.80);
                d_rw = smin_branch(d_rw, sd_curved_branch_g(q, pr_s3, vec2<f32>(cx + 376.0 * sx, y_fork - h_crown * 0.03), -7.0 * sx, 2.5 * sx, 1.8 * tg, 0.60 * tg, g_tw2), k_tw);
                res = smin_branch(res, d_rw, 2.8 * tg);

                let ru_a = curved_branch_pt(pr_up_orig, pr_up, 13.0 * sx, -3.5 * sx, 0.72);
                d_ru = smin_branch(d_ru, sd_curved_branch_g(q, ru_a, vec2<f32>(cx + 118.0 * sx, y_fork - h_crown * 0.92), -8.0 * sx, 2.5 * sx, 3.1 * tg, 0.70 * tg, g_twigs), k_tw);
                d_ru = smin_branch(d_ru, sd_curved_branch_g(q, pr_up, vec2<f32>(cx + 198.0 * sx, y_fork - h_crown * 0.90), 8.0 * sx, -2.0 * sx, 3.1 * tg, 0.70 * tg, g_twigs), k_tw);
                let ru_b = curved_branch_pt(pr_up_orig, pr_up, 13.0 * sx, -3.5 * sx, 0.85);
                d_ru = smin_branch(d_ru, sd_curved_branch_g(q, ru_b, vec2<f32>(cx + 236.0 * sx, y_fork - h_crown * 0.71), -6.0 * sx, 2.0 * sx, 2.5 * tg, 0.65 * tg, g_twigs), k_tw);
                d_ru = smin_branch(d_ru, sd_curved_branch_g(q, pr_in, vec2<f32>(cx + 92.0 * sx, y_fork - h_crown * 0.84), 6.5 * sx, -2.0 * sx, 2.5 * tg, 0.65 * tg, g_twigs), k_tw);
                let ri_a = curved_branch_pt(pr_in_orig, pr_in, -9.0 * sx, 3.0 * sx, 0.68);
                d_ru = smin_branch(d_ru, sd_curved_branch_g(q, ri_a, vec2<f32>(cx + 52.0 * sx, y_fork - h_crown * 0.78), -5.0 * sx, 0.0, 2.1 * tg, 0.55 * tg, smoothstep(0.25, 1.0, g_twigs)), k_tw);

                // Ranting penopang bunga klaster 56 (yang dilingkari user)
                // Tumbuh anggun ke atas dari dahan horizontal utama (pr_elbow -> pr_out)
                let wp_c56_orig = curved_branch_pt(pr_elbow, pr_out, 10.0 * sx, -6.5 * sx, 0.28);
                let d_t56 = sd_curved_branch_g(
                    q,
                    wp_c56_orig,
                    vec2<f32>(cx + 185.0 * sx, y_fork - h_crown * 0.42),
                    -5.0 * sx, 2.5 * sx,
                    3.2 * tg, 0.75 * tg,
                    g_twigs
                );

                // Ranting penopang bunga klaster 59 (di atas rustup)
                // Tumbuh anggun ke atas dari dahan utama (pr1 -> pr_elbow)
                let wp_c59_orig = curved_branch_pt(pr1, pr_elbow, -8.0 * sx, 4.5 * sx, 0.75);
                let d_t59 = sd_curved_branch_g(
                    q,
                    wp_c59_orig,
                    vec2<f32>(cx + 130.0 * sx, y_fork - h_crown * 0.52),
                    6.0 * sx, -2.0 * sx,
                    3.2 * tg, 0.75 * tg,
                    g_twigs
                );
                res = smin_branch(res, smin_branch(d_t56, d_t59, k_tw), 3.0 * tg);

                let wp_r1 = curved_branch_pt(pr1, pr_elbow, -8.0 * sx, 4.5 * sx, 0.42);
                let d_wr1 = sd_curved_branch_g(q, wp_r1, vec2<f32>(cx + 106.0 * sx, y_fork + 8.0), 8.0 * sx, -3.0 * sx, 2.5 * tg, 0.60 * tg, g_twigs);
                let wp_r2 = curved_branch_pt(pr_elbow, pr_out, 10.0 * sx, -6.5 * sx, 0.40);
                let d_wr2 = sd_curved_branch_g(q, wp_r2, vec2<f32>(cx + 220.0 * sx, y_fork + 2.0), 7.5 * sx, -2.5 * sx, 2.3 * tg, 0.60 * tg, g_twigs);
                res = smin_branch(res, smin_branch(d_wr1, d_wr2, k_tw), 2.5 * tg);
            }
            res = smin_branch(res, d_ru, 4.0 * tg);
        }
    }

    return res;
}

fn render_sakura_stump(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    bar_width: f32,
    bottom_y: f32,
    screen_h: f32,
    smooth_t: f32,
    overshoot: f32,
    g_stump: f32,
    time: f32,
    in_col: vec3<f32>,
    in_a: f32,
) -> vec4<f32> {
    if (g_stump <= 0.003) {
        return vec4<f32>(in_col, in_a);
    }

    let g = clamp(g_stump, 0.0, 1.0);
    let lip_center_y = get_taskbar_lip_y(cx, cx, half_w, bottom_y, smooth_t, overshoot);

    // Ketinggian tetap penuh; pertumbuhan ditangani progresif per-tingkat (Staged Unfurl)!
    let h_fork = screen_h * 0.42;
    let h_total = screen_h * 0.78;
    let stump_base_y = lip_center_y + 30.0;
    let thick = clamp(u.tree_style.y, 0.75, 2.05);

    // Bounding guard cepat (pastikan cabang kiri, ujung kanan dahan penopang & buket sakura mekar penuh tanpa terpotong)
    let sx = (half_w / 450.0) * 1.28;
    let max_reach_x = max(half_w + 260.0, max(205.0, 185.0 * sx) + 420.0);
    if (p.y < (lip_center_y - h_total - 58.0) || p.y > (stump_base_y + 24.0) || abs(p.x - cx) > max_reach_x) {
        return vec4<f32>(in_col, in_a);
    }

    // 1-PASS SDF + ANALYTICAL NORMAL
    let tree_res = eval_sakura_tree_sdf_n(p, cx, half_w, lip_center_y, h_fork, h_total, thick, g, time);
    let d_tree = tree_res.x;

    let q = get_sakura_tree_q(p, cx, half_w, lip_center_y, h_total, time);
    let y_fork = lip_center_y - h_fork;
    let h_crown = max(h_total - h_fork, 1.0);
    var b_res: BlossomClusterResult;
    b_res.d_back = 1e5;
    b_res.inner_back = 1.0;
    b_res.stage_back = 1.0;
    b_res.rot_back = 0.0;
    b_res.d_front = 1e5;
    b_res.inner_front = 1.0;
    b_res.stage_front = 1.0;
    b_res.rot_front = 0.0;
    if (g > 0.58 && u.tree_style.w > 0.005 && q.y < (lip_center_y - 12.0)) {
        b_res = eval_all_sakura_blossoms(q, cx, sx, half_w, y_fork, h_crown, h_fork, g, time);
    }

    let gold_warm  = hex(235.0, 178.0, 76.0);
    let gold_core  = hex(255.0, 242.0, 198.0);
    let sakura_tip = hex(228.0, 152.0, 174.0);

    // Proksimitas kursor untuk resonansi cahaya Kintsugi & aura hangat
    let to_mouse = p - u.mouse_pos;
    let m_dist = length(to_mouse);
    let m_prox = exp(-(m_dist * m_dist) / 16500.0);

    var col = in_col;
    var alpha = in_a;

    // ─────────────────────────────────────────────────────────────────────────
    // GUGURAN BUNGA SAKURA OTENTIK MELAYANG JATUH (HANAFUBUKI - LIGHT & RANDOM)
    // ─────────────────────────────────────────────────────────────────────────
    let hanafubuki_on = (u.tree_params.y > 0.5);
    let in_fall_zone = (p.y > (y_fork - h_crown * 1.25) && p.y < (lip_center_y + 35.0) && abs(p.x - cx) < (half_w + 60.0));

    if (hanafubuki_on && g > 0.68 && in_fall_zone) {
        // Serbuk sari emas berkilau halus di sekitar kanopi
        let mote_fade = (1.0 - smoothstep(12.0, 95.0, d_tree)) * smoothstep(0.68, 0.95, g);
        let drift_p = p + vec2<f32>(
            -time * 8.0 + sin(p.y * 0.035 + time * 1.1) * 6.0,
            time * 11.0 + cos(p.x * 0.03 + time * 0.9) * 4.0,
        );
        let cell_sz = 42.0;
        let cell_id = floor(drift_p / cell_sz);
        let cell_f = fract(drift_p / cell_sz) - vec2<f32>(0.5, 0.5);
        let rnd = hash21(cell_id);
        if (rnd > 0.82 && mote_fade > 0.01) {
            let jitter = vec2<f32>(fract(rnd * 17.3) - 0.5, fract(rnd * 31.7) - 0.5) * 0.55;
            let d_mote = length((cell_f - jitter) * cell_sz);
            let twinkle = 0.45 + 0.55 * sin(time * 2.8 + rnd * 19.0);
            let mote_m = (1.0 - smoothstep(0.2, 1.8, d_mote)) * twinkle * mote_fade * (0.65 + 0.45 * m_prox);
            if (mote_m > 0.01) {
                let mote_col = mix(gold_core, hex(255.0, 240.0, 210.0), fract(rnd * 5.3));
                col = mix(col, mote_col, mote_m * 0.85);
                alpha = max(alpha, mote_m * 0.82);
            }
        }

        // Kuntum Bunga Sakura Otentik yang Melayang Jatuh (Hanafubuki Lebih Sering, Ringan & Random)
        let num_falling = 7;
        for (var k = 0; k < num_falling; k = k + 1) {
            let fk = f32(k);
            let rnd_k = hash21(vec2<f32>(fk * 19.73 + 3.1, fk * 31.17 + 8.9));
            let rnd_k2 = hash21(vec2<f32>(fk * 43.21 + 5.7, fk * 17.89 + 2.3));

            let period = mix(4.8, 9.6, rnd_k);
            let t_off = rnd_k2 * 37.0 + fk * 2.3;
            let progress = fract((time + t_off) / period);

            let x_start = cx + (mix(-0.85, 0.80, rnd_k) * half_w * 0.88);
            let y_start = y_fork - h_crown * mix(0.30, 0.96, rnd_k2);

            let fall_dist = (lip_center_y + 24.0) - y_start;
            let y_curr = y_start + progress * fall_dist;

            let sway_freq = mix(3.2, 5.5, rnd_k);
            let sway_amp = mix(22.0, 48.0, rnd_k2);
            let sway = sin(progress * sway_freq * 3.14159) * sway_amp;
            let wind_drift = progress * mix(35.0, 80.0, rnd_k);
            let x_curr = x_start + wind_drift + sway;

            let fl_anchor = vec2<f32>(x_curr, y_curr);
            let rel_p = p - fl_anchor;

            // Bounding box super cepat: hanya piksel yang bersentuhan dengan bunga yang dievaluasi
            if (abs(rel_p.x) < 17.0 && abs(rel_p.y) < 17.0) {
                let tumble_pitch = cos(progress * sway_freq * 3.14159 * 1.4 + rnd_k * 6.28);
                let tilt_scale_y = mix(0.24, 1.0, abs(tumble_pitch));
                let rot_fl = progress * mix(2.2, 4.8, rnd_k2) + rnd_k * 6.28;

                let p_tumbled = vec2<f32>(rel_p.x, rel_p.y / max(tilt_scale_y, 0.18));
                let r_fl = mix(7.0, 9.8, rnd_k);

                let eval_fall = sd_sakura_single(p_tumbled, r_fl, rot_fl, 1.0);
                let d_fall = eval_fall.x;
                let inner_fall = eval_fall.y;

                if (d_fall <= 1.0) {
                    let life_fade = smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
                    let fall_fl = shade_falling_sakura(d_fall, inner_fall);
                    let fall_a = fall_fl.w * life_fade * (0.82 + 0.18 * tilt_scale_y);

                    if (fall_a > 0.002) {
                        let fl_rgb = fall_fl.xyz / max(fall_fl.w, 0.001);
                        col = mix(col, fl_rgb, fall_a);
                        alpha = max(alpha, fall_a);
                    }
                }
            }
        }
    }

    let has_tree = (d_tree <= 12.0);
    let has_back_fl = (b_res.d_back <= 1.0);
    let has_front_fl = (b_res.d_front <= 1.0);

    if (!has_tree && !has_back_fl && !has_front_fl) {
        return vec4<f32>(col, alpha);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. LAPISAN BELAKANG BUNGA SAKURA (Di belakang dahan/ranting)
    // ─────────────────────────────────────────────────────────────────────────
    if (has_back_fl) {
        let back_fl = shade_sakura_blossom(b_res.d_back, b_res.inner_back, b_res.stage_back, b_res.rot_back, time, m_prox);
        if (back_fl.w > 0.002) {
            let fl_rgb = back_fl.xyz / max(back_fl.w, 0.001);
            col = mix(col, fl_rgb, back_fl.w);
            alpha = max(alpha, back_fl.w);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. BADAN POHON, DAHAN, ALUR KULIT KAYU & KINTSUGI EMAS
    // ─────────────────────────────────────────────────────────────────────────
    if (has_tree) {
        let aa = 1.0;
        let fade_edge = smoothstep(0.0, 0.14, g);
        let tree_mask = (1.0 - smoothstep(-aa, aa, d_tree)) * fade_edge;
        let aura_r = 8.0 + m_prox * 4.5;
        let aura_glow = pow(max(clamp(1.0 - max(d_tree, 0.0) / aura_r, 0.0, 1.0), 0.0001), 2.4)
                      * (0.14 + 0.04 * sin(time * 1.8) + m_prox * 0.24) * fade_edge;

        let aura_col = gold_warm;
        col = mix(col, aura_col, aura_glow);
        alpha = max(alpha, aura_glow * 0.78);

        if (tree_mask > 0.002) {
            let gx = tree_res.y;
            let gy = tree_res.z;
            let edge_mag = clamp(sqrt(gx * gx + gy * gy), 0.0, 1.0);
            let nz = sqrt(max(1.0 - edge_mag * edge_mag * 0.84, 0.16));

            let depth_in = clamp(-d_tree / max(15.0 * thick, 8.0), 0.0, 1.0);
            let bark_f = vnoise(vec2<f32>(p.x * 0.042 + 1.3, p.y * 0.022 + 4.7));
            let bark_fine = vnoise(vec2<f32>(p.x * 0.105 + 8.1, p.y * 0.060 + 2.2));
            let bark_ridge = bark_f * 0.65 + bark_fine * 0.35;
            let lenticels = smoothstep(0.60, 0.80, vnoise(vec2<f32>(p.x * 0.05, p.y * 0.24 + bark_f * 1.6)))
                          * smoothstep(0.18, 0.70, depth_in);

            let bump = (bark_ridge - 0.5) * 0.38;
            let n3 = normalize(vec3<f32>(gx + bump * 0.28, gy - bump * 0.22, nz));

            let light_dir = normalize(vec3<f32>(-0.46, -0.78, 0.42));
            let ndl = clamp(dot(n3, light_dir), 0.0, 1.0);
            let key_lit = smoothstep(0.10, 0.88, ndl);

            let bark_shadow = hex(26.0, 18.0, 16.0);
            let bark_base   = hex(62.0, 44.0, 38.0);
            let bark_mid    = hex(98.0, 74.0, 62.0);
            let bark_lit    = hex(158.0, 130.0, 110.0);
            let lenticel_c  = hex(142.0, 98.0, 76.0);
            let sky_bounce  = hex(48.0, 82.0, 114.0);

            var wood_col = mix(bark_shadow, bark_base, smoothstep(0.0, 0.45, ndl));
            wood_col = mix(wood_col, bark_mid, bark_ridge * 0.65 * (0.35 + 0.65 * key_lit));
            wood_col = mix(wood_col, bark_lit, pow(max(key_lit, 0.0001), 1.65) * (0.45 + 0.55 * bark_ridge));
            wood_col = mix(wood_col, lenticel_c, lenticels * 0.32 * (0.40 + 0.60 * key_lit));

            let bounce_m = clamp(n3.y, 0.0, 1.0) * smoothstep(0.15, 0.85, edge_mag) * 0.28;
            wood_col = mix(wood_col, sky_bounce, bounce_m);

            let h_norm = clamp((lip_center_y - p.y) / max(h_total, 1.0), 0.0, 1.0);
            let fissure_n = fbm(vec2<f32>(p.x * 0.026 + bark_f * 1.2 + 5.2, p.y * 0.017 - 1.3));
            let fissure_ridge = 1.0 - abs(fissure_n - 0.5) * 2.0;

            let k_thresh = 0.82 - m_prox * 0.07;
            let kintsugi_base = pow(max(clamp((fissure_ridge - k_thresh) / max(1.0 - k_thresh, 0.05), 0.0, 1.0), 0.0001), 2.1)
                              * smoothstep(0.06, 0.52, depth_in)
                              * mix(1.0, 0.34 + m_prox * 0.45, h_norm);

            let sap_front = fract(time * 0.16);
            let sap_band = exp(-pow((h_norm - sap_front) * 6.2, 2.0));
            let cursor_ripple = (0.5 + 0.5 * sin(m_dist * 0.085 - time * 5.2)) * m_prox;
            let grow_pulse = exp(-pow((h_norm - g) * 7.0, 2.0)) * sin(g * 3.14159265);

            let k_boost = clamp(kintsugi_base * (0.86 + 0.42 * sap_band + 0.55 * m_prox + 0.30 * cursor_ripple), 0.0, 0.98);
            let gold_col = mix(gold_warm, gold_core, clamp(pow(max(k_boost, 0.0001), 1.25) * (0.65 + 0.35 * sap_band) + m_prox * 0.35, 0.0, 1.0));
            var r_col = mix(wood_col, gold_col, k_boost);

            r_col = mix(r_col, gold_core, grow_pulse * 0.42);

            let base_melt = (1.0 - smoothstep(0.0, 0.15, h_norm)) * smoothstep(0.08, 0.72, depth_in);
            r_col = mix(r_col, mix(gold_warm, gold_core, 0.42), base_melt * 0.58);

            let rim = smoothstep(0.55, 0.96, edge_mag) * smoothstep(0.35, 0.90, ndl);
            let cursor_dir_2d = normalize(-to_mouse + vec2<f32>(0.0001, 0.0001));
            let cursor_rim = smoothstep(0.42, 0.95, edge_mag) * clamp(dot(vec2<f32>(gx, gy), cursor_dir_2d), 0.0, 1.0) * m_prox;
            r_col = mix(r_col, mix(gold_core, sakura_tip, h_norm * 0.45), rim * 0.30);
            r_col = mix(r_col, gold_core, cursor_rim * 0.55);

            col = mix(col, r_col, tree_mask * 0.98);
            alpha = max(alpha, tree_mask * 0.98);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LAPISAN DEPAN BUNGA SAKURA (Di depan dahan/ranting — efek 3D tumpang tindih)
    // ─────────────────────────────────────────────────────────────────────────
    if (has_front_fl) {
        let front_fl = shade_sakura_blossom(b_res.d_front, b_res.inner_front, b_res.stage_front, b_res.rot_front, time, m_prox);
        if (front_fl.w > 0.002) {
            let fl_rgb = front_fl.xyz / max(front_fl.w, 0.001);
            col = mix(col, fl_rgb, front_fl.w);
            alpha = max(alpha, front_fl.w);
        }
    }

    return vec4<f32>(col, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 TANZAKU RESULT TAGS DI DAHAN KIRI (Slip Gantungan Hasil Pencarian)
// ─────────────────────────────────────────────────────────────────────────────
fn render_tanzaku_tags(
    p: vec2<f32>,
    res_center: vec2<f32>,
    results_t: f32,
    sel_idx: f32,
    time: f32,
    mouse_pos: vec2<f32>,
    in_col: vec3<f32>,
    in_a: f32,
) -> vec4<f32> {
    if (results_t <= 0.005) {
        return vec4<f32>(in_col, in_a);
    }

    var col = in_col;
    var alpha = in_a;
    let aa = 0.85;

    let tag_hw = 220.0;
    let tag_hh = 21.0;
    let tag_r  = 7.0;

    // 1. TALI GANTUNGAN SUTRA DARI DAHAN KIRI SAKURA
    let cord_x_left  = res_center.x - 198.0;
    let cord_x_right = res_center.x + 198.0;
    let cord_top_y   = res_center.y - 8.0;
    let cord_bot_y   = res_center.y + 18.0 + 4.0 * 50.0 + 21.0;

    let in_cord_strip = (abs(p.x - cord_x_left) < 3.0 || abs(p.x - cord_x_right) < 3.0)
                     && (p.y >= cord_top_y && p.y <= cord_bot_y);
    if (in_cord_strip) {
        let d_cord_l = abs(p.x - cord_x_left) - 0.75;
        let d_cord_r = abs(p.x - cord_x_right) - 0.75;
        let d_cords = min(d_cord_l, d_cord_r);
        if (d_cords <= 1.0) {
            let cord_m = (1.0 - smoothstep(-aa, aa, d_cords)) * results_t * 0.65;
            let cord_c = hex(215.0, 180.0, 115.0);
            col = mix(col, cord_c, cord_m);
            alpha = max(alpha, cord_m);
        }
    }

    // 2. 5 TANZAKU RESULT TAGS DI DAHAN KIRI
    for (var i = 0u; i < 5u; i = i + 1u) {
        let fi = f32(i);
        let cascade_raw = clamp((results_t - fi * 0.065) / 0.74, 0.0, 1.0);
        let cascade = cascade_raw * cascade_raw * (3.0 - 2.0 * cascade_raw);
        if (cascade <= 0.005) {
            continue;
        }

        let tag_cy = res_center.y + 18.0 + fi * 50.0 + 21.0;
        let drop_offset = (1.0 - cascade) * 16.0;
        let eff_cy = tag_cy + drop_offset;

        // Ayunan pendulum lembut khas kertas gantung
        let tag_sway = sin(time * 2.1 + fi * 0.72) * (1.1 * cascade);
        let tag_center = vec2<f32>(res_center.x + tag_sway, eff_cy);

        let d_tag = sd_rounded_box(p - tag_center, vec2<f32>(tag_hw, tag_hh), tag_r);
        if (d_tag > 14.0) {
            continue;
        }

        let is_selected = (abs(sel_idx - fi) < 0.45);
        let d_mouse_tag = sd_rounded_box(mouse_pos - tag_center, vec2<f32>(tag_hw, tag_hh), tag_r);
        let is_tag_hover = (1.0 - smoothstep(-2.0, 8.0, d_mouse_tag)) * cascade;

        let active_state = clamp(select(0.0, 1.0, is_selected) + is_tag_hover * 0.65, 0.0, 1.0);

        // Ambient contact shadow / soft backlight
        let d_shad = max(d_tag, 0.0);
        let shad_m = exp(-d_shad * 0.22) * (0.28 + active_state * 0.25) * cascade;
        if (shad_m > 0.005) {
            let shad_col = mix(hex(10.0, 10.0, 14.0), hex(242.0, 192.0, 110.0), active_state * 0.42);
            col = mix(col, shad_col, shad_m * 0.65);
            alpha = max(alpha, shad_m * 0.55);
        }

        if (d_tag <= 1.0) {
            let fill_m = (1.0 - smoothstep(-aa, aa, d_tag)) * cascade;
            let q_tag = (p - tag_center) / vec2<f32>(tag_hw, tag_hh);

            // Warna dasar: Kaca Urushi pekat dan opak anti tembus pandang teks terminal
            var base_glass = mix(hex(10.0, 11.0, 16.0), hex(18.0, 19.0, 28.0), smoothstep(-1.0, 1.0, q_tag.y));
            if (active_state > 0.01) {
                let warm_tint = mix(hex(25.0, 28.0, 42.0), hex(36.0, 38.0, 56.0), smoothstep(-1.0, 1.0, q_tag.y));
                base_glass = mix(base_glass, warm_tint, active_state);
            }

            // Kilatan kursor di atas slip gantungan
            let cur_rel = length((p - mouse_pos) * vec2<f32>(0.65, 1.0));
            let cur_glow = exp(-(cur_rel * cur_rel) / 4800.0) * is_tag_hover;
            base_glass = base_glass + hex(240.0, 198.0, 115.0) * (cur_glow * 0.095);

            // Garis aksen emas vertikal di sisi kiri (Kinpun accent bar)
            let left_accent_x = tag_center.x - tag_hw + 3.0;
            let d_accent_bar = abs(p.x - left_accent_x) - 1.25;
            if (d_accent_bar <= 1.0) {
                let bar_m = 1.0 - smoothstep(-aa, aa, d_accent_bar);
                let bar_col = mix(hex(210.0, 175.0, 112.0), hex(255.0, 228.0, 150.0), active_state);
                base_glass = mix(base_glass, bar_col, bar_m * (0.65 + active_state * 0.35));
            }

            // Best Match (Item 0): Sentuhan emas Kintsugi halus di sudut kanan
            if (i == 0u) {
                let bm_glow = exp(-abs(p.x - (tag_center.x + tag_hw - 42.0)) / 36.0) * 0.12 * cascade;
                base_glass = base_glass + hex(245.0, 205.0, 120.0) * bm_glow;
            }

            // Hairline Border Kintsugi emas
            let border_w = 1.05;
            let border_m = smoothstep(-aa, 0.0, d_tag + border_w) * (1.0 - smoothstep(0.0, aa, d_tag));
            let gold_border = mix(hex(145.0, 122.0, 84.0), hex(248.0, 215.0, 142.0), active_state);
            base_glass = mix(base_glass, gold_border, border_m * (0.55 + active_state * 0.45));

            let final_tag_a = (0.98 + active_state * 0.015) * fill_m;
            col = mix(col, base_glass, final_tag_a);
            alpha = max(alpha, final_tag_a);
        }
    }

    return vec4<f32>(col, alpha);
}

/// Render Zen Search Pill & Hasil Search (Dahan Kanan: Searchbar Lampion, Dahan Kiri: Hasil Search Tanzaku)
fn render_zen_search_pill(
    p: vec2<f32>,
    cx: f32,
    half_w: f32,
    bottom_y: f32,
    smooth_t: f32,
    overshoot: f32,
    search_t: f32,
    time: f32,
    mouse_pos: vec2<f32>,
    in_col: vec3<f32>,
    in_a: f32,
) -> vec4<f32> {
    if (search_t <= 0.003) {
        return vec4<f32>(in_col, in_a);
    }

    let lip_center_y = get_taskbar_lip_y(cx, cx, half_w, bottom_y, smooth_t, overshoot);
    let is_opening = (u._pad0 > 0.5);
    let t_lin = clamp(search_t, 0.0, 1.0);
    let t_sc = smoothstep(0.0, 1.0, t_lin);
    let over_t = max(search_t - 1.0, 0.0);

    // Mekar organik (IN) & surut halus (OUT)
    let expand_x = select(pow(t_sc, 0.85), smoothstep(0.0, 0.92, t_lin), is_opening) + over_t * 0.16;
    let expand_y = smoothstep(0.0, 0.68, t_lin) + over_t * 0.12;
    let rise = (1.0 - t_sc) * 14.0;

    // Dahan KANAN: Tempat Search Bar (bergaya Lampion)
    let pill_rest = get_search_pill_rest_center(cx, half_w, lip_center_y, u.screen_size.y);
    let anchor_shift_x = -(1.0 - clamp(expand_x, 0.0, 1.0)) * 96.0;
    let pill_center = pill_rest + vec2<f32>(anchor_shift_x, rise);

    // Dahan KIRI: Tempat Hasil Search (Tanzaku Tags)
    let res_rest = get_search_results_rest_center(cx, half_w, lip_center_y, u.screen_size.y);
    let res_center = res_rest + vec2<f32>(-anchor_shift_x, rise);

    let full_hw = 285.0;
    let full_hh = 38.0;
    let pill_hw = max(38.0, full_hw * clamp(expand_x, 0.0, 1.04));
    let pill_hh = max(18.0, full_hh * clamp(expand_y, 0.0, 1.03));

    let results_t = clamp(u.clock_time.w, 0.0, 1.0);

    // Bounding Box Partisi Spasial Ekstrem (Kanan: Search Bar Lampion Besar, Kiri: Hasil Search)
    let in_right_bar = (abs(p.x - pill_center.x) <= (pill_hw + 36.0)) && (abs(p.y - pill_center.y) <= (pill_hh + 36.0));
    let in_left_results = (results_t > 0.005)
        && (abs(p.x - res_center.x) <= 245.0)
        && (p.y >= (res_center.y - 14.0) && p.y <= (res_center.y + 285.0 * results_t));

    if (!in_right_bar && !in_left_results) {
        return vec4<f32>(in_col, in_a);
    }

    var col = in_col;
    var alpha = in_a;

    // 1. HASIL SEARCH DI DAHAN KIRI (5 Tanzaku Tags menggantung di dahan kiri baru)
    if (in_left_results) {
        let tags_res = render_tanzaku_tags(p, res_center, results_t, u.font_scales.z, time, mouse_pos, col, alpha);
        col = tags_res.rgb;
        alpha = tags_res.a;
    }

    // 2. SEARCH BAR BENTUK LAMPION BESAR DI DAHAN KANAN
    if (in_right_bar) {
        let pill_r  = min(pill_hw, pill_hh);
        let d_box = sd_rounded_box(p - pill_center, vec2<f32>(pill_hw, pill_hh), pill_r);

        // Ambient contact shadow / warm glow di ceruk dahan kanan
        let shadow_dist = max(d_box, 0.0);
        let shadow_glow = exp(-shadow_dist * 0.12) * 0.38 * t_sc;
        if (shadow_glow > 0.004) {
            let cradle_shadow = mix(hex(12.0, 10.0, 14.0), hex(24.0, 18.0, 14.0), smoothstep(-8.0, 32.0, p.y - pill_center.y));
            col = mix(col, cradle_shadow, shadow_glow * 0.65);
            alpha = max(alpha, shadow_glow * 0.52);
        }

        let typing_energy = clamp(u.font_scales.w, 0.0, 1.0);
        let d_mouse = sd_rounded_box(mouse_pos - pill_center, vec2<f32>(pill_hw, pill_hh), pill_r);
        let is_hover = 1.0 - smoothstep(-2.0, 10.0, d_mouse);

        if (d_box <= 1.2) {
            let aa = 1.0;
            let fill_mask = 1.0 - smoothstep(-aa, aa, d_box);

            let q_norm = (p - pill_center) / vec2<f32>(max(pill_hw, 1.0), max(pill_hh, 1.0));
            let radial_d = length(q_norm * vec2<f32>(0.55, 1.0));

            // A. BADAN LAMPION KERTAS WASHI TEBAL & OPAK (Anti tembus pandang teks terminal/background)
            // Latar belakang hitam Urushi pekat untuk keterbacaan teks maksimal
            var lantern_glass = mix(hex(12.0, 11.0, 16.0), hex(20.0, 18.0, 26.0), smoothstep(-0.9, 0.9, q_norm.y));
            let warm_inner = mix(hex(255.0, 238.0, 180.0), hex(240.0, 160.0, 70.0), clamp(radial_d * 0.78, 0.0, 1.0));
            let flame_breath = 0.92 + 0.08 * sin(time * 3.4 + q_norm.x * 2.0);
            lantern_glass += warm_inner * (0.055 + is_hover * 0.04 + typing_energy * 0.09) * flame_breath;

            // B. RUSUK CINCIN BAMBU HORIZONTAL (Higo Rings khas Lampion)
            let higo_rings = smoothstep(0.74, 0.98, abs(cos((p.x - pill_center.x) * 0.18)));
            lantern_glass = mix(lantern_glass, hex(14.0, 12.0, 18.0), higo_rings * 0.18);

            // C. TUTUP KAYU URUSHI BERTEPI EMAS DI KIRI & KANAN (End Caps silinder lampion)
            let is_left_cap  = smoothstep(pill_hw - 32.0, pill_hw - 12.0, -(p.x - pill_center.x));
            let is_right_cap = smoothstep(pill_hw - 32.0, pill_hw - 12.0,  (p.x - pill_center.x));
            let is_caps = max(is_left_cap, is_right_cap);
            if (is_caps > 0.01) {
                let cap_wood = mix(hex(22.0, 18.0, 20.0), hex(36.0, 28.0, 28.0), smoothstep(-0.8, 0.8, q_norm.y));
                lantern_glass = mix(lantern_glass, cap_wood, is_caps * 0.65);
            }

            // D. KILAU CAHAYA KURSOR & KINTSUGI SWEEP
            let cursor_rel = length((p - mouse_pos) * vec2<f32>(0.55, 1.0));
            let cursor_pool = exp(-(cursor_rel * cursor_rel) / 7200.0) * is_hover;
            lantern_glass += hex(248.0, 205.0, 120.0) * (cursor_pool * 0.11);

            let sweep_prog = smoothstep(0.35, 0.98, t_lin);
            let sweep_x = mix(-pill_hw - 60.0, pill_hw + 60.0, sweep_prog);
            let sweep_band = exp(-pow((p.x - pill_center.x - sweep_x + (p.y - pill_center.y) * 0.6) / 38.0, 2.0));
            let sweep_fade = sin(sweep_prog * 3.14159265);
            lantern_glass += hex(255.0, 228.0, 155.0) * (sweep_band * sweep_fade * 0.18);

            // E. IKON ZEN ENSŌ CALLIGRAPHIC & DIVIDER (Ukuran proporsional lampion besar)
            let icon_reveal = smoothstep(0.28, 0.78, t_lin);
            if (icon_reveal > 0.01) {
                let icon_cx = pill_center.x - pill_hw + 38.0;
                let icon_cy = pill_center.y;
                let p_icon = p - vec2<f32>(icon_cx, icon_cy);
                let ang_icon = atan2(p_icon.y, p_icon.x);
                let brush_var = 1.15 + 0.36 * sin(ang_icon - 0.8);
                let r_enso = 9.8;
                let d_enso_ring = abs(length(p_icon) - r_enso) - brush_var;
                let d_handle = sd_seg(p_icon, vec2<f32>(6.8, 6.8), vec2<f32>(14.0, 14.0)) - 1.35;
                let d_lens = min(d_enso_ring, d_handle);

                let icon_glow = exp(-max(d_lens, 0.0) * 0.42) * (0.16 + is_hover * 0.16 + typing_energy * 0.24);
                let icon_color = mix(hex(205.0, 178.0, 128.0), hex(255.0, 222.0, 148.0), clamp(is_hover * 0.55 + typing_energy * 0.70, 0.0, 1.0));
                let icon_mask = (1.0 - smoothstep(-aa, aa, d_lens)) * icon_reveal;
                lantern_glass = mix(lantern_glass, icon_color, icon_mask * 0.88);
                lantern_glass += icon_color * (icon_glow * icon_reveal);

                let div_x = pill_center.x - pill_hw + 68.0;
                let d_div = abs(p.x - div_x);
                let div_v_fade = 1.0 - smoothstep(10.0, 22.0, abs(p.y - pill_center.y));
                let div_mask = (1.0 - smoothstep(0.0, 1.0, d_div)) * div_v_fade * icon_reveal;
                lantern_glass = mix(lantern_glass, hex(205.0, 175.0, 120.0), div_mask * (0.28 + typing_energy * 0.25));

                let badge_center = vec2<f32>(pill_center.x + pill_hw - 42.0, pill_center.y);
                let d_badge = sd_rounded_box(p - badge_center, vec2<f32>(27.0, 14.5), 7.0);
                if (d_badge <= 1.0) {
                    let badge_fill = 1.0 - smoothstep(-0.7, 0.7, d_badge);
                    let badge_rim = smoothstep(-0.9, 0.0, d_badge + 0.85) * (1.0 - smoothstep(0.0, 0.8, d_badge));
                    lantern_glass = mix(lantern_glass, hex(28.0, 30.0, 40.0), badge_fill * 0.48 * icon_reveal);
                    lantern_glass = mix(lantern_glass, hex(198.0, 170.0, 118.0), badge_rim * 0.34 * icon_reveal);
                }
            }

            // F. KONTAK CAHAYA & PANTULAN DAHAN KAYU KANAN
            let bot_contact = smoothstep(-0.10, 0.96, q_norm.y) * (1.0 - abs(q_norm.x) * 0.16);
            let gold_radiance = hex(242.0, 188.0, 85.0) * (bot_contact * (0.16 + typing_energy * 0.14));
            let wood_reflection = hex(98.0, 72.0, 54.0) * (bot_contact * 0.26);
            lantern_glass += gold_radiance + wood_reflection;

            // G. BORDERLINE GANDA KINTSUGI EMAS
            let border_w = 1.15;
            let border_mask = smoothstep(-aa, 0.0, d_box + border_w) * (1.0 - smoothstep(0.0, aa, d_box));
            let inner_chamfer_d = abs(d_box + 2.4) - 0.45;
            let inner_chamfer_mask = (1.0 - smoothstep(-0.6, 0.6, inner_chamfer_d)) * (1.0 - smoothstep(0.0, 0.65, q_norm.y));

            let rim_energy = clamp(is_hover * 0.55 + typing_energy * 0.75, 0.0, 1.0);
            let gold_rim = mix(hex(195.0, 165.0, 112.0), hex(255.0, 222.0, 145.0), rim_energy);
            let is_bottom_bed = smoothstep(0.14, 0.84, q_norm.y);
            let wood_melt_col = mix(gold_rim, hex(108.0, 76.0, 54.0), is_bottom_bed * 0.80);
            let border_col_eff = mix(gold_rim, wood_melt_col, is_bottom_bed);

            lantern_glass = mix(lantern_glass, hex(238.0, 220.0, 180.0), inner_chamfer_mask * (0.14 + rim_energy * 0.14));
            lantern_glass = mix(lantern_glass, border_col_eff, border_mask * (0.68 + rim_energy * 0.28));

            let pill_alpha = 0.985 * fill_mask * smoothstep(0.0, 0.22, t_lin);
            col = mix(col, lantern_glass, pill_alpha);
            alpha = max(alpha, pill_alpha);
        }
    }

    return vec4<f32>(col, alpha);
}
