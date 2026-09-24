import { spawn } from "node:child_process";
import * as vscode from "vscode";

export async function mioRun(args: string[], stdin?: string): Promise<string> {
  const cwd = getWorkspaceRoot();
  return new Promise((resolve, reject) => {
    const child = spawn("mio", args, { cwd, shell: true });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d: any) => (stdout += d.toString()));
    child.stderr.on("data", (d: any) => (stderr += d.toString()));
    child.on("close", (code: number) => {
      if (code === 0) resolve(stdout);
      else reject(new Error((stderr || "exit " + code).trim()));
    });
    child.on("error", reject);
    if (stdin) {
      child.stdin.write(stdin);
      child.stdin.end();
    }
  });
}

export function getWorkspaceRoot(): string {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) throw new Error("No hay workspace abierto");
  return folders[0].uri.fsPath;
}
