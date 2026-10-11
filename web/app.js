const invoke = window.__TAURI__.core.invoke;
const status = document.querySelector('#status');
let busy = false;
let error = false;
async function run(action) {
  if (busy) return;
  busy = true;
  error = false;
  document.querySelectorAll('button').forEach((button) => {
    button.disabled = true;
  });
  try {
    await action();
  } catch (failure) {
    error = true;
    status.textContent = String(failure);
  } finally {
    busy = false;
    document.querySelectorAll('button').forEach((button) => {
      button.disabled = false;
    });
  }
}
document.querySelector('#open').onclick = () =>
  run(() => invoke('open_browser'));
for (const [id, command] of [
  ['brave', 'brave'],
  ['capture', 'capture'],
  ['release', 'release'],
  ['quit', 'quit'],
]) {
  document.querySelector(`#${id}`).onclick = () =>
    run(() => invoke('mouse_command', { command }));
}
setInterval(async () => {
  if (busy || error) return;
  try {
    const message = await invoke('session_status');
    if (message) status.textContent = message;
  } catch {
    // Keep the last status while a polling request is unavailable.
  }
}, 600);
run(() => invoke('open_browser'));
