# TestFlowLabs Skills

Claude Code skills for documentation testing and quality assurance.

## Available Skills

| Skill | Description |
|-------|-------------|
| [doctest](doctest/) | Apply DocTest to markdown documentation — detect PHP code blocks, add assertions/attributes, run doctest to verify, review docs quality, make non-runnable blocks executable with hidden boilerplate |

## Installation

### Marketplace (recommended)

```bash
/plugin marketplace add testflowlabs/skills
/plugin install doctest@testflowlabs
```

### Manual — Project-level

```bash
mkdir -p .claude/skills/doctest
curl -sL https://github.com/testflowlabs/skills/archive/master.tar.gz | \
  tar -xz --strip-components=3 -C .claude/skills/doctest \
  skills-master/doctest/skills/doctest
```

### Manual — User-level

```bash
mkdir -p ~/.claude/skills/doctest
curl -sL https://github.com/testflowlabs/skills/archive/master.tar.gz | \
  tar -xz --strip-components=3 -C ~/.claude/skills/doctest \
  skills-master/doctest/skills/doctest
```

## Usage

After installing the doctest skill, use it in Claude Code:

```
/doctest                    # Apply doctest to your documentation
"run doctest"               # Verify existing doctest assertions
"fix doctest failures"      # Fix failing doctest blocks
"review docs"               # Review docs against testable documentation best practices
"make docs runnable"        # Add hidden boilerplate to non-runnable blocks
```

## Local Testing

Test a skill locally without installing:

```bash
claude --plugin-dir ./doctest
```

## License

MIT
