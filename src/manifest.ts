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
