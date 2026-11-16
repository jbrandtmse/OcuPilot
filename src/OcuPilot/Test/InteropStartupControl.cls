/// <p>Pins Story 24.3's two startup writes end to end against the probe productions in <code>USER</code> (AD-4, AD-6, AD-14, AD-15,
/// AD-51, AD-53, AD-56, AD-58, AD-59, AD-62): the person's Productions row actions Start with the instance and Shutdown group over
/// <code>POST /screens/interop.productions/action</code>, and the agent's <code>interop.productions.autostart</code> and
/// <code>interop.productions.shutdowngroup</code> proposals confirmed over HTTP. Each change is read back through the vendor's own state,
/// answers a matching read-back and the change event, writes one audit row of OcuPilot's own, and is seen by the Productions screen's
/// read route and its read tool alike. A production's replaced auto-start sibling shows on the card; a change made elsewhere after the
/// mint closes the confirm target-changed; each tool has a script form.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles the probe productions in <code>USER</code>
/// (<class>OcuPilot.Test.ProductionProbe</class>) and starts one. Each test puts <code>USER</code>'s auto-start production, its
/// priority and the probe productions' shutdown groups back as it found them (<method>OnAfterOneTest</method>). One class per run.</p>
Class OcuPilot.Test.InteropStartupControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PRODUCTIONS = "OcuPilot.Test.InteropControl";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "/screens/interop.productions";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OTHER = "OcuPilotProbe.Interop.Other";

/// <p>What <code>USER</code> held before the class ran (<method>OcuPilot.Test.ProductionProbe.SaveStartup</method>).</p>
Property PreparedStartup As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedStartup = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupControl compiles probe productions in USER and sets its startup settings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedStartup = $ClassMethod(..#PROBE, "SaveStartup")
    If ..PreparedStartup = "" Quit $$$ERROR($$$GeneralError, "USER's startup settings could not be read")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>The probe is removed with its startup settings, and <code>USER</code> reads as it did before the class ran.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "USER's auto-start production, its priority and the probe productions' groups read as they did before the class ran")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Gone"), "and the probe holds nothing")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreStartup", ..PreparedStartup), "USER's startup settings are put back")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The startup settings of <code>USER</code> as the vendor's own state reads them: <code>&lt;auto-start production&gt;|&lt;priority&gt;|&lt;the
/// probe production's group&gt;|&lt;the other's group&gt;|&lt;whether the probe production holds a group node&gt;</code>.</p>
ClassMethod Vendor() As %String
{
    Set tText = "unread"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tText = $Get(^Ens.AutoStart) _ "|" _ $Select($Data(^Ens.AutoStart("StartupPriority")): ^Ens.AutoStart("StartupPriority"), 1: "") _ "|" _ ##class(Ens.Director).GetProductionShutdownGroup(..#PRODUCTION, , 0) _ "|" _ ##class(Ens.Director).GetProductionShutdownGroup(..#OTHER, , 0) _ "|" _ ''$Data(^Ens.Configuration("ShutdownGroup", ..#PRODUCTION))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>Arrange <code>USER</code> through the vendor's own calls: the production <var>pAuto</var> starts with the instance at
/// <var>pPriority</var> (none when <code>""</code>), and the probe production is in <var>pGroup</var> (the default when
/// <code>""</code>).</p>
ClassMethod Seed(pAuto As %String, pPriority As %Integer = 0, pGroup As %Integer = 2) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Director).SetAutoStart(pAuto, pPriority)
        If $$$ISOK(tSC) Set tSC = ##class(Ens.Director).SetProductionShutdownGroup(..#PRODUCTION, pGroup)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The person's row action <var>pAction</var> on <var>pId</var> with the dialog's <var>pValues</var>, as <code>status code</code>.</p>
