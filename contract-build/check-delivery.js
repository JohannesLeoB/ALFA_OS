/* Export 21.10.2026 · Port von DESIGN/brief/check_delivery.py (P4). Aufruf (async): new AsyncFunction('ctx', code)(ctx) liefert { exit, lines }.
   ctx = { V: Ergebnis von validate.js, schema: delivery.schema.json, note: contract/LIEFERUNG.json oder null (+ noteProblem),
           brief: Text von BRIEF.txt, components: components.json (Objekt), drafts: { "ALFA Mail.dc.html": ArrayBuffer }, pruefung: Text von PRUEFUNG.txt oder null } */
const out = [];
const hex = async buf => [...new Uint8Array(await crypto.subtle.digest("SHA-256", buf))].map(b => b.toString(16).padStart(2, "0")).join("");
if (!ctx.note) { out.push("LIEFERUNG.json: " + (ctx.noteProblem || "missing"), "1 finding(s)"); return { exit: 1, lines: out }; }
const note = ctx.note;
const errs = ctx.V.errors(ctx.schema, note);
if (errs.length) { errs.slice(0, 20).forEach(e => out.push("LIEFERUNG.json: " + e)); out.push(errs.length + " finding(s)"); return { exit: 1, lines: out }; }
const wanted = ctx.brief.split("\n").filter(l => /^(T\d+|N\d+)\s/.test(l) && !l.includes("(entfällt)")).map(l => l.match(/^(T\d+|N\d+)\s/)[1]);
const given = note.items.map(i => i.id);
const findings = [];
for (const i of wanted) if (!given.includes(i)) findings.push("item missing in delivery note: " + i);
for (const i of [...new Set(given.filter(i => given.filter(x => x === i).length > 1))].sort()) findings.push("item twice in delivery note: " + i);
for (const i of [...new Set(given)].filter(i => !wanted.includes(i)).sort()) findings.push("item not in the brief: " + i);
const drafts = Object.fromEntries(note.drafts.map(d => [d.file, d.sha256]));
for (const name of Object.keys(ctx.drafts).sort()) if (name.endsWith(".dc.html") && !(name in drafts)) findings.push("draft not in delivery note: " + name);
const lines = {};
for (const name of Object.keys(drafts).sort()) {
  const buf = ctx.drafts[name];
  if (!buf) { findings.push("draft missing in project/: " + name); continue; }
  if ((await hex(buf)) !== drafts[name]) findings.push("draft changed after the delivery note: " + name);
  lines[name] = new TextDecoder().decode(buf).split("\n").length;
}
const ids = new Set(((ctx.components || {}).components || []).flatMap(c => (c.elements || []).map(e => e.id)));
for (const item of note.items) {
  for (const ref of item.where || []) {
    const k = ref.lastIndexOf(":"), name = ref.slice(0, k), line = +ref.slice(k + 1);
    if (!(name in drafts)) findings.push(item.id + ": " + name + " is not in drafts");
    else if (name in lines && !(line >= 1 && line <= lines[name])) findings.push(item.id + ": line " + line + " does not exist in " + name);
  }
  if (item.status === "done") for (const i of item.ids || []) if (!ids.has(i)) findings.push(item.id + ": element id " + i + " not in components.json");
}
if (!ctx.pruefung || !ctx.pruefung.trim()) findings.push("contract/PRUEFUNG.txt missing or empty");
out.push(...findings);
const done = new Set(note.items.filter(i => i.status === "done").map(i => i.id).filter(i => wanted.includes(i))).size;
out.push("items: " + done + " of " + wanted.length + " done");
out.push(findings.length ? findings.length + " finding(s)" : "delivery: complete");
return { exit: findings.length ? 1 : 0, lines: out, wanted };
