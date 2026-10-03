/// <p>The port to the instance's own administration API (AD-2, AD-26, AD-27). <b>This is the
/// only class in the tree that names an <code>%Api.Admin.*</code> class</b>, and it names them
/// only through the parameters below, so a vendor change has a blast radius of one file.</p>
/// <p><method>Invoke</method> is the one way to call an admin endpoint. A caller names the
/// endpoint package-relative (<code>WebApp.App</code>) and the request type by its vendor
/// parameter suffix (<code>GET</code>, <code>LIST</code>, <code>INFO</code>, <code>CERTINFO</code>,
/// <code>UPCOMING</code>, <code>HISTORY</code>), and receives
/// either the endpoint's result or an error <class>%Status</class> with a wire-safe fault. The
/// call reproduces <code>Dispatch.v1:Main()</code> on the pinned build, in its order: construct
/// at <parameter>APIVERSION</parameter>, gate on <code>ResourcesOR()</code>, seed
/// <code>%request.Data</code> and run <code>SaveQueryParams()</code> then
/// <code>ValidateQueryParams()</code>, <code>ValidateRequest()</code>,
/// <code>ValidateSemantics()</code>, <code>ShouldRunAsync()</code>, and
/// <code>Run()</code> inside the vendor's output capture. The sequence runs in
/// <code>%SYS</code>, reached by save and restore (AD-16), behind port-owned
/// <code>%request</code>, <code>%response</code> and <code>%session</code> stubs that are
/// <code>New</code>ed in the invoking frame, so the caller's own CSP objects are never read or
/// written and <code>IsRunningAsync</code> stays 0.</p>
/// <p>Success is exactly an OK vendor status under a 2xx HTTP status. An answer of
/// <code>202</code> whose <code>Location</code> names an <code>async-result</code> id is polled
/// through the <code>AsyncResult</code> endpoint until the task is terminal or
/// <method>AsyncTimeout</method> passes (AD-26), whichever entry queued it; a terminal task's row
/// is deleted by the port. Nothing is cached across calls (AD-8): every invocation first
/// re-runs <method>VerifyInstance</method>.</p>
/// <p><method>TemplateMethod</method> and <method>Template</method> resolve and evaluate an
/// endpoint's body template for the build-time field-list derivation (AD-3); nothing on a
/// request path calls them.</p>
/// <p><b>A failure the endpoint's own gate did not catch is probed once more before it is
/// reported</b> (AD-29, DW-274). <code>ResourcesOR()</code> is a lower bound: the query behind an
/// endpoint may require more, and its refusal reaches this port only as an error status the
/// sequence turns into a 500 naming nothing. So on the error path -- and only there --
/// <method>QueryPairRefused</method> evaluates the pair set <parameter>QUERYPAIRS</parameter>
/// declares for that endpoint and request type, and a caller holding none of it is answered 403
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> instead.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.PortFixture</class>):
/// <method>AdminApiClass</method>, <method>ProbeEndpointClass</method>,
/// <method>EndpointClass</method>, <method>HoldsResource</method>, <method>QueryPairs</method>,
/// <method>HoldsPair</method>, <method>OnBeforeRun</method>,
/// <method>PollTask</method>, <method>ForgetTask</method>, <method>AsyncTimeout</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.AdminPort Extends %RegisteredObject
{

/// <p>The vendor's admin API routing class, whose <code>UrlMap</code>
/// <method>HighestDispatchVersion</method> reads.</p>
Parameter ADMINAPICLASS = "%Api.Admin";

/// <p>The package the vendor's endpoint classes live in. Named here, not in the inventory
/// fixture that enumerates them, so AD-27's containment holds for the literal as well as
/// for the calls.</p>
Parameter ENDPOINTPACKAGE = "%Api.Admin.Endpoints.";

/// <p>The vendor base class every endpoint extends. It declares <code>TYPEGET</code> and
/// <code>TYPELIST</code> for all of them and answers <code>{}</code> for a read its subclass
/// does not implement.</p>
Parameter ENDPOINTBASECLASS = "%Api.Admin.Endpoint";

/// <p>The endpoint whose answers stand for the whole API's contract. Chosen because it is
/// read-only, takes no request body and needs no query parameter, so constructing it and
/// asking it three questions changes nothing on the instance.</p>
Parameter PROBEENDPOINT = "%Api.Admin.Endpoints.WebSession";

/// <p>The API version OcuPilot is built against (NFR-8). Every endpoint is constructed at
/// this version (AD-2, step 1).</p>
Parameter APIVERSION As INTEGER = 2;

/// <p>The request type the probe is constructed with -- the vendor's
/// <code>TYPELIST</code>. Spelled as its number because reading the vendor's parameter for
/// it would mean a second class naming an <code>%Api.Admin.*</code> class.</p>
Parameter PROBETYPE As INTEGER = 0;

/// <p>The base of every async task row, whose IdKey is the task's GUID. Named for
/// <method>ForgetTask</method>'s delete and for the terminal state names.</p>
Parameter ASYNCTASKCLASS = "%Api.Admin.Util.AsyncTask";

/// <p>The async task row that hands a <code>%SYS.BackgroundTask</code> to the vendor's queue and
/// stores its id as <code>SysBGTaskId</code> (read on this build): the queued disk operations' rows,
/// which <class>OcuPilot.Port.BackgroundTaskPort</class> links to their background task (Story 18.4,
/// DW-1821).</p>
Parameter ADMINTASKCLASS = "%Api.Admin.Endpoints.Database.AsyncTaskSysBackground";

/// <p>The task class <code>Main()</code> hands an endpoint to when
/// <code>ShouldRunAsync()</code> is true.</p>
Parameter ASYNCTASKENDPOINTCLASS = "%Api.Admin.Util.AsyncTaskEndpoint";

/// <p>The class holding the vendor's <code>BeginCaptureOutput</code> and
/// <code>EndCaptureOutput</code>.</p>
Parameter CAPTURECLASS = "%Api.Admin.Util.General";

/// <p>The package-relative endpoint an async task is polled through.</p>
Parameter ASYNCRESULTENDPOINT = "AsyncResult";

/// <p>What a <code>Location</code> header carries before a task's GUID when an endpoint queued
/// work and answered <code>202</code>.</p>
Parameter ASYNCLOCATION = "async-result?id=";

/// <p>The request-type suffixes <method>Invoke</method> accepts, each resolved through the
/// endpoint's own <code>TYPE&lt;suffix&gt;</code> parameter. Reads only.</p>
/// <p><code>CERTINFO</code> is <code>Security.X509Credential</code>'s certificate read: that
/// endpoint's LIST carries no subject, issuer or validity, and its <code>CERTINFO</code> answers all
/// three, so they are reachable only through it (AD-36).</p>
/// <p><code>UPCOMING</code> is <code>Task.CRUD</code>'s scheduled-occurrence list, a list-shaped read
/// the endpoint answers synchronously: it defines no <code>ShouldRunAsync</code> and its
/// <code>RunUpcoming</code> queues nothing (AD-26, AD-36).</p>
/// <p><code>HISTORY</code> is the same endpoint's task-run history (Story 6.6), dispatched to
/// <code>RunHistory</code>: synchronous for the same reason <code>UPCOMING</code> is.</p>
/// <p><code>VOLUMELIST</code> is <code>Database.SysCRUD</code>'s volume-file list (Story 6.11):
/// the vendor publishes it <code>TYPE</code>-prefixed (<code>TYPEVOLUMELIST</code>), so it
/// resolves here rather than through <parameter>BARETYPES</parameter>, and it is synchronous --
/// only that endpoint's <code>TYPEINFO</code> answers <code>ShouldRunAsync()</code> true.</p>
/// <p><code>OWNERLIST</code> is <code>Security.Role</code>'s holder list (Story 9.3): the accounts and
/// roles that hold one role, as <code>[{Name, Type, AdminOption}]</code>, 404 for an absent role. It is
/// synchronous: that endpoint's <code>ShouldRunAsync()</code> answers 0 for it (measured on this
/// build).</p>
/// <p><code>ACTIVITY</code> is <code>LanguageServer</code>'s activity read (Story 16.10), which requires
/// <code>name</code>: <code>{Activity: [{ID, DateTime, RecordType, Job, Text}], CurrentlyRunning}</code>,
/// the rows newest first from <code>%Net.Remote.ActivityLog</code> and bounded by <code>maxRows</code>,
/// <code>CurrentlyRunning</code> from <code>%Net.Remote.Service.IsGatewayRunning</code>, which pings the
/// server with a 10 s timeout unless it is local and its port is free, so a <code>Remote</code>
/// server is always pinged; 404 for a name the instance does not define, which is compared with
/// its case. It is synchronous: the endpoint defines no <code>ShouldRunAsync</code> (measured on
/// <code>ocupilot-ci</code>).</p>
Parameter TYPESUFFIXES = "GET,LIST,INFO,CERTINFO,UPCOMING,HISTORY,VOLUMELIST,OWNERLIST,ACTIVITY";

/// <p>The <b>mutating</b> <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs <method>Invoke</method>
/// accepts, each type resolved through that endpoint's own <code>TYPE&lt;suffix&gt;</code>
/// parameter exactly as <parameter>TYPESUFFIXES</parameter> is. Listed apart from the reads
/// because the two are not interchangeable to a reviewer: everything in the other list changes
/// nothing on the instance, and everything here does.</p>
/// <p><b>Keyed by the pair, not by the suffix</b> (DW-1473), the grammar
/// <parameter>BODYLESSTYPES</parameter> and <parameter>BARETYPES</parameter> already use. A bare
/// suffix admits a type on <i>every</i> endpoint that happens to declare a parameter of that name:
/// <code>SUSPEND</code> was admitted for <code>Task.CRUD</code>, whose
/// <code>TYPESUSPEND</code> exists, although no shipped tool issues it and AD-10 has no predicate
/// for it. The pair is the widening removed.</p>
/// <p><b>The nine are the ones the registry actually reaches</b>, established three ways: the
/// registry's own discovery rule, a whole-tree sweep of
/// <code>Extends OcuPilot.Screen.Tool.Write</code> including transitive subclasses, and
/// <class>OcuPilot.Test.SurfaceCoverage</class>'s both-directions assertion.
/// <class>OcuPilot.Screen.Tool.ErrorDelete</class>'s <code>DELETE</code> is legitimately absent:
/// it declares <code>LogSourcePort</code> and reaches its target through that port (AD-52).</p>
/// <p><b>A dropped pair is the high-risk direction.</b> The gate runs after the claim has
/// committed and the token is spent, so a pair missing here 501s a merge write the user already
/// confirmed. Every pair is asserted against the registry by
/// <class>OcuPilot.Test.ToolWrite</class>.</p>
/// <p><b>Reached only from a confirmed write path.</b> A mutating call is issued by
/// <class>OcuPilot.Kernel.Proposal.Operation</class> for <class>OcuPilot.Kernel.Proposal.Confirm</class>'s
/// transition, after its claim has committed (AD-34, AD-40), and for a screen's own row action or
/// Save (AD-53, AD-55); some editors' Save handlers call <method>Invoke</method> themselves with
/// the endpoint and write type their tool class declares, after AD-10's prohibited set, and the
/// install smoke restores its own write target with a direct call. No model tool call, no screen
/// read and no turn reaches one, and the port itself decides nothing about whether the write may
/// happen.</p>
/// <p><b>Synchronous except for <parameter>QUEUEDWRITES</parameter>.</b> Every other pair's
/// <code>ShouldRunAsync()</code> answers false, so the call runs in the caller's job and its answer
/// is the endpoint's own. A mutating request that would queue is refused by <method>Sequence</method>
/// before the vendor's task row is written, because that row would carry a supplied secret from the
/// body (AD-35, DW-1279), unless its pair is in <parameter>QUEUEDWRITES</parameter>, whose bodies
/// carry none and which take AD-26's async path. <method>Sequence</method> reads
/// <code>%request.Method</code>, which <method>HttpMethodFor</method> has already set to the
/// mutating suffix itself -- for <code>RESUME</code> that value is the vendor's request-type
/// suffix rather than an HTTP verb, since the vendor exposes the operation only as a request
/// type -- and asks it of the endpoint name threaded in beside it, never of the suffix alone.</p>
/// <p><code>WebApp.App/DELETE</code> is <class>OcuPilot.Screen.Tool.WebAppDelete</class>'s
/// (Story 7.1, AD-51). Measured on this build: the endpoint's <code>TYPEDELETE</code> is 3, its
/// <code>NeedsRequestBody()</code> is <code>..IsTypePut()</code> so the type reads no body, and its
/// <code>ValidateQueryParams</code> requires the <code>name</code> query parameter -- so it is
/// listed in <parameter>BODYLESSTYPES</parameter> under its own endpoint too. The
/// <code>:159-163</code> note that <code>DELETE</code> is deliberately absent is scoped to
/// <code>Process</code>, whose delete is its terminate.</p>
/// <p><code>RESUME</code> is <code>Task.CRUD</code>'s bodyless resume and <code>Process</code>'s
/// own (AD-51, Stories 5.11 and 5.12), and <code>SUSPEND</code> is <code>Process</code>'s
/// suspend. Each vendor <code>NeedsRequestBody()</code> excludes them, each
/// <code>ValidateQueryParams</code> requires the <code>id</code> query parameter, and each is
/// listed in <parameter>BODYLESSTYPES</parameter> under its own endpoint, which is what exempts
/// it from the object-body refusal below.</p>
/// <p><code>Process/DELETE</code> is deliberately absent. The vendor exposes terminating a process
/// through both <code>TERMINATE</code> and <code>DELETE</code> -- <code>Process</code>'s
/// <code>RunDelete</code> is a one-line delegate to <code>RunTerminate</code> -- and Story 7.8's
/// terminate tools issue <code>TERMINATE</code> alone, through <class>OcuPilot.Port.ProcessPort</class>
/// (AD-52), with AD-10's refusal of IRIS system processes evaluated at the write. So
/// <code>DELETE</code> does not pair with <code>Process</code>, and <method>EndpointType</method>
/// answers <code>""</code> for it.</p>
/// <p><code>Security.OAuth2.Client.ClientConfiguration/DELETE</code> and
/// <code>Security.OAuth2.ServerClients/DELETE</code> are Story 7.3's
/// (<class>OcuPilot.Screen.Tool.OAuthClientDelete</class>,
/// <class>OcuPilot.Screen.Tool.OAuthServerClientDelete</class>, AD-51). Measured on this build: each
/// endpoint's <code>RunDelete</code> answers 404 when the object does not exist and otherwise calls
/// its class's <code>DeleteId</code>; the first's <code>NeedsRequestBody()</code> is a put or the
/// change-secret type and the second's a put, a post or the secret type, so neither reads a body
/// for <code>DELETE</code>; and they require <code>applicationName</code> and <code>clientId</code>
/// respectively. Both are listed in <parameter>BODYLESSTYPES</parameter> under their own
/// endpoints.</p>
/// <p><code>Security.User/DELETE</code> and <code>Security.User/CHANGEPWD</code> are Story 7.2's
/// (<class>OcuPilot.Screen.Tool.UserDelete</class>, <class>OcuPilot.Screen.Tool.UserPassword</class>,
/// AD-51, AD-56). Read on this build: the endpoint's <code>RunDelete</code> answers 404 for an
/// account <code>Security.Users.Exists</code> denies and otherwise calls
/// <code>Security.Users.Delete</code>; <code>TYPECHANGEPWD</code> is 10, its
/// <code>RunChangePassword</code> sets only the password from the body's <code>NewPassword</code>,
/// and <code>NeedsRequestBody()</code> is a put, a post or that type -- so <code>DELETE</code> is
/// listed in <parameter>BODYLESSTYPES</parameter> and <code>CHANGEPWD</code> is not.</p>
/// <p><code>Task.CRUD/RUN</code> is Story 7.5's (<class>OcuPilot.Screen.Tool.TaskRun</class>,
/// AD-51). Measured on this build: <code>TYPERUN</code> is 12, <code>NeedsRequestBody()</code>
/// includes it, <code>ValidateRequest</code> requires <code>RunNow</code>, and
/// <code>ResourcesOR()</code> answers <code>%Admin_Task</code> for it. Its body is a vendor
/// constant no caller supplies, so it is listed in <parameter>CONSTANTBODIES</parameter> rather
/// than in <parameter>BODYLESSTYPES</parameter>.</p>
/// <p><code>Task.CRUD/SUSPEND</code> and <code>Task.CRUD/DELETE</code> are Story 7.6's
/// (<class>OcuPilot.Screen.Tool.TaskSuspend</class>, <class>OcuPilot.Screen.Tool.TaskDelete</class>,
/// AD-51). Measured on this build: <code>SUSPEND</code> reads a body, answers 415 without one and
/// 400 for a key it does not know, and its <code>RunSuspend</code> reads
/// <code>LeaveInQueue</code> (default 1, "Suspend Leave"), so it is listed in
/// <parameter>CONSTANTBODIES</parameter>; <code>DELETE</code> reads no body and its
/// <code>RunDelete</code> is <code>%DeleteId</code>, which removes a system task as readily as a
/// user one, so it is listed in <parameter>BODYLESSTYPES</parameter>. Both answer 404 for an
/// unknown id; <code>ResourcesOR()</code> answers <code>%Admin_Task</code> for
/// <code>SUSPEND</code> and <code>%Admin_Task</code> or <code>%Admin_Operate</code> for
/// <code>DELETE</code>.</p>
/// <p><code>Security.Role/PUT</code> and <code>Security.Role/DELETE</code> are Story 8.3's role
/// create and delete. Read on this build: the endpoint overrides <code>Run</code>, its
/// <code>RunPut</code> modifies a role that exists and otherwise creates it (an upsert, which the
/// create's absence fingerprint guards, AD-54), its <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code> so <code>DELETE</code> reads no body, and its <code>RunDelete</code>
/// answers 404 for an absent role and otherwise reports success whatever the drop did
/// (<parameter>VERIFIEDDELETES</parameter>).</p>
/// <p><code>Security.Resource/PUT</code> and <code>Security.Resource/DELETE</code> are Story 8.4's
/// resource create, edit and delete. Read on this build: the endpoint does not override
/// <code>Run</code>; its <code>RunPut</code> creates an absent resource (201) and otherwise modifies
/// only the keys the body carries; its <code>NeedsRequestBody()</code> is <code>..IsTypePut()</code>
/// so <code>DELETE</code> reads no body; and its <code>RunDelete</code> answers 409 for a system
/// resource and 404 for an absent one. A <code>PUT</code> is re-read
/// (<parameter>VERIFIEDWRITES</parameter>), and one whose public permission is none is completed
/// through the vendor class (<parameter>CLASSCOMPLETEDTYPES</parameter>).</p>
/// <p><code>Security.X509Credential/POST</code>, <code>/PUT</code> and <code>/DELETE</code> are Story
/// 8.5's X.509 import, edit and delete. Read on this build: the endpoint overrides <code>Run</code>
/// (for <code>CERTINFO</code>); its <code>RunPut</code> opens the alias (404 when absent) and sets
/// only the keys the body carries; its <code>NeedsRequestBody()</code> is <code>PUT</code> or
/// <code>POST</code>, so <code>DELETE</code> reads no body; and its <code>POST</code> takes the
/// certificate and key only as server file paths, so the port completes it from content instead
/// (<parameter>CONTENTCOMPLETEDTYPES</parameter>).</p>
/// <p><code>Wallet.Secret/PUT</code> is Story 8.6's wallet secret create and edit. Read on this build:
/// its <code>RunPut</code> modifies a secret that exists and otherwise creates it (an upsert, which
/// the create's absence fingerprint and the edit's fresh read guard, AD-4, AD-54); a modify sets
/// only the keys the body carries and keeps the stored value when <code>Secret</code> is absent or
/// empty; and it answers 400 for an unknown key and 422 for an absent collection. The body is a
/// wrapper (<parameter>WRAPPEDTYPES</parameter>).</p>
/// <p><code>Device.Standard/PUT</code> and <code>/DELETE</code> are Story 8.8's device create, edit
/// and delete. Read on this build: its <code>RunPut</code> modifies a device that exists and otherwise
/// creates it (an upsert, which the create's absence fingerprint and the edit's fresh read guard,
/// AD-4, AD-54), setting only the keys the body carries; its <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body; and its <code>RunDelete</code>
/// answers 404 for an absent device (<parameter>VERIFIEDDELETES</parameter>).</p>
/// <p><code>Security.SSLConfig/PUT</code> and <code>/DELETE</code> are Story 9.5's SSL/TLS
/// configuration create, edit and delete. Read on this build: the endpoint overrides
/// <code>Run</code>; its <code>RunPut</code> modifies a configuration that exists and otherwise
/// creates it (an upsert, which the create's absence fingerprint and the edit's fresh read guard,
/// AD-4, AD-54), setting only the keys the body defines; its <code>NeedsRequestBody()</code> is a
/// put, the test type or the password type, so <code>DELETE</code> reads no body; and its
/// <code>RunDelete</code> answers 404 for an absent configuration. Every class-level refusal of a
/// value answers 500, which <parameter>PROPERTYFAULTS</parameter> maps where the value cannot be
/// checked beforehand.</p>
/// <p><code>Task.CRUD/POST</code> is Story 9.7's task create. Read on this build: its
/// <code>RunPost</code> saves a new <code>%SYS.Task</code> from the body (every key but
/// <code>Settings</code> is required) and answers 201 with the new id only in its
/// <code>Location</code> header, which <method>InvokeLocated</method> keeps for the caller
/// (<class>OcuPilot.Port.TaskPort</class>). A save-time refusal answers 500 carrying the vendor code,
/// which <parameter>PROPERTYFAULTS</parameter> maps to its field. It accepts a duplicate name, so the
/// create's absence read is OcuPilot's (AD-54).</p>
/// <p><code>Task.CRUD/PUT</code> is Story 9.8's task edit. Read on this build: its <code>RunPut</code>
/// is <code>%OpenId</code>, <code>MergeJsonAndObj</code> and <code>%Save</code>, setting only the keys
/// the body defines, and a body carrying <code>Settings</code> replaces every setting.
/// <class>OcuPilot.Port.TaskPort</class> trims the body the vendor refuses or would misread (AD-4's
/// named exception), and the save-time refusals map through the same
/// <parameter>PROPERTYFAULTS</parameter> rows as the create's.</p>
/// <p><code>Wallet.Secret/DELETE</code> is Story 9.5's wallet secret delete. Read on this build: the
/// endpoint does not override <code>Run</code>, its <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, and its <code>RunDelete</code> answers 404 for a name
/// <code>%Wallet.Secret.Exists</code> denies -- an absent or wrong-case one -- and otherwise deletes
/// it (measured on <code>ocupilot-ci</code>: 200).</p>
/// <p><code>Security.Service/PUT</code> and <code>Security.LDAP/PUT</code> are Story 9.9's reduced
/// editors. Read on this build: the service's <code>RunPut</code> answers 404 for an absent name and
/// passes <code>AutheEnabled</code>, <code>ClientSystems</code> and <code>Enabled</code> to
/// <code>Security.Services.Modify</code>, dropping <code>Description</code>; the LDAP
/// configuration's <code>RunPut</code> modifies a present name and creates an absent one (an upsert,
/// so the write's fingerprint is what refuses a deleted target, AD-4).</p>
/// <p><code>Security.OAuth2.Server/REVOKE</code> is Story 12.2's token revoke
/// (<class>OcuPilot.Screen.Tool.UserTokenRevoke</class>, through <class>OcuPilot.Port.TokenPort</class>,
/// AD-51, AD-52). Read on this build: <code>TYPEREVOKE</code> is 10, the endpoint overrides
/// <code>Run</code>, its <code>NeedsRequestBody()</code> is a put or <code>CHANGEPWD</code> so the type
/// reads no body, and its <code>RunRevoke</code> calls <code>OAuth2.Server.AccessToken.RevokeUser</code>
/// with the required <code>user</code> query parameter and answers <code>{}</code>, discarding the
/// count. <code>ResourcesOR()</code> answers <code>%Admin_OAuth2_Registration</code> for it, and the
/// vendor's delete also requires <code>%Admin_Secure:USE</code>. Measured on a throwaway: it answers
/// 200 for a user holding no token, matches the tokens' user name exactly, and records no audit
/// event.</p>
/// <p><code>Security.Audit.Record/COPY</code> and <code>/PURGE</code> are Story 12.3's
/// (<class>OcuPilot.Screen.Tool.AuditCopy</class>, <class>OcuPilot.Screen.Tool.AuditPurge</class>,
/// through <class>OcuPilot.Port.AuditPort</class>). Read on this build: <code>TYPECOPY</code> is 10
/// and <code>TYPEPURGE</code> 11, both read a body and both answer <code>ShouldRunAsync()</code>
/// true, so each is queued (<parameter>QUEUEDWRITES</parameter>); <code>RunCopy</code> calls
/// <code>%SYS.Audit.Copy</code> and <code>RunPurge</code> <code>%SYS.Audit.Delete</code>, each
/// discarding its count; <code>ResourcesOR()</code> is <code>%Admin_Secure</code>.</p>
/// <p><code>Namespace.Namespace/PUT</code> and <code>/DELETE</code> are Story 18.2's namespace
/// create, edit and delete. Read on this build: the <code>RunPut</code> modifies a present namespace
/// and creates an absent one (an upsert, 201 on a create), keeping every field its body omits; the
/// <code>RunDelete</code> answers 404 for an absent name, 409 for a system namespace, and otherwise
/// deletes the namespace, its mappings and every web application bound to it, never a database.
/// Both write the system database, and a caller without <code>%DB_IRISSYS:WRITE</code> is refused
/// <code>&lt;PROTECT&gt;</code> with nothing changed (measured on <code>ocupilot-b-ci</code>).</p>
/// <p><code>WebSession/DELETE</code> is Story 16.2's session end
/// (<class>OcuPilot.Screen.Tool.WebSessionEnd</class>, AD-51). Measured on this build: it takes the
/// session as its <code>id</code> query parameter and reads no body, answers 404 for an unknown id,
/// and otherwise calls <code>$$DeleteSession^%SYS.cspServer</code>, which marks the session for the
/// instance's own daemon to remove (<parameter>AWAITEDDELETES</parameter>); it records no audit
/// event.</p>
/// <p><code>AsyncResult/CANCEL</code>, <code>/PAUSE</code> and <code>/RESUME</code> are Story 16.5's
/// control of the caller's own async task, issued by <class>OcuPilot.Port.BackgroundTaskPort</class>
/// (<parameter>OcuPilot.Port.BackgroundTaskPort.DELEGATEDTYPES</parameter>). Read on this build:
/// <code>TYPECANCEL</code>, <code>TYPEPAUSE</code> and <code>TYPERESUME</code> are 10, 11 and 12, the
/// endpoint overrides <code>Run</code>, <code>NeedsRequestBody()</code> is a <code>PATCH</code> alone,
/// <code>ValidateQueryParams</code> requires <code>id</code>, another user's task answers 404, and a
/// task whose state refuses the request answers 409; each answers synchronously (measured).
/// <code>BackgroundTask/CANCEL</code>, <code>/PAUSE</code> and <code>/RESUME</code> are that port's own
/// pseudo-endpoint, which the three Background tasks tools declare, registered as
/// <code>Process/TERMINATE</code> is for <class>OcuPilot.Port.ProcessPort</class>.</p>
/// <p>The three <code>Namespace.{Global,Routine,Package}Mappings</code> <code>PUT</code> and
/// <code>DELETE</code> pairs are Story 18.14's mapping writes, and <code>Namespace.Namespace/MAPPINGS</code>
/// its copy of mappings (through <class>OcuPilot.Port.NamespacePort</class>). Read on this build:
/// each mapping endpoint requires the <code>namespace</code> query parameter, and <code>name</code>
/// on every type but <code>LIST</code>; its <code>PUT</code> is an upsert (201 on a create, 200 on an
/// edit that keeps the fields its body omits), and its <code>DELETE</code> reads no body and answers
/// 404 for an absent mapping. <code>MAPPINGS</code> reads the strict body
/// <code>{SourceNamespace, DestinationNamespace}</code> and is queued
/// (<parameter>QUEUEDWRITES</parameter>). Every one writes the system database, and a caller without
/// <code>%DB_IRISSYS:WRITE</code> is refused with nothing changed (measured on
/// <code>ocupilot-b-ci</code>).</p>
/// <p><code>Process/BROADCAST</code> is Story 16.6's broadcast
/// (<class>OcuPilot.Screen.Tool.ProcessBroadcast</class>), whose body
/// <class>OcuPilot.Port.ProcessPort</class> composes (AD-51). Read on this build:
/// <code>TYPEBROADCAST</code> is 10, <code>NeedsRequestBody()</code> admits it, its strict
/// <code>ValidateRequest</code> takes exactly <code>{Message, PidList}</code>, and it answers
/// <code>{}</code> whether or not any pid received the message; it records no audit event.</p>
/// <p>The five <code>Database.*</code> pairs are Story 18.3's database writes, each issued through
/// <class>OcuPilot.Port.DatabasePort</class>. Measured on <code>ocupilot-b-ci</code>:
/// <code>Database.SysCRUD/POST</code> creates the directory and <code>IRIS.DAT</code> and mounts the
/// file, answering 201, and makes no configuration and no resource; a directory already holding an
/// <code>IRIS.DAT</code> is refused 500 with the file intact. <code>Database.SysCRUD/PUT</code> keeps
/// every field its body omits and needs no pair beyond the reads' but <code>%Admin_Secure:USE</code>
/// for a resource change. <code>Database.SysCRUD/DELETE</code> reads no body and deletes the file and
/// its volume files whatever still uses it. <code>Database.ConfigCRUD/PUT</code> is an upsert that
/// keeps omitted fields, and <code>Database.ConfigCRUD/DELETE</code> reads no body and answers 409
/// #429 while a namespace uses the database. Every one but the two <code>SysCRUD</code>
/// <code>PUT</code> and <code>DELETE</code> writes the system database and is refused without
/// <code>%DB_IRISSYS:WRITE</code>.</p>
/// <p><code>LanguageServer/START</code> and <code>/STOP</code> are Story 16.10's
/// (<class>OcuPilot.Screen.Tool.LanguageServerStart</class>, AD-51). Measured on <code>ocupilot-ci</code>:
/// each takes <code>name</code>, reads no body and answers 404 for an absent server. A start runs
/// <code>%Net.Remote.Service.StartGateway</code> and answers 200 <code>{}</code> once the server
/// answers, in 10.7 to 14.7 s for a Java server, and 200 in 0.2 s for one already running; a
/// <code>JavaHome</code> that names no JVM answers 500 #5001 in 0.3 s, and a process that dies after
/// launch answers 500 "Failed to detect Gateway" (<parameter>TYPEFAULTS</parameter>). It leaves only
/// the launch's <code>%System/%System/OSCommand</code> audit events. A stop is
/// <code>StopGateway</code>'s hard <code>%Shutdown(0)</code>, 200 in 0.7 s, and 200 again on a stopped
/// server; it records no audit event.</p>
/// <p><code>LanguageServer/PUT</code> and <code>/DELETE</code> are Story 16.25's editor writes
/// (<class>OcuPilot.Screen.Tool.LanguageServerCreate</class>, <class>OcuPilot.Screen.Tool.LanguageServerUpdate</class>,
/// <class>OcuPilot.Screen.Tool.LanguageServerDelete</class>), each issued through
/// <class>OcuPilot.Port.LanguageServerPort</class>. Measured on <code>ocupilot-ci</code>: the
/// <code>PUT</code> is an upsert answering 201 on create, keeps a key its body omits and merges
/// <code>Custom</code> member by member, and refuses a changed <code>Type</code>; the
/// <code>DELETE</code> reads no body and answers 404 for an absent server. Each writes the system
/// database and records <code>%System/%System/ConfigurationChange</code>.</p>
/// <p>The eight <code>Database.Actions</code> pairs are Story 18.4's disk operations, each issued through
/// <class>OcuPilot.Port.DatabasePort</class>, which builds every body. Measured on
/// <code>ocupilot-b-ci</code>, 2026-09-29: every type but <code>INTEGRITYCHECK</code> takes the
/// <code>dir</code> query parameter and answers 404 for a directory the instance does not configure.
/// <code>MOUNT</code> requires a body (<code>{}</code>, or <code>{"ReadOnly":true}</code>) and answers
/// 409 #19 for a mounted database; <code>DISMOUNT</code> reads none and refuses only the manager's
/// database. Both answer synchronously. <code>TRUNCATE</code> (<code>{TargetSize}</code>),
/// <code>MODIFYSIZE</code> (<code>{Size}</code>) and <code>EXPANDVOL</code> (<code>{InitialSize}</code>,
/// the volume made in the database's own new volume directory) queue through
/// <code>ShouldRunAsync()</code>; <code>COMPACT</code> (<code>{TargetFreeSpace}</code>),
/// <code>DEFRAGMENT</code> (no body read) and <code>INTEGRITYCHECK</code>
/// (<code>{Databases:[{Directory, Globals?}]}</code>) queue themselves in <code>Run()</code>
/// (<parameter>SELFQUEUEDTYPES</parameter>). A truncate or grow the vendor cannot make is a silent
/// no-op, and a grow above <code>MaxSize</code> is clamped, so the port's own rules refuse both first.
/// <code>ResourcesOR()</code> is <code>%Admin_Manage</code> for <code>MODIFYSIZE</code> and
/// <code>EXPANDVOL</code> and <code>%Admin_Operate</code> for the rest.</p>
/// <p>The three <code>Task.Manager</code> pairs are Story 16.11's Task Manager controls:
/// <code>SUSPEND</code> and <code>RESUME</code> are <code>SuspendSet(1|0)</code> and answer 200 whether
/// or not the state changes; <code>RUN</code> is <code>StartTASKMGR()</code> and answers 409 while the
/// process is alive. None reads a body or the <code>id</code> query parameter, and
/// <code>ResourcesOR()</code> is <code>%Admin_Task</code> or <code>%Admin_Operate</code> for each.</p>
/// <p>The three <code>Lock</code> pairs are Story 16.12's lock removals. <code>Lock/DELETE</code> is the
/// vendor's own: read on this build, it takes <code>id</code> (a <code>DeleteID</code>) and
/// <code>checkTxn</code> as query parameters and reads no body; with <code>checkTxn</code> 1 and the
/// owner in a transaction it answers 409 and removes nothing (<parameter>UNLOGGEDREFUSALS</parameter>),
/// and it records <code>%System/%System/ConfigurationChange</code> "Delete lock". It is issued only by
/// <class>OcuPilot.Port.LockPort</class>, for the tools' <code>Lock/REMOVE</code> and
/// <code>Lock/REMOVEOWNER</code>, which that port answers itself
/// (<parameter>OcuPilot.Port.LockPort.COMPOSEDTYPES</parameter>).</p>
/// <p>The two <code>Security.LDAP</code> pairs after <code>PUT</code> are Story 16.14's. Read on this
/// build: <code>CHANGEPWD</code> takes <code>{LDAPSearchPassword}</code> and a <code>name</code>
/// query, sets that one property through <code>Security.LDAPConfigs.Modify</code> (an empty value
/// clears it) and answers 404 for an absent name; <code>DELETE</code> reads no body, calls
/// <code>Security.LDAPConfigs.Delete</code> and answers 404 for an absent name. Both need
/// <code>%Admin_Secure</code>.</p>
/// <p>The three <code>Journal.*</code> pairs are Story 18.5's journal writes, each issued through
/// <class>OcuPilot.Port.JournalPort</class>. Read on this build: <code>Journal.Settings</code>'s
/// <code>SWITCHFILE</code> (10) calls <code>RollToNextFile</code> and <code>SWITCHDIR</code> (11)
/// swaps the primary and alternate directories, answering 409 when they are the same; neither reads a
/// body, both answer <code>{CurrentFile}</code>, and <code>ResourcesOR()</code> is
/// <code>%Admin_Operate</code>. <code>Journal.File</code>'s <code>INTEGRITYCHECK</code> (10) requires
/// <code>{CheckDetails}</code>, is queued (<parameter>QUEUEDWRITES</parameter>), and changes nothing:
/// it is admitted on the write path as <code>Database.Actions/INTEGRITYCHECK</code> is.</p>
/// <p><code>Journal.Settings/PUT</code> is Story 18.18's settings write, issued through
/// <class>OcuPilot.Port.JournalPort</class>. Read on this build: it copies only the keys its body
/// carries, <code>wijdir</code> and <code>targwijsz</code> to <code>Config.config.Modify</code> and the
/// rest to <code>Config.Journal.Modify</code>, and checks no type, range or directory.</p>
Parameter MUTATINGTYPES = "WebApp.App/PUT,Security.User/PUT,Security.Audit.Enabled/PUT,Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,Security.User/POST,Security.Role/PUT,Security.Role/DELETE,Security.Resource/PUT,Security.Resource/DELETE,Security.X509Credential/POST,Security.X509Credential/PUT,Security.X509Credential/DELETE,Wallet.Secret/PUT,Device.Standard/PUT,Device.Standard/DELETE,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,Security.User/DELETE,Security.User/CHANGEPWD,Task.CRUD/RUN,Task.CRUD/SUSPEND,Task.CRUD/DELETE,Process/TERMINATE,Security.Audit.Event/PUT,Security.Audit.Event/DELETE,Security.Audit.Event/CLEARCOUNT,Security.SSLConfig/PUT,Security.SSLConfig/DELETE,Wallet.Secret/DELETE,Task.CRUD/POST,Task.CRUD/PUT,Security.Service/PUT,Security.LDAP/PUT,Security.OAuth2.Server/REVOKE,Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Security.OAuth2.Client.ServerDefinition/POST,Security.OAuth2.Client.ServerDefinition/PUT,Security.OAuth2.Client.ServerDefinition/DELETE,Security.OAuth2.Client.ServerDefinition/TOKEN,Security.OAuth2.Client.ServerDefinition/REFRESHJWKS,Security.OAuth2.Client.ClientConfiguration/PUT,Security.OAuth2.Client.ClientConfiguration/CHANGESECRET,Security.OAuth2.Client.ClientConfiguration/ROTATEKEYS,Security.OAuth2.Client.ClientConfiguration/REGISTERCLIENT,Security.OAuth2.ResourceServer/PUT,Security.OAuth2.ResourceServer/CHANGESECRET,Security.OAuth2.ResourceServer/DELETE,Security.OAuth2.ResourceServer/ADDMAPPING,Security.OAuth2.ResourceServer/REMOVEMAPPING,Security.OAuth2.ResourceServerMapping/PUT,Security.OAuth2.ResourceServerMapping/DELETE,Security.OAuth2.Server/PUT,Security.OAuth2.Server/DELETE,Security.OAuth2.Server/CHANGEPWD,Security.OAuth2.Server/ROTATEKEYS,Security.OAuth2.ServerClients/POST,Security.OAuth2.ServerClients/PUT,Security.OAuth2.ServerClients/SECRET,Security.OAuth2.ServerClients/REFRESHJWKS,Namespace.Namespace/PUT,Namespace.Namespace/DELETE,WebSession/DELETE,AsyncResult/CANCEL,AsyncResult/PAUSE,AsyncResult/RESUME,BackgroundTask/CANCEL,BackgroundTask/PAUSE,BackgroundTask/RESUME,Namespace.GlobalMappings/PUT,Namespace.GlobalMappings/DELETE,Namespace.RoutineMappings/PUT,Namespace.RoutineMappings/DELETE,Namespace.PackageMappings/PUT,Namespace.PackageMappings/DELETE,Namespace.Namespace/MAPPINGS,Process/BROADCAST,Database.SysCRUD/POST,Database.SysCRUD/PUT,Database.SysCRUD/DELETE,Database.ConfigCRUD/PUT,Database.ConfigCRUD/DELETE,Database.Actions/MOUNT,Database.Actions/DISMOUNT,Database.Actions/TRUNCATE,Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/EXPANDVOL,Database.Actions/MODIFYSIZE,Database.Actions/INTEGRITYCHECK,TaskTransfer/EXPORT,TaskTransfer/IMPORT,LanguageServer/START,LanguageServer/STOP,LanguageServer/PUT,LanguageServer/DELETE,Task.Manager/SUSPEND,Task.Manager/RESUME,Task.Manager/RUN,Lock/REMOVE,Lock/REMOVEOWNER,Lock/DELETE,Security.LDAP/CHANGEPWD,Security.LDAP/DELETE,Namespace.Namespace/INTEROP,Journal.Settings/SWITCHFILE,Journal.Settings/SWITCHDIR,Journal.File/INTEGRITYCHECK,Journal.Settings/PUT";

/// <p>The <parameter>MUTATINGTYPES</parameter> entries the vendor declares need no request body,
/// so <method>Invoke</method>'s object-body refusal does not apply to them (AD-51). Comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries, the grammar
/// <parameter>QUERYPAIRS</parameter> and <parameter>BARETYPES</parameter> already key by.</p>
/// <p><b>It is a declaration about the vendor, not a relaxation.</b> The refusal exists because a
/// body-taking write given a non-object body writes nothing and answers 2xx (DW-1427); a request
/// type whose own <code>NeedsRequestBody()</code> excludes it never reads a body at all, so there
/// is no silent success to prevent and requiring one would refuse the only call the vendor
/// offers.</p>
/// <p><b>It keys on the pair rather than on the suffix</b> (DW-1464). <code>RESUME</code> is
/// declared by two endpoints on this build, and whether a request type reads a body is a fact
/// about the endpoint that declares it: a suffix-only exemption would carry one endpoint's
/// <code>NeedsRequestBody()</code> answer onto another endpoint's type of the same name, which is
/// the silent success this refusal exists to prevent.</p>
Parameter BODYLESSTYPES = "Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,Security.Role/DELETE,Security.Resource/DELETE,Security.X509Credential/DELETE,Device.Standard/DELETE,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,Security.User/DELETE,Task.CRUD/DELETE,Process/TERMINATE,Security.Audit.Event/DELETE,Security.SSLConfig/DELETE,Wallet.Secret/DELETE,Security.OAuth2.Server/REVOKE,Security.OAuth2.Client.ServerDefinition/DELETE,Security.OAuth2.Client.ClientConfiguration/ROTATEKEYS,Security.OAuth2.Client.ClientConfiguration/REGISTERCLIENT,Security.OAuth2.ResourceServer/DELETE,Security.OAuth2.ResourceServer/ADDMAPPING,Security.OAuth2.ResourceServer/REMOVEMAPPING,Security.OAuth2.ResourceServerMapping/DELETE,Security.OAuth2.Server/DELETE,Security.OAuth2.Server/ROTATEKEYS,Security.OAuth2.ServerClients/REFRESHJWKS,Namespace.Namespace/DELETE,WebSession/DELETE,AsyncResult/CANCEL,AsyncResult/PAUSE,AsyncResult/RESUME,BackgroundTask/CANCEL,BackgroundTask/PAUSE,BackgroundTask/RESUME,Namespace.GlobalMappings/DELETE,Namespace.RoutineMappings/DELETE,Namespace.PackageMappings/DELETE,Database.SysCRUD/DELETE,Database.ConfigCRUD/DELETE,Database.Actions/DISMOUNT,Database.Actions/DEFRAGMENT,LanguageServer/START,LanguageServer/STOP,LanguageServer/DELETE,Task.Manager/SUSPEND,Task.Manager/RESUME,Task.Manager/RUN,Lock/DELETE,Security.LDAP/DELETE,Namespace.Namespace/INTEROP,Journal.Settings/SWITCHFILE,Journal.Settings/SWITCHDIR";

/// <p>The <parameter>MUTATINGTYPES</parameter> deletes whose vendor answer does not say whether the
/// object went, as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries. After a 2xx
/// for a listed pair, <method>Invoke</method> re-issues the endpoint's <code>GET</code> for the same
/// query: only a 404 confirms the delete, and anything else is a 500 fault with
/// <parameter>OcuPilot.Api.Error.PORTNOTAPPLIED</parameter>, never a success.</p>
/// <p><code>Security.Role/DELETE</code> is listed because its <code>RunDelete</code> answers the
/// status of <code>%SQL.Manager.API.DropUser(name, "ROLE")</code>, which is <code>$$$OK</code>
/// whether or not the role was dropped (read on this build). That is a wire fact, so it lives here
/// (AD-27).</p>
/// <p><code>Device.Standard/DELETE</code> is listed because its <code>RunDelete</code> answers the
/// status of <code>Config.Devices.Delete</code>, whose body is stripped from this build's export, so
/// its 200 is not trusted unread.</p>
/// <p><code>Namespace.Namespace/DELETE</code> is listed because its answer was measured not to
/// track its outcome -- a caller the application cascade refused was answered 500 after the
/// namespace was already deleted (<code>ocupilot-b-ci</code>, Story 18.2) -- so its 2xx is not
/// trusted unread either.</p>
/// <p>The non-mutating <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs <method>Invoke</method>
/// admits that open a connection from the instance to a host the caller names and change nothing
/// stored, comma-separated. Each answers <code>{passed, lines}</code> rather than the vendor's own
/// shape: on a 2xx, <code>passed</code> true and <code>lines</code> the vendor's <code>Info</code>
/// array; on a vendor status error at 500, HTTP 200 with <code>passed</code> false and
/// <code>lines</code> each error's text. A 400, 403 or 404 is an ordinary fault.</p>
/// <p><b>The failure text is the result the operator asked for</b> (AD-39's named exception, Story
/// 9.5): it is answered to the caller and nowhere else -- never logged here, never a fault, never a
/// ledger or audit payload -- so no vendor text of a failed test reaches a sink OcuPilot or the
/// agent later reads.</p>
/// <p><code>Security.SSLConfig/TEST</code> is the one entry. Read on this build: its
/// <code>TYPETEST</code> is 10, its body is <code>{Host, Port}</code>, and its <code>RunTest</code>
/// calls <code>Security.SSLConfigs.TestConnection</code> synchronously, answering
/// <code>{Info}</code>, and 404 for an absent configuration.</p>
/// <p><code>Security.LDAP/TEST</code> is the second (Story 16.14, AD-26). Its
/// <code>ShouldRunAsync()</code> is true, and the vendor's queue would write its body -- the tested
/// user's password -- into its task row and the journal, so <method>Sequence</method> runs a pair
/// listed here in process and never hands it to the queue. Read on this build: its body is
/// <code>{Username, Password}</code>, both required; its <code>RunTest</code> JOBs
/// <code>TESTBACKGROUND1^%SYS.LDAP</code>, waits 5 s and writes the job's lines, answering
/// <code>{}</code> and OK whatever happened (<parameter>CONSOLETESTS</parameter>).</p>
Parameter CONNECTIONTESTTYPES = "Security.SSLConfig/TEST,Security.LDAP/TEST";

/// <p>The non-mutating <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs <method>Invoke</method>
/// admits that open a connection from the instance and change nothing stored, answered as ordinary
/// reads: the vendor's own answer, and a 404 an absence (AD-2). Unlike
/// <parameter>CONNECTIONTESTTYPES</parameter>, a failure is a fault.</p>
/// <p><code>ECP.DataServer/DBLIST</code> (Story 18.16, AD-21's seventh case) is the one entry: the
/// databases an ECP data server lists, <code>[{Name, Directory}]</code> from
/// <code>SYS.Database:RemoteDatabaseListSMP</code>, 404 for a server the instance does not define.
/// The vendor call takes no timeout, so its one caller, <class>OcuPilot.Port.RemoteDatabasePort</class>,
/// runs it in a child job against a bound.</p>
Parameter CONNECTIONREADTYPES = "ECP.DataServer/DBLIST";

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>CONNECTIONREADTYPES</parameter> admits, keyed by the pair as
/// <method>IsMutating</method> is.</p>
ClassMethod IsConnectionRead(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#CONNECTIONREADTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>The <parameter>CONNECTIONTESTTYPES</parameter> pairs whose vendor answer carries no verdict,
/// comma-separated. Their outcome is the console lines <method>Sequence</method> captured while
/// <code>Run()</code> ran: <code>{lines}</code> at 200, with no <code>passed</code>, because the
/// vendor answers <code>{}</code> and OK whether the test passed or failed (AD-39's fourth named
/// exception). The lines are answered to the caller and nowhere else.</p>
Parameter CONSOLETESTS = "Security.LDAP/TEST";

Parameter VERIFIEDDELETES = "Security.Role/DELETE,Device.Standard/DELETE,Namespace.Namespace/DELETE";

/// <p>The <parameter>MUTATINGTYPES</parameter> deletes the vendor carries out by marking the object
/// for a daemon of its own to remove later, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;query parameter&gt;:&lt;row key&gt;</code> entries. After
/// a 2xx for a listed pair, <method>Invoke</method> re-reads the endpoint's <code>LIST</code> every
/// <parameter>AWAITEDDELETEPOLLMS</parameter> milliseconds, for at most
/// <parameter>AWAITEDDELETEMS</parameter>, until no row's row key equals the query parameter's value
/// exactly (<method>AwaitGone</method>). The wait never turns the vendor's answer into a failure: a
/// write it reported made stays made (AD-26), and the caller's read-back says what the instance
/// holds (AD-58).</p>
/// <p><code>WebSession/DELETE</code> is listed because <code>$$DeleteSession^%SYS.cspServer</code>
/// only marks the session: measured on this build, the row stayed listed 1.65 to 4.09 seconds after
/// the 200 over five trials.</p>
Parameter AWAITEDDELETES = "WebSession/DELETE=id:ID";

/// <p>The longest <method>AwaitGone</method> waits, in milliseconds.</p>
Parameter AWAITEDDELETEMS As INTEGER = 10000;

/// <p>How long <method>AwaitGone</method> waits between two reads, in milliseconds.</p>
Parameter AWAITEDDELETEPOLLMS As INTEGER = 250;

/// <p>The <parameter>MUTATINGTYPES</parameter> entries whose query parameter's value must never
/// reach the log, as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;query
/// parameter&gt;</code> entries. A vendor refusal for a listed pair that quotes the value is logged
/// with it masked (<method>Unlogged</method>): <code>WebSession</code>'s 404 names the session id it
/// was sent.</p>
Parameter UNLOGGEDQUERY = "WebSession/DELETE=id";

/// <p>The vendor refusals that are an expected answer rather than a fault, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;/&lt;HTTP status&gt;</code> entries: <method>Fail</method> logs
/// nothing for a listed one, and the caller still gets its fault (AD-2 as amended 2026-09-30).
/// <code>Lock/DELETE/409</code> has found the lock's owner in an open transaction, which is the answer
/// Story 16.12's warning is taken from.</p>
Parameter UNLOGGEDREFUSALS = "Lock/DELETE/409";

/// <p>The <parameter>MUTATINGTYPES</parameter> writes whose vendor answer does not say whether the
/// sent values were stored, as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries.
/// After a 2xx for a listed pair, <method>Invoke</method> re-issues the endpoint's <code>GET</code>
/// for the same query, and every key of the sent body must read back equal
/// (<method>VerifyApplied</method>); anything else is a 500 fault with
/// <parameter>OcuPilot.Api.Error.PORTNOTAPPLIED</parameter>, never a success.</p>
/// <p><code>Security.Resource/PUT</code> is listed because its <code>RunPut</code> ends by calling
/// <code>Security.Resources.Exists(..Name, .obj, .sc)</code>, which overwrites the status of the
/// <code>Create</code> or <code>Modify</code> it just made: measured on this build, a 300-character
/// <code>Description</code> answered 200 and left the resource unchanged. That is a wire fact, so it
/// lives here (AD-27).</p>
Parameter VERIFIEDWRITES = "Security.Resource/PUT";

/// <p>AD-27's named fallback: the <parameter>MUTATINGTYPES</parameter> writes the port completes
/// through the vendor's own class when the body carries a value the admin API refuses and the class
/// accepts, as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;field&gt;</code> entries. It
/// applies only when <code>&lt;field&gt;</code> is the empty string.</p>
/// <p><code>Security.Resource/PUT=PublicPermission</code> is the one entry (AD-27 as amended
/// 2026-09-23). The endpoint's <code>RunPut</code> normalizes the value with
/// <code>Security.Datatype.Permission.ExternalToInternal</code>, whose answer for no permission is
/// 0, and refuses that with a 400, so no encoding of "none" is accepted on a create or a clear;
/// <code>Security.Resources.Create</code> and <code>Modify</code> accept an empty permission.
/// <method>CompleteThroughClass</method> makes that call behind the endpoint's own gate and
/// validation, and <parameter>VERIFIEDWRITES</parameter> re-reads it as it re-reads the vendor's
/// own.</p>
Parameter CLASSCOMPLETEDTYPES = "Security.Resource/PUT=PublicPermission";

/// <p>AD-27's second named case: the <parameter>MUTATINGTYPES</parameter> writes the port completes
/// from <b>content</b> through the vendor's own class, because the admin API names only server file
/// paths for them and AD-21 forbids a caller naming a path. Comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries.</p>
/// <p><code>Security.X509Credential/POST</code> is the one entry (AD-27 as amended 2026-09-23). Its
/// <code>RunPost</code> reads the certificate and key through <code>LoadCertificate</code> and
/// <code>LoadPrivateKey</code> from <code>CertificateFile</code> and <code>PrivateKeyFile</code>;
/// <method>ImportThroughClass</method> sets them as content on <class>%SYS.X509Credentials</class>
/// instead, behind the endpoint's own gate. The certificate, key and key password never touch disk,
/// and no status, fault or log line this path writes carries their text (AD-35).</p>
Parameter CONTENTCOMPLETEDTYPES = "Security.X509Credential/POST";

/// <p>AD-27's fifth named case: the <parameter>MUTATINGTYPES</parameter> writes after which the
/// port re-applies the application <code>Type</code> the target held before the vendor call, as
/// comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries.</p>
/// <p><code>WebApp.App/PUT</code> is the one entry (AD-27 as amended 2026-09-24).
/// <code>MergeJsonAndProperties</code> sets <code>Type</code> to CSP on every PUT and
/// <method>Security.Applications.Modify</method> then clears a system application's bit, so an edit
/// of a system application would demote it (measured on this build: 3 became 2).
/// <method>KeptType</method> reads the type in <code>%SYS</code> before the call and
/// <method>RestoreType</method> re-applies it after, behind the same <code>%Admin_Secure</code>
/// gate; nothing above the port knows.</p>
Parameter TYPEKEPTTYPES = "WebApp.App/PUT";

/// <p>The resource the <parameter>TYPEKEPTTYPES</parameter> read and restore are gated on: the
/// endpoint's own <code>ResourcesOR()</code>.</p>
Parameter TYPEKEPTRESOURCE = "%Admin_Secure";

/// <p>The keys a content-completed import body may carry: the credential's two lists and the three
/// secrets. Every other key -- <code>CAFile</code>, <code>CertificateFile</code>,
/// <code>PrivateKeyFile</code> among them -- is refused (AD-21).</p>
Parameter IMPORTFIELDS = "OwnerList,PeerNames,Certificate,PrivateKey,PrivateKeyPassword";

/// <p>The longest PEM text <method>PemBlock</method> accepts, in characters.</p>
Parameter PEMMAXLENGTH As INTEGER = 65536;

/// <p>The longest private key password <class>%SYS.X509Credentials</class> stores: the
/// <code>MAXLEN</code> of its <code>PrivateKeyPassword</code> property on this build. A longer one is
/// refused before the save, whose datatype refusal would quote the value.</p>
Parameter PASSWORDMAXLENGTH As INTEGER = 128;

/// <p>The vendor status codes a content import's save answers for a refused certificate, key or
/// password, each paired with the OcuPilot code the port's log names in its place: expired, a key
/// the password does not decrypt, a key that does not belong to the certificate, a certificate
/// whose public key is not RSA carried with a key, and a certificate the vendor cannot read.</p>
Parameter IMPORTSAVECODES = "728=X509.CERTIFICATE.EXPIRED,732=X509.PRIVATEKEYPASSWORD.WRONG,733=X509.PRIVATEKEY.MISMATCH,731=X509.PRIVATEKEY.MISMATCH,742=X509.CERTIFICATE.SHAPE";

/// <p>The <parameter>MUTATINGTYPES</parameter> entries whose vendor body is a <b>wrapper</b>, as
/// comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;wrapper&gt;:&lt;outer&gt;[:&lt;outer&gt;...]</code>
/// entries. <method>Invoke</method> applies it before the vendor's <code>ValidateRequest</code>:
/// every key of the caller's flat body except the listed outer keys moves under the wrapper key,
/// and an outer key the body does not carry stays missing, so the vendor's own required-field
/// refusal answers for it.</p>
/// <p><code>Security.User/POST</code> is <code>%Api.Admin.Endpoints.Security.User</code>'s create
/// (read on this build): <code>TYPEPOST</code> 5, <code>NeedsRequestBody()</code> true, a
/// <code>ValidateRequest</code> requiring <code>{User:{...}, Password}</code>, and a
/// <code>RunPost</code> that calls <method>Security.Users.Create</method> with the password and then
/// <code>Modify</code> with <code>User</code>'s fields. The wrapper is a wire fact, so it lives in
/// the port (AD-27) and the rest of the product reads <code>Security.User</code>'s flat derived
/// field list. <method>Fail</method> strips the wrapper's leading segment from a field a vendor
/// refusal names, so the refusal lands on the flat field the caller sent.</p>
/// <p><code>Wallet.Secret/PUT</code> is <code>%Api.Admin.Endpoints.Wallet.Secret</code>'s create and
/// edit (read on this build): a <code>ValidateRequest</code> requiring <code>{Type,
/// WalletSecretConfig:{...}}</code> and a <code>RunPut</code> that hands
/// <code>WalletSecretConfig</code> to the <code>Type</code> class's <code>Create</code> or
/// <code>Modify</code>. The rest of the product reads the flat <code>%Wallet.KeyValue</code> field
/// list with <code>Type</code> beside it.</p>
Parameter WRAPPEDTYPES = "Security.User/POST=User:Password,Wallet.Secret/PUT=WalletSecretConfig:Type";

/// <p>The <parameter>MUTATINGTYPES</parameter> entries whose vendor body spells a key differently
/// from the name the rest of the product carries it under, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;ours&gt;:&lt;vendor's&gt;[:&lt;ours&gt;:&lt;vendor's&gt;...]</code>
/// entries. <method>Invoke</method> applies it to a copy of the body before the vendor's
/// <code>ValidateRequest</code> reads it; the caller's body is not modified.</p>
/// <p><code>Security.User/CHANGEPWD</code> reads its password as <code>NewPassword</code>, while
/// the descriptor declares the secret once as <code>Password</code> (AD-3, AD-56). The vendor's key
/// is a wire fact, so it lives in the port (AD-27): renaming in the tool would put
/// <code>NewPassword</code> in the body the ledger's field names are taken from, outside the
/// declared-secret exclusion.</p>
Parameter RENAMEDTYPES = "Security.User/CHANGEPWD=Password:NewPassword";

/// <p>The <parameter>MUTATINGTYPES</parameter> entries whose vendor type requires a fixed body no
/// caller supplies, as <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;JSON object&gt;</code> entries
/// separated by <code>;</code>, because a body's JSON may carry commas. <method>Invoke</method>
/// sends the entry's body in place of an absent caller body, and refuses a caller body for such a
/// pair as a port fault without calling the vendor.</p>
/// <p><b>It is a vendor wire fact</b> (AD-27, AD-51), kept here as
/// <parameter>RENAMEDTYPES</parameter> keeps a vendor key: <code>Task.CRUD</code>'s
/// <code>RUN</code> reads a body and <code>ValidateRequest</code> requires
/// <code>{"RunNow":true}</code>, measured on this build. The tool declares no body and the kernel
/// and the ledger see none; the constant exists only between this port and the vendor.</p>
/// <p><code>Task.CRUD</code>'s <code>SUSPEND</code> reads a body too, and answers 415 without one;
/// its <code>LeaveInQueue</code> defaults to 1 when absent, and the port sends that default
/// explicitly so the suspend a caller gets is the one written here (measured on this build).</p>
/// <p><code>Security.Audit.Event</code>'s <code>CLEARCOUNT</code> requires a body and reads none of
/// it, so the port sends <code>{}</code>.</p>
Parameter CONSTANTBODIES = "Task.CRUD/RUN={""RunNow"":true};Task.CRUD/SUSPEND={""LeaveInQueue"":true};Security.Audit.Event/CLEARCOUNT={}";

/// <p>The <parameter>MUTATINGTYPES</parameter> pairs the vendor always queues and
/// <method>Sequence</method> hands to its Work Queue rather than refusing, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries; the port awaits each within
/// <method>AsyncTimeout</method> (AD-26). Their bodies carry no secret field -- a namespace name, two
/// empty dates, a cut-off and a false flag, and a copy of mappings' two namespace names -- so the
/// vendor's task row holds nothing AD-35 protects. Every other mutating pair that would queue is
/// still refused.</p>
/// <p><code>Namespace.Namespace/MAPPINGS</code> is Story 18.14's copy of mappings: the endpoint's
/// <code>ShouldRunAsync()</code> is true for <code>TYPEMAPPINGS</code> (read on this build).
/// <method>AwaitTask</method> is its one poller and reads the finished result once; a second read of
/// an ended task logs ERROR #7846 (AD-26 as amended 2026-09-28).</p>
/// <p>The six <code>Database.Actions</code> pairs are Story 18.4's queued disk operations (AD-26 as
/// amended 2026-09-29), each body built by <class>OcuPilot.Port.DatabasePort</class> from sizes, a
/// set of directories and global names: <code>TRUNCATE</code>, <code>EXPANDVOL</code> and
/// <code>MODIFYSIZE</code> queue through <code>ShouldRunAsync()</code>, and <code>COMPACT</code>,
/// <code>DEFRAGMENT</code> and <code>INTEGRITYCHECK</code> queue themselves in <code>Run()</code>
/// (<parameter>SELFQUEUEDTYPES</parameter>).</p>
/// <p><code>Namespace.Namespace/INTEROP</code> is Story 18.15's enable interoperability: it takes no
/// body, is queued through <code>ShouldRunAsync()</code>, and is read once by <method>AwaitTask</method>.</p>
/// <p><code>Journal.File/INTEGRITYCHECK</code> is Story 18.5's journal integrity check: queued through
/// <code>ShouldRunAsync()</code>, its body <code>{CheckDetails}</code> built by
/// <class>OcuPilot.Port.JournalPort</class>, and its console lines read once with its end
/// (<parameter>CONSOLEDTYPES</parameter>).</p>
Parameter QUEUEDWRITES = "Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Namespace.Namespace/MAPPINGS,Database.Actions/TRUNCATE,Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/EXPANDVOL,Database.Actions/MODIFYSIZE,Database.Actions/INTEGRITYCHECK,Namespace.Namespace/INTEROP,Journal.File/INTEGRITYCHECK";

/// <p>The <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs whose own <code>Run()</code> queues a task
/// while <code>ShouldRunAsync()</code> answers false (AD-26 as amended 2026-09-29), read on this
/// build: <code>Database.Actions</code>'s <code>COMPACT</code>, <code>DEFRAGMENT</code> and
/// <code>INTEGRITYCHECK</code>, each handing a <code>%SYS.BackgroundTask</code> to the vendor's
/// queue. <method>Sequence</method> refuses a mutating request of such a pair that is not a
/// <parameter>QUEUEDWRITES</parameter> entry before the endpoint's own semantics or
/// <code>Run()</code> is reached, as it refuses one <code>ShouldRunAsync()</code> would queue.</p>
Parameter SELFQUEUEDTYPES = "Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/INTEGRITYCHECK";

/// <p>The <parameter>QUEUEDWRITES</parameter> pairs whose finished task's console lines are part of
/// the answer, comma-separated (AD-26, AD-39's fifth exception): <method>AwaitTask</method> answers
/// <code>{Result, console}</code> for a listed pair, <code>console</code> the poll answer's
/// <code>Console</code> lines cut to <parameter>CONSOLEMAXLINES</parameter>. A listed task that fails
/// with console lines has run and reported, so it is answered the same way with <code>failed</code>
/// true and nothing logged; one that fails with none is an ordinary fault. The lines reach the caller
/// alone.</p>
/// <p><code>Journal.File/INTEGRITYCHECK</code> (Story 18.5): the vendor's check writes its findings
/// to the console and answers <code>{}</code> (read on this build).</p>
Parameter CONSOLEDTYPES = "Journal.File/INTEGRITYCHECK";

/// <p>The most console lines <method>AwaitTask</method> keeps for a <parameter>CONSOLEDTYPES</parameter>
/// pair; a longer console keeps one fewer and ends with U+2026.</p>
Parameter CONSOLEMAXLINES As INTEGER = 200;

/// <p>The <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs whose <parameter>JOURNALFILEPARAM</parameter>
/// query parameter this port accepts only as a name the instance's own journal file list answers
/// (AD-21's eighth case), comma-separated. <method>JournalGuard</method> reads that list whole at the
/// call, before the target's call, and refuses any other name 404 <code>JOURNAL.FILE.UNLISTED</code>
/// without naming it.</p>
Parameter JOURNALFILETYPES = "Journal.File/GET,Journal.File/INTEGRITYCHECK,Journal.Record/LIST,Journal.Record/GET";

/// <p>The <parameter>JOURNALFILETYPES</parameter> pairs for which an omitted or empty file reads the
/// newest listed file, comma-separated.</p>
Parameter JOURNALNEWESTTYPES = "Journal.Record/LIST";

/// <p>The classic record browser's eight match columns (<code>%CSP.UI.System.OpenJournalPane</code>),
/// the only <code>matchColumnName</code> values <method>JournalRecordRules</method> sends (Story 18.19,
/// AD-21), comma-separated. <code>NewValue</code>, <code>OldValue</code> and
/// <code>GlobalReference</code> are never among them.</p>
Parameter JOURNALMATCHCOLUMNS = "TimeStamp,ProcessID,TypeName,ExtTypeName,InTransaction,GlobalNode,DatabaseName,MirrorDatabaseName";

/// <p>The classic record browser's six comparisons, the only <code>matchOperator</code> values
/// <method>JournalRecordRules</method> sends, comma-separated: the vendor splices the operator into
/// code it executes (<code>%SYS.Journal.Record</code> <code>Fetch</code>), so nothing else is ever
/// sent.</p>
Parameter JOURNALMATCHOPERATORS = "=,'=,]],']],[,'[";

/// <p>The three query parameters a record list's filter travels under: column, comparison and value,
/// sent together or not at all.</p>
Parameter JOURNALMATCHPARAMS = "matchColumnName,matchOperator,matchValue";

/// <p>The <code>&lt;endpoint&gt;/&lt;type&gt;</code> pairs whose <parameter>JOURNALMATCHPARAMS</parameter>
/// <method>JournalRecordRules</method> checks, comma-separated.</p>
Parameter JOURNALMATCHTYPES = "Journal.Record/LIST";

/// <p>The query parameter each journal record pair takes as a record address, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;param&gt;</code> entries: digits only, at most 20
/// (<method>JournalRecordRules</method>). The list's empty offset is not sent; the record's empty
/// address is refused.</p>
Parameter JOURNALOFFSETPARAMS = "Journal.Record/LIST=initialOffset,Journal.Record/GET=address";

/// <p>The pairs whose vendor list keeps fewer rows than its <code>maxRows</code>, with the factor this
/// port multiplies <code>maxRows</code> by, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;factor&gt;</code> entries (AD-26). <code>Journal.Record/LIST</code>:
/// the vendor counts each kept row twice and each row on a database the caller cannot read once
/// (measured at Story 18.19's Task 0: 10 kept 5, 40 kept 20), so the doubling is exact only when no
/// row is skipped.</p>
Parameter HALVEDROWTYPES = "Journal.Record/LIST=2";

/// <p>The endpoint whose <code>LIST</code> answers the instance's journal files, newest first
/// (<code>%SYS.Journal.File:ByTimeReverseOrder</code>).</p>
Parameter JOURNALLISTENDPOINT = "Journal.File";

/// <p>The query parameter a journal file travels under.</p>
Parameter JOURNALFILEPARAM = "file";

/// <p>The route of the journal file list, after <parameter>SNIPPETPREFIX</parameter>, which a script
/// renders as the guard's read (AD-59). A <code>GET</code> route, so
/// <class>OcuPilot.Port.AdminRoutes</class> does not hold it.</p>
Parameter JOURNALLISTURL = "/journal/files";

/// <p>The <parameter>MUTATINGTYPES</parameter> pairs whose vendor error answers the product's own code,
/// as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;code&gt;</code> entries (AD-39). A listed
/// pair the vendor answers 500 is answered 500 on that code, with the sentence
/// <class>OcuPilot.Api.Error</class> declares for it (<code>REASON</code> and the code without its
/// dots); the vendor's text goes to the log alone.</p>
/// <p><code>LanguageServer/START</code> (Story 16.10): a start the instance refused -- no JVM at the
/// server's <code>JavaHome</code>, or a process that did not answer -- which the server's activity log
/// records.</p>
Parameter TYPEFAULTS = "LanguageServer/START=LANGUAGESERVER.START";

/// <p>The query parameters an endpoint reads as parts of one composite key, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;key&gt;=&lt;part&gt;:&lt;part&gt;...</code> entries.
/// <method>Invoke</method> applies it to a copy of the query before it is seeded: the named key's
/// value is split on <code>/</code> into the named parts, and a value that is not exactly one
/// non-empty piece per part is answered 404 <code>PORT.NOTFOUND</code> without calling the
/// vendor.</p>
/// <p><b>It is a vendor wire fact</b> (AD-27). An audit event's row key is its
/// <code>EventName</code>, <code>Source/Type/Name</code>, while
/// <code>Security.Audit.Event</code>'s <code>GET</code>, <code>PUT</code>, <code>DELETE</code> and
/// <code>CLEARCOUNT</code> each require <code>source</code>, <code>type</code> and
/// <code>name</code>. <class>Security.Events</class> refuses a <code>/</code> in a name, so the
/// split is unambiguous for every event the instance can hold.</p>
/// <p><code>Security.Audit.Event/PUT</code>, <code>/DELETE</code> and <code>/CLEARCOUNT</code> are
/// Story 7.11's (<class>OcuPilot.Screen.Tool.AuditEventUpdate</class>,
/// <class>OcuPilot.Screen.Tool.AuditUserEventDelete</class>,
/// <class>OcuPilot.Screen.Tool.AuditEventReset</class>). Read on this build: the endpoint overrides
/// <code>Run</code>, <code>ResourcesOR()</code> is <code>%Admin_Secure</code>, and every type but
/// <code>LIST</code> requires the <code>source</code>, <code>type</code> and <code>name</code> query
/// parameters (<parameter>SPLITQUERIES</parameter>). <code>PUT</code> is an upsert that
/// <code>Create</code>s an absent event; <code>DELETE</code> reads no body, answers 404 for an
/// absent event and 409 for a system-defined one; <code>TYPECLEARCOUNT</code> is 10, its
/// <code>NeedsRequestBody()</code> is true and <code>RunClearCount</code> ignores the body, so it is
/// listed in <parameter>CONSTANTBODIES</parameter>.</p>
Parameter SPLITQUERIES = "Security.Audit.Event/event=source:type:name";

/// <p>The pair set the <b>backing query or class</b> of an endpoint requires, beyond the
/// endpoint's own <code>ResourcesOR()</code> gate (AD-29). Comma-separated entries of the form
/// <code>&lt;endpoint&gt;/&lt;type&gt;=&lt;pair&gt;|&lt;pair&gt;</code>, each pair
/// <code>resource:permission</code>. <code>/</code> separates the key because a pair itself
/// carries a colon.</p>
/// <p><b>The set is any-of, not all-of.</b> The vendor checks it as an OR -- probed in
/// <code>irislib</code>, <code>%SYS.ProcessQuery.CONTROLPANELExecute</code> serves a caller
/// holding <code>%Admin_Manage:USE</code> <i>or</i> write on the IRISSYS database -- so an
/// all-of check here would refuse a caller the instance would have served.</p>
/// <p><b>It is established per endpoint, never derived.</b> AD-29's discipline is to read the
/// backing query's own check in <code>irislib/</code> and then run the read as a real
/// least-privileged principal on a throwaway; <code>ResourcesOR()</code> settles nothing, and one
/// endpoint's answer says nothing about the other 69. So this table holds only what has been
/// established that way, and an endpoint absent from it keeps the 500 it answers today rather
/// than acquiring a guessed 403.</p>
/// <p><code>Process/LIST</code> is the one established entry: the endpoint's own gate is
/// <code>%Admin_Operate</code> alone, while <code>CONTROLPANELExecute</code> refuses without
/// <code>%Admin_Manage:USE</code> or IRISSYS write, and the refusal reaches this port only as
/// <code>&lt;INVALID OREF&gt;</code> out of <code>%Api.Admin.Util.ClassQuery</code>, whose own
/// <code>%SQLCODE</code> is a method-local nothing can read.</p>
/// <p><b>The probe is on the synchronous path only.</b> A queued endpoint's failure is reported by
/// <method>AwaitTask</method>, which answers 500 without consulting this table; every type
/// <parameter>TYPESUFFIXES</parameter> admits is a read and none of them queues, so no entry here
/// can reach that path today. An entry for an endpoint that does queue needs the probe there too.</p>
/// <p>The declaration's shape is refused by <method>QueryPairsProblem</method> (DW-305), and its
/// resource names and endpoint are checked against the instance by
/// <class>OcuPilot.Test.AdminPortFault</class>.</p>
Parameter QUERYPAIRS = "Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE";

/// <p>The request types this port admits, per endpoint, without the vendor's <code>TYPE</code>
/// prefix (System usage, Story 6.9). Comma-separated entries of the form
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code>, the grammar <parameter>QUERYPAIRS</parameter> uses.</p>
/// <p><code>%Api.Admin.Endpoints.Monitor</code> publishes its request types as unprefixed class
/// parameters (<code>SYSTEMUSAGE</code>, <code>SYSTEMUSAGESHM</code>, <code>DASHBOARDMAIN</code>)
/// rather than as <code>TYPE&lt;suffix&gt;</code>. A type listed here for an endpoint resolves
/// through that bare parameter on the endpoint's class, without widening
/// <parameter>TYPESUFFIXES</parameter>; every other suffix still resolves through the
/// <code>TYPE</code>-prefixed parameter.</p>
Parameter BARETYPES = "Monitor/SYSTEMUSAGE,Monitor/SYSTEMUSAGESHM,Monitor/DASHBOARDMAIN,Monitor/LICENSEUSAGE";

/// <p>The body-template method names, in the order <method>TemplateMethod</method> resolves them
/// (AD-3): the first one an endpoint class defines itself is its template.</p>
Parameter TEMPLATENAMES = "RequestBodySchema,PutRequestBodySchema,PutAndPostSchema,Schema";

/// <p>The endpoints whose template method takes an argument, as comma-separated
/// <code>&lt;endpoint&gt;:&lt;value&gt;</code> pairs. <method>Template</method> passes the value
/// as the method's one argument; every other template is called with none, so an optional
/// argument is evaluated at its default. <code>Security.SSLConfig</code>'s argument
/// (<code>includePrivateKeyPassword</code>) adds the <code>PrivateKeyPassword</code> field. A
/// caller's own argument to <method>Template</method> takes precedence over this list: the
/// derivation calls <code>LanguageServer</code>'s template once per server type (AD-3).</p>
Parameter TEMPLATEARGUMENTS = "Security.SSLConfig:1";

/// <p>The synthetic request URL prefix. <code>GetName()</code> labels a task with the text
/// after <code>api/admin</code>, and <code>NormalizeLocationHeader()</code> builds the
/// <code>Location</code> from the text before <code>/api/admin</code>, so both need it.</p>
Parameter STUBURLPREFIX = "/api/admin/v2/ocupilot/";

/// <p>The bounded wait for an async task, in seconds (AD-26).</p>
Parameter ASYNCTIMEOUT = 30;

/// <p>The pause between two polls of an async task, in seconds.</p>
Parameter POLLINTERVAL = 0.05;

/// <p>The HTTP status <code>Main()</code> sets when the gate refuses or a
/// <code>&lt;PROTECT&gt;</code> escapes <code>Run()</code>.</p>
Parameter HTTPFORBIDDEN = "403 Forbidden";

/// <p>The HTTP status <code>Main()</code> sets when query parameters or the request body fail
/// validation.</p>
Parameter HTTPBADREQUEST = "400 Bad Request";

/// <p>The admin API routing class this port reads. Overridable so
/// <class>OcuPilot.Test.PortFixture</class> can point the real derivation at a fixture
/// class carrying a fixture <code>UrlMap</code>, which is how version 1, version 3 and an
/// absent API are pinned without touching the instance's own admin API. Production never
/// overrides this.</p>
ClassMethod AdminApiClass() As %String
{
    Quit ..#ADMINAPICLASS
}

/// <p>The endpoint class <method>ProbeAnswers</method> constructs. Overridable for the same
/// reason as <method>AdminApiClass</method>; production never overrides it.</p>
ClassMethod ProbeEndpointClass() As %String
{
    Quit ..#PROBEENDPOINT
}

/// <p>The vendor endpoint package, exposed as a method so
/// <class>OcuPilot.Test.AdminInventory</class> enumerates the classes without naming the
/// package itself.</p>
ClassMethod EndpointPackage() As %String
{
    Quit ..#ENDPOINTPACKAGE
}

/// <p>The highest <code>N</code> among <var>pClass</var>'s own <code>UrlMap</code> routes
/// that forward to <code>&lt;pClass&gt;.Dispatch.v&lt;N&gt;</code>; <code>0</code> when the
/// class, the <code>UrlMap</code> or every such forward is absent <b>or unreadable</b> --
/// the two are not told apart here, so the caller's detail must not claim which it was.</p>
/// <p>This reproduces the vendor's own computation -- <code>%Api.Admin.Info()</code> reads
/// the same <code>UrlMap</code> out of the same class-definition dictionary, tests for
/// <code>Forward="&lt;class&gt;</code> and takes
/// <code>+$Piece(line, "&lt;class&gt;.Dispatch.v", 2)</code> -- so OcuPilot and
/// <code>/api/admin/info</code> cannot report different versions. Two deliberate
/// differences, neither able to change the answer: <code>Info()</code> seeds at 1 and so
/// can never report an absent API, where this reports <code>0</code>, which is what the
/// mismatch notice needs to say; and <code>Info()</code> skips the XData's first and last
/// lines as the <code>&lt;Routes&gt;</code> wrapper, where this reads every line -- a
/// <code>Forward=</code> can only occur inside that wrapper.</p>
/// <p><code>Info()</code> itself is never called in-process: it reads
/// <code>%session.Username</code>, sets <code>%response.Status</code> and writes its JSON
/// to the device.</p>
ClassMethod HighestDispatchVersion(pClass As %String) As %Integer
{
    Set tVersion = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, "UrlMap", , .tSC)
        If '$IsObject(tXData) Quit
        Set tMarker = "Forward=""" _ pClass
        Set tPrefix = pClass _ ".Dispatch.v"
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ tMarker Continue
            Set tFound = +$Piece(tLine, tPrefix, 2)
            If tFound > tVersion Set tVersion = tFound
        }
    } Catch {
        Set tVersion = 0
    }
    Quit tVersion
}

