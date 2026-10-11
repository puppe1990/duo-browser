async function testBraveInput(debuggerAPI, tabId) {
  const target = { tabId };
  await debuggerAPI.attach(target, '1.3');
  try {
    await verifyFixtureInput((method, params) =>
      debuggerAPI.sendCommand(target, method, params),
    );
  } finally {
    await debuggerAPI.detach(target);
  }
}

async function verifyFixtureInput(command) {
  const evaluation = await command('Runtime.evaluate', {
    expression: `(() => {
      const field = document.querySelector('#fixture');
      field.value = '';
      document.body.dataset.trustedClick = 'false';
      const rect = field.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    })()`,
    returnByValue: true,
  });
  for (const type of ['mousePressed', 'mouseReleased']) {
    await command('Input.dispatchMouseEvent', {
      type,
      ...evaluation.result.value,
      button: 'left',
      clickCount: 1,
    });
  }
  await command('Input.insertText', { text: 'Duo Brave' });
  const verification = await command('Runtime.evaluate', {
    expression: `document.querySelector('#fixture').value === 'Duo Brave' && document.body.dataset.trustedClick === 'true'`,
    returnByValue: true,
  });
  if (verification.result.value !== true)
    throw new Error('Clique ou digitação não confirmado na aba de teste.');
}

async function testBraveReconnect(debuggerAPI, tabId, Session) {
  const session = new Session(debuggerAPI, tabId, () => {});
  try {
    await session.attach();
    await debuggerAPI.detach({ tabId });
    try {
      await session.command('Runtime.evaluate', { expression: '1' });
    } catch {
      /* Expected: reproduce a lost debugger without using a user page. */
    }
    if (session.attached)
      throw new Error('A desconexão do Brave não foi detectada');
    await session.attach();
    await verifyFixtureInput((method, params) =>
      session.command(method, params),
    );
  } finally {
    await session.close();
  }
}

if (typeof module !== 'undefined')
  module.exports = { testBraveInput, testBraveReconnect };
