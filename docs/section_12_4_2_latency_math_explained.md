# Section 12.4.2 Explained: Order-Statistic Latency Bounds and the Role of `log(alpha) / log(p)`

## 1. The core idea

Section 12.4.2 is solving this problem:

> You measured a baseline latency distribution. You observed, for example, a p95 latency. But that observed p95 is only a sample estimate. How much slack should you give it before calling a later run a latency regression?

The companion's answer is: do **not** assume normality, do **not** use the mean or standard deviation, and do **not** interpolate a latency model. Instead, sort the successful baseline latencies and choose a sufficiently high **order statistic** as an upper confidence bound for the true baseline percentile.

The document defines the derived threshold as:

$$
\tau_j = t_{(k_j)}
$$

where $t_{(k)}$ is the $k$-th smallest successful latency in the sorted baseline sample.

---

## 2. Why a binomial distribution appears

Suppose the true population p95 latency is:

$$
Q(0.95)
$$

By definition, any fresh latency observation has probability 0.95 of being at or below that value:

$$
P(T \le Q(0.95)) = 0.95
$$

More generally, for percentile $p$:

$$
P(T \le Q(p)) = p
$$

Now take $n_s$ successful baseline latency samples. For each sample, define an indicator:

$$
I_i =
\begin{cases}
1 & \text{if } T_i \le Q(p) \\
0 & \text{otherwise}
\end{cases}
$$

Each $I_i$ is Bernoulli with success probability $p$. Therefore the number of samples at or below the true population quantile is:

$$
B = \sum_{i=1}^{n_s} I_i \sim \mathrm{Bin}(n_s, p)
$$

That is the key statistical move: **the latency values may have an unknown and irregular distribution, but the rank of the true quantile inside the sample has a binomial law**.

This is why the construction is distribution-free. It does not require latencies to be normal, lognormal, unimodal, light-tailed, or smooth.

---

## 3. Why choosing a high rank gives an upper bound

Let the sorted successful baseline latencies be:

$$
t_{(1)} \le t_{(2)} \le \cdots \le t_{(n_s)}
$$

If you pick a high order statistic, say $t_{(900)}$, you are saying:

> Use the 900th-smallest observed latency as the derived threshold.

For this to be a valid upper confidence bound on the true $p$-quantile, you want:

$$
Q(p) \le t_{(900)}
$$

The bad event is the opposite:

$$
t_{(900)} < Q(p)
$$

That bad event means at least 900 baseline observations fell below the true $p$-quantile. Since the number below the true $p$-quantile follows:

$$
B \sim \mathrm{Bin}(n_s, p)
$$

the bad-event probability is:

$$
P(B \ge 900)
$$

So Section 12.4.2 chooses the smallest rank $k$ such that:

$$
P(B \ge k) \le \alpha
$$

where $\alpha$ is the configured error level, for example $0.05$ for a 95% one-sided confidence bound.

In the companion's notation:

$$
k_j = \min\left\{ k : P(\mathrm{Bin}(n_s, p_j) \ge k) \le \alpha \right\}
$$

Then the derived latency threshold is:

$$
\tau_j = t_{(k_j)}
$$

In words:

> Choose the lowest observed latency rank high enough that the chance of the true percentile lying above it is at most $\alpha$.

---

## 4. What `qbinom(...) + 1` is doing

The document gives the computational form:

$$
k_{\mathrm{raw}} = \texttt{qbinom}(1-\alpha, n_s, p_j) + 1
$$

This is the same tail rule expressed through the binomial cumulative distribution function.

The desired condition is:

$$
P(B \ge k) \le \alpha
$$

Equivalently:

$$
P(B \le k-1) \ge 1-\alpha
$$

So:

$$
\texttt{qbinom}(1-\alpha, n_s, p_j)
$$

finds the smallest integer $b$ such that:

$$
P(B \le b) \ge 1-\alpha
$$

Then the rank is:

$$
k = b + 1
$$

The `+ 1` is there because the upper-tail event starts at $k$, while the cumulative distribution function stops at $k-1$.

So:

$$
P(B \ge k) \le \alpha
$$

is implemented by finding the binomial $1-\alpha$ quantile and moving one rank higher.

---

## 5. Worked example

Suppose:

$$
n_s = 935,\quad p = 0.95,\quad \alpha = 0.05
$$

Then:

$$
B \sim \mathrm{Bin}(935, 0.95)
$$

The expected rank of the true p95 inside the sample is:

$$
935 \times 0.95 = 888.25
$$

The raw empirical p95 is therefore around rank:

$$
\lceil 0.95 \times 935 \rceil = 889
$$

