# Requirements: find

## Introduction

`find` walks one or more directory trees and evaluates an expression of
tests, operators and actions on every file and directory it meets. This
repository recreates the core of GNU findutils `find` in Loup: the
expression language (parsed by a recursive-descent parser into a tree of
enums), shell wildcard matching, depth limits, pruning, printing and running
commands with `-exec`. `io.fs` has no `stat()` (roadmap constraint T1), so
tests on sizes, times and permissions are out of scope.

## Requirements

### Requirement 1: Starting points and the walk

**User Story:** As a shell user, I want to list every file below some
directories so that I can feed them to other commands.

#### Acceptance Criteria

1. WHEN find is run with paths before the expression, THE program SHALL walk
   each of them in order, depth-first, printing a directory before its
   contents.
2. WHEN no path is given, THE program SHALL walk `.`.
3. THE program SHALL name entries by joining the starting point and the names
   below it with `/`, without doubling a trailing slash of the starting point.
4. THE program SHALL visit the entries of a directory sorted by name.
5. WHEN a starting point does not exist, THE program SHALL print
   `find: 'PATH': No such file or directory`, go on with the next one, and
   exit with status 1; a path ending in `/` that names a file SHALL give
   `Not a directory`.
6. WHEN a directory cannot be read, THE program SHALL print
   `find: 'DIR': Permission denied` and exit with status 1.
7. WHEN `-P` (the default) is in effect, THE program SHALL not descend into
   symbolic links to directories; `-H` SHALL follow them for the starting
   points only and `-L` everywhere.

### Requirement 2: Tests

**User Story:** As a shell user, I want to select files by name, path, type
and emptiness so that I find only what I need.

#### Acceptance Criteria

1. WHEN `-name PATTERN` is given, THE program SHALL match the last component
   of the path against the shell wildcard PATTERN (`*`, `?`, `[...]`,
   `[!...]`, ranges, `[:class:]`, `\` escapes); `*` SHALL also match a
   leading dot. `-iname` SHALL ignore case.
2. WHEN `-path PATTERN` is given, THE program SHALL match the whole path,
   with `*` matching `/`.
3. WHEN `-type f`, `-type d` or the list `-type f,d` is given, THE program
   SHALL match regular files, directories or either. Type letters other than
   `f` and `d` SHALL be rejected.
4. WHEN `-empty` is given, THE program SHALL match empty regular files and
   directories without entries.
5. `-true` and `-false` SHALL always be true and false.

### Requirement 3: Operators

**User Story:** As a shell user, I want to combine tests so that I can
express any selection.

#### Acceptance Criteria

1. THE program SHALL support `( EXPR )`, `! EXPR` and `-not EXPR`,
   `EXPR -a EXPR` (also `-and`, or juxtaposition) and `EXPR -o EXPR` (also
   `-or`), with that precedence from highest to lowest.
2. THE program SHALL evaluate `-a` and `-o` left to right and stop as soon as
   the result is known, so actions on the right run only when needed.
3. WHEN the expression contains no action other than `-prune`, THE program
   SHALL print every entry for which the whole expression is true.

### Requirement 4: Depth and pruning

**User Story:** As a shell user, I want to limit how deep find goes so that
large trees stay manageable.

#### Acceptance Criteria

1. WHEN `-maxdepth N` is given, THE program SHALL not descend more than N
   levels below the starting points (`0`: the starting points only).
2. WHEN `-mindepth N` is given, THE program SHALL not apply tests or actions
   to entries less than N levels deep.
3. `-maxdepth` and `-mindepth` SHALL be global wherever they appear and
   evaluate to true.
4. WHEN `-prune` is evaluated on a directory, THE program SHALL not descend
   into it; `-prune` SHALL be true.

### Requirement 5: Actions

**User Story:** As a shell user, I want to print paths or run commands on
them so that find can drive other tools.

#### Acceptance Criteria

1. `-print` SHALL print the path and a newline; `-print0` the path and a NUL.
2. WHEN `-exec COMMAND ;` is evaluated, THE program SHALL run COMMAND with
   every `{}` in its words replaced by the path, pass on its output, and be
   true only if it exits with status 0.
3. WHEN `-exec COMMAND {} +` is evaluated, THE program SHALL collect the
   path, be true, and run COMMAND with the collected paths appended when the
   walk ends (or a batch reaches its size limit); a command that fails SHALL
   make find exit with status 1.
4. WHEN the command of `-exec` cannot be found, THE program SHALL print
   `find: 'COMMAND': No such file or directory`.

### Requirement 6: Command line

**User Story:** As a shell user, I want GNU find's diagnostics so that
mistakes are easy to spot.

#### Acceptance Criteria

1. WHEN the expression is malformed (missing argument, unknown predicate,
   path after the expression, unbalanced parentheses, operator without an
   operand, bad `-type` or depth argument, unterminated `-exec`, more than
   one `{}` with `+`), THE program SHALL print GNU find's message prefixed
   `find: ` on standard error, print nothing else and exit with status 1.
2. WHEN `--help` or `--version` (or `-help`, `-version`) appears in the
   expression, THE program SHALL print the help text or the line
   `find (loup-cmd-find) 0.1.0` and exit with status 0.
