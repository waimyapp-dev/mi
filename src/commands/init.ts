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
