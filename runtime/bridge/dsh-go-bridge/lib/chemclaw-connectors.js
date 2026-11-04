// ChemClaw's small, host-side MCP preset adapter for the DSH Go Android bridge.
// No customer API key is bundled or written into a profile. Key values live in
// the active DSH host's credentials store, referenced by name only.
// This module exposes status and explicit reconnect, not a generic MCP proxy.
export const CHEMCLOUD_MCP_PRESETS = Object.freeze([
  Object.freeze({
    id: "chem-data-hub",
    name: "芯化和云数据中台",
    url: "https://datahub.chem-cloud.cn/mcp",
    credential: "CHEM_DATA_HUB",
    tokenUrl: "https://mcp.chem-cloud.cn/",
    anonymous: false,
  }),
  Object.freeze({
    id: "huagongshe",
    name: "化工社公开化学检索",
    url: "https://huagongshe.com/mcp",
    credential: null,
    tokenUrl: "https://huagongshe.com/zh-CN/mcp-guide",
    anonymous: true,
  }),
]);

const ENDPOINT = "/dsh-go/v1/chemclaw/connectors";
const CLIENT = "@deepseek-ai/dsh-mcp-client";
const TIMEOUT = 20000;
const PUBLIC_READ_ONLY = new Set([
  "search_chemistry_data", "get_chemical", "get_reaction",
  "render_molecule_svg", "render_reaction_svg",
  "list_skills", "get_skill", "calculate_stoichiometry",
]);

const isRecord = value => value !== null && typeof value === "object" && !Array.isArray(value);

