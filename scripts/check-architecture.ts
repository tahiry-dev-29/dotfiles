import { readdir } from "node:fs/promises";
import { join } from "node:path";

const MAX_LINES = 200;
const IGNORED_DIRS = new Set([".git", "node_modules", "dist", "generated", "migrations", ".nx", ".angular"]);

async function scanDirectory(dirPath: string) {
  const entries = await readdir(dirPath, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = join(dirPath, entry.name);

    if (entry.isDirectory()) {
      if (IGNORED_DIRS.has(entry.name)) continue;
      await scanDirectory(fullPath);
    } else if (entry.isFile()) {
      await validateFile(fullPath, entry.name);
    }
  }
}

async function validateFile(filePath: string, fileName: string) {
  // Check code files only
  if (!fileName.endsWith(".ts") && !fileName.endsWith(".html") && !fileName.endsWith(".css")) {
    return;
  }

  // 1. Strict naming rule: ban old component naming convention
  if (fileName.includes(".component.ts")) {
    console.error(`❌ Architecture Error: Avoid '.component.ts' suffix. Use Clean Component name directly: ${filePath}`);
    process.exit(1);
  }

  const file = Bun.file(filePath);
  const content = await file.text();
  const lines = content.split("\n");

  // 2. Strict file length rule (Max 200 lines to enforce micro-components)
  if (lines.length > MAX_LINES && !fileName.endsWith(".spec.ts")) {
    console.error(`❌ Architecture Error: File too long (${lines.length} lines). Max allowed is ${MAX_LINES} lines: ${filePath}`);
    process.exit(1);
  }

  // 3. Strict Single Class rule: enforce one class per file
  if (fileName.endsWith(".ts")) {
    const classMatches = content.match(/export\s+class\s+\w+/g) || [];
    if (classMatches.length > 1) {
      console.error(`❌ Architecture Error: Multiple exported classes detected (${classMatches.length}). Rule is One Class Per File: ${filePath}`);
      process.exit(1);
    }
  }
}

console.log("🔍 Scanning monorepo architecture and structural rules...");
await scanDirectory(process.cwd());
console.log("✅ Architecture compliance validated successfully!");
