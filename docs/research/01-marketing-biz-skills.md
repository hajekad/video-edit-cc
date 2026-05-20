# Research: marketing / biz / people-science skill repos

Background research output from a parallel agent. Captures which skill
repos give the fsh-agent the *interpretation* layer for vague business
prompts ("here's footage for general marketing use") so it can pick the
right cuts, on-screen text, opening hooks, and brand voice.

## Top 5 must-clones (priority order)

1. **coreyhaines31/marketingskills** (29.5K★, MIT, 2026-05-19) — Single
   strongest find. 40+ skills including a dedicated `video` skill,
   `marketing-psychology`, `customer-research`, `product-marketing`
   (writes `.agents/product-marketing.md` ICP/positioning context all
   other skills consume — exact pattern we want), `content-strategy`,
   `launch`, `social` (short-form video hooks/scripts/Reels/Shorts
   covered), `ad-creative`, `cold-email`, `copywriting`, `cro`,
   `churn-prevention`.

2. **anthropics/knowledge-work-plugins** (12.3K★, Apache-2.0,
   2026-05-19) — already partially-aware via our anthropic-skills
   research. Clone these subdirs selectively:
   - `marketing/skills/` — `brand-review`, `campaign-plan`,
     `competitive-brief`, `content-creation`, `draft-content`,
     `email-sequence`, `performance-report`, `seo-audit`
   - `sales/skills/` — `account-research`, `call-prep`, `call-summary`,
     `competitive-intelligence`, `create-an-asset`, `daily-briefing`,
     `draft-outreach`, `forecast`, `pipeline-review`
   - `human-resources/skills/` — `comp-analysis`, `draft-offer`,
     `interview-prep`, `onboarding`, `org-planning`, `people-report`,
     `performance-review`, `policy-lookup`, `recruiting-pipeline`
   - `product-management/skills/` — `competitive-brief`,
     `metrics-review`, `product-brainstorming`, `roadmap-update`,
     `sprint-planning`, `stakeholder-update`, `synthesize-research`,
     `write-spec`
   - `customer-support/skills/` — `customer-escalation`,
     `customer-research`, `draft-response`, `kb-article`, `ticket-triage`
   - `partner-built/brand-voice/skills/` — **HIGH RELEVANCE**:
     `brand-voice-enforcement`, `discover-brand`, `guideline-generation`
   - `design/skills/ux-copy` and `research-synthesis`
   - `small-business/{content-strategy,customer-pulse,run-campaign,handle-complaint,job-post-builder,sales-brief}/`
   - SKIP: `bio-research`, `data`, `engineering`, `enterprise-search`,
     `finance`, `legal`, `operations`, `pdf-viewer`, `productivity`,
     `cowork-plugin-management`, `partner-built/{apollo,common-room,slack,zoom-plugin}`

3. **alirezarezvani/claude-skills** (15.5K★, MIT, 2026-05-19) — 313+
   skills. Selectively clone: `video-content-strategist` (YouTube
   channel building, viral short-form, long-to-short), `marketing-strategy-pmm`
   (April Dunford positioning + ICP + battlecards + GTM + launch
   playbooks), `marketing-context` (foundation-context pattern),
   `launch-strategy`, `social-media-manager`, `content-strategy`,
   `content-humanizer`.

4. **mohitagw15856/pm-claude-skills** (804★, MIT) — Extract two
   files only: `strategic-narrative-generator` (roadmap → board-ready
   story arc, useful for inventing a narrative spine when brief is
   vague) and `job-story-mapper` (JTBD framework). Don't clone the
   whole 114-skill repo.

5. **fleurytian/awesome-claude-skills** (275★, MIT) — reference only.
   Has `mckinsey-consultant` (MECE / issue tree / hypothesis-driven
   PPT output) and `mimeng-writing` (Chinese viral copywriting). Read
   the issue-tree pattern; don't clone.

## Already-on-disk overlap

- `agents/anthropic-skills/skills/brand-guidelines` and `internal-comms`
  — already cloned. Don't duplicate.
- `agents/anthropic-skills/skills/frontend-design`, `canvas-design`,
  `theme-factory`, `algorithmic-art` — also cloned.

## Skipped / not worth time

- `JayZeeDesign/awesome-claude-skills` (167★) — already redundant with anthropic-skills.
- `Jeffallan/claude-skills` (9.2K★) — dev-tool skills only, no business interpretation.
- `gouveaero/claude-skills` (0★) — looks like fork of coreyhaines.
- `Dimnas/skill-marketing-psychology` (1★) — content already in coreyhaines.
- `ComposioHQ/awesome-claude-skills` (60.7K★) — awesome-list, no SKILL.md files.
- `karanb192/awesome-claude-skills` (337★) — similar.
- `Mann1988/awesome-claude-skills` (59★) — duplicate content.
- `staruhub/ClaudeSkills` (397★) — no license, mixed dev/utility.
- Anthropic `bio-research/skills/` — single-cell RNA / nextflow / scientific
  instruments. NOT relevant.

## Synthesis — the gap

The ecosystem is strong on text-narrative skills (campaign plans,
positioning docs) and weak on video-specific business interpretation
(TOFU/MOFU/BOFU funnel-stage classifier for video, corporate-HR-comms
video patterns, customer-success-onboarding video patterns).

**Recommended action:** clone the top 5 (or top 4) above. Author our
own thin `fsh-funnel-stage/SKILL.md`, `fsh-corporate-comms-video/SKILL.md`,
`fsh-onboarding-video/SKILL.md` layered on top of the imported brand-voice +
campaign-plan skills.
