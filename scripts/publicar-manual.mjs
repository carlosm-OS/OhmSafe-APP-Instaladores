#!/usr/bin/env node
// =============================================================================
// Publica el manual de la app (docs/manual/*.md) en Odoo › Conocimiento.
//
// La FUENTE es este repo: el manual se edita aquí, en el mismo commit que el
// cambio de la app. Este script lo convierte a HTML y crea/actualiza un
// artículo por archivo bajo «Manual App OHMSAFE INSTALLER» (público en la web,
// sin indexar: robots.txt del sitio bloquea /knowledge). Los archivos cuyo
// nombre contiene «INTERNO» van a un artículo raíz aparte, SIN publicar.
//
// Uso (las credenciales de Odoo sólo existen en los servidores; nunca en git):
//   node scripts/publicar-manual.mjs --vista-previa      # escribe HTML en /tmp, no toca Odoo
//   ODOO_URL=… ODOO_DB=… ODOO_LOGIN=… ODOO_API_KEY=… \
//     node scripts/publicar-manual.mjs --publicar [--build 24]
// Sin dependencias: Node 18+ (fetch). El conversor cubre lo que usa el manual
// (títulos, párrafos, listas, tablas, negritas, cursivas, código, enlaces, citas).
// =============================================================================
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';

const RAIZ_PUBLICA = 'Manual App OHMSAFE INSTALLER';
const RAIZ_INTERNA = 'Manual App OHMSAFE INSTALLER — Guía SAC (interno)';
const dirManual = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'docs', 'manual');

const args = process.argv.slice(2);
const publicar = args.includes('--publicar');
const build = (() => { const i = args.indexOf('--build'); return i >= 0 ? args[i + 1] : leerBuild(); })();

function leerBuild() {
  try {
    const p = fs.readFileSync(path.join(dirManual, '..', '..', 'pubspec.yaml'), 'utf8');
    return (p.match(/^version:\s*\S+\+(\d+)/m) || [])[1] || '?';
  } catch { return '?'; }
}

// ---------------------------------------------------------------- Markdown → HTML
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
function inline(t) {
  const codigos = [];
  let s = esc(t).replace(/`([^`]+)`/g, (_, c) => { codigos.push(c); return `\u0000${codigos.length - 1}\u0000`; });
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, txt, url) => {
    const u = url.replace(/&amp;/g, '&');
    const destino = /^https?:\/\//.test(u) ? u : `#${u.replace(/\.md$/, '')}`;
    return `<a href="${esc(destino)}">${txt}</a>`;
  });
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/(^|[\s(«])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>').replace(/(^|[\s(«])_([^_\s][^_]*)_/g, '$1<em>$2</em>');
  return s.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${codigos[+i]}</code>`);
}
export function mdAHtml(md) {
  const L = md.replace(/\r/g, '').split('\n');
  const out = [];
  let i = 0;
  const lista = (ordenada, nivel) => {
    const items = [];
    const re = ordenada ? /^(\s*)\d+[.)]\s+(.*)$/ : /^(\s*)[-*+]\s+(.*)$/;
    while (i < L.length) {
      const m = L[i].match(/^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$/);
      if (!m) break;
      const ind = m[1].length;
      if (ind < nivel) break;
      if (ind > nivel) { // sublista
        const sub = /^\s*\d+[.)]\s/.test(L[i]);
        const html = lista(sub, ind);
        if (items.length) items[items.length - 1] += html; else items.push(html);
        continue;
      }
      if (!re.test(L[i])) break;
      let texto = m[2]; i++;
      while (i < L.length && L[i].trim() && !/^\s*(?:[-*+]|\d+[.)])\s+/.test(L[i]) && /^\s{2,}/.test(L[i])) { texto += ' ' + L[i].trim(); i++; }
      items.push(inline(texto));
    }
    const tag = ordenada ? 'ol' : 'ul';
    return `<${tag}>${items.map((x) => `<li>${x}</li>`).join('')}</${tag}>`;
  };
  while (i < L.length) {
    const l = L[i];
    if (!l.trim()) { i++; continue; }
    if (/^```/.test(l)) { const b = []; i++; while (i < L.length && !/^```/.test(L[i])) b.push(L[i++]); i++; out.push(`<pre><code>${esc(b.join('\n'))}</code></pre>`); continue; }
    const h = l.match(/^(#{1,4})\s+(.*)$/); if (h) { out.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); i++; continue; }
    if (/^(-{3,}|\*{3,})\s*$/.test(l)) { out.push('<hr/>'); i++; continue; }
    if (/^\s*\|/.test(l)) {
      const filas = []; while (i < L.length && /^\s*\|/.test(L[i])) filas.push(L[i++]);
      const celdas = (f) => f.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
      const cuerpo = filas.filter((f, k) => !(k === 1 && /^[\s|:-]+$/.test(f)));
      const [cab, ...resto] = cuerpo;
      out.push(`<table class="table table-bordered"><thead><tr>${celdas(cab).map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead><tbody>${resto.map((f) => `<tr>${celdas(f).map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`).join('')}</tbody></table>`);
      continue;
    }
    if (/^>\s?/.test(l)) { const b = []; while (i < L.length && /^>\s?/.test(L[i])) b.push(L[i++].replace(/^>\s?/, '')); out.push(`<blockquote>${mdAHtml(b.join('\n'))}</blockquote>`); continue; }
    if (/^\s*[-*+]\s+/.test(l)) { out.push(lista(false, l.match(/^\s*/)[0].length)); continue; }
    if (/^\s*\d+[.)]\s+/.test(l)) { out.push(lista(true, l.match(/^\s*/)[0].length)); continue; }
    const p = [l.trim()]; i++;
    while (i < L.length && L[i].trim() && !/^(#{1,4}\s|```|\s*[-*+]\s|\s*\d+[.)]\s|\s*\||>)/.test(L[i])) p.push(L[i++].trim());
    out.push(`<p>${inline(p.join(' '))}</p>`);
  }
  return out.join('\n');
}

