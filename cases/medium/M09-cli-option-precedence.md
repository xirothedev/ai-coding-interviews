# M09 — CLI Subcommand Option Parser & Env-Var Fallback Precedence

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `M09` |
| **Difficulty Level** | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar) |
| **Task Archetype** | Bugfix + Feature Extension |
| **Source GitHub Repository** | [`pallets/click`](https://github.com/pallets/click) (Python) · [`tj/commander.js`](https://github.com/tj/commander.js) (TypeScript) |
| **Target Files** | `src/click/core.py`, `src/click/types.py`, `tests/test_options.py`, `tests/test_context.py` |
| **Supported Languages** | `Python`, `TypeScript`, `Go`, `Rust` |
| **Primary AI Traps** | Falsy CLI value (`False`, `0`, `""`) falling through `cli_val or env_val or default` · Mutating `default_map` across subcommands |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning
```bash
git clone https://github.com/pallets/click.git click-interview
cd click-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest tests/test_options.py
```

### Seeded Defects to Inject Before the Session
1. **Bug 1 (Falsy CLI Value Overridden by Environment Variable / Config)**: In parameter value resolution (`Option.consume_value` / `Parameter.Full_process_value`), use truthiness (`if not value:`) or `cli_val or env_val or default` so that passing `--retries 0`, `--prefix ""`, or `--no-verify` (`False`) on the command line is ignored when `APP_RETRIES=5` or `APP_VERIFY=true` is set in `os.environ`!
2. **Bug 2 (Boolean String Parsing in Environment Variables)**: Setting `APP_VERIFY="false"` or `APP_VERIFY="0"` in `os.environ` evaluates `bool("false") == True` in Python/JS if not parsed through the boolean type converter!

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working on the parameter and option resolution engine of a CLI framework (`pallets/click` / `commander.js`). You have full access to the AI Assistant and test runner.
>
> ### Problem Context
> CLI options can receive values from **4 distinct sources**, ordered from highest to lowest priority:
> `1. COMMANDLINE (Explicit CLI flag) > 2. ENVIRONMENT (Env var) > 3. DEFAULT_MAP (Config file dictionary) > 4. DEFAULT (Option definition default)`
>
> Users have reported three critical bugs:
> 1. **Falsy Explicit CLI Values Ignored**:
>    - When `APP_RETRIES=3` is set in the environment and the user runs `cli --retries 0`, the resolved value is `3` instead of `0`!
>    - Similarly, when `APP_SSL=true` is in the environment and the user runs `cli --no-ssl` (which passes `False`), `ssl` resolves to `True`!
>    - Passing `--tag ""` (empty string) on the CLI falls back to `DEFAULT` instead of keeping `""`.
> 2. **Environment Variable Boolean & Multiple-Value Parsing**:
>    - Setting `APP_SSL=false`, `APP_SSL=0`, or `APP_SSL=no` in `os.environ` must resolve to `False` (never `bool("false") == True`!), while `APP_SSL=""` (empty env var) should be treated as unset unless the option type is `STRING` with explicit empty support.
>    - For options with `multiple=True` and `envvar="APP_TAGS"`, `APP_TAGS="alpha,beta,gamma"` (or `os.pathsep` / custom `envvar_sep`) must split cleanly into `("alpha", "beta", "gamma")` without turning `APP_TAGS=""` into `("",)`.
> 3. **Source Attribution API (`ctx.get_parameter_source(name)`)**:
>    - Ensure `ctx.get_parameter_source(param_name)` accurately returns `ParameterSource.COMMANDLINE`, `ParameterSource.ENVIRONMENT`, `ParameterSource.DEFAULT_MAP`, or `ParameterSource.DEFAULT` for every resolved parameter—even when the CLI value equals the default value (e.g., default is `0` and user explicitly passed `--retries 0` on the CLI → source MUST be `COMMANDLINE`, not `DEFAULT`!).
>
> ### Your Tasks
> 1. **Explore & Trace**: Inspect `Parameter.consume_value()` and `Option.value_from_envvar()` in `src/click/core.py`.
> 2. **Run & Uncomment Tests**: Run `pytest tests/test_options.py tests/test_context.py` and uncomment the falsy-override and `ParameterSource` tests.
> 3. **Fix Precedence, Env-Var Conversion & Source Tracking**: Fix all three issues cleanly.
> 4. **Verify Edge Cases**: Test `--retries 0` when default is `0` (`source == COMMANDLINE`), `APP_FLAG=false`, `multiple=True` with empty env var, and nested subcommands (`cli --verbose subcmd`).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Comparing `if value == self.default: source = ParameterSource.DEFAULT`
- **What Naive AI Writes**:
  ```python
  # AI tries to infer ParameterSource after the fact:
  if value == self.default:
      source = ParameterSource.DEFAULT
  ```
- **Why It Fails**: If `default = 0` and the user explicitly runs `my-cli --retries 0`, `value == self.default` (`0 == 0`) is `True`, so the AI falsely reports `ParameterSource.DEFAULT` instead of `ParameterSource.COMMANDLINE`! (And in Python, `False == 0` and `True == 1` in value comparisons!)
- **Correct Fix**: Use a unique sentinel object (`_UNSET = object()`) during `consume_value()` and record `(value, ParameterSource)` at the exact step where the value is found (`opts` dict → `COMMANDLINE`, `default_map` → `DEFAULT_MAP`, `envvar` → `ENVIRONMENT`, fallback → `DEFAULT`).

### Trap 2: Splitting Empty Env String `"".split(",") -> [""]` for `multiple=True`
- **What Naive AI Writes**:
  ```python
  return os.environ.get(self.envvar).split(",")
  ```
- **Why It Fails**: In Python and JavaScript, `"".split(",")` returns `[""]` (a 1-element list containing an empty string) instead of `[]`!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > *"Do not write code. Trace `Parameter.consume_value`, `Option.consume_value`, and `Option.value_from_envvar` in `src/click/core.py`. Show how `ParameterSource` is currently set on `ctx`."*
2. **Step 2 (`Plan`)**:
   - Candidate plans sentinel-based `is not _UNSET` checks at each of the 4 precedence tiers and checks `value_from_envvar` empty-string handling.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt the changes in `core.py`; audit for any truthiness check (`if val:` or `val or ...`) and `"".split()`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Separates the 4-tier lookup sentinel logic in `consume_value` from string-to-type conversion in `value_from_envvar` / `type_cast_value`. | Hacks special cases for `False` and `0` while leaving `""` and `[]` broken. |
| **2** | **Prompt Context Quality** | Specifies sentinel identity check (`is not UNSET`), `ParameterSource` tracking during lookup, and empty env string behavior. | Prompts *"Fix falsy CLI values in `core.py`"*. |
| **3** | **Not Blindly Trusting AI** | Catches `"".split(",") == [""]` and `False == 0` in Python value comparisons when auditing AI diffs. | Accepts `if val is not None:` without noticing `consume_value` uses `UNSET` (when `None` can be an explicit value!). |
| **4** | **Code Reading Speed** | Traces `handle_parse_result -> consume_value -> process_value` in `src/click/core.py` within 8 minutes. | Edits parser tokenizer (`parser.py`) instead of parameter consumption (`core.py`). |
| **5** | **Bug & Edge-Case Discovery** | Tests `--count 0` (when default is `0`), `--no-flag` with `ENV=1`, `ENV="0"` vs `ENV="false"`, and `ENV=""` on `multiple=True`. | Misses the test where explicit CLI value equals the default value (`--count 0` with `default=0`). |
| **6** | **Testing Before Claiming Done** | Runs `pytest tests/test_options.py tests/test_context.py` after each edit. | Runs only 1 test and breaks existing `test_options.py` cases. |
| **7** | **Explaining Correctness** | Explains why sentinel identity (`val is _UNSET`) is required over `None` or equality checks (`==`) in dynamic languages. | Cannot explain why `False == 0` in Python causes bugs when checking defaults in sets/dicts. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"In Python, why is even `if value is not None:` sometimes insufficient as a sentinel check in a configuration parser?"*  
   **Expected Answer**: Because a user or `default_map` might explicitly pass `None` to unset/disable an optional setting! Using a private singleton sentinel `_UNSET = object()` and checking `if value is not _UNSET:` distinguishes "not provided" from an explicit `None`, `False`, `0`, or `""`.
