/// <p>Pins the edges of Story 24.13 Batch 3's run-time variable and icon writes against <code>USER</code> (AD-8, AD-13, AD-22, AD-29, AD-34, AD-54, AD-65): a name the namespace holds is 409 <code>ANALYTICS.VARIABLE.TAKEN</code>
/// or <code>ANALYTICS.ICON.TAKEN</code> and a name differing only in case is another name; a name that is not held is 404 <code>*.ABSENT</code> for a change and a removal; a name or text outside the shape rules is 400
/// <code>ANALYTICS.SETTING.NAME</code> or <code>.TEXT</code> and an expression that is not valid ObjectScript 400 <code>ANALYTICS.VARIABLE.EXPRESSION</code>, each with nothing written, by the port, by the person's save and
/// action and at the agent's mint; a write while the namespace's settings lock is held is 409 <code>WRITE.TARGETBUSY</code>; a proposal minted before its target changed is closed as moved; a read-only database that holds
/// either global, a caller without the developer pair and a namespace without analytics are refused before any vendor call; and the agent's removals are refused while their keys ship off.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.AnalyticsSettingsEntryWrite</class>. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsEntryWriteEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsSettingsDatabaseSeam";

Parameter WRITE = "OcuPilot.Test.AnalyticsSettingsEntryWrite";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter VARIABLE = "OcuProbe2413Var";

Parameter ICON = "OcuProbe2413Icon";

Parameter TOOLS = "OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAdd,OcuPilot.Screen.Tool.AnalyticsRuntimeVariableSet,OcuPilot.Screen.Tool.AnalyticsRuntimeVariableRemove,OcuPilot.Screen.Tool.AnalyticsUserIconAdd,OcuPilot.Screen.Tool.AnalyticsUserIconSet,OcuPilot.Screen.Tool.AnalyticsUserIconRemove";

Property StartDigest As %String;

