#!/usr/bin/env bash
set -euo pipefail

# Compiles all Markdown docs, templates, and 30 case pages into GitHub Wiki format
# for every locale. English pages land at the wiki root (default locale); other
# locales land at the wiki root with a "<locale>-" prefix (e.g. vi-Home), because
# GitHub Wiki does not support slash-based sub-pages.

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

copy_locale() {
  local locale="$1"
  local prefix="$2"   # "" for en, else "vi-"
  local src_wiki="${REPO_ROOT}/wiki/${locale}"
  local src_docs="${REPO_ROOT}/docs/${locale}"
  local src_templates="${REPO_ROOT}/templates/${locale}"
  local src_cases="${REPO_ROOT}/cases/${locale}"
  local dest="${BUILD_DIR}"

  if [[ -f "${src_wiki}/Home.md" ]]; then
    cp "${src_wiki}/Home.md" "${dest}/${prefix}Home.md"
  fi
  if [[ -f "${src_wiki}/_Sidebar.md" ]]; then
    cp "${src_wiki}/_Sidebar.md" "${dest}/${prefix}_Sidebar.md"
  fi
  if [[ -f "${src_wiki}/_Footer.md" ]]; then
    cp "${src_wiki}/_Footer.md" "${dest}/${prefix}_Footer.md"
  fi

  for file in "${src_docs}"/*.md; do
    [[ -f "$file" ]] || continue
    cp "$file" "${dest}/${prefix}$(basename "$file")"
  done
  for file in "${src_templates}"/*.md; do
    [[ -f "$file" ]] || continue
    cp "$file" "${dest}/${prefix}$(basename "$file")"
  done

  if [[ -f "${src_cases}/easy/README.md" ]]; then
    cp "${src_cases}/easy/README.md" "${dest}/${prefix}Easy-Tier-Catalog.md"
  fi
  if [[ -f "${src_cases}/medium/README.md" ]]; then
    cp "${src_cases}/medium/README.md" "${dest}/${prefix}Medium-Tier-Catalog.md"
  fi
  if [[ -f "${src_cases}/hard/README.md" ]]; then
    cp "${src_cases}/hard/README.md" "${dest}/${prefix}Hard-Tier-Catalog.md"
  fi
  for tier in easy medium hard; do
    for file in "${src_cases}/${tier}"/*.md; do
      [[ -f "$file" ]] || continue
      base="$(basename "$file")"
      [[ "$base" == "README.md" ]] && continue
      cp "$file" "${dest}/${prefix}${base}"
    done
  done
}

# Default locale (en) at root
copy_locale en ""

# Other locales with prefix
for loc in "${LOCALES[@]}"; do
  [[ "$loc" == "en" ]] && continue
  copy_locale "$loc" "${loc}-"
done

# Normalize relative markdown links for flat GitHub Wiki structure
python3 - "${BUILD_DIR}" << 'PYEOF'
import os, re, sys

build_dir = sys.argv[1]

def locale_of(filename):
    # detect locale by filename prefix like "vi-"
    if filename.startswith("vi-"):
        return "vi"
    return "en"

for root, _, files in os.walk(build_dir):
    for fname in files:
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(root, fname)
        locale = locale_of(fname)
        is_vi = (locale == "vi")
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        if is_vi:
            content = content.replace("(../easy/README.md)", "(vi-Easy-Tier-Catalog)")
            content = content.replace("(../medium/README.md)", "(vi-Medium-Tier-Catalog)")
            content = content.replace("(../hard/README.md)", "(vi-Hard-Tier-Catalog)")
            content = content.replace("(cases/easy/README.md)", "(vi-Easy-Tier-Catalog)")
            content = content.replace("(cases/medium/README.md)", "(vi-Medium-Tier-Catalog)")
            content = content.replace("(cases/hard/README.md)", "(vi-Hard-Tier-Catalog)")
            content = content.replace("(../../README.md)", "(vi-Home)")
        else:
            content = content.replace("(../easy/README.md)", "(Easy-Tier-Catalog)")
            content = content.replace("(../medium/README.md)", "(Medium-Tier-Catalog)")
            content = content.replace("(../hard/README.md)", "(Hard-Tier-Catalog)")
            content = content.replace("(cases/easy/README.md)", "(Easy-Tier-Catalog)")
            content = content.replace("(cases/medium/README.md)", "(Medium-Tier-Catalog)")
            content = content.replace("(cases/hard/README.md)", "(Hard-Tier-Catalog)")
            content = content.replace("(../../README.md)", "(Home)")

        if fname.startswith("E") and not fname.startswith("vi-"):
            content = content.replace("(README.md)", "(Easy-Tier-Catalog)")
        elif fname.startswith("vi-E"):
            content = content.replace("(README.md)", "(vi-Easy-Tier-Catalog)")
        elif fname.startswith("M") and not fname.startswith("vi-"):
            content = content.replace("(README.md)", "(Medium-Tier-Catalog)")
        elif fname.startswith("vi-M"):
            content = content.replace("(README.md)", "(vi-Medium-Tier-Catalog)")
        elif fname.startswith("H") and fname != "Home.md" and not fname.startswith("Hard-Tier") and not fname.startswith("vi-"):
            content = content.replace("(README.md)", "(Hard-Tier-Catalog)")
        elif fname.startswith("vi-H") and fname != "vi-Home.md" and not fname.startswith("vi-Hard-Tier"):
            content = content.replace("(README.md)", "(vi-Hard-Tier-Catalog)")

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
            if is_vi and base and not base.startswith("vi-"):
                base = "vi-" + base
            return f"[{label}]({base}{anchor})"

        content = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", rewrite_link, content)
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
PYEOF

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