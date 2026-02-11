# Assertion Types Reference

DocTest supports 6 assertion types. All use HTML comments (invisible in rendered docs) or inline `// =>` comments.

---

## 1. Output (`<!-- doctest: -->`)

Exact output match. Compares captured output character-for-character after normalization.

**Syntax:**
````markdown
```php
echo 'Hello, World!';
```
<!-- doctest: Hello, World! -->
````

**Multi-line:**
````markdown
```php
echo "line 1\nline 2\nline 3";
```
<!-- doctest: line 1
line 2
line 3 -->
````

**With wildcards:**
````markdown
```php
echo 'Processed 42 items at ' . date('Y-m-d');
```
<!-- doctest: Processed {{int}} items at {{date}} -->
````

**How it works:**
- Output captured via `ob_start()` / `ob_get_clean()`
- Trailing whitespace trimmed, line endings unified to `\n`
- If wildcards present, switches to regex comparison
- Without wildcards, uses strict string equality (`===`)

**When to use:** Default choice for blocks that produce output via `echo`/`print`.

---

## 2. OutputContains (`<!-- doctest-contains: -->`)

Partial output match using `str_contains()`.

**Syntax:**
````markdown
```php
echo 'The quick brown fox jumps over the lazy dog';
```
<!-- doctest-contains: brown fox -->
````

**How it works:**
- Case-sensitive `str_contains()` check
- No wildcards needed (partial by nature)

**When to use:**
- Only care about a specific part of output
- Full output is too long or variable
- Surrounding content may change

---

## 3. OutputMatches (`<!-- doctest-matches: -->`)

Regex pattern match using `preg_match()`.

**Syntax:**
````markdown
```php
echo date('Y');
```
<!-- doctest-matches: /^\d{4}$/ -->
````

**Pattern must include delimiters** (like PHP's `preg_match()`):
````markdown
```php
echo 'Hello World';
```
<!-- doctest-matches: /hello world/i -->
````

**When to use:**
- Output has known structure but variable content
- Need more precision than `OutputContains`
- Validating formats (emails, versions, etc.)

**Tip:** For common dynamic patterns (dates, UUIDs, integers), prefer wildcards with the `Output` assertion — they're more readable.

---

## 4. OutputJson (`<!-- doctest-json: -->`)

JSON structure comparison. Decodes both sides and compares structurally.

**Syntax:**
````markdown
```php
echo json_encode(['name' => 'DocTest', 'php' => '8.4+']);
```
<!-- doctest-json: {"name": "DocTest", "php": "8.4+"} -->
````

**How it works:**
- Both expected and actual decoded with `json_decode()`
- Keys recursively sorted — **key order doesn't matter**
- Compared with `===` after sorting
- Invalid JSON on either side → assertion fails with descriptive error

**Important:** Array order **does** matter. `["a", "b"]` ≠ `["b", "a"]`.

**Nested structures:**
````markdown
```php
echo json_encode([
    'user' => ['name' => 'Alice', 'age' => 30],
    'roles' => ['admin', 'editor'],
]);
```
<!-- doctest-json: {"user": {"name": "Alice", "age": 30}, "roles": ["admin", "editor"]} -->
````

**When to use:** Any block that outputs JSON.

---

## 5. Expect (`<!-- doctest-expect: -->`)

Evaluates a PHP expression that must be truthy.

**Syntax:**
````markdown
```php
$result = array_sum([1, 2, 3, 4, 5]);
```
<!-- doctest-expect: $result === 15 -->
````

**How it works:**
- Code block executes first
- Expression evaluated with `(bool)(expression)`
- Has access to all variables from the code block
- `true` → pass, `false` → fail

**Multiple expects per block:**
````markdown
```php
$name = 'DocTest';
$version = 1;
```
<!-- doctest-expect: is_string($name) -->
<!-- doctest-expect: $version >= 1 -->
<!-- doctest-expect: strlen($name) > 0 -->
````

**When to use:**
- Verifying computed values without printing them
- Assertions involving comparisons or function calls
- APIs where return values matter more than printed output

**Tips:**
- Use strict comparisons (`===`) when possible
- Can call functions: `<!-- doctest-expect: is_array($result) -->`

---

## 6. Result Comment (`// =>`)

Inline return value comparison using `var_export()`.

**Syntax:**
```php
$x = 42; // => 42
$flag = true; // => true
$nothing = null; // => NULL
```

**How it works:**
- Expression left of `// =>` is evaluated
- Result converted via `var_export()`
- Compared against expected value on right

**var_export format:**

| PHP Value | Expected |
|-----------|----------|
| `42` | `42` |
| `3.14` | `3.14` |
| `true` | `true` |
| `false` | `false` |
| `null` | `NULL` |
| `'hello'` | `'hello'` |

**Examples:**
```php
$a = 10 + 5; // => 15
$upper = strtoupper('hello'); // => 'HELLO'
$len = strlen('test'); // => 4
$empty = empty([]); // => true
```

**Regular comments are ignored** — only `// =>` triggers an assertion:
```php
$x = 42; // This is just a comment
$y = 42; // => 42   <-- This IS an assertion
```

**When to use:** Inline demonstrations of expression return values. Natural PHP documentation pattern.

---

## 7. Debug Dump (`// => dd()`)

Inspect expression values without affecting pass/fail. Always passes. Value always shown in output regardless of verbosity level.

**Syntax:**
```php
$x = 42; // => dd()
```

**Output:** `dd $x = 42 => 42`

**Multiple expressions:**
```php
$x = 1; // => dd()
$y = 2; // => dd()
$z = $x + $y; // => dd()
```

**How it works:**
- Expression left of `// => dd()` is evaluated
- Result formatted with `var_export()`
- Printed to output as `dd {expression} => {value}`
- Block **always passes** regardless of value

**When to use:**
- Exploring what an expression returns during development
- Understanding intermediate values in multi-step code
- Debugging a failing block by inspecting values
- Can be combined with other assertions in the same block

---

## Combining Assertions

A single code block can have multiple assertions of different types:

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

## No Assertion

Code blocks without any assertion still execute. If they produce no error, they pass. Useful for syntax demonstrations.

---

## Choosing the Right Assertion

| Scenario | Assertion |
|----------|-----------|
| Block outputs known static text | `<!-- doctest: exact output -->` |
| Block outputs text with dynamic parts | `<!-- doctest: text {{wildcard}} text -->` |
| Only care about part of the output | `<!-- doctest-contains: substring -->` |
| Output has a pattern/format to validate | `<!-- doctest-matches: /regex/ -->` |
| Block outputs JSON | `<!-- doctest-json: {...} -->` |
| Need to check a variable's value without printing | `<!-- doctest-expect: $var === value -->` |
| Showing expression return values inline | `$x = expr; // => value` |
| Inspecting values during development (always passes) | `$x = expr; // => dd()` |

---

## Inline Assertion Placement Guide

When proactively adding `// =>` to code blocks:

| Line Type | Add `// =>`? | Reason |
|-----------|-------------|--------|
| Method call with return value | Yes | Documents API behavior |
| Math/string computation | Yes | Verifies intermediate steps |
| Collection operation | Yes | Confirms transformation result |
| Simple literal assignment | No | Trivial — no computation to verify |
| Object construction | No | Return value is obvious (the object) |
| Side-effect call (`save`, `delete`) | No | Return value is not the focus |
| Line with `echo`/`print` | No | Use `<!-- doctest: -->` instead |
| Variable already checked by `expect` | No | Redundant verification |

**Principle:** `// =>` adds value when it verifies a **computation** the reader should understand. It adds noise when the value is obvious from the code.
