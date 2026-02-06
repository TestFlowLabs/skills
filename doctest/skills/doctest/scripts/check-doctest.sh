#!/usr/bin/env bash
# DocTest environment check script
# Outputs JSON with environment info for the skill to consume

set -euo pipefail

json_output=""

# PHP version
if command -v php &> /dev/null; then
    php_version=$(php -r 'echo PHP_VERSION;')
    php_major=$(php -r 'echo PHP_MAJOR_VERSION;')
    php_minor=$(php -r 'echo PHP_MINOR_VERSION;')
    php_ok="false"
    if [ "$php_major" -gt 8 ] || ([ "$php_major" -eq 8 ] && [ "$php_minor" -ge 4 ]); then
        php_ok="true"
    fi
    json_output="\"php\": {\"version\": \"$php_version\", \"meets_requirement\": $php_ok}"
else
    json_output="\"php\": {\"version\": null, \"meets_requirement\": false}"
fi

# Composer
if [ -f "composer.json" ]; then
    composer_json="true"
else
    composer_json="false"
fi
json_output="$json_output, \"composer_json\": $composer_json"

# DocTest binary
if [ -f "vendor/bin/doctest" ]; then
    doctest_installed="true"
else
    doctest_installed="false"
fi
json_output="$json_output, \"doctest_installed\": $doctest_installed"

# Config file
if [ -f "doctest.php" ]; then
    config_exists="true"
else
    config_exists="false"
fi
json_output="$json_output, \"config_exists\": $config_exists"

# Markdown files
md_count=0
if [ -d "docs" ]; then
    md_count=$(find docs -name "*.md" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ -f "README.md" ]; then
    md_count=$((md_count + 1))
fi
json_output="$json_output, \"markdown_files\": $md_count"

# PHP code blocks in markdown files
php_blocks=0
if [ "$md_count" -gt 0 ]; then
    if [ -d "docs" ]; then
        blocks_in_docs=$(grep -r '```php' docs/ --include="*.md" -l 2>/dev/null | wc -l | tr -d ' ')
        php_blocks=$((php_blocks + blocks_in_docs))
    fi
    if [ -f "README.md" ]; then
        blocks_in_readme=$(grep -c '```php' README.md 2>/dev/null || echo "0")
        if [ "$blocks_in_readme" -gt 0 ]; then
            php_blocks=$((php_blocks + 1))
        fi
    fi
fi
json_output="$json_output, \"files_with_php_blocks\": $php_blocks"

# Bootstrap file
bootstrap_configured="false"
if [ -f "doctest.php" ]; then
    if grep -q "bootstrap" doctest.php 2>/dev/null; then
        bootstrap_configured="true"
    fi
fi
json_output="$json_output, \"bootstrap_configured\": $bootstrap_configured"

echo "{$json_output}"
