// Marca la conformidad de exportación (usesNonExemptEncryption=false) de un build en App Store Connect,
// requisito para que aparezca en TestFlight. Sin fastlane: JWT ES256 con la llave de API de ASC.
// Uso: node scripts/asc-compliance.mjs <buildNumber> [--esperar]
// La llave .p8 NO va en el repo: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';

const KEY_ID = process.env.ASC_KEY_ID || 'A37CJ5YGPP';
const ISSUER = process.env.ASC_ISSUER_ID || 'c9494c00-813d-4353-9e8c-fe2c1e53f871';
const APP = process.env.ASC_APP_ID || '6810498394'; // OhmSafe Installer (com.ohmsafe.instalador)
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

const want = process.argv[2];
const esperar = process.argv.includes('--esperar');
for (let intento = 0; intento < (esperar ? 40 : 1); intento++) {
  const r = await fetch(`${api}/v1/builds?filter[app]=${APP}&sort=-uploadedDate&limit=6`, { headers: H() });
  const builds = await r.json();
  if (!builds.data) { console.log(JSON.stringify(builds).slice(0, 300)); process.exit(1); }
  if (!want) { for (const b of builds.data) console.log(`build ${b.attributes.version} | ${b.attributes.processingState} | usesNonExemptEncryption=${b.attributes.usesNonExemptEncryption}`); process.exit(0); }
  const b = builds.data.find((x) => x.attributes.version === want);
  if (!b) { if (!esperar) { console.log(`build ${want} aun no aparece en ASC`); process.exit(2); } await new Promise((s) => setTimeout(s, 45_000)); continue; }
  if (b.attributes.usesNonExemptEncryption === false) { console.log(`build ${want} ya tenia compliance = false (${b.attributes.processingState})`); process.exit(0); }
  const p = await fetch(`${api}/v1/builds/${b.id}`, { method: 'PATCH', headers: H(), body: JSON.stringify({ data: { type: 'builds', id: b.id, attributes: { usesNonExemptEncryption: false } } }) });
  console.log(p.ok ? `compliance marcado en build ${want}` : `error ${p.status}: ${(await p.text()).slice(0, 300)}`);
  process.exit(p.ok ? 0 : 1);
}
console.log(`build ${want} no apareció tras esperar`); process.exit(2);
