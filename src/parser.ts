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
