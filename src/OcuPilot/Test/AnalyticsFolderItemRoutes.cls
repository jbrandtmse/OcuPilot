/// <p>Pins Story 24.10's folder manager (Batch 2) at both callers' routes against <code>USER</code>: the person's Export (a server file and this browser), Import (a
/// server file and a local file) and Delete as screen actions, and the agent's three proposals, minted and confirmed over HTTP. Each answers the AD-14 action, leaves
/// one audit row of OcuPilot's own and, for the agent, its marker and one ledger row; the export's card names the file it replaces; the delete's card is destructive
/// and its governance key ships off; the imported items are answered by the Folder items screen's read and by the agent's read tool; and the agent's mint refuses
/// what the write would refuse, before a proposal exists. The port's own matrix is <class>OcuPilot.Test.AnalyticsFolderItemTransfer</class>, whose helpers it calls.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in <code>USER</code> and writes folder items and files there. It removes
/// everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsFolderItemRoutes Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter BASE = "OcuPilot.Test.AnalyticsFolderItemTransfer";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter MARKER = "OcuProbeFI2410";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.AnalyticsFolderItemExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.AnalyticsFolderItemImport";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.AnalyticsFolderItemDelete";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemRoutes turns analytics on in USER and writes folder items and files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#BASE, "Sweep")
    Set tSC = $ClassMethod(..#FILES, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemRoutes left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#BASE, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemRoutes left folder items or folders in USER: " _ $ClassMethod(..#BASE, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#BASE, "Sweep")
    Set ..PreparedPolicyTaken = 0
    Quit $ClassMethod(..#FILES, "MakeDirectory")
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
    Do $ClassMethod(..#BASE, "Sweep")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>The mint of <var>pTool</var> with <var>pArgs</var> is refused with no proposal, naming <var>pCode</var> at the start of the fault's code.</p>
Method MintRefused(pTool As %String, pArgs As %DynamicObject, pCode As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusNotOK(tSC, $Parameter(pTool, "TOOLNAME") _ " is refused at the mint")
    Do $$$AssertTrue(('$IsObject($Get(tProposal))) && (+$Get(tHttp) >= 400), "with no proposal and a refusal status: " _ $Get(tHttp))
    Do $$$AssertTrue($IsObject($Get(tFault)) && ($Extract(tFault.%Get("code"), 1, $Length(pCode)) = pCode), "naming " _ pCode _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
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

/// <p>The confirm of <var>pProposal</var> of the tool <var>pTool</var> on the item <var>pId</var> in the turn <var>pTurn</var> left one <code>ConfigChange</code> row
/// naming the tool since <var>pSince</var>, one agent marker carrying the proposal id and one ledger row (AD-15).</p>
Method AssertAgentRecords(pSince As %String, pProposal, pTool As %String, pTurn As %String, pId As %String)
{
    Set tVerb = $Parameter(pTool, "TOOLNAME")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Rows", pSince, pId, tVerb), 1, tVerb _ ": one audit row names the write")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "AgentWrite", pProposal.proposalId, .tMarker, tVerb), 1, tVerb _ ": the agent marker carries the proposal id")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", pTurn, tVerb), 1, tVerb _ ": one ledger row")
}

/// <p>AC1, AC2, AC3: the person's Export (a server file and this browser), Import (a server file and a local file) and Delete are screen actions; each answers the AD-14
/// action and leaves one audit row and no agent marker, the export carrying only the file or the lines and the import the first item's name and the count. The vendor
/// reads each result, a second import is refused as taken and a locked item's Delete is refused.</p>
/// <p>Mutation (Rule 19): send the export's output lines nowhere in <method>OcuPilot.Screen.Tool.AnalyticsFolderItemExport.WriteOutput</method> -- the browser leg goes red.</p>
Method TestThePersonsExportImportAndDelete()
{
    Set tName = ..#MARKER _ "/Person.dashboard"
    Do $ClassMethod(..#BASE, "Item", tName)
    Set tFirst = $ClassMethod(..#BASE, "Exported", tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tFile = $ClassMethod(..#BASE, "FileQuery", "person.xml")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "export", tName, tFile, .tAnswer), 200, "Export to a server file answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")), "the export answers an output")
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.output.root _ "|" _ tAnswer.output.path _ "|" _ tAnswer.output.%GetTypeOf("lines"), "updated|" _ tFile.root _ "|" _ tFile.path _ "|unassigned", "naming the file and nothing else")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "export-browser", tName, "", .tBrowser), 200, "Export to this browser answers 200")
    Do $$$AssertTrue($IsObject(tBrowser) && $IsObject(tBrowser.%Get("output")), "the browser export answers an output")
    Set tText = $ClassMethod(..#FILES, "ReadFile", "person.xml")
    If $IsObject(tBrowser) && $IsObject(tBrowser.%Get("output")) Do $$$AssertEquals(tBrowser.output.lines.%ToJSON(), $ClassMethod(..#BASE, "LinesOf", tText).%ToJSON(), "its output is the XML lines, which are the file's")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "delete", tName, "", .tDeleted), 200, "Delete answers 200: " _ $Select($IsObject(tDeleted): $Extract(tDeleted.%ToJSON(), 1, 300), 1: tDeleted))
    If $IsObject(tDeleted) Do $$$AssertEquals(tDeleted.action _ "|" _ tDeleted.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 0, "and the vendor reads it gone")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "import-local", "import", {"fileName": "person.xml", "content": (tText)}, .tImport), 200, "Import of a local file answers 200: " _ $Select($IsObject(tImport): $Extract(tImport.%ToJSON(), 1, 300), 1: tImport))
    If $IsObject(tImport) Do $$$AssertEquals(tImport.action _ "|" _ tImport.target.id _ "|" _ tImport.output.Name _ "|" _ tImport.output.Count, "created|import|" _ tName _ "|1", "created, on the import target the person named, the output naming the first item and the count")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exported", tName), tFirst, "the vendor's export of the re-created item equals the first")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "import-local", "import", {"fileName": "person.xml", "content": (tText)}, .tAgain) _ " " _ $Select($IsObject(tAgain): tAgain.%Get("code"), 1: ""), "409 ANALYTICS.FOLDERITEM.TAKEN", "a second import is refused as taken")
    Do $ClassMethod(..#BASE, "Drop", tName)
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "import", "import", tFile, .tServer), 200, "Import of a server file answers 200: " _ $Select($IsObject(tServer): $Extract(tServer.%ToJSON(), 1, 300), 1: tServer))
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 1, "and creates the item")
    Set tLocked = ..#MARKER _ "/PersonLocked.dashboard"
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "USER"
    Set tItem = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tItem.fullName = tLocked
    Set tItem.locked = 1
    Do tItem.%Save()
    Set tItem = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "delete", tLocked, "", .tRefused) _ " " _ $Select($IsObject(tRefused): tRefused.%Get("code"), 1: ""), "409 ANALYTICS.FOLDERITEM.LOCKED", "Delete of a locked item is refused")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tLocked), 3, "and leaves it")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Rows", tSince, tName, "analytics.folderitems.export"), 2, "the two exports are audited")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Rows", tSince, tName, "analytics.folderitems.import"), 2, "and the two imports")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Rows", tSince, tName, "analytics.folderitems.delete"), 1, "and the delete")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tName, .tMarker), 0, "and no agent marker is emitted for a person's action")
}

