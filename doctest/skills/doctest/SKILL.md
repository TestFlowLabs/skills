---
name: doctest
description: |
  Apply DocTest to markdown documentation. Detects PHP code blocks, adds
  appropriate assertions/attributes, runs doctest to verify. Use when asked
  to "add doctest", "test documentation", "apply doctest to docs",
  "run doctest", "verify docs", "fix doctest failures",
  "review docs", or "review testable docs".
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
| **MAKE-RUNNABLE** | "make docs runnable", "add hidden setup" | Add `// [!code hide]` boilerplate to non-runnable blocks |

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
3. Fix and re-verify each file

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

## MAKE-RUNNABLE Mode — Add Hidden Boilerplate

Makes non-runnable documentation code blocks executable by adding the necessary boilerplate with `// [!code hide]` markers. Hidden lines are invisible in rendered docs (VitePress/Shiki) but execute when DocTest runs the block.

### Step 1: SCAN

1. Find all PHP blocks in target files
2. Identify blocks that are non-runnable: have `ignore` or `no_run` attributes, or would fail without setup code

### Step 2: CLASSIFY

For each non-runnable block, determine what's missing:

| Missing | What to Add |
|---------|-------------|
| `<?php` declaration | `<?php // [!code hide]` as first line |
| `use` imports | `use App\Models\User; // [!code hide]` |
| `require` autoloader | `require_once 'vendor/autoload.php'; // [!code hide]` |
| Variable definitions from context | `$config = [...]; // [!code hide]` |
| Multi-line setup (4+ lines) | `// [!code hide:start]` / `// [!code hide:end]` block |

### Step 3: CONVERT

#### Single-line hide (1-3 lines of boilerplate)

Append `// [!code hide]` to each boilerplate line:

**Before:**
````markdown
```php ignore
$user = User::find(1);
echo $user->name;
```
````

**After:**
````markdown
```php
<?php // [!code hide]
require_once 'vendor/autoload.php'; // [!code hide]
use App\Models\User; // [!code hide]

$user = User::find(1);
echo $user->name;
```
<!-- doctest: Alice -->
````

#### Block hide (4+ lines of boilerplate)

Use `// [!code hide:start]` and `// [!code hide:end]` delimiters:

**Before:**
````markdown
```php ignore
$total = $cart->total();
echo "Total: $total";
```
````

**After:**
````markdown
```php
// [!code hide:start]
<?php
declare(strict_types=1);
require_once 'vendor/autoload.php';
use App\Services\Cart;
use App\Models\Product;
$cart = new Cart();
$cart->add(new Product('Widget', 9.99));
// [!code hide:end]

$total = $cart->total();
echo "Total: $total";
```
<!-- doctest: Total: 9.99 -->
````

### Step 4: REPORT

1. Change `ignore` or `no_run` attribute to the appropriate assertion (remove attribute, add `<!-- doctest: -->`, `// =>`, etc.)
2. Verify each file after conversion:
   ```bash
   vendor/bin/doctest {file} -v
   ```
3. Report summary: blocks converted, blocks still needing attention

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

See `reference/attributes.md` for full details. Attributes go in the fence info string after `php`:

````markdown
```php ignore
```php no_run
```php throws
```php throws(ExceptionClass)
```php throws(ExceptionClass, "message substring")
```php parse_error
```php group="name"
```php setup group="name"
```php teardown group="name"
````

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

See `reference/groups.md` for full details. Groups share state across blocks:

````markdown
```php setup group="db"
$pdo = new PDO('sqlite::memory:');
$pdo->exec('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
```

```php group="db"
$pdo->exec("INSERT INTO users (name) VALUES ('Alice')");
echo $pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
```
<!-- doctest: 1 -->

```php teardown group="db"
$pdo->exec('DROP TABLE users');
```
````

Execution order: setup blocks → regular blocks → teardown blocks (all in document order within group).

---

## Shiki Compatibility

DocTest automatically handles Shiki markers used in VitePress. Processing order: `--` removal → `hide:start/end` block removal → catch-all regex strip.

| Marker | DocTest Behavior |
|--------|-----------------|
| `{1,4-6}` | Stripped from info string |
| `// [!code --]` | Entire line removed |
| `// [!code ++]` | Marker stripped, code kept |
| `// [!code hide]` | Marker stripped, code kept |
| `// [!code hide:start]` / `// [!code hide:end]` | Delimiter lines removed, inner lines kept |
| `// [!code highlight]` | Marker stripped, code kept |
| `// [!code focus]` | Marker stripped, code kept |
| `// [!code warning]` | Marker stripped, code kept |
| `// [!code error]` | Marker stripped, code kept |
| `// [!code word:xxx]` | Marker stripped, code kept |

No configuration needed. This is always active.

---

## CLI Options

```bash
vendor/bin/doctest [files...] [options]

Options:
  --filter, -f         Filter blocks by content or file name
  --exclude            Exclude files matching pattern
  --dry-run            Parse only, don't execute
  --stop-on-failure    Stop on first failure
  --config, -c         Path to config file (default: doctest.php)
  -v                   Verbose — show per-assertion details
  -vv                  Very verbose — also show source on failure
```

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
