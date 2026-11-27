/// <p>Pins Story 24.18 Batch 1's export and import end to end against probe HL7 schemas in <code>USER</code> (AD-6, AD-10, AD-15, AD-21, AD-22, AD-39, AD-53, AD-62): a schema exported to this browser, deleted
/// and imported back from a local file, and exported to a server file, deleted and imported back from it by the agent, each reads back identical to the vendor's own export of the first; each import
/// and export leaves one <code>ConfigChange</code> of OcuPilot's own that holds no text; the agent's export and import go through mint and confirm, the import behind its key and a destructive card;
/// an import over a held schema replaces it whole; and a standard schema exports and is never imported back.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs, and the manager directory as an allowed root. It writes and removes the files
/// <class>OcuPilot.Test.ExplorerTransferProbe</class> names.</p>
Class OcuPilot.Test.InteropHl7SchemaTransfer Extends OcuPilot.Test.InteropHl7Case
{

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter IMPORTKEY = "interop.hl7schemas.import";

/// <p>The probe the replace-whole test imports over, a name no other test's audit rows carry.</p>
Parameter REPLACED = "OcuProbe2418r";

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##super()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Quit ##super()
}

/// <p>The file values naming probe file <var>pName</var>.</p>
ClassMethod FileValues(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", pName))}
}