/// <p>Whether the probe endpoint still answers the contract AD-2's sequence depends on:
/// it constructs as <code>%New(&lt;type&gt;, 2)</code>, its <code>ResourcesOR()</code>
/// returns a non-empty <code>%List</code> for the gate to evaluate, and its
/// <code>ShouldRunAsync()</code> answers 0 or 1 so the synchronous and async paths can be
/// told apart.</p>
/// <p><var>pDetail</var> names the class and what it lacked; it is empty exactly when the
/// probe passed. The three questions are asked through
/// <code>$ClassMethod</code>/dynamic dispatch rather than a typed reference, so a fixture
/// endpoint needs no vendor superclass (AD-27).</p>
ClassMethod ProbeAnswers(Output pDetail As %String) As %Boolean
{
    Set pDetail = ""
    Set tClass = ..ProbeEndpointClass()
    Try {
        Set tEndpoint = $ClassMethod(tClass, "%New", ..#PROBETYPE, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set pDetail = "probe endpoint " _ tClass _ " did not construct at ApiVersion " _ ..#APIVERSION
            Quit
        }
        Set tResources = tEndpoint.ResourcesOR()
        If ('$ListValid(tResources)) || ($ListLength(tResources) = 0) {
            Set pDetail = "probe endpoint " _ tClass _ " returned no resource from ResourcesOR()"
            Quit
        }
        Set tAsync = tEndpoint.ShouldRunAsync()
        If (tAsync '= 0) && (tAsync '= 1) {
            Set pDetail = "probe endpoint " _ tClass _ " answered ShouldRunAsync() with " _ tAsync
            Quit
        }
    } Catch ex {
        Set pDetail = "probe endpoint " _ tClass _ " failed the port's contract: " _ ex.DisplayString()
    }
    Quit pDetail = ""
}

