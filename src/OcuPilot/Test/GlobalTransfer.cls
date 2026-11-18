/// <p>Pins Story 21.17's export and import of a global (AD-6, AD-10, AD-21, AD-22, AD-36, AD-51, AD-53, AD-61): the global's size and digest read through
/// <class>OcuPilot.Port.GlobalPort</class>; the Globals list's export to a server file and its import, and the agent's both through mint and confirm,
/// round-tripping a global of the test's own whose nodes are plain, a <code>$List</code>, longer than a vendor line and non-Latin; an export of a global
/// that holds nothing, is OcuPilot's own or is too large refused before the vendor's export is called, and an answer the capture refused or an XML above the
/// bound refused with nothing written; a replacing import versioned by content (DW-2608) and refused when the global moved or is too large to replace; and
/// the arm that judges an import's globals and never an export.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and the manager directory as an allowed root. Each test makes and kills its own
/// <code>^ZZOcuGlb&lt;pid&gt;</code> in <code>HSCUSTOM</code>, removes the files <class>OcuPilot.Test.GlobalTransferProbe</class> names, and snapshots the
/// stored governance policy before and puts it back after. It loads no code global and no OcuPilot global.</p>
Class OcuPilot.Test.GlobalTransfer Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "HSCUSTOM";

Parameter PROBE = "OcuPilot.Test.GlobalTransferProbe";

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

Parameter SCREEN = "explorer.globals";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.ExplorerGlobalExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.ExplorerGlobalImport";

Parameter IMPORTKEY = "explorer.globals.import";

/// <p>The name of the test's own global, without <code>^</code>.</p>
Property PreparedName As %String;

Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedName = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedName = "ZZOcuGlb" _ $Job
    Do ..Remove()
    Do ..ClearFixtures()
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove()
    Do ..ClearFixtures()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

Method ClearFixtures()
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Kill the test's global, and the <code>%</code> copy a test of the arm may name.</p>
Method Remove()
{
    Set tRoot = "^" _ ..PreparedName
    Kill @tRoot
    Set tPercent = "^%" _ ..PreparedName
    Kill @tPercent
}

/// <p>The test's global: a plain node, a <code>$List</code> node, a node longer than a vendor line, a non-Latin node and a node with a node below it.</p>
Method Make()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = "plain"
    Set @tRoot@(2) = $ListBuild("a", "b", 3)
    Set @tRoot@(3) = $Translate($Justify("", 40000), " ", "x")
    Set @tRoot@(4) = $Char(955, 8364, 26085)
    Set @tRoot@("t", 1) = "below"
}

/// <p>Every node of the test's global, each as its reference and value, one per line: what a round trip must give back.</p>
Method Walk() As %String
{
    Set tRoot = "^" _ ..PreparedName
    Set tText = ""
    Set tNext = $Select($Data(@tRoot) # 2: tRoot, 1: $Query(@tRoot))
    While tNext '= "" {
        Set tText = tText _ tNext _ "=" _ @tNext _ $Char(10)
        Set tNext = $Query(@tNext)
    }
    Quit tText
}

/// <p>The file values naming probe file <var>pName</var>.</p>
ClassMethod FileValues(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", pName))}
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> with <var>pValues</var>: the status and refusal code as <code>status code</code>, and the
/// parsed answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %String
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ ..#SCREEN _ "/action?ns=" _ ..#NAMESPACE, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: ""), 1: "0 ")
}

/// <p>The agent's call of tool <var>pTool</var> with <var>pArgs</var> in the namespace, inside a completed turn: <var>pProposal</var> is the tool's
/// <code>View</code>, <var>pHttp</var> and <var>pFault</var> its refusal.</p>
Method MintFor(pTool As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(pTool, "View", "", pArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Confirm <var>pProposal</var> in process as the running account: <code>status code</code>, the answer in <var>pResult</var>.</p>
Method ConfirmFor(pProposal As %DynamicObject, Output pResult) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .tHttp, .tCode, .tDetail)
    Quit $Select($$$ISOK(tSC): "200 ", 1: +$Get(tHttp) _ " " _ $Get(tCode))
}

/// <p>The agent's call of tool class <var>pTool</var> sent through the dispatcher in a completed turn: whether it was refused as an error, with the code, and the
/// minted proposal.</p>
Method DispatchFor(pTool As %String, pInput As %DynamicObject, Output pProposal) As %String
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit "seed"
    Set tUse = {"type": "tool_use", "id": "toolu_global"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName($Parameter(pTool, "TOOLNAME")), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) Quit "dispatch"
    Set tContent = tResults.%Get(0).%Get("content")
    Try {
        Set pProposal = ##class(%DynamicObject).%FromJSON(tContent)
    } Catch {
        Set pProposal = ""
    }
    Quit $Select(tResults.%Get(0).%Get("is_error"): "error " _ $Select($IsObject(pProposal): pProposal.%Get("code"), 1: ""), 1: "ok")
}

