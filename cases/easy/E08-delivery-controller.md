# E08 — Delivery Controller Event Replay & Next-Stop ETA

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                                 |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E08`                                                                                                                                                                                   |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                                                           |
| **Task Archetype**           | Bugfix + Dependency Injection + Idempotent Webhook Handling                                                                                                                             |
| **Source GitHub Repository** | [`emilybache/DeliveryController-Refactoring-Kata`](https://github.com/emilybache/DeliveryController-Refactoring-Kata)                                                                   |
| **Target Files**             | `delivery_controller.py`, `map_service.py`, `email_gateway.py`, `test_delivery_service.py` _(in `python/`, or `typescript/`, `java/`, `csharp/`)_                                       |
| **Supported Languages**      | `Python`, `TypeScript`, `Java`, `C#`                                                                                                                                                    |
| **Primary AI Traps**         | Duplicate `DeliveryEvent` overwriting `delivery.time_of_delivery` (`time_difference == 0` -> flipping late delivery to `on_time = True`!) · Blindly indexing `delivery_schedule[i + 1]` |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/DeliveryController-Refactoring-Kata.git delivery-interview
cd delivery-interview/python # (or typescript / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### How the Existing Codebase Works & Native Defects

In `emilybache/DeliveryController-Refactoring-Kata` (`python/`):

- `DeliveryController(delivery_schedule)` in `delivery_controller.py` instantiates `self.email_gateway = EmailGateway()` (which connects to a live `smtplib.SMTP('localhost')` server in `email_gateway.py`!) and `self.map_service = MapService()` directly inside `__init__`, making `test_delivery_service.py` fail unless dependencies are injected.
- `DeliveryController.update_delivery(delivery_event)` iterates through `self.delivery_schedule`, matches `delivery.id == delivery_event.id`, sets `delivery.arrived = True`, computes `time_difference = delivery_event.time_of_delivery - delivery.time_of_delivery`, marks `delivery.on_time = True` if `time_difference < timedelta(minutes=10)`, overwrites `delivery.time_of_delivery = delivery_event.time_of_delivery`, calls `self.map_service.update_average_speed(...)`, and sends feedback + next-stop ETA emails via `self.email_gateway.send(...)`.
- `MapService.update_average_speed` in `map_service.py` uses `elapsed_time.seconds` instead of `elapsed_time.total_seconds()` (which wraps modulo 24 hours and raises `ZeroDivisionError` when `elapsed_time == 0`).

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the **Delivery Controller** service (`emilybache/DeliveryController-Refactoring-Kata`). You have full access to the AI Assistant and `pytest`.
>
> ### Problem Context
>
> `DeliveryController.update_delivery(delivery_event)` receives GPS arrival events (`DeliveryEvent(id, time_of_delivery, location)`), updates the delivery schedule, recalculates average driving speed via `MapService`, and sends customer notifications via `EmailGateway`.
>
> ### Your Tasks
>
> 1. **Task 1 — Dependency Injection & Core Boundary Fixes**:
>    - Make `email_gateway` and `map_service` injectable in `DeliveryController.__init__(self, delivery_schedule, email_gateway=None, map_service=None)` (defaulting to `EmailGateway()` and `MapService()` for backward compatibility) so unit tests in `test_delivery_service.py` run cleanly without a local SMTP server.
>    - Fix the 10-minute grace window boundary: a delivery arriving within `<= 10 minutes` (`time_difference <= timedelta(minutes=10)`) is `on_time = True`; a delivery arriving `> 10 minutes` late must explicitly have `delivery.on_time = False`.
>    - Fix `MapService.update_average_speed` in `map_service.py` to use `elapsed_time.total_seconds()` instead of `elapsed_time.seconds` (which truncates days), and guard against `elapsed_time.total_seconds() <= 0`.
> 2. **Task 2 — Idempotent Event Replay & Out-of-Order Next-Stop ETA**:
>    - **Idempotent Webhook Replay**: GPS trackers deliver `DeliveryEvent` webhooks with at-least-once semantics. In the current code, `update_delivery` overwrites `delivery.time_of_delivery = delivery_event.time_of_delivery` on arrival. If the same `DeliveryEvent` is replayed a second time for an already-arrived `delivery.id`, the legacy code computes `time_difference = 0`, **flipping a late delivery (`on_time = False`) to `on_time = True` and sending duplicate emails**! Make `update_delivery(delivery_event)` idempotent: if `delivery.arrived` is already `True`, ignore the duplicate replay (do not recompute `on_time`, do not update `map_service`, and do not send duplicate emails).
>    - **Next Unarrived Stop ETA**: When a delivery completes and the controller emails the next customer on the schedule with an updated ETA, do **not** blindly index `self.delivery_schedule[i + 1]` if `delivery_schedule[i + 1]` has already arrived out-of-order! Instead, select the next **unarrived** (`not d.arrived`) delivery after index `i` (if any exists).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Checking `if delivery.arrived:` Only Around `email_gateway.send` While Still Mutating `on_time` and `time_of_delivery`

