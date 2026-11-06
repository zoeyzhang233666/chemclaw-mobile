// Optional commercial search APIs on DSH's normal web_search tool.
// All requests go to fixed HTTPS origins; keys come from DSH credentials.
export const name = 'chemclaw-third-party-search';
export const inject = ['web'];
export const SEARCH_API_KEYS = Object.freeze({
  'chemclaw-brave': 'BRAVE_SEARCH_API_KEY',
  'chemclaw-tavily': 'TAVILY_API_KEY',
  'chemclaw-serper': 'SERPER_API_KEY',
});
const endpoint = Object.freeze({
  'chemclaw-brave': 'https://api.search.brave.com/res/v1/web/search',
  'chemclaw-tavily': 'https://api.tavily.com/search',
  'chemclaw-serper': 'https://google.serper.dev/search',
});
const clean = x => typeof x === 'string' ? x.replace(/\s+/g, ' ').trim() : '';
const limit = v => Number.isFinite(v) ? Math.min(10, Math.max(1, Math.floor(v))) : 6;
const urlOf = value => {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.href : null;
  } catch { return null; }
};
export function normalizeSearchSources(id, body, max = 6) {
  const list = id === 'chemclaw-brave' ? body?.web?.results :
    id === 'chemclaw-tavily' ? body?.results : body?.organic;
  if (!Array.isArray(list)) return [];
  const seen = new Set(), out = [];
  for (const item of list) {
    const url = urlOf(item?.url || item?.link);
    if (!url || seen.has(url)) continue;
    seen.add(url);
    const title = clean(item?.title).slice(0, 240);
    const snippet = clean(item?.description || item?.content || item?.snippet).slice(0, 520);
    out.push({ url, ...(title ? { title } : {}), ...(snippet ? { snippet } : {}) });
    if (out.length >= max) break;
  }
  return out;
}
async function credential(ctx, ref) {
  const store = ctx.get('credentials');
  const result = store ? await store.resolve(ref) : null;
  return clean(result?.value || ctx.get('launchEnvironment')?.get(ref)?.value || '');
}
export function makeSearchProvider(ctx, id, fetchFn = fetch) {
  if (!(id in SEARCH_API_KEYS)) throw new Error('Unknown search backend');
  return {
    id,
    available: () => true,
    async search(request, signal) {
      const query = clean(request?.query).slice(0, 400);
      if (!query) throw new Error('A search query is required');
      const key = await credential(ctx, SEARCH_API_KEYS[id]);
      if (!key) throw new Error(id + ': API key missing. Configure it in ChemClaw Settings > Web Search.');
      const count = limit(request?.maxResults);
      const timeout = AbortSignal.timeout(15000);
      const abort = signal ? AbortSignal.any([signal, timeout]) : timeout;
      let url = endpoint[id], init = { signal: abort };
      if (id === 'chemclaw-brave') {
        url += '?q=' + encodeURIComponent(query) + '&count=' + count;
        init.headers = { 'Accept': 'application/json', 'X-Subscription-Token': key };
      } else if (id === 'chemclaw-tavily') {
        init = { ...init, method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + key },
          body: JSON.stringify({ query, max_results: count, search_depth: 'basic' }) };
      } else {
        init = { ...init, method: 'POST', headers: { 'Content-Type': 'application/json', 'X-API-KEY': key },
          body: JSON.stringify({ q: query, num: count }) };
      }
      const response = await fetchFn(url, init);
      if (!response.ok) throw new Error(id + ': HTTP ' + response.status);
      const size = Number(response.headers.get('content-length'));
      if (size > 512 * 1024) throw new Error('Search response too large');
      const raw = await response.text();
      if (raw.length > 512 * 1024) throw new Error('Search response too large');
      const sources = normalizeSearchSources(id, JSON.parse(raw), count);
      if (sources.length === 0) throw new Error(id + ': no verifiable search results');
      return { content: 'Search backend: ' + id + '. Sources are external pages; verify before using.',
        sources, truncated: false };
    },
  };
}
export function apply(ctx) {
  const disposers = Object.keys(SEARCH_API_KEYS).map(id => ctx.web.registerSearchProvider(makeSearchProvider(ctx, id)));
  ctx.effect(() => () => disposers.forEach(dispose => dispose()), 'chemclaw: third-party search');
}
