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

/// <p>The <code>resource:permission</code> pair <method>ForgetTask</method>'s delete needs, in
/// <method>HoldsPair</method>'s grammar (DW-1025).</p>
/// <p><b>Derived from the vendor's storage, not chosen.</b>
/// <parameter>ASYNCTASKCLASS</parameter>'s <code>DataLocation</code> is
/// <code>^|"^^:ds:IRISLOCALDATA"|Api.Admin.Util.AsyncTaskD</code> -- an extended reference naming
/// the dataset itself, so the rows live in IRISLOCALDATA whatever the namespace maps, and that
/// database's resource is <code>%DB_IRISLOCALDATA</code>. The vendor writes those rows through its
/// own <code>SaveTask()</code>, which adds <code>%All</code> for the write; the delete here runs as
/// the caller, so a caller without the pair meets <code>&lt;PROTECT&gt;</code>. Asserted against
/// the instance by <class>OcuPilot.Test.AdminPortForget</class>, which resolves the resource from
/// the database rather than repeating the literal.</p>
Parameter ASYNCTASKPAIR = "%DB_IRISLOCALDATA:WRITE";

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
Parameter TYPESUFFIXES = "GET,LIST,INFO,CERTINFO,UPCOMING,HISTORY,VOLUMELIST";

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
/// <p><b>Reached only by a confirmed proposal.</b> A mutating call is issued by
/// <class>OcuPilot.Kernel.Proposal.Confirm</class> after its claim has committed (AD-34, AD-40);
/// no tool, no screen read and no turn reaches one, and the port itself decides nothing about
/// whether the write may happen.</p>
/// <p><b>Synchronous on the endpoints that ship today.</b> The vendor's base
/// <code>ShouldRunAsync()</code> answers false and neither <code>Security.Applications</code>'s
/// endpoint nor <code>Task.CRUD</code> overrides it, so a mutating call runs in the caller's job
/// and its answer is the endpoint's own. An endpoint that <i>did</i> queue a mutating request is
/// refused by <method>Sequence</method> before the vendor's task row is written, because that row
/// would carry a supplied secret from the body (AD-35, DW-1279). <method>Sequence</method> reads
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
/// <p><code>TERMINATE</code> and <code>DELETE</code> are deliberately absent. The vendor exposes
/// terminating a process through both -- <code>Process</code>'s <code>RunDelete</code> is a
/// one-line delegate to <code>RunTerminate</code> -- and AD-10 names terminating an IRIS system
/// process in the Release 1 prohibited set, so neither pairs with <code>Process</code> here and
/// <method>EndpointType</method> answers <code>""</code> for either.</p>
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
Parameter MUTATINGTYPES = "WebApp.App/PUT,Security.User/PUT,Security.Audit.Enabled/PUT,Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,Security.User/DELETE,Security.User/CHANGEPWD,Task.CRUD/RUN";

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
Parameter BODYLESSTYPES = "Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,Security.User/DELETE";

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
Parameter CONSTANTBODIES = "Task.CRUD/RUN={""RunNow"":true}";

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
Parameter BARETYPES = "Monitor/SYSTEMUSAGE,Monitor/SYSTEMUSAGESHM,Monitor/DASHBOARDMAIN";

/// <p>The body-template method names, in the order <method>TemplateMethod</method> resolves them
/// (AD-3): the first one an endpoint class defines itself is its template.</p>
Parameter TEMPLATENAMES = "RequestBodySchema,PutRequestBodySchema,PutAndPostSchema,Schema";

