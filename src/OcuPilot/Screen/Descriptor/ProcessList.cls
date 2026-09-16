/// <p>The processes list: every process the instance is running, read through the vendor's own
/// <code>Process</code> LIST (AD-2, AD-36) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5). It is the OS management area's first screen.</p>
/// <p><b><code>Nspace</code> is the vendor's spelling, not <code>Namespace</code>.</b> The LIST row
/// answers twenty-one keys and the namespace one is <code>Nspace</code>; the column carries the
/// reader's word through its label key instead, which is the namespace switch's own accessible name.
/// A read declaring <code>Namespace</code> would project <code>null</code> into every row rather
/// than fail, so <class>OcuPilot.Test.ScreenRead</class>'s drift guard holds each declared field to
/// a key of the live row.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> The
/// process table is one instance-wide list whose rows span namespaces -- <code>%SYS</code>, the
/// install namespace, and the daemons that are in none -- so the list is the same whatever namespace
/// the route names, each row carrying its own <code>Nspace</code> as a column (AD-13). That is also
/// why the empty state names the instance rather than a namespace.</p>
/// <p><b>Its id is <code>single</code>, keyed by <code>Pid</code>:</b> one percent-encoded path
/// segment, with no second part. <code>Pid</code> is the <code>name</code> column, so it renders in
/// the code face and as the link Story 6.8's process details will answer; the link is inert until
/// that screen lands, exactly as the task schedule's Name cell is inert until 6.7.</p>
/// <p><b>It declares no write type and none of the <code>CanBe*</code> fields.</b> The vendor class
/// declares broadcast, resume, suspend and terminate request types;
/// <parameter>OcuPilot.Port.AdminPort.TYPESUFFIXES</parameter> admits <code>GET,LIST,INFO,CERTINFO</code> and
/// none of them, which is the containment. The four <code>CanBe*</code> booleans and
/// <code>CanReceiveBroadcast</code> exist only to gate those controls, so a read that carried them
/// would ship the inputs to a decision nothing here makes. Terminate, suspend, resume and broadcast
/// are Stories 5.12, 7.8 and 16.6; Epic 2 ships read tools only, so this screen declares no primary
/// action and no row action.</p>
/// <p><b>The client and identity columns are absent too</b> -- <code>Device</code>,
/// <code>ClientName</code>, <code>EXEname</code>, <code>IPAddress</code>, <code>OSUserName</code>,
/// <code>ParentPid</code>, <code>Job</code>, <code>PrvGblBlkCnt</code>, <code>CPUTime</code> and
/// <code>ElapsedTime</code>. They are Story 6.8's process details, and AD-24 caps what leaves the
/// instance to what the screen shows.</p>
/// <p><b>It declares no <code>rowGet</code>:</b> every field this screen needs is in the LIST, so no
/// detail call is ever issued and <code>context.secretFields</code> is empty because the read carries
/// no secret to strip (AD-24, AD-35). It declares no <code>banner</code> either.</p>
/// <p><b>It is one of the six screens the shared auto-refresh framework binds</b> (AD-43), named
/// first in <file>EXPERIENCE.md</file>'s roster, at the rates its auto-refresh bullet declares. The
/// framework owns the timer, the persisted setting and the silent re-fetch; the screen declares only
/// that it refreshes and at what rates. Its rows change with no write behind them -- processes start
/// and end -- so what a tick preserves is the sort, the filter and the selection, never the row set.</p>
/// <p><b>The privilege set is three pairs, and the middle one is not the endpoint's own.</b></p>
/// <ul>
/// <li><code>%Admin_Operate:USE</code> -- the vendor endpoint's own gate. Probed on this build,
/// <code>Process</code>'s <code>ResourcesOR()</code> answers that single resource, with no OR
/// alternative to narrow (unlike <code>Task.CRUD</code>).</li>
/// <li><code>%Admin_Manage:USE</code> -- what the query <i>behind</i> the endpoint requires.
/// <code>RunList</code> runs <code>SYS.Process:CONTROLPANEL</code> through
/// <code>%Api.Admin.Util.ClassQuery</code>, and
/// <method>%SYS.ProcessQuery.CONTROLPANELExecute</method> opens with
/// <code>$SYSTEM.Security.Check("%Admin_Manage","USE") ! $$$IOwnSYSDBWrite</code> -- an OR of that
/// resource with <b>write</b> on the IRISSYS database. A pair set is an AND, so the narrower half is
/// what is declared, the choice <class>OcuPilot.Screen.Area</class> records for
/// <code>Task.CRUD</code>; <code>%DB_IRISSYS:WRITE</code> is the wider half and is a
/// self-escalation primitive (Consistency Conventions). <b>Endpoint gate and query check are
/// different privileges</b>, which is why the first pair alone is not enough and why the second is
/// declared at all.</li>
/// <li><code>%DB_IRISSYS:READ</code> -- the port runs every endpoint in <code>%SYS</code>
/// (<method>OcuPilot.Screen.Registry.ReadProblem</method>'s last arm).</li>
/// </ul>
/// <p><b>Without the second pair the read answers 500, not a named 403</b>, because
/// <code>ClassQuery.RunQuery</code> does not check what <code>%Execute()</code> answered: the
/// refused query yields no result set and the port raises
/// <code>&lt;INVALID OREF&gt;AppendStatementResult+5^%Api.Admin.Util.ClassQuery.1</code>. Observed
/// on a throwaway with a real principal holding the first and third pairs and not the second, and
/// the same principal plus <code>%Admin_Manage:USE</code> is served 200. Declaring it is what turns
/// that into the named refusal AD-8 asks for.</p>
/// <p>The order is the order <method>OcuPilot.Screen.Gate.EvaluatePairs</method> reports in -- it
/// names the first pair a caller does not hold -- and both wire fixtures pin the name.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Processes</code></b>, spelled in the class's own
/// case because the custom-resource lookup does not case-fold (AD-44).
/// <code>%CSP.UI.Portal.ProcessDetails</code> is Story 6.8's, not this screen's. As a list archetype
/// it links out to nothing.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next rather than
/// inviting the agent.</p>
Class OcuPilot.Screen.Descriptor.ProcessList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/processes",
  "area": "os-management",
  "labelKey": "processListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "process",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Pid", "Username", "Nspace", "Routine", "State", "Commands", "Globals"], "secretFields": []},
  "emptyStateKey": "processListEmpty",
  "commandAliases": ["jobs"],
  "classicPage": "%CSP.UI.Portal.Processes",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Process", "type": "LIST"},
    "fields": ["Pid", "Username", "Nspace", "Routine", "State", "Commands", "Globals"],
    "filter": ["Pid", "Username", "Nspace", "Routine", "State"],
    "sort": {"fields": ["Pid", "Username", "Nspace", "Routine", "State", "Commands", "Globals"], "default": "Pid", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Pid", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "Username", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Nspace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Routine", "labelKey": "processColumnRoutine", "kind": "identifier"},
      {"field": "State", "labelKey": "processColumnState", "kind": "text"},
      {"field": "Commands", "labelKey": "processColumnCommands", "kind": "number"},
      {"field": "Globals", "labelKey": "processColumnGlobals", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.processes"
}
}

}
