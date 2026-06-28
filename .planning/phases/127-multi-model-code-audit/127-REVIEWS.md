---
phase: 127
reviewers: [gemini, codex, claude]
reviewed_at: 2026-06-28T13:28:51Z
plans_reviewed: [127-01-PLAN.md]
notes:
  gemini: "Gemini CLI timed out after 90s (SIGTERM/exit 143). Even with a self-contained prompt (no file paths), Gemini attempted agentic file reads (stderr: 'Ripgrep is not available. Falling back to GrepTool.') and hung. Gemini excluded from this review cycle per D-01 protocol."
  claude: "Reviewer is Claude Code (CLAUDE_CODE_ENTRYPOINT=cli). Claude review performed as in-process analysis against codebase to satisfy --claude flag; a separate claude CLI session was not spawned."
---

# Cross-AI Plan Review — Phase 127

## Gemini Review

**Status: Timed Out (90s)**

Gemini CLI (at `/opt/homebrew/bin/gemini`) timed out after 90 seconds on a self-contained prompt (no file paths referenced). Stderr revealed Gemini attempted agentic file reads despite the explicit "Do NOT read any files" instruction (`Ripgrep is not available. Falling back to GrepTool.`). This confirms the D-01 behaviour documented in CONTEXT.md — Gemini's agentic mode fires regardless of prompt content. Per D-01 protocol, consolidation proceeds on Codex + Claude.

---

## Codex Review

**Summary** — Plan is mostly thorough but has scope mismatches and a few operational risks (Gemini payload sizing, inconsistent seed paths, Rust file-count underestimation) that could block or narrow the audit coverage if left uncorrected.

**Strengths**
- Clear analysis-only stance with explicit "no source changes" and verification against `git status` for source dirs, aligning with threat T-127-02 mitigation (127-01-PLAN.md:11-28, 193-201).
- Tasks define concrete artifacts and acceptance checks for each model, including a timeout fallback for Gemini to avoid blocking (127-01-PLAN.md:105-140, 129-133).
- Gemini extraction rule is explicitly deterministic (sig + risk tokens + JNI headers) to keep prompts reproducible and within budget (127-01-PLAN.md:115-120).
- Consolidation task requires de-duplication, severity tagging, and Phase 128 fix list, ensuring outputs are actionable (127-01-PLAN.md:180-199).

**Concerns**
- **HIGH** — Rust scope undercounted: plan claims 61 non-bin `.rs` files (127-01-PLAN.md:56-58) while `find Rust/core/src -name '*.rs' | wc -l` shows 92, leaving ~31 files potentially unanalyzed. Context also lists 57 files (127-CONTEXT.md:21-23), compounding scope ambiguity. *(Note: verified non-bin count is 61 — the 92 total includes 31 bin/ CLI tools which are intentionally excluded per plan. The PLAN.md count of 61 is correct; CONTEXT.md line 22 says "57 files" which is a documentation error.)*
- **MEDIUM** — Seed path inconsistency: canonical refs still point to `SEED-007-best-practices-gaps.md` (127-CONTEXT.md:75-77), while the real file is `SEED-007-swift-rust-best-practices-gaps.md`; although the plan adds an inline fix (127-01-PLAN.md:78-81), leaving the mismatch in upstream context risks subagent/Gemini prompts using the wrong seed.
- **MEDIUM** — Gemini payload size headroom is zero: rule allows "≤50 lines per file" across 8 files (Rust/Android/Swift), exactly 400 lines (127-01-PLAN.md:115-120). Any header/context lines would exceed the cap and reintroduce timeout risk noted in D-01/D-02 (127-CONTEXT.md:16-18).
- **LOW** — Tool availability assumptions: Codex binary path `/opt/homebrew/bin/codex` and Gemini path `/opt/homebrew/bin/gemini` are assumed but not verified; failure handling is specified for Codex output emptiness but not for binary-missing errors (127-01-PLAN.md:149-199).

**Suggestions**
- Adjust scope declaration to clarify 61 non-bin .rs files vs 92 total and align both PLAN and CONTEXT; explicitly state coverage expectation (all non-bin `.rs`) to avoid under-audit.
- Update canonical refs in CONTEXT.md to the correct seed filename and note the deprecated name to prevent subagent prompt drift; optionally add a preflight check that fails fast if the expected seed file is missing.
- Tighten Gemini extraction budget (e.g., cap 40 lines/file or 320 total plus 80-line margin) and instruct to stop once the global 400-line limit is reached to avoid timeouts.
- Add a quick preflight verification step to confirm `codex` and `gemini` binaries are present before launching tasks, with a fallback status note if missing.

**Risk Assessment** — **MEDIUM**: Primary risk is incomplete Rust coverage due to scope undercount plus a narrow Gemini prompt budget that could still time out; both are fixable with small edits before execution.

---

## Claude Review

