# Block Classification Decision Tree

Use this decision tree to classify each PHP code block and determine the appropriate action.

---

## Decision Flow

```
1. Has assertion already?
   ├── YES → SKIP (already tested)
   └── NO → continue

2. Has attribute already? (ignore, no_run, throws, parse_error)
   ├── YES → SKIP (already controlled)
   └── NO → continue

3. Is it intentionally invalid syntax?
   ├── YES → ADD `parse_error` attribute
   └── NO → continue

4. Does it throw an exception intentionally?
   ├── YES → ADD `throws` or `throws(ClassName)` or `throws(ClassName, "msg")`
   └── NO → continue

5. Does it require external resources? (DB, API, Redis, file system, network)
   ├── YES → ADD `no_run` attribute (syntax check only)
   └── NO → continue

6. Is it a config/require/use statement that can't run standalone?
   ├── YES → ADD `ignore` attribute
   └── NO → continue

7. Does it produce output? (echo, print, var_dump, print_r)
   ├── YES → go to OUTPUT CLASSIFICATION
   └── NO → continue

8. Does it assign values worth verifying?
   ├── YES → ADD `// => value` or `<!-- doctest-expect: $var === value -->`
   └── NO → continue

9. Is it part of a sequence building on prior blocks?
   ├── YES → ADD `group="name"`, consider setup/teardown
   └── NO → LEAVE AS-IS (no assertion needed — passes if no error)
```

---

## Output Classification

When a block produces output, choose the assertion type:

```
1. Is output static JSON?
   ├── YES → ADD `<!-- doctest-json: {output} -->`
   └── NO → continue

2. Is output completely static/predictable?
   ├── YES → ADD `<!-- doctest: {exact output} -->`
   └── NO → continue

3. Does output contain dynamic values with known format?
   │   (timestamps, UUIDs, integers, floats)
   ├── YES → ADD `<!-- doctest: {output with wildcards} -->`
   │         Use: {{date}}, {{time}}, {{datetime}}, {{uuid}},
   │              {{int}}, {{float}}, {{any}}, {{...}}
   └── NO → continue

4. Is only a specific part of the output important?
   ├── YES → ADD `<!-- doctest-contains: {important part} -->`
   └── NO → continue

5. Does output follow a known pattern?
   ├── YES → ADD `<!-- doctest-matches: /pattern/ -->`
   └── NO → ASK USER (output is too dynamic to assert automatically)
```

---

## Examples by Classification

### Already has assertion → SKIP

````markdown
```php
echo 'Hello';
```
<!-- doctest: Hello -->
````
Action: Do nothing.

### Intentional parse error → `parse_error`

````markdown
```php parse_error
$x = 42
echo $x;
```
````

### Throws exception → `throws`

````markdown
```php throws(InvalidArgumentException)
throw new InvalidArgumentException('Bad input');
```
````

### External resources → `no_run`

````markdown
```php no_run
$users = DB::table('users')
    ->where('active', true)
    ->get();
```
````

### Config/require → `ignore`

````markdown
```php ignore
return [
    'database' => 'mysql',
    'host' => 'localhost',
];
```
````

### Static output → `<!-- doctest: -->`

````markdown
```php
echo 'Hello, World!';
```
<!-- doctest: Hello, World! -->
````

### JSON output → `<!-- doctest-json: -->`

````markdown
```php
echo json_encode(['status' => 'ok', 'code' => 200]);
```
<!-- doctest-json: {"status": "ok", "code": 200} -->
````

### Dynamic output with wildcards → `<!-- doctest: {{...}} -->`

````markdown
```php
echo 'Created at ' . date('Y-m-d H:i:s');
```
<!-- doctest: Created at {{date}} {{time}} -->
````

### Partial match → `<!-- doctest-contains: -->`

````markdown
```php
echo 'The system processed 42 items and generated a report';
```
<!-- doctest-contains: processed 42 items -->
````

### Value assignment → `// =>`

````markdown
```php
$sum = array_sum([1, 2, 3, 4, 5]); // => 15
```
````

### Expression check → `<!-- doctest-expect: -->`

````markdown
```php
$result = array_filter([1, 2, 3, 4, 5], fn($n) => $n > 3);
```
<!-- doctest-expect: count($result) === 2 -->
````

### Sequence → `group`

````markdown
```php setup group="cart"
$cart = [];
```

```php group="cart"
$cart[] = ['item' => 'Widget', 'price' => 9.99];
echo count($cart);
```
<!-- doctest: 1 -->

```php group="cart"
$cart[] = ['item' => 'Gadget', 'price' => 19.99];
$total = array_sum(array_column($cart, 'price'));
echo $total;
```
<!-- doctest: 29.98 -->
````

### No output, no assignment → Leave as-is

````markdown
```php
function greet(string $name): string {
    return "Hello, {$name}!";
}
```
````
Action: No assertion needed. Block passes if no error during execution.

---

## Red Flags — When to Ask the User

- Block has side effects you're unsure about
- Output depends on external state or time (beyond what wildcards cover)
- Block seems incomplete or is part of a larger context
- Can't determine if the block is meant to be standalone or grouped
- Code references variables/classes not defined in the block and not from a group
