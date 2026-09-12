## OBJECTIVE

Add a Node-RED sub-flow to the existing Office tab that monitors the centralite thermostat's `hvac_action` attribute during business hours (09:00-18:00 Mon-Fri) and controls `switch.steve_s_office_zigbee_outlet` — on when actively cooling, off when not. Gated by `input_boolean.office_fan_override`: when ON, the automation does nothing. Uses only built-in nodes and existing HA entities (no function nodes, no new dependencies).

project_name: office_fan_automation

## PROJECT CONTEXT

- **System:** Node-RED running as HA add-on on `home-assistant.x86experts.com:8123`
- **Target flow tab:** Office (tab id `6a818ccad08d12d1`)
- **Existing nodes reused:** "Turn Fan On" (`77bacb9aba514e94`), "Turn Fan Off" (`f7e5b06e4590b80c`)
- **HA Server config node:** `46f70193.13e58`
- **Entities:** `climate.0x000d6f000ad99d07` (friendly name "centralite_thermostat" — uses `hvac_action` attribute), `input_boolean.office_fan_override`, `switch.steve_s_office_zigbee_outlet`
- **Design:** Two polling inject nodes — one with weekday cron for business-hours on/off logic, one generic for off-only outside hours. No `server-state-changed` to avoid throttling, no function nodes.

## KEY FILES REFERENCE

| File | Purpose |
|------|---------|
| `HomeAssistant/flows/Office.json` | Target flow tab; nodes appended to this file |
| `agent_planning/execution/office_fan_automation/artifacts/Office_pre_modification.json` | Pre-change backup (73 nodes, live-captured 2026-07-06) |
| `agent_planning/execution/office_fan_automation/devlogs/devlog_20260706.md` | Devlog for this execution |

## TASKS