/// <p>One of the globals port's reads of the test's global, or of <var>pName</var>, as <code>http code</code>, with the answer in <var>pAnswer</var>.</p>
ClassMethod Read(pType As %String, pName As %String, Output pAnswer As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.GlobalPort).Invoke("Globals", pType, .tQuery, "", .pAnswer, .tHttp, .tFault)
    Quit tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The atelier port's <var>pType</var> of <var>pEndpoint</var> (through the fixture's seams) as <code>http code</code>, with the answer in
/// <var>pAnswer</var>; <var>pPairs</var> is a <code>key=value</code> list besides the namespace.</p>
ClassMethod Atelier(pEndpoint As %String, pType As %String, pPairs As %List, Output pAnswer) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    For tI = 1:1:$ListLength(pPairs) {
        Set tQuery($Piece($List(pPairs, tI), "=", 1)) = $Piece($List(pPairs, tI), "=", 2, *)
    }
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", pEndpoint, pType, .tQuery, "", .pAnswer, .tHttp, .tFault)
    Quit tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The globals port's reads of the test's own global (<code>SIZE</code> and <code>DIGEST</code>), pinned by what an independent walk finds: the characters
/// of every node's reference and value, the root included; a digest that is the same across reads, is the SHA-256 of each node's reference length,
/// reference, value length and value as UTF-8, and moves with any value edit or subscript change, and is read for a value whose UTF-8 is longer than the longest string; a global that holds nothing, which is a 404 to
/// <code>SIZE</code> and an undefined global to <code>DIGEST</code>; a name beginning with OcuPilot, refused 403 <code>GLOBAL.OWNDATA</code> to
/// <code>SIZE</code> alone; and the bound, passed by one character.</p>
/// <p>Mutation (Rule 19): count only the value's characters in <method>OcuPilot.Port.GlobalPort.VendorTotals</method> -> the size assertion goes red; leave the
/// value out of the digest batch -> the known-answer and value-edit assertions go red; drop the bound check -> the bound assertions go red; convert a batch to UTF-8 in one call in
/// <method>OcuPilot.Port.GlobalPort.WriteDigestBatch</method> -> the wide-value assertion goes red.</p>
Method TestTheSizeAndTheDigestReadTheWholeGlobal()
{
    Set tRoot = "^" _ ..PreparedName
    Do ..Make()
    Set @tRoot = "root"
    Set tExpected = $Length(tRoot) + 4
    Set tNext = $Query(@tRoot)
    While tNext '= "" {
        Set tExpected = tExpected + $Length(tNext) + $Length(@tNext)
        Set tNext = $Query(@tNext)
    }
    Do $$$AssertEquals(..Read("SIZE", ..PreparedName, .tSize) _ " " _ tSize.Characters, "200  " _ tExpected, "the size is every node's reference and value, the root's included")
    Do $$$AssertEquals(..Read("DIGEST", ..PreparedName, .tFirst), "200 ", "a digest is read")
    Do ..Read("DIGEST", ..PreparedName, .tSecond)
    Do $$$AssertTrue(tFirst.Defined && (tFirst.Digest '= "") && (tFirst.Digest = tSecond.Digest), "and is the same across reads")
    Set @tRoot@(1) = "plaiN"
    Do ..Read("DIGEST", ..PreparedName, .tEdited)
    Do $$$AssertNotEquals(tEdited.Digest, tFirst.Digest, "any value edit moves it")
    Set @tRoot@(1) = "plain"
    Do ..Read("DIGEST", ..PreparedName, .tBack)
    Do $$$AssertEquals(tBack.Digest, tFirst.Digest, "and the same nodes give it back")
    Kill @tRoot@("t", 1)
    Set @tRoot@("u", 1) = "below"
    Do ..Read("DIGEST", ..PreparedName, .tMoved)
    Do $$$AssertNotEquals(tMoved.Digest, tFirst.Digest, "as does a subscript change under the same value")
    Kill @tRoot
    Set @tRoot@("k") = "v" _ $Char(233, 955)
    Set tInput = $Length(tRoot _ "(""k"")") _ ":" _ tRoot _ "(""k"")" _ "3:v" _ $Char(233, 955)
    Set tKnown = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(tInput, "O", "UTF8"))), "L")
    Do ..Read("DIGEST", ..PreparedName, .tKnownRead)
    Do $$$AssertEquals(tKnownRead.Digest, tKnown, "the digest is the SHA-256 of each node's reference length, reference, value length and value as UTF-8")
    Set @tRoot@("w") = $Translate($Justify("", 1300000), " ", $Char(26085))
    Do $$$AssertEquals(..Read("DIGEST", ..PreparedName, .tWide) _ " " _ $Select($IsObject($Get(tWide)): tWide.Defined, 1: ""), "200  1", "a value whose UTF-8 is longer than the longest string is digested")
    Kill @tRoot
    Do $$$AssertEquals(..Read("SIZE", ..PreparedName), "404 GLOBAL.NOTFOUND", "a global that holds nothing is not found")
    Do $$$AssertEquals(..Read("DIGEST", ..PreparedName, .tNone) _ " " _ tNone.Defined _ " " _ tNone.Digest, "200  0 ", "and is an undefined global with no digest")
    Do $$$AssertEquals(..Read("SIZE", "OcuPilotZZ" _ $Job), "403 GLOBAL.OWNDATA", "a name beginning with OcuPilot is not read for an export")
    Do $$$AssertEquals(..Read("SIZE", "ocupilotzz" _ $Job), "403 GLOBAL.OWNDATA", "in any case")
    Do $$$AssertEquals(..Read("DIGEST", "OcuPilotZZ" _ $Job, .tOwn) _ " " _ tOwn.Defined, "200  0", "while a digest, which versions an import, is not refused")
    Set @tRoot = $Justify("", 3000000 - $Length(tRoot))
    Do $$$AssertEquals(..Read("SIZE", ..PreparedName, .tAt) _ " " _ tAt.Characters, "200  3000000", "a global of exactly the bound is read")
    Set @tRoot = $Justify("", 3000001 - $Length(tRoot))
    Do $$$AssertEquals(..Read("SIZE", ..PreparedName), "422 GLOBAL.TOOLARGE", "and one character more is too large")
    Do $$$AssertEquals(..Read("DIGEST", ..PreparedName), "422 GLOBAL.TOOLARGE", "to a digest as well")
    Do $$$AssertEquals(##class(OcuPilot.Api.GlobalError).ReasonFor("GLOBAL.TOOLARGE"), "This global is too large for OcuPilot to export or replace: the most is 3,000,000 characters.", "with the ruled sentence")
}

