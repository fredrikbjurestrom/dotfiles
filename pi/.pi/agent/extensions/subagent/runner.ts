import { spawn } from "node:child_process";
import { StringDecoder } from "node:string_decoder";

export type RunStatus = "completed" | "failed" | "aborted" | "timed_out" | "stalled";

export interface ProcessOutcome {
	status: RunStatus;
	exitCode: number | null;
	reason?: string;
	stderr: string;
}

export interface RunLimits {
	idleMs: number;
	hardMs: number;
	graceMs: number;
}

const STDERR_CAP = 8 * 1024;
const JSON_LINE_CAP = 2 * 1024 * 1024;
export const DEFAULT_RUN_LIMITS: RunLimits = {
	idleMs: 15 * 60_000,
	hardMs: 45 * 60_000,
	graceMs: 5_000,
};

export function resolveRunLimits(options: { timeoutSeconds?: number; idleTimeoutSeconds?: number }): RunLimits {
	const hardMs = Math.round(Math.min(7200, Math.max(30, options.timeoutSeconds ?? 2700)) * 1000);
	const idleMs = Math.round(Math.min(hardMs * 0.8, Math.min(3600, Math.max(10, options.idleTimeoutSeconds ?? 900)) * 1000));
	return { hardMs, idleMs, graceMs: DEFAULT_RUN_LIMITS.graceMs };
}

/** An explicit tool allowlist is required: omitting --tools would enable Pi's defaults. */
export function parallelReadOnlyError(
	tasks: ReadonlyArray<{ agent: string }>,
	agents: ReadonlyArray<{ name: string; tools?: string[] }>,
): string | undefined {
	const readOnlyTools = new Set(["read", "grep", "find", "ls"]);
	for (const task of tasks) {
		const agent = agents.find((candidate) => candidate.name === task.agent);
		if (!agent) return `Unknown agent "${task.agent}". No parallel agents started.`;
		if (!agent.tools?.length || agent.tools.some((tool) => !readOnlyTools.has(tool))) {
			return `Agent "${task.agent}" has no explicit read-only tool allowlist (read, grep, find, ls). No parallel agents started; run it in single mode instead.`;
		}
	}
}

/** Consume JSONL while supervising the child. Partial output survives nonzero exits and cancellation. */
export function runJsonAgentProcess(
	command: string,
	args: string[],
	cwd: string,
	signal: AbortSignal | undefined,
	limits: RunLimits,
	onEvent: (event: any) => void,
): Promise<ProcessOutcome> {
	return new Promise((resolve) => {
		let proc: ReturnType<typeof spawn>;
		try {
			proc = spawn(command, args, { cwd, shell: false, stdio: ["ignore", "pipe", "pipe"] });
		} catch (error) {
			resolve({ status: "failed", exitCode: null, reason: String(error), stderr: "" });
			return;
		}
		let status: RunStatus = "completed";
		let reason: string | undefined;
		let stderr = "";
		let buffer = "";
		const decoder = new StringDecoder("utf8");
		let droppingLongLine = false;
		let closed = false;
		let graceTimer: ReturnType<typeof setTimeout> | undefined;
		let idleTimer: ReturnType<typeof setTimeout> | undefined;
		let hardTimer: ReturnType<typeof setTimeout> | undefined;

		const stop = (nextStatus: RunStatus, message: string) => {
			if (closed || status !== "completed") return;
			status = nextStatus;
			reason = message;
			proc.kill("SIGTERM");
			// proc.killed only means a signal was sent, NOT that the process exited.
			graceTimer = setTimeout(() => { if (!closed) proc.kill("SIGKILL"); }, limits.graceMs);
		};
		const resetIdle = () => {
			if (idleTimer) clearTimeout(idleTimer);
			if (!closed && status === "completed") {
				idleTimer = setTimeout(() => stop("stalled", `No stdout activity for ${limits.idleMs} ms`), limits.idleMs);
			}
		};
		const abort = () => stop("aborted", "Interrupted by caller");
		const processLine = (line: string) => {
			if (!line.trim()) return;
			let event: unknown;
			try { event = JSON.parse(line); } catch { return; }
			try { onEvent(event); } catch (error) { stop("failed", `Could not process child event: ${String(error)}`); }
		};
		proc.stdout.on("data", (chunk: Buffer) => {
			resetIdle();
			const lines = (buffer + decoder.write(chunk)).split("\n");
			buffer = lines.pop() ?? "";
			for (const line of lines) {
				if (!droppingLongLine && line.length <= JSON_LINE_CAP) processLine(line);
				droppingLongLine = false;
			}
			if (buffer.length > JSON_LINE_CAP) { buffer = ""; droppingLongLine = true; }
		});
		proc.stderr.on("data", (chunk: Buffer) => {
			stderr = (stderr + chunk.toString("utf8")).slice(-STDERR_CAP);
		});
		proc.on("error", (error) => {
			if (status === "completed") { status = "failed"; reason = error.message; }
		});
		proc.on("close", (code, exitSignal) => {
			closed = true;
			if (idleTimer) clearTimeout(idleTimer);
			if (hardTimer) clearTimeout(hardTimer);
			if (graceTimer) clearTimeout(graceTimer);
			signal?.removeEventListener("abort", abort);
			buffer += decoder.end();
			if (buffer.trim() && !droppingLongLine) processLine(buffer);
			if (status === "completed" && (code !== 0 || exitSignal)) {
				status = "failed";
				reason = exitSignal ? `Exited on ${exitSignal}` : `Exited with code ${code}`;
			}
			resolve({ status, exitCode: code, reason, stderr });
		});
		if (signal?.aborted) abort();
		else signal?.addEventListener("abort", abort, { once: true });
		if (status === "completed") {
			resetIdle();
			hardTimer = setTimeout(() => stop("timed_out", `Exceeded total time of ${limits.hardMs} ms`), limits.hardMs);
		}
	});
}
