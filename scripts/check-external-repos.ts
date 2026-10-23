import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "..");
const CASES_DIR = join(ROOT, "cases");

function getCaseFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...getCaseFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      results.push(fullPath);
    }
  }
  return results;
}

function extractGithubRepos(files: string[]): Map<string, string[]> {
  const repoToFiles = new Map<string, string[]>();
  const repoRegex = /https:\/\/github\.com\/([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)/g;

  for (const file of files) {
    const content = readFileSync(file, "utf8");
    for (const match of content.matchAll(repoRegex)) {
      const rawRepo = match[1]?.replace(/\.git$/, "").replace(/[).,;]+$/, "");
      if (!rawRepo) continue;
      const existing = repoToFiles.get(rawRepo) ?? [];
      const relFile = file.replace(`${ROOT}/`, "");
      if (!existing.includes(relFile)) {
        existing.push(relFile);
      }
      repoToFiles.set(rawRepo, existing);
    }
  }
  return repoToFiles;
}

async function main() {
  const files = getCaseFiles(CASES_DIR);
  const repoToFiles = extractGithubRepos(files);
  console.log(
    `Checking ${repoToFiles.size} unique GitHub repositories across ${files.length} case files...`,
  );

  const token = process.env.GITHUB_TOKEN;
  const failures: string[] = [];

  for (const [repo, referencedBy] of repoToFiles.entries()) {
    const apiUrl = `https://api.github.com/repos/${repo}`;
    const webUrl = `https://github.com/${repo}`;
    const headers: Record<string, string> = {
      Accept: "application/vnd.github+json",
      "User-Agent": "ai-coding-interviews-repo-checker",
    };
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }

    try {
      const res = await fetch(apiUrl, { method: "GET", redirect: "follow", headers });
      if (!res.ok) {
        failures.push(
          `${webUrl} returned HTTP ${res.status} (referenced in: ${referencedBy.join(", ")})`,
        );
      } else {
        console.log(`  [OK] ${webUrl}`);
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      failures.push(
        `${webUrl} failed to fetch: ${message} (referenced in: ${referencedBy.join(", ")})`,
      );
    }
  }

  if (failures.length > 0) {
    console.error("\nBroken or unreachable external repositories detected:");
    for (const failure of failures) {
      console.error(`  - ${failure}`);
    }
    process.exit(1);
  }

  console.log(`\nAll ${repoToFiles.size} external GitHub repositories are reachable!`);
}

await main();
