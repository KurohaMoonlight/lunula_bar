// ─────────────────────────────────────────────────────────────────────────────
// KONTEN MAIN FLYOUT (Teks dirender oleh glyphon Space Grotesk di pass yang sama)
//   1 = Volume & Sound Output
//   2 = Battery & Power
//   3 = Wi-Fi & Connectivity
// ─────────────────────────────────────────────────────────────────────────────
fn draw_flyout_content(
    p: vec2<f32>,
    mouse_pos: vec2<f32>,
    module_id: f32,
    center: vec2<f32>,
    pop: f32,
    reveal: f32,
    value: f32,
    extra_meta: vec2<f32>,
    time: f32,
    base_col: vec3<f32>,
    base_alpha: f32,
    halo_gain: f32,
) -> FlyoutRenderResult {
    var fg_col = base_col;
    var fg_alpha = base_alpha;

    let gold      = hex(230.0, 195.0, 132.0);
    let gold_hi   = hex(255.0, 238.0, 178.0);
    let cream     = hex(240.0, 235.0, 215.0);
    let muted_txt = hex(145.0, 152.0, 172.0);
    let aqua      = hex(127.0, 180.0, 202.0);
    let green     = hex(152.0, 187.0, 108.0);
    let orange    = hex(235.0, 120.0, 85.0);
    let amber     = hex(220.0, 165.0, 97.0);

    // ═════════════════════════════════════════════════════════════════════════
    // 1. VOLUME & SOUND OUTPUT (Kanagawa Acoustic Wave Slider + Complete Controls)
    // ═════════════════════════════════════════════════════════════════════════
    if (abs(module_id - 1.0) < 0.1) {
        let is_muted = fly_flag(5u);
        let mic_muted = fly_flag(6u);
        let spatial_on = fly_flag(7u);
        let out_idx = u32(clamp(u.flyout_state.z + 0.5, 0.0, 2.0));
        let vol = clamp(value, 0.0, 1.0);
        let mixer_open = (abs(u.chain_info.x - 4.0) < 0.1 && u.flyout_extra.w > 0.1)
                      || (abs(u.chain_info.y - 4.0) < 0.1 && u.chain_info.z > 0.1);
        let fx_open = (abs(u.chain_info.x - 5.0) < 0.1 && u.flyout_extra.w > 0.1)
                   || (abs(u.chain_info.y - 5.0) < 0.1 && u.chain_info.z > 0.1);

        // Row 1: Mute Button (-162, -94) + Kanagawa Acoustic Wave Slider (-8, -94)
        let mute_c = center + vec2<f32>(-162.0, -94.0) * pop;
        let t_mute = draw_fly_tile(
            p, mouse_pos, mute_c, vec2<f32>(26.0, 22.0) * pop, 12.0 * pop,
            select(0.0, 1.0, is_muted), orange, reveal, halo_gain, fg_col, fg_alpha
        );
        fg_col = t_mute.col;
        fg_alpha = t_mute.alpha;
        let mute_ic = icon_speaker_sdf(p, t_mute.eff_center, 1.38 * pop, is_muted);
        fg_col = mix(fg_col, select(cream, orange, is_muted), mute_ic * reveal);
        fg_alpha = max(fg_alpha, mute_ic * reveal);

        let sld_res = draw_kanagawa_audio_slider(
            p, mouse_pos,
            center + vec2<f32>(-8.0, -94.0) * pop,
            vec2<f32>(110.0, 20.0) * pop,
            12.0 * pop,
            vol, is_muted, time, reveal,
            fg_col, fg_alpha
        );
        fg_col = sld_res.col;
        fg_alpha = sld_res.alpha;

        // Row 2: Sound Output Device Selector (3 rows: -34, +12, +58; half 194x20)
        let r0_c = center + vec2<f32>(0.0, -34.0) * pop;
        let t_r0 = draw_fly_tile(p, mouse_pos, r0_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 0u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r0.col;
        fg_alpha = t_r0.alpha;
        let r0_ic = icon_speaker_sdf(p, t_r0.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop, false);
        let r0_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r0.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 0u), r0_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 0u), r0_dot * reveal);
        fg_alpha = max(fg_alpha, max(r0_ic, r0_dot) * reveal);

        let r1_c = center + vec2<f32>(0.0, 12.0) * pop;
        let t_r1 = draw_fly_tile(p, mouse_pos, r1_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 1u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r1.col;
        fg_alpha = t_r1.alpha;
        let r1_ic = icon_headphones_sdf(p, t_r1.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop);
        let r1_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r1.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 1u), r1_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 1u), r1_dot * reveal);
        fg_alpha = max(fg_alpha, max(r1_ic, r1_dot) * reveal);

        let r2_c = center + vec2<f32>(0.0, 58.0) * pop;
        let t_r2 = draw_fly_tile(p, mouse_pos, r2_c, vec2<f32>(194.0, 20.0) * pop, 12.0 * pop, select(0.0, 1.0, out_idx == 2u), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_r2.col;
        fg_alpha = t_r2.alpha;
        let r2_ic = icon_monitor_sdf(p, t_r2.eff_center + vec2<f32>(-160.0, 0.0) * pop, 1.32 * pop);
        let r2_dot = 1.0 - smoothstep(3.4 * pop, 4.8 * pop, length(p - (t_r2.eff_center + vec2<f32>(166.0, 0.0) * pop)));
        fg_col = mix(fg_col, select(cream, gold_hi, out_idx == 2u), r2_ic * reveal);
        fg_col = mix(fg_col, select(hex(64.0, 72.0, 92.0), gold_hi, out_idx == 2u), r2_dot * reveal);
        fg_alpha = max(fg_alpha, max(r2_ic, r2_dot) * reveal);

        // Row 3: Mic (-140) | Mixer > (-20) | Sound FX > (+100) | Gear (+179)
        let mic_c = center + vec2<f32>(-140.0, 110.0) * pop;
        let t_mic = draw_fly_tile(p, mouse_pos, mic_c, vec2<f32>(54.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, mic_muted), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_mic.col;
        fg_alpha = t_mic.alpha;
        let mic_ic = icon_mic_sdf(p, t_mic.eff_center + vec2<f32>(-32.0, 0.0) * pop, 1.22 * pop, mic_muted);
        fg_col = mix(fg_col, select(cream, orange, mic_muted), mic_ic * reveal);
        fg_alpha = max(fg_alpha, mic_ic * reveal);

        let mix_c = center + vec2<f32>(-20.0, 110.0) * pop;
        let t_mix = draw_fly_tile(p, mouse_pos, mix_c, vec2<f32>(58.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, mixer_open), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_mix.col;
        fg_alpha = t_mix.alpha;
        let mix_chv = icon_chevron_sdf(p, t_mix.eff_center + vec2<f32>(38.0, 0.0) * pop, 1.22 * pop, false);
        fg_col = mix(fg_col, select(gold, gold_hi, mixer_open), mix_chv * reveal);
        fg_alpha = max(fg_alpha, mix_chv * reveal);

        let fx_c = center + vec2<f32>(100.0, 110.0) * pop;
        let t_fx = draw_fly_tile(p, mouse_pos, fx_c, vec2<f32>(54.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, fx_open || spatial_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_fx.col;
        fg_alpha = t_fx.alpha;
        let fx_chv = icon_chevron_sdf(p, t_fx.eff_center + vec2<f32>(36.0, 0.0) * pop, 1.22 * pop, false);
        fg_col = mix(fg_col, select(gold, aqua, fx_open || spatial_on), fx_chv * reveal);
        fg_alpha = max(fg_alpha, fx_chv * reveal);

        let sg_c = center + vec2<f32>(179.0, 110.0) * pop;
        let t_sg = draw_fly_tile(p, mouse_pos, sg_c, vec2<f32>(17.0, 20.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_sg.col;
        fg_alpha = t_sg.alpha;
        let sg_ic = icon_gear_sdf(p, t_sg.eff_center, 1.22 * pop);
        fg_col = mix(fg_col, gold_hi, sg_ic * reveal);
        fg_alpha = max(fg_alpha, sg_ic * reveal);
    }
    // ═════════════════════════════════════════════════════════════════════════
    // 2. BATTERY & POWER MODE (Kanagawa Energy Tank + Solar Horizon Slider + Chain)
    // ═════════════════════════════════════════════════════════════════════════
    else if (abs(module_id - 2.0) < 0.1) {
        let is_charging = extra_meta.x > 0.5 || fly_flag(9u);
        let energy_saver = fly_flag(8u);
        let pmode = u32(clamp(u.flyout_state.y + 0.5, 0.0, 2.0));
        let bright = clamp(u.flyout_state.w, 0.05, 1.0);
        let bat_lvl = clamp(value, 0.0, 1.0);
        let health_open = (abs(u.chain_info.x - 6.0) < 0.1 && u.flyout_extra.w > 0.1)
                       || (abs(u.chain_info.y - 6.0) < 0.1 && u.chain_info.z > 0.1);
        let disp_open = (abs(u.chain_info.x - 7.0) < 0.1 && u.flyout_extra.w > 0.1)
                     || (abs(u.chain_info.y - 7.0) < 0.1 && u.chain_info.z > 0.1);

        var bat_accent = gold;
        if (is_charging) {
            bat_accent = green;
        } else if (bat_lvl <= 0.20) {
            bat_accent = orange;
        }

        // Row 1: Hero Battery Card (0, -90, half 194x36) -> clicks open Battery Health
        let hero_c = center + vec2<f32>(0.0, -90.0) * pop;
        let t_hero = draw_fly_tile(p, mouse_pos, hero_c, vec2<f32>(194.0, 36.0) * pop, 15.0 * pop, 0.55, bat_accent, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hero.col;
        fg_alpha = t_hero.alpha;

        let tank_res = draw_kanagawa_battery_tank(
            p, t_hero.eff_center + vec2<f32>(-104.0, 0.0) * pop,
            pop, bat_lvl, is_charging, time, reveal, fg_col, fg_alpha
        );
        fg_col = tank_res.col;
        fg_alpha = tank_res.alpha;

        let h_chv = icon_chevron_sdf(p, t_hero.eff_center + vec2<f32>(168.0, 0.0) * pop, 1.40 * pop, false);
        fg_col = mix(fg_col, gold_hi, h_chv * reveal);
        fg_alpha = max(fg_alpha, h_chv * reveal);

        // Row 2: Power Mode 3-Way Selector (dy = -12, half 59x28)
        let e_c = center + vec2<f32>(-135.0, -12.0) * pop;
        let t_eco = draw_fly_tile(p, mouse_pos, e_c, vec2<f32>(59.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 0u), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_eco.col;
        fg_alpha = t_eco.alpha;
        let e_ic = icon_leaf_sdf(p, t_eco.eff_center + vec2<f32>(0.0, -11.0) * pop, 1.28 * pop);
        fg_col = mix(fg_col, select(cream, green, pmode == 0u), e_ic * reveal);
        fg_alpha = max(fg_alpha, e_ic * reveal);

        let b_c = center + vec2<f32>(0.0, -12.0) * pop;
        let t_bal = draw_fly_tile(p, mouse_pos, b_c, vec2<f32>(59.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 1u), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_bal.col;
        fg_alpha = t_bal.alpha;
        let b_ic = icon_gauge_sdf(p, t_bal.eff_center + vec2<f32>(0.0, -11.0) * pop, 1.28 * pop);
        fg_col = mix(fg_col, select(cream, gold_hi, pmode == 1u), b_ic * reveal);
        fg_alpha = max(fg_alpha, b_ic * reveal);

        let f_c = center + vec2<f32>(135.0, -12.0) * pop;
        let t_prf = draw_fly_tile(p, mouse_pos, f_c, vec2<f32>(59.0, 28.0) * pop, 13.0 * pop, select(0.0, 1.0, pmode == 2u), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_prf.col;
        fg_alpha = t_prf.alpha;
        let f_ic = icon_flame_sdf(p, t_prf.eff_center + vec2<f32>(0.0, -11.0) * pop, 1.28 * pop);
        fg_col = mix(fg_col, select(cream, orange, pmode == 2u), f_ic * reveal);
        fg_alpha = max(fg_alpha, f_ic * reveal);

        // Row 3: Quick Sun Button (-162, +50) + Kanagawa Solar Horizon Brightness Slider (-8, +50)
        let sun_c = center + vec2<f32>(-162.0, 50.0) * pop;
        let t_sun = draw_fly_tile(p, mouse_pos, sun_c, vec2<f32>(26.0, 20.0) * pop, 11.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_sun.col;
        fg_alpha = t_sun.alpha;
        let sun_a = icon_sun_sdf(p, t_sun.eff_center, 1.32 * pop);
        fg_col = mix(fg_col, gold_hi, sun_a * reveal);
        fg_alpha = max(fg_alpha, sun_a * reveal);

        let br_res = draw_kanagawa_solar_slider(
            p, mouse_pos,
            center + vec2<f32>(-8.0, 50.0) * pop,
            vec2<f32>(110.0, 18.0) * pop,
            11.0 * pop,
            bright, time, reveal,
            fg_col, fg_alpha
        );
        fg_col = br_res.col;
        fg_alpha = br_res.alpha;

        // Row 4: Eco Saver (-132) | Health > (-6) | Display > (+106) | Gear (+179)
        let sv_c = center + vec2<f32>(-132.0, 110.0) * pop;
        let t_sv = draw_fly_tile(p, mouse_pos, sv_c, vec2<f32>(62.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, energy_saver), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_sv.col;
        fg_alpha = t_sv.alpha;
        let sv_ic = icon_leaf_sdf(p, t_sv.eff_center + vec2<f32>(-42.0, 0.0) * pop, 1.22 * pop);
        fg_col = mix(fg_col, select(cream, green, energy_saver), sv_ic * reveal);
        fg_alpha = max(fg_alpha, sv_ic * reveal);

        let hl_c = center + vec2<f32>(-6.0, 110.0) * pop;
        let t_hl = draw_fly_tile(p, mouse_pos, hl_c, vec2<f32>(56.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, health_open), gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hl.col;
        fg_alpha = t_hl.alpha;
        let hl_chv = icon_chevron_sdf(p, t_hl.eff_center + vec2<f32>(36.0, 0.0) * pop, 1.20 * pop, false);
        fg_col = mix(fg_col, select(gold, gold_hi, health_open), hl_chv * reveal);
        fg_alpha = max(fg_alpha, hl_chv * reveal);

        let dp_c = center + vec2<f32>(106.0, 110.0) * pop;
        let t_dp = draw_fly_tile(p, mouse_pos, dp_c, vec2<f32>(48.0, 20.0) * pop, 11.0 * pop, select(0.0, 1.0, disp_open), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_dp.col;
        fg_alpha = t_dp.alpha;
        let dp_chv = icon_chevron_sdf(p, t_dp.eff_center + vec2<f32>(32.0, 0.0) * pop, 1.20 * pop, false);
        fg_col = mix(fg_col, select(gold, aqua, disp_open), dp_chv * reveal);
        fg_alpha = max(fg_alpha, dp_chv * reveal);

        let pg_c = center + vec2<f32>(179.0, 110.0) * pop;
        let t_pg = draw_fly_tile(p, mouse_pos, pg_c, vec2<f32>(17.0, 20.0) * pop, 10.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_pg.col;
        fg_alpha = t_pg.alpha;
        let pg_ic = icon_gear_sdf(p, t_pg.eff_center, 1.22 * pop);
        fg_col = mix(fg_col, gold_hi, pg_ic * reveal);
        fg_alpha = max(fg_alpha, pg_ic * reveal);
    }
    // ═════════════════════════════════════════════════════════════════════════
    // 3. WI-FI & CONNECTIVITY (Luxury Kanagawa Wave Cards + Toggle + BT Split)
    // ═════════════════════════════════════════════════════════════════════════
    else if (abs(module_id - 3.0) < 0.1) {
        let wifi_on = fly_flag(0u);
        let bt_on = fly_flag(1u);
        let flight_on = fly_flag(2u);
        let spot_on = fly_flag(3u);
        let night_on = fly_flag(4u);
        let sig = clamp(value, 0.0, 1.0);
        let wifi_t = clamp(u.chain_info.w, 0.0, 1.0);

        // --- Row 1: Hero Wi-Fi Card (0, -94, half 196x36) ---
        let hero_c = center + vec2<f32>(0.0, -94.0) * pop;
        let t_hero = draw_fly_tile(p, mouse_pos, hero_c, vec2<f32>(196.0, 36.0) * pop, 15.0 * pop, select(0.0, 0.72, wifi_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hero.col;
        fg_alpha = t_hero.alpha;

        // Glowing Wi-Fi Icon on Left (-158, -94)
        let w_ic = icon_wifi_sdf(p, t_hero.eff_center + vec2<f32>(-158.0, 0.0) * pop, 1.75 * pop, select(0.0, sig, wifi_on));
        fg_col = mix(fg_col, select(muted_txt, aqua, wifi_on), w_ic * reveal);
        fg_alpha = max(fg_alpha, w_ic * reveal);

        // Chevron Arrow to open Wi-Fi Networks Sub-Flyout (+92, -94)
        let chev_c = t_hero.eff_center + vec2<f32>(92.0, 0.0) * pop;
        let chev_ic = icon_chevron_sdf(p, chev_c, 1.45 * pop, false);
        fg_col = mix(fg_col, gold_hi, chev_ic * reveal);
        fg_alpha = max(fg_alpha, chev_ic * reveal);

        // Luxury Kanagawa Wave & Kintsugi Gold Toggle Switch (+150, -94)
        let sw_res = draw_kanagawa_toggle(
            p, mouse_pos, t_hero.eff_center + vec2<f32>(150.0, 0.0) * pop,
            pop, wifi_t, time, reveal, fg_col, fg_alpha
        );
        fg_col = sw_res.col;
        fg_alpha = sw_res.alpha;

        // --- Row 2: Bluetooth Split Card (-102, -16) & Hotspot (+102, -16) ---
        let bt_c = center + vec2<f32>(-102.0, -16.0) * pop;
        let t_bt = draw_fly_tile(p, mouse_pos, bt_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, bt_on), aqua, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_bt.col;
        fg_alpha = t_bt.alpha;
        let bt_ic = icon_bluetooth_sdf(p, t_bt.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.55 * pop);
        fg_col = mix(fg_col, select(muted_txt, aqua, bt_on), bt_ic * reveal);
        fg_alpha = max(fg_alpha, bt_ic * reveal);

        // Subtle vertical split-divider + gold chevron on right of Bluetooth card to open BT sub-flyout!
        let div_x = t_bt.eff_center.x + 56.0 * pop;
        let d_div = sd_seg(p, vec2<f32>(div_x, t_bt.eff_center.y - 16.0 * pop), vec2<f32>(div_x, t_bt.eff_center.y + 16.0 * pop));
        let div_a = (1.0 - smoothstep(0.0, 1.1, d_div)) * 0.35 * reveal;
        fg_col = mix(fg_col, gold, div_a);
        let bt_chv = icon_chevron_sdf(p, t_bt.eff_center + vec2<f32>(74.0, 0.0) * pop, 1.30 * pop, false);
        fg_col = mix(fg_col, select(muted_txt, gold_hi, bt_on), bt_chv * reveal);
        fg_alpha = max(fg_alpha, bt_chv * reveal);

        let hs_c = center + vec2<f32>(102.0, -16.0) * pop;
        let t_hs = draw_fly_tile(p, mouse_pos, hs_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, spot_on), green, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_hs.col;
        fg_alpha = t_hs.alpha;
        let hs_ic = icon_hotspot_sdf(p, t_hs.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.48 * pop);
        fg_col = mix(fg_col, select(cream, green, spot_on), hs_ic * reveal);
        fg_alpha = max(fg_alpha, hs_ic * reveal);

        // --- Row 3: Flight Mode (-102, +50) & Night Light (+102, +50) ---
        let fl_c = center + vec2<f32>(-102.0, 50.0) * pop;
        let t_fl = draw_fly_tile(p, mouse_pos, fl_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, flight_on), orange, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_fl.col;
        fg_alpha = t_fl.alpha;
        let fl_ic = icon_airplane_sdf(p, t_fl.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.52 * pop);
        fg_col = mix(fg_col, select(cream, orange, flight_on), fl_ic * reveal);
        fg_alpha = max(fg_alpha, fl_ic * reveal);

        let nl_c = center + vec2<f32>(102.0, 50.0) * pop;
        let t_nl = draw_fly_tile(p, mouse_pos, nl_c, vec2<f32>(94.0, 28.0) * pop, 14.0 * pop, select(0.0, 1.0, night_on), amber, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_nl.col;
        fg_alpha = t_nl.alpha;
        let nl_ic = icon_moon_sdf(p, t_nl.eff_center + vec2<f32>(-62.0, 0.0) * pop, 1.45 * pop);
        fg_col = mix(fg_col, select(cream, amber, night_on), nl_ic * reveal);
        fg_alpha = max(fg_alpha, nl_ic * reveal);

        // --- Row 4: Network & Internet Settings Footer (0, +112, half 196x20) ---
        let st_bar = center + vec2<f32>(0.0, 112.0) * pop;
        let t_stb = draw_fly_tile(p, mouse_pos, st_bar, vec2<f32>(196.0, 20.0) * pop, 11.0 * pop, 0.0, gold, reveal, halo_gain, fg_col, fg_alpha);
        fg_col = t_stb.col;
        fg_alpha = t_stb.alpha;
        let stb_ic = icon_gear_sdf(p, t_stb.eff_center + vec2<f32>(-166.0, 0.0) * pop, 1.32 * pop);
        fg_col = mix(fg_col, gold_hi, stb_ic * reveal);
        fg_alpha = max(fg_alpha, stb_ic * reveal);
        let stb_chv = icon_chevron_sdf(p, t_stb.eff_center + vec2<f32>(166.0, 0.0) * pop, 1.28 * pop, false);
        fg_col = mix(fg_col, gold, stb_chv * reveal);
        fg_alpha = max(fg_alpha, stb_chv * reveal);
    }

    return FlyoutRenderResult(fg_col, fg_alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
