const { test } = require('node:test');
const assert = require('node:assert/strict');
const { dispatchDuoInput } = require('../brave-extension/bridge.js');

test('Brave input produces ordered mouse press/release and real text input', async () => {
  const calls = [];
  const command = async (name, params) => calls.push([name, params]);
  await dispatchDuoInput({ kind: 'click', x: 20, y: 30 }, command);
  await dispatchDuoInput({ kind: 'key', key: 'ç' }, command);
  assert.deepEqual(
    calls.map(([, params]) => params.type || params.text),
    ['mousePressed', 'mouseReleased', 'ç'],
  );
  assert.equal(calls[0][1].x, 20);
  assert.equal(calls[0][1].y, 30);
});

test('Brave special keys use key events and navigation rejects unsupported schemes', async () => {
  const calls = [];
  const command = async (name, params) => calls.push([name, params]);
  await dispatchDuoInput({ kind: 'key', key: 'Backspace' }, command);
  await dispatchDuoInput(
    { kind: 'navigate', key: 'javascript:alert(1)' },
    command,
  );
  assert.equal(calls.length, 2);
  assert.deepEqual(
    calls.map(([, params]) => params.type),
    ['keyDown', 'keyUp'],
  );
  assert.ok(calls.every(([name]) => name === 'Input.dispatchKeyEvent'));
});
