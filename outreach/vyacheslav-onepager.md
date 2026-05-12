# agent-coherence — Vyacheslav one-pager

> **STATUS: DRAFT — NOT FOR PUBLICATION**
> **Target send date:** post-Phase-1 discovery (after 2026-05-16)
> **Target poster:** Eric Vyacheslav (LinkedIn, ~mid-six-figure followers)
> **Pre-send gate:** ≥3 completed discovery calls with quotable engineer feedback. Replace the placeholder quote in the post body with a real one.

---

## 1. The LinkedIn post (ready to paste)

> The hard part of multi-agent systems isn't getting agents to do work.
>
> It's getting them to agree on what just changed.
>
> Agent A writes v3 of a shared plan.
> Agent B still has v2 cached.
> B reads, reasons over stale state, writes back — and now v3 is overwritten by logic that didn't know v3 existed.
>
> MLflow's multi-agent observability team has a name for this:
> **shared memory pollution.** One agent's hallucination becomes a "fact" the next one reasons from. Trace-only tools (LangSmith, Braintrust) can show you the calls. They can't tell you the read was stale.
>
> I've been building `agent-coherence` — an MESI-derived cache-coherence protocol adapted from CPU memory systems, for LLM agents that share mutable artifacts.
>
> What it does:
> → detects stale reads at the moment they happen
> → serves the fresh version on the next read instead of rebroadcasting the full artifact (~12-token invalidation vs hundreds of tokens of context)
> → enforces single-writer ordering when one agent commits
> → drop-in adapters for LangGraph, CrewAI, AutoGen, and any custom orchestrator
> → vendor-neutral: same protocol with Anthropic, OpenAI, Google, Mistral, open-source models
>
> Two coherence problems, one ecosystem:
> • **Read-side freshness** (RAG, incremental index pipelines, CocoIndex) keeps agents fresh on external sources of truth.
> • **Write-side coherence** (this) keeps agents consistent with each other when they collaborate on the same artifact.
>
> You need both.
>
> 32% of agent teams cite quality — verbatim "hallucinations and consistency of outputs" — as their #1 production blocker (LangChain, State of Agent Engineering 2026). agent-coherence addresses the consistency half.
>
> Apache-2.0, 165 tests, TLA+/TLC model-checked safety properties, PEP 740 supply-chain attestations.
>
> GitHub: https://github.com/hipvlady/agent-coherence
> Site: https://agent-coherence.dev
> Paper: https://arxiv.org/abs/2603.15183
>
> What's the worst multi-agent failure mode you've hit that observability tools didn't catch?
>
> [INSERT REAL ENGINEER QUOTE FROM DISCOVERY CALLS HERE BEFORE SENDING]

**Word count:** ~270 words. LinkedIn shows ~210 chars before "see more" — first 2 lines must hook.

---

## 2. Diagram (for the LinkedIn image slot)

When posted, attach a clean image of this concept. Two options:

**Option A — failure mode (no coherence):**

```
  Agent A ────[ writes v3 ]──┐
                             ▼
                       ┌─ plan.md ─┐
                       │  v2 → v3  │   (rebroadcast or no protocol)
                       └───────────┘
                             ▲
  Agent B ──[ reads v2 ]─────┘
       │
       └─[ writes back overwriting v3 ]──► plan.md is now v2-derived again

  Trace tool: ✓ A wrote   ✓ B read   ✓ B wrote
  Reality:    A's v3 is lost. Nobody told B.
```

**Option B — with coherence:**

```
  Agent A ──[ writes v3 ]──► Coordinator
                                 │
                                 ├──► invalidates B's cache (~12 tokens)
                                 │
  Agent B ──[ next read ]────────┴──► serves v3
                                       │
       Agent B reasons over fresh state, writes v4 ─► Coordinator
```

Format these as a clean dark-themed image (~1200×675px), match the site's accent (#5eead4) and OG image style. Don't ship the post without the image — LinkedIn engagement on text-only posts is meaningfully lower.

---

## 3. Two-line elevator summary (for DMs / paper abstracts / cold emails)

> agent-coherence detects stale reads in multi-agent LLM systems and serves the fresh version on the next read instead of rebroadcasting the full artifact every turn. Drop-in for LangGraph, CrewAI, AutoGen — vendor-neutral across Anthropic, OpenAI, Google, Mistral, and open-source models; Apache-2.0; arXiv 2603.15183.

---

## 4. Short-form variant (if Vyacheslav posts as a quote-tweet / X thread)

```
Most "multi-agent observability" tools show you what each agent did.

They don't show you when one of them was wrong because it read stale
state from another.

agent-coherence: MESI cache coherence — for LLM agents that share
mutable artifacts.

→ stale reads detected, not just traced
→ ~12-token invalidations vs full rebroadcast
→ LangGraph, CrewAI, AutoGen, custom — Apache-2.0
→ vendor-neutral across all major model providers

github.com/hipvlady/agent-coherence
```

~440 chars. Fits a tweet thread head or a LinkedIn quote-share.

---

## 5. Speaker notes — for briefing Vyacheslav (if you get a call)

**The single line he should walk away with:**
> "Read-side freshness keeps agents fresh on the world. Write-side coherence keeps agents consistent with each other. Different problems, both needed."

**Why this matters now (the timing argument):**
- LangChain's 2026 report says 57% of orgs have agents in production; 32% cite quality (consistency/hallucinations) as the #1 blocker.
- Frameworks have admitted the gap in their own docs (LangGraph BaseStore: "does not natively support optimistic locking, vector versioning, or invalidation protocols").
- Deep Agents Issue #96 is the public smoking gun — concurrent writes crashed production; LangChain's fix was an append-only reducer, which prevents the crash but not the divergence.

**What he should NOT say:**
- "Replaces LangSmith." It doesn't. LangSmith shows what happened; agent-coherence prevents the underlying bug class.
- "Solves hallucinations." It doesn't. It prevents one well-defined sub-class — stale-read-driven cascades — from compounding.
- "10x performance." The 29–69% token savings is workload-dependent (read/write ratio). Quote the table, not the peak.

**What's quotable from him would help us most:**
- A line about why coherence is a *category*, not a feature of any one framework.
- His take on the read-side / write-side split.
- A nudge toward the 10k+-employee org segment that LangChain's data already highlights.

---

## 6. Pre-send checklist

- [ ] ≥3 discovery calls completed; one quotable line captured to replace the `[INSERT…]` placeholder
- [ ] Vyacheslav warmed up (1–2 prior interactions on LinkedIn: thoughtful reply on his CocoIndex post, a relevant DM)
- [ ] Diagram exported as image, accent color matches site
- [ ] Repo README intro paragraph matches the post's framing word-for-word (so a click-through doesn't break the spell)
- [ ] PyPI page description updated with the new positioning
- [ ] GitHub Discussions seeded with 2–3 "starter" threads so cold inbound has something to land on
- [ ] Backup plan if he doesn't post: same content drops as a Show HN, plus a personal LinkedIn post from you

---

## 7. What success looks like — and what to ignore

**Lagging signal that matters:** discovery-call requests via cal.com with GA `cta_target=cal` from `linkedin` source. That's the conversion.

**Lagging signals that don't matter much:** GitHub stars, LinkedIn likes, total clicks. They go up; they don't validate the wedge. (See: the brainstorm's "5 calls is insufficient signal" principle — same applies in reverse to vanity metrics.)

**Off-ramp:** if the post lands but produces 0 cal bookings in the following week, the wedge isn't matching the audience — that's a discovery signal worth more than a thousand stars.
