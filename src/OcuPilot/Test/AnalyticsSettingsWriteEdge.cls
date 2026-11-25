/// <p>Pins the edges of Story 24.13's General and Worklists writes against <code>USER</code> (AD-8, AD-29, AD-34, AD-55, AD-65): a value a setting does not accept, a setting the page does not
/// have and the Google Maps key through the plain set are each refused with nothing written, by the port and by the person's action; worklists that are not customized and a worklist the page does
/// not list are refused for show and hide; a second writer while the namespace's lock is held is refused and the first one applied; a proposal minted before the setting changed is closed as moved;
/// a read-only settings database, a caller without the developer pair and a namespace without analytics are refused before any vendor call, which
/// <class>OcuPilot.Test.AnalyticsGateSeam</class> arms a failure behind. A refused key write carries no key in any answer, store or audit row; the agent's mint refuses what the screen's action refuses; every write
/// takes the namespace's lock; a write of one kind keeps what a write of another kind stored; and a key the agent sends to the plain set is redacted from its ledger row and step.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.AnalyticsSettingsWrite</class>. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsWriteEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsSettingsDatabaseSeam";

Parameter WRITE = "OcuPilot.Test.AnalyticsSettingsWrite";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter RECENT = "%DeepSee.UserPortal.RecentList";

Parameter SETTOOL = "OcuPilot.Screen.Tool.AnalyticsSettingSet";

Parameter KEYTOOL = "OcuPilot.Screen.Tool.AnalyticsSettingKey";

Parameter SHOWTOOL = "OcuPilot.Screen.Tool.AnalyticsWorklistShow";

Parameter HIDETOOL = "OcuPilot.Screen.Tool.AnalyticsWorklistHide";

Parameter KEYMARKER = "OcuProbe2413EdgeKey";

Property StartDigest As %String;

Property StartTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWriteEdge turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWriteEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWriteEdge left USER's analytics settings changed")
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
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>The call <var>pType</var> on <var>pEndpoint</var> for the id <var>pId</var> with the body <var>pBody</var> through the port, as <code>&lt;http&gt; &lt;code&gt;</code>.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject = "", pAction As %String = "", pSeam As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(pSeam, "Invoke", pEndpoint, pType, .tQuery, pBody, .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ $Select($IsObject(tFault.%Get("detail")): " " _ tFault.detail.%Get("failedPair"), 1: ""), 1: "")
}

