# Bounded implementation task: create_poll

You are working in discord-mcp: Java 17/Maven, Spring Boot 4.0.2, Spring AI 2.0.0-M4, JDA 6.4.1. Implement only this feature. Do not spawn subagents, commit, push, publish, deploy, read secrets, start the Spring context, or connect to Discord. Do not modify the harness or acceptance criteria to make checks pass.

Read the root `AGENTS.md` first. Then read `pom.xml`, `src/main/java/dev/saseq/services/MessageService.java`, `src/main/java/dev/saseq/configs/DiscordMcpConfig.java`, and the README's Message Management section. MethodToolCallbackProvider already registers MessageService. Reuse its text/news/thread channel resolver; no configuration change is needed. Existing tools return strings and wait for JDA using `.complete()`.

Add `@Tool(name = "create_poll")` on a public method with these parameters:
- `String channelId`: required, nonblank.
- `String question`: required, nonblank, at most 300 characters according to JDA's rules.
- `List<String> answers`: required, 2-10 nonblank answer strings, at most 55 characters each according to JDA's rules.
- `Integer durationHours`: optional, default 24, inclusive range 1-168.
- `Boolean allowMultiselect`: optional, default false.

Annotate parameters with ToolParam, English descriptions, and required=false for both optional parameters. Use MessagePollData/its builder and sendMessagePoll. Verify signatures against JDA **6.4.1**; do not upgrade any dependency. Validate content before sending. Reuse JDA constants/validation instead of duplicating their internal rules. Return the created message's ID and jump URL. Propagate errors without reporting false success. Do not add a create_pool alias or any other tool.

Allowed changes: pom.xml (test dependency only), MessageService.java, README.md, and new tests under src/test/java/dev/saseq/. Follow the existing style and avoid unrelated refactoring.

Add spring-boot-starter-test with test scope. Write JUnit/Mockito tests without @SpringBootTest:
1. Capture the actual poll payload; verify answer text/order, default/custom options, exactly one send, and the returned ID/URL.
2. Accepted boundaries: 2/10 answers, 300-character question, 55-character answer, 1/168 hours, multiselect true/false.
3. Null/empty/blank inputs, overly long text, 0/1/11 answers, null answer element, and durations -1/0/169: error and no send.
4. Text/news/thread resolution, unknown channel, and propagated JDA/permission failures without false success.
5. Use the real MethodToolCallbackProvider: unique tool name, existing tools preserved; parse the generated JSON Schema and assert types and required/optional fields. Invoke the callback with actual JSON, first omitting optional fields, then supplying them, to verify List<String>/Integer/Boolean deserialization.

Start with `bash scripts/verify.sh --baseline`. Observe the new tests fail for the expected reason before implementation, then pass afterwards. Finish with `bash scripts/verify.sh` and `git diff --check`. The harness requires bash/git/rg/python3 and either Java+Maven or Docker. If the environment prevents a check, report the exact blocker; do not claim success or modify the machine to bypass it.

Document the tool in README with a JSON example (answers array, numeric duration, boolean multiselect), limits, defaults, and View Channel / Send Messages or Send Messages in Threads / Send Polls permissions. Do not extend support to DMs or creating forum posts.

Stop after implementation and verification. Return a short factual report: changed files, checks actually executed and results, remaining limitations. Make at most two repair attempts after a validation failure; after that, report the diagnosis and leave the diff for review.
