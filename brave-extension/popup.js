/* global chrome, testBraveInput */
const testButton = document.querySelector('#test');
const testStatus = document.querySelector('#status');
testButton.onclick = async () => {
  testButton.disabled = true;
  try {
    const tab = await chrome.tabs.create({
      url: chrome.runtime.getURL('fixture.html'),
      active: false,
    });
    await waitForPage(tab.id);
    await testBraveInput(chrome.debugger, tab.id);
    testStatus.textContent =
      'Passou: clique real e digitação em aba de segundo plano. A integração com o Duo ainda está pendente.';
  } catch (error) {
    testStatus.textContent = `Teste falhou: ${error.message}. Confira a aba criada e tente novamente.`;
  } finally {
    testButton.disabled = false;
    document.title = testStatus.textContent;
  }
};

async function waitForPage(tabId) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const tab = await chrome.tabs.get(tabId);
    if (tab.status === 'complete') return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('A aba de teste não carregou em 5 segundos');
}

if (new URLSearchParams(location.search).get('run') === '1') testButton.click();
