/// <p>Interoperability's Jobs: the running production's jobs, each with its host, status, adapter state, last activity,
/// retry count and the message it is working on, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>Jobs</code>) and rendered by the <code>list</code> archetype's page (AD-5,
/// AD-29, AD-36, AD-62, Story 20.4).</p>
/// <p><b>A job no process holds reads <code>Dead</code> and its link is withheld</b> (<code>rowTarget</code>
/// <code>unless</code>), and it is never repaired: the classic Jobs page repairs it on every view, and a read does not
/// write (AD-7). A live job's name cell opens Process details by its pid. It refreshes at the shared rates, default
/// off (AD-43). Its three row actions are <code>abort</code> and <code>suspend</code> (the message a job keeps retrying) and
/// <code>stop</code> (Story 20.23): <code>interop.jobs.abort</code> is destructive and types the job's process id, and the other two
/// warn first.</p>
Class OcuPilot.Screen.Descriptor.InteropJobList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/jobs",
  "area": "interoperability",
  "labelKey": "interopJobsLabel",
  "sideBarPosition": 7,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Jobs", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Jobs", "permission": "READ"}],
  "entityType": "interop-job",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "abort", "selfProtection": ""}, {"id": "suspend", "selfProtection": ""}, {"id": "stop", "selfProtection": ""}],
  "context": {"fields": ["Job", "Host", "Status", "AdapterState", "LastActivity", "ActiveMessage", "Dead"], "secretFields": []},
  "emptyStateKey": "interopJobsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopJobsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopJobsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopJobsPrompt3"}
  ],
  "classicPage": "EnsPortal.Jobs",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "production job",
    "label": "Jobs of this namespace's running production, dead ones included (Dead); the instance's processes are in osmgmt.processes.",
    "source": {"port": "interop", "endpoint": "Jobs", "type": "LIST"},
    "fields": ["Job", "Host", "Status", "AdapterState", "LastActivity", "Retry", "ActiveMessage", "Dead"],
    "filter": ["Job", "Host", "Status", "ActiveMessage"],
    "sort": {"fields": ["Job", "Host", "Status", "LastActivity", "Retry"], "default": "Host", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Job", "labelKey": "interopColumnJob", "kind": "name"},
      {"field": "Host", "labelKey": "sslTestHost", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "AdapterState", "labelKey": "interopColumnAdapterState", "kind": "text"},
      {"field": "LastActivity", "labelKey": "agentTranscriptsColumnLastActivity", "kind": "text"},
      {"field": "Retry", "labelKey": "actionRetry", "kind": "number"},
      {"field": "ActiveMessage", "labelKey": "interopColumnActiveMessage", "kind": "identifier"},
      {"field": "Dead", "labelKey": "interopColumnDead", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopJobsEmptyAgent"
  },
  "rowTarget": {"route": "os-management/processes/details", "field": "Job", "unless": "Dead"},
  "toolIdentifier": "interop.jobs"
}
}

}
