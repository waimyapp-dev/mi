import * as fs from "node:fs";
import * as path from "node:path";
import { mioRun } from "./mi-cli.js";

/** Extrae el texto de un bloque del archivo original. */
function readBlockText(file: string, startLine: number, endLine: number): string {
  const content = fs.readFileSync(file, "utf8");
  return content.split("\n").slice(startLine - 1, endLine).join("\n");
}

/** Busca un bloque por id en el listado del CLI. */
async function findBlockInfo(id: string): Promise<any> {
  const out = await mioRun(["list", "--json"]);
  const blocks = JSON.parse(out);
  const b = blocks.find((x: any) => x.id === id);
  if (!b) throw new Error("Bloque no encontrado: " + id);
  return b;
}

/** Lee el CSS asociado al bloque desde .mi/anchors.json. */
function readAssociatedCss(root: string, id: string): string | null {
  const anchorsPath = path.join(root, ".mi", "anchors.json");
  if (!fs.existsSync(anchorsPath)) return null;
  try {
    const anchors = JSON.parse(fs.readFileSync(anchorsPath, "utf8"));
    const a = anchors.blocks && anchors.blocks[id];
    if (!a || !a.css) return null;
    const cssPath = path.resolve(root, a.css);
    if (!fs.existsSync(cssPath)) return null;
    return "// Archivo: " + a.css + "\n" + fs.readFileSync(cssPath, "utf8");
  } catch { return null; }
}

/** Copy 1: bloque completo + instrucciones simples. */
export async function buildBlockCopy(id: string): Promise<string> {
  const info = await findBlockInfo(id);
  const blockText = readBlockText(info.file, info.startLine, info.endLine);

  const lines = [
    "Te paso un bloque de codigo de mi proyecto.",
    "",
    "Reglas:",
    "1. Modifica SOLO este bloque.",
    "2. Devuelvelo COMPLETO con los marcadores @anchor/@block/@end intactos.",
    "3. Envuelve la respuesta en triple backtick.",
    "4. No cambies nada fuera del bloque.",
    "5. No renombres el id del bloque.",
    "6. No anadas codigo duplicado fuera del bloque.",
    "",
    "Bloque:",
    "",
    blockText,
    "",
    "Cambio a hacer:",
    "[describe aqui el cambio que quieres]",
  ];
  return lines.join("\n");
}

/** Copy 2: bloque + relacionados + CSS + instrucciones avanzadas. */
export async function buildBlockWithRelatedCopy(id: string, root: string): Promise<string> {
  const info = await findBlockInfo(id);
  const mainText = readBlockText(info.file, info.startLine, info.endLine);

  // Relacionados: bloques que comparten prefijo + el contexto del CLI
  let relatedBlocks: any[] = [];
  try {
    const out = await mioRun(["list", "--json"]);
    const all = JSON.parse(out);
    const prefix = id.split("-")[0];
    relatedBlocks = all.filter((b: any) => b.id !== id && b.id.startsWith(prefix));
  } catch {}

  const parts: string[] = [];
  parts.push("Te paso un bloque de codigo y sus bloques relacionados (dependencias + estilos).");
  parts.push("");
  parts.push("Reglas:");
  parts.push("1. Puedes modificar CUALQUIERA de los bloques del contexto.");
  parts.push("2. Devuelve TODOS los bloques que modifiques, cada uno POR SEPARADO.");
  parts.push("3. Cada bloque debe empezar con // @block:id y terminar con // @end:id.");
  parts.push("4. Conserva los marcadores @anchor, @block y @end intactos.");
  parts.push("5. Envuelve CADA bloque en su propio triple backtick.");
  parts.push("6. Si un bloque NO necesita cambios, no lo devuelvas.");
  parts.push("7. Manten coherencia entre bloques (si cambias una prop, actualiza quien la usa).");
  parts.push("");
  parts.push("=== BLOQUE PRINCIPAL ===");
  parts.push("");
  parts.push(mainText);
  parts.push("");

  if (relatedBlocks.length > 0) {
    parts.push("=== BLOQUES RELACIONADOS ===");
    parts.push("");
    for (const r of relatedBlocks) {
      try {
        const t = readBlockText(r.file, r.startLine, r.endLine);
        parts.push(t);
        parts.push("");
      } catch {}
    }
  }

  const css = readAssociatedCss(root, id);
  if (css) {
    parts.push("=== ESTILOS ASOCIADOS ===");
    parts.push("");
    parts.push(css);
    parts.push("");
  }

  parts.push("=== CAMBIO A HACER ===");
  parts.push("");
  parts.push("[describe aqui el cambio visual o funcional que quieres]");

  return parts.join("\n");
}