/// <p>The endpoints whose template method takes an argument, as comma-separated
/// <code>&lt;endpoint&gt;:&lt;value&gt;</code> pairs. <method>Template</method> passes the value
/// as the method's one argument; every other template is called with none, so an optional
/// argument is evaluated at its default. <code>Security.SSLConfig</code>'s argument
/// (<code>includePrivateKeyPassword</code>) adds the <code>PrivateKeyPassword</code> field.</p>
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
/// suffix from <parameter>TYPESUFFIXES</parameter>; <var>pQuery</var> holds query parameters as
/// <code>pQuery(name) = value</code>; <var>pBody</var> is the request body, <code>{}</code> when
/// omitted.</p>
/// <p>Returns OK exactly when the endpoint's status is OK and its HTTP status is 2xx, with
/// <var>pResult</var> the endpoint's return value (an async task's <code>Result</code>) and
/// <var>pFault</var> empty. Otherwise returns an error <class>%Status</class> carrying only
/// OcuPilot's own text, <var>pResult</var> empty and <var>pFault</var>
/// <code>{error, reason, code}</code> from <class>OcuPilot.Kernel.Fault</class>; vendor text goes
/// to <method>LogFault</method> alone. <var>pHttpStatus</var> is the numeric HTTP status in both
/// cases: the endpoint's, 503 for a refusal the port decided (<code>PORT.UNAVAILABLE</code>,
/// <code>PORT.TIMEOUT</code>), 501 for a name no compiled endpoint class answers, a suffix
/// outside <parameter>TYPESUFFIXES</parameter>, a suffix the class declares no
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
/// sent the port's constant; given an object, it is refused the same way and the vendor is not
/// called (AD-27, AD-51).</p>
/// <p>Must not be called from an escalated frame (AD-9). The caller's namespace,
/// <code>%request</code>, <code>%response</code> and <code>%session</code> are unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
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

        ; CONSTANTBODIES: a vendor type whose body is a fixed wire fact takes it here, so no caller
        ; above the port composes it. A caller body for such a pair is a caller bug, refused before
        ; the vendor is reached rather than merged or replaced.
        Set tConstant = ..ConstantBody(pEndpoint, pType)
        If $IsObject(tConstant) {
            If $IsObject(pBody) {
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
        ; body -- and whatever it records from it -- keeps the product's name.
        If $IsObject(pBody) Set pBody = ..Renamed(pEndpoint, pType, pBody)
        Set tSeqSC = ..RunSequence(pEndpoint, tClass, tType, .pQuery, pBody, .tAnswer, .tHttp, .tLocation, ..HttpMethodFor(pEndpoint, pType))
        If $$$ISOK(tSeqSC) && (tHttp = 202) && (tLocation [ ..#ASYNCLOCATION) {
            Set tAnswer = ""
            Set tGuid = $Piece($Piece(tLocation, ..#ASYNCLOCATION, 2), "&", 1)
            Set tSC = ..AwaitTask(pEndpoint, tGuid, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $$$ISOK(tSeqSC) && (tHttp >= 200) && (tHttp < 300) {
            Set pResult = tAnswer
            Set pHttpStatus = tHttp
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
            Set tSC = ..Denied(pEndpoint, tFailedPair, tSeqSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Fail(pEndpoint, tHttp, tSeqSC, .pHttpStatus, .pFault)
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
ClassMethod Template(pEndpoint As %String, Output pTemplate As %DynamicAbstractObject, Output pMethod As %String) As %Status
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
/// it. Only the row this call queued is deleted. A failure is logged and never raised.</p>
/// <p><b>A caller who cannot write the row's database leaves it alone, silently</b>
/// (<parameter>ASYNCTASKPAIR</parameter>, DW-1025). The delete runs as the caller, so without that
/// pair it fails <code>&lt;PROTECT&gt;</code> -- and logging that put the vendor's protect text
/// into the log this instance's own console-log screen displays, once per async read, for a caller
/// who had already been served. The row is the vendor's own housekeeping: leaving it is the same
/// outcome as the timeout arm, which also leaves a row behind, and no caller-visible answer
/// changes either way.</p>
ClassMethod ForgetTask(pGuid As %String)
{
    If '..HoldsPair(..#ASYNCTASKPAIR) Quit
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#ASYNCTASKCLASS, "%DeleteId", pGuid)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFault("an async task row could not be removed", tSC)
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
/// <parameter>BODYLESSTYPES</parameter> exempts from the object-body refusal (AD-51, DW-1464).</p>
ClassMethod IsBodyless(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#BODYLESSTYPES), pEndpoint _ "/" _ pSuffix)
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
/// <parameter>MUTATINGTYPES</parameter> admits (DW-1473). Every read of that parameter is this
/// method, so admitting a type on one endpoint can never be read as admitting it on another.</p>
ClassMethod IsMutating(pEndpoint As %String, pSuffix As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#MUTATINGTYPES), pEndpoint _ "/" _ pSuffix)
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
/// parameter of that name; any other suffix must be in <parameter>TYPESUFFIXES</parameter> and
/// resolves through <code>TYPE&lt;suffix&gt;</code>.</p>
ClassMethod EndpointType(pEndpoint As %String, pClass As %String, pSuffix As %String) As %String [ Private ]
{
    If '$Match(pSuffix, "^[A-Z]+$") Quit ""
    If $ListFind($ListFromString(..#BARETYPES), pEndpoint _ "/" _ pSuffix) {
        Set tBare = $Parameter(pClass, pSuffix)
        If (tBare = "") || '..ImplementsRead(pClass, pSuffix) Quit ""
        Quit tBare
    }
    If '$ListFind($ListFromString(..#TYPESUFFIXES), pSuffix) && '..IsMutating(pEndpoint, pSuffix) Quit ""
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
/// <p>The endpoint is constructed before the switch, in the caller's namespace, because a
/// class compiled only there cannot be constructed from <code>%SYS</code>; the vendor's
/// <code>%OnNew</code> records the type and version and nothing else.</p>
ClassMethod RunSequence(pEndpoint As %String, pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicAbstractObject, Output pAnswer, Output pHttpStatus As %Integer, Output pLocation As %String, pMethod As %String = "GET") As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pLocation = ""
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
        Set tSC = ..Sequence(pEndpoint, tEndpoint, tBody, .pAnswer)
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
ClassMethod Sequence(pName As %String, pEndpoint As %RegisteredObject, pBody As %DynamicAbstractObject, Output pAnswer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
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
        Try {
            Set tSC = pEndpoint.ValidateSemantics()
        } Catch exSemantics {
            Set tSC = exSemantics.AsStatus()
        }
        If $$$ISERR(tSC) Quit

        If pEndpoint.ShouldRunAsync() {
            ; AD-35, DW-1279: a mutating request's body can carry a supplied secret, and
            ; SaveRequestBody writes it into the vendor's own task row
            ; (^|"^^:ds:IRISLOCALDATA"|Api.Admin.Util.AsyncTaskD), which is a surface OcuPilot
            ; neither owns nor purges. Neither Release 1 async entry is mutating, so this refuses a
            ; combination no shipped path reaches -- before the row is written rather than after,
            ; because a secret written there cannot be taken back.
            ; The endpoint name is threaded in rather than re-derived, so this asks the same
            ; (endpoint, type) question the admission gate asked. %request.Method carries the
            ; request-type suffix for a mutating call (HttpMethodFor) and GET otherwise.
            Set tMethod = %request.Method
            If ..IsMutating(pName, tMethod) {
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
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Poll task <var>pGuid</var> until it is terminal or <method>AsyncTimeout</method> passes.
/// <code>Finished</code> is a 200 success carrying the task's <code>Result</code>;
/// <code>Failed</code> is a 500 whose fault is built from <code>FailureReason</code>; both hand the
/// row to <method>ForgetTask</method>, which deletes it only for a caller holding
/// <parameter>ASYNCTASKPAIR</parameter> and leaves it alone silently otherwise. No terminal state
/// within the bound is <code>PORT.TIMEOUT</code>, and the row is left to the worker that still
/// owns it.</p>
ClassMethod AwaitTask(pEndpoint As %String, pGuid As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
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
/// the vendor status to the log, and an error status carrying only the fault's own text.</p>
ClassMethod Fail(pEndpoint As %String, pHttp As %Integer, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = $Select(+pHttp: +pHttp, 1: 500)
    Set tOutcomeSC = ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, pVendorSC, .pFault, .tDetail)
    If $$$ISERR(tOutcomeSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tOutcomeSC, pFault.code)
    If $$$ISERR(pVendorSC) Do ..LogFault(pEndpoint _ " failed with HTTP " _ pHttpStatus, pVendorSC, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
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
ClassMethod Denied(pEndpoint As %String, pFailedPair As %String, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair)
    Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(403, pVendorSC, .tMapped, .tVendorText)
    If $$$ISERR(tMapSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tMapSC)
    Set tSC = ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
    Do ..LogFault(pEndpoint _ "'s backing query refused a caller holding no pair of the set naming " _ pFailedPair, pVendorSC, pFault.code)
    Quit tSC
}

}
