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
/// <p><b>The six are the ones the registry actually reaches</b>, established three ways: the
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
/// <p><code>RESUME</code> is <code>Task.CRUD</code>'s bodyless resume and <code>Process</code>'s
/// own (AD-51, Stories 5.11 and 5.12), and <code>SUSPEND</code> is <code>Process</code>'s
/// suspend. Each vendor <code>NeedsRequestBody()</code> excludes them, each
/// <code>ValidateQueryParams</code> requires the <code>id</code> query parameter, and each is
/// listed in <parameter>BODYLESSTYPES</parameter> under its own endpoint, which is what exempts
/// it from the object-body refusal below.</p>
/// <p><code>TERMINATE</code> and <code>DELETE</code> are deliberately absent for
/// <code>Process</code>. The vendor exposes terminating a process through both --
/// <code>Process</code>'s <code>RunDelete</code> is a one-line delegate to <code>RunTerminate</code>
/// -- and AD-10 names terminating an IRIS system process in the Release 1 prohibited set, so neither
/// pairs with <code>Process</code> here and <method>EndpointType</method> answers <code>""</code>
/// for either.</p>
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
Parameter MUTATINGTYPES = "WebApp.App/PUT,Security.User/PUT,Security.Audit.Enabled/PUT,Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,Security.User/POST,Security.Role/PUT,Security.Role/DELETE,Security.Resource/PUT,Security.Resource/DELETE,Security.X509Credential/POST,Security.X509Credential/PUT,Security.X509Credential/DELETE,Wallet.Secret/PUT";

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
Parameter BODYLESSTYPES = "Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,Security.Role/DELETE,Security.Resource/DELETE,Security.X509Credential/DELETE";

/// <p>The <parameter>MUTATINGTYPES</parameter> deletes whose vendor answer does not say whether the
/// object went, as comma-separated <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries. After a 2xx
/// for a listed pair, <method>Invoke</method> re-issues the endpoint's <code>GET</code> for the same
/// query: only a 404 confirms the delete, and anything else is a 500 fault with
/// <parameter>OcuPilot.Api.Error.PORTNOTAPPLIED</parameter>, never a success.</p>
/// <p><code>Security.Role/DELETE</code> is listed because its <code>RunDelete</code> answers the
/// status of <code>%SQL.Manager.API.DropUser(name, "ROLE")</code>, which is <code>$$$OK</code>
/// whether or not the role was dropped (read on this build). That is a wire fact, so it lives here
/// (AD-27).</p>
Parameter VERIFIEDDELETES = "Security.Role/DELETE";

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

        ; WRAPPEDTYPES: a flat body becomes the vendor's wrapper here, before ValidateRequest reads
        ; it, so no caller above the port composes the wire shape.
        Set tBody = pBody
        If $IsObject(pBody) Set tBody = ..Wrapped(pEndpoint, pType, pBody)
        Set tSeqSC = ..RunSequence(pEndpoint, tClass, tType, .pQuery, tBody, .tAnswer, .tHttp, .tLocation, ..HttpMethodFor(pEndpoint, pType))
        If $$$ISOK(tSeqSC) && (tHttp = 202) && (tLocation [ ..#ASYNCLOCATION) {
            Set tAnswer = ""
            Set tGuid = $Piece($Piece(tLocation, ..#ASYNCLOCATION, 2), "&", 1)
            Set tSC = ..AwaitTask(pEndpoint, tGuid, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $$$ISOK(tSeqSC) && (tHttp >= 200) && (tHttp < 300) {
            ; VERIFIEDDELETES: a delete the vendor reports as made is believed only once a re-read
            ; finds the object gone.
            If ..IsVerifiedDelete(pEndpoint, pType) {
                Set tSC = ..VerifyGone(pEndpoint, .pQuery, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
            ; VERIFIEDWRITES: a write the vendor reports as made is believed only once a re-read
            ; answers every sent value.
            If ..IsVerifiedWrite(pEndpoint, pType) {
                Set tSC = ..VerifyApplied(pEndpoint, .pQuery, pBody, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
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
        Set tSC = ..Fail(pEndpoint, tHttp, tSeqSC, .pHttpStatus, .pFault, ..WrapperKey(pEndpoint, pType))
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
    If pSuffix = "POST" Set tRunner = "RunPost"
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
/// the vendor status to the log, and an error status carrying only the fault's own text.
/// <var>pWrapper</var> is the request's <parameter>WRAPPEDTYPES</parameter> wrapper key, or
/// <code>""</code>; a violation field that begins with it and a dot loses that segment.</p>
ClassMethod Fail(pEndpoint As %String, pHttp As %Integer, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pWrapper As %String = "") As %Status [ Private ]
{
    Set pHttpStatus = $Select(+pHttp: +pHttp, 1: 500)
    Set tOutcomeSC = ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, pVendorSC, .pFault, .tDetail)
    If $$$ISERR(tOutcomeSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tOutcomeSC, pFault.code)
    ; AD-39. A vendor refusal that names a body field crosses the boundary as detail.violations --
    ; the field the vendor named, OcuPilot's stable code for that kind of refusal, and OcuPilot's
    ; own sentence -- so a screen renders it on the field it is about and a tool result renders the
    ; code. The vendor's own text still reaches the log alone, on the line below.
    Set tViolations = ##class(OcuPilot.Api.Error).ViolationsFromVendor(pVendorSC)
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
