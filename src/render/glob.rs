use std::sync::Arc;
use std::time::Instant;
use bytemuck::{Pod, Zeroable};
use wgpu::util::DeviceExt;
use winit::window::Window;

use crate::flyout::start_roots::{RootSegGpu, MAX_ROOT_SEGS};
use crate::render::text::{FlyoutTextLayer, TextEntry};

/// Gabungan compile-time dari seluruh modul WGSL terpisah di `src/render/shaders/`.
pub const COMBINED_WGSL: &str = concat!(
    include_str!("shaders/00_uniforms.wgsl"),
    "\n",
    include_str!("shaders/01_noise_sdf.wgsl"),
    "\n",
    include_str!("shaders/02_taskbar_wave.wgsl"),
    "\n",
    include_str!("shaders/03_flyout_icons.wgsl"),
    "\n",
    include_str!("shaders/04_ui_primitives.wgsl"),
    "\n",
    include_str!("shaders/05_flyout_main.wgsl"),
    "\n",
    include_str!("shaders/06_subflyouts_net.wgsl"),
    "\n",
    include_str!("shaders/07_subflyouts_av_pwr.wgsl"),
    "\n",
    include_str!("shaders/09_start_roots.wgsl"),
    "
",
    include_str!("shaders/08_themes_main.wgsl"),
);

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct GlobUniforms {
    pub screen_size: [f32; 2],
    pub bar_width: f32,
    pub bar_height: f32,
    pub corner_radius: f32,
    pub fillet_radius: f32,
    pub time: f32,
    pub srgb_target: f32,
    pub anim_t: f32,
    pub wave_surge: f32,
    pub mouse_pos: [f32; 2],
    pub pull_strength: f32,
    pub mouse_speed: f32,
    pub mouse_slosh: f32,
    pub _padding0: f32,
    pub clock_time: [f32; 4],
    pub flyout_info: [f32; 4],
    pub flyout_meta: [f32; 4],
    pub flyout_state: [f32; 4],
    pub flyout_extra: [f32; 4],
    pub font_scales: [f32; 4],
    pub texture_params: [f32; 4],
    pub chain_info: [f32; 4],    // [slot1_kind, slot2_kind, slot2_open_t, wifi_toggle_t]
    pub chain_offsets: [f32; 4], // [sub1_offset_x, sub2_offset_x, slot2_parent_is_main, spatial_toggle_t]
    pub audio_levels: [f32; 4],  // [app0_vol, app1_vol, app2_vol, mic_gain]
    pub power_extra: [f32; 4],   // [screen_timeout_idx, care_toggle_t, night_toggle_t, adaptive_toggle_t]
    pub start_info: [f32; 4],    // [phase1_t, phase2_t, pillar_rise_px, win_cinch]
    pub tree_params: [f32; 4],   // [root_seg_count, particle_count, particle_pull, low_quality]
    pub start_fx: [f32; 4],      // [win_flash, win_ripple, pull_activity, seed_phase]
    pub tree_style: [f32; 4],    // [trunk_style, trunk_thickness, trunk_lean, soul_leaves]
}

pub struct GlobRenderer {
    pub surface: wgpu::Surface<'static>,
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub config: wgpu::SurfaceConfiguration,
    pub pipeline: wgpu::RenderPipeline,
    pub uniform_buffer: wgpu::Buffer,
    pub root_buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub uniforms: GlobUniforms,
    pub text_layer: FlyoutTextLayer,
    pub start_time: Instant,
}

