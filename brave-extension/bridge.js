/* global chrome */
async function connectDuoBridge() {
  const query = new URLSearchParams(location.search);
  const port = Number(query.get('bridge'));
  const token = query.get('token');
  if (
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535 ||
    !/^[A-Za-z0-9-]{32,64}$/.test(token ?? '')
  )
    return;
  const socket = new WebSocket(`ws://127.0.0.1:${port}/${token}/extension`);
  const status = (text) => {
    document.querySelector('#status').textContent = text;
    document.title = text;
  };
  status('Conectando ao Duo…');
  socket.onerror = () => status('Falha ao conectar WebSocket local do Duo');
  let target;
  let timer;
  let capturing = false;
  const send = (message) => {
    if (socket.readyState === WebSocket.OPEN)
      socket.send(JSON.stringify(message));
  };
  const command = (method, params = {}) =>
    chrome.debugger.sendCommand(target, method, params);
  socket.onopen = () => status('Conectado ao Duo; aguardando aba');
  let sequence = Promise.resolve();
  socket.onmessage = (event) => {
    sequence = sequence.then(async () => {
      try {
        const message = JSON.parse(event.data);
        if (message.kind === 'init' && !target) {
          const tab = await chrome.tabs.create({
            url: message.url,
            active: false,
          });
          target = { tabId: tab.id };
          await chrome.debugger.attach(target, '1.3');
          await command('Page.enable');
          await command('Emulation.setDeviceMetricsOverride', {
            width: message.width,
            height: message.height,
            deviceScaleFactor: 1,
            mobile: false,
          });
          timer = setInterval(capture, 200);
          status('Brave conectado ao Duo');
          return;
        }
        if (target) await dispatchDuoInput(message, command);
      } catch (error) {
        status(`Brave: ${error.message}`);
        send({ kind: 'error', message: error.message });
      }
    });
  };
  async function capture() {
    if (capturing) return;
    capturing = true;
    try {
      const frame = await command('Page.captureScreenshot', {
        format: 'jpeg',
        quality: 65,
      });
      send({ kind: 'frame', image: frame.data });
    } catch (error) {
      send({ kind: 'error', message: error.message });
    } finally {
      capturing = false;
    }
  }
  socket.onclose = async () => {
    clearInterval(timer);
    document.querySelector('#status').textContent =
      'Duo desconectado. Pode fechar esta janela.';
    if (target) {
      await chrome.debugger.detach(target).catch(() => {});
      await chrome.tabs.remove(target.tabId).catch(() => {});
    }
  };
}

async function dispatchDuoInput(message, command) {
  const { kind, x, y, key } = message;
  if (kind === 'move')
    return command('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  if (kind === 'scroll')
    return command('Input.dispatchMouseEvent', {
      type: 'mouseWheel',
      x,
      y,
      deltaX: 0,
      deltaY: -Number(key) * 48,
    });
  if (kind === 'click') {
    for (const type of ['mousePressed', 'mouseReleased'])
      await command('Input.dispatchMouseEvent', {
        type,
        x,
        y,
        button: 'left',
        clickCount: 1,
      });
  }
  if (kind === 'key') {
    if (!['Enter', 'Backspace'].includes(key))
      return command('Input.insertText', { text: String(key) });
    for (const type of ['keyDown', 'keyUp'])
      await command('Input.dispatchKeyEvent', {
        type,
        key,
        code: key,
        windowsVirtualKeyCode: key === 'Enter' ? 13 : 8,
      });
  }
  if (kind === 'navigate' && /^https?:\/\//.test(key))
    return command('Page.navigate', { url: key });
  if (kind === 'reload') return command('Page.reload');
  if (kind === 'back') {
    const history = await command('Page.getNavigationHistory');
    const previous = history.entries[history.currentIndex - 1];
    if (previous)
      return command('Page.navigateToHistoryEntry', { entryId: previous.id });
  }
}

if (typeof module !== 'undefined') module.exports = { dispatchDuoInput };
if (
  typeof location !== 'undefined' &&
  new URLSearchParams(location.search).has('bridge')
)
  connectDuoBridge();
