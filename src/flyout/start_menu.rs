use crate::config::StartTreeConfig;
use crate::render::text::TextEntry;
use super::search_index::{launch_target, SearchIndex, SearchResultItem};
use super::start_roots::{generate_procedural_roots, RootSegGpu, MAX_ROOT_SEGS};

/// State & fisika untuk Start Menu (Pohon Sakura Fukinagashi):
/// - Fase 1: Pill Search mencair jadi blob cairan tinta emas & tersedot ke tombol Windows
/// - Fase 2: Batang pohon sakura condong ke kanan (*fukinagashi*), menyatu mulus via smin ke taskbar,
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
    /// Fase 4: Pertumbuhan tunggul batang utama (stump) Sakura setinggi 10% layar & lebar 6% ke kiri/kanan
    pub stump_grow_t: f32,
    pub stump_grow_vel: f32,
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

    // ─────────────────────────────────────────────────────────────────────────
    // TAHAP 1 & 2: LUXURY ZEN SEARCH PILL & TANZAKU RESULT TAGS (Pohon Sakura)
    // ─────────────────────────────────────────────────────────────────────────
    pub search_query: String,
    pub search_cursor: usize,
    pub search_pill_t: f32,
    pub search_pill_vel: f32,
    pub cursor_blink: f32,
    /// Denyut cahaya emas Kintsugi saat pengguna mengetik di Search Bar (1.0 -> 0.0)
    pub typing_pulse: f32,
    /// Mesin indeks & katalog pencarian aplikasi
    pub search_index: SearchIndex,
    /// Maksimal 5 hasil pencarian aktif
    pub search_results: Vec<SearchResultItem>,
    /// Indeks hasil yang sedang dipilih dengan keyboard / hover (0..4)
    pub selected_result_idx: usize,
    pub hovered_result_idx: Option<usize>,
    /// Progres mekar / cascade animasi gantungan Tanzaku (0.0 -> 1.0)
    pub results_reveal_t: f32,
    pub results_reveal_vel: f32,
}

impl StartMenuState {
    pub fn new(cfg: &StartTreeConfig) -> Self {
        let (root_segs, root_seg_count) = generate_procedural_roots(cfg.root_seed, cfg.low_quality);
        let mut res = Self {
            open: false,
            phase1_t: 0.0,
            phase1_vel: 0.0,
            phase2_t: 0.0,
            phase2_vel: 0.0,
            root_grow_t: 0.0,
            root_grow_vel: 0.0,
            stump_grow_t: 0.0,
            stump_grow_vel: 0.0,
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
            search_query: String::new(),
            search_cursor: 0,
            search_pill_t: 0.0,
            search_pill_vel: 0.0,
            cursor_blink: 0.0,
            typing_pulse: 0.0,
            search_index: SearchIndex::new(),
            search_results: Vec::new(),
            selected_result_idx: 0,
            hovered_result_idx: None,
            results_reveal_t: 0.0,
            results_reveal_vel: 0.0,
        };
        res.search_results = res.search_index.search("");
        res
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
        self.open
            || self.phase1_t > 0.005
            || self.phase2_t > 0.005
            || self.root_grow_t > 0.005
            || self.stump_grow_t > 0.005
            || self.search_pill_t > 0.005
            || self.results_reveal_t > 0.005
    }