export function createChemClawConnectors(ctx, { readBody, send }) {
  const states = new Map();
  const mounted = new Map();
  const pending = new Map();
  let guardInstalled = false;
  let stopped = false;

  function stateOf(def) {
    return states.get(def.id) ?? { state: def.anonymous ? "not-started" : "needs-key" };
  }
  function publicStatus(def) {
    const status = stateOf(def);
    return {
      id: def.id,
      name: def.name,
      url: def.url,
      tokenUrl: def.tokenUrl,
      anonymous: def.anonymous,
      state: status.state,
      // A generic reason: never echo a caught exception, which may contain a key.
      ...(status.reason ? { reason: status.reason } : {}),
    };
  }
  async function keyOf(def) {
    if (def.anonymous) return "";
    const service = ctx.get?.("credentials");
    if (typeof service?.resolve !== "function") throw Error("credentials-unavailable");
    const record = await service.resolve(def.credential);
    return typeof record?.value === "string" ? record.value : "";
  }
  async function unmount(id) {
    const previous = mounted.get(id);
    mounted.delete(id);
    if (previous?.fiber) await previous.fiber.dispose().catch(() => {});
  }
  function guardPublicTools() {
    if (guardInstalled) return;
    // This publicly reachable service is mounted only if a fail-closed guard is
    // supported by the active DSH runtime. Never expose its nonpublic tools.
    if (typeof ctx.tools?.guard !== "function") throw Error("guard-unavailable");
    ctx.tools.guard(exec => {
      if (!exec?.name?.startsWith("mcp__huagongshe__")) return;
      const tool = exec.name.slice("mcp__huagongshe__".length);
      if (!PUBLIC_READ_ONLY.has(tool)) return "ChemClaw permits only Huagongshe public read-only tools.";
      if (tool === "search_chemistry_data" &&
          /similarity|substructure/i.test(JSON.stringify(exec.args ?? exec.arguments ?? {}))) {
        return "Structure search needs separate authorization.";
      }
    });
    guardInstalled = true;
  }
  async function connect(def) {
    if (stopped) return publicStatus(def);
    let token = "";
    try {
      token = await keyOf(def);
      if (!def.anonymous && token.length === 0) {
        await unmount(def.id);
        states.set(def.id, { state: "needs-key" });
        return publicStatus(def);
      }
      const before = mounted.get(def.id);
      if (before?.token === token && stateOf(def).state === "ready") return publicStatus(def);
      await unmount(def.id);
      if (def.anonymous) guardPublicTools();
      states.set(def.id, { state: "connecting" });
      const loader = ctx.get?.("loader");
      if (typeof loader?.import !== "function" || typeof ctx.plugin !== "function") {
        throw Error("plugin-loader-unavailable");
      }
      const exports = await loader.import(CLIENT);
      if (stopped) return publicStatus(def);
      const plugin = loader.unwrapExports?.(exports) ?? exports.default ?? exports;
      const fiber = ctx.plugin(plugin, {
        transport: "streamable-http",
        serverName: def.id,
        url: def.url,
        headers: def.anonymous ? {} : { Authorization: "Bearer " + token },
        failOnStartupError: true,
        toolCallTimeoutMs: 30000,
      });
      mounted.set(def.id, { fiber, token });
      let timer;
      try {
        await Promise.race([
          fiber.await(),
          new Promise((_, reject) => {
            timer = setTimeout(() => reject(Error("timeout")), TIMEOUT);
          }),
        ]);
      } finally {
        clearTimeout(timer);
      }
      if (!stopped && mounted.get(def.id)?.fiber === fiber) states.set(def.id, { state: "ready" });
    } catch (error) {
      await unmount(def.id);
      const reason = error?.message === "credentials-unavailable" ? "credentials-unavailable"
        : error?.message === "guard-unavailable" ? "guard-unavailable"
        : error?.message === "plugin-loader-unavailable" ? "plugin-loader-unavailable"
        : error?.message === "timeout" ? "timeout" : "connection-failed";
      states.set(def.id, { state: "error", reason });
    }
    return publicStatus(def);
  }
  function sync(def) {
    const last = pending.get(def.id) ?? Promise.resolve();
    const next = last.catch(() => {}).then(() => connect(def));
    pending.set(def.id, next);
    return next;
  }

  async function restore() {
    // A saved data hub key survives the DSH process restart. A missing one
    // does not trigger an outbound request. Public chemistry is read-only.
    await Promise.allSettled(CHEMCLOUD_MCP_PRESETS.map(async def => {
      if (def.anonymous || (await keyOf(def)).length > 0) await sync(def);
    }));
  }

  async function handle(req, res, path) {
    if (path === ENDPOINT) {
      if (req.method !== "GET") {
        req.resume();
        send(res, 405, { error: "method-not-allowed" });
      } else {
        send(res, 200, { v: 1, services: CHEMCLOUD_MCP_PRESETS.map(publicStatus) });
      }
      return true;
    }
    const match = /^\/dsh-go\/v1\/chemclaw\/connectors\/([a-z-]+)$/.exec(path);
    if (!match) return false;
    const def = CHEMCLOUD_MCP_PRESETS.find(x => x.id === match[1]);
    if (!def) {
      req.resume();
      send(res, 404, { error: "unknown-service" });
      return true;
    }
    if (req.method !== "POST") {
      req.resume();
      send(res, 405, { error: "method-not-allowed" });
      return true;
    }
    if (String(req.headers["content-type"]).split(";", 1)[0].trim().toLowerCase() !== "application/json") {
      req.resume();
      send(res, 415, { error: "content-type-required" });
      return true;
    }
    let body;
    try {
      body = JSON.parse((await readBody(req, 2048)).toString("utf8"));
    } catch {
      send(res, 400, { error: "invalid-json" });
      return true;
    }
    if (!isRecord(body) || body.action !== "connect" || Object.keys(body).length !== 1) {
      send(res, 400, { error: "invalid-action" });
      return true;
    }
    const result = await sync(def);
    send(res, 200, { v: 1, service: result });
    return true;
  }
  async function dispose() {
    stopped = true;
    await Promise.allSettled([...mounted.keys()].map(unmount));
  }

  return { handle, restore, dispose };
}
