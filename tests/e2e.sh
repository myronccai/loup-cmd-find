#!/usr/bin/env bash
# End-to-end tests: run the built binary on a directory tree made under a
# temporary directory and compare its standard output (byte for byte), its
# standard error (for error cases) and its exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    want stderr: $want_err"
        sed 's/^/    got stderr:  /' "$TMP/err" | head -5
    fi
}

# The tree under test. Names sort as: .hidden Notes.TXT a.txt empty.txt
# emptydir space dir sub.
cd "$TMP"
mkdir -p t/emptydir t/sub/deep "t/space dir"
printf 'alpha\n' > t/a.txt
: > t/empty.txt
printf 'z\n' > t/.hidden
printf 'x\n' > t/Notes.TXT
printf 'int b;\n' > t/sub/b.c
printf 'int c;\n' > t/sub/deep/c.c
printf 'd\n' > t/sub/deep/d.txt
printf 'ef\n' > "t/space dir/e f.txt"

all='t
t/.hidden
t/Notes.TXT
t/a.txt
t/empty.txt
t/emptydir
t/space dir
t/space dir/e f.txt
t/sub
t/sub/b.c
t/sub/deep
t/sub/deep/c.c
t/sub/deep/d.txt
'

# Walking and the default action.
check "whole tree"         0 "$all"                                     t
check "trailing slash"     0 $'t/\nt/a.txt\n'                           t/ -maxdepth 1 -name '[ta]*'
check "two paths"          0 $'t/sub/deep\nt/sub/deep/c.c\nt/sub/deep/d.txt\nt/emptydir\n' t/sub/deep t/emptydir
check "file as path"       0 $'t/a.txt\n'                               t/a.txt
cd t
check "default path"       0 $'./a.txt\n./empty.txt\n'                  -maxdepth 1 -name '*.txt'
cd ..

# Tests.
check "-name"              0 $'t/a.txt\nt/empty.txt\nt/space dir/e f.txt\nt/sub/deep/d.txt\n' t -name '*.txt'
check "-name hidden"       0 $'t/.hidden\n'                             t -name '.*'
check "-iname"             0 $'t/Notes.TXT\nt/a.txt\nt/empty.txt\nt/space dir/e f.txt\nt/sub/deep/d.txt\n' t -iname '*.txt'
check "-name brackets"     0 $'t/a.txt\nt/sub/b.c\n'                    t -name '[ab]*'
check "-name negated set"  0 $'t/.hidden\nt/Notes.TXT\nt/sub/b.c\nt/sub/deep/c.c\n' t -type f -name '*.[!t]*'
check "-name class"        0 $'t/Notes.TXT\n'                           t -name '[[:upper:]]*'
check "-path"              0 $'t/sub/deep/c.c\nt/sub/deep/d.txt\n'      t -path '*/deep/*'
check "-path star spans /" 0 $'t/sub/b.c\nt/sub/deep/c.c\n'             t -path 't*.c'
check "-type d"            0 $'t\nt/emptydir\nt/space dir\nt/sub\nt/sub/deep\n' t -type d
check "-type f,d"          0 "$all"                                     t -type f,d
check "-empty"             0 $'t/empty.txt\nt/emptydir\n'               t -empty
check "-empty dirs"        0 $'t/emptydir\n'                            t -type d -empty
check "-false"             0 ''                                         t -false

# Depth options.
check "-maxdepth 0"        0 $'t\n'                                     t -maxdepth 0
check "-maxdepth 1 dirs"   0 $'t\nt/emptydir\nt/space dir\nt/sub\n'     t -maxdepth 1 -type d
check "-mindepth 2"        0 $'t/space dir/e f.txt\nt/sub/b.c\nt/sub/deep/c.c\nt/sub/deep/d.txt\n' t -mindepth 2 -type f
check "min and max"        0 $'t/sub/deep\n'                            t -mindepth 2 -maxdepth 2 -type d
check "options anywhere"   0 $'t/a.txt\n'                               t -name 'a*' -maxdepth 1

# Operators.
check "! and -not"         0 $'t/.hidden\nt/Notes.TXT\nt/sub/b.c\nt/sub/deep/c.c\n' t -type f ! -name '*.txt'
check "-not"               0 $'t/.hidden\nt/Notes.TXT\nt/sub/b.c\nt/sub/deep/c.c\n' t -not -type d -not -name '*.txt'
check "-o"                 0 $'t/a.txt\nt/sub/b.c\n'                    t -name a.txt -o -name b.c
check "-a binds tighter"   0 $'t/a.txt\nt/sub/b.c\n'                    t -name a.txt -o -type f -name b.c
check "explicit -and -or"  0 $'t/sub/b.c\n'                             t -type f -and -name '*.c' -and -not -path '*deep*' -or -false
check "parentheses"        0 $'t/a.txt\nt/sub/b.c\nt/sub/deep/c.c\n'    t '(' -name '*.c' -o -name 'a*' ')' -type f
check "print only left"    0 $'t/a.txt\n'                               t -name a.txt -print -o -name b.c

# -prune.
check "-prune -o -print"   0 $'t\nt/.hidden\nt/Notes.TXT\nt/a.txt\nt/empty.txt\nt/emptydir\nt/space dir\nt/space dir/e f.txt\n' t -name sub -prune -o -print
check "-prune alone"       0 $'t/sub\n'                                 t -name sub -prune
check "prune files"        0 $'t/sub/b.c\n'                             t -path t/sub/deep -prune -o -name '*.c' -print