    pub fn update(&mut self, dt: f32, cfg: &StartTreeConfig) {
        // Pegas impuls lilitan tombol Windows memakai parameter spring dari YAML
        let k_cinch = (cfg.spring.stiffness * 2.1).clamp(90.0, 320.0);
        let d_cinch = (cfg.spring.damping * 1.05).clamp(8.0, 26.0);
        let cinch_force = (0.0 - self.win_cinch) * k_cinch;
        self.win_cinch_vel += (cinch_force - self.win_cinch_vel * d_cinch) * dt;
        self.win_cinch = (self.win_cinch + self.win_cinch_vel * dt).clamp(-0.22, 1.0);

        // Peluruhan kilatan Kintsugi, gelombang riak cahaya, & denyut ketikan
        self.win_flash = (self.win_flash - dt * 2.1).max(0.0);
        self.typing_pulse = (self.typing_pulse - dt * 2.8).max(0.0);
        if self.win_ripple < 1.0 {
            self.win_ripple = (self.win_ripple + dt * 1.55).min(1.0);
        }

        // ─────────────────────────────────────────────────────────────────────
        // KOREOGRAFI ANIMASI IN & OUT SEKUENSIAL (True Reverse Botanical Cascade)
        // IN:  Search Icon -> Seed Tracer -> Nebari Roots -> Sakura Tree -> Zen Search Pill -> Tanzaku Tags
        // OUT: Tanzaku Tags -> Zen Search Pill -> Sakura Tree -> Nebari Roots -> Seed Tracer -> Search Icon
        // ─────────────────────────────────────────────────────────────────────

        // Hasil Pencarian Tanzaku (Cascade drop setelah pill mekar; surut paling awal saat OUT)
        let res_target = if self.open && self.search_pill_t > 0.35 && !self.search_results.is_empty() {
            1.0
        } else {
            0.0
        };
        let (k_res, d_res) = if self.open { (86.0, 15.2) } else { (135.0, 19.8) };
        self.results_reveal_vel +=
            ((res_target - self.results_reveal_t) * k_res - self.results_reveal_vel * d_res) * dt;
        self.results_reveal_t = (self.results_reveal_t + self.results_reveal_vel * dt).clamp(0.0, 1.0);

        // Fase 5 (Zen Search Pill: Mekar dari ceruk dahan setelah dahan terbentuk; surut saat Tanzaku surut)
        let pill_target = if self.open && self.stump_grow_t > 0.30 {
            1.0
        } else {
            0.0
        };
        let (k_pill, d_pill) = if self.open {
            (78.0, 14.2) // sedikit elastic settle saat mekar
        } else {
            (132.0, 19.6) // surut cepat & bersih sebelum dahan penopang menghilang
        };
        self.search_pill_vel +=
            ((pill_target - self.search_pill_t) * k_pill - self.search_pill_vel * d_pill) * dt;
        self.search_pill_t = (self.search_pill_t + self.search_pill_vel * dt).clamp(0.0, 1.05);

        // Fase 4 (Pohon Sakura: Tumbuh setelah akar mekar; saat OUT menunggu Search Pill hampir surut)
        let p4_target = if self.open {
            if self.root_grow_t > 0.14 { 1.0 } else { 0.0 }
        } else if self.search_pill_t > 0.42 {
            1.0
        } else {
            0.0
        };
        let (k4, d4) = if self.open { (66.0, 13.8) } else { (104.0, 17.8) };
        self.stump_grow_vel +=
            ((p4_target - self.stump_grow_t) * k4 - self.stump_grow_vel * d4) * dt;
        self.stump_grow_t += self.stump_grow_vel * dt;
        if self.stump_grow_t < 0.0 {
            self.stump_grow_t = 0.0;
            self.stump_grow_vel = self.stump_grow_vel.max(0.0);
        } else if self.stump_grow_t > 1.04 {
            self.stump_grow_t = 1.04;
            self.stump_grow_vel = self.stump_grow_vel.min(0.0);
        }

        // Fase 3 (Akar Nebari: Mekar bersama seed saat IN; saat OUT menunggu pohon menyusut setengah)
        let p3_target = if self.open {
            if self.phase2_t > 0.34 { 1.0 } else { 0.0 }
        } else if self.stump_grow_t > 0.56 {
            1.0
        } else {
            0.0
        };
        let (k3, d3) = if self.open { (72.0, 14.4) } else { (108.0, 18.2) };
        self.root_grow_vel +=
            ((p3_target - self.root_grow_t) * k3 - self.root_grow_vel * d3) * dt;
        self.root_grow_t += self.root_grow_vel * dt;
        if self.root_grow_t < 0.0 {
            self.root_grow_t = 0.0;
            self.root_grow_vel = self.root_grow_vel.max(0.0);
        } else if self.root_grow_t > 1.04 {
            self.root_grow_t = 1.04;
            self.root_grow_vel = self.root_grow_vel.min(0.0);
        }

        // Fase 2 (Sakura Seed Tracer: Meluncur ke tengah saat IN; pulang saat akar menyusut)
        let p2_target = if self.open {
            if self.phase1_t > 0.16 { 1.0 } else { 0.0 }
        } else if self.root_grow_t > 0.52 {
            1.0
        } else {
            0.0
        };
        let (k2, d2) = if self.open { (78.0, 15.0) } else { (114.0, 18.8) };
        self.phase2_vel += ((p2_target - self.phase2_t) * k2 - self.phase2_vel * d2) * dt;
        self.phase2_t += self.phase2_vel * dt;
        if self.phase2_t < 0.0 {
            self.phase2_t = 0.0;
            self.phase2_vel = self.phase2_vel.max(0.0);
        } else if self.phase2_t > 1.04 {
            self.phase2_t = 1.04;
            self.phase2_vel = self.phase2_vel.min(0.0);
        }

        // Fase 1 (Search Pill Absorption: Langsung terpicu saat IN; kembali mekar setelah seed pulang)
        let p1_target = if self.open {
            1.0
        } else if self.phase2_t > 0.45 {
            1.0
        } else {
            0.0
        };
        let (k1, d1) = if self.open { (86.0, 15.6) } else { (116.0, 19.0) };
        self.phase1_vel += ((p1_target - self.phase1_t) * k1 - self.phase1_vel * d1) * dt;
        self.phase1_t += self.phase1_vel * dt;
        if self.phase1_t < 0.0 {
            self.phase1_t = 0.0;
            self.phase1_vel = self.phase1_vel.max(0.0);
        } else if self.phase1_t > 1.04 {
            self.phase1_t = 1.04;
            self.phase1_vel = self.phase1_vel.min(0.0);
        }

        // Tarikan partikel dinamis: kuat saat baru buka (~1.55), tenang saat idle (~0.58)
        let target_pull = if self.open { 1.55 } else { 0.58 };
        self.pull_activity += (target_pull - self.pull_activity) * (dt * 2.4).min(1.0);

        self.cursor_blink += dt;

        if !self.open
            && self.phase1_t < 0.004
            && self.phase1_vel.abs() < 0.05
            && self.phase2_t < 0.004
            && self.root_grow_t < 0.004
            && self.stump_grow_t < 0.004
            && self.search_pill_t < 0.004
        {
            self.phase1_t = 0.0;
            self.phase1_vel = 0.0;
            self.phase2_t = 0.0;
            self.phase2_vel = 0.0;
            self.root_grow_t = 0.0;
            self.root_grow_vel = 0.0;
            self.stump_grow_t = 0.0;
            self.stump_grow_vel = 0.0;
            self.search_pill_t = 0.0;
            self.search_pill_vel = 0.0;
            self.results_reveal_t = 0.0;
            self.results_reveal_vel = 0.0;
            self.selected_result_idx = 0;
            self.hovered_result_idx = None;
            self.search_query.clear();
            self.search_cursor = 0;
            self.typing_pulse = 0.0;
            self.search_results = self.search_index.search("");
        }
    }

