# pane-sheepdog

A Codex skill for running a pack of sibling AI coding agents across Herdr panes without
trampling the human sitting in one of them.

You get one orchestrator, several workers, and a small set of rules that were learned the
expensive way: how to find the pool, how to hand out work that does not collide, which pane
is never safe to talk to, why agents gossiping with each other makes things worse, and how to
keep the flock moving while the orchestrator is asleep between turns.

## The problem

Herdr gives you several terminal panes, each running its own coding agent, and a CLI to type
into any of them. That is enough rope to be genuinely useful and enough rope to hang yourself.

The naive version falls apart fast. You delegate three tasks, two workers write to the same
file, one finishes while you are not in a turn and sits there being done at nobody, and a
third helpfully "reports back" by typing into the pane where your user is halfway through a
sentence. Nothing in the tooling stops any of this. The tooling is a whistle; it does not
teach you to use it.

`pane-sheepdog` is the shepherding discipline layered on top:

- Enumerate the pool, filter it to the current workspace, drop yourself from the roster.
- Give each worker a self-contained slice with a disjoint write set and absolute paths.
- Never prompt a pane a human occupies.
- Keep the topology a fan-out. You are the only integration point.
- Run a supervisor so a finished worker wakes you instead of waiting for you.

## The shared-pane hazard

This is the rule worth reading even if you never install the skill.

`herdr agent prompt <pane> "<text>"` does not deliver a message to an agent. It **types into
that pane's input box**. When the pane is a worker sitting idle, that is exactly what you
want. When the pane hosts a live conversation with a human, the text lands in the middle of
whatever they are composing, and their half-written message and your injected prompt become
one corrupted string. There is no undo and no separate channel to reach for.

The trap is that the obvious way to report back is the destructive one. A worker told only
"tell me when you are finished" will reach for `agent prompt` against the orchestrator, which
is precisely the human-shared pane. So the brief has to name the hazard explicitly:

> Do not run `herdr agent prompt <your-pane-id>`. That pane is shared with a human.
> Append your report to `/abs/path/inbox/from_p3.md` instead.

Workers report by appending to a file, one file per worker so concurrent appends cannot
interleave. You poll those files. This is strictly better than messaging even ignoring the
hazard: a worker that finishes at 3am while you are between turns leaves its result on disk,
and nothing is lost.

## Why fan-out beats peer-to-peer

Worker-to-worker messaging exists, and it is almost always the wrong call.

Peers cannot converge on their own. They share no memory, so two workers "agreeing" means
each one writes its own interpretation into its own file and you still have to reconcile
them. You did not remove the integration step, you just made it harder to see.

Meanwhile every cross-message is paid for by the receiving worker: a turn spent parsing
coordination prose instead of doing the work it was given. Worse, a prompt arriving
mid-task can derail a worker that was making progress, so the cost is not merely wasted
effort but a real chance of regression.

Enable peer messaging only when one worker holds a fact another cannot obtain and the handoff
is a single concrete value. Even then, consider just carrying the fact yourself. And if you
retract the protocol mid-run, send an explicit override, because workers act on their most
recent instructions and will not infer that an earlier protocol is dead:

> Ignore all earlier instructions about peer messaging. Do not prompt any pane.
> I am handling integration.

## The supervisor closes the wake-up loop

An orchestrator agent only exists during a turn. Workers keep running after you stop, but
nothing in Herdr starts a turn in your pane, so a worker that finishes while you are idle
sits unnoticed until the user happens to say something. The pipeline stalls not because
anything failed but because nobody was awake to notice success.

`herdr agent wait` blocks until a worker settles, but only while you are already awake, and
it burns the entire turn doing nothing else.

The fix is a supervisor in its own pane. It outlives your turns, polls each worker's status,
logs every transition, and prompts you when something lands: a worker went idle, a worker got
blocked and needs input, or the whole pool has settled and it is time to dispatch the next
round.

The interesting part is that waking you means typing into a human-shared pane, which is the
exact thing this skill forbids. So the supervisor earns the exception: before it wakes the
orchestrator it checks that the pane is idle **and** that the input box still shows its
untouched placeholder. If the human has started composing, it backs off and retries for up to
ten minutes, then gives up and logs it rather than interrupting. Progress is important;
it is not more important than the human's sentence.

