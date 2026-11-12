/// <p>Pins Story 20.34's build and synchronize end to end over HTTP against the analytics probe in <code>USER</code> (AD-6, AD-14, AD-15,
/// AD-22, AD-34, AD-51, AD-53, AD-58, AD-65), for both callers of the one operation. The person's Build of Categories, from the Cube
/// manager's route, rebuilds it and its dependent Visits (5 and 1,000 facts), moves both cubes' last build, answers the output lines the
/// screen shows, publishes the <code>updated</code> event for the cube with a read-back that sent nothing, and leaves one
/// <code>ConfigChange</code> row and no agent marker; the Cubes list then answers the new last build and facts. The agent's Build, minted
/// and confirmed with its governance key on, shows a destructive card that names Visits among the dependent cubes before the confirm, and
/// leaves one <code>ConfigChange</code> row and the marker. The key ships off, so the agent's call is denied while the person's Build
/// runs; a build confirmed after another build is closed as moved. A synchronize applies exactly the ten changed Visit rows, keeps the
/// facts and the last build, and leaves a row each time and the marker for the agent only.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics
/// on in <code>USER</code> and builds and kills cubes there through <class>OcuPilot.Test.AnalyticsProbe</class>, which removes everything
/// after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsCubeActions Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter MANAGER = "OcuPilot.Test.AnalyticsCubeManager";

Parameter NAMESPACE = "USER";

Parameter BUILDTOOL = "OcuPilot.Screen.Tool.AnalyticsCubeBuild";

Parameter SYNCHRONIZETOOL = "OcuPilot.Screen.Tool.AnalyticsCubeSynchronize";

Parameter CATEGORIES = "OcuPilotProbeCategories";

Parameter VISITS = "OcuPilotProbeVisits";

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeActions turns analytics on in USER and builds and kills cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ##class(OcuPilot.Test.Http).GetTestUsername())
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeActions left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

/// <p>The governance policy is put back, the proposals removed and the cubes rebuilt, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#MANAGER, "Rebuild"), "the probe cubes are built as they were created")
    Quit $$$OK
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>Kill the facts of the vendor's cube <var>pCube</var> in <code>USER</code>, so that a build is seen to rebuild them.</p>
ClassMethod Empty(pCube As %String)
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Do ##class(%DeepSee.Utils).%KillCube(pCube, 0)
    Set $NAMESPACE = tOrigNS
}

/// <p>The last build of <var>pCube</var> to the millisecond, as the state read answers it.</p>
ClassMethod Stamp(pCube As %String) As %String
{
    Set tAsk = $ClassMethod(..#MANAGER, "Ask", "STATE", pCube, .tRow, .tFault)
    Quit $Select($IsObject(tRow): tRow.BuildStamp, 1: "unread")
}

/// <p>The person's row action <var>pAction</var> on the cube <var>pName</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pName As %String, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pName, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/screens/analytics.cubemanager/action", tBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The agent's mint of <var>pTool</var> for the cube <var>pName</var> as the HTTP account: the proposal in <var>pProposal</var> and the
/// turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pName As %String, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, {"Name": (pName)}, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>The text of a card's row <var>pField</var> as <code>before&gt;after</code>, or <code>""</code>.</p>
ClassMethod CardRow(pProposal, pField As %String) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tIterator = pProposal.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.field = pField Quit
    }
    Quit $Select($IsObject($Get(tRow)) && (tRow.field = pField): tRow.before _ ">" _ tRow.after, 1: "")
}

