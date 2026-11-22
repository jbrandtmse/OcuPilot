/// <p>Pins Story 24.16's purge data settings end to end against the settings nodes of <code>USER</code> and <code>HSCUSTOM</code> (AD-6, AD-14, AD-15,
/// AD-51, AD-53, AD-55, AD-58, AD-59, AD-62): a person's Set value and the agent's confirmed proposal each store one setting of the classic Purge Data
/// Settings page, which reads back from <code>^Ens.Configuration("PurgeSettings")</code> exactly as sent; a namespace with no node reads the classic
/// defaults and nothing is written to read them; a value its kind does not accept, a description over 2,000 characters and a name the page has no setting for
/// are refused by their own codes with nothing set. The vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is the record, naming
/// the namespace and the setting and never the value. The script form of the write renders the global set and runs nothing, and a bad value renders none.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the environment:</b> interoperability-enabled
/// <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It puts
/// both namespaces' setting nodes back exactly as it found them.</p>
Class OcuPilot.Test.InteropPurgeSettingControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropPurgeFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SCREEN = "/screens/interop.purgesettings";

/// <p>The four setting names as the classic pages caption them.</p>
Parameter BODIES = "Include message bodies";

Parameter INTEGRITY = "Purge only completed sessions";

Parameter BITMAP = "Run bitmap cleanup for namespace";

Parameter DESCRIPTION = "Description";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPurgeSettingControl writes the purge settings of USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedSettings = $ClassMethod(..#FIXTURE, "SaveSettings")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ..PreparedSettings = "" Quit $$$OK
    Quit $ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
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
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings), "both namespaces' setting nodes are put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveSettings"), ..PreparedSettings, "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The setting <var>pName</var> of <var>pNamespace</var> as the port's single-setting read answers it, or <code>""</code>.</p>
ClassMethod Held(pName As %String, pNamespace As %String = "USER") As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = pName
    Set tQuery("namespace") = pNamespace
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PurgeSettings", "SETTING", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select(tHttp = 200: tRow, 1: "")
}

/// <p>The port's call of the type <var>pType</var> on <var>pName</var> in USER as <code>status code</code>.</p>
ClassMethod Verdict(pType As %String, pName As %String, pBody As %DynamicObject = "", pNamespace As %String = "USER") As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PurgeSettings", pType, .tQuery, pBody, .tRow, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>One person's Set value on the Purge data settings screen as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pId As %String, pValue As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "set", "id": (pId), "values": {"Value": (pValue)}}
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of the set of <var>pName</var> to <var>pValue</var>: the code of its refusal, <code>minted</code> when it was not refused; the sentence in
/// <var>pReason</var>; the proposal in <var>pProposal</var> and its turn in <var>pTurn</var>.</p>
ClassMethod MintVerdict(pName As %String, pValue As %String, Output pReason As %String, Output pProposal, Output pTurn) As %String
{
    Set pReason = ""
    Set tArgs = {"Name": (pName), "Value": (pValue)}
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropPurgeSettingSet", tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    If $IsObject($Get(pProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the purge setting entity type, with the last row's data in <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", "interop-purge-setting", .pData)
}

/// <p>How many rows of the vendor's own audit since <var>pSince</var> carry <var>pWords</var>: the classic page's save writes none (measured).</p>
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

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 17 with Set value as its one row action, over the classic page's own
/// pairs (<code>%Ens_PurgeSettings:WRITE</code> beside the portal), naming the entity type <code>interop-purge-setting</code> and the classic page it replaces.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 16 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropPurgeSettingList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/purge-settings|17|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.toolIdentifier, "interop-purge-setting|namespace|interop.purgesettings", "its entity type, its scope and its tool identifier")
    Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.rowActions.%Get(0).id, "1|set", "its one row action is Set value")
    Do $$$AssertEquals(tDeclaration.classicPage, "EnsPortal.PurgeSettings", "its classic page")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_PurgeSettings"",""permission"":""WRITE""}]", "its pairs are the classic page's")
}