/// <p>The rows of the Folder items screen's read, as <code>&lt;http&gt;|&lt;whether the item named <var>pName</var> is among them&gt;</code>.</p>
ClassMethod ScreenHas(pName As %String) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.folderitems/read?ns=USER", "", .tHttp, .tRead)
    Set tFound = 0
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) {
        For tAt = 0:1:tRead.rows.%Size() - 1 {
            If tRead.rows.%Get(tAt).Name = pName Set tFound = 1
        }
    }
    Quit tHttp _ "|" _ tFound
}

/// <p>AC1, AC2, AC3, AC6: the agent's export, import and delete proposals are minted and confirmed: each leaves one audit row, the agent marker and one ledger row; the
/// export's card names the replaced file and the delete's is destructive with its consequence; an import reads back from the file the export wrote; and the item the
/// import created is answered by the Folder items screen's read and by the agent's read tool.</p>
/// <p>Mutation (Rule 19): make the confirmed import not commit in <method>OcuPilot.Port.AnalyticsPort.PerformFolderImport</method> (roll back instead) -- the integration leg goes red.</p>
Method TestTheAgentsThreeProposalsConfirmAndTheImportedItemReads()
{
    Set tName = ..#MARKER _ "/Agent.dashboard"
    Do $ClassMethod(..#BASE, "Item", tName)
    Set tFirst = $ClassMethod(..#BASE, "Exported", tName)
    Set tFile = $ClassMethod(..#BASE, "FileQuery", "agent.xml")
    Do ..Mint(..#EXPORTTOOL, {"Name": (tName), "root": (tFile.root), "path": (tFile.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "EXPLORER.EXPORT.REPLACES|0", "the export's card names the file it replaces and is not destructive")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Confirm", tProposal, .tAnswer, .tRaw), 200, "the export confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")), "the confirmed export answers an output")
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.output.path, "1|" _ tFile.path, "marked, and the answer names the file")
    Do ..AssertAgentRecords(tSince, tProposal, ..#EXPORTTOOL, tTurn, tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $ClassMethod(..#BASE, "Drop", tName)

    Do ..Mint(..#IMPORTTOOL, {"Name": (tName), "root": (tFile.root), "path": (tFile.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($ClassMethod(..#BASE, "Confirm", tProposal, .tAnswer, .tRaw), 200, "the import confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.createdId, "1|created|" _ tName, "marked, created, naming the first item")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exported", tName), tFirst, "the vendor's export of the item equals the first")
    Do ..AssertAgentRecords(tSince, tProposal, ..#IMPORTTOOL, tTurn, tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..ScreenHas(tName), "200|1", "the Folder items screen's read answers the imported item")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.folderitems.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set tFound = 0
    If $IsObject(tLeg.%Get("rows")) {
        For tAt = 0:1:tLeg.rows.%Size() - 1 {
            If tLeg.rows.%Get(tAt).Name = tName Set tFound = 1
        }
    }
    Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tFound, "200|1", "and so does the agent's read tool")

    Do ..EnableKey("analytics.folderitems.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tName)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.FOLDERITEM.DELETE|1", "the delete's card is destructive with its consequence code")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Confirm", tProposal, .tAnswer, .tRaw), 200, "the delete confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 0, "and the vendor reads it gone")
    Do ..AssertAgentRecords(tSince, tProposal, ..#DELETETOOL, tTurn, tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC3: the baseline ships the delete off for the agent and the export and import on, so a minted delete's confirm is refused <code>GOVERNANCE.DISABLED</code> and the item
/// is still there, while the person's own Delete runs and is not asked for the key (AD-22).</p>
/// <p>Mutation (Rule 19): flip the delete line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the denial leg and the confirm go red.</p>
Method TestTheDeleteKeyShipsOffForTheAgentOnly()
{
    Set tName = ..#MARKER _ "/Off.dashboard"
    Do $ClassMethod(..#BASE, "Item", tName)
    Do ..EnableKey("analytics.folderitems.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tName)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    For tCase = $ListBuild("analytics.folderitems.export", 1), $ListBuild("analytics.folderitems.import", 1), $ListBuild("analytics.folderitems.delete", 0) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
    Set tStatus = $ClassMethod(..#BASE, "Confirm", tProposal, .tConfirmed, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's delete is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 1, "and the item is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#BASE, "Act", "delete", tName, "", .tAnswer), 200, "the person's Delete runs")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 0, "and the item is gone")
}

/// <p>AC4: the agent's mint refuses what the write would refuse, before a proposal exists: a taken name, a first item that is not the one named, a file or root that is not
/// allowed, an item that is not there, a locked item's delete; and a confirm of an import whose file changed after the mint is refused as moved. Nothing is written.</p>
Method TestTheAgentsMintRefusesWhatTheWriteWouldRefuse()
{
    Set tHeld = ..#MARKER _ "/Refuse.dashboard"
    Set tLocked = ..#MARKER _ "/RefuseLocked.dashboard"
    Do $ClassMethod(..#BASE, "Item", tHeld)
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "USER"
    Set tItem = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tItem.fullName = tLocked
    Set tItem.locked = 1
    Do tItem.%Save()
    Set tItem = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "refuse.xml", $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", tHeld))), "the file is written")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "free.xml", $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", ..#MARKER _ "/Free.dashboard"))), "a second file is written")
    Set tTaken = $ClassMethod(..#BASE, "FileQuery", "refuse.xml")
    Set tFree = $ClassMethod(..#BASE, "FileQuery", "free.xml")
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Do ..MintRefused(..#IMPORTTOOL, {"Name": (tHeld), "root": (tTaken.root), "path": (tTaken.path)}, "ANALYTICS.FOLDERITEM.TAKEN")
    Do ..MintRefused(..#IMPORTTOOL, {"Name": "Other.dashboard", "root": (tFree.root), "path": (tFree.path)}, "ANALYTICS.FOLDERITEM.IMPORTSHAPE")
    Do ..MintRefused(..#IMPORTTOOL, {"Name": (tHeld), "root": "/nowhere/", "path": "a.xml"}, "PATH.")
    Do ..MintRefused(..#EXPORTTOOL, {"Name": (tHeld), "root": "/nowhere/", "path": "a.xml"}, "PATH.")
    Do ..MintRefused(..#EXPORTTOOL, {"Name": (..#MARKER _ "/Gone.dashboard"), "root": (tFree.root), "path": (tFree.path)}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#DELETETOOL, {"Name": (tLocked)}, "ANALYTICS.FOLDERITEM.LOCKED")
    Do ..MintRefused(..#DELETETOOL, {"Name": (..#MARKER _ "/Gone.dashboard")}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot"), tBefore, "nothing was written")
    Do ..Mint(..#IMPORTTOOL, {"Name": (..#MARKER _ "/Free.dashboard"), "root": (tFree.root), "path": (tFree.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "free.xml", $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", ..#MARKER _ "/Free.dashboard") _ $ClassMethod(..#BASE, "Doc", ..#MARKER _ "/Free2.dashboard"))), "the file is rewritten after the mint")
    Set tStatus = $ClassMethod(..#BASE, "Confirm", tProposal, .tAnswer, .tRaw)
    Do $$$AssertTrue((tStatus = 409) && (($Get(tRaw) [ "PROPOSAL.TARGETCHANGED") || ($Get(tRaw) [ "ANALYTICS.FOLDERITEM.IMPORTCHANGED")), "the confirm is refused as moved: " _ tStatus _ " " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", ..#MARKER _ "/Free.dashboard"), 0, "and nothing was imported")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
