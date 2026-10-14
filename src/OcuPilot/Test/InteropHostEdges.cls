/// <p>Pins the edges of Story 20.4's runtime reads that <class>OcuPilot.Test.InteropHostRead</class> does not reach
/// (AD-7, AD-24, AD-62): a Troubled production still answers its rows and a dead job is answered <code>Dead</code> and left
/// as it is; the Messages tab holds the headers an item sourced as well as those sent to it, merged newest first and
/// capped, a header reading the same from either side; a business process of pool size 0 reads only its own entries of
/// the shared <code>Ens.Actor</code> queue; a row cap of one answers one row on every endpoint; a log is newest first and
/// each row carries the keys and figures the vendor's own queries give; a host with no queue or job reads no row; a read
/// that cannot take the production's runtime lock answers 503; and a header's and a log row's stamps are converted from
/// UTC once, to the zone of the process that reads them.</p>
/// <p>The zone leg runs the reads in a child process started with the environment variable <code>TZ</code> set, because
/// the conversion follows the operating system's zone for the process: a process can set <code>$ZTIMEZONE</code> without
/// changing it. The expected stamp is the stored UTC value moved by the child's offset, computed by arithmetic on the day
/// and the seconds.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability,
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> and <code>%System_CallOut:USE</code>, because it
/// <b>compiles a probe production in <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), starts it, hangs
/// its operation, sends it messages, leaves it Troubled, queues headers in <code>Ens.Actor</code>, holds the production's
/// runtime lock from a child process for a few seconds, and starts a child <code>iris session</code>, which signs in
/// without a password, as the operating system's user of the instance does in the container, and must hold the nine
/// reads' pairs. It stops and removes the probe, the queued entries and the rows it left, after the last test. One class
/// per run.</p>
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

