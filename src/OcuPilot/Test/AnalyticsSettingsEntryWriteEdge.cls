/// <p>Pins the edges of Story 24.13 Batch 3's run-time variable and icon writes against <code>USER</code> (AD-8, AD-13, AD-22, AD-29, AD-34, AD-54, AD-65): a name the namespace holds is 409 <code>ANALYTICS.VARIABLE.TAKEN</code>
/// or <code>ANALYTICS.ICON.TAKEN</code> and a name differing only in case is another name; a name that is not held is 404 <code>*.ABSENT</code> for a change and a removal; a name or text outside the shape rules is 400
/// <code>ANALYTICS.SETTING.NAME</code> or <code>.TEXT</code> and an expression that is not valid ObjectScript 400 <code>ANALYTICS.VARIABLE.EXPRESSION</code>, each with nothing written, by the port, by the person's save and
/// action and at the agent's mint; a write while the namespace's settings lock is held is 409 <code>WRITE.TARGETBUSY</code>; a proposal minted before its target changed is closed as moved; a read-only database that holds
/// either global, a caller without the developer pair and a namespace without analytics are refused before any vendor call; and the agent's removals are refused while their keys ship off. It also pins the edges of
/// the same writes: an expression that would act is refused or stored and never run by any path; names at the edge of the shape rule, a name's case, a path that looks like a reference, the text rules at the mint,
/// and the agent's confirm while the lock is held.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.AnalyticsSettingsEntryWrite</class>. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsEntryWriteEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsSettingsDatabaseSeam";

Parameter WRITE = "OcuPilot.Test.AnalyticsSettingsEntryWrite";

