/// <p>Pins Story 20.22's descent rule (AD-21's ninth case, AD-62): an inbound file adapter, <code>EnsLib.File.InboundAdapter</code>,
/// reads the directories below its <code>FilePath</code> as many levels down as its <code>SubdirectoryLevels</code>, and
/// measured on a throwaway a parent directory with one level took, then moved, files lying directly in the manager
/// directory and in the served directory. So a set or a reset of either setting that would let the adapter enter the
/// manager directory or the served directory is refused <code>INTEROP.SETTING.DESCENT</code>, from the three callers, at
/// the mint and again at the write: <code>FilePath</code> as the manager directory's parent with one level, one level over
/// that stored path, and a reset to a default that does either. Zero levels, the grandparent with one level, and
/// lowering the levels are accepted. The served directory is reached as the manager directory is; the agent's confirm
/// judges the descent again when the path moves after the mint, in the namespace the set was minted in whatever scope
/// confirms it; and an outbound file adapter, which descends nothing, is judged as a directory alone.</p>
/// <p>It runs on a disabled <code>EnsLib.File.PassthroughService</code> item, sets values only, starts no production and
/// creates no file or directory. The directories are read from the instance.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropSettingControl</class>, whose helpers it
/// calls. One class per run.</p>
Class OcuPilot.Test.InteropSettingDescent Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter REFUSALS = "OcuPilot.Test.InteropSettingRefusals";

Parameter PATHS = "OcuPilot.Test.InteropSettingPaths";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropSettingSeam";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

Parameter SETTOOL = "OcuPilot.Screen.Tool.InteropSettingSet";

Parameter RESETTOOL = "OcuPilot.Screen.Tool.InteropSettingReset";

/// <p>The disabled inbound file item the class adds to the probe production.</p>
Parameter ITEM = "OcuPilotProbeFileSvc";

Parameter SERVICE = "EnsLib.File.PassthroughService";

/// <p>A directory no rule protects, where the adapter starts.</p>
Parameter SAFE = "/tmp/ocupilot-descent/";

/// <p>A namespace that holds no probe production, which a confirm may be scoped to.</p>
Parameter OTHERSCOPE = "HSCUSTOM";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingDescent compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Quit $ClassMethod(..#PROBE, "Remove")
}

/// <p>The probe production gains a disabled inbound file item whose adapter starts at <parameter>SAFE</parameter>.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddFileItem", ..#ITEM, ..#SERVICE, ..#SAFE, 0)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left with its settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The manager directory's parent, and its parent in turn.</p>
ClassMethod Parent() As %String
{
    Quit ##class(%File).ParentDirectoryName($ClassMethod(..#PATHS, "Manager"))
}

ClassMethod Grandparent() As %String
{
    Quit ##class(%File).ParentDirectoryName(..Parent())
}

