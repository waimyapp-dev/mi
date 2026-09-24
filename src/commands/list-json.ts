import { scanProject } from "../manifest.js";
export function listJson(prefix?: string): void {
  const blocks = scanProject();
  const f = prefix ? blocks.filter(b => b.id.startsWith(prefix)) : blocks;
  console.log(JSON.stringify(f.map(b => ({ id: b.id, desc: b.desc, file: b.file, startLine: b.startLine + 1, endLine: b.endLine + 1 }))));
}
