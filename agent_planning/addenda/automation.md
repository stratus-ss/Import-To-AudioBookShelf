# Plan Addendum — Home Automation

_Last updated: 2026-07-28_

Applies to: Home Assistant flows, Node-RED flows, ESPHome device configs, Lovelace dashboards, MQTT automations, HA template sensors, HA integrations.

Read this after `PLAN_CORE.md`. All rules here are ADDITIVE.

**Code quality:** When this plan adds or modifies Node-RED function nodes (JavaScript code), also read `addenda/code-quality.md`. Plans that only compose existing nodes without writing function node code are exempt.

---

## AU1. Flow Backup Before Modify (MANDATORY)

Before any task that modifies a live Node-RED flow or HA configuration, the plan MUST include a backup step as STEP 0 of that task.

**Node-RED flow backup:**
```
STEP 0 (BACKUP):
  1. Export current flows: GET http://node-red-host:1880/flows → save to
     agent_planning/execution/<project_name>/artifacts/flows_backup_<YYYY-MM-DD>.json
  2. Verify backup file size > 0
  3. Record backup path in devlog
  BLOCKED: if backup fails, do NOT proceed with flow modification
```

**HA configuration backup:**
```
STEP 0 (BACKUP):
  1. Copy current config: cp <ha_config_path> <ha_config_path>.bak.<YYYY-MM-DD>
  2. Verify backup exists: ls -la <ha_config_path>.bak.*
```

Backups MUST be saved in the project artifacts directory (not `/tmp`) per EXECUTION_PROTOCOL §1.5.

---

## AU2. Node-RED Deploy Safety

When a task modifies or deploys a Node-RED flow:

1. **Test in the UI before exporting** — verify the flow runs correctly in Node-RED's visual editor before committing the JSON to the repo
2. **Export the final JSON** — pull the deployed flow back from Node-RED, do not commit hand-edited JSON without round-tripping through Node-RED
3. **Commit the exported JSON** — store in `HomeAssistant/flows/` (or the canonical location for the project)
4. **Verify after deploy:**
   - Check the flow's debug nodes or output nodes for expected behavior
   - For MQTT-based flows: confirm the expected MQTT topic receives the expected payload
   - For HA-integrated flows: check HA entity state reflects the expected value

**Import command:**
```bash
# Import a flow JSON to Node-RED via API
curl -X POST http://node-red-host:1880/flows \
  -H "Content-Type: application/json" \
  -d @flows_file.json
```

---

## AU3. HA Entity Naming Conventions

When a plan creates new HA entities (sensors, input_booleans, input_selects, helpers, etc.):

- **Sensor/entity IDs:** `snake_case`, prefixed by domain (e.g., `sensor.living_room_temperature`, `input_select.device_mode`)
- **Friendly names:** Title Case, descriptive (e.g., "Living Room Temperature", "Device Mode")
- **MQTT topics:** follow the existing pattern in the project (e.g., `valetudo/<device_id>/command`)
- **Script/automation names:** verb-first in snake_case (e.g., `script.start_vacuum_segment`, `automation.notify_vacuum_offline`)

STRUCTURE sections that create HA entities MUST list:
- Entity ID (exact)
- Friendly name
- Domain (sensor, input_select, script, automation, etc.)
- Any dependent entities it reads or calls

---

## AU4. HA State Verification

After deploying HA configuration or Node-RED flows, VERIFICATION MUST include state checks:

```
VERIFICATION:
  1. Check entity exists and has non-unavailable state:
     curl -s -H "Authorization: Bearer <token>" \
       http://ha-host:8123/api/states/sensor.living_room_temperature | jq .state
     PASS: returns a numeric value (not "unavailable" or "unknown")

  2. For Node-RED flows: trigger the flow manually and verify expected output appears
     in the debug panel or HA entity state

  3. For MQTT flows: publish test payload and verify HA entity state changes
     mosquitto_pub -h mqtt-host -t "<device_id>/command" -m '{"command":"start"}'
     → verify device entity state changes to expected value
```

For template sensors specifically:
```
VERIFICATION:
  curl -s -H "Authorization: Bearer <token>" \
    http://ha-host:8123/api/template \
    -H "Content-Type: application/json" \
    -d '{"template": "{{ states(\"sensor.living_room_temperature\") }}"}'
  PASS: returns a numeric value
  FAIL: returns "unavailable", "unknown", or an error
```

---

## AU5. Node-RED Function Node Testing Patterns

When a plan adds or modifies Node-RED function nodes containing JavaScript logic:

- **Document the expected input msg structure** in the STRUCTURE section:
  ```
  Input msg:
    msg.payload = { "state": "cleaning", "battery": 85 }
  Output msg:
    msg.payload = "vacuum is cleaning at 85% battery"
  ```
- **Provide a test payload** in the VERIFICATION section that can be injected via the Inject node
- **For complex logic** (multiple conditional paths): enumerate each path as a separate scenario in the CONTEXT section with expected input and output

---

## AU6. ESPHome Device Rules

When a plan modifies ESPHome device configurations:

1. **Flash safely:** Verify OTA update path is reachable before compiling (`ping <device-ip>`)
2. **Config backup:** Copy the existing `.yaml` before modifying
3. **Compile check:** `esphome compile <device>.yaml` must succeed before flashing
4. **Post-flash verification:** Confirm device comes back online and reports expected sensors within 2 minutes

STRUCTURE sections that modify ESPHome configs MUST list:
- Device name and IP
- Which sensors/switches are being modified
- Which sensors/switches must remain unaffected

---

## AU7. Automation Checklist (extends PLAN_CORE §12)

In addition to the universal checklist, verify:

**Cross-cutting framework rules (R1–R7):** see `PLAN_CORE.md §2 — Cross-cutting framework rules`. Apply the same R1–R7 expectations as the other addenda: destructive ops require an operator-confirm gate between dry-run and apply; APIs that return-before-complete must poll-until-drained; collection results must name schemas or carry a runtime dump; skills named in a task must be transcribed; plan preamble records `§12 pass: <n items>` before the plan is declared done; deployment plans place the Code Review task before the first deploy/apply task (§CQ9.6); R7 requires the recorded pre-execution semantic-review line (no unresolved `FAIL`) in the preamble before bootstrap.

- [ ] Flow backup (STEP 0) included in any task that modifies a live flow or HA config
- [ ] Backup destination is the project artifacts directory (not /tmp)
- [ ] Node-RED tasks include: test in UI → export JSON → commit to repo
- [ ] HA entities created by the plan have explicit entity IDs and friendly names in STRUCTURE
- [ ] VERIFICATION includes entity state check (not just "flow was imported")
- [ ] Node-RED function nodes have documented input/output msg structure
- [ ] MQTT flows include a test publish + state verification step
- [ ] ESPHome plans verify OTA reachability and include compile check before flash
