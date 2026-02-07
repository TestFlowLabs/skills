# MAKE-RUNNABLE Mode Reference

Makes non-runnable documentation code blocks executable by adding the necessary boilerplate with `// [!code hide]` markers. Hidden lines are invisible in rendered docs (VitePress/Shiki) but execute when DocTest runs the block.

---

## Workflow

### Step 1: SCAN

1. Find all PHP blocks in target files
2. Identify blocks that are non-runnable:
   - Have `ignore` or `no_run` attributes
   - Would fail without setup code (missing `<?php`, `use`, `require`, undefined variables)

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

Choose the appropriate hide pattern based on number of boilerplate lines.

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

### Step 4: FINALIZE

1. Remove the `ignore` or `no_run` attribute (the block is now runnable)
2. Add the appropriate assertion (`<!-- doctest: -->`, `// =>`, etc.)
3. Verify each file after conversion:
   ```bash
   vendor/bin/doctest {file} -v
   ```
4. Report summary: blocks converted, blocks still needing attention

---

## Decision Guide

```
Block has `ignore` or `no_run`?
├── YES → Can the missing dependency be mocked/provided?
│   ├── YES → How many boilerplate lines?
│   │   ├── 1-3 lines → Single-line hide (// [!code hide])
│   │   └── 4+ lines → Block hide (// [!code hide:start/end])
│   └── NO → Leave as ignore/no_run
└── NO → Not a MAKE-RUNNABLE candidate
```

---

## When NOT to Convert

Leave blocks as `ignore` or `no_run` when:

- **Config snippets** (`return [...]`) — These are partial files, not executable
- **Framework-specific code** — Requires Laravel/Symfony runtime, can't mock easily
- **External service dependencies** — Redis, API calls, real databases
- **Intentionally broken code** — Anti-pattern demonstrations
- **Pseudocode** — Conceptual examples not meant to run

---

## Tips

- Start with blocks that only need 1-2 hidden lines (quick wins)
- Use `// [!code hide:start/end]` for blocks needing complex setup
- The companion npm package `shiki-hide-lines` renders hidden lines as collapsible placeholders in the browser
- Always add an assertion after making a block runnable — otherwise there's no verification
- Run DocTest after each file to catch issues early
