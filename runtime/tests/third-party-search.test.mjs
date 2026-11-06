import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeSearchSources, makeSearchProvider, SEARCH_API_KEYS } from '../bridge/dsh-go-bridge/lib/third-party-search.js';
test('third-party providers select the exact credential reference', () => {
  assert.equal(SEARCH_API_KEYS['chemclaw-tavily'], 'TAVILY_API_KEY');
  assert.equal(SEARCH_API_KEYS['chemclaw-serper'], 'SERPER_API_KEY');
});
test('Brave, Tavily and Serper responses yield real unique HTTP(S) sources only', () => {
  assert.deepEqual(normalizeSearchSources('chemclaw-brave', { web: { results: [
    { title: 'A', url: 'https://one.example', description: 'A source' },
    { title: 'duplicate', url: 'https://one.example' },
    { title: 'bad', url: 'file:///tmp/leak' },
  ] } }), [{ url: 'https://one.example/', title: 'A', snippet: 'A source' }]);
  assert.equal(normalizeSearchSources('chemclaw-tavily', { results: [{ title: 'T', url: 'https://t.example' }] }).length, 1);
  assert.equal(normalizeSearchSources('chemclaw-serper', { organic: [{ title: 'S', link: 'https://s.example' }] }).length, 1);
});
test('API search fails without a key and never sends a network request', async () => {
  const ctx = { get: () => undefined };
  const provider = makeSearchProvider(ctx, 'chemclaw-brave', () => { throw new Error('Unexpected request'); });
  await assert.rejects(provider.search({ query: 'methanol' }), /API key missing/);
});