/// <p>Report the usable admin API version, and refuse to report one at all unless the named
/// probe endpoint still answers (AD-27: fail loudly, never a partly-working screen).</p>
/// <p><var>pVersion</var> is the derived version, or <code>0</code> when the API is absent
/// or the probe failed. <var>pDetail</var> is empty exactly when
/// <var>pVersion</var> is the instance's real version and the probe passed; otherwise it
/// names what was missing and is what the caller logs. An error
/// <class>%Status</class> is always accompanied by a non-empty <var>pDetail</var>.</p>
/// <p>A version other than <parameter>APIVERSION</parameter> is not an error here: the
/// client needs the number in order to name it in the mismatch notice.</p>
ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    Set tSC = $$$OK
    Set pVersion = 0
    Set pDetail = ""
    Try {
        Set tClass = ..AdminApiClass()
        Set pVersion = ..HighestDispatchVersion(tClass)
        If pVersion = 0 {
            Set pDetail = "admin API unusable: " _ tClass _ " publishes no readable UrlMap route forwarding to " _ tClass _ ".Dispatch.v<N>"
            Quit
        }
        Set tProbeDetail = ""
        If '..ProbeAnswers(.tProbeDetail) {
            Set pVersion = 0
            Set pDetail = tProbeDetail
            Quit
        }
    } Catch ex {
        Set pVersion = 0
        Set pDetail = "the admin API check failed: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Call one admin endpoint as the calling process's user (AD-1, AD-2, AD-26).</p>
/// <p><var>pEndpoint</var> is package-relative (<code>WebApp.App</code>); <var>pType</var> is a
/// suffix from <parameter>TYPESUFFIXES</parameter>, the suffix of a
/// <parameter>MUTATINGTYPES</parameter> or <parameter>CONNECTIONTESTTYPES</parameter> pair, or a
/// bare type <parameter>BARETYPES</parameter> lists for <var>pEndpoint</var>;
/// <var>pQuery</var> holds query parameters as
/// <code>pQuery(name) = value</code>; <var>pBody</var> is the request body, <code>{}</code> when
/// omitted.</p>
/// <p>Returns OK exactly when the endpoint's status is OK and its HTTP status is 2xx, with
/// <var>pResult</var> the endpoint's return value (an async task's <code>Result</code>) and
/// <var>pFault</var> empty. Otherwise returns an error <class>%Status</class> carrying only
/// OcuPilot's own text, <var>pResult</var> empty and <var>pFault</var>
/// <code>{error, reason, code}</code> from <class>OcuPilot.Kernel.Fault</class>; vendor text goes
/// to <method>LogFault</method> alone, except a read's 404, which is logged nowhere (AD-2).
/// <var>pHttpStatus</var> is the numeric HTTP status in both
/// cases: the endpoint's, 503 for a refusal the port decided (<code>PORT.UNAVAILABLE</code>,
/// <code>PORT.TIMEOUT</code>), 501 for a name no compiled endpoint class answers, a suffix
/// outside <parameter>TYPESUFFIXES</parameter> that is not a <parameter>MUTATINGTYPES</parameter>
/// or <parameter>CONNECTIONTESTTYPES</parameter> pair or a <parameter>BARETYPES</parameter> entry, a suffix the class declares no
/// <code>TYPE&lt;suffix&gt;</code> parameter for, or a read the class leaves to the vendor base
/// class (<method>ImplementsRead</method>).</p>
/// <p><b>A <parameter>MUTATINGTYPES</parameter> call must carry an object body, unless its type is
/// one <parameter>BODYLESSTYPES</parameter> names.</b> ObjectScript
/// does not enforce a method argument's declared type, and a non-object <var>pBody</var> becomes
/// <code>{}</code> in <method>RunSequence</method> -- which the vendor's
/// <code>MergeJsonAndProperties</code> reads as carrying no properties, so a <code>PUT</code> given
/// JSON <i>text</i> answers 2xx with the target unchanged and writes nothing, and the caller cannot
/// tell that from a write. It is refused here instead, as an internal failure with the generic
/// reason (AD-12) and the cause in the log (DW-1427).</p>
/// <p><b>A <parameter>CONSTANTBODIES</parameter> pair takes no caller body.</b> Given none, it is
/// sent the port's constant; given any body, an object or JSON text, it is refused the same way and
/// the vendor is not called (AD-27, AD-51).</p>
/// <p><b>A <parameter>SPLITQUERIES</parameter> key is split before the query is seeded</b>, and a
/// malformed one is 404 <code>PORT.NOTFOUND</code> with no vendor call.</p>
/// <p>Must not be called from an escalated frame (AD-9). The caller's namespace,
/// <code>%request</code>, <code>%response</code> and <code>%session</code> are unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tLocation)
}

