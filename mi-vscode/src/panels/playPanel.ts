import * as vscode from "vscode";
import * as fs from "node:fs";
import * as path from "node:path";
import { getWorkspaceRoot } from "../mi-cli.js";

let devTerminal: vscode.Terminal | undefined;

export async function play() {
  const root = getWorkspaceRoot();
  const pkgPath = path.join(root, "package.json");
  if (!fs.existsSync(pkgPath)) {
    vscode.window.showWarningMessage("No hay package.json. Inicializa el proyecto primero.");
    return;
  }
  let devCmd = "npm run dev";
  let port = 5173;
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
    if (!pkg.scripts || !pkg.scripts.dev) {
      if (pkg.scripts && pkg.scripts.start) devCmd = "npm start";
      else { vscode.window.showWarningMessage("No hay script dev ni start."); return; }
    }
    const deps = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
    if (deps["next"]) port = 3000;
  } catch (e: any) {
    vscode.window.showErrorMessage("package.json invalido: " + e.message);
    return;
  }
  if (devTerminal) devTerminal.dispose();
  devTerminal = vscode.window.createTerminal({ name: "mio: dev", cwd: root, isTransient: true });
  devTerminal.show();
  devTerminal.sendText(devCmd);
  const url = "http://localhost:" + port;
  vscode.window.showInformationMessage("Arrancando en " + url + "... (4s)");
  await new Promise((r) => setTimeout(r, 4000));
  try { await vscode.commands.executeCommand("simpleBrowser.show", url); }
  catch (e) { vscode.window.showWarningMessage("Servidor corriendo. Abre: " + url); }
}

export function stopPlay() {
  if (devTerminal) {
    devTerminal.dispose();
    devTerminal = undefined;
    vscode.window.showInformationMessage("Servidor detenido.");
  }
}

export async function deployToCloudflare(): Promise<void> {
  const root = getWorkspaceRoot();
  const pkgPath = path.join(root, "package.json");
  if (!fs.existsSync(pkgPath)) {
    vscode.window.showWarningMessage("No hay package.json.");
    return;
  }
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  const projectName = pkg.name || path.basename(root);

  const choice = await vscode.window.showQuickPick(
    [
      { label: "$(rocket) Direct Upload (Wrangler)", description: "Sin Git. Build + deploy directo", action: "wrangler" },
      { label: "$(github) Git Integration", description: "Conectar repo en Cloudflare dashboard", action: "git" }
    ],
    { placeHolder: "Como quieres hacer el deploy?" }
  );
  if (!choice) return;

  if (choice.action === "git") {
    const url = "https://dash.cloudflare.com/?to=/:account/workers-and-pages";
    const sel = await vscode.window.showInformationMessage(
      "Abre Cloudflare -> Workers & Pages -> Create -> Pages -> Connect to Git.",
      "Abrir Cloudflare"
    );
    if (sel === "Abrir Cloudflare") vscode.env.openExternal(vscode.Uri.parse(url));
    return;
  }

  const term = vscode.window.createTerminal({ name: "mio: deploy", cwd: root, isTransient: true });
  term.show();
  term.sendText("npm run build");
  await new Promise((r) => setTimeout(r, 8000));
  term.sendText("npx wrangler pages deploy dist --project-name=" + projectName);
  vscode.window.showInformationMessage("Deploy en curso. Si es la primera vez: npx wrangler login");
}
