/// <p>Task output: the last lines of one scheduled task's output file, read through
/// <class>OcuPilot.Port.LogSourcePort</class>'s <code>taskoutput</code> source as a declared read
/// (AD-36) and rendered by the shared log viewer (<code>log-viewer</code>, AD-5), one row per line
/// with no time, process or severity because the file carries none.</p>
/// <p><b>It is a sub-resource of Task schedule and never listed</b> (<code>sideBarPosition</code>
/// 0). It declares its parent, <code>parentScope</code> <code>tasks/schedule</code> (AD-5), and is
/// reached from Task details' "Open output file" link at <code>tasks/schedule/output/&lt;Id&gt;</code>,
/// the vendor's own numeric task id. Its one criterion, <code>taskId</code>, is filled from that
/// route id; the caller names a task and never a location (AD-21).</p>
/// <p><b>The port decides whether the file is read</b>: only when the stored record names one file
/// directly in the manager directory. Any other location is refused
/// (<code>LOG.TASKOUTPUT.ELSEWHERE</code>), a task that writes no file is refused
/// (<code>LOG.TASKOUTPUT.NONE</code>), and a file not yet written is its own refusal
/// (<code>LOG.TASKOUTPUT.ABSENT</code>). A refusal never carries the path.</p>
/// <p><b>The rows are the file's last 64 KB as whole lines, newest first</b>, <code>offset</code>
/// being the line's first byte and <code>text</code> the line as the instance stored it. Output is
/// untrusted text (AD-11, AD-60).</p>
/// <p><b>The privilege set is Task details' own</b>, <code>%Admin_Task:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> (AD-8, AD-29). <b>The classic page is
/// <code>%CSP.UI.Portal.TaskInfo</code></b> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.TaskOutput Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule/output",
  "area": "tasks",
  "labelKey": "taskOutputLabel",
  "sideBarPosition": 0,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "tasks/schedule",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["offset", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskOutputPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskOutputPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskOutputPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.TaskInfo",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "line of a task's output file",
    "source": {"port": "logsource", "endpoint": "taskoutput", "type": "LIST"},
    "fields": ["offset", "text"],
    "filter": ["offset", "text"],
    "sort": {"fields": ["offset"], "default": "offset", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10, "hint": "One task's whole-number id, as tasks.schedule.read answers its Id."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "text", "labelKey": "logViewerColumnMessage", "kind": "name"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.taskoutput"
}
}

}
