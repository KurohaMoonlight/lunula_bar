// =============================================================================
// LUNULA BAR — INSTANCED 2.5D FUKINAGASHI SAKURA TREE SHADER
//   - Merender 600–1400 segmen batang, dahan, & ranting mikro dalam 1 draw call
//   - Pangkal batang (s = 0..0.15) menyatu mulus (seamless nebari melt) dengan
//     akar energi cair di `09_start_roots.wgsl` pada koordinat `tree_base` identik
//   - Mempertahankan ketiga `trunk_style` (`hybrid`, `liquid`, `wood` + Kintsugi)
//     dengan upgrade pencahayaan 2.5D, alur kulit kayu, depth-layering, & AA sub-piksel
// =============================================================================

struct GlobUniforms {
    screen_size: vec2<f32>,
    bar_width: f32,
    bar_height: f32,
    corner_radius: f32,
    fillet_radius: f32,
    time: f32,
    srgb_target: f32,
    anim_t: f32,
    wave_surge: f32,
    mouse_pos: vec2<f32>,
    pull_strength: f32,
    mouse_speed: f32,
    mouse_slosh: f32,
    _pad0: f32,
    clock_time: vec4<f32>,
    flyout_info: vec4<f32>,
    flyout_meta: vec4<f32>,
    flyout_state: vec4<f32>,
    flyout_extra: vec4<f32>,
    font_scales: vec4<f32>,
    texture_params: vec4<f32>,
    chain_info: vec4<f32>,
    chain_offsets: vec4<f32>,
    audio_levels: vec4<f32>,
    power_extra: vec4<f32>,
    start_info: vec4<f32>,
    tree_params: vec4<f32>,
    start_fx: vec4<f32>,
    tree_style: vec4<f32>,
};

struct SakuraSeg {
    a: vec2<f32>,
    b: vec2<f32>,
    r0: f32,
    r1: f32,
    depth_layer: f32,
    level: f32,
    s0: f32,
    s1: f32,
    grow_start: f32,
    grow_end: f32,
    sway_weight: f32,
    seed: f32,
    role: f32,
    _pad: f32,
};

@group(0) @binding(0)
var<uniform> u: GlobUniforms;

@group(0) @binding(1)
var<storage, read> sakura_segs: array<SakuraSeg>;

struct TreeVertOut {
    @builtin(position) clip_pos: vec4<f32>,
    @location(0) world_p: vec2<f32>,
    @location(1) seg_a: vec2<f32>,
    @location(2) seg_b: vec2<f32>,
    @location(3) radii_s: vec4<f32>,    // (r0_eff, r1_eff, s0, s1)
    @location(4) seg_meta: vec4<f32>,   // (depth_layer, level, seed, g_seg)
    @location(5) tree_base: vec2<f32>,
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers warna & noise prosedural (identik dengan 00_uniforms & 01_noise_sdf)
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

fn hash21(p_in: vec2<f32>) -> f32 {
    var p = fract(p_in * vec2<f32>(123.34, 456.21));
    p = p + dot(p, p + 45.32);
    return fract(p.x * p.y);
}

fn noise2(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let uf = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, uf.x), mix(c, d, uf.x), uf.y);
}

fn fbm(p_in: vec2<f32>) -> f32 {
    var v = 0.0;
    var amp = 0.5;
    var p = p_in;
    for (var i = 0; i < 3; i = i + 1) {
        v = v + amp * noise2(p);
        p = p * 2.03 + vec2<f32>(17.1, 31.7);
        amp = amp * 0.5;
    }
    return v;
}

/// Menghitung offset goyangan angin fukinagashi halus (0.0 di pangkal agar terkunci di akar!).
fn wind_offset(pos_rel: vec2<f32>, sway_w: f32, seed: f32, time: f32) -> vec2<f32> {
    if (sway_w <= 0.001) {
        return vec2<f32>(0.0, 0.0);
    }
    let gust = sin(time * 0.85 + pos_rel.x * 0.0045 + pos_rel.y * 0.003) * 4.2
             + cos(time * 1.45 + seed * 6.2831 + pos_rel.x * 0.011) * 1.6;
    let lift = sin(time * 1.12 + seed * 4.1 + pos_rel.x * 0.006) * 1.4;
    return vec2<f32>(gust * sway_w, lift * sway_w);
}

