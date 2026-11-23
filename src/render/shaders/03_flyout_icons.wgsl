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

// SDF Icons for Flyout & Sub-Flyouts
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
