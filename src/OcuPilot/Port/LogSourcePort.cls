/// <p>The port to the log sources the administration API does not back (AD-21, AD-29). It serves
/// bounded byte pages of whole lines from a file in the instance's manager directory.</p>
/// <p><method>Page</method> is the entry point a route uses, and <method>Rows</method> the one a
/// declared read uses (AD-36): the same window, projected into <code>{time, severity, text}</code>
/// rows newest first instead of raw lines. A caller names a <b>source key</b> from
/// <method>Sources</method>'s fixed enum and never a path, a file name or any part of one: the
/// directory comes from <code>$System.Util.ManagerDirectory()</code> on every call and the file
/// name from the key (AD-21). The step order is load-bearing -- enum, gate, <var>maxBytes</var>,
/// the offset/identity pair, resolve, open, identity, window, read -- and nothing above the gate
/// reaches the filesystem (AD-29: this port inherits no vendor gate, so it declares its own
/// <code>(resource, permission)</code> set and evaluates it first).</p>
/// <p><b>The file moves under a paging reader.</b> The instance rotates the console log at its
/// configured maximum size by renaming it away and creating a new one, so a byte offset held
/// across a rotation points into a file that no longer exists. Each page therefore carries an
/// <b>identity</b> token derived from the file's first line, and a call whose held identity no
/// longer matches -- or whose held offset is past the current end -- is answered from byte 1 with
/// <code>restarted</code> true. A restart is an outcome, never a fault.</p>
/// <p>Every refusal is a wire-safe fault <class>OcuPilot.Kernel.Fault</class> built, with a code
/// from <class>OcuPilot.Api.Error</class> (AD-12, AD-39); raw status text goes to
/// <method>LogFault</method> alone. Nothing here writes to the response device, switches
/// namespace, escalates or spawns.</p>
/// <p><b>One source is not a file.</b> <method>Errors</method> serves the application error
/// log -- the <code>^ERRORS</code> global, read through <code>SYS.ApplicationError</code>'s own
/// four queries and nothing else (AD-48) -- in four drill levels a route binds one of. That class
/// exists only in <code>%SYS</code>, so the port enters that namespace <b>once per call</b> by
/// explicit save and restore, never enters the namespace being read, and passes the target
/// namespace as each query's own first parameter (AD-16). Its gate is a function of the selected
/// namespace rather than a constant, which is why <method>PairsFor</method> takes one.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.LogSourceFixture</class>,
/// <class>OcuPilot.Test.ErrorLogFixture</class>): <method>Sources</method>,
/// <method>PairsFor</method>, <method>FileFor</method>, <method>ManagerDirectory</method>,
/// <method>MaxBytesCap</method>, <method>GateClass</method>, <method>FileExists</method>,
/// <method>OpenStream</method>, <method>ErrorLevels</method>, <method>QueryClass</method>,
/// <method>DetailQuery</method>, <method>NamespaceResolver</method> and
/// <method>OpenQuery</method>. Production overrides none of them.</p>
Class OcuPilot.Port.LogSourcePort Extends %RegisteredObject
{

/// <p>The fixed enum of source keys this port serves (AD-21), comma-separated. A caller names a
/// key from this list and nothing else; a route binds the key, so no caller names a file.</p>
/// <p><b>Two kinds of source, two entry points.</b> <method>Page</method> serves the file sources;
/// <method>Errors</method> serves <parameter>ERRORSKEY</parameter>, which is a global read through
/// a vendor query rather than a file (AD-48). Both entry points read this one enum, so
/// <method>Page</method> admits <parameter>ERRORSKEY</parameter> at its enum check and then refuses
/// it at the next step instead: the key's requirement is a function of a namespace
/// <method>Page</method> never names, so <method>PairsFor</method> answers an empty set and the
/// prologue's empty-pair-set refusal answers 403 rather than serving a page. No route can reach
/// that -- each binds its own key -- and <class>OcuPilot.Test.ErrorLog</class> pins it.</p>
Parameter SOURCES = "messages,alerts,applicationerrors";

/// <p>The <parameter>SOURCES</parameter> key for the instance's console log.</p>
Parameter MESSAGESKEY = "messages";

/// <p>The console log's file name, resolved against <method>ManagerDirectory</method> on every
/// call.</p>
Parameter MESSAGESFILE = "messages.log";

/// <p>The console log's <code>(resource, permission)</code> pair set, comma-separated as
/// <code>resource:permission</code> (AD-8).</p>
/// <p><b>One pair, and <code>%DB_IRISSYS:READ</code> is deliberately not among them.</b> Every
/// admin-port read declares it because that port runs every endpoint in <code>%SYS</code>;
/// reading a file off disk consults no database resource and this path never enters
/// <code>%SYS</code>. The classic portal requires the same one resource, on the web application
/// that serves its console-log page (<code>/csp/sys/op</code> carries
/// <code>%Admin_Operate</code>) and explicitly on a sibling page in that application
/// (<file>irislib/%CSP/UI/Portal/ViewLog.cls</file>'s <code>RESOURCE</code>), so a user reaches a
/// line through OcuPilot only if they could have read it directly (AD-29).</p>
Parameter MESSAGESPAIRS = "%Admin_Operate:USE";

/// <p>The <parameter>SOURCES</parameter> key for the instance's alert log.</p>
Parameter ALERTSKEY = "alerts";

/// <p>The alert log's file name, resolved against <method>ManagerDirectory</method> on every
/// call.</p>
Parameter ALERTSFILE = "alerts.log";

/// <p>The alert log's <code>(resource, permission)</code> pair set, comma-separated as
/// <code>resource:permission</code> (AD-8).</p>
/// <p><parameter>MESSAGESPAIRS</parameter>' one pair, for its reason: reading a file off disk
/// consults no database resource and this path never enters <code>%SYS</code>. The classic page
/// that shows alerts.log first (<file>irislib/%CSP/UI/System/ViewTextFilePane.cls</file>) is served
/// by <code>/csp/sys/op</code>, which carries <code>%Admin_Operate</code>. The screen over this
/// source declares this same one pair, so the gate a user meets is the same whichever way the
/// screen reads (AD-8).</p>
Parameter ALERTSPAIRS = "%Admin_Operate:USE";

/// <p>The <parameter>SOURCES</parameter> key for the instance's application error log, the
/// <code>^ERRORS</code> global read through <code>SYS.ApplicationError</code> (AD-48). It has no
/// file, so <method>Page</method> does not serve it; <method>Errors</method> does.</p>
Parameter ERRORSKEY = "applicationerrors";

/// <p>The pairs every application-error read requires whatever namespace it names, comma-separated
/// as <code>resource:permission</code> and in the order the gate reports in. They are also the
/// whole requirement of <code>NamespaceList</code>, the instance-wide enumeration a caller chooses
/// a namespace from.</p>
/// <ul>
/// <li><code>%Admin_Operate:USE</code> -- the classic portal's own key for these screens
/// (<code>/csp/sys/op</code> carries it).</li>
/// <li><code>%DB_IRISSYS:READ</code> -- <b>measured, not inherited</b> (AD-29).
/// <code>SYS.ApplicationError</code> exists only in <code>%SYS</code>, whose routine database is
/// IRISSYS, and database READ <i>is</i> routine-execution permission: a principal without it
/// cannot execute the query at all. Observed on a real least-privileged principal on a throwaway,
/// which is the only way this pair is findable -- the class publishes no
/// <code>Requires</code>, and <code>%UnitTest</code> runs as <code>%All</code>. Without it in this
/// set the refusal arrives as a <code>&lt;PROTECT&gt;</code> turned into a 500 naming no pair,
/// which is DW-274's shape; with it, the gate answers 403 and names it.</li>
/// </ul>
Parameter ERRORSINSTANCEPAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The permissions an application-error read requires on the guarding resource of the target
/// namespace's globals database, appended to <parameter>ERRORSINSTANCEPAIRS</parameter> in this
/// order (AD-8: the gate names the first pair a caller does not hold, so the order is part of the
/// contract -- append, never prepend).</p>
/// <p><b>WRITE is the half the delete belongs to</b>, and one set serves both: <file>epics.md</file>,
/// the epic context and AD-48 all record the requirement as <code>%Admin_Operate</code> plus read
/// <i>and</i> write on that database, which is what the classic portal asks of a screen that also
/// deletes. <method>Invoke</method>'s <parameter>TYPEDELETE</parameter> is that delete, and it is
/// gated on this same set rather than on one of its own, so the privileges a user meets reading a
/// namespace and deleting in it cannot drift apart. The consequence, stated so it is not discovered
/// later: a principal who could read <code>^ERRORS</code> directly but holds no WRITE on that
/// globals database is refused here, and a namespace whose globals database is mounted read-only
/// can never satisfy the set. That is stricter than the data's own readability, so it does not
/// contradict AD-29, whose rule is one-directional.</p>
Parameter ERRORSDATABASEPERMISSIONS = "READ,WRITE";

/// <p>The namespace <code>SYS.ApplicationError</code> lives in. The port enters it once per call,
/// by explicit save and restore, and never enters the namespace being read: that one travels as
/// the query's own first parameter (AD-16, AD-48).</p>
Parameter ERRORSNAMESPACE = "%SYS";

/// <p>The vendor class whose four queries are the only way this port reads the application error
/// log (AD-48). No <code>^ERRORS</code> traversal of OcuPilot's own, and never
/// <code>%CSP.ErrorLog</code>.</p>
Parameter ERRORSQUERYCLASS = "SYS.ApplicationError";

/// <p>The <parameter>ERRORSQUERYCLASS</parameter> method one date's named errors are removed
/// through (AD-48). Dispatched by name for the reason every query is: the class exists only in
/// <code>%SYS</code>, so a compile-time reference to it would not resolve in the install
/// namespace.</p>
/// <p><b>It is not <code>DeleteByNamespace</code>.</b> That method removes every error in the
/// namespace for every date, which would destroy rows logged after the proposal; this one takes a
/// comma-separated list of error numbers for one date, so the confirm removes exactly the ids the
/// user reviewed.</p>
Parameter DELETEBYERRORMETHOD = "DeleteByError";

/// <p>The query answering the namespaces that hold application errors.</p>
/// <p><b>It answers the set the caller can read.</b> Observed on a real least-privileged principal
/// on a throwaway: a caller without READ on a namespace's globals database is not offered that
/// namespace at all. So a namespace a caller cannot read is refused
/// <code>LOG.NAMESPACE</code> by the enumeration before the per-namespace gate is reached, and
/// what the gate's own database pairs then decide is the WRITE this screen additionally requires
/// (AD-21: where a log source is a global, the namespace is chosen from the set the user can read,
/// never taken as a caller string).</p>
Parameter NAMESPACELISTQUERY = "NamespaceList";

/// <p><code>NamespaceList</code>'s <code>ListType</code>: 0 is every namespace, local and
/// remote.</p>
Parameter NAMESPACELISTALL As INTEGER = 0;

/// <p>The query answering the dates one namespace holds errors for, newest first.</p>
Parameter DATELISTQUERY = "DateList";

/// <p>The query answering one namespace and date's errors, highest error number first.</p>
Parameter ERRORLISTQUERY = "ErrorList";

/// <p>The query answering one error's captured detail. <b>Reachable from the detail level
/// alone</b>: it carries <code>$Roles</code>, <code>$USERNAME</code> and every local at every stack
/// level at every <code>Type</code> it takes, so no <code>Type</code> answers the summary fields
/// without the identity ones. The summary path therefore never calls it -- not even to fill
/// <code>routine</code> and <code>line</code>, both of which <code>ErrorList</code> already
/// carries (AD-48).</p>
Parameter ERRORDETAILQUERY = "ErrorDetail";

/// <p><code>ErrorDetail</code>'s <code>Type</code> for the logged expressions and their values.</p>
Parameter DETAILTYPEEXPRESSIONS As INTEGER = 0;

/// <p><code>ErrorDetail</code>'s <code>Type</code> for the stack levels.</p>
Parameter DETAILTYPESTACK As INTEGER = -1;

/// <p><code>ErrorDetail</code>'s <code>Type</code> for the collapsed stack levels -- every local
/// variable at every level, in one pass.</p>
Parameter DETAILTYPEVARIABLES As INTEGER = -2;

/// <p>The drill level <method>Errors</method> serves: the namespaces that hold errors.</p>
Parameter LEVELNAMESPACES = "namespaces";

/// <p>The drill level <method>Errors</method> serves: one namespace's dates.</p>
Parameter LEVELDATES = "dates";

/// <p>The drill level <method>Errors</method> serves: one namespace and date's errors.</p>
Parameter LEVELLIST = "list";

/// <p>The drill level <method>Errors</method> serves: one error's captured detail.</p>
Parameter LEVELDETAIL = "detail";

/// <p>The fixed enum of drill levels, comma-separated. A route binds one of them, so no caller
/// names a level either; a level outside this list is refused before anything else happens.</p>
Parameter ERRORLEVELS = "namespaces,dates,list,detail";

/// <p>The endpoint name <method>Invoke</method> serves, which is this port's one source key. A
/// write tool declares it through <method>OcuPilot.Screen.Tool.Write.Endpoint</method> (AD-52).</p>
Parameter ENDPOINTERRORS = "applicationerrors";

/// <p><method>Invoke</method>'s read type: the enumeration of every <code>(date, errorNumber)</code>
/// one namespace holds, which is the fresh read a delete proposal is minted from and the subject
/// its fingerprint covers (AD-48, AD-51).</p>
Parameter TYPEENUMERATE = "ENUMERATE";

/// <p><method>Invoke</method>'s write type: remove the enumerated ids named in the call's own
/// query, and nothing else.</p>
Parameter TYPEDELETE = "DELETE";

/// <p>The query parameter <method>Invoke</method> reads the target namespace from, which is the
/// tool's own <method>OcuPilot.Screen.Tool.Write.IdParam</method>.</p>
Parameter NAMESPACEPARAM = "namespace";

/// <p>The query parameter both request types read an enumerated id set from, as the compact JSON
/// of the array <parameter>TYPEENUMERATE</parameter> answered.</p>
/// <p>A <parameter>TYPEDELETE</parameter> whose query carries no such set removes nothing and is
/// refused: re-running the selection at confirm time would delete rows the user never saw
/// (AD-48).</p>
/// <p>A <parameter>TYPEENUMERATE</parameter> whose query carries one answers <b>that set narrowed
/// to the ids the namespace still holds</b>, in the order it was given them, rather than
/// enumerating afresh. That is what the confirm's fingerprint re-read asks: an id another party
/// removed shortens the answer and the digest differs, while an error logged after the proposal is
/// in no given set and leaves it untouched -- the residue AD-48 requires. A mint names no set and
/// gets the whole enumeration.</p>
Parameter ENTRIESPARAM = "entries";

/// <p>The row cap an application-error read is bounded by when its caller names none (AD-36).
/// <b>There is no ceiling</b>: a larger value is honoured, and anything that is not a whole number
/// above zero is refused rather than silently defaulted.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The class that resolves a namespace to its globals database's guarding resource.</p>
Parameter NAMESPACERESOLVER = "OcuPilot.Api.Namespaces";

/// <p>The window size, in bytes, a caller that names none is served.</p>
Parameter DEFAULTMAXBYTES As INTEGER = 65536;

/// <p>The hard server-side ceiling on a window, in bytes (AD-36). No parameter raises it and
/// none disables it; a <code>maxBytes</code> above it is refused, never clamped.</p>
Parameter MAXBYTESCAP As INTEGER = 1048576;

/// <p>How far into the file <method>Identity</method> looks for the first line it hashes. A
/// whole-file hash would change on every append and make every continuation a restart; a first
/// line, once terminated, does not change again while the file lives. A first line longer than
/// this is fingerprinted by its opening bytes, which are equally fixed.</p>
Parameter PREFIXBYTES As INTEGER = 512;

/// <p>The largest single <code>Read</code> this port issues. A single
/// <code>%Stream.FileBinary</code> read returns at most about 32 KB whatever it is asked for, so
/// every window is assembled from chunks of this size.</p>
Parameter CHUNKSIZE As INTEGER = 32000;

/// <p>The grammar a log file's <b>head line</b> takes, which is what
/// <method>Rows</method> projects and what a continuation line is defined as not matching:
/// <code>MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text</code>, the bracketed category
/// optional and the text possibly empty.</p>
/// <p>Both instance log files are written by the same <code>$zu(9)</code> path, so one grammar
/// serves both. <file>ui/src/app/areas/logs/log-line.ts</file> carries the same grammar for the
/// client's own rendering of the raw lines; this one exists because a declared read answers rows
/// rather than lines, and both are pinned against the same seeded file.</p>
Parameter HEADFORM = "^[0-9]{2}/[0-9]{2}/[0-9]{2}-[0-9]{2}:[0-9]{2}:[0-9]{2}:[0-9]{3} \([0-9]+\) -?[0-9]+ .*$";

/// <p>The gate this port evaluates its pair set through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The subsystem name a raw status is logged under.</p>
Parameter LOGSUBSYSTEM = "logsourceport";

/// <p>The source keys this port serves. Overridable so a fixture can drive an unknown key and a
/// second source without waiting for one to ship; production never overrides it.</p>
ClassMethod Sources() As %List
{
    Quit $ListFromString(..#SOURCES)
}

/// <p>The <code>(resource, permission)</code> pair set source <var>pSource</var> requires in
/// namespace <var>pNamespace</var>, as a <code>%List</code> of two-element <code>%List</code>s, or
/// <code>""</code> for a key with no declared requirement and for one whose requirement could not
/// be resolved.</p>
/// <p><b>A function of the source <i>and</i> the namespace, not a class constant</b>, because the
/// application error log's requirement is a function of the namespace selected (AD-48):
/// <code>^ERRORS</code> is unmapped and lives in each namespace's own globals database, so no
/// static descriptor resource can express it. For that source the set is
/// <parameter>ERRORSINSTANCEPAIRS</parameter> followed by
/// <parameter>ERRORSDATABASEPERMISSIONS</parameter> on the resource guarding that namespace's
/// globals database, resolved through <method>NamespaceResolver</method> at call time and never
/// cached (AD-8).</p>
/// <p><b>An unresolvable requirement answers <code>""</code>, never the operate pair alone.</b>
/// The resolver returns 0 when the instance reports no resource for a namespace, which is the one
/// answer that must not be read as "no privilege required"
/// (<class>OcuPilot.Api.Namespaces</class>); an empty answer is refused by the caller rather than
/// passed to the gate, which holds the empty set to be satisfied by everyone.</p>
/// <p><var>pNamespace</var> defaults to <code>""</code>, which is what <method>Page</method>
/// passes: a file source's requirement does not depend on a namespace, and the error source has no
/// namespace to resolve when asked without one, so it answers <code>""</code> and is refused.</p>
/// <p>Overridable for a fixture; production never overrides it.</p>
ClassMethod PairsFor(pSource As %String, pNamespace As %String = "") As %List
{
    Set tDeclared = ""
    If pSource = ..#MESSAGESKEY Set tDeclared = ..#MESSAGESPAIRS
    If pSource = ..#ALERTSKEY Set tDeclared = ..#ALERTSPAIRS
    If pSource = ..#ERRORSKEY Set tDeclared = ..ErrorPairSpec(pNamespace)
    Quit ..ParsePairs(tDeclared)
}

/// <p>The comma-separated <code>resource:permission</code> specification the application error log
/// requires in <var>pNamespace</var>, or <code>""</code> when that namespace's globals database
/// reports no guarding resource -- or when no namespace was named at all, which is the same
/// condition seen one step earlier.</p>
/// <p>Called <b>before</b> the port enters <code>%SYS</code>: the resolver is an
/// <code>OcuPilot.*</code> class, and a dispatch to one from inside that window fails with
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code>. It needs no namespace switch of its own.</p>
ClassMethod ErrorPairSpec(pNamespace As %String) As %String [ Private ]
{
    If pNamespace = "" Quit ""
    Set tResource = ""
    If '$ClassMethod(..NamespaceResolver(), "GlobalDatabase", pNamespace, .tResource, .tReadOnly) Quit ""
    If tResource = "" Quit ""
    Set tSpec = ..#ERRORSINSTANCEPAIRS
    For tI = 1:1:$Length(..#ERRORSDATABASEPERMISSIONS, ",") {
        Set tPermission = $Piece(..#ERRORSDATABASEPERMISSIONS, ",", tI)
        If tPermission = "" Continue
        Set tSpec = tSpec _ "," _ tResource _ ":" _ tPermission
    }
    Quit tSpec
}

/// <p>The pair set <parameter>ERRORSINSTANCEPAIRS</parameter> names: what
/// <code>NamespaceList</code> requires, and the leading pairs of every per-namespace set, so a
/// caller short of one of them is named that pair whichever level it asked for.</p>
ClassMethod InstancePairs() As %List [ Private ]
{
    Quit ..ParsePairs(..#ERRORSINSTANCEPAIRS)
}

/// <p><var>pDeclared</var>, a comma-separated list of <code>resource:permission</code>, as the
/// <code>%List</code> of two-element <code>%List</code>s the gate evaluates. Shared by every pair
/// set this port declares so one spelling cannot be read two ways.</p>
ClassMethod ParsePairs(pDeclared As %String) As %List [ Private ]
{
    Set tPairs = ""
    For tI = 1:1:$Length(pDeclared, ",") {
        Set tPair = $Piece(pDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

/// <p>The drill levels <method>Errors</method> serves. Overridable for a fixture; production never
/// overrides it.</p>
ClassMethod ErrorLevels() As %List
{
    Quit $ListFromString(..#ERRORLEVELS)
}

/// <p>The vendor class whose queries the application error log is read through (AD-48).
/// Overridable so a fixture can point the port at a query class it owns, and so the fixture's own
/// counters have a seam to hang on; production never overrides it.</p>
ClassMethod QueryClass() As %String
{
    Quit ..#ERRORSQUERYCLASS
}

/// <p>The query name the captured detail is read through. Overridable so a fixture can count its
/// executions, which is this story's secrecy witness: the counter must read 0 across the
/// namespaces, dates, list and read-tool paths and non-zero only on the detail path.</p>
ClassMethod DetailQuery() As %String
{
    Quit ..#ERRORDETAILQUERY
}

/// <p>The class that answers a namespace's globals-database resource. Overridable so a fixture can
/// drive a namespace whose resource resolves to nothing -- the answer that must be refused rather
/// than admitted on an empty pair set. Production never overrides it.</p>
ClassMethod NamespaceResolver() As %String
{
    Quit ..#NAMESPACERESOLVER
}

/// <p>Open a <class>%ResultSet</class> over <method>QueryClass</method>'s query
/// <var>pQueryName</var>. <b>The port's one query construction point</b>, so a fixture counts
/// executions here rather than at four call sites.</p>
/// <p><b>Caller contract:</b> <code>$NAMESPACE</code> must already be
/// <parameter>ERRORSNAMESPACE</parameter> -- the class exists nowhere else, and a result set built
/// against it from the install namespace comes back as no object at all.</p>
ClassMethod OpenQuery(pQueryName As %String, Output pResultSet As %ResultSet) As %Status
{
    Set tSC = $$$OK
    Set pResultSet = ""
    Try {
        Set tRS = ##class(%ResultSet).%New(..QueryClass() _ ":" _ pQueryName)
        If '$IsObject(tRS) {
            Set tSC = $$$ERROR($$$GeneralError, "the application error log query could not be constructed")
            Quit
        }
        Set pResultSet = tRS
    } Catch ex {
        Set pResultSet = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The file name source <var>pSource</var> reads, or <code>""</code> for a key this port has
/// no file for. A name only -- the directory is <method>ManagerDirectory</method>'s.</p>
/// <p>Overridable for a fixture; production never overrides it.</p>
ClassMethod FileFor(pSource As %String) As %String
{
    If pSource = ..#MESSAGESKEY Quit ..#MESSAGESFILE
    If pSource = ..#ALERTSKEY Quit ..#ALERTSFILE
    Quit ""
}

/// <p>The instance's manager directory, resolved on <b>every</b> call and never cached (AD-21:
/// the console log's location is operator-settable, so a cached directory is a path that can go
/// stale under a running request).</p>
/// <p>Overridable so a fixture can point the port at a directory it owns; production never
/// overrides it.</p>
ClassMethod ManagerDirectory() As %String
{
    Quit $System.Util.ManagerDirectory()
}

/// <p>The hard byte ceiling on a window. Overridable so a fixture can drive the cap refusal
/// without asking for a megabyte; production never overrides it.</p>
ClassMethod MaxBytesCap() As %Integer
{
    Quit ..#MAXBYTESCAP
}

/// <p>The class <method>Gate</method> evaluates the pair set through. Overridable so a fixture
/// can drive a denial in process -- <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real <code>$System.Security.Check</code> answers yes to every
/// resource. The real check is exercised over the wire by
/// <class>OcuPilot.Test.LogSourceDenial</class>. Production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Whether <var>pPath</var> is present. <b>The port's first filesystem touch</b>, and one of
/// only two; a fixture overrides it to count them, which is what makes "nothing above the gate
/// reaches the filesystem" an observation rather than an assertion against nothing.</p>
ClassMethod FileExists(pPath As %String) As %Boolean
{
    Quit ''##class(%File).Exists(pPath)
}

/// <p>Open <var>pPath</var> for reading. The port's other filesystem touch.</p>
ClassMethod OpenStream(pPath As %String, Output pStream As %Stream.Object) As %Status
{
    Set tSC = $$$OK
    Set pStream = ""
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(pPath)
        If $$$ISERR(tSC) Quit
        Set pStream = tStream
    } Catch ex {
        Set pStream = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Send a raw status to the log, and nowhere else (AD-39).</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>Serve one bounded page of whole lines from log source <var>pSource</var>.</p>
/// <p><var>pOffset</var> and <var>pIdentity</var> are a page's returned cursor, supplied together
/// or not at all; with neither, the page is the <b>last</b> <var>pMaxBytes</var> of the file.
/// <var>pMaxBytes</var> defaults to <parameter>DEFAULTMAXBYTES</parameter> and is refused above
/// <method>MaxBytesCap</method>.</p>
/// <p>On success <var>pResult</var> carries <code>source</code>, <code>lines</code>,
/// <code>offset</code> (the byte the next call passes back, 1-based), <code>identity</code>,
/// <code>size</code>, <code>restarted</code> and <code>truncated</code> (true when the page did
/// not reach the end of the file), and <var>pHttpStatus</var> is 200. Otherwise an error
/// <class>%Status</class> is returned with <var>pResult</var> empty, <var>pHttpStatus</var> the
/// numeric status to answer with and <var>pFault</var> the wire fault
/// <code>{error, reason, code}</code>, plus <code>detail</code> when there is one.</p>
/// <p>Caller contract: <var>pOffset</var>, <var>pMaxBytes</var> and <var>pIdentity</var> arrive
/// as caller text and are validated here, so a handler passes a query parameter through
/// unchanged. Must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Page(pSource As %String = "", pOffset As %String = "", pMaxBytes As %String = "", pIdentity As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '$ListFind(..Sources(), pSource) {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve a log source by that name", .pHttpStatus, .pFault)
            Quit
        }

        Set tPairs = ..PairsFor(pSource)
        If '$ListValid(tPairs) || ($ListLength(tPairs) = 0) {
            ; A source whose requirement is empty or unreadable is refused here rather than
            ; handed to the gate. No pair is named: there is none to report.
            Set tSC = ..DeniedRefusal("", .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        If '..Gate(tPairs, .tFailedPair) {
            Set tSC = ..DeniedRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }

        Set tMaxBytes = ..#DEFAULTMAXBYTES
        If pMaxBytes '= "" {
            If ('$Match(pMaxBytes, "^[0-9]+$")) || (+pMaxBytes = 0) || (+pMaxBytes > ..MaxBytesCap()) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGMAXBYTES, "maxBytes must be a whole number of bytes above zero and no larger than the cap this endpoint serves", .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxBytes = +pMaxBytes
        }

        Set tHasCursor = (pOffset '= "")
        If tHasCursor '= (pIdentity '= "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGOFFSET, "offset and identity are a page's cursor and travel together; supply both or neither", .pHttpStatus, .pFault)
            Quit
        }
        If tHasCursor && (('$Match(pOffset, "^[0-9]+$")) || (+pOffset < 1)) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGOFFSET, "offset must be a whole number of bytes from one upwards", .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Resolve(pSource, .tPath, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tOpenSC = ..OpenStream(tPath, .tStream)
        If $$$ISERR(tOpenSC) || '$IsObject(tStream) {
            Set tSC = ..Unreadable(tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tIdentitySC = ..Identity(tStream, .tSize, .tIdentity)
        If $$$ISERR(tIdentitySC) {
            Set tSC = ..Unreadable(tIdentitySC, .pHttpStatus, .pFault)
            Quit
        }

        ; Two independent restart conditions, either of which alone restarts: the file is not the
        ; one the cursor was taken from, and the cursor is past the end of the file it names.
        Set tRestarted = 0
        If 'tHasCursor {
            Set tStart = tSize - tMaxBytes + 1
            If tStart < 1 Set tStart = 1
        } Else {
            Set tStart = +pOffset
            If (pIdentity '= tIdentity) || (tStart > (tSize + 1)) {
                Set tRestarted = 1
                Set tStart = 1
            }
        }

        Set tWindowSC = ..ReadWindow(tStream, tStart, tMaxBytes, tSize, .tLines, .tNextOffset, .tTruncated)
        If $$$ISERR(tWindowSC) {
            Set tSC = ..Unreadable(tWindowSC, .pHttpStatus, .pFault)
            Quit
        }

        Set pResult = {}
        Do pResult.%Set("source", pSource)
        Do pResult.%Set("lines", tLines)
        Do pResult.%Set("offset", tNextOffset, "number")
        Do pResult.%Set("identity", tIdentity)
        Do pResult.%Set("size", tSize, "number")
        Do pResult.%Set("restarted", ''tRestarted, "boolean")
        Do pResult.%Set("truncated", ''tTruncated, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pSource _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The same bounded tail <method>Page</method> serves, projected into the rows a declared read
/// names (AD-36): at most <var>pMaxRows</var> objects carrying <code>time</code>,
/// <code>severity</code> and <code>text</code>, <b>newest first</b>.</p>
/// <p><b>Newest first, because the caller keeps the first rows it is given.</b>
/// <method>OcuPilot.Screen.Read.Execute</method> asks for one more row than its cap and keeps that
/// many from the front, so a list in file order would answer the oldest entries in the window and
/// drop the ones a reader opened the screen for.</p>
/// <p>A line matching <parameter>HEADFORM</parameter> opens an entry; any other line is a
/// continuation and is appended to the entry above it, newline-separated. A window that opens
/// mid-continuation yields a leading entry with no time and no severity rather than dropping those
/// bytes. <code>time</code> is the file's own local <code>YYYY-MM-DDTHH:MM:SS.mmm</code> with no
/// zone suffix, because the file writes local time and nothing converts it.</p>
/// <p>The gate, the source enum and the window bound are <method>Page</method>'s, evaluated in its
/// own order; this adds no privilege and no file access of its own. <var>pMaxRows</var> at or below
/// zero means the whole window.</p>
/// <p><b>A log the instance has not written yet is an empty read, not a failed one.</b>
/// <method>Page</method> answers 404 <code>LOG.ABSENT</code> for a file that is not there, because a
/// caller paging a file by byte offset asked for a file; a declared read asked for the instance's
/// entries, and a fresh instance that has raised no alert has none. Every other refusal --
/// the gate's included -- passes through unchanged.</p>
ClassMethod Rows(pSource As %String = "", pMaxRows As %Integer = 0, Output pAnswer As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Page(pSource, "", "", "", .tPage, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            If $Select($IsObject(pFault): pFault.%Get("code"), 1: "") '= ##class(OcuPilot.Api.Error).#LOGABSENT Quit
            Set tSC = $$$OK
            Set pFault = ""
            Set pAnswer = []
            Set pHttpStatus = 200
            Quit
        }
        Set pAnswer = ..Entries(tPage.lines, pMaxRows)
        Set pHttpStatus = 200
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail(pSource _ " rows failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One window's <var>pLines</var> as at most <var>pMaxRows</var> row objects, newest first.
/// See <method>Rows</method> for the grammar and for why the order is reversed.</p>
ClassMethod Entries(pLines As %DynamicArray, pMaxRows As %Integer = 0) As %DynamicArray [ Private ]
{
    Kill tHeld
    Set tCount = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If ..HeadParts(tLine, .tTime, .tSeverity, .tText) {
            Set tCount = tCount + 1
            Set tHeld(tCount, "time") = tTime
            Set tHeld(tCount, "severity") = tSeverity
            Set tHeld(tCount, "text") = tText
            Continue
        }
        If tCount = 0 {
            Set tCount = 1
            Set tHeld(1, "time") = ""
            Set tHeld(1, "severity") = ""
            Set tHeld(1, "text") = tLine
            Continue
        }
        Set tHeld(tCount, "text") = tHeld(tCount, "text") _ $Char(10) _ tLine
    }

    Set tWanted = pMaxRows
    If tWanted < 1 Set tWanted = tCount
    Set tRows = []
    For tAt = tCount:-1:1 {
        If tRows.%Size() >= tWanted Quit
        Set tRow = {}
        Do tRow.%Set("time", tHeld(tAt, "time"))
        Do tRow.%Set("severity", tHeld(tAt, "severity"))
        Do tRow.%Set("text", tHeld(tAt, "text"))
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Whether <var>pLine</var> is a head line, and its three projected parts when it is.</p>
/// <p>The parts are read by position rather than by capture group: the stamp is fixed-width, the
/// pid ends at the first <code>)</code> and the severity at the space after it. The bracketed
/// category is stripped only when the line opens with <code>[</code> and the <b>first</b>
/// <code>]</code> is followed by a space -- the same span
/// <file>ui/src/app/areas/logs/log-line.ts</file>'s <code>HEAD_RE</code> strips with its optional
/// group, so a message that merely contains <code>] </code> keeps it.</p>
ClassMethod HeadParts(pLine As %String, Output pTime As %String, Output pSeverity As %String, Output pText As %String) As %Boolean [ Private ]
{
    Set pTime = ""
    Set pSeverity = ""
    Set pText = ""
    If '$Match(pLine, ..#HEADFORM) Quit 0

    Set tYear = +$Extract(pLine, 7, 8)
    Set tYear = $Select(tYear < 70: 2000 + tYear, 1: 1900 + tYear)
    Set pTime = tYear _ "-" _ $Extract(pLine, 1, 2) _ "-" _ $Extract(pLine, 4, 5) _ "T" _ $Extract(pLine, 10, 17) _ "." _ $Extract(pLine, 19, 21)

    Set tAfterPid = $Extract($Piece($Extract(pLine, 24, *), ")", 2, *), 2, *)
    Set pSeverity = $Piece(tAfterPid, " ", 1)
    Set pText = $Piece(tAfterPid, " ", 2, *)
    Set tCloseAt = $Find(pText, "]")
    If ($Extract(pText, 1) = "[") && (tCloseAt > 0) && ($Extract(pText, tCloseAt) = " ") {
        Set pText = $Extract(pText, tCloseAt + 1, *)
    }
    Quit 1
}

/// <p>Serve one level of the application error log (AD-48). <var>pLevel</var> is one of
/// <parameter>ERRORLEVELS</parameter>, bound by the route and never read from the request.</p>
/// <p><b>The step order is fixed and load-bearing</b>: source enum, level, <var>pMaxRows</var>,
/// the <parameter>ERRORSINSTANCEPAIRS</parameter> gate, the namespace against
/// <code>NamespaceList</code>, the per-namespace pair set and <b>its</b> gate, the date against
/// <code>DateList</code>, the error number against <code>ErrorList</code>, then the level's own
/// query. Nothing the caller supplies is used before the instance's own enumeration for the level
/// above it has answered with it (AD-21), and no query scoped to the target namespace runs before
/// the gate has answered (AD-29).</p>
/// <p><b>Where each half of the gate happens, and why.</b> The pair set is resolved and evaluated
/// <i>before</i> the <code>%SYS</code> window opens -- <class>OcuPilot.Api.Namespaces</class> and
/// <class>OcuPilot.Screen.Gate</class> are <code>OcuPilot.*</code> classes and a dispatch to one
/// from inside that window fails with <code>&lt;CLASS DOES NOT EXIST&gt;</code> -- so every
/// <code>$System.Security.Check</code> this call makes precedes every query it makes. Its
/// <i>answer</i> is acted on inside the window, after the namespace membership test, because an
/// unknown namespace is refused before the gate's verdict is reported (the matrix's own order).
/// <code>NamespaceList</code> is the only query above that point, and it is the enumeration the
/// namespace is chosen from, gated by <parameter>ERRORSINSTANCEPAIRS</parameter> alone.</p>
/// <p>On success <var>pResult</var> carries, per level: <code>{rows, truncated}</code> for
/// <parameter>LEVELNAMESPACES</parameter>; <code>{namespace, rows, truncated}</code> for
/// <parameter>LEVELDATES</parameter>; <code>{namespace, date, rows, truncated}</code> for
/// <parameter>LEVELLIST</parameter>; and
/// <code>{expressions, stack, variables, truncated}</code> for
/// <parameter>LEVELDETAIL</parameter>. <var>pHttpStatus</var> is 200. Otherwise an error
/// <class>%Status</class> is returned with <var>pResult</var> empty, <var>pHttpStatus</var> the
/// numeric status to answer with and <var>pFault</var> the wire fault.</p>
/// <p>Caller contract: every argument arrives as caller text and is validated here, so a handler
/// passes a query parameter through unchanged. <b>No route scope reaches this method</b>: the
/// namespace travels under this endpoint's own parameter and has exactly one source, the level the
/// user drilled to (AD-48). Must not be called from an escalated frame (AD-9); the caller's
/// namespace is unchanged on return.</p>
ClassMethod Errors(pLevel As %String = "", pNamespace As %String = "", pDate As %String = "", pErrorNumber As %String = "", pMaxRows As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '$ListFind(..Sources(), ..#ERRORSKEY) {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve a log source by that name", .pHttpStatus, .pFault)
            Quit
        }
        If '$ListFind(..ErrorLevels(), pLevel) {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve that level of the application error log", .pHttpStatus, .pFault)
            Quit
        }

        Set tMaxRows = ..#DEFAULTMAXROWS
        If pMaxRows '= "" {
            If '$Match(pMaxRows, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGMAXROWS, "maxRows must be a whole number above zero", .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxRows = +pMaxRows
        }

        Set tFailedPair = ""
        If '..Gate(..InstancePairs(), .tFailedPair) {
            Set tSC = ..DeniedRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }

        ; Resolved and evaluated out here, where an OcuPilot class still resolves. The window
        ; below reads the two answers and nothing more.
        Set tNeedsNamespace = (pLevel '= ..#LEVELNAMESPACES)
        Set tResolved = 1
        Set tGateOk = 1
        If tNeedsNamespace {
            Set tPairs = ..PairsFor(..#ERRORSKEY, pNamespace)
            Set tResolved = $ListValid(tPairs) && ($ListLength(tPairs) > 0)
            If tResolved {
                Set tGateOk = ..Gate(tPairs, .tFailedPair)
            } Else {
                Set tGateOk = 0
            }
        }

        Set tReadSC = ..ErrorsRead(pLevel, pNamespace, pDate, pErrorNumber, tMaxRows, tResolved, tGateOk, .tOutcome, .tResult)
        If $$$ISERR(tReadSC) {
            Set tSC = ..Fail("the application error log could not be read", tReadSC, .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "namespace" {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGNAMESPACE, "This instance records no application errors for a namespace by that name", .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "unresolvable" {
            ; No pair is named: the instance reports no resource guarding that namespace's globals
            ; database, so there is none to report -- and "no resource" is never "no privilege
            ; required" (OcuPilot.Api.Namespaces).
            Set tSC = ..DeniedRefusal("", .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "denied" {
            Set tSC = ..DeniedRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "date" {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGDATE, "This instance records no application errors for that date in that namespace", .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "entry" {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGENTRY, "That application error is not recorded for that namespace and date", .pHttpStatus, .pFault)
            Quit
        }
        If '$IsObject(tResult) {
            Set tSC = ..Fail("the application error log answered no payload", $$$ERROR($$$GeneralError, "no payload"), .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = tResult
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the application error log failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The write path's port-uniform entry point (AD-52): one endpoint, two request types, the same
/// signature <method>OcuPilot.Port.AdminPort.Invoke</method> answers, so the mint's fresh read, the
/// confirm's fingerprint re-read, the prohibited set's live read and the confirmed write all reach
/// this port exactly as they reach that one.</p>
/// <p><var>pEndpoint</var> is <parameter>ENDPOINTERRORS</parameter> and <var>pType</var> is
/// <parameter>TYPEENUMERATE</parameter> or <parameter>TYPEDELETE</parameter>; anything else is
/// <code>PORT.NOTIMPLEMENTED</code>. <var>pQuery</var> carries the target namespace under
/// <parameter>NAMESPACEPARAM</parameter> and, for the delete, the enumerated id set under
/// <parameter>ENTRIESPARAM</parameter>. <var>pBody</var> is unread: neither type takes one.</p>
/// <p><var>pResult</var> is a <class>%DynamicObject</class> on success and <code>""</code> on every
/// refusal, with <var>pHttpStatus</var> the numeric status and <var>pFault</var> the wire fault
/// (AD-12, AD-39).</p>
/// <p><b>The gate is the read's</b> -- <method>PairsFor</method> on the target namespace, resolved
/// outside the <code>%SYS</code> window and evaluated before any query runs, so a delete meets the
/// same <code>(resource, permission)</code> set a read of that namespace does and the WRITE half
/// this port has always declared is the half that decides it (AD-8, AD-29, AD-48).</p>
/// <p>Must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If (pEndpoint '= ..#ENDPOINTERRORS) || ((pType '= ..#TYPEENUMERATE) && (pType '= ..#TYPEDELETE)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEPARAM))
        Set tEntries = $Get(pQuery(..#ENTRIESPARAM))
        Set tSC = ..ErrorSet(pType, tNamespace, tEntries, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the application error log failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One <method>Invoke</method> call, gated and answered: the enumeration for
/// <parameter>TYPEENUMERATE</parameter>, the removal for <parameter>TYPEDELETE</parameter>.</p>
/// <p>The gate order is <method>Errors</method>'s, for its reasons: the instance pairs first, then
/// the per-namespace set resolved <b>outside</b> the <code>%SYS</code> window, then the window,
/// whose first act is to resolve the namespace against the instance's own enumeration.</p>
ClassMethod ErrorSet(pType As %String, pNamespace As %String, pEntries As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tFailedPair = ""
        If '..Gate(..InstancePairs(), .tFailedPair) {
            Set tSC = ..DeniedRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tPairs = ..PairsFor(..#ERRORSKEY, pNamespace)
        Set tResolved = $ListValid(tPairs) && ($ListLength(tPairs) > 0)
        Set tGateOk = 0
        If tResolved Set tGateOk = ..Gate(tPairs, .tFailedPair)

        Set tReadSC = ..ErrorSetRun(pType, pNamespace, pEntries, tResolved, tGateOk, .tOutcome, .tResult)
        If $$$ISERR(tReadSC) {
            Set tSC = ..Fail("the application error log could not be " _ $Select(pType = ..#TYPEDELETE: "purged", 1: "enumerated"), tReadSC, .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "namespace" {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGNAMESPACE, "This instance records no application errors for a namespace by that name", .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "unresolvable" {
            Set tSC = ..DeniedRefusal("", .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "denied" {
            Set tSC = ..DeniedRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If tOutcome = "entries" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGENTRY, "This delete names no application errors to remove", .pHttpStatus, .pFault)
            Quit
        }
        If '$IsObject(tResult) {
            Set tSC = ..Fail("the application error log answered no payload", $$$ERROR($$$GeneralError, "no payload"), .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = tResult
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the application error log failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The one <code>%SYS</code> window an enumeration or a removal takes (AD-16), entered once and
/// restored on both paths and as the <b>first</b> line of the <code>Catch</code>, never entered
/// into the namespace being acted on -- that one travels as each query's and each delete's own
/// first parameter.</p>
/// <p><b>Nothing here dispatches an <code>OcuPilot.*</code> class.</b> <var>pOutcome</var> is a
/// word the caller turns into a refusal after the restore.</p>
/// <p><var>pResolved</var> and <var>pGateOk</var> are the pair set's own answers, taken before this
/// window opened and read after the namespace membership test, which is what "the gate runs before
/// any per-namespace query" means in execution order.</p>
ClassMethod ErrorSetRun(pType As %String, pNamespace As %String, pEntries As %String, pResolved As %Boolean, pGateOk As %Boolean, Output pOutcome As %String, Output pResult As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pOutcome = ""
    Set pResult = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#ERRORSNAMESPACE

        Set tSC = ..NamespaceSpelling(pNamespace, .tSpelling)
        If $$$ISERR(tSC) Quit
        If tSpelling = "" {
            Set pOutcome = "namespace"
            Quit
        }
        If 'pResolved {
            Set pOutcome = "unresolvable"
            Quit
        }
        If 'pGateOk {
            Set pOutcome = "denied"
            Quit
        }

        If pType = ..#TYPEENUMERATE {
            If pEntries '= "" {
                Set tSC = ..SurvivingIdRows(tSpelling, pEntries, .tEntries)
                Set tTruncated = 0
            } Else {
                Set tSC = ..ErrorIdRows(tSpelling, ..#DEFAULTMAXROWS, .tEntries, .tTruncated)
            }
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set("namespace", tSpelling)
            Do pResult.%Set("entries", tEntries)
            Do pResult.%Set("count", tEntries.%Size(), "number")
            Do pResult.%Set("truncated", ''tTruncated, "boolean")
            Quit
        }

        Set tSC = ..RemoveErrorIds(tSpelling, pEntries, .tRemoved, .tDates)
        If $$$ISERR(tSC) Quit
        If tRemoved = 0 {
            Set pOutcome = "entries"
            Quit
        }
        Set pResult = {}
        Do pResult.%Set("namespace", tSpelling)
        Do pResult.%Set("removed", tRemoved, "number")
        Do pResult.%Set("dates", tDates, "number")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pOutcome = ""
        Set pResult = ""
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The instance's own spelling of <var>pNamespace</var> in <var>pSpelling</var>, or
/// <code>""</code> for a name <code>NamespaceList</code> does not answer with.</p>
/// <p><b>The match folds case and the answer does not.</b> An <code>application-error</code>
/// reference canonicalizes its id to lower case (AD-13), because
/// <code>SYS.ApplicationError</code> resolves a namespace case-insensitively -- measured
/// 2026-09-22, six identical <code>DateList</code> rows for <code>HSCUSTOM</code>,
/// <code>hscustom</code> and <code>HsCustom</code> -- so the mint is handed the agent's spelling and
/// the confirm the canonical one. Answering the instance's own spelling to both is what makes the
/// enumeration, and so the fingerprint taken over it, the same value at both ends.</p>
/// <p><b>Caller contract:</b> <code>$NAMESPACE</code> is already
/// <parameter>ERRORSNAMESPACE</parameter>.</p>
ClassMethod NamespaceSpelling(pNamespace As %String, Output pSpelling As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pSpelling = ""
    Set tRS = ""
    Try {
        If pNamespace = "" Quit
        Set tWanted = $ZConvert(pNamespace, "U")
        Set tSC = ..OpenQuery(..#NAMESPACELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(..#NAMESPACELISTALL)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If $ZConvert(tRS.Get("Namespace"), "U") = tWanted {
                Set pSpelling = tRS.Get("Namespace")
                Quit
            }
        }
    } Catch ex {
        Set pSpelling = ""
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>Every <code>(date, errorNumber)</code> <var>pNamespace</var> holds, in <var>pRows</var>, in
/// the order <code>DateList</code> and <code>ErrorList</code> answer them, bounded by
/// <var>pMaxRows</var> across the whole set with <var>pTruncated</var> true when it was cut.</p>
/// <p><b>It is the identifying triple and nothing else</b> (AD-48). The row carries no error text,
/// no routine, no code line and no captured payload: this set is what a proposal stores, digests
/// and shows, and none of those surfaces is one the captured variable table may reach (AD-24,
/// AD-35).</p>
/// <p><b>Caller contract:</b> <code>$NAMESPACE</code> is already
/// <parameter>ERRORSNAMESPACE</parameter> and <var>pNamespace</var> is the instance's own
/// spelling.</p>
ClassMethod ErrorIdRows(pNamespace As %String, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pTruncated = 0
    Set tDates = ""
    Set tRS = ""
    Try {
        Set tSC = ..OpenQuery(..#DATELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            Set tDate = tRS.Get("Date")
            If tDate = "" Continue
            Set tDates = tDates _ $ListBuild(tDate)
        }
        Do tRS.Close()
        Set tRS = ""

        For tI = 1:1:$ListLength(tDates) {
            Set tDate = $List(tDates, tI)
            Set tSC = ..OpenQuery(..#ERRORLISTQUERY, .tRS)
            If $$$ISERR(tSC) Quit
            Set tSC = tRS.Execute(pNamespace, tDate)
            If $$$ISERR(tSC) Quit
            While tRS.Next() {
                If pRows.%Size() >= pMaxRows {
                    Set pTruncated = 1
                    Quit
                }
                Set tRow = {}
                Do tRow.%Set("date", tDate)
                Do tRow.%Set("errorNumber", +tRS.Get("Error #"), "number")
                Do pRows.%Push(tRow)
            }
            Do tRS.Close()
            Set tRS = ""
            If pTruncated Quit
        }
    } Catch ex {
        Set pRows = []
        Set pTruncated = 0
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>The entries <var>pEntriesJson</var> names that <var>pNamespace</var> still holds, in
/// <var>pRows</var>, in the order they were given -- so an id that has gone shortens the answer
/// and nothing else about the namespace can change it.</p>
/// <p><b>Presence is asked per named date, never through the capped enumeration.</b> A namespace
/// holding more than <parameter>DEFAULTMAXROWS</parameter> errors would answer a cut set, and an
/// id beyond the cut would read as removed -- refusing a confirm over an error that is still
/// there.</p>
/// <p><b>Caller contract:</b> <code>$NAMESPACE</code> is already
/// <parameter>ERRORSNAMESPACE</parameter> and <var>pNamespace</var> is the instance's own
/// spelling.</p>
ClassMethod SurvivingIdRows(pNamespace As %String, pEntriesJson As %String, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set tRS = ""
    Try {
        Set tSC = ..RequestedIds(pEntriesJson, .tByDate, .tOrder, .tRequested)
        If $$$ISERR(tSC) Quit
        Kill tPresent
        For tI = 1:1:$ListLength(tOrder) {
            Set tDate = $List(tOrder, tI)
            Set tSC = ..OpenQuery(..#ERRORLISTQUERY, .tRS)
            If $$$ISERR(tSC) Quit
            Set tSC = tRS.Execute(pNamespace, tDate)
            If $$$ISERR(tSC) Quit
            While tRS.Next() {
                Set tPresent(tDate, +tRS.Get("Error #")) = ""
            }
            Do tRS.Close()
            Set tRS = ""
        }
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tRequested) {
            Set tEntry = $List(tRequested, tI)
            Set tDate = $List(tEntry, 1)
            Set tNumber = $List(tEntry, 2)
            If '$Data(tPresent(tDate, tNumber)) Continue
            Set tRow = {}
            Do tRow.%Set("date", tDate)
            Do tRow.%Set("errorNumber", tNumber, "number")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p><var>pEntriesJson</var> read as an id set: <var>pByDate</var> the comma-separated error
/// numbers per date, <var>pOrder</var> the dates in the order they first appear, and
/// <var>pRequested</var> the whole set as <code>$ListBuild(date, number)</code> pairs in the order
/// given.</p>
/// <p>An entry carrying no date or no whole error number above zero is an error, never a skipped
/// row: a set this method cannot read whole is one no caller may act on part of.</p>
ClassMethod RequestedIds(pEntriesJson As %String, Output pByDate, Output pOrder As %List, Output pRequested As %List) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pByDate
    Set pOrder = ""
    Set pRequested = ""
    Try {
        Set tParsed = ""
        If pEntriesJson '= "" Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pEntriesJson)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tParsed.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) Continue
            Set tDate = tEntry.%Get("date")
            Set tNumber = tEntry.%Get("errorNumber")
            If (tDate = "") || '$Match(tNumber, "^[1-9][0-9]*$") {
                Set tSC = $$$ERROR($$$GeneralError, "an enumerated application error carried no date or no error number")
                Quit
            }
            If '$Data(pByDate(tDate)) {
                Set pByDate(tDate) = ""
                Set pOrder = pOrder _ $ListBuild(tDate)
            }
            If pByDate(tDate) '= "" Set pByDate(tDate) = pByDate(tDate) _ ","
            Set pByDate(tDate) = pByDate(tDate) _ +tNumber
            Set pRequested = pRequested _ $ListBuild($ListBuild(tDate, +tNumber))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Kill pByDate
        Set pOrder = ""
        Set pRequested = ""
    }
    Quit tSC
}

/// <p>Remove exactly the ids <var>pEntriesJson</var> names from <var>pNamespace</var>, through
/// <code>SYS.ApplicationError</code>'s <code>DeleteByError</code> once per enumerated date, with
/// how many ids were named in <var>pRemoved</var> and how many dates in <var>pDates</var>.</p>
/// <p><b><code>DeleteByNamespace</code> is not what this calls, and that is the point</b> (AD-48).
/// It removes every error in the namespace for every date, which would destroy rows logged after
/// the proposal and never shown to the user -- the outcome the enumerated-id-set fingerprint exists
/// to prevent. <code>DeleteByError</code> takes a comma-separated list of error numbers for one
/// date (the vendor's own doc comment), so one call per date removes exactly the reviewed set and
/// leaves the residue.</p>
/// <p><b>Caller contract:</b> <code>$NAMESPACE</code> is already
/// <parameter>ERRORSNAMESPACE</parameter> and <var>pNamespace</var> is the instance's own spelling.
/// An entry list that names nothing leaves <var>pRemoved</var> 0 and deletes nothing, which the
/// caller refuses.</p>
/// <p><b><var>pRemoved</var> is how many ids were named, not how many rows the vendor removed</b>
/// -- <code>DeleteByError</code> answers a status and no count, and an id another party removed
/// between the fingerprint re-read and this call is named here and counted. Nothing may report it
/// to a user as a measurement. On a failure part-way through a multi-date set it is reset to 0
/// while the dates before the failure are already gone, so the error the caller raises means "this
/// delete did not complete", never "nothing was removed".</p>
ClassMethod RemoveErrorIds(pNamespace As %String, pEntriesJson As %String, Output pRemoved As %Integer, Output pDates As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRemoved = 0
    Set pDates = 0
    Try {
        Set tSC = ..RequestedIds(pEntriesJson, .tByDate, .tOrder, .tRequested)
        If $$$ISERR(tSC) Quit
        Set pRemoved = $ListLength(tRequested)
        For tI = 1:1:$ListLength(tOrder) {
            Set tDate = $List(tOrder, tI)
            Set tSC = $ClassMethod(..QueryClass(), ..#DELETEBYERRORMETHOD, pNamespace, tDate, tByDate(tDate))
            If $$$ISERR(tSC) Quit
            Set pDates = pDates + 1
        }
        If $$$ISERR(tSC) Set pRemoved = 0
    } Catch ex {
        Set pRemoved = 0
        Set pDates = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 403 a refused pair set answers with, naming <var>pFailedPair</var> as the envelope's
/// <code>detail.failedPair</code> when there is one to name (AD-8, AD-39).</p>
/// <p>The code, the sentence and the detail are <class>OcuPilot.Kernel.Denial</class>'s, so this
/// port's refusal and the one a screen read or a tool call produces for the same missing pair are
/// the same refusal.</p>
ClassMethod DeniedRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair))
}

/// <p>The one <code>%SYS</code> window an application-error read takes (AD-16): entered once,
/// restored on both paths and as the <b>first</b> line of the <code>Catch</code>, and never
/// entered into the namespace being read -- that one travels as each query's own first
/// parameter.</p>
/// <p><b>Nothing here dispatches an <code>OcuPilot.*</code> class.</b> Every refusal
/// <var>pOutcome</var> names is built by the caller after the restore; what this method answers is
/// a word and, on success, the payload's rows.</p>
/// <p><var>pResolved</var> and <var>pGateOk</var> are the pair set's own answers, taken before this
/// window opened. They are read after the namespace membership test and before the first query
/// scoped to <var>pNamespace</var>, which is what "the gate runs before any per-namespace query"
/// means in execution order.</p>
ClassMethod ErrorsRead(pLevel As %String, pNamespace As %String, pDate As %String, pErrorNumber As %String, pMaxRows As %Integer, pResolved As %Boolean, pGateOk As %Boolean, Output pOutcome As %String, Output pResult As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pOutcome = ""
    Set pResult = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#ERRORSNAMESPACE

        If pLevel = ..#LEVELNAMESPACES {
            Set tSC = ..NamespaceRows(pMaxRows, .tRows, .tTruncated)
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set("rows", tRows)
            Do pResult.%Set("truncated", ''tTruncated, "boolean")
            Quit
        }

        Set tSC = ..NamespaceHeld(pNamespace, .tHeldNamespace)
        If $$$ISERR(tSC) Quit
        If 'tHeldNamespace {
            Set pOutcome = "namespace"
            Quit
        }
        If 'pResolved {
            Set pOutcome = "unresolvable"
            Quit
        }
        If 'pGateOk {
            Set pOutcome = "denied"
            Quit
        }

        If pLevel = ..#LEVELDATES {
            Set tSC = ..DateRows(pNamespace, pMaxRows, .tRows, .tTruncated)
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set("namespace", pNamespace)
            Do pResult.%Set("rows", tRows)
            Do pResult.%Set("truncated", ''tTruncated, "boolean")
            Quit
        }

        Set tSC = ..DateHeld(pNamespace, pDate, .tHeldDate)
        If $$$ISERR(tSC) Quit
        If 'tHeldDate {
            Set pOutcome = "date"
            Quit
        }

        If pLevel = ..#LEVELLIST {
            Set tSC = ..ErrorRows(pNamespace, pDate, pMaxRows, .tRows, .tTruncated)
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set("namespace", pNamespace)
            Do pResult.%Set("date", pDate)
            Do pResult.%Set("rows", tRows)
            Do pResult.%Set("truncated", ''tTruncated, "boolean")
            Quit
        }

        Set tSC = ..ErrorHeld(pNamespace, pDate, pErrorNumber, .tHeldError)
        If $$$ISERR(tSC) Quit
        If 'tHeldError {
            Set pOutcome = "entry"
            Quit
        }

        Set tSC = ..DetailPayload(pNamespace, pDate, pErrorNumber, pMaxRows, .tPayload)
        If $$$ISERR(tSC) Quit
        Set pResult = tPayload
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pOutcome = ""
        Set pResult = ""
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The namespaces this instance records application errors for, bounded by <var>pMaxRows</var>
/// (AD-36). <b>Caller contract:</b> <code>$NAMESPACE</code> is already
/// <parameter>ERRORSNAMESPACE</parameter>.</p>
ClassMethod NamespaceRows(pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pTruncated = 0
    Set tRS = ""
    Try {
        Set tSC = ..OpenQuery(..#NAMESPACELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(..#NAMESPACELISTALL)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If pRows.%Size() >= pMaxRows {
                Set pTruncated = 1
                Quit
            }
            Set tRow = {}
            Do tRow.%Set("namespace", tRS.Get("Namespace"))
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> is one <code>NamespaceList</code> itself answers with. The
/// comparison is exact: the caller drilled to a name the instance emitted, and a name spelled any
/// other way is a name this instance does not record errors for (AD-21).</p>
ClassMethod NamespaceHeld(pNamespace As %String, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pHeld = 0
    Set tRS = ""
    Try {
        If pNamespace = "" Quit
        Set tSC = ..OpenQuery(..#NAMESPACELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(..#NAMESPACELISTALL)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If tRS.Get("Namespace") = pNamespace {
                Set pHeld = 1
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>The dates <var>pNamespace</var> holds errors for, newest first as the query answers them,
/// each with its count. The date is the string <code>DateList</code> emitted, byte for byte: the
/// instance's own clock decides it, and a client-computed date misses (AD-21).</p>
ClassMethod DateRows(pNamespace As %String, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pTruncated = 0
    Set tRS = ""
    Try {
        Set tSC = ..OpenQuery(..#DATELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If pRows.%Size() >= pMaxRows {
                Set pTruncated = 1
                Quit
            }
            Set tRow = {}
            Do tRow.%Set("date", tRS.Get("Date"))
            Do tRow.%Set("count", +tRS.Get("Qty"), "number")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>Whether <var>pDate</var> is one <code>DateList</code> answers with for
/// <var>pNamespace</var>. A date purged between two drill levels is a named refusal, never an empty
/// table: the query validates nothing and answers zero rows for a date it cannot resolve.</p>
ClassMethod DateHeld(pNamespace As %String, pDate As %String, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pHeld = 0
    Set tRS = ""
    Try {
        If pDate = "" Quit
        Set tSC = ..OpenQuery(..#DATELISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If tRS.Get("Date") = pDate {
                Set pHeld = 1
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>One namespace and date's errors, highest error number first as the query answers them, in
/// this port's one summary projection.</p>
/// <p><b>Seven fields, and the captured detail is not among them</b> (AD-48).
/// <code>ErrorList</code>'s own row structurally carries no variable table, no stack and no
/// <code>$Roles</code>, so this path cannot leak the detail even if the projection were wrong --
/// which is why the summary path calls this query and never <code>ErrorDetail</code>.
/// <code>routine</code> and <code>line</code> both come from it: the instance records the routine
/// inside <code>Error message</code> as <code>&lt;CODE&gt;label+offset^routine</code>, and
/// <code>Code line</code> holds the offending line's source text. An entry logged from a
/// <code>Throw</code> leaves <code>$ZError</code> empty and is recorded as the placeholder
/// <code>&lt;LOG ENTRY&gt;</code> with no <code>^</code> in it; its <code>routine</code> is
/// <code>""</code>, because an absent field beats a fabricated one.</p>
ClassMethod ErrorRows(pNamespace As %String, pDate As %String, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pTruncated = 0
    Set tRS = ""
    Try {
        Set tSC = ..OpenQuery(..#ERRORLISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace, pDate)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If pRows.%Size() >= pMaxRows {
                Set pTruncated = 1
                Quit
            }
            Set tText = tRS.Get("Error message")
            Set tRoutine = ..RoutineOf(tText)
            Set tRow = {}
            Do tRow.%Set("errorNumber", +tRS.Get("Error #"), "number")
            Do tRow.%Set("time", tRS.Get("Time"))
            Do tRow.%Set("errorText", tText)
            Do tRow.%Set("routine", tRoutine)
            Do tRow.%Set("line", tRS.Get("Code line"))
            Do tRow.%Set("username", tRS.Get("Username"))
            Do tRow.%Set("process", tRS.Get("Process"))
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>The routine named inside an entry's error text, or <code>""</code> when it names none.</p>
/// <p>The instance records it as <code>&lt;CODE&gt;label+offset^routine</code>, so the routine is
/// the <b>first space-delimited token</b> after the first <code>^</code>. It is not the whole
/// tail: <code>$ZError</code> carries a payload after the routine on several error classes -- an
/// <code>&lt;UNDEFINED&gt;</code> appends <code>&nbsp;*variable</code>, a <code>&lt;THROW&gt;</code>
/// appends <code>&nbsp;*&lt;exception class and message&gt;</code> (45 of 158 rows on three dates of
/// this instance's own log), and a <code>&lt;PROTECT&gt;</code> appends a second
/// <code>^</code>-prefixed global reference. A routine name contains no space, so the token is the
/// whole of it and the payload belongs to <code>errorText</code>, which carries it already.</p>
/// <p>An entry logged from a <code>Throw</code> leaves <code>$ZError</code> empty and
/// <code>$$LOG^%ETN()</code> records the placeholder <code>&lt;LOG ENTRY&gt;</code>, which carries
/// no <code>^</code> at all: that entry's routine is <code>""</code>, because an absent field beats
/// a fabricated one. There is no separate routine column and no line <i>number</i> column in the
/// query's own row -- <code>line</code> is the offending line's source text, from
/// <code>Code line</code> -- so this is the whole derivation, and it is public so it can be
/// exercised as a rule over a corpus rather than only against whatever the instance happens to hold
/// today.</p>
ClassMethod RoutineOf(pErrorText As %String) As %String
{
    If pErrorText '[ "^" Quit ""
    Quit $Piece($Piece(pErrorText, "^", 2, *), " ", 1)
}

/// <p>Whether <var>pErrorNumber</var> is one <code>ErrorList</code> answers with for
/// <var>pNamespace</var> and <var>pDate</var>. Numeric comparison, because the caller's text is
/// compared against the query's own integer column.</p>
ClassMethod ErrorHeld(pNamespace As %String, pDate As %String, pErrorNumber As %String, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pHeld = 0
    Set tRS = ""
    Try {
        If '$Match(pErrorNumber, "^[1-9][0-9]*$") Quit
        Set tSC = ..OpenQuery(..#ERRORLISTQUERY, .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace, pDate)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If +tRS.Get("Error #") = +pErrorNumber {
                Set pHeld = 1
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>One error's captured detail: the logged expressions, the stack levels, and every local
/// variable at every level, each bounded by <var>pMaxRows</var> and <code>truncated</code> true
/// when any of the three was cut.</p>
/// <p><b>Secret by default</b> (AD-48). This payload holds <code>$Roles</code>,
/// <code>$USERNAME</code> and, on an IRIS for Health instance, potentially patient data; it never
/// enters the descriptor's context field list and the read tool never carries it. The caller names
/// no <code>Type</code>: the three the vendor defines for this shape are named here.</p>
ClassMethod DetailPayload(pNamespace As %String, pDate As %String, pErrorNumber As %String, pMaxRows As %Integer, Output pResult As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tSC = ..DetailRows(..#DETAILTYPEEXPRESSIONS, pNamespace, pDate, pErrorNumber, pMaxRows, .tExpressions, .tExpressionsCut)
        If $$$ISERR(tSC) Quit
        Set tSC = ..DetailRows(..#DETAILTYPESTACK, pNamespace, pDate, pErrorNumber, pMaxRows, .tStack, .tStackCut)
        If $$$ISERR(tSC) Quit
        Set tSC = ..DetailRows(..#DETAILTYPEVARIABLES, pNamespace, pDate, pErrorNumber, pMaxRows, .tVariables, .tVariablesCut)
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set("expressions", tExpressions)
        Do pResult.%Set("stack", tStack)
        Do pResult.%Set("variables", tVariables)
        Do pResult.%Set("truncated", ''(tExpressionsCut || tStackCut || tVariablesCut), "boolean")
    } Catch ex {
        Set pResult = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One <code>ErrorDetail</code> section. The query answers four generic columns and <b>two of
/// them are named per <var>pType</var>, three at most</b>: expressions are
/// <code>{expression, value}</code> from Column1-2, stack levels are <code>{level, detail}</code>
/// from Column1 and Column3, and variables are <code>{level, name, value}</code> from Column1-3.</p>
/// <p><b>What is dropped, and why.</b> A stack level's Column2 is the frame's label, which Column3
/// already carries inside the frame text it renders -- so it would be a second copy of the same
/// words in the same row. Column4 is empty at <parameter>DETAILTYPEEXPRESSIONS</parameter> and
/// <parameter>DETAILTYPEVARIABLES</parameter> and carries an undocumented <code>0</code>/<code>1</code>
/// flag at <parameter>DETAILTYPESTACK</parameter> (observed on this instance: 0 of 75, 0 of 493,
/// and 35 of 35 rows non-empty). Nothing on screen or in the contract is defined in terms of it, so
/// it is not projected rather than projected under a name this story would be inventing.</p>
ClassMethod DetailRows(pType As %Integer, pNamespace As %String, pDate As %String, pErrorNumber As %String, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pTruncated = 0
    Set tRS = ""
    Try {
        Set tSC = ..OpenQuery(..DetailQuery(), .tRS)
        If $$$ISERR(tSC) Quit
        Set tSC = tRS.Execute(pNamespace, pDate, +pErrorNumber, pType)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If pRows.%Size() >= pMaxRows {
                Set pTruncated = 1
                Quit
            }
            Set tRow = {}
            If pType = ..#DETAILTYPEEXPRESSIONS {
                Do tRow.%Set("expression", tRS.Get("Column1"))
                Do tRow.%Set("value", tRS.Get("Column2"))
            } ElseIf pType = ..#DETAILTYPESTACK {
                Do tRow.%Set("level", tRS.Get("Column1"))
                Do tRow.%Set("detail", tRS.Get("Column3"))
            } Else {
                Do tRow.%Set("level", tRS.Get("Column1"))
                Do tRow.%Set("name", tRS.Get("Column2"))
                Do tRow.%Set("value", tRS.Get("Column3"))
            }
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $IsObject(tRS) Do tRS.Close()
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <var>pPairs</var>, asked of
/// <method>GateClass</method>'s evaluator so the check and the spelling of a failure are the
/// gate's and not a second copy (the <class>OcuPilot.Api.Namespaces</class> idiom).</p>
/// <p><b>A requirement that names no pair is never held</b> (DW-1120): this asks
/// <method>EvaluateRequired</method>, not <method>EvaluatePairs</method>, so a pair set that
/// resolved to nothing fails closed at the port instead of opening it to everyone.</p>
ClassMethod Gate(pPairs As %List, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Quit $ClassMethod(..GateClass(), "EvaluateRequired", pPairs, .pFailedPair)
}

/// <p>The path source <var>pSource</var> reads, resolved from <method>ManagerDirectory</method>
/// and <method>FileFor</method> on this call and checked for presence.</p>
/// <p>Refuses <code>LOG.SOURCE</code> for a key with no file and <code>LOG.ABSENT</code> when the
/// resolved file is not there; neither refusal echoes the path (AD-21, AD-47).</p>
ClassMethod Resolve(pSource As %String, Output pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pPath = ""
    Set tFile = ..FileFor(pSource)
    If tFile = "" {
        Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve a log source by that name", .pHttpStatus, .pFault)
    } Else {
        Set pPath = ##class(%File).NormalizeFilename(tFile, ..ManagerDirectory())
        If '..FileExists(pPath) {
            Set pPath = ""
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGABSENT, "That log file is not present on this instance", .pHttpStatus, .pFault)
        }
    }
    Quit tSC
}

/// <p>The file's size and its identity token: the URL-safe Base64 of the SHA-256 of the file's
/// <b>first line</b>, read from within its first <parameter>PREFIXBYTES</parameter> bytes, or of
/// the empty string when it has none.</p>
/// <p><b>The first line, not the first N bytes.</b> A console log under
/// <parameter>PREFIXBYTES</parameter> -- which is exactly what one is in the seconds after a
/// rotation -- would hash a different prefix on every append, so every held cursor would restart
/// while the file was still small. The first line is fixed the moment it is written, and on this
/// build it carries the previous generation's last-write time to the millisecond, so it
/// distinguishes generations. A first line longer than the prefix is fingerprinted by its opening
/// <parameter>PREFIXBYTES</parameter> bytes, which are equally fixed.</p>
/// <p><b>URL-safe alphabet.</b> The token is handed back to the caller as a query parameter, and
/// standard Base64's <code>+</code> decodes to a space in a query string -- so a caller that
/// echoed the token verbatim would be answered <code>restarted</code> for a file that had not
/// moved. <code>-</code> and <code>_</code> survive the transport the cursor travels on, and the
/// padding <code>=</code> is left in place so the token's length is unchanged.</p>
/// <p>An error <class>%Status</class> means the file could not be read at all, which is what
/// <method>Page</method> turns into <code>LOG.UNREADABLE</code> -- an open succeeds on a path
/// that is a directory, so the first read is where that is found out.</p>
ClassMethod Identity(pStream As %Stream.Object, Output pSize As %Integer, Output pIdentity As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pSize = 0
    Set pIdentity = ""
    Try {
        Set pSize = +pStream.Size
        If pSize < 0 Set pSize = 0
        Set tPrefix = ""
        If pSize > 0 {
            Set tWant = ..#PREFIXBYTES
            If tWant > pSize Set tWant = pSize
            Do pStream.MoveTo(1)
            Set tSC = ..ReadBytes(pStream, tWant, .tPrefix)
            If $$$ISERR(tSC) Quit
            Set tPrefix = $Piece(tPrefix, $Char(10), 1)
        }
        Set pIdentity = $Translate($System.Encryption.Base64Encode($System.Encryption.SHAHash(256, tPrefix), 1), "+/", "-_")
    } Catch ex {
        Set pSize = 0
        Set pIdentity = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read up to <var>pWant</var> bytes from <var>pStream</var>'s current position into
/// <var>pBytes</var>, in <parameter>CHUNKSIZE</parameter> slices -- a single
/// <code>%Stream.FileBinary</code> read returns at most about 32 KB whatever it is asked for, so
/// a one-call read of a 64 KB window would silently come back short.</p>
/// <p>A read that reports an error stops the loop and returns it rather than spinning: a stream
/// that cannot be read reports <code>AtEnd</code> 0 forever.</p>
ClassMethod ReadBytes(pStream As %Stream.Object, pWant As %Integer, Output pBytes As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pBytes = ""
    While ($Length(pBytes) < pWant) && 'pStream.AtEnd {
        Set tLen = pWant - $Length(pBytes)
        If tLen > ..#CHUNKSIZE Set tLen = ..#CHUNKSIZE
        Set tChunk = pStream.Read(.tLen, .tSC)
        If $$$ISERR(tSC) Quit
        If tLen <= 0 Quit
        Set pBytes = pBytes _ tChunk
    }
    Quit tSC
}

/// <p>The whole lines of the window that starts at byte <var>pStart</var> and runs at most
/// <var>pMaxBytes</var> bytes, with the byte the next call should ask for.</p>
/// <p><b>Whole lines, three cases.</b> A window that begins mid-line -- the byte before
/// <var>pStart</var> is not a newline -- discards through its first newline. A window that stops
/// mid-line drops the partial tail and points <var>pNextOffset</var> at that tail's first byte,
/// so the next page serves it complete. A window holding no newline at all and not reaching the
/// end of the file is one line longer than the window: nothing is served,
/// <var>pTruncated</var> is true, and <var>pNextOffset</var> advances past the window so a reader
/// cannot loop on it.</p>
/// <p><var>pTruncated</var> is true exactly when the page did not reach the end of the file
/// (AD-36). <var>pLines</var> are UTF-8 decoded; a byte sequence that is not UTF-8 decodes to
/// <code>?</code> rather than reaching the envelope as a lone byte.</p>
ClassMethod ReadWindow(pStream As %Stream.Object, pStart As %Integer, pMaxBytes As %Integer, pSize As %Integer, Output pLines As %DynamicArray, Output pNextOffset As %Integer, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pLines = []
    Set pNextOffset = pStart
    Set pTruncated = 0
    Set tNewline = $Char(10)
    Try {
        If pStart > pSize Quit

        ; One byte before the window, when there is one, so "does this window begin mid-line?" is
        ; answered from the file rather than assumed from where the offset came from.
        Set tProbe = (pStart > 1)
        ; Clamped to the size every whole-line decision below is judged against, and to the size
        ; the envelope reports. The instance appends to this file while the page is being
        ; assembled, so an unclamped read returns bytes past pSize whenever the window reaches the
        ; sampled end: those bytes -- the line being written right now -- would be served as lines
        ; of a page whose own `size` says they are not there, and pNextOffset would point past
        ; size + 1. The clamp does not change tReachedEnd, which is true either way for exactly
        ; the windows the clamp fires on; what it bounds is what reaches the caller.
        Set tWant = pMaxBytes + tProbe
        Set tAvailable = pSize - (pStart - tProbe) + 1
        If tWant > tAvailable Set tWant = tAvailable
        Do pStream.MoveTo(pStart - tProbe)
        Set tSC = ..ReadBytes(pStream, tWant, .tBuf)
        If $$$ISERR(tSC) Quit

        Set tMidLine = 0
        If tProbe {
            Set tMidLine = ($Extract(tBuf, 1) '= tNewline)
            Set tBuf = $Extract(tBuf, 2, *)
        }
        ; The file reported a size this window sits inside and handed back nothing, so it shrank
        ; between the two reads. There is nothing to serve and nowhere further forward to point.
        If tBuf = "" Quit

        Set tRegionStart = pStart
        If tMidLine {
            Set tAfterNewline = $Find(tBuf, tNewline)
            If tAfterNewline = 0 {
                Set pNextOffset = pStart + $Length(tBuf)
                Set pTruncated = 1
                Quit
            }
            Set tRegionStart = pStart + tAfterNewline - 1
            Set tBuf = $Extract(tBuf, tAfterNewline, *)
        }

        Set tReachedEnd = ((tRegionStart + $Length(tBuf) - 1) >= pSize)
        If 'tReachedEnd {
            Set tPieces = $Length(tBuf, tNewline)
            If tPieces = 1 {
                Set pNextOffset = tRegionStart + $Length(tBuf)
                Set pTruncated = 1
                Quit
            }
            ; Drop the partial tail after the last newline; pNextOffset then points at its first
            ; byte, so the next page serves that line whole.
            Set tBuf = $Extract(tBuf, 1, $Length(tBuf) - $Length($Piece(tBuf, tNewline, tPieces)))
        }

        Set pNextOffset = tRegionStart + $Length(tBuf)
        Set pTruncated = (pNextOffset <= pSize)

        Set tCount = $Length(tBuf, tNewline)
        For tI = 1:1:tCount {
            Set tLine = $Piece(tBuf, tNewline, tI)
            ; The empty piece a trailing newline leaves is a terminator, not a line.
            If (tI = tCount) && (tLine = "") Quit
            If $Extract(tLine, *) = $Char(13) Set tLine = $Extract(tLine, 1, *-1)
            Do pLines.%Push($ZConvert(tLine, "I", "UTF8"))
        }
    } Catch ex {
        Set pLines = []
        Set pNextOffset = pStart
        Set pTruncated = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 503 a present file that cannot be read answers with. <var>pStatus</var> is logged and
/// never put on the wire (AD-39).</p>
ClassMethod Unreadable(pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#LOGUNREADABLE, "That log file is present and this instance could not read it", .pHttpStatus, .pFault)
    Do ..LogFault("a log source could not be read", pStatus, pFault.code)
    Quit tSC
}

/// <p>A refusal this port decided itself, with no vendor status behind it. <var>pDetail</var>,
/// when supplied, becomes the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure inside the port: the generic internal fault on the wire, the raw
/// status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
