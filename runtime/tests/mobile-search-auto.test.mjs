import test from 'node:test';
import assert from 'node:assert/strict';
import { createAutoSearchProvider, parseDuckDuckGo, AUTO_PROVIDER_ID } from '../bridge/dsh-go-bridge/lib/web-search-auto.js';

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
