# Project test profiles

Detail behind the table in `SKILL.md`. Verify against the repo before relying on any
line here — conventions drift.

## mbp — `~/Projects/mbp`

- **Build**: Ant (`build.xml`) + Maven (`pom.xml`), Java 8 target (`<source>1.8</source>`).
- **Test root**: `test/` at repo root. Package path mirrors `src/`, e.g.
  `test/com/mybookingpal/utils/payment/FooTest.java` for
  `src/com/mybookingpal/utils/payment/Foo.java`.
- **Framework**: JUnit 4 — `import org.junit.Test;`, `import org.junit.Assert;`,
  `@Before`, `@BeforeClass`. (A single JUnit 5 file exists; ignore it — 240+ files are JUnit 4.)
- **Mocking**: Mockito + PowerMock.
  ```java
  @RunWith(PowerMockRunner.class)
  @PrepareForTest({ RazorServer.class, PaymentHelper.class, /* every class whose statics you stub */ })
  public class FooTest {
      @Mock private SomeDao someDao;
      @InjectMocks private Foo foo;

      @BeforeClass public static void setUp() { PowerMockito.mockStatic(ImageService.class); /* ... */ }
      @Before public void init() { PowerMockito.mockStatic(RazorServer.class);
          PowerMockito.when(RazorServer.openSession()).thenReturn(sqlSession); }
  }
  ```
- **Assertions**: `Assert.assertEquals`, `Assert.assertTrue`, etc. For `BigDecimalExt`
  compare with `compareTo` (`Assert.assertEquals(0, expected.compareTo(actual))`), not `equals`.
- **Running**: the Maven wrapper fails in this environment
  (`-Xbootclasspath/p is no longer a supported option`, plus `jaxws-maven-plugin:wsimport`).
  Use the IDE MCP tools:
  - `mcp__idea__build_project` with `filesToRebuild: ["src/.../Foo.java", "test/.../FooTest.java"]`
  - `mcp__idea__get_run_configurations` with `filePath` to get run points, then
    `mcp__idea__execute_run_configuration` with `filePath` + `line`.
  - The IDE test runner can itself time out / fail to start — if so, report "compiles, not executed".

## core-module — `~/Projects/core-module`

- **Build**: Maven. Shared library (also checked out under other paths).
- **Test root**: `src/test/java`.
- **Framework**: JUnit 4 (`junit`), `org.junit.Assert` / `org.junit.Test`.
- **Mocking**: `mockito-all` — the old Mockito 1.x single-jar. `Mockito.mock`, `Mockito.when`,
  `@RunWith(MockitoJUnitRunner.class)`. No PowerMock.
- **Packages**: `com.bookingpal.core.*`, `com.mybookingpal.dal.*`.
- **Run**: `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false` from the repo root.

## dataaccesslayer — `~/Projects/dataaccesslayer`

- **Build**: Maven. DAL / persistence layer.
- **Test root**: `src/test/java` (note: some tests sit in a bare `utils` package).
- **Framework**: JUnit 4, `junit` only — **no Mockito dependency**. Tests use plain
  fixtures and hand-written stub/fake implementations of interfaces.
- **Run**: `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false`.
- If a change genuinely needs mocking, prefer a small local fake class over adding a dependency.

## admin-portal — `~/Projects/admin-portal`

- **Build**: Maven, Spring Boot (`spring-boot-starter-test`).
- **Test root**: `src/test/java`, base package `com.mybookingpal.admin`.
- **Framework**: JUnit 5 (`org.junit.jupiter.api.Test`).
- **Web layer**: `@WebMvcTest(TheController.class)` + `@AutoConfigureMockMvc`, inject
  `MockMvc`, collaborators as `@MockBean`, drive with `mockMvc.perform(...)` and
  `andExpect(...)`. `@ActiveProfiles("test")` where existing tests use it.
- **Assertions**: AssertJ `assertThat`, Mockito `verify` / `when`.
- **Run**: `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false`.

## revpal — `~/Projects/revpal`

- **Build**: Maven, Spring Boot. Small test suite — lots of room, keep it idiomatic.
- **Test root**: `src/test/java`, base package `com.mybookingpal`.
- **Framework**: JUnit 5 with `@ExtendWith(MockitoExtension.class)`.
  ```java
  @ExtendWith(MockitoExtension.class)
  class UserServiceTest {
      @Mock UserRepository repo;
      @InjectMocks UserService service;
      @Test void loadUser_returnsMappedDto_whenFound() { ... assertThat(...) ... }
  }
  ```
- **Assertions**: AssertJ `assertThat`. `ArgumentCaptor` for interaction detail.
- **Privates / field injection**: `org.springframework.test.util.ReflectionTestUtils`.
- **Run**: `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false`.

## supplier-api — `~/Projects/supplier-api`

- **Build**: Maven, Spring Boot (`spring-boot-starter-test` on the classpath).
- **Test root**: `src/test/java`, base package `com.mybookingpal`. **No Java unit tests
  exist yet** — establish the pattern by following revpal (service-layer:
  `@ExtendWith(MockitoExtension.class)`) or admin-portal (web-layer: `@WebMvcTest`).
- **Out of scope**: the sibling `~/Projects/supplier-api-4-tests` is a WebdriverIO / JS
  API integration suite, not unit tests.
- **Run**: `mvn -o -q test -Dtest=<Class> -DfailIfNoTests=false`.

## Unknown project

1. `git rev-parse --show-toplevel`; read `pom.xml` / `build.gradle`:
   - test framework: `junit-jupiter` → JUnit 5; `junit` 4.x → JUnit 4.
   - mock lib: `mockito-junit-jupiter` / `mockito-core` / `mockito-all` / `powermock` / none.
   - Spring Boot present → expect `@SpringBootTest` / slice annotations.
2. `find . -path '*/test/*' -name '*Test*.java'` — open the 2–3 nearest the changed code
   and copy their structure verbatim.
3. Test root is almost always `src/test/java`; confirm by where existing tests live
   (mbp's flat `test/` is the exception).
4. Discover the single-test command from the build tool (`mvn -Dtest=`, `gradle test --tests`).
