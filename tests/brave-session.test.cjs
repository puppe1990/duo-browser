const { test } = require('node:test');
const assert = require('node:assert/strict');
const { BraveSession } = require('../brave-extension/debugger-session.js');

function debuggerAPI() {
  const listeners = new Set();
  const calls = [];
  return {
    calls,
    onDetach: {
      addListener: (listener) => listeners.add(listener),
      removeListener: (listener) => listeners.delete(listener),
    },
    emitDetach: (id, reason) =>
      listeners.forEach((listener) => listener({ tabId: id }, reason)),
    attach: async () => calls.push('attach'),
    detach: async () => calls.push('detach'),
    sendCommand: async () => calls.push('command'),
  };
}

test('detaching the controlled Brave tab disables input without silently reattaching', async () => {
  const api = debuggerAPI();
  const reasons = [];
  const session = new BraveSession(api, 42, (reason) => reasons.push(reason));
  await session.attach();
  api.emitDetach(99, 'canceled_by_user');
  assert.equal(session.attached, true);
  api.emitDetach(42, 'canceled_by_user');
  assert.equal(session.attached, false);
  await assert.rejects(
    session.command('Input.dispatchMouseEvent', {}),
    /desconectado/,
  );
  assert.deepEqual(api.calls, ['attach']);
  assert.deepEqual(reasons, ['canceled_by_user']);
  await session.close();
});

test('explicit reconnect restores the same tab and cleanup removes the detach listener', async () => {
  const api = debuggerAPI();
  const reasons = [];
  const session = new BraveSession(api, 42, (reason) => reasons.push(reason));
  await session.attach();
  api.emitDetach(42, 'canceled_by_user');
  await session.attach();
  await session.command('Input.dispatchMouseEvent', {});
  assert.equal(session.attached, true);
  assert.deepEqual(api.calls, ['attach', 'attach', 'command']);
  await session.close();
  api.emitDetach(42, 'target_closed');
  assert.deepEqual(reasons, ['canceled_by_user']);
});

test('a lost debugger command releases the session even if the detach event was missed', async () => {
  const api = debuggerAPI();
  const reasons = [];
  api.sendCommand = async () => {
    throw new Error('Debugger is not attached to the tab with id: 42.');
  };
  const session = new BraveSession(api, 42, (reason) => reasons.push(reason));
  await session.attach();
  await assert.rejects(
    session.command('Input.dispatchMouseEvent'),
    /not attached/,
  );
  assert.equal(session.attached, false);
  assert.deepEqual(reasons, ['connection_lost']);
  await session.close();
});