@vertex
fn vs_tree(
    @builtin(vertex_index) v_idx: u32,
    @builtin(instance_index) inst_idx: u32,
) -> TreeVertOut {
    var out: TreeVertOut;
    let p2_c = clamp(u.start_info.y, 0.0, 1.0);
    let seg = sakura_segs[inst_idx];

    let g_seg = smoothstep(seg.grow_start, max(seg.grow_end, seg.grow_start + 0.02), p2_c);
    if (p2_c <= 0.004 || g_seg <= 0.004) {
        out.clip_pos = vec4<f32>(-2.0, -2.0, 0.0, 1.0);
        out.world_p = vec2<f32>(0.0, 0.0);
        out.seg_a = vec2<f32>(0.0, 0.0);
        out.seg_b = vec2<f32>(0.0, 0.0);
        out.radii_s = vec4<f32>(0.0);
        out.seg_meta = vec4<f32>(0.0);
        out.tree_base = vec2<f32>(0.0);
        return out;
    }

    // Hitung `tree_base` 100% IDENTIK dengan `08_themes_main.wgsl` agar terkunci di pusat nebari akar!
    let cx = u.screen_size.x * 0.5;
    let bottom_y = u.screen_size.y;
    let t_anim = clamp(u.anim_t, 0.0, 1.15);
    let smooth_t = smoothstep(0.0, 1.0, min(t_anim, 1.0));
    let overshoot = max(t_anim - 1.0, 0.0) * 14.0;
    let bar_left_main = cx - u.bar_width * 0.5;
    let tree_bar_top = bottom_y - (mix(8.0, u.bar_height, smooth_t) + overshoot);
    let tree_base = vec2<f32>(bar_left_main + 78.0, tree_bar_top + 11.0);

    // Bobot angin bertahap sepanjang segmen (pangkal a sedikit lebih kaku dari ujung b)
    let sw_a = max(seg.sway_weight - 0.04, 0.0);
    let sw_b = seg.sway_weight;
    let a_w = tree_base + seg.a + wind_offset(seg.a, sw_a, seg.seed, u.time);
    let b_full = tree_base + seg.b + wind_offset(seg.b, sw_b, seg.seed, u.time);
    let b_w = mix(a_w, b_full, g_seg);

    // Skala radius saat tumbuh (batang utama mekar kokoh, ranting muncul halus)
    let rad_grow = mix(0.35, 1.0, smoothstep(0.0, 0.75, g_seg));
    let r0_eff = seg.r0 * rad_grow;
    let r1_eff = seg.r1 * rad_grow;

    let delta = b_w - a_w;
    let seg_len = length(delta);
    let dir = select(vec2<f32>(1.0, 0.0), delta / seg_len, seg_len > 0.001);
    let perp = vec2<f32>(-dir.y, dir.x);

    // Margin quad untuk anti-aliasing + sedikit aura lembut di batang/dahan utama
    let glow_pad = select(2.2, 6.5, seg.level < 1.5);
    let half_w = max(max(r0_eff, r1_eff), 1.0) + glow_pad;

    let corners = array<vec2<f32>, 6>(
        vec2<f32>(0.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(0.0,  1.0),
        vec2<f32>(0.0,  1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(1.0,  1.0)
    );
    let c = corners[v_idx];

    let along = select(-half_w, seg_len + half_w, c.x > 0.5);
    let world_p = a_w + dir * along + perp * (c.y * half_w);

    let ndc_x = (world_p.x / max(u.screen_size.x, 1.0)) * 2.0 - 1.0;
    let ndc_y = 1.0 - (world_p.y / max(u.screen_size.y, 1.0)) * 2.0;

    out.clip_pos = vec4<f32>(ndc_x, ndc_y, 0.0, 1.0);
    out.world_p = world_p;
    out.seg_a = a_w;
    out.seg_b = b_w;
    out.radii_s = vec4<f32>(r0_eff, r1_eff, seg.s0, mix(seg.s0, seg.s1, g_seg));
    out.seg_meta = vec4<f32>(seg.depth_layer, seg.level, seg.seed, g_seg);
    out.tree_base = tree_base;
    return out;
}

@fragment
fn fs_tree(in: TreeVertOut) -> @location(0) vec4<f32> {
    let p = in.world_p;
    let a = in.seg_a;
    let b = in.seg_b;
    let r0 = in.radii_s.x;
    let r1 = in.radii_s.y;
    let s0 = in.radii_s.z;
    let s1 = in.radii_s.w;

    let depth_layer = in.seg_meta.x;
    let level = in.seg_meta.y;
    let seed = in.seg_meta.z;
    let g_seg = in.seg_meta.w;

    let ba = b - a;
    let pa = p - a;
    let ba_len2 = max(dot(ba, ba), 1e-4);
    let h = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
    let closest = a + ba * h;
    let diff = p - closest;
    let dist_axis = length(diff);

    let raw_r = mix(r0, r1, h);
    let s = mix(s0, s1, h);

    // Sub-pixel AA coverage agar ranting mikro (< 0.9px) tetap tajam & halus tanpa berkedip
    let aa_floor = 0.88;
    let eff_r = max(raw_r, aa_floor);
    let subpx_cov = clamp(raw_r / aa_floor, 0.24, 1.0);

    // Distorsi kulit kayu organik halus hanya pada batang & dahan primer
    let ba_dir = normalize(ba + vec2<f32>(0.0001, -0.0001));
    let perp_dir = vec2<f32>(-ba_dir.y, ba_dir.x);
    let perp_signed = dot(diff, perp_dir);
    let perp_norm = clamp(perp_signed / max(eff_r, 0.5), -1.0, 1.0);

    let bark_uv = vec2<f32>(perp_norm * 2.6 + seed * 7.3, s * 16.0);
    let bark_n = fbm(bark_uv);
    let bark_edge = select(0.0, (bark_n - 0.5) * min(raw_r * 0.14, 1.6), level < 1.5);
    let d_sdf = dist_axis - eff_r + bark_edge;

    // Feather pinggiran halus
    let aa_w = select(0.75, 0.95, level < 1.5);
    let body_m = (1.0 - smoothstep(-aa_w, aa_w, d_sdf)) * subpx_cov;

    // Aura hangat sangat tipis di sekitar batang & dahan primer
    var aura_m = 0.0;
    if (level < 1.5 && d_sdf > -0.5 && d_sdf < 6.5) {
        aura_m = exp(-max(d_sdf, 0.0) * 0.55) * 0.12 * g_seg * (0.45 + 0.55 * depth_layer);
    }

    if (body_m <= 0.002 && aura_m <= 0.002) {
        discard;
    }

    // Fusi lembut pangkal batang ke akar nebari taskbar:
    // Potong halus bagian bawah yang menembus ke bawah bibir akar agar ZERO benjolan kapsul!
    let base_clip = 1.0 - smoothstep(in.tree_base.y - 2.0, in.tree_base.y + 5.0, p.y);
    let final_body_m = body_m * base_clip;
    let final_aura_m = aura_m * base_clip;
    if (final_body_m <= 0.002 && final_aura_m <= 0.002) {
        discard;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PENCAHAYAAN 2.5D SILINDER + ALUR KULIT KAYU + DEPTH LAYERING
    // ─────────────────────────────────────────────────────────────────────────
    let nz = sqrt(max(1.0 - perp_norm * perp_norm * 0.92, 0.08));
    let bark_bump = (bark_n - 0.5) * select(0.18, 0.42, level < 1.5);
    let n3 = normalize(vec3<f32>(
        perp_dir.x * perp_norm + bark_bump * 0.35,
        perp_dir.y * perp_norm - bark_bump * 0.25,
        nz
    ));

    // Arah cahaya utama konsisten dari kiri-atas-depan (memberi sisi terang & bayangan tegas!)
    let light_dir = normalize(vec3<f32>(-0.42, -0.74, 0.52));
    let half_vec = normalize(light_dir + vec3<f32>(0.0, 0.0, 1.0));
    let ndl = clamp(dot(n3, light_dir) * 0.55 + 0.45, 0.0, 1.0);
    let key_lit = smoothstep(0.28, 0.92, ndl);
    let spec = pow(max(dot(n3, half_vec), 0.0001), 18.0);

    let depth_in = clamp(1.0 - abs(perp_norm), 0.0, 1.0);
    let time = u.time;
    let heartbeat = 0.5 + 0.5 * sin(time * 1.57);

    // Palet bersama (identik dengan 09_start_roots.wgsl agar 100% selaras dengan akar!)
    let gold_warm  = hex(232.0, 180.0, 92.0);
    let gold_core  = hex(255.0, 244.0, 206.0);
    let gold_pale  = hex(255.0, 250.0, 226.0);
    let sky_bounce = hex(74.0, 112.0, 148.0);

    let flow_v = s * 6.4 - time * 1.35;
    let streamlines = fbm(vec2<f32>(perp_norm * 2.2 + seed * 3.1, flow_v * 0.85));
    let style_id = u.tree_style.x;
    var col = gold_warm;

    if (style_id < 0.5) {
        // STYLE 0: HYBRID — Kulit kayu sakura 2.5D amber-perunggu berurat + inti energi cair emas
        let bark_shadow = hex(36.0, 22.0, 13.0);
        let bark_mid    = hex(128.0, 82.0, 36.0);
        let bark_lit    = hex(216.0, 168.0, 96.0);

        col = mix(bark_shadow, bark_mid, smoothstep(0.08, 0.68, ndl));
        col = mix(col, bark_lit, key_lit * (0.55 + 0.45 * bark_n));

        // Inti energi cair emas hangat di dalam batang & menyebar tipis ke ranting
        let core_w = mix(0.55, 0.25, clamp(level * 0.28, 0.0, 1.0));
        col = mix(col, mix(gold_warm, gold_core, 0.35 + 0.40 * s), pow(max(depth_in, 0.0001), 1.25) * core_w * (0.65 + 0.35 * streamlines));
    } else if (style_id < 1.5) {
        // STYLE 1: LIQUID — Energi cair emas lembut 2.5D penuh selaras akar
        let meniscus_amber = hex(86.0, 52.0, 24.0);
        let honey_deep     = hex(176.0, 118.0, 44.0);
        col = mix(meniscus_amber, honey_deep, smoothstep(0.0, 0.45, ndl));
        col = mix(col, gold_warm, smoothstep(0.12, 0.72, depth_in) * (0.72 + 0.28 * ndl));
        col = mix(col, gold_core, pow(max(depth_in, 0.0001), 1.5) * (0.55 + 0.30 * s));
        col = col * mix(0.90, 1.15, streamlines);
        col = mix(col, gold_core, spec * 0.38);
    } else {
        // STYLE 2: WOOD + KINTSUGI — Kayu sakura sumi-perak berurat + urat Kintsugi emas cair
        let sumi_shadow = hex(26.0, 22.0, 20.0);
        let bronze_bark = hex(92.0, 68.0, 48.0);
        let silver_lit  = hex(198.0, 178.0, 146.0);
        col = mix(sumi_shadow, bronze_bark, smoothstep(0.10, 0.65, ndl));
        col = mix(col, silver_lit, key_lit * (0.52 + 0.48 * bark_n));
        col = col * mix(0.82, 1.18, bark_n);

        // Urat Kintsugi emas cair mengalir naik dari pangkal nebari ke cabang
        let vein_n = fbm(vec2<f32>(perp_norm * 2.4 + 3.1 + seed * 4.0, s * 10.0 - time * 0.55));
        let k_vein = smoothstep(0.64, 0.80, vein_n) * smoothstep(0.10, 0.55, depth_in) * (1.0 - level * 0.14);
        col = mix(col, gold_warm, clamp(k_vein * 0.85, 0.0, 0.85));
        col = mix(col, gold_core, clamp(smoothstep(0.76, 0.88, vein_n) * depth_in * 0.85, 0.0, 0.85));
    }

    // Pantulan cahaya biru Kanagawa lembut pada sisi bayangan (bawah-kanan)
    let shadow_bounce = clamp(1.0 - ndl, 0.0, 1.0) * smoothstep(0.2, 0.9, abs(perp_norm));
    col = mix(col, sky_bounce, shadow_bounce * 0.22);

    // Rim light tajam pada tepi atas-kiri yang tertimpa cahaya (memberi siluet ranting yang crisp!)
    let rim = smoothstep(0.45, 0.96, abs(perp_norm)) * smoothstep(0.45, 0.92, ndl);
    col = mix(col, gold_pale, rim * select(0.28, 0.42, level >= 2.0));

    // Gelombang getah energi halus merambat naik dari akar ke ujung ranting
    let sap_pos = fract(time * 0.24);
    let sap_d = s - sap_pos;
    let sap_band = exp(-(sap_d * sap_d) * 52.0) * smoothstep(0.15, 0.85, depth_in);
    col = mix(col, gold_pale, sap_band * 0.36 * (1.0 - level * 0.12));

    // SEAMLESS NEBARI MELT: di pangkal batang (s = 0.0..0.15), lelehkan warna langsung ke
    // warna akar energi cair `09_start_roots.wgsl` agar sambungan akar <-> batang 100% menyatu!
    let nebari_melt = 1.0 - smoothstep(0.02, 0.16, s);
    if (nebari_melt > 0.001) {
        let root_amber = hex(176.0, 118.0, 44.0);
        let root_gold  = hex(232.0, 180.0, 92.0);
        let root_core  = hex(255.0, 244.0, 206.0);
        var root_col = mix(root_amber, root_gold, smoothstep(0.10, 0.70, depth_in) * (0.75 + 0.25 * ndl));
        root_col = mix(root_col, root_core, pow(max(depth_in, 0.0001), 1.65) * (0.58 + 0.16 * heartbeat));
        col = mix(col, root_col, nebari_melt * 0.88);
    }

    // DEPTH LAYERING: ranting belakang lebih gelap & sedikit dingin, ranting depan tajam & terang
    let depth_shade = mix(0.48, 1.08, depth_layer);
    let back_cool = hex(42.0, 48.0, 62.0);
    col = mix(back_cool, col, mix(0.58, 1.0, depth_layer)) * depth_shade;

    // Komposit badan + aura tipis (premultiplied alpha)
    let aura_col = mix(gold_warm, gold_core, 0.45);
    let out_alpha = max(final_body_m, final_aura_m);
    let out_col = mix(aura_col, col, clamp(final_body_m / max(out_alpha, 0.001), 0.0, 1.0));

    return vec4<f32>(out_col * out_alpha, out_alpha);
}