<task id="1" reasoning="think-high" temperature="0.0">

  <intent>
    Generate the modified Office.json with the new cooling-fan automation nodes appended,
    preserving all existing nodes and wiring. The result is a drop-in replacement file.
  </intent>

  <structure>
    Produce a complete Office.json file at:
    `agent_planning/execution/office_fan_automation/artifacts/Office_modified.json`

    The file is derived from the pre-modification backup at
    `agent_planning/execution/office_fan_automation/artifacts/Office_pre_modification.json`
    with these 6 new nodes appended and their wiring integrated.
  </structure>

  <context>
    The pre-modification file is at:
    `agent_planning/execution/office_fan_automation/artifacts/Office_pre_modification.json`

    Read it first to capture existing node IDs and the exact JSON shape of each node type.

    **Existing nodes to reuse (DO NOT recreate these nodes):**
    - Turn Fan On: id=`77bacb9aba514e94`, type=`api-call-service`, action=`switch.turn_on`, entity=`switch.steve_s_office_zigbee_outlet`
    - Turn Fan Off: id=`f7e5b06e4590b80c`, type=`api-call-service`, action=`switch.turn_off`, entity=`switch.steve_s_office_zigbee_outlet`

    **New nodes to append (use these exact IDs):**

    Node A — inject "Every 2 min (Weekdays 9-17)"
    ```json
    {"id": "788f4d9e555cdf76", "type": "inject", "z": "6a818ccad08d12d1", "name": "Every 2 min (Weekdays 9-17)", "props": [{"p": "payload"}], "repeat": "", "crontab": "*/2 9-17 * * 1-5", "once": false, "onceDelay": 0.1, "topic": "", "payload": "", "payloadType": "date", "x": 110, "y": 1260, "wires": [["553b67380412b55a"]]}
    ```

    Node B — api-current-state "Read Thermostat"
    ```json
    {"id": "553b67380412b55a", "type": "api-current-state", "z": "6a818ccad08d12d1", "name": "Read Thermostat", "server": "46f70193.13e58", "version": 3, "outputs": 2, "halt_if": "", "halt_if_type": "str", "halt_if_compare": "is", "entity_id": "climate.0x000d6f000ad99d07", "state_type": "str", "blockInputOverrides": false, "outputProperties": [{"property": "payload", "propertyType": "msg", "value": "", "valueType": "entityState"}, {"property": "data", "propertyType": "msg", "value": "", "valueType": "entity"}], "for": 0, "forType": "num", "forUnits": "minutes", "override_topic": false, "state_location": "payload", "override_payload": "msg", "entity_location": "data", "override_data": "msg", "x": 300, "y": 1260, "wires": [["a0f4327e49e18607"]]}
    ```

    Node C — switch "Is Cooling?"
    ```json
    {"id": "a0f4327e49e18607", "type": "switch", "z": "6a818ccad08d12d1", "name": "Is Cooling?", "property": "data.attributes.hvac_action", "propertyType": "msg", "rules": [{"t": "eq", "v": "cooling", "vt": "str"}, {"t": "else"}], "checkall": "true", "repair": false, "outputs": 2, "x": 500, "y": 1260, "wires": [["eecc9d66799cc9ee"], ["f7e5b06e4590b80c"]]}
    ```

    Node D — api-current-state "Fan Override On?"
    ```json
    {"id": "eecc9d66799cc9ee", "type": "api-current-state", "z": "6a818ccad08d12d1", "name": "Fan Override On?", "server": "46f70193.13e58", "version": 3, "outputs": 2, "halt_if": "on", "halt_if_type": "str", "halt_if_compare": "is", "entity_id": "input_boolean.office_fan_override", "state_type": "str", "blockInputOverrides": false, "outputProperties": [{"property": "payload", "propertyType": "msg", "value": "", "valueType": "entityState"}], "for": 0, "forType": "num", "forUnits": "minutes", "override_topic": false, "state_location": "payload", "override_payload": "msg", "entity_location": "data", "override_data": "msg", "x": 700, "y": 1260, "wires": [[], ["ff65646c5fac8cbf"]]}
    ```

    Node E — time-range-switch "09:00-18:00"
    ```json
    {"id": "ff65646c5fac8cbf", "type": "time-range-switch", "z": "6a818ccad08d12d1", "name": "09:00-18:00", "lat": "", "lon": "", "startTime": "09:00", "endTime": "18:00", "startOffset": 0, "endOffset": 0, "x": 900, "y": 1260, "wires": [["77bacb9aba514e94"], []]}
    ```

    Node F — inject "Every 5 min (Off Check)"
    ```json
    {"id": "7a1825d424b7f86e", "type": "inject", "z": "6a818ccad08d12d1", "name": "Every 5 min (Off Check)", "props": [{"p": "payload"}], "repeat": "300", "crontab": "", "once": false, "onceDelay": 0.1, "topic": "", "payload": "", "payloadType": "date", "x": 110, "y": 1340, "wires": [["c6bcdd1a2fb21552"]]}
    ```

    Node G — api-current-state "Read Thermostat (Off Check)"
    ```json
    {"id": "c6bcdd1a2fb21552", "type": "api-current-state", "z": "6a818ccad08d12d1", "name": "Read Thermostat (Off Check)", "server": "46f70193.13e58", "version": 3, "outputs": 2, "halt_if": "", "halt_if_type": "str", "halt_if_compare": "is", "entity_id": "climate.0x000d6f000ad99d07", "state_type": "str", "blockInputOverrides": false, "outputProperties": [{"property": "payload", "propertyType": "msg", "value": "", "valueType": "entityState"}, {"property": "data", "propertyType": "msg", "value": "", "valueType": "entity"}], "for": 0, "forType": "num", "forUnits": "minutes", "override_topic": false, "state_location": "payload", "override_payload": "msg", "entity_location": "data", "override_data": "msg", "x": 300, "y": 1340, "wires": [["e4391c6a605c18cc"]]}
    ```

    Node H — switch "Not Cooling?"
    ```json
    {"id": "e4391c6a605c18cc", "type": "switch", "z": "6a818ccad08d12d1", "name": "Not Cooling?", "property": "data.attributes.hvac_action", "propertyType": "msg", "rules": [{"t": "neq", "v": "cooling", "vt": "str"}], "checkall": "true", "repair": false, "outputs": 1, "x": 500, "y": 1340, "wires": [["f7e5b06e4590b80c"]]}
    ```

    **How to produce the output:**
    1. Read `Office_pre_modification.json`
    2. Append these 8 new node objects to the flow array (after the existing 73 nodes)
    3. Write to `Office_modified.json`

    [TASK RESTATEMENT: Produce Office_modified.json by appending 8 new nodes to the pre-modification backup. Use the exact JSON shown above for each new node — do not change IDs, properties, or wiring.]
  </context>

  <constraints>
    - Read input from: `agent_planning/execution/office_fan_automation/artifacts/Office_pre_modification.json`
    - Write output to: `agent_planning/execution/office_fan_automation/artifacts/Office_modified.json`
    - Do NOT modify any of the original 73 nodes
    - Append the 8 new nodes at the end of the array
    - Use the exact JSON as specified in &lt;structure&gt; for each new node
    - Verify the file is valid JSON after writing: `python3 -c "import json; json.load(open('...'))"`
    - Node IDs are exact; do not regenerate
  </constraints>

  <naming>
    File: Office_modified.json
    Directory: agent_planning/execution/office_fan_automation/artifacts/
  </naming>

  <examples>
    WRONG: Changing any property in the new nodes (IDs, names, wire targets, entity IDs)
    RIGHT: Copy-paste exactly the JSON from &lt;structure&gt; into the output array

    WRONG: Modifying existing node wiring to connect to new nodes
    RIGHT: New nodes reference existing node IDs in their `wires` arrays; this is how Node-RED creates connections without modifying existing nodes
  </examples>

  <dont>
    - Do not modify any of the 73 existing nodes
    - Do not change new node IDs
    - Do not regenerate the file from scratch; append to the read input
    - Do not skip the JSON validity verification step
  </dont>

  <verification>
    Command: python3 -c "import json; d=json.load(open('agent_planning/execution/office_fan_automation/artifacts/Office_modified.json')); print(f'OK: {len(d)} nodes, tab_id={d[0][\"id\"]}')"
    PASS: Output shows "OK: 81 nodes, tab_id=6a818ccad08d12d1"
    FAIL: Any JSON decode error, wrong node count, or wrong tab_id
  </verification>

  <output>
    Writing 81 nodes to Office_modified.json...
  </output>

