"""
Author: Ahmet Aksoy
Date: 2026-03-27
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

17_hmm.mojo -- Hidden Markov Model (pure Mojo)

Algorithms implemented:
  1. Forward          -- P(observations | model)  via alpha pass
  2. Backward         -- beta pass (used in Baum-Welch)
  3. Baum-Welch (EM)  -- unsupervised learning of (A, B, pi)
  4. Viterbi          -- most likely hidden state sequence

Model parameters:
  pi[s]      -- initial state probability
  A[s1][s2]  -- transition probability P(s2 | s1)
  B[s][o]    -- emission probability   P(o  | s)

Demo 1 -- Dishonest Casino:
  2 hidden states: Fair die (F) and Loaded die (L)
  6 observations:  die faces 1-6
  Known ground-truth parameters; verify Viterbi decoding.

Demo 2 -- Iris petal_len sequence:
  Iris petal_len values discretized into 3 bins (short/medium/long).
  2 hidden states learned via Baum-Welch.
  Viterbi decoding reveals latent structure (Setosa vs non-Setosa).

Matrices stored as flat List[Float64]  (gotcha #37).
All log computations use log-sum-exp for numerical stability.
"""

from std.math import exp, log, sqrt


# ──────────────────────────────────────────────
# Constants  (gotcha #41 -- alias -> comptime)
# ──────────────────────────────────────────────
comptime LOG_ZERO = -1e18   # represents log(0)


# ──────────────────────────────────────────────
# Numerically stable log-sum-exp of two log values
# ──────────────────────────────────────────────
fn log_add(a: Float64, b: Float64) -> Float64:
    if a <= LOG_ZERO:
        return b
    if b <= LOG_ZERO:
        return a
    if a > b:
        return a + log(1.0 + exp(b - a))
    return b + log(1.0 + exp(a - b))


# ──────────────────────────────────────────────
# Allocate zero-filled flat matrix (rows x cols)
# gotcha #42 -- return List with ^
# ──────────────────────────────────────────────
fn zeros(rows: Int, cols: Int) -> List[Float64]:
    var m = List[Float64]()
    for _ in range(rows * cols):
        m.append(0.0)
    return m^


fn log_zeros(rows: Int, cols: Int) -> List[Float64]:
    var m = List[Float64]()
    for _ in range(rows * cols):
        m.append(LOG_ZERO)
    return m^


# ──────────────────────────────────────────────
# Normalize a row so it sums to 1.0
# ──────────────────────────────────────────────
fn normalize_row(mut m: List[Float64], row: Int, cols: Int):
    var s = 0.0
    for c in range(cols):
        s += m[row * cols + c]
    if s < 1e-12:
        s = 1e-12
    for c in range(cols):
        m[row * cols + c] /= s


fn normalize_vec(mut v: List[Float64]):
    var s = 0.0
    for i in range(len(v)):
        s += v[i]
    if s < 1e-12:
        s = 1e-12
    for i in range(len(v)):
        v[i] /= s


# ══════════════════════════════════════════════
# FORWARD ALGORITHM
# alpha[t, s] = P(o_0..o_t, q_t=s | model)
# Returns log P(O | model) via log-sum-exp
# ══════════════════════════════════════════════
fn forward(
    obs: List[Int], T: Int,
    pi: List[Float64],
    A:  List[Float64],   # n_states x n_states
    B:  List[Float64],   # n_states x n_obs
    n_states: Int, n_obs: Int,
    mut alpha: List[Float64]   # T x n_states  (output)
) -> Float64:
    # Initialise t=0
    for s in range(n_states):
        alpha[0 * n_states + s] = pi[s] * B[s * n_obs + obs[0]]

    # Induction
    for t in range(1, T):
        for s2 in range(n_states):
            var sum_val = 0.0
            for s1 in range(n_states):
                sum_val += alpha[(t-1) * n_states + s1] * A[s1 * n_states + s2]
            alpha[t * n_states + s2] = sum_val * B[s2 * n_obs + obs[t]]

    # Log-likelihood = log sum_s alpha[T-1, s]
    var total = 0.0
    for s in range(n_states):
        total += alpha[(T-1) * n_states + s]
    if total < 1e-300:
        return LOG_ZERO
    return log(total)


