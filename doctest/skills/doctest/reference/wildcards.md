# Wildcards Reference

Wildcards match dynamic output without hardcoding values. Use them in `<!-- doctest: -->` assertions when exact values change between runs.

---

## Available Wildcards

| Wildcard | Matches | Regex Pattern |
|----------|---------|---------------|
| `{{any}}` | Any non-empty content (non-greedy) | `.+?` |
| `{{int}}` | Integer (optional negative sign) | `-?\d+` |
| `{{float}}` | Float or integer | `-?\d+\.?\d*` |
| `{{uuid}}` | UUID v4 format | `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` |
| `{{date}}` | ISO date (`YYYY-MM-DD`) | `\d{4}-\d{2}-\d{2}` |
| `{{time}}` | Time (`HH:MM:SS`) | `\d{2}:\d{2}:\d{2}` |
| `{{datetime}}` | ISO datetime with optional timezone | `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*` |
| `{{...}}` | Any content including newlines (non-greedy) | `[\s\S]*?` |

---

## Usage Examples

### Timestamps

```php
echo 'Generated: ' . date('Y-m-d H:i:s');
```
<!-- doctest: Generated: {{date}} {{time}} -->

### UUIDs

```php
echo sprintf('User ID: %s', '550e8400-e29b-41d4-a716-446655440000');
```
<!-- doctest: User ID: {{uuid}} -->

### Mixed dynamic content

```php
echo json_encode([
    'id' => 42,
    'created' => '2024-01-15T10:30:00Z',
    'price' => 19.99,
]);
```
<!-- doctest: {"id":{{int}},"created":"{{datetime}}","price":{{float}}} -->

### Multi-line with `{{...}}`

```php
echo "Header\nSome variable content\nhere\nFooter";
```
<!-- doctest: Header{{...}}Footer -->

### Combining wildcards

```php
echo sprintf('[%s] %s: Processed %d items in %.2fs',
    date('Y-m-d'),
    'INFO',
    150,
    0.42
);
```
<!-- doctest: [{{date}}] {{any}}: Processed {{int}} items in {{float}}s -->

---

## How It Works

1. DocTest checks if expected output contains any `{{...}}` patterns
2. Expected string is escaped with `preg_quote()`
3. Each wildcard placeholder replaced with its regex pattern
4. Result wrapped in `^...$` anchors with `s` (dotall) flag
5. `preg_match()` tests actual output against the pattern

**Processing order:** `{{datetime}}` is checked before `{{date}}` and `{{time}}` to avoid partial matches.

---

## Tips

- `{{any}}` is non-greedy — matches shortest possible string, does NOT match newlines
- `{{...}}` is also non-greedy but CAN match newlines — useful for skipping variable blocks
- `{{int}}` matches negative signs: `-42` matches `{{int}}`
- `{{float}}` also matches integers: `42` matches `{{float}}`
- Wildcards are **case-sensitive**: `{{INT}}` is NOT recognized
- Wildcards only work in `<!-- doctest: -->` assertions, not in `doctest-contains`, `doctest-matches`, `doctest-json`, `doctest-expect`, or `// =>`

---

## Choosing Between Wildcards and Other Assertions

| Scenario | Best Choice |
|----------|-------------|
| Output has 1-2 dynamic parts in known format | Wildcards (`{{date}}`, `{{int}}`) |
| Output is mostly dynamic, only care about a substring | `<!-- doctest-contains: substring -->` |
| Need complex pattern matching | `<!-- doctest-matches: /regex/ -->` |
| JSON with dynamic values | `<!-- doctest-json: -->` (for structure) or wildcards in `<!-- doctest: -->` |
