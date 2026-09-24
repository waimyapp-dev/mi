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