    /// Intensitas glow Search Bar saat mengetik atau memiliki query (0.0 .. 1.0).
    pub fn search_energy(&self) -> f32 {
        let base = if self.search_query.is_empty() { 0.0 } else { 0.35 };
        (base + self.typing_pulse * 0.65).clamp(0.0, 1.0)
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
        let p_cnt = if !cfg.blossom.hanafubuki {
            0.0
        } else if cfg.low_quality {
            cfg.particle_count.min(20) as f32
        } else {
            cfg.particle_count.clamp(8, 64) as f32
        };
        [
            self.root_seg_count as f32,
            p_cnt,
            cfg.particle_pull.clamp(0.2, 2.5),
            if cfg.low_quality { 1.0 } else { 0.0 },
        ]
    }

    /// `[stump_grow_t, trunk_thickness, sumi_ink, blossom_density]`
    pub fn tree_style_vec(&self, cfg: &StartTreeConfig) -> [f32; 4] {
        let density = if cfg.blossom.enabled {
            cfg.blossom.density.clamp(0.0, 2.0)
        } else {
            0.0
        };
        [
            self.stump_grow_t.clamp(0.0, 1.05),
            cfg.trunk_thickness.clamp(0.7, 1.6),
            cfg.blossom.sumi_ink.clamp(0.0, 2.5),
            density,
        ]
    }

