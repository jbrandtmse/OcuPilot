/// <p>Pins Story 20.4's nine runtime reads against a real production (AD-7, AD-24, AD-29, AD-36, AD-62): on a probe
/// production running in <code>USER</code> with its operation hung on a message and two more waiting, each endpoint of
/// <class>OcuPilot.Port.InteropPort</class> answers the probe's rows; each screen's read route and read tool answer the
/// rows the port does; a stopped production answers no runtime row; an unknown or ambiguous item, a missing criterion and
/// a namespace that runs no interoperability are refused by name; the instance's queue, active-message, job-request and
/// job-status globals and the probe's message statuses are the same after every read; and the stamps of a header and a log
/// row are the instance's local clock time.</p>
/// <p>While the production runs, its monitor service repairs a job whose process died within about a second, without any
/// read (measured at Story 20.4's Task 0), so no job is killed here: a read that finds a dead job is pinned on the row
/// builder (<class>OcuPilot.Test.InteropHostDescriptor</class>) and in a Troubled production, where nothing repairs it
/// (<class>OcuPilot.Test.InteropHostEdges</class>).</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), starts it, hangs its operation for ten minutes
/// and sends it three messages. It stops and removes the probe, and the rows it left, after the last test. One class per
/// run.</p>
Class OcuPilot.Test.InteropHostRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter SVCNAME = "OcuPilotProbeSvc";

/// <p>The screens, <code>&lt;descriptor&gt;|&lt;endpoint&gt;|&lt;criterion&gt;</code>, separated by <code>;</code>.</p>
Parameter SCREENS = "InteropMonitorList|Monitor|;InteropQueueList|Queues|;InteropQueueMessageList|QueueItems|queue;InteropJobList|Jobs|;InteropItemStatusTab|ItemStatus|item;InteropItemQueueTab|ItemQueue|item;InteropItemLogTab|ItemLog|item;InteropItemMessageTab|ItemMessages|item;InteropItemJobTab|ItemJobs|item";

