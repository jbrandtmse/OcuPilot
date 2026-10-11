/// <p>Pins the edges of Story 20.4's runtime reads that <class>OcuPilot.Test.InteropHostRead</class> does not reach
/// (AD-7, AD-24, AD-62): a Troubled production still answers its rows and a dead job is answered <code>Dead</code> and left
/// as it is; the Messages tab holds the headers an item sourced as well as those sent to it; a business process of pool
/// size 0 reads only its own entries of the shared <code>Ens.Actor</code> queue; a row cap of one answers one row on every
/// endpoint; and a header's and a log row's stamps are converted from UTC once, to the zone of the process that reads
/// them.</p>
/// <p>The zone leg runs the reads in a child process started with the environment variable <code>TZ</code> set, because
/// the conversion follows the operating system's zone for the process: a process can set <code>$ZTIMEZONE</code> without
/// changing it. The expected stamp is the stored UTC value moved by the child's offset, computed by arithmetic on the day
/// and the seconds.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability,
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> and <code>%System_CallOut:USE</code>, because it
/// <b>compiles a probe production in <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), starts it, hangs
/// its operation, sends it messages, leaves it Troubled, queues headers in <code>Ens.Actor</code> and starts a child
/// session. It stops and removes the probe, the queued entries and the rows it left, after the last test. One class per
/// run.</p>
Class OcuPilot.Test.InteropHostEdges Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter SVCNAME = "OcuPilotProbeSvc";

/// <p>The queue every business process of pool size 0 shares.</p>
Parameter ACTOR = "Ens.Actor";

/// <p>The two business processes of pool size 0 the actor-queue leg stores, and their class.</p>
Parameter PROCA = "OcuPilotProbeProcA";

Parameter PROCB = "OcuPilotProbeProcB";

Parameter PROCCLASS = "EnsLib.MsgRouter.RoutingEngine";

/// <p>The nine endpoints.</p>
Parameter ENDPOINTS = "Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs";

/// <p>The value of <code>TZ</code> the zone leg's child runs under: a fixed offset of eight hours west of Greenwich with no
/// daylight saving, which the child reports as 480 minutes west.</p>
Parameter ZONE = "PST8";

Parameter ZONEWEST = 480;

/// <p>The ids of the three messages the probe was sent, oldest first, comma-separated.</p>
Property PreparedIds As %String;

/// <p>The ids of the headers the actor-queue leg queued, comma-separated.</p>
Property PreparedEntries As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedIds = ""
    Set ..PreparedEntries = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostEdges compiles a probe production in USER and runs it on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the queued entries, the probe and the rows it left; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..RemoveEntries(..PreparedEntries)
    Set ..PreparedEntries = ""
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostEdges left probe state in USER")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ..RemoveEntries(..PreparedEntries)
    Set ..PreparedEntries = ""
    Quit $$$OK
}

/// <p>Bring the probe to the state the legs that read a running production assume: running with its operation hung on
/// one message and two waiting (<method>OcuPilot.Test.InteropHostRead.ArmProbe</method>), the ids of the three messages kept
/// in <property>PreparedIds</property>. A probe already there is left alone.</p>
Method Arm() As %Status
{
    Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
    If (tCurrent = ..#PRODUCTION) && (tState = 1) && (..PreparedIds '= "") && ($ClassMethod(..#READ, "QueueCount") = 2) Quit $$$OK
    Set ..PreparedIds = ""
    Set tSC = $ClassMethod(..#READ, "ArmProbe", .tIds)
    If $$$ISOK(tSC) Set ..PreparedIds = tIds
    Quit tSC
}

/// <p>The item <var>pName</var> of the probe production, in the composite spelling.</p>
ClassMethod ItemOf(pName As %String) As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ pName
}

/// <p>The rows <var>pEndpoint</var> answers for the item <var>pItem</var> (a name in the probe production, or <code>""</code>)
/// or the queue <var>pQueue</var>, at most <var>pMax</var> of them; the HTTP status in <var>pHttp</var>.</p>
ClassMethod RowsOf(pEndpoint As %String, pItem As %String = "", pQueue As %String = "", pMax As %Integer = 1000, Output pHttp As %Integer) As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = pMax
    If pItem '= "" Set tQuery("item") = ..ItemOf(pItem)
    If pQueue '= "" Set tQuery("queue") = pQueue
    Set pHttp = 0
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .tQuery, "", .tResult, .pHttp, .tFault)
    Quit $Select($IsObject($Get(tResult)): tResult, 1: "")
}

