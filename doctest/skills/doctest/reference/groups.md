# Groups Reference

Groups link code blocks together so they share state within a single PHP process.

---

## Basic Group

Blocks with the same `group` value share variables:

````markdown
```php group="math"
$numbers = [1, 2, 3, 4, 5];
$sum = array_sum($numbers);
echo $sum;
```
<!-- doctest: 15 -->

```php group="math"
// $numbers and $sum are still available
$average = $sum / count($numbers);
echo $average;
```
<!-- doctest: 3 -->
````

---

## Setup / Teardown

Initialize and clean up resources:

````markdown
```php setup group="users"
$pdo = new PDO('sqlite::memory:');
$pdo->exec('CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT
)');
```

```php group="users"
$stmt = $pdo->prepare('INSERT INTO users (name, email) VALUES (?, ?)');
$stmt->execute(['Alice', 'alice@example.com']);
echo $pdo->lastInsertId();
```
<!-- doctest: 1 -->

```php group="users"
$user = $pdo->query("SELECT name FROM users WHERE id = 1")->fetch();
echo $user['name'];
```
<!-- doctest: Alice -->

```php teardown group="users"
$pdo->exec('DROP TABLE users');
$pdo = null;
```
````

---

## Execution Order

Within a group, execution follows this order:

1. **setup** blocks (in document order)
2. **Regular group blocks** (in document order)
3. **teardown** blocks (in document order)

All run in a single PHP process. Variables persist across all blocks.

---

## Multiple Groups

Multiple independent groups can coexist. Each runs in its own process:

````markdown
```php group="strings"
$greeting = 'Hello';
```

```php group="numbers"
$count = 42;
```

```php group="strings"
echo $greeting . ', World!';
```
<!-- doctest: Hello, World! -->

```php group="numbers"
echo $count * 2;
```
<!-- doctest: 84 -->
````

---

## Global Setup / Teardown

Setup/teardown without a group name applies to **all** non-grouped blocks:

````markdown
```php setup
require_once 'vendor/autoload.php';
```

```php
echo class_exists('Some\Class') ? 'yes' : 'no';
```
<!-- doctest: yes -->

```php teardown
// Cleanup after every non-grouped block
```
````

---

## Multiple Setup/Teardown Blocks

Multiple setup or teardown blocks execute in document order:

````markdown
```php setup group="app"
require_once 'vendor/autoload.php';
```

```php setup group="app"
$config = ['debug' => true];
```
````

---

## SQLite In-Memory Pattern

The most common group pattern uses SQLite in-memory databases:

````markdown
```php setup group="database"
$pdo = new PDO('sqlite::memory:');
$pdo->exec('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
```

```php group="database"
$pdo->exec("INSERT INTO users (name) VALUES ('Alice')");
$count = $pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
echo $count;
```
<!-- doctest: 1 -->

```php group="database"
$pdo->exec("INSERT INTO users (name) VALUES ('Bob')");
$count = $pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
echo $count;
```
<!-- doctest: 2 -->

```php teardown group="database"
$pdo->exec('DROP TABLE users');
```
````

**Why this works:**
- SQLite `:memory:` requires no external database
- `setup` creates the schema
- Group blocks share the `$pdo` connection
- `teardown` cleans up (optional for in-memory, but good practice)

---

## Tips

- Setup blocks don't need assertions — they're purely for initialization
- Teardown blocks are optional but recommended for resource cleanup
- If a setup block fails, all blocks in the group fail
- Each block's assertions are evaluated independently
- Use groups when blocks naturally build on each other (e.g., insert → query → update)
- Don't group blocks that should be independent — process isolation is a feature
