# Attributes Reference

Attributes control how DocTest handles each code block. They appear in the fence info string after `php`.

**Syntax:** ` ```php attribute_here `

---

## ignore

Skip the block entirely. Not executed, not syntax-checked. Reported as "skipped".

````markdown
```php ignore
$config = require 'missing-file.php';
```
````

**Console output:** `:5 ⊘ $config = require 'missing-file.php';  [1/3]`

**Use when:**
- External dependencies not available (Redis, APIs, etc.)
- Configuration examples that can't run standalone
- Pseudocode or incomplete snippets
- Demonstrating incorrect usage intentionally

---

## no_run

Syntax check only — validates with `php -l`, doesn't execute.

````markdown
```php no_run
$db->query('SELECT * FROM users');
```
````

**How it works:**
1. Code written to temp file
2. `php -l` runs against the file
3. Valid syntax → pass
4. Syntax error → fail with error message

**Use when:**
- Examples require runtime resources (database, API, services)
- Code shows patterns that can't run standalone
- Want to verify syntax without execution

**Difference from ignore:**

| | `ignore` | `no_run` |
|---|---|---|
| Syntax check | No | Yes |
| Execution | No | No |
| Reports as | Skipped | Pass/Fail |

---

## throws

Expect an exception. Block passes if the specified exception is thrown.

**Three forms:**

````markdown
```php throws
throw new RuntimeException('Something went wrong');
```

```php throws(InvalidArgumentException)
throw new InvalidArgumentException('Expected an integer');
```

```php throws(InvalidArgumentException, "Expected an integer")
throw new InvalidArgumentException('Expected an integer');
```
````

**How it works:**
1. Code wrapped in `try/catch`
2. Exception class and message captured
3. If specific class expected, thrown class is compared
4. If message specified, `str_contains()` check performed
5. No exception thrown → fail

**Failure conditions:**
- No exception thrown
- Different exception class than expected
- Exception message doesn't contain expected substring

---

## parse_error

Expect a PHP parse error. Block passes if code fails to parse (non-zero exit from PHP).

````markdown
```php parse_error
echo 'Hello
```
````

**How it works:**
1. Code written to temp file as-is
2. File executed with PHP
3. Non-zero exit (parse error) → **pass**
4. Successful execution → **fail**

**Use when:**
- Demonstrating invalid PHP syntax
- Teaching materials showing common mistakes
- Documentation explaining parser behavior

---

## group

Link blocks to share state within a single PHP process.

````markdown
```php group="name"
$x = 42;
```

```php group="name"
echo $x; // $x is still available
```
<!-- doctest: 42 -->
````

**How it works:**
1. All blocks with same `group` value collected
2. Execute in document order in a **single PHP process**
3. Variables, functions, classes persist across blocks
4. Each block's assertions evaluated independently

**Multiple groups:** Each group runs in its own process. Groups are independent.

---

## setup / teardown

Lifecycle hooks for groups. Run before/after group blocks.

````markdown
```php setup group="name"
// Runs BEFORE any regular blocks in group
```

```php teardown group="name"
// Runs AFTER all regular blocks in group
```
````

**Setup:** Initializes resources. Variables available to all group blocks.

**Teardown:** Cleans up resources. Has access to all variables from setup and group blocks.

**Execution order within a group:**
1. `setup` blocks (document order)
2. Regular group blocks (document order)
3. `teardown` blocks (document order)

**Global setup/teardown:** Without a group name, applies to all non-grouped blocks:

````markdown
```php setup
require_once 'vendor/autoload.php';
```
````

**Multiple setup/teardown:** Multiple blocks are allowed. They execute in document order.

**Tips:**
- Setup blocks don't need assertions
- Teardown is optional but recommended for cleanup
- If setup fails, all blocks in the group fail

---

## Combining Attributes

Some attributes combine naturally:

````markdown
```php setup group="database"
// Both setup and group
```

```php teardown group="database"
// Both teardown and group
```
````

---

## bootstrap

Load PHP files before executing a code block. Profiles are `.php` files in the `.doctest/` directory.

**Info string syntax:**
````markdown
```php bootstrap="laravel"
echo config('app.name');
```

```php bootstrap="laravel,database"
// Both profiles loaded, left to right
```
````

**HTML comment syntax:**
````markdown
<!-- doctest-attr: bootstrap="laravel" -->
```php
echo config('app.name');
```
````

**Profile discovery:** Only `.php` files directly in `.doctest/` are discovered (not subdirectories). File name without `.php` becomes the profile name.

**Execution order:** global bootstrap (config) → profiles (left to right) → setup → code → teardown

**With groups:** All blocks in the same group must use identical bootstrap profiles.

**Custom directory:** Set `bootstraps_dir` in config (default: `.doctest`).

---

## HTML Comment Attribute Syntax

All attributes can be specified via HTML comments instead of the info string. This preserves editor syntax highlighting for the PHP code.

**Syntax:** `<!-- doctest-attr: attribute_here -->` on the line immediately before the code fence.

````markdown
<!-- doctest-attr: ignore -->
```php
$config = require 'missing-file.php';
```

<!-- doctest-attr: throws(InvalidArgumentException) -->
```php
throw new InvalidArgumentException('Bad input');
```

<!-- doctest-attr: bootstrap="laravel" group="users" setup -->
```php
$user = User::factory()->create();
```
````

**Rules:**
- Must appear on the line directly before the code fence
- Both syntaxes (info string and HTML comment) can coexist on the same block
- But the same attribute should not appear in both places
- Supports all attributes: `ignore`, `no_run`, `throws`, `parse_error`, `group`, `setup`, `teardown`, `bootstrap`

---

## Processing Priority

When a block has attributes, DocTest processes in this order:

1. **ignore** — skip immediately, no further processing
2. **no_run** — syntax check only (`php -l`)
3. **parse_error** — execute and expect non-zero exit
4. **throws** — execute with try/catch wrapper
5. **group/setup/teardown** — group execution with shared state
