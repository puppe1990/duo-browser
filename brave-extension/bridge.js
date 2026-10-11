/* global chrome, BraveSession, BraveInputQueue */
async function connectDuoBridge(configuration) {
  const port = Number(configuration.bridge);
  const token = configuration.token;
  if (
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535 ||
    !/^[A-Za-z0-9-]{32,64}$/.test(token ?? '')
  )
    return;
  const socket = new WebSocket(`ws://127.0.0.1:${port}/${token}/extension`);
  const status = (text) => {
    if (typeof document !== 'undefined') {
      document.querySelector('#status').textContent = text;
      document.title = text;
    }
  };
  status('Conectando ao Duo…');
  socket.onerror = () => status('Falha ao conectar WebSocket local do Duo');
  let target;
  let session;
  let dimensions;
  let timer;
  let capturing = false;
  const send = (message) => {
    if (socket.readyState === WebSocket.OPEN)
      socket.send(JSON.stringify(message));
  };
  const command = (method, params = {}) => session.command(method, params);
  const detached = (reason, message = '') => {
    clearInterval(timer);
    status('Brave desconectado; clique “Usar / reativar meu Brave” no Duo');
    send({ kind: 'detached', reason, message });
  };
  async function activate() {
    await session.attach();
    await command('Page.enable');
    await command('Emulation.setDeviceMetricsOverride', dimensions);
    await command('Emulation.setFocusEmulationEnabled', { enabled: true });
    clearInterval(timer);
    timer = setInterval(capture, 200);
    status('Brave conectado ao Duo');
    send({ kind: 'connected' });
  }
  socket.onopen = () => status('Conectado ao Duo; aguardando aba');
  const inputQueue = new BraveInputQueue(async (message) => {
    try {
      if (message.kind === 'init' && !target) {
        const window = await chrome.windows.create({
          url: message.url,
          focused: false,
          ...message.windowBounds,
        });
        const tab = window.tabs[0];
        target = { tabId: tab.id };
        session = new BraveSession(chrome.debugger, tab.id, detached);
        dimensions = {
          width: message.width,
          height: message.height,
          deviceScaleFactor: 1,
          mobile: false,
        };
        await activate();
        return;
      }
      if (message.kind === 'reconnect' && session) {
        await activate();
        return;
      }
      if (message.kind === 'fixtureProof' && session?.attached) {
        const proof = await command('Runtime.evaluate', {
          expression: `location.protocol === 'chrome-extension:' && location.pathname === '/fixture.html'
              && document.body.dataset.trustedClick === 'true' && document.querySelector('#fixture').value === 'duo'`,
          returnByValue: true,
        });
        send({ kind: 'fixtureProof', passed: proof.result.value === true });
        return;
      }
      if (message.kind === 'youtubeProof' && session?.attached) {
        const proof = await command('Runtime.evaluate', {
          expression: `location.hostname === 'www.youtube.com' && document.activeElement.tagName === 'INPUT'
              && document.activeElement.value === 'duo'`,
          returnByValue: true,
        });
        send({ kind: 'youtubeProof', passed: proof.result.value === true });
        return;
      }
      if (target && session.attached) {
        await dispatchDuoInput(message, command);
        if (message.kind === 'click') send({ kind: 'inputAck' });
      }
    } catch (error) {
      if (session?.attached) {
        status(`Brave: ${error.message}`);
        send({ kind: 'error', message: error.message });
      } else detached('attach_failed', error.message);
    }
  });
  socket.onmessage = (event) => inputQueue.push(JSON.parse(event.data));
  async function capture() {
    if (capturing || !session?.attached) return;
    capturing = true;
    try {
      const frame = await command('Page.captureScreenshot', {
        format: 'jpeg',
        quality: 65,
      });
      if (session.attached) send({ kind: 'frame', image: frame.data });
    } catch (error) {
      if (session?.attached) send({ kind: 'error', message: error.message });
    } finally {
      capturing = false;
    }
  }
  socket.onclose = async () => {
    clearInterval(timer);
    status('Duo desconectado');
    if (target) {
      await session?.close();
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

if (typeof module !== 'undefined')
  module.exports = { dispatchDuoInput, connectDuoBridge };
async function bootstrapDuo() {
  const configuration = Object.fromEntries(
    new URLSearchParams(location.search),
  );
  if (configuration.reload === '1') {
    chrome.runtime.reload();
    return;
  }
  if (!configuration.bridge) return;
  try {
    const tab = await chrome.tabs.getCurrent();
    const response = await chrome.runtime.sendMessage({
      ...configuration,
      type: 'duo-connect',
    });
    if (response.error) throw new Error(response.error);
    await chrome.tabs.remove(tab.id);
  } catch (error) {
    document.querySelector('#status').textContent =
      `Falha ao iniciar Duo: ${error.message}`;
  }
}

if (typeof document !== 'undefined' && typeof location !== 'undefined')
  bootstrapDuo();
