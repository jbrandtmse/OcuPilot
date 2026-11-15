/// <p>The backup port (AD-23, AD-29, AD-51, AD-52, AD-53, AD-58, Story 21.2): the one product class that lists the
/// instance's backup tasks, its backup history and its backup database list, and that runs a backup, freezes and thaws
/// database writes, and adds or removes a database on the backup list. It switches <code>$NAMESPACE</code> to
/// <code>%SYS</code> by save and restore around each vendor call (AD-16).</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter> for a read, <parameter>WRITEPAIRS</parameter>
/// for a write, evaluated through <method>GateClass</method> in the calling process before any vendor call or body.
/// A caller missing one is refused 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>.</p>
/// <p><b>Endpoints and request types.</b> <parameter>TASKSENDPOINT</parameter>: <code>LIST</code>, <code>GET</code> (one
/// task, with <code>AnyRunning</code>) and <code>RUN</code>; <parameter>HISTORYENDPOINT</parameter>: <code>LIST</code>;
/// <parameter>DATABASESENDPOINT</parameter>: <code>LIST</code>, <code>GET</code> (one database, with <code>Listed</code>),
/// <code>ADD</code> and <code>REMOVE</code>; <parameter>WRITESENDPOINT</parameter>: <code>GET</code> (the write state) and
/// <code>FREEZE</code> and <code>THAW</code>. A <code>GET</code> is the fresh read of the write tools (AD-51). The task
/// or database is named by the query's <code>name</code>, a freeze's suspend limit by <code>limit</code>.</p>
/// <p><b>Every write is judged before any vendor call</b> by <class>OcuPilot.Area.OsMgmt.BackupRules</class>, the rules
/// the tools' mint asks too: the target is read, then refused when the rules say so. A task is named from the instance's
/// own list and a database from its own configuration, so no caller value is a path (AD-21).</p>
/// <p><b>History and run go through the harvested body</b> (AD-23) behind <class>OcuPilot.Port.HarvestPort</class>, built
/// here from two fixed requests. <b>A freeze</b> calls <code>Backup.General.ExternalFreeze</code> with the caller's limit
/// as <code>WDSuspendLimit</code>, so the instance resumes writes by itself when the limit passes; <b>a thaw</b> calls
/// <code>ExternalThaw</code>.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>ClusteredSystem</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on
/// return.</p>
Class OcuPilot.Port.BackupPort Extends %RegisteredObject
{

/// <p>The pair set every read requires, comma-separated as <code>resource:permission</code>, in the order the gate
/// reports in (AD-8, AD-29).</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The pair set every write requires: the classic Backup menu's, which needs <code>%DB_IRISSYS</code> read and
/// write.</p>
Parameter WRITEPAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The one caller of a harvested body, and the body this port runs through it.</p>
Parameter HARVESTPORT = "OcuPilot.Port.HarvestPort";

Parameter BODYCLASS = "OcuPilot.Port.Harvest.Monitor";

Parameter BODYMETHOD = "BackupManage";

/// <p>The longest suspend limit a freeze may name, in seconds: after this long the instance blocks the processes that
/// update a database (<code>ExternalFreezeTimeOut</code>).</p>
Parameter FREEZELIMITMAX As INTEGER = 600;

Parameter TASKSENDPOINT = "Tasks";

/// <p>The endpoints a screen's read lists, in <code>LIST</code> (Story 21.2).</p>
Parameter ENDPOINTS = "Tasks,History,Databases";

Parameter HISTORYENDPOINT = "History";

Parameter DATABASESENDPOINT = "Databases";

Parameter WRITESENDPOINT = "Writes";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

/// <p>The write request types.</p>
Parameter WRITETYPES = "RUN,FREEZE,THAW,ADD,REMOVE";

/// <p>The query keys: the task or database named, a freeze's limit, and the rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter LIMITKEY = "limit";

Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The most history rows the harvested body answers.</p>
Parameter HISTORYMAX As INTEGER = 50;

/// <p>What a task reads while it runs, and what the write state reads as frozen and thawed.</p>
Parameter RUNNINGSTATUS = "Running";

Parameter FROZENSTATE = "Frozen";

Parameter THAWEDSTATE = "Thawed";

/// <p>The text a freeze leaves in the journal marker.</p>
Parameter FREEZETEXT = "OcuPilot freeze";

/// <p>The vendor's refusals a write is answered on its own code for: a database that does not exist and the temporary
/// database (#7321, #7322), and a database not on the list (#7324).</p>
Parameter CODEDATABASEMISSING = 7321;

Parameter CODEDATABASETEMP = 7322;

Parameter CODENOTLISTED = 7324;

/// <p>The vendor's refusal of a thaw while writes are not suspended (#7339), and of a freeze or a run while a backup runs or
/// writes are frozen (#7309), both measured on <code>ocupilot-ci</code>.</p>
Parameter CODENOTSUSPENDED = 7339;

Parameter CODEBACKUPRUNNING = 7309;

/// <p>The temporary database, which is never listed.</p>
Parameter TEMPDATABASE = "IRISTEMP";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "backupport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process;
/// production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line;
/// production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>Whether this instance would ignore a freeze's suspend limit: a clustered system, by the vendor's own test, a
/// cluster member list on the superserver or a database mounted by the cluster. A probe that cannot be completed answers
/// true, so a freeze is refused rather than sent unbounded. Overridable so a fixture can drive the refusal; production
/// never overrides it.</p>
ClassMethod ClusteredSystem() As %Boolean
{
    Set tClustered = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $Length($ZUtil(172, 0), ";") > 1 Set tClustered = 1
        If 'tClustered {
            Set tRS = ##class(%ResultSet).%New("Config.Databases:LocalDatabaseList")
            Set tSC = tRS.Execute()
            If $$$ISERR(tSC) Set tClustered = 1
            While $$$ISOK(tSC) && tRS.Next() {
                Set tDirectory = tRS.Get("Directory")
                If tDirectory '= "" && (+$Piece($ZUtil(49, tDirectory, 1), ",", 2) '= 0) {
                    Set tClustered = 1
                    Quit
                }
            }
        }
    } Catch {
        Set tClustered = 1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tClustered
}

