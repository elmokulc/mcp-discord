# Repository guidance

## Project map

This repository implements a Discord MCP server with Java 17, Maven, Spring Boot,
Spring AI, and JDA. Check `pom.xml` for the pinned dependency versions; do not
upgrade dependencies as part of an unrelated feature.

- `src/main/java/dev/saseq/services/`: Discord operations exposed as MCP tools.
- `src/main/java/dev/saseq/configs/DiscordMcpConfig.java`: JDA startup and the
  `MethodToolCallbackProvider` service registry.
- `src/main/resources/application.properties`: default stdio transport.
- `src/main/resources/application-http.properties`: optional HTTP transport.
- `README.md`: public tool list, setup, and usage.
- `scripts/verify.sh`: build and test harness.
- `docs/tasks/`: bounded implementation briefs with acceptance criteria.

## Implementation conventions

Use constructor injection and follow the surrounding service's style. MCP tools
use `@Tool` and `@ToolParam`, English descriptions, and explicit optional parameter
annotations. Preserve existing tool names, signatures, and behavior.

Current tools return strings, execute JDA requests with `.complete()`, and propagate
validation/JDA errors. Report success only after the operation completes. Validate
inputs before sending requests. Prefer existing channel resolvers and JDA builders
and constants to new infrastructure. Compile against the pinned JDA version rather
than assuming the latest online API matches it.

`MessageService` already resolves cached text channels, announcement channels, and
threads. It is already registered in `discordTools()`; another annotated method in
that service does not require a new service or a registry change.

## Verification

Run commands from the repository root:

```bash
bash scripts/verify.sh --baseline  # inspect the initial build, even without tests
bash scripts/verify.sh             # final build; requires executed tests
git diff --check
```

The harness needs bash, git, rg, python3, and either Java/Maven or Docker. Docker
verification uses a disposable pom/src snapshot and saves results under
`target/harness/`. The baseline is not a substitute for final verification. The
existing Dockerfile skips tests, so building an image alone is insufficient.

For tool changes, add focused JUnit/Mockito tests and exercise the real Spring AI
callback conversion/schema where relevant. Instantiate services with mocked JDA;
avoid `@SpringBootTest`. Starting this application creates a real Discord connection
and can exit the process when configuration is missing. No bot token is needed for
unit tests. Do not weaken tests or modify the harness to conceal failures.

## Scope and handoff

Follow the current user request and its task brief. Keep changes within that scope;
preserve unrelated work. Do not read credentials, use the live bot, commit, push,
publish, or deploy unless the user explicitly requests those actions.

For `create_poll`, read `docs/tasks/create-poll.md` for the contract, allowed files,
test matrix, and stopping criteria. `docs/create-poll-plan.md` contains the French
planning rationale; the English brief contains the implementation requirements.
Use `harness/opencode-qwen.json` when launching the delegated Qwen session. Keep the
session focused; do not spawn subagents or switch providers for this task.

Report changed files, checks actually executed and their results, and remaining
blockers. Never claim a check passed when it was not run. Keep the final report
short and leave the diff available for review.