# ══════════════════════════════════════════════
# BACKWARD ALGORITHM
# beta[t, s] = P(o_{t+1}..o_{T-1} | q_t=s, model)
# ══════════════════════════════════════════════
fn backward(
    obs: List[Int], T: Int,
    A: List[Float64],
    B: List[Float64],
    n_states: Int, n_obs: Int,
    mut beta: List[Float64]   # T x n_states  (output)
):
    # Initialise t=T-1
    for s in range(n_states):
        beta[(T-1) * n_states + s] = 1.0

    # Induction (backwards)
    var t = T - 2
    var go = t >= 0
    while go:
        for s1 in range(n_states):
            var sum_val = 0.0
            for s2 in range(n_states):
                sum_val += A[s1 * n_states + s2] * \
                           B[s2 * n_obs + obs[t+1]] * \
                           beta[(t+1) * n_states + s2]
            beta[t * n_states + s1] = sum_val
        t -= 1
        go = t >= 0


# ══════════════════════════════════════════════
# BAUM-WELCH (EM) TRAINING
# Learns A, B, pi from observation sequence
# ══════════════════════════════════════════════
fn baum_welch(
    obs: List[Int], T: Int,
    n_states: Int, n_obs: Int,
    n_iter: Int,
    mut pi: List[Float64],
    mut A:  List[Float64],
    mut B:  List[Float64]
):
    for _ in range(n_iter):
        # Forward and backward passes
        var alpha = zeros(T, n_states)
        var beta  = zeros(T, n_states)

        # Forward (using current parameters)
        for s in range(n_states):
            alpha[0 * n_states + s] = pi[s] * B[s * n_obs + obs[0]]
        for t in range(1, T):
            for s2 in range(n_states):
                var sv = 0.0
                for s1 in range(n_states):
                    sv += alpha[(t-1) * n_states + s1] * A[s1 * n_states + s2]
                alpha[t * n_states + s2] = sv * B[s2 * n_obs + obs[t]]

        # Backward
        backward(obs, T, A, B, n_states, n_obs, beta)

        # xi[t, s1, s2] = P(q_t=s1, q_{t+1}=s2 | O, model)
        # gamma[t, s]   = P(q_t=s | O, model)

        # Re-estimate pi
        var pi_num = List[Float64]()
        for _ in range(n_states):
            pi_num.append(0.0)

        # Re-estimate A numerator/denominator
        var A_num = zeros(n_states, n_states)
        var A_den = List[Float64]()
        for _ in range(n_states):
            A_den.append(0.0)

        # Re-estimate B numerator/denominator
        var B_num = zeros(n_states, n_obs)
        var B_den = List[Float64]()
        for _ in range(n_states):
            B_den.append(0.0)

        # Compute denominator for normalisation
        var denom = 0.0
        for s in range(n_states):
            denom += alpha[(T-1) * n_states + s]
        if denom < 1e-300:
            denom = 1e-300

        # gamma at t=0 -> new pi
        for s in range(n_states):
            pi_num[s] = alpha[0 * n_states + s] * beta[0 * n_states + s] / denom

        # Accumulate xi and gamma over t=0..T-2
        for t in range(T - 1):
            var xi_denom = 0.0
            for s1 in range(n_states):
                for s2 in range(n_states):
                    xi_denom += (alpha[t * n_states + s1] *
                                 A[s1 * n_states + s2] *
                                 B[s2 * n_obs + obs[t+1]] *
                                 beta[(t+1) * n_states + s2])
            if xi_denom < 1e-300:
                xi_denom = 1e-300

            for s1 in range(n_states):
                var gamma_t = 0.0
                for s2 in range(n_states):
                    var xi = (alpha[t * n_states + s1] *
                              A[s1 * n_states + s2] *
                              B[s2 * n_obs + obs[t+1]] *
                              beta[(t+1) * n_states + s2]) / xi_denom
                    A_num[s1 * n_states + s2] += xi
                    gamma_t += xi
                A_den[s1] += gamma_t
                B_num[s1 * n_obs + obs[t]] += gamma_t
                B_den[s1] += gamma_t

        # Last time step for B only
        for s in range(n_states):
            var gamma_last = (alpha[(T-1) * n_states + s] *
                              beta[(T-1) * n_states + s]) / denom
            B_num[s * n_obs + obs[T-1]] += gamma_last
            B_den[s] += gamma_last

        # Update parameters
        for s in range(n_states):
            pi[s] = pi_num[s]
        normalize_vec(pi)

        for s1 in range(n_states):
            for s2 in range(n_states):
                if A_den[s1] < 1e-300:
                    A[s1 * n_states + s2] = 1.0 / Float64(n_states)
                else:
                    A[s1 * n_states + s2] = A_num[s1 * n_states + s2] / A_den[s1]
            normalize_row(A, s1, n_states)

        for s in range(n_states):
            for o in range(n_obs):
                if B_den[s] < 1e-300:
                    B[s * n_obs + o] = 1.0 / Float64(n_obs)
                else:
                    B[s * n_obs + o] = B_num[s * n_obs + o] / B_den[s]
            normalize_row(B, s, n_obs)


