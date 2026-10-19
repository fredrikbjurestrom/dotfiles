import assert from 'node:assert/strict';
import { test, before, after } from 'node:test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { registerHooks } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

// Resolve installed Pi ESM packages when importing a personal extension outside Pi's loader.
const piExecutable = process.env.PATH.split(path.delimiter).map(dir => path.join(dir, 'pi')).find(file => fs.existsSync(file));
assert.ok(piExecutable, 'pi must be on PATH to run integration tests');
let dir = path.dirname(fs.realpathSync(piExecutable));
let piRoot;
while (!piRoot) {
  for (const candidate of [dir, path.join(dir, 'node_modules', '@earendil-works', 'pi-coding-agent')]) {
    if (fs.existsSync(path.join(candidate, 'dist', 'index.js'))) piRoot = candidate;
  }
  const parent = path.dirname(dir);
  if (piRoot || parent === dir) break;
  dir = parent;
}
assert.ok(piRoot, 'Could not find installed @earendil-works/pi-coding-agent');
const extensionURL = pathToFileURL(path.dirname(fileURLToPath(import.meta.url)) + path.sep).href;
registerHooks({ resolve(specifier, context, next) {
  if (/^(@earendil-works\/pi-(coding-agent|ai|tui|agent-core)|typebox)$/.test(specifier) && context.parentURL?.startsWith(extensionURL)) {
    const target = specifier === 'typebox' ? path.join(piRoot, 'node_modules', 'typebox', 'build', 'index.mjs')
      : specifier === '@earendil-works/pi-coding-agent' ? path.join(piRoot, 'dist', 'index.js')
      : path.join(piRoot, 'node_modules', specifier, 'dist', 'index.js');
    return { url: pathToFileURL(target).href, shortCircuit: true };
  }
  return next(specifier, context);
}});
const { default: register } = await import('./index.ts');
let tool;
register({ registerTool(definition) { tool = definition; } });
assert.equal(tool.name, 'subagent');
const cwd = process.cwd();
const ctx = { cwd, model: undefined, thinkingLevel: 'off', hasUI: false };
const oldScript = process.argv[1];
let tempDir;
let marker;

before(() => {
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'subagent-test-'));
  const fixture = path.join(tempDir, 'fake-pi.mjs');
  marker = path.join(tempDir, 'spawned');
  fs.writeFileSync(fixture, `
import fs from 'node:fs';
fs.appendFileSync(process.env.PI_SUBAGENT_TEST_SPAWN_MARKER, '1');
const args = process.argv.slice(2);
const task = args.at(-1);
if (task.includes('captureargs')) fs.writeFileSync(process.env.PI_SUBAGENT_TEST_SPAWN_MARKER + '.args', JSON.stringify(args));
const text = task.includes('success') ? 'done' : 'partial text';
console.log(JSON.stringify({type:'tool_execution_start',toolName:'read'}));
if (task.includes('streamfail')) {
  console.log(JSON.stringify({type:'message_update',assistantMessageEvent:{type:'text_delta',delta:'streamed partial'}}));
  process.exit(7);
}
if (task.includes('silent')) process.exit(0);
console.log(JSON.stringify({type:'message_end',message:{role:'assistant',content:[{type:'text',text}],stopReason:'stop',model:'mock',usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{total:0}}}}));
if (task.includes('fail')) process.exit(7);
`);
  process.env.PI_SUBAGENT_TEST_SPAWN_MARKER = marker;
  process.argv[1] = fixture;
});
after(() => {
  process.argv[1] = oldScript;
  delete process.env.PI_SUBAGENT_TEST_SPAWN_MARKER;
  fs.rmSync(tempDir, { recursive: true, force: true });
});
const execute = (params) => tool.execute('test', params, undefined, undefined, ctx);

test('single success and empty final text are distinguished', async () => {
  const ok = await execute({ agent: 'scout', task: 'success' });
  assert.equal(ok.isError, undefined);
  assert.equal(ok.content[0].text, 'done');
  const silent = await execute({ agent: 'scout', task: 'silent' });
  assert.equal(silent.isError, true);
  assert.match(silent.content[0].text, /No non-empty final assistant response/);
  assert.deepEqual(silent.details.results[0].observedTools, ['read']);
  const streamed = await execute({ agent: 'scout', task: 'streamfail' });
  assert.equal(streamed.isError, true);
  assert.match(streamed.content[0].text, /streamed partial/);
});

test('agent thinking frontmatter overrides dispatch defaults; pinned models do not inherit', async () => {
  const argsFile = marker + '.args';
  const flag = (args, name) => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
  const run = async (agent) => {
    fs.rmSync(argsFile, { force: true });
    await execute({ agent, task: 'success captureargs' });
    return JSON.parse(fs.readFileSync(argsFile, 'utf8'));
  };
  const shaman = await run('shaman');
  assert.equal(flag(shaman, '--model'), 'github-copilot/claude-sonnet-5.5');
  assert.equal(flag(shaman, '--thinking'), 'high');
  const scout = await run('scout');
  assert.equal(flag(scout, '--model'), 'github-copilot/gpt-6-luna');
  assert.equal(flag(scout, '--thinking'), undefined);
});

test('running subagents render as progress rather than errors', () => {
  const theme = { fg: (_color, text) => text, bold: text => text };
  const preview = (mode, status) => {
    const running = status === 'running';
    const result = {
      content: [{ type: 'text', text: running ? '(running...)' : 'failed' }],
      details: { mode, results: [{
        agent: 'shaman', agentSource: 'user', task: 'review', step: 1,
        status, exitCode: running ? -1 : 1, reason: 'simulated failure',
        messages: [], observedTools: ['read'], usage: {},
      }] },
    };
    return tool.renderResult(result, { expanded: false, isPartial: running }, theme, ctx).render(120).join('\n');
  };
  for (const mode of ['single', 'chain']) {
    assert.match(preview(mode, 'running'), /⏳/);
    assert.doesNotMatch(preview(mode, 'running'), /Incomplete|✗/);
    assert.match(preview(mode, 'failed'), /Incomplete \(failed\)/);
  }
});

test('chain stops on failure and keeps partial activity', async () => {
  const result = await execute({ chain: [
    { agent: 'scout', task: 'success' },
    { agent: 'scout', task: 'fail' },
    { agent: 'scout', task: 'success should not run' },
  ] });
  assert.equal(result.isError, true);
  assert.equal(result.details.results.length, 2);
  assert.match(result.content[0].text, /Partial assistant text/);
});

test('parallel rejects writing and unrestricted agents before spawning', async () => {
  fs.rmSync(marker, { force: true });
  for (const name of ['grunt', 'missing']) {
    const result = await execute({ tasks: [{ agent: 'scout', task: 'success' }, { agent: name, task: 'fail' }] });
    assert.equal(result.isError, true);
    assert.equal(fs.existsSync(marker), false);
  }
});

test('parallel retains successful results when another agent fails', async () => {
  const result = await execute({ tasks: [{ agent: 'scout', task: 'success' }, { agent: 'shaman', task: 'fail' }] });
  assert.equal(result.isError, true);
  assert.match(result.content[0].text, /1\/2 succeeded/);
  assert.match(result.content[0].text, /\[scout\] completed[\s\S]*done/);
  assert.match(result.content[0].text, /\[shaman\] failed[\s\S]*Partial assistant text/);
});
