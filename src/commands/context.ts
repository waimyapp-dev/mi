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
