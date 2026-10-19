import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DEFAULT_RUN_LIMITS, parallelReadOnlyError, resolveRunLimits, runJsonAgentProcess } from './runner.ts';

const agents = [
  { name: 'scout', tools: ['read', 'grep', 'find', 'ls'] },
  { name: 'shaman', tools: ['read', 'grep', 'find', 'ls'] },
  { name: 'grunt', tools: ['read', 'bash', 'edit', 'write'] },
  { name: 'unrestricted' },
];
const tasks = (...names) => names.map(agent => ({ agent }));
const run = (script, limits, signal) => {
  const events = [];
  return runJsonAgentProcess(process.execPath, ['-e', script], process.cwd(), signal, limits, event => events.push(event))
    .then(outcome => ({ ...outcome, events }));
};
const limits = { idleMs: 2000, hardMs: 2000, graceMs: 30 };

test('parallel rejects all unsafe/unknown agents before starting any', () => {
  assert.equal(parallelReadOnlyError(tasks('scout', 'shaman'), agents), undefined);
  assert.match(parallelReadOnlyError(tasks('scout', 'grunt'), agents), /grunt/);
  assert.match(parallelReadOnlyError(tasks('scout', 'unrestricted'), agents), /unrestricted/);
  assert.match(parallelReadOnlyError(tasks('scout', 'missing'), agents), /Unknown agent/);
  assert.ok(DEFAULT_RUN_LIMITS.hardMs > DEFAULT_RUN_LIMITS.idleMs);
  assert.deepEqual(resolveRunLimits({}), DEFAULT_RUN_LIMITS);
  assert.equal(resolveRunLimits({ timeoutSeconds: 30 }).idleMs, 24_000);
  assert.equal(resolveRunLimits({ timeoutSeconds: 500, idleTimeoutSeconds: 100 }).idleMs, 100_000);
});

test('normal exit retains JSON events; nonzero and signal exits are failures', async () => {
  const ok = await run('console.log(JSON.stringify({type:"message_end",message:{role:"assistant"}}))', limits);
  assert.equal(ok.status, 'completed');
  assert.equal(ok.events[0].type, 'message_end');
  const failed = await run('console.log(JSON.stringify({type:"tool_execution_start",toolName:"edit"}));process.exit(7)', limits);
  assert.equal(failed.status, 'failed');
  assert.equal(failed.exitCode, 7);
  assert.equal(failed.events[0].toolName, 'edit');
});

test('idle timeout retains earlier activity', async () => {
  const outcome = await run('console.log(JSON.stringify({type:"tool_execution_start",toolName:"read"}));setInterval(()=>{},1000)',
    { idleMs: 80, hardMs: 2000, graceMs: 30 });
  assert.equal(outcome.status, 'stalled');
  assert.equal(outcome.events[0].toolName, 'read');
});

test('hard timeout wins if child continues streaming', async () => {
  const outcome = await run('setInterval(()=>console.log(JSON.stringify({type:"heartbeat"})),10)',
    { idleMs: 1000, hardMs: 150, graceMs: 30 });
  assert.equal(outcome.status, 'timed_out');
  assert.ok(outcome.events.length > 0);
});

test('ignoring SIGTERM escalates to SIGKILL without losing cancellation status', async () => {
  const controller = new AbortController();
  const started = Date.now();
  const pending = run('process.on("SIGTERM",()=>{}); console.log("ready");setInterval(()=>{},1000)', limits, controller.signal);
  setTimeout(() => controller.abort(), 100);
  const outcome = await pending;
  assert.equal(outcome.status, 'aborted');
  assert.ok(Date.now() - started < 1500);
});

test('pre-aborted signal, spawn failure and silent zero exit are not successful JSON agent runs', async () => {
  const controller = new AbortController();
  controller.abort();
  assert.equal((await run('setInterval(()=>{},1000)', limits, controller.signal)).status, 'aborted');
  const failed = await runJsonAgentProcess('/missing/pi/command', [], process.cwd(), undefined, limits, () => {});
  assert.equal(failed.status, 'failed');
  // A process can exit 0 without producing a final assistant answer. The caller must check its last message.
  const silent = await run('', limits);
  assert.equal(silent.status, 'completed');
});
