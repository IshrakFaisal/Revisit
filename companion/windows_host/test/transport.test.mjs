// SYNTHETIC automated transport regression tests. These do not prove browser detection.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { resolve } from 'node:path';

const origin = 'chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/';
const hostPath = resolve('build/windows_host/revisit_host.exe');
const receiverPath = resolve('build/windows_host/revisit_receiver.exe');
const frame = value => {
  const payload = Buffer.from(JSON.stringify(value));
  const header = Buffer.alloc(4);
  header.writeUInt32LE(payload.length);
  return Buffer.concat([header, payload]);
};
async function send(payload, caller = origin) {
  const child = spawn(hostPath, [caller], { windowsHide: true });
  const chunks = [];
  child.stdout.on('data', b => chunks.push(b));
  child.stdin.on('error', () => {});
  child.stdin.end(payload);
  const [code] = await once(child, 'close');
  const output = Buffer.concat(chunks);
  if (!output.length) return { code, reply: null };
  assert.equal(output.readUInt32LE(0), output.length - 4);
  return { code, reply: JSON.parse(output.subarray(4).toString()) };
}
test('SYNTHETIC native framing, origin, private pipe, replay and disconnect', { timeout: 20000 }, async () => {
  const receiver = spawn(receiverPath, ['--seconds', '15'], { windowsHide: true });
  let log = '';
  let error = '';
  receiver.stdout.setEncoding('utf8');
  receiver.stderr.on('data', b => { error += b; });
  const ready = new Promise((resolveReady, reject) => {
    receiver.stdout.on('data', b => { log += b; if (log.includes('listening')) resolveReady(); });
    receiver.on('error', reject);
    receiver.on('exit', code => reject(new Error(`Receiver exited ${code}: ${error}`)));
  });
  const watchdog = setTimeout(() => receiver.kill(), 16000);
  try {
    await ready;
    const event = { version: 1, target: 'github', eventId: randomUUID(), visitId: randomUUID(), occurredAt: Date.now() };
    assert.deepEqual(await send(frame(event)), { code: 0, reply: { status: 'accepted' } });
    assert.equal((await send(frame(event))).reply.status, 'duplicate');
    assert.equal((await send(frame({ ...event, eventId: randomUUID() }))).reply.status, 'duplicate');
    assert.equal((await send(frame({ ...event, occurredAt: 0 }))).reply.status, 'invalid_event');
    assert.equal((await send(frame({ ...event, target: 'evil' }))).reply.status, 'invalid_event');
    assert.equal((await send(frame(event), 'chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/')).code, 2);
    const oversized = Buffer.alloc(4); oversized.writeUInt32LE(4097);
    assert.equal((await send(oversized)).reply.status, 'invalid_event');
    assert.equal((await send(Buffer.from([1, 0]))).reply.status, 'invalid_event');
    assert.equal(log.split('\n').filter(line => line.includes('receivedAt')).length, 1);
    assert.ok(!log.includes('https://'));
  } finally {
    clearTimeout(watchdog);
    const closed = once(receiver, 'close');
    receiver.kill();
    await closed;
  }
  const event = { version: 1, target: 'x', eventId: randomUUID(), visitId: randomUUID(), occurredAt: Date.now() };
  assert.equal((await send(frame(event))).reply.status, 'receiver_unavailable');
});