/// <p>AC1: a person's Set value stores the setting it names and the agent's confirmed proposal stores another, each reading back from the global as sent with
/// <code>Stored</code> true and a read-back that matches, and each records one <code>ConfigChange</code> naming the namespace and the setting and no value, where the
/// vendor records none. The agent's write is marked and ledgered once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPurgeSetting</method> store the value under the <code>KeepIntegrity</code> node whatever
/// the setting -- the stored-text leg goes red.</p>
Method TestASettingSetFromEitherCallerReadsBackAsSent()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|<absent>", "no setting is stored in USER to begin with")
    Set tText = ..Act(..#BODIES, "1", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Set value answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-purge-setting|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "1|<absent>|<absent>|<absent>", "the global holds exactly what was sent, under its own node, and no other")
    Set tHeld = ..Held(..#BODIES)
    Do $$$AssertEquals($Select($IsObject(tHeld): tHeld.Value _ "|" _ tHeld.Stored _ "|" _ tHeld.Namespace, 1: ""), "1|1|USER", "the single read answers it as stored")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "USER") && (tData [ ..#BODIES), "naming the namespace and the setting: " _ tData)
    Set tNote = "OcuProbe2416 agent note"
    Set tVerdict = ..MintVerdict(..#DESCRIPTION, tNote, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tVerdict, "minted", "the agent's set of the description mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-purge-setting|USER|" _ ..#DESCRIPTION, "the target is the setting, by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "1|<absent>|<absent>|<absent>", "nothing is written by the mint")
    Set tStatus = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tConfirmStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.purgesettings.set"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "1|<absent>|<absent>|" _ tNote, "the global holds the description as the agent sent it")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 2, "OcuPilot records a second ConfigChange")
    Do $$$AssertTrue(tData '[ tNote, "carrying no value: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, "PurgeSettings"), 0, "and the vendor records none")
}

/// <p>AC1: a namespace with no <code>PurgeSettings</code> node reads the four classic defaults, each <code>Stored</code> false, in the classic order, and reading them
/// writes nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeSettingRoster</method> default <code>KeepIntegrity</code> to 0 -- this goes red.</p>
Method TestANamespaceWithNoNodeReadsTheClassicDefaults()
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "HSCUSTOM"), "<absent>|<absent>|<absent>|<absent>", "HSCUSTOM stores no purge setting")
    Kill tQuery
    Set tQuery("namespace") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PurgeSettings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list answers 200")
    Set tText = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Name _ "=" _ tRow.Value _ "/" _ tRow.Stored _ "/" _ tRow.Kind _ "/" _ tRow.Namespace
        }
    }
    Do $$$AssertEquals(tText, ..#BODIES _ "=0/0/boolean/HSCUSTOM;" _ ..#INTEGRITY _ "=1/0/boolean/HSCUSTOM;" _ ..#BITMAP _ "=0/0/boolean/HSCUSTOM;" _ ..#DESCRIPTION _ "=/0/text/HSCUSTOM", "four rows, the classic defaults, none stored")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "HSCUSTOM"), "<absent>|<absent>|<absent>|<absent>", "and reading them wrote no node")
}