# ══════════════════════════════════════════════
# VITERBI DECODING
# Most likely hidden state sequence
# gotcha #44 -- backpointer stored as flat List[Int]
# ══════════════════════════════════════════════
fn viterbi(
    obs: List[Int], T: Int,
    pi: List[Float64],
    A:  List[Float64],
    B:  List[Float64],
    n_states: Int, n_obs: Int,
    mut path: List[Int]   # output: length T
):
    # delta[t, s] = max probability of any path ending in state s at time t
    var delta = zeros(T, n_states)
    var psi   = List[Int]()
    for _ in range(T * n_states):
        psi.append(0)

    # Initialise
    for s in range(n_states):
        delta[0 * n_states + s] = pi[s] * B[s * n_obs + obs[0]]
        psi[0 * n_states + s]   = 0

    # Recursion  (gotcha #39 -- direct for loops, no while+if needed here)
    for t in range(1, T):
        for s2 in range(n_states):
            var best_val = -1.0
            var best_s   = 0
            for s1 in range(n_states):
                var val = delta[(t-1) * n_states + s1] * A[s1 * n_states + s2]
                if val > best_val:
                    best_val = val
                    best_s   = s1
            delta[t * n_states + s2] = best_val * B[s2 * n_obs + obs[t]]
            psi[t * n_states + s2]   = best_s

    # Backtrack
    for _ in range(T):
        path.append(0)

    # Find best final state
    var best_val = -1.0
    var best_s   = 0
    for s in range(n_states):
        if delta[(T-1) * n_states + s] > best_val:
            best_val = delta[(T-1) * n_states + s]
            best_s   = s
    path[T-1] = best_s

    var t = T - 2
    var go = t >= 0
    while go:
        path[t] = psi[(t+1) * n_states + path[t+1]]
        t -= 1
        go = t >= 0


