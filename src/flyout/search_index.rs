use std::path::{Path, PathBuf};
use std::process::Command;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

#[derive(Debug, Clone, PartialEq)]
pub struct SearchResultItem {
    pub title: String,
    pub subtitle: String,
    pub command: String,
    pub badge: &'static str,
    pub is_best_match: bool,
}

#[derive(Debug, Clone)]
struct AppEntry {
    name: String,
    keywords: Vec<String>,
    subtitle: String,
    command: String,
    badge: &'static str,
    priority: i32,
}

pub struct SearchIndex {
    catalog: Vec<AppEntry>,
}

impl SearchIndex {
    pub fn new() -> Self {
        let mut index = Self {
            catalog: Vec::with_capacity(64),
        };
        index.populate_defaults();
        index.scan_windows_start_menu();
        index
    }

    fn populate_defaults(&mut self) {
        let defaults = [
            ("Google Chrome", "chrome.exe", "Browser Web Cepat", "WEB", 100, &["google", "chrome", "browser", "internet", "web"][..]),
            ("Brave Browser", "brave.exe", "Private Web Browser", "WEB", 95, &["brave", "browser", "internet"][..]),
            ("Microsoft Edge", "msedge.exe", "Peramban Web Bawaan", "WEB", 90, &["edge", "msedge", "browser"][..]),
            ("Visual Studio Code", "code.cmd", "Editor Kode & Workspace", "DEV", 98, &["vscode", "code", "visual", "studio", "editor"][..]),
            ("Windows Terminal", "wt.exe", "Terminal & PowerShell", "SYS", 96, &["terminal", "wt", "bash", "pwsh", "console"][..]),
            ("File Explorer", "explorer.exe", "Penjelajah Berkas & Drive", "SYS", 94, &["explorer", "file", "berkas", "folder"][..]),
            ("Pengaturan Windows", "ms-settings:", "Konfigurasi Sistem", "SYS", 92, &["settings", "pengaturan", "setting", "opsi"][..]),
            ("Task Manager", "taskmgr.exe", "Pemantau Kinerja & Proses", "SYS", 88, &["task", "manager", "proses", "cpu", "ram"][..]),
            ("Notepad", "notepad.exe", "Editor Catatan Teks Ringkas", "APP", 85, &["notepad", "catatan", "teks", "text"][..]),
            ("Kalkulator", "calc.exe", "Alat Hitung Cepat", "APP", 84, &["kalkulator", "calculator", "calc", "hitung"][..]),
            ("Snipping Tool", "snippingtool.exe", "Tangkapan Layar & Snipping", "APP", 82, &["snip", "screenshot", "screen", "tangkapan"][..]),
            ("Spotify", "spotify.exe", "Pemutar Musik & Audio", "APP", 80, &["spotify", "musik", "music", "audio"][..]),
            ("Discord", "discord.exe", "Komunikasi & Obrolan Suara", "APP", 78, &["discord", "chat", "voice"][..]),
            ("Paint", "mspaint.exe", "Menggambar & Edit Gambar", "APP", 70, &["paint", "gambar", "draw"][..]),
            ("Control Panel", "control.exe", "Panel Kendali Klasik", "SYS", 68, &["control", "panel"][..]),
            ("PowerShell", "powershell.exe", "Windows PowerShell Core", "SYS", 65, &["powershell", "posh", "pwsh"][..]),
            ("Command Prompt", "cmd.exe", "Baris Perintah Konsol", "SYS", 60, &["cmd", "prompt", "command"][..]),
        ];

        for (name, cmd, sub, badge, prio, kw) in defaults {
            self.catalog.push(AppEntry {
                name: name.to_string(),
                keywords: kw.iter().map(|s| s.to_string()).collect(),
                subtitle: sub.to_string(),
                command: cmd.to_string(),
                badge,
                priority: prio,
            });
        }
    }

