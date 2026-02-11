# MAKE-RUNNABLE Mode Reference

Make documentation code blocks executable. The goal is working code first, clean presentation second.

**Philosophy:** Runnable first, hide second. Every code block must execute successfully before any cosmetic hiding is applied.

---

## Step 1: BOOTSTRAP INVENTORY

Before touching any code block, understand the project's bootstrap landscape:

1. **Scan for existing profiles:**
   ```bash
   ls .doctest/*.php 2>/dev/null
   ```
2. **Check `doctest.php`** for global bootstrap config
3. **List available profiles** — note what each provides (autoloader, framework, database, etc.)

This inventory determines whether to use `bootstrap="profile"` attributes (clean) or inline `// [!code hide]` (fallback).

**Priority:** `bootstrap="profile"` > `group setup` > `// [!code hide:start/end]` > `// [!code hide]`

---

## Step 2: CLASSIFY BLOCKS

For each PHP block that doesn't run, determine the scenario:

| Scenario | Signal | Workflow |
|----------|--------|----------|
| **NEW** | User asks to "write an example", "add a code block" | Design → Run → Hide |
| **EXISTING** | Block has `ignore`/`no_run`, or fails when executed | Analyze → Fix → Run → Hide |

---

## Step 3A: NEW Block — Design → Run → Hide

When writing a new documentation code block from scratch:

1. **Write complete, runnable code** — include everything: imports, setup, the actual example, output
2. **Verify it runs:**
   ```bash
   vendor/bin/doctest {file}:{N} -v
   ```
3. **Identify what the documentation teaches** — what should the reader focus on?
4. **Hide everything else** with the appropriate technique
5. **Add the assertion** (output, contains, json, expect)
6. **Re-verify after hiding:**
   ```bash
   vendor/bin/doctest {file}:{N} -v
   ```

### Example: NEW Block for a Package API

Goal: Document a `PriceCalculator::withTax()` method.

**Phase 1 — Write complete runnable code:**

````markdown
```php bootstrap="laravel"
use App\Services\PriceCalculator;

$calculator = new PriceCalculator();
$price = $calculator->withTax(100.00, 0.21);
echo $price;
```
<!-- doctest: 121.00 -->
````

Verify: `vendor/bin/doctest docs/api.md:5 -v` → PASS

**Phase 2 — Identify teaching purpose:**

The reader should focus on `withTax(100.00, 0.21)` and the result. The `use` statement and constructor are boilerplate.

**Phase 3 — Hide boilerplate:**

````markdown
```php bootstrap="laravel"
use App\Services\PriceCalculator; // [!code hide]
$calculator = new PriceCalculator(); // [!code hide]

$price = $calculator->withTax(100.00, 0.21);
echo $price;
```
<!-- doctest: 121.00 -->
````

Re-verify: `vendor/bin/doctest docs/api.md:5 -v` → PASS

**What the reader sees (rendered):**

```
$price = $calculator->withTax(100.00, 0.21);
echo $price;
```

---

## Step 3B: EXISTING Block — Analyze → Fix → Run → Hide

When an existing block doesn't run:

1. **Run the block to see what fails:**
   ```bash
   vendor/bin/doctest {file}:{N} -vv
   ```
2. **Analyze the failure** — what's missing?
3. **Choose the fix strategy:**

   | Missing | Fix |
   |---------|-----|
   | Autoloader / framework | Add `bootstrap="profile"` attribute |
   | `<?php` tag | Add `<?php // [!code hide]` |
   | `use` imports | Add `use ...; // [!code hide]` |
   | Variables from context | Add setup with `// [!code hide]` |
   | Complex setup (4+ lines) | Use `// [!code hide:start/end]` block |

4. **Run again** — repeat until passing
5. **Add assertion** if missing

### Example: EXISTING Block Needing Framework

**Before — block marked as non-runnable:**

````markdown
```php ignore
$user = User::find(1);
echo $user->name;
```
````

**Step 1 — Run:** fails (no autoloader, no User class)

**Step 2 — Check bootstrap inventory:** `.doctest/laravel.php` exists, `.doctest/database.php` exists, `.doctest/migrations.php` exists

**Step 3 — Fix: add bootstrap + test data setup:**

````markdown
```php bootstrap="laravel,database,migrations"
$user = User::factory()->create(['name' => 'Alice']); // [!code hide]

$user = User::find(1);
echo $user->name;
```
<!-- doctest: Alice -->
````

**Step 4 — Verify:** `vendor/bin/doctest docs/models.md:2 -v` → PASS

Note: `bootstrap="laravel,database,migrations"` loads the framework, configures the database, and runs migrations. The factory call creates test data — hidden because readers don't need to see it.

### Example: EXISTING Block with Complex Setup

**Before:**

