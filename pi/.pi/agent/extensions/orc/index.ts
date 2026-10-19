import { readFileSync } from "node:fs";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// The bundled subagent example registers its tool as active. Make it opt-in
// before the first model request, including in every child Pi process.
export default function orcMode(pi: ExtensionAPI) {
  let enabled = false;
  let taskmasterInstructions = "";
  let quoteIndex = -1;
  const quotes = ["Zug zug", "Work, work.", "Dabu.", "Ready to work.", "Something need doing?"];
  const badgeText = () => ` ORC: ${quotes[quoteIndex]} `;

  function chooseStartQuote() {
    quoteIndex = quoteIndex < 0
      ? Math.floor(Math.random() * quotes.length)
      : (quoteIndex + 1 + Math.floor(Math.random() * (quotes.length - 1))) % quotes.length;
  }

  function showBadge(ctx: ExtensionContext) {
    ctx.ui.setStatus("orc-mode", undefined);
    if (ctx.mode !== "tui" || !enabled) {
      ctx.ui.setWidget("orc-mode", undefined);
      return;
    }

    ctx.ui.setWidget("orc-mode", (tui, theme) => ({
      invalidate() {},
      render(width: number) {
        const text = badgeText().slice(0, Math.max(0, width));
        const badge = theme.style(text, {
          fg: { kind: "rgb", r: 248, g: 255, b: 241 },
          bg: { kind: "rgb", r: 32, g: 100, b: 50 },
          bold: true,
        });
        return [badge];
      },
      handleMouse(event) {
        if (event.type !== "click" || event.button !== "left" || event.y !== 0 ||
            event.x >= Math.min(event.width, badgeText().length)) return;
        quoteIndex = (quoteIndex + 1) % quotes.length;
        tui.requestRender();
        return { handled: true, render: true };
      },
    }), { placement: "belowEditor" });
  }

  function setMode(on: boolean): string | undefined {
    let error: string | undefined;
    if (on) {
      if (!pi.getAllTools().some((tool) => tool.name === "subagent")) {
        error = "Verktyget subagent saknas. Kontrollera ~/.pi/agent/extensions/subagent/.";
      } else {
        try {
          const instructions = readFileSync(new URL("./taskmaster.md", import.meta.url), "utf8").trim();
          if (!instructions) throw new Error("Rollinstruktionen är tom.");
          taskmasterInstructions = instructions;
        } catch (cause) {
          error = `Kan inte läsa ORC:s taskmaster.md: ${cause instanceof Error ? cause.message : String(cause)}`;
        }
      }
    }
    // Aktivera aldrig delegering utan en giltig huvudagentinstruktion.
    enabled = on && !error;
    const tools = pi.getActiveTools().filter((name) => name !== "subagent");
    pi.setActiveTools(enabled ? [...tools, "subagent"] : tools);
    if (!enabled) taskmasterInstructions = "";
    return error;
  }

  pi.on("session_start", (_event, ctx) => {
    setMode(false); // Every new/resumed session starts as ordinary chat.
    quoteIndex = -1;
    showBadge(ctx);
  });

  pi.registerCommand("orc", {
    description: "ORC-läge: /orc on, /orc off, /orc status, /orc quote",
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();
      if (action === "status" || action === "") {
        ctx.ui.notify(`ORC-läge: ${enabled ? "PÅ" : "AV"}. /orc on | /orc off`, "info");
        return;
      }
      if (action === "quote") {
        if (!enabled) {
          ctx.ui.notify("Slå på ORC-läge med /orc on först.", "warning");
          return;
        }
        quoteIndex = (quoteIndex + 1) % quotes.length;
        showBadge(ctx);
        return;
      }
      if (action !== "on" && action !== "off") {
        ctx.ui.notify("Använd /orc on, /orc off, /orc status eller /orc quote.", "warning");
        return;
      }
      const wasEnabled = enabled;
      const error = setMode(action === "on");
      if (error) {
        showBadge(ctx);
        ctx.ui.notify(error, "warning");
        return;
      }
      if (enabled && !wasEnabled) chooseStartQuote();
      showBadge(ctx);
      ctx.ui.notify(`ORC-läge ${enabled ? "PÅ" : "AV"}.`, "info");
    },
  });

  // Also block stale/in-flight attempts after switching back to ordinary chat.
  pi.on("tool_call", (event) => {
    if (event.toolName === "subagent" && !enabled) {
      return { block: true, reason: "ORC-läge är av. Använd /orc on för att delegera." };
    }
  });

  pi.on("before_agent_start", (event) => {
    if (!enabled) {
      delete event.systemPromptOptions.sections.orchestration;
      return;
    }
    event.systemPromptOptions.sections.orchestration = taskmasterInstructions;
  });
}
