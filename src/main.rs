mod app;
mod config;
mod flyout;
mod platform;
mod render;

use winit::event_loop::{ControlFlow, EventLoop};

fn main() {
    let diagnose_mode = std::env::args().any(|a| a == "--diagnose");

    println!("Lunula Bar - Modular Kanagawa Wave Taskbar & Chain Flyout Engine");
    if diagnose_mode {
        println!("[DIAGNOSTIC MODE AKTIF]");
    } else {
        println!("Tekan [1/2/3] ganti tema flyout, [R] reload YAML, [ESC] tutup/keluar.");
    }

    let event_loop = EventLoop::new().expect("Failed to create event loop");
    event_loop.set_control_flow(ControlFlow::Poll);

    let mut application = app::App::new(diagnose_mode);
    let _ = event_loop.run_app(&mut application);
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_shader_compilation() {
        let module = wgpu::naga::front::wgsl::parse_str(crate::render::glob::COMBINED_WGSL);
        match module {
            Ok(m) => {
                let mut validator = wgpu::naga::valid::Validator::new(
                    wgpu::naga::valid::ValidationFlags::all(),
                    wgpu::naga::valid::Capabilities::all(),
                );
                let res = validator.validate(&m);
                assert!(res.is_ok(), "WGSL validation failed: {:?}", res.err());
            }
            Err(e) => panic!("WGSL parsing failed: {:?}", e),
        }
    }
}
