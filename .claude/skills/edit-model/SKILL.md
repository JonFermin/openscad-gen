---
name: edit-model
description: Review and fix an existing 3D model using the reviewer/fixer agent team. Catches positioning errors, proportion issues, and misaligned geometry in both the manifest and source file.
user_invocable: true
---

# edit-model: Review & Fix Existing 3D Models

## Flags

- **`--verbose`** (default: **on**) — Narrate each review/fix pass: show the screenshot, explain what the reviewer found, describe the fixer's changes. Pass `--quiet` to suppress iteration narration and only present the final result.
- **`--manifest-only`** — Only fix the manifest JSON, don't touch the source `.py`/`.scad` file.

---

Run the reviewer → fixer agent loop on an **existing** model to catch and correct issues
with positioning, proportions, orientation, and feature completeness.

Unlike the `make-model` skill which generates from scratch, this skill
operates on models that already exist in `./output/` and applies targeted fixes.

---

## Phase 1: Identify the Target Model

Determine which model to review. The user may specify:
- A filename: `edit-model street_intersection`
- A description: "review the street intersection"
- Nothing: ask which model to review, or if only one model exists, use that

Locate both files:
- **Source file:** `./output/<name>.py` or `./output/<name>.scad`
- **Manifest file:** `./output/<name>_manifest.json`

If the manifest is missing, tell the user to generate it first (via `/make-model`).

---

## Phase 2: Gather Context

Before spawning the reviewer, prepare the context it needs:

1. **Read the source file** — understand what the model is supposed to be
2. **Read the manifest** — this is what the reviewer will evaluate
3. **Infer the spec** — from the source file's docstring, comments, and structure, reconstruct
   what the model represents. If the user provides additional context about what's wrong, include that.

---

## Phase 3: Review & Fix Loop (Agent Team)

### Step 1: Ensure previewer is running

If not already started in this session, run in the background:

```bash
cd previewer && npm run dev
```

The previewer persists across iterations — no need to restart.

### Step 2: Spawn the reviewer agent

Use the Agent tool with `subagent_type: "review-model"` and provide:

```
Review the model preview against this spec.

**Original spec:** <reconstructed spec from source file + any user context about what's wrong>

**Manifest file:** output/<name>_manifest.json

**Manifest content:**
<paste the full manifest JSON>
```

The reviewer will:
1. Analyze the manifest for red flags (inverted rotations, bad Y-positions, missing parts)
2. Navigate to the preview and take a screenshot
3. Evaluate against a 6-point checklist (orientation, shape, proportions, completeness, positioning, plausibility)
4. Return a structured PASS/FAIL verdict with specific issues and suggested fixes

### Step 3: If PASS → proceed to Phase 4

### Step 4: If FAIL → spawn the fixer agent

Use the Agent tool with `subagent_type: "fix-model"` and provide:

```
Fix the following issues found by the reviewer.

**Reviewer's issues:**
<paste the reviewer's full issues list and suggested fixes>

**Manifest file:** output/<name>_manifest.json
**Source file:** output/<name>.py (or .scad)

IMPORTANT: Fix BOTH the manifest AND the source file to keep them in sync.
The source file is the ground truth — if the reviewer found positioning/sizing issues,
the root cause is likely in the source file's coordinate math. Fix the source first,
then update the manifest to match.
```

The fixer will:
1. Read both files and locate the broken parts
2. Apply targeted, surgical edits to both the source and manifest
3. Return a summary of exactly what changed and why

### Step 5: Re-review after fix

After the fixer completes, spawn the reviewer agent again with the updated manifest.
This ensures the fix actually worked and didn't introduce new issues.

### Loop control

- Maximum **3 review cycles** (review → fix → re-review counts as one cycle)
- If still failing after 3 cycles, present the result to the user with a note about
  what the reviewer is still flagging so they can decide how to proceed.

### Troubleshooting:
- **Screenshot shows empty state ("No manifest loaded"):** Verify the manifest file exists and the filename in the URL matches exactly.
- **Connection refused:** The previewer isn't running. Start it and retry.

---

## Phase 4: Present Results to User

After the loop completes (PASS or max cycles), present:

1. **Verdict** — PASS or what's still flagged
2. **Changes made** — Summarize what the fixer changed in both source and manifest
3. **Preview** — Note that the updated 3D preview is at localhost:3000
4. **Remaining issues** — If any items couldn't be auto-fixed, list them for the user

To iterate further: the user can describe what still looks off and run `/edit-model` again.
