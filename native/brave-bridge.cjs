const http = require('node:http');
const { WebSocketServer, WebSocket } = require('ws');

async function startBridge({ token, extensionId, port = 0 }) {
  const server = http.createServer((_, response) =>
    response.writeHead(404).end(),
  );
  const websocket = new WebSocketServer({
    noServer: true,
    maxPayload: 2 * 1024 * 1024,
  });
  const peers = new Map();
  server.on('upgrade', (request, socket, head) => {
    const role = request.url?.split('/')[2];
    const expectedOrigin =
      role === 'extension' ? `chrome-extension://${extensionId}` : undefined;
    if (
      !['native', 'extension'].includes(role) ||
      request.url !== `/${token}/${role}` ||
      request.headers.origin !== expectedOrigin ||
      peers.has(role)
    ) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');
      return;
    }
    websocket.handleUpgrade(request, socket, head, (peer) =>
      connectPeer(peer, role, peers),
    );
  });
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
  return {
    port: server.address().port,
    close: () =>
      new Promise((resolve) => {
        for (const peer of peers.values()) peer.terminate();
        websocket.close();
        server.close(resolve);
      }),
  };
}

function connectPeer(peer, role, peers) {
  peers.set(role, peer);
  if (peers.size === 2)
    peers.get('native').send(JSON.stringify({ kind: 'ready' }));
  peer.on('message', (message) => {
    const destination = peers.get(role === 'native' ? 'extension' : 'native');
    if (
      destination?.readyState === WebSocket.OPEN &&
      destination.bufferedAmount < 2 * 1024 * 1024
    )
      destination.send(message.toString());
  });
  peer.on('close', () => {
    peers.delete(role);
    const other = peers.get(role === 'native' ? 'extension' : 'native');
    other?.close();
  });
  peer.on('error', () => peer.close());
}

module.exports = { startBridge };
if (require.main === module) {
  startBridge({
    token: process.env.DUO_BRIDGE_TOKEN,
    extensionId: process.env.DUO_BRAVE_EXTENSION_ID,
  })
    .then((bridge) => console.log(JSON.stringify({ port: bridge.port })))
    .catch((error) => {
      console.error(error.message);
      process.exit(1);
    });
  process.stdin.resume();
  process.stdin.on('end', () => process.exit(0));
}
