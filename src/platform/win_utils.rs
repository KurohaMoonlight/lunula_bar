use std::sync::atomic::{AtomicBool, AtomicI32, AtomicUsize, Ordering};
use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
use windows::Win32::Foundation::{HWND, LPARAM, LRESULT, POINT, WPARAM};
use windows::Win32::Graphics::Dwm::{
    DwmExtendFrameIntoClientArea, DwmSetWindowAttribute, DWMNCRP_DISABLED,
    DWMWA_NCRENDERING_POLICY, DWMWA_WINDOW_CORNER_PREFERENCE,
};
use windows::Win32::Graphics::Gdi::SetWindowRgn;
use windows::Win32::UI::Controls::MARGINS;
use windows::Win32::UI::WindowsAndMessaging::{
    CallNextHookEx, CallWindowProcW, GetCursorPos, GetWindowLongPtrW, SetWindowLongPtrW,
    SetWindowPos, SetWindowsHookExW, UnhookWindowsHookEx, GWLP_WNDPROC, GWL_EXSTYLE, GWL_STYLE,
    HHOOK, MSLLHOOKSTRUCT, SWP_FRAMECHANGED, SWP_NOACTIVATE, SWP_NOMOVE, SWP_NOSIZE, SWP_NOZORDER,
    WH_MOUSE_LL, WM_ACTIVATE, WM_ACTIVATEAPP, WM_DESTROY, WM_KILLFOCUS, WM_NCACTIVATE,
    WM_NCCALCSIZE, WM_NCHITTEST, WM_NCPAINT, WNDPROC, WS_BORDER, WS_CAPTION, WS_DLGFRAME,
    WS_EX_LAYERED, WS_EX_TOOLWINDOW, WS_EX_TRANSPARENT, WS_MAXIMIZEBOX, WS_MINIMIZEBOX, WS_POPUP,
    WS_SYSMENU, WS_THICKFRAME,
};

static PREV_WNDPROC: AtomicUsize = AtomicUsize::new(0);
static TARGET_HWND: AtomicUsize = AtomicUsize::new(0);
static MOUSE_HOOK: AtomicUsize = AtomicUsize::new(0);
static IS_CLICKTHROUGH: AtomicBool = AtomicBool::new(false);

// Dynamic hit-test zones for passing clicks through outside the glob
// Zone 1: Main Taskbar Bar
pub static BAR_TOP_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static BAR_LEFT_X: AtomicI32 = AtomicI32::new(0);
pub static BAR_RIGHT_X: AtomicI32 = AtomicI32::new(0);

// Zone 2: Main Flyout / Floating Search Pill
pub static FLY_TOP_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static FLY_BOTTOM_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static FLY_LEFT_X: AtomicI32 = AtomicI32::new(0);
pub static FLY_RIGHT_X: AtomicI32 = AtomicI32::new(0);
pub static FLY_CX: AtomicI32 = AtomicI32::new(0);
pub static FLY_CY: AtomicI32 = AtomicI32::new(0);
pub static FLY_HAS_STALK: AtomicBool = AtomicBool::new(false);

// Zone 3: Sub-Flyout Slot 1
pub static SUB1_TOP_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static SUB1_BOTTOM_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static SUB1_LEFT_X: AtomicI32 = AtomicI32::new(0);
pub static SUB1_RIGHT_X: AtomicI32 = AtomicI32::new(0);

// Zone 4: Sub-Flyout Slot 2 (Chain)
pub static SUB2_TOP_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static SUB2_BOTTOM_Y: AtomicI32 = AtomicI32::new(i32::MAX);
pub static SUB2_LEFT_X: AtomicI32 = AtomicI32::new(0);
pub static SUB2_RIGHT_X: AtomicI32 = AtomicI32::new(0);

/// Flag yang diset saat window kehilangan fokus atau di-klik di luar
pub static SHOULD_DISMISS_FLYOUT: AtomicBool = AtomicBool::new(false);