/// <p>AC1, AC2: a value a setting does not accept is refused 400 <code>CONFIG.SETTING.VALUE</code> and nothing is written, by the port and by the person's action; a name the page does not have is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>; the Google Maps key through the plain set is 409 <code>ANALYTICS.SETTING.SECRET</code>, and a key through another setting's write is 404.</p>
/// <p>Mutation (Rule 19): skip <code>ValueHolds</code> in <method>OcuPilot.Port.AnalyticsPort.SendSetting</method> -- the value legs go red.</p>
Method TestARefusedSettingWritesNothing()
{
    Set tBefore = $ClassMethod(..#PROBE, "SettingsDigest")
    Set tLong = $Translate($Justify("", 2001), " ", "x")
    For tCase = $ListBuild("Scheme", "NoSuchScheme"), $ListBuild("MailEnabled", "3"), $ListBuild("DashboardNoTitle", "2"), $ListBuild("PageTitle", tLong), $ListBuild("PageTitle", "a" _ $Char(7) _ "b"), $ListBuild("Worklist", "x"), $ListBuild("ChartSeriesScheme", "nosuchseries") {
        Do $$$AssertEquals(..Call("Settings", "SETTINGSET", $List(tCase, 1), {"Value": ($List(tCase, 2))}), "400 CONFIG.SETTING.VALUE", $List(tCase, 1) _ ": the port refuses a value it does not accept")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", $List(tCase, 1), {"Value": ($List(tCase, 2))}, .tAnswer), 400, $List(tCase, 1) _ ": and so does the person's action")
        If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("code"), "CONFIG.SETTING.VALUE", $List(tCase, 1) _ ": with the setting's own sentence")
    }
    Do $$$AssertEquals(..Call("Settings", "SETTINGSET", "Nosuch", {"Value": "x"}), "404 CONFIG.SETTING.NOTFOUND", "a setting the page does not have is refused")
    Do $$$AssertEquals(..Call("Settings", "SETTINGSET", "GoogleMapsKey", {"Value": "x"}), "409 ANALYTICS.SETTING.SECRET", "the key through the plain set is refused as a secret")
    Do $$$AssertEquals(..Call("Settings", "SETTINGKEY", "PageTitle", {"GoogleMapsKey": "x"}), "404 CONFIG.SETTING.NOTFOUND", "another setting through the key's write is refused")
    Do $$$AssertEquals(..Call("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": (tLong)}), "400 CONFIG.SETTING.VALUE", "a key over the limit is refused")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "GoogleMapsKey", {"Value": "x"}, .tKeyAnswer), 409, "and the person's plain set of the key is refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tBefore, "nothing was written by any of them")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.AnalyticsSettingSet", {"Name": "Scheme", "Value": "NoSuchScheme"}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tHttp), "0|400", "the agent's mint of the same value is refused")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.AnalyticsSettingSet", {"Name": "GoogleMapsKey", "Value": "x"}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "0|409|ANALYTICS.SETTING.SECRET", "and the agent's mint of the key through the plain set is refused as a secret")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC6: with the worklists not customized every Worklists row reads <code>Customized</code> false, and a show or a hide is refused 409 <code>ANALYTICS.WORKLIST.NOTCUSTOMIZED</code> by the port, by the
/// person's action and at the agent's mint, with nothing written; a worklist the page does not list is 404 <code>ANALYTICS.WORKLIST.ABSENT</code>; after the worklists are customized a show and a hide succeed,
/// and the same twice succeed again.</p>
/// <p>Mutation (Rule 19): drop the <code>Customized</code> refusal from <method>OcuPilot.Port.AnalyticsPort.JudgeSetting</method> -- the refusal legs go red.</p>
Method TestWorklistsThatAreNotCustomizedRefuseShowAndHide()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Set tRows = $ClassMethod(..#WRITE, "ScreenRows", "analytics.worklists")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 16), "the Worklists screen reads its sixteen rows")
    Set tCustomized = 0
    If $IsObject(tRows) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tCustomized = tCustomized + tRow.Customized
        }
    }
    Do $$$AssertEquals(tCustomized, 0, "every row says the worklists are not customized")
    Do $$$AssertEquals(..Call("Worklists", "WORKLISTSHOW", tId), "409 ANALYTICS.WORKLIST.NOTCUSTOMIZED", "the port refuses a show")
    Do $$$AssertEquals(..Call("Worklists", "WORKLISTHIDE", tId), "409 ANALYTICS.WORKLIST.NOTCUSTOMIZED", "and a hide")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.worklists", "show", tId, {}, .tAnswer), 409, "the person's Show is refused")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("code"), "ANALYTICS.WORKLIST.NOTCUSTOMIZED", "with its sentence")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.AnalyticsWorklistShow", {"Page": "Home", "Panel": "1", "Class": (..#RECENT)}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "0|409|ANALYTICS.WORKLIST.NOTCUSTOMIZED", "and the agent's mint is refused")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do $$$AssertEquals(..Call("Worklists", "WORKLISTSHOW", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, "%Nosuch.List"))), "404 ANALYTICS.WORKLIST.ABSENT", "a worklist the page does not list is absent")
    Do $$$AssertEquals(..Call("Worklists", "WORKLISTSHOW", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 3, ..#RECENT))), "404 ANALYTICS.WORKLIST.ABSENT", "and so is a panel it does not have")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "Worklist,Home,1,2"), "0|", "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "Worklist", {"Value": "1"}, .tCustom), 200, "the worklists are customized")
    For tTwice = 1, 2 {
        Do $$$AssertEquals(..Call("Worklists", "WORKLISTSHOW", tId), "200 ", "a show succeeds, the " _ tTwice _ " time")
    }
    For tTwice = 1, 2 {
        Do $$$AssertEquals(..Call("Worklists", "WORKLISTHIDE", tId), "200 ", "a hide succeeds, the " _ tTwice _ " time")
    }
}

/// <p>The Edge row "two writers": while another process holds the namespace's settings lock, a person's set is refused 409 <code>WRITE.TARGETBUSY</code> after the wait and writes nothing; once the lock is
/// released the same set applies. The lock is held by this process, and the request is served by another.</p>
/// <p>Mutation (Rule 19): drop the <code>Lock</code> from <method>OcuPilot.Port.AnalyticsPort.InvokeSetting</method> -- the refusal leg goes red.</p>
Method TestASecondWriterIsRefusedWhileTheLockIsHeld()
{
    Lock +^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE):0
    Do $$$AssertTrue($Test, "this process took the namespace's settings lock")
    Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 Busy"}, .tAnswer)
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", "the second writer is refused while the lock is held")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "PageTitle"), "0|", "and nothing was written")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 Free"}, .tFree), 200, "once released the write applies")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "PageTitle"), "1|OcuProbe2413 Free", "and the vendor holds it")
}

