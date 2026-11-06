import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { resolve } from 'node:path';

test('production host rejects a local caller even with the correct extension origin', async () => {
  const child = spawn(resolve('build/windows_host/revisit_desktop_host.exe'),
    ['chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/'], { windowsHide: true });
  let output = '';
  child.stdout.on('data', chunk => output += chunk);
  child.stdin.on('error', () => {});
  child.stdin.end(Buffer.from([2, 0, 0, 0, 123, 125]));
  const [code] = await once(child, 'close');
  assert.equal(code, 4, 'Chrome stdio ownership must be checked before accepting input');
  assert.equal(output, '', 'No forged arrival acknowledgement');
});
