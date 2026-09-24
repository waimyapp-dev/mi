#!/bin/bash
set -e

ROOT="$(pwd)"
echo "Creando proyecto en $ROOT"

mkdir -p src/commands templates scripts mi-vscode/src/panels mi-vscode/media

# ─── package.json ───
cat > package.json <<'EOF'
{
  "name": "mio",
  "version": "1.0.0",
  "description": "Bloques con ID para trabajar con IA sin perder contexto",
  "type": "module",
  "bin": { "mio": "./dist/cli.js" },
  "workspaces": ["mi-vscode"],
  "files": ["dist", "templates", "README.md"],
  "engines": { "node": ">=20" },
  "scripts": {
    "build": "tsup",
    "build:ext": "npm run -w mi-vscode compile && npm run -w mi-vscode package",
    "postinstall": "node scripts/setup.cjs",
    "prepare": "npm run build"
  },
  "dependencies": { "commander": "^12.1.0" },
  "devDependencies": {
    "tsup": "^8.3.0",
    "tsx": "^4.19.0",
    "typescript": "^5.6.0",
    "@types/node": "^22.0.0"
  }
}
EOF

# ─── tsconfig.json ───
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["src/**/*"]
}
EOF

# ─── tsup.config.ts ───
cat > tsup.config.ts <<'EOF'
import { defineConfig } from "tsup";
export default defineConfig({
  entry: { cli: "src/index.ts" },
  format: ["esm"],
  target: "node20",
  splitting: false,
  sourcemap: true,
  clean: true,
  minify: false,
  shims: true,
});
EOF

# ─── .gitignore ───
cat > .gitignore <<'EOF'
node_modules/
dist/
out/
*.vsix
.mi/out/
.mi/in/
.mi/blocks/
.mi/backups/
.DS_Store
Thumbs.db
*.log
.vscode/
.idea/
EOF

# ─── README.md ───
cat > README.md <<'EOF'
# mio

CLI + extensión VS Code para trabajar con bloques de código y IA sin perder contexto.

## Instalación

    git clone https://github.com/waimyapp-dev/mi.git
    cd mi
    npm install

Eso instala el CLI `mio` globalmente y la extensión en VS Code.

## Uso

    mio init
    mio setup react --lang ts --style tailwind
    mio list
    mio doctor
    mio context <id>
    mio find "<código>"
EOF

echo "OK package.json, tsconfig.json, tsup.config.ts, .gitignore, README.md"


# ─── src/parser.ts ───
cat > src/parser.ts <<'EOF'
import fs from "node:fs";

export interface Block {
  id: string;
  desc: string;
  content: string;
  file: string;
  startLine: number;
  endLine: number;
}

const OPEN_RE  = /^[ \t]*(?:\/\/|\/\*|<!--|#)[ \t]*@block:([\w-]+)(?:[ \t]*\[(.*?)\])?[ \t]*(?:\*\/|-->)?[ \t]*$/;
const CLOSE_RE = /^[ \t]*(?:\/\/|\/\*|<!--|#)[ \t]*@end:([\w-]+)[ \t]*(?:\*\/|-->)?[ \t]*$/;

export function scanFile(file: string): Block[] {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const blocks: Block[] = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(OPEN_RE);
    if (!m) continue;
    const id = m[1];
    const desc = m[2] ?? "";
    let end = -1;
    for (let j = i + 1; j < lines.length; j++) {
      const c = lines[j].match(CLOSE_RE);
      if (c && c[1] === id) { end = j; break; }
    }
    if (end === -1) throw new Error("[" + file + ":" + (i + 1) + "] bloque '" + id + "' sin @end");
    blocks.push({ id, desc, file, startLine: i, endLine: end, content: lines.slice(i + 1, end).join("\n") });
    i = end;
  }
  return blocks;
}

export function replaceBlockInFile(file: string, id: string, newText: string): void {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  let start = -1, end = -1;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(OPEN_RE);
    if (m && m[1] === id) {
      start = i;
      for (let j = i + 1; j < lines.length; j++) {
        const c = lines[j].match(CLOSE_RE);
        if (c && c[1] === id) { end = j; break; }
      }
      break;
    }
  }
  if (start === -1 || end === -1) throw new Error("Bloque '" + id + "' no encontrado");
  const out = [...lines.slice(0, start), ...newText.split("\n"), ...lines.slice(end + 1)];
  fs.writeFileSync(file, out.join("\n"), "utf8");
}

export { OPEN_RE, CLOSE_RE };
EOF

