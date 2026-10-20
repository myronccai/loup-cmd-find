# Tasks: find

- [x] 1. Split the command line into `-H`/`-L`/`-P`, starting points and expression
  - _Requirements: 1.1, 1.2, 1.7_
- [x] 2. Wildcard matcher: `*`, `?`, sets, ranges, classes, escapes, case folding
  - _Requirements: 2.1, 2.2_
- [x] 3. Recursive-descent parser into `enum Expr`, with GNU's error messages
  - _Requirements: 3.1, 3.3, 6.1, 6.2_
- [x] 4. Tests: `-name`, `-iname`, `-path`, `-type`, `-empty`, `-true`, `-false`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
- [x] 5. Short-circuit evaluation of `!`, `-a`, `-o`
  - _Requirements: 3.2_
- [x] 6. Sorted depth-first walk with `-maxdepth`, `-mindepth`, `-prune`
  - _Requirements: 1.1, 1.3, 1.4, 4.1, 4.2, 4.3, 4.4_
- [x] 7. Missing starting points, unreadable directories, symbolic links
  - _Requirements: 1.5, 1.6, 1.7_
- [x] 8. `-print`, `-print0`, `-exec ... ;`, `-exec ... {} +`
  - _Requirements: 5.1, 5.2, 5.3, 5.4_
- [x] 9. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