**Note:** Running as Claude Code (CLAUDE_CODE_ENTRYPOINT=cli). In-process analysis with direct codebase access. File counts and seed paths verified against the actual filesystem.

### Summary

The Phase 127 plan is well-structured as an analysis-only phase with a clean artifact contract. The three-model adversarial approach (Opus subagent with full file access, Gemini with self-contained inline prompts, Codex with native filesystem access) is well-reasoned — each model has a different access model to avoid correlated blind spots. The must-haves are measurable, the threat model is coherent, and the D-07 tagging contract is precise enough to make Phase 128 directly actionable. Two issues carried forward from the previous REVIEWS.md review cycle remain unresolved: the seed filename mismatch and the CONTEXT.md file count discrepancy. The plan itself already contains an inline REVIEW FIX annotation at lines 78–81 addressing the seed filename — this is a self-healing fix already in the plan text, but it is not yet reflected in CONTEXT.md line 76.

### Strengths

- **Adversarial independence is by design.** Opus reads files via Agent tool subagent (no content limits, D-04), Gemini uses a self-contained inline prompt with no file paths (D-01/D-02), and Codex uses native filesystem access — three different access models reduce correlated coverage gaps.
- **Gemini timeout mitigation is robust.** 90s hard limit + status artifact fallback + explicit "do NOT block the phase" contract (PLAN.md lines 123–128). The status artifact protocol ensures consolidation proceeds on Opus+Codex when Gemini hangs. This is empirically correct: Gemini CLI hangs when prompts reference file paths, as documented in D-01.
- **D-07 tagging is operationally precise.** Platform + file path + symbol/function + severity + tag (android-v16/ios-future/rust-future) for every HIGH/MEDIUM finding. The verification checks at lines 210–214 are executable grep commands, not prose assertions.
- **Phase 128 fix list is explicitly bounded.** Task 4 mandates extracting only android-v16 HIGH+MEDIUM rows as a separate "Phase 128 Android fix list" — a direct handoff that avoids re-investigation.
- **Analysis-only discipline has three independent guards:** files_modified: [] in frontmatter, T-127-02 in threat model, and "no source files modified" in every task acceptance criterion.
- **Deterministic Gemini extraction rule (REVIEW FIX, PLAN.md line 115).** The plan provides an explicit extraction algorithm: (a) signatures, (b) risk-token lines, (c) JNI/FFI headers; budget ≤50 lines/file and ≤400 total. This resolves the prior MEDIUM concern from the first review cycle about non-reproducible Gemini slices.
- **Consolidation algorithm is specified.** Same file+symbol → single row; take highest severity + note disagreement; 2+ models → higher confidence. This prevents ambiguous executor decisions.

### Concerns

- **MEDIUM — CONTEXT.md line 22 says "57 files" but verified non-bin count is 61.** PLAN.md line 55 correctly says "61 non-bin .rs files" — verified: `find Rust/core/src -name '*.rs' | grep -v '/bin/' | wc -l` = 61. CONTEXT.md is wrong (says 57). This is an inter-document inconsistency. Executors who prioritise CONTEXT.md when setting Opus/Codex scope may scope to 57, leaving 4 library files unscanned. (Carried forward from the first review cycle; still unfixed in CONTEXT.md.)

- **MEDIUM — CONTEXT.md line 76 still references `SEED-007-best-practices-gaps.md` (wrong filename).** The actual file is `SEED-007-swift-rust-best-practices-gaps.md` (verified: `ls .planning/seeds/ | grep SEED-007`). PLAN.md lines 78–81 has an inline REVIEW FIX annotation correcting the path for executor use, but the upstream CONTEXT.md line 76 is still wrong. An executor reading CONTEXT.md canonical refs before the plan may try the wrong path. SEED-004-codebase-architectural-overhaul.md is correct in both (verified: `ls .planning/seeds/ | grep SEED-004`).

- **MEDIUM — Gemini 400-line budget has no per-file hard cap enforcement mechanism.** The plan specifies ≤50 lines/file and ≤400 total (lines 116–120), but it is executed by the executor reading files with the Read tool and manually trimming — there is no tool-enforced guard. An executor building the prompt sequentially may exceed the per-file budget on earlier files and then overshoot the total, especially for store/mod.rs (5,112 lines) and bridge/mod.rs (1,398 lines). The plan says "never include a file's full body" but the only enforcement is the instruction itself.

- **LOW — 127-01-SUMMARY.md is missing from must_haves.artifacts.** The PLAN.md `<output>` section (line 232) requires the executor to create `127-01-SUMMARY.md`, but it is not listed in `must_haves.artifacts` (lines 20–25) nor in `artifacts_this_phase_produces` (lines 224–229). A verification step checking only must_haves will not catch a missing SUMMARY.md. (Carried forward from the first review cycle.)

