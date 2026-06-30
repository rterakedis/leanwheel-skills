---
name: research
description: Run cited, web-grounded research (technical / domain / market) to ground product, PRD, or architecture decisions in real external facts instead of model assumptions. Use when the user wants to research a technology choice, an industry/regulatory landscape, or customers/competitors before committing to a direction.
---

# Research Skill

**Goal:** Produce a short, cited research doc that replaces guesswork with sourced findings — feeding `/product-brief`, `/prd`, or `/architecture` with real external grounding instead of `[ASSUMPTION]` tags pulled from the model's own head.

**Your role:** Researcher, not author of opinions. Every claim needs a source; if the web doesn't substantiate something, say so rather than filling the gap.

## Activation

1. Ask (or infer from phrasing): **what's the topic, and is this more technical (architecture/stack/integration), domain (industry/regulatory/competitive landscape), or market (customers/competitors/buying behavior)?** Confirm if ambiguous — the type picks the facet list below.
2. If web search isn't available in this environment, stop and say so rather than fabricating findings.

## Facet Lists by Type

Pick the matching list — these are the subtopic areas to search and write up, not a fixed step sequence.

**Technical**
- Technology stack — languages, frameworks, databases, cloud platforms, tooling
- Integration patterns — APIs, protocols, interoperability approaches
- Architectural patterns — system architecture, design principles, scalability approaches
- Implementation considerations — adoption strategy, team/ops impact, cost

**Domain**
- Industry analysis — market size, growth, segmentation
- Competitive landscape — players, market share, business models
- Regulatory & compliance — relevant regulations, standards, privacy/licensing constraints
- Technical trends — emerging tech and where the domain is heading

**Market**
- Customer behavior — demographics, psychographics, segments
- Pain points — frustrations, unmet needs, adoption barriers
- Decision journey — touchpoints, decision factors, who's involved in buying
- Competitive analysis — how alternatives position against the need

## Flow

### Step 1 — Scope confirm
Restate the topic, the goal (what decision this research informs), and the 3-4 facet areas you'll cover for the chosen type. One checkpoint with the user before searching — catch a wrong type or missing angle before spending searches on it.

### Step 2 — Research
Work through each facet area for the chosen type. Per facet: run 3-4 web searches scoped to that facet's specific angles, then write a cited section immediately — don't hold findings in context across facets. Every claim gets a `_Source: [URL]_` tag. If a facet turns up thin or contradictory results, say so in the doc rather than padding it.

Write directly to `docs/project/research/{type}-{topic-slug}-{date}.md` as you go, building the doc facet by facet.

### Step 3 — Synthesis
Close the doc with:
- **Key findings** — 3-5 bullets, the things that actually matter for the decision at hand.
- **Confidence & gaps** — where sources agreed/disagreed, and what's still unknown.
- **Recommendation** — how this should inform the next step, stated plainly.

### Step 4 — Output
File path, then: "Feed this into `/product-brief` or `/prd` next" (or `/architecture` for technical research already mid-project).