/// <p><method>Invoke</method>, with the <code>Location</code> header of a 2xx answer in
/// <var>pLocation</var>, or <code>""</code>. A create whose new id the vendor answers only in that
/// header (<code>Task.CRUD/POST</code>) is read through this by its port; every other caller uses
/// <method>Invoke</method>.</p>
ClassMethod InvokeLocated(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pLocation = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tVerifySC = ..VerifyInstance(.tVersion, .tDetail)
        If $$$ISERR(tVerifySC) || (tVersion '= ..#APIVERSION) || (tDetail '= "") {
            If (tVersion '= 0) && (tVersion '= ..#APIVERSION) {
                Set tReason = "The instance's administration API reports version " _ tVersion _ ", and OcuPilot needs version " _ ..#APIVERSION
            } Else {
                Set tReason = "The instance's administration API is absent or did not answer OcuPilot's probe"
            }
            Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, tReason, .pHttpStatus, .pFault)
            If $$$ISERR(tVerifySC) {
                Do ..LogFault("admin API unverified", tVerifySC, pFault.code)
            } ElseIf tDetail '= "" {
                Do ..LogFault("admin API unverified", $$$ERROR($$$GeneralError, tDetail), pFault.code)
            }
            Quit
        }

        Set tClass = ..EndpointClass(pEndpoint)
        Set tType = ""
        If tClass '= "" Set tType = ..EndpointType(pEndpoint, tClass, pType)
        If tType = "" {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }

        ; SPLITQUERIES: a composite key the vendor reads as several parameters is split on a copy,
        ; so the caller's query keeps the product's one key. A malformed key names no target.
        If '..SplitQuery(pEndpoint, .pQuery, .tQuery) {
            Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        ; Story 18.19 (AD-21, AD-26): a journal record call's filter, offset and address are checked,
        ; and the list's maxRows multiplied, on the copy, before the guard's list read, so a refused
        ; filter costs no vendor call at all.
        If ..IsJournalRecordType(pEndpoint, pType) {
            Set tSC = ..JournalRecordRules(pEndpoint, pType, .tQuery, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
        ; AD-21's eighth case: a journal file is accepted only as the instance's own list spells it,
        ; read whole at this call and before the target's call. The guard works on the copy.
        If ..IsJournalFileType(pEndpoint, pType) {
            Set tSC = ..JournalGuard(pEndpoint, pType, .tQuery, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }

        ; CONSTANTBODIES: a vendor type whose body is a fixed wire fact takes it here, so no caller
        ; above the port composes it. A caller body for such a pair is a caller bug, refused before
        ; the vendor is reached rather than merged or replaced.
        Set tConstant = ..ConstantBody(pEndpoint, pType)
        If $IsObject(tConstant) {
            If $IsObject(pBody) || (pBody '= "") {
                Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
                Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its body is the port's constant", $$$ERROR($$$GeneralError, "a CONSTANTBODIES pair takes no caller body"), pFault.code)
                Quit
            }
            Set pBody = tConstant
        }

        ; DW-1427. A mutating call with a non-object body is refused rather than run: RunSequence
        ; substitutes {} for it, the vendor reads that as no properties, and the endpoint answers
        ; 2xx having written nothing. A write that reports success and changed nothing is the one
        ; failure a confirmed proposal must not be able to produce, so the port refuses the call
        ; instead of issuing it. Asked only for a body-taking mutating type, so neither a read's
        ; omitted body nor a BODYLESSTYPES write is affected. The exemption is read for the
        ; (endpoint, type) pair, so one endpoint's bodyless type does not exempt another
        ; endpoint's type of the same name (DW-1464).
        If ..IsMutating(pEndpoint, pType) && '..IsBodyless(pEndpoint, pType) && '$IsObject(pBody) {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a body that is not an object, which the vendor reads as carrying no properties", $$$ERROR($$$GeneralError, "a mutating call's body must be a %DynamicAbstractObject, never its JSON text"), pFault.code)
            Quit
        }

        ; RENAMEDTYPES: the vendor's own spelling of a body key, applied to a copy so the caller's
        ; body -- and whatever it records from it -- keeps the product's name. It runs before the
        ; wrapper, because it renames keys of the flat body.
        If $IsObject(pBody) Set pBody = ..Renamed(pEndpoint, pType, pBody)
        ; WRAPPEDTYPES: a flat body becomes the vendor's wrapper here, before ValidateRequest reads
        ; it, so no caller above the port composes the wire shape.
        Set tBody = pBody
        If $IsObject(pBody) Set tBody = ..Wrapped(pEndpoint, pType, pBody)
        ; TYPEKEPTTYPES: the application type an edit must not change, read before the vendor call.
        Set tKept = ""
        If ..IsTypeKept(pEndpoint, pType) {
            Set tKeptSC = ..KeptType($Get(pQuery("name")), .tKept)
            If $$$ISERR(tKeptSC) {
                Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
                Do ..LogFault(pEndpoint _ " " _ pType _ " could not read the application type it keeps", tKeptSC, pFault.code)
                Quit
            }
        }
        Set tTest = ..IsConnectionTest(pEndpoint, pType)
        Set tSeqSC = ..RunSequence(pEndpoint, tClass, tType, .tQuery, tBody, .tAnswer, .tHttp, .tLocation, ..HttpMethodFor(pEndpoint, pType), tTest, .tLines)
        ; CONNECTIONTESTTYPES: a test runs in process, never queued, its outcome is its answer, pass
        ; or fail, and its text goes to the caller alone (AD-26, AD-39's named exceptions).
        If tTest {
            Set tSC = ..TestOutcome(pEndpoint, pType, tSeqSC, tHttp, $Get(tAnswer), $Get(tLines), .pResult, .pHttpStatus, .pFault)
            Set tLines = ""
            Quit
        }
        If $$$ISOK(tSeqSC) && (tHttp = 202) && (tLocation [ ..#ASYNCLOCATION) {
            Set tAnswer = ""
            Set tGuid = $Piece($Piece(tLocation, ..#ASYNCLOCATION, 2), "&", 1)
            Set tSC = ..AwaitTask(pEndpoint, tGuid, .pResult, .pHttpStatus, .pFault, pType)
            Quit
        }
        If $$$ISOK(tSeqSC) && (tHttp >= 200) && (tHttp < 300) {
            ; VERIFIEDDELETES: a delete the vendor reports as made is believed only once a re-read
            ; finds the object gone.
            If ..IsVerifiedDelete(pEndpoint, pType) {
                Set tSC = ..VerifyGone(pEndpoint, .pQuery, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
            ; AWAITEDDELETES: a delete the vendor only marks is reported once the daemon has removed
            ; the object, or once the bound has passed; either way the write stands as made.
            If ..AwaitedDeleteKey(pEndpoint, pType) '= "" Do ..AwaitGone(pEndpoint, pType, .pQuery)
            ; TYPEKEPTTYPES: the vendor call reset the application type, so the one it held is put
            ; back before the write is reported as made.
            If tKept '= "" {
                Set tRestoreSC = ..RestoreType($Get(pQuery("name")), tKept)
                If $$$ISERR(tRestoreSC) {
                    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, .pHttpStatus, .pFault)
                    Do ..LogFault(pEndpoint _ " " _ pType _ " was applied and the application type could not be restored", tRestoreSC, pFault.code)
                    Quit
                }
            }
            ; VERIFIEDWRITES: a write the vendor reports as made is believed only once a re-read
            ; answers every sent value.
            If ..IsVerifiedWrite(pEndpoint, pType) {
                Set tSC = ..VerifyApplied(pEndpoint, .pQuery, pBody, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
            Set pResult = tAnswer
            Set pHttpStatus = tHttp
            Set pLocation = $Get(tLocation)
            Quit
        }
        ; DW-274. A backing query that refuses on its own privilege check reaches this port as an
        ; error status with no HTTP status of its own, which RunSequence raises to 500 -- so a
        ; screen that under-declares its pair set reads "an internal error occurred" where the real
        ; answer is "you do not hold %Admin_Manage:USE". The vendor's own status is unreachable
        ; (ClassQuery assigns %Execute() to a method-local and never checks it), so the port asks
        ; the question itself, on the error path only: no cost on the happy path, and no false 403
        ; for a caller who does hold the set. An endpoint with no declared set keeps the 500.
        If $$$ISERR(tSeqSC) && (tHttp = 500) && ..QueryPairRefused(pEndpoint, pType, .tFailedPair) {
            Set tSC = ..Denied(pEndpoint, tFailedPair, tSeqSC, .pHttpStatus, .pFault, pBody)
            Quit
        }
        ; UNLOGGEDQUERY: a refusal quoting a value that must not reach the log is masked first.
        If $$$ISERR(tSeqSC) Set tSeqSC = ..Unlogged(pEndpoint, pType, .pQuery, tSeqSC)
        ; TYPEFAULTS: a listed pair's vendor error answers the product's own code and sentence.
        Set tTypeFault = ..TypeFault(pEndpoint, pType)
        If $$$ISERR(tSeqSC) && (tHttp = 500) && (tTypeFault '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, tTypeFault, $Parameter("OcuPilot.Api.Error", "REASON" _ $Translate(tTypeFault, ".")), .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " failed with HTTP 500", ..LoggedStatus(tSeqSC, pBody), pFault.code)
            Quit
        }
        ; AD-2: a read the vendor answers 404 has its answer, an absence, and is not logged.
        Set tSC = ..Fail(pEndpoint, tHttp, tSeqSC, .pHttpStatus, .pFault, ..WrapperKey(pEndpoint, pType), pBody, '..IsMutating(pEndpoint, pType), pType)
    } Catch ex {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Do ..LogFault(pEndpoint _ " failed inside the port", ex.AsStatus(), pFault.code)
        Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
    }
    Quit tSC
}

/// <p>The fully qualified endpoint class for a package-relative name, or <code>""</code> when
/// the name is not dotted identifiers or no such compiled class exists.</p>
ClassMethod EndpointClass(pEndpoint As %String) As %String
{
    If '$Match(pEndpoint, "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit ""
    Set tClass = ..#ENDPOINTPACKAGE _ pEndpoint
    If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Quit ""
    Quit tClass
}

/// <p>The body-template method the endpoint <var>pEndpoint</var> (package-relative) publishes: the
/// first name in <parameter>TEMPLATENAMES</parameter> its class defines itself, or
/// <code>""</code> when <method>EndpointClass</method> resolves no class or the class defines
/// none (AD-3). An inherited definition does not count.</p>
ClassMethod TemplateMethod(pEndpoint As %String) As %String
{
    Set tFound = ""
    Set tClass = ..EndpointClass(pEndpoint)
    If tClass = "" Quit ""
    Set tNames = $ListFromString(..#TEMPLATENAMES)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $ListGet(tNames, tI)
        If ..MethodOrigin(tClass, tName) = tClass {
            Set tFound = tName
            Quit
        }
    }
    Quit tFound
}

/// <p>Evaluate the body template of the endpoint <var>pEndpoint</var> (package-relative). On
/// success <var>pTemplate</var> is the <class>%DynamicAbstractObject</class> the method returned
/// and <var>pMethod</var> the method's name (<method>TemplateMethod</method>). Returns an error
/// status, with <var>pTemplate</var> empty, when no class resolves, the class publishes no
/// template, or the method does not return a dynamic object.</p>
/// <p>An instance method is called on an endpoint constructed at <parameter>APIVERSION</parameter>
/// with the class's <code>TYPEGET</code> request type; a class method is called on the class.
/// The argument <parameter>TEMPLATEARGUMENTS</parameter> names for the endpoint is passed, and no
/// other. The call runs in <code>%SYS</code>, reached by save and restore (AD-16), and the
/// endpoint is constructed before the switch, as <method>RunSequence</method> does. Nothing but
/// the template method is called: no gate, no validation and no <code>Run()</code>.</p>
/// <p><var>pArgument</var>, when given, is passed as the method's one argument in place of any
/// <parameter>TEMPLATEARGUMENTS</parameter> entry, so one endpoint's template can be read once per
/// argument (AD-3: <code>LanguageServer</code>'s, once per <code>Config.Gateways</code> type).</p>
ClassMethod Template(pEndpoint As %String, Output pTemplate As %DynamicAbstractObject, Output pMethod As %String, pArgument As %String) As %Status
{
    Set tSC = $$$OK
    Set pTemplate = ""
    Set pMethod = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tClass = ..EndpointClass(pEndpoint)
        If tClass = "" {
            Set tSC = $$$ERROR($$$GeneralError, "no endpoint class resolves for " _ pEndpoint)
            Quit
        }
        Set pMethod = ..TemplateMethod(pEndpoint)
        If pMethod = "" {
            Set tSC = $$$ERROR($$$GeneralError, pEndpoint _ " publishes no body template")
            Quit
        }
        Set tHasArgument = 0
        Set tArgument = ""
        Set tPairs = $ListFromString(..#TEMPLATEARGUMENTS)
        For tI = 1:1:$ListLength(tPairs) {
            Set tPair = $ListGet(tPairs, tI)
            If $Piece(tPair, ":", 1) '= pEndpoint Continue
            Set tHasArgument = 1
            Set tArgument = $Piece(tPair, ":", 2, *)
        }
        If $Data(pArgument) {
            Set tHasArgument = 1
            Set tArgument = pArgument
        }
        Set tDefinition = ##class(%Dictionary.CompiledMethod).IDKEYOpen(tClass, pMethod, 0)
        Set tIsClassMethod = $IsObject(tDefinition) && tDefinition.ClassMethod
        Set tEndpoint = ""
        If 'tIsClassMethod {
            Set tEndpoint = $ClassMethod(tClass, "%New", $Parameter(tClass, "TYPEGET"), ..#APIVERSION)
            If '$IsObject(tEndpoint) {
                Set tSC = $Get(%objlasterror, $$$ERROR($$$GeneralError, "endpoint did not construct"))
                Quit
            }
        }

        Set $NAMESPACE = "%SYS"
        If tIsClassMethod {
            Set tResult = $Select(tHasArgument: $ClassMethod(tClass, pMethod, tArgument), 1: $ClassMethod(tClass, pMethod))
        } Else {
            Set tResult = $Select(tHasArgument: $Method(tEndpoint, pMethod, tArgument), 1: $Method(tEndpoint, pMethod))
        }
        Set $NAMESPACE = tOrigNS

        If '$IsObject(tResult) || 'tResult.%IsA("%Library.DynamicAbstractObject") {
            Set tSC = $$$ERROR($$$GeneralError, pEndpoint _ "'s " _ pMethod _ " returned no dynamic object")
            Quit
        }
        Set pTemplate = tResult
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pTemplate = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the calling process holds <var>pResource</var> at <code>USE</code>, which is the
/// test <code>Main()</code> applies to each entry of <code>ResourcesOR()</code>.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Quit $System.Security.Check(pResource, "U")
}

/// <p>The any-of pair set <parameter>QUERYPAIRS</parameter> declares for
/// <var>pEndpoint</var> at request type <var>pType</var> (the suffix, not the vendor number), as
/// <code>&lt;pair&gt;|&lt;pair&gt;</code>, or <code>""</code> when none is declared.</p>
/// <p><b>Overridable</b> so a fixture can drive the refusal path without an endpoint whose real
/// backing query would have to be denied on the instance. Production never overrides it.</p>
ClassMethod QueryPairs(pEndpoint As %String, pType As %String) As %String
{
    Set tFound = ""
    Set tWanted = pEndpoint _ "/" _ pType
    Set tEntries = $ListFromString(..#QUERYPAIRS)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $ListGet(tEntries, tI)
        If $Piece(tEntry, "=", 1) '= tWanted Continue
        Set tFound = $Piece(tEntry, "=", 2, *)
    }
    Quit tFound
}

/// <p>What is wrong with a <parameter>QUERYPAIRS</parameter> declaration <var>pDeclared</var>, or
/// <code>""</code> when nothing is (DW-305). Every other declared vocabulary in this tree is
/// refused by name against a corpus, and this one was a bare parameter string: a misspelt key
/// declares nothing and a malformed pair refuses nothing, both silently, because
/// <method>QueryPairs</method> answers <code>""</code> for a key it cannot match and
/// <method>HoldsPair</method> answers 0 for a pair it cannot split.</p>
/// <p>Refused by name: an entry with no <code>=</code>; a key that is not
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code>; an endpoint that is not dotted identifiers; a type
/// outside <parameter>TYPESUFFIXES</parameter>; a key declared twice, since only the last is read;
/// an empty pair set; and a pair that is not <code>resource:permission</code>.</p>
/// <p><b>Whether the resource exists and the endpoint compiles is the instance's answer, not this
/// grammar's</b>, and is asserted against the instance by
/// <class>OcuPilot.Test.AdminPortFault</class> -- a resource name with a typo has a sound shape
/// and would otherwise make the probe refuse every caller.</p>
ClassMethod QueryPairsProblem(pDeclared As %String) As %String
{
    Set tProblem = ""
    Try {
        If pDeclared = "" Quit
        Kill tSeen
        Set tTypes = $ListFromString(..#TYPESUFFIXES)
        Set tEntries = $ListFromString(pDeclared)
        For tI = 1:1:$ListLength(tEntries) {
            Set tEntry = $ListGet(tEntries, tI)
            If tEntry '[ "=" {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' declares no '=', so it names no pair set"
                Quit
            }
            Set tKey = $Piece(tEntry, "=", 1)
            Set tSet = $Piece(tEntry, "=", 2, *)
            Set tEndpoint = $Piece(tKey, "/", 1)
            Set tType = $Piece(tKey, "/", 2, *)
            If (tKey '[ "/") || (tEndpoint = "") || (tType = "") {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' declares the key '" _ tKey _ "', which is not <endpoint>/<type>"
                Quit
            }
            If '$Match(tEndpoint, "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' names the endpoint '" _ tEndpoint _ "', which is not dotted identifiers"
                Quit
            }
            If '$ListFind(tTypes, tType) {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' names the unknown request type '" _ tType _ "'"
                Quit
            }
            If $Data(tSeen(tKey)) {
                Set tProblem = "queryPairs declares the key '" _ tKey _ "' twice, and only the last would be read"
                Quit
            }
            Set tSeen(tKey) = ""
            If tSet = "" {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' declares an empty pair set"
                Quit
            }
            Set tPairs = $ListFromString(tSet, "|")
            Set tBad = ""
            Set tFound = 0
            For tJ = 1:1:$ListLength(tPairs) {
                Set tPair = $ListGet(tPairs, tJ)
                If (tPair '[ ":") || ($Piece(tPair, ":", 1) = "") || ($Piece(tPair, ":", 2, *) = "") {
                    Set tBad = tPair
                    Set tFound = 1
                    Quit
                }
            }
            If tFound {
                Set tProblem = "queryPairs entry '" _ tEntry _ "' declares the pair '" _ tBad _ "', which is not resource:permission"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "queryPairs could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>Whether the calling process holds the pair <var>pPair</var>, spelled
/// <code>resource:permission</code>. The one point at which the backing-query probe consults the
/// instance -- <code>$System.Security.Check</code>, in the calling process, at the moment of the
/// call and never cached (AD-8).</p>
/// <p><b>Overridable</b> for the reason <class>OcuPilot.Screen.Gate</class>'s own check is:
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which the real check
/// answers yes to every resource name, so the set semantics cannot be driven against it. The real
/// check is exercised over the wire by a throwaway principal. Production never overrides it.</p>
ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    Set tResource = $Piece(pPair, ":", 1)
    Set tPermission = $Piece(pPair, ":", 2)
    If (tResource = "") || (tPermission = "") Quit 0
    Quit $System.Security.Check(tResource, tPermission)
}

/// <p>Whether <var>pEndpoint</var> declares a backing-query pair set at <var>pType</var> and the
/// caller holds <b>no</b> pair in it. <var>pFailedPair</var> is then the set's first pair -- the
/// one a denial names, and the one a screen's own declaration is expected to carry (AD-8).</p>
/// <p>0, with <var>pFailedPair</var> empty, when no set is declared or any pair is held. So an
/// endpoint this port knows nothing about, and a caller the instance would have served, both keep
/// whatever answer the sequence produced.</p>
ClassMethod QueryPairRefused(pEndpoint As %String, pType As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tRefused = 0
    Try {
        Set tSet = ..QueryPairs(pEndpoint, pType)
        If tSet = "" Quit
        Set tPairs = $ListFromString(tSet, "|")
        Set tHeld = 0
        For tI = 1:1:$ListLength(tPairs) {
            Set tHeld = tHeld || ..HoldsPair($ListGet(tPairs, tI))
        }
        If tHeld Quit
        Set pFailedPair = $ListGet(tPairs, 1)
        Set tRefused = 1
    } Catch ex {
        ; A probe that cannot answer never invents a denial: the call keeps the 500 it had.
        Set pFailedPair = ""
        Set tRefused = 0
        Do ..LogFault(pEndpoint _ "'s backing-query probe failed", ex.AsStatus())
    }
    Quit tRefused
}

/// <p>Called with the endpoint after <code>ShouldRunAsync()</code> answers 0 and before
/// <code>Run()</code>, in <code>%SYS</code>. Does nothing in production.</p>
ClassMethod OnBeforeRun(pEndpoint As %RegisteredObject)
{
    Quit
}

/// <p>Read one async task's state through the <code>AsyncResult</code> endpoint's GET, by the
/// same sequence <method>Invoke</method> runs. <var>pAnswer</var> is that endpoint's answer
/// (<code>State</code>, <code>TaskName</code>, <code>Result</code>,
/// <code>FailureReason</code>, ...); <var>pHttpStatus</var> the HTTP status it left. The status
/// returned is the vendor sequence's.</p>
ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set tQuery("id") = pGuid
    Set tClass = ..#ENDPOINTPACKAGE _ ..#ASYNCRESULTENDPOINT
    Quit ..RunSequence(..#ASYNCRESULTENDPOINT, tClass, $Parameter(tClass, "TYPEGET"), .tQuery, "", .pAnswer, .pHttpStatus, .tLocation)
}

/// <p>Delete the task row <var>pGuid</var> names, once it is terminal and no worker still owns
/// it. Only the row this call queued is deleted, as the caller, in <code>%SYS</code> (AD-16), and
/// nothing is raised.</p>
/// <p><b>A row the caller cannot delete is left alone, silently, for
/// <method>SweepOwnTasks</method>.</b> The delete is attempted only when
/// <method>MayDeleteTask</method> answers that the caller may write the row, because a delete that
/// meets <code>&lt;PROTECT&gt;</code> is recorded in the instance's audit log as an attempt on a
/// protected global (measured on this build), once per async read, in the log this instance's own
/// Audit screen displays. A <code>&lt;PROTECT&gt;</code> the delete meets all the same, thrown or
/// answered as error 5002 carrying it, is not logged either, since the console-log screen displays
/// that log. Any other failure is logged.</p>
ClassMethod ForgetTask(pGuid As %String)
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ..MayDeleteTask(pGuid) Set tSC = $ClassMethod(..#ASYNCTASKCLASS, "%DeleteId", pGuid)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Quit
    If (("," _ $System.Status.GetErrorCodes(tSC) _ ",") [ ",5002,") && ($System.Status.GetErrorText(tSC) [ "<PROTECT>") Quit
    Do ..LogFault("an async task row could not be removed", tSC)
}

/// <p>Whether the calling process may write the task row <var>pGuid</var> names (DW-1137), as the
/// instance answers it at call time: <code>$System.Security.GetGlobalPermission</code> on
/// <parameter>ASYNCTASKCLASS</parameter>'s data global, whose location is read from that class's
/// compiled storage rather than written here. Asking raises no <code>&lt;PROTECT&gt;</code>. When the
/// location cannot be read, the answer is 1, so the delete is attempted as before.</p>
ClassMethod MayDeleteTask(pGuid As %String) As %Boolean [ Private ]
{
    Set tMay = 1
    Try {
        Set tStorage = ##class(%Dictionary.CompiledStorage).%OpenId(..#ASYNCTASKCLASS _ "||Default")
        If '$IsObject(tStorage) Quit
        Set tLocation = tStorage.DataLocation
        If $Extract(tLocation, 1, 2) = "^|" {
            Set tNamespace = $Piece(tLocation, "|", 2)
            Set tNamespace = $Extract(tNamespace, 2, *-1)
            Set tGlobal = $Piece(tLocation, "|", 3)
        } Else {
            Set tNamespace = $NAMESPACE
            Set tGlobal = $Extract(tLocation, 2, *)
        }
        If (tNamespace = "") || (tGlobal = "") Quit
        Set tPermission = $System.Security.GetGlobalPermission(tNamespace, tGlobal, "(""" _ $Replace(pGuid, """", """""") _ """)")
        Set tMay = (("," _ tPermission _ ",") [ ",WRITE,")
    } Catch {
        Set tMay = 1
    }
    Quit tMay
}

/// <p>Delete the async task rows this port queued once they are terminal and older than
/// <var>pHours</var> hours (AD-37's second bounded case, DW-1101, DW-1136): each row whose
/// <code>TaskName</code> carries the label <parameter>STUBURLPREFIX</parameter> gives it, whose
/// <code>State</code> is <parameter>ASYNCTASKCLASS</parameter>'s finished, failed or canceled
/// state, and whose <code>TimeQueued</code> is earlier than that many hours ago on the instance's
/// clock, which is the clock the vendor queues by. A row this port did not queue is never
/// touched.</p>
/// <p><b>Each row is deleted as an object, never by SQL</b> (DW-1859). The vendor's table runs a SQL
/// delete trigger that attaches the row's work-queue token; the port's own finished read has already
/// ended that queue, so the attach logs ERROR #7846 at severity 2 for every row, which the instance
/// copies to <code>alerts.log</code> and counts toward its Warning state (measured on this build). An
/// object delete does not run the trigger. A row whose result was never read keeps its queue until
/// the vendor's own ten-day detach timeout (inference from the vendor's queueing code).</p>
/// <p><b>Caller contract:</b> one bound-parameter <code>SELECT</code> and an object delete per row it
/// answers, in <code>%SYS</code> (AD-16, AD-21), as the caller, who must be able to delete from the
/// vendor's table -- the retention task's user. <var>pHours</var> is a whole number above zero. A row
/// that fails to delete does not stop the others; the status is the first failure, and nothing is
/// logged here: <method>OcuPilot.Kernel.Retention.Sweep</method> logs a failed step.</p>
ClassMethod SweepOwnTasks(pHours As %Integer = 24) As %Status
{
    Set tSC = $$$OK
    If '$Match(pHours, "^[1-9][0-9]*$") Quit $$$ERROR($$$GeneralError, "the sweep's age is not a whole number of hours above zero: " _ pHours)
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTable = ##class(%Dictionary.CompiledClass).%OpenId(..#ASYNCTASKCLASS).SqlQualifiedNameQ
        ; GetName() labels a task with the text after api/admin, so the label is that part of the
        ; stub URL prefix.
        Set tLabel = $Piece(..#STUBURLPREFIX, "api/admin", 2)
        Set tNow = $Horolog
        Set tSeconds = ($Piece(tNow, ",", 1) * 86400) + $Piece(tNow, ",", 2) - (pHours * 3600)
        Set tCutoff = $ZDateTime((tSeconds \ 86400) _ "," _ (tSeconds # 86400), 3)
        Set tStatement = ##class(%SQL.Statement).%New()
        Set $NAMESPACE = "%SYS"
        Set tSC = tStatement.%Prepare("SELECT %EXACT(GUID) AS GUID FROM " _ tTable _ " WHERE %EXACT(TaskName) [ ? AND %EXACT(State) IN (?, ?, ?) AND TimeQueued < ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute(tLabel, $Parameter(..#ASYNCTASKCLASS, "STATEFINISHED"), $Parameter(..#ASYNCTASKCLASS, "STATEFAILED"), $Parameter(..#ASYNCTASKCLASS, "STATECANCELED"), tCutoff)
            If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the async task rows could not be swept: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
            ; Collected first, so no delete runs while the result set still walks the table.
            Set tGuids = ""
            While $$$ISOK(tSC) && tResult.%Next() {
                Set tGuids = tGuids _ $ListBuild(tResult.%Get("GUID"))
            }
            Set tPointer = 0
            While $ListNext(tGuids, tPointer, tGuid) {
                Set tDeleteSC = $ClassMethod(..#ASYNCTASKCLASS, "%DeleteId", tGuid)
                If $$$ISERR(tDeleteSC) && $$$ISOK(tSC) Set tSC = tDeleteSC
            }
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The bounded wait, in seconds, for an async task to reach a terminal state.</p>
ClassMethod AsyncTimeout() As %Numeric
{
    Quit ..#ASYNCTIMEOUT
}

/// <p>Send raw vendor text to the log, and nowhere else (AD-39).</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("adminport", pMessage, pStatus, pCode)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>VERIFIEDDELETES</parameter> lists.</p>
ClassMethod IsVerifiedDelete(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#VERIFIEDDELETES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Re-read <var>pEndpoint</var> with the query <var>pQuery</var> a delete was issued with, and
/// answer OK only when the read answers 404. A read that finds the object, or fails any other way,
/// is a 500 fault carrying <parameter>OcuPilot.Api.Error.PORTNOTAPPLIED</parameter>, with the read's
/// own answer in the log.</p>
ClassMethod VerifyGone(pEndpoint As %String, ByRef pQuery, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReadSC = ..Invoke(pEndpoint, "GET", .pQuery, "", .tFresh, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) && (+$Get(tReadHttp) = 404) Quit $$$OK
    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, .pHttpStatus, .pFault)
    Do ..LogFault(pEndpoint _ " answered a delete as made and a re-read answered HTTP " _ +$Get(tReadHttp), $Select($$$ISERR(tReadSC): tReadSC, 1: $$$ERROR($$$GeneralError, "the object is still present")), pFault.code)
    Quit tSC
}

/// <p>The <code>&lt;query parameter&gt;:&lt;row key&gt;</code> <parameter>AWAITEDDELETES</parameter>
/// lists for <var>pEndpoint</var>'s request type <var>pSuffix</var>, or <code>""</code> for a pair
/// it does not list.</p>
ClassMethod AwaitedDeleteKey(pEndpoint As %String, pSuffix As %String) As %String
{
    Set tEntries = ..#AWAITEDDELETES
    For tI = 1:1:$Length(tEntries, ",") {
        Set tEntry = $Piece(tEntries, ",", tI)
        If $Piece(tEntry, "=", 1) = (pEndpoint _ "/" _ pSuffix) Quit
        Set tEntry = ""
    }
    Quit $Piece($Get(tEntry), "=", 2)
}

/// <p>Wait until <var>pEndpoint</var>'s <code>LIST</code> no longer holds the row a marked delete
/// of type <var>pSuffix</var> removed, whose key is <var>pQuery</var>'s value for the pair's query
/// parameter (<parameter>AWAITEDDELETES</parameter>). The list is read at once and then every
/// <parameter>AWAITEDDELETEPOLLMS</parameter> milliseconds, the row key compared exactly, for at
/// most <parameter>AWAITEDDELETEMS</parameter>.</p>
/// <p><b>Caller contract:</b> called by <method>Invoke</method> alone, after the vendor answered the
/// delete 2xx, and it never fails the write: gone, past the bound and a list that could not be read
/// all return, and only the bound is logged -- without the removed key, which may be a session id.
/// A pair with no row key, or a query with no value for it, is not waited on.</p>
ClassMethod AwaitGone(pEndpoint As %String, pSuffix As %String, ByRef pQuery) [ Private ]
{
    Try {
        Set tKey = ..AwaitedDeleteKey(pEndpoint, pSuffix)
        Set tParam = $Piece(tKey, ":", 1)
        Set tRowKey = $Piece(tKey, ":", 2)
        If (tParam = "") || (tRowKey = "") Quit
        Set tWanted = $Get(pQuery(tParam))
        If tWanted = "" Quit
        Set tDeadline = $ZHorolog + (..#AWAITEDDELETEMS / 1000)
        Set tGone = 0
        For {
            Kill tListQuery
            Set tListSC = ..Invoke(pEndpoint, "LIST", .tListQuery, "", .tRows, .tHttp, .tFault)
            ; A list that cannot be read leaves the vendor's own answer standing.
            If $$$ISERR(tListSC) || '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit
            Set tListed = 0
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
                If tRow.%Get(tRowKey) = tWanted {
                    Set tListed = 1
                    Quit
                }
            }
            Set tRows = ""
            If 'tListed {
                Set tGone = 1
                Quit
            }
            If $ZHorolog >= tDeadline Quit
            Hang ..#AWAITEDDELETEPOLLMS / 1000
        }
        If 'tGone && ($ZHorolog >= tDeadline) {
            Do ..LogFault(pEndpoint _ " " _ pSuffix _ " was answered as made and its row was still listed " _ (..#AWAITEDDELETEMS / 1000) _ " seconds later", $$$ERROR($$$GeneralError, "the marked row was not yet removed"))
        }
    } Catch ex {
        Do ..LogFault(pEndpoint _ " " _ pSuffix _ " could not be awaited", ex.AsStatus())
    }
}

/// <p><var>pStatus</var> with the value <var>pQuery</var> carries under <var>pEndpoint</var>
/// <var>pSuffix</var>'s <parameter>UNLOGGEDQUERY</parameter> parameter replaced by the log's mask;
/// <var>pStatus</var> itself for a pair that parameter does not list, or a text that does not quote
/// the value. The HTTP status, not this text, decides the fault a caller is answered.</p>
ClassMethod Unlogged(pEndpoint As %String, pSuffix As %String, ByRef pQuery, pStatus As %Status) As %Status [ Private ]
{
    Set tMasked = pStatus
    Try {
        Set tParam = ""
        For tI = 1:1:$Length(..#UNLOGGEDQUERY, ",") {
            Set tEntry = $Piece(..#UNLOGGEDQUERY, ",", tI)
            If $Piece(tEntry, "=", 1) = (pEndpoint _ "/" _ pSuffix) Set tParam = $Piece(tEntry, "=", 2)
        }
        If tParam = "" Quit
        Set tValue = $Get(pQuery(tParam))
        If tValue = "" Quit
        Set tText = $System.Status.GetErrorText(pStatus)
        If '(tText [ tValue) Quit
        Set tMasked = $$$ERROR($$$GeneralError, $Replace(tText, tValue, $Parameter("OcuPilot.Kernel.Audit.Log", "REDACTED")))
    } Catch {
        Set tMasked = $$$ERROR($$$GeneralError, "the vendor's status could not be screened for the value its request named, so its text is not logged")
    }
    Quit tMasked
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>TYPEKEPTTYPES</parameter> lists.</p>
ClassMethod IsTypeKept(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#TYPEKEPTTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>The <code>Type</code> the web application <var>pName</var> holds now, read from
/// <class>Security.Applications</class> in <code>%SYS</code> (AD-16), in <var>pType</var>; <code>""</code>
/// for an application the instance does not hold (a create), for an empty name, and for a caller
/// short of <parameter>TYPEKEPTRESOURCE</parameter>, whom the vendor call refuses on its own gate.</p>
ClassMethod KeptType(pName As %String, Output pType As %String) As %Status [ Private ]
{
    Set pType = ""
    Set tSC = $$$OK
    If pName = "" Quit tSC
    If '..HoldsResource(..#TYPEKEPTRESOURCE) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName) {
            Kill tProps
            Set tSC = ##class(Security.Applications).Get(pName, .tProps)
            If $$$ISOK(tSC) Set pType = $Get(tProps("Type"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pType = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Re-apply <var>pType</var> to the web application <var>pName</var> when the vendor call left it
/// holding another, through <method>Security.Applications.Modify</method> in <code>%SYS</code>
/// (AD-16), behind <parameter>TYPEKEPTRESOURCE</parameter>. The type is read back afterwards, and a
/// type that still differs is an error.</p>
ClassMethod RestoreType(pName As %String, pType As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    If '..HoldsResource(..#TYPEKEPTRESOURCE) Quit $$$ERROR($$$GeneralError, "the caller does not hold " _ ..#TYPEKEPTRESOURCE)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = ##class(Security.Applications).Get(pName, .tProps)
        If $$$ISOK(tSC) && ($Get(tProps("Type")) '= pType) {
            Kill tProps
            Set tProps("Type") = pType
            Set tSC = ##class(Security.Applications).Modify(pName, .tProps)
            If $$$ISOK(tSC) {
                Kill tProps
                Set tSC = ##class(Security.Applications).Get(pName, .tProps)
                If $$$ISOK(tSC) && ($Get(tProps("Type")) '= pType) Set tSC = $$$ERROR($$$GeneralError, "the application type reads " _ $Get(tProps("Type")) _ " after the restore")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>VERIFIEDWRITES</parameter> lists.</p>
ClassMethod IsVerifiedWrite(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#VERIFIEDWRITES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Re-read <var>pEndpoint</var> with the query <var>pQuery</var> a write was issued with, and
/// answer OK only when every key of the sent <var>pBody</var> reads back with the value sent
/// (<method>SameValue</method>). A read that fails, or a value that differs, is a 500 fault carrying
/// <parameter>OcuPilot.Api.Error.PORTNOTAPPLIED</parameter>, with the differing key in the log.</p>
ClassMethod VerifyApplied(pEndpoint As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReadSC = ..Invoke(pEndpoint, "GET", .pQuery, "", .tFresh, .tReadHttp, .tReadFault)
    Set tDiffers = ""
    If $$$ISOK(tReadSC) && $IsObject(tFresh) && $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '..SameValue(tKey, pBody, tFresh) Set tDiffers = tKey Quit
        }
        If tDiffers = "" Quit $$$OK
    }
    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, .pHttpStatus, .pFault)
    Do ..LogFault(pEndpoint _ " answered a write as made and a re-read answered HTTP " _ +$Get(tReadHttp), $Select($$$ISERR(tReadSC): tReadSC, 1: $$$ERROR($$$GeneralError, "the re-read does not carry the sent value of '" _ tDiffers _ "'")), pFault.code)
    Quit tSC
}

/// <p>Whether <var>pKey</var> reads the same on the sent <var>pSent</var> and the re-read
/// <var>pRead</var>: rendered as the proposal diff renders a value, and a
/// <code>PublicPermission</code> compared as a set of letters, since the vendor writes the letters
/// in its own order.</p>
ClassMethod SameValue(pKey As %String, pSent As %DynamicObject, pRead As %DynamicObject) As %Boolean [ Private ]
{
    Set tSent = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pSent.%Get(pKey), pSent.%GetTypeOf(pKey))
    Set tRead = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pRead.%Get(pKey), pRead.%GetTypeOf(pKey))
    If pKey '= "PublicPermission" Quit (tSent = tRead)
    Quit (..LetterSet(tSent) = ..LetterSet(tRead))
}

/// <p>The distinct letters of <var>pLetters</var>, upper-cased and in alphabetical order.</p>
ClassMethod LetterSet(pLetters As %String) As %String [ Private ]
{
    Kill tSeen
    Set tLetters = $ZConvert(pLetters, "U")
    For tI = 1:1:$Length(tLetters) Set tSeen($Extract(tLetters, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ tKey
    }
    Quit tOut
}

/// <p>The field <parameter>CLASSCOMPLETEDTYPES</parameter> names for <var>pEndpoint</var>'s request
/// type <var>pSuffix</var>, when <var>pBody</var> carries it as the empty string; otherwise
/// <code>""</code>, and the call goes to the vendor's endpoint.</p>
ClassMethod ClassCompletedField(pEndpoint As %String, pSuffix As %String, pBody As %DynamicAbstractObject) As %String
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ""
    Set tField = ""
    Set tEntries = $ListFromString(..#CLASSCOMPLETEDTYPES)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        If $Piece(tEntry, "=", 1) '= (pEndpoint _ "/" _ pSuffix) Continue
        Set tField = $Piece(tEntry, "=", 2)
        Quit
    }
    If tField = "" Quit ""
    If pBody.%GetTypeOf(tField) '= "string" Quit ""
    If pBody.%Get(tField) '= "" Quit ""
    Quit tField
}

/// <p>AD-27's fallback for <code>Security.Resource/PUT</code> with no public permission
/// (<parameter>CLASSCOMPLETEDTYPES</parameter>): the endpoint <var>pClass</var>, constructed at
/// <var>pType</var>, is gated on its own <code>ResourcesOR()</code> and validates the body with its
/// own <code>ValidateRequest</code>; the resource is then created (201) or modified (200) through
/// <class>Security.Resources</class> in <code>%SYS</code> (AD-16), with the keys the body carries.
/// <var>pAnswer</var> is the resource as <code>{Description, PublicPermission}</code>.</p>
/// <p><b>Caller contract:</b> <var>pHttpStatus</var> is 403 for a caller the gate refuses, 400 for
/// a missing <code>name</code> or a body the endpoint refuses, and 500 with the vendor status for a
/// class call that fails, which is <method>RunSequence</method>'s own answer shape.</p>
ClassMethod CompleteThroughClass(pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicObject, Output pAnswer, Output pHttpStatus As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tEndpoint = $ClassMethod(pClass, "%New", pType, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set tSC = $Get(%objlasterror, $$$ERROR($$$GeneralError, "endpoint did not construct"))
            Quit
        }
        Set tAllowed = 0
        Set tResources = tEndpoint.ResourcesOR()
        For tI = 1:1:$ListLength(tResources) {
            Set tAllowed = tAllowed || ..HoldsResource($ListGet(tResources, tI))
        }
        If 'tAllowed {
            Set pHttpStatus = 403
            Quit
        }
        Set tName = $Get(pQuery("name"))
        If tName = "" {
            Set pHttpStatus = 400
            Set tSC = $$$ERROR($$$GeneralError, "the name query parameter is required")
            Quit
        }
        Set tEndpoint.Name = tName
        Set $NAMESPACE = "%SYS"
        Set tSC = tEndpoint.ValidateRequest(pBody)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Set pHttpStatus = 400
            Quit
        }
        Set tCreated = 0
        If '##class(Security.Resources).Exists(tName) {
            Set tSC = ##class(Security.Resources).Create(tName, pBody.%Get("Description"), "")
            Set tCreated = 1
        } Else {
            Kill tProps
            If pBody.%IsDefined("Description") Set tProps("Description") = pBody.%Get("Description")
            Set tProps("PublicPermission") = ""
            Set tSC = ##class(Security.Resources).Modify(tName, .tProps)
        }
        If $$$ISOK(tSC) && ##class(Security.Resources).Exists(tName, .tObject) {
            Set pAnswer = {}
            Do pAnswer.%Set("Description", tObject.Description, "string")
            Do pAnswer.%Set("PublicPermission", ##class(Security.Datatype.Permission).InternalToExternal(tObject.PublicPermission), "string")
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) {
            Set pHttpStatus = 500
            Quit
        }
        Set pHttpStatus = $Select(tCreated: 201, 1: 200)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
        Set pHttpStatus = 500
    }
    If $$$ISERR(tSC) && (pHttpStatus = 0) Set pHttpStatus = 500
    Quit tSC
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>CONTENTCOMPLETEDTYPES</parameter> lists.</p>
ClassMethod IsContentCompleted(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#CONTENTCOMPLETEDTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Whether <var>pText</var> is exactly one PEM block of kind <var>pKind</var> -- <code>cert</code>
/// for a <code>CERTIFICATE</code> block, <code>key</code> for a <code>PRIVATE KEY</code>,
/// <code>RSA PRIVATE KEY</code> or <code>ENCRYPTED PRIVATE KEY</code> block -- of at most
/// <parameter>PEMMAXLENGTH</parameter> characters. On success <var>pCanonical</var> is the block
/// rewritten with line feeds only and its base64 body wrapped at 64 columns, which is the shape the
/// vendor's key check reads; on refusal it is <code>""</code>.</p>
/// <p><b>A block whose line breaks were lost is re-wrapped</b> -- a password input and the proposal
/// card both drop them -- unless it carries a <code>Proc-Type</code> header: a legacy encrypted key
/// separates its headers from its body by a blank line, which cannot be recovered once the line
/// breaks are gone. Nothing here writes, logs or returns the text anywhere else (AD-35).</p>
ClassMethod PemBlock(pText As %String, pKind As %String, Output pCanonical As %String) As %Boolean
{
    Set pCanonical = ""
    Set tOK = 0
    Try {
        Set tText = $ZStrip($Translate(pText, $Char(13), ""), "<>WC")
        If (tText = "") || ($Length(tText) > ..#PEMMAXLENGTH) Quit
        If ($Length(tText, "-----BEGIN ") '= 2) || ($Length(tText, "-----END ") '= 2) Quit
        Set tLabels = $Select(pKind = "cert": $ListBuild("CERTIFICATE"), pKind = "key": $ListBuild("PRIVATE KEY", "RSA PRIVATE KEY", "ENCRYPTED PRIVATE KEY"), 1: "")
        Set tBegin = ""
        Set tEnd = ""
        For tI = 1:1:$ListLength(tLabels) {
            Set tTryBegin = "-----BEGIN " _ $List(tLabels, tI) _ "-----"
            Set tTryEnd = "-----END " _ $List(tLabels, tI) _ "-----"
            If ($Extract(tText, 1, $Length(tTryBegin)) = tTryBegin) && ($Extract(tText, *-$Length(tTryEnd) + 1, *) = tTryEnd) {
                Set tBegin = tTryBegin
                Set tEnd = tTryEnd
                Quit
            }
        }
        If tBegin = "" Quit
        Set tInner = $Extract(tText, $Length(tBegin) + 1, *-$Length(tEnd))
        Set tHeaders = ""
        Set tBody = ""
        If tInner '[ $Char(10) {
            If (tInner [ "Proc-Type") || (tInner [ "DEK-Info") Quit
            Set tBody = $Translate(tInner, " " _ $Char(9), "")
        } Else {
            Set tBad = 0
            For tI = 1:1:$Length(tInner, $Char(10)) {
                Set tLine = $ZStrip($Piece(tInner, $Char(10), tI), "<>W")
                If tLine = "" Continue
                If tLine [ ":" {
                    If tBody '= "" Set tBad = 1 Quit
                    Set tHeaders = tHeaders _ tLine _ $Char(10)
                    Continue
                }
                Set tBody = tBody _ $Translate(tLine, " " _ $Char(9), "")
            }
            If tBad Quit
        }
        If (tBody = "") || '$Match(tBody, "^[A-Za-z0-9+/]+={0,2}$") || ($Length(tBody) # 4) Quit
        Set tWrapped = ""
        For tI = 1:64:$Length(tBody) {
            Set tWrapped = tWrapped _ $Extract(tBody, tI, tI + 63) _ $Char(10)
        }
        Set pCanonical = tBegin _ $Char(10) _ $Select(tHeaders = "": "", 1: tHeaders _ $Char(10)) _ tWrapped _ tEnd
        Set tOK = 1
    } Catch {
        Set pCanonical = ""
        Set tOK = 0
    }
    Set tText = ""
    Set tInner = ""
    Set tBody = ""
    Set tWrapped = ""
    Quit tOK
}

/// <p>The DER bytes of the canonical PEM block <var>pCanonical</var> (<method>PemBlock</method>'s
/// answer), or <code>""</code> when they cannot be decoded.</p>
ClassMethod PemBytes(pCanonical As %String) As %String
{
    Set tBytes = ""
    Try {
        Set tLines = ""
        For tI = 2:1:$Length(pCanonical, $Char(10)) - 1 {
            Set tLine = $Piece(pCanonical, $Char(10), tI)
            If (tLine = "") || (tLine [ ":") Continue
            Set tLines = tLines _ tLine
        }
        Set tBytes = $System.Encryption.Base64Decode(tLines)
    } Catch {
        Set tBytes = ""
    }
    Quit tBytes
}

/// <p>AD-27's second case (<parameter>CONTENTCOMPLETEDTYPES</parameter>): import the credential
/// <code>alias</code> names in <var>pQuery</var> from the content in <var>pBody</var> through
/// <class>%SYS.X509Credentials</class> in <code>%SYS</code> (AD-16), behind the endpoint
/// <var>pClass</var>'s own <code>ResourcesOR()</code> gate. <var>pAnswer</var> is the credential as
/// the vendor's own <code>GET</code> then answers it.</p>
/// <p><b>Caller contract:</b> <var>pHttpStatus</var> is 403 for a caller the gate refuses; 400 for
/// a missing alias, a body key outside <parameter>IMPORTFIELDS</parameter>, a list that is not an
/// array of strings, a certificate or key <method>PemBlock</method> refuses, a certificate that
/// does not decode, a password longer than <parameter>PASSWORDMAXLENGTH</parameter> or one sent
/// with no key, and a save refused for a code <parameter>IMPORTSAVECODES</parameter> names; 409 for
/// an alias already present, compared exactly, as the vendor answers it; 500 for any other refused
/// save, the vendor's own answer shape; 201 on success.</p>
/// <p><b>No secret text leaves this method</b> (AD-35). Every error status it returns is written
/// here and names a code, never a value, so neither <method>Fail</method>'s log line nor a fault
/// can carry one; every local that held key, certificate or password text is cleared before it
/// returns, on every path.</p>
ClassMethod ImportThroughClass(pEndpoint As %String, pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicAbstractObject, Output pAnswer, Output pHttpStatus As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set tOrigNS = $NAMESPACE
    Set (tCert, tKey, tPassword, tBytes) = ""
    Set tCredential = ""
    Try {
        Set tEndpoint = $ClassMethod(pClass, "%New", pType, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set tSC = $$$ERROR($$$GeneralError, "endpoint did not construct")
            Quit
        }
        Set tAllowed = 0
        Set tResources = tEndpoint.ResourcesOR()
        For tI = 1:1:$ListLength(tResources) {
            Set tAllowed = tAllowed || ..HoldsResource($ListGet(tResources, tI))
        }
        If 'tAllowed {
            Set pHttpStatus = 403
            Quit
        }
        Set tAlias = $Get(pQuery("alias"))
        If tAlias = "" {
            Set pHttpStatus = 400
            Set tSC = $$$ERROR($$$GeneralError, "the alias query parameter is required")
            Quit
        }
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 400
            Set tSC = $$$ERROR($$$GeneralError, "the import body is not an object")
            Quit
        }
        Set tAdmitted = $ListFromString(..#IMPORTFIELDS)
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKeyName, .tValue) {
            If '$ListFind(tAdmitted, tKeyName) {
                Set pHttpStatus = 400
                Set tSC = $$$ERROR($$$GeneralError, "the import body carries a key it does not admit: " _ tKeyName)
                Quit
            }
        }
        Set tValue = ""
        If $$$ISERR(tSC) Quit
        Kill tLists
        For tField = "OwnerList", "PeerNames" {
            Set tLists(tField) = ""
            Set tType = pBody.%GetTypeOf(tField)
            If (tType = "unassigned") || (tType = "null") Continue
            If tType '= "array" {
                Set tSC = $$$ERROR($$$GeneralError, tField _ " is not an array")
                Quit
            }
            Set tJoined = ""
            Set tItems = pBody.%Get(tField).%GetIterator()
            While tItems.%GetNext(.tIndex, .tItem) {
                If $IsObject(tItem) {
                    Set tSC = $$$ERROR($$$GeneralError, tField _ " holds a value that is not a string")
                    Quit
                }
                If tItem = "" Continue
                Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ",") _ tItem
            }
            Set tLists(tField) = tJoined
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) {
            Set pHttpStatus = 400
            Quit
        }
        If pBody.%GetTypeOf("Certificate") = "string" Set tCert = pBody.%Get("Certificate")
        If pBody.%GetTypeOf("PrivateKey") = "string" Set tKey = pBody.%Get("PrivateKey")
        If pBody.%GetTypeOf("PrivateKeyPassword") = "string" Set tPassword = pBody.%Get("PrivateKeyPassword")
        Set tRefusal = ""
        If '..PemBlock(tCert, "cert", .tCert) {
            Set tRefusal = ##class(OcuPilot.Api.Error).#X509CERTIFICATESHAPE
        } ElseIf (tKey '= "") && '..PemBlock(tKey, "key", .tKey) {
            Set tRefusal = ##class(OcuPilot.Api.Error).#X509PRIVATEKEYSHAPE
        } ElseIf (tPassword '= "") && (tKey = "") {
            Set tRefusal = ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDWITHOUTKEY
        } ElseIf $Length(tPassword) > ..#PASSWORDMAXLENGTH {
            Set tRefusal = ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDLENGTH
        }
        If tRefusal = "" {
            Set tBytes = ..PemBytes(tCert)
            If tBytes = "" Set tRefusal = ##class(OcuPilot.Api.Error).#X509CERTIFICATESHAPE
        }
        If tRefusal '= "" {
            Set pHttpStatus = 400
            Set tSC = $$$ERROR($$$GeneralError, "the import was refused: " _ tRefusal)
            Quit
        }

        Set $NAMESPACE = "%SYS"
        If ##class(%SYS.X509Credentials).Exists(tAlias) {
            Set $NAMESPACE = tOrigNS
            Set pHttpStatus = 409
            Set tSC = $$$ERROR($$$GeneralError, "an X.509 credential already carries that alias")
            Quit
        }
        Set tCredential = ##class(%SYS.X509Credentials).%New()
        Set tCredential.Alias = tAlias
        Set tDecoded = 1
        Try {
            Set tCredential.Certificate = tBytes
        } Catch {
            Set $NAMESPACE = tOrigNS
            Set tDecoded = 0
        }
        If 'tDecoded {
            Set tCredential = ""
            Set $NAMESPACE = tOrigNS
            Set pHttpStatus = 400
            Set tSC = $$$ERROR($$$GeneralError, "the import was refused: " _ ##class(OcuPilot.Api.Error).#X509CERTIFICATESHAPE)
            Quit
        }
        If tKey '= "" {
            Set tCredential.PrivateKey = tKey
            Set tCredential.PrivateKeyPassword = tPassword
        }
        Set tCredential.OwnerList = tLists("OwnerList")
        Set tCredential.PeerNames = tLists("PeerNames")
        Set tSaveSC = tCredential.Save()
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSaveSC) {
            Set tCodes = $System.Status.GetErrorCodes(tSaveSC)
            Set tSaveSC = ""
            If ("," _ tCodes _ ",") [ ",5805," {
                Set pHttpStatus = 409
                Set tSC = $$$ERROR($$$GeneralError, "an X.509 credential already carries that alias")
                Quit
            }
            Set tMapped = ""
            For tI = 1:1:$Length(..#IMPORTSAVECODES, ",") {
                Set tPair = $Piece(..#IMPORTSAVECODES, ",", tI)
                If ("," _ tCodes _ ",") [ ("," _ $Piece(tPair, "=", 1) _ ",") Set tMapped = $Piece(tPair, "=", 2) Quit
            }
            If tMapped '= "" {
                Set pHttpStatus = 400
                Set tSC = $$$ERROR($$$GeneralError, "the import was refused: " _ tMapped)
            } Else {
                Set pHttpStatus = 500
                Set tSC = $$$ERROR($$$GeneralError, "%SYS.X509Credentials refused the save with vendor error " _ tCodes)
            }
            Quit
        }
        Set (tCert, tKey, tPassword, tBytes) = ""
        Kill tRead
        Set tRead("alias") = tAlias
        Set tReadSC = ..Invoke(pEndpoint, "GET", .tRead, "", .tFresh, .tReadHttp, .tReadFault)
        Set pAnswer = $Select($$$ISOK(tReadSC) && $IsObject($Get(tFresh)): tFresh, 1: {})
        Set pHttpStatus = 201
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCredential = ""
        Set pHttpStatus = 500
        Set tSC = $$$ERROR($$$GeneralError, "the X.509 import failed inside the port at " _ $Piece(ex.Location, "^", 1))
    }
    Set (tCert, tKey, tPassword, tBytes, tValue) = ""
    Set tCredential = ""
    If $$$ISERR(tSC) && (pHttpStatus = 0) Set pHttpStatus = 500
    Quit tSC
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>BODYLESSTYPES</parameter> exempts from the object-body refusal (AD-51, DW-1464).</p>
ClassMethod IsBodyless(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#BODYLESSTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>The wrapper key <parameter>WRAPPEDTYPES</parameter> declares for <var>pEndpoint</var>'s
/// request type <var>pSuffix</var>, or <code>""</code> for a type whose body is sent as it is.</p>
ClassMethod WrapperKey(pEndpoint As %String, pSuffix As %String) As %String
{
    Set tKey = ""
    Set tEntries = $ListFromString(..#WRAPPEDTYPES)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        If $Piece(tEntry, "=", 1) '= (pEndpoint _ "/" _ pSuffix) Continue
        Set tKey = $Piece($Piece(tEntry, "=", 2), ":", 1)
        Quit
    }
    Quit tKey
}

/// <p><var>pBody</var> in the vendor's wrapper shape for <var>pEndpoint</var>'s request type
/// <var>pSuffix</var>, or <var>pBody</var> itself where <parameter>WRAPPEDTYPES</parameter> declares
/// none. Every key except the declared outer keys moves under the wrapper key, each keeping its own
/// JSON type; an outer key <var>pBody</var> does not carry stays missing. <var>pBody</var> is not
/// modified.</p>
ClassMethod Wrapped(pEndpoint As %String, pSuffix As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tWrapper = ..WrapperKey(pEndpoint, pSuffix)
    If tWrapper = "" Quit pBody
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit pBody
    Set tOuter = ""
    Set tEntries = $ListFromString(..#WRAPPEDTYPES)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        If $Piece(tEntry, "=", 1) '= (pEndpoint _ "/" _ pSuffix) Continue
        Set tSpec = $Piece(tEntry, "=", 2)
        For tJ = 2:1:$Length(tSpec, ":") {
            If $Piece(tSpec, ":", tJ) '= "" Set tOuter = tOuter _ $ListBuild($Piece(tSpec, ":", tJ))
        }
        Quit
    }
    Set tOut = {}
    Set tInner = {}
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tType = pBody.%GetTypeOf(tKey)
        Set tTarget = $Select($ListFind(tOuter, tKey): tOut, 1: tInner)
        If (tType = "object") || (tType = "array") {
            Do tTarget.%Set(tKey, tValue)
        } Else {
            Do tTarget.%Set(tKey, tValue, tType)
        }
    }
    Do tOut.%Set(tWrapper, tInner)
    Quit tOut
}

/// <p>A copy of <var>pQuery</var> in <var>pSplit</var> with every key
/// <parameter>SPLITQUERIES</parameter> declares for <var>pEndpoint</var> replaced by its parts.
/// Answers 0 when such a key's value is not exactly one non-empty <code>/</code>-separated piece
/// per part, and 1 otherwise; <var>pQuery</var> is never modified.</p>
ClassMethod SplitQuery(pEndpoint As %String, ByRef pQuery, Output pSplit) As %Boolean
{
    Kill pSplit
    Merge pSplit = pQuery
    Set tWellFormed = 1
    For tI = 1:1:$Length(..#SPLITQUERIES, ",") {
        Set tEntry = $ZStrip($Piece(..#SPLITQUERIES, ",", tI), "<>W")
        If $Piece(tEntry, "/", 1) '= pEndpoint Continue
        Set tSpec = $Piece(tEntry, "/", 2, *)
        Set tKey = $Piece(tSpec, "=", 1)
        Set tParts = $Piece(tSpec, "=", 2, *)
        If (tKey = "") || (tParts = "") || '$Data(pSplit(tKey)) Continue
        Set tValue = pSplit(tKey)
        If $Length(tValue, "/") '= $Length(tParts, ":") {
            Set tWellFormed = 0
            Quit
        }
        For tJ = 1:1:$Length(tParts, ":") {
            If $Piece(tValue, "/", tJ) = "" Set tWellFormed = 0
        }
        If 'tWellFormed Quit
        Kill pSplit(tKey)
        For tJ = 1:1:$Length(tParts, ":") {
            Set pSplit($Piece(tParts, ":", tJ)) = $Piece(tValue, "/", tJ)
        }
    }
    Quit tWellFormed
}

/// <p>A new <class>%DynamicObject</class> holding the body <parameter>CONSTANTBODIES</parameter>
/// declares for <var>pEndpoint</var>/<var>pType</var>, or <code>""</code> for a pair it does not
/// name. Each call answers a fresh object, so nothing a caller does to it reaches the next call.</p>
ClassMethod ConstantBody(pEndpoint As %String, pType As %String) As %DynamicObject
{
    Set tBody = ""
    Try {
        Set tKey = pEndpoint _ "/" _ pType _ "="
        For tI = 1:1:$Length(..#CONSTANTBODIES, ";") {
            Set tEntry = $ZStrip($Piece(..#CONSTANTBODIES, ";", tI), "<>W")
            If $Extract(tEntry, 1, $Length(tKey)) '= tKey Continue
            Set tParsed = ##class(%DynamicAbstractObject).%FromJSON($Extract(tEntry, $Length(tKey) + 1, *))
            If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tBody = tParsed
            Quit
        }
    } Catch {
        Set tBody = ""
    }
    Quit tBody
}

/// <p><var>pBody</var> with every key <parameter>RENAMEDTYPES</parameter> declares for
/// <var>pEndpoint</var>'s request type <var>pSuffix</var> carried under the vendor's own name, each
/// keeping its JSON type; <var>pBody</var> itself where the type declares none. A copy is answered,
/// so <var>pBody</var> is never modified.</p>
ClassMethod Renamed(pEndpoint As %String, pSuffix As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tSpec = ""
    Set tEntries = $ListFromString(..#RENAMEDTYPES)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        If $Piece(tEntry, "=", 1) '= (pEndpoint _ "/" _ pSuffix) Continue
        Set tSpec = $Piece(tEntry, "=", 2)
        Quit
    }
    If tSpec = "" Quit pBody
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit pBody
    Kill tRename
    For tJ = 1:2:$Length(tSpec, ":") {
        Set tOurs = $Piece(tSpec, ":", tJ)
        Set tTheirs = $Piece(tSpec, ":", tJ + 1)
        If (tOurs '= "") && (tTheirs '= "") Set tRename(tOurs) = tTheirs
    }
    Set tOut = {}
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tType = pBody.%GetTypeOf(tKey)
        Set tName = $Get(tRename(tKey), tKey)
        If (tType = "object") || (tType = "array") {
            Do tOut.%Set(tName, tValue)
        } Else {
            Do tOut.%Set(tName, tValue, tType)
        }
    }
    Quit tOut
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>CONNECTIONTESTTYPES</parameter> admits, keyed by the pair as
/// <method>IsMutating</method> is.</p>
ClassMethod IsConnectionTest(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#CONNECTIONTESTTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>CONSOLETESTS</parameter> lists.</p>
ClassMethod IsConsoleTest(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#CONSOLETESTS), pEndpoint _ "/" _ pSuffix)
}

/// <p>The answer a <parameter>CONNECTIONTESTTYPES</parameter> call gives, from its sequence status
/// <var>pSeqSC</var>, its HTTP status <var>pHttp</var> and the vendor's answer <var>pAnswer</var>:
/// <code>{passed: true, lines}</code> at 200 from a 2xx, <code>{passed: false, lines}</code> at 200
/// from a vendor status error at 500 -- each error's text a line -- and otherwise the ordinary
/// fault <method>Fail</method> builds.</p>
/// <p>A <parameter>CONSOLETESTS</parameter> pair (<var>pEndpoint</var>'s request type
/// <var>pType</var>) answers <code>{lines}</code> instead, with no <code>passed</code>: the console
/// lines <var>pLines</var> (a <class>%DynamicArray</class>, or <code>""</code>) captured while its
/// <code>Run()</code> ran, followed, on a vendor status error at 500, by each error's text.</p>
/// <p><b>Nothing here logs the failure text or the lines</b>: they are the result the caller asked
/// for, and a line written to the log would hand it to the error log screen and its read tool
/// (AD-35, AD-39).</p>
ClassMethod TestOutcome(pEndpoint As %String, pType As %String, pSeqSC As %Status, pHttp As %Integer, pAnswer, pLines, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pFault = ""
    If ..IsConsoleTest(pEndpoint, pType) && (($$$ISOK(pSeqSC) && (pHttp >= 200) && (pHttp < 300)) || ($$$ISERR(pSeqSC) && (pHttp = 500))) {
        Set tLines = []
        If $IsObject(pLines) {
            Set tIterator = pLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If '$IsObject(tLine) Do tLines.%Push(tLine _ "", "string")
            }
        }
        If $$$ISERR(pSeqSC) {
            Do $System.Status.DecomposeStatus(pSeqSC, .tErrors)
            For tI = 1:1:+$Get(tErrors) {
                Do tLines.%Push($Get(tErrors(tI)), "string")
            }
            Kill tErrors
        }
        Set pResult = {}
        Do pResult.%Set("lines", tLines)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If $$$ISOK(pSeqSC) && (pHttp >= 200) && (pHttp < 300) {
        Set tLines = []
        If $IsObject(pAnswer) && (pAnswer.%GetTypeOf("Info") = "array") {
            Set tIterator = pAnswer.%Get("Info").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If '$IsObject(tLine) Do tLines.%Push(tLine _ "", "string")
            }
        }
        Set pResult = {"passed": true}
        Do pResult.%Set("lines", tLines)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If $$$ISERR(pSeqSC) && (pHttp = 500) {
        Set tLines = []
        Do $System.Status.DecomposeStatus(pSeqSC, .tErrors)
        For tI = 1:1:+$Get(tErrors) {
            Do tLines.%Push($Get(tErrors(tI)), "string")
        }
        Kill tErrors
        Set pResult = {"passed": false}
        Do pResult.%Set("lines", tLines)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..Fail(pEndpoint, pHttp, pSeqSC, .pHttpStatus, .pFault)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is one
/// <parameter>MUTATINGTYPES</parameter> admits (DW-1473). Every read of that parameter is this
/// method, so admitting a type on one endpoint can never be read as admitting it on another.</p>
ClassMethod IsMutating(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#MUTATINGTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> answered
/// <var>pHttpStatus</var> is a refusal <parameter>UNLOGGEDREFUSALS</parameter> lists.</p>
ClassMethod IsUnloggedRefusal(pEndpoint As %String, pSuffix As %String, pHttpStatus As %Integer) As %Boolean
{
    If pSuffix = "" Quit 0
    Quit ''$ListFind($ListFromString(..#UNLOGGEDREFUSALS), pEndpoint _ "/" _ pSuffix _ "/" _ (+pHttpStatus))
}

/// <p>The code <parameter>TYPEFAULTS</parameter> names for <var>pEndpoint</var>'s request type
/// <var>pSuffix</var>, or <code>""</code>.</p>
ClassMethod TypeFault(pEndpoint As %String, pSuffix As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:$Length(..#TYPEFAULTS, ",") {
        Set tEntry = $Piece(..#TYPEFAULTS, ",", tI)
        If $Piece(tEntry, "=", 1) = (pEndpoint _ "/" _ pSuffix) Set tCode = $Piece(tEntry, "=", 2)
    }
    Quit tCode
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is a
/// <parameter>QUEUEDWRITES</parameter> pair, which <method>Sequence</method> lets the vendor queue.</p>
ClassMethod IsQueuedWrite(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#QUEUEDWRITES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is a
/// <parameter>SELFQUEUEDTYPES</parameter> pair, whose own <code>Run()</code> queues a task.</p>
ClassMethod IsSelfQueued(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#SELFQUEUEDTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is a
/// <parameter>CONSOLEDTYPES</parameter> pair.</p>
ClassMethod IsConsoled(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    If pSuffix = "" Quit 0
    Quit ''$ListFind($ListFromString(..#CONSOLEDTYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>A <parameter>CONSOLEDTYPES</parameter> task's answer from its terminal poll answer
/// <var>pAnswer</var>: <code>{Result, console}</code>, and <code>failed</code> true when
/// <var>pFailed</var>. <code>console</code> holds the poll answer's <code>Console</code> lines as
/// strings, at most <parameter>CONSOLEMAXLINES</parameter>: a longer console keeps one fewer and ends
/// with U+2026.</p>
ClassMethod Consoled(pAnswer As %DynamicObject, pFailed As %Boolean = 0) As %DynamicObject
{
    Set tOut = {}
    If $IsObject(pAnswer) && $IsObject(pAnswer.%Get("Result")) {
        Do tOut.%Set("Result", pAnswer.%Get("Result"))
    } Else {
        Do tOut.%Set("Result", {})
    }
    Set tLines = []
    Set tMax = ..#CONSOLEMAXLINES
    If $IsObject(pAnswer) && (pAnswer.%GetTypeOf("Console") = "array") {
        Set tConsole = pAnswer.%Get("Console")
        Set tSize = tConsole.%Size()
        Set tIterator = tConsole.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            If (tSize > tMax) && (tLines.%Size() >= (tMax - 1)) {
                Do tLines.%Push($Char(8230), "string")
                Quit
            }
            Do tLines.%Push($Select($IsObject(tLine): "", 1: tLine _ ""), "string")
        }
    }
    Do tOut.%Set("console", tLines)
    If pFailed Do tOut.%Set("failed", 1, "boolean")
    Quit tOut
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is a
/// <parameter>JOURNALFILETYPES</parameter> pair.</p>
ClassMethod IsJournalFileType(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#JOURNALFILETYPES), pEndpoint _ "/" _ pSuffix)
}

/// <p>AD-21's eighth case for a <parameter>JOURNALFILETYPES</parameter> call (<var>pEndpoint</var>'s
/// request type <var>pType</var>): one <parameter>JOURNALLISTENDPOINT</parameter> <code>LIST</code>
/// with <code>maxRows</code> 0, read whole through this port at the call and never kept, and the
/// query <var>pQuery</var>'s <parameter>JOURNALFILEPARAM</parameter> accepted only when it equals,
/// character for character, a row's <code>Name</code>. A
/// <parameter>JOURNALNEWESTTYPES</parameter> call with an omitted or empty file is given the first,
/// newest, row's name. Any other name is refused 404 <code>JOURNAL.FILE.UNLISTED</code> without naming
/// it; a failed list read is its own fault. Nothing is sent for the target here.</p>
ClassMethod JournalGuard(pEndpoint As %String, pType As %String, ByRef pQuery, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFile = $Get(pQuery(..#JOURNALFILEPARAM))
    Kill tList
    Set tList("maxRows") = 0
    Set tSC = ..InvokeLocated(..#JOURNALLISTENDPOINT, "LIST", .tList, "", .tRows, .tHttp, .tFault, .tLocation)
    If $$$ISERR(tSC) {
        Set pHttpStatus = tHttp
        Set pFault = tFault
        Quit tSC
    }
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#JOURNALLISTENDPOINT _ " LIST answered something other than a list", $$$ERROR($$$GeneralError, "the journal file list is not an array"), pFault.code)
        Quit tSC
    }
    Set tNewest = ""
    Set tListed = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%GetTypeOf("Name") '= "string") Continue
        If tNewest = "" Set tNewest = tRow.%Get("Name")
        If (tFile '= "") && (tRow.%Get("Name") = tFile) {
            Set tListed = 1
            Quit
        }
    }
    If (tFile = "") && (tNewest '= "") && $ListFind($ListFromString(..#JOURNALNEWESTTYPES), pEndpoint _ "/" _ pType) {
        Set pQuery(..#JOURNALFILEPARAM) = tNewest
        Quit $$$OK
    }
    If tListed Quit $$$OK
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.JournalError).#FILEUNLISTED, ##class(OcuPilot.Api.JournalError).#REASONFILEUNLISTED, .pHttpStatus, .pFault)
}

/// <p>Whether <var>pEndpoint</var>'s request type <var>pSuffix</var> is a pair
/// <parameter>JOURNALMATCHTYPES</parameter>, <parameter>JOURNALOFFSETPARAMS</parameter> or
/// <parameter>HALVEDROWTYPES</parameter> names.</p>
ClassMethod IsJournalRecordType(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Set tPair = pEndpoint _ "/" _ pSuffix
    If $ListFind($ListFromString(..#JOURNALMATCHTYPES), tPair) Quit 1
    Quit (..PairValue(..#JOURNALOFFSETPARAMS, tPair) '= "") || (..PairValue(..#HALVEDROWTYPES, tPair) '= "")
}

/// <p>The value after <code>=</code> of the entry for <var>pPair</var> in the comma-separated
/// <code>&lt;pair&gt;=&lt;value&gt;</code> list <var>pList</var>, or <code>""</code>.</p>
ClassMethod PairValue(pList As %String, pPair As %String) As %String [ Private ]
{
    Set tValue = ""
    For tI = 1:1:$Length(pList, ",") {
        Set tEntry = $Piece(pList, ",", tI)
        If $Piece(tEntry, "=", 1) = pPair Set tValue = $Piece(tEntry, "=", 2, *)
    }
    Quit tValue
}

/// <p>Story 18.19's record rules for <var>pEndpoint</var>'s request type <var>pType</var>, applied to
/// the query copy <var>pQuery</var> (AD-21, AD-26). Each refusal is made before any vendor call, the
/// journal file guard's list read included, and none echoes the value:</p>
/// <ul>
/// <li>On a <parameter>JOURNALMATCHTYPES</parameter> pair, a non-empty <code>matchColumnName</code>
/// outside <parameter>JOURNALMATCHCOLUMNS</parameter>, a non-empty <code>matchOperator</code> outside
/// <parameter>JOURNALMATCHOPERATORS</parameter>, or a non-empty <code>matchValue</code> with an empty
/// column or comparison, is refused 400 <code>JOURNAL.FILTER.SHAPE</code>. An empty
/// <code>matchValue</code> removes all three keys, so the list is sent unfiltered.</li>
/// <li>The <parameter>JOURNALOFFSETPARAMS</parameter> parameter must match
/// <code>^[0-9]{1,20}$</code>, else 400 <code>JOURNAL.OFFSET.SHAPE</code>; the list's empty offset is
/// removed, the record's empty or absent address is refused.</li>
/// <li>On a <parameter>HALVEDROWTYPES</parameter> pair, a <code>maxRows</code> of digits is multiplied
/// by its factor; an absent one keeps the vendor's own default.</li>
/// </ul>
ClassMethod JournalRecordRules(pEndpoint As %String, pType As %String, ByRef pQuery, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    If $ListFind($ListFromString(..#JOURNALMATCHTYPES), tPair) {
        Set tColumnParam = $Piece(..#JOURNALMATCHPARAMS, ",", 1)
        Set tOperatorParam = $Piece(..#JOURNALMATCHPARAMS, ",", 2)
        Set tValueParam = $Piece(..#JOURNALMATCHPARAMS, ",", 3)
        Set tColumn = $Get(pQuery(tColumnParam))
        Set tOperator = $Get(pQuery(tOperatorParam))
        Set tValue = $Get(pQuery(tValueParam))
        Set tShape = 1
        If (tColumn '= "") && '$ListFind($ListFromString(..#JOURNALMATCHCOLUMNS), tColumn) Set tShape = 0
        If (tOperator '= "") && '$ListFind($ListFromString(..#JOURNALMATCHOPERATORS), tOperator) Set tShape = 0
        If (tValue '= "") && ((tColumn = "") || (tOperator = "")) Set tShape = 0
        If 'tShape Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.JournalError).#FILTERSHAPE, ##class(OcuPilot.Api.JournalError).#REASONFILTERSHAPE, .pHttpStatus, .pFault)
        If tValue = "" Kill pQuery(tColumnParam), pQuery(tOperatorParam), pQuery(tValueParam)
    }
    Set tOffsetParam = ..PairValue(..#JOURNALOFFSETPARAMS, tPair)
    If tOffsetParam '= "" {
        Set tOffset = $Get(pQuery(tOffsetParam))
        If (tOffset = "") && (pType = "LIST") {
            Kill pQuery(tOffsetParam)
        } ElseIf '$Match(tOffset, "^[0-9]{1,20}$") {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.JournalError).#OFFSETSHAPE, ##class(OcuPilot.Api.JournalError).#REASONOFFSETSHAPE, .pHttpStatus, .pFault)
        }
    }
    Set tFactor = ..PairValue(..#HALVEDROWTYPES, tPair)
    If (tFactor > 1) && $Match($Get(pQuery("maxRows")), "^[0-9]{1,9}$") Set pQuery("maxRows") = pQuery("maxRows") * tFactor
    Quit $$$OK
}

/// <p>The HTTP method the request stub carries for <var>pEndpoint</var>'s request type
/// <var>pSuffix</var>: the suffix itself for a <parameter>MUTATINGTYPES</parameter> pair,
/// <code>GET</code> for everything else.</p>
/// <p>The vendor's endpoints read their own <code>Type</code> property rather than
/// <code>%request.Method</code>, so nothing dispatches on this; it is set truthfully so the stub
/// does not describe a read while a write runs against it. For <code>RESUME</code> the value the
/// stub carries is that request-type suffix and not an HTTP verb, because the vendor exposes the
/// operation as a request type alone; <method>Sequence</method>'s async refusal reads it as a
/// <parameter>MUTATINGTYPES</parameter> member either way.</p>
ClassMethod HttpMethodFor(pEndpoint As %String, pSuffix As %String) As %String [ Private ]
{
    If ..IsMutating(pEndpoint, pSuffix) Quit pSuffix
    Quit "GET"
}

/// <p>The vendor type number for suffix <var>pSuffix</var> on <var>pEndpoint</var>'s class
/// <var>pClass</var>, or <code>""</code> when the class declares no such parameter or
/// <method>ImplementsRead</method> says the class does not implement that read. A suffix
/// <parameter>BARETYPES</parameter> lists for <var>pEndpoint</var> resolves through the bare
/// parameter of that name; any other suffix must be in <parameter>TYPESUFFIXES</parameter> or form
/// a <parameter>MUTATINGTYPES</parameter> or <parameter>CONNECTIONTESTTYPES</parameter> pair, and
/// resolves through <code>TYPE&lt;suffix&gt;</code>.</p>
/// <p>A <parameter>CONNECTIONREADTYPES</parameter> pair resolves through <code>TYPE&lt;suffix&gt;</code>
/// too, on its own endpoint alone.</p>
ClassMethod EndpointType(pEndpoint As %String, pClass As %String, pSuffix As %String) As %String [ Private ]
{
    If '$Match(pSuffix, "^[A-Z]+$") Quit ""
    If $ListFind($ListFromString(..#BARETYPES), pEndpoint _ "/" _ pSuffix) {
        Set tBare = $Parameter(pClass, pSuffix)
        If (tBare = "") || '..ImplementsRead(pClass, pSuffix) Quit ""
        Quit tBare
    }
    ; CONNECTIONREADTYPES: a pair-keyed read, admitted on its own endpoint alone.
    If ..IsConnectionRead(pEndpoint, pSuffix) {
        Set tType = $Parameter(pClass, "TYPE" _ pSuffix)
        If (tType = "") || '..ImplementsRead(pClass, pSuffix) Quit ""
        Quit tType
    }
    If '$ListFind($ListFromString(..#TYPESUFFIXES), pSuffix) && '..IsMutating(pEndpoint, pSuffix) && '..IsConnectionTest(pEndpoint, pSuffix) Quit ""
    Set tType = $Parameter(pClass, "TYPE" _ pSuffix)
    If tType = "" Quit ""
    If '..ImplementsRead(pClass, pSuffix) Quit ""
    Quit tType
}

/// <p>Whether <var>pClass</var> implements the operation <var>pSuffix</var> names. The base class's
/// <code>Run()</code> sends <code>GET</code> to <code>RunGet</code>, <code>LIST</code> to
/// <code>RunList</code> and <code>PUT</code> to <code>RunPut</code>, answers <code>{}</code> for
/// any other type, and every one of those runners answers <code>{}</code>; so an operation is
/// implemented when <code>Run</code>, or the runner for that suffix, is defined below
/// <parameter>ENDPOINTBASECLASS</parameter>. A class that overrides <code>Run</code> is trusted to
/// dispatch its own types.</p>
/// <p>The base <code>Run()</code> also sends <code>DELETE</code> to <code>RunDelete</code> (read on
/// this build), which joined here with Story 7.1, the first tool that issues one through this port;
/// without it every such call read as an operation the instance does not implement, at 501.</p>
ClassMethod ImplementsRead(pClass As %String, pSuffix As %String) As %Boolean [ Private ]
{
    If ..MethodOrigin(pClass, "Run") '= ..#ENDPOINTBASECLASS Quit 1
    Set tRunner = $Case(pSuffix, "GET": "RunGet", "LIST": "RunList", "PUT": "RunPut", : "")
    If pSuffix = "DELETE" Set tRunner = "RunDelete"
    If pSuffix = "POST" Set tRunner = "RunPost"
    If pSuffix = "DELETE" Set tRunner = "RunDelete"
    If tRunner = "" Quit 0
    Quit ..MethodOrigin(pClass, tRunner) '= ..#ENDPOINTBASECLASS
}

/// <p>The class that defines <var>pClass</var>'s compiled method <var>pMethod</var>, or
/// <code>""</code> when it has none.</p>
ClassMethod MethodOrigin(pClass As %String, pMethod As %String) As %String [ Private ]
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(pClass, pMethod, 0)
    If '$IsObject(tMethod) Quit ""
    Quit tMethod.Origin
}

/// <p>Construct the endpoint behind fresh stubs and run <method>Sequence</method> in
/// <code>%SYS</code>. <var>pHttpStatus</var> is the stub response's numeric status, raised to
/// 500 when the returned status is an error under no status or any 2xx (<code>Main()</code>
/// raises it under 200, 201 and 202);
/// <var>pLocation</var> is its <code>Location</code> header.</p>
/// <p><var>pConnectionTest</var> is 1 for a <parameter>CONNECTIONTESTTYPES</parameter> pair, which
/// <method>Sequence</method> never queues; <var>pLines</var> is then the console output its
/// <code>Run()</code> wrote, as a <class>%DynamicArray</class>, and otherwise <code>""</code>.</p>
/// <p>The endpoint is constructed before the switch, in the caller's namespace, because a
/// class compiled only there cannot be constructed from <code>%SYS</code>; the vendor's
/// <code>%OnNew</code> records the type and version and nothing else.</p>
ClassMethod RunSequence(pEndpoint As %String, pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicAbstractObject, Output pAnswer, Output pHttpStatus As %Integer, Output pLocation As %String, pMethod As %String = "GET", pConnectionTest As %Boolean = 0, Output pLines) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pLocation = ""
    Set pLines = ""
    ; AD-27's named fallback: a value the admin API refuses and the vendor class accepts.
    If ..ClassCompletedField(pEndpoint, pMethod, pBody) '= "" Quit ..CompleteThroughClass(pClass, pType, .pQuery, pBody, .pAnswer, .pHttpStatus)
    ; AD-27's second case: an import completed from content rather than from server file paths.
    If ..IsContentCompleted(pEndpoint, pMethod) Quit ..ImportThroughClass(pEndpoint, pClass, pType, .pQuery, pBody, .pAnswer, .pHttpStatus)
    New %request, %response, %session
    Set tOrigNS = $NAMESPACE
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = pMethod
        Set %request.URL = ..#STUBURLPREFIX _ $ZConvert($Translate(pEndpoint, ".", "/"), "L")
        Set tName = $Order(pQuery(""))
        While tName '= "" {
            Set %request.Data(tName, 1) = pQuery(tName)
            Set tName = $Order(pQuery(tName))
        }
        Set %response = ##class(%CSP.Response).%New()
        Set %session = {"Username": ($USERNAME)}
        Set tBody = $Select($IsObject(pBody): pBody, 1: {})

        Set tEndpoint = $ClassMethod(pClass, "%New", pType, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set tSC = $Get(%objlasterror, $$$ERROR($$$GeneralError, "endpoint did not construct"))
            Quit
        }
        Set tEndpoint.IsRunningAsync = 0

        Set $NAMESPACE = "%SYS"
        Set tSC = ..Sequence(pEndpoint, tEndpoint, tBody, .pAnswer, pConnectionTest, .pLines)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $IsObject($Get(%response)) {
        Set pHttpStatus = +%response.Status
        Set pLocation = %response.GetHeader("Location")
    }
    If $$$ISERR(tSC) && ((pHttpStatus = 0) || ((pHttpStatus >= 200) && (pHttpStatus < 300))) {
        Set pHttpStatus = 500
    }
    Quit tSC
}

/// <p><code>Main()</code>'s steps after construction, in its order, against stubs already in
/// place. Runs in <code>%SYS</code>.</p>
/// <p><var>pName</var> is the endpoint's name and <var>pEndpoint</var> its constructed object. The
/// name is here for the async refusal alone, which asks <method>IsMutating</method> the same
/// <code>(endpoint, type)</code> question the admission gate asked (DW-1473).</p>
/// <p><var>pConnectionTest</var> 1 runs <code>Run()</code> in process whatever
/// <code>ShouldRunAsync()</code> answers, so a test's body never reaches the vendor's task row
/// (AD-26, AD-35), and answers the console output <code>Run()</code> wrote in <var>pLines</var>, a
/// <class>%DynamicArray</class>; for any other call <var>pLines</var> is <code>""</code>.</p>
ClassMethod Sequence(pName As %String, pEndpoint As %RegisteredObject, pBody As %DynamicAbstractObject, Output pAnswer, pConnectionTest As %Boolean = 0, Output pLines) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pLines = ""
    Try {
        Set tAllowed = 0
        Set tResources = pEndpoint.ResourcesOR()
        For tI = 1:1:$ListLength(tResources) {
            Set tAllowed = tAllowed || ..HoldsResource($ListGet(tResources, tI))
        }
        If 'tAllowed {
            Set %response.Status = ..#HTTPFORBIDDEN
            Quit
        }

        Do pEndpoint.SaveQueryParams()
        Try {
            Do pEndpoint.ValidateQueryParams()
        } Catch exQuery {
            Set %response.Status = ..#HTTPBADREQUEST
            Set tSC = exQuery.AsStatus()
        }
        If $$$ISERR(tSC) Quit

        Set tSC = pEndpoint.ValidateRequest(pBody)
        If $$$ISERR(tSC) {
            Set %response.Status = ..#HTTPBADREQUEST
            Quit
        }
        ; AD-26 as amended 2026-09-29: a type whose own Run() queues a task is refused on the same
        ; terms as one ShouldRunAsync() would queue, before the endpoint's semantics or Run() is
        ; reached, unless its pair is a QUEUEDWRITES entry. %request.Method carries the request-type
        ; suffix for a mutating call (HttpMethodFor).
        Set tMethod = %request.Method
        If ..IsSelfQueued(pName, tMethod) && ..IsMutating(pName, tMethod) && '..IsQueuedWrite(pName, tMethod) {
            Set tSC = $$$ERROR($$$GeneralError, "the admin API would queue this " _ tMethod _ " request in its own Run(), and a mutating request's body is never written to the vendor's task row (AD-35)")
            Quit
        }
        Try {
            Set tSC = pEndpoint.ValidateSemantics()
        } Catch exSemantics {
            Set tSC = exSemantics.AsStatus()
        }
        If $$$ISERR(tSC) Quit

        ; AD-26 (Story 16.14): a connection test runs in process and is never queued, because its
        ; body can carry a password the vendor's queue would write into its task row and the journal.
        If 'pConnectionTest && pEndpoint.ShouldRunAsync() {
            ; AD-35, DW-1279: a mutating request's body can carry a supplied secret, and
            ; SaveRequestBody writes it into the vendor's own task row
            ; (^|"^^:ds:IRISLOCALDATA"|Api.Admin.Util.AsyncTaskD), which is a surface OcuPilot
            ; neither owns nor purges. So a mutating request is refused here -- before the row is
            ; written, because a secret written there cannot be taken back -- unless its pair is a
            ; QUEUEDWRITES entry, whose body carries none (AD-26).
            ; The endpoint name is threaded in rather than re-derived, so this asks the same
            ; (endpoint, type) question the admission gate asked. %request.Method carries the
            ; request-type suffix for a mutating call (HttpMethodFor) and GET otherwise.
            Set tMethod = %request.Method
            If ..IsMutating(pName, tMethod) && '..IsQueuedWrite(pName, tMethod) {
                Set tSC = $$$ERROR($$$GeneralError, "the admin API would queue this " _ tMethod _ " request, and a mutating request's body is never written to the vendor's task row (AD-35)")
                Quit
            }
            Set tTask = $ClassMethod(..#ASYNCTASKENDPOINTCLASS, "%New", %request, pEndpoint)
            Set tSC = $$$ADDSC(tSC, tTask.SaveRequestBody(pBody))
            Set tSC = $$$ADDSC(tSC, tTask.AddToAsyncQueue())
            ; Drop the task before anything polls it: while an OREF to the row survives, the
            ; poll's %OpenId returns this in-memory copy, which stays Queued.
            Set tTask = ""
            Quit
        }

        Do ..OnBeforeRun(pEndpoint)
        Try {
            Set tSC = $ClassMethod(..#CAPTURECLASS, "BeginCaptureOutput", .tCookie)
            If $$$ISERR(tSC) Quit
            Set pAnswer = pEndpoint.Run(.tSC, pBody)
        } Catch exRun {
            Set tSC = exRun.AsStatus()
            If exRun.%IsA("%Exception.SystemException") && (exRun.Name = "<PROTECT>") {
                Set %response.Status = ..#HTTPFORBIDDEN
            }
        }
        If $Data(tCookie) Do $ClassMethod(..#CAPTURECLASS, "EndCaptureOutput", tCookie, .tLines)
        If pConnectionTest && $IsObject($Get(tLines)) Set pLines = tLines
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Poll task <var>pGuid</var> until it is terminal or <method>AsyncTimeout</method> passes.
/// <code>Finished</code> is a 200 success carrying the task's <code>Result</code>;
/// <code>Failed</code> is a 500 whose fault is built from <code>FailureReason</code>; both hand the
/// row to <method>ForgetTask</method>, which leaves a row the caller cannot delete for
/// <method>SweepOwnTasks</method>. No terminal state
/// within the bound is <code>PORT.TIMEOUT</code>, and the row is left to the worker that still
/// owns it.</p>
/// <p>For a <parameter>CONSOLEDTYPES</parameter> pair (<var>pEndpoint</var>'s request type
/// <var>pType</var>) the answer is <method>Consoled</method>'s.</p>
ClassMethod AwaitTask(pEndpoint As %String, pGuid As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pType As %String = "") As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set tFinished = $Parameter(..#ASYNCTASKCLASS, "STATEFINISHED")
    Set tFailed = $Parameter(..#ASYNCTASKCLASS, "STATEFAILED")
    Set tBound = ..AsyncTimeout()
    Set tStart = $ZHorolog
    For {
        Set tAnswer = ""
        Set tPollHttp = 0
        Set tPollSC = ..PollTask(pGuid, .tAnswer, .tPollHttp)
        If $$$ISERR(tPollSC) || (tPollHttp < 200) || (tPollHttp >= 300) || '$IsObject(tAnswer) {
            Set tSC = ..Fail(pEndpoint _ " task " _ pGuid, $Select((tPollHttp < 200) || (tPollHttp >= 300): tPollHttp, 1: 500), tPollSC, .pHttpStatus, .pFault)
            Quit
        }
        If tAnswer.State = tFinished {
            Do ..ForgetTask(pGuid)
            Set pResult = tAnswer.Result
            If ..IsConsoled(pEndpoint, pType) Set pResult = ..Consoled(tAnswer, 0)
            Set pHttpStatus = 200
            Quit
        }
        ; CONSOLEDTYPES: a failed task that wrote console lines has run and reported its findings.
        If (tAnswer.State = tFailed) && ..IsConsoled(pEndpoint, pType) && (tAnswer.%GetTypeOf("Console") = "array") && (tAnswer.%Get("Console").%Size() > 0) {
            Do ..ForgetTask(pGuid)
            Set pResult = ..Consoled(tAnswer, 1)
            Set pHttpStatus = 200
            Quit
        }
        If tAnswer.State = tFailed {
            Do ..ForgetTask(pGuid)
            Set tSC = ..Fail(pEndpoint, 500, $$$ERROR($$$GeneralError, tAnswer.FailureReason), .pHttpStatus, .pFault)
            Quit
        }
        If ($ZHorolog - tStart) >= tBound {
            Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTTIMEOUT, "The instance did not finish that operation in time", .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " task " _ pGuid _ " left " _ tAnswer.State _ " at the bound", tSC, pFault.code)
            Quit
        }
        Hang ..#POLLINTERVAL
    }
    Quit tSC
}

/// <p>A failed vendor outcome: the fault from <method>OcuPilot.Kernel.Fault.Outcome</method>,
/// the vendor status to the log, and an error status carrying only the fault's own text.
/// <var>pWrapper</var> is the request's <parameter>WRAPPEDTYPES</parameter> wrapper key, or
/// <code>""</code>; a violation field that begins with it and a dot loses that segment.
/// <var>pBody</var> is the body the request sent, whose secrets the logged status never carries
/// (<method>LoggedStatus</method>).</p>
/// <p><var>pRead</var> is 1 when the request was a read. A read answered 404 has found an absence,
/// which is its answer and not a fault: its vendor status is not logged, so a delete's re-read or an
/// existence check never writes an error line that raises the instance's alert state (AD-2). Every
/// other 404, a write's included, is logged as any failure is.</p>
/// <p><var>pType</var> is the request type, where the caller knows it: a refusal
/// <parameter>UNLOGGEDREFUSALS</parameter> lists for that type and status is not logged either.</p>
ClassMethod Fail(pEndpoint As %String, pHttp As %Integer, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pWrapper As %String = "", pBody As %DynamicAbstractObject = "", pRead As %Boolean = 0, pType As %String = "") As %Status [ Private ]
{
    Set pHttpStatus = $Select(+pHttp: +pHttp, 1: 500)
    Set tOutcomeSC = ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, pVendorSC, .pFault, .tDetail)
    If $$$ISERR(tOutcomeSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tOutcomeSC, pFault.code)
    ; AD-39. A vendor refusal that names a body field crosses the boundary as detail.violations --
    ; the field the vendor named, OcuPilot's stable code for that kind of refusal, and OcuPilot's
    ; own sentence -- so a screen renders it on the field it is about and a tool result renders the
    ; code. The vendor's own text still reaches the log alone, on the line below.
    Set tViolations = ##class(OcuPilot.Api.Error).ViolationsFromVendor(pVendorSC)
    Do ..PropertyViolations(pEndpoint, pVendorSC, tViolations)
    If (pWrapper '= "") && $IsObject(tViolations) {
        Set tRowIterator = tViolations.%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tField = tRow.%Get("field")
            If $Extract(tField, 1, $Length(pWrapper) + 1) = (pWrapper _ ".") Do tRow.%Set("field", $Extract(tField, $Length(pWrapper) + 2, *), "string")
        }
    }
    If $IsObject(pFault) && $IsObject(tViolations) && (tViolations.%Size() > 0) {
        Set tFieldDetail = {}
        Do tFieldDetail.%Set("violations", tViolations)
        Do pFault.%Set("detail", tFieldDetail)
    }
    If $$$ISERR(pVendorSC) && '(pRead && (pHttpStatus = 404)) && '..IsUnloggedRefusal(pEndpoint, pType, pHttpStatus) Do ..LogFault(pEndpoint _ " failed with HTTP " _ pHttpStatus, ..LoggedStatus(pVendorSC, pBody), pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><var>pStatus</var> as the log may carry it (AD-35): every non-empty string <var>pBody</var>
/// holds under a credential name (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), at
/// any depth, replaced by the log's own mask, because a vendor refusal can quote a value it was
/// sent -- a private key password over its <code>MAXLEN</code> is quoted by errors 7201 and 5802.
/// A status quoting none is answered unchanged; one that cannot be screened is replaced by a
/// sentence carrying no vendor text.</p>
ClassMethod LoggedStatus(pStatus As %Status, pBody As %DynamicAbstractObject = "") As %Status [ Private ]
{
    Set tLogged = pStatus
    Try {
        If $$$ISOK(pStatus) || '$IsObject(pBody) Quit
        Set tSecrets = ..SecretValues(pBody)
        If tSecrets = "" Quit
        Set tText = $System.Status.GetErrorText(pStatus)
        Set tMasked = tText
        For tI = 1:1:$ListLength(tSecrets) Set tMasked = $Replace(tMasked, $List(tSecrets, tI), $Parameter("OcuPilot.Kernel.Audit.Log", "REDACTED"))
        If tMasked '= tText Set tLogged = $$$ERROR($$$GeneralError, tMasked)
    } Catch {
        Set tLogged = $$$ERROR($$$GeneralError, "the vendor's status could not be screened for the secrets its request sent, so its text is not logged")
    }
    Quit tLogged
}

/// <p>Every non-empty string <var>pData</var> holds under a credential name, at any depth, as a
/// list.</p>
ClassMethod SecretValues(pData As %DynamicAbstractObject) As %List [ Private ]
{
    Set tValues = ""
    Set tInArray = ($ClassName(pData) = "%Library.DynamicArray")
    Set tIterator = pData.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $IsObject(tValue) {
            Set tValues = tValues _ ..SecretValues(tValue)
        } ElseIf 'tInArray && (pData.%GetTypeOf(tKey) = "string") && (tValue '= "") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tKey) {
            Set tValues = tValues _ $ListBuild(tValue)
        }
    }
    Quit tValues
}

/// <p>A refusal the port decided itself, with no vendor status behind it. <var>pDetail</var>,
/// when supplied, becomes the fault's <code>detail</code> (AD-39) -- the same shape
/// <class>OcuPilot.Port.LogSourcePort</class>'s own <code>Refuse</code> carries.</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The 403 a refused <b>backing query</b> answers with: <code>PORT.ACCESSDENIED</code> on the
/// <code>forbidden</code> slug, with <var>pFailedPair</var> as the envelope's
/// <code>detail.failedPair</code> (AD-8, AD-39). The vendor status goes to the log alone, as on
/// every other failure path here.</p>
/// <p>The slug, the code and the sentence are <class>OcuPilot.Kernel.Fault</class>'s own, read
/// from its mapping of HTTP 403 rather than written a second time here -- which is what keeps one
/// code from being worded two ways.</p>
ClassMethod Denied(pEndpoint As %String, pFailedPair As %String, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pBody As %DynamicAbstractObject = "") As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair)
    Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(403, pVendorSC, .tMapped, .tVendorText)
    If $$$ISERR(tMapSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tMapSC)
    Set tSC = ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
    Do ..LogFault(pEndpoint _ "'s backing query refused a caller holding no pair of the set naming " _ pFailedPair, ..LoggedStatus(pVendorSC, pBody), pFault.code)
    Quit tSC
}

/// <p>The vendor class errors that name one property of the object an endpoint saves, as
/// comma-separated <code>&lt;endpoint&gt;:&lt;vendor code&gt;:&lt;property&gt;=&lt;violation code&gt;</code>
/// entries (AD-39). Such an error's first parameter is <code>&lt;object&gt;.&lt;property&gt;</code>,
/// which <method>OcuPilot.Api.Error.ViolationsFromVendor</method> does not read as a body field.</p>
/// <p><code>Device.Standard:644:OpenParameters</code>: <code>Config.Devices</code> parses a device's
/// open parameters when it saves one and refuses what it cannot parse with error 644, which the
/// endpoint answers at 500 (read on this build).</p>
/// <p><b>An entry whose property is written <code>@&lt;field&gt;</code> names its field outright</b>
/// and matches the vendor code alone, for an error whose parameter is not a property: the three
/// <code>Security.SSLConfig</code> entries (Story 9.5, measured on <code>ocupilot-ci</code>). Error
/// 726 carries no parameter; 746's names the unknown cipher suite; 732's names the private key
/// file's path, which is logged and never carried.</p>
/// <p>The <code>Task.CRUD</code> entries (Story 9.7) are the task save's own refusals, each an
/// <code>@</code> entry because the vendor names no property: 7402, 7405 and 7406 on
/// <code>RunAsUser</code>, 7404 on <code>DailyIncrement</code>, 7408 on <code>DailyEndTime</code>,
/// 7409 on <code>EndDate</code>, 7410, 7426 and 7428 on <code>TimePeriodDay</code>, 7411 and 7412 on
/// <code>OutputFilename</code>, 7413, 7414, 7433 and 7434 on <code>TaskClass</code>, 7427 and 7429 on
/// <code>TimePeriodEvery</code>, 7430 on <code>DailyFrequencyTime</code>, 7431 on
/// <code>RunAfterGUID</code> and 7432 on <code>StartDate</code>.</p>
/// <p>The <code>Security.OAuth2.ServerClients</code> entries (Story 12.8) are the client save's own
/// refusals: 8863 on <code>Metadata.grant_types</code>, a grant type the authorization server does not
/// support; 8886 on <code>ClientCredentials</code>, a credential the instance does not hold; and 8864,
/// no authorization server configuration, which names no field
/// (<class>OcuPilot.Port.OAuthRegisteredClientPort</class> answers it as a refusal of its own).</p>
/// <p>The two <code>Namespace.Namespace</code> entries (Story 18.2) are the name's refusals,
/// neither naming a property: 457, a name <class>Config.Namespaces</class> does not accept, and
/// 7201, one longer than it stores (measured on <code>ocupilot-b-ci</code>).</p>
/// <p>The <code>Namespace.{Global,Routine,Package}Mappings</code> entries (Story 18.14) are the
/// mapping name's refusals, none naming a property: 5854 and 448 for each kind, the name refusals
/// Story 18.2's plan measured; and, measured on <code>ocupilot-b-ci</code> on 2026-09-28, 5854
/// (an invalid global reference), 655 (an unclosed subscript) and 217 (a global name too long) for a
/// global, 5028 (an invalid routine name) for a routine, and 5084 (an invalid package name) for a
/// package; and, for a global, 451, a base mapping deleted while a subscript-level mapping of the
/// same global exists, which the vendor refuses with nothing changed (measured there too).</p>
/// <p>The three <code>Database.SysCRUD</code> entries (Story 18.3), measured on
/// <code>ocupilot-b-ci</code>: 896, a resource name that does not begin with <code>%DB_</code>, on
/// <code>ResourceName</code>; and 60 (a mounted database) and 78 (a dismounted one), a
/// <code>POST</code> on a directory that already holds an <code>IRIS.DAT</code>, on the create's
/// <code>path</code>, which the vendor refuses with the file intact. Story 18.4 adds two, measured on
/// <code>ocupilot-b-ci</code>, 2026-09-29 (DW-1791): a <code>PUT</code> whose
/// <code>NewVolumeDirectory</code> is another database's directory is refused 576, and one that is
/// another database's volume directory 575, each at 500 with nothing changed, on the file edit's
/// <code>volumePath</code>.</p>
Parameter PROPERTYFAULTS = "Device.Standard:644:OpenParameters=DEVICE.OPENPARAMETERS.SHAPE,Security.SSLConfig:726:@CipherList=SSL.CIPHERLIST.EXPANDSEMPTY,Security.SSLConfig:746:@Ciphersuites=SSL.CIPHERSUITES.UNKNOWN,Security.SSLConfig:732:@PrivateKeyPassword=SSL.PRIVATEKEYPASSWORD.WRONG,Task.CRUD:7402:@RunAsUser=TASK.RUNASUSER.REFUSED,Task.CRUD:7405:@RunAsUser=TASK.RUNASUSER.REFUSED,Task.CRUD:7406:@RunAsUser=TASK.RUNASUSER.REFUSED,Task.CRUD:7404:@DailyIncrement=TASK.DAILYINCREMENT.REFUSED,Task.CRUD:7408:@DailyEndTime=TASK.DAILYENDTIME.REFUSED,Task.CRUD:7409:@EndDate=TASK.ENDDATE.REFUSED,Task.CRUD:7410:@TimePeriodDay=TASK.TIMEPERIODDAY.REFUSED,Task.CRUD:7426:@TimePeriodDay=TASK.TIMEPERIODDAY.REFUSED,Task.CRUD:7428:@TimePeriodDay=TASK.TIMEPERIODDAY.REFUSED,Task.CRUD:7411:@OutputFilename=TASK.OUTPUTFILENAME.REFUSED,Task.CRUD:7412:@OutputFilename=TASK.OUTPUTFILENAME.REFUSED,Task.CRUD:7413:@TaskClass=TASK.TASKCLASS.REFUSED,Task.CRUD:7414:@TaskClass=TASK.TASKCLASS.REFUSED,Task.CRUD:7433:@TaskClass=TASK.TASKCLASS.REFUSED,Task.CRUD:7434:@TaskClass=TASK.TASKCLASS.REFUSED,Task.CRUD:7427:@TimePeriodEvery=TASK.TIMEPERIODEVERY.REFUSED,Task.CRUD:7429:@TimePeriodEvery=TASK.TIMEPERIODEVERY.REFUSED,Task.CRUD:7430:@DailyFrequencyTime=TASK.DAILYFREQUENCYTIME.REFUSED,Task.CRUD:7431:@RunAfterGUID=TASK.RUNAFTERGUID.REFUSED,Task.CRUD:7432:@StartDate=TASK.STARTDATE.REFUSED,Security.OAuth2.ServerClients:8863:@Metadata.grant_types=OAUTH.CLIENTGRANTTYPES.UNSUPPORTED,Security.OAuth2.ServerClients:8886:@ClientCredentials=OAUTH.SERVERCLIENTCREDENTIALS.ABSENT,Security.OAuth2.ServerClients:8864:@=OAUTH.SERVERCLIENTCONFIG.ABSENT,Namespace.Namespace:457:@Name=NAMESPACE.NAME.SHAPE,Namespace.Namespace:7201:@Name=NAMESPACE.NAME.SHAPE,Namespace.GlobalMappings:5854:@Name=MAPPING.NAME.SHAPE,Namespace.GlobalMappings:448:@Name=MAPPING.NAME.SHAPE,Namespace.RoutineMappings:5854:@Name=MAPPING.NAME.SHAPE,Namespace.RoutineMappings:448:@Name=MAPPING.NAME.SHAPE,Namespace.PackageMappings:5854:@Name=MAPPING.NAME.SHAPE,Namespace.PackageMappings:448:@Name=MAPPING.NAME.SHAPE,Namespace.GlobalMappings:655:@Name=MAPPING.NAME.SHAPE,Namespace.GlobalMappings:217:@Name=MAPPING.NAME.SHAPE,Namespace.RoutineMappings:5028:@Name=MAPPING.NAME.SHAPE,Namespace.PackageMappings:5084:@Name=MAPPING.NAME.SHAPE,Namespace.GlobalMappings:451:@Name=MAPPING.NAME.SUBSCRIPTS,Database.SysCRUD:896:@ResourceName=DATABASE.RESOURCE.SHAPE,Database.SysCRUD:60:@path=DATABASE.DIRECTORY.INUSE,Database.SysCRUD:78:@path=DATABASE.DIRECTORY.INUSE,Database.SysCRUD:575:@volumePath=DATABASE.DIRECTORY.INUSE,Database.SysCRUD:576:@volumePath=DATABASE.DIRECTORY.INUSE";

/// <p>Append to <var>pRows</var> one <code>{field, code, reason}</code> row per error in
/// <var>pVendorSC</var> that <parameter>PROPERTYFAULTS</parameter> names for <var>pEndpoint</var>. The
/// vendor's own text is not carried; the sentence is OcuPilot's.</p>
ClassMethod PropertyViolations(pEndpoint As %String, pVendorSC As %Status, pRows As %DynamicArray) [ Private ]
{
    Try {
        If $$$ISOK(pVendorSC) || '$IsObject(pRows) Quit
        Do $System.Status.DecomposeStatus(pVendorSC, .tErrors, "-d")
        For tI = 1:1:+$Get(tErrors) {
            Set tParam = $Get(tErrors(tI, "param", 1))
            Set tProperty = $Piece(tParam, ".", $Length(tParam, "."))
            For tJ = 1:1:$Length(..#PROPERTYFAULTS, ",") {
                Set tEntry = $Piece(..#PROPERTYFAULTS, ",", tJ)
                Set tKey = $Piece(tEntry, "=", 1)
                If $Piece(tKey, ":", 1) '= pEndpoint Continue
                If $Piece(tKey, ":", 2) '= $Get(tErrors(tI, "code")) Continue
                Set tNamed = $Piece(tKey, ":", 3)
                Set tField = tProperty
                If $Extract(tNamed) = "@" {
                    Set tField = $Extract(tNamed, 2, *)
                } ElseIf tNamed '= tProperty {
                    Continue
                }
                Set tCode = $Piece(tEntry, "=", 2)
                Set tRow = {}
                Do tRow.%Set("field", tField, "string")
                Do tRow.%Set("code", tCode, "string")
                Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "string")
                Do pRows.%Push(tRow)
            }
        }
    } Catch {
        ; A status that cannot be decomposed names no property; the fault keeps its other rows.
    }
}

/// <p>The route prefix a <code>rest</code> script step addresses, after the origin.</p>
Parameter SNIPPETPREFIX = "/api/admin/v2";

/// <p>Every non-<code>GET</code> route of the vendor's version-<parameter>APIVERSION</parameter>
/// dispatch map, as <code>[{endpoint, type, verb, url}]</code> in <var>pRoutes</var>, ordered by
/// endpoint, then type, then url (AD-27, AD-59). <code>endpoint</code> is package-relative, as
/// <method>Invoke</method> names it; <code>type</code> is the request-type suffix the route's
/// <code>Call</code> constructs its endpoint with, read from a <code>#TYPE&lt;suffix&gt;</code>
/// parameter reference or through the dispatch class's own <code>Type&lt;verb&gt;()</code>
/// method; <code>verb</code> is the route's method in upper case.</p>
/// <p><b>Caller contract:</b> a build-time derivation. <class>OcuPilot.Port.AdminRoutes</class>
/// holds its checked-in output, which <class>OcuPilot.Test.DraftRegistry</class> holds equal to a
/// fresh call; nothing on a request path calls it. A route whose <code>Call</code> names no
/// endpoint or no type, a route element it cannot read, and two routes on one endpoint, type and
/// url are each an error, never a shorter table.</p>
ClassMethod DeriveRoutes(Output pRoutes As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pRoutes = []
    Try {
        Set tDispatch = ..AdminApiClass() _ ".Dispatch.v" _ ..#APIVERSION
        Set tXData = ##class(%Dictionary.CompiledXData).%OpenId(tDispatch _ "||UrlMap")
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the dispatch map of " _ tDispatch _ " is not readable")
            Quit
        }
        Set tMap = ""
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tMap = tMap _ tXData.Data.Read(32000)
        }
        Set tXData = ""
        Set tPackage = ..EndpointPackage()
        Kill tSorted
        Set tStart = 1
        Set tRead = 0
        For {
            Set tAt = $Locate(tMap, "<Route\s+Url=""[^""]*""\s+Method=""[^""]*""\s+Call=""[^""]*""", tStart, tEnd, tRoute)
            If 'tAt Quit
            Set tStart = tEnd
            Set tRead = tRead + 1
            Set tUrl = $Piece($Piece(tRoute, "Url=""", 2), """", 1)
            Set tVerb = $ZConvert($Piece($Piece(tRoute, "Method=""", 2), """", 1), "U")
            Set tCall = $Piece($Piece(tRoute, "Call=""", 2), """", 1)
            If tVerb = "GET" Continue
            Set tBody = ..MethodText(tDispatch, tCall)
            Set tEndpoint = $Piece($Piece(tBody, "##class(" _ tPackage, 2), ")", 1)
            Set tType = ""
            If $Locate(tBody, "#TYPE[A-Z0-9]+", 1, , tFound) {
                Set tType = $Extract(tFound, 6, *)
            } ElseIf $Locate(tBody, "\.\.Type[A-Za-z0-9]+\(\)", 1, , tFound) {
                Set tHelper = $Extract($Piece(tFound, "(", 1), 3, *)
                If $Locate(..MethodText(tDispatch, tHelper), "#TYPE[A-Z0-9]+", 1, , tFound) Set tType = $Extract(tFound, 6, *)
            }
            If (tEndpoint = "") || (tType = "") {
                Set tSC = $$$ERROR($$$GeneralError, "the route " _ tVerb _ " " _ tUrl _ " (" _ tCall _ ") names no endpoint or no request type")
                Quit
            }
            If $Data(tSorted(tEndpoint, tType, tUrl), tOther) {
                Set tSC = $$$ERROR($$$GeneralError, "the routes " _ tOther _ " and " _ tVerb _ " " _ tUrl _ " name the same endpoint and request type")
                Quit
            }
            Set tSorted(tEndpoint, tType, tUrl) = tVerb
        }
        If $$$ISERR(tSC) Quit
        Set tHeld = 0
        Set tStart = 1
        While $Locate(tMap, "<Route\s", tStart, tStart) {
            Set tHeld = tHeld + 1
        }
        If tRead '= tHeld {
            Set tSC = $$$ERROR($$$GeneralError, "the dispatch map holds " _ tHeld _ " routes and " _ tRead _ " of them were read")
            Quit
        }
        Set tEndpoint = ""
        For {
            Set tEndpoint = $Order(tSorted(tEndpoint))
            If tEndpoint = "" Quit
            Set tType = ""
            For {
                Set tType = $Order(tSorted(tEndpoint, tType))
                If tType = "" Quit
                Set tUrl = ""
                For {
                    Set tUrl = $Order(tSorted(tEndpoint, tType, tUrl), 1, tVerb)
                    If tUrl = "" Quit
                    Set tRow = {}
                    Do tRow.%Set("endpoint", tEndpoint, "string")
                    Do tRow.%Set("type", tType, "string")
                    Do tRow.%Set("verb", tVerb, "string")
                    Do tRow.%Set("url", tUrl, "string")
                    Do pRoutes.%Push(tRow)
                }
            }
        }
    } Catch ex {
        Set pRoutes = []
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pRoutes = []
    Quit tSC
}

/// <p>The compiled implementation of <var>pClass</var>'s method <var>pMethod</var> as text, or
/// <code>""</code> when it has none.</p>
ClassMethod MethodText(pClass As %String, pMethod As %String) As %String [ Private ]
{
    Set tText = ""
    Try {
        Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(pClass _ "||" _ pMethod)
        If '$IsObject(tMethod) Quit
        Do tMethod.Implementation.Rewind()
        While 'tMethod.Implementation.AtEnd {
            Set tText = tText _ tMethod.Implementation.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

/// <p>The kind of script step this port renders for <var>pEndpoint</var>'s request type
/// <var>pType</var> (AD-59): <code>objectscript</code> for the AD-27 import this port completes
/// from content, <code>rest</code> where <class>OcuPilot.Port.AdminRoutes</class> resolves the
/// pair, and <code>""</code> otherwise. A subclass that carries a type out itself answers that type
/// and asks this for the rest.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ..IsContentCompleted(pEndpoint, pType) Quit "objectscript"
    If ##class(OcuPilot.Port.AdminRoutes).Route(pEndpoint, pType, .tVerb, .tUrl) Quit "rest"
    Quit ""
}

/// <p>The script <method>Invoke</method> would carry out for the same arguments, as an array of
/// <code>{kind, text}</code> steps, without calling anything (AD-59). Every branch of
/// <method>Invoke</method> and of the sequence it runs is mirrored: the composite query split
/// (<parameter>SPLITQUERIES</parameter>), the constant body (<parameter>CONSTANTBODIES</parameter>),
/// the vendor's key names (<parameter>RENAMEDTYPES</parameter>) and wrapper
/// (<parameter>WRAPPEDTYPES</parameter>), and AD-27's named completions -- a resource with no
/// public permission and a credential imported from content as <code>objectscript</code> steps in
/// <code>%SYS</code>, and the application type an edit keeps as an <code>objectscript</code> step
/// on either side of the call. Every other call is one <code>rest</code> step against the route
/// <class>OcuPilot.Port.AdminRoutes</class> names.</p>
/// <p><b>Caller contract:</b> <var>pQuery</var> and <var>pBody</var> are what the write would be
/// handed, with every secret already a placeholder; <var>pContext</var> is
/// <code>{origin, user, creates, payload, diff}</code>. A pair with no route, and a malformed
/// composite key, answer no step. Nothing here reads the instance or writes anything.</p>
/// <p>A <parameter>JOURNALFILETYPES</parameter> pair's script begins with the guard's read of the
/// journal file list (<method>JournalListStep</method>).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Set tSteps = []
    If '..SplitQuery(pEndpoint, .pQuery, .tQuery) Quit tSteps
    Set tConstant = ..ConstantBody(pEndpoint, pType)
    If $IsObject(tConstant) Set pBody = tConstant
    If $IsObject(pBody) Set pBody = ..Renamed(pEndpoint, pType, pBody)
    Set tBody = pBody
    If $IsObject(pBody) Set tBody = ..Wrapped(pEndpoint, pType, pBody)
    If ..ClassCompletedField(pEndpoint, pType, tBody) '= "" {
        Do tSteps.%Push(..ResourceStep($Get(tQuery("name")), tBody))
        Quit tSteps
    }
    If ..IsContentCompleted(pEndpoint, pType) {
        Do tSteps.%Push(..ImportStep($Get(tQuery("alias")), tBody))
        Quit tSteps
    }
    ; AD-21's eighth case: the guard's read of the journal file list comes first, as it does in
    ; Invoke.
    If ..IsJournalFileType(pEndpoint, pType) Do tSteps.%Push(..JournalListStep(pContext))
    Set tKept = ..IsTypeKept(pEndpoint, pType)
    If $IsObject(pContext) && pContext.%Get("creates") Set tKept = 0
    If tKept Do tSteps.%Push(..KeptTypeStep($Get(tQuery("name"))))
    Set tRest = ..RestStep(pEndpoint, pType, .tQuery, tBody, pContext)
    If '$IsObject(tRest) Quit []
    Do tSteps.%Push(tRest)
    If tKept Do tSteps.%Push(..RestoreTypeStep($Get(tQuery("name"))))
    Quit tSteps
}

/// <p>One <code>rest</code> step: a <code>curl</code> command naming the caller, the route's verb
/// and its URL on <code>pContext.origin</code>, with <var>pQuery</var> as its query and
/// <var>pBody</var> as its JSON body when it is an object. <code>""</code> for a pair
/// <class>OcuPilot.Port.AdminRoutes</class> does not resolve.</p>
ClassMethod RestStep(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicObject
{
    If '##class(OcuPilot.Port.AdminRoutes).Route(pEndpoint, pType, .tVerb, .tUrl) Quit ""
    Set tOrigin = ""
    Set tUser = ""
    If $IsObject(pContext) {
        Set tOrigin = pContext.%Get("origin")
        Set tUser = pContext.%Get("user")
    }
    Set tQueryText = ""
    Set tName = ""
    For {
        Set tName = $Order(pQuery(tName), 1, tValue)
        If tName = "" Quit
        ; A value that is wholly a placeholder stays readable as one, so the caption's "each value in
        ; angle brackets" finds it; every other value is URL-encoded.
        Set tQueryText = tQueryText _ $Select(tQueryText = "": "?", 1: "&") _ $ZConvert(tName, "O", "URL") _ "=" _ $Select($Match(tValue, "^<[A-Za-z0-9_.]+>$"): tValue, 1: $ZConvert(tValue, "O", "URL"))
    }
    Set tBreak = " \" _ $Char(10) _ "  "
    Set tText = "curl -u " _ ..ShellQuoted(tUser) _ " -X " _ tVerb _ " " _ ..ShellQuoted(tOrigin _ ..#SNIPPETPREFIX _ tUrl _ tQueryText)
    If $IsObject(pBody) {
        Set tText = tText _ tBreak _ "-H " _ ..ShellQuoted("Content-Type: application/json") _ tBreak _ "-d " _ ..ShellQuoted(pBody.%ToJSON())
    }
    Quit ..Step("rest", tText)
}

/// <p>The guard's read of the journal file list as one <code>rest</code> step (AD-21's eighth case,
/// AD-59): a <code>GET</code> of <parameter>JOURNALLISTURL</parameter> with <code>maxRows</code> 0, as
/// <method>JournalGuard</method> sends it, naming the caller and origin
/// <var>pContext</var> carries.</p>
ClassMethod JournalListStep(pContext As %DynamicObject = "") As %DynamicObject
{
    Set tOrigin = ""
    Set tUser = ""
    If $IsObject(pContext) {
        Set tOrigin = pContext.%Get("origin")
        Set tUser = pContext.%Get("user")
    }
    Quit ..Step("rest", "curl -u " _ ..ShellQuoted(tUser) _ " -X GET " _ ..ShellQuoted(tOrigin _ ..#SNIPPETPREFIX _ ..#JOURNALLISTURL _ "?maxRows=0"))
}

/// <p>One step of kind <var>pKind</var> carrying <var>pText</var>.</p>
ClassMethod Step(pKind As %String, pText As %String) As %DynamicObject
{
    Set tStep = {}
    Do tStep.%Set("kind", pKind, "string")
    Do tStep.%Set("text", pText, "string")
    Quit tStep
}

/// <p>One <code>objectscript</code> step from the lines of <var>pLines</var>, each indented one
/// space, starting in <code>%SYS</code>.</p>
ClassMethod ObjectScriptStep(pLines As %List) As %DynamicObject
{
    Set tText = " Set $NAMESPACE = ""%SYS"""
    For tI = 1:1:$ListLength(pLines) {
        Set tText = tText _ $Char(10) _ " " _ $List(pLines, tI)
    }
    Quit ..Step("objectscript", tText)
}

/// <p><var>pValue</var> as a POSIX shell single-quoted word.</p>
ClassMethod ShellQuoted(pValue As %String) As %String
{
    Quit "'" _ $Replace(pValue, "'", "'\''") _ "'"
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character written as a
/// <code>$Char</code> term so the literal stays on one line.</p>
ClassMethod Literal(pValue As %String) As %String
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

/// <p>Whether <var>pValue</var> is wholly one <code>&lt;Name&gt;</code> placeholder.</p>
ClassMethod IsPlaceholder(pValue As %String) As %Boolean
{
    Quit ''$Match(pValue, "^<[A-Za-z0-9_.]+>$")
}

/// <p>AD-27's first case as a script: <method>CompleteThroughClass</method>'s create or modify of
/// resource <var>pName</var> through <class>Security.Resources</class> with an empty public
/// permission.</p>
ClassMethod ResourceStep(pName As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tDescription = ""
    If $IsObject(pBody) && pBody.%IsDefined("Description") Set tDescription = pBody.%Get("Description")
    Set tLines = $ListBuild("Kill tProps")
    If $IsObject(pBody) && pBody.%IsDefined("Description") Set tLines = tLines _ $ListBuild("Set tProps(""Description"") = " _ ..Literal(tDescription))
    Set tLines = tLines _ $ListBuild("Set tProps(""PublicPermission"") = """"")
    Set tLines = tLines _ $ListBuild("If ##class(Security.Resources).Exists(" _ ..Literal(pName) _ ") { Set tSC = ##class(Security.Resources).Modify(" _ ..Literal(pName) _ ", .tProps) } Else { Set tSC = ##class(Security.Resources).Create(" _ ..Literal(pName) _ ", " _ ..Literal(tDescription) _ ", """") }")
    Set tLines = tLines _ $ListBuild("Do $System.Status.DisplayError(tSC)")
    Quit ..ObjectScriptStep(tLines)
}

/// <p>AD-27's second case as a script: <method>ImportThroughClass</method>'s import of credential
/// <var>pAlias</var> from content through <class>%SYS.X509Credentials</class>, refused as the port
/// refuses it when the alias is already present. The certificate is decoded from the base64 body of
/// its PEM block (<method>PemBlock</method>), which is what the port decodes; a certificate that is
/// not one PEM block is rendered as given. A certificate or private key that is a placeholder -- a
/// draft's always is, since both are secrets -- is read from the PEM file the placeholder names,
/// through the class's own <code>LoadCertificate</code> and <code>LoadPrivateKey</code>, because a
/// PEM block's line breaks cannot sit inside one ObjectScript string literal.</p>
ClassMethod ImportStep(pAlias As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tLines = $ListBuild("Set tCredential = ##class(%SYS.X509Credentials).%New()", "Set tCredential.Alias = " _ ..Literal(pAlias))
    If $IsObject(pBody) {
        Set tCertificate = ..Scalar(pBody, "Certificate")
        Set tKey = ..Scalar(pBody, "PrivateKey")
        Set tPaths = ""
        If ..IsPlaceholder(tCertificate) Set tPaths = tCertificate
        If ..IsPlaceholder(tKey) Set tPaths = tPaths _ $Select(tPaths = "": "", 1: ", ") _ tKey
        If tPaths '= "" Set tLines = $ListBuild("; " _ tPaths _ ": the path of a PEM file this instance can read") _ tLines
        If ..IsPlaceholder(tCertificate) {
            Set tLines = tLines _ $ListBuild("Set tSC = tCredential.LoadCertificate(" _ ..Literal(tCertificate) _ ")", "Do $System.Status.DisplayError(tSC)")
        } Else {
            If ..PemBlock(tCertificate, "cert", .tCanonical) {
                Set tCertificate = ""
                For tI = 2:1:$Length(tCanonical, $Char(10)) - 1 {
                    Set tLine = $Piece(tCanonical, $Char(10), tI)
                    If (tLine = "") || (tLine [ ":") Continue
                    Set tCertificate = tCertificate _ tLine
                }
            }
            Set tLines = tLines _ $ListBuild("Set tCredential.Certificate = $System.Encryption.Base64Decode(" _ ..Literal(tCertificate) _ ")")
        }
        If tKey '= "" {
            If ..IsPlaceholder(tKey) {
                Set tLines = tLines _ $ListBuild("Set tSC = tCredential.LoadPrivateKey(" _ ..Literal(tKey) _ ")", "Do $System.Status.DisplayError(tSC)")
            } Else {
                Set tLines = tLines _ $ListBuild("Set tCredential.PrivateKey = " _ ..Literal(tKey))
            }
            Set tLines = tLines _ $ListBuild("Set tCredential.PrivateKeyPassword = " _ ..Literal(..Scalar(pBody, "PrivateKeyPassword")))
        }
        For tField = "OwnerList", "PeerNames" {
            If pBody.%GetTypeOf(tField) '= "array" Continue
            Set tJoined = ""
            Set tIterator = pBody.%Get(tField).%GetIterator()
            While tIterator.%GetNext(.tIndex, .tItem) {
                If $IsObject(tItem) || (tItem = "") Continue
                Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ",") _ tItem
            }
            Set tLines = tLines _ $ListBuild("Set tCredential." _ tField _ " = " _ ..Literal(tJoined))
        }
    }
    Set tLines = tLines _ $ListBuild("Set tSC = $Select(##class(%SYS.X509Credentials).Exists(" _ ..Literal(pAlias) _ "): $System.Status.Error(5001, ""an X.509 credential already carries that alias""), 1: tCredential.Save())", "Do $System.Status.DisplayError(tSC)")
    Quit ..ObjectScriptStep(tLines)
}

/// <p>The first half of AD-27's fifth case as a script: the type web application <var>pName</var>
/// holds before the edit, read from <class>Security.Applications</class>.</p>
ClassMethod KeptTypeStep(pName As %String) As %DynamicObject
{
    Quit ..ObjectScriptStep($ListBuild("Kill tProps", "Set tSC = ##class(Security.Applications).Get(" _ ..Literal(pName) _ ", .tProps)", "ZWrite tProps(""Type"")"))
}

/// <p>The second half of AD-27's fifth case as a script: the type the first step wrote, re-applied
/// to web application <var>pName</var>. <code>&lt;Type&gt;</code> is that value.</p>
ClassMethod RestoreTypeStep(pName As %String) As %DynamicObject
{
    Quit ..ObjectScriptStep($ListBuild("Kill tProps", "Set tProps(""Type"") = <Type>", "Set tSC = ##class(Security.Applications).Modify(" _ ..Literal(pName) _ ", .tProps)", "Do $System.Status.DisplayError(tSC)"))
}

/// <p>The scalar <var>pObject</var> carries at <var>pKey</var>, or <code>""</code>.</p>
ClassMethod Scalar(pObject, pKey As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pKey)
    If (tType = "unassigned") || (tType = "object") || (tType = "array") || (tType = "null") Quit ""
    Quit pObject.%Get(pKey)
}

}