/// Evaluasi hit-test CPU untuk taskbar, flyout / floating search pill, dan chain sub-flyout.
/// Saat `flyout_has_stalk == false` (mode Pohon Sakura + Zen Search Pill), area di bawah pill
/// 100% bolong (tidak menghasilkan phantom stalk hitbox).
#[allow(clippy::too_many_arguments)]
pub fn cpu_hit_test(
    x: i32,
    y: i32,
    bar_top: i32,
    bar_left: i32,
    bar_right: i32,
    flyout: Option<(i32, i32, i32, i32, i32, i32)>,
    flyout_has_stalk: bool,
    sub1: Option<(i32, i32, i32, i32)>,
    sub2: Option<(i32, i32, i32, i32)>,
) -> bool {
    // 1. Taskbar (lebar bar + margin antialias)
    if y >= (bar_top - 8) && x >= (bar_left - 12) && x <= (bar_right + 12) {
        return true;
    }

    // 2. Main Flyout / Floating Zen Search Pill (+ Stalk/Leher khusus Tray Flyout)
    if let Some((fly_top, fly_bottom, fly_l, fly_r, fly_cx, fly_cy)) = flyout {
        if y >= (fly_top - 8) && y <= (fly_bottom + 8) && x >= (fly_l - 8) && x <= (fly_r + 8) {
            return true;
        }

        if flyout_has_stalk && y > fly_bottom && y < bar_top {
            let stalk_progress = (y - fly_bottom) as f32 / (bar_top - fly_bottom).max(1) as f32;
            let half_width = 38.0 + 35.0 * (stalk_progress - 0.5).powi(2) * 4.0;
            if (x - fly_cx).abs() <= half_width as i32 + 8 {
                return true;
            }
        }

        // 3. Sub-Flyout Slot 1 & Bridge
        if let Some((s1_top, s1_bot, s1_l, s1_r)) = sub1 {
            if y >= (s1_top - 8) && y <= (s1_bot + 8) && x >= (s1_l - 8) && x <= (s1_r + 8) {
                return true;
            }
            let bridge_min_x = s1_l.min(fly_l);
            let bridge_max_x = s1_r.max(fly_r);
            if (y - fly_cy).abs() <= 45 && x >= bridge_min_x && x <= bridge_max_x {
                return true;
            }
        }

        // 4. Sub-Flyout Slot 2 & Bridge (mendukung Left-Chain maupun Split-Wing)
        if let Some((s2_top, s2_bot, s2_l, s2_r)) = sub2 {
            if y >= (s2_top - 8) && y <= (s2_bot + 8) && x >= (s2_l - 8) && x <= (s2_r + 8) {
                return true;
            }
            let (ref_l, ref_r) = if let Some((_, _, s1_l, s1_r)) = sub1 {
                (s1_l.min(fly_l), s1_r.max(fly_r))
            } else {
                (fly_l, fly_r)
            };
            let bridge_min_x = s2_l.min(ref_l);
            let bridge_max_x = s2_r.max(ref_r);
            if (y - fly_cy).abs() <= 45 && x >= bridge_min_x && x <= bridge_max_x {
                return true;
            }
        }
    }

    false
}

/// Evaluasi lock-free terhadap zona hit-test atomik saat ini untuk koordinat layar (x, y).
#[inline]
fn eval_current_hit_test(x: i32, y: i32) -> bool {
    let bar_top = BAR_TOP_Y.load(Ordering::Relaxed);
    let bar_left = BAR_LEFT_X.load(Ordering::Relaxed);
    let bar_right = BAR_RIGHT_X.load(Ordering::Relaxed);

    let fly_top = FLY_TOP_Y.load(Ordering::Relaxed);
    let flyout = if fly_top < i32::MAX - 1000 {
        Some((
            fly_top,
            FLY_BOTTOM_Y.load(Ordering::Relaxed),
            FLY_LEFT_X.load(Ordering::Relaxed),
            FLY_RIGHT_X.load(Ordering::Relaxed),
            FLY_CX.load(Ordering::Relaxed),
            FLY_CY.load(Ordering::Relaxed),
        ))
    } else {
        None
    };
    let flyout_has_stalk = FLY_HAS_STALK.load(Ordering::Relaxed);

    let s1_top = SUB1_TOP_Y.load(Ordering::Relaxed);
    let sub1 = if s1_top < i32::MAX - 1000 {
        Some((
            s1_top,
            SUB1_BOTTOM_Y.load(Ordering::Relaxed),
            SUB1_LEFT_X.load(Ordering::Relaxed),
            SUB1_RIGHT_X.load(Ordering::Relaxed),
        ))
    } else {
        None
    };

    let s2_top = SUB2_TOP_Y.load(Ordering::Relaxed);
    let sub2 = if s2_top < i32::MAX - 1000 {
        Some((
            s2_top,
            SUB2_BOTTOM_Y.load(Ordering::Relaxed),
            SUB2_LEFT_X.load(Ordering::Relaxed),
            SUB2_RIGHT_X.load(Ordering::Relaxed),
        ))
    } else {
        None
    };

    cpu_hit_test(
        x,
        y,
        bar_top,
        bar_left,
        bar_right,
        flyout,
        flyout_has_stalk,
        sub1,
        sub2,
    )
}