/// <p>AC3: a probe exported to this browser answers the vendor's own export as lines and writes no file; deleted, it imports back from a local file whose text is those lines, and reads back identical to the
/// first export, which a second export equals; each export and the import leave one <code>ConfigChange</code>, naming the namespace and the schema and holding no text.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformHl7Import</method> pass an empty selected-document array to the vendor's load -- the import loads nothing and this goes red.</p>
Method TestTheBrowserRoundTripReadsBackIdentical()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5.1", "Round trip"), "a probe is stored")
    Set tBefore = $ClassMethod(tFx, "Body", ..#NAMEA)
    Set tSince = ..AuditNow()
    Do $$$AssertEquals(..Act("export-browser", ..#NAMEA, "", .tAnswer), "200 ", "the export to this browser answers: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 300))
    If '$IsObject($Get(tAnswer)) || '$IsObject(tAnswer.output) Quit
    Set tText = ..JoinLines(tAnswer.output.lines)
    Do $$$AssertTrue((tText [ "<Document name=""" _ ..#NAMEA _ ".HL7"">") && (tText [ "description=""Round trip""") && (tAnswer.output.%GetTypeOf("root") = "unassigned"), "its output is the vendor's export lines and names no file")
    Do $$$AssertEquals(..FilesIn($ClassMethod(..#PROBE, "Directory")), 0, "and writes no file")
    Do $$$AssertEquals(..Act("delete", ..#NAMEA, "", .tDeleted), "200 ", "the probe is deleted")
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA), 0, "and gone")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "a.xml", "content": (tText)}, .tImported), "200 ", "the local file imports: " _ $Extract($Select($IsObject(tImported): tImported.%ToJSON(), 1: ""), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA), "2.5.1|Round trip|0", "the schema reads back with its base and description")
    Do $$$AssertEquals($ClassMethod(tFx, "Body", ..#NAMEA), tBefore, "and the vendor's own export of it equals the first")
    Do $$$AssertEquals(..Act("export-browser", ..#NAMEA, "", .tAgain), "200 ", "a second export answers")
    Do $$$AssertEquals($Select($IsObject($Get(tAgain)) && $IsObject(tAgain.output): $ZStrip($Piece(..JoinLines(tAgain.output.lines), "<Document", 2, *), "<>", $Char(10, 13)), 1: ""), $ZStrip(tBefore, "<>", $Char(10, 13)), "and equals the first, but for the line end the lines drop")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 3, 1), 3, "two exports and one import leave three ConfigChange rows of OcuPilot's own")
    Do $$$AssertTrue((tData [ ..#NAMEA) && (tData [ "USER") && (tData '[ "Round trip") && (tData '[ "<Category"), "naming the schema and the namespace and carrying no text: " _ tData)
    Do $$$AssertEquals(..OwnRows(tSince, "", .tText1, 0, 1, "Round trip") + ..OwnRows(tSince, "", .tText2, 0, 1, "<Category"), 0, "and no row of the three, the import's included, carries the description or the file's text")
}

/// <p>AC3, the import's consequence: a file imported over a schema the namespace holds replaces it whole, so a base the file names replaces the held one and a description and a message type the
/// file does not define are removed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Hl7VendorLoad</method> select a document the file does not hold -- the import answers <code>IMPORTSHAPE</code> and this goes red.</p>
Method TestAnImportReplacesTheHeldSchemaWhole()
{
    Set tFx = ..#FIXTURE
    Set tName = ..#REPLACED
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", tName, ..#SOURCE, "2.5", "Held before"), "a probe is stored")
    Set ^|"USER"|EnsHL7.Schema(tName, "MT", "ZZZ_Z01") = "base:ADT_A01"
    Do $$$AssertEquals($ClassMethod(tFx, "Text", tName) _ "|" _ $Data(^|"USER"|EnsHL7.Schema(tName, "MT", "ZZZ_Z01")), "2.5|Held before|0|1", "it holds a base, a description and a message type")
    Set tNL = $Char(10)
    Set tFile = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ tNL _ "<Export generator=""IRIS"" version=""26"">" _ tNL _ "<Document name=""" _ tName _ ".HL7"">" _ tNL _ "<Category name=""" _ tName _ """ base=""2.5.1"">" _ tNL _ "</Category>" _ tNL _ "</Document></Export>"
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "r.xml", "content": (tFile)}, .tImported), "200 ", "the file imports over it: " _ $Extract($Select($IsObject(tImported): tImported.%ToJSON(), 1: ""), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFx, "Text", tName) _ "|" _ $Data(^|"USER"|EnsHL7.Schema(tName, "MT", "ZZZ_Z01")), "2.5.1||0|0", "the schema is the file's: its base, and no description or message type the file does not define")
}

/// <p>AC3: a probe exported to a server file through a person's action and again through the agent's confirmed export, deleted, imports back through the agent's confirmed import, which is refused while
/// its key is off, destructive, names the file and the schema, and closes target-changed when the file changed after the mint; the schema reads back identical, and the import leaves one
/// <code>ConfigChange</code> naming a server file and no text.</p>
/// <p>Mutation (Rule 19): drop the digest comparison from <method>OcuPilot.Port.InteropPort.PerformHl7Import</method> -- the target-changed leg goes red.</p>
Method TestTheServerFileRoundTripThroughTheAgentRestoresTheSchema()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "Server file"), "a probe is stored")
    Set tBefore = $ClassMethod(tFx, "Body", ..#NAMEA)
    Set tExportSince = ..AuditNow()
    Do $$$AssertEquals(..Act("export", ..#NAMEA, ..FileValues("a.xml"), .tAnswer), "200 ", "the export to a server file answers: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 300))
    Set tFile = $ClassMethod(..#PROBE, "ReadFile", "a.xml")
    Do $$$AssertTrue((tFile [ " name=""" _ ..#NAMEA _ ".HL7"">") && (tFile [ "description=""Server file""") && (tFile '[ "<Class"), "the file is the vendor's export of that one document")
    Set tBadArgs = {"Name": (..#NAMEA), "root": "/not/an/allowed/dir/", "path": "agent.xml"}
    Do $$$AssertEquals($Extract(..Mint("Export", ..#NAMEA, tBadArgs, .tReason, .tRefused, .tRefusedTurn), 1, 5), "PATH.", "an export to a directory that is not allowed is refused at the mint with PathPort's code: " _ tReason)
    Set tArgs = ..FileValues("agent.xml")
    Do $$$AssertEquals(..Mint("Export", ..#NAMEA, tArgs, .tReason, .tExport, .tExportTurn), "minted", "the agent's export mints: " _ tReason)
    If '$IsObject($Get(tExport)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tExport.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tExport.proposalId, "Destructive") + 0), "EXPLORER.EXPORT.REPLACES|0", "its card says a file at the name is replaced, and is not destructive")
    Do ..Confirm(tExport.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tHttp, 200, "the export confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "FileExists", "agent.xml") && ($ClassMethod(..#PROBE, "ReadFile", "agent.xml") [ "description=""Server file"""), "and writes the file")
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked"), 1: ""), 1, "the agent's export is marked (AD-15)")
    Do $$$AssertEquals(..OwnRows(tExportSince, ..#NAMEA, .tExportData, 2, 1), 2, "the person's and the agent's server-file exports each left one ConfigChange of OcuPilot's own")
    Do $$$AssertTrue((tExportData [ """toFile"":true") && (tExportData [ """completed"":true") && (tExportData '[ "Server file") && (tExportData '[ "<Category"), "naming a server file and carrying no text: " _ tExportData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tExportTurn))
    Do $$$AssertEquals(..Act("delete", ..#NAMEA, "", .tDeleted), "200 ", "the probe is deleted")
    Set tArgs = ..FileValues("agent.xml")
    Do tArgs.%Set("Name", ..#NAMEA, "string")
    Set tCode = ..Mint("Import", ..#NAMEA, tArgs, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the agent's import mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.HL7.IMPORT|1", "its card says the schema is replaced, and is destructive")
    Do $$$AssertTrue((tProposal.changed.%ToJSON() [ "agent.xml") && (tProposal.changed.%ToJSON() [ ..#NAMEA), "and names the file and the schema: " _ tProposal.changed.%ToJSON())
    Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tHttp), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the import's key is off: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertStatusOK(..EnableKeys(..#IMPORTKEY), "the key is turned on")
    Set tFileText = $ClassMethod(..#PROBE, "ReadFile", "agent.xml")
    Do $ClassMethod(..#PROBE, "WriteFile", "agent.xml", tFileText _ "<!-- changed after the mint -->")
    Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "a file changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA), 0, "and nothing was imported")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do $ClassMethod(..#PROBE, "WriteFile", "agent.xml", tFileText)
    Do $$$AssertEquals(..Mint("Import", ..#NAMEA, tArgs, .tReason, .tFresh, .tFreshTurn), "minted", "a fresh import mints: " _ tReason)
    If '$IsObject($Get(tFresh)) Quit
    Set tSince = ..AuditNow()
    Do ..Confirm(tFresh.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tHttp, 200, "and confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action, 1: ""), "1|updated", "marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ ($ClassMethod(tFx, "Body", ..#NAMEA) = tBefore), "2.5|Server file|0|1", "the schema reads back identical to the first export")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 1, 1), 1, "the import leaves one ConfigChange of OcuPilot's own")
    Do $$$AssertTrue((tData [ "server file") && (tData '[ "Server file") && (tData '[ "<Category"), "naming a server file and carrying no text: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tFreshTurn))
}

/// <p>AC3, AC5: a standard schema exports, and its export, which marks itself standard, is never imported back: the file as it is, and the same text under a probe's name, are each refused
/// <code>INTEROP.HL7.IMPORTSTANDARD</code> before any load, and neither the standard schema nor a probe of that name is written.</p>
/// <p>Mutation (Rule 19): drop the flagged-file test from <method>OcuPilot.Port.InteropPort.ReadHl7Import</method> and <method>OcuPilot.Port.InteropPort.PerformHl7Import</method> -- the renamed leg goes
/// red, since the import would create a standard probe.</p>
Method TestAStandardSchemaExportsAndIsNeverImportedBack()
{
    Set tFx = ..#FIXTURE
    Set tStandard = $ClassMethod(tFx, "Text", "2.5")
    Do $$$AssertEquals(..Act("export-browser", "2.5", "", .tAnswer), "200 ", "the export of 2.5 answers")
    If '$IsObject($Get(tAnswer)) || '$IsObject(tAnswer.output) Quit
    Set tText = ..JoinLines(tAnswer.output.lines)
    Do $$$AssertTrue((tText [ "<Category name=""2.5""") && (tText [ "std=""1"""), "the export marks 2.5 standard")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "s.xml", "content": (tText)}, .tRefused), "409 INTEROP.HL7.IMPORTSTANDARD", "importing it back is refused")
    Set tRenamed = $Replace($Replace(tText, "name=""2.5.HL7""", "name=""" _ ..#NAMEA _ ".HL7"""), "<Category name=""2.5""", "<Category name=""" _ ..#NAMEA _ """")
    Do $$$AssertTrue(tRenamed [ ..#NAMEA _ ".HL7", "the same text is renamed to a probe's name")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "s.xml", "content": (tRenamed)}, .tRenamedAnswer), "409 INTEROP.HL7.IMPORTSTANDARD", "importing it under a probe's name is refused too")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", "2.5") _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Standards"), tStandard _ "|0|14", "2.5 is untouched, no probe appeared and the fourteen standard schemas are held")
}

}