But rank 889 is only the point estimate. It has no confidence margin.

To get a one-sided 95% upper confidence bound, the companion computes:

$$
k_{0.95} = \texttt{qbinom}(0.95, 935, 0.95) + 1 = 900
$$

So the derived latency threshold is:

$$
\tau_{0.95} = t_{(900)}
$$

The baseline p95 point estimate is rank 889. The confidence-bound threshold is rank 900. The threshold is therefore 11 sorted latency positions above the raw p95 estimate.

Operationally:

> A later test whose observed p95 is at or below $t_{(900)}$ does not breach the derived latency threshold; a later test whose observed p95 exceeds $t_{(900)}$ is treated as evidence of latency degradation.

---

## 6. Where `log(alpha) / log(p)` comes in

The log calculation is **not** the main threshold formula. It is an **existence gate**.

The main formula asks:

$$
\text{Can I find a rank } k \le n_s \text{ such that } P(B \ge k) \le \alpha?
$$

The highest possible rank inside the sample is:

$$
k = n_s
$$

That corresponds to using the maximum observed latency:

$$
t_{(n_s)}
$$

If even the maximum observed latency is not high enough to make the binomial tail probability at most $\alpha$, then no within-sample order statistic can serve as the desired confidence bound.

For $k = n_s$, the bad-event probability is:

$$
P(B \ge n_s)
$$

Since $B$ cannot exceed $n_s$, this is:

$$
P(B = n_s)
$$

Because $B \sim \mathrm{Bin}(n_s, p)$:

$$
P(B = n_s) = p^{n_s}
$$

Therefore, the best possible within-sample upper bound exists only if:

$$
p^{n_s} \le \alpha
$$

Taking logs:

$$
n_s \log(p) \le \log(\alpha)
$$

Since $0 < p < 1$, $\log(p)$ is negative. Dividing by a negative number reverses the inequality:

$$
n_s \ge \frac{\log(\alpha)}{\log(p)}
$$

Because sample size must be an integer:

$$
n_s \ge \left\lceil \frac{\log(\alpha)}{\log(p)} \right\rceil
$$

That is the role of the log formula.

It answers:

> How many successful latency samples do I need so that even the maximum observed latency can serve as a $1-\alpha$ upper confidence bound on the true $p$-quantile?

---

## 7. Example: p99 at 95% confidence

For p99 at 95% confidence:

$$
p = 0.99,\quad \alpha = 0.05
$$

The existence-gate calculation is:

$$
n_s \ge \left\lceil \frac{\log(0.05)}{\log(0.99)} \right\rceil
$$

This gives:

$$
n_s \ge \lceil 298.07\ldots \rceil = 299
$$

So a 95% upper confidence bound for p99 requires at least 299 successful baseline latency samples.

The intuition is stark.

With only 100 successful samples:

$$
0.99^{100} \approx 0.366
$$

That means there is still about a 36.6% probability that all 100 observations fall at or below the true p99. So even the maximum observed latency is not a 95% upper confidence bound for the true p99.

With 299 successful samples:

$$
0.99^{299} \approx 0.0495
$$

Now the probability that every observed latency lies at or below the true p99 is just under 5%. Therefore the maximum observed latency can just barely function as a 95% upper confidence bound.

With larger $n_s$, the required confidence-bound rank may move below the maximum to some earlier order statistic.

---

## 8. Saturation: when the required rank exceeds the sample

§7 established a sample-size floor: for p99 at 95% confidence, you need at least 299 successful samples. But what *happens* below that floor? The companion gives this case a name — **saturation** — and a specific behavioural rule.

### 8.1 What saturation means in plain language

Recall the rule for the rank of the upper confidence bound:

$$
k_{\text{raw}} = \texttt{qbinom}(1-\alpha,\, n_s,\, p) + 1
$$

This is "go climb this many rungs up the sorted-latency ladder." For the formula to produce a usable threshold, that rung must actually exist — that is, $k_{\text{raw}} \le n_s$. **Saturation** is the case where the required rank exceeds the top of the ladder:

$$
k_{\text{raw}} > n_s
$$

The construction is telling you: "to give you a $1-\alpha$ upper bound on the true $p$-quantile, I would need to point at an observation that doesn't exist in your sample."

### 8.2 A worked example

Take $n_s = 200$ successful baseline samples, target percentile $p = 0.99$, confidence $1 - \alpha = 0.95$. The rank we want is:

$$
k_{\text{raw}} = \texttt{qbinom}(0.95,\, 200,\, 0.99) + 1 = 200 + 1 = 201
$$

