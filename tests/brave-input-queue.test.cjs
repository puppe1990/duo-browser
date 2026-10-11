const { test } = require('node:test');
const assert = require('node:assert/strict');
const { BraveInputQueue } = require('../brave-extension/input-queue.js');

test('clicks bypass accumulated mouse movement and keep their own coordinates', async () => {
  const calls = [];
  let release;
  const held = new Promise((resolve) => {
    release = resolve;
  });
  const queue = new BraveInputQueue(async (message) => {
    calls.push(message);
    if (calls.length === 1) await held;
  });
  queue.push({ kind: 'move', x: 0, y: 0 });
  for (let index = 1; index < 100; index += 1)
    queue.push({ kind: 'move', x: index, y: index });
  queue.push({ kind: 'click', x: 200, y: 300 });
  queue.push({ kind: 'key', key: 'd' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(
    calls.map((message) => message.kind),
    ['move', 'click', 'key'],
  );
  assert.deepEqual(calls[1], { kind: 'click', x: 200, y: 300 });
  release();
});

test('only the latest pending mouse move is dispatched', async () => {
  const calls = [];
  let release;
  const held = new Promise((resolve) => {
    release = resolve;
  });
  const queue = new BraveInputQueue(async (message) => {
    calls.push(message.x);
    if (calls.length === 1) await held;
  });
  queue.push({ kind: 'move', x: 0 });
  for (let index = 1; index < 100; index += 1)
    queue.push({ kind: 'move', x: index });
  release();
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(calls, [0, 99]);
});
