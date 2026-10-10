/// <p>The port to the instance's interoperability runtime (AD-62, AD-29, AD-52, Stories 20.2 and 20.3): <b>the
/// only product class that starts, stops, restarts, updates or recovers a production, or enables, disables,
/// adds or removes one of its items</b>, and the only one that reads the interoperability configuration for
/// a declared read (source kind <code>interop</code>). It calls the documented classes the classic pages call --
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
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Items";

Parameter ENDPOINTPRODUCTIONS = "Productions";

Parameter ENDPOINTPROCESSES = "Processes";

Parameter ENDPOINTTRANSFORMS = "Transforms";

Parameter ENDPOINTRULES = "Rules";

/// <p>A production's items: <code>LIST</code> for the production the <parameter>PRODUCTIONKEY</parameter>
/// names, <code>ITEM</code> for one item and the four item writes (Story 20.3).</p>
Parameter ENDPOINTITEMS = "Items";

/// <p>The pairs the Productions endpoint requires: the classic Interoperability menu's
/// <code>%Ens_Portal:USE</code> and <code>EnsPortal.Productions</code>'s own resource (AD-8,
/// AD-29).</p>
Parameter PRODUCTIONPAIRS = "%Ens_Portal:USE,%Ens_ProductionConfig:READ";

/// <p>The pairs the three code lists require. The classic pages' resource is an OR list a pair set
/// cannot express; <code>%Ens_Code:READ</code> is held by every shipped role that reaches them
/// (AD-62's named limit).</p>
Parameter CODEPAIRS = "%Ens_Portal:USE,%Ens_Code:READ";

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

Parameter REASONITEMBODY = "An item write names its fields in an object.";

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

/// <p>The pairs <var>pEndpoint</var> requires for <var>pType</var>, as the <code>%List</code> of
/// two-element <code>%List</code>s the gate evaluates: the endpoint's own pairs, then
/// <parameter>WRITEPAIRS</parameter> for a production write or <parameter>ITEMWRITEPAIRS</parameter> for an
/// item write; <code>""</code> for an endpoint this port does not serve. The Items endpoint takes the
/// Productions endpoint's pairs.</p>
ClassMethod Pairs(pEndpoint As %String, pType As %String = "") As %List
{
    If (pEndpoint = ..#ENDPOINTPRODUCTIONS) || (pEndpoint = ..#ENDPOINTITEMS) {
        Set tSpec = ..#PRODUCTIONPAIRS
    } ElseIf $ListFind(..Endpoints(), pEndpoint) {
        Set tSpec = ..#CODEPAIRS
    } Else {
        Quit ""
    }
    If ..IsWrite(pType) Set tSpec = tSpec _ "," _ ..#WRITEPAIRS
    If ..IsItemWrite(pType) Set tSpec = tSpec _ "," _ ..#ITEMWRITEPAIRS
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
    If pEndpoint = ..#ENDPOINTITEMS Quit (pType = ..#TYPEITEM) || ..IsItemWrite(pType)
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
/// NeedsUpdate}</code>.</p>
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
        Set tWrite = ..IsWrite(pType) || ..IsItemWrite(pType)
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint, pType), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If '$Match(tNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        If '##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("interoperability", tNamespace) {
            Set tSC = ..Conflict(##class(OcuPilot.Api.InteropError).#NAMESPACE, .pHttpStatus, .pFault)
            Quit
        }
        Set tResource = ""
        If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(tNamespace, .tResource, .tReadOnly) || (tResource = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
            Quit
        }
        Set tDatabasePair = $ListBuild($ListBuild(tResource, $Select(tWrite: ..#WRITEPERMISSION, 1: ..#READPERMISSION)))
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tDatabasePair, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        ; An item write also writes the routines database (^oddDEF), after the globals one.
        If ..IsItemWrite(pType) {
            Set tRoutineResource = ""
            If '..RoutineResource(tNamespace, .tRoutineResource) || (tRoutineResource = "") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONROUTINESUNKNOWN, .pHttpStatus, .pFault)
                Quit
            }
            If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tRoutineResource, ..#WRITEPERMISSION)), .tFailedPair) {
                Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
                Quit
            }
        }

        If pEndpoint = ..#ENDPOINTITEMS {
            Set tSC = ..InvokeItems(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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
/// by explicit save and restore.</p>
ClassMethod AddViolations(pNamespace As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
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

/// <p>Whether <var>pNamespace</var> holds the production <var>pProduction</var>. A fault in the look-up
/// answers 1, so the write's own refusal decides rather than this one.</p>
ClassMethod ProductionHeld(pNamespace As %String, pProduction As %String) As %Boolean
{
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
/// <li>Remove: <code>ENABLEDREMOVE</code> while it is enabled.</li>
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
        If pEnabled Quit "ENABLEDREMOVE"
        Quit ""
    }
    Quit ""
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
/// unlogged. With <var>pAction</var> it refuses what that action would be refused
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
/// disable carry the vendor's own event. A record that cannot be written is logged once the namespace is
/// restored and never fails the write.</li>
/// <li>The production class is saved every time (<code>SaveToClass</code>), because the configuration
/// alone is reverted by the next compile of the class. A failure there, after the configuration saved, is
/// a logged 500.</li>
/// </ol>
/// <p>Every reference is dropped before the namespace is restored.</p>
ClassMethod PerformItem(pNamespace As %String, pType As %String, pProduction As %String, pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
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
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(Ens.Config.Production).%ExistsId(pProduction) {
            Set tAbsent = 1
        } Else {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction, 4)
            If '$IsObject(tProduction) {
                Set tBusy = 1
            } Else {
                Set tFactsSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tGatherCaught)
                If $IsObject(tGatherCaught) Throw tGatherCaught
                Set tLine = $Get(tFound(1))
                If (pType '= ..#TYPEADD) && (tCount = 0) {
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
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $$$ISERR(tAuditSC) Do ..LogFault("the item " _ pType _ " was saved but its audit record could not be written", tAuditSC)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If tAbsent Quit ..Absent(.pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tRefusal '= "" Quit ..Conflict(..ItemCode(tRefusal), .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tSaveSC) Quit ..Fail("the production class could not be saved after the item " _ pType, tSaveSC, .pHttpStatus, .pFault)
    If tAfter = "" {
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

/// <p>A vendor exception <var>pException</var> in this port's own words: <code>&lt;PROTECT&gt;</code>
/// is 403 <code>PORT.ACCESSDENIED</code>, anything else 500 <code>INTERNAL</code>, each logging the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
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

/// <p><code>objectscript</code> for each write this port carries; <code>""</code> for
/// <parameter>TYPELIST</parameter>, <parameter>TYPESTATE</parameter>, <parameter>TYPEITEM</parameter> and
/// anything else, which have no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTITEMS) && ..IsItemWrite(pType) Quit "objectscript"
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
/// id <var>pId</var> names, carrying the add's body <var>pBody</var>.</p>
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
