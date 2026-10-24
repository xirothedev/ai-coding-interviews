import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "..");

function getMarkdownFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === "node_modules" || entry.name === ".git") continue;
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...getMarkdownFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      results.push(fullPath);
    }
  }
  return results;
}

describe("AI Coding Interviews Repository Integrity", () => {
  const easyCases = readdirSync(join(ROOT, "cases/en/easy"))
    .filter((f) => /^E\d{2}-.*\.md$/.test(f))
    .sort();
  const mediumCases = readdirSync(join(ROOT, "cases/en/medium"))
    .filter((f) => /^M\d{2}-.*\.md$/.test(f))
    .sort();
  const hardCases = readdirSync(join(ROOT, "cases/en/hard"))
    .filter((f) => /^H\d{2}-.*\.md$/.test(f))
    .sort();

  test("contains exactly 30 interview cases (10 Easy, 10 Medium, 10 Hard)", () => {
    expect(easyCases).toHaveLength(10);
    expect(mediumCases).toHaveLength(10);
    expect(hardCases).toHaveLength(10);
  });

  test("every case file contains the 5 mandatory rubric and setup sections", () => {
    const allCases = [
      ...easyCases.map((f) => join(ROOT, "cases/en/easy", f)),
      ...mediumCases.map((f) => join(ROOT, "cases/en/medium", f)),
      ...hardCases.map((f) => join(ROOT, "cases/en/hard", f)),
    ];

    const requiredHeadings = [
      "## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)",
      "## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)",
      "## 3. The AI Traps & Expected Solution (Confidential)",
      "## 4. Reference Divide-and-Conquer Prompt Flow",
      "## 5. HR & Interviewer Grading Rubric (All 7 Criteria)",
    ];

    for (const filePath of allCases) {
      const content = readFileSync(filePath, "utf8");
      for (const heading of requiredHeadings) {
        expect(content).toContain(heading);
      }
      expect(content).toMatch(/https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+/);

      // Ensure Section 2 (Candidate Instructions) is written as a natural prompt without file/line spoilers
      const sec2Start = content.indexOf("## 2. Candidate Instructions");
      const sec3Start = content.indexOf("## 3. The AI Traps");
      const sec2Content = content.slice(sec2Start, sec3Start);
      expect(sec2Content).not.toMatch(/\b[A-Za-z0-9_-]+\.(py|ts|tsx|go|java|rs|cs|kt)\b/);
      expect(sec2Content).not.toMatch(/\bline\s+\d+\b/i);
    }
  });

  test("root README.md and wiki/_Sidebar.md index all 30 case IDs", () => {
    const readme = readFileSync(join(ROOT, "README.md"), "utf8");
    const sidebar = readFileSync(join(ROOT, "wiki/en/_Sidebar.md"), "utf8");

    for (let i = 1; i <= 10; i++) {
      const num = String(i).padStart(2, "0");
      for (const prefix of ["E", "M", "H"]) {
        const id = `${prefix}${num}`;
        expect(readme).toContain(id);
        expect(sidebar).toContain(id);
      }
    }
  });

  test("all internal relative Markdown file links resolve to existing files", () => {
    const mdFiles = getMarkdownFiles(ROOT).filter((f) => !f.startsWith(join(ROOT, "wiki")));
    const linkRegex = /\[[^\]]+\]\(([^)]+)\)/g;

    for (const mdFile of mdFiles) {
      const content = readFileSync(mdFile, "utf8");
      // Strip fenced code blocks to avoid matching example links inside code snippets
      const stripped = content.replace(/```[\s\S]*?```/g, "");
      for (const match of stripped.matchAll(linkRegex)) {
        const rawTarget = match[1]?.trim();
        if (!rawTarget) continue;
        if (
          rawTarget.startsWith("http://") ||
          rawTarget.startsWith("https://") ||
          rawTarget.startsWith("mailto:") ||
          rawTarget.startsWith("#")
        ) {
          continue;
        }
        const [pathPart] = rawTarget.split("#");
        if (!pathPart) continue;
        // Wiki page slugs (no file extension) are not filesystem paths
        if (!pathPart.includes(".")) continue;
        const resolvedRelative = resolve(dirname(mdFile), pathPart);
        const resolvedFromRoot = resolve(ROOT, pathPart);
        const exists = existsSync(resolvedRelative) || existsSync(resolvedFromRoot);
        if (!exists) {
          throw new Error(`Broken link in ${mdFile}: "${rawTarget}" -> ${resolvedRelative}`);
        }
        expect(exists).toBe(true);
      }
    }
  });

  test("i18n parity: every English content file has a Vietnamese counterpart", () => {
    const roots = ["wiki", "docs", "templates", "cases"];
    for (const root of roots) {
      const enDir = join(ROOT, root, "en");
      if (!existsSync(enDir)) continue;
      const enFiles = getMarkdownFiles(enDir);
      for (const enFile of enFiles) {
        const rel = enFile.slice(enDir.length + 1);
        const viFile = join(ROOT, root, "vi", rel);
        expect(existsSync(viFile)).toBe(true);
      }
    }
  });

  test("publish-wiki.sh --dry-run builds all 86 Wiki pages cleanly", () => {
    const proc = Bun.spawnSync(["bash", "./scripts/publish-wiki.sh", "--dry-run"], {
      cwd: ROOT,
      stdout: "pipe",
      stderr: "pipe",
    });
    const output = proc.stdout.toString();
    expect(proc.exitCode).toBe(0);
    expect(output).toContain("Compiled 86 Wiki pages");
  });
});
