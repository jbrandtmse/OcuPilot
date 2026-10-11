/// <p>The port to the instance's interoperability runtime (AD-62, AD-29, AD-52, Stories 20.2 and 20.3): <b>the
/// only product class that starts, stops, restarts, updates or recovers a production, or enables, disables,
/// adds or removes one of its items</b>, and the only one that reads the interoperability configuration for
/// a declared read (source kind <code>interop</code>); Story 20.4 adds the nine runtime reads (<parameter>ENDPOINTS</parameter>
/// from <code>Monitor</code> on), which write nothing and never call a queue or job action. It calls the documented classes the classic pages call --
/// <code>Ens.Director</code>, <code>Ens.Config.Production:ProductionStatus</code> and
/// <code>%Dictionary.ClassDefinition:SubclassOf</code> -- in the caller's process, as the signed-in
/// user. Nothing here issues an HTTP request, calls a <code>%Api.InteropEditors</code> class or calls
/// <code>Ens.Director.CleanProduction</code>.</p>
/// <p>The vendor's reads check no privilege (a principal holding only <code>%DB_USER:R</code> read the
/// status, the production list and the rule list, measured), so <method>Invoke</method>'s gate is the
/// whole gate for a read. <b>The order of every call is fixed</b>, and nothing reaches the vendor before
/// all of it has passed:</p>
/// <ol>
/// <li>The endpoint and type are one this port serves, else 501 <code>PORT.NOTIMPLEMENTED</code>.</li>
/// <li>The endpoint's pairs (<parameter>PRODUCTIONPAIRS</parameter> or <parameter>CODEPAIRS</parameter>)
/// and, for a write, <parameter>WRITEPAIRS</parameter>, through
/// <method>OcuPilot.Screen.Gate.EvaluateRequired</method>; a refusal is 403 naming the failed pair.</li>
/// <li>The namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>), its shape checked; a namespace that does not report
/// interoperability is 409 <parameter>OcuPilot.Api.InteropError.NAMESPACE</parameter>, refused before any
/// switch.</li>
/// <li>READ, or for a write WRITE, on the resource guarding the namespace's globals database, and for an
/// item write WRITE on the one guarding its routines database too; an unresolved resource is 400
/// <code>PORT.VALIDATION</code>.</li>
/// <li>For a write, the production's state, read first and judged by <method>Refusal</method>: whatever
/// the vendor would answer as a silent success is refused by its own code, and nothing is called.</li>
/// <li>The vendor call, in the target namespace, switched by explicit save and restore (AD-16): the
/// restore is the first line of every <code>Catch</code>, and no <code>OcuPilot.*</code> class is called
/// while switched.</li>
/// </ol>
/// <p>The vendor performs start, stop, restart and update as its own service account after checking the
/// caller's run resource, as from the classic page (AD-8, AD-62): this port adds no elevation, and the
/// caller's <code>$USERNAME</code> and <code>$ROLES</code> read the same afterwards (measured). A write
/// finishes inside its own request (AD-7): start returns once its jobs are launched, and stop, restart
/// and update pass the production's own timeout capped at <parameter>STOPSECONDS</parameter>. A
/// production that does not quiesce in that time is refused by the vendor and left as it was.</p>
/// <p><b>Every refusal is a written reason</b> (AD-39): the vendor's text goes to
/// <method>LogFault</method> and nowhere else, and a read answered 404 is not logged (AD-2).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>,
/// <method>StopSeconds</method>, <method>RoutineResource</method> and <method>SourceControlled</method>.
/// Production overrides none.</p>
Class OcuPilot.Port.InteropPort Extends %RegisteredObject
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints this port serves, comma-separated: the namespace's productions, business
/// processes, data transformations and business rules, and a production's items.
/// <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Items,Settings,Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs";

Parameter ENDPOINTPRODUCTIONS = "Productions";

Parameter ENDPOINTPROCESSES = "Processes";

Parameter ENDPOINTTRANSFORMS = "Transforms";

Parameter ENDPOINTRULES = "Rules";

/// <p>A production's items: <code>LIST</code> for the production the <parameter>PRODUCTIONKEY</parameter>
/// names, <code>ITEM</code> for one item and the four item writes (Story 20.3).</p>
Parameter ENDPOINTITEMS = "Items";

/// <p>An item's settings (Story 20.22): <code>LIST</code> for the item the <parameter>ITEMKEY</parameter> names,
/// <code>SETTING</code> for one setting and the two setting writes <code>SET</code> and <code>RESET</code>. A
/// setting is one of the item's own properties (<parameter>TARGETCORE</parameter>) or one the item's class
/// (<parameter>TARGETHOST</parameter>) or its adapter (<parameter>TARGETADAPTER</parameter>) declares.</p>
Parameter ENDPOINTSETTINGS = "Settings";

/// <p>The production monitor (Story 20.4): the hosts the namespace's running production configures, with the status the
/// vendor's host monitor keeps. <code>LIST</code> only, like every endpoint from here to <parameter>ENDPOINTITEMJOBS</parameter>;
/// none writes, and none calls a queue or job action.</p>
Parameter ENDPOINTMONITOR = "Monitor";

/// <p>One item's status (Story 20.4): its configuration facts and its host's monitor row. An item endpoint takes the
/// item under <parameter>ITEMKEY</parameter>.</p>
Parameter ENDPOINTITEMSTATUS = "ItemStatus";

/// <p>The namespace's queues and the entries of one of them, named under <parameter>QUEUEKEY</parameter>.</p>
Parameter ENDPOINTQUEUES = "Queues";

Parameter ENDPOINTQUEUEITEMS = "QueueItems";

/// <p>An item's queue, its event log rows and its message headers.</p>
Parameter ENDPOINTITEMQUEUE = "ItemQueue";

Parameter ENDPOINTITEMLOG = "ItemLog";

Parameter ENDPOINTITEMMESSAGES = "ItemMessages";

/// <p>The running production's jobs, and one item's.</p>
Parameter ENDPOINTJOBS = "Jobs";

Parameter ENDPOINTITEMJOBS = "ItemJobs";

/// <p>The pairs the Productions endpoint requires: the classic Interoperability menu's
/// <code>%Ens_Portal:USE</code> and <code>EnsPortal.Productions</code>'s own resource (AD-8,
/// AD-29).</p>
Parameter PRODUCTIONPAIRS = "%Ens_Portal:USE,%Ens_ProductionConfig:READ";

/// <p>The pairs the three code lists require. The classic pages' resource is an OR list a pair set
/// cannot express; <code>%Ens_Code:READ</code> is held by every shipped role that reaches them
/// (AD-62's named limit).</p>
Parameter CODEPAIRS = "%Ens_Portal:USE,%Ens_Code:READ";

/// <p>The pairs the Monitor endpoint requires: the classic <code>EnsPortal.ProductionMonitor</code>'s resource
/// (Story 20.4).</p>
Parameter MONITORPAIRS = "%Ens_Portal:USE,%Ens_Dashboard:USE";

/// <p>The pairs the Queues and QueueItems endpoints require: <code>EnsPortal.Queues</code>' resource.</p>
Parameter QUEUEPAIRS = "%Ens_Portal:USE,%Ens_Queues:READ";

/// <p>The pairs the Jobs endpoint requires: <code>EnsPortal.Jobs</code>' resource.</p>
Parameter JOBPAIRS = "%Ens_Portal:USE,%Ens_Jobs:READ";

/// <p>The pair each item tab adds to the Productions endpoint's pairs (the classic configuration page's
/// <code>initSecurity</code>): the queue, the event log, the message headers and the jobs.</p>
Parameter ITEMQUEUEPAIR = "%Ens_Queues:READ";

Parameter ITEMLOGPAIR = "%Ens_EventLog:USE";

Parameter ITEMMESSAGEPAIR = "%Ens_MessageHeader:USE";

Parameter ITEMJOBPAIR = "%Ens_Jobs:READ";

/// <p>The pair a write adds: the vendor's own run resource, the classic
/// <code>EnsPortal.ProductionConfig</code> check (measured: start, stop and restart answer #940
/// without it).</p>
Parameter WRITEPAIRS = "%Ens_ProductionRun:USE";

/// <p>The pair an item write adds to the Productions endpoint's pairs: the classic
/// <code>EnsPortal.ProductionConfig</code> editor's resource at WRITE. The vendor's item writes check no
/// privilege of their own (measured), so the declared pairs are the whole gate. An item write does not
/// need <code>%Ens_ProductionRun:USE</code>.</p>
Parameter ITEMWRITEPAIRS = "%Ens_ProductionConfig:WRITE";

/// <p>The permission a read requires on the namespace's globals database.</p>
Parameter READPERMISSION = "READ";

/// <p>The permission a write requires on it (recover raises <code>&lt;PROTECT&gt;</code> on
/// <code>^Ens.Suspended</code> without it, measured), and an item write on the namespace's routines
/// database as well (<code>&lt;PROTECT&gt;</code> on <code>^Ens.Config.ItemD</code> and
/// <code>^oddDEF</code> without it, measured).</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The longest a stop, restart or update waits for the production's work in progress, in seconds;
/// <method>StopSeconds</method> caps the production's own timeout at it. The sentences that state it
/// (<class>OcuPilot.Api.InteropError</class>) hold the same number, pinned by
/// <file>ui/tools/interop.test.mjs</file>.</p>
Parameter STOPSECONDS = 15;

/// <p>The request types. <code>LIST</code> answers rows on every endpoint; the rest are the
/// Productions endpoint's.</p>
Parameter TYPELIST = "LIST";

/// <p>One production's state: <code>{Name, Namespace, State, Current, NeedsUpdate}</code>, the tools'
/// fresh read. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be
/// refused (<method>Refusal</method>).</p>
Parameter TYPESTATE = "STATE";

Parameter TYPESTART = "START";

Parameter TYPESTOP = "STOP";

Parameter TYPERESTART = "RESTART";

Parameter TYPEUPDATE = "UPDATE";

Parameter TYPERECOVER = "RECOVER";

/// <p>One item: <code>{Production, Name, ClassName, Type, Enabled, EnabledSource, PoolSize, Category,
/// Comment, Namespace, Count}</code>, the item tools' fresh read. The id is the composite
/// <code>[Production, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses what that
/// action would be refused (<method>ItemRefusal</method>).</p>
Parameter TYPEITEM = "ITEM";

Parameter TYPEENABLE = "ENABLE";

Parameter TYPEDISABLE = "DISABLE";

Parameter TYPEADD = "ADD";

Parameter TYPEREMOVE = "REMOVE";

/// <p>One setting: <code>{Production, Item, Target, Name, Value, Source, Default, DefaultSource, Type, Category,
/// Location, Secret, Namespace, Count}</code>, the setting tools' fresh read. The id is the composite
/// <code>[Production, Item, Target, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses
/// what that action would be refused (<method>SettingRefusalToken</method>).</p>
Parameter TYPESETTING = "SETTING";

/// <p>Store a value for a setting. The body names it in <code>Value</code>.</p>
Parameter TYPESET = "SET";

/// <p>Remove the production's own value of a Host or Adapter setting, so its default applies again.</p>
Parameter TYPERESET = "RESET";

/// <p>The query key naming the item a <code>Settings</code> list reads: its one criterion. Its value is the item's
/// composite id <code>[Production, Name]</code> or the vendor's config name <code>Production||Name</code>.</p>
Parameter ITEMKEY = "item";

/// <p>The query key naming the queue a <code>QueueItems</code> list reads: its one criterion (Story 20.4).</p>
Parameter QUEUEKEY = "queue";

/// <p>The queue a business process of pool size 0 shares with every other such process; its entries are told apart by
/// the header's target.</p>
Parameter ACTORQUEUE = "Ens.Actor";

/// <p>The state words a runtime read answers rows in: the namespace's current production, running or troubled
/// (<method>ReadState</method>'s words).</p>
Parameter LIVEWORDS = "Running,Troubled";

/// <p>The most entries one queue read examines. A queue shared by many hosts (<parameter>ACTORQUEUE</parameter>) is
/// walked entry by entry and each header opened; past this many the read stops, so an item whose entries lie further
/// down the queue shows only those it reached.</p>
Parameter QUEUESCANMAX = 10000;

/// <p>What a setting refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter SETTINGCODEPREFIX = "INTEROP.SETTING.";

/// <p>The three groups a setting belongs to.</p>
Parameter TARGETCORE = "Core";

Parameter TARGETHOST = "Host";

Parameter TARGETADAPTER = "Adapter";

/// <p>The pair of adapter settings that makes an inbound file adapter read below its directory: the levels it
/// descends, and the directory it starts from.</p>
Parameter DESCENTSETTING = "SubdirectoryLevels";

Parameter DESCENTPATH = "FilePath";

/// <p>The editor-context components that mark a server path: a directory, or a file.</p>
Parameter LOCATIONDIRECTORY = "directorySelector";

Parameter LOCATIONFILE = "fileSelector";

/// <p>The query key naming the production an <code>Items</code> list reads: its one criterion.</p>
Parameter PRODUCTIONKEY = "production";

/// <p>What every item refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter ITEMCODEPREFIX = "INTEROP.ITEM.";

/// <p>The query key naming the namespace a call runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key naming the production a typed call is about.</p>
Parameter IDKEY = "id";

/// <p>The query key naming the action a <parameter>TYPESTATE</parameter> read is composed for, one of the
/// write types: the read then refuses what that action would be refused.</p>
Parameter ACTIONKEY = "action";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The vendor's status codes this port answers in its own words.</p>
Parameter CODENOTQUIESCENT = "<Ens>ErrProductionNotQuiescent";

Parameter CODEJOBNOTSTOPPED = "<Ens>ErrJobNotStopped";

Parameter CODEJOBSNOTSTOPPED = "<Ens>ErrJobsNotStopped";

Parameter CODEALREADYRUNNING = "<Ens>ErrProductionAlreadyRunning";

Parameter CODENOTSHUTDOWNCLEANLY = "<Ens>ErrProductionNotShutdownCleanly";

Parameter CODESUSPENDEDMISMATCH = "<Ens>ErrProductionSuspendedMismatch";

Parameter CODERUNTIMELOCK = "<Ens>ErrCanNotAcquireRuntimeLock";

/// <p>#940: the vendor's own privilege refusal.</p>
Parameter CODEPRIVILEGE = 940;

/// <p>The state words a write acts on. Any other word, <code>Unknown</code> and a mirror backup's
/// among them, refuses every action.</p>
Parameter ACTIONABLEWORDS = "Running,Stopped,Suspended,Troubled";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "interopport";

/// <p>The reasons this port's own refusals carry.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONNAMESPACESHAPE = "Name the namespace the call runs in.";

Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the database that namespace keeps its interoperability configuration in.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONIDREQUIRED = "Name the production.";

Parameter REASONLOCK = "The production's state could not be read just now. Try again.";

Parameter REASONROUTINESUNKNOWN = "This instance cannot name the database that namespace keeps its routines in.";

Parameter REASONITEMIDREQUIRED = "Name the production and the item.";

Parameter REASONQUEUEREQUIRED = "Name the queue.";

Parameter REASONITEMBODY = "An item write names its fields in an object.";

Parameter REASONSETTINGID = "Name the production, the item, the group (Core, Host or Adapter) and the setting.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The longest a stop, restart or update waits, in seconds. Overridable so a test can shorten the
/// wait and observe a busy production refused; production never overrides it.</p>
ClassMethod StopSeconds() As %Integer
{
    Quit ..#STOPSECONDS
}

/// <p>The endpoint list as a <class>%List</class>.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListFromString(..#ENDPOINTS)
}

/// <p>Whether <var>pType</var> is one of the writes this port carries.</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESTART) || (pType = ..#TYPESTOP) || (pType = ..#TYPERESTART) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPERECOVER)
}

/// <p>Whether <var>pType</var> is one of the item writes this port carries (Story 20.3).</p>
ClassMethod IsItemWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) || (pType = ..#TYPEADD) || (pType = ..#TYPEREMOVE)
}