/// <p>AC1. The test's global, exported from the Globals list to a server file, killed and imported from the list, and again exported by the agent's proposal,
/// killed, and imported by the agent's proposal, each confirmed, is as it was: every node, a <code>$List</code>, a value over a vendor line and a non-Latin value
/// included. The agent's export card names the global's document and the file with the replacement consequence.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.AtelierPort.WholeLines</method> from the export's lines in <method>OcuPilot.Port.AtelierPort.ExportSet</method>
/// -> the long value breaks and both round trips go red.</p>
Method TestAGlobalRoundTripsThroughTheScreenAndTheAgent()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    Do ..Make()
    Set tBefore = ..Walk()
    Do $$$AssertTrue($Length(tBefore) > 40000, "the global holds a value over a vendor line")
    Set tStatus = ..Act("export", ..PreparedName, ..FileValues("screen.xml"), .tAnswer)
    Do $$$AssertEquals(tStatus, "200 ", "the Globals list exports it to a server file: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue($ClassMethod(tProbe, "FileExists", "screen.xml") && ($ClassMethod(tProbe, "ReadFile", "screen.xml") [ ("<Sub>" _ tRoot _ "</Sub>")), "the file holds the vendor's XML of the global")
    Kill @tRoot
    Set tValues = ..FileValues("screen.xml")
    Do tValues.%Set("Compile", "false", "string")
    Set tStatus = ..Act("import", "import", tValues, .tAnswer)
    Do $$$AssertEquals(tStatus, "200 ", "and imports it back from the list: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Walk(), tBefore, "every node is as it was")
    Set tArgs = ..FileValues("agent.xml")
    Do tArgs.%Set("Names", ..PreparedName, "string")
    Set tOutcome = ..DispatchFor(..#EXPORTTOOL, tArgs, .tExport)
    Do $$$AssertEquals(tOutcome, "ok", "the agent's export is minted through the dispatcher: " _ $Select($IsObject(tExport): tExport.%ToJSON(), 1: ""))
    If '$IsObject(tExport) Quit
    Set tCard = tExport.changed.%ToJSON()
    Do $$$AssertTrue((tCard [ (..PreparedName _ ".GBL")) && (tCard [ "OcuProbe2117/agent.xml"), "its card names the global's document and the file: " _ tCard)
    Do $$$AssertEquals(..ConfirmFor(tExport, .tResult), "200 ", "and is confirmed")
    Do $$$AssertTrue($ClassMethod(tProbe, "FileExists", "agent.xml"), "which writes the file")
    Kill @tRoot
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tImportArgs = {"Id": "import", "Compile": false}
    Do tImportArgs.%Set("root", tArgs.root, "string")
    Do tImportArgs.%Set("path", tArgs.path, "string")
    Set tOutcome = ..DispatchFor(..#IMPORTTOOL, tImportArgs, .tImport)
    Do $$$AssertEquals(tOutcome, "ok", "the agent's import is minted: " _ $Select($IsObject(tImport): tImport.%ToJSON(), 1: ""))
    If '$IsObject(tImport) Quit
    Do $$$AssertTrue(tImport.changed.%ToJSON() [ (..PreparedName _ ".gbl new (sha256 "), "its card shows the reviewed document, which the namespace does not hold")
    Do $$$AssertEquals($Data(@tRoot), 0, "nothing is loaded by the mint")
    Do $$$AssertEquals(..ConfirmFor(tImport, .tResult), "200 ", "and the confirm loads it")
    Do $$$AssertEquals(..Walk(), tBefore, "every node is as it was")
}

/// <p>The Globals list's export to this browser answers the XML lines of a global of Latin-1 values short enough for the test client's single read of an answer, which the list's local import loads back as it was; and the export tool
/// takes exactly one global's name, as the Globals list reports it: a list of names, a name with <code>^</code> and an empty name are refused, and the port reads
/// one name as its <code>.GBL</code> document.</p>
/// <p>Mutation (Rule 19): answer no lines from the no-file branch of <method>OcuPilot.Port.AtelierPort.ExportSet</method> for a global -> the browser leg goes red;
/// drop the <code>Globals</code> case from <method>OcuPilot.Port.AtelierPort.SetNames</method> -> the name legs go red.</p>
Method TestAnExportToThisBrowserAnswersTheLinesAndANameIsOneGlobal()
{
    Set tRoot = "^" _ ..PreparedName
    Do ..Make()
    Kill @tRoot@(3), @tRoot@(4)
    Set tBefore = ..Walk()
    Set tStatus = ..Act("export-browser", ..PreparedName, "", .tAnswer)
    Do $$$AssertEquals(tStatus, "200 ", "the Globals list exports it to this browser (" _ tStatus _ "): " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 300))
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("output")) Quit
    Set tText = ""
    Set tIterator = tAnswer.output.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Do $$$AssertTrue((tText [ "<Export") && (tText [ ("<Sub>" _ tRoot _ "</Sub>")), "its output is the XML lines of the global")
    Kill @tRoot
    Set tStatus = ..Act("import-local", "import", {"fileName": "USER-export.xml", "content": (tText), "Compile": "false"}, .tAnswer)
    Do $$$AssertEquals(tStatus, "200 ", "the local file imports it back: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 300))
    Do $$$AssertEquals(..Walk(), tBefore, "every node is as it was")
    For tBad = "A,B", "^A", "" {
        Do $$$AssertTrue($ClassMethod(..#EXPORTTOOL, "SetProblem", tBad) '= "", "the export tool refuses the names '" _ tBad _ "'")
        Do $$$AssertEquals($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames("Globals", tBad)), 0, "and the port reads no document for '" _ tBad _ "'")
    }
    Do $$$AssertEquals($ClassMethod(..#EXPORTTOOL, "SetProblem", "ZZOcuGlbA"), "", "one name is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).SetNames("Globals", "ZZOcuGlbA"), $ListBuild("ZZOcuGlbA.GBL"), "and read as its document")
}

/// <p>AC2. An export of a global that holds nothing, one that is OcuPilot's own, or one over the bound is refused by the Globals list and at the agent's mint
/// with its own code, 404 <code>GLOBAL.NOTFOUND</code>, 403 <code>GLOBAL.OWNDATA</code> or 422 <code>GLOBAL.TOOLARGE</code>, with no file written; and the
/// vendor's export is not called for any of them.</p>
/// <p>Mutation (Rule 19): skip the size read in <method>OcuPilot.Port.AtelierPort.ExportSet</method> for a global -> the vendor is called for the missing and
/// the own global and this goes red.</p>
Method TestAnExportOfAMissingOwnOrOversizedGlobalIsRefusedBeforeTheVendor()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    Set tBig = $Justify("", 800000)
    For tI = 1:1:4 Set @tRoot@(tI) = tBig
    Set tOwn = "OcuPilotZZ" _ $Job
    For tCase = $ListBuild(..PreparedName _ "Gone", "404 GLOBAL.NOTFOUND"), $ListBuild(tOwn, "403 GLOBAL.OWNDATA"), $ListBuild(..PreparedName, "422 GLOBAL.TOOLARGE") {
        Set tName = $List(tCase, 1)
        Set tStatus = ..Act("export", tName, ..FileValues("refused.xml"), .tAnswer)
        Do $$$AssertEquals(tStatus, $List(tCase, 2), "the list's export of " _ tName _ " is refused: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
        Set tArgs = ..FileValues("refused.xml")
        Do tArgs.%Set("Names", tName, "string")
        Do ..MintFor(..#EXPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $List(tCase, 2), "and so is the agent's, at the mint")
        Do $$$AssertTrue('$IsObject($Get(tProposal)) && '$ClassMethod(tProbe, "FileExists", "refused.xml"), "with nothing minted and no file written")
        Do $ClassMethod(..#FIXTURE, "Clear")
        Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
        Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
        Set tSaid = ..Atelier("Globals", "EXPORT", $ListBuild("names=" _ tName, "root=" _ tArgs.root, "path=" _ tArgs.path), .tNone)
        Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), $List(tCase, 2) _ " 0", "the port calls no route for it: " _ tSaid)
    }
}

/// <p>An export whose answer is above the capture's ceiling, which a global of many short nodes whose node text is well under the bound reaches, and one whose XML lines
/// together pass the bound, are 422 <code>GLOBAL.TOOLARGE</code> and write no file, the first through the live vendor and the second through a canned route.</p>
/// <p>Mutation (Rule 19): drop the length check after <method>OcuPilot.Port.AtelierPort.WholeLines</method> in <method>OcuPilot.Port.AtelierPort.ExportSet</method>
/// -> the canned leg goes red; drop the ceiling mapping there -> the live leg goes red, answering 503.</p>
Method TestAnAnswerTheCaptureRefusedOrXmlAboveTheBoundIsTooLarge()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    For tI = 1:1:90000 Set @tRoot@(tI) = "x"
    Do $$$AssertEquals(..Read("SIZE", ..PreparedName), "200 ", "a global of 90,000 one-character nodes is under the bound")
    Set tStatus = ..Act("export", ..PreparedName, ..FileValues("many.xml"), .tAnswer)
    Do $$$AssertEquals(tStatus, "422 GLOBAL.TOOLARGE", "and its export, whose answer the capture refuses, is too large: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "many.xml"), "with no file written")
    Kill @tRoot
    Set @tRoot@(1) = "x"
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Set tContent = []
    Set tLine = $Translate($Justify("", 30000), " ", "x")
    For tI = 1:1:105 Do tContent.%Push(tLine)
    Set tEnvelope = {"status": {"errors": [], "summary": ""}, "console": []}
    Do tEnvelope.%Set("result", {"content": (tContent)})
    Do $ClassMethod(..#FIXTURE, "Arm", "ExportToXMLFile", "200 OK", tEnvelope.%ToJSON())
    Set tFile = ..FileValues("lines.xml")
    Set tSaid = ..Atelier("Globals", "EXPORT", $ListBuild("names=" _ ..PreparedName, "root=" _ tFile.root, "path=" _ tFile.path), .tNone)
    Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "422 GLOBAL.TOOLARGE 1", "XML lines of 3,150,000 characters are too large, after the vendor's export ran once")
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "lines.xml"), "with no file written")
}

/// <p>Only an answer above the capture's ceiling, in one string or in lines that together pass it, is 422 <code>GLOBAL.TOOLARGE</code> for a global's export, and
/// it logs no fault; a capture that cannot be ended
/// is 503 <code>PORT.UNAVAILABLE</code> and a refused route is 403, each with its fault logged and no file written (canned routes; the export's route runs once each).</p>
/// <p>Mutation (Rule 19): convert every 503 of a global's export in <method>OcuPilot.Port.AtelierPort.ExportSet</method>, or count a capture that cannot be ended as the
/// ceiling in <method>OcuPilot.Port.AtelierPort.Route</method> -> the capture-end leg goes red; log the ceiling's fault in <method>OcuPilot.Port.AtelierPort.Outcome</method>
/// although the caller owns it -> the ceiling leg goes red on the empty log; set the ceiling for any failed call -> the refused leg goes red; count lines that
/// together pass the ceiling as a capture that cannot be ended in <method>OcuPilot.Port.AtelierPort.Route</method> -> the lines leg goes red.</p>
Method TestOnlyTheCaptureCeilingIsTooLargeAndAnyOtherPortFailureStaysUnavailable()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = "x"
    Set tFile = ..FileValues("ceiling.xml")
    Set tPairs = $ListBuild("names=" _ ..PreparedName, "root=" _ tFile.root, "path=" _ tFile.path)
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "ArmOversize", "ExportToXMLFile")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSaid = ..Atelier("Globals", "EXPORT", tPairs, .tNone)
    Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "422 GLOBAL.TOOLARGE 1", "an answer above the capture's ceiling is too large, after the vendor's export ran once")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and logs no fault")
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "ceiling.xml"), "with no file written")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "ArmOversizeLines", "ExportToXMLFile")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSaid = ..Atelier("Globals", "EXPORT", tPairs, .tNone)
    Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "422 GLOBAL.TOOLARGE 1", "lines that together pass the capture's ceiling are too large, after the vendor's export ran once and succeeded")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and log no fault")
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "ceiling.xml"), "with no file written")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "ArmEndFailure")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSaid = ..Atelier("Globals", "EXPORT", tPairs, .tNone)
    Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "503 PORT.UNAVAILABLE 1", "a capture that cannot be ended is unavailable, not too large, after the vendor's export ran once")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "could not end its capture", "and its fault is logged: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "ceiling.xml"), "with no file written")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "ArmThrow", "ExportToXMLFile", "<PROTECT>")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSaid = ..Atelier("Globals", "EXPORT", tPairs, .tNone)
    Do $$$AssertEquals(tSaid _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "403 PORT.ACCESSDENIED 1", "a route the vendor refuses is access denied, not too large, after the vendor's export ran once")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "ExportToXMLFile was refused", "and its fault is logged: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertTrue('$ClassMethod(tProbe, "FileExists", "ceiling.xml"), "with no file written")
}

