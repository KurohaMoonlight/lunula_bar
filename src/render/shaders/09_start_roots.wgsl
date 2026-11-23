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

    // Ketinggian Y bibir atas taskbar di tengah
    let lip_center_y = get_taskbar_lip_y(cx, cx, half_w, bottom_y, smooth_t, overshoot);

    // Guard vertikal batas atas (fade-out gradual, bukan potongan lurus)
    if (p.y < lip_center_y - 56.0) {
        return vec4<f32>(in_col, in_a);
    }

    var col = in_col;
    var alpha = in_a;

    let g = clamp(g_root, 0.0, 1.0);
    let g_hub = smoothstep(0.00, 0.45, g);
    let g_span = smoothstep(0.10, 1.00, g);
    let g_branch = smoothstep(0.16, 0.95, g);

    let hub_center = vec2<f32>(cx, lip_center_y + 1.5);

    // Bentangan 80% dari setengah lebar taskbar (sebelum radius lekukan pojok taskbar)
    let max_span = half_w * 0.80;
    let cur_span = max_span * g_span;

    // Palet Warna Akar Emas Kintsugi Sakura
    let gold_core   = hex(255.0, 248.0, 224.0); // Inti emas terang
    let gold_body   = hex(236.0, 184.0, 92.0);  // Badan akar cairan emas
    let bronze_bark = hex(112.0, 68.0, 28.0);   // Kulit tepi amber-perunggu Kintsugi
    let sakura_blush= hex(248.0, 168.0, 185.0); // Rona sakura anggun

    // ─────────────────────────────────────────────────────────────────────────
    // 1. PANGKAL AKAR ORGANIK DI TENGAH (The Muscular Nebari Hub + Arching Buttresses)
    // ─────────────────────────────────────────────────────────────────────────
    let q_hub = p - hub_center;
    let dist_hub = length(q_hub);
    let ang_hub = atan2(q_hub.y, q_hub.x);

    // Otot urat organik pada pangkal nebari (melebar ke bawah & samping, menonjol di bibir)
    let muscle = (sin(ang_hub * 3.0 + 1.2) * 0.55 + cos(ang_hub * 5.0 - 0.8) * 0.35) * 3.8;
    let y_flare = select(q_hub.y * 0.35, -q_hub.y * 0.65, q_hub.y < 0.0);
    let r_hub_eff = max((15.5 + muscle + y_flare) * g_hub, 0.5);
    var d_hub_all = dist_hub - r_hub_eff;

    // Sulur Nebari Atas-Kiri: melengkung naik ke atas bibir ombak lalu memeluk ke samping
    let hub_ul_p0 = hub_center + vec2<f32>(-4.0, -8.0 * g_hub);
    let hub_ul_p1 = hub_center + vec2<f32>(-24.0, -17.0 * g_hub);
    let hub_ul_p2 = hub_center + vec2<f32>(-48.0, -4.0 * g_hub);
    let d_hub_ul = min(
        sd_tapered_capsule(p, hub_ul_p0, hub_ul_p1, 5.8 * g_hub, 4.0 * g_hub).x,
        sd_tapered_capsule(p, hub_ul_p1, hub_ul_p2, 4.0 * g_hub, 2.2 * g_hub).x
    );

    // Sulur Nebari Atas-Kanan: melengkung naik ke atas bibir ombak lalu memeluk ke kanan
    let hub_ur_p0 = hub_center + vec2<f32>(4.0, -8.0 * g_hub);
    let hub_ur_p1 = hub_center + vec2<f32>(26.0, -18.0 * g_hub);
    let hub_ur_p2 = hub_center + vec2<f32>(52.0, -5.0 * g_hub);
    let d_hub_ur = min(
        sd_tapered_capsule(p, hub_ur_p0, hub_ur_p1, 5.8 * g_hub, 4.0 * g_hub).x,
        sd_tapered_capsule(p, hub_ur_p1, hub_ur_p2, 4.0 * g_hub, 2.2 * g_hub).x
    );

    d_hub_all = smin_cubic(d_hub_all, min(d_hub_ul, d_hub_ur), 4.5 * g_hub);

    // ─────────────────────────────────────────────────────────────────────────
    // 2. SAYAP AKAR UTAMA BERSERABUT DENGAN UJUNG BULAT & GRADASI HALUS (Zero Box Clip)
    // ─────────────────────────────────────────────────────────────────────────
    let dx = abs(p.x - cx);
    var d_wings = 1e5;
    var wing_r = 1.0;

    // Evaluasi sayap diperluas hingga cur_span + 32px untuk perhitungan tutup bulat Euclidean sempurna
    if (dx <= cur_span + 32.0 && dx >= 1.5) {
        let span_norm = clamp(dx / max_span, 0.0, 1.0);
        let sample_x = select(cx + sign(p.x - cx) * min(dx, cur_span), p.x, dx <= cur_span);
        let lip_y_x = get_taskbar_lip_y(sample_x, cx, half_w, bottom_y, smooth_t, overshoot);

        // Riak ombak permukaan tempat akar merayap
        let wave_ripple = (sin((sample_x - bar_left) * 0.034 + time * 2.8) * 0.65 + sin((sample_x - bar_left) * 0.072 - time * 1.5) * 0.35) * 2.4;
        let lip_runner_y = lip_y_x + wave_ripple;

        // Trunk A: Urat akar utama meliuk halus (S-curve wabi-sabi)
        let meander_a = sin(min(dx, cur_span) * 0.045 - time * 0.8) * 2.8 * smoothstep(0.08, 0.70, span_norm);
        let root_y_a = lip_runner_y + meander_a;

        // Profil ketebalan: Dari pangkal gendut (~10.5px) menipis bertahap hingga sangat halus (~0.8px) di ujung
        let taper = pow(clamp(1.0 - span_norm, 0.0, 1.0), 0.82);
        wing_r = mix(0.8, 10.5, taper) * min(g_span * 1.15, 1.0);

        // Euclidean end-cap: Di luar cur_span, jarak dihitung melengkung setengah lingkaran (tutup bulat)
        let cap_dx = max(dx - cur_span, 0.0);
        let d_trunk_a = length(vec2<f32>(cap_dx, p.y - root_y_a)) - wing_r;

        // Trunk B: Urat akar sekunder yang terpilin saling melilit dengan Trunk A
        let meander_b = cos(min(dx, cur_span) * 0.058 + time * 0.6 + 1.2) * 3.4 * smoothstep(0.05, 0.75, span_norm);
        let root_y_b = lip_runner_y + meander_b - 1.5;
        let r_b = max(wing_r * 0.62, 0.75);
        let d_trunk_b = length(vec2<f32>(cap_dx, p.y - root_y_b)) - r_b;

        // Untaian Serabut Dorsal (melilit di punggung atas sayap)
        let dorsal_off = sin(min(dx, cur_span) * 0.12 - time * 1.2) * (wing_r * 0.45 + 1.2);
        let dorsal_r = max(wing_r * 0.38, 0.65);
        let d_dorsal = length(vec2<f32>(cap_dx, p.y - (root_y_a - dorsal_off))) - dorsal_r;

        // Untaian Serabut Ventral (melilit di perut bawah sayap)
        let ventral_off = cos(min(dx, cur_span) * 0.14 + time * 0.9 + 1.4) * (wing_r * 0.40 + 1.0);
        let ventral_r = max(wing_r * 0.35, 0.60);
        let d_ventral = length(vec2<f32>(cap_dx, p.y - (root_y_a + ventral_off))) - ventral_r;

        // Serabut mikro acak (fine whiskers) mencuat di sepanjang akar
        let micro_freq = sin(min(dx, cur_span) * 0.42 + p.x * 0.06);
        let micro_dir = select(1.0, -1.0, sin(min(dx, cur_span) * 0.22) > 0.0);
        let micro_len = clamp(micro_freq * 4.2, 0.0, 4.8) * smoothstep(0.12, 0.88, span_norm);
        let d_micro = length(vec2<f32>(cap_dx, p.y - (root_y_a + micro_dir * (wing_r + micro_len * 0.5)))) - max(micro_len * 0.25, 0.55);

        d_wings = min(min(d_trunk_a, d_trunk_b), min(min(d_dorsal, d_ventral), d_micro));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. SEBARAN CABANG DINAMIS & BENAR-BENAR RANDOM (Procedural Multi-Directional Roots)
    // ─────────────────────────────────────────────────────────────────────────
    var d_branches = 1e5;
    let dock_y = lip_center_y + 28.0;

    if (g_branch > 0.02) {
        // Celah Aman Tengah (cx +/- 0): melengkung S-curve di antara App2 dan App3
        let d_div_c0 = min(
            sd_tapered_capsule(p, vec2<f32>(cx - 1.0, lip_center_y + 1.0), vec2<f32>(cx + 2.5, lip_center_y + 18.0), 3.8 * g_branch, 2.2 * g_branch).x,
            sd_tapered_capsule(p, vec2<f32>(cx + 2.5, lip_center_y + 18.0), vec2<f32>(cx - 1.2, lip_center_y + 36.0 * g_branch), 2.2 * g_branch, 0.9 * g_branch).x
        );

        // Celah Aman Kiri & Kanan (cx +/- 64px)
        let d_div_c1 = sd_tapered_capsule(p, vec2<f32>(cx - 64.0, lip_center_y + 2.0), vec2<f32>(cx - 62.5, lip_center_y + 25.0 * g_branch), 2.4 * g_branch, 0.8 * g_branch).x;
        let d_div_c2 = sd_tapered_capsule(p, vec2<f32>(cx + 64.0, lip_center_y + 2.0), vec2<f32>(cx + 65.5, lip_center_y + 26.0 * g_branch), 2.4 * g_branch, 0.8 * g_branch).x;

        var d_proc_branches = min(d_div_c0, min(d_div_c1, d_div_c2));

        // Loop Prosedural Dinamis: 10 cabang acak di sisi Kiri dan 10 cabang acak di sisi Kanan
        // Setiap cabang memiliki posisi, arah sudut (ke atas/samping/bawah), panjang (dengan max_len), dan kelengkungan yang acak!
        let max_len = 46.0; // Batas panjang maksimum cabang

        for (var i = 0; i < 10; i = i + 1) {
            let fi = f32(i);

            // --- SISI KIRI (Negative X) ---
            let rnd_l1 = hash21_root(fi * 17.3 + 3.1);
            let rnd_l2 = hash21_root(fi * 31.7 + 7.9);

            // Jarak X dasar sepanjang sayap kiri: menyebar dari cx - 40px hingga cx - cur_span
            let dist_x_l = mix(38.0, cur_span * 0.96, (fi + rnd_l1.x * 0.8) / 10.0);

            if (dist_x_l <= cur_span + 5.0) {
                let origin_x_l = cx - dist_x_l;
                let origin_y_l = get_taskbar_lip_y(origin_x_l, cx, half_w, bottom_y, smooth_t, overshoot);

                // Arah acak 360 derajat:
                // Modulo jenis cabang: 0=naik ke atas, 1=menjalar menyamping, 2=menukik diagonal ke ombak, 3=bercabang loop
                let branch_type_l = i % 4;
                var ang_l = 0.0;
                var len_l = mix(14.0, max_len, rnd_l1.y) * g_branch;

                if (branch_type_l == 0) {
                    // Melengkung naik ke atas (arching upward)
                    ang_l = mix(-2.35, -0.78, rnd_l2.x); // -135 to -45 derajat
                    len_l = min(len_l, 26.0); // Naik ke atas dibatasi agar tetap proporsional
                } else if (branch_type_l == 1) {
                    // Menjalar menyamping horizontal (menyilang ombak)
                    ang_l = mix(2.80, 3.45, rnd_l2.x); // ke arah kiri (-X)
                } else {
                    // Menyelam diagonal ke bawah masuk ke dalam air ombak
                    ang_l = mix(0.70, 2.45, rnd_l2.x); // ke arah bawah-kiri
                }

                let dir_l = vec2<f32>(cos(ang_l), sin(ang_l));
                let bend_l = vec2<f32>(-dir_l.y, dir_l.x) * (rnd_l2.y * 12.0 - 6.0);

                let p0_l = vec2<f32>(origin_x_l, origin_y_l);
                let p1_l = p0_l + dir_l * (len_l * 0.52) + bend_l;
                let p2_l = p0_l + dir_l * len_l;

                let r0_l = mix(2.6, 4.0, rnd_l1.x) * g_branch;
                let r1_l = mix(1.4, 2.2, rnd_l1.x) * g_branch;
                let r2_l = 0.65 * g_branch;

                let d_b_l = min(
                    sd_tapered_capsule(p, p0_l, p1_l, r0_l, r1_l).x,
                    sd_tapered_capsule(p, p1_l, p2_l, r1_l, r2_l).x
                );

                // Ranting bifurkasi kecil (sub-branch) untuk variasi alami
                if (rnd_l2.x > 0.45 && len_l > 22.0) {
                    let sub_ang_l = ang_l + mix(0.45, 0.95, rnd_l1.y);
                    let sub_p2_l = p1_l + vec2<f32>(cos(sub_ang_l), sin(sub_ang_l)) * (len_l * 0.45);
                    let d_sub_l = sd_tapered_capsule(p, p1_l, sub_p2_l, r1_l * 0.8, 0.55 * g_branch).x;
                    d_proc_branches = min(d_proc_branches, min(d_b_l, d_sub_l));
                } else {
                    d_proc_branches = min(d_proc_branches, d_b_l);
                }
            }

            // --- SISI KANAN (Positive X) ---
            let rnd_r1 = hash21_root(fi * 23.9 + 5.7);
            let rnd_r2 = hash21_root(fi * 41.1 + 11.3);

            let dist_x_r = mix(38.0, cur_span * 0.96, (fi + rnd_r1.x * 0.8) / 10.0);

            if (dist_x_r <= cur_span + 5.0) {
                let origin_x_r = cx + dist_x_r;
                let origin_y_r = get_taskbar_lip_y(origin_x_r, cx, half_w, bottom_y, smooth_t, overshoot);

                let branch_type_r = (i + 1) % 4;
                var ang_r = 0.0;
                var len_r = mix(14.0, max_len, rnd_r1.y) * g_branch;

                if (branch_type_r == 0) {
                    // Melengkung naik ke atas
                    ang_r = mix(-2.35, -0.78, rnd_r2.x);
                    len_r = min(len_r, 26.0);
                } else if (branch_type_r == 1) {
                    // Menjalar menyamping ke kanan
                    ang_r = mix(-0.35, 0.35, rnd_r2.x);
                } else {
                    // Menyelam diagonal ke bawah-kanan
                    ang_r = mix(0.70, 2.45, rnd_r2.x);
                }

                let dir_r = vec2<f32>(cos(ang_r), sin(ang_r));
                let bend_r = vec2<f32>(-dir_r.y, dir_r.x) * (rnd_r2.y * 12.0 - 6.0);

                let p0_r = vec2<f32>(origin_x_r, origin_y_r);
                let p1_r = p0_r + dir_r * (len_r * 0.52) + bend_r;
                let p2_r = p0_r + dir_r * len_r;

                let r0_r = mix(2.6, 4.0, rnd_r1.x) * g_branch;
                let r1_r = mix(1.4, 2.2, rnd_r1.x) * g_branch;
                let r2_r = 0.65 * g_branch;

                let d_b_r = min(
                    sd_tapered_capsule(p, p0_r, p1_r, r0_r, r1_r).x,
                    sd_tapered_capsule(p, p1_r, p2_r, r1_r, r2_r).x
                );

                if (rnd_r2.x > 0.45 && len_r > 22.0) {
                    let sub_ang_r = ang_r + mix(-0.95, -0.45, rnd_r1.y);
                    let sub_p2_r = p1_r + vec2<f32>(cos(sub_ang_r), sin(sub_ang_r)) * (len_r * 0.45);
                    let d_sub_r = sd_tapered_capsule(p, p1_r, sub_p2_r, r1_r * 0.8, 0.55 * g_branch).x;
                    d_proc_branches = min(d_proc_branches, min(d_b_r, d_sub_r));
                } else {
                    d_proc_branches = min(d_proc_branches, d_b_r);
                }
            }
        }

        // ATURAN MUTLAK: Potong secara matematis bila mendekati 4 GUI icon dock tengah
        let d_dock_keepout = eval_dock_keepout_dist(p, cx, dock_y);
        d_branches = max(d_proc_branches, -d_dock_keepout + 1.5);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FUSI SDF SEMUA AKAR (Pangkal + Sayap + Cabang Prosedural)
    // ─────────────────────────────────────────────────────────────────────────
    let d_surface_roots = smin_cubic(d_hub_all, d_wings, 5.5 * g_hub);
    let d_all_roots = smin_cubic(d_surface_roots, d_branches, 2.8 * g_branch);

    if (d_all_roots > 22.0) {
        return vec4<f32>(col, alpha);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SHADING & MATERIAL AKAR EMAS SAKURA KINTSUGI BERSERABUT ALAMI
    // ─────────────────────────────────────────────────────────────────────────
    let aa = 1.15;
    let root_mask = 1.0 - smoothstep(-aa, aa, d_all_roots);
    let aura_raw = pow(clamp(1.0 - max(d_all_roots, 0.0) / 16.0, 0.0, 1.0), 2.2) * (0.40 + 0.15 * sin(time * 2.2));

    // Pemudaran halus gradasi di ujung bentangan (Zero Box Cut!):
    // Aura dan badan akar memudar halus secara radial di ujung bentangan 80%
    let tip_gradient = 1.0 - smoothstep(cur_span - 26.0, cur_span + 14.0, dx);
    let aura_glow = aura_raw * tip_gradient;
    let eff_root_mask = root_mask * tip_gradient;

    // Refleksi volume 3D silindris pada batang akar
    let norm_depth = clamp(-d_all_roots / 8.0, 0.0, 1.0);
    let core_highlight = pow(norm_depth, 1.45);

    // Striasi serat kayu emas Kintsugi (longitudinal fibrous grain)
    let fiber_grain = sin(p.y * 3.8 + p.x * 0.25 + sin(p.x * 0.08) * 2.2) * 0.18 + 0.5;

    // Aliran urat emas cair Kintsugi sepanjang akar
    let flow = sin(p.x * 0.09 - time * 2.4) * 0.5 + 0.5;

    var r_col = mix(bronze_bark, gold_body, smoothstep(0.0, 0.45, norm_depth));
    r_col = mix(r_col, gold_core, core_highlight * (0.60 + 0.40 * flow) * fiber_grain);
    r_col = mix(r_col, sakura_blush, smoothstep(0.35, 0.95, abs(p.x - cx) / max_span) * 0.40);

    // Efek refraksi untuk akar yang menyelam ke dalam ombak taskbar (sedikit biru gelap air)
    let in_water = smoothstep(0.0, 6.0, p.y - lip_center_y);
    let dive_fade = clamp((p.y - lip_center_y) / 50.0, 0.0, 1.0);
    let water_tint = hex(24.0, 52.0, 78.0);
    r_col = mix(r_col, water_tint, in_water * dive_fade * 0.48);

    // Aura pendaran emas di sekitar akar
    let aura_col = mix(gold_body, sakura_blush, 0.35);
    col = mix(col, aura_col, aura_glow * 0.55 * g);
    col = mix(col, r_col, eff_root_mask * 0.96);
    alpha = max(alpha, max(eff_root_mask * 0.98, aura_glow * 0.65) * g);

    return vec4<f32>(col, alpha);
}
