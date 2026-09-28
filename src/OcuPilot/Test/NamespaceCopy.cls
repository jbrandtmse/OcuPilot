/// <p>Pins Story 18.14's copy of mappings on both callers (AD-26, AD-51, AD-53): the Namespaces list's
/// <code>copy-mappings</code> row action (<class>OcuPilot.Test.MappingActionFixture</class>) and the
/// agent's mint and confirm (<class>OcuPilot.Test.NamespaceConfirm</class>). The copy is queued, awaited
/// by the port's one poller and its finished result read once; a copy still running at the bound is
/// applied and continues (<class>OcuPilot.Test.NamespaceStartedPort</class>); a bad source is refused
/// before any task is queued; and a copy into the install namespace from a source holding an
/// OcuPilot mapping, or one whose list is cut at its cap, is refused (AD-10).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the <code>USER</code>
/// and <code>IRISTEMP</code> databases, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes namespaces and mappings
/// (<class>OcuPilot.Test.MappingProbe</class>). Every copy writes only into a probe namespace, except
/// the install-namespace legs, which write through <class>OcuPilot.Test.MappingAcceptPort</class>
/// and send nothing. Every probe namespace is removed by exact name before all, after each and after
/// all.</p>
Class OcuPilot.Test.NamespaceCopy Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter WRITE = "OcuPilot.Test.MappingWrite";

Parameter RECORD = "OcuPilot.Test.MappingRecordPort";

Parameter ACCEPT = "OcuPilot.Test.MappingAcceptPort";

Parameter STARTED = "OcuPilot.Test.NamespaceStartedPort";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.NamespaceCopyMappings";

Parameter OWNCODE = "PROHIBITED.OCUPILOTMAPPING";

Parameter SOURCE = "OCUPROBE1814A";

Parameter DESTINATION = "OCUPROBE1814B";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceCopy creates and deletes namespaces and mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>A source holding one mapping of each kind, and a destination holding a mapping the source also
/// names, on another database, and one of its own.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Add", ..#SOURCE)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Add", ..#DESTINATION))
    For tKind = "global", "routine", "package" {
        Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "AddMapping", tKind, ..#SOURCE, "OcuProbe1814C" _ $ZConvert($Extract(tKind), "U"), "USER"))
    }
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "AddMapping", "global", ..#DESTINATION, "OcuProbe1814CG", "IRISTEMP"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "AddMapping", "global", ..#DESTINATION, "OcuProbe1814Keep", "IRISTEMP"))
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort, ^||OcuPilotMappingProhibitedClass
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#STARTED, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name, with its mappings")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.NamespaceCopy"))
    Quit tSC
}

/// <p>AD-26 as amended: the port lets the vendor queue the copy of mappings, a mutating pair it
/// composes the body of.</p>
/// <p>Mutation (Rule 19): remove <code>Namespace.Namespace/MAPPINGS</code> from
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> -> the copy is refused before it is
/// queued and this and the round trip go red.</p>
Method TestTheCopyIsAQueuedWrite()
{
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Namespace.Namespace", "MAPPINGS"), "the copy is a mutating pair")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsQueuedWrite("Namespace.Namespace", "MAPPINGS"), "which the port lets the vendor queue")
    Kill tQuery
    Set tQuery("name") = ..#DESTINATION
    Set tQuery("SourceNamespace") = $ZConvert(..#SOURCE, "L")
    Set tSteps = ##class(OcuPilot.Port.NamespacePort).Snippet("Namespace.Namespace", "MAPPINGS", .tQuery, "", {"origin": "https://example", "user": "u"})
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 1) && (tSteps.%Get(0).text [ "/namespace/copy-mappings") && (tSteps.%Get(0).text [ "{""SourceNamespace"":""OCUPROBE1814A"",""DestinationNamespace"":""OCUPROBE1814B""}"), "its script is the vendor's route with the port-built body, both namespaces upper-cased (AD-59)")
}

/// <p>The copy on both callers: each answers once the vendor's task has finished, its task row read
/// once and gone; the destination then holds the source's three mappings, the same-named one replaced
/// and its own kept. The agent's proposal is destructive with the copy's consequence.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.NamespacePort.CopyBody</method> swaps source and
/// destination -> the probe source is overwritten instead and this goes red.</p>
Method TestACopyRoundTripsOnBothCallers()
{
    Set tTasks = ..TaskCount()
    Do $$$AssertTrue(tTasks >= 0, "the async task list is readable, so the task counts below compare something")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", ..Body(..#DESTINATION, ..#SOURCE), .tAnswer, .tStatus)
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
    Do $$$AssertEquals(tStatus, 200, "the screen's copy answers 200: " _ tAnswer)
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ tBody.%Get("target").%Get("id") _ " " _ tBody.%GetTypeOf("continues"), 1: ""), "updated namespace " _ $ZConvert(..#DESTINATION, "L") _ " unassigned", "publishing updated on the destination, finished rather than continuing")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastQueryKeys") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "MAPPINGS SourceNamespace,name ", "the port was handed the source and the destination and no caller body")
    Do $$$AssertEquals(..TaskCount(), tTasks, "the finished task's row was read once and removed, so nothing reads it again")
    Do ..AssertCopied(..#DESTINATION)

    Set tAgent = "OCUPROBE1814D"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tAgent), "a second destination is created for the agent")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tAgent), "SourceNamespace": (..#SOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's copy is minted " _ tProblem)
    If '$IsObject(tProposal) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.changed.%Get(0).field _ " " _ tProposal.changed.%Get(0).after, "1 SourceNamespace " _ ..#SOURCE, "its card's one row names the source")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Marked", tProposal), "1|NAMESPACE.COPYMAPPINGS", "destructive, carrying the copy's consequence")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "200 ", "and it is confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType"), "MAPPINGS", "through the queued copy")
    Do $$$AssertEquals(..TaskCount(), tTasks, "its finished task read once and removed too")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", tAgent) _ "|" _ $ClassMethod(..#PROBE, "Names", "routine", tAgent) _ "|" _ $ClassMethod(..#PROBE, "Names", "package", tAgent), "OcuProbe1814CG|OcuProbe1814CR|OcuProbe1814CP", "and the destination holds the source's mappings")
}