/// Sinkronisasi flag `WS_EX_TRANSPARENT` + flush `SWP_FRAMECHANGED` hanya saat status berubah.
/// Mempertahankan `WS_EX_LAYERED` agar click-through menembus ke proses aplikasi lain di belakangnya.
unsafe fn sync_clickthrough_state(hit: bool) {
    let want_clickthrough = !hit;
    let current = IS_CLICKTHROUGH.load(Ordering::Relaxed);
    if want_clickthrough == current {
        return;
    }

    let hwnd_raw = TARGET_HWND.load(Ordering::Relaxed);
    if hwnd_raw == 0 {
        return;
    }

    let hwnd = HWND(hwnd_raw as _);
    unsafe {
        let ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
        let new_ex = if want_clickthrough {
            ex_style | (WS_EX_LAYERED.0 as isize) | (WS_EX_TRANSPARENT.0 as isize)
        } else {
            (ex_style | (WS_EX_LAYERED.0 as isize)) & !(WS_EX_TRANSPARENT.0 as isize)
        };
        let _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, new_ex);
        let _ = SetWindowPos(
            hwnd,
            None,
            0,
            0,
            0,
            0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
        );
    }
    IS_CLICKTHROUGH.store(want_clickthrough, Ordering::Relaxed);
}

/// Hook mouse low-level ultra-ringan: membalik `WS_EX_TRANSPARENT` secara instan saat kursor
/// melintasi batas interaktif (Taskbar / Flyout / Search Pill) sebelum event klik dikirim OS,
/// sehingga menghilangkan race condition 1-frame VSync.
unsafe extern "system" fn mouse_ll_hook_proc(
    ncode: i32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    if ncode >= 0 && lparam.0 != 0 {
        let pt = unsafe { (*(lparam.0 as *const MSLLHOOKSTRUCT)).pt };
        let hit = eval_current_hit_test(pt.x, pt.y);
        unsafe {
            sync_clickthrough_state(hit);
        }
    }
    unsafe { CallNextHookEx(None, ncode, wparam, lparam) }
}

/// Lepas global mouse hook secara bersih saat aplikasi keluar.
pub fn cleanup_hooks() {
    let hook_raw = MOUSE_HOOK.swap(0, Ordering::AcqRel);
    if hook_raw != 0 {
        unsafe {
            let _ = UnhookWindowsHookEx(HHOOK(hook_raw as _));
        }
    }
}