ClassMethod ActOn(pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", {"action": (pAction), "id": (pId), "values": (pValues)}, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The probe production's startup read through the port: <code>AutoStart|StartupPriority|ShutdownGroup|AutoStartOther</code>.</p>
ClassMethod Startup(pId As %String = {..#PRODUCTION}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "STARTUP", .tQuery, "", .tRow, .tHttp, .tFault)
    If '$IsObject($Get(tRow)) Quit "unread " _ $Get(tHttp)
    Quit tRow.AutoStart _ "|" _ tRow.StartupPriority _ "|" _ tRow.ShutdownGroup _ "|" _ tRow.AutoStartOther
}

/// <p>The row of <var>pName</var> in <var>pRows</var>, or <code>""</code>.</p>
ClassMethod RowIn(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    Set tHit = ""
    If '$IsObject(pRows) Quit tHit
    For tI = 0:1:pRows.%Size() - 1 {
        If pRows.%Get(tI).Name = pName Set tHit = pRows.%Get(tI) Quit
    }
    Quit tHit
}

/// <p>What the Productions list reads for <var>pName</var> as <code>AutoStart|StartupPriority|ShutdownGroup</code>, after checking the
/// screen's read route and the read tool <code>interop.productions.read</code> answer the same row; <code>differ</code> when they do not,
/// <code>unlisted</code> when either lacks it.</p>
ClassMethod Listed(pName As %String) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tAnswer)
    Set tScreen = ..RowIn($Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: ""), pName)
    Set tTool = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.productions.read", .tResolved)
    If $IsObject($Get(tResolved)) {
        Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tResolved, {}, 1000, .tResult, .tHttp, .tFault)
        If +$Get(tHttp) = 200 Set tTool = ..RowIn(tResult.%Get("rows"), pName)
    }
    If '$IsObject(tScreen) || '$IsObject(tTool) Quit "unlisted"
    If tScreen.%ToJSON() '= tTool.%ToJSON() Quit "differ"
    Quit tScreen.AutoStart _ "|" _ tScreen.StartupPriority _ "|" _ tScreen.ShutdownGroup
}

/// <p>The agent's call of <var>pTool</var> (a class name) with <var>pArgs</var>, minted for <var>pUser</var>.</p>
ClassMethod Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pFault, Output pTurn, pUser As %String = {##class(OcuPilot.Test.Http).GetTestUsername()}) As %Status
{
    Quit $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, pArgs, pUser, .pProposal, .tHttp, .pFault, .pTurn)
}

/// <p>Mint <var>pTool</var> for <var>pArgs</var> and confirm it over HTTP: the card's rows as JSON in <var>pChanged</var>, the consequence
/// code in <var>pConsequence</var> and the confirm's answer in <var>pAnswer</var>; the confirm's status. 0 when it did not mint.</p>
Method Agent(pTool As %String, pArgs As %DynamicObject, Output pChanged As %String, Output pConsequence As %String, Output pAnswer) As %Integer
{
    Set pChanged = ""
    Set pConsequence = ""
    Set tName = $Parameter("OcuPilot.Screen.Tool." _ pTool, "TOOLNAME")
    Set tSC = ..Mint(pTool, pArgs, .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit 0
    Set pChanged = tProposal.changed.%ToJSON()
    Set pConsequence = ##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, tName _ ": it is not destructive")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "production|USER|" _ pArgs.Name, tName _ ": the target is the production")
    Set tStatus = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tHttp, .tRaw, .pAnswer)
    Do $$$AssertEquals(tHttp, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(pAnswer): pAnswer.%Get("auditMarked") _ "|" _ pAnswer.action _ "|" _ pAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, tName _ ": updated, marked (AD-15) and read back as sent")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Quit tHttp
}

