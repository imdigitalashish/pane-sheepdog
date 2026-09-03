# Adversarial delegation

Read this when the user wants an architecture or plan pressure-tested, not just researched. Ordinary fan-out research does not need it.

## Why neutral prompts underperform

Asking several workers to "analyze the tradeoffs" yields several hedged surveys that agree with each other and with whatever the brief implied. Nothing gets falsified, and you end up integrating consensus that was never tested.

Assigning a position changes the output. A worker told to attack a specific claim searches for the failure case; a worker told to defend one has to concede or rebut on the record. You adjudicate, so a worker being wrong is still useful.

## Give workers a stated antithesis

State the counter-claim concretely and ask the worker to break it. Vague invitations to "consider risks" produce vague risks.

Weak: "Evaluate whether the authority gate design is sound."

Strong: "My antithesis, stress-test it as hard as you can: the tool gate is unenforceable because the model emits audio directly onto the call, so nothing sits between the model deciding to say 'sounds good' and the callee hearing it. The gate binds a compliant model, which is the model that did not need binding. Is this correct? Answer directly, do not hedge."

Add the permission that makes concession safe, since a worker defending its own design will otherwise optimize for looking right:

> Concede what is genuinely broken and defend what is genuinely sound. I value a real concession over a clever save.

Constrain the shape of the answer too. Naming the candidate repairs and asking for a ranked recommendation beats asking for open-ended thoughts, and lets you compare two workers' answers directly.

## Split attack and defense across panes

Put the critique and the rebuttal in different workers on the same question, then decide yourself:

- The **author** of a design defends it and must address each attack on the record.
- An **independent worker** attacks the same design without seeing the defense.

Keep them isolated. If the two panes talk, they converge on a compromise before you see the strongest form of either side, which is the whole value of running both.

Give the attacker read-only access to the design file and say so, otherwise it may "improve" a file another worker owns.

## Attack the inputs, not just the conclusion

The reusable move is to find where a design claims determinism but actually depends on model output. A gate whose arguments are all model-generated has relocated trust, not removed it. Name that specifically:

> Every input to your deterministic gate is model-generated. You moved trust from the model's assertions to the model's arguments and called it deterministic. Defend that or concede it.

## Attack from first principles

The strongest attacks come from re-deriving the problem rather than inspecting the proposal. When the `first-principles-study` skill is available, its Assumption Challenge questions convert directly into delegation prompts, because each one can be answered adversarially by a worker:

- Is the named abstraction the correct abstraction, or did the design inherit it from the request's vocabulary?
- What would we build if the fashionable solution did not exist?
- Which parts are being handed to a model that could be deterministic?
- Are we optimizing a proxy instead of the real objective?
- What information was destroyed by an earlier representation decision?

The causal decomposition pattern is also worth handing to a worker directly: *why does this problem exist, what is the simplest solution, where does it fail, what mechanism fixes that failure, and what new failure does that mechanism introduce?* A worker that answers this produces the design's actual failure boundary rather than a critique of its surface.

Watch for the failure this catches most often: a control that binds only a component already inclined to comply. Ask whether the mechanism constrains the adversarial case or merely documents the cooperative one.

## Forced perspectives

Six-hat assignment works when a decision has stalled or the pool is producing uniform analysis. Assign each worker one lens and forbid the others, so a single pass yields genuinely different material:

| Lens | Assignment |
|---|---|
| Facts | Only what is verifiable, with citations. No recommendations. |
| Risks | Only failure modes, ordered by severity. Assume the worst plausible case. |
| Benefits | Only the strongest case for the proposal, argued in good faith. |
| Feelings | The user's and callee's experience, including where the design feels wrong to a human. |
| Creative | Alternatives outside the stated option set, including reframings of the problem. |
| Process | Whether the decision is even being made correctly, and what evidence is missing. |

Do not run all six by reflex. Two or three lenses that match the actual uncertainty beat a full sweep that fills panes with material you will not use.

A cheaper variant for a single worker: "Argue the strongest case against your own recommendation, then say whether it changes your answer."

## Adjudicate explicitly

You are the decision point. After the rounds land, state which position won and why, name what each side conceded, and carry the residual risk forward rather than dropping it. Workers cannot see each other's output, so an unstated verdict is lost.

Report the disagreement to the user rather than smoothing it into consensus. A design where the attack succeeded and the fix is known is more trustworthy than one where everyone agreed.