Parameter SETTINGS = "OcuPilot.Test.AnalyticsSettingsWrite";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter LOCKSEAM = "OcuPilot.Test.AnalyticsSettingsLockSeam";

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
    Do $ClassMethod(..#WRITE, "KillRan")
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

Method OnAfterOneTest() As %Status
{
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do $ClassMethod(..#WRITE, "KillRan")
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

/// <p>The final status of the script form of <var>pType</var> on <var>pEndpoint</var> for <var>pId</var> with <var>pBody</var>, run one line at a time in <code>USER</code> as it is pasted:
/// <code>OK</code>, or the error text.</p>
Method ScriptStatus(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSteps = $ClassMethod(..#LOCKSEAM, "Snippet", pEndpoint, pType, .tQuery, pBody)
    If '$IsObject(tSteps) || (tSteps.%Size() '= 1) Quit "no script"
    Set tOrigNS = $NAMESPACE
    XECUTE "Kill tSC,tOptions,tOption,tData,tMessage,tPage,tPanel,tNumber,tClass,tAt,tLocked"
    Set tRaised = ""
    Try {
        For tI = 1:1:$Length(tSteps.%Get(0).text, $Char(10)) {
            Set tLine = $Piece(tSteps.%Get(0).text, $Char(10), tI)
            If tLine '= "" XECUTE tLine
        }
    } Catch ex {
        Set tRaised = ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    If tRaised '= "" Quit "raised " _ tRaised
    Set tStatus = $Get(@"tSC")
    Quit $Select($System.Status.IsOK(tStatus): "OK", 1: $System.Status.GetErrorText(tStatus))
}

/// <p>An expression is code, and is checked and never run, by every path: text that would set <code>^OcuProbe2413Ran</code> when run, and is refused (a preprocessor form the check does not accept, an incomplete
/// expression), is refused 400 <code>ANALYTICS.VARIABLE.EXPRESSION</code> by the port's add and change, the person's save and change, the agent's mint and the script forms, with nothing written; a multi-command
/// expression that is valid is stored as the text it is and read back by the screen, the tool and the port as that text. The global stays undefined and the journal holds no write of it from any process.</p>
/// <p>Mutation (Rule 19): run the line in <method>OcuPilot.Port.AnalyticsPort.VariableExpressionHolds</method> with <code>Xecute</code> -- the global leg goes red.</p>
Method TestAnExpressionThatWouldActIsRefusedOrStoredAndNeverRun()
{
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tProbe = $Parameter(..#WRITE, "EXPRESSION")
    Set tMulti = "1 Set ^OcuProbe2413Ran=1 Kill ^OcuProbe2413Ran"
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    For tBad = "##Expression(" _ tProbe _ ")", tProbe _ "+" {
        Set tLabel = "'" _ $Extract(tBad, 1, 14) _ "...'"
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "OcuProbe2413Fresh", {"Value": (tBad)}), "400 ANALYTICS.VARIABLE.EXPRESSION", tLabel _ ": the port's add refuses it")
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Value": (tBad)}), "400 ANALYTICS.VARIABLE.EXPRESSION", tLabel _ ": and its change")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": "OcuProbe2413Fresh", "Value": (tBad)}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 ANALYTICS.VARIABLE.EXPRESSION", tLabel _ ": the person's save refuses it")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, {"Value": (tBad)}, .tAnswer), 400, tLabel _ ": and the person's change")
        Do ..MintRefused($Piece(..#TOOLS, ",", 1), {"Name": "OcuProbe2413Fresh", "Value": (tBad)}.%ToJSON(), "0|400", tLabel _ ": the agent's add is refused at the mint")
        Do ..MintRefused($Piece(..#TOOLS, ",", 2), {"Name": (..#VARIABLE), "Value": (tBad)}.%ToJSON(), "0|400", tLabel _ ": and its change")
        Do $$$AssertTrue(..ScriptStatus("RuntimeVariables", "ENTRYADD", "OcuProbe2413Fresh", {"Value": (tBad)}) '= "OK", tLabel _ ": the add script is refused")
        Do $$$AssertTrue(..ScriptStatus("RuntimeVariables", "ENTRYSET", ..#VARIABLE, {"Value": (tBad)}) '= "OK", tLabel _ ": and the change script")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "nothing was written by any of them")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Ran"), 0, "and the global the text would set is undefined")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "OcuProbe2413Multi", {"Value": (tMulti)}), "200 ", "a multi-command expression that is valid is added")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, {"Value": (tMulti)}, .tSet), 200, "and set by the person")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", "OcuProbe2413Multi") _ "|" _ $ClassMethod(..#WRITE, "Variable", ..#VARIABLE), "1|" _ tMulti _ "|||1|" _ tMulti _ "|kept|", "each is held as the text it was sent")
    Set tRow = $ClassMethod(..#SETTINGS, "RowWhere", $ClassMethod(..#SETTINGS, "ScreenRows", "analytics.runtimevariables"), "Name", "OcuProbe2413Multi")
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Value = tMulti), "the screen shows it as text")
    Set tToolRow = $ClassMethod(..#SETTINGS, "ToolRow", "analytics.runtimevariables.read", "Name", "OcuProbe2413Multi")
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Value = tMulti), "and the agent's read tool")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "OcuProbe2413Multi"
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "Invoke", "RuntimeVariables", "RUNTIMEVARIABLE", .tQuery, "", .tOne, .tHttp, .tFault), "and the port's single-row read answers")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Ran"), 0, "none of them ran it")
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tWrites, 1)
    Set tNamed = 0
    For tI = 1:1:tTotal {
        If tWrites(tI) [ "OcuProbe2413Ran" Set tNamed = tNamed + 1
    }
    Do $$$AssertTrue(tTotal > 0, "the journal scan spans the writes (" _ tTotal _ " records)")
    Do $$$AssertEquals(tNamed, 0, "and no process journaled a write of that global")
}

/// <p>A name at the edge of the shape rule is stored whole or refused whole. A name of 255 characters, in single-byte and in wide characters, and a name that looks like a number, a decimal, an exponent, a
/// negative, holds a space, a caret, a quote, a dot or markup, is each added, changed, refused as taken when added again, and removed, for a variable and for an icon, held exactly as sent. A name of 600
/// characters, which the instance cannot address, is refused 400 <code>ANALYTICS.SETTING.NAME</code> by the port and the person's save, as are 600 characters, 256 characters and a control character at the agent's mint,
/// with nothing written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.NameShaped</method> admit any length -- the 600-character legs go red.</p>
Method TestNamesAtTheEdgesOfTheShapeRuleAreStoredOrRefusedWhole()
{
    Set tNames = $ListBuild($Translate($Justify("", 255), " ", "n"), $Translate($Justify("", 255), " ", $Char(960)), "7", "007", "1e3", ".5", "-5", "a b", "a^b", "q""uote", "<b>x</b>", "a.b")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    For tAt = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tAt)
        Set tLabel = "name " _ tAt _ " (" _ $Length(tName) _ " characters)"
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", tName, {"Value": "1", "Comment": "c", "Context": "x"}), "200 ", tLabel _ ": added as a variable")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", tName), "1|1|c|x", tLabel _ ": held exactly as sent")
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", tName, {"Value": "2"}), "409 ANALYTICS.VARIABLE.TAKEN", tLabel _ ": added again it is taken")
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", tName, {"Comment": "d"}), "200 ", tLabel _ ": changed")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", tName), "1|1|d|x", tLabel _ ": and the rest kept")
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYREMOVE", tName, {}), "200 ", tLabel _ ": removed, with no fault beside the answer")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", tName), "0|||", tLabel _ ": and gone")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", tName, {"Path": "/p.png"}), "200 ", tLabel _ ": added as an icon")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", tName), "1|/p.png", tLabel _ ": held exactly as sent")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", tName, {"Path": "/z.png"}), "409 ANALYTICS.ICON.TAKEN", tLabel _ ": added again it is taken")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", tName, {"Path": "/q.png"}), "200 ", tLabel _ ": changed")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", tName), "1|/q.png", tLabel _ ": and the path replaced")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYREMOVE", tName, {}), "200 ", tLabel _ ": removed, with no fault beside the answer")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", tName), "0|", tLabel _ ": and gone")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "every name left the namespace as it was found")
    Set tLong = $Translate($Justify("", 600), " ", "n")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", tLong, {"Value": "1"}), "400 ANALYTICS.SETTING.NAME", "a variable name of 600 characters is refused")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", tLong, {"Path": "p"}), "400 ANALYTICS.SETTING.NAME", "and an icon's")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", {"Name": (tLong), "Value": "1"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 ANALYTICS.SETTING.NAME", "the person's variable save refuses it")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/user-icons", {"Name": (tLong), "Path": "p"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 ANALYTICS.SETTING.NAME", "and the icon save")
    For tTool = 1, 4 {
        For tBad = tLong, $Translate($Justify("", 256), " ", "n"), "Bad" _ $Char(7) _ "Name" {
            Set tArgs = {"Name": (tBad)}
            Do tArgs.%Set($Select(tTool = 1: "Value", 1: "Path"), "x", "string")
            Do ..MintRefused($Piece(..#TOOLS, ",", tTool), tArgs.%ToJSON(), "0|400", "the agent's add of a name of " _ $Length(tBad) _ " characters to " _ $Select(tTool = 1: "the variables", 1: "the icons") _ " is refused at the mint")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "and nothing was written by any refusal")
}

/// <p>Names that differ only in case are separate targets. With <code>OcuProbe2413Var</code> and <code>ocuprobe2413var</code> held, and the same for an icon, a change of the lower-case name leaves the other as it was;
/// a change or a removal of a third spelling is 404 <code>*.ABSENT</code> from the port and from the person's action, and the agent's mint refuses it; the person's removal of one spelling leaves the other held, and
/// the audit row names the spelling removed.</p>
/// <p>Mutation (Rule 19): compare names without regard to case where <method>OcuPilot.Port.AnalyticsPort.JudgeSetting</method> finds the row -- the third-spelling legs go red.</p>
Method TestNamesThatDifferOnlyInCaseAreSeparateTargetsForEveryWrite()
{
    Set tUpper = ..#VARIABLE
    Set tLower = $ZConvert(..#VARIABLE, "L")
    Set tOther = $ZConvert(..#VARIABLE, "U")
    Set tIconUpper = ..#ICON
    Set tIconLower = $ZConvert(..#ICON, "L")
    Set tIconOther = $ZConvert(..#ICON, "U")
    Do $ClassMethod(..#WRITE, "Seed", 0, tUpper, "1", "upper", "u")
    Do $ClassMethod(..#WRITE, "Seed", 0, tLower, "2", "lower", "l")
    Do $ClassMethod(..#WRITE, "Seed", 1, tIconUpper, "/U.png")
    Do $ClassMethod(..#WRITE, "Seed", 1, tIconLower, "/l.png")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", tLower, {"Comment": "lower2"}), "200 ", "the lower-case variable is changed")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", tUpper) _ "|" _ $ClassMethod(..#WRITE, "Variable", tLower), "1|1|upper|u|1|2|lower2|l", "and the other spelling is as it was")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", tIconLower, {"Path": "/l2.png"}), "200 ", "the lower-case icon is changed")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", tIconUpper) _ "|" _ $ClassMethod(..#WRITE, "Icon", tIconLower), "1|/U.png|1|/l2.png", "and the other spelling is as it was")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", tOther, {"Comment": "x"}), "404 ANALYTICS.VARIABLE.ABSENT", "a change of a third spelling of the variable is refused")
    Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYREMOVE", tOther, {}), "404 ANALYTICS.VARIABLE.ABSENT", "and a removal")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", tIconOther, {"Path": "x"}), "404 ANALYTICS.ICON.ABSENT", "a change of a third spelling of the icon is refused")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYREMOVE", tIconOther, {}), "404 ANALYTICS.ICON.ABSENT", "and a removal")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tOther, {"Comment": "x"}, .tAnswer), 404, "the person's change of a third spelling is refused")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.usericons", "remove", tIconOther, "", .tAnswer), 404, "and the person's removal of an icon")
    Do ..MintRefused($Piece(..#TOOLS, ",", 2), {"Name": (tOther), "Comment": "x"}.%ToJSON(), "0|400", "the agent's change of a third spelling is refused at the mint")
    Do ..MintRefused($Piece(..#TOOLS, ",", 5), {"Name": (tIconOther), "Path": "x"}.%ToJSON(), "0|400", "and its icon change")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBaseUpper = $ClassMethod(..#WRITE, "Rows", tSince, "analytics-runtime-variable", tUpper, "analytics.runtimevariables.remove", 0)
    Set tBaseLower = $ClassMethod(..#WRITE, "Rows", tSince, "analytics-runtime-variable", tLower, "analytics.runtimevariables.remove", 0)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "remove", tUpper, "", .tRemoved), 200, "the person removes the upper-case variable")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Variable", tUpper) _ "|" _ $ClassMethod(..#WRITE, "Variable", tLower), "0||||1|2|lower2|l", "the lower-case one is still held")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Rows", tSince, "analytics-runtime-variable", tUpper, "analytics.runtimevariables.remove", tBaseUpper), 1, "one ConfigChange row names the spelling removed")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Rows", tSince, "analytics-runtime-variable", tLower, "analytics.runtimevariables.remove", tBaseLower), 0, "and none names the other")
    Do $$$AssertEquals(..Call("UserIcons", "ENTRYREMOVE", tIconLower, {}), "200 ", "the lower-case icon is removed")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", tIconUpper) _ "|" _ $ClassMethod(..#WRITE, "Icon", tIconLower), "1|/U.png|0|", "and the upper-case one is still held")
}

/// <p>A path is text. Paths a renderer could turn into an image or a link or that name a local file (a URL with markup and a query, a local file path, a <code>file:</code> and a <code>javascript:</code> and a
/// <code>data:</code> reference, a Windows path with backslashes) are each stored exactly as sent, answered by the screen's read and the agent's tool as a string of that text, and kept out of the audit row, which
/// names the icon only.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.TextOr</method> trim the path to its first word -- the stored-text legs go red.</p>
Method TestAnIconPathThatLooksLikeAReferenceIsStoredAndShownAsText()
{
    Set tPaths = $ListBuild("http://ocuprobe2413.invalid/i.png?a=1&b=<b>x</b>", "/etc/passwd", "file:///etc/hosts", "javascript:alert(1)", "data:image/svg+xml,<svg onload=alert(1)>", "C:\ocuprobe2413\i.png")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tAt = 1:1:$ListLength(tPaths) {
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", ..#ICON _ tAt, {"Path": ($List(tPaths, tAt))}), "200 ", "path " _ tAt _ " is added")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", ..#ICON _ tAt), "1|" _ $List(tPaths, tAt), "path " _ tAt _ " is held exactly as sent")
    }
    Set tRows = $ClassMethod(..#SETTINGS, "ScreenRows", "analytics.usericons")
    For tAt = 1:1:$ListLength(tPaths) {
        Set tRow = $ClassMethod(..#SETTINGS, "RowWhere", tRows, "Name", ..#ICON _ tAt)
        Do $$$AssertTrue($IsObject(tRow) && (tRow.%GetTypeOf("Path") = "string") && (tRow.Path = $List(tPaths, tAt)), "the screen shows path " _ tAt _ " as the string it was sent")
        Set tToolRow = $ClassMethod(..#SETTINGS, "ToolRow", "analytics.usericons.read", "Name", ..#ICON _ tAt)
        Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.%GetTypeOf("Path") = "string") && (tToolRow.Path = $List(tPaths, tAt)), "and the agent's read tool answers it as that string")
    }
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.usericons", "set", ..#ICON _ 1, {"Path": "javascript:alert(2)"}, .tAnswer), 200, "a change to a script reference is stored too")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Icon", ..#ICON _ 1), "1|javascript:alert(2)", "as the text it is")
    Set tCount = $ClassMethod(..#WRITE, "Rows", tSince, "analytics-user-icon", ..#ICON _ 2, "analytics.usericons.add", 0, .tData)
    Do $$$AssertTrue((tCount = 1) && (tData [ ..#ICON _ 2) && (tData '[ "/etc/passwd"), "the audit row names the icon and never its path: " _ tData)
}

/// <p>The agent's mint is refused what the screen is refused for the shape of the text: an expression, comment or context that is not a string, holds a control character (a line break included, so an expression is
/// one line) or is 2001 characters, and a path that is not a string, is refused 400 <code>ANALYTICS.SETTING.TEXT</code> by the port's add and change, 400 by the person's save and change, and 400 at the mint, each
/// with nothing written. The agent's call of each of the six tools with an empty name is 400 <code>TOOL.ARGUMENTS</code> from the tool's own entry point, before the mint.</p>
/// <p>Mutation (Rule 19): drop the control-character test from <method>OcuPilot.Port.AnalyticsPort.SettingTextShaped</method> -- the line-break and control legs go red.</p>
Method TestTheAgentsMintRefusesTheTextTheScreenRefuses()
{
    Set tLong = $Translate($Justify("", 2001), " ", "x")
    Set tCases = $ListBuild($ListBuild("Value", {"Value": 5}.%ToJSON()), $ListBuild("Value", {"Value": ("1" _ $Char(10) _ "Kill ^OcuProbe2413Ran")}.%ToJSON()), $ListBuild("Value", {"Value": (tLong)}.%ToJSON()), $ListBuild("Comment", {"Comment": ("a" _ $Char(9))}.%ToJSON()), $ListBuild("Comment", {"Comment": 7}.%ToJSON()), $ListBuild("Context", {"Context": (tLong)}.%ToJSON()), $ListBuild("Context", {"Context": ("a" _ $Char(13))}.%ToJSON()))
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "ctx")
    Do $ClassMethod(..#WRITE, "Seed", 1, ..#ICON, "/kept.png")
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2))
        Set tLabel = "the " _ $List(tCase, 1) _ " case " _ tAt
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYADD", "OcuProbe2413Text", tBody), "400 ANALYTICS.SETTING.TEXT", tLabel _ ": the port's add refuses it")
        Do $$$AssertEquals(..Call("RuntimeVariables", "ENTRYSET", ..#VARIABLE, tBody), "400 ANALYTICS.SETTING.TEXT", tLabel _ ": and its change")
        Set tSave = {"Name": "OcuProbe2413Text"}
        Do tSave.%Set($List(tCase, 1), tBody.%Get($List(tCase, 1)), tBody.%GetTypeOf($List(tCase, 1)))
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Post", "/analytics/runtime-variables", tSave, .tAnswer), 400, tLabel _ ": the person's save refuses it")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", ..#VARIABLE, tBody, .tAnswer), 400, tLabel _ ": and the person's change")
        Set tMint = ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2))
        Do tMint.%Set("Name", "OcuProbe2413Text", "string")
        Do ..MintRefused($Piece(..#TOOLS, ",", 1), tMint.%ToJSON(), "0|400", tLabel _ ": the agent's add is refused at the mint")
    }
    Set tPathCases = $ListBuild({"Path": 5}.%ToJSON(), {"Path": ("/a" _ $Char(10))}.%ToJSON(), {"Path": (tLong)}.%ToJSON())
    For tAt = 1:1:$ListLength(tPathCases) {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON($List(tPathCases, tAt))
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYADD", "OcuProbe2413TextIcon", tBody), "400 ANALYTICS.SETTING.TEXT", "path case " _ tAt _ ": the port's add refuses it")
        Do $$$AssertEquals(..Call("UserIcons", "ENTRYSET", ..#ICON, tBody), "400 ANALYTICS.SETTING.TEXT", "path case " _ tAt _ ": and its change")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.usericons", "set", ..#ICON, tBody, .tAnswer), 400, "path case " _ tAt _ ": and the person's change")
        Set tMint = ##class(%DynamicAbstractObject).%FromJSON($List(tPathCases, tAt))
        Do tMint.%Set("Name", ..#ICON, "string")
        Do ..MintRefused($Piece(..#TOOLS, ",", 5), tMint.%ToJSON(), "0|400", "path case " _ tAt _ ": the agent's change is refused at the mint")
    }
    For tAt = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tAt)
        Kill tHttp, tFault
        Set tSC = $ClassMethod(tTool, "View", $Parameter(tTool, "DESCRIPTORCLASS"), {"Name": ""}, 0, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", "the agent's call of " _ tTool _ " with an empty name is refused before the mint")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "nothing was written by any of them")
}

/// <p>The agent's confirm of each write, minted while the namespace's settings lock was free, is refused 409 <code>WRITE.TARGETBUSY</code> while another process holds the lock, and writes nothing: a variable add,
/// change and removal and an icon add and change (the removal's key is turned on for the test).</p>
/// <p>Mutation (Rule 19): drop the <code>Lock</code> from <method>OcuPilot.Port.AnalyticsPort.InvokeSetting</method> -- the held legs go red.</p>
Method TestAnAgentsConfirmIsRefusedWhileTheLockIsHeld()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Kill tSettings
    Set tSettings("analytics.runtimevariables.remove") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the variable removal's key is turned on")
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE, "1", "kept", "")
    Do $ClassMethod(..#WRITE, "Seed", 0, ..#VARIABLE _ "Gone", "1", "", "")
    Do $ClassMethod(..#WRITE, "Seed", 1, ..#ICON, "/kept.png")
    Set tArgs(1) = {"Name": (..#VARIABLE _ "Busy"), "Value": "1"}.%ToJSON()
    Set tArgs(2) = {"Name": (..#VARIABLE), "Comment": "busy"}.%ToJSON()
    Set tArgs(3) = {"Name": (..#VARIABLE _ "Gone")}.%ToJSON()
    Set tArgs(4) = {"Name": (..#ICON _ "Busy"), "Path": "/busy.png"}.%ToJSON()
    Set tArgs(5) = {"Name": (..#ICON), "Path": "/busy.png"}.%ToJSON()
    For tAt = 1:1:5 {
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", $Piece(..#TOOLS, ",", tAt), ##class(%DynamicAbstractObject).%FromJSON(tArgs(tAt)), tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($IsObject($Get(tProposal)), "write " _ tAt _ " is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        Set tId(tAt) = $Select($IsObject($Get(tProposal)): tProposal.proposalId, 1: "")
        Set tTurns(tAt) = $Get(tTurn)
    }
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    Lock +^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE):0
    Do $$$AssertTrue($Test, "this process took the namespace's settings lock")
    For tAt = 1:1:5 {
        If tId(tAt) = "" Continue
        Do $ClassMethod(..#CONTROL, "ConfirmHttp", tId(tAt), .tStatus, .tRaw, .tConfirmed)
        Set tAnswer(tAt) = tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: "")
    }
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    For tAt = 1:1:5 {
        Do $$$AssertEquals($Get(tAnswer(tAt)), "409|WRITE.TARGETBUSY", "the agent's write " _ tAt _ " is refused while the lock is held: " _ $Get(tAnswer(tAt)))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "and nothing was written")
    For tAt = 1:1:5 {
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurns(tAt)))
    }
}

}
