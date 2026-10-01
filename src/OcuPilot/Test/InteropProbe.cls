/// <p>Test-only helper for Story 18.15's enable-interop suites: creates and removes probe namespaces
/// named with <parameter>PREFIX</parameter> over a probe database in a directory under the manager
/// directory named with <parameter>DIRPREFIX</parameter>, through <class>OcuPilot.Port.AdminPort</class>,
/// and takes canonical snapshots of what an enable can change, so a run can be compared with the state
/// before it. It never touches an object whose name is outside those prefixes, except that
/// <method>RemoveAll</method> restores <parameter>EDITORSAPP</parameter>'s matching roles and, through
/// <method>RestoreInstance</method>, the instance-wide objects an enable changes, to the record
/// <method>Add</method> took before the first probe namespace existed.</p>
/// <p><method>RemoveAll</method> deletes each probe namespace through the port, then, by exact probe
/// name, the roles, SQL privilege rows, vendor records, application directories, activation logs and
/// tasks an enable left for it, and last the probe database, its directory and its resource. Its HS
/// and Ensemble calls are test cleanup only.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropProbe Extends %RegisteredObject
{

/// <p>The prefix every probe namespace's and database's name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE1815";

/// <p>The prefix every probe directory's and file's name starts with, compared lower-cased.</p>
Parameter DIRPREFIX = "ocuprobe1815";

/// <p>The prefix every probe resource's name starts with, compared upper-cased.</p>
Parameter RESOURCEPREFIX = "%DB_OCUPROBE1815";

/// <p>The suffix of the probe database every probe namespace is created over by default.</p>
Parameter DATABASE = "D";

/// <p>The label the port's queued namespace tasks carry in their task name.</p>
Parameter TASKLABEL = "/namespace/namespace";

/// <p>How long <method>SettleOwnTasks</method> waits for one task to end, in seconds: three times the
/// reference enable measured at Story 18.15's Task 0, and at least 300.</p>
Parameter SETTLESECONDS = 300;

/// <p>How old, in seconds, <method>RecordInstance</method>'s record may be when
/// <method>RestoreInstance</method> applies it. A record lives from one test's <method>Add</method> to
/// its <method>RemoveAll</method>; an older one was left by a run whose restore failed, and applying it
/// would delete every role, resource and task created since.</p>
Parameter RECORDSECONDS = 3600;

/// <p>The application whose matching roles the vendor's enable adds the interoperability editors' role
/// to once.</p>
Parameter EDITORSAPP = "/api/interop-editors";

/// <p>The global <method>Add</method> records <parameter>EDITORSAPP</parameter>'s matching roles in
/// before the first probe namespace exists, and <method>RemoveAll</method> restores them from.</p>
Parameter RECORD = "^OCUPROBE1815";

/// <p>The vendor's namespace-scoped role names an enable creates, each followed by the namespace.</p>
Parameter ROLESTEMS = "%EnsRole_ProdPrivs_,%HS_DB_";

/// <p>The second subscript prefix of the <code>^%SYS("HealthShare")</code> records the HealthShare
/// Foundation install writes instance-wide.</p>
Parameter SYSTEMCONFIG = "SystemConfig";

/// <p>The snapshot line kinds <method>RecordInstance</method> records and
/// <method>RestoreInstance</method> restores.</p>
Parameter INSTANCEKINDS = "resource,role,application,task,user,languageserver";

/// <p>The broad snapshot lines (<method>Snapshot</method> with <var>pBroad</var> 1) that may differ after
/// <method>RemoveAll</method> with the instance otherwise restored, as a <code>;</code>-separated closed
/// list of line prefixes, each naming one counter, edit stamp or HSSYS index node (measured on
/// <code>ocupilot-b-ci</code>, 2026-10-01): the work-queue manager's repeat counter, which moves on its
/// own; the SQL cursor and statement-id counters; the web-application configuration's
/// <code>LastUpdate</code> stamp; the four <parameter>STAMPEDROWS</parameter>; the activation log's ID
/// counter, whose data global's checksum moves with it; and the activation log's bitmap extent
/// index.</p>
Parameter RESIDUE = "global|^%SYS(""WQM"",""Repeat"")=;global|^%SYS(""sql"",""cursor counter"")=;global|^%SYS(""sql"",""statement id"")=;global|^%SYS(""CSP"",""LastUpdate"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",""curr"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",""prev"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",1,""curr"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",1,""prev"")=;hssys|HS.HC.Util.Installer.LogD|;hssys|HS.HC.Util.Installer.LogI|";

/// <p>The <parameter>RESIDUE</parameter> prefixes whose value is a SQL statistics settings row: its
/// first four <code>$List</code> positions are an edit stamp (date, job, namespace, user) and the rest
/// its settings (<code>irislib/%SYS/PTools/Stats.inc</code>). Such a line is residue only when the other
/// side of the difference holds the same node with the same settings.</p>
Parameter STAMPEDROWS = "global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",""curr"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",""prev"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",1,""curr"")=;global|^%SYS(""sql"",""sys"",""SQLStatsSettings"",1,""prev"")=";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ENDPOINT = "Namespace.Namespace";

/// <p>Whether <var>pName</var> is a probe namespace or database name.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit ($Extract($ZConvert(pName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX)
}

/// <p>The probe namespace or database name for <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ $ZConvert(pSuffix, "U")
}

/// <p>The manager directory, normalized with its trailing separator.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>The probe database directory for <var>pSuffix</var> under the manager directory.</p>
ClassMethod DirectoryFor(pSuffix As %String) As %String
{
    Quit ..Manager() _ ..#DIRPREFIX _ $ZConvert(pSuffix, "L") _ "/"
}