// ---------------------------------------------------------------- Archivos
function articulos() {
  const archivos = fs.readdirSync(dirManual).filter((f) => f.endsWith('.md')).sort((a, b) => (a === 'README.md' ? -1 : b === 'README.md' ? 1 : a.localeCompare(b)));
  return archivos.map((f) => {
    const md = fs.readFileSync(path.join(dirManual, f), 'utf8');
    const titulo = (md.match(/^#\s+(.+)$/m) || [])[1]?.trim() || f.replace(/\.md$/, '');
    const cuerpoMd = md.replace(/^#\s+.+\n?/m, '');
    const pie = `<hr/><p><em>Versión de la app: 1.0.0 (${build}). Actualizado el ${new Date().toISOString().slice(0, 10)} desde el repositorio de la app; no edites este artículo en Odoo, se sobrescribe en la siguiente publicación.</em></p>`;
    return { archivo: f, titulo, interno: /INTERNO/i.test(f), readme: f === 'README.md', html: mdAHtml(cuerpoMd) + pie };
  });
}

// ---------------------------------------------------------------- Odoo (JSON-RPC)
async function odoo() {
  const { ODOO_URL, ODOO_DB, ODOO_LOGIN, ODOO_API_KEY } = process.env;
  if (!ODOO_URL || !ODOO_DB || !ODOO_LOGIN || !ODOO_API_KEY) throw new Error('Faltan ODOO_URL / ODOO_DB / ODOO_LOGIN / ODOO_API_KEY');
  const rpc = async (service, method, a) => {
    for (let intento = 1; ; intento++) {
      const r = await fetch(`${ODOO_URL}/jsonrpc`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', method: 'call', params: { service, method, args: a } }) });
      if (r.status === 429 && intento < 6) { await new Promise((ok) => setTimeout(ok, 5000 * intento)); continue; }
      const j = await r.json();
      if (j.error) throw new Error(j.error.data?.message || j.error.message);
      return j.result;
    }
  };
  const uid = await rpc('common', 'authenticate', [ODOO_DB, ODOO_LOGIN, ODOO_API_KEY, {}]);
  if (!uid) throw new Error('Odoo rechazó las credenciales');
  return (model, method, a = [], kw = {}) => rpc('object', 'execute_kw', [ODOO_DB, uid, ODOO_API_KEY, model, method, a, kw]);
}

async function upsert(x, nombre, vals, parentId) {
  const dom = [['name', '=', nombre], ['parent_id', '=', parentId || false]];
  const [ya] = await x('knowledge.article', 'search_read', [dom], { fields: ['id'], limit: 1 });
  if (ya) { await x('knowledge.article', 'write', [[ya.id], vals]); return ya.id; }
  return x('knowledge.article', 'create', [{ name: nombre, ...(parentId ? { parent_id: parentId } : {}), ...vals }]);
}

async function main() {
  const arts = articulos();
  if (!publicar) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'manual-'));
    for (const a of arts) fs.writeFileSync(path.join(dir, a.archivo.replace(/\.md$/, '.html')), `<meta charset="utf-8"><h1>${esc(a.titulo)}</h1>\n${a.html}`);
    console.log(`Vista previa (no se tocó Odoo): ${dir}`);
    for (const a of arts) console.log(` - ${a.interno ? '[INTERNO] ' : ''}${a.titulo}`);
    return;
  }
  const x = await odoo();
  const readme = arts.find((a) => a.readme);
  // Raíz pública: su cuerpo es el README (índice).
  const raiz = await upsert(x, RAIZ_PUBLICA, { body: readme ? readme.html : '<p></p>', internal_permission: 'write', is_published: true }, null);
  const interna = await upsert(x, RAIZ_INTERNA, { body: '<p>Uso interno de soporte y SAC. No se publica en la web.</p>', internal_permission: 'write', is_published: false }, null);
  let seq = 10;
  for (const a of arts.filter((y) => !y.readme)) {
    const id = await upsert(x, a.titulo, { body: a.html, sequence: seq, is_published: !a.interno }, a.interno ? interna : raiz);
    seq += 10;
    console.log(`${a.interno ? 'interno ' : 'público '} ${id}  ${a.titulo}`);
  }
  const [r] = await x('knowledge.article', 'read', [[raiz]], { fields: ['article_url', 'website_published'] });
  console.log(`Raíz pública ${raiz} publicada=${r.website_published} url=${r.article_url}`);
  console.log(`Raíz interna ${interna} (sin publicar)`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
