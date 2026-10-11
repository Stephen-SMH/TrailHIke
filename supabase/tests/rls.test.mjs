// Integration test for the database rules. Runs against a Supabase instance:
//   API_URL=... ANON_KEY=... node supabase/tests/rls.test.mjs
// Uses real anonymous users, so it checks the same paths the app uses.
import assert from 'node:assert/strict';

const API = process.env.API_URL ?? 'http://127.0.0.1:54421';
const KEY = process.env.ANON_KEY;
if (!KEY) throw new Error('set ANON_KEY');

async function user(name) {
  const r = await fetch(`${API}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: KEY, 'Content-Type': 'application/json' },
    body: '{}',
  });
  const j = await r.json();
  assert.ok(j.access_token, `anonymous sign-in failed: ${JSON.stringify(j)}`);
  const h = {
    apikey: KEY,
    Authorization: `Bearer ${j.access_token}`,
    'Content-Type': 'application/json',
  };
  const rpc = async (fn, args = {}) => {
    const res = await fetch(`${API}/rest/v1/rpc/${fn}`, {
      method: 'POST', headers: h, body: JSON.stringify(args),
    });
    const text = await res.text();
    return { ok: res.ok, status: res.status, body: text ? JSON.parse(text) : null };
  };
  const table = async (t, query = '') => {
    const res = await fetch(`${API}/rest/v1/${t}${query}`, { headers: h });
    const text = await res.text();
    return { ok: res.ok, status: res.status, body: text ? JSON.parse(text) : null };
  };
  const insert = async (t, row) => {
    const res = await fetch(`${API}/rest/v1/${t}`, {
      method: 'POST', headers: h, body: JSON.stringify(row),
    });
    return { ok: res.ok, status: res.status };
  };
  return { id: j.user.id, name, rpc, table, insert };
}

// Random spot per run, so leftovers from earlier runs are never in range.
const L = Math.round((Math.random() * 100 - 50) * 1000) / 1000;
const O = Math.round((Math.random() * 300 - 150) * 1000) / 1000;
const near = (d) => Number(d.toFixed(3));

let passed = 0;
const test = async (name, fn) => {
  await fn();
  passed++;
  console.log(`ok - ${name}`);
};

const a = await user('Alice Victim');   // 0.000, 0.000
const b = await user('Bob Helper');     // ~440 m away
const c = await user('Carl Faraway');   // ~111 km away
const d = await user('Dan Outsider');   // nearby but never shares presence

await a.rpc('set_presence', { p_lat: L, p_lon: O, p_name: a.name });
await b.rpc('set_presence', { p_lat: L + 0.004, p_lon: O + 0.0021, p_name: b.name });
await c.rpc('set_presence', { p_lat: L + 1.0, p_lon: O, p_name: c.name });

await test('nearby hikers: radius, fuzzed position, first name only', async () => {
  const r = await a.rpc('nearby_hikers', { p_lat: L, p_lon: O, p_radius_m: 5000 });
  assert.equal(r.ok, true, JSON.stringify(r.body));
  assert.equal(r.body.length, 1);
  assert.equal(r.body[0].name, 'Bob');
  assert.equal(r.body[0].lat, near(L + 0.004)); // rounded to 3 decimals
  assert.equal(r.body[0].lon, near(O + 0.0021)); // exact spot hidden
  assert.ok(!r.body.some((h) => h.id === a.id), 'never lists yourself');
});

await test('presence table cannot be read directly', async () => {
  const r = await b.table('presence', '?select=*');
  assert.ok(!r.ok || r.body.length === 0, `leaked: ${JSON.stringify(r.body)}`);
});

await test('cannot write presence or incidents directly', async () => {
  const w1 = await a.insert('presence', { user_id: a.id, name: 'x', geom: 'POINT(0 0)' });
  const w2 = await a.insert('incidents', { victim_id: a.id, victim_name: 'x', geom: 'POINT(0 0)' });
  assert.equal(w1.ok, false);
  assert.equal(w2.ok, false);
});

let incident;
await test('SOS: created, visible to nearby hiker only', async () => {
  const r = await a.rpc('create_incident', {
    p_lat: L, p_lon: O, p_name: a.name, p_note: 'twisted ankle',
  });
  assert.equal(r.ok, true, JSON.stringify(r.body));
  incident = r.body;
  const near = await b.rpc('nearby_incidents', { p_lat: L + 0.004, p_lon: O + 0.0021, p_radius_m: 5000 });
  assert.equal(near.body.length, 1);
  assert.equal(near.body[0].victim_name, 'Alice Victim');
  assert.equal(near.body[0].note, 'twisted ankle');
  const far = await c.rpc('nearby_incidents', { p_lat: L + 1, p_lon: O, p_radius_m: 5000 });
  assert.equal(far.body.length, 0);
  const own = await a.rpc('nearby_incidents', { p_lat: L, p_lon: O, p_radius_m: 5000 });
  assert.equal(own.body.length, 0, 'victim does not see own SOS as one to answer');
});

await test('incidents table: readable by victim and in-range hikers only', async () => {
  assert.equal((await a.table('incidents')).body.length, 1);
  assert.equal((await b.table('incidents')).body.length, 1);
  assert.equal((await c.table('incidents')).body.length, 0);
  assert.equal((await d.table('incidents')).body.length, 0);
});

await test('only someone in range can respond', async () => {
  const far = await c.rpc('respond_to_incident', { p_incident: incident });
  assert.equal(far.ok, false);
  const noPresence = await d.rpc('respond_to_incident', { p_incident: incident });
  assert.equal(noPresence.ok, false);
  const near = await b.rpc('respond_to_incident', { p_incident: incident });
  assert.equal(near.ok, true, JSON.stringify(near.body));
  const again = await b.rpc('respond_to_incident', { p_incident: incident });
  assert.equal(again.ok, true); // idempotent
  const list = await b.rpc('my_incident', { p_id: incident });
  assert.deepEqual(list.body[0].responder_ids, [b.id]);
});

await test('chat: participants can talk, outsiders see and write nothing', async () => {
  const m1 = await b.insert('messages', {
    incident_id: incident, sender_id: b.id, sender_name: 'Bob', body: 'On my way',
  });
  assert.equal(m1.ok, true);
  const m2 = await a.insert('messages', {
    incident_id: incident, sender_id: a.id, sender_name: 'Alice', body: 'Thank you',
  });
  assert.equal(m2.ok, true);
  assert.equal((await a.table('messages', '?select=body&order=created_at')).body.length, 2);
  assert.equal((await b.table('messages')).body.length, 2);
  assert.equal((await c.table('messages')).body.length, 0);
  const spoof = await b.insert('messages', {
    incident_id: incident, sender_id: a.id, sender_name: 'Alice', body: 'fake',
  });
  assert.equal(spoof.ok, false, 'cannot send as someone else');
  const outsider = await c.insert('messages', {
    incident_id: incident, sender_id: c.id, sender_name: 'Carl', body: 'hi',
  });
  assert.equal(outsider.ok, false);
});

await test('only the victim can resolve; resolved SOS disappears and chat closes', async () => {
  assert.equal((await b.rpc('resolve_incident', { p_incident: incident })).ok, true); // no-op
  assert.equal((await b.rpc('nearby_incidents', { p_lat: L + 0.004, p_lon: O + 0.0021, p_radius_m: 5000 })).body.length, 1);
  await a.rpc('resolve_incident', { p_incident: incident });
  assert.equal((await b.rpc('nearby_incidents', { p_lat: L + 0.004, p_lon: O + 0.0021, p_radius_m: 5000 })).body.length, 0);
  const late = await b.insert('messages', {
    incident_id: incident, sender_id: b.id, sender_name: 'Bob', body: 'too late',
  });
  assert.equal(late.ok, false);
});

await test('SOS rate limit: 3 per hour', async () => {
  const e = await user('Eve Spammer');
  for (let i = 0; i < 3; i++) {
    const r = await e.rpc('create_incident', { p_lat: 5, p_lon: 5, p_name: 'Eve', p_note: '' });
    assert.equal(r.ok, true);
  }
  const fourth = await e.rpc('create_incident', { p_lat: 5, p_lon: 5, p_name: 'Eve', p_note: '' });
  assert.equal(fourth.ok, false);
});

await test('bad input is rejected; leaving presence hides you', async () => {
  assert.equal((await a.rpc('set_presence', { p_lat: 999, p_lon: O, p_name: 'x' })).ok, false);
  assert.equal((await a.rpc('create_incident', { p_lat: L, p_lon: 400, p_name: 'x', p_note: '' })).ok, false);
  await b.rpc('clear_presence');
  const r = await a.rpc('nearby_hikers', { p_lat: L, p_lon: O, p_radius_m: 5000 });
  assert.equal(r.body.length, 0);
});

await test('internal functions are not callable by users', async () => {
  assert.equal((await a.rpc('cleanup')).ok, false);
});

await test('anonymous (not signed in) callers get nothing', async () => {
  const res = await fetch(`${API}/rest/v1/rpc/nearby_hikers`, {
    method: 'POST',
    headers: { apikey: KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_lat: L, p_lon: O, p_radius_m: 5000 }),
  });
  assert.equal(res.ok, false);
});

console.log(`\n${passed} passed`);
