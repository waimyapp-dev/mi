const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const EXT = path.join(ROOT, "mi-vscode");

if (!fs.existsSync(path.join(EXT, "package.json")) || !fs.existsSync(path.join(EXT, "src"))) {
  process.exit(0);
}

function run(cmd, cwd) {
  console.log("\n> " + cmd);
  try { execSync(cmd, { cwd, stdio: "inherit", shell: true }); }
  catch (e) { console.log("AVISO: fallo " + cmd); }
}

console.log("\n==========================================");
console.log("  mio setup");
console.log("==========================================\n");

run("npm run build", ROOT);

console.log("\n[2/5] Linkeando CLI...");
try { execSync("npm link", { cwd: ROOT, stdio: "inherit", shell: true }); }
catch (e) { console.log("AVISO: npm link fallo"); }

console.log("\n[3/5] Compilando extension...");
run("npm run compile --workspace mi-vscode", ROOT);

console.log("\n[4/5] Empaquetando extension...");
run("npm run package --workspace mi-vscode", ROOT);

console.log("\n[5/5] Instalando extension en VS Code...");
const files = fs.readdirSync(EXT).filter(f => f.endsWith(".vsix"));
if (files.length > 0) {
  files.sort((a, b) => fs.statSync(path.join(EXT, b)).mtimeMs - fs.statSync(path.join(EXT, a)).mtimeMs);
  const vsix = files[0];
  try { execSync('code --install-extension "' + path.join(EXT, vsix) + '" --force', { cwd: EXT, stdio: "inherit", shell: true }); }
  catch (e) { console.log("AVISO: instala manualmente: " + path.join(EXT, vsix)); }
}

console.log("\n==========================================");
console.log("  Listo. Comando: mio");
console.log("==========================================\n");
