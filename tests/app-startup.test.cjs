const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('control opens browser and starts separation automatically on launch', async () => {
  const calls = [];
  const buttons = new Map();
  const status = { textContent: '' };
  const context = {
    window: {
      __TAURI__: {
        core: {
          invoke: async (name) => {
            calls.push(name);
          },
        },
      },
    },
    document: {
      querySelector: (selector) => {
        if (selector === '#status') return status;
        if (!buttons.has(selector)) buttons.set(selector, {});
        return buttons.get(selector);
      },
      querySelectorAll: () => [...buttons.values()],
    },
    setInterval() {},
  };
  vm.runInNewContext(fs.readFileSync('web/app.js', 'utf8'), context);
  await Promise.resolve();
  assert.deepEqual(calls, ['open_browser']);
});