/// <p>A bad source is refused before any task is queued, on both callers: an absent one with the
/// namespace-absent reason, and the destination itself, in another case, with
/// <code>NAMESPACE.SOURCE.SAME</code>'s, each compared with the published sentence itself.</p>
/// <p>Mutation (Rule 19): drop the <code>NAMESPACE.SOURCE.SAME</code> arm of
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -> the refusal names no reason, and this
/// goes red.</p>
Method TestABadSourceIsRefusedBeforeAnyTaskIsQueued()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tCase = $ListBuild("OCUPROBE1814NONE", ##class(OcuPilot.Api.Error).#NAMESPACESOURCEABSENT, ##class(OcuPilot.Api.Error).#REASONNAMESPACENAMEABSENT), $ListBuild($ZConvert(..#DESTINATION, "L"), ##class(OcuPilot.Api.Error).#NAMESPACESOURCESAME, ##class(OcuPilot.Api.Error).#REASONNAMESPACESOURCESAME) {
        Set tSource = $List(tCase, 1)
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 2)), $List(tCase, 3), $List(tCase, 2) _ ": carries its published sentence")
        Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", ..Body(..#DESTINATION, tSource), .tAnswer, .tStatus)
        Set tProblem = ""
        Try { Set tProblem = ##class(%DynamicObject).%FromJSON(tAnswer).detail.problem } Catch {}
        Do $$$AssertEquals(tStatus, 400, tSource _ ": the screen's copy is refused 400")
        Do $$$AssertTrue(tProblem [ $List(tCase, 3), tSource _ ": naming the reason: " _ tProblem)
        Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (..#DESTINATION), "SourceNamespace": (tSource)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tHttp = 400) && (tProblem [ $List(tCase, 3)), tSource _ ": the agent's copy is refused at the mint: " _ tProblem)
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "no copy was queued")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#DESTINATION), "OcuProbe1814CG,OcuProbe1814Keep", "and the destination is unchanged")
}

/// <p>Copy into the install namespace (AD-10): from a source holding an <code>OcuPilot</code> mapping
/// the copy is refused <code>PROHIBITED.OCUPILOTMAPPING</code> on both callers, and from a source
/// holding none it is permitted; every write goes to <class>OcuPilot.Test.MappingAcceptPort</class>,
/// which sends none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.CopiesOwnMapping</method>
/// answers false -> each refused leg is an accepted copy and this goes red.</p>
Method TestACopyIntoTheInstallNamespaceOfAnOcuPilotMappingIsRefused()
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#SOURCE, "OcuPilotProbe1814", "USER"), "the source is seeded with an OcuPilot mapping")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", ..Body(tOwnNs, ..#SOURCE), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer), "403 " _ ..#OWNCODE, "the screen's copy is refused")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tOwnNs), "SourceNamespace": (..#SOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's copy is minted " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no copy reached the port")
    Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", ..Body(tOwnNs, ..#DESTINATION), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "200 MAPPINGS", "a source with no OcuPilot mapping is permitted, and the copy reaches the port")
}