# ══════════════════════════════════════════════
# DEMO 1: Dishonest Casino
# ══════════════════════════════════════════════
fn demo_casino():
    print("\n" + "=" * 60)
    print("  Demo 1: Dishonest Casino")
    print("  Hidden states: 0=Fair  1=Loaded")
    print("  Observations : die faces 0-5 (representing 1-6)")
    print("=" * 60)

    comptime N_ST  = 2   # Fair, Loaded
    comptime N_OBS = 6   # die faces 1-6

    # Ground-truth parameters
    # pi: start with Fair
    var pi = List[Float64]()
    pi.append(0.5); pi.append(0.5)

    # A: transition matrix
    # Fair->Fair=0.95, Fair->Loaded=0.05
    # Loaded->Fair=0.10, Loaded->Loaded=0.90
    var A = zeros(N_ST, N_ST)
    A[0 * N_ST + 0] = 0.95; A[0 * N_ST + 1] = 0.05
    A[1 * N_ST + 0] = 0.10; A[1 * N_ST + 1] = 0.90

    # B: emission matrix
    # Fair: uniform 1/6
    # Loaded: face 6 (index 5) with prob 0.5, others 0.1
    var B = zeros(N_ST, N_OBS)
    for o in range(N_OBS):
        B[0 * N_OBS + o] = 1.0 / 6.0
    for o in range(5):
        B[1 * N_OBS + o] = 0.1
    B[1 * N_OBS + 5] = 0.5

    # Simulate a short observation sequence (hand-crafted for clarity)
    # First 10: Fair die, next 10: Loaded die, last 10: Fair die
    var obs_raw = List[Int]()
    # Fair region (varied faces)
    obs_raw.append(0); obs_raw.append(2); obs_raw.append(4)
    obs_raw.append(1); obs_raw.append(3); obs_raw.append(0)
    obs_raw.append(2); obs_raw.append(5); obs_raw.append(1)
    obs_raw.append(3)
    # Loaded region (mostly 5s)
    obs_raw.append(5); obs_raw.append(5); obs_raw.append(4)
    obs_raw.append(5); obs_raw.append(5); obs_raw.append(5)
    obs_raw.append(3); obs_raw.append(5); obs_raw.append(5)
    obs_raw.append(5)
    # Fair region again
    obs_raw.append(1); obs_raw.append(0); obs_raw.append(3)
    obs_raw.append(2); obs_raw.append(4); obs_raw.append(1)
    obs_raw.append(0); obs_raw.append(2); obs_raw.append(3)
    obs_raw.append(1)

    var T = len(obs_raw)

    # True hidden states (for comparison)
    var true_states = List[Int]()
    for _ in range(10):
        true_states.append(0)   # Fair
    for _ in range(10):
        true_states.append(1)   # Loaded
    for _ in range(10):
        true_states.append(0)   # Fair

    # Forward: compute log-likelihood
    var alpha = zeros(T, N_ST)
    var log_p = forward(obs_raw, T, pi, A, B, N_ST, N_OBS, alpha)
    print("\nForward log-likelihood: " + String(Int(log_p * 100)) + "e-2")

    # Viterbi decoding
    var path = List[Int]()
    viterbi(obs_raw, T, pi, A, B, N_ST, N_OBS, path)

    # Compare with true states
    var correct = 0
    for t in range(T):
        if path[t] == true_states[t]:
            correct += 1

    print("Viterbi accuracy vs true states: " +
          String(correct) + "/" + String(T) +
          "  (" + String(Int(Float64(correct)/Float64(T)*100)) + "%)")

    # Print decoded sequence
    print("\nObservations (die face+1):")
    var obs_str = "  "
    for t in range(T):
        obs_str += String(obs_raw[t] + 1) + " "
    print(obs_str)

    print("Viterbi states (F=Fair, L=Loaded):")
    var path_str = "  "
    for t in range(T):
        if path[t] == 0:
            path_str += "F "
        else:
            path_str += "L "
    print(path_str)

    print("True states:")
    var true_str = "  "
    for t in range(T):
        if true_states[t] == 0:
            true_str += "F "
        else:
            true_str += "L "
    print(true_str)

    # Baum-Welch: learn parameters from scratch
    # Asymmetric init -- uniform B causes symmetry and EM gets stuck
    print("\n-- Baum-Welch learning (init: asymmetric) --")
    var pi2 = List[Float64]()
    pi2.append(0.6); pi2.append(0.4)

    var A2 = zeros(N_ST, N_ST)
    A2[0 * N_ST + 0] = 0.7; A2[0 * N_ST + 1] = 0.3
    A2[1 * N_ST + 0] = 0.2; A2[1 * N_ST + 1] = 0.8

    # State 0 hint: roughly uniform; State 1 hint: biased toward face 6
    var B2 = zeros(N_ST, N_OBS)
    for o in range(N_OBS):
        B2[0 * N_OBS + o] = 1.0 / 6.0
    for o in range(5):
        B2[1 * N_OBS + o] = 0.12
    B2[1 * N_OBS + 5] = 0.40

    baum_welch(obs_raw, T, N_ST, N_OBS, 50, pi2, A2, B2)

    var path2 = List[Int]()
    viterbi(obs_raw, T, pi2, A2, B2, N_ST, N_OBS, path2)

    var correct2 = 0
    for t in range(T):
        # States may be flipped after unsupervised learning
        if path2[t] == true_states[t]:
            correct2 += 1
    # Check flipped version too
    var correct2f = 0
    for t in range(T):
        if path2[t] != true_states[t]:
            correct2f += 1

    var best_correct = correct2
    if correct2f > correct2:
        best_correct = correct2f

    print("Baum-Welch Viterbi accuracy: " +
          String(best_correct) + "/" + String(T) +
          "  (" + String(Int(Float64(best_correct)/Float64(T)*100)) + "%)")

    print("\nLearned transition matrix A:")
    print("  F->F=" + String(Int(A2[0*N_ST+0]*100)) + "%  " +
          "F->L=" + String(Int(A2[0*N_ST+1]*100)) + "%")
    print("  L->F=" + String(Int(A2[1*N_ST+0]*100)) + "%  " +
          "L->L=" + String(Int(A2[1*N_ST+1]*100)) + "%")

    print("\nLearned emission B (face probabilities %):")
    print("  State0: ", end="")
    var s0_str = ""
    for o in range(N_OBS):
        s0_str += String(Int(B2[0*N_OBS+o]*100)) + " "
    print(s0_str)
    print("  State1: ", end="")
    var s1_str = ""
    for o in range(N_OBS):
        s1_str += String(Int(B2[1*N_OBS+o]*100)) + " "
    print(s1_str)


