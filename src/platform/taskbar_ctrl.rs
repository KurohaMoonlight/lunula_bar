use windows::core::w;
use windows::Win32::UI::WindowsAndMessaging::{FindWindowW, ShowWindow, SW_HIDE, SW_SHOW};

/// Menyembunyikan taskbar bawaan Windows (`Shell_TrayWnd`)
#[allow(dead_code)]
pub fn hide_windows_taskbar() {
    unsafe {
        if let Ok(hwnd) = FindWindowW(w!("Shell_TrayWnd"), None) {
            let _ = ShowWindow(hwnd, SW_HIDE);
        }
        
        // Secondary taskbars on multi-monitor setups
        if let Ok(secondary) = FindWindowW(w!("Shell_SecondaryTrayWnd"), None) {
            let _ = ShowWindow(secondary, SW_HIDE);
        }
    }
}

/// Menampilkan kembali taskbar bawaan Windows (untuk safety / cleanup saat exit)
#[allow(dead_code)]
pub fn restore_windows_taskbar() {
    unsafe {
        if let Ok(hwnd) = FindWindowW(w!("Shell_TrayWnd"), None) {
            let _ = ShowWindow(hwnd, SW_SHOW);
        }
        if let Ok(secondary) = FindWindowW(w!("Shell_SecondaryTrayWnd"), None) {
            let _ = ShowWindow(secondary, SW_SHOW);
        }
    }
}