unsafe extern "system" fn sub_wndproc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    if msg == WM_DESTROY {
        cleanup_hooks();
    }

    // 1. Mencegah DWM menggambar non-client area (titlebar, tombol caption close, minimize, maximize)
    if msg == WM_NCCALCSIZE {
        return LRESULT(0);
    }
    if msg == WM_NCPAINT {
        return LRESULT(0);
    }
    if msg == WM_NCACTIVATE {
        return LRESULT(1);
    }

    if msg == WM_KILLFOCUS || msg == WM_ACTIVATEAPP || msg == WM_ACTIVATE {
        let is_deactivating = if msg == WM_ACTIVATE {
            (wparam.0 & 0xFFFF) == 0
        } else if msg == WM_ACTIVATEAPP {
            wparam.0 == 0
        } else {
            true
        };

        if is_deactivating {
            SHOULD_DISMISS_FLYOUT.store(true, Ordering::Relaxed);
        }
    }

    if msg == WM_NCHITTEST {
        let x = (lparam.0 & 0xFFFF) as i16 as i32;
        let y = ((lparam.0 >> 16) & 0xFFFF) as i16 as i32;

        if eval_current_hit_test(x, y) {
            return LRESULT(1); // HTCLIENT
        } else {
            return LRESULT(-1); // HTTRANSPARENT
        }
    }

    let prev = PREV_WNDPROC.load(Ordering::Relaxed);
    if prev != 0 {
        unsafe {
            let prev_fn: WNDPROC = std::mem::transmute(prev);
            CallWindowProcW(prev_fn, hwnd, msg, wparam, lparam)
        }
    } else {
        LRESULT(0)
    }
}

#[allow(clippy::too_many_arguments)]
pub fn update_hittest_zones(
    bar_top: i32,
    bar_left: i32,
    bar_right: i32,
    _window_top_screen: i32,
    _window_width: i32,
    _window_height: i32,
    flyout: Option<(i32, i32, i32, i32, i32, i32)>,
    flyout_has_stalk: bool,
    sub1: Option<(i32, i32, i32, i32)>,
    sub2: Option<(i32, i32, i32, i32)>,
) {
    BAR_TOP_Y.store(bar_top, Ordering::Relaxed);
    BAR_LEFT_X.store(bar_left, Ordering::Relaxed);
    BAR_RIGHT_X.store(bar_right, Ordering::Relaxed);

    if let Some((top, bottom, left, right, cx, cy)) = flyout {
        FLY_TOP_Y.store(top, Ordering::Relaxed);
        FLY_BOTTOM_Y.store(bottom, Ordering::Relaxed);
        FLY_LEFT_X.store(left, Ordering::Relaxed);
        FLY_RIGHT_X.store(right, Ordering::Relaxed);
        FLY_CX.store(cx, Ordering::Relaxed);
        FLY_CY.store(cy, Ordering::Relaxed);
        FLY_HAS_STALK.store(flyout_has_stalk, Ordering::Relaxed);
    } else {
        FLY_TOP_Y.store(i32::MAX, Ordering::Relaxed);
        FLY_BOTTOM_Y.store(i32::MAX, Ordering::Relaxed);
        FLY_LEFT_X.store(0, Ordering::Relaxed);
        FLY_RIGHT_X.store(0, Ordering::Relaxed);
        FLY_CX.store(0, Ordering::Relaxed);
        FLY_CY.store(0, Ordering::Relaxed);
        FLY_HAS_STALK.store(false, Ordering::Relaxed);
    }

    if let Some((top, bottom, left, right)) = sub1 {
        SUB1_TOP_Y.store(top, Ordering::Relaxed);
        SUB1_BOTTOM_Y.store(bottom, Ordering::Relaxed);
        SUB1_LEFT_X.store(left, Ordering::Relaxed);
        SUB1_RIGHT_X.store(right, Ordering::Relaxed);
    } else {
        SUB1_TOP_Y.store(i32::MAX, Ordering::Relaxed);
        SUB1_BOTTOM_Y.store(i32::MAX, Ordering::Relaxed);
        SUB1_LEFT_X.store(0, Ordering::Relaxed);
        SUB1_RIGHT_X.store(0, Ordering::Relaxed);
    }

    if let Some((top, bottom, left, right)) = sub2 {
        SUB2_TOP_Y.store(top, Ordering::Relaxed);
        SUB2_BOTTOM_Y.store(bottom, Ordering::Relaxed);
        SUB2_LEFT_X.store(left, Ordering::Relaxed);
        SUB2_RIGHT_X.store(right, Ordering::Relaxed);
    } else {
        SUB2_TOP_Y.store(i32::MAX, Ordering::Relaxed);
        SUB2_BOTTOM_Y.store(i32::MAX, Ordering::Relaxed);
        SUB2_LEFT_X.store(0, Ordering::Relaxed);
        SUB2_RIGHT_X.store(0, Ordering::Relaxed);
    }

    // Sinkronisasi immediate untuk kasus zona berubah saat kursor sedang diam
    // (mis. Start Menu / Search Pill / Flyout baru saja muncul atau tertutup di bawah kursor).
    unsafe {
        let mut pt = POINT { x: 0, y: 0 };
        if GetCursorPos(&mut pt).is_ok() {
            let hit = cpu_hit_test(
                pt.x,
                pt.y,
                bar_top,
                bar_left,
                bar_right,
                flyout,
                flyout_has_stalk,
                sub1,
                sub2,
            );
            sync_clickthrough_state(hit);
        }
    }
}

