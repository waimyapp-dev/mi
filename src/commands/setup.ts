import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { setAnchor } from "../anchors.js";
import { init } from "./init.js";

export interface SetupOptions { framework: string; lang: "ts" | "js"; style: "tailwind" | "css-modules" | "plain"; }

function writeBlock(opts: { root: string; anchor: string; blockId: string; desc: string; content: string; strict?: boolean }) {
  const target = path.resolve(opts.root, opts.anchor);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const ext = path.extname(opts.anchor).toLowerCase();
  const base = path.basename(opts.anchor);
  let open = "// ", close = "";
  if (ext === ".css" || ext === ".scss") { open = "/* "; close = " */"; }
  else if (ext === ".html") { open = "<!-- "; close = " -->"; }
  else if (ext === ".json" || ext === ".env" || base === ".gitignore") { open = "# "; close = ""; }
  const source = [open + "@anchor:" + opts.anchor + close, open + "@block:" + opts.blockId + " [" + opts.desc + "]" + close, opts.content.trimEnd(), open + "@end:" + opts.blockId + close].join("\n") + "\n";
  const srcDir = path.join(opts.root, ".mi", "blocks", opts.blockId);
  fs.mkdirSync(srcDir, { recursive: true });
  fs.writeFileSync(path.join(srcDir, "source.txt"), source, "utf8");
  fs.writeFileSync(target, opts.strict ? opts.content.trimEnd() + "\n" : source, "utf8");
  setAnchor(opts.root, opts.blockId, { file: opts.anchor, css: null, inject: true, type: "setup" });
  console.log("  " + opts.anchor + "  [" + opts.blockId + "]");
}

