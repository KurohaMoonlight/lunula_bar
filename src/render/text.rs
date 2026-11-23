use glyphon::{
    Attrs, Buffer, Cache, Color, Family, FontSystem, Metrics, Resolution, Shaping, SwashCache,
    TextArea, TextAtlas, TextBounds, TextRenderer, Viewport, Weight,
};
use glyphon::cosmic_text::Align;

/// Satu item teks yang akan dirender di atas flyout / sub-flyout pada frame saat ini.
#[derive(Debug, Clone)]
pub struct TextEntry {
    pub text: String,
    pub x: f32,
    pub y: f32,
    pub max_w: f32,
    pub max_h: f32,
    pub font_size: f32,
    pub line_height: f32,
    pub color: [u8; 4],
    pub bold: bool,
    pub semibold: bool,
    pub center: bool,
}

impl TextEntry {
    pub fn left(
        text: impl Into<String>,
        x: f32,
        y: f32,
        max_w: f32,
        font_size: f32,
        color: [u8; 4],
    ) -> Self {
        Self {
            text: text.into(),
            x,
            y,
            max_w,
            max_h: font_size * 1.45,
            font_size,
            line_height: font_size * 1.25,
            color,
            bold: false,
            semibold: false,
            center: false,
        }
    }

    pub fn centered(
        text: impl Into<String>,
        cx: f32,
        y: f32,
        box_w: f32,
        font_size: f32,
        color: [u8; 4],
    ) -> Self {
        Self {
            text: text.into(),
            x: cx - box_w * 0.5,
            y,
            max_w: box_w,
            max_h: font_size * 1.45,
            font_size,
            line_height: font_size * 1.25,
            color,
            bold: false,
            semibold: false,
            center: true,
        }
    }

    pub fn semibold(mut self) -> Self {
        self.semibold = true;
        self
    }

    pub fn bold(mut self) -> Self {
        self.bold = true;
        self
    }
}

pub struct FlyoutTextLayer {
    font_system: FontSystem,
    swash_cache: SwashCache,
    #[allow(dead_code)]
    cache: Cache,
    viewport: Viewport,
    atlas: TextAtlas,
    renderer: TextRenderer,
    buffers: Vec<Buffer>,
    entries: Vec<TextEntry>,
    font_family: String,
}

impl FlyoutTextLayer {
    pub fn new(
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        surface_format: wgpu::TextureFormat,
        width: u32,
        height: u32,
        font_family: &str,
    ) -> Self {
        let font_system = FontSystem::new();
        let swash_cache = SwashCache::new();
        let cache = Cache::new(device);
        let mut viewport = Viewport::new(device, &cache);
        viewport.update(
            queue,
            Resolution {
                width: width.max(1),
                height: height.max(1),
            },
        );
        let mut atlas = TextAtlas::new(device, queue, &cache, surface_format);
        let renderer = TextRenderer::new(
            &mut atlas,
            device,
            wgpu::MultisampleState::default(),
            None,
        );

        Self {
            font_system,
            swash_cache,
            cache,
            viewport,
            atlas,
            renderer,
            buffers: Vec::with_capacity(48),
            entries: Vec::with_capacity(48),
            font_family: font_family.to_string(),
        }
    }

    pub fn set_font_family(&mut self, font_family: &str) {
        if self.font_family != font_family {
            self.font_family = font_family.to_string();
        }
    }

    pub fn resize(&mut self, queue: &wgpu::Queue, width: u32, height: u32) {
        self.viewport.update(
            queue,
            Resolution {
                width: width.max(1),
                height: height.max(1),
            },
        );
    }

    pub fn prepare(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        entries: Vec<TextEntry>,
    ) {
        self.entries = entries;
        let needed = self.entries.len();

        while self.buffers.len() < needed {
            self.buffers.push(Buffer::new(
                &mut self.font_system,
                Metrics::new(14.0, 18.0),
            ));
        }

        let family = if self.font_family.trim().is_empty() {
            Family::Name("Space Grotesk")
        } else {
            Family::Name(&self.font_family)
        };

        for (i, entry) in self.entries.iter().enumerate() {
            let buf = &mut self.buffers[i];
            let fs = entry.font_size.max(6.0);
            let lh = entry.line_height.max(fs * 1.1);
            buf.set_metrics_and_size(
                Metrics::new(fs, lh),
                Some(entry.max_w.max(10.0)),
                Some(entry.max_h.max(lh + 4.0)),
            );

            let weight = if entry.bold {
                Weight::BOLD
            } else if entry.semibold {
                Weight::SEMIBOLD
            } else {
                Weight::MEDIUM
            };

            let attrs = Attrs::new().family(family).weight(weight);
            let align = if entry.center {
                Some(Align::Center)
            } else {
                Some(Align::Left)
            };

            buf.set_text(&entry.text, &attrs, Shaping::Advanced, align);
            buf.shape_until_scroll(&mut self.font_system, false);
        }

        let areas: Vec<TextArea<'_>> = self
            .entries
            .iter()
            .enumerate()
            .filter(|(_, e)| e.color[3] > 2)
            .map(|(i, e)| {
                let left = e.x.round();
                let top = e.y.round();
                TextArea {
                    buffer: &self.buffers[i],
                    left,
                    top,
                    scale: 1.0,
                    bounds: TextBounds {
                        left: left as i32,
                        top: top as i32,
                        right: (left + e.max_w).ceil() as i32,
                        bottom: (top + e.max_h).ceil() as i32,
                    },
                    default_color: Color::rgba(e.color[0], e.color[1], e.color[2], e.color[3]),
                    custom_glyphs: &[],
                }
            })
            .collect();

        let _ = self.renderer.prepare(
            device,
            queue,
            &mut self.font_system,
            &mut self.atlas,
            &self.viewport,
            areas,
            &mut self.swash_cache,
        );
    }

    pub fn render<'pass>(&'pass self, pass: &mut wgpu::RenderPass<'pass>) {
        if !self.entries.is_empty() {
            let _ = self.renderer.render(&self.atlas, &self.viewport, pass);
        }
    }

    pub fn trim(&mut self) {
        self.atlas.trim();
    }
}
