use bytemuck::{Pod, Zeroable};

pub const MAX_ROOT_SEGS: usize = 96;

/// Satu segmen kapsul akar meruncing (48 byte = 3x vec4<f32>, 16-byte aligned untuk GPU uniform buffer).
///
/// Sistem koordinat RELATIF TERHADAP `tree_base = (bar_left + 78.0, bar_top + 11.0)` (pusat nebari / pangkal akar):
/// - `a.x`, `b.x`: offset horizontal (px) dari `tree_base.x`:
///     * Negatif = akar penahan angin kiri (*windward tension roots*) memeluk bahu kiri taskbar
///     * Positif = akar kanan panjang (di-skala proporsional terhadap lebar taskbar di shader agar selalu
///       menjalar anggun ~85% lebar bar dan semakin tipis meruncing ke kanan!)
/// - `a.y`, `b.y`: offset vertikal (px) dari `tree_base.y` (`bar_top` di `y = -11.0`).
/// - `arc0`, `arc1`: panjang busur kontinu `0.0` (pangkal batang) -> `1.0` (ujung akar).
/// - `root_id`: indeks akar utama untuk variasi gelombang energi cair.
/// - `layer_phase`: menyimpan `chain_id` kontinu per rantai akar (0.0, 1.0, 2.0, ...) agar GPU
///   menggabungkan segmen dalam satu rantai memakai exact `min()` (ZERO benjolan ruas) dan
///   memakai `smin_cubic()` hanya saat dua rantai berbeda bertemu.
#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct RootSegGpu {
    pub a: [f32; 2],
    pub b: [f32; 2],
    pub r0: f32,
    pub r1: f32,
    pub depth: f32,
    pub stagger: f32,
    pub arc0: f32,
    pub arc1: f32,
    pub root_id: f32,
    pub layer_phase: f32,
}

/// Deterministic XorShift64* PRNG untuk generator akar prosedural berbasis seed YAML.
struct Rng(u64);

