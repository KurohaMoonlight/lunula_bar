// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 4: APP VOLUME MIXER (Mini Kanagawa Wave Sliders per App)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_app_mixer_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let orange  = hex(235.0, 120.0, 85.0);

    // Header: Back (-126, -114) & Reset (+126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    let ref_c = center + vec2<f32>(126.0, -114.0) * pop;
    let t_ref = draw_fly_tile(p, mouse_pos, ref_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_ref.col;
    fg_alpha = t_ref.alpha;
    let ref_ic = icon_refresh_sdf(p, t_ref.eff_center, 1.38 * pop);
    fg_col = mix(fg_col, aqua, ref_ic * reveal);
    fg_alpha = max(fg_alpha, ref_ic * reveal);

    // 3 App Volume Rows (y = -52, +8, +68)
    var ys = array<f32, 3>(-52.0, 8.0, 68.0);
    var lvls = array<f32, 3>(u.audio_levels.x, u.audio_levels.y, u.audio_levels.z);
    var mutes = array<bool, 3>(fly_flag(17u), fly_flag(18u), fly_flag(19u));

    for (var i = 0u; i < 3u; i = i + 1u) {
        let rc = center + vec2<f32>(0.0, ys[i]) * pop;
        let is_m = mutes[i];

        // Mute mini tile on left (-124, y)
        let mc = rc + vec2<f32>(-124.0, 0.0) * pop;
        let t_m = draw_fly_tile(p, mouse_pos, mc, vec2<f32>(18.0, 18.0) * pop, 9.0 * pop, select(0.0, 1.0, is_m), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_m.col;
        fg_alpha = t_m.alpha;
        let mic = icon_speaker_sdf(p, t_m.eff_center, 1.12 * pop, is_m);
        fg_col = mix(fg_col, select(cream, orange, is_m), mic * reveal);
        fg_alpha = max(fg_alpha, mic * reveal);

        // Mini Kanagawa Acoustic Wave Slider (-2, y + 8, half 90x10)
        let sres = draw_kanagawa_audio_slider(
            p, mouse_pos,
            rc + vec2<f32>(-2.0, 8.0) * pop,
            vec2<f32>(90.0, 10.0) * pop,
            7.0 * pop,
            lvls[i], is_m, time + f32(i) * 0.7, reveal,
            fg_col, fg_alpha
        );
        fg_col = sres.col;
        fg_alpha = sres.alpha;
    }

    // Bottom Settings Bar
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 5: SOUND & MIC FX (Spatial Audio, EQ Presets, Mic Gain Kanagawa Slider)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_audio_fx_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let orange  = hex(235.0, 120.0, 85.0);

    let spatial_on = fly_flag(7u);
    let mic_muted = fly_flag(6u);
    let eq_idx = select(0u, 1u, fly_flag(20u)) | select(0u, 2u, fly_flag(21u));
    let sp_t = clamp(u.chain_offsets.w, 0.0, 1.0);

    // Header: Back (-126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    // Section 1: Spatial Audio Card (0, -60, half 150x24) + Flat-Luminous Toggle
    let sp_c = center + vec2<f32>(0.0, -60.0) * pop;
    let t_sp = draw_fly_tile(p, mouse_pos, sp_c, vec2<f32>(150.0, 24.0) * pop, 13.0 * pop, select(0.0, 0.85, spatial_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_sp.col;
    fg_alpha = t_sp.alpha;
    let sp_ic = icon_spatial_sdf(p, t_sp.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.38 * pop);
    fg_col = mix(fg_col, select(cream, aqua, spatial_on), sp_ic * reveal);
    fg_alpha = max(fg_alpha, sp_ic * reveal);

    let sw_res = draw_kanagawa_toggle(
        p, mouse_pos, t_sp.eff_center + vec2<f32>(108.0, 0.0) * pop,
        pop * 0.92, sp_t, time, reveal, fg_col, fg_alpha
    );
    fg_col = sw_res.col;
    fg_alpha = sw_res.alpha;

    // Section 2: EQ Presets (Flat -104, Warm 0, Studio +104; y = -2, half 46x22)
    var eq_xs = array<f32, 3>(-104.0, 0.0, 104.0);
    for (var i = 0u; i < 3u; i = i + 1u) {
        let ec = center + vec2<f32>(eq_xs[i], -2.0) * pop;
        let t_eq = draw_fly_tile(p, mouse_pos, ec, vec2<f32>(46.0, 22.0) * pop, 11.0 * pop, select(0.0, 1.0, eq_idx == i), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_eq.col;
        fg_alpha = t_eq.alpha;
    }

    // Section 3: Microphone Gain Row (y = +58)
    let mc = center + vec2<f32>(-124.0, 58.0) * pop;
    let t_mc = draw_fly_tile(p, mouse_pos, mc, vec2<f32>(18.0, 18.0) * pop, 9.0 * pop, select(0.0, 1.0, mic_muted), orange, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_mc.col;
    fg_alpha = t_mc.alpha;
    let mic_ic = icon_mic_sdf(p, t_mc.eff_center, 1.18 * pop, mic_muted);
    fg_col = mix(fg_col, select(cream, orange, mic_muted), mic_ic * reveal);
    fg_alpha = max(fg_alpha, mic_ic * reveal);

    let mg_res = draw_kanagawa_audio_slider(
        p, mouse_pos,
        center + vec2<f32>(-4.0, 64.0) * pop,
        vec2<f32>(88.0, 10.0) * pop,
        7.0 * pop,
        u.audio_levels.w, mic_muted, time + 1.3, reveal,
        fg_col, fg_alpha
    );
    fg_col = mg_res.col;
    fg_alpha = mg_res.alpha;

    // Footer
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 6: BATTERY HEALTH & 80% CARE MODE
// ─────────────────────────────────────────────────────────────────────────────
fn draw_battery_health_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let green   = hex(152.0, 187.0, 108.0);
    let care_on = fly_flag(22u);
    let care_t  = clamp(u.power_extra.y, 0.0, 1.0);

    // Header: Back (-126, -114)
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    // Card 1: Condition (0, -56, half 150x26)
    let c1 = center + vec2<f32>(0.0, -56.0) * pop;
    let t_c1 = draw_fly_tile(p, mouse_pos, c1, vec2<f32>(150.0, 26.0) * pop, 13.0 * pop, 0.70, green, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_c1.col;
    fg_alpha = t_c1.alpha;
    let c1_ic = icon_leaf_sdf(p, t_c1.eff_center + vec2<f32>(-122.0, 0.0) * pop, 1.42 * pop);
    fg_col = mix(fg_col, green, c1_ic * reveal);
    fg_alpha = max(fg_alpha, c1_ic * reveal);

    // Card 2: Battery Care 80% Limit (0, +2, half 150x24) + Flat-Luminous Toggle
    let c2 = center + vec2<f32>(0.0, 2.0) * pop;
    let t_c2 = draw_fly_tile(p, mouse_pos, c2, vec2<f32>(150.0, 24.0) * pop, 13.0 * pop, select(0.0, 0.80, care_on), gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_c2.col;
    fg_alpha = t_c2.alpha;
    let c2_ic = icon_gauge_sdf(p, t_c2.eff_center + vec2<f32>(-122.0, 0.0) * pop, 1.38 * pop);
    fg_col = mix(fg_col, select(cream, gold_hi, care_on), c2_ic * reveal);
    fg_alpha = max(fg_alpha, c2_ic * reveal);
    let sw_care = draw_kanagawa_toggle(p, mouse_pos, t_c2.eff_center + vec2<f32>(108.0, 0.0) * pop, pop * 0.90, care_t, time, reveal, fg_col, fg_alpha);
    fg_col = sw_care.col;
    fg_alpha = sw_care.alpha;

    // Card 3: Power Draw / AC Status (0, +60, half 150x26)
    let c3 = center + vec2<f32>(0.0, 60.0) * pop;
    let t_c3 = draw_fly_tile(p, mouse_pos, c3, vec2<f32>(150.0, 26.0) * pop, 13.0 * pop, 0.35, aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_c3.col;
    fg_alpha = t_c3.alpha;
    let c3_ic = icon_flame_sdf(p, t_c3.eff_center + vec2<f32>(-122.0, 0.0) * pop, 1.40 * pop);
    fg_col = mix(fg_col, aqua, c3_ic * reveal);
    fg_alpha = max(fg_alpha, c3_ic * reveal);

    // Footer
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FLYOUT 7: DISPLAY & SLEEP (Night Light, Screen Timeout, Adaptive Bright)
// ─────────────────────────────────────────────────────────────────────────────
fn draw_display_power_subflyout(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold    = hex(230.0, 195.0, 132.0);
    let gold_hi = hex(255.0, 238.0, 178.0);
    let cream   = hex(240.0, 235.0, 215.0);
    let aqua    = hex(127.0, 180.0, 202.0);
    let amber   = hex(220.0, 165.0, 97.0);

    let night_on = fly_flag(4u);
    let adapt_on = fly_flag(23u);
    let to_idx   = u32(clamp(u.power_extra.x + 0.5, 0.0, 2.0));
    let night_t  = clamp(u.power_extra.z, 0.0, 1.0);
    let adapt_t  = clamp(u.power_extra.w, 0.0, 1.0);

    // Header: Back
    let back_c = center + vec2<f32>(-126.0, -114.0) * pop;
    let t_back = draw_fly_tile(p, mouse_pos, back_c, vec2<f32>(24.0, 18.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_back.col;
    fg_alpha = t_back.alpha;
    let back_ic = icon_chevron_sdf(p, t_back.eff_center, 1.38 * pop, true);
    fg_col = mix(fg_col, gold_hi, back_ic * reveal);
    fg_alpha = max(fg_alpha, back_ic * reveal);

    // Card 1: Night Light (0, -60, half 150x24)
    let nl_c = center + vec2<f32>(0.0, -60.0) * pop;
    let t_nl = draw_fly_tile(p, mouse_pos, nl_c, vec2<f32>(150.0, 24.0) * pop, 13.0 * pop, select(0.0, 0.85, night_on), amber, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_nl.col;
    fg_alpha = t_nl.alpha;
    let nl_ic = icon_moon_sdf(p, t_nl.eff_center + vec2<f32>(-122.0, 0.0) * pop, 1.38 * pop);
    fg_col = mix(fg_col, select(cream, amber, night_on), nl_ic * reveal);
    fg_alpha = max(fg_alpha, nl_ic * reveal);
    let sw_nl = draw_kanagawa_toggle(p, mouse_pos, t_nl.eff_center + vec2<f32>(108.0, 0.0) * pop, pop * 0.90, night_t, time, reveal, fg_col, fg_alpha);
    fg_col = sw_nl.col;
    fg_alpha = sw_nl.alpha;

    // Section 2: Screen Timeout Pills (5m, 15m, Never; y = -2)
    var to_xs = array<f32, 3>(-104.0, 0.0, 104.0);
    for (var i = 0u; i < 3u; i = i + 1u) {
        let tc = center + vec2<f32>(to_xs[i], -2.0) * pop;
        let t_to = draw_fly_tile(p, mouse_pos, tc, vec2<f32>(46.0, 22.0) * pop, 11.0 * pop, select(0.0, 1.0, to_idx == i), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_to.col;
        fg_alpha = t_to.alpha;
    }

    // Card 3: Adaptive Brightness (0, +58, half 150x24)
    let ad_c = center + vec2<f32>(0.0, 58.0) * pop;
    let t_ad = draw_fly_tile(p, mouse_pos, ad_c, vec2<f32>(150.0, 24.0) * pop, 13.0 * pop, select(0.0, 0.85, adapt_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_ad.col;
    fg_alpha = t_ad.alpha;
    let ad_ic = icon_sun_sdf(p, t_ad.eff_center + vec2<f32>(-122.0, 0.0) * pop, 1.35 * pop);
    fg_col = mix(fg_col, select(cream, aqua, adapt_on), ad_ic * reveal);
    fg_alpha = max(fg_alpha, ad_ic * reveal);
    let sw_ad = draw_kanagawa_toggle(p, mouse_pos, t_ad.eff_center + vec2<f32>(108.0, 0.0) * pop, pop * 0.90, adapt_t, time, reveal, fg_col, fg_alpha);
    fg_col = sw_ad.col;
    fg_alpha = sw_ad.alpha;

    // Footer
    let st_bar = center + vec2<f32>(0.0, 118.0) * pop;
    let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(150.0, 16.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
    fg_col = t_stb.col;
    fg_alpha = t_stb.alpha;
    let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-120.0, 0.0) * pop, 1.20 * pop);
    fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
    fg_alpha = max(fg_alpha, stb_ic * reveal);
    let stb_ch = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(122.0, 0.0) * pop, 1.18 * pop, false);
    fg_col = mix(fg_col, gold, stb_ch * reveal);
    fg_alpha = max(fg_alpha, stb_ch * reveal);

    return FlyoutRenderResult(fg_col, fg_alpha);
}

fn draw_subflyout_by_kind(
    kind: f32,
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    wifi_on: bool,
    sig: f32,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    if (abs(kind - 1.0) < 0.1) {
        return draw_networks_subflyout(p, mouse_pos, center, pop, reveal, wifi_on, sig, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 2.0) < 0.1) {
        return draw_bluetooth_subflyout(p, mouse_pos, center, pop, reveal, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 3.0) < 0.1) {
        return draw_password_subflyout(p, mouse_pos, center, pop, reveal, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 4.0) < 0.1) {
        return draw_app_mixer_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 5.0) < 0.1) {
        return draw_audio_fx_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 6.0) < 0.1) {
        return draw_battery_health_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    } else if (abs(kind - 7.0) < 0.1) {
        return draw_display_power_subflyout(p, mouse_pos, center, pop, reveal, time, base_col, base_alpha, halo_gain);
    }
    return FlyoutRenderResult(base_col, base_alpha);
}
