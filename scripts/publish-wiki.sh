#!/usr/bin/env bash
set -euo pipefail

# Compiles all Markdown docs, templates, and 30 case pages into GitHub Wiki format
# for every locale under wiki/<locale>/, docs/<locale>/, ... and pushes them to
# https://github.com/xirothedev/ai-coding-interviews.wiki.git
#
# English pages land at the wiki root (default locale); other locales land under
# <locale>/ (e.g. vi/Home).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIKI_REMOTE="${WIKI_REMOTE:-https://github.com/xirothedev/ai-coding-interviews.wiki.git}"
BUILD_DIR="${TMPDIR:-/tmp}/ai-coding-interviews-wiki-build"

echo "==> Preparing Wiki build directory at ${BUILD_DIR}..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

LOCALES=(en)
for d in "${REPO_ROOT}"/wiki/*/; do
  loc="$(basename "$d")"
  [[ "$loc" == "en" ]] && continue
  LOCALES+=("$loc")
done

# English (default locale) -> wiki root
copy_locale() {
  local locale="$1"
  local target_root="$2"   # "" for en (BUILD_DIR root), else "vi"
  local src_wiki="${REPO_ROOT}/wiki/${locale}"
  local src_docs="${REPO_ROOT}/docs/${locale}"
  local src_templates="${REPO_ROOT}/templates/${locale}"
  local src_cases="${REPO_ROOT}/cases/${locale}"
  local dest="${BUILD_DIR}"
  [[ -n "$target_root" ]] && dest="${BUILD_DIR}/${target_root}"
  mkdir -p "$dest"

  [[ -f "${src_wiki}/Home.md" ]] && cp "${src_wiki}/Home.md" "${dest}/Home.md"
  [[ -f "${src_wiki}/_Sidebar.md" ]] && cp "${src_wiki}/_Sidebar.md" "${dest}/_Sidebar.md"
  [[ -f "${src_wiki}/_Footer.md" ]] && cp "${src_wiki}/_Footer.md" "${dest}/_Footer.md"

  for file in "${src_docs}"/*.md; do
    [[ -f "$file" ]] || continue
    cp "$file" "${dest}/$(basename "$file")"
  done
  for file in "${src_templates}"/*.md; do
    [[ -f "$file" ]] || continue
    cp "$file" "${dest}/$(basename "$file")"
  done

  if [[ -f "${src_cases}/easy/README.md" ]]; then
    cp "${src_cases}/easy/README.md" "${dest}/Easy-Tier-Catalog.md"
  fi
  if [[ -f "${src_cases}/medium/README.md" ]]; then
    cp "${src_cases}/medium/README.md" "${dest}/Medium-Tier-Catalog.md"
  fi
  if [[ -f "${src_cases}/hard/README.md" ]]; then
    cp "${src_cases}/hard/README.md" "${dest}/Hard-Tier-Catalog.md"
  fi
  for tier in easy medium hard; do
    for file in "${src_cases}/${tier}"/*.md; do
      [[ -f "$file" ]] || continue
      base="$(basename "$file")"
      [[ "$base" == "README.md" ]] && continue
      cp "$file" "${dest}/${base}"
    done
  done
}

# Default locale (en) at root
copy_locale en ""

# Other locales under their own folder
for loc in "${LOCALES[@]}"; do
  [[ "$loc" == "en" ]] && continue
  copy_locale "$loc" "$loc"
done

# Normalize relative markdown links for flat GitHub Wiki structure
python3 - "${BUILD_DIR}" << 'PYEOF'
import os, re, sys

build_dir = sys.argv[1]

def locale_of(relpath):
    first = relpath.split(os.sep)[0]
    return first if first in ("vi",) else "en"

# locale list derived from top-level dirs
locales = [d for d in os.listdir(build_dir) if os.path.isdir(os.path.join(build_dir, d))]

for root, _, files in os.walk(build_dir):
    for fname in files:
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(root, fname)
        rel = os.path.relpath(fpath, build_dir)
        locale = locale_of(rel)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        is_vi = (locale == "vi")

        # Tier README link maps
        if is_vi:
            content = content.replace("(../easy/README.md)", "(vi/Easy-Tier-Catalog)")
            content = content.replace("(../medium/README.md)", "(vi/Medium-Tier-Catalog)")
            content = content.replace("(../hard/README.md)", "(vi/Hard-Tier-Catalog)")
            content = content.replace("(cases/easy/README.md)", "(vi/Easy-Tier-Catalog)")
            content = content.replace("(cases/medium/README.md)", "(vi/Medium-Tier-Catalog)")
            content = content.replace("(cases/hard/README.md)", "(vi/Hard-Tier-Catalog)")
            content = content.replace("(../../README.md)", "(vi/Home)")
        else:
            content = content.replace("(../easy/README.md)", "(Easy-Tier-Catalog)")
            content = content.replace("(../medium/README.md)", "(Medium-Tier-Catalog)")
            content = content.replace("(../hard/README.md)", "(Hard-Tier-Catalog)")
            content = content.replace("(cases/easy/README.md)", "(Easy-Tier-Catalog)")
            content = content.replace("(cases/medium/README.md)", "(Medium-Tier-Catalog)")
            content = content.replace("(cases/hard/README.md)", "(Hard-Tier-Catalog)")
            content = content.replace("(../../README.md)", "(Home)")

        if fname.startswith("E"):
            content = content.replace("(README.md)", "(Easy-Tier-Catalog)" if not is_vi else "(vi/Easy-Tier-Catalog)")
        elif fname.startswith("M"):
            content = content.replace("(README.md)", "(Medium-Tier-Catalog)" if not is_vi else "(vi/Medium-Tier-Catalog)")
        elif fname.startswith("H") and fname != "Home.md" and not fname.startswith("Hard-Tier"):
            content = content.replace("(README.md)", "(Hard-Tier-Catalog)" if not is_vi else "(vi/Hard-Tier-Catalog)")

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
            if is_vi and base and not base.startswith("vi/"):
                base = "vi/" + base
            return f"[{label}]({base}{anchor})"

        content = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", rewrite_link, content)
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
PYEOF

PAGE_COUNT=$(find "${BUILD_DIR}" -name '*.md' | wc -l | tr -d ' ')
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
PYEOF
chmod +x /Users/xirothedev/workspace/ai-coding-interviews/scripts/publish-wiki.sh