---
name: generate-unit-tests
description: >-
  Generate unit tests for code that was added or changed on the current working
  branch, using an optional PDF spec as domain context. Use when the user asks to
  "write tests for my branch / my changes", "cover the new code with unit tests",
  "generate tests from this spec", or points at a spec PDF plus a feature branch.
  Detects the project (mbp, core-module, dataaccesslayer, admin-portal, revpal,
  supplier-api, or unknown) and follows that project's test conventions.
---

# Generate unit tests for branch changes

Generate focused unit tests for the **delta** on the current branch — new and modified
production code — matching the host project's existing test style. A PDF spec, if
supplied, is read **for context only** (domain rules, terminology, edge cases to think
about); it is not a machine-checkable oracle. Tests assert what the code contract implies.

## Inputs

Invoked as `/generate-unit-tests [spec.pdf ...] [base-ref]` — all arguments optional.

- **Spec PDFs** — any argument that is a path to a `.pdf` (or an existing file). Zero, one, or many.
- **Base ref** — an argument that is a git ref rather than a file (e.g. `origin/master`, `develop`, a SHA, a tag). Overrides the default diff base.
- If the user named a spec or branch in prose instead of as an argument, use that.

## Workflow

### 1. Locate repo and detect the project profile

```bash
git -C . rev-parse --show-toplevel
```

Match the repo (folder name, and `<artifactId>` in `pom.xml`) against the table below.
If it matches none, build an ad-hoc profile: read `pom.xml` / `build.gradle` for the
test framework and mock library, and open 2–3 existing `*Test` files nearest the changed
code to copy their runner, assertion style, and fixtures.

| Project | Repo | Test root | Framework | Mocking / assertions | Run a single test |
|---|---|---|---|---|---|
| **mbp** | `~/Projects/mbp` | `test/` — mirrors `src/` package path, **not** `src/test/java` | JUnit 4 (`org.junit.Test`, `org.junit.Assert`) | Mockito + PowerMock: `@RunWith(PowerMockRunner.class)`, `@PrepareForTest({...})`, `@Mock` / `@InjectMocks`, `PowerMockito.mockStatic` | Maven wrapper is **broken** here (`-Xbootclasspath/p` + jaxws `wsimport`). Use IDE MCP: `mcp__idea__build_project` (`filesToRebuild`), then `mcp__idea__get_run_configurations` + `mcp__idea__execute_run_configuration`. |
| **core-module** | `~/Projects/core-module` | `src/test/java` | JUnit 4 | `mockito-all` (Mockito 1.x API), `org.junit.Assert` | `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false` |
| **dataaccesslayer** | `~/Projects/dataaccesslayer` | `src/test/java` | JUnit 4, **plain** (no Mockito dependency) | Hand-built stubs/fakes, `org.junit.Assert` | `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false` |
| **admin-portal** | `~/Projects/admin-portal` | `src/test/java` | JUnit 5 (Jupiter) + Spring Boot Test | `@WebMvcTest` + `MockMvc`, `@MockBean`, Mockito, AssertJ `assertThat` | `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false` |
| **revpal** | `~/Projects/revpal` | `src/test/java` | JUnit 5 | `@ExtendWith(MockitoExtension.class)`, `@Mock` / `@InjectMocks`, AssertJ `assertThat`, `ReflectionTestUtils` for privates | `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false` |
| **supplier-api** | `~/Projects/supplier-api` | `src/test/java` | JUnit 5 + Spring Boot Test — **no Java unit-test precedent yet**; follow the revpal / admin-portal style | Mockito + AssertJ | `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false`. The `supplier-api-4-tests` sibling is a JS/WDIO integration suite — out of scope. |

Package bases: mbp `com.mybookingpal` · core-module `com.bookingpal.core`, `com.mybookingpal.dal` · admin-portal `com.mybookingpal.admin` · revpal / supplier-api `com.mybookingpal`.

Full detail: `references/project-profiles.md`.

### 2. Compute the change set

- **Base ref**: the explicit argument if given; otherwise the merge-base with the main branch:
  ```bash
  git merge-base HEAD master 2>/dev/null || git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD main
  ```
