# AGENTS.md

Rules for every change to this repository. The schema lives in [ARCHITECTURE.md](ARCHITECTURE.md#schema); `utils/check.py` enforces the rules marked (check) there; the others are reviewed.

## Schema

- Folders: `App/<Feature>`, `Sources/<Module>`, `Sources/Integrations/<Service>`, `Tests/<Module>Tests`. Swift files sit directly in the module; the old role folders `{Model,Logic,Port,Adapter,State,Store,Tool}` are dissolved module by module and keep their placement rule until then (check).
- One file per function, not per type (Johannes 30.10.): a file holds what one function needs, for example one POP mail file with client, session, store and entries; helpers are `private` inside; the file is named after the function. Aim for 200 to 600 lines, at most 800 (check); split by sub-function, never one type per file. Role suffixes (Client, Engine, Store, Port, Tool, State, Failure) name types, not folders.
- Manager, Helper, Util, Service, Handler, Impl, Base, Common, Misc, New, Old and number suffixes are not used in names (check for file and type names).
- `internal` by default; `public` when another module calls it. Remove code with no caller.

## Content

- English identifiers in ASCII, CamelCase, no module prefix (check: ASCII and CamelCase of file and type names; the rest is reviewed).
- Code carries no comments and no prose. User-facing text is a key in a `Resources/*.localizable.json` file (reviewed), merged into `Resources/Localizable.xcstrings` by `utils/merge_strings.py`.
- Views take every colour, size, spacing, radius and duration from `Design` tokens or `App/Design/SheetValues.swift`; the only literals are 0, 1 and 2. Token values change in `Resources/tokens.json`, then `utils/generate_tokens.py` regenerates `Sources/Design/Model`.
- The company name and company values stay out of code; they come from the company configuration file described in [README.md](README.md).
- The Markdown files are `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`. Each statement in the first three is meant to be checkable in the code; `utils/check.py` verifies only that their links and paths exist; `CLAUDE.md` is the session start and carries status, decisions and next tasks, kept current with every change of them.

## Workflow

1. Read the files you change and their callers first.
2. Change the code. Behaviour changes only when the task asks for it. A view is built only from the valid design master named in `CLAUDE.md`; where that master has no bow for it, the task stops and says so instead of inventing a form.
3. Run `python3 -I utils/check.py` and `zsh utils/check_modules.sh`; both end green before a commit.
4. Write the commit message as: subject of at most 72 characters, blank line, at most three body lines, and the last line exactly `Designed by Johannes Leo Berger, made with help of Claude`. `utils/commit_check.py` verifies it.
5. Commit and push to `main`. History moves forward only.

## Sandbox

When a sandbox blocks a command or a test, report the blocked restriction and leave production code as it is.
