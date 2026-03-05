#!/usr/bin/env npx tsx
/**
 * workiq-client.ts — WorkIQ MCP stdio client
 *
 * Spawns the WorkIQ MCP server as a child process over stdio, discovers
 * available tools via JSON-RPC, fetches a meeting summary, and prints
 * prose to stdout (same shape as mocks/workiq-response.txt).
 *
 * Auth prompts (Entra ID device-code on first run) go to stderr so
 * they appear in the terminal without polluting the captured output.
 *
 * Usage:
 *   npx tsx extraction/workiq-client.ts "<meeting query>"
 *
 * Called by extract-prd.sh when WORKIQ_LIVE=true.
 */

import { spawn } from "child_process";
import * as readline from "readline";

const query = process.argv[2] ?? "Get the most recent meeting transcript";

async function main() {
  // Spawn the WorkIQ MCP server over stdio.
  // stderr is inherited so Entra ID device-code auth prompts reach the terminal.
  const server = spawn("npx", ["-y", "@microsoft/workiq", "mcp"], {
    stdio: ["pipe", "pipe", "inherit"],
  });

  server.on("error", (err) => {
    process.stderr.write(`Failed to start WorkIQ MCP server: ${err.message}\n`);
    process.exit(1);
  });

  // JSON-RPC request state
  let requestId = 0;
  const pending = new Map<
    number,
    { resolve: (v: unknown) => void; reject: (e: Error) => void }
  >();

  // Single readline interface for the lifetime of the connection
  const rl = readline.createInterface({ input: server.stdout! });

  rl.on("line", (line) => {
    if (!line.trim()) return;
    try {
      const msg = JSON.parse(line) as {
        id?: number;
        result?: unknown;
        error?: { message?: string };
      };
      if (msg.id !== undefined && pending.has(msg.id)) {
        const { resolve, reject } = pending.get(msg.id)!;
        pending.delete(msg.id);
        if (msg.error) {
          reject(new Error(msg.error.message ?? JSON.stringify(msg.error)));
        } else {
          resolve(msg.result);
        }
      }
    } catch {
      // Non-JSON line (e.g. server startup log) — ignore
    }
  });

  function rpc(method: string, params?: unknown): Promise<unknown> {
    const id = ++requestId;
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      const request =
        JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n";
      server.stdin!.write(request);
    });
  }

  // MCP handshake
  await rpc("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "meeting-to-main", version: "1.0.0" },
  });

  // Discover available tools
  const { tools } = (await rpc("tools/list")) as {
    tools: Array<{ name: string }>;
  };
  process.stderr.write(
    `[workiq-client] tools: ${tools.map((t) => t.name).join(", ")}\n`
  );

  // Pick the most relevant tool — prefer explicit meeting/query tools
  const preferredNames = [
    "query",
    "search_meetings",
    "get_meeting_transcript",
    "meetings",
  ];
  const tool =
    tools.find((t) => preferredNames.includes(t.name)) ?? tools[0];

  if (!tool) {
    throw new Error("WorkIQ MCP server returned no tools");
  }

  process.stderr.write(`[workiq-client] calling tool: ${tool.name}\n`);

  // Fetch meeting data
  const result = (await rpc("tools/call", {
    name: tool.name,
    arguments: { query },
  })) as { content: Array<{ type: string; text: string }> };

  // Extract prose from MCP content blocks
  const prose = result.content
    .filter((c) => c.type === "text")
    .map((c) => c.text)
    .join("\n\n");

  if (!prose.trim()) {
    throw new Error(
      "WorkIQ returned empty content — check your meeting query or M365 permissions"
    );
  }

  // Print prose to stdout — captured by extract-prd.sh as WORKIQ_OUTPUT
  process.stdout.write(prose + "\n");

  server.stdin!.end();
}

main().catch((err: Error) => {
  process.stderr.write(`[workiq-client] error: ${err.message}\n`);
  process.exit(1);
});
