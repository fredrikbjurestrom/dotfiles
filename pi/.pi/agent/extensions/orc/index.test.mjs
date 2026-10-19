import assert from "node:assert/strict";
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { test } from "node:test";

import registerOrc from "./index.ts";

const instructions = readFileSync(new URL("./taskmaster.md", import.meta.url), "utf8").trim();

function createHarness(register = registerOrc, hasSubagent = true) {
  const hooks = new Map();
  const commands = new Map();
  const notices = [];
  const widgets = [];
  let activeTools = ["read", "bash", "edit", "write", "tool_search", "subagent"];
  const pi = {
    getAllTools: () => hasSubagent ? [{ name: "subagent" }] : [],
    getActiveTools: () => [...activeTools],
    setActiveTools: (tools) => { activeTools = [...tools]; },
    on: (name, handler) => { hooks.set(name, handler); },
    registerCommand: (name, command) => { commands.set(name, command); },
  };
  const ctx = {
    mode: "print",
    ui: {
      setStatus() {},
      setWidget: (...args) => { widgets.push(args); },
      notify: (message, level) => { notices.push({ message, level }); },
    },
  };
  register(pi);
  return {
    hooks, notices, widgets, ctx,
    activeTools: () => [...activeTools],
    command: (args) => commands.get("orc").handler(args, ctx),
    start: () => hooks.get("session_start")({}, ctx),
    prompt: () => {
      const event = { systemPromptOptions: { sections: { project_context: "keep", orchestration: "stale" } } };
      hooks.get("before_agent_start")(event, ctx);
      return event.systemPromptOptions.sections;
    },
    toolCall: (toolName) => hooks.get("tool_call")({ toolName }),
  };
}

test("session start removes delegation and stale prompt without changing other tools", () => {
  const h = createHarness();
  h.start();
  assert.deepEqual(h.activeTools(), ["read", "bash", "edit", "write", "tool_search"]);
  assert.deepEqual(h.prompt(), { project_context: "keep" });
  assert.match(h.toolCall("subagent").reason, /ORC-läge är av/);
  assert.equal(h.toolCall("read"), undefined);
});

test("enabling injects the external role instruction; disabling removes it", async () => {
  const h = createHarness();
  h.start();
  await h.command("on");
  assert.deepEqual(h.prompt(), { project_context: "keep", orchestration: instructions });
  assert.equal(h.toolCall("subagent"), undefined);
  assert.equal(h.activeTools().filter((name) => name === "subagent").length, 1);
  await h.command("on");
  assert.equal(h.activeTools().filter((name) => name === "subagent").length, 1);
  await h.command("off");
  assert.deepEqual(h.prompt(), { project_context: "keep" });
  assert.equal(h.activeTools().includes("subagent"), false);
  assert.equal(h.toolCall("subagent").block, true);
});

test("new or resumed sessions always require explicit activation", async () => {
  const h = createHarness();
  h.start();
  await h.command("on");
  h.start();
  assert.equal(h.activeTools().includes("subagent"), false);
  assert.deepEqual(h.prompt(), { project_context: "keep" });
});

test("missing subagent tool cannot enable orchestration", async () => {
  const h = createHarness(registerOrc, false);
  h.start();
  await h.command("on");
  assert.equal(h.activeTools().includes("subagent"), false);
  assert.deepEqual(h.prompt(), { project_context: "keep" });
  assert.match(h.notices.at(-1).message, /Verktyget subagent saknas/);
  assert.equal(h.notices.at(-1).level, "warning");
});

test("status, quote and invalid commands do not enable delegation", async () => {
  const h = createHarness();
  h.start();
  for (const command of ["", "status", "quote", "invalid"]) await h.command(command);
  assert.equal(h.activeTools().includes("subagent"), false);
  assert.deepEqual(h.prompt(), { project_context: "keep" });
});

