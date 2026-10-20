# loup-cmd-find

GNU `find` recreated in [Loup](https://code-craft.ai/references/loup): walk
directory trees and evaluate an expression of tests (`-name`, `-iname`,
`-path`, `-type`, `-empty`), operators (`!`, `-a`, `-o`, `( )`), depth
limits, `-prune`, and actions (`-print`, `-print0`, `-exec ... ;`,
`-exec ... {} +`).

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It shows a
recursive-descent parser that turns the expression into a tree of enums, a
shell wildcard matcher, and running commands for `-exec` with `exec` and
`io.proc`.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                                # native binary: build/find
make ci                                   # check, unit tests, build, end-to-end tests
make run ARGS="source -name '*.loup'"     # run from source with loup run
```

```text
$ build/find demo
demo
demo/README.md
demo/build
demo/build/main.o
demo/docs
demo/src
demo/src/main.c
demo/src/util.c
demo/src/util.h
$ build/find demo -name '*.c'
demo/src/main.c
demo/src/util.c
$ build/find demo -type d -empty
demo/docs
$ build/find demo -name build -prune -o -type f -print
demo/README.md
demo/src/main.c
demo/src/util.c
demo/src/util.h
$ build/find demo -name '*.[ch]' -exec wc -l {} +
  1 demo/src/main.c
  2 demo/src/util.c
  1 demo/src/util.h
  4 total
$ build/find demo -iname 'readme*' -exec echo 'found: {}' ';'
found: demo/README.md
$ build/find demo/src -type f -print0 | xargs -0 grep -l twice
demo/src/util.c
demo/src/util.h
$ build/find demo -maxdepth 1 ! -type d
demo/README.md
$ build/find demo -name '*.c' -o
find: expected an expression after '-o'
$ build/find nowhere; echo "status $?"
find: 'nowhere': No such file or directory
status 1
```

`find [-H] [-L] [-P] [PATH...] [EXPRESSION]`. The default path is `.` and
the default expression `-print`; an expression without an action prints the
entries for which it is true.

| Kind | Supported |
|---|---|
| Tests | `-name PATTERN`, `-iname PATTERN`, `-path PATTERN`, `-type f\|d` (or `f,d`), `-empty`, `-true`, `-false` |
| Operators | `( EXPR )`, `! EXPR`, `-not EXPR`, `EXPR -a EXPR` (`-and`, or nothing), `EXPR -o EXPR` (`-or`) |
| Global options | `-maxdepth N`, `-mindepth N` |
| Actions | `-print`, `-print0`, `-prune`, `-exec COMMAND ;`, `-exec COMMAND {} +` |
| Symbolic links | `-P` (default: do not follow), `-H` (follow for the starting points), `-L` (follow) |
| Other | `--help`, `--version` (also `-help`, `-version`) |

Patterns are shell wildcards: `*`, `?`, `[abc]`, `[!abc]`, `[a-z]`,
`[[:digit:]]`, and `\` to quote the next character. `*` matches a leading
`.` and, for `-path`, `/`.

Exit status: `0` on success; `1` if a starting point is missing, a directory
cannot be read, an `-exec ... {} +` command fails, or the command line is
wrong.

## Differences from GNU find

- Entries are visited in name order, not in the order the directory lists
  them, so output is the same on every machine.
- `io.fs` has no `stat()` (Loup 1.26.0), so:
  - there are no tests on metadata: `-size`, `-mtime`, `-newer`, `-perm`,
    `-user` and the like;
  - `-type` accepts only `f` and `d`;
  - a symbolic link to a regular file counts as a regular file. Links to
    directories are found by asking `test -h` (one process per directory),
    so `-P` and `-H` do not descend into them;
  - `-L` has no loop detection: a link loop is followed until the kernel's
    limit on links in a path stops it;
  - `-empty` asks `test -s` for each regular file it tests (reading the file
    would abort on one that cannot be read), which is slow on large trees.
    Put `-type d` first to test only directories.
- Not implemented: `-delete`, `-execdir`, `-ok`, `-printf`, `-fprint`,
  `-regex`, `-depth`, `-xdev`, the `,` operator, `-D` and `-O`.
- `-exec` runs the command without a shell, as GNU find does, but collects
  its output and prints it when the command ends instead of streaming it;
  the output is treated as UTF-8 text.
- `--help` is shorter and `--version` prints one line:
  `find (loup-cmd-find) 0.1.0`.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # -H/-L/-P, starting points, then the expression
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/expr.loup     # enum Expr and the recursive-descent parser
source/commands/glob.loup     # wildcard matching
source/commands/find.loup     # walk, evaluation, -exec
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/find (make e2e)
specs/find/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