/// <p>The facts of a cube in <code>USER</code> after the update: Categories and Visits.</p>
ClassMethod Both() As %String
{
    Quit $ClassMethod(..#MANAGER, "Facts", ..#CATEGORIES) _ "|" _ $ClassMethod(..#MANAGER, "Facts", ..#VISITS)
}

/// <p>AC1, AC7: the person's Build of Categories, with its dependent Visits killed first, rebuilds both (5 and 1,000 facts), moves both
/// last-build stamps, answers the two output lines and no error, publishes <code>updated</code> for the cube with a read-back that sent
/// nothing, and leaves one audit row naming the build and the cube and no agent marker. The Cubes list then answers the new last build and
/// facts of the cube the manager built.</p>
/// <p>Mutation (Rule 19): answer OK in <method>OcuPilot.Port.AnalyticsPort.VendorBuild</method> without calling the vendor -- the facts, the
/// stamps and the lines go red, and so does the Cubes list; drop <code>AuditWrite</code> from <method>OcuPilot.Port.AnalyticsPort.PerformCube</method> -- the
/// audit leg goes red.</p>
Method TestThePersonsBuildRebuildsTheCubeAndItsDependent()
{
    Do ..Empty(..#VISITS)
    Do $$$AssertEquals(..Both(), "5|0", "Visits' facts are killed")
    Set tCategoriesStamp = ..Stamp(..#CATEGORIES)
    Set tVisitsStamp = ..Stamp(..#VISITS)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act("build", ..#CATEGORIES, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the Build answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "updated|cube|USER|" _ ..#CATEGORIES _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "publishing the updated event for the cube, and the read-back sent nothing")
    Do $$$AssertEquals(tAnswer.output.lines.%ToJSON() _ "|" _ tAnswer.output.errors, "[""Facts in OcuPilotProbeCategories: 5"",""Facts in OcuPilotProbeVisits: 1000""]|0", "the screen is answered the two facts lines, and no error")
    Do $$$AssertEquals(..Both(), "5|1000", "Categories and its dependent Visits are rebuilt")
    Do $$$AssertTrue((..Stamp(..#CATEGORIES) '= tCategoriesStamp) && (..Stamp(..#VISITS) '= tVisitsStamp), "and both last builds moved")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "cube", ..#CATEGORIES, "build", .tData), 1, "one audit row names the build of the cube")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ ..#VISITS), "naming the namespace and the cubes updated: " _ tData)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#CATEGORIES, .tMarker), 0, "and no agent marker is emitted for a person's action")
    Set tStatus = $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.cubes/read", "", .tHttp, .tCubes)
    Do $$$AssertEquals(tHttp, 200, "the Cubes list reads")
    If $IsObject(tCubes) && $IsObject(tCubes.%Get("rows")) {
        Set tRow = $ClassMethod(..#MANAGER, "RowOf", tCubes.rows, ..#CATEGORIES)
        Set tVisitsRow = $ClassMethod(..#MANAGER, "RowOf", tCubes.rows, ..#VISITS)
        Do $$$AssertTrue($IsObject(tRow) && $IsObject(tVisitsRow), "it holds both cubes")
        If $IsObject(tRow) && $IsObject(tVisitsRow) {
            Set tAsk = $ClassMethod(..#MANAGER, "Ask", "STATE", ..#CATEGORIES, .tState, .tFault)
            Do $$$AssertEquals(tRow.Facts _ "|" _ tVisitsRow.Facts _ "|" _ tRow.LastBuild, "5|1000|" _ tState.LastBuild, "and answers the new facts and the new last build")
        }
    }
}

/// <p>AC1, AC5: the agent's Build of Categories, minted and confirmed over HTTP with its key on: the card is destructive with the consequence
/// code, shows its last build moving to <code>Rebuilt now</code> and names Visits under Dependent cubes before the confirm; the confirm
/// rebuilds both cubes, answers one envelope with the lines for the screen, and leaves one audit row and the agent marker.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.AnalyticsCubeBuild.DESTRUCTIVE</parameter> to 0 -- the destructive leg goes red; drop
/// the Dependent cubes row from <method>OcuPilot.Screen.Tool.AnalyticsAction.StateDiff</method> -- the card leg goes red.</p>
Method TestTheAgentsBuildIsADestructiveCardNamingItsDependentsBeforeItConfirms()
{
    Do ..EnableKey("analytics.cubemanager.build")
    Do ..Empty(..#VISITS)
    Do ..Mint(..#BUILDTOOL, ..#CATEGORIES, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.CUBE.BUILD|1", "the card carries the build's consequence code and is destructive")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "cube|USER|" _ ..#CATEGORIES, "the target is the cube, by its logical name")
    Do $$$AssertEquals(..CardRow(tProposal, "Dependent cubes"), ..#VISITS _ ">" _ ..#VISITS, "its rows name Visits among the dependent cubes")
    Do $$$AssertEquals($Piece(..CardRow(tProposal, "Last build"), ">", 2), "Rebuilt now", "and the last build moving to Rebuilt now")
    Do $$$AssertEquals(..Both(), "5|0", "nothing was built by the mint")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "exactly one envelope")
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "updated, marked (AD-15), and the read-back sent nothing")
        Do $$$AssertEquals(tAnswer.output.lines.%ToJSON(), "[""Facts in OcuPilotProbeCategories: 5"",""Facts in OcuPilotProbeVisits: 1000""]", "the screen is answered the lines")
    }
    Do $$$AssertEquals(..Both(), "5|1000", "both cubes are rebuilt")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "cube", ..#CATEGORIES, "build", .tData), 1, "one ConfigChange row names the build")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#CATEGORIES, .tMarker), 1, "and the agent marker names the cube once")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, $Parameter(..#BUILDTOOL, "TOOLNAME")), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5: the baseline ships the build key off and the synchronize key on, so the governance gate denies the agent's Build with its
/// structured refusal and allows its Synchronize, while the person's Build still runs (a person's action is not governed).</p>
/// <p>Mutation (Rule 19): flip the build line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the denial leg goes red.</p>
Method TestTheBuildKeyShipsOffForTheAgentAndAPersonsBuildStillRuns()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tStored), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tStored), "and leaves every key to the baseline")
    For tCase = $ListBuild("analytics.cubemanager.build", 0), $ListBuild("analytics.cubemanager.synchronize", 1) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
    Do $$$AssertEquals(..Act("build", ..#CATEGORIES, .tAnswer), 200, "the person's Build still builds")
}

/// <p>AC2: after ten Visit rows changed, the person's Synchronize on Visits applies exactly those ten (<code>Facts updated in
/// OcuPilotProbeVisits: 10</code>), keeps the 1,000 facts and the last build, and leaves one audit row and no agent marker; the agent's
/// Synchronize, minted and confirmed with the baseline's key on, applies seven more, shows a card that is not destructive, and leaves a row
/// and the marker.</p>
/// <p>Mutation (Rule 19): call <code>%BuildCube</code> from <method>OcuPilot.Port.AnalyticsPort.VendorSynchronize</method> -- the last build moves and
/// the count reads 1,000, so this goes red.</p>
Method TestASynchronizeAppliesExactlyTheChangesForBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ChangeVisits", 10), "ten Visit rows are changed")
    Set tStamp = ..Stamp(..#VISITS)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act("synchronize", ..#VISITS, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the Synchronize answers 200 with no dialog: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.output.lines.%ToJSON(), "[""Facts updated in OcuPilotProbeVisits: 10""]", "the screen is answered the ten changes")
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Facts", ..#VISITS) _ "|" _ (..Stamp(..#VISITS) = tStamp), "1000|1", "Visits keeps its facts and its last build")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "cube", ..#VISITS, "synchronize", .tData), 1, "one audit row names the synchronize")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#VISITS, .tMarker), 0, "and no agent marker is emitted for a person's action")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ChangeVisits", 7), "seven more rows are changed")
    Do ..Mint(..#SYNCHRONIZETOOL, ..#VISITS, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.CUBE.SYNCHRONIZE|0", "the agent's card carries the synchronize consequence and is not destructive")
    Do $$$AssertEquals($Piece(..CardRow(tProposal, "Last update"), ">", 2), "Synchronized now", "and shows the last update moving to Synchronized now")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tConfirmStatus, 200, "the confirm answers 200 with the baseline's key: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tConfirmed) {
        Do $$$AssertEquals(tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.output.lines.%ToJSON(), "1|[""Facts updated in OcuPilotProbeVisits: 7""]", "marked, with the seven changes for the screen")
    }
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "cube", ..#VISITS, "synchronize", .tAgentData), 1, "one ConfigChange row names the agent's synchronize")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#VISITS, .tAgentMarker), 1, "and the agent marker names the cube once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>A Build confirmed after the cube was built by someone else is closed as moved: <code>BuildStamp</code>, to the millisecond, is in the
/// proposal's subject, so the confirm is refused 409 <code>PROPOSAL.TARGETCHANGED</code> with nothing rebuilt, and the person's earlier
/// build is the one audit row for the cube.</p>
/// <p>Mutation (Rule 19): drop <code>BuildStamp</code> from <parameter>OcuPilot.Screen.Tool.AnalyticsCubeBuild.FINGERPRINTSUBJECT</parameter> -- the confirm
/// is applied and this goes red.</p>
Method TestAConfirmAfterAnotherBuildIsRefusedAsMoved()
{
    Do ..EnableKey("analytics.cubemanager.build")
    Do ..Mint(..#BUILDTOOL, ..#CATEGORIES, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act("build", ..#CATEGORIES, .tAnswer), 200, "the person builds the same cube")
    Do ..Empty(..#VISITS)
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is refused, the cube having been built since the review: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Both(), "5|0", "and nothing was rebuilt by it")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "cube", ..#CATEGORIES, "build", .tData), 1, "the person's build is the one audit row")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

}
