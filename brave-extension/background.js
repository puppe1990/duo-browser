/* global chrome, connectDuoBridge, importScripts */
importScripts('debugger-session.js', 'input-queue.js', 'bridge.js');

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || message.type !== 'duo-connect')
    return false;
  connectDuoBridge(message).then(
    () => respond({ connected: true }),
    (error) => respond({ error: error.message }),
  );
  return true;
});
