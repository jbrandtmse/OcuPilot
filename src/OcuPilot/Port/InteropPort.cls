/// <p>The port to the instance's interoperability runtime (AD-62, AD-29, AD-52, Story 20.2): <b>the only
/// product class that starts, stops, restarts, updates or recovers a production</b>, and the only one
/// that reads the interoperability configuration for a declared read (source kind
/// <code>interop</code>). It calls the documented classes the classic pages call --
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
/// <li>READ, or for a write WRITE, on the resource guarding the namespace's globals database; an
/// unresolved resource is 400 <code>PORT.VALIDATION</code>.</li>
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
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method> and
/// <method>StopSeconds</method>. Production overrides none.</p>
Class OcuPilot.Port.InteropPort Extends %RegisteredObject
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The four endpoints this port serves, comma-separated: the namespace's productions, business
/// processes, data transformations and business rules.
/// <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules";

Parameter ENDPOINTPRODUCTIONS = "Productions";

Parameter ENDPOINTPROCESSES = "Processes";

Parameter ENDPOINTTRANSFORMS = "Transforms";

Parameter ENDPOINTRULES = "Rules";

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

/// <p>The permission a read requires on the namespace's globals database.</p>
Parameter READPERMISSION = "READ";

/// <p>The permission a write requires on it (recover raises <code>&lt;PROTECT&gt;</code> on
/// <code>^Ens.Suspended</code> without it, measured).</p>
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

/// <p>The pairs <var>pEndpoint</var> requires for <var>pType</var>, as the <code>%List</code> of
/// two-element <code>%List</code>s the gate evaluates: the endpoint's own pairs, then
/// <parameter>WRITEPAIRS</parameter> for a write; <code>""</code> for an endpoint this port does not
/// serve.</p>
ClassMethod Pairs(pEndpoint As %String, pType As %String = "") As %List
{
    If pEndpoint = ..#ENDPOINTPRODUCTIONS {
        Set tSpec = ..#PRODUCTIONPAIRS
    } ElseIf $ListFind(..Endpoints(), pEndpoint) {
        Set tSpec = ..#CODEPAIRS
    } Else {
        Quit ""
    }
    If ..IsWrite(pType) Set tSpec = tSpec _ "," _ ..#WRITEPAIRS
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
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
        Set tWrite = ..IsWrite(pType)
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
/// <parameter>OcuPilot.Api.InteropError.BUSY</parameter>; <code>ErrProductionAlreadyRunning</code>,
/// <code>ErrProductionNotShutdownCleanly</code> and <code>ErrProductionSuspendedMismatch</code> are
/// <code>RUNNING</code>, <code>TROUBLED</code> and <code>OTHER</code>, each unlogged; a lock the vendor
/// could not take is 503 <code>PORT.UNAVAILABLE</code>; <code>&lt;PROTECT&gt;</code> and #940 are 403
/// <code>PORT.ACCESSDENIED</code>; anything else is 500 <code>INTERNAL</code>. The last two log the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Statused(pStatus As %Status, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pStatus, ..#CODENOTQUIESCENT) || ..HasCode(pStatus, ..#CODEJOBNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#BUSY, .pHttpStatus, .pFault)
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
/// <parameter>TYPELIST</parameter>, <parameter>TYPESTATE</parameter> and anything else, which have no
/// script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit ""
    If ..IsWrite(pType) Quit "objectscript"
    Quit ""
}

/// <p><method>Perform</method>'s branches as a script (AD-59), in the namespace
/// <parameter>NAMESPACEKEY</parameter> names: <code>Ens.Director</code>'s <code>StartProduction</code>
/// of the one production, <code>StopProduction</code>, <code>RestartProduction</code> and
/// <code>UpdateProduction</code> with the production's own timeout capped at
/// <parameter>STOPSECONDS</parameter>, and <code>RecoverProduction</code>. A read writes nothing and
/// answers no step. Every value is rendered as a string literal, so nothing the query carries runs as
/// code. Whoever runs the script is checked by the vendor's own run resource, and a recover by the
/// namespace's database alone.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pType = ..#TYPESTART {
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
