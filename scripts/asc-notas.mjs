// Pone las notas «Qué probar» de un build en TestFlight (App Store Connect, betaBuildLocalizations).
// Pedido de Dan (2026-10-17): cada build debe decir a qué API apunta, porque TestFlight actualiza solo
// al más nuevo y 47/48 (prod) y 49 (api-dev) conviven.
// Uso: node scripts/asc-notas.mjs <buildNumber> "<texto>"
// Misma llave de API que asc-compliance.mjs (~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8).
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';

const KEY_ID = process.env.ASC_KEY_ID || 'A37CJ5YGPP';
const ISSUER = process.env.ASC_ISSUER_ID || 'c9494c00-813d-4353-9e8c-fe2c1e53f871';
const APP = process.env.ASC_APP_ID || '6810498394';
const key = fs.readFileSync(`${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`, 'utf8');
const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const body = b64({ iss: ISSUER, iat: now, exp: now + 1100, aud: 'appstoreconnect-v1' });
  const sig = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${head}.${body}.${sig}`;
}
const api = 'https://api.appstoreconnect.apple.com';
const H = () => ({ Authorization: `Bearer ${jwt()}`, 'Content-Type': 'application/json' });

const [want, texto] = process.argv.slice(2);
if (!want || !texto) { console.error('Uso: node scripts/asc-notas.mjs <build> "<texto>"'); process.exit(1); }
const builds = await (await fetch(`${api}/v1/builds?filter[app]=${APP}&sort=-uploadedDate&limit=20`, { headers: H() })).json();
const b = builds.data?.find((x) => x.attributes.version === want);
if (!b) { console.log(`build ${want} no está en ASC`); process.exit(2); }
const locs = await (await fetch(`${api}/v1/builds/${b.id}/betaBuildLocalizations`, { headers: H() })).json();
const loc = locs.data?.find((l) => (l.attributes.locale || '').toLowerCase().startsWith('es')) ?? locs.data?.[0];
let r;
if (loc) {
  r = await fetch(`${api}/v1/betaBuildLocalizations/${loc.id}`, { method: 'PATCH', headers: H(), body: JSON.stringify({ data: { type: 'betaBuildLocalizations', id: loc.id, attributes: { whatsNew: texto } } }) });
} else {
  r = await fetch(`${api}/v1/betaBuildLocalizations`, { method: 'POST', headers: H(), body: JSON.stringify({ data: { type: 'betaBuildLocalizations', attributes: { locale: 'es-MX', whatsNew: texto }, relationships: { build: { data: { type: 'builds', id: b.id } } } } }) });
}
console.log(r.ok ? `notas puestas en build ${want}` : `error ${r.status}: ${(await r.text()).slice(0, 300)}`);
process.exit(r.ok ? 0 : 1);
