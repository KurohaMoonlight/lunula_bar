use crate::config::StartTreeConfig;
use super::start_roots::{generate_procedural_roots, RootSegGpu, MAX_ROOT_SEGS};

/// State & fisika untuk Start Menu (Fukinagashi Bonsai Kanagawa Tree):
/// - Fase 1: Pill Search mencair jadi blob cairan tinta emas & tersedot ke tombol Windows
/// - Fase 2: Batang bonsai condong ke kanan (*fukinagashi*), menyatu mulus via smin ke taskbar,
///           akar energi-cair Catmull-Rom mengikuti kontur ombak h(x), partikel serbuk emas
///           tersedot spiral dengan velocity stretch, dan lilitan 2-layer + retakan Kintsugi.
pub struct StartMenuState {
    pub open: bool,
    pub phase1_t: f32,
    pub phase1_vel: f32,
    pub phase2_t: f32,
    pub phase2_vel: f32,
    /// Fase 3: Pertumbuhan akar Sakura (pangkal gendut + bentangan 80% taskbar + akar menyelam)
    pub root_grow_t: f32,
    pub root_grow_vel: f32,
    /// Reaksi interaktif lilitan tombol Windows saat ditekan (mengencang sesaat lalu rileks via pegas YAML)
    pub win_cinch: f32,
    pub win_cinch_vel: f32,
    /// Kilatan singkat retakan Kintsugi saat tombol Windows diklik (1.0 -> 0.0)
    pub win_flash: f32,
    /// Progres satu gelombang riak cahaya saat tombol Windows diklik (0.0 -> 1.0)
    pub win_ripple: f32,
    /// Intensitas tarikan partikel dinamis: lebih kuat saat pohon sedang tumbuh / Start baru dibuka, tenang saat idle
    pub pull_activity: f32,
    /// Akar prosedural yang digenerate dari `root_seed` YAML
    pub root_segs: [RootSegGpu; MAX_ROOT_SEGS],
    pub root_seg_count: u32,
    pub roots_dirty: bool,
    last_seed: u64,
    last_low_quality: bool,
}

impl StartMenuState {
    pub fn new(cfg: &StartTreeConfig) -> Self {
        let (root_segs, root_seg_count) = generate_procedural_roots(cfg.root_seed, cfg.low_quality);
        Self {
            open: false,
            phase1_t: 0.0,
            phase1_vel: 0.0,
            phase2_t: 0.0,
            phase2_vel: 0.0,
            root_grow_t: 0.0,
            root_grow_vel: 0.0,
            win_cinch: 0.0,
            win_cinch_vel: 0.0,
            win_flash: 0.0,
            win_ripple: 1.0,
            pull_activity: 0.55,
            root_segs,
            root_seg_count,
            roots_dirty: true,
            last_seed: cfg.root_seed,
            last_low_quality: cfg.low_quality,
        }
    }

    pub fn sync_config(&mut self, cfg: &StartTreeConfig) {
        if cfg.root_seed != self.last_seed || cfg.low_quality != self.last_low_quality {
            let (segs, cnt) = generate_procedural_roots(cfg.root_seed, cfg.low_quality);
            self.root_segs = segs;
            self.root_seg_count = cnt;
            self.roots_dirty = true;
            self.last_seed = cfg.root_seed;
            self.last_low_quality = cfg.low_quality;
        }
    }

    pub fn toggle(&mut self) {
        self.open = !self.open;
        // Impuls mengencang sesaat pada lilitan akar + kilatan Kintsugi + satu riak cahaya
        self.win_cinch_vel += 10.5;
        self.win_flash = 1.0;
        self.win_ripple = 0.0;
        if self.open {
            self.pull_activity = 1.65;
        }
        println!(
            "[Start Menu] {}",
            if self.open {
                "Membuka Start Menu..."
            } else {
                "Menutup Start Menu..."
            }
        );
    }

    pub fn open_now(&mut self) {
        if !self.open {
            self.toggle();
        }
    }

    pub fn close(&mut self) {
        if self.open {
            self.open = false;
        }
    }

    pub fn is_active(&self) -> bool {
        self.open || self.phase1_t > 0.005 || self.phase2_t > 0.005 || self.root_grow_t > 0.005
    }

