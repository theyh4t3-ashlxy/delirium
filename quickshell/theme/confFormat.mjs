// theme/confFormat.mjs — zero-JSON flat .conf serialization, record storage, and legacy migration parsers

/** Escape backslashes, newlines, and flat delimiter characters for lossless .conf values. */
export function escapeField(raw) {
    return String(raw ?? "")
        .replace(/\\/g, "\\\\")
        .replace(/\r/g, "\\r")
        .replace(/\n/g, "\\n")
        .replace(/=/g, "\\e")
        .replace(/,/g, "\\c")
        .replace(/;/g, "\\s")
        .replace(/\|/g, "\\p");
}

/** Restore escaped field string written by escapeField(). */
export function unescapeField(raw) {
    const s = String(raw ?? "");
    let out = "";
    for (let i = 0; i < s.length; i++) {
        const ch = s[i];
        if (ch === "\\" && i + 1 < s.length) {
            const nxt = s[i + 1];
            i++;
            if (nxt === "n") out += "\n";
            else if (nxt === "r") out += "\r";
            else if (nxt === "e") out += "=";
            else if (nxt === "c") out += ",";
            else if (nxt === "s") out += ";";
            else if (nxt === "p") out += "|";
            else out += nxt;
        } else {
            out += ch;
        }
    }
    return out;
}

function unquote(v) {
    let s = String(v ?? "").trim();
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
        return s.slice(1, -1);
    }
    return s;
}

/** Split an unescaped legacy JSON-like flat bracket array ['a','b'] without calling JSON.parse. */
function splitLegacyBracketList(s) {
    const inner = s.slice(1, -1).trim();
    if (!inner) return [];
    const items = [];
    let cur = "";
    let quote = "";
    let esc = false;
    for (let i = 0; i < inner.length; i++) {
        const c = inner[i];
        if (esc) { cur += c; esc = false; continue; }
        if (c === "\\") { cur += c; esc = true; continue; }
        if (quote) {
            if (c === quote) quote = "";
            else cur += c;
            continue;
        }
        if (c === '"' || c === "'") { quote = c; continue; }
        if (c === ",") {
            const t = cur.trim();
            if (t !== "") items.push(t);
            cur = "";
            continue;
        }
        cur += c;
    }
    const tail = cur.trim();
    if (tail !== "") items.push(tail);
    return items;
}

/** Parse a comma-separated list (also accepts legacy ["a","b"] arrays on migration). */
export function parseList(raw) {
    if (Array.isArray(raw)) return raw.map(x => String(x));
    const s = unquote(raw);
    if (!s) return [];
    if (s.startsWith("[") && s.endsWith("]")) return splitLegacyBracketList(s);
    return s.split(",").map(x => unescapeField(x.trim())).filter(Boolean);
}

/** Serialize an array of strings to escaped comma-separated flat format. */
export function serializeList(arr) {
    if (!Array.isArray(arr) || arr.length === 0) return "";
    return arr.map(x => escapeField(String(x))).join(",");
}

/** Parse flat key=val;key2=val2 string (also migrates simple legacy {"k":"v"} objects). */
export function parseKvMap(raw) {
    if (raw && typeof raw === "object" && !Array.isArray(raw)) return Object.assign({}, raw);
    const s = unquote(raw);
    const out = {};
    if (!s) return out;
    if (s.startsWith("{") && s.endsWith("}")) {
        const inner = s.slice(1, -1).trim();
        if (!inner) return out;
        const pairs = splitLegacyBracketList("[" + inner + "]");
        for (let i = 0; i < pairs.length; i++) {
            const col = pairs[i].indexOf(":");
            if (col <= 0) continue;
            const k = unquote(pairs[i].slice(0, col));
            const v = unquote(pairs[i].slice(col + 1));
            if (k) out[k] = v;
        }
        return out;
    }
    const entries = s.split(";");
    for (let i = 0; i < entries.length; i++) {
        const ent = entries[i].trim();
        if (!ent) continue;
        const eq = ent.indexOf("=");
        if (eq <= 0) continue;
        const k = unescapeField(ent.slice(0, eq));
        const v = unescapeField(ent.slice(eq + 1));
        if (k) out[k] = v;
    }
    return out;
}

/** Serialize plain string dictionary to escaped semicolon-separated k=v pairs. */
export function serializeKvMap(obj) {
    if (!obj || typeof obj !== "object") return "";
    const parts = [];
    for (const k in obj) {
        if (!Object.prototype.hasOwnProperty.call(obj, k)) continue;
        parts.push(escapeField(k) + "=" + escapeField(obj[k]));
    }
    return parts.join(";");
}

