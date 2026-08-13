const assert = require('assert');
const fs = require('fs');
const path = require('path');

class ClassList {
  constructor() { this.values = new Set(); }
  add(value) { this.values.add(value); }
  remove(value) { this.values.delete(value); }
  contains(value) { return this.values.has(value); }
}

function makeMetric(name) {
  const card = { classList: new ClassList(), offsetWidth: 1 };
  return {
    dataset: { stat: name },
    classList: new ClassList(),
    offsetWidth: 1,
    textContent: '',
    closest(selector) { return selector === '.proof-card' ? card : null; },
    card,
  };
}

(async () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'website', 'index.html'), 'utf8');
  const source = html.split('<script>')[1].split('</script>')[0];
  const names = ['users', 'active7d', 'active60m', 'launchesToday', 'totalLaunches', 'totalApplies', 'totalApplyOk'];
  const metrics = names.map(makeMetric);
  const byName = new Map(metrics.map(metric => [metric.dataset.stat, metric]));
  const status = { textContent: '' };
  let stats = Object.fromEntries(names.map(name => [name, 10]));
  stats.generatedAt = 1786600000;
  stats.trends = {};
  let intervalCallback = null;
  let timerId = 0;
  const timers = new Map();

  global.window = { matchMedia: () => ({ matches: true }) };
  global.document = {
    getElementById: id => id === 'publicStatsStatus' ? status : null,
    querySelectorAll: selector => selector === '[data-stat]' ? metrics : [],
  };
  global.localStorage = { getItem: () => null, setItem: () => {} };
  global.crypto = { randomUUID: () => '11111111-1111-4111-8111-111111111111' };
  global.fetch = async url => {
    if (url === '/report/website-visit') return { ok: true };
    if (url === '/report/public-stats') return { ok: true, json: async () => stats };
    throw new Error(`unexpected URL: ${url}`);
  };
  global.setInterval = callback => { intervalCallback = callback; return 1; };
  global.setTimeout = (callback, delay) => {
    const id = ++timerId;
    timers.set(id, { callback, delay });
    return id;
  };
  global.clearTimeout = id => timers.delete(id);

  new Function(source)();
  await new Promise(resolve => setImmediate(resolve));
  await new Promise(resolve => setImmediate(resolve));

  assert(intervalCallback, 'statistics refresh interval was not registered');
  for (const metric of metrics) {
    assert(!metric.classList.contains('stat-changed'), 'initial load highlighted a metric');
    assert(!metric.card.classList.contains('stat-changed'), 'initial load highlighted a card');
  }

  stats = { ...stats, users: 11, totalApplyOk: 14, generatedAt: stats.generatedAt + 15 };
  await intervalCallback();

  for (const name of ['users', 'totalApplyOk']) {
    assert(byName.get(name).classList.contains('stat-changed'), `${name} value was not highlighted`);
    assert(byName.get(name).card.classList.contains('stat-changed'), `${name} card was not highlighted`);
  }
  assert(!byName.get('active7d').classList.contains('stat-changed'), 'unchanged metric was highlighted');
  assert.equal(byName.get('users').textContent, '11');
  assert.equal(byName.get('totalApplyOk').textContent, '14');
  assert([...timers.values()].every(timer => timer.delay === 1400), 'highlight duration changed unexpectedly');

  for (const timer of [...timers.values()]) timer.callback();
  assert(!byName.get('users').classList.contains('stat-changed'), 'value highlight did not clear');
  assert(!byName.get('users').card.classList.contains('stat-changed'), 'card highlight did not clear');

  console.log('website statistic highlight tests passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
