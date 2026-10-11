const { test } = require('node:test');
const assert = require('node:assert/strict');
const { testBraveInput } = require('../brave-extension/protocol.js');

function debuggerFixture(verified) {
  const calls = [];
  return {
    calls,
    attach: async (target) => calls.push(['attach', target]),
    detach: async (target) => calls.push(['detach', target]),
    sendCommand: async (target, command, params) => {
      calls.push([command, target, params]);
      return {
        result: { value: calls.length === 2 ? { x: 10, y: 20 } : verified },
      };
    },
  };
}

test('Brave probe targets only its own tab and detaches after verification', async () => {
  const api = debuggerFixture(true);
  await testBraveInput(api, 42);
  assert.ok(api.calls.every(([, target]) => target.tabId === 42));
  assert.deepEqual(
    api.calls
      .filter(([command]) => command === 'Input.dispatchMouseEvent')
      .map(([, , params]) => params.type),
    ['mousePressed', 'mouseReleased'],
  );
  assert.equal(api.calls.at(-1)[0], 'detach');
});

test('Brave probe rejects failed verification and always releases debugger', async () => {
  const api = debuggerFixture(false);
  await assert.rejects(testBraveInput(api, 42), /não confirmado/);
  assert.equal(api.calls.at(-1)[0], 'detach');
});