# Output actions.
printf 't/sub/b.c\0t/sub/deep/c.c\0' > "$TMP/want0"
check_file "-print0"       0 "$TMP/want0"                               t -name '*.c' -print0
check "-print twice"       0 $'t/a.txt\nt/a.txt\n'                      t -name a.txt -print -print

# -exec.
check "-exec ;"            0 $'[t/sub/b.c]\n[t/sub/deep/c.c]\n'         t -name '*.c' -exec echo '[{}]' ';'
check "-exec {} twice"     0 $'t/a.txt t/a.txt\n'                       t -name a.txt -exec echo {} {} ';'
check "-exec output"       0 $'int b;\nint c;\n'                        t -name '*.c' -exec cat {} ';'
check "-exec as a test"    0 $'t/Notes.TXT\nt/a.txt\n'                  t -maxdepth 1 -type f -exec grep -q . {} ';' -name '[Na]*' -print
check "-exec false"        0 ''                                         t -name '*.c' -exec false ';'
check "-exec suppresses print" 0 ''                                     t -name '*.c' -exec true ';'
check "-exec +"            0 $'t/a.txt t/empty.txt t/space dir/e f.txt t/sub/deep/d.txt\n' t -name '*.txt' -exec echo {} +
check "-exec + words"      0 $'files: t/sub/b.c t/sub/deep/c.c\n'        t -name '*.c' -exec echo files: {} +
check "-exec + after print" 0 $'t/sub/b.c\nt/sub/deep/c.c\nt/sub/b.c t/sub/deep/c.c\n' t -name '*.c' -print -exec echo {} +
check "-exec + no match"   0 ''                                         t -name nothing -exec echo {} +
check "-exec + fails"      1 ''                                         t -name '*.c' -exec false {} +
check_err "-exec not found ;" 0 $'find: \'no-such-command-zz\': No such file or directory\nfind: \'no-such-command-zz\': No such file or directory' t -name '*.c' -exec no-such-command-zz {} ';'
check_err "-exec not found +" 1 "find: 'no-such-command-zz': No such file or directory" t -name '*.c' -exec no-such-command-zz {} +
check_err "-exec stderr"   0 "oops"                                     t -name a.txt -exec sh -c 'echo oops >&2' ';'

# Missing paths.
check "missing path"       1 $'t/emptydir\n'                            nope t/emptydir
check_err "missing message" 1 "find: 'nope': No such file or directory" nope
check_err "not a directory" 1 "find: 't/a.txt/': Not a directory"       t/a.txt/

# Symbolic links: -P (default) does not follow them, -H only for the
# starting points, -L always.
mkdir -p l/real
printf 'f\n' > l/real/f
ln -s real l/link
check "-P link"            0 $'l\nl/link\nl/real\nl/real/f\n'           l
check "-P link not a dir"  0 $'l\nl/real\n'                             l -type d
check "-H start point"     0 $'l/link\nl/link/f\n'                      -H l/link
check "-P start point"     0 $'l/link\n'                                l/link
check "-L"                 0 $'l\nl/link\nl/link/f\nl/real\nl/real/f\n' -L l

# An unreadable directory (skipped when running as root, who can read it).
if [ "$(id -u)" -ne 0 ]; then
    mkdir -p p/locked p/open
    chmod 000 p/locked
    check "unreadable dir"     1 $'p\np/locked\np/open\n'               p
    check_err "unreadable msg" 1 "find: 'p/locked': Permission denied"  p
fi

# Command-line errors: GNU find's messages and status 1.
check_err "missing argument"  1 "find: missing argument to \`-name'"    t -name
check_err "unknown predicate" 1 "find: unknown predicate \`-bogus'"     t -bogus
check_err "path after expr"   1 "find: paths must precede expression: \`b'" t -name a b
check_err "unclosed paren"    1 "find: invalid expression; I was expecting to find a ')' somewhere but did not see one." t '(' -name a
check_err "extra paren"       1 "find: you have too many ')'"           t -name a ')'
check_err "empty parens"      1 "find: invalid expression; empty parentheses are not allowed." t '(' ')'
check_err "leading -o"        1 "find: invalid expression; you have used a binary operator '-o' with nothing before it." t -o -name a
check_err "trailing -o"       1 "find: expected an expression after '-o'" t -name a -o
check_err "-not then )"       1 "find: expected an expression between '!' and ')'" t '(' '!' ')'
check_err "bad -type"         1 "find: Unknown argument to -type: x"    t -type x
check_err "unsupported -type" 1 "find: -type l is not supported: only f and d can be told apart" t -type l
check_err "bad -maxdepth"     1 "find: Expected a positive decimal integer argument to -maxdepth, but got 'x'" t -maxdepth x
check_err "unterminated exec" 1 "find: missing argument to \`-exec'"    t -exec echo {}
check_err "two {} with +"     1 "find: Only one instance of {} is supported with -exec ... +" t -exec echo {} {} +
check "errors print nothing"  1 ''                                     t -name

# Help and version.
check "version"            0 $'find (loup-cmd-find) 0.1.0\n'            --version
check "version in expr"    0 $'find (loup-cmd-find) 0.1.0\n'            t -version
"$BIN" --help > "$TMP/help" 2>&1
if [ $? -eq 0 ] && head -1 "$TMP/help" | grep -q '^Usage: find '; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
