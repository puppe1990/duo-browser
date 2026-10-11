const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('compiler wrapper supports the selected SDK and host architecture', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'duo-compiler-'));
  try {
    fs.writeFileSync(
      path.join(root, 'xcrun'),
      '#!/bin/sh\necho /selected/SDK\n',
      { mode: 0o755 },
    );
    fs.writeFileSync(path.join(root, 'uname'), '#!/bin/sh\necho x86_64\n', {
      mode: 0o755,
    });
    fs.writeFileSync(
      path.join(root, 'swiftc'),
      '#!/bin/sh\nprintf "%s\\n" "$@"\n',
      { mode: 0o755 },
    );
    const output = execFileSync(
      'bash',
      ['scripts/swift-compile.sh', 'fixture.swift'],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          DUO_USE_SYSTEM_SDK: '1',
          PATH: `${root}:${process.env.PATH}`,
        },
      },
    );
    assert.match(output, /-sdk\n\/selected\/SDK/);
    assert.match(output, /-target\nx86_64-apple-macos14.0/);
    assert.match(output, /fixture.swift/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
