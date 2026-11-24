use bytemuck::{Pod, Zeroable};

/// Kapasitas maksimum segmen bonsai fukinagashi 5-tingkat di GPU storage buffer.
/// 1400 * 64 byte = 89.6 KB (sangat kecil untuk storage buffer, < 0.2ms render time).
pub const MAX_TREE_SEGS: usize = 1400;

/// Kapasitas maksimum bunga sakura di GPU storage buffer (dompolan mahkota & ranting).
pub const MAX_TREE_BLOSSOMS: usize = 600;

/// Satu unit bunga / kuncup sakura instanced (32 byte = 2 x vec4<f32>, 16-byte aligned).
///
/// Sistem koordinat RELATIF terhadap `tree_base`:
/// - `pos`: offset (px) dari `tree_base` (identik dengan ranting pohon).
/// - `radius`: radius mekar kelopak (px, ~4.5 - 9.0 px).
/// - `rot`: sudut orientasi kelopak (radian).
/// - `cluster_id`: ID klaster dompolan (untuk variasi warna & angin mikro).
/// - `depth_layer`: kedalaman 2.5D (0.0 belakang dahan, 1.0 depan dahan).
/// - `stage`: 0.0 kuncup (tsubomi), 1.0 mekar penuh (mankai).
/// - `sway_weight`: bobot lentur goyangan angin.
#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct SakuraBlossomGpu {
    pub pos: [f32; 2],
    pub radius: f32,
    pub rot: f32,
    pub cluster_id: f32,
    pub depth_layer: f32,
    pub stage: f32,
    pub sway_weight: f32,
}

/// Satu segmen kapsul meruncing pohon bonsai (64 byte = 4 x vec4<f32>, 16-byte aligned).
///
/// Sistem koordinat RELATIF terhadap `tree_base = (bar_left + 78.0, tree_bar_top + 11.0)`
/// (identik dengan `start_roots.rs` sehingga pangkal batang 100% terkunci pada pusat nebari akar):
/// - `a`, `b`: offset (px) dari `tree_base` (Y negatif = ke atas, X positif = menyapu ke kanan).
/// - `r0`, `r1`: radius pangkal & ujung segmen (px).
/// - `depth_layer`: kedalaman 2.5D (`0.0` = belakang gelap, `1.0` = depan terang), sudah di-sort CPU.
/// - `level`: `0.0` batang utama/nebari, `1.0` dahan primer, `2.0` sekunder, `3.0` tersier, `4.0` ranting mikro.
/// - `s0`, `s1`: progres kontinu `0.0` (pangkal akar nebari) -> `1.0` (ujung ranting) untuk aliran getah & transisi nebari.
/// - `grow_start`, `grow_end`: jendela timing animasi tumbuh sekuensial saat Start Menu dibuka.
/// - `sway_weight`: bobot goyangan angin (`0.0` di pangkal agar tidak lepas dari akar, `1.0` di ujung ranting).
/// - `seed`: fase acak per-segmen untuk variasi tekstur kulit kayu & angin.
/// - `role`: `0.0` = rangka permanen, `1.0` = slot cabang atas fix (untuk Search Bar nanti), `2.0` = cabang dinamis search nanti.
#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct BonsaiSegGpu {
    pub a: [f32; 2],
    pub b: [f32; 2],
    pub r0: f32,
    pub r1: f32,
    pub depth_layer: f32,
    pub level: f32,
    pub s0: f32,
    pub s1: f32,
    pub grow_start: f32,
    pub grow_end: f32,
    pub sway_weight: f32,
    pub seed: f32,
    pub role: f32,
    pub _pad: f32,
}

/// Output generator pohon sakura fukinagashi prosedural.
pub struct ProceduralTreeData {
    pub segs: Vec<BonsaiSegGpu>,
    pub seg_count: u32,
    pub blossoms: Vec<SakuraBlossomGpu>,
    pub blossom_count: u32,
    /// Titik jangkar cabang mahkota atas (relatif terhadap `tree_base`) yang disiapkan
    /// untuk tempat bertengger Search Bar pada fase berikutnya.
    pub search_anchor: [f32; 2],
}

/// Deterministic XorShift64* PRNG berbasis seed YAML.
struct Rng(u64);

