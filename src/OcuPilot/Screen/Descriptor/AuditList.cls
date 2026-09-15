/// <p>The audit database viewer: the instance's own audit rows, read through the vendor's
/// <code>Security.Audit.Record</code> LIST (AD-2, AD-36) and rendered by the
/// <code>list (server criteria)</code> archetype's page from the declared <code>table</code>
/// (AD-5). It is the Logs area's first screen, and the one Release 1 list whose API searches on
/// the <b>server</b>.</p>
/// <p><b>It declares <code>read.criteria</code>, which no other screen does</b> (AD-21). The
/// endpoint takes thirteen query parameters; eight criteria over nine of them are declared here,
/// the eight the amended FR-61 names: the time range (<code>beginDateTime</code> and
/// <code>endDateTime</code>), the event source, type and name, the user, the process id, the
/// namespace and the authentication mechanism. <code>systemIDs</code> and <code>ascending</code>
/// are real parameters FR-61 does not name, and <code>jsonSearch</code> is a recorded non-goal --
/// it is a mode rather than a search, since <code>%SYS.Audit</code> forces the event type to
/// <code>%SQL</code> whenever it is set, silently discarding <code>eventTypes</code>. The
/// thirteenth is <code>maxRows</code>, which every read sends already. The roster is
/// the allow-list: <method>OcuPilot.Api.ScreenRead.Handle</method> reads a query parameter only
/// where this block names it, and the read tool publishes one property per criterion, so the screen
/// and the tool send the same search.</p>
/// <p><b>Each criterion declares the <code>maxLength</code> its own vendor property carries</b>
/// (DW-279), read from <code>%Dictionary.CompiledProperty</code> on
/// <code>%Api.Admin.Endpoints.Security.Audit.RecordListTask</code>: 50 for
/// <code>beginDateTime</code>, <code>endDateTime</code>, <code>pids</code> and
/// <code>authentication</code>, 1000 for the other five. A longer value is refused 400
/// <code>READ.CRITERION</code> naming the parameter and its bound, before the port is called --
/// where an unbounded one reached the vendor property and faulted inside the port, naming nothing.
/// <class>OcuPilot.Test.Descriptor</class> pins these nine against the live dictionary, so a vendor
/// narrowing goes red rather than shipping a bound the instance no longer honours.</p>
/// <p><b><code>authentication</code> is a <code>choice</code>, not free text, because an
/// unrecognized value <i>widens</i> the search.</b> The vendor converts the criterion with
/// <code>$$AuthenticationDisplayToLogical^%SYS.SECURITY</code>, which answers <code>-1</code> for a
/// name it does not know, and <code>%SYS.Audit.CheckAuthentication</code> is
/// <code>$zb(+Select, +Data, 1)</code> -- so <code>-1</code> matches every row with any
/// authentication bit set. The declared options are <b>eleven display names</b>, each verified to
/// round-trip to a real logical value on this build. FR-61 names the criterion and not its values,
/// so the eleven are this descriptor's own choice; they are not the build's whole vocabulary, which
/// is wider, so a row authenticated by a mechanism outside them is not reachable through this
/// criterion. They are not the instance's <i>enabled</i> subset either:
/// the classic page builds its own list from <code>Security.System.AutheEnabled</code>, which
/// differs per instance, so pinning that subset would pin this container. Selecting a mechanism the
/// instance does not use returns no rows, which
/// is honest; <method>OcuPilot.Screen.Read.Execute</method> refuses anything outside the options
/// before the port is called, so the <code>-1</code> conversion is unreachable from either caller.
/// The names are vendor vocabulary carried as descriptor data, the status a namespace name has --
/// not OcuPilot copy -- so only the field's label and its unset option take string keys.</p>
/// <p><b>The agent-marker filter is a Source filter</b> (AD-15, AD-46):
/// <code>eventSources = OcuPilot</code>, the Source
/// <class>OcuPilot.Kernel.State.Base</class> declares, the installer registers and every future
/// marker carries. It <b>overrides</b> the Event source criterion rather than merging with it --
/// both name <code>eventSources</code>, and the vendor treats a comma list as membership, so
/// appending would widen the result instead of narrowing it. It is an affordance, never a default,
/// and OcuPilot's own rows are never hidden from this screen.</p>
/// <p><b>It reaches the port's async path, and that path is the self-queued one</b> (AD-26).
/// <code>Record.ShouldRunAsync()</code> answers 0 for LIST; <code>RunList</code> queues its own
/// task and answers 202 with an <code>async-result</code> location, which
/// <class>OcuPilot.Port.AdminPort</class> already polls. Nothing here declares the async path: it
/// is a property of the endpoint, and the port is where it is handled.</p>
/// <p><b>Its id is <code>composite</code> over <code>UTCTimeStamp</code>, <code>SystemID</code> and
/// <code>AuditIndex</code>, in the record's own IDKEY order</b> -- one percent-encoded path segment
/// joined by the one shared encoder (AD-13). Neither <code>AuditIndex</code> nor
/// <code>UTCTimeStamp</code> is unique across the population on its own, so no single column gives a
/// sound row key. The composite is also what gives the screen an <code>/:id</code> route, which is
/// the detail dialog's own channel: the Event name cell's link navigates to it, the page opens the
/// dialog for that row, and closing returns to the bare route.</p>
/// <p><b>The dialog renders the row already fetched, so this read declares no
/// <code>rowGet</code>.</b> The endpoint's own GET answers twenty-two keys and the LIST row carries
/// twenty-four; every GET key is a LIST key, and the LIST additionally carries
/// <code>TimeStamp</code> and <code>SessionID</code>. A detail call would issue one GET per
/// surviving row (AD-36) for no key the row lacks. It would convert one <i>value</i>: the GET runs
/// <code>Authentication</code> through <code>$$AuthenticationLogicalToDisplay</code> where the LIST
/// answers the stored integer. That conversion buys nothing here, because no surface renders the
/// mechanism (see below).</p>
/// <p><b><code>EventData</code> is out of <code>context.fields</code></b>, the screen context a
/// serializer emits (AD-24), because AD-24 names an audit event's data blob as the unbounded-row
/// case and AD-11 makes it untrusted text. It is in <code>read.fields</code>, so the dialog renders
/// it -- and so the read tool's own payload carries it too, bounded by that tool's context cap:
/// <method>OcuPilot.Screen.Tool.Read.View</method> answers the read's fields stripped of
/// <code>context.secretFields</code>, which is what AD-36 specifies, not the context roster. It is
/// not a secret field: a secret is stripped from the screen's own answer too, and the dialog needs
/// it.</p>
/// <p><b><code>Authentication</code> is not a table column.</b> It arrives as the stored logical
/// integer while the criterion beside it takes display names, so a column would read
/// <code>32</code> and would not round-trip into the field. The port normalizes vendor <i>error</i>
/// text and says nothing about result values (AD-39), so it is left unrendered rather than
/// converted. It stays in <code>read.fields</code> for the dialog and out of
/// <code>table.columns</code>.</p>
/// <p><b>It declares no <code>refreshes</code>.</b> <file>EXPERIENCE.md</file> exempts this screen
/// by name: it renders nothing until Search is pressed, so a timer would have no rows to re-read
/// (AD-43). <method>OcuPilot.Screen.Registry.CriteriaProblem</method> refuses the pair.</p>
/// <p><b>The privilege set is three pairs, in the order the gate reports in.</b></p>
/// <ul>
/// <li><code>%Admin_Secure:USE</code> -- the vendor endpoint's own gate.
/// <code>Record.ResourcesOR()</code> answers that single resource, and <code>%SYS.Audit</code>
/// re-checks the same pair for itself inside the query, so the backing class and the endpoint agree
/// here (AD-29).</li>
/// <li><code>%Admin_Operate:USE</code> -- <code>AsyncResult.ResourcesOR()</code>'s, which the port
/// polls the queued task through. A caller without it is refused <b>after</b> the task is
/// queued, so the pair is required although the LIST endpoint's own gate does not name it.</li>
/// <li><code>%DB_IRISSYS:READ</code> -- the port runs every endpoint in <code>%SYS</code>
/// (<method>OcuPilot.Screen.Registry.ReadProblem</method>'s last arm).</li>
/// </ul>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Audit.View</code></b>, spelled in the class's own
/// case because the custom-resource lookup does not case-fold (AD-44).
/// <code>%CSP.UI.Portal.Audit.Detail</code> is the classic detail page, which this screen's dialog
/// replaces. As a list archetype it links out to nothing.</p>
/// <p>It declares no primary or row action -- Epic 2 ships read tools only, and copy, purge and
/// audit-event administration are Epic 7's -- so its empty state names what to do next rather than
/// inviting the agent.</p>
Class OcuPilot.Screen.Descriptor.AuditList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/audit",
  "area": "logs",
  "labelKey": "auditListLabel",
  "sideBarPosition": 4,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "audit-record",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["UTCTimeStamp", "SystemID", "AuditIndex"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["SystemID", "AuditIndex", "TimeStamp", "EventSource", "EventType", "Event", "Pid", "SessionID", "Username", "Description", "UTCTimeStamp", "JobNumber", "Authentication", "ClientExecutableName", "ClientIPAddress", "Namespace", "Roles", "RoutineSpec", "UserInfo", "JobId", "Status", "OSUsername", "StartupClientIPAddress"], "secretFields": []},
  "emptyStateKey": "auditListEmpty",
  "commandAliases": ["audit"],
  "classicPage": "%CSP.UI.Portal.Audit.View",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Audit.Record", "type": "LIST"},
    "fields": ["SystemID", "AuditIndex", "TimeStamp", "EventSource", "EventType", "Event", "Pid", "SessionID", "Username", "Description", "UTCTimeStamp", "JobNumber", "Authentication", "ClientExecutableName", "ClientIPAddress", "EventData", "Namespace", "Roles", "RoutineSpec", "UserInfo", "JobId", "Status", "OSUsername", "StartupClientIPAddress"],
    "filter": ["TimeStamp", "EventSource", "EventType", "Event", "Username", "Pid", "Namespace", "Description"],
    "sort": {"fields": ["TimeStamp", "EventSource", "EventType", "Event", "Username", "Pid", "Namespace", "Description"], "default": "TimeStamp", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50},
        {"param": "endDateTime", "labelKey": "auditCriteriaEnd", "kind": "datetime", "maxLength": 50},
        {"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 1000},
        {"param": "eventTypes", "labelKey": "auditColumnEventType", "kind": "text", "maxLength": 1000},
        {"param": "events", "labelKey": "auditColumnEventName", "kind": "text", "maxLength": 1000},
        {"param": "usernames", "labelKey": "processColumnUser", "kind": "text", "maxLength": 1000},
        {"param": "pids", "labelKey": "processColumnPid", "kind": "text", "maxLength": 50},
        {"param": "namespaces", "labelKey": "headerNamespaceLabel", "kind": "text", "maxLength": 1000},
        {"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50, "options": ["Kerberos Credentials Cache", "Kerberos", "K5KeyTab", "Operating System", "Password", "Unauthenticated", "Kerberos with Encryption", "Kerberos with Packet Integrity", "LDAP", "Delegated", "Mutual TLS"]}
      ],
      "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}
    }
  },
  "table": {
    "columns": [
      {"field": "TimeStamp", "labelKey": "auditColumnTime", "kind": "text"},
      {"field": "EventSource", "labelKey": "auditColumnEventSource", "kind": "text"},
      {"field": "EventType", "labelKey": "auditColumnEventType", "kind": "text"},
      {"field": "Event", "labelKey": "auditColumnEventName", "kind": "name"},
      {"field": "Username", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Pid", "labelKey": "processColumnPid", "kind": "identifier"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "logs.audit"
}
}

}