/// <p>The Edge row "stale": a proposal minted before the setting changed is closed as moved when it is confirmed after, whether the setting was unstored at the mint and is stored now or held another value;
/// nothing the proposal would have written is written.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.AnalyticsSettingSet.GUARDMOVED</parameter> 0, so <method>OcuPilot.Screen.Tool.ConfigSettingSet.MergeUpdate</method> adds no <code>Was</code> -- the second leg goes red.</p>
Method TestAProposalMintedBeforeTheSettingChangedIsClosedAsMoved()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.AnalyticsSettingSet", {"Name": "PageTitle", "Value": "OcuProbe2413 Stale"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's set is minted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 Person"}, .tAnswer), 200, "the person sets another value, which stores every row")
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is closed as moved")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "PageTitle"), "1|OcuProbe2413 Person", "and the person's value stands")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.AnalyticsSettingSet", {"Name": "PageTitle", "Value": "OcuProbe2413 Stale 2"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 Person 2"}, .tAnswer), 200, "the person sets the stored value to another")
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm of a proposal that read the old value is closed as moved")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "PageTitle"), "1|OcuProbe2413 Person 2", "and the person's second value stands")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5: the baseline ships the four settings keys on (none of the four is destructive), so the governance gate allows the agent's call of each, and every one of them is a write the registry
/// declares against <code>AnalyticsPort</code> and the classic Settings page.</p>
/// <p>Mutation (Rule 19): flip one of the four lines of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>false</code> -- the gate leg goes red naming it.</p>
Method TestTheBaselineShipsTheFourKeysOn()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tStored), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tStored), "and leaves every key to the baseline")
    For tTool = "OcuPilot.Screen.Tool.AnalyticsSettingSet", "OcuPilot.Screen.Tool.AnalyticsSettingKey", "OcuPilot.Screen.Tool.AnalyticsWorklistShow", "OcuPilot.Screen.Tool.AnalyticsWorklistHide" {
        Set tName = $Parameter(tTool, "TOOLNAME")
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(tName, "write", $Username, {}, .tDecision), tName _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")), 1, tName _ ": the baseline allows it")
        Do $$$AssertEquals($Parameter(tTool, "PORTCLASS") _ "|" _ $Parameter(tTool, "CLASSICPAGES") _ "|" _ ($Parameter(tTool, "DESTRUCTIVE") + 0), "OcuPilot.Port.AnalyticsPort|%DeepSee.UI.Settings|0", tName _ ": declares the analytics port and the classic page, and is not destructive")
    }
}