impl Rng {
    fn new(seed: u64) -> Self {
        Self(if seed == 0 {
            0x9E37_79B9_7F4A_7C15
        } else {
            seed
        })
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn f32(&mut self) -> f32 {
        ((self.next_u64() >> 40) as f32) / ((1u64 << 24) as f32)
    }

    fn range(&mut self, lo: f32, hi: f32) -> f32 {
        lo + (hi - lo) * self.f32()
    }
}

/// Evaluasi kurva Catmull-Rom halus melalui daftar titik kontrol.
fn catmull_rom_chain(pts: &[[f32; 2]], steps_per_span: usize) -> Vec<[f32; 2]> {
    let n = pts.len();
    if n < 2 {
        return pts.to_vec();
    }
    let mut out = Vec::with_capacity((n - 1) * steps_per_span + 1);
    for i in 0..(n - 1) {
        let p0 = pts[i.saturating_sub(1)];
        let p1 = pts[i];
        let p2 = pts[i + 1];
        let p3 = pts[(i + 2).min(n - 1)];
        for k in 0..steps_per_span {
            let t = (k as f32) / (steps_per_span as f32);
            let t2 = t * t;
            let t3 = t2 * t;
            let x = 0.5
                * ((2.0 * p1[0])
                    + (-p0[0] + p2[0]) * t
                    + (2.0 * p0[0] - 5.0 * p1[0] + 4.0 * p2[0] - p3[0]) * t2
                    + (-p0[0] + 3.0 * p1[0] - 3.0 * p2[0] + p3[0]) * t3);
            let y = 0.5
                * ((2.0 * p1[1])
                    + (-p0[1] + p2[1]) * t
                    + (2.0 * p0[1] - 5.0 * p1[1] + 4.0 * p2[1] - p3[1]) * t2
                    + (-p0[1] + 3.0 * p1[1] - 3.0 * p2[1] + p3[1]) * t3);
            out.push([x, y]);
        }
    }
    out.push(pts[n - 1]);
    out
}

/// Generator Pohon Bonsai *Fukinagashi* (Windswept) 5-Tingkat.
///
/// Merancang anatomi bonsai yang setia pada referensi:
/// - **Level 0:** Pangkal *nebari* melebar cekung menyatu dengan akar taskbar + batang utama kekar berotot
///   dengan lengkungan C-arch/S-arch berkarakter & kontras taper dramatis.
/// - **Level 1:** 7 dahan primer bertingkat asimetris menyapu kuat ke kanan (*windswept tiers*)
///   dengan ruang negatif (*negative space*) antar-lapisan + titik jangkar mahkota untuk Search Bar nanti.
/// - **Level 2–4:** Ramifikasi dikotomus/trikotomus berlekuk (*gnarled*) meruncing hingga ranting mikro
///   super halus (`0.4px–1.6px`) dan diurutkan berdasarkan `depth_layer` dari belakang ke depan.
pub fn generate_fukinagashi_tree(
    seed: u64,
    rise_h: f32,
    trunk_thickness: f32,
    trunk_lean: f32,
    low_quality: bool,
) -> ProceduralTreeData {
    let mut rng = Rng::new(seed ^ 0x517C_C1B7_2722_0A95);
    let max_segs = if low_quality { 620 } else { MAX_TREE_SEGS };
    let mut segs: Vec<BonsaiSegGpu> = Vec::with_capacity(max_segs);

    let sc = (rise_h / 440.0).clamp(0.65, 1.65);
    let thick = trunk_thickness.clamp(0.70, 1.65);
    let lean = trunk_lean.clamp(0.15, 0.65);
    let r_base = 26.5 * thick * sc;

    // Helper tambah segmen dengan kalkulasi otomatis `grow_start`/`grow_end` & `sway_weight`.
    #[allow(clippy::too_many_arguments)]
    fn push_seg(
        segs: &mut Vec<BonsaiSegGpu>,
        max_segs: usize,
        rng: &mut Rng,
        a: [f32; 2],
        b: [f32; 2],
        r0: f32,
        r1: f32,
        depth: f32,
        level: f32,
        s0: f32,
        s1: f32,
        role: f32,
    ) {
        if segs.len() >= max_segs {
            return;
        }
        let s_mid = 0.5 * (s0 + s1);
        // Pangkal batang (s <= 0.08) terkunci 0.0 sway agar tidak pernah bergeser dari pusat akar nebari!
        let sway = ((s_mid - 0.08) / 0.92).clamp(0.0, 1.0).powf(1.45);
        // Animasi tumbuh bergelombang dari pangkal (0.0) -> dahan primer -> ranting mikro (1.0)
        let g_start = (s0 * 0.72 + level * 0.035).clamp(0.0, 0.84);
        let g_span = (0.14 + (1.0 - level * 0.14) * 0.08).clamp(0.10, 0.24);
        let g_end = (g_start + g_span).min(1.0);

        segs.push(BonsaiSegGpu {
            a,
            b,
            r0,
            r1,
            depth_layer: depth.clamp(0.04, 0.98),
            level,
            s0: s0.clamp(0.0, 1.0),
            s1: s1.clamp(0.0, 1.0),
            grow_start: g_start,
            grow_end: g_end,
            sway_weight: sway,
            seed: rng.f32(),
            role,
            _pad: 0.0,
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LEVEL 0A: FLARE NEBARI CEKUNG (menyatu mulus ke akar energi cair taskbar)
    // Didesain melengkung tipis keluar menyusuri bibir atas taskbar (y ~ 0..-6)
    // tanpa bulatan menggantung ke bawah.
    // ─────────────────────────────────────────────────────────────────────────
    let nebari_defs: [([[f32; 2]; 3], f32, f32, f32); 4] = [
        (
            [
                [-36.0 * sc * thick, -2.0 * sc],
                [-18.0 * sc * thick, -10.0 * sc],
                [-11.0 * sc, -38.0 * sc],
            ],
            5.0 * thick * sc,
            12.5 * thick * sc,
            0.40,
        ),
        (
            [
                [-20.0 * sc * thick, -1.0 * sc],
                [-11.0 * sc * thick, -13.0 * sc],
                [-5.0 * sc, -44.0 * sc],
            ],
            8.0 * thick * sc,
            15.5 * thick * sc,
            0.55,
        ),
        (
            [
                [22.0 * sc * thick, -1.0 * sc],
                [13.0 * sc * thick, -14.0 * sc],
                [7.0 * sc, -46.0 * sc],
            ],
            9.0 * thick * sc,
            16.0 * thick * sc,
            0.58,
        ),
        (
            [
                [42.0 * sc * thick, -2.0 * sc],
                [24.0 * sc * thick, -9.0 * sc],
                [14.0 * sc, -34.0 * sc],
            ],
            5.5 * thick * sc,
            11.5 * thick * sc,
            0.44,
        ),
    ];

    for (ctrl, ra, rb, dp) in &nebari_defs {
        let pts = catmull_rom_chain(ctrl, 3);
        let n_p = pts.len();
        for i in 0..(n_p - 1) {
            let u0 = (i as f32) / ((n_p - 1) as f32);
            let u1 = ((i + 1) as f32) / ((n_p - 1) as f32);
            let r0 = ra + (rb - ra) * u0;
            let r1 = ra + (rb - ra) * u1;
            push_seg(
                &mut segs,
                max_segs,
                &mut rng,
                pts[i],
                pts[i + 1],
                r0,
                r1,
                *dp,
                0.0,
                u0 * 0.09,
                u1 * 0.09,
                0.0,
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LEVEL 0B: BATANG UTAMA KEKAR & BERLEKUK (*Tachiagari* C/S-Arch)
    // Tetap kompak & berotot di sisi kiri lalu melengkung kuat searah angin.
    // ─────────────────────────────────────────────────────────────────────────
    let lean_sc = (0.76 + lean * 0.62) * sc;
    let jx = rng.range(-5.0, 5.0) * sc;
    let spine_ctrl = [
        [0.0, -3.0 * sc],
        [-9.0 * sc + jx * 0.3, -48.0 * sc],
        [-25.0 * sc + jx * 0.6, -108.0 * sc], // Bahu windward berotot
        [-17.0 * sc + jx * 0.5, -174.0 * sc], // Angkatan vertikal kokoh
        [14.0 * lean_sc + jx * 0.4, -236.0 * sc],
        [56.0 * lean_sc + jx * 0.3, -284.0 * sc],
        [98.0 * lean_sc, -316.0 * sc],
        [146.0 * lean_sc, -332.0 * sc], // Puncak inti mahkota
    ];

    let raw_trunk = catmull_rom_chain(&spine_ctrl, 3);
    let n_tn = raw_trunk.len();
    let mut trunk_nodes: Vec<([f32; 2], f32)> = Vec::with_capacity(n_tn);
    let mut trunk_radii: Vec<f32> = Vec::with_capacity(n_tn);

    for (i, &pt) in raw_trunk.iter().enumerate() {
        let s = (i as f32) / ((n_tn - 1) as f32);
        // Kontras taper dramatis khas bonsai tua: pangkal sangat kokoh -> mahkota ramping
        let taper = (1.0 - s).powf(1.42) * (0.78 + 0.22 * (s * std::f32::consts::FRAC_PI_2).cos());
        let gnarl_burl = 1.0 + 0.09 * (s * 19.0 + 0.5).sin() * (1.0 - s * 0.4);
        let r = (r_base * taper * gnarl_burl).max(3.6 * sc);
        trunk_nodes.push((pt, s));
        trunk_radii.push(r);
    }

    for i in 0..(n_tn - 1) {
        let (p0, s0) = trunk_nodes[i];
        let (p1, s1) = trunk_nodes[i + 1];
        push_seg(
            &mut segs,
            max_segs,
            &mut rng,
            p0,
            p1,
            trunk_radii[i],
            trunk_radii[i + 1],
            0.50,
            0.0,
            s0 * 0.52,
            s1 * 0.52,
            0.0,
        );
    }

    // Dahan kembar dalam (twin gnarled inner leader) keluar dari bahu batang (s ~ 0.32)
    let sh_i = ((0.32 * ((n_tn - 1) as f32)) as usize).min(n_tn - 1);
    let (sh_pt, _) = trunk_nodes[sh_i];
    let leader2_ctrl = [
        [sh_pt[0] + 6.0 * sc, sh_pt[1]],
        [sh_pt[0] + 48.0 * sc, sh_pt[1] - 46.0 * sc],
        [sh_pt[0] + 98.0 * sc, sh_pt[1] - 80.0 * sc],
        [sh_pt[0] + 158.0 * sc, sh_pt[1] - 92.0 * sc],
    ];
    let l2_pts = catmull_rom_chain(&leader2_ctrl, 3);
    let l2_r0 = trunk_radii[sh_i] * 0.62;
    for i in 0..(l2_pts.len() - 1) {
        let u0 = (i as f32) / ((l2_pts.len() - 1) as f32);
        let u1 = ((i + 1) as f32) / ((l2_pts.len() - 1) as f32);
        let r0 = (l2_r0 * (1.0 - u0 * 0.75).powf(1.2)).max(2.8 * sc);
        let r1 = (l2_r0 * (1.0 - u1 * 0.75).powf(1.2)).max(2.4 * sc);
        push_seg(
            &mut segs,
            max_segs,
            &mut rng,
            l2_pts[i],
            l2_pts[i + 1],
            r0,
            r1,
            0.42,
            1.0,
            0.22 + u0 * 0.34,
            0.22 + u1 * 0.34,
            0.0,
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RAMIFIKASI REKURSIF TINGKAT 2 -> 3 -> 4 (RANTING MIKRO HALUS SEARAH ANGIN)
    // ─────────────────────────────────────────────────────────────────────────
    #[allow(clippy::too_many_arguments)]
    fn grow_twig(
        segs: &mut Vec<BonsaiSegGpu>,
        max_segs: usize,
        rng: &mut Rng,
        sc: f32,
        low_quality: bool,
        start: [f32; 2],
        ang: f32,
        length: f32,
        r_start: f32,
        level: u32,
        depth: f32,
        s_start: f32,
        wind_bias: f32,
        role: f32,
    ) {
        if segs.len() >= max_segs || level > 4 || r_start < 0.38 * sc || length < 5.5 * sc {
            return;
        }

        let steps = if level == 2 { 2 } else { 1 };
        let mut cur = start;
        let mut cur_ang = ang;
        let mut cur_r = r_start;
        let mut cur_s = s_start;
        let s_span = (1.0 - s_start)
            * match level {
                2 => 0.34,
                3 => 0.52,
                _ => 0.95,
            };

        for k in 0..steps {
            let pull = if level == 2 { 0.38 } else { 0.48 };
            let wiggle = if level >= 3 {
                rng.range(-0.34, 0.34)
            } else {
                rng.range(-0.24, 0.24)
            };
            cur_ang = (cur_ang + (wind_bias - cur_ang) * pull + wiggle).clamp(-1.15, 0.55);

            let seg_l = (length / (steps as f32)) * rng.range(0.82, 1.18);
            let nxt = [cur[0] + cur_ang.cos() * seg_l, cur[1] + cur_ang.sin() * seg_l];
            let nxt_r = (cur_r * if level == 2 { 0.72 } else { 0.64 }).max(0.38 * sc);
            let nxt_s = (cur_s + s_span / (steps as f32)).min(1.0);

            push_seg(
                segs,
                max_segs,
                rng,
                cur,
                nxt,
                cur_r,
                nxt_r,
                depth,
                level as f32,
                cur_s,
                nxt_s,
                role,
            );

            // Cabang samping pada ruas pertama level 2 untuk kepadatan lapisan horizontal
            if level == 2 && k == 0 && rng.f32() < 0.80 {
                let side = if rng.f32() < 0.55 { -1.0 } else { 1.0 };
                let c_ang = cur_ang + side * rng.range(0.32, 0.65);
                let c_d = (depth + rng.range(-0.22, 0.22)).clamp(0.06, 0.96);
                let c_len = length * rng.range(0.52, 0.72);
                grow_twig(
                    segs,
                    max_segs,
                    rng,
                    sc,
                    low_quality,
                    nxt,
                    c_ang,
                    c_len,
                    nxt_r * 0.72,
                    3,
                    c_d,
                    nxt_s,
                    wind_bias,
                    role,
                );
            }

            cur = nxt;
            cur_r = nxt_r;
            cur_s = nxt_s;
        }

        if level < 4 {
            let spreads: &[f32] = if level == 2 {
                if low_quality {
                    &[-0.38, 0.34]
                } else {
                    &[-0.48, 0.02, 0.44]
                }
            } else if !low_quality || rng.f32() < 0.65 {
                &[-0.42, 0.36]
            } else {
                &[0.04]
            };

            for &sp in spreads {
                let c_ang = cur_ang + sp + rng.range(-0.14, 0.14);
                let c_len = length * rng.range(0.58, 0.78);
                let c_r = cur_r * rng.range(0.60, 0.76);
                let c_d = (depth + rng.range(-0.20, 0.20)).clamp(0.05, 0.97);
                grow_twig(
                    segs,
                    max_segs,
                    rng,
                    sc,
                    low_quality,
                    cur,
                    c_ang,
                    c_len,
                    c_r,
                    level + 1,
                    c_d,
                    cur_s,
                    wind_bias,
                    role,
                );
            }
        } else if !low_quality && rng.f32() < 0.72 {
            // Ujung ranting rambut kembar (*winter bonsai tip flick*)
            for &sp in &[-0.34_f32, 0.22] {
                let ta = cur_ang + sp + rng.range(-0.12, 0.12);
                let tl = rng.range(6.0, 13.0) * sc;
                let tip = [cur[0] + ta.cos() * tl, cur[1] + ta.sin() * tl];
                push_seg(
                    segs,
                    max_segs,
                    rng,
                    cur,
                    tip,
                    cur_r,
                    0.36 * sc,
                    depth,
                    4.0,
                    cur_s,
                    1.0,
                    role,
                );
            }
        }
    }

    // Helper bangun 1 dahan primer berlekuk + taburan ranting mikro horizontal di sepanjangnya
    #[allow(clippy::too_many_arguments)]
    fn build_primary_limb(
        segs: &mut Vec<BonsaiSegGpu>,
        max_segs: usize,
        rng: &mut Rng,
        sc: f32,
        low_quality: bool,
        start_pt: [f32; 2],
        r_start: f32,
        s_start: f32,
        ctrl_offsets: &[[f32; 2]],
        depth: f32,
        pad_scale: f32,
        wind_bias: f32,
        role: f32,
    ) -> [f32; 2] {
        let mut pts_ctrl = Vec::with_capacity(ctrl_offsets.len() + 1);
        pts_ctrl.push(start_pt);
        for &[dx, dy] in ctrl_offsets {
            pts_ctrl.push([start_pt[0] + dx * sc, start_pt[1] + dy * sc]);
        }
        let pts = catmull_rom_chain(&pts_ctrl, 2);
        let n_p = pts.len();
        let mut cur_r = r_start;
        let mut cur_s = s_start;

        for i in 0..(n_p - 1) {
            let u = (i as f32) / ((n_p - 2).max(1) as f32);
            let a = pts[i];
            let b = pts[i + 1];
            let frac_next = ((i + 1) as f32) / ((n_p - 1) as f32);
            let nxt_r = (r_start * (1.0 - frac_next * 0.78).powf(1.15)).max(1.6 * sc);
            let nxt_s = (s_start + (0.76 - s_start) * frac_next).min(0.80);

            push_seg(segs, max_segs, rng, a, b, cur_r, nxt_r, depth, 1.0, cur_s, nxt_s, role);

            let seg_ang = (b[1] - a[1]).atan2(b[0] - a[0]);
            if i >= 1 {
                let n_sprays = if i >= 2 && !low_quality { 2 } else { 1 };
                for sp_i in 0..n_sprays {
                    let side = if sp_i % 2 == 0 { -1.0 } else { 1.0 };
                    let spray_ang = seg_ang + side * rng.range(0.28, 0.62) - 0.12;
                    let spray_len =
                        (34.0 + 20.0 * (1.0 - 0.35 * u)) * sc * pad_scale * rng.range(0.82, 1.18);
                    let spray_r = (nxt_r * rng.range(0.55, 0.72)).max(1.0 * sc);
                    let spray_d = (depth + side * rng.range(0.10, 0.24)).clamp(0.08, 0.94);
                    grow_twig(
                        segs,
                        max_segs,
                        rng,
                        sc,
                        low_quality,
                        b,
                        spray_ang,
                        spray_len,
                        spray_r,
                        2,
                        spray_d,
                        nxt_s,
                        wind_bias,
                        role,
                    );
                }
            }
            cur_r = nxt_r;
            cur_s = nxt_s;
        }

        let end_pt = pts[n_p - 1];
        let prev_pt = pts[n_p - 2];
        let end_ang = (end_pt[1] - prev_pt[1]).atan2(end_pt[0] - prev_pt[0]);
        for &sp in &[-0.34_f32, -0.02, 0.28] {
            grow_twig(
                segs,
                max_segs,
                rng,
                sc,
                low_quality,
                end_pt,
                end_ang + sp,
                44.0 * sc * pad_scale,
                (cur_r * 0.85).max(1.1 * sc),
                2,
                depth,
                cur_s,
                wind_bias,
                role,
            );
        }
        end_pt
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LEVEL 1: 7 DAHAN PRIMER BERTINGKAT (*WINDSWEPT TIERS* SEPERTI REFERENSI)
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Dahan galeri bawah menyapu ke kanan (ruang negatif tegas di atasnya!)
    let p_low = l2_pts[l2_pts.len() / 2];
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        p_low, l2_r0 * 0.60, 0.38,
        &[[55.0, 8.0], [118.0, -6.0], [185.0, 4.0], [238.0, -10.0]],
        0.66, 0.94, -0.02, 0.0,
    );

    // 2. Dahan tengah-bawah dari ujung leader2
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        l2_pts[l2_pts.len() - 1], l2_r0 * 0.42, 0.52,
        &[[56.0, -16.0], [124.0, -10.0], [195.0, -24.0], [264.0, -18.0]],
        0.46, 1.08, -0.05, 0.0,
    );

    // 3. Dahan utama tengah-atas (jangkauan sapuan angin paling dramatis!)
    let i_mid = ((0.58 * ((n_tn - 1) as f32)) as usize).min(n_tn - 1);
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        trunk_nodes[i_mid].0, trunk_radii[i_mid] * 0.62, 0.40,
        &[[48.0, -26.0], [118.0, -36.0], [198.0, -24.0], [278.0, -36.0], [348.0, -28.0]],
        0.72, 1.12, -0.04, 0.0,
    );

    // 4. Dahan lapisan belakang (lebih gelap -> memberi kedalaman 3D antar-ranting!)
    let i_back = ((0.68 * ((n_tn - 1) as f32)) as usize).min(n_tn - 1);
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        trunk_nodes[i_back].0, trunk_radii[i_back] * 0.58, 0.44,
        &[[58.0, -18.0], [132.0, -32.0], [212.0, -26.0], [282.0, -34.0]],
        0.20, 1.02, -0.06, 0.0,
    );

    // 5. Dahan kubah mahkota atas-kiri (mengisi puncak dome tepat di atas batang)
    let i_up = ((0.76 * ((n_tn - 1) as f32)) as usize).min(n_tn - 1);
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        trunk_nodes[i_up].0, trunk_radii[i_up] * 0.65, 0.46,
        &[[-16.0, -34.0], [24.0, -58.0], [84.0, -64.0], [150.0, -54.0]],
        0.58, 0.96, -0.08, 0.0,
    );

    // 6. Dahan mahkota puncak (`role = 1.0`: cabang atas fix, anchor Search Bar nanti!)
    let top_pt = trunk_nodes[n_tn - 1].0;
    let top_r = trunk_radii[n_tn - 1] * 0.92;
    let apex_end = build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        top_pt, top_r, 0.52,
        &[[52.0, -22.0], [116.0, -28.0], [188.0, -18.0], [256.0, -22.0]],
        0.62, 0.95, -0.03, 1.0,
    );
    let search_anchor = [0.5 * (top_pt[0] + apex_end[0]), top_pt[1].min(apex_end[1]) - 18.0 * sc];

    // 7. Dahan bahu belakang kiri-atas (membentuk bahu kubah kanopi seperti referensi)
    let i_sh = ((0.48 * ((n_tn - 1) as f32)) as usize).min(n_tn - 1);
    build_primary_limb(
        &mut segs, max_segs, &mut rng, sc, low_quality,
        trunk_nodes[i_sh].0, trunk_radii[i_sh] * 0.45, 0.36,
        &[[-28.0, -32.0], [-14.0, -68.0], [26.0, -86.0], [78.0, -82.0]],
        0.28, 0.82, -0.10, 0.0,
    );

    // Urutkan dari belakang ke depan (painter's algorithm) agar lapisan 2.5D rapi
    segs.sort_by(|a, b| {
        a.depth_layer
            .partial_cmp(&b.depth_layer)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GENERATOR KLASTER BUNGA SAKURA (HANAGASUMI) PADA RANTING LEVEL 3 & 4
    // ─────────────────────────────────────────────────────────────────────────
    let max_blossoms = if low_quality { 280 } else { MAX_TREE_BLOSSOMS };
    let mut blossoms: Vec<SakuraBlossomGpu> = Vec::with_capacity(max_blossoms);

    // Kumpulkan segmen ranting terluar (level >= 3.0) sebagai jangkar dompolan
    for (idx, seg) in segs.iter().enumerate() {
        if blossoms.len() >= max_blossoms {
            break;
        }
        if seg.level >= 3.0 && seg.r1 < 2.8 * sc {
            let cluster_id = idx as f32;
            let n_flowers = if seg.level >= 4.0 { 4 } else { 3 };

            for f_idx in 0..n_flowers {
                if blossoms.len() >= max_blossoms {
                    break;
                }
                let ang = rng.range(0.0, std::f32::consts::TAU);
                let dist = rng.range(2.0, 14.5) * sc;
                let px = seg.b[0] + ang.cos() * dist;
                let py = seg.b[1] + ang.sin() * dist;
                let r_bloom = rng.range(4.2, 7.8) * sc;
                let rot = rng.range(0.0, std::f32::consts::TAU);
                let stage = if f_idx == 0 {
                    0.45 // kuncup (tsubomi)
                } else {
                    rng.range(0.85, 1.0) // mekar penuh (mankai)
                };
                let depth = (seg.depth_layer + rng.range(-0.15, 0.15)).clamp(0.05, 0.95);

                blossoms.push(SakuraBlossomGpu {
                    pos: [px, py],
                    radius: r_bloom,
                    rot,
                    cluster_id,
                    depth_layer: depth,
                    stage,
                    sway_weight: seg.sway_weight,
                });
            }
        }
    }

    // Urutkan blossom berdasarkan depth_layer (painter's sort)
    blossoms.sort_by(|a, b| {
        a.depth_layer
            .partial_cmp(&b.depth_layer)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let blossom_count = blossoms.len().min(MAX_TREE_BLOSSOMS) as u32;
    blossoms.resize(MAX_TREE_BLOSSOMS, SakuraBlossomGpu::zeroed());

    let seg_count = segs.len().min(MAX_TREE_SEGS) as u32;
    // Pad hingga MAX_TREE_SEGS agar `queue.write_buffer` ukuran tetap & aman
    segs.resize(MAX_TREE_SEGS, BonsaiSegGpu::zeroed());

    ProceduralTreeData {
        segs,
        seg_count,
        blossoms,
        blossom_count,
        search_anchor,
    }
}
