/// <p>Pins Story 24.2's term list editor end to end over HTTP against <code>USER</code> (AD-6, AD-14, AD-15, AD-22, AD-34, AD-53, AD-55, AD-56,
/// AD-58, AD-65), for both callers of each of the six operations. The person's New term list and Add entry post to their routes, and Edit,
/// Delete, Change entry and Remove entry are screen actions carrying only the values their tool declares: each answers the AD-14 action and a
/// read-back, and leaves one <code>ConfigChange</code> row and no agent marker. The agent's six proposals are minted and confirmed with the
/// governance keys on: the delete's and the remove's cards are destructive with their consequence codes, and each confirm leaves one
/// <code>ConfigChange</code> row, the agent marker and one ledger row. An entry the agent added is read back by the Entries screen's read and
/// by the agent's read tool with its fields joined; a confirm after the list changed is refused as moved; and the baseline ships the delete
/// and the remove off for the agent while a person's Delete still runs.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics
/// on in <code>USER</code> and writes term lists there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsTermListRoutes Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter EDIT = "OcuPilot.Test.AnalyticsTermListEdit";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter NAMESPACE = "USER";

Parameter MARKER = "OcuProbeTL24R";

Parameter LISTS = "/screens/analytics.termlists/action";

Parameter ENTRIES = "/screens/analytics.termlistentries/action";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListAdd";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AnalyticsTermListUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.AnalyticsTermListDelete";

Parameter ENTRYADDTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListEntryAdd";

Parameter ENTRYSETTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListEntrySet";

Parameter ENTRYREMOVETOOL = "OcuPilot.Screen.Tool.AnalyticsTermListEntryRemove";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListRoutes turns analytics on in USER and writes term lists there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#EDIT, "Sweep")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListRoutes left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#EDIT, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListRoutes left term lists in USER: " _ $ClassMethod(..#EDIT, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#EDIT, "Sweep")
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

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
    Do $ClassMethod(..#EDIT, "Sweep")
    Quit $$$OK
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    Do ..TakePolicy()
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>Keep the policy found, once per test, for <method>OnAfterOneTest</method> to restore.</p>
Method TakePolicy()
{
    If ..PreparedPolicyTaken Quit
    Kill tPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
    Merge ..PreparedPolicy = tPolicy
    Set ..PreparedPolicyTaken = 1
}

/// <p>The confirm of <var>pProposal</var>, the tool <var>pTool</var> on the target <var>pType</var> <var>pId</var> in the turn <var>pTurn</var>, left one
/// <code>ConfigChange</code> row naming the tool since <var>pSince</var>, one agent marker carrying the proposal id and one ledger row (AD-15).</p>
Method AssertAgentRecords(pSince As %String, pProposal, pTool As %String, pTurn As %String, pType As %String, pId As %String)
{
    Set tVerb = $Parameter(pTool, "TOOLNAME")
    Do $$$AssertEquals(..Rows(pSince, pType, pId, tVerb), 1, tVerb _ ": one audit row names the write")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "AgentWrite", pProposal.proposalId, .tMarker, tVerb), 1, tVerb _ ": the agent marker carries the proposal id")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", pTurn, tVerb), 1, tVerb _ ": one ledger row")
}

/// <p>The hide-value node of the list <var>pName</var> in <code>USER</code>.</p>
ClassMethod HideNode(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tNode = $Get(^DeepSee.TermList($ZConvert(pName, "U"), "hideValue"))
    Set $NAMESPACE = tOrigNS
    Quit tNode
}