test("missing or empty role instruction fails closed, including after prior activation", async () => {
  const dir = mkdtempSync(join(tmpdir(), "orc-instructions-test-"));
  try {
    const extension = join(dir, "index.ts");
    const prompt = join(dir, "taskmaster.md");
    copyFileSync(new URL("./index.ts", import.meta.url), extension);
    const { default: register } = await import(pathToFileURL(extension).href);
    const h = createHarness(register);
    h.start();
    await h.command("on");
    assert.match(h.notices.at(-1).message, /Kan inte läsa ORC:s taskmaster.md/);
    assert.equal(h.activeTools().includes("subagent"), false);
    assert.deepEqual(h.prompt(), { project_context: "keep" });
    writeFileSync(prompt, instructions, "utf8");
    await h.command("on");
    assert.equal(h.prompt().orchestration, instructions);
    writeFileSync(prompt, "  \n", "utf8");
    await h.command("on");
    assert.match(h.notices.at(-1).message, /Rollinstruktionen är tom/);
    assert.equal(h.activeTools().includes("subagent"), false);
    assert.deepEqual(h.prompt(), { project_context: "keep" });
    assert.equal(h.toolCall("subagent").block, true);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("external role instruction defines stable identities and delivery constraints", () => {
  assert.match(instructions, /^# Taskmaster: huvudagentens arbetskontrakt/m);
  assert.match(instructions, /Du är Taskmaster, den aktiva huvudagenten som samtalar med användaren — inte Warchief/);
  assert.match(instructions, /\*\*Warchief\*\*: användaren/);
  assert.match(instructions, /Warchief är inte en agent och Taskmaster ska inte startas som en extra underagent/);
  assert.doesNotMatch(instructions, /Du är Warchief|Warchief: huvudagenten/);
  for (const phrase of [
    "Grunt", "Shaman", "Scout", "`grunt`", "`shaman`", "`scout`",
    "Leveranser ska vara neutrala", "Bevara befintliga datakontrakt",
    "före/efter-utdrag", "befintliga användarändringar",
    "statisk kontroll, enhetstest, integration och målmiljö",
    "Ett passerande alternativt test avskriver inte ett fel i en annan kodväg",
  ]) assert.ok(instructions.includes(phrase), `Missing instruction: ${phrase}`);
});

test("delegation targets uncertainty and gives Grunt bounded implementation ownership", () => {
  assert.match(instructions, /ORC ska sänka totalkostnaden/);
  assert.match(instructions, /Befintligt mönster och tydligt beteende: delegera direkt till Grunt/);
  assert.match(instructions, /Oklart ansvar eller kontrakt: läs den centrala koden/);
  assert.match(instructions, /ett undantag när det minskar osäkerheten, inte ett obligatoriskt extra steg/);
  for (const label of [
    "Mål", "Referensimplementation", "Måste bevaras", "Tillåtet ändringsområde",
    "Öppna lokala val", "Verifiering", "Eskalera om",
  ]) assert.ok(instructions.includes(`**${label}:**`), `Missing handoff field: ${label}`);

  const grunt = readFileSync(new URL("../../agents/grunt.md", import.meta.url), "utf8");
  for (const text of [instructions, grunt]) {
    assert.match(text, /förenkla intern uppdelning utan nytt godkännande/);
    assert.match(text, /beslutade beteenden, externa kontrakt och ansvar mellan komponenter bevaras/);
    assert.match(text, /ännu obeslutade ändringar av publikt API, datakontrakt eller fel-\/retry-beteende/);
    assert.match(text, /nya beroenden, större ansvarsförflyttningar eller utökad omfattning/);
    assert.doesNotMatch(text, /utan strategiska val/);
  }
});

test("Scout stays concise without replacing the design owner's direct code reading", () => {
  assert.match(instructions, /Undvik att upprepa Scouts breda kartläggning/);
  assert.match(instructions, /Läs själv de centrala kodavsnitt som behövs för designbeslut/);
  assert.doesNotMatch(instructions, /Lita på Scouts rapport|läs inte om filer/);
  const scout = readFileSync(new URL("../../agents/scout.md", import.meta.url), "utf8");
  assert.match(scout, /Håll huvudrapporten kort, normalt högst cirka 300 ord/);
  assert.match(scout, /Utöver huvudrapporten får du bifoga ett kort, relevant kodutdrag med filväg och radnummer/);
});

test("routine fixes remain delegated while design corrections and final verification stay owned", () => {
  assert.match(instructions, /Rutinmässiga implementations- och testfixar går normalt till Grunt/);
  assert.match(instructions, /ansvarar du för omprövningen och får korrigera den centrala delen direkt/);
  assert.match(instructions, /ta inte över hela implementationen slentrianmässigt/);
  assert.doesNotMatch(instructions, /Redigera inte koden själv efter granskningen/);
  assert.match(instructions, /Låt aldrig flera agenter, eller huvudagent och underagent, redigera samma fil samtidigt/);
  assert.match(instructions, /Vid ändrat produktionsbeteende kör du de berörda testprojekten i sin helhet/);
});

test("agent ids, tool restrictions and model selection remain compatible", () => {
  const expected = {
    grunt: { label: "Grunt", tools: "read, bash, edit, write", model: "github-copilot/gpt-6-luna" },
    shaman: { label: "Shaman", tools: "read, grep, find, ls", model: "github-copilot/claude-sonnet-5.5", thinking: "high" },
    scout: { label: "Scout", tools: "read, grep, find, ls", model: "github-copilot/gpt-6-luna" },
  };
  for (const [id, config] of Object.entries(expected)) {
    const text = readFileSync(new URL(`../../agents/${id}.md`, import.meta.url), "utf8");
    const header = text.split("---")[1];
    assert.ok(header.split(/\r?\n/).includes(`name: ${id}`));
    assert.ok(header.split(/\r?\n/).includes(`tools: ${config.tools}`));
    if (config.model) assert.ok(header.split(/\r?\n/).includes(`model: ${config.model}`));
    else assert.equal(/^model:/m.test(header), false);
    if (config.thinking) assert.ok(header.split(/\r?\n/).includes(`thinking: ${config.thinking}`));
    assert.ok(text.includes(config.label));
    assert.ok(text.includes("Användaren är Warchief; huvudagenten är Taskmaster."));
    assert.ok(text.includes("Ingen flavor får förekomma"));
  }
});
