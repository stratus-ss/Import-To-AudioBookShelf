# Plan Addendum — Infrastructure & Ops

_Last updated: 2026-09-10_

Applies to: SSH deployments, containers, monitoring, DNS, storage, VMs, Ansible, Prometheus/Grafana, reverse proxies, database migrations, network config.

Read this after `PLAN_CORE.md`. All rules here are ADDITIVE — they extend, not replace, the core protocol.

**Code quality:** When this plan produces executable scripts, Ansible playbooks, or Dockerfiles (not pure config-only plans), also read `addenda/code-quality.md`. Pure config-only plans (adding a scrape target, changing a dashboard) are exempt.

---

## A1. ACCESS & CREDENTIAL PREREQUISITES (MANDATORY for plans touching remote systems)

When the plan interacts with remote hosts, APIs, network devices, or authenticated services, this section MUST enumerate every access path:

| Target | Type | Credential/Path | Verified? | Verification command |
|--------|------|-----------------|-----------|---------------------|
| app-server.example.internal | SSH | root key-based | ✅ | `ssh -o ConnectTimeout=5 root@app-server.example.internal true` |
| monitoring.example.internal | API | glsa_... token | ✅ | `curl -sk -o /dev/null -w "%{http_code}" https://monitoring.example.internal/api/health` |
| 10.0.0.10 | SNMPv3 | user snmp | ❌ ASSUMED | `snmpwalk -v3 -u snmp -l noAuthNoPriv -t 5 10.0.0.10 1.3.6.1.2.1.1.5.0` |

**Rules:**
- Every target the plan deploys an exporter/scraper/agent against MUST appear in this table
- Claims MUST be marked `✅ VERIFIED` (with the exact command and its output) or `❌ ASSUMED` (untested)
- No task that depends on an ASSUMED access path may proceed without first verifying it
- If a verification command returns unexpected results, update the mark to `❌ BLOCKED` and halt the task

**Toolchain rows (MANDATORY for plans with build/lint/test steps):** the ACCESS table additionally carries one row per **local toolchain component** the plan's tasks invoke — compiler/runtime versions and any complexity/lint tool the gate uses. Each row names the tool, its version (resolved by a command), PATH status (on `PATH` or off with invocation-prefix workaround), and a verifying command with date. Mark each `✅ VERIFIED` (tool runs and reports the expected version) or `❌ ASSUMED` (path status known but version not resolved in the current session).

| Tool | Version | PATH status | Purpose | Verified? | Verification command |
|------|---------|-------------|---------|-----------|---------------------|
| bash | 5.3.15 | on PATH | framework scripts | ✅ VERIFIED 2026-09-11 | `bash --version` |
| ripgrep (`rg`) | 15.2.0 | on PATH | lint pattern engine | ✅ VERIFIED 2026-09-11 | `rg --version` |
| shellcheck | 0.11.0 | on PATH | Bash complexity/style gate | ✅ VERIFIED 2026-09-11 | `shellcheck --version` |
| gocyclo | n/a — not used | off default PATH (`~/go/bin`) | Go complexity (gated via PATH export) | n/a | recorded as a toolchain-row failure mode for reference |

---

## A2. PROJECT CONTEXT — Infrastructure Requirements

In addition to the PLAN_CORE.md PROJECT CONTEXT requirements, infrastructure plans MUST include:

- **Tool versions for EVERY external tool the plan interacts with** — the exact version string, verified from the target host. Format: `Prometheus 2.45.0 (verified via prometheus --version on app-server.example.internal)`. Do NOT write "v0.24+" or "latest".
  - **Why:** v0.24.0 of blackbox_exporter uses `fail_if_body_not_matches_regexp`; v0.25+ uses a `body:` sub-map. Plans that assume tool behavior without verifying the actual version produce tasks that silently fail.
- **Existing infrastructure on ALL hosts the plan touches** — not just the target system. When a plan interacts with monitoring stacks, reverse proxies, databases, or any shared infrastructure, document what already runs there (ports, versions, config paths). Cite the source.
  - **Litmus test:** If the plan proposes creating or modifying a component on host B to monitor host A, the PROJECT CONTEXT must describe what is already running on host B.
- **Behavioral assumptions must be verified-by-example** — for each tool the plan configures, cite an existing working instance of the same configuration pattern on the SAME host. Do NOT assume patterns work without citing an existing example.

---

## A3. ACCESS PREREQUISITES Per-Task (deployment/monitoring tasks)