/// <p>A person's route <var>pPath</var> with <var>pBody</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %Integer
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The person's screen action <var>pAction</var> on <var>pId</var> with the values <var>pValues</var>.</p>
ClassMethod Act(pPath As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Quit ..Post(pPath, tBody, .pAnswer)
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>Confirm <var>pProposal</var> over HTTP: the answer in <var>pAnswer</var>, the status returned.</p>
ClassMethod Confirm(pProposal, Output pAnswer, Output pRaw) As %Integer
{
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>The count of <code>ConfigChange</code> rows of <var>pType</var> and <var>pId</var> with the verb <var>pVerb</var> since <var>pSince</var>, and the agent markers
/// naming <var>pMarkerId</var>.</p>
ClassMethod Rows(pSince As %String, pType As %String, pId As %String, pVerb As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "AuditRows", pSince, pType, pId, pVerb, .tData)
}

/// <p>AC1, AC2, AC5: the person's routes and actions: a list is created, changed (caption, fields as JSON text, hide-value as text) and
/// deleted, an entry is added, changed and removed; each answers the AD-14 action, the target and a read-back, and leaves one audit row
/// naming the tool and no agent marker. The vendor reads each result.</p>
/// <p>Mutation (Rule 19): drop the <code>AuditWrite</code> in <method>OcuPilot.Port.AnalyticsPort.PerformTermList</method> -- the audit legs go red.</p>
Method TestThePersonsRoutesAndActionsWriteAndAreAudited()
{
    Set tName = ..#MARKER _ "Person"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Post("/analytics/term-lists", {"Name": (tName), "Caption": "Cap", "Fields": ["Region"], "HideValue": true}, .tAnswer), 201, "New term list answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.readBack.verdict, tName _ "|term-list|USER|matches", "naming the list, with a read-back that matches")
    Do $$$AssertEquals(..Rows(tSince, "term-list", tName, "analytics.termlists.add"), 1, "one audit row names the create")
    Do $$$AssertEquals(..Act(..#LISTS, "update", tName, {"Caption": "Changed", "Fields": "[\"Region\",\"Note\"]", "HideValue": "false"}, .tAnswer), 200, "Edit answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "updated|" _ tName _ "|matches", "updated, with a read-back that matches")
    Do $$$AssertEquals(..Rows(tSince, "term-list", tName, "analytics.termlists.update"), 1, "one audit row names the change")
    Do $$$AssertEquals(..HideNode(tName), "", "and the hide-value flag the Edit turned off is gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tName, .tMarker), 0, "and no agent marker is emitted for a person's action")
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tName, "K1"))
    Do $$$AssertEquals(..Post("/analytics/term-list-entries", {"TermList": (tName), "Key": "K1", "Value": "V1", "FieldValues": [{"Field": "Region", "Value": "West"}]}, .tAnswer), 201, "Add entry answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1") _ "|" _ $ClassMethod(..#EDIT, "Lookup", tName, "K1", "Region"), "V1|West", "%Lookup answers the entry")
    Do $$$AssertEquals(..Rows(tSince, "term-list-entry", tName _ "\u0001K1", "analytics.termlistentries.add"), 1, "one audit row names the entry add")
    Do $$$AssertEquals(..Act(..#ENTRIES, "set", tId, {"Value": "V2", "FieldValues": "[{\"Field\":\"Region\",\"Value\":\"East\"}]"}, .tAnswer), 200, "Change entry answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1") _ "|" _ $ClassMethod(..#EDIT, "Lookup", tName, "K1", "Region"), "V2|East", "the change is in effect")
    Do $$$AssertEquals(..Rows(tSince, "term-list-entry", tName _ "\u0001K1", "analytics.termlistentries.set"), 1, "one audit row names the entry change")
    Do $$$AssertEquals(..Act(..#ENTRIES, "remove", tId, "", .tAnswer), 200, "Remove entry answers 200")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1"), "<default>", "the key answers its default")
    Do $$$AssertEquals(..Act(..#LISTS, "delete", tName, "", .tAnswer), 200, "Delete answers 200")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Marked"), "", "and the list is gone")
    Do $$$AssertEquals(..Rows(tSince, "term-list", tName, "analytics.termlists.delete"), 1, "one audit row names the delete")
}

/// <p>AC1, AC2, AC5, AC6: the agent's six proposals, minted and confirmed over HTTP with the delete's and the remove's keys on: the create and
/// the entry add read back; the entry the agent added is answered by the Entries screen's read and by the agent's read tool with its fields
/// joined as <code>Region: West</code>; the delete's and the remove's cards are destructive and carry their consequence codes; each confirm
/// leaves one audit row, the agent marker and one ledger row.</p>
/// <p>Mutation (Rule 19): drop the <code>Fields</code> member of <method>OcuPilot.Port.AnalyticsPort.EntryRow</method> -- the integration leg goes red; keep no field value the
/// call leaves out in <method>OcuPilot.Screen.Tool.AnalyticsTermListEntryAction.OverlaidPairs</method> -- the entry change's read-back leg goes red.</p>
Method TestTheAgentsSixProposalsConfirmAndTheEntryReadsBack()
{
    Do ..EnableKey("analytics.termlists.delete")
    Do ..EnableKey("analytics.termlistentries.remove")
    Set tName = ..#MARKER _ "Agent"
    Do ..Mint(..#ADDTOOL, {"Name": (tName), "Caption": "Cap", "Fields": ["Region", "Note"]}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the create confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, "1|created|matches", "marked, created, and the read-back matches")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ADDTOOL, tTurn, "term-list", tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..Mint(..#ENTRYADDTOOL, {"TermList": (tName), "Key": "K1", "Value": "V1", "FieldValues": [{"Field": "Region", "Value": "West"}, {"Field": "Note", "Value": "n1"}]}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the entry add confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do ..AssertAgentRecords(tSince, tProposal, ..#ENTRYADDTOOL, tTurn, "term-list-entry", tName _ "\u0001K1")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.termlistentries/read?termlist=" _ tName, "", .tHttp, .tRead)
    Do $$$AssertEquals(tHttp, 200, "the Entries screen reads")
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) Do $$$AssertEquals(tRead.rows.%Get(0).Key _ "|" _ tRead.rows.%Get(0).Fields, "K1|Region: West; Note: n1", "its row carries the fields joined")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.termlistentries.read", {"termlist": (tName)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Do $$$AssertEquals(tLeg.%Get("http"), 200, "and the agent's read tool answers")
    If $IsObject(tLeg.%Get("rows")) Do $$$AssertEquals(tLeg.rows.%Get(0).Key _ "|" _ tLeg.rows.%Get(0).Fields, "K1|Region: West; Note: n1", "the same row")

    Do ..Mint(..#ENTRYSETTOOL, {"TermList": (tName), "Key": "K1", "Value": "V2", "FieldValues": [{"Field": "Note", "Value": "n2"}]}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the entry change confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1") _ "|" _ $ClassMethod(..#EDIT, "Lookup", tName, "K1", "Region") _ "|" _ $ClassMethod(..#EDIT, "Lookup", tName, "K1", "Note"), "V2|West|n2", "the value and the named field changed and the field the call left out kept its value")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, "matches", "and the read-back matches")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ENTRYSETTOOL, tTurn, "term-list-entry", tName _ "\u0001K1")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..Mint(..#UPDATETOOL, {"Name": (tName), "Caption": "Changed"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the list change confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, "matches", "and the read-back matches")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Call", "TermLists", "TERMLIST", tName, "", .tHeader, .tFault), "200 ", "the list reads")
    If $IsObject(tHeader) Do $$$AssertEquals(tHeader.Caption _ "|" _ tHeader.Fields.%ToJSON(), "Changed|[""Region"",""Note""]", "with the new caption and the fields the call left out")
    Do ..AssertAgentRecords(tSince, tProposal, ..#UPDATETOOL, tTurn, "term-list", tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..Mint(..#ENTRYREMOVETOOL, {"TermList": (tName), "Key": "K1"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.TERMLIST.REMOVE|1", "the remove's card is destructive with its consequence code")
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the remove confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1"), "<default>", "the key answers its default")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ENTRYREMOVETOOL, tTurn, "term-list-entry", tName _ "\u0001K1")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..Mint(..#DELETETOOL, {"Name": (tName)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.TERMLIST.DELETE|1", "the delete's card is destructive with its consequence code")
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the delete confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Marked"), "", "and the list is gone")
    Do ..AssertAgentRecords(tSince, tProposal, ..#DELETETOOL, tTurn, "term-list", tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC3: the agent's mint refuses what the write would refuse, before a proposal exists, each with the rule's own sentence: a field removed while
/// an entry holds a value for it (<code>FIELDINUSE</code>'s), an entry value for a field the list lacks (<code>NOFIELD</code>'s), a key with
/// <code>^</code> (<code>KEY</code>'s) and an entry for a list that is not there (<code>ABSENT</code>'s), each the kernel's 400 <code>TOOL.ARGUMENTS</code>;
/// a key the list holds (409 <code>ENTRYTAKEN</code>) and a list name already taken (409 <code>TAKEN</code>), each the fresh read's own code. Each leaves no
/// proposal and the list's nodes as they were.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsTermListAction.RuleProblem</method> quit before its checks -- the update, the unknown-field, the key and the
/// absent-list legs go red.</p>
Method TestAMintRefusesWhatTheWriteWouldRefuse()
{
    Set tName = ..#MARKER _ "Mint"
    Do $ClassMethod(..#EDIT, "Arrange", tName)
    Set tBefore = $ClassMethod(..#EDIT, "Snapshot")
    Set tList = """TermList"":""" _ tName _ """"
    Set tErrors = "OcuPilot.Api.AnalyticsError"
    For tCase = $ListBuild(..#UPDATETOOL, "{""Name"":""" _ tName _ """,""Fields"":[]}", "400 TOOL.ARGUMENTS", "REASONTERMLISTFIELDINUSE"), $ListBuild(..#ENTRYADDTOOL, "{" _ tList _ ",""Key"":""K9"",""FieldValues"":[{""Field"":""Nope"",""Value"":""x""}]}", "400 TOOL.ARGUMENTS", "REASONTERMLISTNOFIELD"), $ListBuild(..#ENTRYADDTOOL, "{" _ tList _ ",""Key"":""a^b"",""Value"":""x""}", "400 TOOL.ARGUMENTS", "REASONTERMLISTKEY"), $ListBuild(..#ENTRYADDTOOL, "{""TermList"":""" _ tName _ "None"",""Key"":""K1"",""Value"":""x""}", "400 TOOL.ARGUMENTS", "REASONTERMLISTABSENT"), $ListBuild(..#ENTRYADDTOOL, "{" _ tList _ ",""Key"":""K1"",""Value"":""x""}", "409 ANALYTICS.TERMLIST.ENTRYTAKEN", "REASONTERMLISTENTRYTAKEN"), $ListBuild(..#ADDTOOL, "{""Name"":""" _ $ZConvert(tName, "L") _ """}", "409 ANALYTICS.TERMLIST.TAKEN", "REASONTERMLISTTAKEN") {
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", $List(tCase, 1), tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
        Set tGot = +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Set tSaid = $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "")
        Do $$$AssertEquals(tGot, $List(tCase, 3), $Parameter($List(tCase, 1), "TOOLNAME") _ " is refused at the mint: " _ tSaid)
        Do $$$AssertTrue(tSaid [ $Parameter(tErrors, $List(tCase, 4)), "with the rule's own sentence")
        Do $$$AssertTrue('$IsObject($Get(tProposal)), "and no proposal made")
    }
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Snapshot"), tBefore, "and the list's nodes are as they were")
}

/// <p>AC3, AC7: the baseline ships the delete and the remove off for the agent and the other four on, while a person's Delete still runs.</p>
/// <p>Mutation (Rule 19): flip the delete line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the denial leg goes red.</p>
Method TestTheDeleteAndRemoveKeysShipOffForTheAgentOnly()
{
    Do ..TakePolicy()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    For tCase = $ListBuild("analytics.termlists.add", 1), $ListBuild("analytics.termlists.update", 1), $ListBuild("analytics.termlists.delete", 0), $ListBuild("analytics.termlistentries.add", 1), $ListBuild("analytics.termlistentries.set", 1), $ListBuild("analytics.termlistentries.remove", 0) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
    Set tName = ..#MARKER _ "Keys"
    Do $$$AssertEquals(..Post("/analytics/term-lists", {"Name": (tName)}, .tAnswer), 201, "a list is made")
    Do $$$AssertEquals(..Act(..#LISTS, "delete", tName, "", .tAnswer), 200, "the person's Delete still runs")
}

/// <p>AC3: a confirm after the list changed is refused as moved (<code>PROPOSAL.TARGETCHANGED</code>), and a create whose name was taken after the
/// mint is refused the same way; nothing is written by either.</p>
/// <p>Mutation (Rule 19): drop <code>Modified</code> from <parameter>OcuPilot.Screen.Tool.AnalyticsTermListDelete.FINGERPRINTSUBJECT</parameter> -- the first confirm
/// is applied and this goes red.</p>
Method TestAConfirmAfterTheListChangedIsRefusedAsMoved()
{
    Do ..EnableKey("analytics.termlists.delete")
    Set tName = ..#MARKER _ "Moved"
    Do $$$AssertEquals(..Post("/analytics/term-lists", {"Name": (tName), "Caption": "one"}, .tAnswer), 201, "a list is made")
    Do ..Mint(..#DELETETOOL, {"Name": (tName)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Hang 1.1
    Do $$$AssertEquals(..Act(..#LISTS, "update", tName, {"Caption": "two"}, .tAnswer), 200, "the list is changed after the review")
    Set tStatus = ..Confirm(tProposal, .tConfirmed, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is refused: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Marked"), $ZConvert(tName, "U"), "and the list is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Mint(..#ADDTOOL, {"Name": (tName _ "X")}, .tAddProposal, .tAddTurn)
    If '$IsObject($Get(tAddProposal)) Quit
    Do ..Post("/analytics/term-lists", {"Name": (tName _ "X")}, .tOther)
    Set tStatus = ..Confirm(tAddProposal, .tConfirmed, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "a create whose name was taken since the review is refused: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tAddTurn)
}

/// <p>AC3 (QA): the person's own routes and screen actions answer each refusal row with its status and code, over HTTP, and leave every node of
/// the list as it was: a name held in another case (409 <code>TAKEN</code>), a field removed while an entry holds a value for it (422
/// <code>FIELDINUSE</code>), a key the list holds (409 <code>ENTRYTAKEN</code>), an entry for a list that is not there (404 <code>ABSENT</code>), a key with <code>^</code> (422
/// <code>KEY</code>), a value of 32,001 characters (422 <code>VALUE</code>) and a field value naming a field the list lacks
/// (422 <code>NOFIELD</code>).</p>
/// <p>Mutation (Rule 19): drop the removed-field test in <method>OcuPilot.Port.AnalyticsPort.TermListStateViolations</method> -- the Edit leg goes red.</p>
Method TestThePersonsRefusalsAnswerTheirCodesAndWriteNothing()
{
    Set tName = ..#MARKER _ "Refuse"
    Do $ClassMethod(..#EDIT, "Arrange", tName)
    Set tBefore = $ClassMethod(..#EDIT, "Snapshot")
    Set tLong = $Translate($Justify("", 32001), " ", "v")
    Set tNone = tName _ "None"
    Set tAdd = "/analytics/term-list-entries"
    ; A body is kept as JSON text in the list: a $ListBuild would flatten an object.
    Set tCases = $ListBuild($ListBuild("/analytics/term-lists", "{""Name"":""" _ $ZConvert(tName, "L") _ """}", "409 ANALYTICS.TERMLIST.TAKEN"), $ListBuild(..#LISTS, "{""action"":""update"",""id"":""" _ tName _ """,""values"":{""Fields"":""[]""}}", "422 ANALYTICS.TERMLIST.FIELDINUSE"), $ListBuild(tAdd, "{""TermList"":""" _ tName _ """,""Key"":""K1"",""Value"":""again""}", "409 ANALYTICS.TERMLIST.ENTRYTAKEN"), $ListBuild(tAdd, "{""TermList"":""" _ tNone _ """,""Key"":""K1"",""Value"":""x""}", "404 ANALYTICS.TERMLIST.ABSENT"), $ListBuild(tAdd, "{""TermList"":""" _ tName _ """,""Key"":""a^b"",""Value"":""x""}", "422 ANALYTICS.TERMLIST.KEY"), $ListBuild(tAdd, "{""TermList"":""" _ tName _ """,""Key"":""K9"",""Value"":""" _ tLong _ """}", "422 ANALYTICS.TERMLIST.VALUE"), $ListBuild(tAdd, "{""TermList"":""" _ tName _ """,""Key"":""K9"",""FieldValues"":[{""Field"":""Nope"",""Value"":""x""}]}", "422 ANALYTICS.TERMLIST.NOFIELD"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tStatus = ..Post($List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tAnswer)
        Set tGot = tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")
        Do $$$AssertEquals(tGot, $List(tCase, 3), "the person's " _ $List(tCase, 1) _ " is refused: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: tAnswer))
    }
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Snapshot"), tBefore, "and the list's nodes are as they were")
}

/// <p>AC3, AC7 (QA): at the baseline the agent's delete and remove are refused <code>GOVERNANCE.DISABLED</code> at the confirm of a minted proposal, over HTTP, and the
/// list and its entry are still there, while the person's own Remove entry and Delete run and are not asked for the key (AD-22).</p>
/// <p>Mutation (Rule 19): flip the delete line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the delete leg's confirm is
/// applied and this goes red.</p>
Method TestTheAgentsDeleteAndRemoveAreRefusedAtTheConfirmWhileThePersonsRun()
{
    Set tName = ..#MARKER _ "Off"
    Do $$$AssertEquals(..Post("/analytics/term-lists", {"Name": (tName), "Fields": ["Region"]}, .tAnswer), 201, "a list is made")
    Do $$$AssertEquals(..Post("/analytics/term-list-entries", {"TermList": (tName), "Key": "K1", "Value": "V1"}, .tAnswer), 201, "with an entry")
    Do ..EnableKey("analytics.termlists.delete")
    Do ..EnableKey("analytics.termlistentries.remove")
    Do ..Mint(..#ENTRYREMOVETOOL, {"TermList": (tName), "Key": "K1"}, .tRemove, .tRemoveTurn)
    Do ..Mint(..#DELETETOOL, {"Name": (tName)}, .tDelete, .tDeleteTurn)
    If '$IsObject($Get(tRemove)) || '$IsObject($Get(tDelete)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides again")
    Set tStatus = ..Confirm(tRemove, .tConfirmed, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's remove is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Set tStatus = ..Confirm(tDelete, .tConfirmed, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's delete is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Lookup", tName, "K1") _ "|" _ $ClassMethod(..#EDIT, "Marked"), "V1|" _ $ZConvert(tName, "U"), "and the entry and the list are still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tRemoveTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tDeleteTurn)
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tName, "K1"))
    Do $$$AssertEquals(..Act(..#ENTRIES, "remove", tId, "", .tAnswer), 200, "the person's Remove entry runs")
    Do $$$AssertEquals(..Act(..#LISTS, "delete", tName, "", .tAnswer), 200, "the person's Delete runs")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Marked"), "", "and the list is gone")
}

}
