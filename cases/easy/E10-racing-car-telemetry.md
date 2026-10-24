# E10 — Racing Car Telemetry Alarm & Sliding Window Drift Detector

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                     |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E10`                                                                                                                                                                                                                       |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                                                                                               |
| **Task Archetype**           | System Component Integration & Stateful Stream Filtering                                                                                                                                                                    |
| **Source GitHub Repository** | [`emilybache/Racing-Car-Katas`](https://github.com/emilybache/Racing-Car-Katas) (`TirePressureMonitoringSystem`)                                                                                                            |
| **Target Files**             | `tire_pressure_monitoring.py`, `sensor.py`, `test_tire_pressure_monitoring.py` _(in `Python/TirePressureMonitoringSystem/`, or `TypeScript/`, `go/`, `Java/`, `Rust/tire_pressure_monitoring_system/`, `CSharp/`)_          |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                                                                                          |
| **Primary AI Traps**         | Overwriting latched `is_alarm_on = True` back to `False` on next normal reading · Breaking zero-arg `Alarm()` constructor · Checking pressure drop only across 2 consecutive samples instead of the 3-sample sliding window |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/Racing-Car-Katas.git racing-car-interview
cd racing-car-interview/Python/TirePressureMonitoringSystem # (or TypeScript / go / Java / Rust/tire_pressure_monitoring_system / CSharp)
rm -rf ../../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Hardcoded `Sensor()` Dependency & Inclusive/Exclusive Threshold Bug)**: In `tire_pressure_monitoring.py`, `Alarm.__init__` hardcodes `self._sensor = Sensor()` (which uses random numbers, making deterministic unit tests impossible without DI!) and checks `< 17` / `> 21` with an off-by-one or resets `self._is_alarm_on = False` when a normal reading follows an alarm!
2. **Commented Tests**: Comment out `test_alarm_latches_on_until_reset`, `test_transient_spike_debounced`, and `test_gradual_three_sample_pressure_drop` in `test_tire_pressure_monitoring.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the Formula 1 Tire Pressure Monitoring System (`TirePressureMonitoringSystem` in `Racing-Car-Katas`). You have full access to the AI Assistant and `pytest`.
>
> ### Problem Context
>
> 1. **Dependency Injection & Safety-Latch Bug**:
>    - Refactor `Alarm` so a custom/mock `sensor` can be passed to `Alarm(sensor=...)`, while **preserving backward compatibility** for existing callers that call `Alarm()` with zero arguments!
>    - **Safety-Latch Invariant**: Once `is_alarm_on` triggers (`True`), subsequent normal `check()` readings MUST NOT silence the alarm! It must remain `True` until an explicit `alarm.reset()` method is called (which resets both `is_alarm_on` and the sliding window history).
> 2. **New Feature — Debounced Spike Filtering & 3-Sample Rapid Puncture Detector**:
>    - Normal operating range is **`17.0 <= psi <= 21.0`** (inclusive).
>    - **Rule A — Critical Extreme Bounds (`< 15.0` or `> 23.0`)**: Any single reading strictly `< 15.0` or `> 23.0` triggers the alarm **immediately** on that first reading.
>    - **Rule B — Debounced Minor Out-of-Range (`[15.0, 17.0)` or `(21.0, 23.0]`)**: A single transient reading in `[15.0, 17.0)` or `(21.0, 23.0]` does **NOT** trigger the alarm by itself; the alarm triggers only if **2 consecutive readings** are outside `[17.0, 21.0]`.
>    - **Rule C — 3-Sample Rapid Pressure Drop (Slow Puncture Detector)**: Even if all readings remain inside `[17.0, 21.0]`, if the current reading has dropped by **`>= 3.0 psi`** compared to either the reading 1 step ago OR the reading 2 steps ago (i.e., within the last 3 readings `[r_{t-2}, r_{t-1}, r_t]`, `max(r_{t-2}, r_{t-1}) - r_t >= 3.0`, e.g., `20.8 -> 19.2 -> 17.5`), trigger the alarm immediately!
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect `tire_pressure_monitoring.py`, `sensor.py`, and `test_tire_pressure_monitoring.py`. Run `pytest`.
> 2. **Uncomment & Fix Latch / DI**: Make `sensor` injectable (`sensor: Sensor | None = None`), fix the safety-latch invariant, and add `reset()`.
> 3. **Implement Rules A, B & C**: Implement critical bounds, 2-sample debounce, and the 3-sample `>= 3.0 psi` puncture drop detector.
> 4. **Verify Edge Cases**: Test `[16.5, 19.0, 16.5]` (non-consecutive minor spikes → alarm stays `False`!), `[20.8, 19.2, 17.5]` (all inside `[17, 21]`, but `20.8 - 17.5 = 3.3 >= 3.0` → alarm `True`!), and `reset()` clearing the history buffer.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Overwriting `self._is_alarm_on = ...` on Every `check()` Call

