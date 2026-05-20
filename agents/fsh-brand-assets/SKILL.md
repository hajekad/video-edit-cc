---
name: fsh-brand-assets
description: Pull official brand assets (logos, colors, voice guidelines) from a brand's official press / media page. WebFetch-based, audit-trail preserving. Used during /inventory's automatic-research pass when a brand is identified from the footage. Never uses generic image search.
version: 1.0.0
---

# Brand Asset Retrieval — Official Sources Only

When the agent identifies a brand from footage (visible logo, branded
PPE, name patches, transcript mention), this skill pulls the brand's
official media kit. Used in the `/inventory` automatic-research pass.

> Reference case: smoke test #1 needed a reprompt to pull the ORLEN
> logo. Without this skill, the agent either skipped brand assets or
> grabbed something from Google Images — both fail audit. With this
> skill, the agent reaches the official press page directly and saves
> the URL alongside the asset for provenance.

## Aggressive fetch workflow — try hard before falling through

The agent's job is to land the brand mark autonomously. Filing a
Capability issue and dropping a scaffold is the LAST resort, not the
second move. The full fetch chain is:

### Step 1 — Resolve the press page

Try in order until one returns HTTP 200 with content > 1 KB:

1. `<brand-domain>/media`
2. `<brand-domain>/press`
3. `<brand-domain>/en/media` / `<brand-domain>/cs/media` (locale-aware)
4. `<brand-domain>/about/media` / `<brand-domain>/about-the-company/media`
5. `<brand-domain>/newsroom`
6. `<brand-domain>/brand-guidelines`
7. `<brand-domain>/en/about-the-company/media/press-pack`
8. `<brand-parent-corp-domain>/...` for subsidiary brands

### Step 2 — Parse the resolved page

Don't stop at "page loaded but no obvious download link." Modern
corporate sites embed the brand mark inline. Extract candidate URLs
with:

```bash
# Direct image asset references from the rendered HTML
grep -oE 'src="[^"]+\.(svg|png|jpg)"' page.html | sort -u
grep -oE 'href="[^"]+\.(svg|png|pdf|zip|ai)"' page.html | sort -u

# Inline backgrounds in CSS / inline styles
grep -oE 'background-image:\s*url\([^)]+\)' page.html
```

The brand mark is often hosted on the company's own CDN under a path
like `/content/.../coreimg.png` or `/sites/default/files/brand/logo.svg`.
That's NOT an aggregator — it's the brand's canonical CDN.

### Step 3 — Pick the right candidate

Heuristics to identify the canonical brand mark among the page's image
references:

- URL contains "logo", "brand", "wordmark", "mark", "lockup", or the
  brand name itself
- Image is reasonably small (< 200 KB) — full brand campaigns or hero
  shots are typically larger
- Image is square-ish or wider — letter-grid logos are typically not
  tall portrait
- Path is under the brand's own domain (not an aggregator)

Pull 2-3 candidates with `curl`. Probe with `identify`. Pick the one
whose visual matches "this is the brand mark" (square format with the
mark, color matches brand guidelines if known).

### Step 4 — Try the parent corporation if needed

If the subsidiary (e.g. `orlenunipetrol.cz`) doesn't surface the
canonical mark, try the parent (`orlen.pl`). For multinationals,
also try `<brand>.com` regardless of the subsidiary's TLD.

### Step 5 — ONLY now: dropin-scaffold

If Steps 1-4 all fail (no resolvable press page, no parsed image
candidates, no parent-corp source either), then:

```bash
/opt/claude-config/tools/dropin-scaffold "$SLUG" logo \
  --sources "<all the URLs you tried>" \
  --notes "Brand identified as <name>. Press-page fetch failed: <reason>."
```

Document in `docs/issues/brand-asset-fetch-failed.md` the SPECIFIC
URLs tried and what each returned. Don't ship a vague "couldn't find
the logo."

**Never use Google Images, Wikipedia, Wikimedia Commons, or third-party
logo aggregators** (logosearch, brandfetch, seeklogo, etc.) as the
canonical source. These can carry outdated or unauthorized variants.
The brand's own CDN — even when reached via parsing the press page's
HTML — IS the canonical source.

## What to fetch

For each identified brand, save to `/work/<id>/brand/`:

