import test from 'node:test';
import assert from 'node:assert/strict';
import { createAutoSearchProvider, parseDuckDuckGo, AUTO_PROVIDER_ID } from '../bridge/dsh-go-bridge/lib/web-search-auto.js';
import { registerChemClawSearch } from '../bridge/dsh-go-bridge/lib/index.js';

test('mobile keeps the official DSH web provider contract', () => {
  assert.equal(AUTO_PROVIDER_ID, 'auto');
  const provider = createAutoSearchProvider({
    route: () => undefined,
    resolveKey: async () => undefined,
    resolveAccountToken: async () => undefined,
    fetch: async () => { throw new Error('should not call native API'); },
    webFetch: async () => ({
      statusCode: 200, url: 'https://www.bing.com/search?q=acetone',
      body: { kind: 'html', content: '<li class="b_algo"><h2><a href="https://example.org/price">Acetone spot market</a></h2><p>Market price report</p></li>' },
    }),
  }, { native: false, fallback: true, engines: ['bing'] });
  assert.equal(provider.id, 'auto');
  assert.equal(provider.available(), true);
});

test('DuckDuckGo parsing never invents a source', () => {
  assert.deepEqual(parseDuckDuckGo('<div>No results found</div>').sources ?? [], []);
});

test('single bridge Loader entry registers all four search backends', () => {
  const ids = [];
  const disposers = [];
  const ctx = {
    web: {
      registerSearchProvider(provider) {
        ids.push(provider.id);
        return () => disposers.push(provider.id);
      },
      fetch: async () => { throw new Error('No network in registration test'); },
    },
    get: () => undefined,
    effect: (factory) => { const cleanup = factory(); if (typeof cleanup === 'function') cleanup(); },
  };
  registerChemClawSearch(ctx);
  assert.deepEqual(ids, ['auto', 'chemclaw-brave', 'chemclaw-tavily', 'chemclaw-serper']);
  assert.deepEqual(disposers, ['chemclaw-brave', 'chemclaw-tavily', 'chemclaw-serper']);
});

test('bridge starts with no web seam in safe or minimal host contexts', () => {
  assert.doesNotThrow(() => registerChemClawSearch({}));
  assert.doesNotThrow(() => registerChemClawSearch({ web: undefined }));
  assert.doesNotThrow(() => registerChemClawSearch({ web: {} }));
});