When a task deploys an exporter, scraper, agent, or configuration that targets a remote system, include this subsection:

- **Network reachability:** `ping -c 2 -W 2 <target>` must succeed (0% loss) OR document why ICMP may be blocked
- **Port accessibility:** `nc -z -w 3 <target> <port>` must show open
- **Credential validity:** The exact test command that confirms credentials work
- **Fallback instruction:** "If any prerequisite fails, mark the task BLOCKED with the specific failure evidence and continue to the next task. Do NOT deploy a scraper/exporter that will permanently show DOWN."

---

## A4. Reconstruction Completeness (MANDATORY for external deployments)

Every plan that deploys artifacts to external systems MUST leave behind enough repo-side material for a complete rebuild without access to the deployed system.

**Litmus test:** If the server is destroyed, can an agent with only the repo reconstruct every deployed artifact?

### Required Artifacts

| Artifact | Requirement |
|----------|-------------|
| Plan file | Full task descriptions with STRUCTURE showing exact config/script content |
| Devlog | Per-task records with verification output, deviations, and discoveries |
| Notes file | Monitoring/architectural documentation section with redeployment steps |
| Scripts | Every script deployed to a server MUST have a copy saved in the repo |

### Script Preservation Rule

Any script or config file created on or copied to a remote server MUST also be saved in the repository:
1. **Write the script to the repo first**, then `scp` it to the server, OR
2. **Pull the script back from the server** after deployment: `scp user@host:/path/to/script.sh ./repo/path/`

### Devlog Completeness for Reconstruction

- **For small files** (<100 lines): Include the full file content in the devlog verification output
- **For larger files**: Reference the repo path where the copy is saved
- **For config patches**: Show the exact `sed` commands or diff hunks applied
- **For generated values** (tokens, keys): Document the generation command so it can be re-run

---

## A7. Diagnostic and Investigation Plans

When a plan's purpose is to reproduce a bug, collect diagnostic data, or identify root cause, additional rules apply.

### Test Fidelity: Match Production Behavior Exactly

Diagnostic tests MUST replicate how the system operates in production.

**stdio/pipe transports:** `cat input | process` closes stdin immediately. For MCP servers or any protocol where the client maintains a persistent connection, use a method that keeps the connection open:
```
{ cat input.txt; sleep 30; } | docker exec -i ...
```

**API clients:** Diagnostic test scripts MUST use the same initialization path as production code.

```python
# BAD: different from production
client = VikunjaClient()

# GOOD: same as production
config = Config.from_env()
client = VikunjaClient(base_url=config.base_url, token=config.api_token, verify=config.verify_ssl)
```

### Complex Shell Commands as Script Files

When a plan task includes commands with 2+ levels of quoting (SSH wrapping heredoc wrapping JSON), provide the command as a standalone script file — not as inline shell.

### Sanity-Check Test Results Before Analysis

After collecting diagnostic data, compare results against KNOWN BEHAVIOR before proceeding to root cause analysis. If the test output does not match the expected failure pattern, the test is invalid — do not draw conclusions from it.

| Expected | Actual | Action |
|----------|--------|--------|
| 2 calls succeed, 3rd crashes | 0 calls complete | INVALID. Redesign the test. Do NOT classify a root cause. |
| 2 calls succeed, 3rd crashes | 2 calls succeed, 3rd returns error | Valid — proceed to analysis |

### Artifact Cleanup

Every plan that creates temporary files or test data MUST include an explicit cleanup step:
```
CLEANUP:
  1. Delete test records from Vikunja API
  2. Remove temp files: rm test_vikunja.py test_http.py
  3. Verify: ls test_*.py 2>&1 | grep -q "No such file" && echo PASS
```

---

## A8. Operational Robustness

### Container Filesystem vs Host Filesystem

Scripts created on the host are NOT automatically available inside a container. Any task executing a file inside a container MUST include an explicit copy step:
```
1. Write /tmp/test_script.py on host
2. docker cp /tmp/test_script.py container_name:/tmp/test_script.py
3. docker exec container_name python3 /tmp/test_script.py
```

### Container Overlay Filesystem Limitations

When modifying files inside a running container, the overlay filesystem blocks writes to in-use files. `docker cp`, `sed -i`, and `cat >` all fail silently or with "Device or resource busy."

**The only reliable method** to update an in-use file inside a container:
1. `docker stop` the container
2. Write to the file via the host's MergedDir: `docker inspect -f '{{.GraphDriver.Data.MergedDir}}' container_name`
3. `docker start` the container

