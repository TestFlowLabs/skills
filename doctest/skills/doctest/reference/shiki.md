# Shiki Compatibility Reference

DocTest automatically handles Shiki markers used in any Shiki-powered documentation tool — VitePress, Astro, Nuxt Content, Slidev, or direct Shiki usage.

No configuration needed. This is always active.

---

## Processing Order

ShikiFilter processes markers in this order:

1. `// [!code --]` — remove entire line
2. `// [!code hide:start]` / `// [!code hide:end]` — remove delimiter lines, keep inner lines
3. Catch-all regex — strip remaining `// [!code xxx]` markers, keep code

---

## Marker Behavior Table

Every marker follows one of two rules:

1. **Remove the entire line** — the line is not needed for execution
2. **Strip the marker, keep the code** — the code must execute, but the marker comment is removed

| Marker | Rendered Docs | DocTest Execution |
|--------|--------------|-------------------|
| `{1,4-6}` | Highlighted lines | Stripped from info string |
| `// [!code --]` | Red diff line | Line removed entirely |
| `// [!code ++]` | Green diff line | Marker stripped, line kept |
| `// [!code hide]` | Line hidden | Marker stripped, line kept |
| `// [!code hide:start]` | Block hidden | Delimiter line removed |
| `// [!code hide:end]` | Block hidden | Delimiter line removed |
| `// [!code highlight]` | Yellow highlight | Marker stripped, line kept |
| `// [!code focus]` | Focused line | Marker stripped, line kept |
| `// [!code warning]` | Warning style | Marker stripped, line kept |
| `// [!code error]` | Error style | Marker stripped, line kept |
| `// [!code word:xxx]` | Word highlight | Marker stripped, line kept |

---

## Per-Marker Details

### Line Highlights `{1,4-6}`

The `{...}` notation is **stripped from the info string** so it doesn't interfere with attribute parsing:

```
php{1,4-6}  →  php
```

### Diff Removal `// [!code --]`

Lines containing `// [!code --]` are **removed entirely**. These represent "old" code that shouldn't execute:

```php ignore
// Before filtering:
$old = 'before'; // [!code --]
$new = 'after';  // [!code ++]

// After filtering:
$new = 'after';
```

### Diff Addition `// [!code ++]`

The `// [!code ++]` marker is **stripped**, but the code is kept:

```php ignore
// Before filtering:
$new = 'after'; // [!code ++]

// After filtering:
$new = 'after';
```

### Single-Line Hide `// [!code hide]`

The `// [!code hide]` marker is **stripped**, but the code is kept. Useful for lines that must run (`<?php` tags, `use` statements, `require`) but would distract readers:

```php ignore
// Before filtering:
<?php // [!code hide]
require_once 'vendor/autoload.php'; // [!code hide]
use App\Models\User; // [!code hide]

$user = User::find(1);

// After filtering:
<?php
require_once 'vendor/autoload.php';
use App\Models\User;

$user = User::find(1);
```

### Block Hide `// [!code hide:start]` / `// [!code hide:end]`

For hiding multiple consecutive lines. The **delimiter lines are removed entirely**, but all lines between them are kept:

```php ignore
// Before filtering:
$visible = 1;
// [!code hide:start]
$setup_a = 2;
$setup_b = 3;
// [!code hide:end]
$also_visible = 4;

// After filtering:
$visible = 1;
$setup_a = 2;
$setup_b = 3;
$also_visible = 4;
```

Edge cases:
- An unclosed `// [!code hide:start]` removes only the marker line — all following lines are kept
- An orphan `// [!code hide:end]` is simply removed

### Other Markers (highlight, focus, warning, error, word)

All other `// [!code xxx]` markers are **stripped**, and the code is kept. These markers only affect visual rendering:

```php ignore
// Before filtering:
$x = 1; // [!code highlight]
$y = 2; // [!code focus]
$z = 3; // [!code warning]

// After filtering:
$x = 1;
$y = 2;
$z = 3;
```

---

## Interaction with MAKE-RUNNABLE

The `// [!code hide]` marker is the primary tool for the MAKE-RUNNABLE workflow. When making blocks runnable, hidden boilerplate uses these markers so:

1. **DocTest** strips the markers and executes the full code (including hidden lines)
2. **Shiki** hides the marked lines from rendered documentation
3. **Readers** see only the meaningful code, not the boilerplate

See `reference/make-runnable.md` for the full MAKE-RUNNABLE workflow.