</task>

<task id="2" reasoning="think-high" temperature="0.0">

  <intent>
    Deploy the modified Office flow to the live Node-RED instance via its admin API.
    This replaces the current Office tab with the new version containing the cooling-fan automation.
  </intent>

  <structure>
    Using the HA WebSocket ingress method (documented in HomeAssistant/NODERED-API-ACCESS.md):
    1. Connect to HA WebSocket and authenticate with the read-only token
    2. Get Node-RED addon info → ingress_entry
    3. Create ingress session
    4. Read the existing flow from: GET `{ingress_entry}/flow/6a818ccad08d12d1`
    5. Replace with modified flow: POST `{ingress_entry}/flow/6a818ccad08d12d1`
       Body: the full flow tab JSON array from Office_modified.json
    6. Trigger Node-RED deploy: POST `{ingress_entry}/flow/6a818ccad08d12d1` with the full flow

    The HA read-only token is in HomeAssistant/NODERED-API-ACCESS.md line 17.
  </intent>

  <context>
    The HA WebSocket ingress flow pattern is documented in:
    - HomeAssistant/NODERED-API-ACCESS.md (full code example)
    - HomeAssistant/helper_scripts/fetch_nr_flow.py (working script that was already tested)

    The modified flow file is at:
    `agent_planning/execution/office_fan_automation/artifacts/Office_modified.json`

    The Node-RED admin API endpoints:
    - GET `{ingress_entry}/flow/{flow_id}` — read a single flow tab
    - POST `{ingress_entry}/flow/{flow_id}` — update a single flow tab (auto-deploys)

    Note: NODERED-API-ACCESS.md documents that posting to `/flows` imports all flows.
    A POST to `/flow/{id}` with the tab+node array updates just that tab.

    [TASK RESTATEMENT: Deploy Office_modified.json to live Node-RED via HA WebSocket ingress + Node-RED admin API.]
  </context>

  <constraints>
    - Use the token from HomeAssistant/NODERED-API-ACCESS.md (not from .cursor/mcp.json)
    - Write a standalone Python script to perform the deploy (do not cargo-cult the full script inline)
    - Save the deploy script in the repo at: `HomeAssistant/helper_scripts/deploy_nr_flow.py`
    - Script must accept: python3 deploy_nr_flow.py &lt;flow_tab_label&gt; &lt;flow_json_path&gt;
    - Verify the deployed flow by reading it back after POST
  </constraints>

  <naming>
    Script: HomeAssistant/helper_scripts/deploy_nr_flow.py
  </naming>

  <examples>
    WRONG: Using curl with the HA REST API on port 8123 (that API cannot access Node-RED)
    RIGHT: Use the WebSocket ingress method to tunnel through to Node-RED's admin API

    WRONG: POSTing to /flows (replaces ALL flows)
    RIGHT: POST to /flow/6a818ccad08d12d1 (replaces only the Office tab)
  </examples>

  <dont>
    - Do not POST to `/flows` (that replaces every flow tab in Node-RED)
    - Do not deploy without verification of the flow content
    - Do not use the deprecated REST API; ingress WebSocket is the only path
  </dont>

  <verification>
    Command: python3 HomeAssistant/helper_scripts/deploy_nr_flow.py "Office" "agent_planning/execution/office_fan_automation/artifacts/Office_modified.json"
    PASS: Script exits 0, prints "Deployed OK" and verifies by reading back the flow
    FAIL: Any HTTP error, auth failure, or flow readback shows wrong node count
  </verification>

  <output>
    Deploying Office flow with cooling-fan automation...
  </output>