/// <p>The ids of the headers a test stored or queued, comma-separated; they are removed after each test.</p>
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
/// to it: the statement's first branch reads the headers an item is the source of. Each reads, field for field, as it
/// does on the operation's Messages tab, which the statement's second branch reads.</p>
/// <p>Mutation (Rule 19): make the first branch of <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> read
/// <code>TargetConfigName</code>, or read <code>Status</code> without <code>%EXTERNAL</code> -- this goes red.</p>
Method TestTheServicesMessagesAreThoseItSourced()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tRows = ..RowsOf("ItemMessages", ..#SVCNAME, , , .tHttp)
    Do $$$AssertEquals(tHttp, 200, "ItemMessages answers for the service")
    Set tSent = ..ProbeRows("ItemMessages", .tHttp)
    For tI = 1:1:3 {
        Set tHeader = $ClassMethod(..#READ, "RowWhere", tRows, "ID", $Piece(..PreparedIds, ",", tI))
        If $IsObject(tHeader) {
            Do $$$AssertEquals(tHeader.Source _ "|" _ tHeader.Target, ..#SVCNAME _ "|" _ ..#OPNAME, "message " _ tI _ " is listed as the service's, sent to the operation")
            Set tSentRow = $ClassMethod(..#READ, "RowWhere", tSent, "ID", tHeader.ID)
            For tField = "TimeCreated", "Status", "BodyClass", "SessionId" {
                Do $$$AssertEquals(tHeader.%Get(tField), $Select($IsObject(tSentRow): tSentRow.%Get(tField), 1: "none"), "message " _ tI _ "'s " _ tField _ " reads as it does on the operation's Messages tab")
            }
        } Else {
            Do $$$AssertTrue(0, "message " _ tI _ " is among the service's messages")
        }
    }
    Do $$$AssertEquals($Piece(..Ordered(tRows, "ID"), ",", 1, 3), $Piece(..PreparedIds, ",", 3) _ "," _ $Piece(..PreparedIds, ",", 2) _ "," _ $Piece(..PreparedIds, ",", 1), "the newest three are the probe's, newest first")
}

/// <p>Store a message header from <var>pSource</var> to <var>pTarget</var> and answer its id, 0 when it could not be
/// stored: queued in <var>pQueue</var> when that is given, else queued nowhere.</p>
ClassMethod StoreHeader(pSource As %String, pTarget As %String, pQueue As %String = "") As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%New()
        Set tHeader.SourceConfigName = pSource
        Set tHeader.TargetConfigName = pTarget
        Set tHeader.MessageBodyClassName = "Ens.Request"
        Set tHeader.Type = 1
        Set tHeader.Priority = 6
        Set tHeader.TimeCreated = $ZDateTime($ZTimeStamp, 3, , 3)
        If pQueue '= "" {
            Set tHeader.TargetQueueName = pQueue
            Set tSC = ##class(Ens.Queue).EnQueue(tHeader)
        } Else {
            Set tSC = tHeader.%Save()
        }
        If $$$ISOK(tSC) Set tId = tHeader.%Id()
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tId
}

/// <p>AC1: an item that is the source of some headers and the target of others reads them as one list, newest first: the
/// ids of both sides interleaved, a header that names the item as both its source and its target once, and at most the
/// cap's rows however many each side holds. The operation holds three target headers of the probe's; the five this test
/// stores are newer, so they are the newest five of its Messages. They are removed afterwards.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListItemMessages</method> without its <code>tCount &lt; tTop</code>
/// test, or keying them by a counter instead of the header id; or the source branch of
/// <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> without its <code>ORDER BY</code> -- each goes red.</p>
Method TestAnItemWithHeadersOnBothSidesReadsThemMergedNewestFirstOnceEachAndCapped()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tH1 = ..StoreHeader(..#OPNAME, ..#SVCNAME)
    Set tH2 = ..StoreHeader(..#SVCNAME, ..#OPNAME)
    Set tH3 = ..StoreHeader(..#OPNAME, ..#OPNAME)
    Set tH4 = ..StoreHeader(..#OPNAME, ..#SVCNAME)
    Set tH5 = ..StoreHeader(..#SVCNAME, ..#OPNAME)
    Set ..PreparedEntries = tH1 _ "," _ tH2 _ "," _ tH3 _ "," _ tH4 _ "," _ tH5
    Do $$$AssertTrue((tH1 > 0) && (tH2 > tH1) && (tH3 > tH2) && (tH4 > tH3) && (tH5 > tH4), "five headers are stored, each newer than the last: " _ ..PreparedEntries)
    Set tNewest = tH5 _ "," _ tH4 _ "," _ tH3 _ "," _ tH2 _ "," _ tH1
    Set tAll = ..Ordered(..RowsOf("ItemMessages", ..#OPNAME, , , .tHttp), "ID")
    Do $$$AssertEquals(tHttp _ "|" _ $Piece(tAll, ",", 1, 5), "200|" _ tNewest, "the operation's five newest headers are the five stored, interleaved newest first")
    Do $$$AssertEquals($Length("," _ tAll _ ",", "," _ tH3 _ ",") - 1, 1, "the header that is both its source and its target is listed once")
    For tCap = 2, 4, 5 {
        Set tRows = ..RowsOf("ItemMessages", ..#OPNAME, , tCap, .tHttp)
        Do $$$AssertEquals(tHttp _ "|" _ ..Ordered(tRows, "ID"), "200|" _ $Piece(tNewest, ",", 1, tCap), "a cap of " _ tCap _ " answers the newest " _ tCap _ " of the two sides together")
    }
    Do ..RemoveEntries(..PreparedEntries)
    Do $$$AssertEquals(..EntriesLeft(..PreparedEntries), 0, "the stored headers are removed")
    Set ..PreparedEntries = ""
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
    Quit ..StoreHeader(..#SVCNAME, pTarget, ..#ACTOR)
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

/// <p>AC1, AC2, AC3: the Log tab is newest first, its rows naming the job Jobs lists; each queue entry carries the priority
/// and index the vendor's queue lists it under; and the monitor's, the item status's, the jobs' and the queues' rows carry the
/// figures the vendor's own queries give for the same hosts (type, light, last activity, queue and message counts, retry,
/// active message), but for the elapsed time, which moves.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.InteropPort:LOGSQL</parameter> ordered by <code>ID</code> ascending -- the
/// log leg goes red; <method>OcuPilot.Port.InteropPort.QueueEntryRow</method> answering the index as the priority -- the entry
/// leg; <method>OcuPilot.Port.InteropPort.HostRow</method> answering the elapsed time as the message count -- the monitor leg.</p>
Method TestEachRowCarriesTheOrderAndFiguresTheVendorGives()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Set tMonitor = ..ProbeRows("Monitor", .tHttp)
    For tName = ..#OPNAME, ..#SVCNAME {
        Set tVendor = ..VendorRow("Ens.Util.Statistics:EnumerateHostStatus", "", 1, tName)
        Set tHost = $ClassMethod(..#READ, "RowWhere", tMonitor, "Name", tName)
        Do $$$AssertEquals($Select($IsObject(tHost): tHost.Type _ "|" _ tHost.AdapterState _ "|" _ tHost.LastActivity _ "|" _ tHost.Queue _ "|" _ tHost.Count, 1: "none"), $ListGet(tVendor, 2) _ "|" _ $ListGet(tVendor, 4) _ "|" _ ..Clock($ListGet(tVendor, 5)) _ "|" _ +$ListGet(tVendor, 7) _ "|" _ +$ListGet(tVendor, 8), tName _ ": its monitor row is the vendor's")
    }
    Set tVendor = ..VendorRow("Ens.Util.Statistics:EnumerateHostStatus", "", 1, ..#OPNAME)
    Set tStatus = ..ProbeRows("ItemStatus", .tHttp)
    Do $$$AssertEquals($Select(..SizeOf(tStatus) = 1: tStatus.%Get(0).Status _ "|" _ tStatus.%Get(0).AdapterState _ "|" _ tStatus.%Get(0).LastActivity, 1: "none"), $ListGet(tVendor, 3) _ "|" _ $ListGet(tVendor, 4) _ "|" _ ..Clock($ListGet(tVendor, 5)), "the item's status carries the monitor's light")
    Set tJob = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("Jobs", .tHttp), "Host", ..#OPNAME)
    Set tVendor = ..VendorRow("Ens.Util.Statistics:EnumerateJobStatus", ..#OPNAME, 1, ..#OPNAME)
    Do $$$AssertEquals($Select($IsObject(tJob): tJob.Job _ "|" _ tJob.Status _ "|" _ tJob.AdapterState _ "|" _ tJob.LastActivity _ "|" _ tJob.Retry _ "|" _ tJob.ActiveMessage, 1: "none"), $ListGet(tVendor, 2) _ "|" _ $ListGet(tVendor, 3) _ "|" _ $ListGet(tVendor, 4) _ "|" _ ..Clock($ListGet(tVendor, 5)) _ "|" _ +$ListGet(tVendor, 8) _ "|" _ $ListGet(tVendor, 9), "the operation's job row is the vendor's")

    Set tLog = ..ProbeRows("ItemLog", .tHttp)
    Do $$$AssertTrue(..SizeOf(tLog) > 1, "the operation's log holds its start line and its message line")
    If (..SizeOf(tLog) > 1) && $IsObject(tJob) {
        Do $$$AssertTrue(+tLog.%Get(0).ID > +tLog.%Get(1).ID, "the log is newest first")
        Do $$$AssertEquals(tLog.%Get(0).Text _ "|" _ tLog.%Get(0).Job, $Parameter(..#PROBE, "LOGTEXT") _ "|" _ tJob.Job, "its newest line is the one the operation wrote for its message, written by the job Jobs lists")
    }

    Set tEntries = ..ProbeRows("QueueItems", .tHttp)
    If '$IsObject(tEntries) Set tEntries = []
    Set (tSeen, tVendorSeen) = ""
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tAt, .tEntry) {
        Set tVendor = ..VendorRow("Ens.Queue:EnumerateItem", ..#OPNAME, 3, tEntry.MessageId)
        Set tSeen = tSeen _ tEntry.Priority _ "/" _ tEntry.Index _ " "
        Set tVendorSeen = tVendorSeen _ +$ListGet(tVendor, 1) _ "/" _ +$ListGet(tVendor, 2) _ " "
    }
    Do $$$AssertTrue(tSeen '= "", "the queue holds entries")
    Do $$$AssertEquals(tSeen, tVendorSeen, "each is listed under the priority and index the vendor's queue gives it")
    Set tQueue = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("Queues", .tHttp), "Name", ..#OPNAME)
    Set tVendor = ..VendorRow("Ens.Queue:Enumerate", "", 1, ..#OPNAME)
    Do $$$AssertEquals($Select($IsObject(tQueue): tQueue.Count _ "|" _ tQueue.Created, 1: "none"), +$ListGet(tVendor, 2) _ "|" _ ..Clock($ListGet(tVendor, 3)), "the operation's queue row is the vendor's")
}

/// <p>AC3: a queue with no entry and an item with no queue or job read no row, not a refusal: the probe's service has no
/// queue and no job, and a queue that does not exist holds nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListQueueEntries</method> answering 404 for an empty queue.</p>
Method TestAHostWithNoQueueOrJobAnswersNoRow()
{
    Do $$$AssertStatusOK(..Arm(), "the probe runs with its operation hung on one message and two waiting")
    Do $$$AssertEquals(..SizeOf(..RowsOf("ItemQueue", ..#SVCNAME, , , .tQueueHttp)) _ "|" _ tQueueHttp, "0|200", "the service's queue holds no entry")
    Do $$$AssertEquals(..SizeOf(..RowsOf("ItemJobs", ..#SVCNAME, , , .tJobHttp)) _ "|" _ tJobHttp, "0|200", "and it has no job")
    Do $$$AssertEquals(..SizeOf(..RowsOf("QueueItems", , "OcuPilotProbeNoSuchQueue", , .tEntryHttp)) _ "|" _ tEntryHttp, "0|200", "a queue that does not exist holds no entry")
}

/// <p>A read that asks the vendor for the production's state while another process holds the runtime lock, as the
/// vendor's start, stop and update hold it, answers 503 <code>PORT.UNAVAILABLE</code>, as a state read does, not a logged
/// 500. With the production stopped, a child process holds the lock until it is told to let go.</p>
/// <p>Mutation (Rule 19): drop the runtime-lock test from <method>OcuPilot.Port.InteropPort.Mapped</method> -- each leg
/// reads 500 <code>INTERNAL</code> and this goes red.</p>
Method TestABusyRuntimeLockAnswersUnavailable()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is stopped")
    Set ..PreparedIds = ""
    Set tHolder = ..HoldRuntime()
    Do $$$AssertTrue(tHolder > 0, "a child process holds the production's runtime lock")
    For tEndpoint = "Monitor", "Jobs", "ItemStatus", "ItemJobs", "ItemQueue" {
        Kill tQuery, tResult
        Set tQuery("namespace") = ..#NAMESPACE
        If $ListFind($ClassMethod(..#PORT, "ItemEndpoints"), tEndpoint) Set tQuery("item") = ..ItemOf(..#OPNAME)
        Set tHttp = 0
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Invoke", tEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "503|PORT.UNAVAILABLE", tEndpoint _ " answers that the state could not be read just now")
    }
    Do ..LetGo(tHolder)
    Do $$$AssertEquals(..SizeOf(..ProbeRows("Monitor", .tHttp)) _ "|" _ tHttp, "0|200", "once the lock is let go, the stopped production's monitor answers no row")
}

/// <p>Start <method>Holder</method> in a child process and answer its pid once it holds the runtime lock; 0 when it did
/// not signal that it does.</p>
ClassMethod HoldRuntime() As %Integer
{
    Do $System.Event.Clear($Job)
    Job ##class(OcuPilot.Test.InteropHostEdges).Holder($Job)::10
    If '$Test Quit 0
    Set tChild = $ZChild
    Set tMessage = $System.Event.WaitMsg("", 20)
    If $ListGet(tMessage, 2) = "held" Quit tChild
    Do ..LetGo(tChild)
    Quit 0
}

/// <p>The child process <method>HoldRuntime</method> starts: hold <code>^Ens.Runtime</code> in <parameter>NAMESPACE</parameter>,
/// signal <code>held</code> to process <var>pParent</var>, and let go when signalled or after a minute.</p>
ClassMethod Holder(pParent As %Integer)
{
    Set $NAMESPACE = ..#NAMESPACE
    Lock +^Ens.Runtime:5
    If '$Test {
        Do $System.Event.Signal(pParent, "busy")
        Quit
    }
    Do $System.Event.Signal(pParent, "held")
    Set tMessage = $System.Event.WaitMsg("", 60)
    Lock -^Ens.Runtime
}

/// <p>Tell the holder <var>pChild</var> to let go, and wait, ten seconds at most, until its process has ended.</p>
ClassMethod LetGo(pChild As %Integer)
{
    If pChild '> 0 Quit
    Do $System.Event.Signal(pChild, "release")
    For tTry = 1:1:40 {
        If '$Data(^$JOB(pChild)) Quit
        Hang 0.25
    }
}

/// <p>The first row of the vendor query <var>pQuery</var> (<code>Class:Query</code>, run in <code>USER</code> with
/// <var>pArg</var> unless that is empty) whose column <var>pAt</var> reads <var>pKey</var>, as a <class>%List</class> of its
/// columns; <code>""</code> when there is none.</p>
ClassMethod VendorRow(pQuery As %String, pArg As %String, pAt As %Integer, pKey As %String) As %List
{
    Set tLine = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%ResultSet).%New(pQuery)
        Set tSC = $Select(pArg = "": tResult.Execute(), 1: tResult.Execute(pArg))
        While $$$ISOK(tSC) && tResult.Next() {
            If tResult.GetData(pAt) '= pKey Continue
            For tI = 1:1:tResult.GetColumnCount() Set tLine = tLine _ $ListBuild(tResult.GetData(tI))
            Quit
        }
        Do tResult.Close()
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tLine
}

/// <p>The vendor's local <code>YYYY-MM-DD HH:MM:SS[.f]</code> <var>pLocal</var> as the port writes it, <code>YYYY-MM-DDTHH:MM:SS.fff</code>.</p>
ClassMethod Clock(pLocal As %String) As %String
{
    Quit $Select(pLocal = "": "", 1: $Translate($Extract(pLocal, 1, 19), " ", "T") _ "." _ $Extract($Piece(pLocal, ".", 2) _ "000", 1, 3))
}

/// <p>The stamps of a header (on the Messages tab of the item that sent it and of the one it was sent to), a queue entry
/// and a log row are converted from UTC to local time once: read by a process
/// whose zone is eight hours west of Greenwich, each is the stored UTC value less eight hours; read by this process, each
/// is the stored value moved by this process's own offset. The stored values are read from the columns, never through
/// <code>%EXTERNAL</code>, which converts too.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.LocalStamp</method> reformatting its argument without
/// converting -- the western legs go red; <code>%EXTERNAL</code> put back around the stamp in either branch of
/// <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> -- a Messages leg goes red, the stamp converted twice.</p>
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
    Set tHereWest = +tHere.%Get("west")
    Do $$$AssertEquals(tHere.%Get("messages") _ "|" _ tHere.%Get("sourced") _ "|" _ tHere.%Get("queue") _ "|" _ tHere.%Get("log"), ..MovedWest(tCreated, tHereWest) _ "|" _ ..MovedWest(tCreated, tHereWest) _ "|" _ ..MovedWest(tCreated, tHereWest) _ "|" _ ..MovedWest(tLogged, tHereWest), "read here, " _ tHereWest _ " minutes west, each stamp is the stored one moved by that")
    Set tThere = ..ReadInZone(..#ZONE, tHeaderId, tLogId)
    Do $$$AssertEquals(tThere.%Get("error") _ "|" _ tThere.%Get("west"), "|" _ ..#ZONEWEST, "the child ran eight hours west of Greenwich: " _ tThere.%ToJSON())
    Set tWest = +tThere.%Get("west")
    Do $$$AssertEquals(tThere.%Get("messages"), ..MovedWest(tCreated, tWest), "read eight hours west, a header's stamp is the stored one less eight hours (stored " _ tCreated _ ")")
    Do $$$AssertEquals(tThere.%Get("sourced"), ..MovedWest(tCreated, tWest), "and so it is on the Messages tab of the item that sent it (stored " _ tCreated _ ")")
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
/// <var>pLogId</var>: <code>{west, messages, sourced, queue, log}</code>, <code>west</code> the process's
/// <code>$ZTIMEZONE</code>, <code>messages</code> and <code>sourced</code> the header on the operation's and on the
/// service's Messages tab.</p>
ClassMethod StampsRead(pHeaderId As %String, pLogId As %String) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("west", +$ZTimeZone, "number")
    Set tHeader = $ClassMethod(..#READ, "RowWhere", ..ProbeRows("ItemMessages", .tHttp), "ID", pHeaderId)
    Do tOut.%Set("messages", $Select($IsObject(tHeader): tHeader.TimeCreated, 1: "none"))
    Set tSourced = $ClassMethod(..#READ, "RowWhere", ..RowsOf("ItemMessages", ..#SVCNAME, , , .tHttp), "ID", pHeaderId)
    Do tOut.%Set("sourced", $Select($IsObject(tSourced): tSourced.TimeCreated, 1: "none"))
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