/// <p>The probe's rows from <var>pEndpoint</var>: the operation's item, or its queue for <code>QueueItems</code>, uncapped
/// but for the port's own bound.</p>
ClassMethod ProbeRows(pEndpoint As %String, Output pHttp As %Integer, pMax As %Integer = 1000) As %DynamicArray
{
    Set tItem = $Select($ListFind($ClassMethod(..#PORT, "ItemEndpoints"), pEndpoint): ..#OPNAME, 1: "")
    Quit ..RowsOf(pEndpoint, tItem, $Select(pEndpoint = "QueueItems": ..#OPNAME, 1: ""), pMax, .pHttp)
}

/// <p>How many of <var>pRows</var>, or -1 when it is not an array.</p>
ClassMethod SizeOf(pRows As %DynamicArray) As %Integer
{
    Quit $Select($IsObject(pRows): pRows.%Size(), 1: -1)
}

/// <p>The value of <var>pField</var> in each of <var>pRows</var>, in the order the rows came, comma-separated.</p>
ClassMethod Ordered(pRows As %DynamicArray, pField As %String) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tText
}

/// <p>AC6, AD-7: a production left Troubled (its jobs ended, as a crash leaves it) still answers its rows, and a read that
/// finds a job whose process is gone answers it <code>Dead</code> and leaves its status entry, its active message and the
/// queue as they were. With the monitor service ended too, nothing repairs the entry. The probe is settled afterwards.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.InteropPort:LIVEWORDS</parameter> reading <code>Running</code> alone -- the
/// monitor, jobs and status legs go red; <method>OcuPilot.Port.InteropPort.GatherJobs</method> running
/// <code>Ens.Job:Enumerate</code> -- the snapshot leg goes red, the vendor moving the dead job to a ghost id and its
/// message back on the queue.</p>
Method TestATroubledProductionStillAnswersItsRowsAndChangesNothing()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tIds = ..PreparedIds
    Set ..PreparedIds = ""
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "the probe production is left Troubled")
    Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
    Do $$$AssertEquals(tCurrent _ "|" _ tState, ..#PRODUCTION _ "|4", "it reads Troubled")
    Set tBefore = $ClassMethod(..#READ, "Snapshot")
    Do $$$AssertTrue(tBefore [ "^IRIS.Temp.EnsJobStatus(""USER"",""sys"",", "the snapshot holds the operation's job status")

    Set tMonitor = ..ProbeRows("Monitor", .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "Column", tMonitor, "Name"), "200|" _ ..#OPNAME _ "," _ ..#SVCNAME, "Monitor still lists the probe's two items")
    Set tStatus = ..ProbeRows("ItemStatus", .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..SizeOf(tStatus), "200|1", "ItemStatus is one row")
    If ..SizeOf(tStatus) = 1 {
        Set tRow = tStatus.%Get(0)
        Do $$$AssertTrue((tRow.Status '= "") && $Match(tRow.LastActivity, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$"), "and its runtime fields are the monitor's: " _ tRow.Status _ " " _ tRow.LastActivity)
    }
    Set tJobs = ..ProbeRows("Jobs", .tHttp)
    Set tJob = $ClassMethod(..#READ, "RowWhere", tJobs, "Host", ..#OPNAME)
    Do $$$AssertEquals(tHttp _ "|" _ $IsObject(tJob), "200|1", "Jobs still lists the operation's job")
    If $IsObject(tJob) {
        Do $$$AssertEquals(tJob.Dead _ "|" _ tJob.ActiveMessage, "1|" _ $Piece(tIds, ",", 1), "which reads Dead, with the message it held")
    }
    Set tItemJobs = ..ProbeRows("ItemJobs", .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..SizeOf(tItemJobs), "200|1", "ItemJobs is the item's one job")
    If (..SizeOf(tItemJobs) = 1) && $IsObject(tJob) {
        Do $$$AssertEquals(tItemJobs.%Get(0).Job _ "|" _ tItemJobs.%Get(0).Dead, tJob.Job _ "|1", "the job Jobs lists, Dead")
    }
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tRows = ..ProbeRows(tEndpoint, .tHttp)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ " answers in a Troubled production")
    }
    Do $$$AssertEquals($ClassMethod(..#READ, "Snapshot"), tBefore, "no read changed the queue, the active message, the job requests or the dead job's status entry")
    Do $$$AssertEquals($ClassMethod(..#READ, "QueueCount"), 2, "and the operation's queue still holds its two waiting messages")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is settled")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Current"), "", "and no production is current")
}

/// <p>AC1: the Messages tab of the service holds the three headers it sourced, newest first, though no header was sent
/// to it: the statement's first subselect reads the headers an item is the source of.</p>
/// <p>Mutation (Rule 19): make the first subselect of <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> read
/// <code>TargetConfigName</code> -- this goes red.</p>
Method TestTheServicesMessagesAreThoseItSourced()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tRows = ..RowsOf("ItemMessages", ..#SVCNAME, , , .tHttp)
    Do $$$AssertEquals(tHttp, 200, "ItemMessages answers for the service")
    For tI = 1:1:3 {
        Set tHeader = $ClassMethod(..#READ, "RowWhere", tRows, "ID", $Piece(..PreparedIds, ",", tI))
        If $IsObject(tHeader) {
            Do $$$AssertEquals(tHeader.Source _ "|" _ tHeader.Target, ..#SVCNAME _ "|" _ ..#OPNAME, "message " _ tI _ " is listed as the service's, sent to the operation")
        } Else {
            Do $$$AssertTrue(0, "message " _ tI _ " is among the service's messages")
        }
    }
    Do $$$AssertEquals($Piece(..Ordered(tRows, "ID"), ",", 1, 3), $Piece(..PreparedIds, ",", 3) _ "," _ $Piece(..PreparedIds, ",", 2) _ "," _ $Piece(..PreparedIds, ",", 1), "the newest three are the probe's, newest first")
}

/// <p>AC3: a business process of pool size 0 reads only its own entries of the queue it shares with every other such
/// process. With the production Troubled, so no actor job takes an entry, two entries for one process and one for another
/// are queued in <code>Ens.Actor</code>; each process's queue holds its own and the shared queue holds all three. The
/// entries and the headers are removed afterwards.</p>
/// <p>Mutation (Rule 19): delete, or invert, the target test (the <code>Continue</code>) in
/// <method>OcuPilot.Port.InteropPort.GatherQueueEntries</method> -- the first process's queue lists the other's entry or
/// none of its own, and this goes red.</p>
Method TestAPoolSizeZeroItemReadsOnlyItsOwnActorEntries()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is stopped")
    Set ..PreparedIds = ""
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "and put back as declared")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "then left Troubled, where no job takes an actor entry")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#PROCA, ..#PROCCLASS, 0, 0), "a business process of pool size 0 is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#PROCB, ..#PROCCLASS, 0, 0), "and a second")
    Set tA1 = ..QueueEntry(..#PROCA)
    Set tA2 = ..QueueEntry(..#PROCA)
    Set tB1 = ..QueueEntry(..#PROCB)
    Do $$$AssertTrue((tA1 > 0) && (tA2 > 0) && (tB1 > 0), "three entries are queued in the shared queue")
    Set ..PreparedEntries = tA1 _ "," _ tA2 _ "," _ tB1

    Set tOwn = ..RowsOf("ItemQueue", ..#PROCA, , , .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..Ordered(tOwn, "MessageId"), "200|" _ tA1 _ "," _ tA2, "the first process's queue holds its two entries")
    Do $$$AssertEquals(..Ordered(tOwn, "Target") _ "|" _ ..Ordered(tOwn, "Queue"), ..#PROCA _ "," _ ..#PROCA _ "|" _ ..#ACTOR _ "," _ ..#ACTOR, "each addressed to it, in the shared queue")
    Set tOther = ..RowsOf("ItemQueue", ..#PROCB, , , .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..Ordered(tOther, "MessageId"), "200|" _ tB1, "the second process's queue holds its one")
    Set tShared = ..RowsOf("QueueItems", , ..#ACTOR, , .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..Ordered(tShared, "MessageId"), "200|" _ tA1 _ "," _ tA2 _ "," _ tB1, "while the shared queue holds all three")

    Do ..RemoveEntries(..PreparedEntries)
    Do $$$AssertEquals(..EntriesLeft(..PreparedEntries), 0, "the queued entries are removed")
    Set ..PreparedEntries = ""
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is settled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "and put back as declared")
}

/// <p>Queue a request for <var>pTarget</var> in the shared actor queue and answer its header's id, 0 when it could not be
/// queued. Called while no job reads the queue.</p>
ClassMethod QueueEntry(pTarget As %String) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%New()
        Set tHeader.SourceConfigName = ..#SVCNAME
        Set tHeader.TargetConfigName = pTarget
        Set tHeader.TargetQueueName = ..#ACTOR
        Set tHeader.MessageBodyClassName = "Ens.Request"
        Set tHeader.Type = 1
        Set tHeader.Priority = 6
        Set tHeader.TimeCreated = $ZDateTime($ZTimeStamp, 3, , 3)
        Set tSC = ##class(Ens.Queue).EnQueue(tHeader)
        If $$$ISOK(tSC) Set tId = tHeader.%Id()
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tId
}

/// <p>Take the entries for the headers <var>pIds</var> (comma-separated) out of the shared actor queue, delete the headers,
/// and drop this process's registration in the queue. A call with no ids only drops the registration.</p>
ClassMethod RemoveEntries(pIds As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If pIds '= "" {
            Kill tAt
            Set tResult = ##class(%ResultSet).%New("Ens.Queue:EnumerateItem")
            Do tResult.Execute(..#ACTOR)
            While tResult.Next() {
                If $ListFind($ListFromString(pIds), tResult.GetData(3)) Set tAt(tResult.GetData(1), tResult.GetData(2)) = ""
            }
            Do tResult.Close()
            Set tPriority = ""
            For {
                Set tPriority = $Order(tAt(tPriority))
                If tPriority = "" Quit
                Set tIndex = ""
                For {
                    Set tIndex = $Order(tAt(tPriority, tIndex))
                    If tIndex = "" Quit
                    Do ##class(Ens.Queue).AbortItem(..#ACTOR, tPriority, tIndex)
                }
            }
            For tI = 1:1:$Length(pIds, ",") {
                Do ##class(Ens.MessageHeader).%DeleteId($Piece(pIds, ",", tI))
            }
        }
        Do ##class(Ens.Queue).Delete(..#ACTOR, $Job)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>How many of the headers <var>pIds</var> (comma-separated) are still in the shared actor queue or still stored.</p>
ClassMethod EntriesLeft(pIds As %String) As %Integer
{
    Set tLeft = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:EnumerateItem")
        Do tResult.Execute(..#ACTOR)
        While tResult.Next() {
            If $ListFind($ListFromString(pIds), tResult.GetData(3)) Set tLeft = tLeft + 1
        }
        Do tResult.Close()
        For tI = 1:1:$Length(pIds, ",") {
            If ##class(Ens.MessageHeader).%ExistsId($Piece(pIds, ",", tI)) Set tLeft = tLeft + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tLeft = -1
    }
    Quit tLeft
}

/// <p>AD-24: a row cap of one answers exactly one row on each endpoint. Seven of the nine hold more than one row on the
/// probe, so the cap is what shortens them; ItemStatus is one row by construction and the operation runs one job, so those
/// two answer one row with or without it, and the cap code they share is read through Monitor and Jobs.</p>
/// <p>Mutation (Rule 19): <code>tTop</code> always <parameter>OcuPilot.Port.InteropPort:SQLMAX</parameter> in the log and
/// message reads, or the <code>pMax</code> tests dropped from the other gatherers -- that endpoint's leg goes red.</p>
Method TestARowCapOfOneAnswersOneRowOnEveryEndpoint()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tFull = ..SizeOf(..ProbeRows(tEndpoint, .tFullHttp))
        Set tCapped = ..SizeOf(..ProbeRows(tEndpoint, .tCappedHttp, 1))
        Do $$$AssertEquals(tCappedHttp _ "|" _ tCapped, "200|1", tEndpoint _ " answers one row for a cap of one")
        Do $$$AssertTrue((tFull > 1) || ((tFull = 1) && $ListFind($ListBuild("ItemStatus", "ItemJobs"), tEndpoint)), tEndpoint _ " holds " _ tFull _ " rows uncapped, so the cap is what shortens it unless it is one of the two that hold one")
    }
}

/// <p>The stamps of a header, a queue entry and a log row are converted from UTC to local time once: read by a process
/// whose zone is eight hours west of Greenwich, each is the stored UTC value less eight hours; read by this process, whose
/// zone is UTC, each is the stored value. The stored values are read from the columns, never through
/// <code>%EXTERNAL</code>, which converts too.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.LocalStamp</method> reformatting its argument without
/// converting -- the western legs go red; <code>%EXTERNAL</code> put back around the stamp in
/// <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> -- the Messages leg goes red, the stamp converted twice.</p>
Method TestTheStampsAreConvertedOnceToTheZoneOfTheReader()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tHeaderId = $Piece(..PreparedIds, ",", 2)
    Set tLine = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("ItemLog", .tHttp), "Text", $Parameter(..#PROBE, "LOGTEXT"))
    Do $$$AssertTrue($IsObject(tLine), "the operation's line is in its log")
    Set tLogId = $Select($IsObject(tLine): tLine.ID, 1: 0)
    Set tCreated = $ClassMethod(..#READ, "StoredStamp", "SELECT TimeCreated FROM Ens.MessageHeader WHERE ID = ?", tHeaderId)
    Set tLogged = $ClassMethod(..#READ, "StoredStamp", "SELECT TimeLogged FROM Ens_Util.Log WHERE ID = ?", tLogId)
    Do $$$AssertTrue($Match(tCreated, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]*)?$") && $Match(tLogged, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]*)?$"), "the stored stamps are UTC times: " _ tCreated _ " and " _ tLogged)

    Set tHere = ..StampsRead(tHeaderId, tLogId)
    Do $$$AssertEquals(tHere.%Get("messages") _ "|" _ tHere.%Get("queue") _ "|" _ tHere.%Get("log"), ..MovedWest(tCreated, 0) _ "|" _ ..MovedWest(tCreated, 0) _ "|" _ ..MovedWest(tLogged, 0), "read in UTC, each stamp is the stored one")
    Set tThere = ..ReadInZone(..#ZONE, tHeaderId, tLogId)
    Do $$$AssertEquals(tThere.%Get("error") _ "|" _ tThere.%Get("west"), "|" _ ..#ZONEWEST, "the child ran eight hours west of Greenwich: " _ tThere.%ToJSON())
    Set tWest = +tThere.%Get("west")
    Do $$$AssertEquals(tThere.%Get("messages"), ..MovedWest(tCreated, tWest), "read eight hours west, a header's stamp is the stored one less eight hours (stored " _ tCreated _ ")")
    Do $$$AssertEquals(tThere.%Get("queue"), ..MovedWest(tCreated, tWest), "and so is a queue entry's (stored " _ tCreated _ ")")
    Do $$$AssertEquals(tThere.%Get("log"), ..MovedWest(tLogged, tWest), "and a log row's (stored " _ tLogged _ ")")
}

/// <p>The stored UTC stamp <var>pUtc</var> (<code>YYYY-MM-DD HH:MM:SS[.fff]</code>) moved <var>pWest</var> minutes west
/// of Greenwich, as <code>YYYY-MM-DDTHH:MM:SS.fff</code>: whole days and seconds, no time zone function.</p>
ClassMethod MovedWest(pUtc As %String, pWest As %Integer) As %String
{
    Set tClock = $Piece(pUtc, " ", 2)
    Set tTotal = ($ZDateH($Piece(pUtc, " ", 1), 3) * 86400) + $ZTimeH($Piece(tClock, ".", 1), 1) - (pWest * 60)
    Set tDays = tTotal \ 86400
    Quit $ZDate(tDays, 3) _ "T" _ $ZTime(tTotal - (tDays * 86400), 1) _ "." _ $Extract($Piece(tClock, ".", 2) _ "000", 1, 3)
}

/// <p>The stamps the port answers to the calling process for the header <var>pHeaderId</var> and the log row
/// <var>pLogId</var>: <code>{west, messages, queue, log}</code>, <code>west</code> the process's <code>$ZTIMEZONE</code>.</p>
ClassMethod StampsRead(pHeaderId As %String, pLogId As %String) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("west", +$ZTimeZone, "number")
    Set tHeader = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("ItemMessages", .tHttp), "ID", pHeaderId)
    Do tOut.%Set("messages", $Select($IsObject(tHeader): tHeader.TimeCreated, 1: "none"))
    Set tEntry = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("QueueItems", .tHttp), "MessageId", pHeaderId)
    Do tOut.%Set("queue", $Select($IsObject(tEntry): tEntry.TimeCreated, 1: "none"))
    Set tLog = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("ItemLog", .tHttp), "ID", pLogId)
    Do tOut.%Set("log", $Select($IsObject(tLog): tLog.TimeLogged, 1: "none"))
    Quit tOut
}

/// <p>Run <method>StampsRead</method> in a new session, in the caller's namespace, whose environment sets <code>TZ</code>
/// to <var>pZone</var>, and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ReadInZone(pZone As %String, pHeaderId As %String, pLogId As %String) As %DynamicObject
{
    Set tOut = {}
    Set tFile = ##class(%File).TempFilename("txt")
    Try {
        Do $System.Event.Clear($Job)
        Set tCommand = "##class(" _ $ClassName() _ ").ZoneChild(" _ $Job _ "," _ pHeaderId _ "," _ pLogId _ ")"
        Set tCode = $ZF(-100, "/ASYNC /STDOUT=""" _ tFile _ """ /STDERR=""" _ tFile _ ".err""", "/usr/bin/env", "TZ=" _ pZone, $System.Util.BinaryDirectory() _ "iris", "session", ##class(%SYS.System).GetInstanceName(), "-U", $NAMESPACE, tCommand)
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child session signalled nothing within 120 seconds, code " _ tCode)
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Set tDeleted = ##class(%File).Delete(tFile)
    Set tDeleted = ##class(%File).Delete(tFile _ ".err")
    Quit tOut
}

/// <p>The session <method>ReadInZone</method> starts: signal <method>StampsRead</method>'s object to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod ZoneChild(pParent As %Integer, pHeaderId As %String, pLogId As %String)
{
    Try {
        Set tOut = ..StampsRead(pHeaderId, pLogId)
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