/** Parse flat launcher categories: id|name|icon|app1;app2,id2|... */
export function parseCategories(raw) {
    if (Array.isArray(raw)) return raw;
    const s = unquote(raw);
    if (!s || s === "[]") return [];
    const out = [];
    if (s.startsWith("[") && s.endsWith("]")) {
        const objs = s.match(/\{[^}]*\}/g) || [];
        for (let i = 0; i < objs.length; i++) {
            const block = objs[i];
            const idM = block.match(/"id"\s*:\s*"([^"]*)"/);
            const nameM = block.match(/"name"\s*:\s*"([^"]*)"/);
            const iconM = block.match(/"icon"\s*:\s*"([^"]*)"/);
            const appsM = block.match(/"appIds"\s*:\s*\[([^\]]*)\]/);
            if (idM && nameM) {
                const appIds = appsM ? splitLegacyBracketList("[" + appsM[1] + "]") : [];
                out.push({ id: idM[1], name: nameM[1], icon: iconM ? iconM[1] : "folder", appIds });
            }
        }
        return out;
    }
    const recs = s.split(",");
    for (let i = 0; i < recs.length; i++) {
        const r = recs[i].trim();
        if (!r) continue;
        const cols = r.split("|");
        if (cols.length < 2) continue;
        const id = unescapeField(cols[0]);
        const name = unescapeField(cols[1]);
        const icon = cols.length > 2 ? unescapeField(cols[2]) : "folder";
        const appRaw = cols.length > 3 ? cols[3] : "";
        const appIds = appRaw ? appRaw.split(";").map(a => unescapeField(a)).filter(Boolean) : [];
        if (id && name) out.push({ id, name, icon: icon || "folder", appIds });
    }
    return out;
}

/** Serialize launcher categories into flat delimited .conf records. */
export function serializeCategories(cats) {
    if (!Array.isArray(cats) || cats.length === 0) return "";
    return cats
        .filter(c => c && c.id && c.name)
        .map(c => {
            const apps = Array.isArray(c.appIds) ? c.appIds.map(a => escapeField(a)).join(";") : "";
            return [escapeField(c.id), escapeField(c.name), escapeField(c.icon || "folder"), apps].join("|");
        })
        .join(",");
}

/** Parse flat key-value lines into a dictionary. */
export function parseFlatConf(str) {
    const data = {};
    if (!str || !String(str).trim()) return data;
    const lines = String(str).split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line || line.startsWith("#")) continue;
        const eqIdx = line.indexOf("=");
        if (eqIdx === -1) continue;
        const key = line.slice(0, eqIdx).trim();
        const val = unquote(line.slice(eqIdx + 1));
        data[key] = val;
    }
    return data;
}

/** Parse indexed flat records: `<prefix>.<idx>.<field>=<escapedValue>`. */
export function parseRecords(str, prefix) {
    const raw = parseFlatConf(str);
    const byIdx = {};
    const head = prefix + ".";
    for (const k in raw) {
        if (!k.startsWith(head)) continue;
        const rest = k.slice(head.length);
        const dot = rest.indexOf(".");
        if (dot <= 0) continue;
        const idx = parseInt(rest.slice(0, dot), 10);
        if (isNaN(idx)) continue;
        const field = rest.slice(dot + 1);
        if (!byIdx[idx]) byIdx[idx] = {};
        byIdx[idx][field] = unescapeField(raw[k]);
    }
    const indices = Object.keys(byIdx).map(n => parseInt(n, 10)).sort((a, b) => a - b);
    return indices.map(i => byIdx[i]);
}

/** Serialize an array of objects as `<prefix>.<idx>.<field>=<escapedValue>` lines. */
export function serializeRecords(records, prefix, fields) {
    const lines = ["# Quickshell native " + prefix + " store", "count=" + (records ? records.length : 0)];
    if (!Array.isArray(records)) return lines.join("\n") + "\n";
    for (let i = 0; i < records.length; i++) {
        const rec = records[i];
        if (!rec) continue;
        for (let j = 0; j < fields.length; j++) {
            const f = fields[j];
            const val = rec[f] !== undefined ? rec[f] : "";
            lines.push(prefix + "." + i + "." + f + "=" + escapeField(val));
        }
    }
    return lines.join("\n") + "\n";
}
