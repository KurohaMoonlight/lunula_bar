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