</task>

<task id="3" reasoning="think-high" temperature="0.0">

  <intent>
    Functional end-to-end validation of the deployed cooling-fan automation against the live system.
    Tests the full path: thermostat hvac_action → override gate → time gate → fan outlet.
  </intent>

  <structure>
    1. Verify the deployed flow is correct:
       - Read back the flow from Node-RED
       - Count nodes (must be 81)
       - Verify all 8 new node IDs are present

    2. Test Case 1 — Override gates correctly:
       - Set `input_boolean.office_fan_override` to ON via HA API
       - Trigger the inject node manually (or wait for next poll)
       - Verify `switch.steve_s_office_zigbee_outlet` state does NOT change

    3. Test Case 2 — Cooling triggers fan ON (if within hours):
       - Set `input_boolean.office_fan_override` to OFF via HA API
       - Inject a state change to `climate.0x000d6f000ad99d07` simulating hvac_action=cooling
         (Or use the `api-call-service` node path if available)
       - Verify `switch.steve_s_office_zigbee_outlet` turns ON (or is already on)
       - Inject hvac_action=idle
       - Verify `switch.steve_s_office_zigbee_outlet` turns OFF

    4. Print PASS/FAIL summary

    Note: Since this is a polling flow (every 2 min), tests may need to wait for the inject timer.
    Use the Node-RED debug node or HA API to read states before/after.
  </intent>

  <context>
    HA API access:
    - REST: `GET https://home-assistant.x86experts.com:8123/api/states/{entity_id}`
    - Token: same read-only token from NODERED-API-ACCESS.md
    - Services: `POST https://home-assistant.x86experts.com:8123/api/services/{domain}/{service}`
      with body `{"entity_id": "..."}`
      (Note: the read-only token may not allow service calls)

    Since the token is read-only, testing may be limited to observation:
    - Verify nodes are deployed correctly (structural check)
    - Verify flow JSON matches expected shape
    - Report that live-state verification requires a user to trigger the thermostat and observe

    [TASK RESTATEMENT: Verify flow structure (node count, IDs) and document what live-state test the user should perform.]
  </context>

  <constraints>
    - The HA token is read-only; do not attempt service calls that will fail
    - Structural verification (node count, IDs, wiring) is the primary validation
    - Test the flow JSON by parsing and validating wiring references: every target ID in `wires` arrays must exist in the flow
    - Reference-check: every node ID referenced in new nodes' wires must exist in the full flow (either existing or new)
  </constraints>

  <naming>
    Validation script: (inline in task, not a separate file)
  </naming>

  <examples>
    WRONG: Attempting to call HA services with a read-only token (will get 401)
    RIGHT: Verify structural integrity of the flow JSON; document manual test procedure

    WRONG: Skipping wire reference validation
    RIGHT: Every node ID in every `wires` array must resolve to a node in the flow
  </examples>

  <dont>
    - Do not attempt to set entity states with a read-only token
    - Do not skip the wire reference check
  </dont>

  <verification>
    Command: python3 -c "
    import json
    with open('agent_planning/execution/office_fan_automation/artifacts/Office_modified.json') as f:
        flow = json.load(f)
    ids = {n['id'] for n in flow}
    # Check all wire targets exist
    refs = set()
    for n in flow:
        for wire_list in n.get('wires', []):
            for target in wire_list:
                refs.add(target)
    missing = refs - ids
    new_ids = ['788f4d9e555cdf76','553b67380412b55a','a0f4327e49e18607','eecc9d66799cc9ee','ff65646c5fac8cbf','7a1825d424b7f86e','c6bcdd1a2fb21552','e4391c6a605c18cc']
    present = [nid for nid in new_ids if nid in ids]
    print(f'Nodes: {len(flow)}, Missing refs: {missing}')
    print(f'New nodes deployed: {len(present)}/8')
    assert len(missing) == 0, f'Missing wire targets: {missing}'
    assert len(present) == 8, f'Missing new nodes: {set(new_ids)-ids}'
    print('PASS: All structural checks OK')
    "
    PASS: "PASS: All structural checks OK"
    FAIL: AssertionError with missing references
  </verification>

  <output>
    Validating cooling-fan flow structure...
  </output>

