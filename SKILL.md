---
name: herdr-workers
description: "Discover the other coding agents running in the current Herdr workspace and drive them as delegation targets. Use when the user mentions Herdr workers, panes, or sibling agents, or asks to plan work that those agents will execute. Not for ordinary background shell commands or in-process subagents."
---

# Herdr Workers

When the user refers to Herdr in the context of other agents, enumerate the sibling agents in the current workspace and treat them as the execution pool. Plan and decompose locally; hand each worker a self-contained slice.

Confirm the environment first. If `HERDR_ENV` is not `1`, say so and stop rather than controlling a session from outside Herdr.

## Discover the pool

```bash
herdr agent list
```

Keep the agents whose `workspace_id` matches `$HERDR_WORKSPACE_ID`, and drop the entry whose `pane_id` is `$HERDR_PANE_ID` - that one is you. Agents in other workspaces usually belong to a different run; leave them alone unless the user asks for them.

Report the resulting roster before delegating, including pane ID, name, status, and cwd, so the user can see who is about to do the work.

## Decompose before you delegate

Delegation quality is set before any worker starts. Slice along the wrong seam and workers duplicate each other, research questions that do not matter, or leave the load-bearing problem untouched. Decompose from first principles rather than from the vocabulary of the request.

When the `first-principles-study` skill is available, use its Mandatory Internal Coverage Scan as the decomposition tool. Four of its lenses do most of the work here:

- **Objects and ontology.** What actually exists in this problem, as opposed to what the request happens to name. These become candidate slices.
- **Upstream dependencies.** What must be solved before the thing the user asked about. A dependency nobody owns is the slice most worth assigning first.
- **Deterministic versus probabilistic.** Which parts are rules, data, or protocol facts, and which need judgment. Factual slices parallelize cleanly; judgment slices need an owner and usually an adversary.
- **Missing-layer audit.** Ask what an expert would complain you forgot entirely, then staff that gap. A request phrased around one layer often hides its real difficulty in another.

A user asking for a phone-calling agent names the voice model, but the binding constraints may be carrier origination, legal eligibility, and what the agent is permitted to commit to. Those are separate slices with different owners, and only one of them was in the question.

Prefer slices that are separable by evidence: each worker should be able to finish without knowing what another concluded. When two slices genuinely depend on each other, own the dependency yourself and hand each worker the resolved fact rather than making them negotiate it.

## Write a brief a worker can finish alone

A worker starts with no context beyond your prompt: not your reasoning, not the user's request, not its own working directory. Vague briefs come back as link dumps.

State the deliverable as one absolute path the worker owns exclusively, and say which paths belong to others and are read-only. Name the questions to answer rather than the topic to explore, and say what would make the answer wrong. Include settled facts explicitly so the worker does not spend turns rediscovering them, and mark which sections matter most when the brief is long. If output could be large, require a file plus a one-line reply so a long answer cannot scroll off the pane.

Correct a worker as soon as you see it wasting turns; a mid-task prompt costs one turn and can save many. Watch for search engines returning consent interstitials, re-researching a settled fact, or drifting outside its slice.

## Add a worker when the pool is short

Every existing agent may be busy, or the only idle ones may belong to another workspace. Create your own worker rather than interrupting someone else's run:

```bash
herdr pane split <pane-id> --direction down --ratio 0.5 --no-focus
herdr agent start <name> --kind codex --pane <new-pane-id> --timeout 120000 -- --yolo
```

`herdr agent start` needs a pane already sitting at an interactive shell prompt, and everything after `--` is passed to the agent binary. Start Codex workers with `--yolo` so they do not stall on approval prompts mid-task: a worker that blocks on "create this repo?" holds its slot until someone notices, which defeats delegating in the first place. Only do this when the user has accepted that tradeoff, and keep the task brief narrow enough that unattended execution is appropriate.

A worker will still stop for anything its own configuration escalates. When the supervisor reports a pane as `blocked`, read it and clear the prompt:

```bash
herdr agent read     <pane-id> --source recent-unwrapped --lines 45
herdr agent send-keys <pane-id> enter
```

Read before answering. `send-keys enter` accepts whatever is selected, so confirm what the worker is actually asking before approving a destructive or externally visible action.

