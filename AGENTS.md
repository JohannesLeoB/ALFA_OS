# AGENTS.md

Rules for every change to this repository. The schema lives in [ARCHITECTURE.md](ARCHITECTURE.md#schema); `utils/check.py` enforces it.

## Schema

- Folders: `App/<Feature>`, `Sources/<Module>/{Model,Logic,Port,Adapter,State,Store,Tool}`, `Sources/Integrations/<Service>`, `Tests/<Module>Tests`.
- One main type per file, file name = type name. Role suffix decides the folder: Client in Adapter, Engine in Logic, Store in Store, Port in Port, Tool in Tool, State in State, Failure in Model.
- Name words from the suffix list only; Manager, Helper, Util, Service, Handler, Impl, Base, Common, Misc, New, Old and number suffixes do not exist.
- `internal` by default; `public` when another module calls it. Remove code with no caller.

## Content

- English identifiers in ASCII, CamelCase, no module prefix.
- Code carries no comments and no prose. User-facing text is a key in a `Resources/*.localizable.json` file, merged into `Resources/Localizable.xcstrings` by `utils/merge_strings.py`.
- Views take every colour, size, spacing, radius and duration from `Design` tokens or `App/Design/SheetValues.swift`; the only literals are 0, 1 and 2. Token values change in `Resources/tokens.json`, then `utils/generate_tokens.py` regenerates `Sources/Design/Model`.
- The company name and company values stay out of code; they come from the company configuration file described in [README.md](README.md).
- The Markdown files are `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`. Each statement in the first three is checkable in the code; `CLAUDE.md` is the session start and carries status, decisions and next tasks, kept current with every change of them.

## Workflow

1. Read the files you change and their callers first.
2. Change the code. Behaviour changes only when the task asks for it.
3. Run `python3 -I utils/check.py` and `zsh utils/check_modules.sh`; both end green before a commit.
4. Write the commit message as: subject of at most 72 characters, blank line, at most three body lines, and the last line exactly `Designed by Johannes Leo Berger, made with help of Claude`. `utils/commit_check.py` verifies it.
5. Commit and push to `main`. History moves forward only.

## Sandbox

When a sandbox blocks a command or a test, report the blocked restriction and leave production code as it is.