/// <p>The ids of the three messages the probe was sent, oldest first, comma-separated.</p>
Property PreparedIds As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedIds = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostRead compiles a probe production in USER and runs it on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Stop and remove the probe; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostRead left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Bring the probe to the state a test that reads a running production assumes (<method>ArmProbe</method>), and keep
/// the ids of its three messages. A probe already there is left alone.</p>
Method Arm() As %Status
{
    Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
    If (tCurrent = ..#PRODUCTION) && (tState = 1) && (..PreparedIds '= "") && (..QueueCount() = 2) Quit $$$OK
    Set ..PreparedIds = ""
    Set tSC = ..ArmProbe(.tIds)
    If $$$ISOK(tSC) Set ..PreparedIds = tIds
    Quit tSC
}

/// <p>Stop what is running, put the probe production back as declared and start it with its operation hung for ten
/// minutes, then send it three messages: the operation takes the first and holds it, and the other two wait in its queue.
/// <var>pIds</var> is the three message ids, oldest first, comma-separated. Shared with
/// <class>OcuPilot.Test.InteropHostGate</class>.</p>
ClassMethod ArmProbe(Output pIds As %String) As %Status
{
    Set pIds = ""
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SetHang", 600)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Hang 3
    Set tBefore = ..LastHeader()
    For tI = 1:1:3 {
        Set tSC = $ClassMethod(..#PROBE, "Send")
        If $$$ISERR(tSC) Quit
        Hang 1
    }
    If $$$ISERR(tSC) Quit tSC
    For tTry = 1:1:30 {
        If ..QueueCount() = 2 Quit
        Hang 1
    }
    If ..QueueCount() '= 2 Quit $$$ERROR($$$GeneralError, "the probe's operation did not take one message and leave two waiting")
    Set pIds = ..HeaderIdsAfter(tBefore)
    If $Length(pIds, ",") '= 3 Quit $$$ERROR($$$GeneralError, "the probe was sent three messages and the headers read " _ pIds)
    Quit $$$OK
}

/// <p>The messages waiting in the probe operation's queue, read in <code>USER</code>.</p>
ClassMethod QueueCount() As %Integer
{
    Set tCount = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tCount = +##class(Ens.Queue).GetCount(..#OPNAME)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The newest message header's id in <code>USER</code>, 0 when there is none.</p>
ClassMethod LastHeader() As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT MAX(ID) FROM Ens.MessageHeader")
        If tResult.%Next() Set tId = +tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tId
}

/// <p>The ids of the probe service's messages to the probe operation after header <var>pAfter</var>, oldest first.</p>
ClassMethod HeaderIdsAfter(pAfter As %Integer) As %String
{
    Set tIds = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens.MessageHeader WHERE ID > ? AND SourceConfigName = ? AND TargetConfigName = ? ORDER BY ID", pAfter, ..#SVCNAME, ..#OPNAME)
        While tResult.%Next() {
            Set tIds = tIds _ $Select(tIds = "": "", 1: ",") _ tResult.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tIds
}

/// <p>The probe operation's item, in the composite spelling.</p>
ClassMethod ItemId() As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ ..#OPNAME
}

/// <p>The rows <var>pEndpoint</var> answers for the query <var>pQuery</var>, or <code>""</code> when it answers none; the
/// HTTP status in <var>pHttp</var> and the fault in <var>pFault</var>.</p>
ClassMethod Rows(pEndpoint As %String, ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Set pQuery("namespace") = ..#NAMESPACE
    Set pQuery("maxRows") = 1000
    Set pHttp = 0
    Set pFault = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .pQuery, "", .tResult, .pHttp, .pFault)
    Quit $Select($IsObject($Get(tResult)): tResult, 1: "")
}

/// <p>The probe's rows from <var>pEndpoint</var>, the item or the queue named by the probe.</p>
ClassMethod ProbeRows(pEndpoint As %String, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Kill tQuery
    If $ListFind($ClassMethod(..#PORT, "ItemEndpoints"), pEndpoint) Set tQuery("item") = ..ItemId()
    If pEndpoint = "QueueItems" Set tQuery("queue") = ..#OPNAME
    Quit ..Rows(pEndpoint, .tQuery, .pHttp, .pFault)
}

/// <p>The value of <var>pField</var> in each of <var>pRows</var>, comma-separated and sorted.</p>
ClassMethod Column(pRows As %DynamicArray, pField As %String) As %String
{
    Kill tSet
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSet(tRow.%Get(pField), tIndex) = ""
    }
    Set tText = ""
    Set tValue = ""
    For {
        Set tValue = $Order(tSet(tValue))
        If tValue = "" Quit
        Set tIndex = ""
        For {
            Set tIndex = $Order(tSet(tValue, tIndex))
            If tIndex = "" Quit
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tValue
        }
    }
    Quit tText
}

/// <p>The first of <var>pRows</var> whose <var>pField</var> is <var>pValue</var>, or <code>""</code>.</p>
ClassMethod RowWhere(pRows As %DynamicArray, pField As %String, pValue As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get(pField) = pValue Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>The rows as a sorted digest of their members but the idle time, which moves between two reads.</p>
ClassMethod Digest(pRows As %DynamicArray) As %String
{
    Kill tSet
    If '$IsObject(pRows) Quit "none"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tCopy = ##class(%DynamicObject).%FromJSON(tRow.%ToJSON())
        Do tCopy.%Remove("ElapsedTime")
        Set tSet(tCopy.%ToJSON()) = ""
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSet(tKey))
        If tKey = "" Quit
        Set tText = tText _ tKey _ $Char(10)
    }
    Quit tText
}

/// <p>AC1, AC2, AC3: each endpoint answers the probe's rows. Monitor holds the operation and the service and no vendor
/// host; the item's status is one row; Queues shows the operation's queue with two waiting and one active; the queue's
/// entries and the item's queue are the two waiting messages with their headers; the item's log holds the probe's
/// line, the one the operation wrote for the message it took, and none of another item's; its messages are the three the
/// probe was sent; and Jobs and the item's jobs hold the operation's job with the message it is working on.</p>
/// <p>Mutation (Rule 19): keep the vendor's hosts in <method>OcuPilot.Port.InteropPort.GatherHosts</method> (drop the
/// test of the production's item names) -- the monitor leg goes red; make <method>OcuPilot.Port.InteropPort.GatherQueueEntries</method>
/// skip the header join -- the queue legs go red; drop the <code>ConfigName</code> bind from the Log statement -- the log
/// leg goes red.</p>
Method TestEachEndpointAnswersTheProbesRows()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tMonitor = ..ProbeRows("Monitor", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Monitor answers")
    Do $$$AssertEquals(..Column(tMonitor, "Name"), ..#OPNAME _ "," _ ..#SVCNAME, "Monitor holds the probe's operation and service and none of the vendor's hosts")
    Set tOp = ..RowWhere(tMonitor, "Name", ..#OPNAME)
    If $IsObject(tOp) {
        Do $$$AssertEquals(tOp.Production _ "|" _ tOp.Item _ "|" _ tOp.Type _ "|" _ tOp.Status _ "|" _ tOp.Queue, ..#PRODUCTION _ "|" _ ..#PRODUCTION _ "||" _ ..#OPNAME _ "|BusinessOperation|OK|2", "the operation's monitor row names its production and item, and the two messages waiting")
        Do $$$AssertTrue($Match(tOp.LastActivity, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$"), "its last activity is the local clock time the log readers write: " _ tOp.LastActivity)
    } Else {
        Do $$$AssertTrue(0, "the operation is on the monitor")
    }

    Set tStatus = ..ProbeRows("ItemStatus", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tStatus): tStatus.%Size(), 1: -1), "200|1", "ItemStatus is one row")
    If $IsObject(tStatus) && (tStatus.%Size() = 1) {
        Set tRow = tStatus.%Get(0)
        Do $$$AssertEquals(tRow.Production _ "|" _ tRow.Name _ "|" _ tRow.ClassName _ "|" _ tRow.Type _ "|" _ tRow.Enabled _ "|" _ tRow.Status, ..#PRODUCTION _ "|" _ ..#OPNAME _ "|OcuPilotProbe.Interop.Op|operation|1|OK", "the item's configuration facts and the monitor's status")
        Do $$$AssertEquals(tRow.%IsDefined("PoolSize") + tRow.%IsDefined("Category") + tRow.%IsDefined("Comment") + tRow.%IsDefined("EnabledSource"), 0, "and no member beyond the eight")
    }

    Set tQueues = ..ProbeRows("Queues", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Queues answers")
    Set tQueue = ..RowWhere(tQueues, "Name", ..#OPNAME)
    If $IsObject(tQueue) {
        Do $$$AssertEquals(tQueue.Count _ "|" _ tQueue.Active, "2|1", "the operation's queue holds two messages and one job is working on one")
    } Else {
        Do $$$AssertTrue(0, "the operation's queue is listed")
    }

    Set tEntries = ..ProbeRows("QueueItems", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tEntries): tEntries.%Size(), 1: -1), "200|2", "QueueItems shows the two waiting entries")
    Set tWaiting = $Piece(..PreparedIds, ",", 2, 3)
    Do $$$AssertEquals(..Column(tEntries, "MessageId"), tWaiting, "they are the second and third message")
    If $IsObject(tEntries) && (tEntries.%Size() = 2) {
        Set tRow = tEntries.%Get(0)
        Do $$$AssertEquals(tRow.Queue _ "|" _ tRow.Source _ "|" _ tRow.Target _ "|" _ tRow.BodyClass _ "|" _ tRow.Status, ..#OPNAME _ "|" _ ..#SVCNAME _ "|" _ ..#OPNAME _ "|Ens.Request|Queued", "each carries its header")
    }
    Set tItemQueue = ..ProbeRows("ItemQueue", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Column(tItemQueue, "MessageId") _ "|" _ ..Column(tItemQueue, "Item"), "200|" _ tWaiting _ "|" _ ..#PRODUCTION _ "||" _ ..#OPNAME _ "," _ ..#PRODUCTION _ "||" _ ..#OPNAME, "the item's queue is the same two entries, each naming its item")

    Set tLog = ..ProbeRows("ItemLog", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "ItemLog answers")
    Set tLine = ..RowWhere(tLog, "Text", $Parameter(..#PROBE, "LOGTEXT"))
    If $IsObject(tLine) {
        Do $$$AssertEquals(tLine.Type _ "|" _ tLine.SessionId, "Info|" _ $Piece(..PreparedIds, ",", 1), "the line the operation wrote is an Info row of the first message's session")
    } Else {
        Do $$$AssertTrue(0, "the operation's line is in the item's log")
    }
    Do $$$AssertEquals(..ContainsText(tLog, "'" _ ..#SVCNAME _ "'") + ..ContainsText(tLog, "Production '"), 0, "and the log holds no row of another item or of the production")

    Set tMessages = ..ProbeRows("ItemMessages", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "ItemMessages answers")
    For tI = 1:1:3 {
        Set tHeader = ..RowWhere(tMessages, "ID", $Piece(..PreparedIds, ",", tI))
        If $IsObject(tHeader) {
            Do $$$AssertEquals(tHeader.Source _ "|" _ tHeader.Target _ "|" _ tHeader.BodyClass, ..#SVCNAME _ "|" _ ..#OPNAME _ "|Ens.Request", "message " _ tI _ " is a request of the service to the operation")
        } Else {
            Do $$$AssertTrue(0, "message " _ tI _ " is among the item's messages")
        }
    }
    Set tWaitingHeader = ..RowWhere(tMessages, "ID", $Piece(..PreparedIds, ",", 3))
    Do $$$AssertEquals($Select($IsObject(tWaitingHeader): tWaitingHeader.Status, 1: "none"), "Queued", "a waiting message reads Queued")

    Set tJobs = ..ProbeRows("Jobs", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Jobs answers")
    Set tJob = ..RowWhere(tJobs, "Host", ..#OPNAME)
    If $IsObject(tJob) {
        Do $$$AssertEquals(tJob.Status _ "|" _ tJob.ActiveMessage _ "|" _ tJob.Dead, "OK|" _ $Piece(..PreparedIds, ",", 1) _ "|0", "the operation's job is working on the first message and is alive")
        Do $$$AssertEquals(..CountWhere(tJobs, "Dead", 1), 0, "no job of the probe production is dead")
    } Else {
        Do $$$AssertTrue(0, "the operation's job is listed")
    }
    Set tItemJobs = ..ProbeRows("ItemJobs", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tItemJobs): tItemJobs.%Size(), 1: -1), "200|1", "ItemJobs is the item's one job")
    If $IsObject(tItemJobs) && (tItemJobs.%Size() = 1) && $IsObject(tJob) {
        Set tOwn = tItemJobs.%Get(0)
        Do $$$AssertEquals(tOwn.Job _ "|" _ tOwn.ActiveMessage _ "|" _ tOwn.Production _ "|" _ tOwn.Item, tJob.Job _ "|" _ tJob.ActiveMessage _ "|" _ ..#PRODUCTION _ "|" _ ..#PRODUCTION _ "||" _ ..#OPNAME, "and it is the job Jobs lists")
    }
}

/// <p>How many of <var>pRows</var> have <var>pField</var> equal to <var>pValue</var>.</p>
ClassMethod CountWhere(pRows As %DynamicArray, pField As %String, pValue As %String) As %Integer
{
    Set tCount = 0
    If '$IsObject(pRows) Quit 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get(pField) = pValue Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>How many of <var>pRows</var> have <var>pText</var> in their <code>Text</code>.</p>
ClassMethod ContainsText(pRows As %DynamicArray, pText As %String) As %Integer
{
    Set tCount = 0
    If '$IsObject(pRows) Quit 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Text") [ pText Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>AC1, AC2, AC3: each screen's read route and its read tool answer the rows the port does -- the screen's by
/// <code>Screen.Read</code>, the tool's by the registry -- compared but for the idle time, which moves between two reads.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Read</method> drop the interop source's criteria -- the item and
/// queue screens go red.</p>
Method TestEachScreenAndToolAnswerTheSameRowsAsThePort()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tEntry, "|", 1)
        Set tEndpoint = $Piece(tEntry, "|", 2)
        Set tCriterion = $Piece(tEntry, "|", 3)
        Kill tCriteria
        Set tArgs = {}
        If tCriterion = "item" {
            Set tCriteria("item") = ..ItemId()
            Do tArgs.%Set("item", ..ItemId(), "string")
        } ElseIf tCriterion = "queue" {
            Set tCriteria("queue") = ..#OPNAME
            Do tArgs.%Set("queue", ..#OPNAME, "string")
        }
        Set tPortRows = ..ProbeRows(tEndpoint, .tPortHttp, .tPortFault)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
        Do $$$AssertEquals(+$Get(tScreenHttp), 200, tEndpoint _ ": the screen's read answers")
        Set tToolName = $ClassMethod(tClass, "ToolIdentifier") _ ".read"
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
        Kill tResult
        Set tToolHttp = 0
        If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(+$Get(tToolHttp), 200, tToolName _ ": the read tool answers")
        If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) || '$IsObject(tPortRows) Continue
        Do $$$AssertTrue(tPortRows.%Size() > 0, tEndpoint _ ": the port answers rows")
        Set tPortDigest = ..Digest(..Projected(tPortRows, tClass))
        Do $$$AssertEquals(..Digest(tAnswer.rows), tPortDigest, tEndpoint _ ": the screen's rows are the port's, in the fields it declares")
        Do $$$AssertEquals(..Digest(tResult.rows), tPortDigest, tEndpoint _ ": and so are the tool's")
    }
}

/// <p><var>pRows</var> reduced to the fields <var>pClass</var> declares to read, as the screen's read returns them.</p>
ClassMethod Projected(pRows As %DynamicArray, pClass As %String) As %DynamicArray
{
    Set tSC = $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Set tOut = []
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tCopy = {}
        Set tFields = tDeclaration.read.fields.%GetIterator()
        While tFields.%GetNext(.tAt, .tField) {
            If tRow.%IsDefined(tField) Do tCopy.%Set(tField, tRow.%Get(tField), $Select(tRow.%GetTypeOf(tField) = "array": "", tRow.%GetTypeOf(tField) = "object": "", 1: tRow.%GetTypeOf(tField)))
        }
        Do tOut.%Push(tCopy)
    }
    Quit tOut
}

/// <p>AC2, AC3, AC5: with the production stopped, Monitor, Jobs and the item's jobs answer no row and the item's
/// status keeps its configuration facts with empty runtime fields.</p>
/// <p>The vendor answers no row for a stopped production (measured at Story 20.4's Task 0), so the running-or-troubled
/// test in <method>OcuPilot.Port.InteropPort.LiveCurrent</method> is a second guard and dropping it turns nothing red here.
/// The production-identity clause it also carries is pinned by <method>TestAnItemOfAnotherProductionReadsNoRuntimeRow</method>,
/// and a Troubled production's rows by <method>OcuPilot.Test.InteropHostEdges.TestATroubledProductionStillAnswersItsRowsAndChangesNothing</method>.</p>
Method TestAStoppedProductionAnswersNoRuntimeRow()
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Do $$$AssertStatusOK(tSC, "the probe production stops")
    Set ..PreparedIds = ""
    For tEndpoint = "Monitor", "Jobs", "ItemJobs" {
        Set tRows = ..ProbeRows(tEndpoint, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: -1), "200|0", tEndpoint _ ": a stopped production answers no row")
    }
    Set tStatus = ..ProbeRows("ItemStatus", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tStatus): tStatus.%Size(), 1: -1), "200|1", "ItemStatus still answers its one row")
    If $IsObject(tStatus) && (tStatus.%Size() = 1) {
        Set tRow = tStatus.%Get(0)
        Do $$$AssertEquals(tRow.Name _ "|" _ tRow.ClassName _ "|" _ tRow.Enabled _ "|" _ tRow.Status _ "|" _ tRow.AdapterState _ "|" _ tRow.LastActivity, ..#OPNAME _ "|OcuPilotProbe.Interop.Op|1|||", "with its configuration facts and empty runtime fields")
    }
    Set tScreenSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.InteropMonitorList", 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tNone)
    Do $$$AssertEquals(+$Get(tScreenHttp) _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.rows.%Size(), 1: -1), "200|0", "and the Production monitor lists none")
}

/// <p>AC2: an item of a production that is not the namespace's current one reads no runtime row, though the running
/// production holds a host of the same name: the probe's second production declares the same operation and service, so its
/// operation's status has empty runtime fields, its jobs and its queue are none, and the running production's
/// operation is untouched by the read.</p>
/// <p>Mutation (Rule 19): drop the <code>pProduction = tCurrent</code> test from
/// <method>OcuPilot.Port.InteropPort.LiveCurrent</method> -- the status and jobs legs go red; drop the current test from
/// <method>OcuPilot.Port.InteropPort.ItemQueueEntries</method> -- the queue leg goes red.</p>
Method TestAnItemOfAnotherProductionReadsNoRuntimeRow()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tOther = $Parameter(..#PROBE, "OTHER")
    Kill tQuery
    Set tQuery("item") = tOther _ $Char(1) _ ..#OPNAME
    Set tStatus = ..Rows("ItemStatus", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tStatus): tStatus.%Size(), 1: -1), "200|1", "the other production's operation has a status row")
    If $IsObject(tStatus) && (tStatus.%Size() = 1) {
        Set tRow = tStatus.%Get(0)
        Do $$$AssertEquals(tRow.Production _ "|" _ tRow.Name _ "|" _ tRow.Status _ "|" _ tRow.AdapterState _ "|" _ tRow.LastActivity, tOther _ "|" _ ..#OPNAME _ "|||", "whose runtime fields are empty, though the running production's host of that name is not")
    }
    Kill tQuery
    Set tQuery("item") = tOther _ $Char(1) _ ..#OPNAME
    Set tJobs = ..Rows("ItemJobs", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tJobs): tJobs.%Size(), 1: -1), "200|0", "and it has no job")
    Kill tQuery
    Set tQuery("item") = tOther _ $Char(1) _ ..#OPNAME
    Set tQueue = ..Rows("ItemQueue", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tQueue): tQueue.%Size(), 1: -1), "200|0", "and no queued message, which the running production's queue of that name holds")
    Set tOwn = ..ProbeRows("ItemQueue", .tOwnHttp, .tOwnFault)
    Do $$$AssertEquals($Select($IsObject(tOwn): tOwn.%Size(), 1: -1), 2, "while the running production's own item still reads its two")
}

/// <p>AC5: an input that does not name a read is refused by name before the vendor is asked: no item, an item spelled
/// as neither the composite nor <code>Production||Name</code>, no queue, a row cap that is not a whole number above zero
/// (400); an unknown production and an unknown item (404); a name the production holds twice (409
/// <code>INTEROP.ITEM.AMBIGUOUS</code>); and a namespace that runs no interoperability (409
/// <code>INTEROP.NAMESPACE</code>) on every endpoint. The ambiguity is made by a second item of the same name in another
/// case and removed after.</p>
/// <p>Mutation (Rule 19): drop the count test from <method>OcuPilot.Port.InteropPort.ResolveItem</method> -- the ambiguous
/// leg goes red.</p>
Method TestAnInputThatNamesNoReadIsRefusedByName()
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Do $$$AssertStatusOK(tSC, "the probe production stops")
    Set ..PreparedIds = ""
    For tEndpoint = "ItemStatus", "ItemQueue", "ItemLog", "ItemMessages", "ItemJobs" {
        Kill tQuery
        Set tRows = ..Rows(tEndpoint, .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 PORT.VALIDATION", tEndpoint _ " without an item is refused")
        Kill tQuery
        Set tQuery("item") = ..#OPNAME
        Set tRows = ..Rows(tEndpoint, .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 PORT.VALIDATION", tEndpoint _ " with an item that is neither spelling is refused")
        Kill tQuery
        Set tQuery("item") = ..#PRODUCTION _ $Char(1) _ "OcuPilotProbeNoSuch"
        Set tRows = ..Rows(tEndpoint, .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "404 PORT.NOTFOUND", tEndpoint _ " with an unknown item is not found")
        Kill tQuery
        Set tQuery("item") = "OcuPilotProbe.No.Such||" _ ..#OPNAME
        Set tRows = ..Rows(tEndpoint, .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "404 PORT.NOTFOUND", tEndpoint _ " with an unknown production is not found")
    }
    Kill tQuery
    Set tRows = ..Rows("QueueItems", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 PORT.VALIDATION", "QueueItems without a queue is refused")
    For tBad = "0", "-1", "many" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("maxRows") = tBad
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Monitor", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 PORT.VALIDATION", "a row cap of " _ tBad _ " is refused")
    }

    Set tSC = $ClassMethod(..#PROBE, "AddItem", "ocupilotprobeop", "OcuPilotProbe.Interop.Op", 1, 0)
    Do $$$AssertStatusOK(tSC, "a second item of the operation's name in another case is stored")
    For tEndpoint = "ItemStatus", "ItemQueue", "ItemLog", "ItemMessages", "ItemJobs" {
        Kill tQuery
        Set tQuery("item") = ..ItemId()
        Set tRows = ..Rows(tEndpoint, .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.ITEM.AMBIGUOUS", tEndpoint _ " for a name the production holds twice is refused")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the production is put back as it was declared")

    For tEndpoint = "Monitor", "Queues", "Jobs", "QueueItems", "ItemStatus", "ItemQueue", "ItemLog", "ItemMessages", "ItemJobs" {
        Kill tQuery
        Set tQuery("namespace") = "%SYS"
        Set tQuery("item") = ..ItemId()
        Set tQuery("queue") = ..#OPNAME
        Set tSC = $ClassMethod(..#PORT, "Invoke", tEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.NAMESPACE", tEndpoint _ " in a namespace that runs no interoperability is refused")
    }
}

/// <p>The wire code of a fault, <code>""</code> when it is not an object.</p>
ClassMethod CodeOf(pFault) As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.%Get("code")
}

/// <p>A digest of what the vendor keeps that a read must not touch, read in <code>USER</code>: the probe operation's
/// queue, every active message, the job-request global, the operation's job status and the probe's message statuses.</p>
ClassMethod Snapshot() As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRoots = $ListBuild($Name(^Ens.Queue(..#OPNAME)), $Name(^Ens.ActiveMessage), $Name(^Ens.JobRequest))
        Set tJobs = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
        Do tJobs.Execute(..#OPNAME)
        While tJobs.Next() {
            Set tRoots = tRoots _ $ListBuild($Name(^IRIS.Temp.EnsJobStatus(..#NAMESPACE, "sys", tJobs.GetData(2))))
        }
        For tAt = 1:1:$ListLength(tRoots) {
            Set tRoot = $List(tRoots, tAt)
            Set tText = tText _ "{" _ tRoot _ "=" _ $Get(@tRoot) _ ":"
            Set tRef = tRoot
            For {
                Set tRef = $Query(@tRef)
                If (tRef = "") || ($Name(@tRef, $QLength(tRoot)) '= tRoot) Quit
                Set tText = tText _ tRef _ "=" _ @tRef _ ";"
            }
            Set tText = tText _ "}"
        }
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID, Status FROM Ens.MessageHeader WHERE TargetConfigName = ? OR SourceConfigName = ? ORDER BY ID", ..#OPNAME, ..#OPNAME)
        While tResult.%Next() {
            Set tText = tText _ "[" _ tResult.%GetData(1) _ "=" _ tResult.%GetData(2) _ "]"
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = tText _ "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>AC6: the vendor's queue, active-message, job-request and job-status globals, and the status of the probe's
/// messages, are the same after every read -- the nine endpoints through the port and the nine screens' reads -- as they
/// were before, and the snapshot is not empty: it holds the operation's two waiting entries, the message its job is working
/// on and its job.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.GatherQueueEntries</method> call
/// <code>Ens.Queue.AbortItem</code> on each entry it reads -- the snapshot differs and this goes red. No job is dead here,
/// so <code>Ens.Job:Enumerate</code> in <method>OcuPilot.Port.InteropPort.GatherJobs</method> is read by
/// <method>OcuPilot.Test.InteropHostEdges.TestATroubledProductionStillAnswersItsRowsAndChangesNothing</method>.</p>
Method TestNoReadChangesWhatTheVendorKeeps()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tBefore = ..Snapshot()
    Do $$$AssertTrue($Length(tBefore) > 200, "the snapshot is not empty: " _ $Length(tBefore) _ " characters")
    Do $$$AssertTrue((tBefore [ "^Ens.Queue(""" _ ..#OPNAME _ """,6,2)") && (tBefore [ "^Ens.Queue(""" _ ..#OPNAME _ """,6,3)"), "and holds the operation's two waiting entries")
    Do $$$AssertTrue(tBefore [ "^IRIS.Temp.EnsJobStatus(""USER"",""sys"",", "and its job's status")
    For tPass = 1:1:2 {
        For tI = 1:1:$Length(..#SCREENS, ";") {
            Set tEntry = $Piece(..#SCREENS, ";", tI)
            Set tRows = ..ProbeRows($Piece(tEntry, "|", 2), .tHttp, .tFault)
            Do $$$AssertEquals(tHttp, 200, $Piece(tEntry, "|", 2) _ " answers")
            Kill tCriteria
            If $Piece(tEntry, "|", 3) = "item" Set tCriteria("item") = ..ItemId()
            If $Piece(tEntry, "|", 3) = "queue" Set tCriteria("queue") = ..#OPNAME
            Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ $Piece(tEntry, "|", 1), 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
            Do $$$AssertEquals(+$Get(tScreenHttp), 200, $Piece(tEntry, "|", 1) _ "'s screen read answers")
        }
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no read changed the queue, the active messages, the job requests, the job status or a message's status")
}

/// <p>The stamps of a header and a log row are the instance's local clock time in the form the log readers write:
/// each is the stamp the instance stores, converted to local time by the vendor's own conversion (what the classic pages
/// call <code>$$$timeUTCtoLocal</code>), with a <code>T</code> between the date and the time. The container's zone is UTC, so
/// the conversion changes nothing here; the form, which a raw stamp breaks, is what this pins.</p>
/// <p>Mutation (Rule 19): drop the <code>LocalStamp</code> call from <method>OcuPilot.Port.InteropPort.ListItemMessages</method>
/// -- the header leg goes red (the raw stamp has a space where the form has a <code>T</code>).</p>
Method TestTheStampsAreTheInstancesLocalClockTime()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tHeaderId = $Piece(..PreparedIds, ",", 1)
    Set tStored = ..StoredStamp("SELECT TimeCreated FROM Ens.MessageHeader WHERE ID = ?", tHeaderId)
    Do $$$AssertTrue($Match(tStored, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]*)?$"), "the stored stamp is a UTC time: " _ tStored)
    Set tMessages = ..ProbeRows("ItemMessages", .tHttp, .tFault)
    Set tRow = ..RowWhere(tMessages, "ID", tHeaderId)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.TimeCreated, 1: "none"), ..LocalForm(tStored), "a header's stamp is the stored one in local time, in the log readers' form")
    Set tLog = ..ProbeRows("ItemLog", .tLogHttp, .tLogFault)
    Set tLine = ..RowWhere(tLog, "Text", $Parameter(..#PROBE, "LOGTEXT"))
    Set tLogged = ..StoredStamp("SELECT TimeLogged FROM Ens_Util.Log WHERE ID = ?", $Select($IsObject(tLine): tLine.ID, 1: 0))
    Do $$$AssertEquals($Select($IsObject(tLine): tLine.TimeLogged, 1: "none"), ..LocalForm(tLogged), "and so is a log row's")
    Set tQueue = ..ProbeRows("QueueItems", .tQueueHttp, .tQueueFault)
    Set tEntry = ..RowWhere(tQueue, "MessageId", $Piece(..PreparedIds, ",", 2))
    Set tEntryStored = ..StoredStamp("SELECT TimeCreated FROM Ens.MessageHeader WHERE ID = ?", $Piece(..PreparedIds, ",", 2))
    Do $$$AssertEquals($Select($IsObject(tEntry): tEntry.TimeCreated, 1: "none"), ..LocalForm(tEntryStored), "and so is a queue entry's")
}

/// <p>The stamp <var>pSql</var> reads for <var>pId</var> in <code>USER</code>, as the instance stores it.</p>
ClassMethod StoredStamp(pSql As %String, pId As %String) As %String
{
    Set tStamp = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql, pId)
        If tResult.%Next() Set tStamp = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tStamp
}

/// <p>The UTC stamp <var>pUtc</var> in local time by the vendor's own conversion, as <code>YYYY-MM-DDTHH:MM:SS.fff</code>;
/// <code>"none"</code> for none.</p>
ClassMethod LocalForm(pUtc As %String) As %String
{
    If pUtc = "" Quit "none"
    Set tLocal = ##class(Ens.DataType.UTC).LogicalToOdbc(pUtc)
    Quit $Extract(tLocal, 1, 10) _ "T" _ $Extract(tLocal, 12, 23)
}

}
