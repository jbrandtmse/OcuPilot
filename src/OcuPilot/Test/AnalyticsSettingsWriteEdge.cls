/// <p>Pins the edges of Story 24.13's General and Worklists writes against <code>USER</code> (AD-8, AD-29, AD-34, AD-55, AD-65): a value a setting does not accept, a setting the page does not
/// have and the Google Maps key through the plain set are each refused with nothing written, by the port and by the person's action; worklists that are not customized and a worklist the page does
/// not list are refused for show and hide; a second writer while the namespace's lock is held is refused and the first one applied; a proposal minted before the setting changed is closed as moved;
/// a read-only settings database, a caller without the developer pair and a namespace without analytics are refused before any vendor call, which
/// <class>OcuPilot.Test.AnalyticsGateSeam</class> arms a failure behind.</p>
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
/// <p>Mutation (Rule 19): drop <code>Was</code> from <method>OcuPilot.Screen.Tool.AnalyticsSettingSet.MergeUpdate</method> -- the second leg goes red.</p>
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

}