- **What Naive AI Writes**:
  ```python
  time_difference = delivery_event.time_of_delivery - delivery.time_of_delivery
  delivery.on_time = time_difference <= timedelta(minutes=10)
  delivery.time_of_delivery = delivery_event.time_of_delivery
  if not delivery.arrived:
      delivery.arrived = True
      self.email_gateway.send(...)
  ```
- **Why It Fails**: Because `delivery.time_of_delivery` was overwritten on the first delivery event (e.g., `10:25` when scheduled for `10:00`, so `on_time = False`), when the duplicate webhook (`10:25`) arrives a second time, `time_difference` is `10:25 - 10:25 = 0 <= 10m`, which overwrites `delivery.on_time = True`!
- **Correct Fix**: Guard at the very top of the matched delivery block:
  ```python
  if delivery.arrived:
      return
  ```

### Trap 2: Blindly Indexing `delivery_schedule[i + 1]` When Stops Complete Out of Order

- **What Naive AI Writes**:
  ```python
  if len(self.delivery_schedule) > i + 1:
      next_delivery = self.delivery_schedule[i + 1]
      self.email_gateway.send(next_delivery.contact_email, "Your delivery will arrive soon", ...)
  ```
- **Why It Fails**: If Stop #2 (`i = 1`) already arrived early before Stop #1 (`i = 0`), when Stop #1 arrives, `delivery_schedule[0 + 1]` is Stop #2 (which was already delivered!), emailing an ETA to a customer who already received their package while Stop #3 (`i = 2`) gets no ETA email!
- **Correct Fix**:
  ```python
  next_delivery = next((d for d in self.delivery_schedule[i + 1:] if not d.arrived), None)
  ```

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `DeliveryController.update_delivery` in `delivery_controller.py` and `MapService.update_average_speed` in `map_service.py`. Explain why `test_delivery_service.py` fails to run and what happens if the same `DeliveryEvent` is passed to `update_delivery` twice."_
2. **Step 2 (`Plan`)**:
   - Inject `email_gateway` and `map_service` into `DeliveryController.__init__` with defaults; add early return `if delivery.arrived: return`; fix `<= timedelta(minutes=10)` and `else: delivery.on_time = False`; find `next_delivery` via `next((d for d in self.delivery_schedule[i + 1:] if not d.arrived), None)`; fix `total_seconds()` in `map_service.py`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt the changes and write unit tests in `test_delivery_service.py` using a spy/mock `EmailGateway` and `MapService`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                                               | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                        |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Separates constructor DI from idempotent `update_delivery` state transitions and `MapService` math fixes.                                                                      | Leaves `EmailGateway()` hardcoded or mocks `smtplib.SMTP` globally instead of injecting `email_gateway`.                        |
| **2** | **Prompt Context Quality**       | Specifies early return on `delivery.arrived`, `<= timedelta(minutes=10)`, `next((d for d in schedule[i+1:] if not d.arrived), None)`, and `total_seconds()`.                   | Prompts _"Fix the bugs in `delivery_controller.py`"_.                                                                           |
| **3** | **Not Blindly Trusting AI**      | Spots that `delivery.time_of_delivery = delivery_event.time_of_delivery` corrupts `on_time` on duplicate replay unless `if delivery.arrived: return` runs first.               | Accepts AI code that checks `if not delivery.arrived` only around `email_gateway.send()`, allowing `on_time` to flip to `True`. |
| **4** | **Code Reading Speed**           | Quickly diagnoses why `test_delivery_service.py` fails (`ConnectionRefusedError` from `smtplib.SMTP('localhost')`) and spots `.seconds` vs `.total_seconds()`.                 | Wastes time trying to start a local mail server instead of injecting a fake `EmailGateway`.                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests duplicate replay of a late delivery (verifying `on_time` stays `False` and only 1 email is sent), exact 10-minute boundary, and out-of-order stop completion.            | Only tests happy-path on-time single events.                                                                                    |
| **6** | **Testing Before Claiming Done** | Runs `pytest` and asserts exact `email_gateway.send` arguments and call counts.                                                                                                | Claims done without testing duplicate event replay on a late delivery.                                                          |
| **7** | **Explaining Correctness**       | Explains why mutating `delivery.time_of_delivery` in-place makes `update_delivery` non-idempotent unless guarded by `delivery.arrived`, and why `.seconds` truncates `>= 24h`. | Cannot explain the difference between `timedelta.seconds` and `timedelta.total_seconds()` in Python.                            |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Suppose Delivery #1 is scheduled for `10:00` and arrives late at `10:25`. The webhook for `10:25` is delivered twice. What happens to `delivery.on_time` in the original code on the second webhook delivery, and why?"_  
   **Expected Answer**: On the first call, `time_difference` is `25m`, so `on_time` is `False`, and the code sets `delivery.time_of_delivery = 10:25`. On the second call, `time_difference` is `10:25 - 10:25 = 0m < 10m`, which flips `delivery.on_time` to `True` and sends a "regarding your on time delivery" email!