    pub fn update(&mut self, dt: f32, cfg: &StartTreeConfig) {
        // Pegas impuls lilitan tombol Windows memakai parameter spring dari YAML
        let k_cinch = (cfg.spring.stiffness * 2.1).clamp(90.0, 320.0);
        let d_cinch = (cfg.spring.damping * 1.05).clamp(8.0, 26.0);
        let cinch_force = (0.0 - self.win_cinch) * k_cinch;
        self.win_cinch_vel += (cinch_force - self.win_cinch_vel * d_cinch) * dt;
        self.win_cinch = (self.win_cinch + self.win_cinch_vel * dt).clamp(-0.22, 1.0);

        // Peluruhan kilatan Kintsugi & satu gelombang riak cahaya saat tombol Windows diklik
        self.win_flash = (self.win_flash - dt * 2.1).max(0.0);
        if self.win_ripple < 1.0 {
            self.win_ripple = (self.win_ripple + dt * 1.55).min(1.0);
        }

        // Fase 1 (Search Pill Absorption ke Tombol Windows)
        let p1_target = if self.open {
            1.0
        } else {
            0.0
        };
        let (k1, d1) = if p1_target > 0.5 { (76.0, 14.0) } else { (90.0, 15.5) };
        self.phase1_vel += ((p1_target - self.phase1_t) * k1 - self.phase1_vel * d1) * dt;
        self.phase1_t += self.phase1_vel * dt;
        if self.phase1_t < 0.0 {
            self.phase1_t = 0.0;
            self.phase1_vel = self.phase1_vel.max(0.0);
        } else if self.phase1_t > 1.05 {
            self.phase1_t = 1.05;
            self.phase1_vel = self.phase1_vel.min(0.0);
        }

        // Fase 2 (Sakura Seed Outline Tracer: Meluncur dari Tombol Windows ke Tengah)
        // Mulai meluncur saat search pill sudah terserap ke tombol Windows (phase1_t > 0.38)
        let p2_target = if self.open && self.phase1_t > 0.38 {
            1.0
        } else {
            0.0
        };
        let (k2, d2) = if p2_target > 0.5 { (52.0, 13.5) } else { (85.0, 16.5) };
        self.phase2_vel += ((p2_target - self.phase2_t) * k2 - self.phase2_vel * d2) * dt;
        self.phase2_t += self.phase2_vel * dt;
        if self.phase2_t < 0.0 {
            self.phase2_t = 0.0;
            self.phase2_vel = self.phase2_vel.max(0.0);
        } else if self.phase2_t > 1.05 {
            self.phase2_t = 1.05;
            self.phase2_vel = self.phase2_vel.min(0.0);
        }

        // Fase 3 (Sakura Roots Growth: Membuka Pangkal Gendut di Tengah & Menjalar ke Kiri/Kanan 80% Taskbar)
        // Mulai mekar begitu benih tiba mendekati tengah layar (phase2_t > 0.72)
        let p3_target = if self.open && self.phase2_t > 0.72 {
            1.0
        } else {
            0.0
        };
        let (k3, d3) = if p3_target > 0.5 { (46.0, 12.0) } else { (75.0, 15.5) };
        self.root_grow_vel += ((p3_target - self.root_grow_t) * k3 - self.root_grow_vel * d3) * dt;
        self.root_grow_t += self.root_grow_vel * dt;
        if self.root_grow_t < 0.0 {
            self.root_grow_t = 0.0;
            self.root_grow_vel = self.root_grow_vel.max(0.0);
        } else if self.root_grow_t > 1.05 {
            self.root_grow_t = 1.05;
            self.root_grow_vel = self.root_grow_vel.min(0.0);
        }

        // Tarikan partikel dinamis: kuat saat baru buka (~1.55), tenang saat idle (~0.58)
        let target_pull = if self.open { 1.55 } else { 0.58 };
        self.pull_activity += (target_pull - self.pull_activity) * (dt * 2.4).min(1.0);

        if !self.open && self.phase1_t < 0.004 && self.phase1_vel.abs() < 0.05 && self.phase2_t < 0.004 && self.root_grow_t < 0.004 {
            self.phase1_t = 0.0;
            self.phase1_vel = 0.0;
            self.phase2_t = 0.0;
            self.phase2_vel = 0.0;
            self.root_grow_t = 0.0;
            self.root_grow_vel = 0.0;
        }
    }

    /// `[phase1_t, phase2_t, root_grow_t, win_cinch]`
    pub fn uniform_vec(&self, _screen_h: u32) -> [f32; 4] {
        [
            self.phase1_t.clamp(0.0, 1.05),
            self.phase2_t.clamp(0.0, 1.06),
            self.root_grow_t.clamp(0.0, 1.05),
            self.win_cinch,
        ]
    }

    /// `[root_seg_count, particle_count, particle_pull, low_quality_flag]`
    pub fn tree_params_vec(&self, cfg: &StartTreeConfig) -> [f32; 4] {
        let p_cnt = if cfg.low_quality {
            cfg.particle_count.min(20)
        } else {
            cfg.particle_count.clamp(8, 64)
        };
        [
            self.root_seg_count as f32,
            p_cnt as f32,
            cfg.particle_pull.clamp(0.2, 2.5),
            if cfg.low_quality { 1.0 } else { 0.0 },
        ]
    }

    /// `[trunk_style (0=hybrid, 1=liquid, 2=wood), trunk_thickness, trunk_lean, soul_leaves]`
    pub fn tree_style_vec(&self, cfg: &StartTreeConfig) -> [f32; 4] {
        [
            cfg.trunk_style as u32 as f32,
            cfg.trunk_thickness.clamp(0.7, 1.6),
            cfg.trunk_lean.clamp(0.15, 0.55),
            cfg.soul_leaves.clamp(0.0, 1.5),
        ]
    }

    /// `[win_flash, win_ripple, pull_activity, seed_phase]`
    pub fn start_fx_vec(&self) -> [f32; 4] {
        let seed_phase = ((self.last_seed % 1000) as f32) * 0.006283185;
        [
            self.win_flash.clamp(0.0, 1.0),
            self.win_ripple.clamp(0.0, 1.0),
            self.pull_activity.clamp(0.35, 1.8),
            seed_phase,
        ]
    }
}