/// <p>The gate: a read-only database that holds the settings refuses each of the four writes 409 <code>ANALYTICS.SETTING.READONLY</code> before any vendor call, also for the read composed for it; a caller
/// holding only the portal's pair is refused 403 naming <code>%Development:USE</code>; a namespace that does not report analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>. Each is answered while a vendor failure
/// is armed on the gate seam, so a vendor call before the gate would answer 500.</p>
/// <p>Mutation (Rule 19): drop the settings branch from <method>OcuPilot.Port.AnalyticsPort.Admit</method> -- the read-only leg goes red.</p>
Method TestTheGateRefusesBeforeAnyVendorCall()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    Do $ClassMethod(..#SEAM, "Arm", "sdatabase", "readonly")
    For tPair = $ListBuild("%DeepSee_Portal", "USE"), $ListBuild("%Development", "USE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    For tCase = $ListBuild("Settings", "SETTINGSET", "PageTitle", {"Value": "x"}), $ListBuild("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": "x"}), $ListBuild("Worklists", "WORKLISTSHOW", tId, {}), $ListBuild("Worklists", "WORKLISTHIDE", tId, {}) {
        Set tAnswer = ..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), "", ..#SEAM)
        Do $$$AssertEquals(tAnswer, "409 ANALYTICS.SETTING.READONLY", $List(tCase, 2) _ ": a read-only settings database is refused: " _ tAnswer)
    }
    Set tAnswer = ..Call("Settings", "SETTING", "PageTitle", "", "SETTINGSET", ..#SEAM)
    Do $$$AssertEquals(tAnswer, "409 ANALYTICS.SETTING.READONLY", "and so is the read composed for a set: " _ tAnswer)
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    For tCase = $ListBuild("Settings", "SETTINGSET", "PageTitle", {"Value": "x"}), $ListBuild("Worklists", "WORKLISTSHOW", tId, {}) {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Do $$$AssertEquals(..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), "", ..#SEAM), "403 AUTH.NOPRIVILEGE %Development:USE", $List(tCase, 2) _ ": without the developer pair the write is refused, naming the pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tQuery("id") = $List(tCase, 3)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, $List(tCase, 4), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", $List(tCase, 2) _ ": a namespace without analytics is refused")
    }
}

/// <p>The port's answer to the call as the wire text of its refusal, <code>""</code> for an answer: the status in <var>pHttp</var>, the fault's code in <var>pCode</var>.</p>
ClassMethod Fault(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, pSeam As %String = {..#PORT}, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(pSeam, "Invoke", pEndpoint, pType, .tQuery, pBody, .tResult, .pHttp, .tFault)
    Set pCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "")
}

/// <p>Everything the proposal <var>pProposalId</var> and the turn <var>pTurn</var> keep: the proposal's three streams and its row, and the turn's ledger rows.</p>
ClassMethod StoredText(pProposalId As %String, pTurn As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pProposalId)
    If (tRS.%SQLCODE = 0) && tRS.%Next() {
        Set tStored = ##class(OcuPilot.Kernel.State.Propose).%OpenId(tRS.%GetData(1))
        If $IsObject(tStored) Set tText = tStored.Arguments.Read(32000) _ "|" _ tStored.Payload.Read(32000) _ "|" _ tStored.Diff.Read(32000)
    }
    Quit tText _ $ClassMethod(..#WRITE, "RowText", "SELECT * FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pProposalId) _ $ClassMethod(..#WRITE, "RowText", "SELECT * FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurn)
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> is refused: <var>pExpect</var> reads <code>proposal|status|code</code>. What the refusal says is added to <var>pSaid</var>.</p>
Method MintRefused(pTool As %String, pArgs As %DynamicObject, pExpect As %String, pLabel As %String, ByRef pSaid As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), pExpect, pLabel)
    If $IsObject($Get(tFault)) Set pSaid = $Get(pSaid) _ tFault.%ToJSON()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>A key write that is refused says nothing of the key, and writes nothing: a key over the limit or with a control character is 400 <code>CONFIG.SETTING.VALUE</code> from the port and from the person's
