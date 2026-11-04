import test from "node:test";
import assert from "node:assert/strict";
import { CHEMCLOUD_MCP_PRESETS, createChemClawConnectors } from "../bridge/dsh-go-bridge/lib/chemclaw-connectors.js";

function fake({ key = "" } = {}) {
  const mounted = [];
  const guards = [];
  const ctx = {
    get(name) {
      if (name === "credentials") return { async resolve(ref) {
        assert.ok(["CHEM_DATA_HUB", "QCC"].includes(ref));
        return key ? { value: key } : undefined;
      }};
      if (name === "loader") return { async import(name) {
        assert.equal(name, "@deepseek-ai/dsh-mcp-client");
        return { default: {} };
      }};
    },
    tools: { guard: fn => guards.push(fn) },
    plugin(_module, config) {
      mounted.push(config);
      return { async await() {}, async dispose() {} };
    },
  };
  const responses = [];
  const routes = createChemClawConnectors(ctx, {
    async readBody(_req) { return Buffer.from(JSON.stringify({ action: "connect" })); },
    send(_res, status, data) { responses.push({ status, data }); },
  });
  async function action(id, method = "POST") {
    await routes.handle({ method, headers: { "content-type": "application/json" }, resume() {} }, {}, 
      "/dsh-go/v1/chemclaw/connectors" + (id ? "/" + id : ""));
    return responses.at(-1);
  }
  return { routes, action, responses, mounted, guards };
}

test("preset endpoints and key references are fixed by ChemClaw desktop contract", () => {
  assert.deepEqual(CHEMCLOUD_MCP_PRESETS.map(x => x.id), ["chem-data-hub", "qcc-company", "qcc-ipr", "qcc-operation", "qcc-risk", "huagongshe"]);
  assert.equal(CHEMCLOUD_MCP_PRESETS[0].url, "https://datahub.chem-cloud.cn/mcp");
  assert.equal(CHEMCLOUD_MCP_PRESETS[0].credential, "CHEM_DATA_HUB");
  assert.equal(CHEMCLOUD_MCP_PRESETS.find(x => x.id === "huagongshe").anonymous, true);
  assert.equal(CHEMCLOUD_MCP_PRESETS.filter(x => x.credential === "QCC").length, 4);
});

test("QCC uses one secret for four HTTPS MCP connectors", async () => {
  const f = fake({ key: "test-only-qcc-key" });
  for (const id of ["qcc-company", "qcc-ipr", "qcc-operation", "qcc-risk"]) {
    const r = await f.action(id);
    assert.equal(r.data.service.state, "ready");
    assert.equal(JSON.stringify(r).includes("test-only-qcc-key"), false);
  }
  assert.deepEqual(f.mounted.map(x => x.url), [
    "https://agent.qcc.com/mcp/company/stream",
    "https://agent.qcc.com/mcp/ipr/stream",
    "https://agent.qcc.com/mcp/operation/stream",
    "https://agent.qcc.com/mcp/risk/stream",
  ]);
  assert.ok(f.mounted.every(x => x.headers.Authorization === "Bearer test-only-qcc-key"));
  await f.routes.dispose();
});

test("missing QCC key never contacts its MCP services", async () => {
  const f = fake();
  const r = await f.action("qcc-company");
  assert.equal(r.data.service.state, "needs-key");
  assert.equal(f.mounted.length, 0);
  await f.routes.dispose();
});

test("missing credential does not call the private MCP endpoint", async () => {
  const f = fake();
  const res = await f.action("chem-data-hub");
  assert.equal(res.status, 200);
  assert.equal(res.data.service.state, "needs-key");
  assert.equal(f.mounted.length, 0);
  await f.routes.dispose();
});

test("after credential/set, Connect mounts the MCP client but never echoes the key", async () => {
  const secret = "test-key-not-for-repo";
  const f = fake({ key: secret });
  const res = await f.action("chem-data-hub");
  assert.equal(res.data.service.state, "ready");
  assert.equal(f.mounted[0].serverName, "chem-data-hub");
  assert.equal(f.mounted[0].headers.Authorization, "Bearer " + secret);
  assert.equal(f.mounted[0].transport, "streamable-http");
  assert.equal(f.mounted[0].url, "https://datahub.chem-cloud.cn/mcp");
  assert.equal(JSON.stringify(res), JSON.stringify(res).replace(secret, "redacted"));
  await f.routes.dispose();
});

test("public chemistry requires a deny-by-default guard and no key", async () => {
  const f = fake();
  const result = await f.action("huagongshe");
  assert.equal(result.data.service.state, "ready");
  assert.equal(f.mounted[0].headers.Authorization, undefined);
  assert.equal(f.guards.length, 1);
  assert.match(f.guards[0]({ name: "mcp__huagongshe__write_private_data" }), /read-only/);
  assert.equal(f.guards[0]({ name: "mcp__huagongshe__get_chemical" }), undefined);
  await f.routes.dispose();
});

test("connector route rejects secret-bearing JSON and unsupported verbs", async () => {
  const f = fake();
  const r = await f.action("chem-data-hub", "GET");
  assert.equal(r.status, 405);
  await f.routes.dispose();
});
