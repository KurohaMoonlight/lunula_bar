/// Crisp GPU font atlas (`R8Unorm`, `FilterMode::Nearest`, no mipmaps, 2px padding per glyph).
///
/// Row 0: Pixel Display Font (6x8) — decorative elements (clock, panel titles).
/// Row 1: Clean Readable Body Font (6x8) — network names (`LINTANG`, `GUEST`, `OFFICE`),
///        status labels (`ACTIVE`, `SECURE`, `CONN`, `5G`), and control labels.
///
/// Every glyph is placed in a 10x12 cell (6x8 active bitmap + 2px transparent padding on all sides)
/// so adjacent glyphs never bleed even under DPI scaling.

pub const ATLAS_GLYPH_COUNT: u32 = 64; // ASCII 32 (' ') ..= 95 ('_')
pub const GLYPH_W: u32 = 6;
pub const GLYPH_H: u32 = 8;
pub const CELL_PAD: u32 = 2;
pub const CELL_W: u32 = GLYPH_W + CELL_PAD * 2; // 10
pub const CELL_H: u32 = GLYPH_H + CELL_PAD * 2; // 12
pub const ATLAS_ROWS: u32 = 2; // 0 = display pixel, 1 = clean body
pub const ATLAS_W: u32 = ATLAS_GLYPH_COUNT * CELL_W; // 640
pub const ATLAS_H: u32 = ATLAS_ROWS * CELL_H; // 24

pub struct FontAtlas {
    pub _texture: wgpu::Texture,
    pub view: wgpu::TextureView,
    pub sampler: wgpu::Sampler,
}

impl FontAtlas {
    pub fn new(device: &wgpu::Device, queue: &wgpu::Queue) -> Self {
        let pixels = build_atlas_pixels();

        let texture_size = wgpu::Extent3d {
            width: ATLAS_W,
            height: ATLAS_H,
            depth_or_array_layers: 1,
        };

        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("Lunula Font Atlas (R8Unorm Nearest)"),
            size: texture_size,
            mip_level_count: 1, // Tanpa mipmap agar font pixel tidak pernah blur
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::R8Unorm,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });

        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            &pixels,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(ATLAS_W),
                rows_per_image: Some(ATLAS_H),
            },
            texture_size,
        );

        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("Lunula Font Nearest Sampler"),
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            address_mode_w: wgpu::AddressMode::ClampToEdge,
            mag_filter: wgpu::FilterMode::Nearest,
            min_filter: wgpu::FilterMode::Nearest,
            mipmap_filter: wgpu::MipmapFilterMode::Nearest,
            ..Default::default()
        });

        Self {
            _texture: texture,
            view,
            sampler,
        }
    }
}

fn build_atlas_pixels() -> Vec<u8> {
    let mut data = vec![0u8; (ATLAS_W * ATLAS_H) as usize];

    for code in 32u8..=95u8 {
        let idx = (code - 32) as u32;
        let display_rows = glyph_bitmap_display(code as char);
        let body_rows = glyph_bitmap_body(code as char);

        blit_glyph(&mut data, idx, 0, &display_rows);
        blit_glyph(&mut data, idx, 1, &body_rows);
    }

    data
}

fn blit_glyph(data: &mut [u8], glyph_idx: u32, row_idx: u32, rows: &[&str; 8]) {
    let base_x = glyph_idx * CELL_W + CELL_PAD;
    let base_y = row_idx * CELL_H + CELL_PAD;
    for (y, line) in rows.iter().enumerate() {
        for (x, ch) in line.bytes().take(GLYPH_W as usize).enumerate() {
            if ch == b'#' {
                let px = base_x + x as u32;
                let py = base_y + y as u32;
                data[(py * ATLAS_W + px) as usize] = 255;
            }
        }
    }
}