    fn scan_windows_start_menu(&mut self) {
        let mut dirs = Vec::new();
        dirs.push(PathBuf::from(r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs"));
        if let Ok(appdata) = std::env::var("APPDATA") {
            dirs.push(PathBuf::from(appdata).join(r"Microsoft\Windows\Start Menu\Programs"));
        }

        for dir in dirs {
            if dir.exists() {
                self.walk_dir_for_shortcuts(&dir);
            }
        }
    }

    fn walk_dir_for_shortcuts(&mut self, dir: &Path) {
        let entries = match std::fs::read_dir(dir) {
            Ok(e) => e,
            Err(_) => return,
        };

        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                self.walk_dir_for_shortcuts(&path);
            } else if let Some(ext) = path.extension() {
                if ext.eq_ignore_ascii_case("lnk") {
                    if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                        let lower_stem = stem.to_lowercase();
                        // Abaikan uninstaller / help links
                        if lower_stem.contains("uninstall")
                            || lower_stem.contains("readme")
                            || lower_stem.contains("help")
                            || lower_stem.contains("documentation")
                        {
                            continue;
                        }

                        // Cek apakah nama sudah ada dalam katalog
                        if self.catalog.iter().any(|e| e.name.eq_ignore_ascii_case(stem)) {
                            continue;
                        }

                        let keywords: Vec<String> = lower_stem
                            .split(|c: char| !c.is_alphanumeric())
                            .filter(|w| !w.is_empty())
                            .map(|w| w.to_string())
                            .collect();

                        self.catalog.push(AppEntry {
                            name: stem.to_string(),
                            keywords,
                            subtitle: "Aplikasi Windows".to_string(),
                            command: path.to_string_lossy().to_string(),
                            badge: "APP",
                            priority: 50,
                        });
                    }
                }
            }
        }
    }

    /// Menghasilkan maksimal 5 item hasil pencarian yang paling relevan.
    pub fn search(&self, query: &str) -> Vec<SearchResultItem> {
        let q_trimmed = query.trim().to_lowercase();

        if q_trimmed.is_empty() {
            // 5 Aplikasi default yang paling sering digunakan
            let mut top = self.catalog.clone();
            top.sort_by(|a, b| b.priority.cmp(&a.priority));
            return top
                .into_iter()
                .take(5)
                .enumerate()
                .map(|(i, app)| SearchResultItem {
                    title: app.name,
                    subtitle: app.subtitle,
                    command: app.command,
                    badge: app.badge,
                    is_best_match: i == 0,
                })
                .collect();
        }

        let mut scored: Vec<(i32, &AppEntry)> = Vec::new();

        for app in &self.catalog {
            let name_lower = app.name.to_lowercase();
            let mut score = 0;

            if name_lower == q_trimmed {
                score += 1000;
            } else if name_lower.starts_with(&q_trimmed) {
                score += 500;
            } else if name_lower.contains(&q_trimmed) {
                score += 250;
            } else if app.keywords.iter().any(|k| k.starts_with(&q_trimmed)) {
                score += 180;
            } else if app.keywords.iter().any(|k| k.contains(&q_trimmed)) {
                score += 100;
            }

            if score > 0 {
                score += app.priority;
                scored.push((score, app));
            }
        }

        scored.sort_by(|a, b| b.0.cmp(&a.0));

        let mut results = Vec::with_capacity(5);
        for (i, (_, app)) in scored.into_iter().take(5).enumerate() {
            results.push(SearchResultItem {
                title: app.name.clone(),
                subtitle: app.subtitle.clone(),
                command: app.command.clone(),
                badge: app.badge,
                is_best_match: i == 0,
            });
        }

        // Jika query pengguna tidak menemukan aplikasi tapi mirip perintah eksekusi
        if results.is_empty() {
            results.push(SearchResultItem {
                title: format!("Jalankan \"{}\"", query.trim()),
                subtitle: "Eksekusi perintah di Command Prompt".to_string(),
                command: query.trim().to_string(),
                badge: "RUN",
                is_best_match: true,
            });
        }

        results
    }
}

/// Menjalankan target (aplikasi, .lnk, path, atau URL) secara asynchronous di Windows
pub fn launch_target(target: &str) {
    let t = target.to_string();
    std::thread::spawn(move || {
        let mut cmd = Command::new("cmd");
        cmd.args(["/c", "start", "", &t]);
        #[cfg(windows)]
        {
            cmd.creation_flags(CREATE_NO_WINDOW);
        }
        let _ = cmd.spawn();
    });
}