- **What Naive AI Writes**:
  ```python
  self._is_alarm_on = is_critical or is_two_consecutive_out or is_rapid_drop
  ```
- **Why It Fails**: If `check()` #1 triggers the alarm (`True`) and `check()` #2 reads `19.0` (`False`), assigning `self._is_alarm_on = ...` overwrites `True` with `False`, violating the **Safety-Latch Invariant**!
- **Correct Fix**: Use `if should_trigger: self._is_alarm_on = True` (or `self._is_alarm_on = self._is_alarm_on or should_trigger`), and only clear `self._is_alarm_on = False` inside `reset()`!

### Trap 2: Not Clearing Sliding Window History in `reset()`

- **What Naive AI Writes**:
  ```python
  def reset(self) -> None:
      self._is_alarm_on = False
      # Forgets to clear self._history!
  ```
- **Why It Fails**: If `check()` recorded `20.9`, triggered an alarm on `14.0`, and the pit crew calls `alarm.reset()` and inflates the tire to `17.8`, the next `check()` compares `17.8` against the pre-reset reading `20.9` (`20.9 - 17.8 = 3.1 >= 3.0`) and falsely triggers a puncture alarm!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read `tire_pressure_monitoring.py` and `test_tire_pressure_monitoring.py` and list the existing constructor signature and properties."_
2. **Step 2 (`Plan`)**:
   - Keep `def __init__(self, sensor=None): self._sensor = sensor or Sensor()`; store `self._recent_readings = deque(maxlen=3)` and `self._consecutive_out_of_bounds = 0`; evaluate Rules A, B, C cleanly; latch `self._is_alarm_on = True`; clear `_is_alarm_on`, `_recent_readings`, and `_consecutive_out_of_bounds` in `reset()`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Audit `reset()` to ensure all state variables (`_recent_readings`, `_consecutive_out_of_bounds`, `_is_alarm_on`) are reset.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                  | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                              |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates DI refactoring, stateful sliding-window tracking (`deque(maxlen=3)`), and the 3 alarm predicate rules.                  | Writes tangled index arithmetic (`readings[-1]`, `readings[-2]`) that crashes with `IndexError` on the first reading. |
| **2** | **Prompt Context Quality**       | Specifies preserving zero-arg `Alarm()`, latching `_is_alarm_on`, and clearing history on `reset()`.                              | Prompts _"Update `tire_pressure_monitoring.py` with the new rules"_.                                                  |
| **3** | **Not Blindly Trusting AI**      | Checks whether `reset()` clears `_history` / `_consecutive_out` and whether a normal reading un-latches `_is_alarm_on`.           | Accepts AI code where `reset()` leaves old readings in `self._history`.                                               |
| **4** | **Code Reading Speed**           | Reads `tire_pressure_monitoring.py` and `sensor.py` in 2 minutes and spots the hardcoded `Sensor()` instantiation.                | Breaks existing zero-arg `Alarm()` tests by making `sensor` a required positional argument.                           |
| **5** | **Bug & Edge-Case Discovery**    | Tests `[16.5, 19.0, 16.5]` (alternating spikes), `[20.8, 19.2, 17.5]` (3-sample drop), and post-`reset()` readings.               | Misses testing readings _after_ `reset()` is called.                                                                  |
| **6** | **Testing Before Claiming Done** | Writes a deterministic `StubSensor([r1, r2, r3])` helper in `test_tire_pressure_monitoring.py` and tests all 3 rules + `reset()`. | Uses `unittest.mock.patch` clumsily or doesn't test multi-step sequences.                                             |
| **7** | **Explaining Correctness**       | Explains bounded memory $O(1)$ (`deque(maxlen=3)`) and why safety alarms use a latch (`S-R flip-flop`) pattern.                   | Cannot explain what happens on the first `check()` after `reset()` if history isn't cleared.                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What happens on the very first `check()` call after `alarm.reset()` if `reset()` sets `_is_alarm_on = False` but forgets to clear the sliding window of previous readings?"_  
   **Expected Answer**: Stale readings from before `reset()` (such as a high pressure reading `21.0` or an out-of-bounds reading `16.0`) remain in the window, causing the first normal post-reset reading (`17.9`) to falsely trigger either the `>= 3.0 psi` drop rule or the 2-consecutive out-of-bounds rule!
