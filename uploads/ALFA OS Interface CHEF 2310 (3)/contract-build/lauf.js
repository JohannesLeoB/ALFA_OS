/* lauf.js · 28.10.2026 · ein Lauf: Änderungsprotokoll auf einen Block, Lieferschein (Prüfsummen), PRUEFUNG.txt, akte.json, Prüfer P1 bis P4 und pruefung.js.
   Aufruf im Skriptfenster: const AF = Object.getPrototypeOf(async function(){}).constructor;
   const r = await new AF("io","opt", await readFile("contract-build/lauf.js"))({ readFile, readFileBinary, saveFile, ls }, { stamp: "2026-10-28T16:00", write: false });
   opt.write false = nur messen (nichts schreiben). opt.items = { N37: { status: "done", where: ["ALFA Shell.dc.html:89"] } } setzt Lieferschein-Punkte (Felder: status, where, question).
   Vorher: Änderungen am Vertrag nur über contract-build/apply.js (Block je Lauf wird hier zu einem zusammengeführt). Basis: contract-build/previous/2026-10-23T-vor-uebergabe. */
const { readFile, readFileBinary, saveFile, ls } = io, J = async p => JSON.parse(await readFile(p));
const names = ["base.tokens.json", "theme-light.tokens.json", "theme-dark.tokens.json", "ground-lightGray.tokens.json", "alfa.resolver.json", "components.json", "views.json", "texts.json", "changes.json"];
const files = {}, old = {}; for (const n of names) { files[n] = await J("contract/" + n); old[n] = await J("contract-build/previous/2026-10-23T-vor-uebergabe/contract__" + n); }
const D = new Function(await readFile("contract-build/diff.js"))();
const oldN = old["changes.json"].blocks.length, why = {}; for (const b of files["changes.json"].blocks.slice(oldN - 1)) for (const c of b.changes) why[c.kind + "\u0000" + c.id] = c.reason;
const blk = D.makeBlock(old, files, opt.stamp, (k, id) => why[k + "\u0000" + id]);
const noReason = blk.changes.filter(c => c.reason === "Änderung im Vertrag").map(c => c.kind + " " + c.id);
files["changes.json"] = { blocks: [...old["changes.json"].blocks, blk] };
const r3 = D.check(old, files);
const V = new Function(await readFile("contract-build/validate.js"))(); let p1 = [];
for (const n of names) { const m = V.MAP.find(([s]) => n.endsWith(s)); p1 = p1.concat(V.errors(await J("DESIGN/brief/" + m[1]), files[n]).map(e => n + ": " + e)); }
const have = await ls(""), bogen = have.filter(f => f.endsWith(".dc.html")).sort();
const drafts = {}; for (const f of ["ALFA Mail.dc.html", "ALFA Einstellungen.dc.html", "ALFA Shell.dc.html", "ALFA Bestaetigen.dc.html"]) if (have.includes(f)) drafts[f] = await readFile(f);
const p2 = new Function(await readFile("contract-build/check.js"))().check(files, ["shell", "mail", "settings"], drafts);
const L = await J("contract/LIEFERUNG.json"); for (const [id, o] of Object.entries(opt.items || {})) { const it = L.items.find(i => i.id === id); if (!it) throw new Error("Punkt fehlt: " + id); if (o.status === "done") delete it.question; Object.assign(it, o); }
const hex = async b => [...new Uint8Array(await crypto.subtle.digest("SHA-256", b))].map(x => x.toString(16).padStart(2, "0")).join("");
const dr = {}; L.drafts = []; for (const f of bogen) { dr[f] = await (await readFileBinary(f)).arrayBuffer(); L.drafts.push({ file: f, sha256: await hex(dr[f]) }); } L.export = opt.stamp;
const txt = "P1 validate (contract/):\n" + (p1.length ? p1.join("\n") : "contract: valid") + "\n\nP2 check (--areas shell,mail,settings; Mail, Einstellungen, Shell, Bestaetigen):\n" + (p2.length ? p2.join("\n") : "consistent") + "\n\nP3 diff (Basis contract-build/previous/2026-10-23T-vor-uebergabe, " + r3.difference + " Änderungen, " + r3.logged + " im Protokoll):\n" + (r3.findings.length ? r3.findings.join("\n") : "log matches") + "\n\nLauf " + opt.stamp + "\n";
const AF = Object.getPrototypeOf(async function () {}).constructor;
const p4 = await new AF("ctx", await readFile("contract-build/check-delivery.js"))({ V, schema: await J("DESIGN/brief/delivery.schema.json"), note: L, brief: await readFile("DESIGN/brief/BRIEF.txt"), components: files["components.json"], drafts: dr, pruefung: txt });
const pj = await readFile("lieferung-an-code/pruefung.js"), root = {}; new Function("module", "window", "globalThis", pj)(undefined, root, root); const pr = await root.pruefe(async f => await readFile(f));
const lc = {}, whereBad = []; for (const it of L.items) for (const ref of it.where || []) { const k = ref.lastIndexOf(":"), f = ref.slice(0, k), n = +ref.slice(k + 1); lc[f] = lc[f] || new TextDecoder().decode(dr[f]).split("\n"); const l = (lc[f][n - 1] || "").trim(); if (!l || /^<\/|^\}\)?;?$/.test(l)) whereBad.push(it.id + " " + ref); }
const st = s => L.items.filter(i => i.status === s).map(i => i.id);
const rep = { P1: p1, P2: p2, P3: r3.findings, P3zahl: r3.difference + "/" + r3.logged, P4: p4.lines, pruefungJs: { gruen: pr.gruen, fehler: pr.fehler }, ohneGrund: noReason, lieferscheinWhereSchlusszeilen: whereBad, open: st("open"), question: st("question"), done: st("done").length, written: false };
if (!opt.write || p1.length || p2.length || r3.findings.length || p4.exit || !pr.gruen) return rep;
await saveFile("contract/changes.json", JSON.stringify(files["changes.json"], null, 2) + "\n"); await saveFile("contract/LIEFERUNG.json", JSON.stringify(L, null, 2) + "\n"); await saveFile("contract/PRUEFUNG.txt", txt);
const Ak = await J("contract/akte.json"), sizes = {}; for (const s of Ak.seiten) sizes[s.datei] = (await readFileBinary(s.datei)).size;
const out = new Function("akte", "sizes", "contract", "answered", await readFile("contract-build/t7-akte.js"))(Ak, sizes, files, Ak.answered); out.export = opt.stamp.slice(0, 10);
await saveFile("contract/akte.json", JSON.stringify(out, null, 2) + "\n"); await saveFile("lieferung-an-code/akte.json", JSON.stringify(out, null, 2) + "\n"); rep.written = true; return rep;