/// action; a read-only settings database, a caller without the developer pair and a namespace without analytics refuse it before any vendor call; the agent's confirm with a key over the limit is refused
/// the same way. The key's text is in no answer, no stored proposal, no ledger row and no audit row, and no <code>ConfigChange</code> row is added.</p>
/// <p>Mutation (Rule 19): put the value into the reason of <method>OcuPilot.Port.AnalyticsPort.SendSetting</method>'s value refusal -- the leg that finds the key in no refusal goes red.</p>
Method TestARefusedKeyWriteSaysNothingOfTheKey()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tDigest = $ClassMethod(..#PROBE, "SettingsDigest")
    Set tBase = $ClassMethod(..#WRITE, "Base", tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey")
    Set tLong = ..#KEYMARKER _ $Translate($Justify("", 2001), " ", "x")
    Set tSaid = ""
    For tKey = tLong, (..#KEYMARKER _ $Char(7)) {
        Set tSaid = tSaid _ ..Fault("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": (tKey)}, .tHttp, .tCode)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "400 CONFIG.SETTING.VALUE", "the port refuses a key it does not accept")
        Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": (tKey)}, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400|CONFIG.SETTING.VALUE", "and so does the person's action")
        If $IsObject(tAnswer) Set tSaid = tSaid _ tAnswer.%ToJSON()
    }
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    Do $ClassMethod(..#SEAM, "Arm", "sdatabase", "readonly")
    For tPair = $ListBuild("%DeepSee_Portal", "USE"), $ListBuild("%Development", "USE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Set tSaid = tSaid _ ..Fault("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER)}, .tHttp, .tCode, ..#SEAM)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 ANALYTICS.SETTING.READONLY", "a read-only settings database refuses the key")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Set tSaid = tSaid _ ..Fault("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER)}, .tHttp, .tCode, ..#SEAM)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 AUTH.NOPRIVILEGE", "a caller without the developer pair is refused")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSaid = tSaid _ ..Fault("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER)}, .tHttp, .tCode, ..#SEAM, "HSCUSTOM")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")

    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#KEYTOOL, {"Name": "GoogleMapsKey"}, $Username, .tProposal, .tMintHttp, .tMintFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's key proposal is minted")
    If $IsObject($Get(tProposal)) {
        Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), {"GoogleMapsKey": (tLong)}, $Username, .tConfirmed, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "400 CONFIG.SETTING.VALUE", "the agent's confirm with a key over the limit is refused")
        If $IsObject($Get(tDetail)) Set tSaid = tSaid _ tDetail.%ToJSON()
        If $IsObject($Get(tConfirmed)) Set tSaid = tSaid _ tConfirmed.%ToJSON()
        Set tStored = ..StoredText(tProposal.%Get("proposalId"), tTurn)
        Do $$$AssertTrue(tStored [ "GoogleMapsKey", "the stored proposal and the turn's ledger rows were read")
        Do $$$AssertTrue(tStored '[ ..#KEYMARKER, "the key's text is in neither")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertTrue(tSaid '[ ..#KEYMARKER, "the key's text is in no refusal")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "GoogleMapsKey"), "0|", "no key was stored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tDigest, "and nothing else was written")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Added", tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey", tBase, .tData), 0, "no ConfigChange row names a key write")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", ..#KEYMARKER, .tNone), 0, "and no audit row carries the key")
}

/// <p>The agent's mint refuses what the screen's action refuses, with nothing written and no key in what it says: a value of the wrong kind or length, a control character, a setting the page does not have, the key's tool
/// aimed at another setting, sent the key, or called (through its <method>View</method>, the model's one entry) with an argument it does not declare, and a worklist that does not exist or, for a hide, is not customized; the screen's Hide while the worklists are not customized is 409
/// <code>ANALYTICS.WORKLIST.NOTCUSTOMIZED</code> and its Show of a worklist the page does not list is 404 <code>ANALYTICS.WORKLIST.ABSENT</code>.</p>
/// <p>Mutation (Rule 19): empty <method>OcuPilot.Screen.Tool.AnalyticsSettingKey.PortQuery</method> -- the key tool's aimed-at-another-setting leg goes red.</p>
Method TestTheAgentsMintRefusesWhatTheScreenRefusesToo()
{
    Set tDigest = $ClassMethod(..#PROBE, "SettingsDigest")
    Set tSaid = ""
    Set tRefused = "0|400|TOOL.ARGUMENTS"
    Do ..MintRefused(..#SETTOOL, {"Name": "PageTitle", "Value": ($Translate($Justify("", 2001), " ", "x"))}, tRefused, "a text over the limit is refused at the mint", .tSaid)
    Do ..MintRefused(..#SETTOOL, {"Name": "PageTitle", "Value": ("a" _ $Char(7) _ "b")}, tRefused, "a control character is refused at the mint", .tSaid)
    Do ..MintRefused(..#SETTOOL, {"Name": "MailEnabled", "Value": "3"}, tRefused, "a choice outside its list is refused at the mint", .tSaid)
    Do ..MintRefused(..#SETTOOL, {"Name": "DashboardNoTitle", "Value": "2"}, tRefused, "a boolean that is neither 0 nor 1 is refused at the mint", .tSaid)
    Do ..MintRefused(..#SETTOOL, {"Name": "Worklist", "Value": "x"}, tRefused, "the Worklists flag takes 0 or 1", .tSaid)
    Do ..MintRefused(..#SETTOOL, {"Name": "Nosuch", "Value": "x"}, tRefused, "a setting the page does not have is refused at the mint", .tSaid)
    Do ..MintRefused(..#KEYTOOL, {"Name": "PageTitle"}, tRefused, "the key's tool aimed at another setting is refused", .tSaid)
    Do ..MintRefused(..#KEYTOOL, {"Name": "GoogleMapsKey", "GoogleMapsKey": (..#KEYMARKER)}, tRefused, "a key sent to the key's tool is refused", .tSaid)
    Set tSC = $ClassMethod(..#KEYTOOL, "View", "", {"Name": "GoogleMapsKey", "Value": (..#KEYMARKER)}, 0, .tViewed, .tViewHttp, .tViewFault)
    Do $$$AssertEquals($IsObject($Get(tViewed)) _ "|" _ $Get(tViewHttp) _ "|" _ $Select($IsObject($Get(tViewFault)): tViewFault.%Get("code"), 1: ""), tRefused, "the key's tool refuses an argument it does not declare, so no key can sit in a stored proposal")
    If $IsObject($Get(tViewFault)) Set tSaid = tSaid _ tViewFault.%ToJSON()
    Do ..MintRefused(..#SHOWTOOL, {"Page": "Home", "Panel": "1", "Class": "%Nosuch.List"}, tRefused, "a worklist the page does not list is refused for a show", .tSaid)
    Do ..MintRefused(..#HIDETOOL, {"Page": "Home", "Panel": "3", "Class": (..#RECENT)}, tRefused, "and a panel it does not have for a hide", .tSaid)
    Do ..MintRefused(..#HIDETOOL, {"Page": "Home", "Panel": "1", "Class": (..#RECENT)}, "0|409|ANALYTICS.WORKLIST.NOTCUSTOMIZED", "a hide while the worklists are not customized is refused at the mint", .tSaid)
    Do $$$AssertTrue(tSaid '[ ..#KEYMARKER, "no refusal repeats the key sent to the key's tool")
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.worklists", "hide", tId, {}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|ANALYTICS.WORKLIST.NOTCUSTOMIZED", "the person's Hide is refused while the worklists are not customized")
    Set tAbsent = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, "%Nosuch.List"))
    Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.worklists", "show", tAbsent, {}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404|ANALYTICS.WORKLIST.ABSENT", "and a Show of a worklist the page does not list is absent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tDigest, "nothing was written")
}

/// <p>Every write takes the namespace's lock: while another process holds it the key, a show, a hide and the Worklists flag are each refused 409 <code>WRITE.TARGETBUSY</code> with nothing written, no audit row and
/// no key in the answer; once it is released a show applies.</p>
/// <p>Mutation (Rule 19): refuse a busy lock only for the plain set in <method>OcuPilot.Port.AnalyticsPort.InvokeSetting</method> -- the key, show and hide legs go red.</p>
Method TestEveryWriteIsRefusedWhileTheLockIsHeld()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "Worklist", {"Value": "1"}, .tCustom), 200, "the worklists are customized")
    Set tDigest = $ClassMethod(..#PROBE, "SettingsDigest")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKeyBase = $ClassMethod(..#WRITE, "Base", tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey")
    Set tShowBase = $ClassMethod(..#WRITE, "Base", tSince, "analytics-worklist", tId, "analytics.worklists.show")
    Set tHideBase = $ClassMethod(..#WRITE, "Base", tSince, "analytics-worklist", tId, "analytics.worklists.hide")
    Set tSaid = ""
    Lock +^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE):0
    Do $$$AssertTrue($Test, "this process took the namespace's settings lock")
    For tCase = $ListBuild("analytics.settings", "setkey", "GoogleMapsKey", "{""GoogleMapsKey"":""" _ ..#KEYMARKER _ """}"), $ListBuild("analytics.worklists", "show", tId, "{}"), $ListBuild("analytics.worklists", "hide", tId, "{}"), $ListBuild("analytics.settings", "set", "Worklist", "{""Value"":""0""}") {
        Set tStatus = $ClassMethod(..#WRITE, "Act", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicObject).%FromJSON($List(tCase, 4)), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|WRITE.TARGETBUSY", $List(tCase, 2) _ ": refused while the lock is held")
        If $IsObject(tAnswer) Set tSaid = tSaid _ tAnswer.%ToJSON()
    }
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do $$$AssertTrue(tSaid '[ ..#KEYMARKER, "the key's text is in no busy answer")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), tDigest, "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Added", tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey", tKeyBase, .tData), 0, "no key row was audited")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Added", tSince, "analytics-worklist", tId, "analytics.worklists.show", tShowBase, .tData), 0, "no show was audited")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Added", tSince, "analytics-worklist", tId, "analytics.worklists.hide", tHideBase, .tData), 0, "no hide was audited")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.worklists", "show", tId, {}, .tFree), 200, "once released a show applies")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "Worklist,Home,1,2"), "1|" _ ..#RECENT, "and the vendor holds the option")
}

/// <p>Two writes in a row lose neither change, whatever their kind: with the worklists customized and an option shown, a General set keeps the flag and the option; the key's write keeps them and the title;
/// a hide and a General set after it keep the flag, the title and the key, and the option stays hidden.</p>
/// <p>Mutation (Rule 19): kill the <code>Worklist</code> node after the save in <method>OcuPilot.Port.AnalyticsPort.SettingsSaveHere</method> -- the first leg goes red.</p>
Method TestWritesOfDifferentKindsKeepEachOthersChanges()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Set tFlagAndOption = "1|1|1|" _ ..#RECENT
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "Worklist", {"Value": "1"}, .tAnswer), 200, "the worklists are customized")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.worklists", "show", tId, {}, .tAnswer), 200, "an option is shown")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 Kinds"}, .tAnswer), 200, "a General set follows")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "Worklist") _ "|" _ $ClassMethod(..#WRITE, "Node", "Worklist,Home,1,2"), tFlagAndOption, "it keeps the Worklists flag and the shown option")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER)}, .tAnswer), 200, "the key's write follows")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "Worklist") _ "|" _ $ClassMethod(..#WRITE, "Node", "Worklist,Home,1,2") _ "|" _ $ClassMethod(..#WRITE, "Node", "PageTitle"), tFlagAndOption _ "|1|OcuProbe2413 Kinds", "it keeps the flag, the option and the title")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.worklists", "hide", tId, {}, .tAnswer), 200, "a hide follows")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.settings", "set", "CompanyName", {"Value": "OcuProbe2413 Co"}, .tAnswer), 200, "and another General set")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "Worklist"), "1|1", "the flag is kept")
    Do $$$AssertEquals($Piece($ClassMethod(..#WRITE, "Node", "Worklist,Home,1,2"), "|", 1), 0, "the option stays hidden")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Node", "PageTitle") _ "|" _ $ClassMethod(..#WRITE, "Node", "GoogleMapsKey") _ "|" _ $ClassMethod(..#WRITE, "Node", "CompanyName"), "1|OcuProbe2413 Kinds|1|" _ ..#KEYMARKER _ "|1|OcuProbe2413 Co", "and the title, the key and the company name are each kept")
}

/// <p>Dispatched through the agent's tool loop, a set the agent sends for the Google Maps key, under its own name or another spelling of it, is refused, and neither its ledger row nor its step carries
/// the value, which reads as the redaction mark; a value sent for a setting the page does not have is kept in both.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Screen.Tool.AnalyticsSettingSet.CallSecretNames</method> -- the key's ledger and step legs go red.</p>
Method TestAKeyTheAgentSendsToTheSetIsRedactedInTheLedgerRowAndTheStep()
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tWire = ##class(OcuPilot.Screen.Tool.Registry).WireName("analytics.settings.set")
    For tCase = $ListBuild("GoogleMapsKey", ..#KEYMARKER _ "Sent", 1), $ListBuild("googlemapskey", ..#KEYMARKER _ "Case", 1), $ListBuild("Nosuch", "OcuProbe2413Plain", 0) {
        Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
        Set tUse = {"id": "toolu_analyticssetting"}
        Do tUse.%Set("name", tWire, "string")
        Do tUse.%Set("input", {"Name": ($List(tCase, 1)), "Value": ($List(tCase, 2)), "rationale": "probe", "expectedImpact": "probe"})
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tKey, $Username, "1", tUses, "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, , , .tDetails, "")
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the dispatcher answers the call")
        Do $$$AssertEquals(tResults.%Size() _ "|" _ tResults.%Get(0).%Get("is_error"), "1|1", $List(tCase, 1) _ ": the call is refused")
        Set tText = ##class(OcuPilot.Test.Ledger).RowText(tKey)
        Set tStepArgs = $Select(tDetails.%Size() = 1: tDetails.%Get(0).arguments, 1: "")
        Do $$$AssertTrue((tText [ $List(tCase, 1)) && (tStepArgs [ $List(tCase, 1)), $List(tCase, 1) _ ": the row and the step keep the setting's name: " _ tText)
        If $List(tCase, 3) {
            Do $$$AssertTrue((tText '[ ..#KEYMARKER) && (tStepArgs '[ ..#KEYMARKER), $List(tCase, 1) _ ": neither the ledger row nor the step carries the key sent: " _ tText)
            Do $$$AssertTrue((tText [ "[redacted]") && (tStepArgs [ "[redacted]"), $List(tCase, 1) _ ": the value reads as redacted in both")
        } Else {
            Do $$$AssertTrue((tText [ $List(tCase, 2)) && (tStepArgs [ $List(tCase, 2)), "a value sent for a setting the page does not have is kept in the row and the step")
        }
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
    }
}

}