But the sample only contains 200 sorted observations. There is no $t_{(201)}$. The rank has saturated past the maximum.

This is exactly the regime in the companion's bootstrap-comparison table (§12.4.4): a lognormal baseline with $n_s = 200$ and $p = 0.99$ has a point estimate $\hat{Q}_{0.99} = 448\text{ms}$, but the binomial construction cannot produce a 95% upper bound from this sample — the formula would point at the 201st-smallest observation, which is not there.

### 8.3 What the framework does about it

The companion is firm about what it will **not** do: it will not silently clamp $k_{\text{raw}}$ down to $n_s$ and present $t_{(n_s)}$ as if it were a valid bound. That would manufacture a number that *looks* statistically authoritative but no longer carries the $1-\alpha$ guarantee. The construction either delivers an exact distribution-free upper bound or refuses.

The refusal takes two forms, depending on the test's intent:

- **Under VERIFICATION** — the evidential posture used for compliance against an SLA, SLO, or policy threshold — saturation is treated as a configuration error. The verdict is **INCONCLUSIVE**. The author is being told: "this sample size is too small to deliver the affirmative statistical claim you have asked for."
- **Under SMOKE** — directional signal, not a compliance claim — the maximum observed latency $t_{(n_s)}$ may be displayed alongside the flag `saturated: true`. The number is shown so the operator has *something* to look at, but it is explicitly labelled as not constituting an exact upper bound at the configured confidence.

In the worked example above, a SMOKE report would show $t_{(200)} = 589\text{ms}$ (the maximum observed latency) with `saturated: true`. It is *not* a 95% upper bound on the true $Q(0.99)$; it is the best statistic the sample can offer, clearly flagged as such.

### 8.4 Back to the ladder

In the mental model of §10, the binomial calculation tells you which rung of the sorted-latency ladder to use. Saturation is the case where the calculation says "climb past the top rung." The ladder is not tall enough. The methodology declines to manufacture a rung that is not there.

This is the same idea expressed by the log formula of §6: $n_s \ge \lceil \log(\alpha) / \log(p) \rceil$ is the smallest sample size at which $k_{\text{raw}}$ first lands within the ladder. Below that floor, every configuration saturates. For 95% / p99 the floor is 299; with 200 observations you sit one rung short, and the saturation gate fires.

---

## 9. Difference between the two sample-size gates

The companion distinguishes two different ideas.

### 8.1 Non-degeneracy

A percentile is non-degenerate when the nearest-rank percentile is not merely the maximum.

For p99, this requires at least 100 successful samples. With only 50 successful samples:

$$
\lceil 0.99 \times 50 \rceil = 50
$$

So the empirical p99 is simply the maximum. That is a weak descriptive statistic.

### 8.2 Confidence-bound existence

A confidence-bound existence gate is stricter. It asks whether the sample is large enough to support a distribution-free upper confidence bound at the configured confidence level.

For p99 at 95% confidence, this requires:

$$
n_s \ge 299
$$

So:

$$
100 \le n_s < 299
$$

is the awkward middle region:

- the empirical p99 is no longer simply the maximum;
- but the sample is still too small to support a 95% distribution-free upper confidence bound on the true p99.

In other words:

> A non-degenerate empirical percentile is necessary but not sufficient for an informative binomial order-statistic upper confidence bound.

---

## 10. Mental model

Think of the sorted latency sample as a ladder.

The empirical percentile chooses a rung near:

$$
p \cdot n_s
$$

For p95 with 935 successful samples, that is approximately rung 889.

A confidence bound asks for more than the point estimate. It asks:

> How many rungs higher must I climb so that it would be rare, at level $\alpha$, for the true p95 still to lie above me?

The binomial tail calculation finds that rung. In the worked example, it says: climb from rung 889 to rung 900.

The log calculation asks a more basic question:

> Is the ladder tall enough at all?

For p99 with 100 successful samples, the ladder is not tall enough for a 95% confidence upper bound. For p99 with 299 successful samples, it just becomes tall enough.

---

## 11. Summary

The two formulas have different roles.

The binomial quantile formula:

$$
\texttt{qbinom}(1-\alpha,n_s,p)+1
$$

finds the **rank of the latency threshold**.

The log formula:

$$
\left\lceil \frac{\log(\alpha)}{\log(p)} \right\rceil
$$

finds the **minimum successful sample size needed for such a rank to exist inside the sample**.

So the simplest separation is:

> `qbinom(...) + 1` tells you which sorted latency to use.  
> `log(alpha) / log(p)` tells you whether you have enough successful samples to use any sorted latency at all as a valid upper confidence bound.