A worker started without `--yolo` will block on every escalation, not once. If the same pane keeps stopping on routine read-only commands, that is a configuration problem rather than a series of incidents: either take the worker's persistent-approval option so the prefix is remembered, or plan on clearing it repeatedly for the rest of the run. Note which panes you created with `--yolo`, since a pane that was already running when you found it may not have been.

## Drive a worker

```bash
herdr agent prompt <pane-id> "<self-contained task>" --wait --timeout 300000
herdr agent read  <pane-id> --source recent-unwrapped --lines 200
```

Always read the pane after a prompt. `agent prompt --wait` returns on the first settled state, which can arrive within seconds and does not by itself prove the work happened.

Give each worker a disjoint write set so parallel tasks cannot collide, and prefer explicit absolute paths in the prompt. Workers do not inherit your working directory.

## Never prompt a pane a human is sitting in

Your own pane usually hosts a live conversation with the user. `herdr agent prompt` types into that pane's input box, so a worker prompting you lands in the middle of whatever the user is composing and corrupts their message. Treat any human-occupied pane as write-protected.

Say so explicitly when briefing workers, because the obvious way to "report back" is the destructive one:

> Do not run `herdr agent prompt <your-pane-id>`. That pane is shared with a human. Append your report to `<absolute path>` instead.

Have workers report by appending to a per-worker file, one file per worker so appends cannot interleave. Poll those files yourself. A worker that finishes while you are asleep leaves its result on disk, which loses nothing.

## Choose a coordination topology

Default to fan-out: workers talk only to you, and you own all integration. Worker-to-worker messaging is available and occasionally right, but it is not free and usually loses.

Peers cannot converge on their own. They share no memory, so "agreeing" means each writes its own interpretation into its own file and you still reconcile them. Meanwhile every cross-message costs the receiving worker a turn spent parsing coordination prose instead of doing the work, and a prompt arriving mid-task can derail a worker that was making progress.

Enable peer messaging only when one worker holds a fact another cannot obtain and the handoff is a single concrete value. Even then, consider whether you can just carry the fact yourself.

When you retract peer messaging mid-run, send an explicit override. Workers act on their most recent instructions but do not infer that an earlier protocol is dead:

> Ignore all earlier instructions about peer messaging, seams, and roster updates. Do not prompt any pane. I am handling integration.

## Keep work moving while you are asleep

You only exist during a turn. Workers keep running after you stop, but nothing in Herdr starts a turn in your pane, so a finished worker sits unnoticed until the user next speaks to you.

`herdr agent wait <pane-id> --until idle --timeout <ms>` blocks until a worker settles, but only works while you are already awake and burns the turn doing nothing else. Use it when you genuinely need a result before you can continue.

For continuous operation, run a supervisor in its own pane. It outlives your turns, watches worker status, and prompts you when something lands:

```bash
herdr pane split <pane-id> --direction down --ratio 0.2 --no-focus
herdr pane run <new-pane-id> "<skill-dir>/scripts/supervisor.sh <your-pane> <worker-pane>..."
```

[scripts/supervisor.sh](scripts/supervisor.sh) polls each worker, logs transitions to `$HERDR_WORK_DIR/.supervisor/supervisor.log`, and wakes the orchestrator when workers finish or block. Set `HERDR_WORK_DIR` to the directory your workers write to, since the wake message points there. Tell the user the supervisor is running and which pane hosts it.

Three behaviours matter when you rely on it:

Waking means typing into a human-shared pane, so the script only prompts when that pane is idle with an untouched placeholder, retries while the human is composing, and gives up after ten minutes rather than interrupting. That deferral is what makes the next two points necessary.

Because a wake can be delayed by minutes, an alert may describe a condition that has since resolved. Blocked-worker alerts re-verify the pane is still blocked immediately before prompting and drop the alert otherwise. Treat any alert as a prompt to re-check current state rather than as a fact.

Workers finishing seconds apart would otherwise produce separate wakes for the same batch. Completions are collected during a settle window, then reported in one message. Give the supervisor every worker you care about in a single invocation instead of running one per worker.

Every alert carries the full roster, not just the pane that triggered it. Treat a wake as a scheduling opportunity: a worker finishing usually means others are free too, and the alert names them so you can fill the whole pool in one turn rather than discovering idle workers one wake at a time. Check the roster before writing any brief, since what is available changes which slices are worth cutting.

