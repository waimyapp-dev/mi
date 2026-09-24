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
