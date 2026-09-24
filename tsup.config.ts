import { defineConfig } from "tsup";
export default defineConfig({
  entry: { cli: "src/index.ts" },
  format: ["esm"],
  target: "node20",
  splitting: false,
  sourcemap: true,
  clean: true,
  minify: false,
  shims: true,
});