/// <p>A source list cut at its cap fails closed (AD-10): read through
/// <class>OcuPilot.Test.MappingProhibitedFixture</class>, whose cap is one row, a source holding two
/// ordinary global mappings is refused on both callers when the destination is the install
/// namespace.</p>
/// <p>Mutation (Rule 19): drop the <code>truncated</code> test from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.CopiesOwnMapping</method> -> the cut list is read as
/// checked, the copy is accepted and this goes red.</p>
Method TestACutSourceListIsRefused()
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#SOURCE, "OcuProbe1814C2", "USER"), "the source holds two global mappings")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    Set ^||OcuPilotMappingProhibitedClass = "OcuPilot.Test.MappingProhibitedFixture"
    Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", ..Body(tOwnNs, ..#SOURCE), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer), "403 " _ ..#OWNCODE, "the screen's copy is refused")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.MappingProhibitedFixture")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tOwnNs), "SourceNamespace": (..#SOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's copy is minted " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no copy reached the port")
}

/// <p>AD-26 on the agent's caller: a copy still running at the bound is answered 200
/// <code>confirmed</code> with <code>continues</code>, is not read back, and the vendor's worker then
/// finishes it.</p>
/// <p>Mutation (Rule 19): remove the started branch from
/// <method>OcuPilot.Port.NamespacePort.Invoke</method> -> the confirm answers 503
/// <code>PORT.TIMEOUT</code> and this goes red.</p>
Method TestAnAgentCopyStillRunningAtTheBoundIsApplied()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": (..#DESTINATION), "SourceNamespace": (..#SOURCE)}, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the copy is minted through the tool's own view")
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Test.NamespaceStartedConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ $Get(tCode))
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tResult)): tResult.%Get("state") _ " " _ tResult.%Get("continues"), 1: ""), "200 confirmed 1", "answered confirmed, continuing on the instance")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && (tResult.%GetTypeOf("readBack") = "object"): tResult.%Get("readBack").%Get("verdict") _ "/" _ tResult.%Get("readBack").%Get("reason"), 1: ""), "unchecked/running", "a copy still running is not read back (AD-58)")
    Do ..AssertTheWorkerFinishes(..#DESTINATION)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>AD-26, AD-53 on the screen's caller: a copy still running at the bound is answered
/// <code>updated</code> on the destination with <code>continues: true</code>, and the vendor's worker
/// then finishes it.</p>
Method TestTheScreenRouteAnswersThatACopyStillRunningContinues()
{
    Set tSC = ##class(OcuPilot.Test.NamespaceStartedAction).Copy(..#DESTINATION, ..#SOURCE, .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the screen route runs")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch { Set tBody = "" }
    Do $$$AssertEquals(tStatus, 200, "answered 200: " _ $Get(tAnswer))
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ tBody.%Get("continues") _ " " _ tBody.%GetTypeOf("continues"), 1: ""), "updated namespace 1 boolean", "publishing updated, continuing on the instance, as JSON true")
    Do ..AssertTheWorkerFinishes(..#DESTINATION)
}

/// <p>The copy the vendor's worker was still running at the bound finishes, read once, and
/// <var>pDestination</var> then holds the source's mappings.</p>
Method AssertTheWorkerFinishes(pDestination As %String)
{
    Set tGuid = $ClassMethod(..#STARTED, "LastTask")
    Do $$$AssertNotEquals(tGuid, "", "the port polled a queued task")
    Do $$$AssertEquals($ClassMethod(..#STARTED, "Settle", tGuid), "Finished", "the vendor's worker finishes the copy after the port stopped waiting")
    Do ..AssertCopied(pDestination)
}

/// <p>The destination <var>pDestination</var> holds the source's three mappings, its same-named
/// global mapping replaced by the source's, and its own other mapping kept.</p>
Method AssertCopied(pDestination As %String)
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", pDestination), "OcuProbe1814CG,OcuProbe1814Keep", pDestination _ ": holds the source's global mapping and keeps its own")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "routine", pDestination) _ "|" _ $ClassMethod(..#PROBE, "Names", "package", pDestination), "OcuProbe1814CR|OcuProbe1814CP", pDestination _ ": and the source's routine and package mappings")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", pDestination, "OcuProbe1814CG", "Database") _ " " _ $ClassMethod(..#PROBE, "Stored", "global", pDestination, "OcuProbe1814Keep", "Database"), "USER IRISTEMP", pDestination _ ": the same-named mapping is replaced and the other is kept")
}

/// <p>The screen action body copying <var>pSource</var>'s mappings into <var>pDestination</var>.</p>
ClassMethod Body(pDestination As %String, pSource As %String) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set("action", "copy-mappings", "string")
    Do tBody.%Set("id", pDestination, "string")
    Set tValues = {}
    Do tValues.%Set("SourceNamespace", pSource, "string")
    Do tBody.%Set("values", tValues)
    Quit tBody
}

/// <p>The code of the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %String) As %String
{
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(pAnswer).%Get("code") } Catch {}
    Quit tCode
}

/// <p>How many async task rows this user owns, read through the port's own
/// <code>AsyncResult</code> list. <code>-1</code> when the list cannot be read.</p>
ClassMethod TaskCount() As %Integer
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("AsyncResult", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit -1
    Quit tRows.%Size()
}

}
