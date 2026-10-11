async function testBraveInput(debuggerAPI, tabId) {
  const target = { tabId };
  await debuggerAPI.attach(target, '1.3');
  try {
    const evaluation = await debuggerAPI.sendCommand(
      target,
      'Runtime.evaluate',
      {
        expression: `(() => {
        const rect = document.querySelector('#fixture').getBoundingClientRect();
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
      })()`,
        returnByValue: true,
      },
    );
    const point = evaluation.result.value;
    for (const type of ['mousePressed', 'mouseReleased']) {
      await debuggerAPI.sendCommand(target, 'Input.dispatchMouseEvent', {
        type,
        ...point,
        button: 'left',
        clickCount: 1,
      });
    }
    await debuggerAPI.sendCommand(target, 'Input.insertText', {
      text: 'Duo Brave',
    });
    const verification = await debuggerAPI.sendCommand(
      target,
      'Runtime.evaluate',
      {
        expression: `document.querySelector('#fixture').value === 'Duo Brave'
        && document.body.dataset.trustedClick === 'true'`,
        returnByValue: true,
      },
    );
    if (verification.result.value !== true)
      throw new Error('Clique ou digitação não confirmado na aba de teste.');
  } finally {
    await debuggerAPI.detach(target);
  }
}

if (typeof module !== 'undefined') module.exports = { testBraveInput };