/// <p>Whether <var>pType</var> is one of the setting writes this port carries (Story 20.22). A setting write is an
/// item write for the pairs and the databases it needs: it stores the item and the production class.</p>
ClassMethod IsSettingWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESET) || (pType = ..#TYPERESET)
}

/// <p>The endpoints Story 20.4 added, as a <class>%List</class>: the nine runtime reads, each <code>LIST</code> alone.</p>
ClassMethod RuntimeEndpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTMONITOR, ..#ENDPOINTITEMSTATUS, ..#ENDPOINTQUEUES, ..#ENDPOINTQUEUEITEMS, ..#ENDPOINTITEMQUEUE, ..#ENDPOINTITEMLOG, ..#ENDPOINTITEMMESSAGES, ..#ENDPOINTJOBS, ..#ENDPOINTITEMJOBS)
}

/// <p>The runtime reads that are about one item, named under <parameter>ITEMKEY</parameter>.</p>
ClassMethod ItemEndpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTITEMSTATUS, ..#ENDPOINTITEMQUEUE, ..#ENDPOINTITEMLOG, ..#ENDPOINTITEMMESSAGES, ..#ENDPOINTITEMJOBS)
}

/// <p>The pairs <var>pEndpoint</var> requires for <var>pType</var>, as the <code>%List</code> of
/// two-element <code>%List</code>s the gate evaluates: the endpoint's own pairs, then
/// <parameter>WRITEPAIRS</parameter> for a production write or <parameter>ITEMWRITEPAIRS</parameter> for an
/// item write; <code>""</code> for an endpoint this port does not serve. The Items and Settings endpoints take the
/// Productions endpoint's pairs, and so does ItemStatus. The other runtime reads take the pairs of the classic page
/// they replace (Story 20.4): Monitor, Queues and QueueItems, Jobs; and each item tab the Productions pairs plus its
/// own (queue, event log, message headers, jobs).</p>
ClassMethod Pairs(pEndpoint As %String, pType As %String = "") As %List
{
    If (pEndpoint = ..#ENDPOINTPRODUCTIONS) || (pEndpoint = ..#ENDPOINTITEMS) || (pEndpoint = ..#ENDPOINTSETTINGS) || (pEndpoint = ..#ENDPOINTITEMSTATUS) {
        Set tSpec = ..#PRODUCTIONPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTMONITOR {
        Set tSpec = ..#MONITORPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTQUEUES) || (pEndpoint = ..#ENDPOINTQUEUEITEMS) {
        Set tSpec = ..#QUEUEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTJOBS {
        Set tSpec = ..#JOBPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTITEMQUEUE {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMQUEUEPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMLOG {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMLOGPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMMESSAGES {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMMESSAGEPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMJOBS {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMJOBPAIR
    } ElseIf $ListFind(..Endpoints(), pEndpoint) {
        Set tSpec = ..#CODEPAIRS
    } Else {
        Quit ""
    }
    If ..IsWrite(pType) Set tSpec = tSpec _ "," _ ..#WRITEPAIRS
    If ..IsItemWrite(pType) || ..IsSettingWrite(pType) Set tSpec = tSpec _ "," _ ..#ITEMWRITEPAIRS
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
    If pEndpoint = ..#ENDPOINTITEMS Quit (pType = ..#TYPEITEM) || ..IsItemWrite(pType)
    If pEndpoint = ..#ENDPOINTSETTINGS Quit (pType = ..#TYPESETTING) || ..IsSettingWrite(pType)
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit 0
    Quit (pType = ..#TYPESTATE) || ..IsWrite(pType)
}

/// <p>The code a write of type <var>pType</var> is refused with, or <code>""</code> when it may go ahead
/// (AD-62): whatever the vendor would answer as a silent success, or refuse, is refused here by its own
/// name. <var>pWord</var> is the target's state word, <var>pCurrent</var> the namespace's current
/// production (<code>""</code> when none), <var>pId</var> the target and <var>pNeedsUpdate</var>
/// whether the running production has an update pending. Pure.</p>
/// <ul>
/// <li>Any word outside <parameter>ACTIONABLEWORDS</parameter>: <code>INTEROP.PRODUCTION.STATE</code>.</li>
/// <li>Start: <code>RUNNING</code> when the target runs, <code>TROUBLED</code> when it is troubled,
/// <code>OTHER</code> when another production is current.</li>
/// <li>Stop and restart: <code>NOTRUNNING</code> unless the target runs.</li>
/// <li>Update: <code>NOTRUNNING</code> unless the target runs, then <code>UPTODATE</code> when nothing is
/// pending.</li>
/// <li>Recover: <code>NOTTROUBLED</code> unless the target is troubled.</li>
/// </ul>
ClassMethod Refusal(pType As %String, pWord As %String, pCurrent As %String, pId As %String, pNeedsUpdate As %Boolean) As %String
{
    If '$ListFind($ListFromString(..#ACTIONABLEWORDS), pWord) Quit ##class(OcuPilot.Api.InteropError).#STATE
    If pType = ..#TYPESTART {
        If (pWord = "Running") && (pCurrent = pId) Quit ##class(OcuPilot.Api.InteropError).#RUNNING
        If (pWord = "Troubled") && (pCurrent = pId) Quit ##class(OcuPilot.Api.InteropError).#TROUBLED
        If (pCurrent '= "") && (pCurrent '= pId) Quit ##class(OcuPilot.Api.InteropError).#OTHER
        Quit ""
    }
    If (pType = ..#TYPESTOP) || (pType = ..#TYPERESTART) {
        If pWord '= "Running" Quit ##class(OcuPilot.Api.InteropError).#NOTRUNNING
        Quit ""
    }
    If pType = ..#TYPEUPDATE {
        If pWord '= "Running" Quit ##class(OcuPilot.Api.InteropError).#NOTRUNNING
        If 'pNeedsUpdate Quit ##class(OcuPilot.Api.InteropError).#UPTODATE
        Quit ""
    }
    If pType = ..#TYPERECOVER {
        If pWord '= "Troubled" Quit ##class(OcuPilot.Api.InteropError).#NOTTROUBLED
        Quit ""
    }
    Quit ""
}

/// <p>The codes a write's fresh read refuses with when the action does not fit the production's state,
/// and a namespace that runs no productions, as a <class>%List</class>: the tools'
/// <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method>, which may not name
/// <class>OcuPilot.Api.InteropError</class> themselves.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.InteropError).PreconditionCodes() _ $ListBuild(##class(OcuPilot.Api.InteropError).#NAMESPACE)
}

