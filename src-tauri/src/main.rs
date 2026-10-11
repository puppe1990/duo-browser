#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use tauri::Manager;

#[derive(Default)]
struct NativeSession {
    child: Mutex<Option<Child>>,
    status: Arc<Mutex<String>>,
}

#[tauri::command]
fn open_browser(app: tauri::AppHandle, session: tauri::State<NativeSession>) -> Result<(), String> {
    let mut child_slot = session.child.lock().map_err(|e| e.to_string())?;
    if let Some(child) = child_slot.as_mut() {
        if child.try_wait().map_err(|e| e.to_string())?.is_none() {
            let stdin = child
                .stdin
                .as_mut()
                .ok_or("Entrada do helper indisponível")?;
            writeln!(stdin, "capture").map_err(|e| e.to_string())?;
            return Ok(());
        }
    }
    let root = app.path().resource_dir().map_err(|e| e.to_string())?;
    let binary = root.join("DuoNative.app/Contents/MacOS/DuoNative");
    let mut child = Command::new(&binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Não foi possível abrir {}: {e}", binary.display()))?;
    if let Some(stdin) = child.stdin.as_mut() {
        if let Err(failure) = writeln!(stdin, "capture") {
            let _ = child.kill();
            let _ = child.wait();
            return Err(format!("Falha ao iniciar captura automática: {failure}"));
        }
    }
    let stdout = child.stdout.take().ok_or("Saída do helper indisponível")?;
    let status = Arc::clone(&session.status);
    std::thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            if let Ok(message) = serde_json::from_str::<serde_json::Value>(&line) {
                if let Some(text) = message["status"].as_str() {
                    if let Ok(mut status) = status.lock() {
                        *status = text.to_owned();
                    }
                }
            }
        }
    });
    *child_slot = Some(child);
    Ok(())
}

#[tauri::command]
fn mouse_command(command: String, session: tauri::State<NativeSession>) -> Result<(), String> {
    if !["capture", "release", "quit"].contains(&command.as_str()) {
        return Err(format!(
            "Comando recebido: {command}; esperado capture, release ou quit."
        ));
    }
    let mut child_slot = session.child.lock().map_err(|e| e.to_string())?;
    let child = child_slot
        .as_mut()
        .ok_or("Abra o navegador antes de controlar o mouse.")?;
    if child.try_wait().map_err(|e| e.to_string())?.is_some() {
        return Err("Navegador fechado. Abra novamente antes de capturar o mouse.".into());
    }
    let stdin = child
        .stdin
        .as_mut()
        .ok_or("Entrada do helper indisponível")?;
    writeln!(stdin, "{command}").map_err(|e| e.to_string())
}

#[tauri::command]
fn session_status(session: tauri::State<NativeSession>) -> Result<String, String> {
    session
        .status
        .lock()
        .map(|status| status.clone())
        .map_err(|e| e.to_string())
}

fn main() {
    let app = tauri::Builder::default()
        .manage(NativeSession::default())
        .invoke_handler(tauri::generate_handler![
            open_browser,
            mouse_command,
            session_status
        ])
        .build(tauri::generate_context!())
        .expect("Falha ao iniciar Duo Browser");
    app.run(|app, event| {
        if matches!(event, tauri::RunEvent::Exit) {
            if let Ok(mut slot) = app.state::<NativeSession>().child.lock() {
                if let Some(mut child) = slot.take() {
                    if let Some(input) = child.stdin.as_mut() {
                        let _ = writeln!(input, "quit");
                    }
                    let _ = child.kill();
                    let _ = child.wait();
                }
            }
        }
    });
}