/// Enable true per-pixel alpha transparency, toolwindow style, dynamic click-through, and Per-Monitor DPI Awareness V2
pub fn setup_transparent_window(window: &winit::window::Window) {
    unsafe {
        use windows::Win32::UI::HiDpi::{
            SetProcessDpiAwarenessContext, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
        };
        let _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    }
    if let Ok(handle) = window.window_handle() {
        if let RawWindowHandle::Win32(win32_handle) = handle.as_raw() {
            let hwnd = HWND(win32_handle.hwnd.get() as _);
            TARGET_HWND.store(hwnd.0 as usize, Ordering::Relaxed);
            unsafe {
                let style = GetWindowLongPtrW(hwnd, GWL_STYLE);
                let remove_styles = (WS_CAPTION.0
                    | WS_THICKFRAME.0
                    | WS_MINIMIZEBOX.0
                    | WS_MAXIMIZEBOX.0
                    | WS_SYSMENU.0
                    | WS_BORDER.0
                    | WS_DLGFRAME.0) as isize;
                let new_style = (style & !remove_styles) | (WS_POPUP.0 as isize);
                let _ = SetWindowLongPtrW(hwnd, GWL_STYLE, new_style);

                let ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
                let new_ex_style =
                    ex_style | (WS_EX_LAYERED.0 as isize) | (WS_EX_TOOLWINDOW.0 as isize);
                let _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, new_ex_style);

                // Disable DWM non-client rendering policy and rounded corner decorations
                let ncrp = DWMNCRP_DISABLED.0 as i32;
                let _ = DwmSetWindowAttribute(
                    hwnd,
                    DWMWA_NCRENDERING_POLICY,
                    &ncrp as *const _ as _,
                    std::mem::size_of::<i32>() as u32,
                );

                let corner = 1i32; // DWMWCP_DONOTROUND
                let _ = DwmSetWindowAttribute(
                    hwnd,
                    DWMWA_WINDOW_CORNER_PREFERENCE,
                    &corner as *const _ as _,
                    std::mem::size_of::<i32>() as u32,
                );

                let _ = SetWindowPos(
                    hwnd,
                    None,
                    0,
                    0,
                    0,
                    0,
                    SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
                );

                let margins = MARGINS {
                    cxLeftWidth: -1,
                    cxRightWidth: -1,
                    cyTopHeight: -1,
                    cyBottomHeight: -1,
                };
                let _ = DwmExtendFrameIntoClientArea(hwnd, &margins);

                // Pastikan tidak ada region GDI yang memotong kanopi pohon!
                let _ = SetWindowRgn(hwnd, None, true);

                let prev = SetWindowLongPtrW(
                    hwnd,
                    GWLP_WNDPROC,
                    sub_wndproc as *const () as usize as isize,
                );
                if prev != 0 {
                    PREV_WNDPROC.store(prev as usize, Ordering::Relaxed);
                }

                // Pasang low-level mouse hook sekali untuk click-through 0-frame-latency
                if MOUSE_HOOK.load(Ordering::Acquire) == 0 {
                    if let Ok(hook) =
                        SetWindowsHookExW(WH_MOUSE_LL, Some(mouse_ll_hook_proc), None, 0)
                    {
                        MOUSE_HOOK.store(hook.0 as usize, Ordering::Release);
                    }
                }
            }
        }
    }
}
