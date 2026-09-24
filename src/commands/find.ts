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
