/// <p>The application error log: the errors applications on this instance actually threw, read
/// through <code>SYS.ApplicationError</code>'s own queries and drilled namespaces &#8594; dates
/// &#8594; errors &#8594; one error's captured detail (AD-48, FR-63). It is the Logs area's second
/// screen.</p>
/// <p><b>It declares no <code>read</code>, and that is not an omission</b> (AD-36).
/// <code>read</code> is singular with a closed key set, and the client's refresh framework holds
/// exactly one binding, so three drill levels with three different column sets could not be one
/// declared read whatever port served them.</p>
/// <p>A descriptor that declares no read is a supported shape --
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> quits early,
/// <method>OcuPilot.Screen.Registry.TableProblem</method> is never reached, and the
/// <code>%DB_IRISSYS:READ</code> rule lives inside the read arm -- and it costs the screen its
/// descriptor-derived tool. That tool is supplied instead by the registry's <b>other</b> documented
/// source: <class>OcuPilot.Screen.Tool.ErrorRead</class>, a class extending
/// <class>OcuPilot.Screen.Tool.Base</class> with its own <code>TOOLNAME</code> and
/// <code>KIND</code>. AD-36's "one read shared by screen and tool" is met where this source's read
/// actually lives -- at <method>OcuPilot.Port.LogSourcePort.Errors</method>, the entry point both
/// callers use. <method>OcuPilot.Screen.Tool.Registry.Claim</method> refuses a name two sources
/// hold, so a later story that gave this descriptor a <code>read</code> would be refused rather
/// than resolve to either.</p>
/// <p><b>The privilege set is two pairs, and the rest is resolved per namespace at the port.</b>
/// <code>%Admin_Operate:USE</code> is what the classic portal requires of these screens and what
/// the instance-wide namespace enumeration is gated on. <code>%DB_IRISSYS:READ</code> is
/// <b>measured, not inherited</b> (AD-29): <code>SYS.ApplicationError</code> exists only in
/// <code>%SYS</code>, whose routine database is IRISSYS, and database READ <i>is</i>
/// routine-execution permission -- a real least-privileged principal without it was refused by
/// IRIS itself rather than by this screen's gate, which is a 500 naming no pair. Both are already
/// in the <code>logs</code> area's own set.</p>
/// <p>The read and write this screen also needs on the <i>selected</i> namespace's globals database
/// cannot be declared here at all: <code>^ERRORS</code> is unmapped and lives in each namespace's
/// own database, so the requirement is a function of the drill level the user has reached (AD-48),
/// and a <code>%DB_&lt;ns&gt;</code> pair the <code>logs</code> area does not declare would be
/// refused by <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> besides.
/// <method>OcuPilot.Port.LogSourcePort.PairsFor</method> resolves it at call time.</p>
/// <p><b>The captured detail is secret by default</b> (AD-48). <code>context.fields</code> carries
/// the five summary fields and nothing else, so the screen context a turn sends can never include a
/// variable table -- every local at every stack level plus <code>$ROLES</code> and
/// <code>$USERNAME</code>, which on an IRIS for Health instance can hold patient data. The user
/// reads that table on screen; the agent does not. Secrecy here is enforced by <b>which query is
/// called</b>: the summary path calls <code>ErrorList</code>, whose row structurally carries no
/// variable table, and <code>ErrorDetail</code> is reachable from the detail route alone.</p>
/// <p><b>Its id is <code>composite</code> over the namespace, the date and the error number</b>,
/// which is the triple that identifies one entry (AD-13) -- an error number is unique only within
/// one namespace and date. The route carries no scope: <code>scope</code> is
/// <code>instance</code> because the screen enumerates namespaces itself and the namespace it acts
/// on has exactly one source, the level the user drilled to. The route's <code>?ns=</code> (AD-44)
/// does not reach this screen's reads.</p>
/// <p><b>It declares no <code>refreshes</code></b>: <file>EXPERIENCE.md</file>'s Auto-refresh
/// controls roster -- Processes, Databases, Database details, Task schedule, Task details, System
/// usage -- does not name it (AD-43). The roster is cited by its own words rather than by a line
/// number, because an insert anywhere above it moves the number and nothing re-resolves it
/// (DW-272). <b>No primary or row action</b>: AD-48's three
/// delete scopes are Epic 5's, where a proposal, a confirm and an audit marker first exist.</p>
/// <p><b>The classic page is <code>%cspapp.op.utilsysapperrornamespaces</code></b>, the drill's own
/// entry point, spelled in the class's own case because the custom-resource lookup does not
/// case-fold (AD-44). None of the four classic classes declares a <code>RESOURCE</code> or
/// <code>SECURITYRESOURCE</code> of its own -- a genuine negative from
/// <class>%Dictionary.CompiledParameter</class>, not a failed lookup -- so the requirement lives on
/// the <code>/csp/sys/op</code> web application, which carries <code>%Admin_Operate</code>. As a
/// <code>drill-down</code> archetype, which <class>OcuPilot.Screen.Archetype</class> classifies
/// <code>list</code>, it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.LogErrorList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/errors",
  "area": "logs",
  "labelKey": "errorLogListLabel",
  "sideBarPosition": 3,
  "archetype": "drill-down",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "application-error",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["namespace", "date", "errorNumber"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["errorNumber", "time", "errorText", "routine", "line"], "secretFields": []},
  "emptyStateKey": "errorLogEmptyInstance",
  "commandAliases": ["application errors"],
  "classicPage": "%cspapp.op.utilsysapperrornamespaces",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "logs.applicationerrors"
}
}

}