/// <p>How many <code>ConfigChange</code> rows since <var>pSince</var> record a <code>set</code> of production <var>pName</var>, and the
/// last such row's data in <var>pData</var>.</p>
ClassMethod Audited(pSince As %String, pName As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """id"":""" _ pName _ """", .pData, """verb"":""set""")
}

/// <p>AC1, AC4: a person's Start with the instance turns auto-start on for the probe production at a priority, replacing the other
/// production that started with the instance, then turns it off. Each answers 200 with the updated event for the production and a
/// read-back that matches; the vendor's own state reads each change; the Productions list shows it; and each writes one audit row of
/// OcuPilot's own naming the tool, the namespace and the production and carrying no value.</p>
Method TestAPersonsStartWithTheInstanceTurnsAutoStartOnAndOff()
{
    Do $$$AssertStatusOK(..Seed(..#OTHER, 5), "the other production starts with the instance at priority 5")
    Do $$$AssertEquals(..Listed(..#OTHER) _ ";" _ ..Listed(..#PRODUCTION), "Yes|5|2;No||2", "the list shows it: the other Yes at 5 and this production No")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..ActOn("autostart", ..#PRODUCTION, {"AutoStart": "1", "StartupPriority": "4"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Start with the instance answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|production|" _ ..#PRODUCTION _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the production, whose read-back matches")
    Do $$$AssertEquals(..Vendor(), ..#PRODUCTION _ "|4|2|2|0", "the vendor's state reads the production at priority 4 in place of the other")
    Do $$$AssertEquals(..Startup() _ ";" _ ..Startup(..#OTHER), "1|4|2|;0||2|" _ ..#PRODUCTION, "and its startup read names the replaced production")
    Do $$$AssertEquals(..Listed(..#PRODUCTION) _ ";" _ ..Listed(..#OTHER), "Yes|4|2;No||2", "the list shows the change")
    Do $$$AssertEquals(..Audited(tSince, ..#PRODUCTION, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue((tData [ "interop.productions.autostart") && (tData [ "USER") && (tData [ ..#OTHER), "naming the tool, the namespace and the production it replaced: " _ tData)
    Do $$$AssertTrue((tData '[ "Priority") && (tData '[ "AutoStart"""), "and carrying no value: " _ tData)
    Do $$$AssertEquals(..ActOn("autostart", ..#PRODUCTION, {"AutoStart": "0"}, .tAnswer), "200 ", "turning it off answers 200")
    Do $$$AssertEquals(..Vendor(), "||2|2|0", "and no production of USER starts with the instance")
    Do $$$AssertEquals(..Listed(..#PRODUCTION) _ ";" _ ..Listed(..#OTHER), "No||2;No||2", "the list shows none")
    Do $$$AssertEquals(..Audited(tSince, ..#PRODUCTION, .tData), 2, "and a second audit row")
}

/// <p>AC1, AC4, AC5 (Integration): the agent's <code>interop.productions.autostart</code> proposals for the same two changes are
/// confirmed over HTTP. The card for the first shows the production's change from No to Yes at its priority and the replaced production's
/// change from Yes to No, with the replacement consequence; the second shows Yes to No and none. The vendor's state reads each change, the
/// Productions screen and its read tool answer the same row, and each confirm is marked and ledgered. A third, turning it on with no
/// priority, shows the priority 0 it sets.</p>
Method TestTheAgentsAutoStartReplacesTheOtherAndTurnsOff()
{
    Do $$$AssertStatusOK(..Seed(..#OTHER, 5), "the other production starts with the instance at priority 5")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Agent("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "1", "StartupPriority": "4"}, .tChanged, .tConsequence)
    Do $$$AssertEquals(tChanged, "[{""field"":""AutoStart"",""before"":""No"",""after"":""Yes""},{""field"":""StartupPriority"",""before"":"""",""after"":""4""},{""field"":""AutoStartOther"",""before"":""Yes"",""after"":""No""}]", "its card shows the change, the priority and the replaced production")
    Do $$$AssertEquals(tConsequence, "INTEROP.AUTOSTART", "with the replacement consequence")
    Do $$$AssertEquals(..Vendor(), ..#PRODUCTION _ "|4|2|2|0", "the vendor's state reads the production at priority 4")
    Do $$$AssertEquals(..Listed(..#PRODUCTION) _ ";" _ ..Listed(..#OTHER), "Yes|4|2;No||2", "the screen and the read tool answer the same AutoStart, priority and group")
    Do $$$AssertEquals(..Audited(tSince, ..#PRODUCTION, .tData), 1, "one audit row of OcuPilot's own from the agent's write too")
    Set tStatus = ..Agent("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "0"}, .tChanged, .tConsequence)
    Do $$$AssertEquals(tChanged, "[{""field"":""AutoStart"",""before"":""Yes"",""after"":""No""}]", "turning it off shows one row")
    Do $$$AssertEquals(tConsequence, "", "and no replacement consequence")
    Do $$$AssertEquals(..Vendor(), "||2|2|0", "no production of USER then starts with the instance")
    Do $$$AssertStatusOK(..Seed(..#OTHER, 5), "the other production starts with the instance at priority 5 again")
    Set tStatus = ..Agent("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "1"}, .tChanged, .tConsequence)
    Do $$$AssertEquals(tChanged, "[{""field"":""AutoStart"",""before"":""No"",""after"":""Yes""},{""field"":""StartupPriority"",""before"":"""",""after"":""0""},{""field"":""AutoStartOther"",""before"":""Yes"",""after"":""No""}]", "turning it on with no priority shows the priority 0 it sets")
    Do $$$AssertEquals(..Vendor(), ..#PRODUCTION _ "|0|2|2|0", "and the vendor reads the production at priority 0")
}

/// <p>AC2, AC4: for the probe production stopped and then running, each caller sets its shutdown group to 3 and then back to 2. The vendor reads
/// 3 and then 2, the default group removing its node; a running production's running-namespace value matches; the card carries the
/// shutdown-group consequence and the person's answer a matching read-back; and each set writes one more <code>ConfigChange</code> row naming
/// the tool, the namespace and the production.</p>
Method TestEachCallerSetsTheShutdownGroupOfAStoppedAndARunningProduction()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tWrites = 0
    For tState = "stopped", "running" {
        If tState = "running" {
            Do $$$AssertStatusOK($ClassMethod(..#PRODUCTIONS, "StartIt"), "the probe production is started")
            Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AwaitRunning"), "and reads running")
        }
        For tCaller = "person", "agent" {
            For tGroup = 3, 2 {
                Set tLabel = tState _ ", " _ tCaller _ ", group " _ tGroup _ ": "
                If tCaller = "person" {
                    Set tText = ..ActOn("shutdowngroup", ..#PRODUCTION, {"ShutdownGroup": (tGroup _ "")}, .tAnswer)
                    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.readBack.verdict, 1: ""), "200 |" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, tLabel _ "the row action answers 200 and a matching read-back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
                } Else {
                    Set tStatus = ..Agent("InteropProductionShutdownGroup", {"Name": (..#PRODUCTION), "ShutdownGroup": (tGroup _ "")}, .tChanged, .tConsequence)
                    Do $$$AssertEquals(tChanged, "[{""field"":""ShutdownGroup"",""before"":""" _ $Select(tGroup = 3: 2, 1: 3) _ """,""after"":""" _ tGroup _ """}]", tLabel _ "its card shows one row")
                    Do $$$AssertEquals(tConsequence, "INTEROP.SHUTDOWNGROUP", tLabel _ "with the shutdown-group consequence")
                }
                Do $$$AssertEquals($Piece(..Vendor(), "|", 3, 5), tGroup _ "|2|" _ (tGroup '= 2), tLabel _ "the vendor's group reads it, and holds a node only off the default")
                If tState = "running" Do $$$AssertEquals($Get(^%SYS("Ensemble", "RunningNamespace", ..#NAMESPACE, "SystemShutdownGroup")), tGroup, tLabel _ "and the vendor's running-namespace value matches")
                Set tWrites = tWrites + 1
                Do $$$AssertEquals(..Audited(tSince, ..#PRODUCTION, .tData), tWrites, tLabel _ "one more ConfigChange row of OcuPilot's own, a set of the production")
                Do $$$AssertTrue((tData [ "interop.productions.shutdowngroup") && (tData [ "USER"), tLabel _ "naming the tool and the namespace: " _ tData)
            }
        }
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is stopped again")
    }
}

/// <p>AC1: a proposal to start the production with the instance, made while no production did, is closed target-changed at its confirm
/// when another production was set to start with the instance in between, and nothing is written.</p>
Method TestAChangeMadeElsewhereAfterTheMintClosesTheConfirm()
{
    Do $$$AssertStatusOK(..Seed("", 0), "no production starts with the instance")
    Set tSC = ..Mint("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "1", "StartupPriority": "4"}, .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(..Seed(..#OTHER, 9), "another production is set to start with the instance")
    Set tStatus = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Vendor(), ..#OTHER _ "|9|2|2|0", "and the other production still starts with the instance")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AD-59: each tool's copy-out draft renders one ObjectScript step that switches to the namespace the proposal read and makes the
/// vendor's call with the reviewed values as the numbers the write passes (a group typed <code>007</code> as 7), closes the proposal as a
/// draft, and changes nothing.</p>
Method TestEachStartupToolsDraftRendersItsScript()
{
    Set tTools = $ListBuild("InteropProductionAutoStart", "InteropProductionAutoStart", "InteropProductionShutdownGroup", "InteropProductionShutdownGroup")
    Set tCalls = $ListBuild("SetAutoStart(""" _ ..#PRODUCTION _ """, 4)", "SetAutoStart("""")", "SetProductionShutdownGroup(""" _ ..#PRODUCTION _ """, 3)", "SetProductionShutdownGroup(""" _ ..#PRODUCTION _ """, 7)")
    For tI = 1:1:4 {
        Set tArgs = $Case(tI, 1: {"Name": (..#PRODUCTION), "AutoStart": "1", "StartupPriority": "4"}, 2: {"Name": (..#PRODUCTION), "AutoStart": "0"}, 3: {"Name": (..#PRODUCTION), "ShutdownGroup": "3"}, : {"Name": (..#PRODUCTION), "ShutdownGroup": "007"})
        Set tName = $Parameter("OcuPilot.Screen.Tool." _ $List(tTools, tI), "TOOLNAME")
        Set tBefore = ..Vendor()
        If tI = 2 Do $$$AssertStatusOK(..Seed(..#PRODUCTION, 4), "the production starts with the instance, so a stop is a change")
        If tI = 2 Set tBefore = ..Vendor()
        Set tSC = ..Mint($List(tTools, tI), tArgs, .tProposal, .tFault, .tTurn, $Username)
        Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, $Username, "https://draft.example:52773", .tAnswer, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tName _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tAnswer)) Continue
        Set tText = tAnswer.draft.steps.%Get(0).text
        Do $$$AssertEquals(tAnswer.state _ "|" _ tAnswer.closedReason _ "|" _ tAnswer.draft.steps.%Get(0).kind, "canceled|draft|objectscript", tName _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCalls, tI)), tName _ ": " _ tText)
        Do $$$AssertEquals(..Vendor(), tBefore, tName _ ": and nothing changed")
    }
}

}
