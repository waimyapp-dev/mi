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
