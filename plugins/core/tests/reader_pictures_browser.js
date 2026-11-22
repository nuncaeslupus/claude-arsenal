#!/usr/bin/env node
// reader_pictures_browser.js — pictures in reader notes, in a real browser.
//
// Not part of `make test`: CI has no Node or Playwright, so this runs where they
// are (`node plugins/core/tests/reader_pictures_browser.js`). The Python side —
// seeding from a .zip export, the reviewed copy's picture files, the 5.33.1
// export — is in reader_pictures_test.sh, which CI runs.
//
// One check per behaviour: a pasted screenshot shows as a thumbnail and survives
// a reload; a dropped file attaches; a large one is downscaled; the export is a
// .zip whose Markdown links each picture and carries it; that .zip imports into a
// clean browser; a 5.33.1 export imports into a later revision, reporting the
// note whose section is gone; a refused picture store is said out loud and the
// note text still saves; a text-only export is unchanged.
//
// Exit: 0 on PASS, 1 on FAIL.
'use strict';
const {chromium} = require('playwright');
const {execFileSync} = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const here = __dirname;
const READER = path.join(here, '..', 'skills', 'init', 'assets', 'scripts', 'create_reader.py');
const OLD_EXPORT = path.join(here, 'fixtures', 'yourproject-spec-v1-2026-11-22-1222-notes.md');
const base = fs.mkdtempSync(path.join(os.tmpdir(), 'reader-pics-'));
const repo = path.join(base, 'yourproject');
fs.mkdirSync(path.join(repo, 'status'), {recursive: true});
execFileSync('git', ['init', '-q', repo]);

