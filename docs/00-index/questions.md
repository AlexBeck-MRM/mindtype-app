<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  Q U E S T I O N S   L O G  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Running list of clarifications needed while building
    • WHY  ▸ Keep a persistent paper trail of open questions
    • HOW  ▸ Append dated entries; resolve items in-line when answered
-->

# Mind⠶Flow Questions Log

_Updated: 2025-11-15_

1. **Implementation doc path?** — Rules reference `docs/implementation.md`, but only `docs/02-implementation/02-Implementation.md` exists. Should we create a `docs/implementation.md` shim, rename the current file, or update all references to the numeric path?
2. **Questionnaire folder source?** — `scripts/qna_cleanup.cjs` expects `docs/questionnaire/*.md`, yet no such folder is present in the repo. Is the questionnaire content stored elsewhere, or should we restore the folder so the tooling works?
3. **Revolutionary architecture diagram location?** — `docs/04-architecture/README.md` links to `revolutionary-architecture.mmd`, but only `architecture.mmd` exists. Should we rename the existing file, add the missing diagram, or update the links?
4. **Project tidying scope?** — “Tidy up the project. All files.” could mean rewriting folder structure, deleting unused modules, or just running formatters. Which subsystems should be reorganized (TS core, Rust crate, docs, demos, macOS), and do we have a target architecture diagram to mirror during the cleanup?

<!-- DOC META: VERSION=1.0 | UPDATED=2025-11-15T00:00:00Z -->