The pane hosting the supervisor is a plain shell, not an agent, so it does not appear in `herdr agent list`. Restart it with `herdr pane run` on the same pane after changing the roster or editing the script; stop the previous process first so two instances do not both wake you.

## Decide when the run is over

A supervisor polls forever. Nothing in the loop knows the objective was met, so deciding the run is finished is your job, and it is a real decision rather than a formality. Without it you keep getting woken about a project that is done, and each wake tempts you to invent filler work for idle workers.

Judge completion against the user's objective, not against worker activity. An idle pool means nobody is busy; it does not mean the question is answered. Ask whether the deliverable the user asked for exists, whether the findings that would change it have been collected, and whether the remaining unknowns are ones more delegation could actually resolve. Work that only a decision from the user can unblock is finished from your side even though it is not resolved.

Each wake therefore forces one of two answers: dispatch work to every available worker, or end the run. Drifting between them is what produces repeated wakes about a finished project.

Resist manufacturing tasks to fill capacity. An idle worker costs nothing; a worker producing material nobody needs costs you the turns spent reading it and dilutes the result. If the next slice would not change a conclusion or a decision, there is no next slice, and that is a signal the run is over rather than a reason to invent one.

When the objective is met, stop the supervisor and say so:

```bash
touch "$HERDR_WORK_DIR/.supervisor/STOP"
```

The supervisor exits on its next poll. Then deliver the integrated result, name anything still open, and leave the workers idle rather than closing panes you did not create. If the user reopens the thread later, start a new supervisor with the current roster.

## Get real disagreement out of the pool

Parallel workers that only answer questions produce parallel opinions, not a decision. When the user wants an architecture stress-tested rather than merely researched, assign opposing roles on the same question and adjudicate the result yourself. State a concrete antithesis instead of asking for balanced analysis, and tell workers a genuine concession is worth more than a clever save.

For the role assignments, forced-perspective framings, and prompt shapes that hold up, read [references/adversarial-delegation.md](references/adversarial-delegation.md).

Form your own position before you assign the roles. An orchestrator who has not reasoned about the problem cannot tell a real concession from a fluent one, and cannot write an antithesis sharp enough to be worth attacking. Do the primary reading yourself on whatever is load-bearing.

## Adjudicate, then act on the ruling

Opposing briefs are not a decision. Say plainly which position won, name what each side conceded, and carry forward the risk that neither eliminated. Workers cannot see each other's output, so an unstated verdict is lost.

Then push the ruling back into the pool. A losing design usually needs revising by its author, and a newly exposed gap usually needs a fresh slice. Send both as new tasks that state the ruling as a settled premise, so nobody relitigates it. Tell the author what survived as well as what failed; that is what keeps the next round honest rather than defensive.

Report the disagreement to the user rather than smoothing it into consensus. A design where an attack succeeded and the fix is known is more trustworthy than one where everyone agreed.

## Integrate rather than concatenate

Worker files are inputs, not the answer. Read them, resolve conflicts, and state a single position. When two workers disagree on fact, check the primary source yourself rather than averaging them.

Verify claims that assert an external side effect. A worker reporting that it published, deployed, or created something is reporting its belief; confirm against the system itself. Give the user the conclusion and its consequences, cite which worker produced what only when provenance matters, and surface any finding that changes the shape of the task as soon as you have it rather than saving it for a final summary.

## Operational invariants

Address workers by pane ID, not by name. Friendly names set with `herdr agent rename` are cleared whenever Herdr re-detects the pane occupant, so a name that worked a moment ago can fail with `agent_not_found`. Pane IDs are stable and never reused.

A pane can drop out of the agent registry briefly during re-detection. On `agent_not_found`, re-check with `herdr agent get <pane-id>` and retry rather than concluding the agent is gone.

The `herdr` CLI talks to a unix socket and needs escalated permissions under a restricted sandbox. Run bare `herdr ...` commands: shell pipes, redirection, and substitutions split the command and fall outside an approved `herdr` prefix rule, which fails with `PermissionDenied`. Parse the JSON from the full output instead of filtering it through `grep` or `jq`.

Output that scrolls off a pane's alternate screen is unrecoverable, so `--lines` cannot bring it back. When a response is too long to read, ask the worker to write it to a file under `/tmp` and reply with only the path, then read that file.

Use `--no-focus` when creating panes, and do not close panes, tabs, or workspaces you did not create.
