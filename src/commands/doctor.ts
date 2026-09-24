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