# ─── src/manifest.ts ───
cat > src/manifest.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { scanFile, type Block } from "./parser.js";

const EXT = new Set([".tsx",".ts",".jsx",".js",".css",".html",".vue",".svelte",".json",".yaml",".yml",".md"]);
const IGNORE = new Set(["node_modules",".git",".mi","dist","build",".next","coverage",".cache","out"]);

export function scanProject(root = process.cwd()): Block[] {
  const blocks: Block[] = [];
  const walk = (dir: string) => {
    for (const e of fs.readdirSync(dir)) {
      if (IGNORE.has(e)) continue;
      const full = path.join(dir, e);
      const st = fs.statSync(full);
      if (st.isDirectory()) { walk(full); continue; }
      if (!EXT.has(path.extname(e))) continue;
      try { blocks.push(...scanFile(full)); }
      catch (err: any) { console.warn("[warn] " + err.message); }
    }
  };
  walk(root);
  return blocks;
}

export function findBlock(blocks: Block[], id: string): Block {
  const found = blocks.filter(b => b.id === id);
  if (found.length === 0) throw new Error("Bloque '" + id + "' no existe");
  if (found.length > 1) throw new Error("ID '" + id + "' duplicado");
  return found[0];
}

export function checkDuplicates(blocks: Block[]): string[] {
  const seen = new Map<string, Block>();
  const dup: string[] = [];
  for (const b of blocks) {
    if (seen.has(b.id)) dup.push(b.id);
    else seen.set(b.id, b);
  }
  return dup;
}
EOF

# ─── src/anchors.ts ───
cat > src/anchors.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";

export interface Anchor { file: string; css?: string | null; inject?: boolean; type?: string; }
export interface AnchorsFile { blocks: Record<string, Anchor>; }

function file(root: string) { return path.join(root, ".mi", "anchors.json"); }

export function loadAnchors(root = process.cwd()): AnchorsFile {
  const f = file(root);
  if (!fs.existsSync(f)) return { blocks: {} };
  try { return JSON.parse(fs.readFileSync(f, "utf8")); }
  catch { return { blocks: {} }; }
}

export function saveAnchors(root: string, data: AnchorsFile): void {
  const f = file(root);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, JSON.stringify(data, null, 2), "utf8");
}

export function getAnchor(root: string, id: string): Anchor | null {
  return loadAnchors(root).blocks[id] ?? null;
}

export function setAnchor(root: string, id: string, a: Anchor): void {
  const data = loadAnchors(root);
  data.blocks[id] = a;
  saveAnchors(root, data);
}

export function removeAnchor(root: string, id: string): boolean {
  const data = loadAnchors(root);
  if (!data.blocks[id]) return false;
  delete data.blocks[id];
  saveAnchors(root, data);
  return true;
}
EOF

# ─── src/backup.ts ───
cat > src/backup.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";

export function backupBlock(root: string, id: string, content: string): string {
  const dir = path.join(root, ".mi", "blocks", id);
  fs.mkdirSync(dir, { recursive: true });
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const file = path.join(dir, ts + ".txt");
  fs.writeFileSync(file, content, "utf8");
  return file;
}

export function historyBlock(root: string, id: string): string[] {
  const dir = path.join(root, ".mi", "blocks", id);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith(".txt") && f !== "latest.txt").sort().reverse();
}
EOF