impl Rng {
    fn new(seed: u64) -> Self {
        Self(if seed == 0 { 0x9E37_79B9_7F4A_7C15 } else { seed })
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

#[inline]
fn smoothstep_rs(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Penipisan nebari bonsai non-linear:
/// - `long_right = true`: tebal berotot di pangkal nebari, lalu menipis progresif & kontinu sepanjang
///   jalur panjang ke kanan hingga menjadi filamen energi cair setipis benang di ujung jauh.
/// - `long_right = false`: penipisan organik untuk akar penahan angin sisi kiri.
#[inline]
fn nebari_taper(r_start: f32, r_end: f32, u: f32, long_right: bool) -> f32 {
    let u_c = u.clamp(0.0, 1.0);
    let k = if long_right {
        let buttress_drop = 1.0 - 0.58 * (1.0 - (-7.5 * u_c).exp());
        let progressive = (1.0 - u_c).powf(1.35);
        (buttress_drop * (0.28 + 0.72 * progressive)).clamp(0.0, 1.0)
    } else {
        let buttress_drop = 1.0 - 0.62 * (1.0 - (-6.0 * u_c).exp());
        let tip_pinch = 1.0 - 0.86 * smoothstep_rs(0.48, 1.0, u_c);
        (buttress_drop * tip_pinch).clamp(0.0, 1.0)
    };
    r_end + (r_start - r_end) * k
}

/// Evaluasi spline Catmull-Rom 2D halus pada parameter `t` in [0, 1].
#[inline]
fn catmull_rom(p0: [f32; 2], p1: [f32; 2], p2: [f32; 2], p3: [f32; 2], t: f32) -> [f32; 2] {
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
    [x, y]
}

fn sample_smooth_curve(ctrl: &[[f32; 2]], total_segs: usize) -> Vec<[f32; 2]> {
    let n = ctrl.len();
    if n < 2 || total_segs == 0 {
        return ctrl.to_vec();
    }
    let spans = n - 1;
    let mut pts = Vec::with_capacity(total_segs + 1);
    for s in 0..=total_segs {
        let u = (s as f32) / (total_segs as f32);
        let scaled = u * (spans as f32);
        let idx = (scaled.floor() as usize).min(spans - 1);
        let local_t = (scaled - idx as f32).clamp(0.0, 1.0);

        let p0 = if idx == 0 {
            [2.0 * ctrl[0][0] - ctrl[1][0], 2.0 * ctrl[0][1] - ctrl[1][1]]
        } else {
            ctrl[idx - 1]
        };
        let p1 = ctrl[idx];
        let p2 = ctrl[idx + 1];
        let p3 = if idx + 2 >= n {
            [
                2.0 * ctrl[n - 1][0] - ctrl[n - 2][0],
                2.0 * ctrl[n - 1][1] - ctrl[n - 2][1],
            ]
        } else {
            ctrl[idx + 2]
        };
        pts.push(catmull_rom(p0, p1, p2, p3, local_t));
    }
    pts
}

#[allow(clippy::too_many_arguments)]
fn emit_smooth_chain(
    segs: &mut [RootSegGpu; MAX_ROOT_SEGS],
    count: &mut usize,
    chain_counter: &mut u32,
    max_budget: usize,
    ctrl: &[[f32; 2]],
    num_segs: usize,
    r_start: f32,
    r_end: f32,
    depth: u32,
    stagger_start: f32,
    stagger_span: f32,
    arc_start: f32,
    arc_end: f32,
    root_id: u32,
    long_right: bool,
) -> Vec<([f32; 2], f32, f32, f32)> {
    let pts = sample_smooth_curve(ctrl, num_segs);
    let mut anchors = Vec::with_capacity(pts.len());
    let actual_segs = pts.len().saturating_sub(1);
    let chain_id = *chain_counter as f32;
    *chain_counter += 1;

    for i in 0..actual_segs {
        if *count >= max_budget {
            break;
        }
        let u0 = (i as f32) / (actual_segs as f32);
        let u1 = ((i + 1) as f32) / (actual_segs as f32);

        let a = pts[i];
        let b = pts[i + 1];
        let r0 = nebari_taper(r_start, r_end, u0, long_right).max(0.22);
        let r1 = nebari_taper(r_start, r_end, u1, long_right).max(0.18);
        let arc0 = arc_start + (arc_end - arc_start) * u0;
        let arc1 = arc_start + (arc_end - arc_start) * u1;
        let stagger = (stagger_start + stagger_span * u0).clamp(0.0, 0.78);

        segs[*count] = RootSegGpu {
            a,
            b,
            r0,
            r1,
            depth: depth as f32,
            stagger,
            arc0,
            arc1,
            root_id: root_id as f32,
            layer_phase: chain_id,
        };
        *count += 1;

        let ang = (b[1] - a[1]).atan2(b[0] - a[0]);
        anchors.push((b, ang, r1, arc1));
    }
    anchors
}

/// Generator akar bonsai Fukinagashi energi cair lembut:
/// - Sisi KIRI diperkaya (5 rantai = 32 segmen): akar penahan angin (*windward tension roots*) yang
///   mencengkeram penuh lengkungan sudut & bahu kiri taskbar hingga ke tepi kiri-bawah beserta 2 cabang halus.
/// - Sisi KANAN diperpanjang jauh (7 rantai = 63 segmen, hingga ~770px relatif): menjalar luwes di zona
///   langit gelap (bersih di atas ombak Kanagawa) dan semakin tipis meruncing menjadi filamen energi cair.
pub fn generate_procedural_roots(seed: u64, low_quality: bool) -> ([RootSegGpu; MAX_ROOT_SEGS], u32) {
    let mut segs = [RootSegGpu::zeroed(); MAX_ROOT_SEGS];
    let mut count = 0usize;
    let mut chain_counter = 0u32;
    let max_budget = if low_quality { 40 } else { MAX_ROOT_SEGS };
    let mut rng = Rng::new(seed);

    let j_right = |rng: &mut Rng, base: f32, amp: f32| -> f32 {
        (base + rng.range(-amp, amp)).clamp(-11.5, 22.0)
    };
    let j_left = |rng: &mut Rng, base: f32, amp: f32| -> f32 {
        (base + rng.range(-amp, amp)).clamp(-12.5, 70.0)
    };

    // ─────────────────────────────────────────────────────────────────────────
    // BAGIAN KIRI (DIPERKAYA): AKAR PENAHAN ANGIN FUKINAGASHI (5 rantai, 32 seg)
    // ─────────────────────────────────────────────────────────────────────────

    // L1: Akar Penahan Utama Kiri — mulai flush di dinding kiri batang, flare nebari lebar,
    // lalu mencengkeram penuh lengkungan bahu kiri sampai jauh ke tepi kiri-bawah.
    let l1_ctrl = [
        [1.5, -22.0],
        [-8.0, -8.5],
        [-22.5, j_left(&mut rng, -2.5, 1.0)],
        [-40.5, j_left(&mut rng, 0.5, 1.2)],
        [-56.5, j_left(&mut rng, 11.5, 1.4)],
        [-68.5, j_left(&mut rng, 29.5, 1.6)],
        [-75.0, j_left(&mut rng, 51.0, 1.8)],
        [-77.0, j_left(&mut rng, 67.5, 1.8)],
    ];
    let a_l1 = emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &l1_ctrl,
        if low_quality { 6 } else { 10 },
        7.4, 0.30, 0, 0.01, 0.28, 0.0, 1.0, 4, false,
    );

    // L2: Akar Bibir Kiri-Atas — mencengkeram bibir atas lalu melengkung anggun mengikuti sudut kiri
    let l2_ctrl = [
        [0.0, -17.5],
        [-13.0, j_left(&mut rng, -10.0, 0.8)],
        [-30.5, j_left(&mut rng, -11.0, 0.9)],
        [-48.5, j_left(&mut rng, -7.0, 1.0)],
        [-63.5, j_left(&mut rng, 4.5, 1.2)],
        [-72.5, j_left(&mut rng, 21.5, 1.4)],
    ];
    let a_l2 = emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &l2_ctrl,
        if low_quality { 5 } else { 7 },
        5.2, 0.26, 0, 0.02, 0.24, 0.0, 1.0, 5, false,
    );

    // L3: Akar Nebari Depan-Kiri — meleburkan dasar batang ke kiri, memeluk sudut atas-kiri tombol Windows
    let l3_ctrl = [
        [-0.5, -14.0],
        [-5.5, 2.5],
        [-18.0, j_left(&mut rng, 10.5, 1.0)],
        [-35.0, j_left(&mut rng, 11.5, 1.2)],
        [-49.5, j_left(&mut rng, 21.0, 1.4)],
        [-58.0, j_left(&mut rng, 35.5, 1.5)],
    ];
    emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &l3_ctrl,
        if low_quality { 4 } else { 6 },
        5.8, 0.28, 0, 0.02, 0.24, 0.0, 1.0, 6, false,
    );