function py(args) {
  let cmd = ['python3'];
  try { execFileSync('python3', ['-c', 'import markdown'], {stdio: 'ignore'}); }
  catch (e) { cmd = ['uv', 'run', '--quiet', '--with', 'markdown', 'python3']; }
  return execFileSync(cmd[0], cmd.slice(1).concat(args), {cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
}
function spec(rev, withThird) {
  fs.writeFileSync(path.join(repo, 'status', 'specification.md'),
    `# Widget Overhaul\n\n**Revision**: ${rev}\n\n## 1. Problem\n\nThe widget is bad.\n\nIt breaks on Tuesdays.\n\n` +
    `## 2. Options\n\nPatch it or rebuild it.\n` + (withThird ? `\n## 3. Removed later\n\nThis section goes away in revision 2.\n` : ''));
  const out = JSON.parse(py([READER, '--input', 'status/specification.md', '--output-dir', 'status', '--no-markdown', '--json']));
  return path.resolve(repo, out.html);
}

const failures = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${ok || !detail ? '' : ' — ' + detail}`);
  if (!ok) failures.push(name);
}

// A picture made in the page, so the test needs no image file on disk.
async function makePicture(page, w, h, noisy) {
  return page.evaluate(([w, h, noisy]) => new Promise(res => {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const g = c.getContext('2d'); g.fillStyle = '#3366cc'; g.fillRect(0, 0, w, h);
    if (noisy) { const d = g.getImageData(0, 0, w, h); for (let i = 0; i < d.data.length; i++) d.data[i] = (i * 2654435761) >>> 24; g.putImageData(d, 0, 0); }
    g.fillStyle = '#fff'; g.font = '40px sans-serif'; g.fillText('screenshot', 20, 60);
    c.toBlob(b => { window.__pic = new File([b], 'shot.png', {type: 'image/png'}); res(b.size); }, 'image/png');
  }), [w, h, noisy]);
}
async function pasteInto(page, sel) {
  await page.evaluate(sel => {
    const dt = new DataTransfer(); dt.items.add(window.__pic);
    document.querySelector(sel).dispatchEvent(new ClipboardEvent('paste', {clipboardData: dt, bubbles: true, cancelable: true}));
  }, sel);
}
async function dropOn(page, sel) {
  await page.evaluate(sel => {
    const dt = new DataTransfer(); dt.items.add(window.__pic);
    const el = document.querySelector(sel);
    el.dispatchEvent(new DragEvent('dragover', {dataTransfer: dt, bubbles: true, cancelable: true}));
    el.dispatchEvent(new DragEvent('drop', {dataTransfer: dt, bubbles: true, cancelable: true}));
  }, sel);
}
async function exportFile(page) {
  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#btn-export')]);
  const to = path.join(base, dl.suggestedFilename()); await dl.saveAs(to);
  await page.click('#modal-close');
  return to;
}
function zipList(zip) {
  return JSON.parse(execFileSync('python3', ['-c',
    'import json,sys,zipfile;z=zipfile.ZipFile(sys.argv[1]);' +
    'print(json.dumps({n:(z.read(n).decode() if n.endswith(".md") else len(z.read(n))) for n in z.namelist()}))', zip], {encoding: 'utf8'}));
}
async function importFiles(page, files) {
  await page.setInputFiles('#file-import', files);
  await page.waitForFunction(() => /Imported|Could not|Choose/.test(document.getElementById('savestate').textContent + document.getElementById('toast').textContent));
  return page.evaluate(() => document.getElementById('savestate').textContent);
}

(async () => {
  const browser = await chromium.launch();
  try {
    const html1 = spec(1, true);
    const url1 = 'file://' + html1;

    // ---- paste → thumbnail → persisted after reload
    let ctx = await browser.newContext({acceptDownloads: true});
    let page = await ctx.newPage();
    await page.goto(url1);
    await makePicture(page, 400, 200, false);
    await pasteInto(page, '#n-s-spec-1');
    await page.waitForSelector('.note[data-for="s-spec-1"] .npic img');
    await page.waitForFunction(() => /Picture attached/.test(document.getElementById('toast').textContent));
    await page.reload();
    const after = await page.waitForSelector('.note[data-for="s-spec-1"] .npic img', {timeout: 5000}).then(() => true, () => false);
    check('pasted picture shows as a thumbnail and survives a reload', after);
    // enlarge / remove are keyboard-reachable buttons
    const btns = await page.$$eval('.note[data-for="s-spec-1"] .npic button', bs => bs.map(b => b.getAttribute('aria-label')));
    check('thumbnail has enlarge and remove buttons', btns.length === 2 && /enlarge/.test(btns[0]) && /Remove/.test(btns[1]), JSON.stringify(btns));

    // ---- drop of a large picture → attached, downscaled to 1600 px on its long edge
    await makePicture(page, 3200, 1800, true);
    await dropOn(page, '.note[data-for="s-spec-2"]');
    await page.waitForSelector('.note[data-for="s-spec-2"] .npic img');
    const dims = await page.$eval('.note[data-for="s-spec-2"] .npic img', im => im.decode().then(() => [im.naturalWidth, im.naturalHeight]));
    check('dropped picture attaches, downscaled to 1600 px', dims[0] === 1600 && dims[1] === 900, JSON.stringify(dims));
    await page.fill('#n-s-spec-2', 'Look at this.');

    // ---- export → .zip with the Markdown and its pictures, linked by path
    const zip = await exportFile(page);
    const entries = zipList(zip);
    const md = Object.keys(entries).find(n => n.endsWith('.md'));
    const imgs = Object.keys(entries).filter(n => /-img\/\d\d\.(png|jpg)$/.test(n));
    const text = md ? entries[md] : '';
    check('export with pictures is a .zip holding the notes and each picture',
      /\.zip$/.test(zip) && md && imgs.length === 2 && imgs.every(n => entries[n] > 100), JSON.stringify(Object.keys(entries)));
    check('the exported Markdown links each picture and maps it to its note',
      imgs.every(n => text.includes('](<' + n + '>)')) && /<!-- SPEC-NOTES-PICTURES\n\{"s-spec-1":\["[^"]+01\.png"\],"s-spec-2":\["[^"]+02\.jpg"\]\}/.test(text),
      text.slice(-400));
    check('the export is not inlined base64', !/data:image/.test(text));
    let seeded = '';
    try { py([READER, '--input', 'status/specification.md', '--output-dir', path.join(base, 'seeded'), '--notes', zip, '--no-markdown']); seeded = 'ok'; }
    catch (e) { seeded = String(e.stderr || e); }
    check('create_reader.py --notes reads that .zip', seeded === 'ok', seeded);
    await ctx.close();

    // ---- import the .zip into a clean browser
    ctx = await browser.newContext();
    // Opening the picture store takes 800 ms here, so a paste can land before the
    // stored pictures are read — the window a slow disk opens for real.
    await ctx.addInitScript(() => {
      const open = IDBFactory.prototype.open;
      IDBFactory.prototype.open = function (...a) {
        const fake = {}, self = this;
        setTimeout(() => {
          const r = open.apply(self, a);
          ['upgradeneeded', 'success', 'error'].forEach(ev => {
            r['on' + ev] = () => { fake.result = r.result; fake.error = r.error; if (fake['on' + ev]) fake['on' + ev](); };
          });
        }, 800);
        return fake;
      };
    });
    page = await ctx.newPage();
    await page.goto(url1);
    const st = await importFiles(page, zip);
    const n = await page.$$eval('.npic img', ims => ims.length);
    check('importing the .zip restores notes and pictures', n === 2 && /2 pictures/.test(st), st + ' / ' + n);
    // a picture added right after load joins the stored ones; it does not replace them
    await page.reload();
    await makePicture(page, 120, 80, false);
    await pasteInto(page, '#n-s-spec-1');
    await page.waitForFunction(() => document.querySelectorAll('.note[data-for="s-spec-1"] .npic img').length >= 2, null, {timeout: 5000}).catch(() => {});
    await page.waitForTimeout(300);
    await page.reload();
    await page.waitForSelector('.note[data-for="s-spec-1"] .npic img', {timeout: 5000}).catch(() => {});
    await page.waitForTimeout(300);
    const kept = await page.$$eval('.note[data-for="s-spec-1"] .npic img', ims => ims.length);
    check('a picture pasted while stored ones load is added to them', kept === 2, String(kept));
    // a block note blurred while its picture is still being prepared keeps it
    const host = await page.$('.bn-host:has-text("Tuesdays")'); await host.hover(); await (await host.$('.bn-btn')).click();
    const bkey = await page.$eval('.bnote .note-ta', t => t.dataset.key);
    await makePicture(page, 3200, 1800, true);
    await page.evaluate(k => {
      const box = document.querySelector('.bnote .note-ta[data-key="' + k + '"]').closest('.note');
      const dt = new DataTransfer(); dt.items.add(window.__pic);
      box.dispatchEvent(new DragEvent('drop', {dataTransfer: dt, bubbles: true, cancelable: true}));
      document.querySelector('.bnote .note-ta[data-key="' + k + '"]').blur();
    }, bkey);
    await page.waitForSelector('.bnote .npic img', {timeout: 5000}).catch(() => {});
    const zb = zipList(await exportFile(page));
    const zmd = zb[Object.keys(zb).find(x => x.endsWith('.md'))] || '';
    check('a block note blurred before its picture lands keeps it in the export',
      zmd.includes('"' + bkey + '":["'), zmd.slice(-300));
    await ctx.close();

    // ---- a 5.33.1 export into a later revision whose section 3 is gone
    const html2 = spec(2, false);
    ctx = await browser.newContext(); page = await ctx.newPage();
    page.on('dialog', d => d.accept());  // "notes for -v1, not this page (-v2)": the expected question
    await page.goto('file://' + html2);
    const st2 = await importFiles(page, OLD_EXPORT);
    const vals = await page.evaluate(() => ({
      sec: document.querySelector('#n-s-spec-1').value,
      block: Array.from(document.querySelectorAll('.bnote .note-ta')).map(t => t.value),
      unplaced: Array.from(document.querySelectorAll('#bn-unplaced .note-ta')).map(t => t.value)}));
    check('a 5.33.1 export imports into a regenerated reader',
      vals.sec === 'Section note on problem.\nSecond line.' && vals.block.includes('Block note on Tuesdays'), JSON.stringify(vals));
    check('a note whose section is gone is kept and reported',
      vals.unplaced.includes('Note on a section that will vanish') && /1 under “Unplaced notes”/.test(st2), st2);
    // text-only export is unchanged: a .md, no pictures block
    const mdOnly = await exportFile(page);
    const t2 = fs.readFileSync(mdOnly, 'utf8');
    check('a text-only export is still a single .md', /-notes\.md$/.test(mdOnly) && !t2.includes('SPEC-NOTES-PICTURES') && t2.includes('SPEC-NOTES-DATA'));
    await ctx.close();

    // ---- the picture store refuses (quota): said out loud, nothing dropped
    ctx = await browser.newContext({acceptDownloads: true});
    await ctx.addInitScript(() => {
      IDBObjectStore.prototype.put = function () { throw new DOMException('full', 'QuotaExceededError'); };
    });
    page = await ctx.newPage();
    await page.goto('file://' + html2);  // a rebuild removed the revision-1 reader
    await page.fill('#n-s-spec-1', 'text survives');
    await makePicture(page, 300, 150, false);
    await pasteInto(page, '#n-s-spec-1');
    const warned = await page.waitForSelector('.note[data-for="s-spec-1"] .npic-warn', {timeout: 5000}).then(() => true, () => false);
    const state = await page.$eval('#savestate', e => e.textContent + '|' + e.className);
    const stored = await page.evaluate(() => { for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); if (/s-spec-1$/.test(k)) return localStorage.getItem(k); } return null; });
    check('a refused picture store warns in the note and the bar', warned && /Picture not stored/.test(state) && /warn/.test(state), state);
    check('the note text still saves when the picture cannot', stored === 'text survives', String(stored));
    const zq = zipList(await exportFile(page));
    check('the unstored picture is still in the export', Object.keys(zq).some(n => /-img\/01\.png$/.test(n)), JSON.stringify(Object.keys(zq)));
    // ...and leaving the page still warns, though the text was saved and exported
    let asked = false;
    page.on('dialog', d => { if (d.type() === 'beforeunload') asked = true; d.dismiss().catch(() => {}); });
    await page.click('h1');  // a user gesture, which Chromium needs before it will ask
    await page.close({runBeforeUnload: true});
    await new Promise(r => setTimeout(r, 500));
    check('leaving with an unstored picture warns', asked);
    await ctx.close();
  } finally {
    await browser.close();
    fs.rmSync(base, {recursive: true, force: true});
  }
  if (failures.length) { console.error(`FAIL: ${failures.length} check(s)`); process.exit(1); }
  console.log('PASS');
})().catch(e => { console.error('FAIL:', e); process.exit(1); });