## Install

The skill directory must be named `herdr-workers` to match the skill name in `SKILL.md`,
even though the repo has a better name.

```bash
git clone https://github.com/imdigitalashish/pane-sheepdog.git \
  ~/.codex/skills/herdr-workers
chmod +x ~/.codex/skills/herdr-workers/scripts/supervisor.sh
```

Requires Codex running inside a Herdr workspace with the `herdr` CLI on `PATH`. The skill
checks `HERDR_ENV=1` first and stops rather than trying to drive a session from outside
Herdr.

## Quickstart

Ask your orchestrator agent to use the skill, then let it work the flock:

```bash
# 1. Find the pack. Keep entries matching $HERDR_WORKSPACE_ID,
#    drop the one whose pane_id is $HERDR_PANE_ID - that one is you.
herdr agent list

# 2. Send a worker a self-contained slice, with absolute paths.
#    Workers do not inherit your working directory.
herdr agent prompt wB:p3 "Read /abs/path/api.ts and list every unchecked error path.
Write findings to /tmp/herdr_work/inbox/from_p3.md. Do not prompt any pane." \
  --wait --timeout 300000

# 3. Always read the pane afterwards. --wait returns on the first settled
#    state, which can arrive in seconds and does not prove work happened.
herdr agent read wB:p3 --source recent-unwrapped --lines 200
```

Then put a supervisor behind you so nothing stalls:

```bash
herdr pane split wB:p1 --direction down --ratio 0.2 --no-focus
herdr pane run wB:p9 "$HOME/.codex/skills/herdr-workers/scripts/supervisor.sh wB:p1 wB:p2 wB:p3"
```

The first pane argument is the orchestrator to wake; the rest are the workers to watch.
Tune it with `HERDR_WORK_DIR` (default `/tmp/herdr_work`) and `HERDR_POLL_SECS`
(default `15`). Transitions land in `$HERDR_WORK_DIR/.supervisor/supervisor.log`.

Tell the user the supervisor is running and which pane hosts it. An unexplained pane that
occasionally types into their terminal is alarming.

## Getting real disagreement out of the pool

Parallel workers asked to "analyze the tradeoffs" return parallel hedged surveys that agree
with each other and with whatever your brief implied. Nothing is falsified and you integrate
a consensus that was never tested.

`references/adversarial-delegation.md` covers the alternative: state a concrete antithesis
and ask a worker to break it, split attack and defense across isolated panes so they cannot
converge on a compromise before you see the strongest form of either side, attack the inputs
rather than the conclusion, and adjudicate explicitly at the end. It includes the permission
that makes concession safe, which matters more than it sounds:

> Concede what is genuinely broken and defend what is genuinely sound.
> I value a real concession over a clever save.

## Operational invariants

Hard-won details that will otherwise cost you a debugging session each:

- Address workers by pane ID, never by name. Friendly names are cleared whenever Herdr
  re-detects a pane occupant, so a name that worked a moment ago fails with `agent_not_found`.
  Pane IDs are stable and never reused.
- On `agent_not_found`, re-check with `herdr agent get <pane-id>` and retry. Panes drop out of
  the registry briefly during re-detection; the agent is probably fine.
- Run bare `herdr ...` commands. Pipes, redirection, and substitutions split the command and
  fall outside an approved `herdr` prefix rule under a restricted sandbox, which fails with
  `PermissionDenied`. Parse the full JSON output instead of filtering through `grep` or `jq`.
- Output that scrolls off a pane's alternate screen is gone for good, and `--lines` cannot
  bring it back. For long responses, have the worker write to a file under `/tmp` and reply
  with only the path.
- Use `--no-focus` when creating panes, and never close a pane, tab, or workspace you did not
  create.

## What is in the box

```
SKILL.md                            the skill itself: discovery, delegation, topology, invariants
scripts/supervisor.sh               polls workers, logs transitions, safely wakes the orchestrator
references/adversarial-delegation.md  stress-testing designs with opposed workers and forced lenses
agents/openai.yaml                  display metadata
```

## License

MIT. See [LICENSE](LICENSE).
