const { test } = require('node:test');
const assert = require('node:assert/strict');
const { WebSocket } = require('ws');
const { startBridge } = require('../native/brave-bridge.cjs');

test('bridge announces readiness when the extension connects before the native client', async () => {
  const bridge = await startBridge({
    token: 'fixture-secret',
    extensionId: 'fixture',
    port: 0,
  });
  const url = `ws://127.0.0.1:${bridge.port}`;
  const extension = new WebSocket(`${url}/fixture-secret/extension`, {
    origin: 'chrome-extension://fixture',
  });
  let native;
  try {
    await new Promise((resolve) => extension.once('open', resolve));
    native = new WebSocket(`${url}/fixture-secret/native`);
    const ready = await new Promise((resolve) =>
      native.once('message', (message) => resolve(JSON.parse(message))),
    );
    assert.deepEqual(ready, { kind: 'ready' });
  } finally {
    native?.terminate();
    extension.terminate();
    await bridge.close();
  }
});

test('bridge rejects wrong token and relays only between authenticated peers', async () => {
  const bridge = await startBridge({
    token: 'fixture-secret',
    extensionId: 'fixture',
    port: 0,
  });
  const url = `ws://127.0.0.1:${bridge.port}`;
  const native = new WebSocket(`${url}/fixture-secret/native`);
  const extension = new WebSocket(`${url}/fixture-secret/extension`, {
    origin: 'chrome-extension://fixture',
  });
  try {
    await Promise.all(
      [native, extension].map(
        (socket) => new Promise((resolve) => socket.once('open', resolve)),
      ),
    );
    const received = new Promise((resolve) =>
      extension.once('message', (message) => resolve(JSON.parse(message))),
    );
    native.send(JSON.stringify({ kind: 'click', x: 10, y: 20 }));
    assert.deepEqual(await received, { kind: 'click', x: 10, y: 20 });
    const refused = new WebSocket(`${url}/wrong/native`);
    await new Promise((resolve) => refused.once('error', resolve));
    assert.notEqual(refused.readyState, WebSocket.OPEN);
  } finally {
    native.terminate();
    extension.terminate();
    await bridge.close();
  }
});

test('bridge rejects connections from websites even with the token', async () => {
  const bridge = await startBridge({
    token: 'fixture-secret',
    extensionId: 'fixture',
    port: 0,
  });
  try {
    const socket = new WebSocket(
      `ws://127.0.0.1:${bridge.port}/fixture-secret/extension`,
      { origin: 'https://example.com' },
    );
    await new Promise((resolve) => socket.once('error', resolve));
    assert.notEqual(socket.readyState, WebSocket.OPEN);
  } finally {
    await bridge.close();
  }
});