````markdown
```php no_run
$report = $analyzer->generate($data);
echo $report->summary();
```
````

**After — using block hide for 4+ setup lines:**

````markdown
```php
// [!code hide:start]
<?php
require_once 'vendor/autoload.php';
use App\Analytics\Analyzer;
use App\Analytics\DataSet;

$analyzer = new Analyzer();
$data = DataSet::fromArray([
    ['value' => 10, 'category' => 'A'],
    ['value' => 20, 'category' => 'B'],
]);
// [!code hide:end]

$report = $analyzer->generate($data);
echo $report->summary();
```
<!-- doctest-contains: Total: 30 -->
````

---

## Step 4: HARDEN WITH INLINE ASSERTIONS

After blocks run successfully, add `// =>` to strengthen verification on non-trivial expression lines.

**Add `// =>` when the line:**
- Computes a meaningful result: `$tax = $price * 0.21; // => 21.0`
- Calls a method being documented: `$len = strlen('test'); // => 4`
- Performs a transformation: `$upper = strtoupper('hello'); // => 'HELLO'`
- Aggregates data: `$total = array_sum($prices); // => 299.97`

**Skip `// =>` when the line:**
- Assigns a literal: `$name = 'Alice'`
- Constructs an object: `$calculator = new Calculator()`
- Performs a side effect: `$db->save()`, `file_put_contents(...)`
- Already outputs via `echo` with a `<!-- doctest: -->` assertion

### Example: Hardening a Multi-Step Computation

**Before (runs, but only checks final output):**

````markdown
```php
$items = [10.00, 25.50, 14.50];
$subtotal = array_sum($items);
$tax = $subtotal * 0.21;
$total = $subtotal + $tax;
echo "Total: $total";
```
<!-- doctest: Total: 60.5 -->
````

**After (intermediate values verified):**

````markdown
```php
$items = [10.00, 25.50, 14.50];
$subtotal = array_sum($items); // => 50.0
$tax = $subtotal * 0.21; // => 10.5
$total = $subtotal + $tax; // => 60.5
echo "Total: $total";
```
<!-- doctest: Total: 60.5 -->
````

Now if `array_sum` or the tax calculation changes, the `// =>` assertions catch the exact line where the value diverges — not just the final output.

**Verify after adding:** `vendor/bin/doctest {file}:{N} -v` — all `// =>` are checked alongside the output assertion.

---

## Step 5: BOOTSTRAP RECOMMENDATIONS

After processing blocks, look for repeated patterns:

| Pattern | Recommendation |
|---------|---------------|
| 3+ blocks need autoloader | Add global bootstrap in `doctest.php`: `'bootstrap' => '.doctest/bootstrap.php'` |
| 3+ blocks need same framework | Create `.doctest/{framework}.php` profile |
| 3+ blocks need same DB tables | Create `.doctest/migrations.php` profile |
| Blocks share variable definitions | Consider `group` with `setup` block instead of hide |

Suggest new profiles to the user before creating them. Each profile should have a single responsibility — compose them with `bootstrap="a,b,c"` for blocks that need multiple concerns.

---

## Step 6: VERIFY ALL

After all blocks are processed, run the full file:

```bash
vendor/bin/doctest {file} -v
```

Block index targeting (`file:N`) is for fast iteration on individual blocks. Final verification should always run the whole file to ensure blocks don't interfere with each other.

---

## Hide Strategy Reference

| Boilerplate Size | Technique | Example |
|------------------|-----------|---------|
| Framework/autoloader | `bootstrap="profile"` attribute | `bootstrap="laravel"` |
| Shared across blocks | `group` with `setup` block | `setup group="db"` |
| 4+ lines | `// [!code hide:start/end]` block | See complex setup example above |
| 1-3 lines | `// [!code hide]` per line | `use App\User; // [!code hide]` |

---

## Decision Guide

```
Block doesn't run?
├── Needs framework/autoloader?
│   ├── Profile exists → Add bootstrap="profile" attribute
│   └── No profile → Suggest creating one, OR inline hide
├── Missing <?php / use / require?
│   └── Add with // [!code hide]
├── Missing variable definitions?
│   ├── 1-3 lines → // [!code hide] per line
│   └── 4+ lines → // [!code hide:start/end]
├── Too complex to mock?
│   └── Leave as ignore/no_run
└── After any fix → VERIFY with vendor/bin/doctest {file}:{N} -v
```

---

## When NOT to Convert

Leave blocks as `ignore` or `no_run` when:

- **Config snippets** (`return [...]`) — partial files, not executable
- **External service dependencies** — Redis, real APIs, real databases without mocking
- **Intentionally broken code** — anti-pattern demonstrations
- **Pseudocode** — conceptual examples not meant to run
- **Mocking cost exceeds value** — complex setup for minimal verification benefit
