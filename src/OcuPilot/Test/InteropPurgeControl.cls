/// <p>Pins Story 24.16's purge of management data end to end against back-dated probe records in <code>USER</code> (AD-6, AD-7, AD-14, AD-15, AD-22,
/// AD-51, AD-53, AD-58, AD-59, AD-62): a person's Purge and the agent's confirmed proposal each remove, through the vendor's <code>Ens.Purge.PurgeAll</code>,
/// the probe headers, bodies, event log, I/O log and closed managed alert records dated years before the cut-off and keep the one made now, and the counts read the
/// change. The settings hold: a session with a message still queued is kept whole while Purge only completed sessions is on, and a body is kept while Include
/// message bodies is off and deleted once it is on. The vendor audits no purge, so OcuPilot's own <code>ConfigChange</code> is the record, naming the namespace, the
/// days, the three settings and the count deleted of each kind, never the description. A setting changed after the mint closes the agent's proposal target-changed, and
/// the script form renders the locked <code>PurgeAll</code> and runs nothing.</p>
/// <p>Every probe is back-dated 7,300 days and every purge keeps 3,650, so nothing but a probe is old enough to go. <b>What it needs from the environment:</b>
/// interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>. It removes every probe record and puts both namespaces' setting nodes back exactly as it found them.</p>
Class OcuPilot.Test.InteropPurgeControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropPurgeFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SCREEN = "/screens/interop.purge";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropPurgeRun";

/// <p>What both namespaces' setting nodes held when the class started.</p>
Property PreparedSettings As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSettings = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPurgeControl deletes probe records and writes the purge settings of USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedSettings = $ClassMethod(..#FIXTURE, "SaveSettings")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    If ..PreparedSettings = "" Quit $$$OK
    Quit $ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    For tNamespace = "USER", "HSCUSTOM" {
        For tNode = "BodiesToo", "KeepIntegrity", "NamespaceBitmapMaint", "Desc" {
            Do $ClassMethod(..#FIXTURE, "PutSetting", tNamespace, tNode, "<absent>")
        }
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe records are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings), "both namespaces' setting nodes are put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveSettings"), ..PreparedSettings, "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Arrange in USER, back-dated: one Completed header with a body, one event log row, one I/O log row and a closed and an open managed alert; and one Completed header
/// with a body made now.</p>
ClassMethod Arrange(pNamespace As %String = "USER") As %Boolean
{
    Set tOk = ''$ClassMethod(..#FIXTURE, "Header", pNamespace, $Parameter(..#FIXTURE, "COMPLETED"), $Parameter(..#FIXTURE, "OLDDAYS"), 1, "", "Old")
    Set tOk = tOk && $ClassMethod(..#FIXTURE, "Others", pNamespace, $Parameter(..#FIXTURE, "OLDDAYS"))
    Set tOk = tOk && ''$ClassMethod(..#FIXTURE, "Header", pNamespace, $Parameter(..#FIXTURE, "COMPLETED"), 0, 1, "", "Cur")
    Quit tOk
}

/// <p>The port's purge of USER for <var>pDays</var> as <code>status code</code>.</p>
ClassMethod Purge(pDays As %String = {$Parameter("OcuPilot.Test.InteropPurgeFixture", "KEEPDAYS")}, pNamespace As %String = "USER") As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pNamespace
    Set tQuery("days") = pDays
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Purge", "PURGE", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>One person's Purge on the Purge management data screen as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pDays As %String, Output pAnswer) As %String
{
    Set tValues = {}
    Do tValues.%Set("DaysToKeep", pDays, "string")
    Set tBody = {"action": "purge", "id": "USER"}
    Do tBody.%Set("values", tValues)
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint the agent's purge of USER for <var>pDays</var>, with the proposal in <var>pProposal</var>, its turn in <var>pTurn</var> and the code of its refusal, or <code>minted</code>.</p>
ClassMethod Mint(pDays As %String, Output pProposal, Output pTurn, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tArgs = {"Name": "USER"}
    Do tArgs.%Set("DaysToKeep", pDays, "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    If $IsObject($Get(pProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that carry a purge's <code>daysToKeep</code>, with the last row's data in <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", "daysToKeep", .pData)
}

/// <p>How many rows of the vendor's own audit since <var>pSince</var> carry <var>pWords</var>: a purge writes none (measured).</p>
ClassMethod VendorRows(pSince As %String, pWords As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData, Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble'", pSince)
        While tRS.%Next() {
            If (tRS.%Get("EventData") [ pWords) || (tRS.%Get("Description") [ pWords) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Turn on the governance key of the purge, which ships off, for the rest of the test; <var>pPolicy</var> is what to hand back to <method>RestoreGovernance</method>.</p>
ClassMethod EnableKey(Output pPolicy) As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.pPolicy)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    Set tSettings("interop.purge.run") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 16 with Purge as its one (row) action, over
/// <code>%Ens_Purge:USE</code>, naming the entity type <code>interop-purge</code> and the classic page it replaces.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 17 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropPurgeList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/purge|16|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.toolIdentifier, "interop-purge|namespace|interop.purge", "its entity type, its scope and its tool identifier")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.rowActions.%Get(0).id, "|1|purge", "its one action is the row action Purge, which the action route admits")
    Do $$$AssertEquals(tDeclaration.classicPage, "EnsPortal.PurgeAll", "its classic page")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Purge"",""permission"":""USE""}]", "its pairs are the classic page's")
}

/// <p>AC2: the counts list answers the six records of the classic page, in its order, each with the vendor's own name, the count the vendor reads and the namespace,
/// and reads nothing it writes.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListPurgeCounts</method> answer the six types in another order -- this goes red.</p>
Method TestTheCountsReadTheSixRecordsOfTheClassicPageInItsOrder()
{
    Do $$$AssertTrue(..Arrange(), "the probe records are arranged")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Purge", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list answers 200")
    Set tTypes = ""
    Set tAgree = 1
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tTypes = tTypes _ $Select(tTypes = "": "", 1: ",") _ tRow.Type
            If (tRow.Count '= $ClassMethod(..#FIXTURE, "VendorCount", "USER", tRow.Type)) || (tRow.Namespace '= "USER") Set tAgree = 0
        }
    }
    Do $$$AssertEquals(tTypes, "Event Log,Messages,Business Processes,Business Rule Log,I/O Log,Managed Alerts", "the six types, in the classic order")
    Do $$$AssertTrue(tAgree, "each count is the vendor's own, and each row names the namespace")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "VendorCount", "USER", "Messages") >= 2, "the probe headers are counted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1", "and reading them deleted nothing")
}