/// <p>AC3 (DW-2608). An import that replaces the existing global reads a summary that names its content, <code>&lt;name&gt;.gbl replaces sha256 &lt;digest&gt;</code>,
/// the same across two previews a second apart, and a new global reads <code>new</code>; the Globals list's import loads it and the global equals the file's;
/// the agent's import, minted over the global and confirmed a second later, loads it; and one confirmed after a node changed is refused 409
/// <code>EXPLORER.IMPORT.CHANGED</code> with nothing loaded.</p>
/// <p>Mutation (Rule 19): take the vendor's time for a <code>.gbl</code> document in <method>OcuPilot.Port.AtelierPort.Examine</method> -> the equal-previews leg
/// and the agent's confirm a second later go red; digest the references without the values in <method>OcuPilot.Port.GlobalPort.VendorTotals</method> -> the moved leg goes red, the confirm loading.</p>
Method TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    Do ..Make()
    Set tBefore = ..Walk()
    Set tValues = ..FileValues("replace.xml")
    Do $$$AssertEquals(..Act("export", ..PreparedName, tValues), "200 ", "the global is exported")
    Set tPairs = $ListBuild("id=import", "root=" _ tValues.root, "path=" _ tValues.path)
    Set tSaid = ..Atelier("Globals", "PREVIEW", tPairs, .tFirst)
    Hang 1.1
    Do ..Atelier("Globals", "PREVIEW", tPairs, .tSecond)
    Do $$$AssertTrue($IsObject(tFirst) && ($Extract(tFirst.documents, 1, $Length(..PreparedName _ ".gbl replaces sha256 ")) = (..PreparedName _ ".gbl replaces sha256 ")) && ($Length(tFirst.documents, " ") = 6), "the summary of the existing global names its content: " _ tSaid _ " " _ $Select($IsObject(tFirst): tFirst.documents, 1: ""))
    Do $$$AssertEquals($Select($IsObject(tSecond): tSecond.documents, 1: "2"), $Select($IsObject(tFirst): tFirst.documents, 1: "1"), "and is the same a second later")
    Kill @tRoot
    Do ..Atelier("Globals", "PREVIEW", tPairs, .tNew)
    Do $$$AssertTrue($IsObject(tNew) && (tNew.documents [ (..PreparedName _ ".gbl new (sha256 ")), "a global the namespace does not hold reads new: " _ $Select($IsObject(tNew): tNew.documents, 1: ""))
    Do ..Make()
    Set @tRoot@(1) = "changed"
    Set tValues = ..FileValues("replace.xml")
    Do tValues.%Set("Compile", "false", "string")
    Do $$$AssertEquals(..Act("import", "import", tValues, .tAnswer), "200 ", "the Globals list's import replaces it: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Walk(), tBefore, "and the global is the file's")
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tArgs = {"Id": "import", "Compile": false}
    Do tArgs.%Set("root", tValues.root, "string")
    Do tArgs.%Set("path", tValues.path, "string")
    Set @tRoot@(1) = "changed"
    Do ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's import is minted over the existing global: " _ ..Json($Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Hang 1.1
    Do $$$AssertEquals(..ConfirmFor(tProposal, .tResult), "200 ", "a second later, over the unchanged global, the confirm is answered")
    Do $$$AssertEquals(..Walk(), tBefore, "and loads the file over it")
    Set @tRoot@(1) = "changed"
    Do ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's import is minted over the existing global again: " _ ..Json($Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set @tRoot@(2) = "moved"
    Do $$$AssertEquals(..ConfirmFor(tProposal, .tResult), "409 " _ ##class(OcuPilot.Api.AtelierError).#IMPORTCHANGED, "a node that changed after the mint refuses the confirm")
    Do $$$AssertEquals(@tRoot@(2), "moved", "and nothing is loaded")
}

/// <p>An import is refused 422 <code>GLOBAL.TOOLARGE</code> at its preview and its write when the global it would replace is over the bound, with that global left
/// as it is.</p>
/// <p>Mutation (Rule 19): leave the refusal out of <method>OcuPilot.Port.AtelierPort.Examine</method>'s versioning loop -> this goes red.</p>
Method TestAGlobalTooLargeToReplaceRefusesThePreviewAndTheWrite()
{
    Set tRoot = "^" _ ..PreparedName
    Do ..Make()
    Set tValues = ..FileValues("large.xml")
    Do $$$AssertEquals(..Act("export", ..PreparedName, tValues), "200 ", "the global is exported")
    Kill @tRoot
    Set tBig = $Justify("", 800000)
    For tI = 1:1:4 Set @tRoot@(tI) = tBig
    Set tSaid = ..Atelier("Globals", "PREVIEW", $ListBuild("id=import", "root=" _ tValues.root, "path=" _ tValues.path), .tNone)
    Do $$$AssertEquals(tSaid, "422 GLOBAL.TOOLARGE", "the preview is refused")
    Do tValues.%Set("Compile", "false", "string")
    Do $$$AssertEquals(..Act("import", "import", tValues, .tAnswer), "422 GLOBAL.TOOLARGE", "and so is the write")
    Do $$$AssertEquals($Length(@tRoot@(1)) _ " " _ $Data(@tRoot@(4)), "800000 1", "the global is left as it was")
}

/// <p>AC4. An import whose file holds a <code>%</code>-global is refused 403 <code>PROHIBITED.PROTECTEDGLOBAL</code> before anything loads on both callers; at the
/// arm a code global is refused, an ordinary global and a file naming classes alone are not, and one of OcuPilot's own is refused as code; and an export is
/// never judged, an OcuPilot-named global included.</p>
/// <p>Mutation (Rule 19): drop the <code>global</code> import routing in <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -> the arm rows and both
/// end-to-end legs go red.</p>
Method TestAnImportOfACodeOrPercentGlobalIsRefusedAndAnExportIsNeverJudged()
{
    Set tProbe = ..#PROBE
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("global", ..#NAMESPACE, "import", .tImportRef), "the import's target key is built")
    For tCase = $ListBuild("oddDEP.GBL new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("%" _ ..PreparedName _ ".gbl new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild(..PreparedName _ ".GBL new", "0 "), $ListBuild(..PreparedName _ ".gbl replaces sha256 abc, Foo.Bar.cls new (sha256 abc)", "0 "), $ListBuild("Foo.Bar.cls new, oddDEP.GBL new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("OcuPilotZZ.gbl new", "1 PROHIBITED.OCUPILOTCODE") {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("explorer.globals.import", tImportRef, {"documents": ($List(tCase, 1))}.%ToJSON(), "[]", .tProhibits, .tCode)
        Do $$$AssertEquals($Select($$$ISOK(tSC): tProhibits _ " " _ tCode, 1: "error"), $List(tCase, 2), "an import of " _ $List(tCase, 1))
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("global", ..#NAMESPACE, "OcuPilotZZ" _ $Job, .tExportRef), "an export's target key is built")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("explorer.globals.export", tExportRef, "{}", "[]", .tProhibits, .tCode)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tProhibits _ " " _ tCode, 1: "error"), "0 ", "an export of a global named for OcuPilot is not judged")
    Set @tRoot@(1) = "a"
    Set tSC = $System.OBJ.Export(..PreparedName _ ".GBL", ..Directory("source.xml"), "/nodisplay")
    Do $$$AssertStatusOK(tSC, "the instance's export of a global is made")
    Set tText = $ClassMethod(tProbe, "ReadFile", "source.xml")
    Kill @tRoot
    Set tPercent = "^%" _ ..PreparedName
    Set tText = $Replace(tText, "<Sub>" _ tRoot _ "</Sub>", "<Sub>" _ tPercent _ "</Sub>")
    Do $$$AssertTrue(tText [ ("<Sub>" _ tPercent _ "</Sub>"), "its file names the % global")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "percent.xml", "content": (tText), "Compile": "false"}, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "403 PROHIBITED.PROTECTEDGLOBAL " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#PROTECTEDGLOBALREASON, "the list's import is refused with the published sentence")
    Do $$$AssertEquals($Data(@tPercent), 0, "and the global stays undefined")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "WriteFile", "percent.xml", tText), "the file is written for the agent")
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the import key is enabled through its stored setting")
    Set tArgs = ..FileValues("percent.xml")
    Do tArgs.%Set("Id", "import", "string")
    Do tArgs.%Set("Compile", 0, "boolean")
    Do ..MintFor(..#IMPORTTOOL, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's import is minted: " _ ..Json($Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..ConfirmFor(tProposal, .tResult), "403 PROHIBITED.PROTECTEDGLOBAL", "and refused at the confirm")
    Do $$$AssertEquals($Data(@tPercent), 0, "the global stays undefined")
}

/// <p>The Globals endpoint renders a script for its export and its import alone (AD-59): the export is <code>$System.OBJ.Export</code> of the global's
/// <code>.GBL</code> document to the file the root and path name, the import <code>$System.OBJ.Load</code> of it, and every other type renders none.</p>
/// <p>Mutation (Rule 19): drop the <code>.GBL</code> extension in <method>OcuPilot.Port.AtelierPort.Snippet</method> -> the export assertion goes red.</p>
Method TestTheTransfersRenderTheirScripts()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Set tForms = ""
    For tType = "EXPORT", "IMPORT", "EXPORTDOCS", "PREVIEW", "IMPORTTARGET", "LIST" {
        Set tForms = tForms _ $Select(tForms = "": "", 1: ",") _ $ClassMethod(tPort, "SnippetForm", "Globals", tType)
    }
    Do $$$AssertEquals(tForms, "objectscript,objectscript,,,,", "only the export and the import render a script")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("names") = ..PreparedName
    Set tQuery("root") = "/tmp/"
    Set tQuery("path") = "g.xml"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Globals", "EXPORT", .tQuery)
    Do $$$AssertTrue((tSteps.%Size() = 1) && (tSteps.%Get(0).text [ ("$System.OBJ.Export(""" _ ..PreparedName _ ".GBL""")), "the export's script exports the global's document: " _ tSteps.%ToJSON())
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("root") = "/tmp/"
    Set tQuery("path") = "g.xml"
    Set tQuery("Compile") = 0
    Set tSteps = $ClassMethod(tPort, "Snippet", "Globals", "IMPORT", .tQuery)
    Do $$$AssertTrue((tSteps.%Size() = 1) && (tSteps.%Get(0).text [ "$System.OBJ.Load("), "and the import's loads the file: " _ tSteps.%ToJSON())
}

/// <p>The probe file <var>pName</var>'s full name.</p>
ClassMethod Directory(pName As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Directory") _ pName
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject($Get(pBody)) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>The two tools declare what the story rules: names, the Globals endpoint of the atelier port, write types, who reaches each, the baseline keys (export on,
/// import off and destructive), the row actions each takes and the classic pages whose operation each performs; and the agent's import call at the baseline is
/// refused by governance while the tool stays advertised.</p>
/// <p>Mutation (Rule 19): set <code>explorer.globals.import</code> <code>true</code> in <method>OcuPilot.Kernel.Governance.Baseline</method> -> the baseline and
/// dispatch assertions go red.</p>
Method TestTheToolsDeclareTheirWritePathAndTheImportKeyShipsOff()
{
    For tCase = $ListBuild(..#EXPORTTOOL, "explorer.globals.export", "EXPORT", "0", "export,export-browser", 1), $ListBuild(..#IMPORTTOOL, "explorer.globals.import", "IMPORT", "1", "import,import-local", 0) {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "Advertised"), $List(tCase, 2) _ "|OcuPilot.Port.AtelierPort|Globals|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4) _ "|1", $List(tCase, 2) _ ": name, port, endpoint, write type, destructive and advertised")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionIds")), $List(tCase, 5), $List(tCase, 2) _ ": its row actions")
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 2), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 " _ $List(tCase, 6), $List(tCase, 2) _ ": its key is in the baseline and ships " _ $Select($List(tCase, 6): "enabled", 1: "disabled"))
    }
    Set tArgs = ..FileValues("none.xml")
    Do tArgs.%Set("Id", "import", "string")
    Do tArgs.%Set("Compile", 1, "boolean")
    Set tOutcome = ..DispatchFor(..#IMPORTTOOL, tArgs, .tAnswer)
    Do $$$AssertEquals(tOutcome, "error " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's import is refused by governance at the baseline")
    Do $$$AssertEquals($ClassMethod(..#IMPORTTOOL, "Advertised"), 1, "while the tool stays advertised")
}

}