impl GlobRenderer {
    pub async fn new(window: Arc<Window>, font_family: &str) -> Self {
        let size = window.inner_size();
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::PRIMARY,
            flags: wgpu::InstanceFlags::default(),
            backend_options: wgpu::BackendOptions::default(),
            display: None,
            memory_budget_thresholds: Default::default(),
        });
        let surface = instance
            .create_surface(window.clone())
            .expect("Failed to create surface");

        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::LowPower,
                compatible_surface: Some(&surface),
                ..Default::default()
            })
            .await
            .expect("Failed to find suitable GPU adapter");

        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                label: Some("Lunula Bar Device"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                experimental_features: Default::default(),
                memory_hints: wgpu::MemoryHints::MemoryUsage,
                trace: Default::default(),
            })
            .await
            .expect("Failed to create GPU device");

        let surface_caps = surface.get_capabilities(&adapter);
        let alpha_mode = if surface_caps
            .alpha_modes
            .contains(&wgpu::CompositeAlphaMode::PreMultiplied)
        {
            wgpu::CompositeAlphaMode::PreMultiplied
        } else if surface_caps
            .alpha_modes
            .contains(&wgpu::CompositeAlphaMode::PostMultiplied)
        {
            wgpu::CompositeAlphaMode::PostMultiplied
        } else if surface_caps
            .alpha_modes
            .contains(&wgpu::CompositeAlphaMode::Inherit)
        {
            wgpu::CompositeAlphaMode::Inherit
        } else {
            surface_caps.alpha_modes[0]
        };

        let surface_format = surface_caps
            .formats
            .iter()
            .copied()
            .find(|f| f.is_srgb())
            .unwrap_or(surface_caps.formats[0]);

        let width = size.width.max(1);
        let height = size.height.max(1);

        let mut config = surface
            .get_default_config(&adapter, width, height)
            .expect("Surface config not supported");
        config.format = surface_format;
        config.alpha_mode = alpha_mode;
        config.present_mode = wgpu::PresentMode::Fifo;
        surface.configure(&device, &config);

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Lunula Modular WGSL Shader"),
            source: wgpu::ShaderSource::Wgsl(COMBINED_WGSL.into()),
        });

        let uniforms = GlobUniforms {
            screen_size: [width as f32, height as f32],
            bar_width: (width as f32) * 0.50,
            bar_height: 108.0,
            corner_radius: 42.0,
            fillet_radius: 130.0,
            time: 0.0,
            srgb_target: if surface_format.is_srgb() { 1.0 } else { 0.0 },
            anim_t: 1.0,
            wave_surge: 0.0,
            mouse_pos: [-1000.0, -1000.0],
            pull_strength: 0.0,
            mouse_speed: 0.0,
            mouse_slosh: 0.0,
            _padding0: 0.0,
            clock_time: [0.0; 4],
            flyout_info: [0.0; 4],
            flyout_meta: [0.0; 4],
            flyout_state: [0.0; 4],
            flyout_extra: [0.0; 4],
            font_scales: [1.0, 1.0, 1.0, 0.0],
            texture_params: [0.65, 30.0, -408.0, 0.92],
            chain_info: [0.0, 0.0, 0.0, 1.0],
            chain_offsets: [-408.0, -772.0, 0.0, 0.0],
            audio_levels: [0.86, 0.64, 0.90, 0.80],
            power_extra: [1.0, 1.0, 0.0, 0.0],
            start_info: [0.0; 4],
            tree_params: [0.0, 44.0, 1.0, 0.0],
            start_fx: [0.0, 1.0, 0.55, 0.0],
            tree_style: [0.0, 1.0, 0.30, 1.0],
        };

        let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Glob Uniform Buffer"),
            contents: bytemuck::cast_slice(&[uniforms]),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        let empty_roots = [RootSegGpu::zeroed(); MAX_ROOT_SEGS];
        let root_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Procedural Roots Buffer"),
            contents: bytemuck::cast_slice(&empty_roots),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Glob Bind Group Layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });

        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Glob Bind Group"),
            layout: &bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: root_buffer.as_entire_binding(),
                },
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Glob Pipeline Layout"),
            bind_group_layouts: &[Some(&bind_group_layout)],
            immediate_size: 0,
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Glob Render Pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_main"),
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let text_layer =
            FlyoutTextLayer::new(&device, &queue, config.format, width, height, font_family);

        Self {
            surface,
            device,
            queue,
            config,
            pipeline,
            uniform_buffer,
            root_buffer,
            bind_group,
            uniforms,
            text_layer,
            start_time: Instant::now(),
        }
    }

    pub fn update_root_segments(&mut self, segs: &[RootSegGpu; MAX_ROOT_SEGS]) {
        self.queue.write_buffer(&self.root_buffer, 0, bytemuck::cast_slice(segs));
    }

    pub fn set_font_family(&mut self, font_family: &str) {
        self.text_layer.set_font_family(font_family);
    }

    pub fn elapsed_secs(&self) -> f32 {
        self.start_time.elapsed().as_secs_f32()
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        if width > 0 && height > 0 {
            self.config.width = width;
            self.config.height = height;
            self.surface.configure(&self.device, &self.config);
            self.uniforms.screen_size = [width as f32, height as f32];
            self.uniforms.bar_width = (width as f32) * 0.50;
            self.queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&[self.uniforms]));
            self.text_layer.resize(&self.queue, width, height);
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn update_animation(
        &mut self,
        anim_t: f32,
        wave_surge: f32,
        mouse_pos: [f32; 2],
        pull_strength: f32,
        mouse_speed: f32,
        mouse_slosh: f32,
        clock_time: [f32; 4],
        flyout_info: [f32; 4],
        flyout_meta: [f32; 4],
        flyout_state: [f32; 4],
        flyout_extra: [f32; 4],
        font_scales: [f32; 4],
        texture_params: [f32; 4],
        chain_info: [f32; 4],
        chain_offsets: [f32; 4],
        audio_levels: [f32; 4],
        power_extra: [f32; 4],
        start_info: [f32; 4],
        tree_params: [f32; 4],
        start_fx: [f32; 4],
        tree_style: [f32; 4],
        text_entries: Vec<TextEntry>,
    ) {
        self.uniforms.anim_t = anim_t;
        self.uniforms.wave_surge = wave_surge;
        self.uniforms.mouse_pos = mouse_pos;
        self.uniforms.pull_strength = pull_strength;
        self.uniforms.mouse_speed = mouse_speed;
        self.uniforms.mouse_slosh = mouse_slosh;
        self.uniforms.clock_time = clock_time;
        self.uniforms.flyout_info = flyout_info;
        self.uniforms.flyout_meta = flyout_meta;
        self.uniforms.flyout_state = flyout_state;
        self.uniforms.flyout_extra = flyout_extra;
        self.uniforms.font_scales = font_scales;
        self.uniforms.texture_params = texture_params;
        self.uniforms.chain_info = chain_info;
        self.uniforms.chain_offsets = chain_offsets;
        self.uniforms.audio_levels = audio_levels;
        self.uniforms.power_extra = power_extra;
        self.uniforms.start_info = start_info;
        self.uniforms.tree_params = tree_params;
        self.uniforms.start_fx = start_fx;
        self.uniforms.tree_style = tree_style;

        self.text_layer.prepare(&self.device, &self.queue, text_entries);
    }

    pub fn render(&mut self) -> bool {
        self.uniforms.time = self.start_time.elapsed().as_secs_f32();
        self.queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&[self.uniforms]));

        let output = match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(t)
            | wgpu::CurrentSurfaceTexture::Suboptimal(t) => t,
            wgpu::CurrentSurfaceTexture::Outdated | wgpu::CurrentSurfaceTexture::Lost => {
                self.resize(self.config.width, self.config.height);
                return true;
            }
            _ => return true,
        };

        let view = output.texture.create_view(&wgpu::TextureViewDescriptor::default());
        let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Glob Render Encoder"),
        });

        {
            let mut rpass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Glob Render Pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color { r: 0.0, g: 0.0, b: 0.0, a: 0.0 }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });

            rpass.set_pipeline(&self.pipeline);
            rpass.set_bind_group(0, &self.bind_group, &[]);
            rpass.draw(0..6, 0..1);
            self.text_layer.render(&mut rpass);
        }

        self.queue.submit(std::iter::once(encoder.finish()));
        self.queue.present(output);
        self.text_layer.trim();
        true
    }
}
