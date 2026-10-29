/* Export 19.10.2026 · Port von DESIGN/brief/validate.py (JS, gleiche Schlüsselwörter). Aufruf: new Function(code)() liefert { errors(schema, value), contractCheck(files) } */
const TYPES = { object: v => v !== null && typeof v === "object" && !Array.isArray(v), array: v => Array.isArray(v), string: v => typeof v === "string", number: v => typeof v === "number", integer: v => Number.isInteger(v), boolean: v => typeof v === "boolean", null: v => v === null };
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
class Validator {
  constructor(root) { this.root = root; }
  resolve(ref) { let n = this.root; for (const p of ref.slice(2).split("/")) n = n[p.replace(/~1/g, "/").replace(/~0/g, "~")]; return n; }
  errors(s, v, path) {
    let out = [];
    if (s.$ref) out = out.concat(this.errors(this.resolve(s.$ref), v, path));
    if (s.type !== undefined) { const names = Array.isArray(s.type) ? s.type : [s.type]; if (!names.some(n => TYPES[n](v))) return out.concat([path + ": type " + names.join("/") + " expected"]); }
    if (s.enum && !s.enum.some(e => eq(e, v))) out.push(path + ": value " + JSON.stringify(v) + " not in " + JSON.stringify(s.enum));
    if ("const" in s && !eq(v, s.const)) out.push(path + ": value " + JSON.stringify(v) + " is not " + JSON.stringify(s.const));
    if (typeof v === "string") { if (s.pattern && !new RegExp(s.pattern).test(v)) out.push(path + ": " + JSON.stringify(v) + " does not match " + s.pattern); if (v.length < (s.minLength || 0)) out.push(path + ": string too short"); if (s.maxLength !== undefined && v.length > s.maxLength) out.push(path + ": string too long"); }
    if (TYPES.number(v)) { if (s.minimum !== undefined && v < s.minimum) out.push(path + ": " + v + " < " + s.minimum); if (s.maximum !== undefined && v > s.maximum) out.push(path + ": " + v + " > " + s.maximum); }
    if (TYPES.object(v)) {
      for (const k of s.required || []) if (!(k in v)) out.push(path + ": missing " + k);
      if (Object.keys(v).length < (s.minProperties || 0)) out.push(path + ": too few properties");
      const props = s.properties || {}, pats = s.patternProperties || {};
      for (const [k, sub] of Object.entries(v)) { const p = path + "/" + k; if (s.propertyNames) out = out.concat(this.errors(s.propertyNames, k, p + "(name)")); let m = false; if (k in props) { m = true; out = out.concat(this.errors(props[k], sub, p)); } for (const [pat, ps] of Object.entries(pats)) if (new RegExp(pat).test(k)) { m = true; out = out.concat(this.errors(ps, sub, p)); } if (!m) { const extra = "additionalProperties" in s ? s.additionalProperties : true; if (extra === false) out.push(p + ": property not allowed"); else if (TYPES.object(extra)) out = out.concat(this.errors(extra, sub, p)); } }
    }
    if (Array.isArray(v)) {
      if (v.length < (s.minItems || 0)) out.push(path + ": too few items"); if (s.maxItems !== undefined && v.length > s.maxItems) out.push(path + ": too many items");
      const pre = s.prefixItems || []; v.forEach((it, i) => { if (i < pre.length) out = out.concat(this.errors(pre[i], it, path + "[" + i + "]")); else if (s.items) out = out.concat(this.errors(s.items, it, path + "[" + i + "]")); });
    }
    for (const sub of s.allOf || []) out = out.concat(this.errors(sub, v, path));
    if (s.anyOf && !s.anyOf.some(x => !this.errors(x, v, path).length)) out.push(path + ": matches no allowed form");
    if (s.if) { if (!this.errors(s.if, v, path).length) { if (s.then) out = out.concat(this.errors(s.then, v, path)); } else if (s.else) out = out.concat(this.errors(s.else, v, path)); }
    return out;
  }
}
const MAP = [[".tokens.json", "alfa.tokens.schema.json"], ["alfa.resolver.json", "alfa.resolver.schema.json"], ["components.json", "components.schema.json"], ["views.json", "views.schema.json"], ["texts.json", "texts.schema.json"], ["changes.json", "changes.schema.json"]];
return { Validator, MAP, errors: (schema, value) => new Validator(schema).errors(schema, value, "#") };
