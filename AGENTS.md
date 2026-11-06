STALE AND HISTORIC - DONT BELIEVE THESE StONEAGED WORDS BELOW:



Rules for every change to this repository. The schema lives in [ARCHITECTURE.md](ARCHITECTURE.md#schema); `utils/check.py` enforces the rules marked (check) there; the others are reviewed.

## Schema

- Folders: `App/<Feature>`, `Sources/<Module>/{Model,Logic,Port,Adapter,State,Store,Tool}`, `Sources/Integrations/<Service>`, `Tests/<Module>Tests`. Role suffix decides the folder (check for file names): Client in Adapter, Engine in Logic, Parser in Logic or Adapter, Store in Store, Port in Port, Tool in Tool, State in State, Failure in Model. The folders Port, Tool, Store and State accept only names with their own suffix (Tool also Registry); where Router and Registry belong is reviewed.
- Strong files, not one type per file (Johannes 30.10.): inside its folder a file holds the main type of a function with its related types, extensions and `private` helpers; the file name is that main type. Aim for 200 to 600 lines, at most 800 (check); never split a function into one-type crumbs.
- Manager, Helper, Util, Service, Handler, Impl, Base, Common, Misc, New, Old and number suffixes are not used in names (check for file and type names).
- `internal` by default; `public` when another module calls it. Remove code with no caller.

## Content

- English identifiers in ASCII, CamelCase, no module prefix (check: ASCII and CamelCase of file and type names; the rest is reviewed).
- Code carries no comments and no prose. User-facing text is a key in a `Resources/*.localizable.json` file (reviewed), merged into `Resources/Localizable.xcstrings` by `utils/merge_strings.py`.
- Views take every colour, size, spacing, radius and duration from `Design` tokens or `App/Design/SheetValues.swift`; the only literals are 0, 1 and 2. Token values change in `Resources/tokens.json`, then `utils/generate_tokens.py` regenerates `Sources/Design/Model`.
- The company name and company values stay out of code; they come from the company configuration file described in [README.md](README.md).
- The Markdown files are `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`. Each statement in the first three is meant to be checkable in the code; `utils/check.py` verifies only that their links and paths exist; `CLAUDE.md` is the session start and carries status, decisions and next tasks; it changes only on Johannes' word, and then in the same commit as the change it records.

## Workflow

1. Work in a worktree outside the repository (the session's scratchpad), never inside `ALFA_OS/`: `git worktree add -b <branch> <folder outside the repository> main`.
2. Read the files you change and their callers first.
3. Change the code. Behaviour changes only when the task asks for it. A view is built only from the valid design master named in `CLAUDE.md`; where that master has no bow for it, the task stops and says so instead of inventing a form. An interim form is built only on Johannes' word and is reported to Design on DESIGNCHANNEL.
4. Run `python3 -I utils/check.py` and `zsh utils/check_modules.sh`; both end green before a commit (the pre-commit hook runs both once `core.hooksPath` is set, see [README.md](README.md)).
5. Write the commit message as: subject of at most 72 characters, blank line, at most three body lines, and the last line exactly `Designed by Johannes Leo Berger, made with help of Claude`. No `Co-Authored-By` line. `utils/commit_check.py` verifies it.
6. Commit on the branch. After review, merge it into `main` and push `main`. History moves forward only. After the merge the worktree and its branch are removed.

## Sandbox

When a sandbox blocks a command or a test, report the blocked restriction and leave production code as it is.