/// <p>The stored value of the file item's adapter setting <var>pName</var>.</p>
ClassMethod StoredOf(pName As %String) As %String
{
    Set tText = "<none>"
    Set tProductionName = $Parameter(..#CONTROL, "PRODUCTION")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tProduction = ##class(Ens.Config.Production).%OpenId(tProductionName)
        Set tItem = tProduction.FindItemByConfigName(..#ITEM)
        Set tSetting = tItem.FindSettingByName(pName, "Adapter")
        If $IsObject(tSetting) Set tText = tSetting.Value
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>Assert that the three callers earn <var>pPort</var>, <var>pMint</var> and <var>pScreen</var> for the write of the
/// file item's <var>pName</var>, and that the item's stored settings and the class are as they were.</p>
Method Refused(pLabel As %String, pType As %String, pName As %String, pValue As %String, pPort As %String, pMint As %String, pScreen As %String)
{
    Set tBefore = ..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", pType, "Adapter", pName, pValue, ..#ITEM), pPort, pLabel _ ": through the port")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", pType, "Adapter", pName, pValue, .tProblem, ..#ITEM), pMint, pLabel _ ": through the agent's mint " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByScreen", pType, "Adapter", pName, pValue, ..#ITEM), pScreen, pLabel _ ": through the person's row action")
    Do $$$AssertEquals(..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText"), tBefore, pLabel _ ": the stored settings and the class are as they were")
    Set tAudit = $ClassMethod(..#CONTROL, "SettingAudited", tSince)
    Do $$$AssertEquals(tAudit, "", pLabel _ ": and the vendor audited no setting: " _ tAudit)
}

/// <p>AC9: with one level of subdirectories, <code>FilePath</code> as the manager directory's parent is refused
/// <code>INTEROP.SETTING.DESCENT</code> by the three callers, and one level over a stored <code>FilePath</code> of that
/// parent is refused the same; the item's rows list both settings with their classes' types.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DescentReaches</method> stop one level short -- both
/// legs go red; make a set of <code>SubdirectoryLevels</code> not judged -- the levels leg goes red.</p>
Method TestAParentDirectoryWithOneLevelIsRefused()
{
    Set tDescent = "422 INTEROP.SETTING.DESCENT"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do ..Refused("FilePath as the manager directory's parent, one level", "SET", "FilePath", ..Parent(), tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "the adapter descends no level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "and starts in the manager directory's parent")
    Do ..Refused("one level over that parent", "SET", "SubdirectoryLevels", "1", tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do ..Refused("two levels over it", "SET", "SubdirectoryLevels", "2", tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "SubdirectoryLevels", "1", .tProblem, ..#ITEM)
    Do $$$AssertEquals(tProblem, "'Value': " _ ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.SETTING.DESCENT"), "the mint says why, in the story's own sentence")
}

/// <p>AC9: no level, the grandparent with one level (the manager directory lies two levels down), a protected directory
/// deeper than the levels, and lowering the levels are all accepted; the stored path and levels are what the callers set.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DescentReaches</method> ignore the levels -- the
/// grandparent and the lowering rows go red.</p>
Method TestTheLevelsThatDoNotReachAProtectedDirectoryAreAccepted()
{
    Set tManager = $ClassMethod(..#PATHS, "Manager")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", ..Parent(), .tProblem, ..#ITEM), "minted", "the parent with no level is accepted at the mint: the manager directory is not entered")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", ..Grandparent(), .tProblem, ..#ITEM), "minted", "the grandparent with one level is accepted: the manager directory lies two levels down")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", ..Grandparent(), ..#ITEM), "200 ", "and the port stores it")
    Do $$$AssertEquals(..StoredOf("FilePath"), ..Grandparent(), "as given")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "SubdirectoryLevels", "2", ..#ITEM), "422 INTEROP.SETTING.DESCENT", "a second level over it reaches the manager directory and is refused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the path is moved to the parent behind the rule's back")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "SubdirectoryLevels", "0", ..#ITEM), "200 ", "lowering the levels from one to none is accepted, as it can only lessen what the adapter reads")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "0", "and stored")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", tManager _ "sub/", ..#ITEM), "200 ", "a path below the manager directory is judged by the directory rules alone, and passes")
}

/// <p>AC9: a reset is judged by the default it would leave in force, by descent too. The production holds its own
/// <code>FilePath</code> and a system default names the manager directory's parent: with one level the reset is refused
/// <code>INTEROP.SETTING.DESCENT</code> by the three callers; and a reset of the levels to a default of one over a
/// stored path that reaches the manager directory is refused the same.</p>
/// <p>Mutation (Rule 19): judge the current value, not the default, in a reset -- both legs go red.</p>
Method TestAResetThatLeavesADescentInForceIsRefused()
{
    Set tDescent = "409 INTEROP.SETTING.DESCENT"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", ..#ITEM, "Adapter", "FilePath", ..Parent()), "a system default names the manager directory's parent")
    Do ..Refused("a reset of FilePath to that default", "RESET", "FilePath", $Char(0), tDescent, tDescent, tDescent)
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the item starts in the manager directory's parent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", ..#ITEM, "Adapter", "SubdirectoryLevels", "1"), "a system default sets one level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "and the production holds none")
    Do ..Refused("a reset of the levels to that default", "RESET", "SubdirectoryLevels", $Char(0), tDescent, tDescent, tDescent)
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 3), "the production holds three levels")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "RESET", "Adapter", "SubdirectoryLevels", $Char(0), ..#ITEM), "200 ", "a reset to the class default of none is accepted: lowering is never refused")
}

/// <p>AC9: the write judges descent again. A mint accepts one level over a path; the served directory then moves to a
/// directory directly under the path, through <class>OcuPilot.Test.InteropSettingSeam</class>, and the port's set of the
/// levels refuses it <code>INTEROP.SETTING.DESCENT</code>, storing nothing.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.InteropPort.ChangeProblem</method> in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> and in <method>OcuPilot.Port.InteropPort.SettingViolations</method> --
/// this goes red.</p>
Method TestTheWriteJudgesTheDescentAgain()
{
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "SubdirectoryLevels", "1", .tProblem, ..#ITEM), "minted", "the mint accepts one level over the safe path")
    Do $ClassMethod(..#PATHS, "HoldTheWriterPairs")
    Do $ClassMethod(..#SEAM, "UsePathPortFixture")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", ..#SAFE _ "served")
    Set tHttpCode = $ClassMethod(..#PATHS, "BySeam", "SET", "Adapter", "SubdirectoryLevels", "1", ..#ITEM)
    Do $$$AssertEquals(tHttpCode, "422 INTEROP.SETTING.DESCENT", "the served directory has moved one level below the path: the port refuses the levels")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "0", "and stores nothing")
}

/// <p>The agent's call of <var>pTool</var> for the file item's <var>pName</var>, minted for the HTTP account on a seeded
/// turn: the proposal in <var>pProposal</var> (<code>""</code> when the mint refused) and its turn in <var>pTurn</var>.</p>
ClassMethod Mint(pTool As %String, pName As %String, pValue As %String, Output pProposal, Output pTurn) As %Status
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", "Adapter", pName, pValue, ..#ITEM)
    Quit $ClassMethod(..#ITEMS, "MintAs", pTool, tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
}

/// <p>The agent's confirm of <var>pProposal</var> over HTTP, as <code>status code</code>, the answer in
/// <var>pAnswer</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pAnswer) As %String
{
    Set tSC = $ClassMethod(..#ITEMS, "ConfirmHttp", pProposal.proposalId, .tStatus, .tRaw, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>AC9: the agent's confirm judges the descent again. A set of the levels is minted over a safe path and accepted; the
/// file path then moves to the manager directory's parent, which no proposal can see, and the confirm over HTTP is
/// refused <code>TOOL.ARGUMENTS</code> with the descent sentence before the claim, storing nothing and leaving the
/// proposal live. With the path moved back the same proposal confirms: the refusal was the descent's.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DescentReaches</method> answer 0 -- the confirm is
/// admitted and the first leg goes red; make <method>OcuPilot.Screen.Tool.InteropSettingAction.ConfirmProblem</method>
/// answer no problem -- the claim is made first, the port refuses it, and the proposal is spent: the first and last legs
/// go red.</p>
Method TestTheAgentsConfirmOfALevelsSetIsRefusedWhenThePathMovesAfterTheMint()
{
    Set tSC = ..Mint(..#SETTOOL, "SubdirectoryLevels", "1", .tProposal, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the mint accepts one level over the safe path")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the file path moves to the manager directory's parent behind the proposal's back")
    Set tBefore = ..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer), "400 TOOL.ARGUMENTS", "the confirm is refused before the claim: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && (tAnswer.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.SETTING.DESCENT")), "and says why, in the descent sentence")
    Do $$$AssertEquals(..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText"), tBefore, "nothing was stored and the class is as it was")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "SettingAudited", tSince), "", "and the vendor audited no setting")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "State"), ##class(OcuPilot.Kernel.State.Propose).#STATELIVE, "the proposal is still live")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..#SAFE), "the file path moves back")
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer), "200 ", "the same proposal now confirms: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "1", "and stores the levels")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC9, AD-52: the agent's confirm judges the set where the proposal was minted, whatever namespace the confirming
/// request is scoped to. A set of the levels is minted in <code>USER</code> over a safe path, the file path moves to the
/// manager directory's parent, and the confirm sent from <parameter>OTHERSCOPE</parameter>, which holds no probe
/// production, is refused <code>TOOL.ARGUMENTS</code> before the claim, leaving the proposal live; with the path moved
/// back the same confirm from that scope stores the levels in <code>USER</code>.</p>
/// <p>Mutation (Rule 19): judge <method>OcuPilot.Screen.Tool.InteropSettingSet.ArgumentProblem</method> in
/// <code>Kernel.Scope.Current()</code> again -- the confirm finds no production in the other scope, the claim is made and
/// the write refuses it, and the first leg goes red.</p>
Method TestAConfirmFromAnotherScopeIsJudgedWhereTheSetWasMinted()
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", "Adapter", "SubdirectoryLevels", "1", ..#ITEM)
    Set tSC = $ClassMethod(..#ITEMS, "MintAs", ..#SETTOOL, tArgs, $Username, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the mint accepts one level over the safe path in USER")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the file path moves to the manager directory's parent behind the proposal's back")
    Set tSC = ##class(OcuPilot.Test.InteropControl).ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "400 TOOL.ARGUMENTS", "the confirm from " _ ..#OTHERSCOPE _ "'s scope is refused before the claim")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "State"), ##class(OcuPilot.Kernel.State.Propose).#STATELIVE, "the proposal is still live")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "0", "and nothing was stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..#SAFE), "the file path moves back")
    Set tSC = ##class(OcuPilot.Test.InteropControl).ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "200 ", "the same confirm from that scope is admitted")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "1", "and stores the levels in USER")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC9: the agent's confirm of a reset is refused by the write when the path moves after the mint. A reset of the levels
/// to a system default of one is minted over a safe path and confirms; the same reset minted again is confirmed after the
/// file path moves to the manager directory's parent. The confirm's fingerprint holds (the levels' own row is unchanged),
/// the claim is made, and the write judges the default it would leave in force: 409
/// <code>INTEROP.SETTING.DESCENT</code> at the write, the production's own value kept.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.InteropPort.ChangeProblem</method> in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> -- the second leg is admitted and goes red; make
/// <method>OcuPilot.Port.InteropPort.DescentReaches</method> answer 0 -- the same.</p>
Method TestTheAgentsConfirmOfAResetIsRefusedWhenThePathMovesAfterTheMint()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", ..#ITEM, "Adapter", "SubdirectoryLevels", "1"), "a system default sets one level")
    Set tSC = ..Mint(..#RESETTOOL, "SubdirectoryLevels", $Char(0), .tFirst, .tFirstTurn)
    Do $$$AssertTrue($IsObject($Get(tFirst)), "the mint of a reset over the safe path is accepted")
    If '$IsObject($Get(tFirst)) Quit
    Do $$$AssertEquals(..Confirm(tFirst, .tAnswer), "200 ", "and confirms while the path stays: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "<none>", "removing the production's own levels")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tFirstTurn)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "the production holds its own levels again")
    Set tSC = ..Mint(..#RESETTOOL, "SubdirectoryLevels", $Char(0), .tProposal, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the second mint is accepted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the file path moves to the manager directory's parent behind the proposal's back")
    Set tBefore = ..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer), "409 INTEROP.SETTING.DESCENT", "the confirm is refused by the write: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("state"), 1: ""), "confirmed", "after the claim, which the fingerprint let through: the reset's own row had not changed")
    Do $$$AssertEquals(..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText"), tBefore, "nothing was stored and the class is as it was")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "SettingAudited", tSince), "", "and the vendor audited no setting")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC9: descent reaches the served directory as it reaches the manager directory, from the three callers: with one
/// level, <code>FilePath</code> as the served directory's parent is refused <code>INTEROP.SETTING.DESCENT</code>, and so is
/// one level over that stored path, while no level is accepted. The served directory moved two levels below the path
/// (through <class>OcuPilot.Test.InteropSettingSeam</class>) is not reached by one level and is by two.</p>
/// <p>Mutation (Rule 19): drop <code>ServedDirectory</code> from the directories
/// <method>OcuPilot.Port.InteropPort.DescentReaches</method> tests -- every leg goes red.</p>
Method TestTheServedDirectoryIsReachedByDescentToo()
{
    Set tServedParent = ##class(%File).ParentDirectoryName($ClassMethod(..#PATHS, "Served"))
    Do $$$AssertEquals($ClassMethod("OcuPilot.Port.PathPort", "Contains", tServedParent, $ClassMethod(..#PATHS, "Manager")), 0, "the served directory's parent holds no manager directory below it, so only the served directory can be reached")
    Set tDescent = "422 INTEROP.SETTING.DESCENT"
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", tServedParent, .tProblem, ..#ITEM), "minted", "the served directory's parent with no level is accepted at the mint")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do ..Refused("FilePath as the served directory's parent, one level", "SET", "FilePath", tServedParent, tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "the adapter descends no level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", tServedParent), "and starts in the served directory's parent")
    Do ..Refused("one level over that parent", "SET", "SubdirectoryLevels", "1", tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..#SAFE), "the path returns to the safe directory")
    Do $ClassMethod(..#PATHS, "HoldTheWriterPairs")
    Do $ClassMethod(..#SEAM, "UsePathPortFixture")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", ..#SAFE _ "a/b/")
    Do $$$AssertEquals($ClassMethod(..#PATHS, "BySeam", "SET", "Adapter", "SubdirectoryLevels", "1", ..#ITEM), "200 ", "a served directory two levels below the path is not reached by one level")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "1", "and the levels are stored")
    Do $$$AssertEquals($ClassMethod(..#PATHS, "BySeam", "SET", "Adapter", "SubdirectoryLevels", "2", ..#ITEM), tDescent, "two levels reach it")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "1", "and the stored levels stay one")
}

/// <p>AC9: an outbound file adapter reads no directory below its path, so its <code>FilePath</code> is judged as a
/// directory alone: the manager directory's parent is accepted by the mint and the port, which store it, while the manager
/// directory itself is still refused <code>PATH.MANAGERDIR</code> by the mint, the port and the person's row action.</p>
/// <p>Mutation (Rule 19): judge every <code>FilePath</code> with one level of descent in
/// <method>OcuPilot.Port.InteropPort.ChangeProblem</method> (<code>Set tLevels = 1</code> for the file path) -- the
/// accepted legs go red.</p>
Method TestAnOutboundAdaptersFilePathIsJudgedAsADirectoryAlone()
{
    Set tOutbound = "OcuPilotProbeFileOp"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddFileItem", tOutbound, "EnsLib.File.PassthroughOperation", ..#SAFE), "a disabled outbound file item is added")
    Set tManager = $ClassMethod(..#PATHS, "Manager")
    Set tRefused = "422 PATH.MANAGERDIR"
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", ..Parent(), .tProblem, tOutbound), "minted", "the manager directory's parent is accepted at the mint: nothing below it is read")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", ..Parent(), tOutbound), "200 ", "and by the port")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Adapter", "FilePath", tOutbound), ..Parent(), "which stores it as given")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", tManager, tOutbound), tRefused, "the manager directory itself is refused by the port")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", tManager, .tProblem, tOutbound), "400 TOOL.ARGUMENTS", "by the agent's mint")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByScreen", "SET", "Adapter", "FilePath", tManager, tOutbound), tRefused, "and by the person's row action")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Adapter", "FilePath", tOutbound), ..Parent(), "which leave the stored path as it was")
}

}