| File | Source | Notes |
|---|---|---|
| `logo.svg` (or `.png` fallback) | Press kit's primary download | Prefer SVG; fall back to highest-res PNG |
| `logo_mono.svg` | If brand has a single-color version | Useful for overlays on busy footage |
| `colors.json` | Brand guidelines page | `{primary: "#ED1C24", secondary: "#000000", neutrals: [...]}` |
| `typography.json` | Brand guidelines page | `{primary_face: "...", secondary_face: "...", fallback: "..."}` |
| `voice.md` | Brand guidelines page | Tone keywords, do/don't phrases |
| `source.md` | Auto-generated | URL of every fetch + ISO timestamp |

The `source.md` audit file is non-negotiable. It lists every URL the
agent visited, what it pulled from each, and when. Without it, the
marketing team can't verify the asset provenance.

## Skill output

Updates `manifest.brand` with the structured result:

```json
{
  "brand": {
    "name": "ORLEN Unipetrol",
    "parent_brand": "ORLEN",
    "official_press_url": "https://www.unipetrol.cz/en/media",
    "logo_path": "/work/<id>/brand/logo.svg",
    "logo_mono_path": "/work/<id>/brand/logo_mono.svg",
    "primary_color": "#ED1C24",
    "secondary_color": "#000000",
    "voice": "industrial / technical / sustainability-forward",
    "source_audit": "/work/<id>/brand/source.md"
  }
}
```

## Architecture

The skill is a single Python module
`agents/fsh-brand-assets/fetch.py` that exposes:

```python
def fetch_brand(brand_name: str, hint_domain: str = None, work_dir: Path = None) -> BrandKit:
    """Resolve the brand's official press URL, download the assets,
    populate /work/<id>/brand/, return a BrandKit dataclass.

    Tries common press-page URL patterns. Uses WebFetch (claude tool)
    to read the page, then a follow-up WebFetch per asset URL.

    Saves source.md as it goes — every URL visited, every asset
    pulled, every timestamp.
    """
```

## When the autonomous fetch is blocked

Two reasons it can happen:

1. **Classifier denial** — the agent's WebFetch / Bash tools refuse the
   fetch even after rephrasing. Common in early-session sandboxes.
2. **Official press page not resolvable** — none of the common URL
   patterns return a usable kit.

In either case, **do not** substitute a Google grab, a Wikimedia
upload, or a third-party logo aggregator. Instead, generate a drop-in
scaffold so the user can supply the official asset in one file move:

```bash
/opt/claude-config/tools/dropin-scaffold "<slug>" logo \
  --sources "<brand-domain>/media,<brand-domain>/press,<brand-parent-corp>/about/media" \
  --notes "Brand identified as <name>. Logo overlay used on close card last 1.5s."
```

That creates:
- `/assets/<id>/branding/README.md` listing the candidate URLs + drop path
- `/work/<slug>/edit/add_logo.py` merge script template
- `manifest.logo.pending_dropin = true`

The agent then continues with everything else (renders all variants
the logo isn't required for; bakes the merge step so a single command
applies the logo when the file lands).

Also file a `Capability` issue:

```markdown
---
type: Capability
status: investigating
brand: <inferred brand name>
hint_domain: <inferred domain or null>
why: official press page not autonomously fetchable
---

Tried:
- <url-1>: <result>
- <url-2>: <result>
...

Drop-in scaffold staged at /assets/<id>/branding/. Two unblock paths:
authorize a specific URL, or drop the file directly.
```

See `/docs/DROPIN_SCAFFOLD_PATTERN.md` for the canonical pattern.

## Cross-references

- `/docs/BRIEF_INTERPRETATION.md` — the automatic-research pass calls
  this skill during /inventory
- `agents/fsh-music-mood-bridge/personas.yaml` — persona's
  `brand_voice` field aligns with this skill's `voice.md`
- `agents/brand-guidelines/` (Anthropic skills) — broader brand-intake
  guidance, complementary

## Pitfalls

- **Logo at wrong aspect.** Press kits often ship multiple variants
  (horizontal lockup, square, monogram). Pick the right one for the
  overlay context: square for vertical Reels lower-third, horizontal
  for landscape end-card.
- **Color profile mismatch.** Brand guidelines list sRGB / CMYK
  variants. Always pick sRGB for video.
- **Trademark / usage restrictions.** Some press kits restrict use to
  editorial vs commercial. Save the usage terms link in `source.md`.
- **Cached / outdated assets.** If `source.md` shows the last fetch
  was > 90 days ago, re-fetch before delivery.
