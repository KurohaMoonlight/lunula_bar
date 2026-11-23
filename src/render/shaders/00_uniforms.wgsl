struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct GlobUniforms {
    screen_size: vec2<f32>,   // window size (width, height)
    bar_width: f32,           // main bar width (50% screen)
    bar_height: f32,          // max height (108.0)
    corner_radius: f32,       // 42.0
    fillet_radius: f32,       // 130.0
    time: f32,
    srgb_target: f32,         // 1.0 if srgb
    anim_t: f32,              // 0.0 = peeking crest, 1.0 = fully open
    wave_surge: f32,          // kinetic surge energy from motion
    mouse_pos: vec2<f32>,     // window cursor coordinate (x, y)
    pull_strength: f32,       // 0.0 .. 1.0 magnetic pull intensity
    mouse_speed: f32,         // kecepatan gerak mouse
    mouse_slosh: f32,         // unused / reserved
    _pad0: f32,
    clock_time: vec4<f32>,    // [hour, minute, second, 0.0]
    flyout_info: vec4<f32>,   // [module (0=none, 1=vol, 2=bat, 3=wifi), open_t (0..1), theme (0..2), value]
    flyout_meta: vec4<f32>,   // [center_x, center_y, is_charging, bat_percent]
    flyout_state: vec4<f32>,  // [flags_bitmask, power_mode, sound_output, brightness]
    flyout_extra: vec4<f32>,  // [bat_mins, wifi_signal, volume_level, sub_open_t]
    font_scales: vec4<f32>,   // [display_scale, body_scale, dpi_factor, 0.0]
    texture_params: vec4<f32>, // [texture_intensity, texture_fade_px, sub1_offset_x, backdrop_alpha]
    chain_info: vec4<f32>,     // [slot1_kind, slot2_kind, slot2_open_t, wifi_toggle_t]
    chain_offsets: vec4<f32>,  // [sub1_offset_x, sub2_offset_x, slot2_parent_is_main, spatial_toggle_t]
    audio_levels: vec4<f32>,   // [app0_vol, app1_vol, app2_vol, mic_gain]
    power_extra: vec4<f32>,    // [screen_timeout_idx, care_toggle_t, night_toggle_t, adaptive_toggle_t]
    start_info: vec4<f32>,     // [phase1_t, phase2_t, pillar_rise_px, win_cinch]
    tree_params: vec4<f32>,    // [root_seg_count, particle_count, particle_pull, low_quality]
    start_fx: vec4<f32>,       // [win_flash, win_ripple, pull_activity, seed_phase]
    tree_style: vec4<f32>,     // [trunk_style, trunk_thickness, trunk_lean, soul_leaves]
};

struct RootSeg {
    a: vec2<f32>,
    b: vec2<f32>,
    r0: f32,
    r1: f32,
    depth: f32,
    stagger: f32,
    arc0: f32,
    arc1: f32,
    root_id: f32,
    layer_phase: f32,
};

struct RootSegBuffer {
    segs: array<RootSeg, 96>,
};

@group(0) @binding(0)
var<uniform> u: GlobUniforms;

@group(0) @binding(1)
var<uniform> roots_buf: RootSegBuffer;

@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;
    var positions = array<vec2<f32>, 4>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>(-1.0,  1.0),
        vec2<f32>( 1.0,  1.0)
    );

    let indices = array<u32, 6>(0u, 1u, 2u, 2u, 1u, 3u);
    let p = positions[indices[in_vertex_index]];
    out.position = vec4<f32>(p, 0.0, 1.0);
    out.uv = vec2<f32>((p.x + 1.0) * 0.5, (1.0 - p.y) * 0.5);
    return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
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

// ─────────────────────────────────────────────────────────────────────────────