# ─── src/fences.ts ───
cat > src/fences.ts <<'EOF'
export function stripCodeFences(content: string): string {
  return content.split("\n").filter(l => !/^\s*```\w*\s*$/.test(l)).join("\n");
}
EOF

echo "OK src/parser.ts, manifest.ts, anchors.ts, backup.ts, fences.ts"



# ─── src/commands/init.ts ───
cat > src/commands/init.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function findTemplates(): string | null {
  const candidates = [
    path.resolve(__dirname, "..", "templates"),
    path.resolve(__dirname, "..", "..", "templates"),
    path.resolve(process.cwd(), "templates"),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c) && fs.existsSync(path.join(c, "ai-system.md"))) return c;
  }
  return null;
}

export function init(root = process.cwd()): void {
  console.log("Inicializando mio...\n");
  const dirs = [".mi/out", ".mi/in", ".mi/blocks", ".mi/prompts"];
  for (const d of dirs) fs.mkdirSync(path.join(root, d), { recursive: true });

  const tmpl = findTemplates();
  if (!tmpl) {
    console.warn("AVISO: no se encontro templates/");
  } else {
    for (const name of fs.readdirSync(tmpl).filter(f => f.endsWith(".md"))) {
      const dest = path.join(root, ".mi", "prompts", name);
      const src = fs.readFileSync(path.join(tmpl, name), "utf8");
      if (!fs.existsSync(dest) || fs.readFileSync(dest, "utf8") !== src) {
        fs.writeFileSync(dest, src, "utf8");
        console.log("  " + name);
      }
    }
  }

  const gi = path.join(root, ".gitignore");
  const entries = ["", "# Sistema mio", ".mi/out/", ".mi/in/", ".mi/blocks/", ".mi/backups/"];
  const existing = fs.existsSync(gi) ? fs.readFileSync(gi, "utf8") : "";
  if (!existing.includes(".mi/out/")) fs.appendFileSync(gi, entries.join("\n") + "\n", "utf8");
  console.log("\nOK.\n");
}
EOF

# ─── src/commands/inject.ts ───
cat > src/commands/inject.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { getAnchor, setAnchor } from "../anchors.js";
import { OPEN_RE, CLOSE_RE } from "../parser.js";
import { backupBlock } from "../backup.js";
import { stripCodeFences } from "../fences.js";

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const c of process.stdin) chunks.push(Buffer.from(c));
  return Buffer.concat(chunks).toString("utf8");
}

const ANCHOR_RE = /^\s*(?:\/\/|\/\*|<!--|#)\s*@anchor:\s*(\S+)/;

function commentStyle(file: string) {
  const ext = path.extname(file).toLowerCase();
  const base = path.basename(file);
  if (ext === ".css" || ext === ".scss") return { open: "/* ", close: " */" };
  if (ext === ".html") return { open: "<!-- ", close: " -->" };
  if (ext === ".json" || ext === ".env" || base === ".gitignore" || ext === ".yaml" || ext === ".yml") return { open: "# ", close: "" };
  return { open: "// ", close: "" };
}

function normalizeMarkers(text: string, target: string): string {
  const s = commentStyle(target);
  return text.split("\n").map(line => {
    const t = line.trim();
    const isMarker = t.includes("@anchor:") || t.includes("@block:") || t.includes("@end:");
    if (!isMarker) return line;
    const body = t.replace(/^\/\/\s*/, "").replace(/^#\s*/, "").replace(/^\/\*\s*/, "").replace(/\s*\*\/$/, "").replace(/^<!--\s*/, "").replace(/\s*-->$/, "");
    return s.open + body + s.close;
  }).join("\n");
}

interface Parsed { id: string; raw: string; anchor?: string; }

function splitBlocks(text: string): Parsed[] {
  const lines = text.split("\n").map(l => l.replace(/\r$/, ""));
  const out: Parsed[] = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && !lines[i].match(OPEN_RE)) i++;
    if (i >= lines.length) break;
    let anchor: string | undefined;
    for (let k = i - 1; k >= 0 && k >= i - 3; k--) {
      const a = lines[k].match(ANCHOR_RE);
      if (a) anchor = a[1];
    }
    const id = lines[i].match(OPEN_RE)![1];
    const bl = [lines[i]];
    let j = i + 1;
    while (j < lines.length) {
      bl.push(lines[j]);
      const c = lines[j].match(CLOSE_RE);
      if (c && c[1] === id) break;
      j++;
    }
    if (j >= lines.length) throw new Error("Bloque '" + id + "' sin @end");
    out.push({ id, raw: bl.join("\n").trim(), anchor });
    i = j + 1;
  }
  return out;
}

function stripMarkers(text: string): string {
  return text.split("\n").slice(1, -1).join("\n");
}

function injectOne(b: Parsed, root: string): void {
  const { id, raw } = b;
  let anchorFile = b.anchor;
  if (!anchorFile) {
    const saved = getAnchor(root, id);
    if (!saved) throw new Error("No hay @anchor para '" + id + "'");
    anchorFile = saved.file;
  } else {
    setAnchor(root, id, { file: anchorFile, inject: true, type: "component" });
  }
  const target = path.resolve(root, anchorFile);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const norm = normalizeMarkers(raw, target);
  const ext = path.extname(target).toLowerCase();
  const isStrict = ext === ".json" || ext === ".env";
  if (isStrict) {
    const dir = path.join(root, ".mi", "blocks", id);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, "source.txt"), norm, "utf8");
    if (fs.existsSync(target)) backupBlock(root, id, fs.readFileSync(target, "utf8"));
    fs.writeFileSync(target, stripMarkers(norm).trimEnd() + "\n", "utf8");
    console.log("  [" + id + "] " + anchorFile + " (sin marcadores)");
    return;
  }
  const exists = fs.existsSync(target);
  const old = exists ? fs.readFileSync(target, "utf8") : "";
  const oldLines = old ? old.split("\n") : [];
  const blockCount = oldLines.filter(l => l.match(OPEN_RE)).length;
  const shouldReplace = !exists || blockCount <= 1;
  if (exists) backupBlock(root, id, old);
  const dir = path.join(root, ".mi", "blocks", id);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "source.txt"), norm, "utf8");
  if (shouldReplace) {
    fs.writeFileSync(target, norm + "\n", "utf8");
    console.log("  [" + id + "] " + (exists ? "reemplazado" : "creado") + " en " + anchorFile);
  } else {
    fs.writeFileSync(target, old + "\n" + norm + "\n", "utf8");
    console.log("  [" + id + "] anadido en " + anchorFile);
  }
}

export async function inject(root = process.cwd()): Promise<void> {
  const raw = await readStdin();
  if (!raw.trim()) throw new Error("Sin datos");
  const blocks = splitBlocks(stripCodeFences(raw));
  if (blocks.length === 0) throw new Error("No hay bloques");
  console.log("Aplicando " + blocks.length + " bloque(s):\n");
  for (const b of blocks) injectOne(b, root);
  console.log("\nOK. " + blocks.length + " aplicados.");
}
EOF

# ─── src/commands/list-json.ts ───
cat > src/commands/list-json.ts <<'EOF'
import { scanProject } from "../manifest.js";
export function listJson(prefix?: string): void {
  const blocks = scanProject();
  const f = prefix ? blocks.filter(b => b.id.startsWith(prefix)) : blocks;
  console.log(JSON.stringify(f.map(b => ({ id: b.id, desc: b.desc, file: b.file, startLine: b.startLine + 1, endLine: b.endLine + 1 }))));
}
EOF

# ─── src/commands/doctor.ts ───
cat > src/commands/doctor.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { scanProject, checkDuplicates } from "../manifest.js";
import { loadAnchors } from "../anchors.js";

export function doctor(json = false, root = process.cwd()): void {
  const blocks = scanProject(root);
  const dup = checkDuplicates(blocks);
  const anchors = loadAnchors(root);
  const blockIds = new Set(blocks.map(b => b.id));
  const orphans = Object.keys(anchors.blocks).filter(id => !blockIds.has(id));
  const report = {
    blocks: { total: blocks.length, duplicates: dup, orphanAnchors: orphans },
    structure: {
      hasPackageJson: fs.existsSync(path.join(root, "package.json")),
      hasMiDir: fs.existsSync(path.join(root, ".mi")),
      hasPrompts: fs.existsSync(path.join(root, ".mi", "prompts")),
    },
  };
  if (json) { console.log(JSON.stringify(report)); return; }
  console.log("=== DOCTOR ===\n");
  console.log("  package.json: " + (report.structure.hasPackageJson ? "OK" : "falta"));
  console.log("  .mi/: " + (report.structure.hasMiDir ? "OK" : "falta"));
  console.log("  .mi/prompts/: " + (report.structure.hasPrompts ? "OK" : "falta"));
  console.log("\nBloques: " + blocks.length);
  if (dup.length) console.log("  IDs duplicados: " + dup.join(", "));
  if (orphans.length) console.log("  Anclajes huerfanos: " + orphans.join(", "));
}
EOF

# ─── src/commands/context.ts ───
cat > src/commands/context.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { scanProject, findBlock } from "../manifest.js";

export function context(id: string, root = process.cwd()): void {
  const blocks = scanProject(root);
  const b = findBlock(blocks, id);
  const lines = fs.readFileSync(b.file, "utf8").split("\n");
  const raw = lines.slice(b.startLine, b.endLine + 1).join("\n");
  const out = "=== CONTEXTO PARA " + id + " ===\n\n=== BLOQUE PRINCIPAL ===\n" + raw + "\n";
  const outDir = path.join(root, ".mi", "out");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "context-" + id + ".txt"), out, "utf8");
  console.log(out);
  console.log("\n-> .mi/out/context-" + id + ".txt");
}
EOF

# ─── src/commands/find.ts ───
cat > src/commands/find.ts <<'EOF'
import fs from "node:fs";
import { scanProject } from "../manifest.js";
import { getAnchor } from "../anchors.js";

function lineMatches(line: string, query: string): boolean {
  const a = line.replace(/\s+/g, " ").trim();
  const b = query.replace(/\s+/g, " ").trim();
  return a === b || a.includes(b);
}

export function find(query: string, json = false, root = process.cwd()): void {
  const blocks = scanProject(root);
  const matches: any[] = [];
  const queryLines = query.split("\n").map(l => l.trim()).filter(Boolean);
  for (const b of blocks) {
    const fileLines = fs.readFileSync(b.file, "utf8").split("\n");
    const blockLines = fileLines.slice(b.startLine + 1, b.endLine);
    const anchor = getAnchor(root, b.id);
    for (let i = 0; i < blockLines.length; i++) {
      if (lineMatches(blockLines[i], queryLines[0])) {
        const ctxStart = Math.max(0, i - 2);
        const ctxEnd = Math.min(blockLines.length, i + 3);
        matches.push({
          blockId: b.id, blockDesc: b.desc, file: b.file,
          anchorFile: anchor?.file ?? null, lineInBlock: i + 1,
          lineInFile: b.startLine + 2 + i, matchedLine: queryLines[0],
          context: blockLines.slice(ctxStart, ctxEnd),
        });
      }
    }
  }
  const report = { query, matches, totalBlocks: blocks.length };
  if (json) { console.log(JSON.stringify(report)); return; }
  if (matches.length === 0) { console.log("Sin coincidencias en " + blocks.length + " bloques."); return; }
  console.log("=== " + matches.length + " coincidencia(s) ===\n");
  for (const m of matches) {
    console.log("  " + m.blockId + "  [" + m.blockDesc + "]");
    console.log("    " + (m.anchorFile || m.file) + ":" + m.lineInFile);
    for (const c of m.context) console.log("    " + c);
    console.log("");
  }
}
EOF

# ─── src/commands/setup.ts ───
cat > src/commands/setup.ts <<'EOF'
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { setAnchor } from "../anchors.js";
import { init } from "./init.js";

export interface SetupOptions { framework: string; lang: "ts" | "js"; style: "tailwind" | "css-modules" | "plain"; }

function writeBlock(opts: { root: string; anchor: string; blockId: string; desc: string; content: string; strict?: boolean }) {
  const target = path.resolve(opts.root, opts.anchor);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const ext = path.extname(opts.anchor).toLowerCase();
  const base = path.basename(opts.anchor);
  let open = "// ", close = "";
  if (ext === ".css" || ext === ".scss") { open = "/* "; close = " */"; }
  else if (ext === ".html") { open = "<!-- "; close = " -->"; }
  else if (ext === ".json" || ext === ".env" || base === ".gitignore") { open = "# "; close = ""; }
  const source = [open + "@anchor:" + opts.anchor + close, open + "@block:" + opts.blockId + " [" + opts.desc + "]" + close, opts.content.trimEnd(), open + "@end:" + opts.blockId + close].join("\n") + "\n";
  const srcDir = path.join(opts.root, ".mi", "blocks", opts.blockId);
  fs.mkdirSync(srcDir, { recursive: true });
  fs.writeFileSync(path.join(srcDir, "source.txt"), source, "utf8");
  fs.writeFileSync(target, opts.strict ? opts.content.trimEnd() + "\n" : source, "utf8");
  setAnchor(opts.root, opts.blockId, { file: opts.anchor, css: null, inject: true, type: "setup" });
  console.log("  " + opts.anchor + "  [" + opts.blockId + "]");
}

export function setup(opts: SetupOptions, root = process.cwd()): void {
  const lang = opts.lang === "js" ? "js" : "ts";
  const style = opts.style || "tailwind";
  console.log("Configurando: " + opts.framework + " + " + lang + " + " + style + "\n");
  try { init(root); } catch (e) {}

  const deps: any = {};
  const devDeps: any = { vite: "^5.4.0" };
  const scripts = { dev: "vite", build: "vite build", preview: "vite preview" };
  let ext = lang === "ts" ? "tsx" : "jsx";
  let mainCode = "", appCode = "";
  let mainFile = "src/main." + ext;
  let appFile = "src/App." + ext;
  let indexEntry = "/src/main." + ext;

  if (opts.framework === "react") {
    deps.react = "^18.3.0"; deps["react-dom"] = "^18.3.0";
    devDeps["@vitejs/plugin-react"] = "^4.3.0";
    if (lang === "ts") { devDeps.typescript = "^5.6.0"; devDeps["@types/react"] = "^18.3.0"; devDeps["@types/react-dom"] = "^18.3.0"; }
    mainCode = 'import React from "react";\nimport ReactDOM from "react-dom/client";\nimport { App } from "./App";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\nReactDOM.createRoot(document.getElementById("app")' + (lang === "ts" ? "!" : "") + ').render(\n  <React.StrictMode>\n    <App />\n  </React.StrictMode>\n);';
    appCode = 'export function App() {\n  return (\n    <div' + (style === "tailwind" ? ' className="p-8"' : "") + '>\n      <h1>Hola desde mio + React</h1>\n    </div>\n  );\n}';
  } else if (opts.framework === "vue") {
    deps.vue = "^3.5.0"; devDeps["@vitejs/plugin-vue"] = "^5.1.0";
    if (lang === "ts") devDeps.typescript = "^5.6.0";
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; appFile = "src/App.vue"; indexEntry = "/src/main." + ext;
    mainCode = 'import { createApp } from "vue";\nimport App from "./App.vue";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\ncreateApp(App).mount("#app");';
    appCode = '<template>\n  <div' + (style === "tailwind" ? ' class="p-8"' : "") + '>\n    <h1>Hola desde mio + Vue</h1>\n  </div>\n</template>\n\n<script setup' + (lang === "ts" ? ' lang="ts"' : "") + '>\n</script>';
  } else if (opts.framework === "svelte") {
    devDeps.svelte = "^4.2.0"; devDeps["@sveltejs/vite-plugin-svelte"] = "^3.1.0";
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; appFile = "src/App.svelte"; indexEntry = "/src/main." + ext;
    mainCode = 'import App from "./App.svelte";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\nconst app = new App({ target: document.getElementById("app") });\nexport default app;';
    appCode = '<script' + (lang === "ts" ? ' lang="ts"' : "") + '>\n</script>\n\n<div' + (style === "tailwind" ? ' class="p-8"' : "") + '>\n  <h1>Hola desde mio + Svelte</h1>\n</div>';
  } else if (opts.framework === "next") {
    deps.next = "^14.2.0"; deps.react = "^18.3.0"; deps["react-dom"] = "^18.3.0";
    scripts.dev = "next dev"; scripts.build = "next build"; (scripts as any).start = "next start";
    if (lang === "ts") { devDeps.typescript = "^5.6.0"; devDeps["@types/react"] = "^18.3.0"; devDeps["@types/node"] = "^22.0.0"; }
    const nextExt = lang === "ts" ? "tsx" : "jsx";
    writeBlock({ root, anchor: "app/layout." + nextExt, blockId: "layout-setup", desc: "Layout raiz", content: 'export const metadata = { title: "mio app" };\n\nexport default function RootLayout({ children }: { children: React.ReactNode }) {\n  return (\n    <html lang="es">\n      <body' + (style === "tailwind" ? ' className="p-8"' : "") + '>{children}</body>\n    </html>\n  );\n}' });
    writeBlock({ root, anchor: "app/page." + nextExt, blockId: "page-setup", desc: "Pagina principal", content: 'export default function Home() {\n  return <h1>Hola desde mio + Next.js</h1>;\n}' });
  } else {
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; indexEntry = "/src/main." + ext;
    mainCode = (style === "tailwind" ? 'import "./index.css";\n\n' : "") + 'document.getElementById("app"' + (lang === "ts" ? "!" : "") + ').innerHTML = \'<div' + (style === "tailwind" ? ' class="p-8"' : "") + '><h1>Hola desde mio + Vanilla</h1></div>\';';
  }

  if (style === "tailwind") {
    devDeps.tailwindcss = "^3.4.0"; devDeps.postcss = "^8.4.0"; devDeps.autoprefixer = "^10.4.0";
    writeBlock({ root, anchor: "tailwind.config.js", blockId: "tailwind-setup", desc: "Config Tailwind", content: '/** @type {import(\'tailwindcss\').Config} */\nexport default {\n  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx,vue,svelte}"],\n  theme: { extend: {} },\n  plugins: [],\n};' });
    writeBlock({ root, anchor: "postcss.config.js", blockId: "postcss-setup", desc: "Config PostCSS", content: 'export default {\n  plugins: { tailwindcss: {}, autoprefixer: {} },\n};' });
  }

  const pkg = { name: "mio-app", private: true, version: "0.1.0", type: "module", scripts, dependencies: deps, devDependencies: devDeps };
  writeBlock({ root, anchor: "package.json", blockId: "package-setup", desc: "Dependencias y scripts", content: JSON.stringify(pkg, null, 2), strict: true });

  writeBlock({ root, anchor: "index.html", blockId: "index-html-setup", desc: "Shell HTML", content: '<!DOCTYPE html>\n<html lang="es">\n  <head>\n    <meta charset="UTF-8" />\n    <meta name="viewport" content="width=device-width, initial-scale=1.0" />\n    <title>mio app</title>\n  </head>\n  <body>\n    <div id="app"></div>\n    <script type="module" src="' + indexEntry + '"></script>\n  </body>\n</html>' });

  if (lang === "ts" && opts.framework !== "next") {
    writeBlock({ root, anchor: "tsconfig.json", blockId: "tsconfig-setup", desc: "Config TypeScript", content: JSON.stringify({ compilerOptions: { target: "ES2022", lib: ["ES2022", "DOM", "DOM.Iterable"], module: "ESNext", moduleResolution: "Bundler", strict: true, esModuleInterop: true, skipLibCheck: true, noEmit: true, ...(opts.framework === "react" ? { jsx: "react-jsx" } : {}) }, include: ["src"] }, null, 2), strict: true });
  }

  if (mainCode && mainFile) writeBlock({ root, anchor: mainFile, blockId: "main-setup", desc: "Entry point", content: mainCode });
  if (appCode && appFile) writeBlock({ root, anchor: appFile, blockId: "app-setup", desc: "Componente raiz", content: appCode });
  if (style === "tailwind") writeBlock({ root, anchor: "src/index.css", blockId: "css-setup", desc: "Directivas Tailwind", content: "@tailwind base;\n@tailwind components;\n@tailwind utilities;" });

  console.log("\nInstalando dependencias...");
  execSync("npm install", { cwd: root, stdio: "inherit" });
  console.log("\nOK. Ejecuta: npm run dev\n");
}
EOF

# ─── src/index.ts ───
cat > src/index.ts <<'EOF'
#!/usr/bin/env node
import { Command } from "commander";
import { scanProject, checkDuplicates } from "./manifest.js";
import { init } from "./commands/init.js";
import { inject } from "./commands/inject.js";
import { listJson } from "./commands/list-json.js";
import { doctor } from "./commands/doctor.js";
import { context } from "./commands/context.js";
import { find } from "./commands/find.js";
import { setup } from "./commands/setup.js";

const p = new Command();
p.name("mio").description("Bloques con ID para trabajar con IA").version("1.0.0");

p.command("init").description("Inicializa .mi/").action(() => {
  try { init(); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("setup <framework>")
  .description("Crea la estructura base (react, vue, svelte, next, vanilla)")
  .option("--lang <lang>", "ts o js", "ts")
  .option("--style <style>", "tailwind, css-modules o plain", "tailwind")
  .action((framework, opts) => {
    try { setup({ framework, lang: opts.lang, style: opts.style }); }
    catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
  });

p.command("list")
  .description("Lista todos los bloques")
  .option("--json")
  .option("-t, --type <prefix>")
  .action((opts) => {
    if (opts.json) { listJson(opts.type); return; }
    const blocks = scanProject();
    const f = opts.type ? blocks.filter(b => b.id.startsWith(opts.type)) : blocks;
    for (const b of f) console.log(b.id.padEnd(24) + "  " + (b.file + ":" + (b.startLine + 1)).padEnd(60) + "  " + b.desc);
    console.log("\nTotal: " + f.length + " bloques");
  });

p.command("inject").description("Aplica bloques desde stdin").action(async () => {
  try { await inject(); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("doctor").option("--json").action((opts) => {
  try { doctor(!!opts.json); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("context <id>").action((id) => {
  try { context(id); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("find <query>").option("--json").action((query, opts) => {
  try { find(query, !!opts.json); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("check").action(() => {
  const blocks = scanProject();
  const dup = checkDuplicates(blocks);
  if (dup.length) { console.error("IDs duplicados: " + dup.join(", ")); process.exit(1); }
  console.log(blocks.length + " bloques validos");
});

p.parse();
EOF

echo "OK comandos + index.ts"

# ─── templates/ai-system.md ───
cat > templates/ai-system.md <<'EOF'
# Sistema de trabajo: bloques mio

## REGLA CRITICA: SIEMPRE responde en bloque de codigo

Envuelve TODAS tus respuestas en triple backtick para que yo tenga el boton de copiar.

Formato EXACTO:

```tsx
// @anchor:src/App.tsx
// @block:app-setup [App]
...codigo completo...
// @end:app-setup


# ─── templates/ai-system.md ───
cat > templates/ai-system.md <<'EOF'
# Sistema de trabajo: bloques mio

## REGLA CRITICA: SIEMPRE responde en bloque de codigo

Envuelve TODAS tus respuestas en triple backtick para que yo tenga el boton de copiar.

Formato EXACTO:

```tsx
// @anchor:src/App.tsx
// @block:app-setup [App]
...codigo completo...
// @end:app-setup
```

## Formato de bloques

    // @anchor:ruta/al/archivo.ext
    // @block:id [descripcion]
    ...codigo...
    // @end:id

Prefijo segun archivo:
- .ts .tsx .js .jsx -> //
- .css -> /* */
- .html -> <!-- -->
- .json .env .yaml .gitignore -> #

## Reglas

1. SIEMPRE envuelve en triple backtick.
2. SOLO los bloques, sin explicaciones fuera.
3. Conserva @anchor, @block, @end exactamente.
4. No anadas codigo duplicado fuera del bloque.
5. No dupliques imports que ya estan.
6. No crees export default duplicado.
7. No renombres ids.
8. Si algo afecta a otros bloques, UNA linea NOTA: al final.

Cuando entiendas esto responde solo: "Listo, entendi el sistema mio."
EOF

# ─── templates/response-format.md ───
cat > templates/response-format.md <<'EOF'
# Recordatorio: formato obligatorio

Envuelve tu respuesta en triple backtick:

```tsx
// @anchor:ruta/archivo.ext
// @block:id [desc]
...codigo completo...
// @end:id
```

- Solo el bloque principal.
- Marcadores intactos.
- Sin codigo duplicado fuera del bloque.
- Sin export default duplicado.
- Si avisas algo, UNA linea NOTA: al final.
EOF

# ─── templates/project-migration.md ───
cat > templates/project-migration.md <<'EOF'
# Migracion de proyecto existente al formato mio

Reorganiza el proyecto completo en bloques.

## Formato

    // @anchor:ruta/archivo.ext
    // @block:id [desc]
    ...codigo completo...
    // @end:id

## Convencion

- src/main.tsx -> main-001
- src/App.tsx -> app-001
- src/components/Navbar.tsx -> ui-navbar
- package.json -> pkg-001
- vite.config.js -> vite-001
- index.html -> html-001
- src/index.css -> css-001

## Reglas

1. Devuelve TODOS los bloques en UN mensaje.
2. Envuelve cada bloque en triple backtick.
3. Preserva TODO el codigo.
EOF

# ─── scripts/setup.cjs ───
cat > scripts/setup.cjs <<'EOF'
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const EXT = path.join(ROOT, "mi-vscode");

if (!fs.existsSync(path.join(EXT, "package.json")) || !fs.existsSync(path.join(EXT, "src"))) {
  process.exit(0);
}

function run(cmd, cwd) {
  console.log("\n> " + cmd);
  try { execSync(cmd, { cwd, stdio: "inherit", shell: true }); }
  catch (e) { console.log("AVISO: fallo " + cmd); }
}

console.log("\n==========================================");
console.log("  mio setup");
console.log("==========================================\n");

run("npm run build", ROOT);

console.log("\n[2/5] Linkeando CLI...");
try { execSync("npm link", { cwd: ROOT, stdio: "inherit", shell: true }); }
catch (e) { console.log("AVISO: npm link fallo"); }

console.log("\n[3/5] Compilando extension...");
run("npm run compile --workspace mi-vscode", ROOT);

console.log("\n[4/5] Empaquetando extension...");
run("npm run package --workspace mi-vscode", ROOT);

console.log("\n[5/5] Instalando extension en VS Code...");
const files = fs.readdirSync(EXT).filter(f => f.endsWith(".vsix"));
if (files.length > 0) {
  files.sort((a, b) => fs.statSync(path.join(EXT, b)).mtimeMs - fs.statSync(path.join(EXT, a)).mtimeMs);
  const vsix = files[0];
  try { execSync('code --install-extension "' + path.join(EXT, vsix) + '" --force', { cwd: EXT, stdio: "inherit", shell: true }); }
  catch (e) { console.log("AVISO: instala manualmente: " + path.join(EXT, vsix)); }
}

console.log("\n==========================================");
console.log("  Listo. Comando: mio");
console.log("==========================================\n");
EOF

# ─── install.sh (Linux/Mac) ───
cat > install.sh <<'EOF'
#!/bin/bash
set -e
echo "Instalando mio..."
npm install
echo ""
echo "Listo. Comando disponible: mio"
mio --help
EOF
chmod +x install.sh

echo ""
echo "=========================================="
echo "  Bloque CLI completo"
echo "=========================================="
echo ""
echo "Siguiente: bootstrap-ext.sh (la extension)"