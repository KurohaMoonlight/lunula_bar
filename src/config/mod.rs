use serde::Deserialize;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FlyoutTheme {
    LiquidSpire = 0,
    SumiCloud = 1,
    PureHud = 2,
}

impl Default for FlyoutTheme {
    fn default() -> Self {
        FlyoutTheme::LiquidSpire
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct SpringConfig {
    #[serde(default = "default_stiffness")]
    pub stiffness: f32,
    #[serde(default = "default_damping")]
    pub damping: f32,
}

fn default_stiffness() -> f32 {
    150.0
}
fn default_damping() -> f32 {
    14.0
}

impl Default for SpringConfig {
    fn default() -> Self {
        Self {
            stiffness: 150.0,
            damping: 14.0,
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct TypographyConfig {
    #[allow(dead_code)]
    #[serde(default = "default_display_font")]
    pub display_font: String,
    #[serde(default = "default_body_font")]
    pub body_font: String,
    #[serde(default = "default_display_scale")]
    pub display_scale: f32,
    #[serde(default = "default_body_scale")]
    pub body_scale: f32,
}

fn default_display_font() -> String {
    "Space Grotesk".into()
}
fn default_body_font() -> String {
    "Space Grotesk".into()
}
fn default_display_scale() -> f32 {
    1.0
}
fn default_body_scale() -> f32 {
    1.0
}

impl Default for TypographyConfig {
    fn default() -> Self {
        Self {
            display_font: default_display_font(),
            body_font: default_body_font(),
            display_scale: default_display_scale(),
            body_scale: default_body_scale(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ModuleConfig {
    #[allow(dead_code)]
    #[serde(default = "default_module_name")]
    pub module: String,
    #[allow(dead_code)]
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default)]
    pub theme: FlyoutTheme,
    #[serde(default)]
    pub spring: SpringConfig,
    #[serde(default)]
    pub typography: TypographyConfig,
}

fn default_module_name() -> String {
    "unknown".into()
}
fn default_true() -> bool {
    true
}

impl ModuleConfig {
    pub fn load_or_default(path: &str, default_theme: FlyoutTheme) -> Self {
        if Path::new(path).exists() {
            if let Ok(content) = fs::read_to_string(path) {
                if let Ok(cfg) = serde_yaml::from_str::<ModuleConfig>(&content) {
                    return cfg;
                }
            }
        }
        Self {
            module: path.into(),
            enabled: true,
            theme: default_theme,
            spring: SpringConfig::default(),
            typography: TypographyConfig::default(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrunkStyle {
    Hybrid = 0,
    Liquid = 1,
    Wood = 2,
}

impl Default for TrunkStyle {
    fn default() -> Self {
        TrunkStyle::Hybrid
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct StartTreeConfig {
    #[serde(default = "default_start_spring")]
    pub spring: SpringConfig,
    #[serde(default)]
    #[allow(dead_code)]
    pub trunk_style: TrunkStyle,
    #[serde(default = "default_trunk_thickness")]
    pub trunk_thickness: f32,
    #[serde(default = "default_trunk_lean")]
    pub trunk_lean: f32,
    #[serde(default = "default_soul_leaves")]
    pub soul_leaves: f32,
    #[serde(default = "default_root_seed")]
    pub root_seed: u64,
    #[serde(default = "default_particle_count")]
    pub particle_count: u32,
    #[serde(default = "default_particle_pull")]
    pub particle_pull: f32,
    #[serde(default)]
    pub low_quality: bool,
}

fn default_start_spring() -> SpringConfig {
    SpringConfig {
        stiffness: 58.0,
        damping: 12.8,
    }
}
fn default_trunk_thickness() -> f32 {
    1.30
}
fn default_trunk_lean() -> f32 {
    0.44
}
fn default_soul_leaves() -> f32 {
    1.40
}
fn default_root_seed() -> u64 {
    1337
}
fn default_particle_count() -> u32 {
    44
}
fn default_particle_pull() -> f32 {
    1.0
}

impl Default for StartTreeConfig {
    fn default() -> Self {
        Self {
            spring: default_start_spring(),
            trunk_style: TrunkStyle::Hybrid,
            trunk_thickness: default_trunk_thickness(),
            trunk_lean: default_trunk_lean(),
            soul_leaves: default_soul_leaves(),
            root_seed: default_root_seed(),
            particle_count: default_particle_count(),
            particle_pull: default_particle_pull(),
            low_quality: false,
        }
    }
}

impl StartTreeConfig {
    pub fn load_or_default(path: &str) -> Self {
        if Path::new(path).exists() {
            if let Ok(content) = fs::read_to_string(path) {
                if let Ok(cfg) = serde_yaml::from_str::<StartTreeConfig>(&content) {
                    return cfg;
                }
            }
        }
        Self::default()
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct FlyoutVisualConfig {
    #[serde(default = "default_texture_intensity")]
    pub texture_intensity: f32,
    #[allow(dead_code)]
    #[serde(default = "default_outline_width_px")]
    pub outline_width_px: f32,
    #[serde(default = "default_texture_fade_px")]
    pub texture_fade_px: f32,
    #[serde(default = "default_content_backdrop_alpha")]
    pub content_backdrop_alpha: f32,
}

fn default_texture_intensity() -> f32 {
    0.65
}
fn default_outline_width_px() -> f32 {
    1.8
}
fn default_texture_fade_px() -> f32 {
    30.0
}
fn default_content_backdrop_alpha() -> f32 {
    0.92
}

impl Default for FlyoutVisualConfig {
    fn default() -> Self {
        Self {
            texture_intensity: default_texture_intensity(),
            outline_width_px: default_outline_width_px(),
            texture_fade_px: default_texture_fade_px(),
            content_backdrop_alpha: default_content_backdrop_alpha(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct AppearanceFile {
    #[serde(default)]
    pub typography: TypographyConfig,
    #[serde(default)]
    pub flyout_visual: FlyoutVisualConfig,
}

impl Default for AppearanceFile {
    fn default() -> Self {
        Self {
            typography: TypographyConfig::default(),
            flyout_visual: FlyoutVisualConfig::default(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ModulesConfig {
    pub volume: ModuleConfig,
    pub battery: ModuleConfig,
    pub wifi: ModuleConfig,
    pub start: StartTreeConfig,
    pub visual: FlyoutVisualConfig,
    pub typography: TypographyConfig,
}

impl ModulesConfig {
    pub fn load() -> Self {
        let appearance = if Path::new("config/appearance.yaml").exists() {
            if let Ok(content) = fs::read_to_string("config/appearance.yaml") {
                serde_yaml::from_str::<AppearanceFile>(&content).unwrap_or_default()
            } else {
                AppearanceFile::default()
            }
        } else {
            AppearanceFile::default()
        };

        Self {
            volume: ModuleConfig::load_or_default(
                "config/modules/volume.yaml",
                FlyoutTheme::LiquidSpire,
            ),
            battery: ModuleConfig::load_or_default(
                "config/modules/battery.yaml",
                FlyoutTheme::SumiCloud,
            ),
            wifi: ModuleConfig::load_or_default(
                "config/modules/wifi.yaml",
                FlyoutTheme::PureHud,
            ),
            start: StartTreeConfig::load_or_default("config/modules/start.yaml"),
            visual: appearance.flyout_visual,
            typography: appearance.typography,
        }
    }
}
