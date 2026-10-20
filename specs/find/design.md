# Design: find

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `cli.args.parse_args`
takes the leading `-H`/`-L`/`-P` options and the starting points, and hands
the rest to `commands.expr.parse_expression`, which builds a tree of `Expr`
enum values. `commands.find.run_find` walks each starting point and calls
`evaluate` on every entry.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (1 for usage errors, as GNU find) |
| `source/cli/args.loup` | `Options` (`links`, `paths`, `query`), `starts_expression`, `parse_args` |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, `run_find`, exceptions to status 1 |
| `source/commands/expr.loup` | `enum Expr`, `Query`, the parser (`parse_or`, `parse_and`, `parse_unary`, `parse_primary`, `parse_exec`), `parse_types`, `parse_depth`, `show` |
| `source/commands/glob.loup` | `compile_glob` into `GlobPart`s, `match_parts`, `glob_match`, `in_class` |
| `source/commands/find.loup` | `Entry`, `State`, `evaluate`, `visit`, `walk_all`, `-exec` (`run_command`, batches), `run_find` |

### The expression tree

```text
enum Expr { Name(pattern, fold), Path(pattern), Kind(kinds), Empty, Const(bool),
            Prune, Print, Print0, Exec(words), ExecPlus(words, batch),
            Not(Expr), And(Expr, Expr), Or(Expr, Expr) }
```

The parser is one function per precedence level:

```text
or      := and { (-o | -or) and }
and     := unary { [-a | -and] unary }
unary   := (! | -not) unary | primary
primary := ( or ) | test | action | global option
```

A `Parser` struct holds the tokens and a cursor and records what the
primaries imply: `-maxdepth`/`-mindepth` values (the primaries themselves
become `Const(true)`), whether an action was seen, and how many `{} +`
batches there are. Without an action the root becomes `And(root, Print)`.

### Evaluation

`evaluate(expr, entry, edits state)` is a `match` statement over the tree;
`And` and `Or` evaluate their right side only when needed, so actions run in
GNU order. `Prune` sets `state.prune`, which `visit` reads before
descending. `ExecPlus` appends the path to its batch; `flush_all` runs the
batches after the walk.

`State.capture` switches the output side: when true, printed text goes to
`state.out` and command lines to `state.commands` (as `core.shlex.join`
renders them) instead of standard output and a child process. The unit tests
use it; `run_find` uses the printing mode.

### Files and processes

- The walk uses `io.fs.listDir`, `isDir` and `isFile` (which follow symbolic
  links), sorts the names, and recurses.
- `io.fs` has no `lstat`, so whether a directory is a symbolic link is asked
  of `test -h` through `io.proc.exitCode` (one process per directory, only
  under `-P` and `-H`).
- `-empty` on a directory lists it. On a regular file it asks `test -s`:
  measuring a file by reading it would abort the native program on an
  unreadable file (its `IoError` cannot be caught there).
- A directory that lists as empty is checked with `test -r -a -x` to tell an
  empty directory from an unreadable one (the native `listDir` returns no
  names for both).
- `-exec` looks the command up on `PATH` first, then runs it with the prelude
  `exec(argv)` (no shell). Its captured standard output is printed and its
  standard error written to standard error. The child inherits standard
  input.

## Differences from the original

- Entries are visited in name order, not directory order.
- A symbolic link to a regular file counts as a regular file (`-type f`);
  only links to directories are recognised. `-L` follows directory links
  without loop detection (a loop ends at the kernel's symlink limit).
- Unsupported: tests on metadata (`-size`, `-mtime`, `-newer`, `-perm`,
  `-user`, ...; T1), `-type` letters other than `f` and `d`, `-delete`,
  `-execdir`, `-ok`, `-printf`, `-regex`, the `,` operator, `-depth`, `-D`
  and `-O`.
- The output of `-exec` commands is collected and printed when the command
  ends, as UTF-8 text (invalid bytes are replaced), not streamed.
- `--version` prints one line; `--help` is shorter.

## Error handling

Expression errors are `Result` errors returned from the parser and printed
by `run()` with status 1. Walk errors (missing starting points, unreadable
directories, failing `{} +` commands) are reported as they happen and make
the final status 1. An unexpected exception is printed and gives status 1.

## Testing

- `tests/glob_test.loup`: wildcards, sets, ranges, classes, escapes, case
  folding.
- `tests/expr_test.loup`: the tree for each operator and precedence level,
  implicit `-print`, global options, every parser error message.
- `tests/args_test.loup`: paths versus expression, `-H`/`-L`/`-P`, help and
  version.
- `tests/find_test.loup`: path helpers, `{}` substitution, and `evaluate`
  in capture mode (printing, short-circuiting, `-prune`, `-exec` in both
  forms).
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: builds a tree under a temporary directory and runs the
  native binary on it: every test, operator and action, `-exec` output and
  statuses, symbolic links, an unreadable directory and every error message.