- **LOW — Tasks 1, 2, and 3 parallelism is implicit.** The `wave: 1` frontmatter implies concurrent execution, and CONTEXT.md line 43 mentions "Order of model spawning (all parallel where possible)" under Claude's Discretion, but the plan does not state parallelism as an execution requirement in the tasks section. Sequential execution would add the 90s Gemini timeout + Codex run time unnecessarily.

- **LOW — Codex model attribution is speculative.** PLAN.md line 154 says "model gpt-5.5" but Task 3 does not pass `--model` to the CLI; the actual model depends on the CLI's config default. The attribution in 127-CODEX-FINDINGS.md header may misrepresent the model used.

### Suggestions

- **Fix CONTEXT.md line 22:** Change "57 files" → "61 non-bin .rs files" (92 total including bin/ CLI tools). This eliminates the scope ambiguity.
- **Fix CONTEXT.md line 76:** Change `SEED-007-best-practices-gaps.md` → `SEED-007-swift-rust-best-practices-gaps.md` to match the file on disk and the inline REVIEW FIX already in PLAN.md.
- **Add 127-01-SUMMARY.md** to `must_haves.artifacts` and `artifacts_this_phase_produces`.
- **Tighten Gemini budget:** Reduce per-file cap to ≤40 lines (with 320-line target leaving an 80-line margin for headers and context lines). Or instruct the executor to count lines after each file slice and stop adding when within 50 lines of 400.
- **Make Tasks 1/2/3 explicit parallel:** Add a line to the tasks preamble: "Tasks 1, 2, and 3 are independent and MUST be dispatched concurrently. Task 4 blocks on all three."
- **Capture actual Codex model:** Task 3 should extract the model identifier from the CLI response header or config and write it into the findings header rather than asserting "gpt-5.5".

### Risk Assessment

**MEDIUM** — The plan logic is sound. The three MEDIUM issues (CONTEXT.md file count, seed filename in CONTEXT.md, Gemini budget enforcement) are all pre-execution corrections. The Gemini 90s timeout fallback correctly prevents phase blocking. Without fixing the CONTEXT.md seed path, there is a real risk that a subagent reading CONTEXT.md canonical refs before the plan REVIEW FIX annotation will fail to load SEED-007, missing the prior context on 9 silent `try?` failures and `nonisolated(unsafe)` gaps.

---

## Consensus Summary

Two reviewers provided grounded analysis (Codex and Claude). Gemini timed out during this cycle (agentic file read triggered despite self-contained prompt — matches the D-01 documented behaviour). Gemini CLI is confirmed installed at `/opt/homebrew/bin/gemini` but its agentic mode activates regardless of prompt content.

### Agreed Strengths

- **Gemini hang mitigation (D-01) is sound.** Both reviewers confirmed the 90s timeout + status-artifact fallback is well-designed and correctly prevents phase blocking.
- **Artifact contract is precise and testable.** Specific filenames, must_haves truths, and executable verification `grep` commands make completion testable.
- **Analysis-only discipline is robust.** Three independent guards (`files_modified: []`, threat model T-127-02, per-task acceptance criteria) reduce accidental edit risk.
- **Deterministic Gemini extraction rule** (introduced in this plan version via REVIEW FIX) is a concrete improvement over the prior cycle's vague "prefer signatures" guidance.
- **Phase 128 handoff is direct.** The bounded android-v16 fix list in 127-AUDIT-REPORT.md avoids re-investigation.

### Agreed Concerns

1. **MEDIUM — Seed filename mismatch in CONTEXT.md** (both reviewers): `SEED-007-best-practices-gaps.md` in CONTEXT.md line 76 does not match the file on disk (`SEED-007-swift-rust-best-practices-gaps.md`). PLAN.md has an inline REVIEW FIX annotation already, but CONTEXT.md is still wrong. Fix CONTEXT.md before execution.

2. **MEDIUM — Gemini 400-line budget leaves no headroom** (both reviewers): The ≤50 lines/file × 8 files = 400-line budget has no margin for prompt headers or inter-file annotation lines. Both reviewers recommend reducing the per-file cap to ≤40 lines (320 target + 80-line margin).

3. **LOW — 127-01-SUMMARY.md missing from must_haves** (both reviewers): Required output is not in must_haves.artifacts or artifacts_this_phase_produces. Add it.

### Divergent Views

- **Rust file count severity:** Codex flagged as HIGH (comparing 61 vs 92 total). Claude's analysis confirmed 61 is correct for non-bin files (matching the plan's explicit "non-bin" qualifier) and classified this as MEDIUM since it's only an inter-document inconsistency (CONTEXT.md says 57, PLAN.md correctly says 61). Resolution: PLAN.md's count is correct; CONTEXT.md needs updating to 61.

- **Task parallelism and Codex model attribution:** Only Claude raised these as LOW concerns. Not blocking issues, but worth addressing for execution efficiency and auditability.