/// <p>AC1, AC3: a boolean other than 0 or 1 and a description of 2,001 characters are refused 400 <code>CONFIG.SETTING.VALUE</code>, a name the page has no
/// setting for is 404 <code>CONFIG.SETTING.NOTFOUND</code>, from the person's Set value, the agent's mint and the port, with the sentence the instance publishes and
/// nothing set; a description of 2,000 characters is stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeSettingLimits</method> answer a text limit of 2,001 -- the long description leg goes red.</p>
Method TestABadValueOrNameIsRefusedAndNothingIsSet()
{
    Set tLong = $Translate($Justify("", 2001), " ", "x")
    Set tFull = $Translate($Justify("", 2000), " ", "y")
    Set tValueReason = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.VALUE")
    Set tNotFound = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.NOTFOUND")
    For tCase = $ListBuild(..#BODIES, "2"), $ListBuild(..#INTEGRITY, "yes"), $ListBuild(..#BITMAP, ""), $ListBuild(..#DESCRIPTION, tLong) {
        Set tName = $List(tCase, 1)
        Set tValue = $List(tCase, 2)
        Do $$$AssertEquals(..Verdict("SETTINGSET", tName, {"Value": (tValue)}), "400 CONFIG.SETTING.VALUE", tName _ ": the port refuses the value")
        Set tText = ..Act(tName, tValue, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: tText), "CONFIG.SETTING.VALUE " _ tValueReason, tName _ ": the person's Set value is refused with the published sentence")
        Do $$$AssertEquals(..MintVerdict(tName, tValue, .tReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", tName _ ": the agent's mint is refused")
        Do $$$AssertTrue(tReason [ tValueReason, tName _ ": naming the sentence: " _ tReason)
    }
    Do $$$AssertEquals(..Verdict("SETTINGSET", "Not a setting", {"Value": "1"}), "404 CONFIG.SETTING.NOTFOUND", "an unknown name is refused by the port")
    Do $$$AssertEquals(..Verdict("SETTING", "Not a setting"), "404 CONFIG.SETTING.NOTFOUND", "and by the single read")
    Do $$$AssertEquals(..Verdict("SETTINGSET", ..#BODIES, {"Value": 1}), "400 PORT.VALIDATION", "a value that is not text is refused")
    Do $$$AssertEquals(..Verdict("SETTINGSET", ..#BODIES, {}), "400 PORT.VALIDATION", "and so is no value")
    Do $$$AssertEquals(..MintVerdict("Not a setting", "1", .tReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", "the agent's mint of an unknown name is refused")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|<absent>", "no refusal set a node")
    Do $$$AssertEquals(..Verdict("SETTINGSET", ..#DESCRIPTION, {"Value": (tFull)}), "200 ", "a description of 2,000 characters is accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|" _ tFull, "and stored whole")
}

/// <p>AC1: the script form of the write names the namespace and renders the one global set the port makes, the value as a string literal and a boolean as 0 or
/// 1, and runs nothing; a value or a name the port would refuse renders no script.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeSettingSnippet</method> render the <code>KeepIntegrity</code> node for every setting -- this goes
/// red.</p>
Method TestTheScriptFormRendersTheGlobalSetAndRunsNothing()
{
    Kill tScript
    Set tScript("namespace") = "USER"
    Set tScript("id") = ..#BODIES
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "PurgeSettings", "SETTINGSET", .tScript, {"Value": "1"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step is rendered")
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""USER""", "it names the namespace: " _ tText)
    Do $$$AssertTrue(tText [ "^Ens.Configuration(""PurgeSettings"", ""BodiesToo"") = 1", "and sets the node as a number: " _ tText)
    Set tScript("id") = ..#DESCRIPTION
    Set tQuoted = "a ""quoted"" note"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "PurgeSettings", "SETTINGSET", .tScript, {"Value": (tQuoted)})
    Set tText = ..StepText(tSteps)
    Do $$$AssertTrue(tText [ "^Ens.Configuration(""PurgeSettings"", ""Desc"") = ""a """"quoted"""" note""", "a text value is a string literal: " _ tText)
    Set tScript("id") = ..#BODIES
    Set tNone = $ClassMethod(..#PORT, "Snippet", "PurgeSettings", "SETTINGSET", .tScript, {"Value": "2"})
    Do $$$AssertEquals(tNone.%Size(), 0, "a value the port would refuse renders no script")
    Set tScript("id") = "Not a setting"
    Set tNone = $ClassMethod(..#PORT, "Snippet", "PurgeSettings", "SETTINGSET", .tScript, {"Value": "1"})
    Do $$$AssertEquals(tNone.%Size(), 0, "and so does a name it does not know")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|<absent>", "no draft wrote a node")
}

/// <p>The text of every step of <var>pSteps</var>, joined by line feeds.</p>
ClassMethod StepText(pSteps As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pSteps) Quit tText
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("text")
    }
    Quit tText
}

}
