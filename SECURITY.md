# Security & Confidentiality Policy

## Scope of This Repository

`ai-coding-interviews` is a curated Markdown knowledge base and wiki that maps real, open-source GitHub repositories into structured AI-enabled coding interview cases, rubrics, and prompt playbooks.

Even though this repository does not distribute compiled binaries or run production services, security and integrity matter in three areas:

1. **Supply-Chain Safety of Linked Open-Source Repositories**
2. **Protection Against Malicious Commands in Setup Snippets**
3. **Intellectual Property & Candidate Privacy Protection**

---

## Reporting a Vulnerability or Policy Violation

### 1. Malicious or Compromised Linked Repositories
Because interview cases reference external open-source GitHub repositories (and recommend specific tags or commit SHAs), if you discover that a linked repository:
- Has been compromised, hijacked, or injected with malicious dependency install scripts (`postinstall`, `setup.py`, etc.),
- Contains unsafe shell commands in its test runner,

Please **open a high-priority issue immediately** using the [Broken or Unsafe Repository Template](.github/ISSUE_TEMPLATE/broken_link_or_repo.yml) so maintainers can remove the link or pin a verified safe commit hash.

### 2. Accidental Inclusion of Proprietary / NDA Material or Candidate PII
All interview cases in this repository must be **clean-room educational designs built atop public open-source GitHub repositories**.
- Never commit real candidate names, transcripts, or private HR scorecards.
- Never commit proprietary, closed-source company codebases.

If you believe any contribution infringes copyright or leaks confidential material, please open an issue or contact the maintainers directly for immediate takedown.

---

## Safe Interview Sandbox Best Practices for HR & Interviewers

When running any third-party open-source repository during a live interview or practice session:
- **Pin Commit SHAs**: Always checkout the exact commit SHA specified in the case blueprint rather than pulling an unverified `HEAD` branch.
- **Use Isolated Environments**: Run candidate sessions in ephemeral cloud sandboxes (e.g., CoderPad, GitHub Codespaces, DevContainers, or Docker containers without host credentials mounted).
- **Never Mount Production Secrets**: Do not expose internal company API keys when provisioning AI assistants for candidates.
