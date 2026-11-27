/// <p>Pins Story 24.18 Batch 1's namespace at confirm (AD-52; Integration, Rule 1): every stored proposal carries the namespace it was read in, and every judgment at the confirm runs there, whichever
/// namespace the confirm request is scoped to. With a same-named probe schema in <code>USER</code> and <code>HSCUSTOM</code>, an add, a delete and an import each minted in <code>USER</code> and
/// confirmed from <code>HSCUSTOM</code> act in <code>USER</code> only, the add is not refused <code>TAKEN</code> for the name <code>HSCUSTOM</code> holds, and <code>HSCUSTOM</code>'s probes are unchanged; a base
/// only the other namespace holds is refused at the mint.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs, and the manager directory as an allowed root.</p>
Class OcuPilot.Test.InteropHl7SchemaElsewhere Extends OcuPilot.Test.InteropHl7Case
{

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter KEYS = "interop.hl7schemas.delete,interop.hl7schemas.import";

Parameter ADDNAME = "OcuProbe2418ea";

Parameter DELETENAME = "OcuProbe2418ed";

Parameter IMPORTNAME = "OcuProbe2418ei";

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

/// <p>AC7: an add of a name only <code>HSCUSTOM</code> holds, a delete and an import of names both hold, each minted in <code>USER</code> and confirmed with the request scoped to <code>HSCUSTOM</code>,
/// act in <code>USER</code>: the add is created there and not refused as taken, the delete removes <code>USER</code>'s schema, the import replaces it with the file's; <code>HSCUSTOM</code>'s three probes are
/// as they were.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropHl7SchemaDelete.FINGERPRINTSUBJECT</parameter> -- the delete leg acts in <code>HSCUSTOM</code> and this goes red.</p>
Method TestEachAgentWriteActsWhereItWasMintedWhateverNamespaceConfirms()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#ADDNAME, ..#OTHER, "2.5", "other add"), "the add's name is held in " _ ..#OTHER _ " alone")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#DELETENAME, ..#SOURCE, "2.5", "user delete"), "the delete's name is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#DELETENAME, ..#OTHER, "2.5.1", "other delete"), "and in " _ ..#OTHER)
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#IMPORTNAME, ..#SOURCE, "2.5", "user import"), "the import's name is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#IMPORTNAME, ..#OTHER, "2.5.1", "other import"), "and in " _ ..#OTHER)
    Set tHeld = $ClassMethod(tFx, "Text", ..#ADDNAME, ..#OTHER) _ "#" _ $ClassMethod(tFx, "Text", ..#DELETENAME, ..#OTHER) _ "#" _ $ClassMethod(tFx, "Text", ..#IMPORTNAME, ..#OTHER)
    Set tText = $ClassMethod(tFx, "Body", ..#IMPORTNAME, ..#SOURCE)
    Set tFile = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ $Char(10) _ "<Document" _ $Replace(tText, "description=""user import""", "description=""from the file""")
    Do $$$AssertTrue(tFile [ "description=""from the file""", "the import file is the USER probe's export with another description")
    Do $ClassMethod(..#PROBE, "WriteFile", "i.xml", tFile)
    Do $$$AssertStatusOK(..EnableKeys(..#KEYS), "the delete and import keys are turned on")
    Do $$$AssertEquals(..Mint("Add", ..#ADDNAME, {"Description": "user add"}, .tReason, .tAdd, .tAddTurn, ..#SOURCE), "minted", "the add mints in USER, which does not hold the name: " _ tReason)
    Do $$$AssertEquals(..Mint("Delete", ..#DELETENAME, {}, .tReason, .tDelete, .tDeleteTurn, ..#SOURCE), "minted", "the delete mints in USER: " _ tReason)
    Set tArgs = {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "i.xml"))}
    Do $$$AssertEquals(..Mint("Import", ..#IMPORTNAME, tArgs, .tReason, .tImport, .tImportTurn, ..#SOURCE), "minted", "the import mints in USER: " _ tReason)
    If '$IsObject($Get(tAdd)) || '$IsObject($Get(tDelete)) || '$IsObject($Get(tImport)) Quit
    Do $$$AssertEquals(tAdd.target.scope _ "|" _ tDelete.target.scope _ "|" _ tImport.target.scope, "USER|USER|USER", "each proposal's target is scoped to USER")
    For tProposal = tAdd, tDelete, tImport {
        Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer, ..#OTHER)
        Do $$$AssertEquals(tHttp, 200, tProposal.target.id _ ": confirmed with the request scoped to " _ ..#OTHER _ ": " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#ADDNAME, ..#SOURCE) _ "#" _ $ClassMethod(tFx, "Held", ..#DELETENAME, ..#SOURCE) _ "#" _ $ClassMethod(tFx, "Text", ..#IMPORTNAME, ..#SOURCE), "|user add|0#0#2.5|from the file|0", "USER holds the add, lacks the deleted schema and holds the import's replacement, with the file's description")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#ADDNAME, ..#OTHER) _ "#" _ $ClassMethod(tFx, "Text", ..#DELETENAME, ..#OTHER) _ "#" _ $ClassMethod(tFx, "Text", ..#IMPORTNAME, ..#OTHER), tHeld, "and " _ ..#OTHER _ "'s three probes are as they were")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tAddTurn))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tDeleteTurn))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tImportTurn))
}

/// <p>AC7: a base only <code>HSCUSTOM</code> holds is refused at the mint in <code>USER</code>, which judges the base where it is minted, and the same add is minted in <code>HSCUSTOM</code>.</p>
/// <p>Mutation (Rule 19): judge the base in the request's namespace rather than the arguments' in <method>OcuPilot.Screen.Tool.InteropHl7SchemaAdd.ArgumentProblem</method> -- this goes red.</p>
Method TestABaseOnlyTheOtherNamespaceHoldsIsRefusedAtTheMint()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#ADDNAME, ..#OTHER, "2.5", "base only here"), "a schema is held in " _ ..#OTHER _ " alone")
    Do $$$AssertEquals(..Mint("Add", ..#NAMEA, {"Base": (..#ADDNAME)}, .tReason, .tRefused, .tRefusedTurn, ..#SOURCE), "TOOL.ARGUMENTS", "an add based on it is refused in USER")
    Do $$$AssertTrue(tReason [ ..#BASESENTENCE, "with the published sentence: " _ $Extract(tReason, 1, 200))
    Do $$$AssertEquals(..Mint("Add", ..#NAMEA, {"Base": (..#ADDNAME)}, .tReason, .tMinted, .tMintedTurn, ..#OTHER), "minted", "and is minted in " _ ..#OTHER _ ": " _ tReason)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tMintedTurn))
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA, ..#SOURCE) _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEA, ..#OTHER), "0|0", "and nothing was written by either mint")
}

Parameter BASESENTENCE = "Choose a base schema this namespace holds, or none.";

}