# ══════════════════════════════════════════════
# DEMO 2: Iris petal_len discretized
# ══════════════════════════════════════════════
fn demo_iris():
    print("\n" + "=" * 60)
    print("  Demo 2: Iris petal_len sequence")
    print("  Discretized into 3 bins: 0=short 1=medium 2=long")
    print("  2 hidden states learned via Baum-Welch")
    print("=" * 60)

    # Iris petal_len values (30 samples, ordered by class)
    var petal = List[Float64]()
    # Setosa (short petals ~1.3-1.7)
    petal.append(1.4); petal.append(1.4); petal.append(1.3)
    petal.append(1.5); petal.append(1.4); petal.append(1.7)
    petal.append(1.4); petal.append(1.5); petal.append(1.4)
    petal.append(1.5)
    # Versicolor (medium petals ~3.3-4.9)
    petal.append(4.7); petal.append(4.5); petal.append(4.9)
    petal.append(4.0); petal.append(4.6); petal.append(4.5)
    petal.append(4.7); petal.append(3.3); petal.append(4.6)
    petal.append(3.9)
    # Virginica (long petals ~4.5-6.6)
    petal.append(6.0); petal.append(5.1); petal.append(5.9)
    petal.append(5.6); petal.append(5.8); petal.append(6.6)
    petal.append(4.5); petal.append(6.3); petal.append(5.8)
    petal.append(6.1)

    # True labels for evaluation
    var true_class = List[Int]()
    for _ in range(10):
        true_class.append(0)   # Setosa
    for _ in range(10):
        true_class.append(1)   # Versicolor
    for _ in range(10):
        true_class.append(2)   # Virginica

    # Discretize: 0 = [0, 2.5), 1 = [2.5, 5.0), 2 = [5.0, inf)
    var obs = List[Int]()
    for i in range(len(petal)):
        var v = petal[i]
        var bin = 2
        if v < 2.5:
            bin = 0
        elif v < 5.0:
            bin = 1
        obs.append(bin)

    var T      = len(obs)
    comptime N_ST2  = 2
    comptime N_OBS2 = 3

    print("\nDiscretized observations:")
    print("  (0=short, 1=medium, 2=long)")
    var obs_str = "  "
    for t in range(T):
        obs_str += String(obs[t]) + " "
    print(obs_str)

    # Baum-Welch from uniform init
    var pi = List[Float64]()
    pi.append(0.5); pi.append(0.5)

    var A = zeros(N_ST2, N_ST2)
    A[0 * N_ST2 + 0] = 0.7; A[0 * N_ST2 + 1] = 0.3
    A[1 * N_ST2 + 0] = 0.3; A[1 * N_ST2 + 1] = 0.7

    var B = zeros(N_ST2, N_OBS2)
    for o in range(N_OBS2):
        B[0 * N_OBS2 + o] = 1.0 / 3.0
        B[1 * N_OBS2 + o] = 1.0 / 3.0

    baum_welch(obs, T, N_ST2, N_OBS2, 100, pi, A, B)

    # Viterbi decoding
    var path = List[Int]()
    viterbi(obs, T, pi, A, B, N_ST2, N_OBS2, path)

    print("\nViterbi hidden states:")
    var path_str = "  "
    for t in range(T):
        path_str += String(path[t]) + " "
    print(path_str)

    # Check if state 0 = Setosa or state 1 = Setosa
    # Setosa has obs=0 (short), so the state that emits 0 most is Setosa state
    var state0_is_setosa = B[0 * N_OBS2 + 0] > B[1 * N_OBS2 + 0]

    print("\nLearned B (emission probabilities %):")
    var bin_names = List[String]()
    bin_names.append("short ")
    bin_names.append("medium")
    bin_names.append("long  ")
    for s in range(N_ST2):
        var row_str = "  State" + String(s) + ": "
        for o in range(N_OBS2):
            row_str += bin_names[o] + "=" +
                       String(Int(B[s * N_OBS2 + o] * 100)) + "%  "
        print(row_str)

    print("\nLearned A (transition %):")
    print("  S0->S0=" + String(Int(A[0*N_ST2+0]*100)) + "%  " +
          "S0->S1=" + String(Int(A[0*N_ST2+1]*100)) + "%")
    print("  S1->S0=" + String(Int(A[1*N_ST2+0]*100)) + "%  " +
          "S1->S1=" + String(Int(A[1*N_ST2+1]*100)) + "%")

    # Evaluate: does Viterbi separate Setosa (obs=0) from the rest?
    var setosa_state = 0
    if not state0_is_setosa:
        setosa_state = 1

    var setosa_correct = 0
    var other_correct  = 0
    for t in range(T):
        if true_class[t] == 0:   # Setosa
            if path[t] == setosa_state:
                setosa_correct += 1
        else:
            if path[t] != setosa_state:
                other_correct += 1

    print("\nViterbi vs true labels (2-class: Setosa vs non-Setosa):")
    print("  Setosa    detected: " + String(setosa_correct) + "/10")
    print("  Non-Setosa detected: " + String(other_correct) + "/20")
    var total_correct = setosa_correct + other_correct
    print("  Overall accuracy: " + String(total_correct) + "/30" +
          "  (" + String(Int(Float64(total_correct)/30.0*100)) + "%)")

    # Log-likelihood after learning
    var alpha = zeros(T, N_ST2)
    var log_p = forward(obs, T, pi, A, B, N_ST2, N_OBS2, alpha)
    print("  Log-likelihood after Baum-Welch: " +
          String(Int(log_p * 100)) + "e-2")