### SSH/Remote Execution Reliability

- Always verify SSH connectivity as the first step: `ssh -o ConnectTimeout=5 host true`
- Use explicit paths, never rely on shell aliases or `.bashrc` being sourced
- Capture both stdout and stderr: `ssh host 'command' 2>&1`

### Docker Build/Push Verification

After any `docker build` or `docker push`:
```
VERIFICATION:
  1. docker images | grep "image_name" | grep "tag"
  2. docker manifest inspect registry/image:tag
```

Do NOT rely on "command exited successfully" alone — network issues can produce partial pushes with exit code 0.

### File Modification Resilience

For critical modifications:
- Provide the FULL intended file content if the file is small (<50 lines)
- Provide a precise diff with 5+ lines of surrounding context if the file is large
- Include a verification step that checks syntax validity after modification

### Recovery from Tool-Induced Corruption

If a modification produces invalid output (syntax errors, merged content, markdown injection):
1. Do NOT attempt to fix corruption with more edits
2. Restore from version control: `git checkout -- <file>`
3. Re-attempt with a different strategy

### Configuration Reload Behavior (Prometheus, nginx, blackbox_exporter)

| Tool | SIGHUP reloads | SIGHUP does NOT reload |
|------|---------------|------------------------|
| Prometheus | Rule files, scrape interval changes | `__address__` relabel changes, `job_name` changes, new/removed scrape jobs |
| blackbox_exporter | Module definitions | Module removal, port changes |
| nginx | Full config | — |

When in doubt, specify a full container restart. For Prometheus: if the plan changes `relabel_configs`, `__address__`, or adds/removes scrape jobs, use `docker restart` (not SIGHUP).

---

## A9. Pre-Deployment Access Verification (MANDATORY for monitoring plans)

Before any task that deploys an exporter, scraper, or agent for a remote target, STEP 1 MUST be an access verification gate:

```
STEP 1 (ACCESS GATE):
  a. ping -c 2 -W 2 <target> — must return 0% loss
  b. For SNMP: snmpwalk -v3 -u <user> -l noAuthNoPriv -t 5 <target> 1.3.6.1.2.1.1.5.0
  c. For HTTP: curl -sk -o /dev/null -w "%{http_code}" <target_url> — must return non-000
  d. If ANY check fails: mark task BLOCKED with specific evidence. Do NOT deploy.
  e. If ALL checks pass: record evidence in devlog and proceed.
```

---

## A10. Grafana-Specific Rules

### 3-Stage Alert Rule Pattern (CRITICAL)

Grafana-managed alert rules use a 3-stage expression pattern (A → B → C):
- B step MUST be `type: "reduce"` with `reducer: "last"`, NOT `type: "threshold"` with empty params
- Put PromQL expression WITHOUT a comparison in the A step; put the threshold in the C step's `evaluator.params`
- `notification_settings.receiver` uses the contact point NAME, not the UID

### Dashboard API — `folderUid` Placement (CRITICAL)

`folderUid` MUST be placed at the **top level** of the `POST /api/dashboards/db` payload, NOT inside the `dashboard` object. Grafana silently ignores `folderUid` inside `dashboard`.

Additional quirks:
- UID length limit: 40 characters
- Self-signed certs: All curl commands MUST use `-k`
- Dashboard `id` response field is NOT the UID

### Data Source Schema Verification (CRITICAL)

Every measurement name, field key, tag name, metric name, and label referenced in the plan MUST be extracted from a **working, verifiable artifact** — never fabricated from naming conventions.

Every query in a plan MUST cite its source artifact (file path + line or panel name that proves the query works).

---

## A11. Production Image Verification (MANDATORY for containerized projects)

Every plan for a project that has a `Dockerfile` or deployment target MUST include a final task that:

1. Builds the container image from the current working tree
2. Pushes to the registry with the next version tag
3. Deploys to the target host (pull + restart)
4. Runs the project's canonical E2E verification against the deployed container
5. Confirms the container healthcheck passes post-deploy

**Exemptions** (must be stated explicitly in the plan):
- The project has no `Dockerfile` and is not deployed as a container or service
- The plan is a documentation-only change with no code, config, or test modifications

---

## A12. Functional Testing (MCP Tools, APIs, Services)

Every plan that adds or modifies an MCP tool, API endpoint, CLI subcommand, or production-facing entrypoint MUST include a dedicated functional testing task.