/// <p>Whether the last segment of <var>pPath</var> starts with <parameter>DIRPREFIX</parameter>,
/// ignoring case.</p>
ClassMethod IsProbePath(pPath As %String) As %Boolean
{
    Set tPath = $ZConvert(pPath, "L")
    If $Extract(tPath, *) = "/" Set tPath = $Extract(tPath, 1, *-1)
    Set tLast = $Piece(tPath, "/", $Length(tPath, "/"))
    Quit ($Extract(tLast, 1, $Length(..#DIRPREFIX)) = ..#DIRPREFIX)
}

/// <p>Create the probe namespace for <var>pSuffix</var> over the probe database for
/// <var>pDatabase</var>, for both its globals and its routines, creating the database first when it is
/// absent: its resource in <code>%SYS</code>, then its file and configuration through the port, in its
/// own directory under the manager directory.</p>
ClassMethod Add(pSuffix As %String, pDatabase As %String = {..#DATABASE}) As %Status
{
    Set tNamespace = ..Name(pSuffix)
    Set tDatabase = ..Name(pDatabase)
    Set tSC = ..RecordEditorsApp()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..RecordInstance()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..AddDatabase(pDatabase)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("name") = tNamespace
    Set tBody = {}
    Do tBody.%Set("Globals", tDatabase, "string")
    Do tBody.%Set("Routines", tDatabase, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe namespace " _ tNamespace _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Create the probe database for <var>pSuffix</var> when the instance does not hold it: the resource
/// <code>%DB_&lt;NAME&gt;</code> first, then the file and the configuration through the port.</p>
ClassMethod AddDatabase(pSuffix As %String) As %Status
{
    Set tName = ..Name(pSuffix)
    If ..HoldsDatabase(tName) Quit $$$OK
    Set tResource = "%DB_" _ tName
    Set tDirectory = ..DirectoryFor(pSuffix)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(tResource) Set tSC = ##class(Security.Resources).Create(tResource, "OcuPilot interop probe (throwaway)", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Kill tNone
    Set tBody = {"Size": 1}
    Do tBody.%Set("Directory", tDirectory, "string")
    Do tBody.%Set("ResourceName", tResource, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Database.SysCRUD", "POST", .tNone, tBody, .tFile, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("name") = tName
    Set tBody = {}
    Do tBody.%Set("Directory", tDirectory, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe database " _ tName _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Whether the instance holds the database configuration <var>pName</var>.</p>
ClassMethod HoldsDatabase(pName As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit $$$ISOK(tSC) && $IsObject($Get(tResult))
}

/// <p>Whether the instance holds the namespace <var>pName</var>.</p>
ClassMethod HoldsNamespace(pName As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit $$$ISOK(tSC) && $IsObject($Get(tResult))
}

/// <p>Whether <var>pNamespace</var> is enabled for interoperability, as the vendor answers it. The
/// vendor answers 1 once its mappings exist, early in an enable, so this does not say the enable has
/// ended.</p>
ClassMethod IsEnabled(pNamespace As %String) As %Boolean
{
    Set tEnabled = 0
    Try {
        Set tEnabled = ''##class(%Library.EnsembleMgr).IsEnsembleNamespace($ZConvert(pNamespace, "U"))
    } Catch {
        Set tEnabled = 0
    }
    Quit tEnabled
}

/// <p>Whether an enable of <var>pNamespace</var> ran its HealthShare half: the vendor's
/// <code>%HS_DB_</code> role for the namespace exists, which Story 18.15's Task 0 measured after a full
/// enable and not after one that skipped that half. 1 on an instance without the HealthShare
/// libraries.</p>
ClassMethod HasHealthShareHalf(pNamespace As %String) As %Boolean
{
    Set tHas = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If '##class(%Library.EnsembleMgr).IsHealthShareInstalled() {
            Set tHas = 1
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tHas = ''##class(Security.Roles).Exists("%HS_DB_" _ $ZConvert(pNamespace, "U"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHas = 0
    }
    Quit tHas
}

/// <p>Whether a web application runs in <var>pNamespace</var>.</p>
ClassMethod HasPortal(pNamespace As %String) As %Boolean
{
    Quit ($ListLength(..Applications(pNamespace)) > 0)
}

/// <p>The web applications whose namespace is <var>pNamespace</var>, ignoring case.</p>
ClassMethod Applications(pNamespace As %String) As %List
{
    Set tApps = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                If $ZConvert(tRS.Get("Namespace"), "U") = $ZConvert(pNamespace, "U") Set tApps = tApps _ $ListBuild(tRS.Get("Name"))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tApps
}

/// <p>The probe namespaces the instance holds, as the vendor's list names them.</p>
ClassMethod ProbeNamespaces() As %List
{
    Set tNames = ""
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>Record <parameter>EDITORSAPP</parameter>'s matching roles in <parameter>RECORD</parameter> when
/// no probe namespace exists and nothing is recorded yet.</p>
ClassMethod RecordEditorsApp() As %Status
{
    If $Data(@..#RECORD@("E5")) Quit $$$OK
    If $ListLength(..ProbeNamespaces()) > 0 Quit $$$OK
    Set tRoles = ..EditorsRoles(.tHeld)
    If 'tHeld Quit $$$OK
    Set @..#RECORD@("E5") = tRoles
    Quit $$$OK
}

/// <p><parameter>EDITORSAPP</parameter>'s matching roles, with <var>pHeld</var> 0 when the application
/// is absent.</p>
ClassMethod EditorsRoles(Output pHeld As %Boolean) As %String
{
    Set pHeld = 0
    Set tRoles = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#EDITORSAPP) {
            Set pHeld = 1
            Kill tProperties
            Do ##class(Security.Applications).Get(..#EDITORSAPP, .tProperties)
            Set tRoles = $Get(tProperties("MatchRoles"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRoles
}

/// <p>The caller's own queued namespace tasks (their task name carries <parameter>TASKLABEL</parameter>),
/// each waited for until it ends, its finished result read once, and its row deleted. <var>pResults</var>
/// holds one <code>{GUID, State, FailureReason, Console, seconds}</code> per task, the read's own
/// answer. A task the list already shows ended is never read: its row is only deleted, because it may
/// have been read once already by a caller that could not delete it, and a second read logs ERROR
/// #7846 (AD-26).</p>
ClassMethod SettleOwnTasks(Output pResults As %DynamicArray, pSeconds As %Integer = {..#SETTLESECONDS}) As %Status
{
    Set pResults = []
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "AsyncResult", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) Quit $$$OK
    Set tGuids = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || '($ZConvert(tRow.%Get("TaskName"), "L") [ ..#TASKLABEL) Continue
        If ..Ended(tRow.%Get("State")) {
            Do $ClassMethod(..#PORT, "ForgetTask", tRow.%Get("GUID"))
            Continue
        }
        Set tGuids = tGuids _ $ListBuild(tRow.%Get("GUID"))
    }
    Set tPointer = 0
    While $ListNext(tGuids, tPointer, tGuid) {
        Do pResults.%Push(..Settle(tGuid, pSeconds))
    }
    Quit $$$OK
}

/// <p>Wait up to <var>pSeconds</var> for task <var>pGuid</var> to end, read through the port's own
/// poll, and remove its row once it has; the answer is the terminal read's
/// <code>{GUID, State, FailureReason, Console, TimeStarted, TimeFinished, seconds}</code>, or the last
/// state read.</p>
ClassMethod Settle(pGuid As %String, pSeconds As %Integer = {..#SETTLESECONDS}) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("GUID", pGuid, "string")
    Set tState = ""
    Set tStart = $ZHorolog
    For {
        Set tAnswer = ""
        Set tSC = $ClassMethod(..#PORT, "PollTask", pGuid, .tAnswer, .tHttp)
        If $$$ISOK(tSC) && $IsObject(tAnswer) Set tState = tAnswer.%Get("State")
        If $$$ISERR(tSC) || ..Ended(tState) || (($ZHorolog - tStart) >= pSeconds) Quit
        Hang 0.5
    }
    Do tOut.%Set("State", tState, "string")
    Do tOut.%Set("seconds", $ZHorolog - tStart, "number")
    If ..Ended(tState) {
        Do tOut.%Set("FailureReason", tAnswer.%Get("FailureReason"), "string")
        Do tOut.%Set("Console", tAnswer.%Get("Console"))
        Do tOut.%Set("TimeStarted", tAnswer.%Get("TimeStarted"), "string")
        Do tOut.%Set("TimeFinished", tAnswer.%Get("TimeFinished"), "string")
        Do $ClassMethod(..#PORT, "ForgetTask", pGuid)
    }
    Quit tOut
}

/// <p>Whether <var>pState</var> is a terminal task state.</p>
ClassMethod Ended(pState As %String) As %Boolean
{
    Quit ''$ListFind($ListBuild("Finished", "Failed", "Canceled"), pState)
}

/// <p>How many of the caller's own queued namespace tasks are still held, read through the port's own
/// <code>AsyncResult</code> list; <code>-1</code> when it cannot be read.</p>
ClassMethod OwnTaskCount() As %Integer
{
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "AsyncResult", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit -1
    Set tCount = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($ZConvert(tRow.%Get("TaskName"), "L") [ ..#TASKLABEL) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>A canonical, sorted snapshot of what an enable can change, one line per object: namespaces;
/// databases and their directories; applications with their namespace, matching roles and path; roles
/// with their resources and granted roles; resources; SQL privilege rows for a probe namespace; tasks
/// with their namespace; users with their roles; external language servers and whether each runs;
/// the mappings of each probe namespace, of the install namespace and of <code>%ALL</code>; the
/// <code>^%SYS("Ensemble")</code>, <code>("HealthShare")</code> and <code>("HealthShareLocal")</code>
/// nodes a probe subscripts, and every <code>^%SYS("HealthShare")</code> node whose second subscript
/// begins <parameter>SYSTEMCONFIG</parameter>; HSSYS configuration items and activation log counts;
/// probe directories under the manager directory and the CSP tree; probe-named files in the manager
/// directory; and configuration-file lines naming a probe.</p>
/// <p>With <var>pBroad</var> 1 it also lists every <code>^%SYS</code> node and, for each global in the
/// HSSYS database, its node count and checksum, so an effect outside those classes shows too.</p>
/// <p>Each vendor read runs in <code>%SYS</code> by explicit save and restore, and calls nothing of this
/// class while it is there.</p>
ClassMethod Snapshot(pBroad As %Boolean = 0) As %DynamicArray
{
    Kill tLines
    Set tInstallNs = $ZConvert(##class(OcuPilot.Install.Installer).ResolveNamespace(), "U")
    Do ..SnapSystem(pBroad, .tLines)
    Set tSpaces = $ListBuild(tInstallNs, "%ALL")
    Set tLine = "namespace|"
    For {
        Set tLine = $Order(tLines(tLine))
        If $Piece(tLine, "|", 1) '= "namespace" Quit
        If ..IsProbe($Piece(tLine, "|", 2)) Set tSpaces = tSpaces _ $ListBuild($Piece(tLine, "|", 2))
    }
    Do ..SnapMappings(tSpaces, .tLines)
    Do ..SnapLanguageServers(.tLines)
    Do ..SnapFiles(.tLines)
    Do ..SnapCpf(.tLines)
    If pBroad Do ..SnapHssys(.tLines)
    Do ..SnapHealthShare(.tLines)
    Set tOut = []
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>The lines of <var>pAfter</var> not in <var>pBefore</var>, as <code>added</code>, and of
/// <var>pBefore</var> not in <var>pAfter</var>, as <code>removed</code>.</p>
ClassMethod Diff(pBefore As %DynamicArray, pAfter As %DynamicArray) As %DynamicObject
{
    Kill tBefore, tAfter
    Set tIterator = pBefore.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tBefore(tLine) = ""
    }
    Set tIterator = pAfter.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tAfter(tLine) = ""
    }
    Set tAdded = []
    Set tRemoved = []
    Set tLine = ""
    For {
        Set tLine = $Order(tAfter(tLine))
        If tLine = "" Quit
        If '$Data(tBefore(tLine)) Do tAdded.%Push(tLine)
    }
    Set tLine = ""
    For {
        Set tLine = $Order(tBefore(tLine))
        If tLine = "" Quit
        If '$Data(tAfter(tLine)) Do tRemoved.%Push(tLine)
    }
    Quit {"added": (tAdded), "removed": (tRemoved)}
}

/// <p>The effect classes of Story 18.15's Task 0 that <var>pDiff</var> shows for the probe namespace
/// <var>pNamespace</var>, sorted and comma-joined: <code>E1</code> its mappings, <code>E2</code> its
/// applications and their directories, <code>E3</code> the roles named for it and its SQL privilege
/// rows, <code>E4</code> the vendor's records keyed by it, <code>E5</code> the interoperability editors
/// application's matching roles, <code>E6</code> configuration-file lines; any other changed line is
/// named <code>other:&lt;kind&gt;</code>.</p>
ClassMethod EffectClasses(pDiff As %DynamicObject, pNamespace As %String) As %String
{
    Kill tClasses
    For tSide = "added", "removed" {
        Set tIterator = pDiff.%Get(tSide).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tClasses(..EffectClass(tLine, pNamespace)) = ""
        }
    }
    Set tOut = ""
    Set tClass = ""
    For {
        Set tClass = $Order(tClasses(tClass))
        If tClass = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tClass
    }
    Quit tOut
}

/// <p>The effect class of one snapshot line for <var>pNamespace</var> (see
/// <method>EffectClasses</method>).</p>
ClassMethod EffectClass(pLine As %String, pNamespace As %String) As %String
{
    Set tNamespace = $ZConvert(pNamespace, "U")
    Set tKind = $Piece(pLine, "|", 1)
    If (tKind = "mapping") && ($Piece(pLine, "|", 2) = tNamespace) Quit "E1"
    If (tKind = "application") && ($ZConvert($Piece(pLine, "|", 3), "U") = tNamespace) Quit "E2"
    If (tKind = "application") && ($Piece(pLine, "|", 2) = ..#EDITORSAPP) Quit "E5"
    If (tKind = "directory") && ($Piece(pLine, "|", 2) = "csp") Quit "E2"
    If (tKind = "role") && ..IsRoleFor($Piece(pLine, "|", 2), tNamespace) Quit "E3"
    If (tKind = "sqlprivilege") && ($Piece(pLine, "|", 2) = tNamespace) Quit "E3"
    If (tKind = "global") || (tKind = "configitem") || (tKind = "activationlog") Quit "E4"
    If (tKind = "file") && ($ZConvert(pLine, "U") [ tNamespace) Quit "E4"
    If tKind = "cpf" Quit "E6"
    Quit "other:" _ tKind
}

/// <p>The lines describing OcuPilot's own objects, from <var>pSnapshot</var>: its applications and
/// roles, its administration resource, its database and that database's resource, and the install
/// namespace's and <code>%ALL</code>'s mappings.</p>
ClassMethod OwnObjects(pSnapshot As %DynamicArray) As %DynamicArray
{
    Set tInstallNs = $ZConvert(##class(OcuPilot.Install.Installer).ResolveNamespace(), "U")
    Set tOut = []
    Set tIterator = pSnapshot.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tKind = $Piece(tLine, "|", 1)
        Set tName = $Piece(tLine, "|", 2)
        Set tOwn = 0
        If (tKind = "application") && ($ZConvert(tName, "L") [ "ocupilot") Set tOwn = 1
        If (tKind = "role") && ($ZConvert(tName, "U") [ "OCUPILOT") Set tOwn = 1
        If (tKind = "resource") && ((tName = "OcuPilotAdmin") || (tName = "%DB_OCUPILOT")) Set tOwn = 1
        If (tKind = "database") && (tName = "OCUPILOT") Set tOwn = 1
        If (tKind = "mapping") && ((tName = tInstallNs) || (tName = "%ALL")) Set tOwn = 1
        If tOwn Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>Remove every probe object, each by its exact name: the namespaces through the port, then the
/// roles named for a probe, the SQL privilege rows of a probe namespace, the vendor's records and
/// activation logs keyed by a probe, the tasks that run in one, and the application directories under
/// the CSP tree; <parameter>EDITORSAPP</parameter>'s matching roles restored when they changed; each
/// probe database's configuration, file, directory and resource; and last the instance-wide objects
/// <method>RestoreInstance</method> restores. <var>pRemaining</var> is how many probe objects survived,
/// and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Try {
        Set tSC = $$$ADDSC(tSC, ..SettleOwnTasks(.tSettled))
        Set tIterator = tSettled.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTask) {
            If '..Ended(tTask.%Get("State")) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "probe task " _ tTask.%Get("GUID") _ " was still " _ tTask.%Get("State") _ " after the settle's wait"))
        }
        Set tNamespaces = ..ProbeNamespaces()
        Set tPointer = 0
        While $ListNext(tNamespaces, tPointer, tNamespace) {
            Kill tQuery
            Set tQuery("name") = tNamespace
            Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
        }
        Set tSC = $$$ADDSC(tSC, ..RemoveSystemRecords())
        Set tSC = $$$ADDSC(tSC, ..RemoveHealthShareRecords())
        Set tSC = $$$ADDSC(tSC, ..RestoreEditorsApp())
        Set tSC = $$$ADDSC(tSC, ..RemoveDatabases())
        Set tSC = $$$ADDSC(tSC, ..RestoreInstance())
        Set pRemaining = ..Remaining()
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " interop probe object(s) survived their removal"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many probe objects the instance still holds: snapshot lines naming a probe.</p>
ClassMethod Remaining() As %Integer
{
    Set tCount = 0
    Set tIterator = ..Snapshot().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If $ZConvert(tLine, "U") [ ..#PREFIX Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Delete the roles named for a probe namespace, its SQL privilege rows, the <code>^%SYS</code>
/// nodes a probe subscripts and the tasks that run in a probe namespace, in <code>%SYS</code>, and the
/// probe application directories under the CSP tree and the probe-named files in the manager
/// directory.</p>
ClassMethod RemoveSystemRecords() As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tPrefix = ..#PREFIX
    Set tRoles = ""
    Set tIterator = ..Snapshot().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If ($Piece(tLine, "|", 1) = "role") && ..IsProbeRole($Piece(tLine, "|", 2)) Set tRoles = tRoles _ $ListBuild($Piece(tLine, "|", 2))
    }
    Set tPaths = ..ProbePaths()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPointer = 0
        While $ListNext(tRoles, tPointer, tRole) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tRole))
        }
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tPrepare = tStatement.%Prepare("DELETE FROM Security.SQLPrivileges WHERE %EXACT(Namespace) %STARTSWITH ?")
        If $$$ISOK(tPrepare) {
            Set tResult = tStatement.%Execute(tPrefix)
            If tResult.%SQLCODE < 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe SQL privilege rows could not be deleted: SQLCODE " _ tResult.%SQLCODE))
        } Else {
            Set tSC = $$$ADDSC(tSC, tPrepare)
        }
        For tTop = "Ensemble", "HealthShare", "HealthShareLocal" {
            Set tNodes = ""
            Set tNode = $Name(^%SYS(tTop))
            For {
                Set tNode = $Query(@tNode)
                If (tNode = "") || ($QSubscript(tNode, 1) '= tTop) Quit
                Set tNamed = 0
                For tI = 2:1:$QLength(tNode) {
                    If $ZConvert($QSubscript(tNode, tI), "U") [ tPrefix Set tNamed = 1 Quit
                }
                If tNamed Set tNodes = tNodes _ $ListBuild(tNode)
            }
            Set tPointer = 0
            While $ListNext(tNodes, tPointer, tNode) {
                Kill @tNode
            }
        }
        Set tTasks = ""
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, NameSpace FROM %SYS.Task")
        While tResult.%Next() {
            If $Extract($ZConvert(tResult.%Get("NameSpace"), "U"), 1, $Length(tPrefix)) = tPrefix Set tTasks = tTasks _ $ListBuild(tResult.%Get("ID"))
        }
        Set tPointer = 0
        While $ListNext(tTasks, tPointer, tTask) {
            Set tSC = $$$ADDSC(tSC, ##class(%SYS.Task).%DeleteId(tTask))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set tPointer = 0
    While $ListNext(tPaths, tPointer, tPath) {
        If $Extract(tPath, *) = "/" {
            Do ##class(%File).RemoveDirectoryTree(tPath)
        } Else {
            Do ##class(%File).Delete(tPath)
        }
    }
    Quit tSC
}

/// <p>In HSSYS, where the HealthShare libraries are installed: delete the configuration item and the
/// activation log rows of each probe namespace, by exact name.</p>
ClassMethod RemoveHealthShareRecords() As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tPrefix = ..#PREFIX
    Set tOrigNS = $NAMESPACE
    Try {
        If '##class(%SYS.Namespace).Exists("HSSYS") Quit
        Set $NAMESPACE = "HSSYS"
        If $System.SQL.Schema.TableExists("HS_Util_Installer.ConfigItem") {
            Set tItems = ""
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ID) AS ID FROM HS_Util_Installer.ConfigItem")
            While tResult.%Next() {
                If $Extract($ZConvert(tResult.%Get("ID"), "U"), 1, $Length(tPrefix)) = tPrefix Set tItems = tItems _ $ListBuild(tResult.%Get("ID"))
            }
            Set tPointer = 0
            While $ListNext(tItems, tPointer, tItem) {
                Set tSC = $$$ADDSC(tSC, $ClassMethod("HS.Util.Installer.ConfigItem", "%DeleteId", tItem))
            }
        }
        If $System.SQL.Schema.TableExists("HS_HC_Util_Installer.Log") {
            Set tRows = ""
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, %EXACT(Namespace) AS Namespace FROM HS_HC_Util_Installer.Log")
            While tResult.%Next() {
                If $Extract($ZConvert(tResult.%Get("Namespace"), "U"), 1, $Length(tPrefix)) = tPrefix Set tRows = tRows _ $ListBuild(tResult.%Get("ID"))
            }
            Set tPointer = 0
            While $ListNext(tRows, tPointer, tRow) {
                Set tSC = $$$ADDSC(tSC, $ClassMethod("HS.HC.Util.Installer.Log", "%DeleteId", tRow))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Restore <parameter>EDITORSAPP</parameter>'s matching roles to the value <method>Add</method>
/// recorded, when they differ, and forget the record once no probe namespace remains.</p>
ClassMethod RestoreEditorsApp() As %Status [ Private ]
{
    If '$Data(@..#RECORD@("E5"), tRecorded) Quit $$$OK
    Set tSC = $$$OK
    Set tRoles = ..EditorsRoles(.tHeld)
    If tHeld && (tRoles '= tRecorded) {
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            Kill tProperties
            Set tProperties("MatchRoles") = tRecorded
            Set tSC = ##class(Security.Applications).Modify(..#EDITORSAPP, .tProperties)
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = ex.AsStatus()
        }
    }
    If $$$ISOK(tSC) && ($ListLength(..ProbeNamespaces()) = 0) Kill @..#RECORD@("E5")
    Quit tSC
}

/// <p>Record in <parameter>RECORD</parameter> the instance-wide lines of <method>Snapshot</method> (its
/// <parameter>INSTANCEKINDS</parameter> lines, under <code>"I"</code>) and the
/// <parameter>SYSTEMCONFIG</parameter> nodes (under <code>"N"</code>), when no probe namespace exists and
/// nothing is recorded yet.</p>
ClassMethod RecordInstance() As %Status
{
    If $Data(@..#RECORD@("I")) Quit $$$OK
    If $ListLength(..ProbeNamespaces()) > 0 Quit $$$OK
    Set tCount = 0
    Set tIterator = ..Snapshot().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If '..IsInstanceKind($Piece(tLine, "|", 1)) Continue
        Set tCount = tCount + 1
        Set @..#RECORD@("I", tCount) = tLine
    }
    Do ..SystemConfigNodes(.tNodes)
    Set tNodeCount = 0
    Set tNode = ""
    For {
        Set tNode = $Order(tNodes(tNode))
        If tNode = "" Quit
        Set tNodeCount = tNodeCount + 1
        Set @..#RECORD@("N", tNodeCount) = tNode
    }
    Set @..#RECORD@("N") = tNodeCount
    Set @..#RECORD@("T") = $ZTimeStamp
    Set @..#RECORD@("I") = tCount
    Quit $$$OK
}

/// <p>Restore the instance-wide objects an enable changes to <method>RecordInstance</method>'s record,
/// each by an exact name taken from the difference: delete each resource, role and task the record
/// lacks; put back each role's resources and granted roles, each user's roles and each application's
/// matching roles that differ from it; stop, through the port's <code>LanguageServer</code>
/// <code>STOP</code>, each external language server that runs now and was stopped in it, and stop when
/// it runs, then <code>DELETE</code>, each one it lacks (none when it holds no language server, as when
/// its list could not be read); kill each <parameter>SYSTEMCONFIG</parameter> node it lacks; and forget
/// it once no probe namespace remains.
/// A name holding <parameter>PREFIX</parameter> is <method>RemoveAll</method>'s own removal and is left
/// to it, and nothing the record holds is removed. A record older than
/// <parameter>RECORDSECONDS</parameter> is discarded unapplied, and the status says so.</p>
ClassMethod RestoreInstance() As %Status
{
    If '$Data(@..#RECORD@("I"), tTotal) Quit $$$OK
    Set tTaken = $Get(@..#RECORD@("T"))
    Set tNow = $ZTimeStamp
    If (tTaken = "") || (((($Piece(tNow, ",", 1) - $Piece(tTaken, ",", 1)) * 86400) + $Piece(tNow, ",", 2) - $Piece(tTaken, ",", 2)) > ..#RECORDSECONDS) {
        Kill @..#RECORD@("I"), @..#RECORD@("N"), @..#RECORD@("T")
        Quit $$$ERROR($$$GeneralError, "the instance-wide record was left by an earlier run whose restore failed, more than " _ ..#RECORDSECONDS _ " seconds ago; it was discarded unapplied, so restore what that run's enable changed by hand")
    }
    Set tSC = $$$OK
    Kill tRecord, tNow, tRecordNodes
    For tI = 1:1:tTotal {
        Set tLine = $Get(@..#RECORD@("I", tI))
        Set tRecord($Piece(tLine, "|", 1), $Piece(tLine, "|", 2)) = $Piece(tLine, "|", 3, *)
    }
    For tI = 1:1:+$Get(@..#RECORD@("N")) {
        Set tRecordNodes($Get(@..#RECORD@("N", tI))) = ""
    }
    Set tIterator = ..Snapshot().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tKind = $Piece(tLine, "|", 1)
        If '..IsInstanceKind(tKind) Continue
        Set tNow(tKind, $Piece(tLine, "|", 2)) = $Piece(tLine, "|", 3, *)
    }
    Do ..SystemConfigNodes(.tNodes)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tName = ""
        For {
            Set tName = $Order(tNow("user", tName), 1, tRoles)
            If tName = "" Quit
            If '$Data(tRecord("user", tName), tRecorded) || (tRecorded = tRoles) Continue
            Kill tProperties
            Set tProperties("Roles") = tRecorded
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Modify(tName, .tProperties))
        }
        Set tName = ""
        For {
            Set tName = $Order(tNow("application", tName), 1, tValue)
            If tName = "" Quit
            If '$Data(tRecord("application", tName), tRecorded) || ($Piece(tRecorded, "|", 2) = $Piece(tValue, "|", 2)) Continue
            Kill tProperties
            Set tProperties("MatchRoles") = $Piece(tRecorded, "|", 2)
            Set tSC = $$$ADDSC(tSC, ##class(Security.Applications).Modify(tName, .tProperties))
        }
        Set tName = ""
        For {
            Set tName = $Order(tNow("role", tName), 1, tValue)
            If tName = "" Quit
            If $Data(tRecord("role", tName), tRecorded) {
                If tRecorded = tValue Continue
                Kill tProperties
                Set tProperties("Resources") = $Piece(tRecorded, "|", 1)
                Set tProperties("GrantedRoles") = $Piece(tRecorded, "|", 2)
                Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Modify(tName, .tProperties))
                Continue
            }
            If ..HoldsPrefix(tName) Continue
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tName))
        }
        Set tName = ""
        For {
            Set tName = $Order(tNow("resource", tName))
            If tName = "" Quit
            If $Data(tRecord("resource", tName)) || ..HoldsPrefix(tName) Continue
            Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(tName))
        }
        Set tName = ""
        For {
            Set tName = $Order(tNow("task", tName))
            If tName = "" Quit
            If $Data(tRecord("task", tName)) Continue
            Set tSC = $$$ADDSC(tSC, ##class(%SYS.Task).%DeleteId(tName))
        }
        Set tNode = ""
        For {
            Set tNode = $Order(tNodes(tNode))
            If tNode = "" Quit
            If '$Data(tRecordNodes(tNode)) ZKill @tNode
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set tName = ""
    For {
        Set tName = $Order(tNow("languageserver", tName), 1, tRunning)
        If tName = "" Quit
        Set tHeld = $Data(tRecord("languageserver", tName), tRecorded)
        If tHeld && ('tRunning || (tRecorded '= 0)) Continue
        If 'tHeld && '$Data(tRecord("languageserver")) Continue
        Kill tQuery
        Set tQuery("name") = tName
        If tRunning Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PORT, "Invoke", "LanguageServer", "STOP", .tQuery, "", .tResult, .tHttp, .tFault))
        If 'tHeld Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PORT, "Invoke", "LanguageServer", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
    }
    If $$$ISOK(tSC) && ($ListLength(..ProbeNamespaces()) = 0) Kill @..#RECORD@("I"), @..#RECORD@("N"), @..#RECORD@("T")
    Quit tSC
}

/// <p>The lines of the difference between two broad snapshots outside <parameter>RESIDUE</parameter>,
/// as <method>Diff</method> answers them. A <parameter>STAMPEDROWS</parameter> line counts as residue
/// only when the other side holds the same node with the same settings.</p>
ClassMethod BroadResidue(pBefore As %DynamicArray, pAfter As %DynamicArray) As %DynamicObject
{
    Set tDiff = ..Diff(pBefore, pAfter)
    Kill tSettings
    For tSide = "added", "removed" {
        Set tIterator = tDiff.%Get(tSide).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tPrefix = ..StampedPrefix(tLine)
            If tPrefix '= "" Set tSettings(tSide, tPrefix) = ..RowSettings($Extract(tLine, $Length(tPrefix) + 1, *))
        }
    }
    Set tOut = {"added": [], "removed": []}
    For tSide = "added", "removed" {
        Set tOther = $Select(tSide = "added": "removed", 1: "added")
        Set tIterator = tDiff.%Get(tSide).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tResidue = ..IsResidue(tLine)
            Set tPrefix = ..StampedPrefix(tLine)
            If tResidue && (tPrefix '= "") {
                Set tMine = $Get(tSettings(tSide, tPrefix), $Char(0))
                Set tResidue = $Data(tSettings(tOther, tPrefix)) && (tMine '= $Char(0)) && (tMine = tSettings(tOther, tPrefix))
            }
            If 'tResidue Do tOut.%Get(tSide).%Push(tLine)
        }
    }
    Quit tOut
}

/// <p>The <parameter>STAMPEDROWS</parameter> prefix <var>pLine</var> begins with, or <code>""</code>.</p>
ClassMethod StampedPrefix(pLine As %String) As %String
{
    Set tFound = ""
    For tI = 1:1:$Length(..#STAMPEDROWS, ";") {
        Set tPrefix = $Piece(..#STAMPEDROWS, ";", tI)
        If (tPrefix '= "") && ($Extract(pLine, 1, $Length(tPrefix)) = tPrefix) Set tFound = tPrefix
    }
    Quit tFound
}

/// <p>A SQL statistics settings row's settings, its <code>$List</code> from the fifth position on, or
/// <code>$Char(0)</code> when <var>pValue</var> is not a list of more than four elements.</p>
ClassMethod RowSettings(pValue As %String) As %String
{
    If '$ListValid(pValue) || ($ListLength(pValue) < 5) Quit $Char(0)
    Quit $List(pValue, 5, $ListLength(pValue))
}

/// <p>Whether snapshot line <var>pLine</var> begins with one of <parameter>RESIDUE</parameter>'s
/// prefixes.</p>
ClassMethod IsResidue(pLine As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$Length(..#RESIDUE, ";") {
        Set tPrefix = $Piece(..#RESIDUE, ";", tI)
        If (tPrefix '= "") && ($Extract(pLine, 1, $Length(tPrefix)) = tPrefix) Set tFound = 1
    }
    Quit tFound
}

/// <p>Whether <var>pKind</var> is one of <parameter>INSTANCEKINDS</parameter>.</p>
ClassMethod IsInstanceKind(pKind As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#INSTANCEKINDS), pKind)
}

/// <p>Whether <var>pName</var> holds <parameter>PREFIX</parameter>, ignoring case.</p>
ClassMethod HoldsPrefix(pName As %String) As %Boolean
{
    Quit ($ZConvert(pName, "U") [ ..#PREFIX)
}

/// <p>Whether <var>pNode</var> is a <code>^%SYS("HealthShare")</code> node whose second subscript begins
/// <parameter>SYSTEMCONFIG</parameter>.</p>
ClassMethod IsSystemConfigNode(pNode As %String) As %Boolean
{
    If $QLength(pNode) < 2 Quit 0
    If $QSubscript(pNode, 1) '= "HealthShare" Quit 0
    Quit ($Extract($QSubscript(pNode, 2), 1, $Length(..#SYSTEMCONFIG)) = ..#SYSTEMCONFIG)
}

/// <p>The <parameter>SYSTEMCONFIG</parameter> nodes holding a value, as subscripts of
/// <var>pNodes</var>, read in <code>%SYS</code>.</p>
ClassMethod SystemConfigNodes(Output pNodes) [ Private ]
{
    Kill pNodes
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNode = $Name(^%SYS("HealthShare"))
        For {
            Set tNode = $Query(@tNode)
            If (tNode = "") || ($QSubscript(tNode, 1) '= "HealthShare") Quit
            If ..IsSystemConfigNode(tNode) Set pNodes(tNode) = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Each external language server, as <code>languageserver|&lt;name&gt;|&lt;0|1&gt;</code>, 1 when it
/// runs: the port's <code>LanguageServer</code> <code>LIST</code>, then its <code>ACTIVITY</code> once per
/// server for <code>CurrentlyRunning</code>.</p>
ClassMethod SnapLanguageServers(ByRef pLines) [ Private ]
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "LanguageServer", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) {
        Set pLines("error|languageserver|list") = ""
        Quit
    }
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tName = tRow.%Get("Name")
        Kill tQuery
        Set tQuery("name") = tName
        Set tQuery("maxRows") = 1
        Set tAnswer = ""
        Set tSC = $ClassMethod(..#PORT, "Invoke", "LanguageServer", "ACTIVITY", .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject(tAnswer) {
            Set pLines("error|languageserver|" _ tName) = ""
            Continue
        }
        Set pLines("languageserver|" _ tName _ "|" _ (''tAnswer.%Get("CurrentlyRunning"))) = ""
    }
}

/// <p>Delete each probe database's configuration and file through the port, then its directory and its
/// resource.</p>
ClassMethod RemoveDatabases() As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tNames = ""
    Kill tQuery
    Set tListSC = $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISOK(tListSC) && $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild($ListBuild(tRow.%Get("Name"), tRow.%Get("Directory")))
        }
    }
    Set tPointer = 0
    While $ListNext(tNames, tPointer, tEntry) {
        Kill tQuery
        Set tQuery("name") = $List(tEntry, 1)
        Set tDeleteSC = $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    }
    Set tDirectories = ..ProbeDatabaseDirectories()
    Set tPointer = 0
    While $ListNext(tDirectories, tPointer, tDirectory) {
        If ##class(%File).Exists(tDirectory _ "IRIS.DAT") {
            Kill tQuery
            Set tQuery("dir") = tDirectory
            Set tDeleteSC = $ClassMethod(..#PORT, "Invoke", "Database.SysCRUD", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
        }
        Do ##class(%File).RemoveDirectoryTree(tDirectory)
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        Set tResources = ""
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                If $Extract($ZConvert(tRS.Get("Name"), "U"), 1, $Length(..#RESOURCEPREFIX)) = ..#RESOURCEPREFIX Set tResources = tResources _ $ListBuild(tRS.Get("Name"))
            }
        }
        Set tPointer = 0
        While $ListNext(tResources, tPointer, tResource) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(tResource))
            If ##class(Security.Roles).Exists(tResource) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tResource))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>The probe database directories under the manager directory, each with its trailing
/// separator.</p>
ClassMethod ProbeDatabaseDirectories() As %List
{
    Set tDirectories = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    If $$$ISERR(tRS.Execute(..Manager(), "*", "", 1)) Quit ""
    While tRS.Next() {
        If tRS.Get("Type") '= "D" Continue
        Set tDirectory = ##class(%File).NormalizeDirectory(tRS.Get("Name"))
        If ..IsProbePath(tDirectory) Set tDirectories = tDirectories _ $ListBuild(tDirectory)
    }
    Quit tDirectories
}

/// <p>The probe application directories under the data directory's CSP tree (each ending with a
/// separator), and the probe-named files in the manager directory: what an enable leaves on disk for a
/// probe namespace.</p>
ClassMethod ProbePaths() As %List
{
    Set tPaths = ""
    Set tCsp = ##class(%File).NormalizeDirectory($System.Util.DataDirectory() _ "csp")
    For tRoot = tCsp, ##class(%File).NormalizeDirectory(tCsp _ "healthshare") {
        Set tRS = ##class(%ResultSet).%New("%File:FileSet")
        If $$$ISERR(tRS.Execute(tRoot, "*", "", 1)) Continue
        While tRS.Next() {
            If (tRS.Get("Type") = "D") && ..IsProbePath(tRS.Get("Name")) Set tPaths = tPaths _ $ListBuild(##class(%File).NormalizeDirectory(tRS.Get("Name")))
        }
    }
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    If $$$ISOK(tRS.Execute(..Manager(), "*", "", 0)) {
        While tRS.Next() {
            If (tRS.Get("Type") = "F") && ($ZConvert(tRS.Get("ItemName"), "L") [ ..#DIRPREFIX) Set tPaths = tPaths _ $ListBuild(tRS.Get("Name"))
        }
    }
    Quit tPaths
}

/// <p>Whether role <var>pRole</var> is one the vendor names for a probe namespace.</p>
ClassMethod IsProbeRole(pRole As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$Length(..#ROLESTEMS, ",") {
        Set tStem = $Piece(..#ROLESTEMS, ",", tI)
        If ($Extract(pRole, 1, $Length(tStem)) = tStem) && ..IsProbe($Extract(pRole, $Length(tStem) + 1, *)) Set tFound = 1
    }
    Quit tFound
}

/// <p>Whether role <var>pRole</var> is one the vendor names for namespace <var>pNamespace</var>.</p>
ClassMethod IsRoleFor(pRole As %String, pNamespace As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$Length(..#ROLESTEMS, ",") {
        If pRole = ($Piece(..#ROLESTEMS, ",", tI) _ pNamespace) Set tFound = 1
    }
    Quit tFound
}

/// <p>The <code>%SYS</code> reads of <method>Snapshot</method>: namespaces, databases, applications,
/// roles, resources, probe SQL privilege rows, tasks, users, and the <code>^%SYS</code> nodes (all of
/// them with <var>pBroad</var> 1, else those under <code>Ensemble</code>, <code>HealthShare</code> and
/// <code>HealthShareLocal</code> whose subscripts name a probe, and the <parameter>SYSTEMCONFIG</parameter>
/// records), each value cut to 120 characters.</p>
ClassMethod SnapSystem(pBroad As %Boolean, ByRef pLines) [ Private ]
{
    Set tPrefix = ..#PREFIX
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Namespaces:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set pLines("namespace|" _ tRS.Get("Namespace") _ "|" _ tRS.Get("Globals") _ "|" _ tRS.Get("Routines") _ "|" _ tRS.Get("Temp Storage")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set pLines("database|" _ tRS.Get("Name") _ "|" _ tRS.Get("Directory")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Kill tProperties
                Do ##class(Security.Applications).Get(tName, .tProperties)
                Set pLines("application|" _ tName _ "|" _ $Get(tProperties("NameSpace")) _ "|" _ $Get(tProperties("MatchRoles")) _ "|" _ $Get(tProperties("Path"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Kill tProperties
                Do ##class(Security.Roles).Get(tName, .tProperties)
                Set pLines("role|" _ tName _ "|" _ $Get(tProperties("Resources")) _ "|" _ $Get(tProperties("GrantedRoles"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set pLines("resource|" _ tRS.Get("Name") _ "|" _ tRS.Get("PublicPermission")) = ""
            }
        }
        Set tStatement = ##class(%SQL.Statement).%New()
        If $$$ISOK(tStatement.%Prepare("SELECT %EXACT(Namespace) AS Namespace, %EXACT(SQLObject) AS SQLObject, Privilege, %EXACT(Grantee) AS Grantee, %EXACT(Grantor) AS Grantor FROM Security.SQLPrivileges WHERE %EXACT(Namespace) %STARTSWITH ?")) {
            Set tResult = tStatement.%Execute(tPrefix)
            While tResult.%Next() {
                Set pLines("sqlprivilege|" _ tResult.%Get("Namespace") _ "|" _ tResult.%Get("SQLObject") _ "|" _ tResult.%Get("Privilege") _ "|" _ tResult.%Get("Grantee") _ "|" _ tResult.%Get("Grantor")) = ""
            }
        }
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Name, NameSpace FROM %SYS.Task")
        While tResult.%Next() {
            Set pLines("task|" _ tResult.%Get("ID") _ "|" _ tResult.%Get("Name") _ "|" _ tResult.%Get("NameSpace")) = ""
        }
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set pLines("user|" _ tRS.Get("Name") _ "|" _ tRS.Get("Roles")) = ""
            }
        }
        Set tNode = "^%SYS"
        For {
            Set tNode = $Query(@tNode)
            If tNode = "" Quit
            Set tTop = $QSubscript(tNode, 1)
            If 'pBroad {
                If (tTop '= "Ensemble") && (tTop '= "HealthShare") && (tTop '= "HealthShareLocal") Continue
                Set tNamed = ..IsSystemConfigNode(tNode)
                For tI = 2:1:$QLength(tNode) {
                    If $ZConvert($QSubscript(tNode, tI), "U") [ tPrefix Set tNamed = 1 Quit
                }
                If 'tNamed Continue
            }
            Set pLines("global|" _ tNode _ "=" _ $Extract($Get(@tNode), 1, 120)) = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pLines("error|system|" _ ex.DisplayString()) = ""
    }
}

/// <p>The mappings of each namespace in <var>pNamespaces</var>, read in <code>%SYS</code>.</p>
ClassMethod SnapMappings(pNamespaces As %List, ByRef pLines) [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPointer = 0
        While $ListNext(pNamespaces, tPointer, tNamespace) {
            For tKind = "Globals", "Routines", "Packages" {
                Set tRS = ##class(%ResultSet).%New("Config.Map" _ tKind _ ":List")
                If $$$ISERR(tRS.Execute(tNamespace, "*")) Continue
                While tRS.Next() {
                    Set pLines("mapping|" _ $ZConvert(tNamespace, "U") _ "|" _ tKind _ "|" _ tRS.Get("Name") _ "|" _ tRS.Get("Database")) = ""
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pLines("error|mappings|" _ ex.DisplayString()) = ""
    }
}

ClassMethod SnapFiles(ByRef pLines) [ Private ]
{
    Set tPaths = ..ProbePaths()
    Set tPointer = 0
    While $ListNext(tPaths, tPointer, tPath) {
        If $Extract(tPath, *) = "/" {
            Set pLines("directory|csp|" _ tPath) = ""
        } Else {
            Set pLines("file|" _ tPath) = ""
        }
    }
    Set tDirectories = ..ProbeDatabaseDirectories()
    Set tPointer = 0
    While $ListNext(tDirectories, tPointer, tDirectory) {
        Set pLines("directory|database|" _ tDirectory) = ""
    }
}

ClassMethod SnapCpf(ByRef pLines) [ Private ]
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(##class(%SYS.System).GetCPFFileName())) Quit
    Set tSection = ""
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        If $Extract(tLine) = "[" Set tSection = tLine
        If $ZConvert(tLine, "U") [ ..#PREFIX Set pLines("cpf|" _ tSection _ "|" _ tLine) = ""
    }
}

/// <p>For each global in the HSSYS database: its node count, and a checksum over its nodes and
/// values, the walk cut at 200,000 nodes.</p>
ClassMethod SnapHssys(ByRef pLines) [ Private ]
{
    Set tDirectory = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        If $$$ISOK(##class(Config.Databases).Get("HSSYS", .tProperties)) Set tDirectory = tProperties("Directory")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    If tDirectory = "" Quit
    Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:DirectoryList")
    If $$$ISERR(tRS.Execute(tDirectory, "", "*", 1)) Quit
    While tRS.Next() {
        Set tGlobal = tRS.Get("Name")
        Set tRoot = "^|""^^" _ tDirectory _ """|" _ tGlobal
        Set tCount = 0
        Set tCrc = 0
        If $Data(@tRoot) # 2 Set tCrc = $ZCRC(tRoot _ $Get(@tRoot), 7, tCrc)
        Set tNode = tRoot
        For {
            Set tNode = $Query(@tNode)
            If (tNode = "") || (tCount > 200000) Quit
            Set tCount = tCount + 1
            Set tCrc = $ZCRC(tNode _ "=" _ $Get(@tNode), 7, tCrc)
        }
        Set pLines("hssys|" _ tGlobal _ "|" _ tCount _ "|" _ tCrc) = ""
    }
}

/// <p>The HSSYS configuration items, and per probe namespace the count of activation log rows, read in
/// HSSYS where the HealthShare libraries are installed.</p>
ClassMethod SnapHealthShare(ByRef pLines) [ Private ]
{
    Set tPrefix = ..#PREFIX
    Set tOrigNS = $NAMESPACE
    Try {
        If '##class(%SYS.Namespace).Exists("HSSYS") Quit
        Set $NAMESPACE = "HSSYS"
        If $System.SQL.Schema.TableExists("HS_Util_Installer.ConfigItem") {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ID) AS ID FROM HS_Util_Installer.ConfigItem")
            While tResult.%Next() {
                Set pLines("configitem|" _ tResult.%Get("ID")) = ""
            }
        }
        If $System.SQL.Schema.TableExists("HS_HC_Util_Installer.Log") {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(Namespace) AS Namespace, COUNT(*) AS N FROM HS_HC_Util_Installer.Log GROUP BY %EXACT(Namespace)")
            While tResult.%Next() {
                If $Extract($ZConvert(tResult.%Get("Namespace"), "U"), 1, $Length(tPrefix)) = tPrefix Set pLines("activationlog|" _ tResult.%Get("Namespace") _ "|" _ tResult.%Get("N")) = ""
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pLines("error|healthshare|" _ ex.DisplayString()) = ""
    }
    Set $NAMESPACE = tOrigNS
}

}