    if !low_quality {
        // L1a: Cabang sekunder luar kiri dari L1 menyusuri tepi luar kiri ke bawah
        if let Some(&(pos, _ang, rad, arc)) = a_l1.get(4.min(a_l1.len().saturating_sub(1))) {
            let ctrl = [
                pos,
                [pos[0] - 8.5, j_left(&mut rng, pos[1] + 10.5, 1.0)],
                [pos[0] - 14.5, j_left(&mut rng, pos[1] + 24.5, 1.2)],
                [pos[0] - 17.5, j_left(&mut rng, pos[1] + 38.0, 1.4)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 5,
                rad * 0.74, 0.22, 1, 0.18, 0.22, arc, 1.0, 4, false,
            );
        }

        // L2a: Cabang sulur halus kiri-atas dari L2 melengkung ke kantong kiri luar
        if let Some(&(pos, _ang, rad, arc)) = a_l2.get(3.min(a_l2.len().saturating_sub(1))) {
            let ctrl = [
                pos,
                [pos[0] - 11.0, j_left(&mut rng, pos[1] + 6.5, 1.0)],
                [pos[0] - 20.5, j_left(&mut rng, pos[1] + 16.5, 1.2)],
                [pos[0] - 26.0, j_left(&mut rng, pos[1] + 27.5, 1.4)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 4,
                rad * 0.72, 0.22, 1, 0.20, 0.22, arc, 1.0, 5, false,
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BAGIAN KANAN (LEBIH PANJANG & SEMAKIN TIPIS): 7 rantai, 63 segmen
    // ─────────────────────────────────────────────────────────────────────────

    // R1: Filamen Utama Panjang Kanan (~715-775px, menipis progresif hingga setipis benang di kanan!)
    let r1_len = rng.range(715.0, 775.0);
    let r1_ctrl = [
        [4.8, -25.0],
        [12.0, -9.0],
        [32.0, j_right(&mut rng, -3.5, 1.0)],
        [r1_len * 0.13, j_right(&mut rng, -8.5, 1.2)],
        [r1_len * 0.26, j_right(&mut rng, -2.5, 1.4)],
        [r1_len * 0.40, j_right(&mut rng, -7.5, 1.4)],
        [r1_len * 0.56, j_right(&mut rng, -1.0, 1.5)],
        [r1_len * 0.73, j_right(&mut rng, -5.5, 1.4)],
        [r1_len * 0.88, j_right(&mut rng, -1.5, 1.2)],
        [r1_len, j_right(&mut rng, -3.5, 1.0)],
    ];
    let a_r1 = emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &r1_ctrl,
        if low_quality { 10 } else { 20 },
        8.4, 0.20, 0, 0.01, 0.36, 0.0, 1.0, 0, true,
    );

    // R2: Akar Kanan Menengah Panjang di Langit Gelap (~545-605px, bersih di atas ombak)
    let r2_len = rng.range(545.0, 605.0);
    let r2_ctrl = [
        [2.8, -17.5],
        [11.5, 0.5],
        [36.0, j_right(&mut rng, 7.5, 1.2)],
        [r2_len * 0.18, j_right(&mut rng, 4.5, 1.4)],
        [r2_len * 0.34, j_right(&mut rng, 12.5, 1.6)],
        [r2_len * 0.52, j_right(&mut rng, 8.0, 1.6)],
        [r2_len * 0.70, j_right(&mut rng, 13.5, 1.5)],
        [r2_len * 0.86, j_right(&mut rng, 9.0, 1.3)],
        [r2_len, j_right(&mut rng, 11.0, 1.2)],
    ];
    let a_r2 = emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &r2_ctrl,
        if low_quality { 8 } else { 15 },
        6.8, 0.20, 0, 0.02, 0.34, 0.0, 1.0, 1, true,
    );

    // R3: Akar Penopang Depan-Kanan (~215-260px) — menopang volume pangkal nebari lalu meruncing halus
    let r3_len = rng.range(215.0, 260.0);
    let r3_ctrl = [
        [0.5, -13.5],
        [7.0, 4.5],
        [26.0, j_right(&mut rng, 14.5, 1.2)],
        [r3_len * 0.36, j_right(&mut rng, 19.0, 1.5)],
        [r3_len * 0.68, j_right(&mut rng, 15.0, 1.4)],
        [r3_len, j_right(&mut rng, 18.0, 1.3)],
    ];
    emit_smooth_chain(
        &mut segs, &mut count, &mut chain_counter, max_budget, &r3_ctrl,
        if low_quality { 5 } else { 8 },
        5.8, 0.24, 0, 0.03, 0.26, 0.0, 1.0, 2, true,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // CABANG SEKUNDER & FILAMEN HALUS KANAN (makin ke kanan makin tipis & lembut)
    // ─────────────────────────────────────────────────────────────────────────
    if !low_quality {
        // R1a: Cabang sekunder dari R1 (~22%) masuk lembut ke langit gelap
        if let Some(&(pos, _ang, rad, arc)) = a_r1.get(4.min(a_r1.len().saturating_sub(1))) {
            let len = rng.range(155.0, 195.0);
            let ctrl = [
                pos,
                [pos[0] + len * 0.26, j_right(&mut rng, pos[1] + 7.0, 1.2)],
                [pos[0] + len * 0.60, j_right(&mut rng, pos[1] + 13.0, 1.4)],
                [pos[0] + len, j_right(&mut rng, pos[1] + 9.0, 1.4)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 6,
                rad * 0.72, 0.20, 1, 0.16, 0.28, arc, 1.0, 0, true,
            );
        }

        // R1b: Cabang filamen panjang dari R1 (~52%) menyebar tipis ke kanan jauh
        if let Some(&(pos, _ang, rad, arc)) = a_r1.get(10.min(a_r1.len().saturating_sub(1))) {
            let len = rng.range(165.0, 210.0);
            let ctrl = [
                pos,
                [pos[0] + len * 0.28, j_right(&mut rng, pos[1] + 6.5, 1.2)],
                [pos[0] + len * 0.64, j_right(&mut rng, pos[1] + 10.5, 1.4)],
                [pos[0] + len, j_right(&mut rng, pos[1] + 6.5, 1.2)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 6,
                rad * 0.72, 0.18, 1, 0.28, 0.28, arc, 1.0, 0, true,
            );
        }

        // R2a: Cabang sekunder dari R2 (~34%) naik halus menuju bibir atas taskbar
        if let Some(&(pos, _ang, rad, arc)) = a_r2.get(5.min(a_r2.len().saturating_sub(1))) {
            let len = rng.range(138.0, 174.0);
            let ctrl = [
                pos,
                [pos[0] + len * 0.28, j_right(&mut rng, pos[1] - 5.5, 1.2)],
                [pos[0] + len * 0.66, j_right(&mut rng, pos[1] - 9.5, 1.2)],
                [pos[0] + len, j_right(&mut rng, pos[1] - 6.0, 1.2)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 4,
                rad * 0.72, 0.20, 1, 0.22, 0.28, arc, 1.0, 1, true,
            );
        }

        // R2b: Filamen halus ujung kanan dari R2 (~62%)
        if let Some(&(pos, _ang, rad, arc)) = a_r2.get(9.min(a_r2.len().saturating_sub(1))) {
            let len = rng.range(110.0, 145.0);
            let ctrl = [
                pos,
                [pos[0] + len * 0.45, j_right(&mut rng, pos[1] + 4.5, 1.2)],
                [pos[0] + len, j_right(&mut rng, pos[1] + 2.0, 1.2)],
            ];
            emit_smooth_chain(
                &mut segs, &mut count, &mut chain_counter, max_budget, &ctrl, 4,
                rad * 0.70, 0.18, 2, 0.34, 0.26, arc, 1.0, 1, true,
            );
        }
    }

    (segs, count as u32)
}
