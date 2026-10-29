/* Export 21.10.2026 · T9: contract/base.tokens.json → CSS-Variablen (:root-Block für alfa-theme.css). Aufruf: new Function('base', code)(baseJson) → String.
   Name: "--" + Tokenpfad, Punkte → "-" (size.edge → --size-edge). Nur Gruppen size, spacing, radius, opacity, scale, motion, typography, count, layer, confirm (29.10.: Johannes „ja“, Bestätigen liest Radieren/Zittern). */
const flat = (o, p, out) => { for (const [k, v] of Object.entries(o)) { if (k.startsWith("$")) continue; const pp = p ? p + "." + k : k; if (v && typeof v === "object" && "$value" in v) out.push([pp, v]); else if (v && typeof v === "object") flat(v, pp, out); } return out; };
const val = (k, t) => { const v = t.$value; if (typeof v === "string" && /^\{.*\}$/.test(v)) return "var(--" + v.slice(1, -1).replace(/\./g, "-") + ")";
  if (t.$type === "dimension" || t.$type === "duration") return v.value + v.unit;
  if (k.startsWith("typography.tracking.")) return v + "em";
  if (t.$type === "number" || t.$type === "fontWeight") return String(v);
  if (t.$type === "cubicBezier") return "cubic-bezier(" + v.join(",") + ")";
  if (t.$type === "fontFamily") return Array.isArray(v) ? v.map(x => /\s/.test(x) ? '"' + x + '"' : x).join(",") : v;
  return null; };
const rows = flat(base, "", []).filter(([k]) => /^(size|spacing|radius|opacity|scale|ratio|motion|typography\.(size|weight|tracking|lineHeight|family)|count|layer|confirm)/.test(k)).map(([k, t]) => [k, val(k, t)]).filter(r => r[1] !== null);
return ":root{" + rows.map(([k, v]) => "--" + k.replace(/\./g, "-") + ":" + v).join(";") + "}";
