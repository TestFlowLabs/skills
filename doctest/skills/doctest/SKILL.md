---
name: doctest
description: |
  Apply DocTest to markdown documentation. Detects PHP code blocks, adds
  appropriate assertions/attributes, runs doctest to verify. Use when asked
  to "add doctest", "test documentation", "apply doctest to docs",
  "run doctest", "verify docs", "fix doctest failures",
  "review docs", "review testable docs", "make docs runnable",
  or "add hidden setup".
allowed-tools:
  - Bash(php:*)
  - Bash(composer:*)
  - Bash(vendor/bin/doctest:*)
  - Bash(chmod:*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# DocTest Skill

You are an expert at applying [DocTest](https://github.com/testflowlabs/doctest) to PHP markdown documentation. DocTest extracts PHP code blocks from markdown files, executes them in isolated processes, and verifies their output.

## Modes

Detect the mode from the user's request:

| Mode | Triggers | Action |
|------|----------|--------|
| **APPLY** | "apply doctest", "add doctest to docs", "test documentation" | Full workflow: install → analyze → convert → verify |
| **VERIFY** | "run doctest", "verify docs", "check docs" | Just run `vendor/bin/doctest` and report results |
| **FIX** | "fix doctest failures", "fix failing docs" | Analyze failures, fix blocks, re-verify |
| **REVIEW** | "review docs", "review testable docs", "check docs quality" | Review documentation against testable docs best practices, suggest improvements |
| **MAKE-RUNNABLE** | "make docs runnable", "add hidden setup", "make this block work" | Make code blocks executable — runnable first, hide second |

---

## APPLY Mode — Full Workflow

### Step 1: SETUP

1. **Check environment** by running the check script (see `scripts/check-doctest.sh` in this skill directory) or manually:
   ```bash
   php -v                          # Must be 8.4+
   test -f composer.json            # Must exist
   test -f vendor/bin/doctest       # Check if installed
   test -f doctest.php              # Check for config
   ```

2. **Install DocTest** if missing:
   ```bash
   composer require --dev testflowlabs/doctest
   ```

3. **Create config** if missing — create `doctest.php` in project root:
   ```php
   <?php

   declare(strict_types=1);

   return [
       'paths'     => ['docs', 'README.md'],
       'exclude'   => [],
       'execution' => [
           'timeout'      => 30,
           'memory_limit' => '256M',
       ],
       'output' => [
           'normalize_whitespace' => true,
           'trim_trailing'        => true,
       ],
       'reporters' => [
           'console' => true,
           'json'    => null,
       ],
   ];
   ```
   Adjust `paths` based on project structure.

4. **Check for bootstrap needs** — if the project uses a framework (Laravel, Symfony) or needs autoloading, suggest adding:
   ```php
   'bootstrap' => 'tests/doctest-bootstrap.php',
   ```

### Step 2: DISCOVER

1. Find all `.md` files in configured paths
2. Extract PHP code blocks (fenced with ` ```php `)
3. For each block, note: file, line number, code content, existing attributes, existing assertions

### Step 3: CLASSIFY

For each code block, apply the **Decision Tree** (see `reference/decision-tree.md`):

| Pattern | Action |
|---------|--------|
| Already has assertion (`<!-- doctest: -->`, `// =>`, etc.) | **SKIP** — already tested |
| `echo "..."` / `print(...)` with static output | Add `<!-- doctest: {output} -->` |
| `echo json_encode(...)` | Add `<!-- doctest-json: {json} -->` |
| `echo $dynamic` with partially predictable output | Add `<!-- doctest-contains: {partial} -->` or use wildcards |
| `echo` with timestamps, UUIDs, dynamic values | Add `<!-- doctest: ... -->` with wildcards (`{{date}}`, `{{uuid}}`, etc.) |
| `$x = expr;` (assigns value, no output) | Add `// => {value}` result comment or `<!-- doctest-expect: $x === {value} -->` |
| `return [...]` (config array, not in function) | Add `ignore` attribute |
| `throw new Exception(...)` | Add `throws(ClassName)` attribute |
| `{invalid syntax` (intentional parse error) | Add `parse_error` attribute |
| `$db->query(...)`, file I/O, API calls | Add `no_run` attribute (syntax check only) |
| `require 'vendor/...'`, `use App\...` without autoloader | Add `ignore`, or use MAKE-RUNNABLE to add hidden boilerplate |
| Related sequence of blocks building on each other | Add `group="name"` attribute, consider `setup`/`teardown` |
| Already has `ignore` / `no_run` / `throws` / `parse_error` | **SKIP** — already controlled |
| No output, no side effects, just syntax demo | Leave as-is (blocks without assertions still pass if no error) |

### Step 4: CONVERT

Process file by file:

1. Apply classification decisions — edit the markdown file
2. After each file, run:
   ```bash
   vendor/bin/doctest {file} -v
   ```
3. If all pass → move to next file
4. If any fail → analyze stderr, fix the assertion, re-run
5. Common fixes:
   - Wrong expected output → correct the value
   - Missing trailing newline → adjust expected value
   - Dynamic output → switch to wildcard or `doctest-contains`
   - Needs autoloader → suggest bootstrap config
   - Block depends on earlier block → add `group` attribute

### Example: Converting a Block

**Found in docs/api.md — block has output but no assertion:**

````markdown
```php
echo strtoupper('hello');
```
````

**Classification:** Static output → add exact assertion.

**After conversion:**

````markdown
```php
echo strtoupper('hello');
```
<!-- doctest: HELLO -->
````

**Verify:** `vendor/bin/doctest docs/api.md:1 -v` → `:3 ✔ echo strtoupper('hello');  [1/1]  0.02s`

### Step 5: REPORT

1. Run full suite:
   ```bash
   vendor/bin/doctest -v
   ```
2. Report summary: total blocks, passed, failed, skipped
3. List any blocks needing user attention (ambiguous, external dependencies)

---

## VERIFY Mode

Simply run DocTest and report results:

```bash
vendor/bin/doctest -v
```

Report the summary. If there are failures, show what failed and suggest fixes.

---

## FIX Mode

1. Run DocTest to see failures:
   ```bash
   vendor/bin/doctest -vv
   ```
2. For each failure, analyze:
   - Expected vs actual output
   - Whether the code block needs a different assertion type
   - Whether wildcards would fix dynamic output issues
   - Whether the code itself has a bug
3. Fix and re-verify each file — use `file:N` to target specific blocks for fast iteration

### Example: Fixing a Dynamic Output Failure

```
vendor/bin/doctest docs/api.md -vv
  :7 ✖ echo date('Y');  [1/3]  0.02s
    Expected: 2025
    Actual:   2026
```

**Diagnosis:** Hardcoded year in assertion will break every January.

**Fix:** Change `<!-- doctest: 2025 -->` to `<!-- doctest-matches: /^\d{4}$/ -->` or use a wildcard: `<!-- doctest: {{int}} -->`.

**Verify:** `vendor/bin/doctest docs/api.md:7 -v` → PASS

---

## REVIEW Mode — Testable Documentation Review

Review existing documentation against the **Ten Principles of Testable Documentation** and suggest concrete improvements.

The user may specify a project directory, a `docs/` folder, or a single `.md` file. Default to `docs/` and `README.md` if no path is given.

### Step 1: SCAN

1. Find all `.md` files in the target path
2. Extract all PHP code blocks
3. For each block, record: file, line number, code, existing attributes, existing assertions

### Step 2: EVALUATE

Check each code block against these principles (report violations only):

| # | Principle | What to Check | Severity |
|---|-----------|---------------|----------|
| 1 | Every Example Should Run | Block uses undefined variables, missing imports, hidden state (`$user`, `$config`, `$app` without setup) | High |
| 2 | One Concept Per Block | Block does 2+ unrelated things (e.g., array ops AND string ops AND math) | Medium |
| 3 | Prefer `echo` Over `var_dump` | Block uses `var_dump()` or `print_r()` for output verification | Medium |
| 4 | Handle Dynamic Output | Assertion uses hardcoded timestamps, dates, UUIDs instead of wildcards | High |
| 5 | Mark Non-Runnable Explicitly | Block has external dependencies (DB, API, framework) but no `no_run`/`ignore` attribute | High |
| 6 | Use Groups for Related Examples | Sequential blocks share variables but aren't grouped | Medium |
| 7 | Document Error Conditions | Functions that can throw have no `throws` example nearby | Low |
| 8 | Choose the Right Assertion | Using `doctest-matches` (regex) where `doctest` + wildcards would work, or `doctest` where `doctest-json` fits better | Low |
| 9 | Keep Setup Minimal | Block has 5+ lines of boilerplate before the actual example | Medium |
| 10 | Test-Driven Documentation | Block has no assertion at all and could have one (not a config/setup block) | Medium |

Also check for **Anti-Patterns**:

| Anti-Pattern | What to Check |
|--------------|---------------|
| Hidden State | Variables used but never defined in the block or a group |
| Testing the Language | Block only demonstrates PHP built-ins, not the library's API |
| Overly Complex | Block exceeds 15 lines |
| Fragile Assertions | Uses `print_r` or `var_dump` output as expected value |
| Ignoring Everything | Block marked `ignore` but could actually run |

### Step 3: REPORT

Present findings as a structured report:

```
## Testable Documentation Review: {path}

### Summary
- Files scanned: N
- PHP blocks found: N
- Violations found: N (High: N, Medium: N, Low: N)

### Findings

#### {file.md}:{line} — {Principle name} (Severity)
**Current:**
{code block as-is}

**Issue:** {what's wrong}

**Suggested fix:**
{improved code block with proper assertion/attribute}

---
```

### Step 4: APPLY (optional)

If the user confirms, apply the suggested fixes:

1. Edit each file with the suggested improvements
2. Run `vendor/bin/doctest {file} -v` after each file
3. Fix any issues from the run
4. Report final results

### Review Scope Options

- `review docs/` — review all documentation
- `review README.md` — review a single file
- `review docs/ --strict` — also flag Low severity issues
- `review docs/ --fix` — review and apply fixes immediately

---

## MAKE-RUNNABLE Mode — Make Documentation Code Executable

**Philosophy:** Runnable first, hide second. Every code block must execute successfully before any cosmetic hiding is applied.

See `reference/make-runnable.md` for the full workflow with examples.

### Core Workflow

1. **BOOTSTRAP INVENTORY** — Scan `.doctest/` for existing profiles, check `doctest.php` for global bootstrap
2. **CLASSIFY** — For each block: NEW (design from scratch) or EXISTING (fix to make runnable)
3. **MAKE RUNNABLE** — Write/add minimum code, verify with `vendor/bin/doctest {file}:{N} -v`, iterate until green
4. **HIDE** — Once running, hide boilerplate with `// [!code hide]` or `bootstrap="profile"` attributes
5. **RE-VERIFY** — Confirm block still passes after hiding: `vendor/bin/doctest {file}:{N} -v`
6. **BOOTSTRAP RECOMMENDATIONS** — If 3+ blocks share setup, suggest a `.doctest/` profile

### Key Principles

- **Run before hide** — Never add `// [!code hide]` to code you haven't verified runs
- **Use bootstrap profiles** over inline `// [!code hide]` when setup is framework/autoloader related
- **Target single blocks** with `file:N` syntax for fast iteration (e.g., `vendor/bin/doctest docs/api.md:3 -v`)
- **Iterate until green** — Fix loop: run → analyze failure → fix → run again

**When NOT to convert:** Config snippets (`return [...]`), external service dependencies, intentionally broken code, pseudocode.

---

## Assertion Syntax Reference

See `reference/assertions.md` for full details. Quick reference:

### HTML Comment Assertions (invisible in rendered docs)

```markdown
<!-- doctest: exact output here -->
<!-- doctest-contains: partial match -->
<!-- doctest-matches: /regex pattern/ -->
<!-- doctest-json: {"key": "value"} -->
<!-- doctest-expect: $variable === value -->
```

### Inline Result Comment

```php
$x = 42; // => 42
```

### Debug Dump (inspect without failing)

```php
$x = 42; // => dd()
```

Always passes. Value shown in output regardless of verbosity. Useful for exploring values during development.

### Multiple Assertions per Block

````markdown
```php
$x = 42; // => 42
$y = true; // => true
echo $x;
```
<!-- doctest: 42 -->
<!-- doctest-expect: $y === true -->
````

---

## Attribute Syntax Reference

See `reference/attributes.md` for full details. Two syntaxes are available:

**Info string** (after `php`):
````markdown
```php ignore
```php no_run
```php throws(ExceptionClass)
```php parse_error
```php group="name"
```php setup group="name"
```php bootstrap="laravel,database"
````

**HTML comment** (preserves editor syntax highlighting):
````markdown
<!-- doctest-attr: ignore -->
<!-- doctest-attr: throws(InvalidArgumentException) -->
<!-- doctest-attr: bootstrap="laravel" group="users" setup -->
````

Place the comment on the line immediately before the code fence. Both syntaxes can coexist (but not for the same attribute).

**Processing priority:** ignore → no_run → parse_error → throws → group/setup/teardown

---

## Wildcard Reference

See `reference/wildcards.md` for full details. Use in `<!-- doctest: -->` assertions:

| Wildcard | Matches |
|----------|---------|
| `{{any}}` | Any non-empty content (non-greedy) |
| `{{int}}` | Integer (optional negative) |
| `{{float}}` | Float or integer |
| `{{uuid}}` | UUID v4 format |
| `{{date}}` | `YYYY-MM-DD` |
| `{{time}}` | `HH:MM:SS` |
| `{{datetime}}` | ISO datetime with optional timezone |
| `{{...}}` | Any content including newlines (non-greedy) |

Example:
```markdown
<!-- doctest: Generated: {{date}} {{time}} -->
<!-- doctest: User ID: {{uuid}} -->
<!-- doctest: {"id":{{int}},"created":"{{datetime}}","price":{{float}}} -->
```

---

## Group Patterns

See `reference/groups.md` for full details. Groups share state across blocks with `group="name"`. Add `setup`/`teardown` for initialization and cleanup.

Execution order: setup → regular blocks → teardown (all in document order within group). All blocks in a group must have identical `bootstrap` profiles.

---

## Shiki Compatibility

See `reference/shiki.md` for full details. DocTest automatically strips all Shiki markers:

- `// [!code --]` → line removed entirely
- `// [!code hide]` → marker stripped, code kept (primary tool for MAKE-RUNNABLE)
- `// [!code hide:start/end]` → delimiters removed, inner code kept
- All other markers (`++`, `highlight`, `focus`, `warning`, `error`, `word:xxx`) → marker stripped, code kept
- `{1,4-6}` → stripped from info string

No configuration needed. Always active.

---

## CLI Options

```bash
vendor/bin/doctest [files...] [options]

Arguments:
  files                Markdown files or directories (supports file:N for block targeting)

Options:
  --filter, -f         Filter blocks by content or file name
  --exclude            Exclude files matching pattern
  --dry-run            Parse only, don't execute
  --stop-on-failure    Stop on first failure
  --parallel, -p       Run blocks in parallel (auto-detects CPU cores, or specify: -p 4)
  --config, -c         Path to config file (default: doctest.php)
  -v                   Verbose — show per-assertion details
  -vv                  Very verbose — also show source on failure
```

**Block targeting:** `vendor/bin/doctest README.md:3` runs only the 3rd PHP block in the file (1-based). Useful for iterating on a single block during MAKE-RUNNABLE or FIX workflows.

Exit codes: `0` = all passed, `1` = failures, `3` = no testable blocks found

---

## Error Handling

| Situation | Response |
|-----------|----------|
| DocTest not installed | Run `composer require --dev testflowlabs/doctest` |
| PHP < 8.4 | Report to user — DocTest requires PHP 8.4+ |
| No `composer.json` | Report to user — not a PHP project |
| Block fails after conversion | Analyze stderr, fix assertion or add appropriate attribute |
| Ambiguous block (can't determine assertion) | Ask user what the expected behavior is |
| Needs bootstrap/autoload | Suggest adding `bootstrap` key to config |
| No PHP blocks in file | Skip silently |
| Code outputs nothing, no assertion | Leave as-is — passes if no error |
| Need machine-readable results | Add `'reporters' => ['json' => 'build/doctest.json']` to config |
| Slow test suite | Add `--parallel` flag or `'execution' => ['parallel' => 4]` to config |

---

## Important Rules

1. **Never add assertions to blocks that already have them** — check first
2. **Prefer invisible assertions** (HTML comments) over inline `// =>` for output
3. **Use `// =>` only for return value demonstrations** where the pattern is natural
4. **Use the simplest assertion type** — `<!-- doctest: -->` before `<!-- doctest-matches: -->`
5. **Use wildcards over regex** when possible — they're more readable
6. **Group blocks that depend on each other** — don't force standalone execution
7. **Use `no_run` over `ignore`** when syntax should still be validated
8. **Run doctest after each file** to catch issues early
9. **Report blocks you're unsure about** rather than guessing wrong