/// Clean readable 6x8 body font (JetBrains Mono / Zen Kaku style):
/// - Clear diagonal `N` (never looks like `M`)
/// - Open smooth `O` vs slashed `0` (so `OFFICE` never reads as `0FFICE`)
/// - Proper `U`, `G`, `S`, `E`, `C`, `R`, `M`, `W`
fn glyph_bitmap_body(ch: char) -> [&'static str; 8] {
    match ch {
        '0' => [
            ".####.",
            "##..##",
            "##.###",
            "####.#",
            "###.##",
            "##..##",
            ".####.",
            "......",
        ],
        '1' => [
            "..##..",
            ".###..",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            ".####.",
            "......",
        ],
        '2' => [
            ".####.",
            "##..##",
            "....##",
            "..###.",
            ".##...",
            "##....",
            "######",
            "......",
        ],
        '3' => [
            ".####.",
            "##..##",
            "....##",
            "..###.",
            "....##",
            "##..##",
            ".####.",
            "......",
        ],
        '4' => [
            "...##.",
            "..###.",
            ".####.",
            "##.##.",
            "######",
            "...##.",
            "...##.",
            "......",
        ],
        '5' => [
            "######",
            "##....",
            "#####.",
            "....##",
            "....##",
            "##..##",
            ".####.",
            "......",
        ],
        '6' => [
            "..###.",
            ".##...",
            "##....",
            "#####.",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        '7' => [
            "######",
            "....##",
            "...##.",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "......",
        ],
        '8' => [
            ".####.",
            "##..##",
            "##..##",
            ".####.",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        '9' => [
            ".####.",
            "##..##",
            "##..##",
            ".#####",
            "....##",
            "...##.",
            ".###..",
            "......",
        ],
        'A' => [
            "..##..",
            ".####.",
            "##..##",
            "##..##",
            "######",
            "##..##",
            "##..##",
            "......",
        ],
        'B' => [
            "#####.",
            "##..##",
            "##..##",
            "#####.",
            "##..##",
            "##..##",
            "#####.",
            "......",
        ],
        'C' => [
            ".####.",
            "##..##",
            "##....",
            "##....",
            "##....",
            "##..##",
            ".####.",
            "......",
        ],
        'D' => [
            "####..",
            "##.##.",
            "##..##",
            "##..##",
            "##..##",
            "##.##.",
            "####..",
            "......",
        ],
        'E' => [
            "######",
            "##....",
            "##....",
            "#####.",
            "##....",
            "##....",
            "######",
            "......",
        ],
        'F' => [
            "######",
            "##....",
            "##....",
            "#####.",
            "##....",
            "##....",
            "##....",
            "......",
        ],
        'G' => [
            ".####.",
            "##..##",
            "##....",
            "##.###",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        'H' => [
            "##..##",
            "##..##",
            "##..##",
            "######",
            "##..##",
            "##..##",
            "##..##",
            "......",
        ],
        'I' => [
            ".####.",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            ".####.",
            "......",
        ],
        'J' => [
            "..####",
            "....##",
            "....##",
            "....##",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        'K' => [
            "##..##",
            "##.##.",
            "####..",
            "###...",
            "####..",
            "##.##.",
            "##..##",
            "......",
        ],
        'L' => [
            "##....",
            "##....",
            "##....",
            "##....",
            "##....",
            "##....",
            "######",
            "......",
        ],
        'M' => [
            "#....#",
            "##..##",
            "######",
            "#.##.#",
            "#....#",
            "#....#",
            "#....#",
            "......",
        ],
        'N' => [
            "##...#",
            "###..#",
            "####.#",
            "##.###",
            "##..##",
            "##...#",
            "##...#",
            "......",
        ],
        'O' => [
            ".####.",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        'P' => [
            "#####.",
            "##..##",
            "##..##",
            "#####.",
            "##....",
            "##....",
            "##....",
            "......",
        ],
        'Q' => [
            ".####.",
            "##..##",
            "##..##",
            "##..##",
            "##.###",
            "##.##.",
            ".###.#",
            "......",
        ],
        'R' => [
            "#####.",
            "##..##",
            "##..##",
            "#####.",
            "##.##.",
            "##..##",
            "##..##",
            "......",
        ],
        'S' => [
            ".####.",
            "##..##",
            "##....",
            ".####.",
            "....##",
            "##..##",
            ".####.",
            "......",
        ],
        'T' => [
            "######",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "......",
        ],
        'U' => [
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            ".####.",
            "......",
        ],
        'V' => [
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            ".####.",
            ".####.",
            "..##..",
            "......",
        ],
        'W' => [
            "#....#",
            "#....#",
            "#....#",
            "#.##.#",
            "######",
            "##..##",
            "#....#",
            "......",
        ],
        'X' => [
            "##..##",
            ".####.",
            "..##..",
            "..##..",
            ".####.",
            "##..##",
            "##..##",
            "......",
        ],
        'Y' => [
            "##..##",
            "##..##",
            ".####.",
            "..##..",
            "..##..",
            "..##..",
            "..##..",
            "......",
        ],
        'Z' => [
            "######",
            "....##",
            "...##.",
            "..##..",
            ".##...",
            "##....",
            "######",
            "......",
        ],
        ':' => [
            "......",
            "..##..",
            "..##..",
            "......",
            "..##..",
            "..##..",
            "......",
            "......",
        ],
        '%' => [
            "##...#",
            "##..#.",
            "...#..",
            "..#...",
            ".#..##",
            "#...##",
            "......",
            "......",
        ],
        '-' => [
            "......",
            "......",
            "......",
            ".####.",
            "......",
            "......",
            "......",
            "......",
        ],
        '.' => [
            "......",
            "......",
            "......",
            "......",
            "......",
            "..##..",
            "..##..",
            "......",
        ],
        '/' => [
            "....##",
            "...##.",
            "..##..",
            "..##..",
            ".##...",
            "##....",
            "......",
            "......",
        ],
        _ => [
            "......",
            "......",
            "......",
            "......",
            "......",
            "......",
            "......",
            "......",
        ],
    }
}

/// Decorative crisp pixel display font (Departure Mono / Silkscreen style) for clock & panel titles:
/// slightly squared corners & strong pixel geometry while keeping `N` and `O` unambiguous.
fn glyph_bitmap_display(ch: char) -> [&'static str; 8] {
    match ch {
        'O' => [
            "######",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            "##..##",
            "######",
            "......",
        ],
        '0' => [
            "######",
            "##..##",
            "##.###",
            "##.#.#",
            "###.##",
            "##..##",
            "######",
            "......",
        ],
        'C' => [
            "######",
            "##....",
            "##....",
            "##....",
            "##....",
            "##....",
            "######",
            "......",
        ],
        'S' => [
            "######",
            "##....",
            "##....",
            "######",
            "....##",
            "....##",
            "######",
            "......",
        ],
        'A' => [
            "######",
            "##..##",
            "##..##",
            "######",
            "##..##",
            "##..##",
            "##..##",
            "......",
        ],
        _ => glyph_bitmap_body(ch),
    }
}