export function setup(opts: SetupOptions, root = process.cwd()): void {
  const lang = opts.lang === "js" ? "js" : "ts";
  const style = opts.style || "tailwind";
  console.log("Configurando: " + opts.framework + " + " + lang + " + " + style + "\n");
  try { init(root); } catch (e) {}

  const deps: any = {};
  const devDeps: any = { vite: "^5.4.0" };
  const scripts = { dev: "vite", build: "vite build", preview: "vite preview" };
  let ext = lang === "ts" ? "tsx" : "jsx";
  let mainCode = "", appCode = "";
  let mainFile = "src/main." + ext;
  let appFile = "src/App." + ext;
  let indexEntry = "/src/main." + ext;

  if (opts.framework === "react") {
    deps.react = "^18.3.0"; deps["react-dom"] = "^18.3.0";
    devDeps["@vitejs/plugin-react"] = "^4.3.0";
    if (lang === "ts") { devDeps.typescript = "^5.6.0"; devDeps["@types/react"] = "^18.3.0"; devDeps["@types/react-dom"] = "^18.3.0"; }
    mainCode = 'import React from "react";\nimport ReactDOM from "react-dom/client";\nimport { App } from "./App";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\nReactDOM.createRoot(document.getElementById("app")' + (lang === "ts" ? "!" : "") + ').render(\n  <React.StrictMode>\n    <App />\n  </React.StrictMode>\n);';
    appCode = 'export function App() {\n  return (\n    <div' + (style === "tailwind" ? ' className="p-8"' : "") + '>\n      <h1>Hola desde mio + React</h1>\n    </div>\n  );\n}';
  } else if (opts.framework === "vue") {
    deps.vue = "^3.5.0"; devDeps["@vitejs/plugin-vue"] = "^5.1.0";
    if (lang === "ts") devDeps.typescript = "^5.6.0";
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; appFile = "src/App.vue"; indexEntry = "/src/main." + ext;
    mainCode = 'import { createApp } from "vue";\nimport App from "./App.vue";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\ncreateApp(App).mount("#app");';
    appCode = '<template>\n  <div' + (style === "tailwind" ? ' class="p-8"' : "") + '>\n    <h1>Hola desde mio + Vue</h1>\n  </div>\n</template>\n\n<script setup' + (lang === "ts" ? ' lang="ts"' : "") + '>\n</script>';
  } else if (opts.framework === "svelte") {
    devDeps.svelte = "^4.2.0"; devDeps["@sveltejs/vite-plugin-svelte"] = "^3.1.0";
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; appFile = "src/App.svelte"; indexEntry = "/src/main." + ext;
    mainCode = 'import App from "./App.svelte";\n' + (style === "tailwind" ? 'import "./index.css";\n' : "") + '\nconst app = new App({ target: document.getElementById("app") });\nexport default app;';
    appCode = '<script' + (lang === "ts" ? ' lang="ts"' : "") + '>\n</script>\n\n<div' + (style === "tailwind" ? ' class="p-8"' : "") + '>\n  <h1>Hola desde mio + Svelte</h1>\n</div>';
  } else if (opts.framework === "next") {
    deps.next = "^14.2.0"; deps.react = "^18.3.0"; deps["react-dom"] = "^18.3.0";
    scripts.dev = "next dev"; scripts.build = "next build"; (scripts as any).start = "next start";
    if (lang === "ts") { devDeps.typescript = "^5.6.0"; devDeps["@types/react"] = "^18.3.0"; devDeps["@types/node"] = "^22.0.0"; }
    const nextExt = lang === "ts" ? "tsx" : "jsx";
    writeBlock({ root, anchor: "app/layout." + nextExt, blockId: "layout-setup", desc: "Layout raiz", content: 'export const metadata = { title: "mio app" };\n\nexport default function RootLayout({ children }: { children: React.ReactNode }) {\n  return (\n    <html lang="es">\n      <body' + (style === "tailwind" ? ' className="p-8"' : "") + '>{children}</body>\n    </html>\n  );\n}' });
    writeBlock({ root, anchor: "app/page." + nextExt, blockId: "page-setup", desc: "Pagina principal", content: 'export default function Home() {\n  return <h1>Hola desde mio + Next.js</h1>;\n}' });
  } else {
    ext = lang === "ts" ? "ts" : "js"; mainFile = "src/main." + ext; indexEntry = "/src/main." + ext;
    mainCode = (style === "tailwind" ? 'import "./index.css";\n\n' : "") + 'document.getElementById("app"' + (lang === "ts" ? "!" : "") + ').innerHTML = \'<div' + (style === "tailwind" ? ' class="p-8"' : "") + '><h1>Hola desde mio + Vanilla</h1></div>\';';
  }

  if (style === "tailwind") {
    devDeps.tailwindcss = "^3.4.0"; devDeps.postcss = "^8.4.0"; devDeps.autoprefixer = "^10.4.0";
    writeBlock({ root, anchor: "tailwind.config.js", blockId: "tailwind-setup", desc: "Config Tailwind", content: '/** @type {import(\'tailwindcss\').Config} */\nexport default {\n  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx,vue,svelte}"],\n  theme: { extend: {} },\n  plugins: [],\n};' });
    writeBlock({ root, anchor: "postcss.config.js", blockId: "postcss-setup", desc: "Config PostCSS", content: 'export default {\n  plugins: { tailwindcss: {}, autoprefixer: {} },\n};' });
  }

  const pkg = { name: "mio-app", private: true, version: "0.1.0", type: "module", scripts, dependencies: deps, devDependencies: devDeps };
  writeBlock({ root, anchor: "package.json", blockId: "package-setup", desc: "Dependencias y scripts", content: JSON.stringify(pkg, null, 2), strict: true });

  writeBlock({ root, anchor: "index.html", blockId: "index-html-setup", desc: "Shell HTML", content: '<!DOCTYPE html>\n<html lang="es">\n  <head>\n    <meta charset="UTF-8" />\n    <meta name="viewport" content="width=device-width, initial-scale=1.0" />\n    <title>mio app</title>\n  </head>\n  <body>\n    <div id="app"></div>\n    <script type="module" src="' + indexEntry + '"></script>\n  </body>\n</html>' });

  if (lang === "ts" && opts.framework !== "next") {
    writeBlock({ root, anchor: "tsconfig.json", blockId: "tsconfig-setup", desc: "Config TypeScript", content: JSON.stringify({ compilerOptions: { target: "ES2022", lib: ["ES2022", "DOM", "DOM.Iterable"], module: "ESNext", moduleResolution: "Bundler", strict: true, esModuleInterop: true, skipLibCheck: true, noEmit: true, ...(opts.framework === "react" ? { jsx: "react-jsx" } : {}) }, include: ["src"] }, null, 2), strict: true });
  }

  if (mainCode && mainFile) writeBlock({ root, anchor: mainFile, blockId: "main-setup", desc: "Entry point", content: mainCode });
  if (appCode && appFile) writeBlock({ root, anchor: appFile, blockId: "app-setup", desc: "Componente raiz", content: appCode });
  if (style === "tailwind") writeBlock({ root, anchor: "src/index.css", blockId: "css-setup", desc: "Directivas Tailwind", content: "@tailwind base;\n@tailwind components;\n@tailwind utilities;" });

  console.log("\nInstalando dependencias...");
  execSync("npm install", { cwd: root, stdio: "inherit" });
  console.log("\nOK. Ejecuta: npm run dev\n");
}