# ══════════════════════════════════════════════
# Parameter sensitivity: n_iter effect on log-likelihood
# ══════════════════════════════════════════════
fn param_study():
    print("\n" + "=" * 55)
    print("Parameter Sensitivity: Baum-Welch n_iter")
    print("(Casino sequence, 2 states, 6 observations)")
    print("=" * 55)

    # Same casino sequence as Demo 1
    var obs = List[Int]()
    obs.append(0); obs.append(2); obs.append(4); obs.append(1)
    obs.append(3); obs.append(0); obs.append(2); obs.append(5)
    obs.append(1); obs.append(3)
    obs.append(5); obs.append(5); obs.append(4); obs.append(5)
    obs.append(5); obs.append(5); obs.append(3); obs.append(5)
    obs.append(5); obs.append(5)
    obs.append(1); obs.append(0); obs.append(3); obs.append(2)
    obs.append(4); obs.append(1); obs.append(0); obs.append(2)
    obs.append(3); obs.append(1)

    var T = len(obs)
    comptime NST = 2
    comptime NOB = 6

    var iter_vals = List[Int]()
    iter_vals.append(1); iter_vals.append(5); iter_vals.append(10)
    iter_vals.append(25); iter_vals.append(50); iter_vals.append(100)

    for ii in range(len(iter_vals)):
        var n_it = iter_vals[ii]

        var pi = List[Float64]()
        pi.append(0.6); pi.append(0.4)
        var A = zeros(NST, NST)
        A[0*NST+0]=0.7; A[0*NST+1]=0.3
        A[1*NST+0]=0.2; A[1*NST+1]=0.8
        var B = zeros(NST, NOB)
        for o in range(NOB):
            B[0*NOB+o] = 1.0/6.0
        for o in range(5):
            B[1*NOB+o] = 0.12
        B[1*NOB+5] = 0.40

        baum_welch(obs, T, NST, NOB, n_it, pi, A, B)

        var alpha = zeros(T, NST)
        var log_p = forward(obs, T, pi, A, B, NST, NOB, alpha)
        print("  n_iter=" + String(n_it) +
              "  log-likelihood=" + String(Int(log_p * 100)) + "e-2")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 60)
    print("  Hidden Markov Model (HMM) -- Mojo 0.26.2")
    print("  Algorithms: Forward, Backward, Baum-Welch, Viterbi")
    print("=" * 60)

    demo_casino()
    demo_iris()
    param_study()

    print("\n" + "=" * 60)
    print("  HMM complete.")
    print("  Next: 18_adaboost.mojo or 18_isolation_forest.mojo")
    print("=" * 60)
