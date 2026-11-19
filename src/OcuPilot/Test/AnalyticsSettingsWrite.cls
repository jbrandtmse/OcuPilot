/// <p>Pins Story 24.13's General and Worklists writes end to end over HTTP against <code>USER</code> (AD-6, AD-15, AD-34, AD-35, AD-51, AD-53, AD-56, AD-58, AD-59, AD-65), for both callers of
/// each of the four operations: the person's row action (<code>set</code>, <code>setkey</code>, <code>show</code>, <code>hide</code>) and the agent's proposal, confirmed. Each write is checked
/// where the vendor holds it (<code>^DeepSee.UserPortalSettings</code>), in both reads (the screen's and the agent's tool's), in the read-back and in exactly one <code>ConfigChange</code> row,
/// counted before and after. The Google Maps key is checked to be in no answer, read, draft or audit row. The three settings globals are restored from the snapshot taken first.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in <code>USER</code> and rewrites its analytics settings through
/// <class>OcuPilot.Test.AnalyticsProbe</class>. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsWrite Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter NAMESPACE = "USER";

Parameter SETTOOL = "OcuPilot.Screen.Tool.AnalyticsSettingSet";

Parameter KEYTOOL = "OcuPilot.Screen.Tool.AnalyticsSettingKey";

Parameter SHOWTOOL = "OcuPilot.Screen.Tool.AnalyticsWorklistShow";

Parameter HIDETOOL = "OcuPilot.Screen.Tool.AnalyticsWorklistHide";

Parameter RECENT = "%DeepSee.UserPortal.RecentList";

Parameter KEYMARKER = "OcuProbe2413WriteKey";

Parameter MASK = "[redacted]";

/// <p>What <code>USER</code>'s three settings globals read as before the class changed them.</p>
Property StartDigest As %String;

