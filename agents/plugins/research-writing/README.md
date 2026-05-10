# research-writing

A Claude Code plugin bundling skills for drafting, revising, and diagnosing scientific research papers. Each skill targets one section of a typical empirical paper and is adapted from Hilary Glasman-Deal's *Science Research Writing: For Non-Native Speakers of English*.

## Skills

| Skill | Use when working on |
|-------|---------------------|
| `abstract` | Abstracts and titles — drafting, shortening, structured vs. single-paragraph formats, keyword tuning. |
| `introduction` | Introduction sections — establishing the field, locating prior work, stating the research gap, describing the present study. |
| `methodology` | Methods / Materials and Methods / Experimental / Procedure / Simulation / Model sections — reproducibility, voice, justification of choices. |
| `results-evaluation` | Results / Data Analysis / Results and Discussion sections — interpreting tables and figures, evaluating findings, comparing with prior work. |

## Installation

Install from a local checkout:

```bash
claude --plugin-dir /path/to/research-writing
```

Or copy the directory under your project's `.claude-plugin/` to enable it for that project.

## Usage

Skills load automatically when their trigger conditions match — for example, asking Claude to "draft an abstract", "revise this Methods section", or "evaluate these results" will invoke the matching skill. Each skill begins with a "First Checks" pass to confirm target journal, section name, and reader before drafting.

## Source

Guidance is adapted from:

> Glasman-Deal, H. *Science Research Writing: For Non-Native Speakers of English.* Imperial College Press.

Each skill cites the specific unit (1 = Introduction, 2 = Methodology, 3 = Results, 5 = Abstract).

## License

MIT