    /// `[win_flash, win_ripple, pull_activity, search_pill_t]`
    pub fn start_fx_vec(&self) -> [f32; 4] {
        [
            self.win_flash.clamp(0.0, 1.0),
            self.win_ripple.clamp(0.0, 1.0),
            self.pull_activity.clamp(0.35, 1.8),
            self.search_pill_t.clamp(0.0, 1.05),
        ]
    }

    pub fn handle_search_char(&mut self, ch: char) {
        if !ch.is_control() {
            self.search_query.push(ch);
            self.search_cursor = self.search_query.len();
            self.cursor_blink = 0.0;
            self.typing_pulse = 1.0;
            self.search_results = self.search_index.search(&self.search_query);
            self.selected_result_idx = 0;
        }
    }

    pub fn handle_search_backspace(&mut self) {
        if !self.search_query.is_empty() {
            self.search_query.pop();
            self.search_cursor = self.search_query.len();
            self.cursor_blink = 0.0;
            self.typing_pulse = 0.75;
            self.search_results = self.search_index.search(&self.search_query);
            self.selected_result_idx = 0;
        }
    }

    pub fn clear_search(&mut self) {
        self.search_query.clear();
        self.search_cursor = 0;
        self.cursor_blink = 0.0;
        self.typing_pulse = 0.0;
        self.search_results = self.search_index.search("");
        self.selected_result_idx = 0;
    }

    pub fn select_next(&mut self) {
        if !self.search_results.is_empty() {
            self.selected_result_idx = (self.selected_result_idx + 1) % self.search_results.len().min(5);
            self.cursor_blink = 0.0;
            self.typing_pulse = 0.40;
        }
    }

    pub fn select_prev(&mut self) {
        if !self.search_results.is_empty() {
            let max_idx = self.search_results.len().min(5) - 1;
            if self.selected_result_idx == 0 {
                self.selected_result_idx = max_idx;
            } else {
                self.selected_result_idx -= 1;
            }
            self.cursor_blink = 0.0;
            self.typing_pulse = 0.40;
        }
    }

    pub fn execute_selected(&mut self) -> bool {
        if let Some(item) = self.search_results.get(self.selected_result_idx) {
            launch_target(&item.command);
            self.close();
            true
        } else {
            false
        }
    }

    pub fn execute_index(&mut self, idx: usize) -> bool {
        if let Some(item) = self.search_results.get(idx) {
            launch_target(&item.command);
            self.close();
            true
        } else {
            false
        }
    }

