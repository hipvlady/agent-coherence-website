# UTM scheme — agent-coherence.dev

Single source of truth for outbound links. Every time the site is linked
from anywhere external, attach UTM parameters from this file. GA4 will
record the source, and you'll see end-to-end attribution from channel →
visit → cal.com booking.

## Convention

```
https://agent-coherence.dev/?utm_source={source}&utm_medium={medium}&utm_campaign={campaign}
```

Lowercase. No spaces. Use hyphens, not underscores, inside campaign names.

## Standard channel matrix

| Channel | utm_source | utm_medium | utm_campaign (example) |
|---|---|---|---|
| LinkedIn organic post | `linkedin` | `social` | `langsmith-wedge`, `mesi-explainer` |
| LinkedIn paid (Insight Tag) | `linkedin` | `paid` | `discovery-q2` |
| X / Twitter organic | `x` | `social` | `stale-read-thread` |
| X / Twitter promoted | `x` | `paid` | `copy-test-2026q2` |
| Hacker News Show HN | `hn` | `community` | `show-hn-launch` |
| Hacker News comment | `hn` | `community` | `lggraph-issue-comment` |
| Reddit r/LangChain | `reddit` | `community` | `langgraph-{thread-id}` |
| Reddit r/LocalLLaMA | `reddit` | `community` | `localllama-coherence` |
| Reddit DM (outreach) | `reddit` | `dm` | `discovery-radar` |
| Reddit promoted post | `reddit` | `paid` | `copy-test-2026q2` |
| arXiv paper landing | `arxiv` | `paper` | `2603-15183` |
| LangChain Slack | `langchain` | `community` | `discovery` |
| Discord (any AI dev community) | `discord` | `community` | `{server-name}` |
| Email signature | `email` | `signature` | `personal` |
| Conference talk slides | `conference` | `talk` | `{event-name-year}` |
| Newsletter mention | `newsletter` | `referral` | `{newsletter-slug}` |
| Direct DM (cold outreach) | `outreach` | `dm` | `discovery-radar` |
| GitHub README badge | `github` | `readme` | `agent-coherence-repo` |
| PyPI project description | `pypi` | `package` | `agent-coherence` |

## Worked examples

LinkedIn post launching the new positioning:
```
https://agent-coherence.dev/?utm_source=linkedin&utm_medium=social&utm_campaign=stale-read-launch
```

Reddit DM to a discovery lead:
```
https://agent-coherence.dev/?utm_source=reddit&utm_medium=dm&utm_campaign=discovery-radar
```

Show HN post:
```
https://agent-coherence.dev/?utm_source=hn&utm_medium=community&utm_campaign=show-hn-launch
```

Paid Reddit promoted post (the $20 test from earlier discussion):
```
https://agent-coherence.dev/?utm_source=reddit&utm_medium=paid&utm_campaign=copy-test-2026q2
```

## On-site CTA UTMs (already wired)

These are set on outbound links from the site itself, so cal.com sees
where on the page the click came from. Do not change them ad hoc.

| Surface | Outbound URL |
|---|---|
| Header CTA | `cal.com/agent-coherence?utm_source=agent-coherence.dev&utm_medium=cta_header&utm_campaign=launch` |
| Hero "Book a 15-min call" | `...&utm_medium=cta_hero&utm_campaign=launch` |
| Bottom CTA strip | `...&utm_medium=cta_bottom&utm_campaign=launch` |

## Events emitted in GA4 (Path B analytics)

The site `gtag.js` config emits these events. Use these as conversion
definitions in GA4 → Admin → Events → Mark as conversion.

| Event name | Parameters | Mark as conversion? |
|---|---|---|
| `cta_click` | `cta_target` (`cal`/`github`/`arxiv`/`pypi`/`discussions`/`email`), `cta_location` (`header`/`hero`/`bottom`/`footer`), `cta_text` | only when `cta_target=cal` |
| `pip_install_copied` | `snippet` | yes — strongest intent signal short of cal booking |
| `scroll_milestone` | `percent` (25/50/75/100) | no — engagement metric |
| `faq_open` | `question` (first 80 chars) | no — engagement metric |

Cross-domain measurement (`linker`) is configured for `cal.com`, so a
booking on cal.com inherits the same client ID as the originating site
visit. Use `Event > cta_click (cta_target=cal)` as the canonical lead
conversion in GA4.

## Ground-truth metrics (when GA shows nothing)

Tracker blocking on engineering audiences runs 40–60%. Always
cross-reference these:

- cal.com bookings (cal.com → Insights, has its own UTM read)
- GitHub stars (https://github.com/hipvlady/agent-coherence)
- PyPI downloads (https://pepy.tech/project/agent-coherence)
- Discord/Slack mentions (search manually weekly)

If GA4 says "0 sessions" but cal bookings exist, the campaign is
working — the engineers just block tracking. Trust the booking number.

## Migration to full GTM (if/when LinkedIn ads)

Current setup uses gtag.js directly (works fine for the events above).
Migrate to Google Tag Manager when you need:

- LinkedIn Insight Tag (paid LinkedIn ads conversion tracking)
- Microsoft Clarity (heatmaps / session replay)
- Server-side tagging (resilience against blockers)
- Multiple tags managed without redeploying the site

Steps when ready:
1. Create a GTM container at https://tagmanager.google.com → get `GTM-XXXXXXX`
2. Replace the gtag.js snippet in `<head>` with the GTM container snippet
3. Move the GA4 config from inline JS into a GTM tag
4. Republish.

The data-cta-target / data-cta-location attributes are GTM-friendly — a
single Custom Event trigger in GTM can read them via DOM scraping, no
HTML changes needed.