</task>

<task id="4" reasoning="non-think" temperature="0.0">

  <intent>
    Update the repo copy of Office.json and update the Node-RED KB doc to reflect
    the new flow. Back up the deployed flow from live Node-RED as a post-change artifact.
  </intent>

  <structure>
    1. Copy `Office_modified.json` → `HomeAssistant/flows/Office.json`
    2. Run the existing backup script to capture the live deployed state from Node-RED:
       `python3 HomeAssistant/helper_scripts/fetch_nr_flow.py "Office" agent_planning/execution/office_fan_automation/artifacts/`
    3. Compare the two files to confirm they match
    4. Update `knowledge/home-automation/node-red-flows.md`:
       - Add entry in the per-room flow tabs paragraph for the cooling-fan automation
       - Bump `updated:` date
    5. Add an entry to `knowledge/GO_BACK_VERIFICATION.md` for the live fetch
  </intent>

  <context>
    Repo paths:
    - `HomeAssistant/flows/Office.json` — canonical repo copy
    - `knowledge/home-automation/node-red-flows.md` — KB doc for Node-RED flows
    - `knowledge/GO_BACK_VERIFICATION.md` — verification tracking

    The fetch_nr_flow.py script already exists and was tested in Task 0 (backup step).

    [TASK RESTATEMENT: Commit modified Office.json to repo, update KB doc, capture post-deploy backup.]
  </context>

  <constraints>
    - Do NOT change the existing flow entries in node-red-flows.md; append the new entry
    - The `updated:` date on node-red-flows.md must be today (2026-07-06)
    - The GO_BACK_VERIFICATION.md entry must reference the deployed-flow fetch command
  </constraints>

  <naming>
    Repo copy: HomeAssistant/flows/Office.json
    KB edit: knowledge/home-automation/node-red-flows.md
    Verification: knowledge/GO_BACK_VERIFICATION.md
  </naming>

  <examples>
    WRONG: Replacing the entire node-red-flows.md instead of appending
    RIGHT: Append a bullet or table row for the new cooling-fan automation

    WRONG: Skipping the post-deploy live backup
    RIGHT: Always capture live state to confirm the deploy actually took effect
  </examples>

  <dont>
    - Do not edit knowledge/home-automation/overview.md (it doesn't track per-flow details)
    - Do not commit to git unless the user explicitly asks
    - Do not skip the post-deploy live backup
  </dont>

  <verification>
    Commands:
    1. diff -q HomeAssistant/flows/Office.json agent_planning/execution/office_fan_automation/artifacts/Office_modified.json
       PASS: files are identical
    2. rg 'cooling-fan' knowledge/home-automation/node-red-flows.md
       PASS: line found
    3. rg 'office_fan_automation' knowledge/GO_BACK_VERIFICATION.md
       PASS: line found
  </verification>

  <output>
    Updating repo + KB for cooling-fan automation...
  </output>

</task>