    pub fn build_search_text_entries(
        &self,
        pill_cx: f32,
        pill_cy: f32,
        res_cx: f32,
        res_cy: f32,
        _time: f32,
    ) -> Vec<TextEntry> {
        let mut out = Vec::with_capacity(16);
        if self.search_pill_t <= 0.18 {
            return out;
        }

        // Teks baru mulai muncul elegan setelah kapsul terbuka cukup lebar (> 0.25)
        let t_fade = ((self.search_pill_t - 0.25) / 0.75).clamp(0.0, 1.0);
        let smooth_fade = t_fade * t_fade * (3.0 - 2.0 * t_fade);
        let alpha = (smooth_fade * 255.0).clamp(0.0, 255.0) as u8;

        // Lampion Besar di dahan KANAN (Grand Chōchin Capsule — 570x76 px)
        // Ikon Zen Ensō berada di sisi kiri + divider vertikal emas di pill_cx - 217.0
        // Teks dimulai di pill_cx - 204.0 dengan ukuran font 18.5px & kontras tinggi
        let text_x = pill_cx - 204.0;
        let text_w = 435.0;
        let font_size = 18.5;
        let text_y = pill_cy - 12.0;

        let cream_white = [255, 252, 245, alpha];
        let quiet_pearl = [232, 226, 214, (alpha as f32 * 0.94) as u8];
        let gold_hint = [255, 222, 138, (alpha as f32 * 0.90) as u8];

        if self.search_query.is_empty() {
            out.push(TextEntry::left(
                "Cari aplikasi, berkas, atau perintah...",
                text_x,
                text_y,
                text_w,
                font_size,
                quiet_pearl,
            ));
            out.push(TextEntry::centered(
                "ESC",
                pill_cx + 242.0,
                pill_cy - 8.5,
                48.0,
                11.5,
                gold_hint,
            ).semibold());
        } else {
            let caret = if (self.cursor_blink * 3.4).sin() > -0.25 { "|" } else { "" };
            let display_text = format!("{}{}", self.search_query, caret);
            out.push(
                TextEntry::left(
                    display_text,
                    text_x,
                    text_y,
                    text_w,
                    font_size,
                    cream_white,
                )
                .semibold(),
            );
            out.push(TextEntry::centered(
                "ENTER",
                pill_cx + 238.0,
                pill_cy - 8.5,
                56.0,
                11.0,
                gold_hint,
            ).semibold());
        }

        // ─────────────────────────────────────────────────────────────────────
        // 5 TANZAKU HANGING RESULT TAGS (Slip Gantungan Hasil Pencarian di Dahan Kiri)
        // ─────────────────────────────────────────────────────────────────────
        if self.results_reveal_t > 0.05 && !self.search_results.is_empty() {
            let res_alpha_f = (self.results_reveal_t * smooth_fade * 255.0).clamp(0.0, 255.0);
            let res_alpha = res_alpha_f as u8;

            if res_alpha > 12 {
                for (i, item) in self.search_results.iter().take(5).enumerate() {
                    let fi = i as f32;
                    let tag_top = res_cy + 18.0 + fi * 50.0;
                    let is_sel = i == self.selected_result_idx;

                    let title_col = if is_sel {
                        [255, 252, 240, res_alpha]
                    } else {
                        [235, 230, 220, (res_alpha_f * 0.95) as u8]
                    };
                    let sub_col = [190, 195, 210, (res_alpha_f * 0.85) as u8];
                    let badge_col = if is_sel {
                        [255, 230, 145, res_alpha]
                    } else {
                        [225, 190, 125, (res_alpha_f * 0.85) as u8]
                    };

                    // Badge Kategori di sisi kiri slip Tanzaku (res_cx - 190.0)
                    out.push(
                        TextEntry::centered(
                            item.badge,
                            res_cx - 190.0,
                            tag_top + 14.5,
                            40.0,
                            10.0,
                            badge_col,
                        )
                        .semibold(),
                    );

                    // Judul Item Aplikasi / File (res_cx - 158.0)
                    let title_entry = TextEntry::left(
                        &item.title,
                        res_cx - 158.0,
                        tag_top + 5.5,
                        280.0,
                        14.5,
                        title_col,
                    );
                    out.push(if is_sel {
                        title_entry.semibold()
                    } else {
                        title_entry
                    });

                    // Subjudul / Deskripsi / Path di bawah judul (res_cx - 158.0)
                    out.push(TextEntry::left(
                        &item.subtitle,
                        res_cx - 158.0,
                        tag_top + 23.5,
                        280.0,
                        11.5,
                        sub_col,
                    ));

                    // Indikator Aksi di ujung kanan (res_cx + 175.0)
                    if is_sel {
                        out.push(
                            TextEntry::centered(
                                "ENTER ↵",
                                res_cx + 175.0,
                                tag_top + 14.5,
                                62.0,
                                10.5,
                                [255, 232, 155, res_alpha],
                            )
                            .semibold(),
                        );
                    } else if item.is_best_match {
                        out.push(
                            TextEntry::centered(
                                "BEST MATCH ✦",
                                res_cx + 158.0,
                                tag_top + 14.5,
                                88.0,
                                9.5,
                                [225, 185, 115, (res_alpha_f * 0.85) as u8],
                            )
                            .semibold(),
                        );
                    }
                }
            }
        }

        out
    }
}