Property StartTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWrite turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    If $$$ISOK(tSC) Set ..StartDigest = $ClassMethod(..#PROBE, "SettingsDigest"), ..StartTaken = 1
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, which restores USER's three settings globals; a failing status when anything of it is left or they read otherwise than at the start.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWrite left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsWrite left USER's analytics settings changed")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>The proposals and turns this test seeded are removed and the settings emptied, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>The node of <code>^DeepSee.UserPortalSettings</code> named by <var>pNode</var> (subscripts joined with <code>,</code>) in <code>USER</code>, as <code>stored|value</code>.</p>
ClassMethod Node(pNode As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "unread"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRef = "^DeepSee.UserPortalSettings(""" _ $Replace(pNode, ",", """,""") _ """)"
        Set tText = ($Data(@tRef) # 2) _ "|" _ $Get(@tRef)
    } Catch ex {
        Set tText = "unread " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>How many of the fourteen nodes <code>SaveToServer</code> stores are stored in <code>USER</code>.</p>
ClassMethod StoredCount() As %Integer
{
    Set tCount = 0
    Set tRoster = ##class(OcuPilot.Port.AnalyticsPort).SettingRoster()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tAt = 1:1:$ListLength(tRoster) {
            Set tEntry = $List(tRoster, tAt)
            If $List(tEntry, 8) = "custom" Continue
            If $List(tEntry, 3) = "" {
                Set tCount = tCount + ($Data(^DeepSee.UserPortalSettings($List(tEntry, 2))) # 2)
            } Else {
                Set tCount = tCount + ($Data(^DeepSee.UserPortalSettings($List(tEntry, 2), $List(tEntry, 3))) # 2)
            }
        }
    } Catch {
        Set tCount = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The person's row action <var>pAction</var> of the screen <var>pScreen</var> on <var>pId</var> with <var>pValues</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction)}
    If $IsObject(pValues) && (pValues.%Size() > 0) Do tBody.%Set("values", pValues)
    Do tBody.%Set("id", pId, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/screens/" _ pScreen _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The screen's read of <var>pScreen</var>: its rows, or <code>""</code>.</p>
ClassMethod ScreenRows(pScreen As %String) As %DynamicArray
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ pScreen _ "/read?maxRows=100", "", .tStatus, .tScreen)
    Quit $Select((tStatus = 200) && $IsObject(tScreen) && $IsObject(tScreen.%Get("rows")): tScreen.%Get("rows"), 1: "")
}

/// <p>The row of <var>pRows</var> whose <var>pField</var> reads <var>pValue</var>.</p>
ClassMethod RowWhere(pRows As %DynamicArray, pField As %String, pValue As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get(pField) = pValue Quit
    }
    Quit $Select($IsObject($Get(tRow)) && (tRow.%Get(pField) = pValue): tRow, 1: "")
}

/// <p>The agent's read tool <var>pName</var>'s row whose <var>pField</var> reads <var>pValue</var>.</p>
ClassMethod ToolRow(pName As %String, pField As %String, pValue As %String, pPage As %String = "") As %DynamicObject
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(pName, {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set tRows = $Select(tLeg.%Get("http") = 200: tLeg.%Get("rows"), 1: "")
    If '$IsObject(tRows) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%Get(pField) = pValue) && ((pPage = "") || (tRow.%Get("Page") = pPage)) Quit
    }
    Quit $Select($IsObject($Get(tRow)) && (tRow.%Get(pField) = pValue) && ((pPage = "") || (tRow.%Get("Page") = pPage)): tRow, 1: "")
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>The agent's mint of the key's tool as this process's user, whose confirm and script the secret channel asks for in process: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method MintKey(Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#KEYTOOL, {"Name": "GoogleMapsKey"}, $Username, .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, "the key's tool mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>The agent's proposal <var>pProposal</var>, confirmed over HTTP: the answer, which must be one envelope at 200.</p>
Method Confirm(pProposal, Output pAnswer)
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .tRaw, .pAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(pAnswer) && ($Length(tRaw, "}{") = 1), "exactly one envelope")
}

/// <p>Every column of every row the statement <var>pSql</var> answers for the bound value <var>pValue</var>, joined into one text; <code>""</code> when none.</p>
ClassMethod RowText(pSql As %String, pValue As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pValue)
    If tRS.%SQLCODE < 0 Quit ""
    While tRS.%Next() {
        For tAt = 1:1:tRS.%ResultColumnCount {
            Set tText = tText _ "|" _ tRS.%GetData(tAt)
        }
    }
    Quit tText
}

/// <p>The number of <code>ConfigChange</code> rows since <var>pSince</var> for the entity <var>pType</var>, id <var>pId</var> and verb <var>pVerb</var>, as a baseline.</p>
ClassMethod Base(pSince As %String, pType As %String, pId As %String, pVerb As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "Count", pSince, pType, ..Escaped(pId), pVerb)
}

/// <p>The id <var>pId</var> as the audit row's JSON spells it: the composite separator is a control character, written as its escape.</p>
ClassMethod Escaped(pId As %String) As %String
{
    Quit $Replace(pId, $Char(1), "\u0001")
}

/// <p>The rows added after the baseline <var>pBase</var>.</p>
ClassMethod Added(pSince As %String, pType As %String, pId As %String, pVerb As %String, pBase As %Integer, Output pData As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "Added", pSince, pType, ..Escaped(pId), pVerb, pBase, .pData)
}

/// <p>AC1, AC2, AC5: a General setting, <code>PageTitle</code>, set by both callers from a namespace that stores nothing. The person's action stores the marker, stores all fourteen nodes and changes no
/// other row's value; the screen's and the tool's reads answer it; the answer's read-back matches; one <code>ConfigChange</code> row names the setting. The agent's card carries the save consequence
/// while a row is unstored, its confirm stores its value, and the card carries none once every row is stored.</p>
/// <p>Mutation (Rule 19): drop <code>AuditWrite</code> from <method>OcuPilot.Port.AnalyticsPort.SendSetting</method> -- the audit legs go red; make
/// <method>OcuPilot.Port.AnalyticsPort.SettingsSaveHere</method> send only the overrides -- the stored-count leg goes red.</p>
Method TestASettingIsSetByBothCallers()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "PageTitle", "analytics.settings.set")
    Do $$$AssertEquals(..StoredCount(), 0, "nothing is stored to begin with")
    Set tStatus = ..Act("analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 A"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's set answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "updated, and the read-back matches")
    Do $$$AssertEquals(..Node("PageTitle"), "1|OcuProbe2413 A", "the vendor holds what was sent")
    Do $$$AssertEquals(..StoredCount(), 14, "the page's save stored all fourteen nodes, as the classic page's Save does")
    Do $$$AssertEquals(..Node("Scheme"), "1|simple", "an unset scheme is stored as the page's default")
    Do $$$AssertEquals(..Node("MailEnabled"), "1|0", "and an unset mail flag as 0")
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "PageTitle", "analytics.settings.set", tBase, .tData), 1, "one ConfigChange row names the set")
    Do $$$AssertTrue((tData [ """setting"":""PageTitle""") && (tData [ """namespace"":""USER""") && (tData '[ "OcuProbe2413 A"), "naming the namespace and the setting, never the value: " _ tData)
    Set tRow = ..RowWhere(..ScreenRows("analytics.settings"), "Name", "PageTitle")
    Do $$$AssertTrue($IsObject(tRow), "the screen reads the row")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Stored _ "|" _ tRow.Kind, "OcuProbe2413 A|1|text", "the screen answers the new value, stored, as text")
    Set tToolRow = ..ToolRow("analytics.settings.read", "Name", "PageTitle")
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Value = "OcuProbe2413 A"), "and the agent's tool answers it")

    Do $ClassMethod(..#PROBE, "ClearSettings")
    Do ..Mint(..#SETTOOL, {"Name": "PageTitle", "Value": "OcuProbe2413 B"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "ANALYTICS.SETTING.SAVE", "the card says the save stores every general setting while a row is unstored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "PageTitle", "analytics.settings.set")
    Do ..Confirm(tProposal, .tConfirmed)
    If $IsObject(tConfirmed) Do $$$AssertEquals(tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked, updated, and the read-back matches")
    Do $$$AssertEquals(..Node("PageTitle"), "1|OcuProbe2413 B", "the agent's confirm stores its value")
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "PageTitle", "analytics.settings.set", tBase, .tAgentData), 1, "and one ConfigChange row names it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, $Parameter(..#SETTOOL, "TOOLNAME")), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Mint(..#SETTOOL, {"Name": "PageTitle", "Value": "OcuProbe2413 C"}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "", "with every row stored the card carries no consequence")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC1: each kind of setting is stored as sent and reads back as it was sent: a color scheme and a chart series scheme the vendor lists, the mail flag 2, a boolean 1, text of the
/// longest length, and the choice 0 for a boolean. Every other row keeps its value, and the answers' read-backs match.</p>
/// <p>Mutation (Rule 19): store the value of a <code>choice</code> row as its upper-case form in <method>OcuPilot.Port.AnalyticsPort.SettingsSaveHere</method> -- the scheme leg goes red.</p>
Method TestEachKindIsStoredAsSent()
{
    Set tLong = $Translate($Justify("", 2000), " ", "x")
    For tCase = $ListBuild("Scheme", "bluechip", "Scheme"), $ListBuild("ChartSeriesScheme", "urban", "ChartSeriesScheme"), $ListBuild("MailEnabled", "2", "MailEnabled"), $ListBuild("DashboardNoTitle", "1", "DashboardNoTitle"), $ListBuild("autosaveAnalyzer", "0", "autosaveAnalyzer"), $ListBuild("CompanyName", tLong, "CompanyName"), $ListBuild("Controls.showCalculated", "1", "Controls,showCalculated") {
        Set tName = $List(tCase, 1)
        Set tStatus = ..Act("analytics.settings", "set", tName, {"Value": ($List(tCase, 2))}, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tName _ " is set: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: tAnswer))
        If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, tName _ " reads back as sent")
        Do $$$AssertEquals(..Node($List(tCase, 3)), "1|" _ $List(tCase, 2), tName _ " is stored as sent")
    }
    Do $$$AssertEquals(..Node("Scheme"), "1|bluechip", "an earlier setting is not changed by a later one")
    Do $$$AssertEquals(..Node("MailEnabled"), "1|2", "nor the mail flag")
}

/// <p>AC1: <code>Worklist</code> turns the Worklists options on and off through the page's own call and keeps the options already chosen: 1 stores the flag, 0 removes it and leaves the stored option
/// as it was (the vendor's call alone would remove it), and 1 again shows the option as it was.</p>
/// <p>Mutation (Rule 19): call <code>SetCustom</code> without setting the options again in <method>OcuPilot.Port.AnalyticsPort.SettingCustomHere</method> -- the option leg goes red.</p>
Method TestCustomizingKeepsTheOptions()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "Worklist", "analytics.settings.set")
    Do $$$AssertEquals(..Act("analytics.settings", "set", "Worklist", {"Value": "1"}, .tAnswer), 200, "the worklists are customized")
    Do $$$AssertEquals(..Node("Worklist"), "1|1", "the flag is 1")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "its read-back matches")
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "Worklist", "analytics.settings.set", tBase, .tData), 1, "one ConfigChange row names the flag's set")
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Do $$$AssertEquals(..Act("analytics.worklists", "show", tId, {}, .tShown), 200, "an option is shown")
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "the vendor holds the option")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "Worklist", "analytics.settings.set")
    Do $$$AssertEquals(..Act("analytics.settings", "set", "Worklist", {"Value": "0"}, .tAnswer), 200, "the worklists are not customized any more")
    Do $$$AssertEquals($Piece(..Node("Worklist"), "|", 1), 0, "the flag is gone")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "its read-back matches")
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "Worklist", "analytics.settings.set", tBase, .tData), 1, "one ConfigChange row names it")
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "and the option the person chose is kept")
    Do $$$AssertEquals(..Act("analytics.settings", "set", "Worklist", {"Value": "1"}, .tAnswer), 200, "customized again")
    Set tRows = ..ScreenRows("analytics.worklists")
    Do $$$AssertTrue($IsObject(tRows), "the Worklists screen is read")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    Set tShownRows = 0
    While tIterator.%GetNext(.tIndex, .tOne) {
        If tOne.Shown Set tShownRows = tShownRows + 1
    }
    Do $$$AssertEquals(tShownRows _ "|" _ tRows.%Get(0).Customized, "1|1", "the option is read as shown again, and the rows say the worklists are customized")
}

/// <p>AC1, AC2, AC3, AC5: the Google Maps key set by both callers. The person's <code>setkey</code> stores it, the row then reads the mask, the answer reports it written, and its text is in no
/// answer, read, audit row or draft. The agent's proposal asks for the key at the confirm, its card and its script hold a placeholder, its confirm stores the key, and an empty key at the confirm
/// clears it.</p>
/// <p>Mutation (Rule 19): put the key's text into the effects of <method>OcuPilot.Port.AnalyticsPort.SendSetting</method>'s audit row -- the audit leg goes red.</p>
Method TestTheKeyIsSetByBothCallersAndSurfacesNowhere()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey")
    Set tStatus = ..Act("analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER _ "A")}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's key write answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Set tAnswers = $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: "")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#WRITTEN, "the read-back reports the key written, and does not read it")
    Do $$$AssertEquals(..Node("GoogleMapsKey"), "1|" _ ..#KEYMARKER _ "A", "the vendor holds the key")
    Do $$$AssertEquals(..StoredCount(), 14, "and the save stored every general row")
    Set tRows = ..ScreenRows("analytics.settings")
    Set tRow = ..RowWhere(tRows, "Name", "GoogleMapsKey")
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Value = ..#MASK) && (tRow.Kind = "secret"), "the screen's row reads the mask, as a secret")
    Set tAnswers = tAnswers _ $Select($IsObject(tRows): tRows.%ToJSON(), 1: "")
    Set tToolRow = ..ToolRow("analytics.settings.read", "Name", "GoogleMapsKey")
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Value = ..#MASK), "the agent's tool reads the mask too")
    Set tAnswers = tAnswers _ $Select($IsObject(tToolRow): tToolRow.%ToJSON(), 1: "")
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey", tBase, .tData), 1, "one ConfigChange row names the key write")

    Do ..MintKey(.tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tDraft =##class(OcuPilot.Test.EncryptionKeyWrite).Draft(tProposal, .tSteps)
    Do $$$AssertTrue((tDraft [ "<GoogleMapsKey>") && (tDraft [ "SaveToServer") && (tDraft [ "$Get(^DeepSee.UserPortalSettings(\""PageTitle\""), \""\"")") && (tDraft '[ ..#KEYMARKER), "the script re-reads every other stored setting and renders the key as a placeholder: " _ $Extract(tDraft, 1, 400))
    Set tAnswers = tAnswers _ tDraft _ tProposal.%ToJSON()
    Do ..MintKey(.tProposal, .tTurn)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), {"GoogleMapsKey": (..#KEYMARKER _ "B")}, $Username, .tConfirmed, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ "|" _ $Get(tCode), "200|", "the confirm with the key answers 200: " _ $Get(tHttp) _ " " _ $Get(tCode) _ " " _ $Select($IsObject($Get(tDetail)): $Extract(tDetail.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..Node("GoogleMapsKey"), "1|" _ ..#KEYMARKER _ "B", "and stores the key typed at the confirm")
    If $IsObject($Get(tConfirmed)) {
        Do $$$AssertEquals(tConfirmed.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#WRITTEN, "its read-back reports it written")
        Set tAnswers = tAnswers _ tConfirmed.%ToJSON()
    }
    Do $$$AssertEquals(..Added(tSince, "analytics-setting", "GoogleMapsKey", "analytics.settings.setkey", tBase, .tAgentData), 1, "and one ConfigChange row names it")
    Set tStored = ..RowText("SELECT * FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", tProposal.%Get("proposalId")) _ ..RowText("SELECT * FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurn)
    Do $$$AssertTrue(tStored [ "GoogleMapsKey", "the stored proposal row and the turn's ledger rows were read")
    Do $$$AssertTrue(tStored '[ ..#KEYMARKER, "the key's text is in neither the stored proposal nor the ledger")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Act("analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": ""}, .tCleared), 200, "an empty key is accepted")
    Do $$$AssertEquals(..Node("GoogleMapsKey"), "1|", "and clears the key: stored empty")
    Set tAudit = $Get(tData) _ $Get(tAgentData)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", ..#KEYMARKER, .tNone), 0, "the key's text is in no audit row")
    Do $$$AssertTrue(tAnswers '[ ..#KEYMARKER, "the key's text is in no answer, read, card or script")
    Do $$$AssertTrue(tAudit '[ ..#KEYMARKER, "nor in the audit rows' data")
}

/// <p>AC1, AC2, AC5, AC6: a worklist shown and hidden by both callers once the worklists are customized. The person's Show and Hide write the option the vendor holds and the screen reads it; the
/// agent's proposals show a card whose <code>Shown</code> row moves, and their confirms write the same state and read back as matching; each write adds one <code>ConfigChange</code> row.
/// Showing a shown option and hiding a hidden one succeed.</p>
/// <p>Mutation (Rule 19): hide in place of show in <method>OcuPilot.Port.AnalyticsPort.SendSetting</method> -- the vendor leg goes red.</p>
Method TestAWorklistIsShownAndHiddenByBothCallers()
{
    Do $$$AssertEquals(..Act("analytics.settings", "set", "Worklist", {"Value": "1"}, .tCustom), 200, "the worklists are customized")
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-worklist", tId, "analytics.worklists.show")
    Set tStatus = ..Act("analytics.worklists", "show", tId, {}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Show answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "its read-back matches")
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "the vendor holds the option")
    Set tRow = ..RowWhere(..ScreenRows("analytics.worklists"), "Class", ..#RECENT)
    Do $$$AssertTrue($IsObject(tRow) && tRow.Shown && tRow.Customized, "the screen reads it shown")
    Set tToolRow = ..ToolRow("analytics.worklists.read", "Class", ..#RECENT, "Home")
    Do $$$AssertTrue($IsObject(tToolRow) && tToolRow.Shown, "and the agent's tool does")
    Do $$$AssertEquals(..Added(tSince, "analytics-worklist", tId, "analytics.worklists.show", tBase, .tData), 1, "one ConfigChange row names the show")
    Do $$$AssertTrue((tData [ """page"":""Home""") && (tData [ """class"":""" _ ..#RECENT _ """"), "naming the page and the class: " _ tData)
    Do $$$AssertEquals(..Act("analytics.worklists", "show", tId, {}, .tAgain), 200, "showing a shown worklist succeeds")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-worklist", tId, "analytics.worklists.hide")
    Do $$$AssertEquals(..Act("analytics.worklists", "hide", tId, {}, .tHidden), 200, "the person's Hide answers 200")
    Do $$$AssertEquals($Piece(..Node("Worklist,Home,1,2"), "|", 1), 0, "the option is gone")
    Do $$$AssertEquals(..Added(tSince, "analytics-worklist", tId, "analytics.worklists.hide", tBase, .tData), 1, "one ConfigChange row names the person's hide")
    Do $$$AssertEquals(..Act("analytics.worklists", "hide", tId, {}, .tHiddenAgain), 200, "hiding a hidden worklist succeeds")

    Do ..Mint(..#SHOWTOOL, {"Page": "Home", "Panel": "1", "Class": (..#RECENT)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertTrue(tProposal.changed.%Size() > 0, "the card's rows are present")
    Set tShownRow = ""
    Set tIterator = tProposal.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCard) {
        If tCard.field = "Shown" Set tShownRow = tCard.before _ ">" _ tCard.after
    }
    Do $$$AssertEquals(tShownRow, "false>true", "the card's Shown row moves from false to true")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Base(tSince, "analytics-worklist", tId, "analytics.worklists.show")
    Do ..Confirm(tProposal, .tConfirmed)
    If $IsObject(tConfirmed) Do $$$AssertEquals(tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.readBack.verdict, "1|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked, and the read-back matches")
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "the agent's show writes the option")
    Do $$$AssertEquals(..Added(tSince, "analytics-worklist", tId, "analytics.worklists.show", tBase, .tAgentData), 1, "and one ConfigChange row names it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Mint(..#HIDETOOL, {"Page": "Home", "Panel": "1", "Class": (..#RECENT)}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tBase = ..Base(tSince, "analytics-worklist", tId, "analytics.worklists.hide")
        Do ..Confirm(tProposal, .tConfirmed)
        If $IsObject(tConfirmed) Do $$$AssertEquals(tConfirmed.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "the agent's hide reads back as matching")
        Do $$$AssertEquals($Piece(..Node("Worklist,Home,1,2"), "|", 1), 0, "and removes the option")
        Do $$$AssertEquals(..Added(tSince, "analytics-worklist", tId, "analytics.worklists.hide", tBase, .tAgentData), 1, "and one ConfigChange row names the agent's hide")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC1: a General set keeps every other stored row, the Google Maps key and the rows whose form field is named otherwise than the row (<code>CompanyImage</code> is the page's
/// <code>CompanyLogo</code>) among them.</p>
/// <p>Mutation (Rule 19): read a row's default in place of its stored value in <method>OcuPilot.Port.AnalyticsPort.SettingsSaveHere</method> -- the key leg and the others go red.</p>
Method TestAGeneralSetKeepsTheOtherRows()
{
    Do $$$AssertEquals(..Act("analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER _ "C")}, .tKey), 200, "the key is stored")
    For tCase = $ListBuild("CompanyImage", "OcuProbe2413 image"), $ListBuild("CompanyLink", "OcuProbe2413 link"), $ListBuild("DefaultResource", "OcuProbe2413 resource"), $ListBuild("DashboardNoBorder", "1"), $ListBuild("autosaveUserPortal", "1") {
        Do $$$AssertEquals(..Act("analytics.settings", "set", $List(tCase, 1), {"Value": ($List(tCase, 2))}, .tAnswer), 200, $List(tCase, 1) _ " is set")
    }
    Do $$$AssertEquals(..Act("analytics.settings", "set", "PageTitle", {"Value": "OcuProbe2413 title"}, .tTitle), 200, "an unrelated row is set last")
    Do $$$AssertEquals(..Node("GoogleMapsKey"), "1|" _ ..#KEYMARKER _ "C", "the stored key is kept")
    Do $$$AssertEquals(..Node("CompanyImage"), "1|OcuProbe2413 image", "the company image is kept")
    Do $$$AssertEquals(..Node("CompanyLink"), "1|OcuProbe2413 link", "the company link is kept")
    Do $$$AssertEquals(..Node("DefaultResource"), "1|OcuProbe2413 resource", "the default resource is kept")
    Do $$$AssertEquals(..Node("DashboardNoBorder"), "1|1", "the border flag is kept")
    Do $$$AssertEquals(..Node("autosaveUserPortal"), "1|1", "the portal autosave flag is kept")
}

/// <p>Run the script form of the write <var>pType</var> on <var>pEndpoint</var> for <var>pId</var> with <var>pBody</var>, one line at a time, in the namespace it names, and assert that its final
/// status is OK, or, when <var>pExpectOK</var> is 0, that it is not. The variables the scripts use are killed first, and <var>pPrelude</var>, when given, is run after that, as a terminal the script is
/// pasted into might already hold something.</p>
Method RunScript(pEndpoint As %String, pType As %String, pId As %String, pBody, pExpectOK As %Boolean = 1, pPrelude As %String = "")
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSteps = ##class(OcuPilot.Port.AnalyticsPort).Snippet(pEndpoint, pType, .tQuery, pBody)
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 1), pType _ " renders one script step")
    If '$IsObject(tSteps) || (tSteps.%Size() '= 1) Quit
    Set tOrigNS = $NAMESPACE
    XECUTE "Kill tSC,tOptions,tOption,tData,tMessage,tPage,tPanel,tNumber,tClass,tAt"
    If pPrelude '= "" XECUTE pPrelude
    Try {
        For tI = 1:1:$Length(tSteps.%Get(0).text, $Char(10)) {
            Set tLine = $Piece(tSteps.%Get(0).text, $Char(10), tI)
            If tLine '= "" XECUTE tLine
        }
    } Catch ex {
        Do $$$AssertTrue(0, pType _ " script ran: " _ ex.DisplayString())
    }
    Set $NAMESPACE = tOrigNS
    Set tScriptStatus = $Get(@"tSC")
    Do $$$AssertEquals(''$System.Status.IsOK(tScriptStatus), ''pExpectOK, pType _ " script ends with its status " _ $Select(pExpectOK: "OK", 1: "refused") _ ": " _ $System.Status.GetErrorText(tScriptStatus))
}

/// <p>AC2 (AD-59): each write's script form, run line by line in <code>USER</code>, makes the change the write makes: a General set (the rows the person set before it, the key among them, kept), the key's
/// write, the Worklists flag on and off (the chosen option kept), and a show and a hide; a hide while the worklists are not customized is refused and changes nothing.</p>
/// <p>Mutation (Rule 19): swap the shown flag of the show and hide scripts in <method>OcuPilot.Port.AnalyticsPort.SettingSnippet</method> -- the option legs go red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, ..#RECENT))
    Do $$$AssertEquals(..Act("analytics.settings", "setkey", "GoogleMapsKey", {"GoogleMapsKey": (..#KEYMARKER _ "D")}, .tKey), 200, "the key is stored")
    Do $$$AssertEquals(..Act("analytics.settings", "set", "CompanyLink", {"Value": "OcuProbe2413 link"}, .tLink), 200, "a row is stored")
    Do ..RunScript("Settings", "SETTINGSET", "CompanyImage", {"Value": "OcuProbe2413 image"})
    Do $$$AssertEquals(..Node("CompanyImage"), "1|OcuProbe2413 image", "the set script stores the value under the page's own field")
    Do $$$AssertEquals(..Node("GoogleMapsKey") _ "|" _ ..Node("CompanyLink"), "1|" _ ..#KEYMARKER _ "D|1|OcuProbe2413 link", "and keeps the stored key and the other rows")
    Do ..RunScript("Settings", "SETTINGKEY", "GoogleMapsKey", {"GoogleMapsKey": ""})
    Do $$$AssertEquals(..Node("GoogleMapsKey") _ "|" _ ..Node("CompanyImage"), "1||1|OcuProbe2413 image", "the key script stores what it is given and keeps the other rows")
    Do ..RunScript("Settings", "SETTINGSET", "Worklist", {"Value": "1"})
    Do $$$AssertEquals(..Node("Worklist"), "1|1", "the flag script turns the worklists on")
    Do ..RunScript("Worklists", "WORKLISTSHOW", tId, {})
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "the show script stores the option")
    Do ..RunScript("Worklists", "WORKLISTHIDE", tId, {})
    Do $$$AssertEquals($Piece(..Node("Worklist,Home,1,2"), "|", 1), 0, "the hide script removes it")
    Do ..RunScript("Worklists", "WORKLISTSHOW", tId, {})
    Do ..RunScript("Settings", "SETTINGSET", "Worklist", {"Value": "0"}, 1, "Set tOptions = 1, tOptions(1) = $ListBuild(""Home"", 2, ""%DeepSee.UserPortal.AlertList"", 3)")
    Do $$$AssertEquals($Piece(..Node("Worklist"), "|", 1) _ "|" _ ..Node("Worklist,Home,1,2"), "0|1|" _ ..#RECENT, "the flag script turns them off and keeps the option")
    Do $$$AssertEquals($Piece(..Node("Worklist,Home,2,3"), "|", 1), 0, "and sets no option the terminal held from before")
    Do ..RunScript("Worklists", "WORKLISTHIDE", tId, {}, 0)
    Do $$$AssertEquals(..Node("Worklist,Home,1,2"), "1|" _ ..#RECENT, "a hide while the worklists are not customized is refused and changes nothing")
}

/// <p>AC5: the agent's card for the key and for a General set says the save stores every general setting while a row is unstored, and the card for <code>Worklist</code>, which is its own call,
/// says nothing.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Screen.Tool.AnalyticsSettingKey.Consequence</method> -- the key's leg goes red.</p>
Method TestTheCardsSayWhatTheSaveStores()
{
    Do ..MintKey(.tKeyProposal, .tKeyTurn)
    If $IsObject($Get(tKeyProposal)) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKeyProposal.proposalId, "Consequence"), "ANALYTICS.SETTING.SAVE", "the key's card carries the save consequence while a row is unstored")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKeyTurn)
    }
    Do ..Mint(..#SETTOOL, {"Name": "Worklist", "Value": "1"}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "", "the Worklist card carries none: that call stores no other row")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

}
