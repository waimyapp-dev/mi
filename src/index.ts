#!/usr/bin/env node
import { Command } from "commander";
import { scanProject, checkDuplicates } from "./manifest.js";
import { init } from "./commands/init.js";
import { inject } from "./commands/inject.js";
import { listJson } from "./commands/list-json.js";
import { doctor } from "./commands/doctor.js";
import { context } from "./commands/context.js";
import { find } from "./commands/find.js";
import { setup } from "./commands/setup.js";

const p = new Command();
p.name("mio").description("Bloques con ID para trabajar con IA").version("1.0.0");

p.command("init").description("Inicializa .mi/").action(() => {
  try { init(); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("setup <framework>")
  .description("Crea la estructura base (react, vue, svelte, next, vanilla)")
  .option("--lang <lang>", "ts o js", "ts")
  .option("--style <style>", "tailwind, css-modules o plain", "tailwind")
  .action((framework, opts) => {
    try { setup({ framework, lang: opts.lang, style: opts.style }); }
    catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
  });

p.command("list")
  .description("Lista todos los bloques")
  .option("--json")
  .option("-t, --type <prefix>")
  .action((opts) => {
    if (opts.json) { listJson(opts.type); return; }
    const blocks = scanProject();
    const f = opts.type ? blocks.filter(b => b.id.startsWith(opts.type)) : blocks;
    for (const b of f) console.log(b.id.padEnd(24) + "  " + (b.file + ":" + (b.startLine + 1)).padEnd(60) + "  " + b.desc);
    console.log("\nTotal: " + f.length + " bloques");
  });

p.command("inject").description("Aplica bloques desde stdin").action(async () => {
  try { await inject(); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("doctor").option("--json").action((opts) => {
  try { doctor(!!opts.json); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("context <id>").action((id) => {
  try { context(id); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("find <query>").option("--json").action((query, opts) => {
  try { find(query, !!opts.json); } catch (e: any) { console.error("ERROR: " + e.message); process.exit(1); }
});

p.command("check").action(() => {
  const blocks = scanProject();
  const dup = checkDuplicates(blocks);
  if (dup.length) { console.error("IDs duplicados: " + dup.join(", ")); process.exit(1); }
  console.log(blocks.length + " bloques validos");
});

p.parse();