**Rules:**
- Functional testing is its own task, not a throwaway subsection
- The test MUST exercise the production entrypoint using the same protocol as production
- Never verify by module introspection alone (`_tool_manager._tools` proves registration, not correctness)
- Test both happy path AND error path

**Anti-patterns to reject:**
```
# WRONG: proves function is decorated, not that it works
python -c "assert 'my_tool' in [t.name for t in mcp._tool_manager._tools.values()]"

# WRONG: proves no import-time crash, nothing about runtime
python -c "import my_module; print('OK')"
```

---

## A13. Infrastructure Checklist (extends PLAN_CORE §12)

In addition to the universal checklist, verify:

**Cross-cutting framework rules (R1–R7):** see `PLAN_CORE.md §2 — Cross-cutting framework rules`. Of particular note for infrastructure plans: R1 (operator-confirm between dry-run and apply is mandatory for any plan that calls `terraform apply`, `kubectl apply`, `ansible-playbook` without `--check`, or remote `DROP`/`DELETE`/`rm -rf`); R2 (long-running deploy APIs require explicit poll-until-drained); R3 (infrastructure queries that consume collections must cite the schema or carry an `⚠️ UNTESTED` dump step); R6 (the Code Review task precedes the first deploy/apply task — see §A14); R7 (the plan preamble carries the recorded pre-execution semantic-review line, with no unresolved `FAIL`, before bootstrap).

- [ ] ACCESS & CREDENTIAL PREREQUISITES table present; every target marked ✅ VERIFIED or ❌ ASSUMED
- [ ] toolchain rows: compiler/runtime + complexity/lint tools each carry version, PATH status, verifying command, and date
- [ ] Deployment tasks have ACCESS PREREQUISITES subsection with reachability gate as STEP 1
- [ ] Tool versions verified for every external tool configured (not "latest" or version ranges)
- [ ] Existing infrastructure documented for ALL hosts touched (not just the target system)
- [ ] Each tool configuration cites an existing working example on the same host
- [ ] Overlay FS: tasks modifying container config files use stop-MergedDir-start pattern
- [ ] Config reload: tasks specify SIGHUP vs restart based on change type
- [ ] Pre-deployment access verification: every exporter/scraper deployment task has STEP 1 as access gate
- [ ] Grafana API: dashboard create/update tasks show `folderUid` at payload top level
- [ ] Grafana alerts: B step is `type: reduce`, not `type: threshold`; threshold in C step
- [ ] Every database query cites its source artifact (not fabricated from naming conventions)
- [ ] Reconstruction: every script deployed to server has a copy in the repo
- [ ] Reconstruction: devlog includes full content of small files or repo references for larger files
- [ ] Reconstruction: notes file has architecture, ports, alert rules, and redeployment steps
- [ ] Production image verification: plan includes final task that builds, pushes, deploys, and runs E2E (or states explicit exemption)
- [ ] Functional testing: MCP tools/APIs/CLI commands have dedicated functional testing tasks invoking the production code path
- [ ] Deviation propagation: plan includes sub-step to write Adaptation Notes table to project README
- [ ] Pre-deployment Code Review gate: Code Review task precedes the first deploy/apply task; each deploy task gates on review pass (§A14 / CQ9.6 / R6)

---

## A14. Pre-Deployment Code Review Gate (MANDATORY for deployment plans)

Every deployment plan — any plan that applies or mutates live or remote state —
MUST place the dedicated Code Review task (code-quality.md §CQ9) **after all
authoring tasks and before the first deployment task**. The artifacts are
reviewed before they touch a live system; deployment never precedes review.

**Deployment task** (triggers this gate): `deploy`, `apply` (`terraform apply`,
`kubectl apply`), `ansible-playbook` without `--check`, `docker build` + `push`
+ `restart`, `systemctl restart`, `migrate`, `rollout`, `release`, `scp`/`rsync`
to a target, or a remote `rm`/`DROP`/`DELETE`.

**Rules:**

- The Code Review task MUST precede every deploy/apply/provision/restart/migrate task.
- The review's file scope MUST be the deployable artifacts, not a summary.
- Each deployment task MUST gate on the review passing (CQ9.6 CONSTRAINTS text).
- Doc Update remains the final task.
- For non-deployment plans, CQ9.4's penultimate rule applies unchanged.
- Authors may declare `Deployment phase: yes` / `Deployment phase: N/A` in the
  plan preamble when the heading heuristic is ambiguous (`plan_lint.sh` P7).