/// <p>AC2: a person's Purge and the agent's confirmed proposal each delete the back-dated probe records and keep the one made now, and the counts read the change. The
/// closed managed alert goes and the open one stays, as Purge only completed sessions says. Each records one <code>ConfigChange</code> naming the namespace, the days,
/// the three settings and the count deleted of each kind, and no description; the vendor records none. The agent's card is destructive, states the purge's
/// consequence and ships behind a key that is off; its confirm is marked and ledgered once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPurge</method> pass <code>0</code> days to the vendor -- the kept-current-row leg goes red;
/// make it pass <code>0</code> for Include message bodies whatever is stored -- the agent's body leg goes red.</p>
Method TestAPurgeFromEitherCallerDeletesTheOldRecordsAndKeepsTheCurrentOne()
{
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "1")
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "Desc", "OcuProbe2416 description")
    Do $$$AssertTrue(..Arrange(), "the probe records are arranged")
    Set tMessages = $ClassMethod(..#FIXTURE, "VendorCount", "USER", "Messages")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act(3650, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Purge answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "updated|interop-purge", "publishing the updated event for the purge")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=1 body=1 log=0 io=0 alertClosed=0 alertOpen=1", "the old records are gone, the one made now stays, and so does an open managed alert")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "VendorCount", "USER", "Messages"), tMessages - 1, "the vendor's own count of messages fell by the one deleted")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "USER") && (tData [ """daysToKeep"":3650") && (tData [ """bodiesToo"":true") && (tData [ """keepIntegrity"":true") && (tData [ """bitmapMaint"":false") && (tData [ """messages"":1") && (tData [ """completed"":true"), "naming the namespace, the days, the three settings, the messages deleted and that the purge completed: " _ tData)
    Do $$$AssertTrue(tData '[ "OcuProbe2416 description", "and never the description: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, "EnsPurge"), 0, "and the vendor records none")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do $$$AssertTrue(..Arrange(), "the probe records are arranged again, from nothing, for the agent's purge")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purge's governance key is turned on")
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..Mint(3650, .tProposal, .tTurn, .tReason), "minted", "the agent's purge mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-purge|USER|USER", "the target is the namespace")
        Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""DaysToKeep"",""before"":"""",""after"":""3650""}]", "its card shows the days it will keep")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.PURGE.RUN|1", "its consequence says what a purge deletes, and it is destructive")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1", "nothing is deleted by the mint")
        Set tStatus = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tConfirmStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action, 1: ""), "1|updated", "marked (AD-15)")
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.purge.run"), 1, "the confirmed write is in the ledger once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=1 body=1 log=0 io=0 alertClosed=0 alertOpen=1", "the old records are gone and the one made now stays")
        Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange for the agent's purge")
        Do $$$AssertTrue(tData '[ "OcuProbe2416 description", "never the description: " _ tData)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: with Purge only completed sessions on, an old session that holds a message still queued is kept whole, and with it off the whole session is deleted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPurge</method> pass <code>0</code> for the stored Purge only completed sessions -- the first leg goes
/// red.</p>
Method TestAnOldSessionWithAQueuedMessageIsKeptWholeWhileIntegrityIsOn()
{
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "KeepIntegrity", "1")
    Set tSession = $ClassMethod(..#FIXTURE, "Header", "USER", $Parameter(..#FIXTURE, "COMPLETED"), $Parameter(..#FIXTURE, "OLDDAYS"), 0, "", "SessA")
    Do $$$AssertTrue(tSession > 0, "a back-dated Completed header opens a session")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Header", "USER", $Parameter(..#FIXTURE, "QUEUED"), $Parameter(..#FIXTURE, "OLDDAYS"), 0, tSession, "SessB") > 0, "and a back-dated Queued header joins it")
    Do $$$AssertEquals(..Purge(), "200 ", "the purge runs")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Count", "USER", "header"), 2, "the whole session is kept")
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "KeepIntegrity", "0")
    Do $$$AssertEquals(..Purge(), "200 ", "with the setting off the purge runs again")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Count", "USER", "header"), 0, "and the whole session is deleted")
}

/// <p>AC2: with Include message bodies off a back-dated body is kept, and once it is on the body is deleted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPurge</method> pass <code>0</code> for the stored Include message bodies -- the second leg goes red.</p>
Method TestABodyIsKeptWhileIncludeMessageBodiesIsOffAndDeletedWhenItIsOn()
{
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "0")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Header", "USER", $Parameter(..#FIXTURE, "COMPLETED"), $Parameter(..#FIXTURE, "OLDDAYS"), 1, "", "Bod") > 0, "a back-dated header with a body is arranged")
    Do $$$AssertEquals(..Purge(), "200 ", "the purge runs with the setting off")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=0 body=1 log=0 io=0 alertClosed=0 alertOpen=0", "the header is deleted and the body is kept")
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "1")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Header", "USER", $Parameter(..#FIXTURE, "COMPLETED"), $Parameter(..#FIXTURE, "OLDDAYS"), 1, "", "Bod2") > 0, "a second back-dated header with a body is arranged")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=1 body=2 log=0 io=0 alertClosed=0 alertOpen=0", "and the first body is still there beside it")
    Do $$$AssertEquals(..Purge(), "200 ", "the purge runs with the setting on")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=0 body=1 log=0 io=0 alertClosed=0 alertOpen=0", "the header and its body are deleted, and the first body, whose header went earlier, stays")
}

/// <p>AC2, AC3: a setting changed after the agent's purge was minted closes the confirm target-changed, and nothing is deleted.</p>
/// <p>Mutation (Rule 19): drop <code>BodiesToo</code> from <parameter>OcuPilot.Screen.Tool.InteropPurgeRun.FINGERPRINTSUBJECT</parameter> -- this goes red.</p>
Method TestASettingChangedAfterTheMintClosesTheConfirmTargetChanged()
{
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "0")
    Do $$$AssertTrue(..Arrange(), "the probe records are arranged")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purge's governance key is turned on")
    Try {
        Do $$$AssertEquals(..Mint(3650, .tProposal, .tTurn, .tReason), "minted", "the agent's purge mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "BodiesToo", "1")
        Set tStatus = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tConfirmStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1", "and nothing was deleted")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: with Run bitmap cleanup for namespace stored on, the agent's card states the consequence that adds the cleanup's reach.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropPurgeRun.Consequence</method> answer the plain code for every payload -- this goes red.</p>
Method TestTheBitmapSettingChangesTheConsequenceTheCardStates()
{
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purge's governance key is turned on")
    Try {
        Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "NamespaceBitmapMaint", "1")
        Do $$$AssertEquals(..Mint(3650, .tProposal, .tTurn, .tReason), "minted", "the agent's purge mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "INTEROP.PURGE.BITMAP", "the consequence names the bitmap cleanup")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: the script form of the purge names the namespace, takes the classic page's lock at once and calls <code>Ens.Purge.PurgeAll</code> while it is held, with the days
/// the draft carries; days the port would refuse render no script. A draft deletes nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeSnippet</method> drop the lock line -- this goes red.</p>
Method TestTheScriptFormRendersTheLockedPurgeAndRunsNothing()
{
    Do $$$AssertTrue(..Arrange(), "the probe records are arranged")
    Kill tScript
    Set tScript("namespace") = "USER"
    Set tScript("id") = "USER"
    Set tScript("days") = "3650"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Purge", "PURGE", .tScript, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step is rendered")
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""USER""", "it names the namespace: " _ tText)
    Do $$$AssertTrue(tText [ "Lock +^IRIS.Temp.EnsPurgeAll($Namespace, ""lock""):0", "it takes the classic page's lock at once: " _ tText)
    Do $$$AssertTrue(tText [ "##class(Ens.Purge).PurgeAll(.tDeleted, 3650, tKeep, tBodies, , .tOptions)", "and calls the vendor's purge with the days: " _ tText)
    Set tScript("days") = "99999"
    Set tPast = $ClassMethod(..#PORT, "Snippet", "Purge", "PURGE", .tScript, "")
    Set tText = $Select(tPast.%Size() = 1: tPast.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "##class(Ens.Purge).PurgeAll(.tDeleted, +$Horolog - 2, tKeep, tBodies, , .tOptions)", "days past the instance's calendar are the calendar's own count, as the port passes them: " _ tText)
    For tDays = "-1", "1.5", "100000", "x", "" {
        Set tScript("days") = tDays
        Set tNone = $ClassMethod(..#PORT, "Snippet", "Purge", "PURGE", .tScript, "")
        Do $$$AssertEquals(tNone.%Size(), 0, "days '" _ tDays _ "' render no script")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1", "no draft deleted a record")
}

}
