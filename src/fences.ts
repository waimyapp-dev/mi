export function stripCodeFences(content: string): string {
  return content.split("\n").filter(l => !/^\s*```\w*\s*$/.test(l)).join("\n");
}
