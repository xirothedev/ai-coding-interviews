#!/usr/bin/env bash
set -euo pipefail

# Compiles all Markdown docs, templates, and 30 case pages into GitHub Wiki format
# and pushes them to https://github.com/xirothedev/ai-coding-interviews.wiki.git

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIKI_REMOTE="${WIKI_REMOTE:-https://github.com/xirothedev/ai-coding-interviews.wiki.git}"
BUILD_DIR="${TMPDIR:-/tmp}/ai-coding-interviews-wiki-build"

echo "==> Preparing Wiki build directory at ${BUILD_DIR}..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 1. Copy Wiki layout files (Home.md, _Sidebar.md, _Footer.md)
cp "${REPO_ROOT}/wiki/Home.md" "${BUILD_DIR}/Home.md"
cp "${REPO_ROOT}/wiki/_Sidebar.md" "${BUILD_DIR}/_Sidebar.md"
cp "${REPO_ROOT}/wiki/_Footer.md" "${BUILD_DIR}/_Footer.md"

# 2. Copy Playbooks & Templates and rewrite relative .md links to flat Wiki page slugs
for file in "${REPO_ROOT}"/docs/*.md "${REPO_ROOT}"/templates/*.md; do
  filename="$(basename "${file}")"
  cp "${file}" "${BUILD_DIR}/${filename}"
done

# 3. Copy Tier Catalog READMEs as dedicated Wiki catalog pages
cp "${REPO_ROOT}/cases/easy/README.md" "${BUILD_DIR}/Easy-Tier-Catalog.md"
cp "${REPO_ROOT}/cases/medium/README.md" "${BUILD_DIR}/Medium-Tier-Catalog.md"
cp "${REPO_ROOT}/cases/hard/README.md" "${BUILD_DIR}/Hard-Tier-Catalog.md"

# 4. Copy all 30 standalone case pages
for file in "${REPO_ROOT}"/cases/easy/E*.md "${REPO_ROOT}"/cases/medium/M*.md "${REPO_ROOT}"/cases/hard/H*.md; do
  filename="$(basename "${file}")"
  cp "${file}" "${BUILD_DIR}/${filename}"
done

# 5. Normalize relative markdown links for flat GitHub Wiki structure
python3 - "${BUILD_DIR}" << 'EOF'
import os, re, sys

build_dir = sys.argv[1]
for fname in os.listdir(build_dir):
    if not fname.endswith(".md"):
        continue
    fpath = os.path.join(build_dir, fname)
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()

    # Map tier README links
    content = content.replace("(../easy/README.md)", "(Easy-Tier-Catalog)")
    content = content.replace("(../medium/README.md)", "(Medium-Tier-Catalog)")
    content = content.replace("(../hard/README.md)", "(Hard-Tier-Catalog)")
    content = content.replace("(cases/easy/README.md)", "(Easy-Tier-Catalog)")
    content = content.replace("(cases/medium/README.md)", "(Medium-Tier-Catalog)")
    content = content.replace("(cases/hard/README.md)", "(Hard-Tier-Catalog)")
    content = content.replace("(../../README.md)", "(Home)")

    if fname.startswith("E"):
        content = content.replace("(README.md)", "(Easy-Tier-Catalog)")
    elif fname.startswith("M"):
        content = content.replace("(README.md)", "(Medium-Tier-Catalog)")
    elif fname.startswith("H") and fname != "Home.md" and fname != "Hard-Tier-Catalog.md":
        content = content.replace("(README.md)", "(Hard-Tier-Catalog)")

    # Strip directory prefixes and .md suffixes on internal links (excluding http/https)
    def rewrite_link(match):
        label, target = match.group(1), match.group(2)
        if target.startswith(("http://", "https://", "#", "mailto:")):
            return match.group(0)
        anchor = ""
        if "#" in target:
            target, anchor = target.split("#", 1)
            anchor = "#" + anchor
        base = os.path.basename(target)
        if base.endswith(".md"):
            base = base[:-3]
        if base == "README":
            base = "Home"
        return f"[{label}]({base}{anchor})"

    content = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", rewrite_link, content)
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(content)
EOF

PAGE_COUNT=$(find "${BUILD_DIR}" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
echo "==> Compiled ${PAGE_COUNT} Wiki pages in ${BUILD_DIR}."

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "==> Dry run complete. Files generated at: ${BUILD_DIR}"
  exit 0
fi

cd "${BUILD_DIR}"
git init -b master
git add .
git commit -m "docs(wiki): sync ${PAGE_COUNT} wiki pages (Home, Sidebar, Playbooks, and 30 Cases)"
git remote add origin "${WIKI_REMOTE}"
git push --force origin master:master
echo "==> Successfully published Wiki to https://github.com/xirothedev/ai-coding-interviews/wiki"