/// <p>The published sentence of <var>pCode</var>, <code>""</code> for a code this port does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.InteropError).ReasonFor(pCode)
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after this class's header's
/// gate.</p>
/// <p><var>pQuery</var> carries <parameter>NAMESPACEKEY</parameter> (optional: the request's scope when
/// absent), <parameter>IDKEY</parameter> for a typed call, <parameter>ACTIONKEY</parameter> for a
/// <code>STATE</code> read composed for an action, and <parameter>MAXROWSKEY</parameter> for a list
/// (optional, a whole number above zero). <var>pBody</var> is not read: no write carries one.</p>
/// <p>On success, at 200, <var>pResult</var> is: for <code>LIST</code> on Productions an array of
/// <code>{Name, Status, LastStartTime, LastStopTime}</code>; for <code>LIST</code> on a code list an
/// array of <code>{Name, Modified}</code> (the document name <code>&lt;class&gt;.cls</code> and the
/// class's last change as <code>YYYY-MM-DD HH:MM:SS</code>), cut at <parameter>MAXROWSKEY</parameter>;
/// for <code>STATE</code> and after every write <code>{Name, Namespace, State, Current,
/// NeedsUpdate}</code>; for the nine runtime reads an array of rows (<method>InvokeRuntime</method>).</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace, id or cap of the
/// wrong shape, or a namespace whose database cannot be resolved; 501
/// <code>PORT.NOTIMPLEMENTED</code>; 409 <parameter>OcuPilot.Api.InteropError.NAMESPACE</parameter> for
/// a namespace that runs no productions; 404 <code>PORT.NOTFOUND</code> for an unknown production,
/// unlogged; 409 with one of the <parameter>OcuPilot.Api.InteropError</parameter> codes
/// (<method>Refusal</method>, or the vendor's own refusal of a busy production); 503
/// <code>PORT.UNAVAILABLE</code> when the runtime lock cannot be taken; 403
/// <code>PORT.ACCESSDENIED</code> for <code>&lt;PROTECT&gt;</code> or #940; and 500
/// <code>INTERNAL</code>, logged, for anything else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tWrite = ..IsWrite(pType) || ..IsItemWrite(pType) || ..IsSettingWrite(pType)
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tSC = ..Admit(pEndpoint, pType, tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        If pEndpoint = ..#ENDPOINTITEMS {
            Set tSC = ..InvokeItems(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSETTINGS {
            Set tSC = ..InvokeSettings(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $ListFind(..RuntimeEndpoints(), pEndpoint) {
            Set tSC = ..InvokeRuntime(tNamespace, pEndpoint, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        If pType = ..#TYPELIST {
            Set tMax = 0
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = +tMaxText
            If pEndpoint = ..#ENDPOINTPRODUCTIONS {
                Set tSC = ..ListProductions(tNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ListClasses(tNamespace, pEndpoint, tMax, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }

        Set tId = $Get(pQuery(..#IDKEY))
        If tId = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadState(tNamespace, tId, .tFacts, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tAction '= "" {
            Set tCode = ..Refusal(tAction, tFacts("word"), tFacts("current"), tId, tFacts("needsUpdate"))
            If tCode '= "" {
                Set tSC = ..Conflict(tCode, .pHttpStatus, .pFault)
                Quit
            }
        }
        If 'tWrite {
            Set pResult = ..StateRow(tNamespace, tId, .tFacts)
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..Perform(tNamespace, pType, tId, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>This port's gate (AD-29, AD-62), evaluated before any vendor call for <var>pType</var> on
/// <var>pEndpoint</var> in <var>pNamespace</var>, in this order: the endpoint's pairs; the namespace's shape;
/// the namespace reporting interoperability; READ on its globals database (WRITE for a write); and, for an item
/// write, WRITE on its routines database. A refusal is an error status with <var>pHttpStatus</var> and
/// <var>pFault</var> set as <method>Invoke</method> answers them. Names no vendor class.</p>
ClassMethod Admit(pEndpoint As %String, pType As %String, pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tWrite = ..IsWrite(pType) || ..IsItemWrite(pType) || ..IsSettingWrite(pType)
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint, pType), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    If '##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("interoperability", pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NAMESPACE, .pHttpStatus, .pFault)
    Set tResource = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(pNamespace, .tResource, .tReadOnly) || (tResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tResource, $Select(tWrite: ..#WRITEPERMISSION, 1: ..#READPERMISSION))), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    ; An item write also writes the routines database (^oddDEF), after the globals one.
    If '..IsItemWrite(pType) && '..IsSettingWrite(pType) Quit $$$OK
    Set tRoutineResource = ""
    If '..RoutineResource(pNamespace, .tRoutineResource) || (tRoutineResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONROUTINESUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tRoutineResource, ..#WRITEPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The Productions list: one row per <code>Ens.Config.Production</code>, <code>{Name, Status,
/// LastStartTime, LastStopTime}</code>, at most <var>pMax</var> of them when it is above zero. The
/// vendor's own query answers them (<code>Ens.Config.Production:ProductionStatus</code>); only vendor
/// classes run while the namespace is switched, and the rows are built once it is restored.</p>
ClassMethod ListProductions(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("Ens.Config.Production:ProductionStatus")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tFound = tFound + 1
                Set tWord = ##class(Ens.Config.Production).ProductionStateToText(+tResultSet.GetData(5), 0)
                If $Extract(tWord, 1, 13) = "Unrecognized:" Set tWord = "Unknown"
                Set tFound(tFound) = $ListBuild(tResultSet.GetData(1), tWord, tResultSet.GetData(3), tResultSet.GetData(4))
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the production list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ "", "string")
        Do tRow.%Set("Status", $List(tFound(tI), 2) _ "", "string")
        Do tRow.%Set("LastStartTime", $List(tFound(tI), 3) _ "", "string")
        Do tRow.%Set("LastStopTime", $List(tFound(tI), 4) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The classes of <var>pEndpoint</var>'s kind in <var>pNamespace</var>, at most <var>pMax</var> of
/// them when it is above zero: the subclasses of <code>Ens.BusinessProcess</code> less
/// <code>Ens.BusinessProcessBPL</code>, of <code>Ens.DataTransform</code> less
/// <code>Ens.DataTransformDTL</code>, and of <code>Ens.Rule.Definition</code>, through
/// <code>%Dictionary.ClassDefinition:SubclassOf</code>, which writes nothing. A row is
/// <code>{Name, Modified}</code>: the document name <code>&lt;class&gt;.cls</code> and the class's
/// <code>TimeChanged</code> as local <code>YYYY-MM-DD HH:MM:SS</code>.</p>
ClassMethod ListClasses(pNamespace As %String, pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Set tSuper = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcess", ..#ENDPOINTTRANSFORMS: "Ens.DataTransform", : "Ens.Rule.Definition")
    Set tExcluded = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcessBPL", ..#ENDPOINTTRANSFORMS: "Ens.DataTransformDTL", : "")
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
        Set tStatusSC = tResultSet.Execute(tSuper)
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tName = tResultSet.GetData(1)
                If (tName = "") || (tName = tExcluded) Continue
                Set tModified = ""
                Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(tName)
                If $IsObject(tDefinition) {
                    If tDefinition.TimeChanged '= "" Set tModified = $ZDateTime(tDefinition.TimeChanged, 3)
                }
                Set tDefinition = ""
                Set tFound = tFound + 1
                Set tFound(tFound) = $ListBuild(tName, tModified)
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the " _ pEndpoint _ " list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the " _ pEndpoint _ " list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ ".cls", "string")
        Do tRow.%Set("Modified", $List(tFound(tI), 2) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The facts one state read gathers, in <var>pFacts</var>: <code>word</code>, the target's state
/// word (the current production's state word when it is the target, else <code>Stopped</code>, as the
/// vendor's own list reads it; a mirror backup's word is kept, and any other unnamed state reads
/// <code>Unknown</code>); <code>current</code>, the namespace's current production, <code>""</code>
/// when none; and <code>needsUpdate</code>, whether the vendor reports an update pending, asked only
/// when the target is current and running.</p>
/// <p>An id absent from <code>Ens.Config.Production</code> (exact) is 404 <code>PORT.NOTFOUND</code>,
/// unlogged. A lock the vendor cannot take is 503 <code>PORT.UNAVAILABLE</code>, for the status read and
/// for the update-pending read alike, since a busy answer is no answer.</p>
ClassMethod ReadState(pNamespace As %String, pId As %String, Output pFacts, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pFacts
    Set pHttpStatus = 0
    Set pFault = ""
    Set tCaught = ""
    Set tExists = 0
    Set tCurrent = ""
    Set tState = 0
    Set tStatusSC = $$$OK
    Set tNeeds = 0
    Set tNeedsKnown = 1
    Set tWord = "Unknown"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ''##class(Ens.Config.Production).%ExistsId(pId)
        If tExists {
            Set tStatusSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
            If $$$ISOK(tStatusSC) {
                Set tCurrent = $Get(tCurrent)
                If (tCurrent = pId) {
                    Set tTargetState = tState
                } Else {
                    Set tTargetState = $Select(tState < 0: -2, 1: 2)
                }
                Set tWord = ##class(Ens.Config.Production).ProductionStateToText(tTargetState, 0)
                If $Extract(tWord, 1, 13) = "Unrecognized:" Set tWord = "Unknown"
                If (tCurrent = pId) && (tState = 1) {
                    ; The vendor's quick lock gives up after a tenth of a second; a few more tries cost less
                    ; than a read refused as unavailable.
                    For tTry = 1:1:5 {
                        Set tNeeds = ''##class(Ens.Director).ProductionNeedsUpdate(.tReason, 1)
                        If $Get(tReason) '= -1 Quit
                        Hang 0.2
                    }
                    If $Get(tReason) = -1 Set tNeedsKnown = 0
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production state read failed", .pHttpStatus, .pFault)
    If 'tExists Quit ..Absent(.pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the production state read failed", .pHttpStatus, .pFault)
    If 'tNeedsKnown Quit ..Unavailable(.pHttpStatus, .pFault)
    Set pFacts("word") = tWord
    Set pFacts("current") = tCurrent
    Set pFacts("needsUpdate") = tNeeds
    Quit $$$OK
}

/// <p>The answer a state read or a write gives: <code>{Name, Namespace, State, Current,
/// NeedsUpdate}</code> from <var>pFacts</var>.</p>
ClassMethod StateRow(pNamespace As %String, pId As %String, ByRef pFacts) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", pId, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Do tRow.%Set("State", pFacts("word"), "string")
    Do tRow.%Set("Current", pFacts("current"), "string")
    Do tRow.%Set("NeedsUpdate", ''pFacts("needsUpdate"), "boolean")
    Quit tRow
}

/// <p>Run write <var>pType</var> against production <var>pId</var> in <var>pNamespace</var> and answer
/// the state it leaves. Stop, restart and update pass the production's own timeout capped at
/// <method>StopSeconds</method>. The vendor writes nothing to the current device (measured: no line on
/// a capture around each call, Story 20.2's Task 0), and no capture is opened here, because a capture
/// refuses to open inside another. Clean is never called.</p>
ClassMethod Perform(pNamespace As %String, pType As %String, pId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tCap = ..StopSeconds()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType = ..#TYPESTART {
            Set tVendorSC = ##class(Ens.Director).StartProduction(pId)
        } ElseIf pType = ..#TYPERECOVER {
            Set tVendorSC = ##class(Ens.Director).RecoverProduction()
        } ElseIf pType = ..#TYPEUPDATE {
            Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()
            If tTimeout > tCap Set tTimeout = tCap
            Set tVendorSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0)
        } Else {
            Set tTimeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()
            If tTimeout > tCap Set tTimeout = tCap
            If pType = ..#TYPESTOP {
                Set tVendorSC = ##class(Ens.Director).StopProduction(tTimeout, 0)
            } Else {
                Set tVendorSC = ##class(Ens.Director).RestartProduction(tTimeout, 0)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the production " _ pType _ " failed", .pHttpStatus, .pFault)
    Set tReadSC = ..ReadState(pNamespace, pId, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tReadSC) Quit tReadSC
    Set pResult = ..StateRow(pNamespace, pId, .tFacts)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The resource guarding <var>pNamespace</var>'s routines database, which an item write also needs
/// WRITE on, as <method>OcuPilot.Kernel.Shell.Namespaces.RoutineDatabase</method> reports it; 0 when the
/// instance reports none. Overridable so a fixture can name another resource, because in a namespace whose
/// routines and globals share a database no principal can hold one without the other; production never
/// overrides it.</p>
ClassMethod RoutineResource(pNamespace As %String, Output pResource As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(pNamespace, .pResource, .tReadOnly)
}

/// <p>Whether <var>pNamespace</var> is under source control, which refuses every item write. Overridable
/// so a fixture can answer 1; production never overrides it.</p>
ClassMethod SourceControlled(pNamespace As %String) As %Boolean
{
    Quit ''##class(%CSP.Portal.SourceControl.Util).IsEnabled(pNamespace)
}

/// <p>Serve the Items endpoint (Story 20.3) after <method>Invoke</method>'s gate. A <code>LIST</code> names
/// its production under <parameter>PRODUCTIONKEY</parameter>; every other type names an item by the
/// composite id <code>[Production, Name]</code> under <parameter>IDKEY</parameter>, never by the vendor's
/// integer id, which a recompile renumbers.</p>
ClassMethod InvokeItems(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tProduction = $Get(pQuery(..#PRODUCTIONKEY))
            If tProduction = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListItems(pNamespace, tProduction, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
        If ($ListLength(tParts) '= 2) || ($List(tParts, 1) = "") || ($List(tParts, 2) = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tProduction = $List(tParts, 1)
        Set tName = $List(tParts, 2)
        Set tAction = $Select(..IsItemWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsItemWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsItemWrite(pType) {
            Set tSC = ..PerformItem(pNamespace, pType, tProduction, tName, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadItem(pNamespace, tProduction, tName, tAction, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the item call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pName</var> breaks the item name rule, as <code>OcuPilot.Api.InteropError.ITEMNAME</code>,
/// else <code>""</code> (Story 20.3). It mirrors <code>Ens.Config.Item.CheckForIllegalCharacters</code>, which
/// the vendor runs at <code>%Save</code>: none of <code>| ; , [</code>, not beginning with <code>-</code> or
/// <code>_</code>, not ending with <code>-</code>, <code>!</code> or <code>$</code>, and not <code>*</code>.
/// It adds the 128-character limit and refuses a control character and a space at either end. Pure, so it
/// runs before the namespace is switched.</p>
ClassMethod NameProblem(pName As %String) As %String
{
    Set tProblem = ##class(OcuPilot.Api.InteropError).#ITEMNAME
    If (pName = "") || ($Length(pName) > 128) Quit tProblem
    If $ZStrip(pName, "<>", " ") '= pName Quit tProblem
    If $ZStrip(pName, "*C") '= pName Quit tProblem
    If (pName [ "|") || (pName [ ";") || (pName [ ",") || (pName [ "[") Quit tProblem
    If $Extract(pName) = "-" Quit tProblem
    If $Extract(pName) = "_" Quit tProblem
    If ($Extract(pName, *) = "-") || ($Extract(pName, *) = "!") || ($Extract(pName, *) = "$") Quit tProblem
    If pName = "*" Quit tProblem
    Quit ""
}

/// <p>Every rule over an add's fields, in <var>pViolations</var> as <code>pViolations(n) =
/// $ListBuild(field, code)</code> with the count in <code>pViolations</code> (Story 20.3): the name
/// (<method>NameProblem</method>); <code>ClassName</code> must be a class of <var>pNamespace</var> that
/// <code>Ens.Config.Item</code> types as a business service, process or operation; <code>PoolSize</code>,
/// <code>Category</code> and <code>Comment</code> must be what <code>Ens.Config.Item</code>'s own
/// <code>&lt;Prop&gt;IsValid</code> accepts; <code>Enabled</code> must be a boolean. A field of the wrong
/// JSON type is <code>PORT.FIELD.SHAPE</code>. The vendor classes run in <var>pNamespace</var>, switched
/// by explicit save and restore, and only once this port's gate admits an add there (<method>Admit</method>);
/// when it does not, only the rules that need no vendor class are judged, and the caller's next
/// <method>Invoke</method> answers the gate's refusal.</p>
ClassMethod AddViolations(pNamespace As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tAdmitted = $$$ISOK(..Admit(..#ENDPOINTITEMS, ..#TYPEADD, pNamespace, .tHttp, .tFault))
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        If ..NameProblem(pName) '= "" Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#ITEMNAME)
        Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
        Set tCodeClass = ##class(OcuPilot.Api.InteropError).#ITEMCLASS
        Set tCodeValue = ##class(OcuPilot.Api.InteropError).#ITEMVALUE
        Set tClassType = pBody.%GetTypeOf("ClassName")
        Set tClass = ""
        If tClassType = "string" Set tClass = pBody.%Get("ClassName")
        Set tClassOk = 0
        If (tClassType '= "string") && (tClassType '= "unassigned") {
            Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tShape)
        } ElseIf '$Match(tClass, "^[A-Za-z%][A-Za-z0-9%._]*$") || ($Length(tClass) > 128) {
            Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tCodeClass)
        } Else {
            Set tClassOk = 1
        }
        Set tPoolType = pBody.%GetTypeOf("PoolSize")
        Set tCategoryType = pBody.%GetTypeOf("Category")
        Set tCommentType = pBody.%GetTypeOf("Comment")
        Set tEnabledType = pBody.%GetTypeOf("Enabled")
        If (tPoolType '= "unassigned") && (tPoolType '= "number") Set pViolations($Increment(pViolations)) = $ListBuild("PoolSize", tShape)
        If (tCategoryType '= "unassigned") && (tCategoryType '= "string") Set pViolations($Increment(pViolations)) = $ListBuild("Category", tShape)
        If (tCommentType '= "unassigned") && (tCommentType '= "string") Set pViolations($Increment(pViolations)) = $ListBuild("Comment", tShape)
        If (tEnabledType '= "unassigned") && (tEnabledType '= "boolean") Set pViolations($Increment(pViolations)) = $ListBuild("Enabled", tShape)
        If 'tAdmitted Quit
        Set $NAMESPACE = pNamespace
        If tClassOk {
            Set tItem = ##class(Ens.Config.Item).%New(tClass)
            Set tBusinessType = tItem.BusinessType()
            Set tItem = ""
            If (tBusinessType '= 1) && (tBusinessType '= 2) && (tBusinessType '= 3) Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tCodeClass)
        }
        If (tPoolType = "number") && '##class(Ens.Config.Item).PoolSizeIsValid(pBody.%Get("PoolSize")) Set pViolations($Increment(pViolations)) = $ListBuild("PoolSize", tCodeValue)
        If (tCategoryType = "string") && '##class(Ens.Config.Item).CategoryIsValid(pBody.%Get("Category")) Set pViolations($Increment(pViolations)) = $ListBuild("Category", tCodeValue)
        If (tCommentType = "string") && '##class(Ens.Config.Item).CommentIsValid(pBody.%Get("Comment")) Set pViolations($Increment(pViolations)) = $ListBuild("Comment", tCodeValue)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> holds the production <var>pProduction</var>. A namespace this port's gate
/// does not admit an item read in (<method>Admit</method>), and a fault in the look-up, answer 1 without a
/// vendor call, so the write's own refusal decides rather than this one.</p>
ClassMethod ProductionHeld(pNamespace As %String, pProduction As %String) As %Boolean
{
    If $$$ISERR(..Admit(..#ENDPOINTITEMS, ..#TYPEITEM, pNamespace, .tHttp, .tFault)) Quit 1
    Set tSC = ..GatherItems(pNamespace, pProduction, "", 1, .tExists, .tFound, .tCount, .tCaught)
    Quit $IsObject(tCaught) || tExists
}

/// <p>The 422 refusal an add's <var>pViolations</var> earn (AD-39): the envelope carries the first
/// violation's code and sentence and <code>detail.violations</code> every one.</p>
ClassMethod Violations(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {"violations": []}
    For tI = 1:1:pViolations {
        Set tCode = $List(pViolations(tI), 2)
        Do tDetail.%Get("violations").%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (##class(OcuPilot.Api.Error).ReasonForViolation(tCode))})
    }
    Set tFirst = $List(pViolations(1), 2)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tFirst, ##class(OcuPilot.Api.Error).ReasonForViolation(tFirst), .pHttpStatus, .pFault, tDetail)
}

/// <p>The item code an item write <var>pType</var> is refused with, or <code>""</code> when it may go
/// ahead (Story 20.3): whatever the vendor would store twice, answer as a silent success, or change in the
/// wrong place is refused here by its own name. <var>pCount</var> is how many items of the name the
/// production holds (without regard to case), <var>pEnabled</var> the first one's effective
/// <code>Enabled</code>, <var>pSource</var> <code>default</code> when a system default supplies it,
/// <var>pBusinessType</var> its host type code and <var>pPoolSize</var> its pool size. Pure.</p>
/// <ul>
/// <li>Add: <code>TAKEN</code> when the name is held.</li>
/// <li>Any other write: <code>AMBIGUOUS</code> when more than one item holds the name.</li>
/// <li>Enable: <code>ENABLED</code> when it is, else <code>DEFAULTSETTING</code> when a system default
/// supplies <code>Enabled</code>.</li>
/// <li>Disable: <code>DISABLED</code> when it is, then <code>DEFAULTSETTING</code>, then
/// <code>POOLZERO</code> for a business process whose pool size is 0.</li>
/// <li>Remove: <code>DEFAULTSETTING</code> while a system default keeps it enabled, else
/// <code>ENABLEDREMOVE</code> while it is enabled.</li>
/// </ul>
ClassMethod ItemRefusal(pType As %String, pCount As %Integer, pEnabled As %Boolean, pSource As %String, pBusinessType As %Integer, pPoolSize As %String) As %String
{
    Quit ..ItemCode(..ItemRefusalToken(pType, pCount, pEnabled, pSource, pBusinessType, pPoolSize))
}

/// <p><method>ItemRefusal</method>'s decision as the last segment of the code (<code>ENABLED</code>,
/// <code>TAKEN</code> and so on), <code>""</code> for none. It names no other class, so it runs while the
/// production's namespace is switched, where a reference to another OcuPilot class does not resolve.</p>
ClassMethod ItemRefusalToken(pType As %String, pCount As %Integer, pEnabled As %Boolean, pSource As %String, pBusinessType As %Integer, pPoolSize As %String) As %String
{
    If pType = ..#TYPEADD {
        If pCount > 0 Quit "TAKEN"
        Quit ""
    }
    If pCount > 1 Quit "AMBIGUOUS"
    If pType = ..#TYPEENABLE {
        If pEnabled Quit "ENABLED"
        If pSource = "default" Quit "DEFAULTSETTING"
        Quit ""
    }
    If pType = ..#TYPEDISABLE {
        If 'pEnabled Quit "DISABLED"
        If pSource = "default" Quit "DEFAULTSETTING"
        If (pBusinessType = 2) && (pPoolSize = 0) Quit "POOLZERO"
        Quit ""
    }
    If pType = ..#TYPEREMOVE {
        If pEnabled && (pSource = "default") Quit "DEFAULTSETTING"
        If pEnabled Quit "ENABLEDREMOVE"
        Quit ""
    }
    Quit ""
}

/// <p>Whether an enable or a disable (<var>pType</var>) of the one item <var>pLine</var>
/// (<method>GatherItems</method>'s element, <var>pCount</var> items of the name) would not find it:
/// <code>Ens.Director:EnableConfigItem</code> skips an item whose class it types as no business host and
/// answers <code>ErrConfigItemNotFound</code>, so such an item reads absent to an enable and a disable, as it
/// does to the vendor. It names no other class, so it runs while the production's namespace is switched.</p>
ClassMethod VendorCannotFind(pType As %String, pCount As %Integer, pLine As %List) As %Boolean
{
    If (pType '= ..#TYPEENABLE) && (pType '= ..#TYPEDISABLE) Quit 0
    If (pCount '= 1) || (pLine = "") Quit 0
    Quit (+$List(pLine, 3) = 0)
}

/// <p>The code <var>pToken</var> names: <code>INTEROP.ITEM.</code> and the token; <code>""</code> for no
/// token.</p>
ClassMethod ItemCode(pToken As %String) As %String
{
    If pToken = "" Quit ""
    Quit ..#ITEMCODEPREFIX _ pToken
}

/// <p>Read the items of <var>pProduction</var> in <var>pNamespace</var> whose name is <var>pName</var>
/// without regard to case, or every item when it is <code>""</code> (at most <var>pMax</var> of them when
/// that is above zero), without changing anything. <var>pExists</var> is whether the production is there.
/// <var>pFound(n)</var> is <code>$ListBuild(Name, ClassName, Type code, Enabled, EnabledSource, PoolSize,
/// Category, Comment)</code>, <code>Enabled</code> the effective value and <code>EnabledSource</code>
/// <code>default</code> when a system default supplies it, <code>production</code> else, as the vendor's own
/// check reads it (<code>Ens.Config.DefaultSettings:%GetSetting</code>). <var>pCount</var> counts every item
/// of the name. A fault is <var>pCaught</var>, with the namespace restored. Only vendor classes and this
/// class run while the namespace is switched.</p>
ClassMethod GatherItems(pNamespace As %String, pProduction As %String, pName As %String, pMax As %Integer, Output pExists As %Boolean, ByRef pFound, Output pCount As %Integer, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pExists = 0
    Set pCount = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pExists = ''##class(Ens.Config.Production).%ExistsId(pProduction)
        If pExists {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
            If $IsObject(tProduction) {
                Set tWanted = $ZConvert(pName, "U")
                For tI = 1:1:tProduction.Items.Count() {
                    Set tItem = tProduction.Items.GetAt(tI)
                    If '$IsObject(tItem) Continue
                    If (pName '= "") && ($ZConvert(tItem.Name, "U") '= tWanted) Continue
                    Set pCount = pCount + 1
                    If (pMax > 0) && (pFound >= pMax) Quit
                    Set tClass = tItem.ClassName
                    Set tEnabled = ''tItem.Enabled
                    Set tSource = "production"
                    If ##class(Ens.Config.DefaultSettings).%GetSetting(pProduction, tItem.Name, tClass, "", "Enabled", .tDefault) {
                        Set tEnabled = ''(+tDefault)
                        Set tSource = "default"
                    }
                    Set pFound($Increment(pFound)) = $ListBuild(tItem.Name, tClass, ##class(Ens.Config.Item).GetBusinessType(tClass, tItem), tEnabled, tSource, tItem.PoolSize, tItem.Category, tItem.Comment)
                }
            }
            Set tItem = ""
            Set tProduction = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The item row <var>pLine</var> (<method>GatherItems</method>'s element) of <var>pProduction</var> as
/// the list and the item read answer it: <code>{Production, Name, ClassName, Type, Enabled,
/// EnabledSource, PoolSize, Category, Comment}</code>, <code>Type</code> one of <code>service</code>,
/// <code>process</code>, <code>operation</code> and <code>unknown</code>; with <var>pNamespace</var> and
/// <var>pCount</var> it also carries <code>Namespace</code> and <code>Count</code>.</p>
ClassMethod ItemRow(pProduction As %String, pLine As %List, pNamespace As %String = "", pCount As %Integer = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("ClassName", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("Type", $Case($List(pLine, 3), 1: "service", 2: "process", 3: "operation", : "unknown"), "string")
    Do tRow.%Set("Enabled", ''$List(pLine, 4), "boolean")
    Do tRow.%Set("EnabledSource", $List(pLine, 5), "string")
    Do tRow.%Set("PoolSize", +$List(pLine, 6), "number")
    Do tRow.%Set("Category", $List(pLine, 7) _ "", "string")
    Do tRow.%Set("Comment", $List(pLine, 8) _ "", "string")
    If pNamespace '= "" {
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do tRow.%Set("Count", +pCount, "number")
    }
    Quit tRow
}

/// <p>The items of <var>pProduction</var>, one row per item in the production's order, at most
/// <var>pMax</var> when it is above zero. An unknown production is 404 <code>PORT.NOTFOUND</code>,
/// unlogged.</p>
ClassMethod ListItems(pNamespace As %String, pProduction As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherItems(pNamespace, pProduction, "", pMax, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item list failed", .pHttpStatus, .pFault)
    If 'tExists Quit ..Absent(.pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..ItemRow(pProduction, tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One item, fresh (Story 20.3): the item row with <code>Namespace</code> and <code>Count</code>.
/// A namespace under source control is <code>INTEROP.ITEM.SOURCECONTROL</code> first; an item the
/// production does not hold, or a production it does not hold, is 404 <code>PORT.NOTFOUND</code>,
/// unlogged, and so is an item an enable or a disable would not find (<method>VendorCannotFind</method>); a
/// name the production holds more than once is <code>AMBIGUOUS</code>. With <var>pAction</var> it refuses
/// what that action would be refused
/// (<method>ItemRefusal</method>); for an add (AD-54) it inverts, so absence is the 404 the create
/// expects and a held name is <code>TAKEN</code>.</p>
ClassMethod ReadItem(pNamespace As %String, pProduction As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADD {
        If tCount > 0 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMTAKEN, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    Set tLine = tFound(1)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    If ..VendorCannotFind(pAction, tCount, tLine) Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tCode = ..ItemRefusal(pAction, tCount, $List(tLine, 4), $List(tLine, 5), $List(tLine, 3), $List(tLine, 6))
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    Set pRow = ..ItemRow(pProduction, tLine, pNamespace, tCount)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The in-memory item of <var>pProduction</var> named exactly <var>pName</var>, or <code>""</code>.
/// Called while the production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemObject(pProduction As Ens.Config.Production, pName As %String) As Ens.Config.Item [ Private ]
{
    Set tFound = ""
    For tI = 1:1:pProduction.Items.Count() {
        Set tItem = pProduction.Items.GetAt(tI)
        If $IsObject(tItem) && (tItem.Name = pName) {
            Set tFound = tItem
            Quit
        }
    }
    Quit tFound
}

/// <p>Run item write <var>pType</var> against the item <var>pName</var> of <var>pProduction</var> in
/// <var>pNamespace</var>, and answer the item as it stands (Story 20.3). It changes the stored production
/// configuration and the production class and nothing else: it never updates, starts, stops or recovers a
/// production, so a running one reads update pending until 20.2's confirmed Update applies the change.
/// The sequence, in one switched block:</p>
/// <ol>
/// <li>A namespace under source control is refused, before anything is read.</li>
/// <li>An add's fields are validated (<method>AddViolations</method>): 422.</li>
/// <li>The production is opened at concurrency 4, so writers on one production wait on the vendor's row
/// lock; a lock not taken in time is 503 <code>PORT.UNAVAILABLE</code>.</li>
/// <li>The item's facts are read under that lock and judged by <method>ItemRefusal</method>: 409.</li>
/// <li>Enable and disable call <code>Ens.Director:EnableConfigItem</code> with no update; add inserts a new
/// <code>Ens.Config.Item</code> and saves the production; remove calls <code>RemoveItem</code> and saves
/// it. Add and remove record <code>%Ensemble/%Production/ModifyConfiguration</code> through
/// <code>Ens.Util.Auditing</code>, naming the operation and the item and never a value; enable and
/// disable carry the vendor's own event. The vendor answers an error status only when the audit call
/// raises (an event that is disabled is dropped without one); that status is logged once the namespace is
/// restored and never fails the write.</li>
/// <li>The production class is saved every time (<code>SaveToClass</code>), because the configuration
/// alone is reverted by the next compile of the class. A failure there, after the configuration saved, is
/// a logged 500.</li>
/// </ol>
/// <p>Every reference is dropped before the namespace is restored.</p>
ClassMethod PerformItem(pNamespace As %String, pType As %String, pProduction As %String, pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSettingTarget As %String = "", pSettingName As %String = "") As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSetting = ..IsSettingWrite(pType)
    If pType = ..#TYPESET {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        Set tViolationSC = ..SettingViolations(pNamespace, pProduction, pName, pSettingTarget, pSettingName, pBody, .tViolations)
        If $$$ISERR(tViolationSC) Quit ..Fail("the setting's value could not be judged", tViolationSC, .pHttpStatus, .pFault)
        If tViolations > 0 Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If pType = ..#TYPEADD {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        Set tViolationSC = ..AddViolations(pNamespace, pName, pBody, .tViolations)
        If $$$ISERR(tViolationSC) Quit ..Fail("the item's fields could not be judged", tViolationSC, .pHttpStatus, .pFault)
        If tViolations > 0 Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tCaught = ""
    Set tAbsent = 0
    Set tBusy = 0
    Set tRefusal = ""
    Set tVendorSC = $$$OK
    Set tSaveSC = $$$OK
    Set tAuditSC = $$$OK
    Set tAfter = ""
    Set tCount = 0
    Set tLocation = ""
    Set tItemName = pName
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(Ens.Config.Production).%ExistsId(pProduction) {
            Set tAbsent = 1
        } Else {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction, 4)
            If '$IsObject(tProduction) {
                Set tBusy = 1
            } ElseIf tSetting {
                Do ..SettingStep(pNamespace, pType, pProduction, pName, pSettingTarget, pSettingName, pBody, tOrigNS, tProduction, .tStep)
                Set tAbsent = tStep("absent")
                Set tRefusal = tStep("refusal")
                Set tLocation = tStep("location")
                Set tVendorSC = tStep("vendor")
                Set tAuditSC = tStep("audit")
                Set tSaveSC = tStep("save")
                Set tAfter = tStep("after")
                Set tCount = tStep("afterCount")
                Set tItemName = tStep("itemName")
            } Else {
                Set tFactsSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tGatherCaught)
                If $IsObject(tGatherCaught) Throw tGatherCaught
                Set tLine = $Get(tFound(1))
                If (pType '= ..#TYPEADD) && (tCount = 0) {
                    Set tAbsent = 1
                } ElseIf ..VendorCannotFind(pType, tCount, tLine) {
                    Set tAbsent = 1
                } Else {
                    If tLine = "" {
                        Set tRefusal = ..ItemRefusalToken(pType, tCount, 0, "", 0, "")
                    } Else {
                        Set tRefusal = ..ItemRefusalToken(pType, tCount, $List(tLine, 4), $List(tLine, 5), $List(tLine, 3), $List(tLine, 6))
                    }
                }
                If (tRefusal = "") && 'tAbsent {
                    Set tName = $Select(tLine = "": pName, 1: $List(tLine, 1))
                    Set tTarget = ""
                    If (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) {
                        Set tVendorSC = ##class(Ens.Director).EnableConfigItem(pProduction _ "||" _ tName, (pType = ..#TYPEENABLE), 0)
                        If $$$ISOK(tVendorSC) Set tSaveSC = tProduction.SaveToClass(..ItemObject(tProduction, tName))
                    } ElseIf pType = ..#TYPEADD {
                        Set tNew = ##class(Ens.Config.Item).%New(pBody.%Get("ClassName"))
                        Set tNew.Name = pName
                        Set tNew.Enabled = $Select(pBody.%GetTypeOf("Enabled") = "boolean": pBody.%Get("Enabled"), 1: 0)
                        If pBody.%GetTypeOf("PoolSize") = "number" Set tNew.PoolSize = pBody.%Get("PoolSize")
                        If pBody.%GetTypeOf("Category") = "string" Set tNew.Category = pBody.%Get("Category")
                        If pBody.%GetTypeOf("Comment") = "string" Set tNew.Comment = pBody.%Get("Comment")
                        Do tProduction.Items.Insert(tNew)
                        Set tVendorSC = tProduction.%Save()
                        If $$$ISOK(tVendorSC) {
                            Set tActions = "item added by OcuPilot"
                            Set tAuditSC = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, pName, .tActions)
                            Set tSaveSC = tProduction.SaveToClass(tNew)
                        }
                        Set tNew = ""
                    } Else {
                        Set tTarget = ..ItemObject(tProduction, tName)
                        Do tProduction.RemoveItem(tTarget)
                        Set tTarget = ""
                        Set tVendorSC = tProduction.%Save()
                        If $$$ISOK(tVendorSC) {
                            Set tActions = "item removed by OcuPilot"
                            Set tAuditSC = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, tName, .tActions)
                            Set tSaveSC = tProduction.SaveToClass()
                        }
                    }
                    If $$$ISOK(tVendorSC) && (pType '= ..#TYPEREMOVE) {
                        Set tAfterSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tAfterExists, .tAfterFound, .tAfterCount, .tAfterCaught)
                        If $IsObject(tAfterCaught) Throw tAfterCaught
                        If tAfterCount > 0 Set tAfter = tAfterFound(1)
                    }
                }
            }
        }
        Set tTarget = ""
        Set tNew = ""
        Set tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        ; The production's lock is released in the namespace it was taken in: a setting write may have left it to
        ; judge a server path.
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tTarget = "", tNew = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $$$ISERR(tAuditSC) Do ..LogFault("the item " _ pType _ " was saved but its audit record could not be written", tAuditSC)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If tAbsent Quit ..Absent(.pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tSetting && (tRefusal '= "") Quit ..Conflict(..SettingCode(tRefusal), .pHttpStatus, .pFault)
    If tRefusal '= "" Quit ..Conflict(..ItemCode(tRefusal), .pHttpStatus, .pFault)
    If tLocation '= "" {
        If pType = ..#TYPERESET Quit ..ConflictFor(tLocation, .pHttpStatus, .pFault)
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("Value", tLocation)
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tSaveSC) Quit ..Fail("the production class could not be saved after the item " _ pType, tSaveSC, .pHttpStatus, .pFault)
    If tSetting && (tAfter '= "") {
        Set pResult = ..SettingRow(pProduction, tItemName, tAfter, pNamespace, tCount)
    } ElseIf tAfter = "" {
        Set pResult = {}
        Do pResult.%Set("Production", pProduction, "string")
        Do pResult.%Set("Name", pName, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Do pResult.%Set("Count", 0, "number")
    } Else {
        Set pResult = ..ItemRow(pProduction, tAfter, pNamespace, tAfterCount)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Settings endpoint (Story 20.22) after <method>Invoke</method>'s gate. A <code>LIST</code> names its
/// item under <parameter>ITEMKEY</parameter>; every other type names a setting by the composite id
/// <code>[Production, Item, Target, Name]</code> under <parameter>IDKEY</parameter>. A setting whose name the
/// credential pattern matches is refused <code>INTEROP.SETTING.SECRET</code> for a write and for a read composed for
/// one, on the name alone, before the namespace is switched.</p>
ClassMethod InvokeSettings(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListSettings(pNamespace, tProduction, tItem, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
        Set tValid = ($ListLength(tParts) = 4)
        For tI = 1:1:$Select(tValid: 4, 1: 0) {
            If $List(tParts, tI) = "" Set tValid = 0
        }
        If tValid && '$ListFind($ListBuild(..#TARGETCORE, ..#TARGETHOST, ..#TARGETADAPTER), $List(tParts, 3)) Set tValid = 0
        If 'tValid {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSETTINGID, .pHttpStatus, .pFault)
            Quit
        }
        Set tProduction = $List(tParts, 1)
        Set tItem = $List(tParts, 2)
        Set tTarget = $List(tParts, 3)
        Set tSetting = $List(tParts, 4)
        Set tAction = $Select(..IsSettingWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsSettingWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If (tAction '= "") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tSetting) {
            Set tSC = ..Conflict(##class(OcuPilot.Api.InteropError).#SETTINGSECRET, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsSettingWrite(pType) {
            Set tSC = ..PerformItem(pNamespace, pType, tProduction, tItem, pBody, .pResult, .pHttpStatus, .pFault, tTarget, tSetting)
            Quit
        }
        Set tSC = ..ReadSetting(pNamespace, tProduction, tItem, tTarget, tSetting, tAction, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the setting call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The production and the item <var>pText</var> names, in <var>pProduction</var> and <var>pItem</var>: the item's
/// composite id <code>[Production, Name]</code>, or the vendor's config name <code>Production||Name</code>. Neither
/// name can hold a vertical bar, so a text with another is not one. Pure.</p>
ClassMethod ItemParts(pText As %String, Output pProduction As %String, Output pItem As %String) As %Boolean
{
    Set pProduction = ""
    Set pItem = ""
    If pText = "" Quit 0
    If pText [ $Char(1) {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pText)
        If $ListLength(tParts) '= 2 Quit 0
        Set pProduction = $List(tParts, 1)
        Set pItem = $List(tParts, 2)
    } ElseIf pText [ "||" {
        Set pProduction = $Piece(pText, "||", 1)
        Set pItem = $Piece(pText, "||", 2, *)
    } Else {
        Quit 0
    }
    If (pProduction = "") || (pItem = "") || (pProduction [ "|") || (pItem [ "|") {
        Set pProduction = ""
        Set pItem = ""
        Quit 0
    }
    Quit 1
}

/// <p>The decision on a setting read or write, as the last segment of the code (<code>AMBIGUOUS</code>,
/// <code>SUPPLIED</code>, <code>CORE</code>, <code>DEFAULTED</code>), <code>""</code> for none (Story 20.22). It names
/// no other class, so it runs while the production's namespace is switched. <var>pSource</var> is the setting's value
/// source (1 production, 2 system default, 3 class default, 4 service registry), <var>pCount</var> how many items
/// of the name the production holds. Pure.</p>
/// <ul>
/// <li>More than one item of the name: <code>AMBIGUOUS</code>, which is <code>INTEROP.ITEM.AMBIGUOUS</code>.</li>
/// <li>A value a service registry entry supplies, and a Core setting a system default supplies:
/// <code>SUPPLIED</code>.</li>
/// <li>Reset: <code>CORE</code> for one of the item's own properties, then <code>DEFAULTED</code> when the
/// production holds no value of its own.</li>
/// </ul>
ClassMethod SettingRefusalToken(pType As %String, pTarget As %String, pSource As %Integer, pCount As %Integer) As %String
{
    If pCount > 1 Quit "AMBIGUOUS"
    If pSource = 4 Quit "SUPPLIED"
    If (pTarget = "Core") && (pSource = 2) Quit "SUPPLIED"
    If pType = "RESET" {
        If pTarget = "Core" Quit "CORE"
        If pSource '= 1 Quit "DEFAULTED"
    }
    Quit ""
}

/// <p>The code <var>pToken</var> names (<method>SettingRefusalToken</method>, or <code>SAME</code>):
/// <code>INTEROP.ITEM.AMBIGUOUS</code> for <code>AMBIGUOUS</code>, else <code>INTEROP.SETTING.</code> and the token;
/// <code>""</code> for no token.</p>
ClassMethod SettingCode(pToken As %String) As %String
{
    If pToken = "" Quit ""
    If pToken = "AMBIGUOUS" Quit ..#ITEMCODEPREFIX _ pToken
    Quit ..#SETTINGCODEPREFIX _ pToken
}

/// <p>Whether a set of <var>pValue</var> would store what the production already holds (Story 20.22): its own
/// value for a Host or Adapter setting (<var>pSource</var> 1), the property's for one of the item's own. Pure.</p>
ClassMethod SameValue(pTarget As %String, pSource As %Integer, pHeld As %String, pValue As %String) As %Boolean
{
    If (pTarget '= "Core") && (pSource '= 1) Quit 0
    Quit (pHeld = pValue)
}

/// <p>The word for a value source code, <code>""</code> for any other: <code>production</code>,
/// <code>systemDefault</code>, <code>classDefault</code> or <code>registry</code>. Pure.</p>
ClassMethod SourceWord(pCode As %Integer) As %String
{
    Quit $Case(+pCode, 1: "production", 2: "systemDefault", 3: "classDefault", 4: "registry", : "")
}

/// <p><code>directory</code> when the editor context <var>pContext</var> has the component
/// <parameter>LOCATIONDIRECTORY</parameter> (the part before <code>?</code>), <code>file</code> for
/// <parameter>LOCATIONFILE</parameter>, else <code>""</code> (Story 20.22). A setting of either kind is a location on
/// the server. Pure.</p>
ClassMethod LocationKind(pContext As %String) As %String
{
    Set tComponent = $Piece(pContext, "?", 1)
    If tComponent = ..#LOCATIONDIRECTORY Quit "directory"
    If tComponent = ..#LOCATIONFILE Quit "file"
    Quit ""
}

/// <p>The class that answers the path predicates (AD-21, AD-62). Overridable so a fixture can move the served
/// directory; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p><var>pValue</var> as the running process resolves it, in the current namespace, where a relative value is read
/// against that namespace's database directory: <code>%File</code>'s one-argument <code>NormalizeDirectory</code> for a
/// <code>directory</code>, <code>NormalizeFilename</code> for a <code>file</code>; <code>""</code> for either other
/// kind and for an empty value. It names no other OcuPilot class, so it runs while the production's namespace is
/// switched.</p>
ClassMethod NormalizeLocation(pKind As %String, pValue As %String) As %String
{
    If pValue = "" Quit ""
    If pKind = "directory" Quit ##class(%File).NormalizeDirectory(pValue)
    If pKind = "file" Quit ##class(%File).NormalizeFilename(pValue)
    Quit ""
}

/// <p>The code a server path is refused with, or <code>""</code> (Story 20.22): the self-protection <class>OcuPilot.Port.PathPort</class>
/// keeps, evaluated through <method>PathPortClass</method> on <var>pNormalized</var>, the value as
/// <method>NormalizeLocation</method> answers it. A <code>directory</code> is refused for the manager directory
/// itself (<code>PATH.MANAGERDIR</code>) and for the served directory or anything under it
/// (<code>PATH.SERVED</code>); with <var>pLevels</var> above zero, also when the adapter would descend that many
/// levels into either (<method>DescentReaches</method>). A <code>file</code> is refused directly in the manager
/// directory (<code>PATH.MANAGER</code>) and under the served directory (<code>PATH.SERVED</code>). The order is
/// <method>OcuPilot.Port.PathPort.Resolve</method>'s. Runs only in the install namespace.</p>
ClassMethod LocationProblem(pKind As %String, pNormalized As %String, pLevels As %Integer = 0) As %String
{
    If pNormalized = "" Quit ""
    Set tPath = ..PathPortClass()
    If pKind = "directory" {
        If $ClassMethod(tPath, "IsManagerDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHMANAGERDIR
        If $ClassMethod(tPath, "InServedDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHSERVED
        If (+pLevels > 0) && ..DescentReaches(pNormalized, pLevels) Quit ##class(OcuPilot.Api.InteropError).#SETTINGDESCENT
        Quit ""
    }
    If pKind = "file" {
        If $ClassMethod(tPath, "DirectlyInManagerDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHMANAGER
        If $ClassMethod(tPath, "InServedDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHSERVED
    }
    Quit ""
}

/// <p>Whether an adapter that starts in the normalized directory <var>pDirectory</var> and descends
/// <var>pLevels</var> levels of subdirectories would enter the manager directory or the directory OcuPilot serves
/// its files from (Story 20.22). Each is read through <method>PathPortClass</method> and normalized; one that lies
/// strictly below <var>pDirectory</var> is approached one segment at a time up to <var>pLevels</var>, and each
/// directory entered is tested with the same predicates the directory itself is. Textual, as the predicates are.
/// Runs only in the install namespace.</p>
ClassMethod DescentReaches(pDirectory As %String, pLevels As %Integer) As %Boolean
{
    If (pDirectory = "") || (+pLevels < 1) Quit 0
    Set tPath = ..PathPortClass()
    Set tDirectory = ##class(%File).NormalizeDirectory(pDirectory)
    If tDirectory = "" Quit 0
    Set tSeparator = $Extract(tDirectory, *)
    Set tReached = 0
    For tMethod = "ManagerDirectory", "ServedDirectory" {
        Set tProtected = $ClassMethod(tPath, tMethod)
        If tProtected '= "" Set tProtected = ##class(%File).NormalizeDirectory(tProtected)
        If (tProtected = "") || (tProtected = tDirectory) Continue
        If '$ClassMethod(tPath, "Contains", tDirectory, tProtected) Continue
        Set tRelative = $Extract(tProtected, $Length(tDirectory) + 1, *)
        Set tDepth = $Length(tRelative, tSeparator) - 1
        Set tCandidate = tDirectory
        For tK = 1:1:$Select(tDepth < +pLevels: tDepth, 1: +pLevels) {
            Set tCandidate = tCandidate _ $Piece(tRelative, tSeparator, tK) _ tSeparator
            If $ClassMethod(tPath, "IsManagerDirectory", tCandidate) || $ClassMethod(tPath, "InServedDirectory", tCandidate) {
                Set tReached = 1
                Quit
            }
        }
        If tReached Quit
    }
    Quit tReached
}

/// <p>The code the change <var>pFacts</var> describes is refused with on a server path, or <code>""</code> (Story
/// 20.22). <var>pFacts</var> is <method>SettingFacts</method>'s. A change of the subdirectory levels is judged by
/// <method>DescentReaches</method> alone, on the effective file path and the levels that would take effect; any
/// other location is judged by <method>LocationProblem</method>, with the effective levels when it is the file path of
/// an item that holds both settings. Runs only in the install namespace.</p>
ClassMethod ChangeProblem(ByRef pFacts) As %String
{
    Set tTarget = $Get(pFacts("target"))
    Set tName = $Get(pFacts("name"))
    Set tDescent = +$Get(pFacts("hasDescent")) && (tTarget = ..#TARGETADAPTER)
    If tDescent && (tName = ..#DESCENTSETTING) {
        If $Get(pFacts("pathNorm")) = "" Quit ""
        If ..DescentReaches(pFacts("pathNorm"), +$Get(pFacts("newValue"))) Quit ##class(OcuPilot.Api.InteropError).#SETTINGDESCENT
        Quit ""
    }
    Set tLevels = $Select(tDescent && (tName = ..#DESCENTPATH): +$Get(pFacts("levels")), 1: 0)
    Quit ..LocationProblem($Get(pFacts("kind")), $Get(pFacts("normalized")), tLevels)
}

/// <p>The item <var>pItem</var> of <var>pProduction</var> in <var>pNamespace</var>, whose name matches without
/// regard to case, with its settings (Story 20.22). <var>pExists</var> is whether the production is there,
/// <var>pCount</var> how many items bear the name; only when it is one are <var>pFound</var> and
/// <var>pFacts</var> filled. <var>pFound(n)</var> is <code>$ListBuild(Target, Name, Value, Source code, Default,
/// DefaultSource code, Type, Category, EditorContext, Value normalized, Default normalized)</code>: the item's own
/// settable properties first (<code>Core</code>, less the read-only ones and <code>Enabled</code>), then its Host
/// settings, then its Adapter settings, each value the effective one. The two normalized values are the value and
/// the default of a server path as <method>NormalizeLocation</method> reads them in this namespace, else
/// <code>""</code>. <var>pFacts</var> holds <code>name</code>, <code>class</code> and <code>adapter</code>, the item's
/// own name and its host and adapter classes. A fault is <var>pCaught</var>, with the namespace restored. Only
/// vendor classes and this class run while the namespace is switched.</p>
ClassMethod GatherSettings(pNamespace As %String, pProduction As %String, pItem As %String, Output pExists As %Boolean, Output pCount As %Integer, ByRef pFound, Output pFacts, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Kill pFacts
    Set pFound = 0
    Set pExists = 0
    Set pCount = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pExists = ''##class(Ens.Config.Production).%ExistsId(pProduction)
        If pExists {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
            If $IsObject(tProduction) {
                Set tWanted = $ZConvert(pItem, "U")
                Set tChosen = ""
                For tI = 1:1:tProduction.Items.Count() {
                    Set tCandidate = tProduction.Items.GetAt(tI)
                    If '$IsObject(tCandidate) Continue
                    If $ZConvert(tCandidate.Name, "U") '= tWanted Continue
                    Set pCount = pCount + 1
                    If pCount = 1 Set tChosen = tCandidate
                }
                If pCount = 1 {
                    Set pFacts("name") = tChosen.Name
                    Set pFacts("class") = tChosen.ClassName
                    Set pFacts("adapter") = tChosen.AdapterClassName()
                    Kill tStatic
                    Set tStaticSC = tChosen.GetStaticSettings(.tStatic)
                    If $$$ISERR(tStaticSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tStaticSC)
                    Set tKey = ""
                    For {
                        Set tKey = $Order(tStatic(tKey))
                        If tKey = "" Quit
                        Set tRow = tStatic(tKey)
                        If (+$List(tRow, 4) = 0) || ($List(tRow, 2) = "Enabled") Continue
                        Set pFound($Increment(pFound)) = ..SettingLine(tRow, "Core")
                    }
                    Set tVirtualSC = tChosen.PopulateVirtualSettings()
                    If $$$ISERR(tVirtualSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tVirtualSC)
                    For tGroup = "Host", "Adapter" {
                        For tI = 1:1:tChosen.VirtualSettings.Count() {
                            Set tRow = tChosen.VirtualSettings.GetAt(tI)
                            If $List(tRow, 1) '= tGroup Continue
                            Set pFound($Increment(pFound)) = ..SettingLine(tRow, tGroup)
                        }
                    }
                }
            }
            Set tChosen = ""
            Set tCandidate = ""
            Set tProduction = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The line <method>GatherSettings</method> keeps of one setting row <var>pRow</var> of group
/// <var>pTarget</var>, the vendor's 18-element row (Story 20.22). Called while the namespace is switched.</p>
ClassMethod SettingLine(pRow As %List, pTarget As %String) As %List [ Private ]
{
    Set tKind = ..LocationKind($List(pRow, 18))
    Set tValue = $List(pRow, 3)
    Set tDefault = $List(pRow, 5)
    Quit $ListBuild(pTarget, $List(pRow, 2), tValue, +$List(pRow, 4), tDefault, +$List(pRow, 6), $List(pRow, 8), $List(pRow, 16), $List(pRow, 18), ..NormalizeLocation(tKind, tValue), ..NormalizeLocation(tKind, tDefault))
}

/// <p>Everything one setting call needs, read in the current namespace, which must be <var>pNamespace</var>
/// (Story 20.22), in <var>pFacts</var>. It is <method>GatherSettings</method> and the facts about the one setting
/// <var>pTarget</var>/<var>pName</var> that <var>pType</var> (<code>SET</code>, <code>RESET</code> or
/// <code>""</code>) is about:</p>
/// <ul>
/// <li><code>exists</code>, <code>count</code>, <code>itemName</code>, <code>class</code>, <code>adapter</code>,
/// <code>rows</code> and <code>row(n)</code>: the production, how many items bear the name, the item and its
/// settings. <code>line</code> is the one setting's line, <code>""</code> when the item declares none.</li>
/// <li><code>kind</code>: <method>LocationKind</method> of the setting. <code>newValue</code> and
/// <code>normalized</code>: the value the change leaves in force and its normalized form, which a set takes from
/// <var>pValue</var> and a reset from the default.</li>
/// <li><code>hasDescent</code>, <code>pathNorm</code> and <code>levels</code>: whether the item holds both
/// <parameter>DESCENTSETTING</parameter> and <parameter>DESCENTPATH</parameter> as adapter settings, the effective
/// file path normalized and the effective levels.</li>
/// <li><code>valid</code>: for a set, whether the declaring class's <code>&lt;Name&gt;IsValid</code> accepts
/// <var>pValue</var> (<method>ValueAccepted</method>).</li>
/// </ul>
/// <p>A fault is thrown. Only vendor classes and this class run.</p>
ClassMethod SettingFacts(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pType As %String, pValue As %String, Output pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("count") = 0
    Set pFacts("itemName") = ""
    Set pFacts("class") = ""
    Set pFacts("adapter") = ""
    Set pFacts("rows") = 0
    Set pFacts("line") = ""
    Set pFacts("target") = pTarget
    Set pFacts("name") = pName
    Set pFacts("kind") = ""
    Set pFacts("newValue") = ""
    Set pFacts("normalized") = ""
    Set pFacts("hasDescent") = 0
    Set pFacts("pathNorm") = ""
    Set pFacts("levels") = 0
    Set pFacts("valid") = 1
    Set tGatherSC = ..GatherSettings(pNamespace, pProduction, pItem, .tExists, .tCount, .tFound, .tItemFacts, .tCaught)
    If $IsObject(tCaught) Throw tCaught
    Set pFacts("exists") = tExists
    Set pFacts("count") = tCount
    If tCount '= 1 Quit
    Set pFacts("itemName") = tItemFacts("name")
    Set pFacts("class") = tItemFacts("class")
    Set pFacts("adapter") = tItemFacts("adapter")
    Set pFacts("rows") = tFound
    Set tHasLevels = 0
    Set tHasPath = 0
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set pFacts("row", tI) = tLine
        If $List(tLine, 1) = ..#TARGETADAPTER {
            If $List(tLine, 2) = ..#DESCENTSETTING {
                Set tHasLevels = 1
                Set pFacts("levels") = +$List(tLine, 3)
            } ElseIf $List(tLine, 2) = ..#DESCENTPATH {
                Set tHasPath = 1
                Set pFacts("pathNorm") = $List(tLine, 10)
            }
        }
        If ($List(tLine, 1) = pTarget) && ($List(tLine, 2) = pName) Set pFacts("line") = tLine
    }
    Set pFacts("hasDescent") = (tHasLevels && tHasPath)
    If pFacts("line") = "" Quit
    Set tKind = ..LocationKind($List(pFacts("line"), 9))
    Set pFacts("kind") = tKind
    If pType = ..#TYPESET {
        Set pFacts("newValue") = pValue
        Set pFacts("normalized") = ..NormalizeLocation(tKind, pValue)
        Set pFacts("valid") = ..ValueAccepted(.pFacts, pTarget, pName, pValue)
    } ElseIf pType = ..#TYPERESET {
        Set pFacts("newValue") = $List(pFacts("line"), 5)
        Set pFacts("normalized") = $List(pFacts("line"), 11)
    }
}

/// <p>Whether the class that declares the setting accepts <var>pValue</var> (Story 20.22): an item's own property by
/// <code>Ens.Config.Item</code>'s <code>&lt;Name&gt;IsValid</code>, a Host setting by the item's class, an Adapter
/// setting by its adapter class, as the classic configuration page asks them. An empty value is not judged for a
/// Host or Adapter setting, as there; a class that has no such method accepts anything. Called while the namespace
/// is switched.</p>
ClassMethod ValueAccepted(ByRef pFacts, pTarget As %String, pName As %String, pValue As %String) As %Boolean [ Private ]
{
    Set tClass = $Case(pTarget, "Core": "Ens.Config.Item", "Host": pFacts("class"), "Adapter": pFacts("adapter"), : "")
    If tClass = "" Quit 1
    If (pTarget '= "Core") && (pValue = "") Quit 1
    If '##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||" _ pName _ "IsValid") Quit 1
    Quit ''$$$ISOK($ClassMethod(tClass, pName _ "IsValid", pValue))
}

/// <p>The setting row <var>pLine</var> (<method>GatherSettings</method>'s element) of item <var>pItemName</var> of
/// <var>pProduction</var> as the list and the setting read answer it: <code>{Production, Item, Target, Name, Value,
/// Source, Default, DefaultSource, Type, Category, Location, Secret}</code>; with <var>pNamespace</var> and
/// <var>pCount</var> it also carries <code>Namespace</code> and <code>Count</code>. A setting whose name the
/// credential pattern matches (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) answers an empty
/// <code>Value</code> and <code>Default</code> and <code>Secret</code> true: the value is dropped here, in the
/// install namespace, and reaches nothing that renders the row (AD-35, Story 20.22).</p>
ClassMethod SettingRow(pProduction As %String, pItemName As %String, pLine As %List, pNamespace As %String = "", pCount As %Integer = "") As %DynamicObject [ Private ]
{
    Set tName = $List(pLine, 2)
    Set tSecret = ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName)
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Item", pItemName, "string")
    Do tRow.%Set("Target", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Name", tName _ "", "string")
    Do tRow.%Set("Value", $Select(tSecret: "", 1: $List(pLine, 3) _ ""), "string")
    Do tRow.%Set("Source", ..SourceWord($List(pLine, 4)), "string")
    Do tRow.%Set("Default", $Select(tSecret: "", 1: $List(pLine, 5) _ ""), "string")
    Do tRow.%Set("DefaultSource", ..SourceWord($List(pLine, 6)), "string")
    Do tRow.%Set("Type", $List(pLine, 7) _ "", "string")
    Do tRow.%Set("Category", $List(pLine, 8) _ "", "string")
    Do tRow.%Set("Location", ''(..LocationKind($List(pLine, 9)) '= ""), "boolean")
    Do tRow.%Set("Secret", ''tSecret, "boolean")
    If pNamespace '= "" {
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do tRow.%Set("Count", +pCount, "number")
    }
    Quit tRow
}

/// <p>The facts of <var>pType</var> on one setting, read in <var>pNamespace</var> (<method>SettingFacts</method>),
/// with the namespace restored whatever happens. A fault is <var>pCaught</var>.</p>
ClassMethod SettingsOf(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pType As %String, pValue As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, pType, pValue, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The settings of the item <var>pItem</var> of <var>pProduction</var>, one row per setting in
/// <method>GatherSettings</method>'s order, at most <var>pMax</var> when it is above zero (Story 20.22). An unknown
/// production or item is 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more than once is
/// <code>INTEROP.ITEM.AMBIGUOUS</code>.</p>
ClassMethod ListSettings(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Do ..SettingsOf(pNamespace, pProduction, pItem, "", "", "", "", .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item settings list failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") || (tFacts("count") = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tFacts("count") > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFacts("rows") {
        If (pMax > 0) && (tI > pMax) Quit
        Do pRows.%Push(..SettingRow(pProduction, tFacts("itemName"), tFacts("row", tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One setting, fresh (Story 20.22): the setting row with <code>Namespace</code> and <code>Count</code>. A
/// namespace under source control is <code>INTEROP.ITEM.SOURCECONTROL</code> first; an unknown production, item or
/// setting, and <code>Enabled</code>, are 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more
/// than once is <code>AMBIGUOUS</code>. With <var>pAction</var> it refuses what that action would be refused
/// (<method>SettingRefusalToken</method>), and for a reset the server path the default would leave in force
/// (<method>ChangeProblem</method>), 409 with that code.</p>
ClassMethod ReadSetting(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Do ..SettingsOf(pNamespace, pProduction, pItem, pTarget, pName, $Select(pAction = ..#TYPERESET: pAction, 1: ""), "", .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the setting read failed", .pHttpStatus, .pFault)
    Set tCount = tFacts("count")
    If 'tFacts("exists") || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set tLine = tFacts("line")
    If tLine = "" Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tToken = ..SettingRefusalToken(pAction, pTarget, $List(tLine, 4), tCount)
        If tToken '= "" Quit ..Conflict(..SettingCode(tToken), .pHttpStatus, .pFault)
        If pAction = ..#TYPERESET {
            Set tLocation = ..ChangeProblem(.tFacts)
            If tLocation '= "" Quit ..ConflictFor(tLocation, .pHttpStatus, .pFault)
        }
    }
    Set pRow = ..SettingRow(pProduction, tFacts("itemName"), tLine, pNamespace, tCount)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Every rule over a set's value, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code> (Story 20.22), for the setting <var>pTarget</var>/<var>pName</var> of the
/// item <var>pItem</var> of <var>pProduction</var>: <code>Value</code> must be a JSON string
/// (<code>PORT.FIELD.SHAPE</code>); a Host or Adapter value has no space or control character at either end, which the
/// vendor would store trimmed; the declaring class's <code>&lt;Name&gt;IsValid</code> accepts it
/// (<code>INTEROP.SETTING.VALUE</code>, <method>ValueAccepted</method>); and a server path breaks no self-protection
/// (<method>ChangeProblem</method>: <code>PATH.MANAGERDIR</code>, <code>PATH.SERVED</code>, <code>PATH.MANAGER</code> or
/// <code>INTEROP.SETTING.DESCENT</code>). A setting the item does not declare earns none, and the call answers its 404.
/// The vendor classes run in <var>pNamespace</var>, switched by explicit save and restore, and only once this port's gate
/// admits a set there (<method>Admit</method>).</p>
ClassMethod SettingViolations(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tAdmitted = $$$ISOK(..Admit(..#ENDPOINTSETTINGS, ..#TYPESET, pNamespace, .tHttp, .tFault))
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        If pBody.%GetTypeOf("Value") '= "string" {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Quit
        }
        If 'tAdmitted Quit
        Set tValue = pBody.%Get("Value")
        If (pTarget '= ..#TARGETCORE) && ($ZStrip(tValue, "<>WC") '= tValue) {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#SETTINGVALUE)
            Quit
        }
        Do ..SettingsOf(pNamespace, pProduction, pItem, pTarget, pName, ..#TYPESET, tValue, .tFacts, .tCaught)
        If $IsObject(tCaught) {
            Set tSC = tCaught.AsStatus()
            Quit
        }
        If (tFacts("count") '= 1) || (tFacts("line") = "") Quit
        If 'tFacts("valid") {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#SETTINGVALUE)
            Quit
        }
        Set tCode = ..ChangeProblem(.tFacts)
        If tCode '= "" Set pViolations($Increment(pViolations)) = $ListBuild("Value", tCode)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The in-lock part of a setting write (Story 20.22), called by <method>PerformItem</method> while the namespace
/// is switched to <var>pNamespace</var> and <var>pLocked</var>, the production, is open at concurrency 4 with the lock
/// held. It reads the setting's facts under that lock and answers in <var>pStep</var>:</p>
/// <ul>
/// <li><code>absent</code>: the production holds no such item, or the item declares no such setting.</li>
/// <li><code>refusal</code>: <method>SettingRefusalToken</method>'s decision, else <code>SAME</code> for a set of the value
/// the production already holds.</li>
/// <li><code>location</code>: the code <method>ChangeProblem</method> refuses a server path with, judged from the rows
/// just read. The namespace is left for that judgement, which calls classes it cannot see, and entered again; the
/// production stays open, so its lock is held throughout, and nothing is stored when a code is answered.</li>
/// <li>Otherwise the write: an item's own property is set; a Host or Adapter setting is updated or inserted, or, for
/// a reset, removed; the item is saved; <code>%Ensemble/%Production/ModifyConfiguration</code> is recorded through
/// <code>Ens.Util.Auditing</code>, naming the setting and never a value; and the production class is saved
/// (<code>SaveToClass</code>). <code>vendor</code>, <code>audit</code> and <code>save</code> are the three statuses;
/// <code>after</code> and <code>afterCount</code> are the setting's line and its item count once saved.</li>
/// </ul>
ClassMethod SettingStep(pNamespace As %String, pType As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pBody As %DynamicObject, pOrigNS As %String, pLocked As Ens.Config.Production, Output pStep) [ Private ]
{
    Kill pStep
    Set pStep("absent") = 0
    Set pStep("refusal") = ""
    Set pStep("location") = ""
    Set pStep("vendor") = $$$OK
    Set pStep("audit") = $$$OK
    Set pStep("save") = $$$OK
    Set pStep("after") = ""
    Set pStep("afterCount") = 0
    Set pStep("itemName") = pItem
    Set tValue = $Select(pType = ..#TYPESET: pBody.%Get("Value"), 1: "")
    Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, pType, tValue, .tFacts)
    Set tCount = tFacts("count")
    Set tLine = tFacts("line")
    If (tCount = 0) || ((tCount = 1) && (tLine = "")) {
        Set pStep("absent") = 1
        Quit
    }
    Set pStep("itemName") = tFacts("itemName")
    Set tSource = $Select(tLine = "": 0, 1: +$List(tLine, 4))
    Set pStep("refusal") = ..SettingRefusalToken(pType, pTarget, tSource, tCount)
    If (pStep("refusal") = "") && (pType = ..#TYPESET) && ..SameValue(pTarget, tSource, $List(tLine, 3), tValue) Set pStep("refusal") = "SAME"
    If pStep("refusal") '= "" Quit
    Set $NAMESPACE = pOrigNS
    Set pStep("location") = ..ChangeProblem(.tFacts)
    Set $NAMESPACE = pNamespace
    If pStep("location") '= "" Quit
    Set tItemObject = ..ItemObject(pLocked, tFacts("itemName"))
    If pTarget = ..#TARGETCORE {
        Set $Property(tItemObject, pName) = tValue
    } ElseIf pType = ..#TYPESET {
        Set tHeld = tItemObject.FindSettingByName(pName, pTarget)
        If '$IsObject(tHeld) {
            Set tHeld = ##class(Ens.Config.Setting).%New()
            Set tHeld.Target = pTarget
            Set tHeld.Name = pName
            Do tItemObject.Settings.Insert(tHeld)
        }
        Set tHeld.Value = tValue
    } Else {
        For tI = 1:1:tItemObject.Settings.Count() {
            Set tHeld = tItemObject.Settings.GetAt(tI)
            If (tHeld.Name = pName) && (tHeld.Target = pTarget) {
                Do tItemObject.Settings.RemoveAt(tI)
                Quit
            }
        }
    }
    Set pStep("vendor") = tItemObject.%Save()
    If $$$ISOK(pStep("vendor")) {
        Set tActions = "setting " _ $Select(pType = ..#TYPESET: "set", 1: "reset") _ " by OcuPilot"
        Set tActions(pTarget _ ":" _ pName) = ""
        Set pStep("audit") = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, tFacts("itemName"), .tActions)
        Set pStep("save") = pLocked.SaveToClass(tItemObject)
        Set tHeld = ""
        Set tItemObject = ""
        Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, "", "", .tAfter)
        Set pStep("after") = tAfter("line")
        Set pStep("afterCount") = tAfter("count")
    }
    Set tHeld = ""
    Set tItemObject = ""
}

/// <p>Whether status <var>pStatus</var> carries vendor status code <var>pCode</var>, as one whole entry of
/// its comma-separated code list.</p>
ClassMethod HasCode(pStatus As %Status, pCode As %String) As %Boolean [ Private ]
{
    Set tCodes = ""
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
    } Catch {
        Set tCodes = ""
    }
    Quit ($ListFind($ListFromString(tCodes, ","), pCode) > 0)
}

/// <p>A vendor status <var>pStatus</var> in this port's own words: a production that did not quiesce in
/// time, <code>&lt;Ens&gt;ErrProductionNotQuiescent</code> and <code>&lt;Ens&gt;ErrJobNotStopped</code>, is
/// <parameter>OcuPilot.Api.InteropError.BUSY</parameter>; jobs that outlasted the wait after the production
/// quiesced, <code>&lt;Ens&gt;ErrJobsNotStopped</code>, are
/// <parameter>OcuPilot.Api.InteropError.PARTSTOPPED</parameter>, unlogged; <code>ErrProductionAlreadyRunning</code>,
/// <code>ErrProductionNotShutdownCleanly</code> and <code>ErrProductionSuspendedMismatch</code> are
/// <code>RUNNING</code>, <code>TROUBLED</code> and <code>OTHER</code>, each unlogged; a lock the vendor
/// could not take is 503 <code>PORT.UNAVAILABLE</code>; <code>&lt;PROTECT&gt;</code> and #940 are 403
/// <code>PORT.ACCESSDENIED</code>; anything else is 500 <code>INTERNAL</code>. The last two log the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Statused(pStatus As %Status, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pStatus, ..#CODENOTQUIESCENT) || ..HasCode(pStatus, ..#CODEJOBNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#BUSY, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODEJOBSNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PARTSTOPPED, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODEALREADYRUNNING) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#RUNNING, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODENOTSHUTDOWNCLEANLY) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TROUBLED, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODESUSPENDEDMISMATCH) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#OTHER, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODERUNTIMELOCK) Quit ..Unavailable(.pHttpStatus, .pFault)
    Set tText = ""
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    If (tText [ "<PROTECT>") || ..HasCode(pStatus, ..#CODEPRIVILEGE) {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pStatus, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pStatus, .pHttpStatus, .pFault)
}

/// <p>A vendor exception <var>pException</var> in this port's own words: a lock the vendor could not take is 503
/// <code>PORT.UNAVAILABLE</code>, unlogged, as <method>Statused</method> answers it; <code>&lt;PROTECT&gt;</code>
/// is 403 <code>PORT.ACCESSDENIED</code>, anything else 500 <code>INTERNAL</code>, each logging the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pException.AsStatus(), ..#CODERUNTIMELOCK) Quit ..Unavailable(.pHttpStatus, .pFault)
    Set tProtect = 0
    Try {
        Set tProtect = (pException.Name [ "<PROTECT>")
    } Catch {
        Set tProtect = 0
    }
    If tProtect {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pException.AsStatus(), ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pException.AsStatus(), .pHttpStatus, .pFault)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The 409 refusal <var>pCode</var>, with its published sentence.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.InteropError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The 409 refusal <var>pCode</var>, with the sentence <method>OcuPilot.Api.Error.ReasonForViolation</method> gives
/// it: a code of this port's own or one of <class>OcuPilot.Port.PathPort</class>'s.</p>
ClassMethod ConflictFor(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), .pHttpStatus, .pFault)
}

/// <p>404 <code>PORT.NOTFOUND</code>: the production is not there. Unlogged (AD-2).</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>503 <code>PORT.UNAVAILABLE</code>: the runtime lock could not be taken, so the state is
/// unknown. Unlogged: the caller may try again.</p>
ClassMethod Unavailable(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, ..#REASONLOCK, .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>Serve one of the nine runtime reads (Story 20.4) after <method>Invoke</method>'s gate. Each answers an array of
/// rows, at most <parameter>MAXROWSKEY</parameter> of them when that is above zero, and writes nothing: no queue or
/// job action is called, and <code>Ens.Job:Enumerate</code>, whose <code>MarkDeadJobs</code> writes, never is.</p>
/// <ul>
/// <li>Monitor, Queues and Jobs take no criterion; QueueItems takes <parameter>QUEUEKEY</parameter>; every other
/// endpoint takes the item under <parameter>ITEMKEY</parameter> (the composite id or <code>Production||Name</code>),
/// resolved as an item read resolves it: 400 when it is not one, 404 for an unknown production or item, 409
/// <code>INTEROP.ITEM.AMBIGUOUS</code> for a name the production holds more than once.</li>
/// </ul>
ClassMethod InvokeRuntime(pNamespace As %String, pEndpoint As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = +tMaxText
        If pEndpoint = ..#ENDPOINTMONITOR {
            Set tSC = ..ListMonitor(pNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTQUEUES {
            Set tSC = ..ListQueues(pNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTJOBS {
            Set tSC = ..ListJobs(pNamespace, "", "", tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTQUEUEITEMS {
            Set tQueue = $Get(pQuery(..#QUEUEKEY))
            If tQueue = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONQUEUEREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListQueueEntries(pNamespace, tQueue, "", "", "", tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ResolveItem(pNamespace, tProduction, tItem, .tLine, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tName = $List(tLine, 1)
        If pEndpoint = ..#ENDPOINTITEMSTATUS {
            Set tSC = ..ReadItemStatus(pNamespace, tProduction, tLine, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMQUEUE {
            Set tSC = ..ItemQueueEntries(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMLOG {
            Set tSC = ..ListItemLog(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMMESSAGES {
            Set tSC = ..ListItemMessages(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ListJobs(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The item <var>pItem</var> of <var>pProduction</var> in <var>pNamespace</var>, as <method>GatherItems</method>
/// reads it, in <var>pLine</var> (its element), whose name is the item's own spelling. An unknown production or item is
/// 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more than once is
/// <code>INTEROP.ITEM.AMBIGUOUS</code>, the count rule an item read applies.</p>
ClassMethod ResolveItem(pNamespace As %String, pProduction As %String, pItem As %String, Output pLine As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pLine = ""
    Set tSC = ..GatherItems(pNamespace, pProduction, pItem, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item could not be read", .pHttpStatus, .pFault)
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set pLine = tFound(1)
    Quit $$$OK
}

/// <p>The namespace's current production when it is running or troubled (<parameter>LIVEWORDS</parameter>) and, when
/// <var>pProduction</var> is given, is that production; <code>""</code> otherwise, so a stopped production answers
/// nothing a stale host record could fill. Called while the production's namespace is switched; a fault is
/// thrown.</p>
ClassMethod LiveCurrent(pProduction As %String) As %String [ Private ]
{
    Set tSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    Set tCurrent = $Get(tCurrent)
    If tCurrent = "" Quit ""
    If (pProduction '= "") && (pProduction '= tCurrent) Quit ""
    Set tWord = ##class(Ens.Config.Production).ProductionStateToText(+$Get(tState), 0)
    Quit $Select($ListFind($ListFromString(..#LIVEWORDS), tWord): tCurrent, 1: "")
}

/// <p>The host monitor's rows (<code>Ens.Util.Statistics:EnumerateHostStatus</code>) for the hosts the namespace's
/// current production configures, and only while that production is running or troubled
/// (<method>LiveCurrent</method>); <var>pCurrent</var> is that production, <code>""</code> when there are no rows to
/// give. <var>pProduction</var> limits it to that production, and <var>pName</var> to the host of that name. The
/// vendor's own hosts the production does not configure (<code>Ens.Actor</code>, <code>Ens.ScheduleHandler</code>) are
/// left out. <var>pFound(n)</var> is <code>$ListBuild(Name, Type, Status, AdapterState, LastActivity, ElapsedTime,
/// Queue, Count)</code>, at most <var>pMax</var> of them when that is above zero. A fault is <var>pCaught</var>, with
/// the namespace restored. Only vendor classes and this class run while it is switched.</p>
ClassMethod GatherHosts(pNamespace As %String, pProduction As %String, pName As %String, pMax As %Integer, Output pCurrent As %String, ByRef pFound, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCurrent = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCurrent = ..LiveCurrent(pProduction)
        If tCurrent '= "" {
            Set pCurrent = tCurrent
            Kill tNames
            Set tProduction = ##class(Ens.Config.Production).%OpenId(tCurrent)
            If $IsObject(tProduction) {
                For tI = 1:1:tProduction.Items.Count() {
                    Set tItem = tProduction.Items.GetAt(tI)
                    If $IsObject(tItem) Set tNames(tItem.Name) = ""
                }
            }
            Set tItem = ""
            Set tProduction = ""
            Set tResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
            Set tExecuteSC = tResult.Execute()
            If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
            While tResult.Next() {
                Set tHost = tResult.GetData(1)
                If '$Data(tNames(tHost)) Continue
                If (pName '= "") && (tHost '= pName) Continue
                If (pMax > 0) && (pFound >= pMax) Quit
                Set pFound($Increment(pFound)) = $ListBuild(tHost, tResult.GetData(2), tResult.GetData(3), tResult.GetData(4), tResult.GetData(5), tResult.GetData(6), tResult.GetData(7), tResult.GetData(8))
            }
            Do tResult.Close()
            Set tResult = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The host monitor's row <var>pLine</var> (<method>GatherHosts</method>'s element) of production
/// <var>pProduction</var> as the monitor answers it: <code>{Production, Item, Name, Type, Status, AdapterState,
/// LastActivity, ElapsedTime, Queue, Count}</code>, <code>Item</code> the item's <code>Production||Name</code> and
/// <code>LastActivity</code> the instance's local clock time as the log readers write it. Runs in the install
/// namespace.</p>
ClassMethod HostRow(pProduction As %String, pLine As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Item", pProduction _ "||" _ $List(pLine, 1), "string")
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Type", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("Status", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("AdapterState", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("LastActivity", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(pLine, 5)), "string")
    Do tRow.%Set("ElapsedTime", +$List(pLine, 6), "number")
    Do tRow.%Set("Queue", +$List(pLine, 7), "number")
    Do tRow.%Set("Count", +$List(pLine, 8), "number")
    Quit tRow
}

/// <p>The production monitor (Story 20.4): one row per host the namespace's running or troubled production configures
/// (<method>GatherHosts</method>, <method>HostRow</method>), none while it is not running.</p>
ClassMethod ListMonitor(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherHosts(pNamespace, "", "", pMax, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production monitor failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..HostRow(tCurrent, tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One item's status (Story 20.4): <code>{Production, Name, ClassName, Type, Enabled, Status, AdapterState,
/// LastActivity}</code> as one row. The first five are the item's configuration (<var>pLine</var>,
/// <method>GatherItems</method>'s element, as <method>ItemRow</method> gives them); the last three are its host
/// monitor row's, and empty while the item's production is not the namespace's running or troubled one or the monitor
/// holds no host of the name.</p>
ClassMethod ReadItemStatus(pNamespace As %String, pProduction As %String, pLine As %List, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherHosts(pNamespace, pProduction, $List(pLine, 1), 1, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item status failed", .pHttpStatus, .pFault)
    Set tRow = ..ItemRow(pProduction, pLine)
    For tKey = "EnabledSource", "PoolSize", "Category", "Comment" {
        Do tRow.%Remove(tKey)
    }
    Set tHost = $Select(tFound > 0: ..HostRow(pProduction, tFound(1)), 1: {})
    For tKey = "Status", "AdapterState", "LastActivity" {
        Do tRow.%Set(tKey, $Select(tHost.%IsDefined(tKey): tHost.%Get(tKey), 1: ""), "string")
    }
    Set pRows = [(tRow)]
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The job rows of the host <var>pHost</var>, or of every host <code>Ens.Util.Statistics:EnumerateHostStatus</code>
/// answers when it is empty (the vendor's own hosts the production does not configure included, unlike
/// <method>GatherHosts</method>), only while the namespace's production is running or troubled and, when
/// <var>pProduction</var> is given, is that production: <var>pFound(n)</var> is <code>Ens.Util.Statistics:EnumerateJobStatus</code>'s row
/// <code>$ListBuild(Name, Job, Status, AdapterState, LastActivity, Count, Method, Retry, ActiveMessage)</code>, at most
/// <var>pMax</var> when that is above zero. <var>pCurrent</var> is the production they belong to, <code>""</code> when
/// there are none to give. A fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod GatherJobs(pNamespace As %String, pProduction As %String, pHost As %String, pMax As %Integer, Output pCurrent As %String, ByRef pFound, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCurrent = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCurrent = ..LiveCurrent(pProduction)
        If tCurrent '= "" {
            Set pCurrent = tCurrent
            Kill tHosts
            If pHost '= "" {
                Set tHosts(1) = pHost
                Set tHosts = 1
            } Else {
                Set tHosts = 0
                Set tHostResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
                Set tHostSC = tHostResult.Execute()
                If $$$ISERR(tHostSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tHostSC)
                While tHostResult.Next() {
                    Set tHosts($Increment(tHosts)) = tHostResult.GetData(1)
                }
                Do tHostResult.Close()
                Set tHostResult = ""
            }
            For tH = 1:1:tHosts {
                If (pMax > 0) && (pFound >= pMax) Quit
                Set tResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
                Set tExecuteSC = tResult.Execute(tHosts(tH))
                If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
                While tResult.Next() {
                    If (pMax > 0) && (pFound >= pMax) Quit
                    Set pFound($Increment(pFound)) = $ListBuild(tResult.GetData(1), tResult.GetData(2), tResult.GetData(3), tResult.GetData(4), tResult.GetData(5), tResult.GetData(6), tResult.GetData(7), tResult.GetData(8), tResult.GetData(9))
                }
                Do tResult.Close()
                Set tResult = ""
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The job row <var>pLine</var> (<method>GatherJobs</method>'s element) as the Jobs reads answer it: <code>{Job,
/// Host, Status, AdapterState, LastActivity, Retry, ActiveMessage, Dead}</code>. <code>Dead</code> is true when no
/// process holds the job (<code>^$JOB</code>), the vendor's ghost ids among them: such a row is answered and never
/// repaired. With <var>pProduction</var> the row also carries <code>Production</code> and <code>Item</code>
/// (<code>Production||Host</code>). Pure but for the process table.</p>
ClassMethod JobRow(pLine As %List, pProduction As %String = "") As %DynamicObject
{
    Set tJob = $List(pLine, 2) _ ""
    Set tRow = {}
    If pProduction '= "" {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ $List(pLine, 1), "string")
    }
    Do tRow.%Set("Job", tJob, "string")
    Do tRow.%Set("Host", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Status", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("AdapterState", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("LastActivity", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(pLine, 5)), "string")
    Do tRow.%Set("Retry", +$List(pLine, 8), "number")
    Do tRow.%Set("ActiveMessage", $List(pLine, 9) _ "", "string")
    Set tDead = 1
    If tJob '= "" Set tDead = '$Data(^$JOB(tJob))
    Do tRow.%Set("Dead", ''tDead, "boolean")
    Quit tRow
}

/// <p>The running production's jobs (Story 20.4): every host's, or with <var>pHost</var> one item's of
/// <var>pProduction</var>; none while the production is not running or troubled. A job no process holds is answered
/// <code>Dead</code> (<method>JobRow</method>).</p>
ClassMethod ListJobs(pNamespace As %String, pProduction As %String, pHost As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherJobs(pNamespace, pProduction, pHost, pMax, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the job list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..JobRow(tFound(tI), $Select(pHost '= "": tCurrent, 1: "")))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The namespace's queues and the count of active messages in each (Story 20.4): <code>{Name, Count, Active,
/// Created}</code> from <code>Ens.Queue:Enumerate</code>, <code>Active</code> the jobs of the host of that name that
/// hold a message (<code>Ens.Util.Statistics:EnumerateJobStatus</code>), at most <var>pMax</var> when that is above
/// zero. A queue of a stopped production still lists, as the vendor's query lists it.</p>
ClassMethod ListQueues(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:Enumerate")
        Set tExecuteSC = tResult.Execute()
        If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
        While tResult.Next() {
            If (pMax > 0) && (tFound >= pMax) Quit
            Set tName = tResult.GetData(1)
            Set tActive = 0
            Set tJobs = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
            Set tJobSC = tJobs.Execute(tName)
            If $$$ISERR(tJobSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tJobSC)
            While tJobs.Next() {
                If tJobs.GetData(9) '= "" Set tActive = tActive + 1
            }
            Do tJobs.Close()
            Set tJobs = ""
            Set tFound($Increment(tFound)) = $ListBuild(tName, tResult.GetData(2), tActive, tResult.GetData(3))
        }
        Do tResult.Close()
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the queue list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ "", "string")
        Do tRow.%Set("Count", +$List(tFound(tI), 2), "number")
        Do tRow.%Set("Active", +$List(tFound(tI), 3), "number")
        Do tRow.%Set("Created", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(tFound(tI), 4)), "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The queue an item's messages wait in, and the target that tells them apart from the other messages of that
/// queue (Story 20.4). A business process of pool size 0 shares <parameter>ACTORQUEUE</parameter> with the others of
/// its kind, so its queue is that one and <var>pTarget</var> is the item's name; any other item's is
/// <code>Ens.Config.Item.QueueName()</code> and <var>pTarget</var> is <code>""</code>. Called while the
/// production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemQueueName(pItem As Ens.Config.Item, Output pTarget As %String) As %String
{
    Set pTarget = ""
    If (pItem.BusinessType() = 2) && (+pItem.PoolSize = 0) {
        Set pTarget = pItem.Name
        Quit ..#ACTORQUEUE
    }
    Quit pItem.QueueName()
}

/// <p>The queue of the item <var>pItem</var> of <var>pProduction</var> (<method>ItemQueueName</method>) in
/// <var>pQueue</var> and its target in <var>pTarget</var>; both <code>""</code> when the production or the item is not
/// there. <var>pCurrent</var> is whether <var>pProduction</var> is the production the namespace has current (running,
/// troubled or suspended), the only one whose queues the item reads, as the classic configuration page reads them. A fault
/// is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod QueueOf(pNamespace As %String, pProduction As %String, pItem As %String, Output pQueue As %String, Output pTarget As %String, Output pCurrent As %Boolean, Output pCaught) As %Status [ Private ]
{
    Set pQueue = ""
    Set pTarget = ""
    Set pCurrent = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
        If $IsObject(tProduction) {
            Set tItem = ..ItemObject(tProduction, pItem)
            If $IsObject(tItem) Set pQueue = ..ItemQueueName(tItem, .pTarget)
        }
        Set tItem = ""
        Set tProduction = ""
        Set tStatusSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
        If $$$ISERR(tStatusSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatusSC)
        Set pCurrent = ($Get(tCurrent) = pProduction)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The entries of the queue <var>pQueue</var> (<code>Ens.Queue:EnumerateItem</code>), each joined to its message
/// header (<code>%OpenId</code>): <var>pFound(n)</var> is <code>$ListBuild(Priority, Index, MessageId, Source, Target,
/// BodyClass, TimeCreated, Status)</code>, <code>Status</code> the display word. With <var>pTarget</var> an entry whose
/// header names another target is left out; an entry whose header is gone is kept with empty fields. At most
/// <var>pMax</var> are kept when that is above zero, and at most <parameter>QUEUESCANMAX</parameter> are examined. A
/// fault is <var>pCaught</var>, with the namespace restored. Only vendor classes and this class run while it is
/// switched.</p>
ClassMethod GatherQueueEntries(pNamespace As %String, pQueue As %String, pTarget As %String, pMax As %Integer, ByRef pFound, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:EnumerateItem")
        Set tExecuteSC = tResult.Execute(pQueue)
        If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
        Set tScanned = 0
        While tResult.Next() {
            Set tScanned = tScanned + 1
            If tScanned > ..#QUEUESCANMAX Quit
            Set tMessageId = tResult.GetData(3)
            Set (tSource, tTarget, tBody, tCreated, tStatus) = ""
            Set tHeader = ##class(Ens.MessageHeader).%OpenId(tMessageId)
            If $IsObject(tHeader) {
                Set tSource = tHeader.SourceConfigName
                Set tTarget = tHeader.TargetConfigName
                Set tBody = tHeader.MessageBodyClassName
                Set tCreated = tHeader.TimeCreated
                Set tStatus = ##class(Ens.DataType.MessageStatus).LogicalToDisplay(tHeader.Status)
            }
            Set tHeader = ""
            If (pTarget '= "") && (tTarget '= "") && (tTarget '= pTarget) Continue
            If (pMax > 0) && (pFound >= pMax) Quit
            Set pFound($Increment(pFound)) = $ListBuild(tResult.GetData(1), tResult.GetData(2), tMessageId, tSource, tTarget, tBody, tCreated, tStatus)
        }
        Do tResult.Close()
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>A UTC <code>YYYY-MM-DD HH:MM:SS[.fff]</code> as the instance's local clock time in the form the log readers
/// write it (<method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method>); <code>""</code> for a value that is not
/// one. The vendor's own queries answer the local time, and a header's and a log row's stamps are UTC, so the
/// Queue, Log and Messages tabs convert theirs. Runs in the install namespace.</p>
ClassMethod LocalStamp(pUtc As %String) As %String [ Private ]
{
    Quit ##class(OcuPilot.Port.LogSourcePort).LocalFromUtc(pUtc)
}

/// <p>The queue entry <var>pLine</var> (<method>GatherQueueEntries</method>'s element) of queue <var>pQueue</var> as the
/// queue reads answer it: <code>{Queue, Priority, Index, MessageId, Source, Target, BodyClass, TimeCreated,
/// Status}</code>; with <var>pProduction</var> and <var>pItem</var> it also carries <code>Production</code> and
/// <code>Item</code> (<code>Production||Item</code>). Runs in the install namespace.</p>
ClassMethod QueueEntryRow(pQueue As %String, pLine As %List, pProduction As %String = "", pItem As %String = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    If pProduction '= "" {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
    }
    Do tRow.%Set("Queue", pQueue, "string")
    Do tRow.%Set("Priority", +$List(pLine, 1), "number")
    Do tRow.%Set("Index", +$List(pLine, 2), "number")
    Do tRow.%Set("MessageId", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Source", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("Target", $List(pLine, 5) _ "", "string")
    Do tRow.%Set("BodyClass", $List(pLine, 6) _ "", "string")
    Do tRow.%Set("TimeCreated", ..LocalStamp($List(pLine, 7)), "string")
    Do tRow.%Set("Status", $List(pLine, 8) _ "", "string")
    Quit tRow
}

/// <p>The entries of queue <var>pQueue</var> with their headers (Story 20.4): <method>GatherQueueEntries</method>'s,
/// <method>QueueEntryRow</method>'s. With <var>pProduction</var> and <var>pItem</var> the rows carry that item as their
/// parent.</p>
ClassMethod ListQueueEntries(pNamespace As %String, pQueue As %String, pTarget As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherQueueEntries(pNamespace, pQueue, pTarget, pMax, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the queue entries failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..QueueEntryRow(pQueue, tFound(tI), pProduction, pItem))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>An item's queue (Story 20.4): the entries of the queue <method>ItemQueueName</method> names for the item
/// <var>pItem</var> of <var>pProduction</var>, with their headers; none when <var>pProduction</var> is not the namespace's
/// current production, whose queue of that name is another item's.</p>
ClassMethod ItemQueueEntries(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..QueueOf(pNamespace, pProduction, pItem, .tQueue, .tTarget, .tCurrent, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's queue could not be named", .pHttpStatus, .pFault)
    If tQueue = "" Quit ..Absent(.pHttpStatus, .pFault)
    If 'tCurrent {
        Set pRows = []
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..ListQueueEntries(pNamespace, tQueue, tTarget, pProduction, pItem, pMax, .pRows, .pHttpStatus, .pFault)
}

/// <p>Run the statement <var>pSql</var> in <var>pNamespace</var> with the values <var>pArgs</var> bound, through
/// <code>%SQL.Statement:%ExecDirectNoPriv</code>: the vendor's grants on the interoperability tables are not kept per
/// namespace (a holder of every read resource was answered SQLCODE -99), so the port's gate is the whole gate and runs
/// first (AD-29). <var>pFound(n)</var> is the row as a <code>%List</code> of its columns. A fault is
/// <var>pCaught</var>, with the namespace restored.</p>
ClassMethod SqlRows(pNamespace As %String, pSql As %String, ByRef pFound, Output pCaught, pArgs...) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, pSql, pArgs...)
        If '$IsObject(tResult) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the statement answered no result"))
        If tResult.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message))
        Set tColumns = tResult.%ResultColumnCount
        While tResult.%Next(.tNextSC) {
            Set tLine = ""
            For tC = 1:1:tColumns {
                Set tLine = tLine _ $ListBuild(tResult.%GetData(tC))
            }
            Set pFound($Increment(pFound)) = tLine
        }
        If $$$ISERR($Get(tNextSC, $$$OK)) Throw ##class(%Exception.StatusException).CreateFromStatus(tNextSC)
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The rows of the Log tab's statement: the item's event log rows newest first, as the classic configuration page's
/// own query reads them (<code>EnsPortal.Utils</code>), with the type as its display word. The stamp is read as stored, in
/// UTC: <code>%EXTERNAL</code> would convert it to the reading process's zone, and <method>LocalStamp</method> does that
/// once.</p>
Parameter LOGSQL = "SELECT TOP ? ID, TimeLogged, %EXTERNAL(Type), Text, Job, SessionId FROM Ens_Util.Log WHERE ConfigName = ? ORDER BY ID DESC";

/// <p>The rows of the Messages tab's statement: the newest headers sourced by the item and the newest targeted at it,
/// newest first, as the classic configuration page's Messages tab reads them (<code>EnsPortal.ProductionConfig</code>). The
/// stamp is read as stored, as the Log statement's is.</p>
Parameter MESSAGESQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId FROM Ens.MessageHeader WHERE ID IN (SELECT TOP ? ID FROM Ens.MessageHeader WHERE SourceConfigName = ? ORDER BY ID DESC UNION SELECT TOP ? ID FROM Ens.MessageHeader WHERE TargetConfigName = ? ORDER BY ID DESC) ORDER BY ID DESC";

/// <p>The most rows a statement of the Log or Messages tab asks for when the call gives no cap.</p>
Parameter SQLMAX = 1000;

/// <p>The item's event log (Story 20.4): <code>{Production, Item, ID, TimeLogged, Type, Text, Job, SessionId}</code>,
/// newest first, at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is not above zero). The rows are the
/// ones whose <code>ConfigName</code> is the item's name: the vendor keeps no production on a log row, so an item of a
/// production that is not current reads the rows of any item of that name, as the classic page does. Every value is
/// bound, and <code>TimeLogged</code> is the instance's local clock time (<method>LocalStamp</method>).</p>
ClassMethod ListItemLog(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#LOGSQL, .tFound, .tCaught, tTop, pItem)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's event log failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set tRow = {}
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
        Do tRow.%Set("ID", $List(tLine, 1) _ "", "string")
        Do tRow.%Set("TimeLogged", ..LocalStamp($List(tLine, 2)), "string")
        Do tRow.%Set("Type", $List(tLine, 3) _ "", "string")
        Do tRow.%Set("Text", $List(tLine, 4) _ "", "string")
        Do tRow.%Set("Job", $List(tLine, 5) _ "", "string")
        Do tRow.%Set("SessionId", $List(tLine, 6) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The item's message headers (Story 20.4): <code>{Production, Item, ID, TimeCreated, Status, Source, Target,
/// BodyClass, SessionId}</code>, newest first, the headers sourced by the item's name and those targeted at it (a
/// header names no production, as a log row does not), at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that
/// is not above zero). No body or contents are read. Every value is bound, and <code>TimeCreated</code> is the instance's local clock time (<method>LocalStamp</method>).</p>
ClassMethod ListItemMessages(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#MESSAGESQL, .tFound, .tCaught, tTop, tTop, pItem, tTop, pItem)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's messages failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set tRow = {}
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
        Do tRow.%Set("ID", $List(tLine, 1) _ "", "string")
        Do tRow.%Set("TimeCreated", ..LocalStamp($List(tLine, 2)), "string")
        Do tRow.%Set("Status", $List(tLine, 3) _ "", "string")
        Do tRow.%Set("Source", $List(tLine, 4) _ "", "string")
        Do tRow.%Set("Target", $List(tLine, 5) _ "", "string")
        Do tRow.%Set("BodyClass", $List(tLine, 6) _ "", "string")
        Do tRow.%Set("SessionId", $List(tLine, 7) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p><code>objectscript</code> for each write this port carries; <code>""</code> for
/// <parameter>TYPELIST</parameter>, <parameter>TYPESTATE</parameter>, <parameter>TYPEITEM</parameter> and
/// anything else, which have no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTITEMS) && ..IsItemWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTSETTINGS) && ..IsSettingWrite(pType) Quit "objectscript"
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit ""
    If ..IsWrite(pType) Quit "objectscript"
    Quit ""
}

/// <p><method>Perform</method>'s and <method>PerformItem</method>'s branches as a script (AD-59), in the
/// namespace <parameter>NAMESPACEKEY</parameter> names: <code>Ens.Director</code>'s
/// <code>StartProduction</code> of the one production, <code>StopProduction</code>,
/// <code>RestartProduction</code> and <code>UpdateProduction</code> with the production's own timeout capped
/// at <parameter>STOPSECONDS</parameter>, and <code>RecoverProduction</code>; and an item's
/// <code>EnableConfigItem</code>, add and remove, each followed by the production class's
/// <code>SaveToClass</code>. A read writes nothing and answers no step. Every value is rendered as a
/// string literal, so nothing the query carries runs as code, and every line closes any block it opens.
/// Whoever runs the script is checked by the vendor's own run resource, and a recover by the namespace's
/// database alone; an item write is checked by the databases alone.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pEndpoint = ..#ENDPOINTITEMS {
        Set tText = tText _ ..ItemSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTSETTINGS {
        Set tText = tText _ ..SettingSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pType = ..#TYPESTART {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).StartProduction(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ")"
    } ElseIf pType = ..#TYPERECOVER {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).RecoverProduction()"
    } ElseIf pType = ..#TYPEUPDATE {
        Set tText = tText _ $Char(10) _ " Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()"
        Set tText = tText _ $Char(10) _ " If tTimeout > " _ ..#STOPSECONDS _ " Set tTimeout = " _ ..#STOPSECONDS
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0)"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tTimeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()"
        Set tText = tText _ $Char(10) _ " If tTimeout > " _ ..#STOPSECONDS _ " Set tTimeout = " _ ..#STOPSECONDS
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director)." _ $Select(pType = ..#TYPESTOP: "StopProduction", 1: "RestartProduction") _ "(tTimeout, 0)"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The lines <method>Snippet</method> adds for the item write <var>pType</var> of the item the composite
/// id <var>pId</var> names, carrying the add's body <var>pBody</var>. The last line drops the production, so a
/// terminal that runs the script does not keep its exclusive lock.</p>
ClassMethod ItemSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tProduction = ..Literal($ListGet(tParts, 1))
    Set tName = ..Literal($ListGet(tParts, 2))
    Set tConfigName = ..Literal($ListGet(tParts, 1) _ "||" _ $ListGet(tParts, 2))
    Set tNL = $Char(10)
    Set tText = tNL _ " Set tProduction = ##class(Ens.Config.Production).%OpenId(" _ tProduction _ ", 4)"
    If (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) {
        Set tText = tText _ tNL _ " Set tSC = ##class(Ens.Director).EnableConfigItem(" _ tConfigName _ ", " _ (pType = ..#TYPEENABLE) _ ", 0)"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tProduction.FindItemByConfigName(" _ tName _ "))"
    } ElseIf pType = ..#TYPEADD {
        Set tClass = ""
        If $IsObject(pBody) && (pBody.%GetTypeOf("ClassName") = "string") Set tClass = pBody.%Get("ClassName")
        Set tText = tText _ tNL _ " Set tItem = ##class(Ens.Config.Item).%New(" _ ..Literal(tClass) _ ")"
        Set tText = tText _ tNL _ " Set tItem.Name = " _ tName
        Set tEnabled = 0
        If $IsObject(pBody) && (pBody.%GetTypeOf("Enabled") = "boolean") Set tEnabled = ''pBody.%Get("Enabled")
        Set tText = tText _ tNL _ " Set tItem.Enabled = " _ tEnabled
        If $IsObject(pBody) && (pBody.%GetTypeOf("PoolSize") = "number") Set tText = tText _ tNL _ " Set tItem.PoolSize = " _ ..Literal(pBody.%Get("PoolSize"))
        If $IsObject(pBody) && (pBody.%GetTypeOf("Category") = "string") Set tText = tText _ tNL _ " Set tItem.Category = " _ ..Literal(pBody.%Get("Category"))
        If $IsObject(pBody) && (pBody.%GetTypeOf("Comment") = "string") Set tText = tText _ tNL _ " Set tItem.Comment = " _ ..Literal(pBody.%Get("Comment"))
        Set tText = tText _ tNL _ " Do tProduction.Items.Insert(tItem)"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    } Else {
        Set tText = tText _ tNL _ " Do tProduction.RemoveItem(tProduction.FindItemByConfigName(" _ tName _ "))"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass()"
    }
    ; The production was opened with its exclusive lock, which lasts while a reference to it does.
    Set tText = tText _ tNL _ " Kill tItem, tProduction"
    Quit tText
}

/// <p>The lines <method>Snippet</method> adds for the setting write <var>pType</var> of the setting the composite id
/// <var>pId</var> names, carrying the set's body <var>pBody</var> (Story 20.22): the item opened with the production,
/// the property or the setting stored or removed, the item saved and the production class saved. Names and values are
/// string literals. The last line drops the production, so a terminal that runs the script does not keep its
/// exclusive lock.</p>
ClassMethod SettingSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tProduction = ..Literal($ListGet(tParts, 1))
    Set tItemName = ..Literal($ListGet(tParts, 2))
    Set tTarget = $ListGet(tParts, 3)
    Set tName = ..Literal($ListGet(tParts, 4))
    Set tNL = $Char(10)
    Set tValue = ""
    If $IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string") Set tValue = pBody.%Get("Value")
    Set tText = tNL _ " Set tProduction = ##class(Ens.Config.Production).%OpenId(" _ tProduction _ ", 4)"
    Set tText = tText _ tNL _ " Set tItem = tProduction.FindItemByConfigName(" _ tItemName _ ")"
    If tTarget = ..#TARGETCORE {
        Set tText = tText _ tNL _ " Set $Property(tItem, " _ tName _ ") = " _ ..Literal(tValue)
    } ElseIf pType = ..#TYPESET {
        Set tText = tText _ tNL _ " Set tSetting = tItem.FindSettingByName(" _ tName _ ", " _ ..Literal(tTarget) _ ")"
        Set tText = tText _ tNL _ " If '$IsObject(tSetting) Set tSetting = ##class(Ens.Config.Setting).%New(), tSetting.Target = " _ ..Literal(tTarget) _ ", tSetting.Name = " _ tName _ " Do tItem.Settings.Insert(tSetting)"
        Set tText = tText _ tNL _ " Set tSetting.Value = " _ ..Literal(tValue)
    } Else {
        Set tText = tText _ tNL _ " For tI = 1:1:tItem.Settings.Count() { If (tItem.Settings.GetAt(tI).Name = " _ tName _ ") && (tItem.Settings.GetAt(tI).Target = " _ ..Literal(tTarget) _ ") { Do tItem.Settings.RemoveAt(tI) Quit } }"
    }
    Set tText = tText _ tNL _ " Set tSC = tItem.%Save()"
    Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    ; The production was opened with its exclusive lock, which lasts while a reference to it does.
    Set tText = tText _ tNL _ " Kill tSetting, tItem, tProduction"
    Quit tText
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