- Changed production files (committed on the branch **and** uncommitted):
  ```bash
  git diff --name-only <base>...HEAD
  git status --porcelain
  git diff <base>...HEAD -- <file>      # actual hunks, per file
  git diff -- <file>                     # uncommitted hunks
  ```
- Keep only production sources in the project language. Drop test files, resources,
  generated sources (`target/`, `generated-sources/`, `*.xml` mappers unless logic lives there),
  config, and pure data/DTO classes.

### 3. Read the spec PDFs (context only)

For each PDF:
```bash
pdftotext -layout "<spec.pdf>" -    # try text first
```
If that is empty the PDF is image-only — render and read it in slices:
```bash
pdftoppm -png -r 200 "<spec.pdf>" <scratchpad>/spec
# then crop tall pages into strips with PIL (Image.MAX_IMAGE_PIXELS = None) and Read them
```
Pull out: business rules, domain vocabulary, worked examples, boundary conditions,
"must / must not" statements. Hold these as **context** — they guide which cases to test
and how to name them. Do not invent assertions the code does not support; if the spec
clearly contradicts the code, note it in the report rather than encoding either side blindly.

### 4. Build the coverage checklist

For every changed production file, list the units that need tests:

- new public / package-private methods;
- modified methods — focus on **what changed**: new branches, new parameters, altered
  calculations, new early-returns / fallbacks, changed exception behavior;
- new classes and their construction / validation logic.

Skip trivial getters/setters, `toString`, `equals`/`hashCode`, and generated code unless
they carry logic. For each unit enumerate the paths to cover: happy path, **each new
conditional branch**, null / empty / zero inputs, boundary values, and error/exception paths.

### 5. Study local test conventions

Open the closest existing tests — same package under the test root, or tests of the
class's collaborators. Copy their: runner and annotations, mock setup, assertion library,
fixture / builder helpers, test-method naming (`testXxx` vs `xxx_shouldYyy_whenZzz`),
and how they handle statics, time, and DB. New tests must look like they were written by
the same team.

### 6. Write the tests

- Location: the project's test root, mirroring the production package.
- If a `*Test` class already exists for the target class → **add methods to it**, matching
  its style. Otherwise create a new test class next to where it would belong.
- One behavior per test. Arrange / Act / Assert. Names describe the changed behavior and,
  where useful, borrow spec terminology.
- Mock only collaborators, per the project's mock convention. Prefer real objects for
  value types and pure functions.
- Cover every item from the step-4 checklist, including the fallback / edge branches that
  are easy to forget.
- To test a private method, prefer making it package-private (note it in the report), or
  use the project's existing reflection helper (`ReflectionTestUtils`, PowerMock `Whitebox`).
- **Do not** modify production code, delete existing tests, or rewrite unrelated tests.

### 7. Compile, run, iterate to green

1. Compile: IDE MCP `mcp__idea__build_project` with `filesToRebuild`, else the project's Maven command.
2. Run the new/changed test classes only (IDE run-config or `-Dtest=`).
3. Iterate on failures, **max ~3 rounds**:
   - compile errors, wrong mock signatures, missing fixtures → fix the test;
   - an assertion failure that reveals a **real defect in the production code** → **stop**,
     do not weaken the assertion; report the finding with the failing case.
4. If the build/test environment itself is broken (e.g. mbp Maven, a missing local DB,
   `wsimport` failure) → stop after confirming the tests **compile**, and say plainly in
   the report which checks ran and which did not. **Never report tests as passing if they
   were not executed.**

### 8. Report

- Project + profile detected; base ref; production files considered.
- Test files created / modified, with the list of new test methods.
- Coverage checklist: what is covered, what was intentionally left out and why.
- Run result: compiled? executed? passed? — or exactly what blocked execution.
- Any spec-vs-implementation discrepancies noticed.
- Any real bugs the tests surfaced.

## Guardrails

- Production code is read-only unless the user explicitly asks for a fix.
- Minimal diffs; match surrounding style exactly.
- If the branch has no testable production changes, say so instead of inventing tests.
- Don't chase coverage of untouched code — the mandate is the branch delta.