Property StartTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWriteEdge turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    If $$$ISOK(tSC) Set ..StartDigest = $ClassMethod(..#PROBE, "SettingsDigest"), ..StartTaken = 1
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWriteEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWriteEdge left USER's analytics settings changed")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

Method OnAfterOneTest() As %Status
{
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the governance policy is put back to the baseline")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>The call <var>pType</var> on <var>pEndpoint</var> for the id <var>pId</var> with the body <var>pBody</var> through the port (or the seam <var>pSeam</var>), as <code>&lt;http&gt; &lt;code&gt;</code>; the
/// composed read when <var>pAction</var> is given.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject = "", pAction As %String = "", pSeam As %String = {..#PORT}, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(pSeam, "Invoke", pEndpoint, pType, .tQuery, pBody, .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ $Select($IsObject(tFault.%Get("detail")): " " _ tFault.detail.%Get("failedPair"), 1: ""), 1: "")
}

/// <p>The agent's mint of <var>pTool</var> with the arguments <var>pJson</var> is refused: <var>pExpect</var> reads <code>proposal|status</code>.</p>
Method MintRefused(pTool As %String, pJson As %String, pExpect As %String, pLabel As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, ##class(%DynamicAbstractObject).%FromJSON(pJson), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tHttp), pExpect, pLabel _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC1: each refusal answers its own code with nothing written, from the port and from the person's save or action, and the agent's mint refuses what the person is refused. A name held is 409 TAKEN, a name that
/// differs only in case is another name and is added, a name not held is 404 ABSENT for a change and a removal, a name that is empty, 256 characters or holds a control character is 400 <code>ANALYTICS.SETTING.NAME</code>,
/// a text of 2001 characters or with a control character is 400 <code>ANALYTICS.SETTING.TEXT</code>, and an expression that is not valid is 400 <code>ANALYTICS.VARIABLE.EXPRESSION</code>; an empty expression is stored empty.</p>
/// <p>Mutation (Rule 19): compare names without regard to case in <method>OcuPilot.Port.AnalyticsPort.JudgeSetting</method> -- the case leg goes red.</p>
Method TestARefusedWriteSaysWhyAndWritesNothing()
{
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "ctx")
    Do $ClassMethod(..#WRITE, "Seed", 1, ..#ICON, "/kept.png")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", ..#VARIABLE, {"Value": "2"}), "409 ANALYTICS.VARIABLE.TAKEN", "an add of a held variable name is refused")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", ..#ICON, {"Path": "/x.png"}), "409 ANALYTICS.ICON.TAKEN", "and an add of a held icon name")
    Do $$$AssertEquals(..Call("RuntimeVariables", "RUNTIMEVARIABLE", ..#VARIABLE, "", "ENTRYADD"), "409 ANALYTICS.VARIABLE.TAKEN", "the read composed for the add says the same")
    Do $$$AssertEquals(..Call("RuntimeVariables", "RUNTIMEVARIABLE", ..#VARIABLE _ "Free", "", "ENTRYADD"), "404 PORT.NOTFOUND", "and reads a free name as absent, which a create expects")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": (..#VARIABLE), "Value": "2"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.VARIABLE.TAKEN", "the person's save of a held name is refused")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/user-icons", {"Name": (..#ICON), "Path": "/x.png"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.ICON.TAKEN", "and of a held icon")
    Do ..MintRefused($Piece(..#TOOLS, ",", 1), {"Name": (..#VARIABLE), "Value": "2"}.%ToJSON(), "0|409", "the agent's add of a held name is refused at the mint")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE _ "Missing", {"Comment": "x"}), "404 ANALYTICS.VARIABLE.ABSENT", "a change of a variable that is not held is refused")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYREMOVE", ..#VARIABLE _ "Missing", {}), "404 ANALYTICS.VARIABLE.ABSENT", "and a removal")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", ..#ICON _ "Missing", {"Path": "x"}), "404 ANALYTICS.ICON.ABSENT", "a change of an icon that is not held is refused")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYREMOVE", ..#ICON _ "Missing", {}), "404 ANALYTICS.ICON.ABSENT", "and a removal")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE _ "Missing", {"Comment": "x"}, .tAnswer), 404, "the person's change of a missing variable is refused")
    Do ..MintRefused($Piece(..#TOOLS, ",", 2), {"Name": (..#VARIABLE _ "Missing"), "Comment": "x"}.%ToJSON(), "0|400", "and so is the agent's mint")
    Do ..MintRefused($Piece(..#TOOLS, ",", 5), {"Name": (..#ICON _ "Missing"), "Path": "x"}.%ToJSON(), "0|400", "and the agent's icon change")
    Set tLong = $Translate($Justify("", 2001), " ", "x")
    For tCase = $ListBuild("", "x"), $ListBuild($Translate($Justify("", 256), " ", "n"), "x"), $ListBuild("Bad" _ $Char(7) _ "Name", "x") {
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", $List(tCase, 1), {"Value": "1"}), "400 ANALYTICS.SETTING.NAME", "a variable name of " _ $Length($List(tCase, 1)) _ " characters is refused")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", $List(tCase, 1), {"Path": "p"}), "400 ANALYTICS.SETTING.NAME", "and so is an icon's")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": ($List(tCase, 1)), "Value": "1"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 ANALYTICS.SETTING.NAME", "the person's save is refused the same way")
    }
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "OcuProbe2413Text", {"Comment": (tLong)}), "400 ANALYTICS.SETTING.TEXT", "a comment of 2001 characters is refused")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "OcuProbe2413Text", {"Context": ("a" _ $Char(7))}), "400 ANALYTICS.SETTING.TEXT", "and a context with a control character")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Value": (tLong)}), "400 ANALYTICS.SETTING.TEXT", "and an expression of 2001 characters")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", ..#ICON, {"Path": (tLong)}), "400 ANALYTICS.SETTING.TEXT", "and a path of 2001 characters")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Value": "1+"}), "400 ANALYTICS.VARIABLE.EXPRESSION", "an expression that is not valid is refused")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": "OcuProbe2413Bad", "Value": "1+"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 ANALYTICS.VARIABLE.EXPRESSION", "the person's save is refused it")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, {"Value": "1+"}, .tAnswer), 400, "so is the person's change")
    Do ..MintRefused($Piece(..#TOOLS, ",", 1), {"Name": "OcuProbe2413Bad", "Value": "1+"}.%ToJSON(), "0|400", "and the agent's add")
    Do ..MintRefused($Piece(..#TOOLS, ",", 2), {"Name": (..#VARIABLE), "Value": "1+"}.%ToJSON(), "0|400", "and the agent's change")
    Do ..MintRefused($Piece(..#TOOLS, ",", 4), {"Name": "OcuProbe2413BadIcon", "Path": (tLong)}.%ToJSON(), "0|400", "and the agent's icon add with a path that is too long")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "nothing was written by any of them")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "ocuprobe2413var", {"Value": "3"}), "200 ", "a name that differs only in case is another name, and is added")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", ..#VARIABLE) _ "|" _ $ClassMethod(..#WRITE, "Variable", "ocuprobe2413var"), "1|1|kept|ctx|1|3||", "so both are held, the first as it was")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Value": ""}), "200 ", "an empty expression is stored as the classic page stores it")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", ..#VARIABLE), "1||kept|ctx", "empty, with the comment and the context kept")
}

/// <p>The Edge row "two writers": while another process holds the namespace's settings lock, the person's add, change and removal of a variable and of an icon are each refused 409 <code>WRITE.TARGETBUSY</code> after the
/// wait and write nothing; once the lock is released the same add applies. The lock is held by this process, and the request is served by another.</p>
/// <p>Mutation (Rule 19): drop the <code>Lock</code> from <method>OcuPilot.Port.AnalyticsPort.InvokeSetting</method> -- the refusal legs go red.</p>
Method TestASecondWriterIsRefusedWhileTheLockIsHeld()
{
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "")
    Do $ClassMethod(..#WRITE, "Seed", 1, ..#ICON, "/kept.png")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    Lock +^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE):0
    Do $$$AssertTrue($Test, "this process took the namespace's settings lock")
    Set tAdd = $ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": (..#VARIABLE _ "Busy"), "Value": "1"}, .tAddAnswer)
    Set tIcon = $ClassMethod(..#WRITE, "Post", "/analytics/user-icons", {"Name": (..#ICON _ "Busy"), "Path": "/x.png"}, .tIconAnswer)
    Set tSet = $ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, {"Comment": "busy"}, .tSetAnswer)
    Set tRemove = $ClassMethod(..#WRITE, "Act", "analytics.usericons", "remove", ..#ICON, "", .tRemoveAnswer)
    Set tVariableRemove = $ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "remove", ..#VARIABLE, "", .tVariableRemoveAnswer)
    Set tIconSet = $ClassMethod(..#WRITE, "Act", "analytics.usericons", "set", ..#ICON, {"Path": "/busy.png"}, .tIconSetAnswer)
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do $$$AssertEquals(tAdd _ "|" _ $Select($IsObject($Get(tAddAnswer)): tAddAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the variable add is refused while the lock is held")
    Do $$$AssertEquals(tIcon _ "|" _ $Select($IsObject($Get(tIconAnswer)): tIconAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the icon add is refused while the lock is held")
    Do $$$AssertEquals(tSet _ "|" _ $Select($IsObject($Get(tSetAnswer)): tSetAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the variable change is refused while the lock is held")
    Do $$$AssertEquals(tRemove _ "|" _ $Select($IsObject($Get(tRemoveAnswer)): tRemoveAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the icon removal is refused while the lock is held")
    Do $$$AssertEquals(tVariableRemove _ "|" _ $Select($IsObject($Get(tVariableRemoveAnswer)): tVariableRemoveAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the variable removal is refused while the lock is held")
    Do $$$AssertEquals(tIconSet _ "|" _ $Select($IsObject($Get(tIconSetAnswer)): tIconSetAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the icon change is refused while the lock is held")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "and nothing was written")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": (..#VARIABLE _ "Busy"), "Value": "1"}, .tFree), 201, "once released the add applies")
}

/// <p>The Edge row "stale": a change minted before another change of the same variable is closed as moved when it is confirmed after; so is an add whose name was taken after the mint. Nothing the proposal would have
/// written is written.</p>
/// <p>Mutation (Rule 19): drop <code>Was</code> from <method>OcuPilot.Screen.Tool.AnalyticsSettingEntryAction.MergeUpdate</method> -- the first leg goes red.</p>
Method TestAProposalMintedBeforeTheTargetChangedIsClosedAsMoved()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "first", "")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", $Piece(..#TOOLS, ",", 2), {"Name": (..#VARIABLE), "Comment": "agent"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's change is minted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, {"Comment": "person"}, .tAnswer), 200, "the person changes the comment")
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is closed as moved")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", ..#VARIABLE), "1|1|person|", "and the person's change stands")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", $Piece(..#TOOLS, ",", 4), {"Name": (..#ICON), "Path": "/agent.png"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's icon add is minted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/user-icons", {"Name": (..#ICON), "Path": "/person.png"}, .tAdded), 201, "the person adds the name")
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the add of the name taken since the mint is closed as moved")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", ..#ICON), "1|/person.png", "and the person's icon stands")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>The gate: a read-only database that holds every settings global refuses each of the six writes 409 <code>ANALYTICS.SETTING.READONLY</code> before any vendor call, also for the read composed for them; one that
/// holds only <code>^DeepSee.User.Settings</code> refuses the three variable writes and not the three icon writes, and one that holds only <code>^DeepSee.User.Icons</code> the reverse; a caller holding only the
/// portal's pair is refused 403 naming <code>%Development:USE</code>; a namespace that does not report analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>. Each is answered while a vendor failure is armed on the
/// gate seam, so a vendor call before the gate would answer 500.</p>
/// <p>Mutation (Rule 19): answer <code>SETTINGSGLOBAL</code> from <method>OcuPilot.Port.AnalyticsPort.SettingsGlobal</method> for every endpoint -- the one-global-at-a-time legs go red, and only they.</p>
Method TestTheGateRefusesBeforeAnyVendorCall()
{
    Set tCases = $ListBuild($ListBuild("RuntimeVariables", "ENTRYADD", "OcuProbe2413Gate", {"Value": "1"}.%ToJSON()), $ListBuild("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Comment": "x"}.%ToJSON()), $ListBuild("RuntimeVariables", "ENTRYREMOVE", ..#VARIABLE, "{}"), $ListBuild("UserIcons", "ENTRYADD", "OcuProbe2413GateIcon", {"Path": "x"}.%ToJSON()), $ListBuild("UserIcons", "ENTRYSET", ..#ICON, {"Path": "x"}.%ToJSON()), $ListBuild("UserIcons", "ENTRYREMOVE", ..#ICON, "{}"))
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    Do $ClassMethod(..#SEAM, "Arm", "sdatabase", "readonly")
    For tPair = $ListBuild("%DeepSee_Portal", "USE"), $ListBuild("%Development", "USE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tAnswer = ..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), "", ..#SEAM)
        Do $$$AssertEquals(tAnswer, "409 ANALYTICS.SETTING.READONLY", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": a read-only database is refused: " _ tAnswer)
    }
    Set tAnswer = ..Call("UserIcons", "USERICON", ..#ICON, "", "ENTRYSET", ..#SEAM)
    Do $$$AssertEquals(tAnswer, "409 ANALYTICS.SETTING.READONLY", "and so is the read composed for a change: " _ tAnswer)
    Set tDigest = $ClassMethod(..#PROBE, "SettingsDigest")
    For tGlobal = $Parameter(..#PORT, "VARIABLEGLOBAL"), $Parameter(..#PORT, "ICONGLOBAL") {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
        Do $ClassMethod(..#SEAM, "Arm", "sglobal", tGlobal)
        Do $ClassMethod(..#SEAM, "Arm", "sdatabase", "readonly")
        For tAt = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tAt)
            Set tOwn = $Select(tAt < 4: $Parameter(..#PORT, "VARIABLEGLOBAL"), 1: $Parameter(..#PORT, "ICONGLOBAL"))
            Set tAnswer = ..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), "", ..#SEAM)
            Do $$$AssertEquals(tAnswer = "409 ANALYTICS.SETTING.READONLY", tOwn = tGlobal, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": only a read-only " _ tGlobal _ " refuses it, and it answered " _ tAnswer)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tDigest, "and no write reached the vendor")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        If '$ListFind($ListBuild(1, 4), tAt) Continue
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Do $$$AssertEquals(..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), "", ..#SEAM), "403 AUTH.NOPRIVILEGE %Development:USE", $List(tCase, 1) _ ": without the developer pair the write is refused, naming the pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Do $$$AssertEquals(..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), "", ..#SEAM, "HSCUSTOM"), "409 ANALYTICS.NAMESPACE", $List(tCase, 1) _ ": a namespace without analytics is refused")
    }
}

/// <p>AC5 and the Edge row "key off": the baseline ships the four add and change keys on and the two removals off, so the governance gate allows the agent's call of each of the first four and refuses each removal as
/// disabled; every one is a write the registry declares against <code>AnalyticsPort</code> and the classic Settings page, destructive only for a removal.</p>
/// <p>Mutation (Rule 19): flip the <code>analytics.runtimevariables.add</code> line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>false</code> -- the gate leg goes red naming it.</p>
Method TestTheBaselineShipsFourKeysOnAndTwoOff()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tStored), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tStored), "and leaves every key to the baseline")
    For tAt = 1:1:6 {
        Set tTool = $Piece(..#TOOLS, ",", tAt)
        Set tName = $Parameter(tTool, "TOOLNAME")
        Set tRemove = (tAt = 3) || (tAt = 6)
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(tName, "write", $Username, {}, .tDecision), tName _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")), 'tRemove, tName _ ": the baseline " _ $Select(tRemove: "refuses", 1: "allows") _ " it")
        Do $$$AssertEquals($Parameter(tTool, "PORTCLASS") _ "|" _ $Parameter(tTool, "CLASSICPAGES") _ "|" _ ($Parameter(tTool, "DESTRUCTIVE") + 0), "OcuPilot.Port.AnalyticsPort|%DeepSee.UI.Settings|" _ ''tRemove, tName _ ": declares the analytics port and the classic page, and is destructive only as a removal")
    }
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "")
    Do $ClassMethod(..#WRITE, "Seed", 1, ..#ICON, "/kept.png")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    Do ..ConfirmRefused($Piece(..#TOOLS, ",", 3), {"Name": (..#VARIABLE)}.%ToJSON(), "the agent's removal of a variable is refused at its shipped key")
    Do ..ConfirmRefused($Piece(..#TOOLS, ",", 6), {"Name": (..#ICON)}.%ToJSON(), "and the removal of an icon")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "and nothing was removed")
}

/// <p>The agent's mint of <var>pTool</var> with the arguments <var>pJson</var> gives a proposal, and its confirm is refused 403 <code>GOVERNANCE.DISABLED</code>.</p>
Method ConfirmRefused(pTool As %String, pJson As %String, pLabel As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, ##class(%DynamicAbstractObject).%FromJSON(pJson), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), pLabel _ ": the proposal is minted")
    If $IsObject($Get(tProposal)) {
        Do $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "403|GOVERNANCE.DISABLED", pLabel)
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