/// <p>The pairs <var>pSpec</var> names as the <code>%List</code> the gate evaluates.</p>
ClassMethod Pairs(pSpec As %String) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(pSpec)
}

/// <p>Whether <var>pType</var> is one of <parameter>WRITETYPES</parameter>.</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#WRITETYPES), pType)
}

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint = ..#TASKSENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = "RUN")
    If pEndpoint = ..#HISTORYENDPOINT Quit (pType = ..#TYPELIST)
    If pEndpoint = ..#DATABASESENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = "ADD") || (pType = "REMOVE")
    If pEndpoint = ..#WRITESENDPOINT Quit (pType = ..#TYPEGET) || (pType = "FREEZE") || (pType = "THAW")
    Quit 0
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A read answers <var>pResult</var> as an array of rows (<code>LIST</code>, at most
/// <parameter>DEFAULTMAXROWS</parameter> unless <var>pQuery</var> carries <parameter>MAXROWSKEY</parameter>) or as one
/// object (<code>GET</code>); a write answers its own object. <var>pBody</var> must be empty.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; 400 <code>PORT.VALIDATION</code> for a cap of the
/// wrong shape; each <code>BACKUP.*</code> refusal on the status <class>OcuPilot.Api.BackupError</class> names; and 500
/// <code>INTERNAL</code>, logged, for a body or any failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(pType, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a backup call takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
            Set tSC = ..Listing(pEndpoint, tMax, .pResult, .pHttpStatus, .pFault, .tCut)
            Quit
        }
        If pEndpoint = ..#TASKSENDPOINT {
            If pType = ..#TYPEGET Set tSC = ..TaskState($Get(pQuery(..#NAMEKEY)), .pResult, .pHttpStatus, .pFault)
            If pType = "RUN" Set tSC = ..Run(.pQuery, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#DATABASESENDPOINT {
            If pType = ..#TYPEGET Set tSC = ..DatabaseState($Get(pQuery(..#NAMEKEY)), .pResult, .pHttpStatus, .pFault)
            If (pType = "ADD") || (pType = "REMOVE") Set tSC = ..ChangeList(pType, .pQuery, .pResult, .pHttpStatus, .pFault)
        } Else {
            If pType = ..#TYPEGET Set tSC = ..WriteState(.pResult, .pHttpStatus, .pFault)
            If (pType = "FREEZE") || (pType = "THAW") Set tSC = ..FreezeOrThaw(pType, .pQuery, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>The rows of the list <var>pEndpoint</var> names, after the read gate, at most <var>pMax</var> of them, with
/// <var>pCut</var> true when the port itself left rows out (the history's fixed cap): the call the screens' and the
/// read tools' reads are issued through (AD-36). Otherwise <method>Invoke</method>'s answers.</p>
ClassMethod Rows(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pCut = 0
    Set tSC = ..Admit(..#TYPELIST, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Listing(pEndpoint, pMax, .pRows, .pHttpStatus, .pFault, .pCut)
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The gate: <parameter>WRITEPAIRS</parameter> for a write type, otherwise <parameter>PAIRS</parameter>.</p>
ClassMethod Admit(pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs($Select(..IsWrite(pType): ..#WRITEPAIRS, 1: ..#PAIRS)), .tFailedPair) Quit $$$OK
    Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
}

/// <p>The rows of <var>pEndpoint</var>'s list.</p>
ClassMethod Listing(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status [ Private ]
{
    Set pCut = 0
    If pEndpoint = ..#TASKSENDPOINT Quit ..TaskList(pMax, .pRows, .pHttpStatus, .pFault)
    If pEndpoint = ..#HISTORYENDPOINT Quit ..History(pMax, .pRows, .pHttpStatus, .pFault, .pCut)
    Quit ..DatabaseList(pMax, .pRows, .pHttpStatus, .pFault)
}

/// <p>The backup tasks, built-in tasks first as the vendor lists them: <code>{Name, Type, LastRun, Status,
/// Description, SystemTask, WritesFrozen}</code>.</p>
ClassMethod TaskList(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 200
    Set tSC = ..TaskRows(.tAll)
    If $$$ISERR(tSC) Quit ..Fail("the backup tasks could not be read", tSC, .pHttpStatus, .pFault)
    Set pRows = []
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If pRows.%Size() >= pMax Quit
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The backup history, newest first, at most <parameter>HISTORYMAX</parameter> rows through the harvested body:
/// <code>{Time, Type, Status, Databases, Description}</code>. <var>pCut</var> is true when a further entry exists.</p>
ClassMethod History(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status [ Private ]
{
    Set pCut = 0
    Set tBody = {}
    Do tBody.%Set("action", "listHistory", "string")
    Kill tQuery
    Set tSC = $ClassMethod(..#HARVESTPORT, "Invoke", ..#BODYCLASS, ..#BODYMETHOD, ..Pairs(..#PAIRS), .tQuery, tBody, .tAnswer, .pHttpStatus, .pFault, .tConsole)
    If $$$ISERR(tSC) Quit tSC
    Set pRows = []
    Set tEntries = $Select($IsObject(tAnswer) && tAnswer.%IsA("%Library.DynamicObject") && (tAnswer.%GetTypeOf("entries") = "array"): tAnswer.%Get("entries"), 1: "")
    If '$IsObject(tEntries) Quit ..Fail("the backup history answered no entries", $$$ERROR($$$GeneralError, "the backup history body answered no entries"), .pHttpStatus, .pFault)
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If pRows.%Size() >= pMax Quit
        If '$IsObject(tEntry) Continue
        Set tRow = {}
        Do tRow.%Set("Time", ..Text(tEntry, "timestamp"), "string")
        Do tRow.%Set("Type", ..Text(tEntry, "type"), "string")
        Do tRow.%Set("Status", ..Text(tEntry, "status"), "string")
        Do tRow.%Set("Databases", ..Text(tEntry, "list"), "string")
        Do tRow.%Set("Description", ..Text(tEntry, "description"), "string")
        Do pRows.%Push(tRow)
    }
    Set pCut = ..MoreHistory()
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the history holds an entry beyond the <parameter>HISTORYMAX</parameter> the body answers: the same
/// canonical positive-integer subscripts the body counts.</p>
ClassMethod MoreHistory() As %Boolean [ Private ]
{
    Set tMore = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCount = 0
        Set tKey = $Order(^SYS("BUHISTORY", ""), -1)
        While tKey '= "" {
            If (tKey = +tKey) && (tKey = (tKey \ 1)) && (+tKey > 0) Set tCount = tCount + 1
            If tCount > ..#HISTORYMAX {
                Set tMore = 1
                Quit
            }
            Set tKey = $Order(^SYS("BUHISTORY", tKey), -1)
        }
    } Catch {
        Set tMore = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tMore
}

/// <p>The backup database list: <code>{Database, Directory}</code> per database. A list nobody defined answers no
/// rows.</p>
ClassMethod DatabaseList(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 200
    Set tSC = ..ListedRows(.tAll)
    If $$$ISERR(tSC) Quit ..Fail("the backup database list could not be read", tSC, .pHttpStatus, .pFault)
    Set pRows = []
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If pRows.%Size() >= pMax Quit
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The vendor's backup tasks as <code>{Name, Type, LastRun, Status, Description, SystemTask, WritesFrozen}</code>.</p>
ClassMethod TaskRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFrozen = ''##class(Backup.General).IsWDSuspended()
        Set tRS = ##class(%ResultSet).%New("Backup.Task:List")
        Set tSC = tRS.Execute()
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            Set tRow = {}
            Do tRow.%Set("Name", tRS.GetData(1), "string")
            Do tRow.%Set("Type", tRS.GetData(2), "string")
            Do tRow.%Set("LastRun", tRS.GetData(7), "string")
            Do tRow.%Set("Status", tRS.GetData(8), "string")
            Do tRow.%Set("Description", tRS.GetData(5), "string")
            Do tRow.%Set("SystemTask", ''tRS.GetData(9), "boolean")
            Do tRow.%Set("WritesFrozen", tFrozen, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Set pRows = []
    Quit tSC
}

/// <p>The vendor's backup database list as <code>{Database, Directory}</code>.</p>
ClassMethod ListedRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Backup.General:DatabaseList")
        Set tSC = tRS.Execute()
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            Set tRow = {}
            Do tRow.%Set("Database", tRS.GetData(1), "string")
            Do tRow.%Set("Directory", tRS.GetData(2), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Set pRows = []
    Quit tSC
}

/// <p>The names of the local databases the instance configures, upper-cased, mapped to their directory, in
/// <var>pDatabases</var>. The temporary database is not one.</p>
ClassMethod LocalDatabases(Output pDatabases) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pDatabases
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Databases:LocalDatabaseList")
        Set tSC = tRS.Execute()
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            Set tName = tRS.Get("Name")
            If $ZConvert(tName, "U") = ..#TEMPDATABASE Continue
            Set pDatabases($ZConvert(tName, "U")) = $ListBuild(tName, tRS.Get("Directory"))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The task <var>pName</var> as the instance lists it, in <var>pState</var>, with <code>AnyRunning</code> true while
/// any task reads <parameter>RUNNINGSTATUS</parameter>. A name the list does not hold, compared exactly, is 404
/// <code>BACKUP.TASK.NOTFOUND</code>.</p>
ClassMethod TaskState(pName As %String, Output pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pState = ""
    Set tSC = ..TaskRows(.tRows)
    If $$$ISERR(tSC) Quit ..Fail("the backup tasks could not be read", tSC, .pHttpStatus, .pFault)
    Set tFound = ""
    Set tRunning = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Status") = ..#RUNNINGSTATUS Set tRunning = 1
        If '$IsObject(tFound) && (tRow.%Get("Name") = pName) Set tFound = tRow
    }
    If '$IsObject(tFound) Quit ..Refused(##class(OcuPilot.Api.BackupError).#TASKNOTFOUND, .pHttpStatus, .pFault)
    Do tFound.%Set("AnyRunning", ''tRunning, "boolean")
    Set pState = tFound
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The database <var>pName</var>, matched without regard to case against the databases the instance configures and
/// the backup list, in <var>pState</var> as <code>{Database, Directory, Listed}</code>. A name neither holds, and the
/// temporary database, are 404 <code>BACKUP.DATABASE.NOTFOUND</code>.</p>
ClassMethod DatabaseState(pName As %String, Output pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pState = ""
    Set tSC = ..LocalDatabases(.tLocal)
    If $$$ISERR(tSC) Quit ..Fail("the databases could not be read", tSC, .pHttpStatus, .pFault)
    Set tSC = ..ListedRows(.tListedRows)
    If $$$ISERR(tSC) Quit ..Fail("the backup database list could not be read", tSC, .pHttpStatus, .pFault)
    Set tKey = $ZConvert(pName, "U")
    Set tName = ""
    Set tDirectory = ""
    If (tKey '= "") && (tKey '= ..#TEMPDATABASE) && $Data(tLocal(tKey)) {
        Set tName = $List(tLocal(tKey), 1)
        Set tDirectory = $List(tLocal(tKey), 2)
    }
    Set tListed = 0
    Set tIterator = tListedRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert(tRow.%Get("Database"), "U") '= tKey Continue
        Set tListed = 1
        If tName = "" Set tName = tRow.%Get("Database")
        If tDirectory = "" Set tDirectory = tRow.%Get("Directory")
    }
    If (tName = "") || (tKey = ..#TEMPDATABASE) Quit ..Refused(##class(OcuPilot.Api.BackupError).#DATABASENOTFOUND, .pHttpStatus, .pFault)
    Set pState = {}
    Do pState.%Set("Database", tName, "string")
    Do pState.%Set("Directory", tDirectory, "string")
    Do pState.%Set("Listed", ''tListed, "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The write state in <var>pState</var>: <code>{WriteState, Clustered, LimitMax, limit}</code>, <code>limit</code> always null, <code>WriteState</code>
/// <parameter>FROZENSTATE</parameter> or <parameter>THAWEDSTATE</parameter>.</p>
ClassMethod WriteState(Output pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pState = ""
    Set tOrigNS = $NAMESPACE
    Set tFrozen = 0
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFrozen = ''##class(Backup.General).IsWDSuspended()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Quit ..Fail("the write state could not be read", tSC, .pHttpStatus, .pFault)
    Set pState = {}
    Do pState.%Set("WriteState", $Select(tFrozen: ..#FROZENSTATE, 1: ..#THAWEDSTATE), "string")
    Do pState.%Set("Clustered", ''..ClusteredSystem(), "boolean")
    Do pState.%Set("LimitMax", ..#FREEZELIMITMAX, "number")
    ; The freeze's one argument is a member of the read, as a merge needs a member to set (AD-51): null, since a freeze has no prior limit.
    Do pState.%Set(..#LIMITKEY, "", "null")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Start the task <var>pQuery</var> names, in the background through the harvested body: the task is read, the
/// rules refuse a run while any task runs, and then the body is sent only <code>{"action":"run","taskName",
/// "jobbackup":1}</code>. Answers <code>{Name, Started}</code>.</p>
ClassMethod Run(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tName = $Get(pQuery(..#NAMEKEY))
    Set tSC = ..TaskState(tName, .tState, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ##class(OcuPilot.Area.OsMgmt.BackupRules).Code("RUN", tState, .pQuery)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tBody = {}
    Do tBody.%Set("action", "run", "string")
    Do tBody.%Set("taskName", tName, "string")
    Do tBody.%Set("jobbackup", 1, "number")
    Kill tQuery
    Set tSC = $ClassMethod(..#HARVESTPORT, "Invoke", ..#BODYCLASS, ..#BODYMETHOD, ..Pairs(..#WRITEPAIRS), .tQuery, tBody, .tAnswer, .pHttpStatus, .pFault, .tConsole)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Started", 1, "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Add or remove the database <var>pQuery</var> names on the backup list: the database is read, the rules refuse a
/// change the list already reflects, and then the vendor is called with the database's own configured name. A vendor
/// refusal that a concurrent change makes is answered on the same codes. Answers <code>{Database, Listed}</code>.</p>
ClassMethod ChangeList(pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..DatabaseState($Get(pQuery(..#NAMEKEY)), .tState, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ##class(OcuPilot.Area.OsMgmt.BackupRules).Code(pType, tState, .pQuery)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tName = tState.%Get("Database")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pType = "ADD" {
            Set tVendor = ##class(Backup.General).AddDatabaseToList(tName)
        } Else {
            Set tVendor = ##class(Backup.General).RemoveDatabaseFromList(tName)
        }
    } Catch ex {
        Set tVendor = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tVendor) {
        Set tCodes = $System.Status.GetErrorCodes(tVendor)
        If ($ListFind($ListFromString(tCodes), ..#CODEDATABASEMISSING)) || ($ListFind($ListFromString(tCodes), ..#CODEDATABASETEMP)) Quit ..Refused(##class(OcuPilot.Api.BackupError).#DATABASENOTFOUND, .pHttpStatus, .pFault)
        If $ListFind($ListFromString(tCodes), ..#CODENOTLISTED) Quit ..Refused(##class(OcuPilot.Api.BackupError).#LISTCONFLICT, .pHttpStatus, .pFault)
        Quit ..Fail("the backup list change was refused", tVendor, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Database", tName, "string")
    Do pResult.%Set("Listed", (pType = "ADD"), "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Freeze database writes with the suspend limit <var>pQuery</var> names, or thaw them. The write state is read and
/// the rules refuse a freeze whose limit cannot hold, writes already frozen and an instance that would ignore the limit,
/// and a thaw of writes that are not frozen, before any vendor call. A vendor refusal of the same states, reached when the
/// state changes between the read and the call, or of a freeze while a backup runs, is answered on the same codes. A freeze
/// sends the limit as
/// <code>WDSuspendLimit</code>, so the instance resumes writes by itself when it passes. Answers
/// <code>{WriteState, Limit}</code> for a freeze and <code>{WriteState}</code> for a thaw.</p>
ClassMethod FreezeOrThaw(pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..WriteState(.tState, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ##class(OcuPilot.Area.OsMgmt.BackupRules).Code(pType, tState, .pQuery)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tLimit = +$Get(pQuery(..#LIMITKEY))
    Set tVendor = ..SuspendCall(pType, tLimit)
    If $$$ISERR(tVendor) {
        ; The write state can change between the read and the call: a freeze's limit passing, or another caller.
        Set tCodes = $ListFromString($System.Status.GetErrorCodes(tVendor))
        If (pType = "THAW") && $ListFind(tCodes, ..#CODENOTSUSPENDED) Quit ..Refused(##class(OcuPilot.Api.BackupError).#NOTFROZEN, .pHttpStatus, .pFault)
        If (pType = "FREEZE") && $ListFind(tCodes, ..#CODEBACKUPRUNNING) Quit ..Refused(##class(OcuPilot.Api.BackupError).#RUNNING, .pHttpStatus, .pFault)
        If (pType = "FREEZE") && $$$ISOK(..WriteState(.tNow, .tNowHttp, .tNowFault)) && (tNow.%Get("WriteState") = ..#FROZENSTATE) Quit ..Refused(##class(OcuPilot.Api.BackupError).#FROZEN, .pHttpStatus, .pFault)
        Quit ..Fail("the " _ $ZConvert(pType, "L") _ " of database writes was refused", tVendor, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    If pType = "FREEZE" {
        Do pResult.%Set("WriteState", ..#FROZENSTATE, "string")
        Do pResult.%Set("Limit", tLimit, "number")
    } Else {
        Do pResult.%Set("WriteState", ..#THAWEDSTATE, "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's <code>ExternalFreeze</code> with the suspend limit <var>pLimit</var> as <code>WDSuspendLimit</code>, or its
/// <code>ExternalThaw</code>, in <code>%SYS</code> by save and restore, with the current device switched to the null device for the
/// call: both print their progress to the current device, which in a request is the response. The output is discarded rather than
/// captured, because <code>%SYS.Capture</code> refuses the freeze's output with <code>&lt;PROTECT&gt;</code> for a caller holding only
/// <parameter>WRITEPAIRS</parameter> (measured on <code>ocupilot-ci</code>).</p>
ClassMethod SuspendCall(pType As %String, pLimit As %Integer) As %Status [ Private ]
{
    Set tVendor = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tDevice = $IO
    Set tMnemonic = ##class(%Library.Device).GetMnemonicRoutine()
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set tOpened = 0
    ; The caller's device may redirect its output to a routine (a request, a capture); the vendor's output takes none of it.
    Set tRedirected = ##class(%Library.Device).ReDirectIO(0)
    Try {
        ; A caller already writing to the null device (its name is followed by a job suffix) keeps it: it is not this method's to close.
        If $Piece(tDevice, ":", 1) '= tNull {
            Open tNull::1
            If '$Test {
                Set tVendor = $$$ERROR($$$GeneralError, "the null device could not be opened")
                Quit
            }
            Set tOpened = 1
            Use tNull
        }
        Set $NAMESPACE = "%SYS"
        If pType = "FREEZE" {
            Set tVendor = ##class(Backup.General).ExternalFreeze("", ..#FREEZETEXT, 1, 10, 0, 0, 0, "", "", pLimit)
        } Else {
            Set tVendor = ##class(Backup.General).ExternalThaw()
        }
    } Catch ex {
        Set tVendor = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tOpened {
        If tMnemonic '= "" {
            Use tDevice::("^" _ tMnemonic)
        } Else {
            Use tDevice
        }
        Close tNull
    }
    Do ##class(%Library.Device).ReDirectIO(tRedirected)
    Quit tVendor
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as <code>""</code>.</p>
ClassMethod Text(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>The 403 the gate answers, <code>AUTH.NOPRIVILEGE</code> with the pair in <code>detail.failedPair</code> (AD-8,
/// AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>A refusal this port decided, with a written reason (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.BackupError</class>, on the status and slug that class names
/// and with its sentence. Nothing is logged: a refusal is an answer, not a fault.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Refuse(##class(OcuPilot.Api.BackupError).HttpStatusFor(pCode), ##class(OcuPilot.Api.BackupError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.BackupError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for each write; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ..IsWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    Quit ""
}

/// <p>The write as a script (AD-59), in <code>%SYS</code>: <code>Backup.General.StartTask</code> of the task named,
/// <code>ExternalFreeze</code> with the limit as <code>WDSuspendLimit</code>, <code>ExternalThaw</code>, or
/// <code>AddDatabaseToList</code> or <code>RemoveDatabaseFromList</code> of the database named. A value is a string
/// literal or a whole number, so nothing the query carries runs as code. A freeze whose limit the rules refuse renders
/// one <code>comment</code> step carrying the refusal's sentence and no call.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tName = $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY)))
    If pType = "RUN" {
        Set tLine = "Set tSC = ##class(Backup.General).StartTask(" _ tName _ ", 1, 1)"
    } ElseIf pType = "FREEZE" {
        If '##class(OcuPilot.Area.OsMgmt.BackupRules).LimitHolds($Get(pQuery(..#LIMITKEY))) {
            Quit [($ClassMethod(tAdmin, "Step", "comment", ##class(OcuPilot.Api.BackupError).#REASONFREEZELIMIT))]
        }
        Set tLine = "Set tSC = ##class(Backup.General).ExternalFreeze("""", " _ $ClassMethod(tAdmin, "Literal", ..#FREEZETEXT) _ ", 1, 10, 0, 0, 0, """", """", " _ (+$Get(pQuery(..#LIMITKEY))) _ ")"
    } ElseIf pType = "THAW" {
        Set tLine = "Set tSC = ##class(Backup.General).ExternalThaw()"
    } ElseIf pType = "ADD" {
        Set tLine = "Set tSC = ##class(Backup.General).AddDatabaseToList(" _ tName _ ")"
    } Else {
        Set tLine = "Set tSC = ##class(Backup.General).RemoveDatabaseFromList(" _ tName _ ")"
    }
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild(tLine)))]
}

}
