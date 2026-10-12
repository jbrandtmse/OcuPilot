/// <p>Pins the names Story 20.5's lookup writes meet at the vendor's own limits (AD-62 (5), AD-21), against probe lookup tables in
/// <code>USER</code>: a table and a key each within its bound but too long together for the instance to address are the key's
/// violation from the Save and the agent's mint, and absent to every read, remove and delete, never a fault; a table whose name the
/// vendor's export reads as a pattern, a path or a separator is refused <code>INTEROP.LOOKUP.EXPORTNAME</code> from the port, the
/// screen and the agent before any export; a comma in a name exports and imports exactly that table; an import file naming a table
/// the export cannot name is refused <code>INTEROP.LOOKUP.IMPORTSHAPE</code>; and a table held in another letter case is
/// found whatever the names around it, at once.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account, the
/// manager directory as an allowed root and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes what it makes.</p>
Class OcuPilot.Test.InteropLookupNames Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropLookupControl";

Parameter TRANSFER = "OcuPilot.Test.InteropLookupTransfer";

Parameter REFUSALS = "OcuPilot.Test.InteropLookupRefusals";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter TABLE = "OcuProbe205Names";

/// <p>A table named by a canonical number and one whose name begins with a number, which the probe prefix does not cover.</p>
Parameter NUMERIC = "205205205";

Parameter NUMERICCASE = "205205204OCUPROBE";

/// <p>A table whose name begins with an apostrophe, which the probe prefix does not cover either.</p>
Parameter LEADING = "'OcuProbe205NamesLead";

Parameter ENTRYSCREEN = "/screens/interop.lookupentries";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupNames writes probe lookup tables and files in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..Reset()
}

Method OnAfterAllTests() As %Status
{
    Quit ..Reset()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Reset()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(..Reset(), "the probe tables and the probe directory are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Remove every probe table, the three the prefix does not cover, and the probe directory, and make the directory again.</p>
ClassMethod Reset() As %Status
{
    Set tFixture = ..#FIXTURE
    Set tSC = $ClassMethod(tFixture, "Clear")
    For tName = ..#NUMERIC, ..#NUMERICCASE, $ZConvert(..#NUMERICCASE, "L"), ..#LEADING {
        If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Drop", tName)
    }
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

/// <p><var>pCount</var> copies of the character <var>pCharacter</var>.</p>
ClassMethod Run(pCharacter As %String, pCount As %Integer) As %String
{
    Quit $Translate($Justify("", pCount), " ", pCharacter)
}

/// <p>The port's answer to <var>pType</var> on <var>pEndpoint</var> for the query <var>pQuery</var> in <code>USER</code>, as
/// <code>status code</code>, the result in <var>pResult</var>; the process's own privileges admit the gate.</p>
ClassMethod PortSays(pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult) As %String
{
    Set pQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, pType, .pQuery, "", .pResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>AC4: a 255-character table takes a key of at most 238 characters, and one character more is the key's violation -- from the
/// rule, the person's Save (422 naming the key) and the agent's mint (refused with the key's sentence) -- while every read, remove
/// and delete of that pair, or of a table name too long to address, answers 404 rather than a fault, and nothing is written. Two-byte
/// characters count as more than one: a 146-character table holding 130 of them cannot take a 255-character key, and a table of 255
/// of them cannot be stored at all.</p>
/// <p>Mutation (Rule 19): drop the pair test from <method>OcuPilot.Port.InteropPort.LookupViolations</method> -- the Save, the
/// mint and the rule's legs go red (the Save answers 500).</p>
Method TestAPairTooLongTogetherIsAViolationAndNeverAFault()
{
    Set tPort = ..#PORT
    Set tFixture = ..#FIXTURE
    Set tTable = ..#TABLE _ ..Run("t", 255 - $Length(..#TABLE))
    Set tFits = ..Run("k", 238)
    Set tLong = ..Run("k", 239)
    Do $ClassMethod(tPort, "LookupViolations", tTable, tFits, "v", .tViolations)
    Do $$$AssertEquals(tViolations, 0, "the largest pair the instance stores is no violation")
    Do $ClassMethod(tPort, "LookupViolations", tTable, tLong, "v", .tViolations)
    Do $$$AssertEquals(tViolations _ "|" _ $ListToString($Get(tViolations(1))), "1|Key,INTEROP.LOOKUP.KEY", "one character more is the key's violation")
    Set tWide = ..#TABLE _ ..Run($Char(20320), 130)
    Do $ClassMethod(tPort, "LookupViolations", tWide, ..Run("k", 255), "v", .tViolations)
    Do $$$AssertEquals(tViolations _ "|" _ $ListToString($Get(tViolations(1))), "1|Key,INTEROP.LOOKUP.KEY", "a table of two-byte characters takes a shorter key than its length alone allows")
    Do $ClassMethod(tPort, "LookupViolations", ..Run($Char(20320), 255), "k", "v", .tViolations)
    Do $$$AssertEquals(tViolations _ "|" _ $ListToString($Get(tViolations(1))), "1|Table,INTEROP.LOOKUP.TABLENAME", "and a table of 255 of them is the table's violation")
    Set tReason = $Parameter(..#ERROR, "REASONLOOKUPKEY")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "SaveBody", {"Table": (tTable), "Key": (tLong), "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.KEY", "the Save refuses the pair: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.detail.violations.%Get(0).field _ "|" _ tAnswer.detail.violations.%Get(0).reason, 1: ""), "Key|" _ tReason, "naming the key with its sentence")
    Set tSC = $ClassMethod(..#CONTROL, "Mint", "InteropLookupEntryAdd", $ClassMethod(..#CONTROL, "ArgsFor", tTable, tLong, "v"), .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("code") _ " " _ tFault.detail.%Get("problem"), 1: "minted")
    Do $$$AssertEquals(tProblem, "TOOL.ARGUMENTS 'Key': " _ tReason, "the agent's add of the pair is refused with the key's sentence")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tTable, tLong))
    Do $$$AssertEquals(..PortSays("LookupEntries", "LOOKUPENTRY", .tQuery), "404 PORT.NOTFOUND", "a read of the pair finds no entry")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", ..#ENTRYSCREEN, "remove", tQuery("id"), $Char(0), .tAnswer), "404 PORT.NOTFOUND", "a remove of it finds none either")
    Set tTooLong = ..Run("t", 600)
    Kill tQuery
    Set tQuery("table") = tTooLong
    Do $$$AssertEquals(..PortSays("LookupEntries", "LIST", .tQuery), "404 PORT.NOTFOUND", "the entries of a table name too long to address are not found")
    Kill tQuery
    Set tQuery("id") = tTooLong
    Do $$$AssertEquals(..PortSays("LookupTables", "LOOKUPTABLE", .tQuery), "404 PORT.NOTFOUND", "nor is the table")
    Kill tQuery
    Set tQuery("id") = tTooLong
    Do $$$AssertEquals(..PortSays("LookupTables", "DELETETABLE", .tQuery), "404 PORT.NOTFOUND", "and its delete takes no lock and finds nothing")
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tTable), 0, "nothing was written")
}

/// <p>AC8: a table whose name holds <code>*</code>, <code>?</code>, <code>/</code>, <code>\</code> or <code>;</code>, or begins with an
/// apostrophe, is refused <code>INTEROP.LOOKUP.EXPORTNAME</code> by the port, to the browser and to a server file, before any file is
/// written, by the screen's export, and at the agent's mint; a table that only shares such a name's prefix is never exported in its
/// place.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.InteropPort.LookupAddressable</method> test from
/// <method>OcuPilot.Port.InteropPort.ExportTable</method> -- the port's and the screen's legs go red (the pattern exports every
/// table it matches, the path a file with no entry).</p>
Method TestATableTheExportCannotNameIsRefusedByName()
{
    Set tFixture = ..#FIXTURE
    Set tTransfer = ..#TRANSFER
    Set tCode = $Parameter(..#ERROR, "LOOKUPEXPORTNAME")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#TABLE _ "PatA", "decoy", "d"), "a table the pattern would match is arranged")
    Set tNames = $ListBuild(..#TABLE _ "Pat*", ..#TABLE _ "Pat?", ..#TABLE _ "Pat/x", ..#TABLE _ "Pat\x", ..#TABLE _ "Pat;x", ..#LEADING)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", tName, "k", "v"), tName _ " is arranged")
        Kill tQuery
        Set tQuery("id") = tName
        Do $$$AssertEquals(..PortSays("LookupTables", "EXPORT", .tQuery), "409 " _ tCode, tName _ ": the export to the browser is refused by name")
        Kill tQuery
        Set tQuery("id") = tName
        Set tQuery("root") = $ClassMethod(..#PROBE, "Root")
        Set tQuery("path") = $ClassMethod(..#PROBE, "RelativeName", "names.xml")
        Do $$$AssertEquals(..PortSays("LookupTables", "EXPORT", .tQuery), "409 " _ tCode, tName _ ": and to a server file")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "FileExists", "names.xml"), 0, tName _ ": which is never written")
        Do $ClassMethod(tTransfer, "Act", "export-browser", tName, "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409 " _ tCode, tName _ ": the screen's export is refused: " _ $Extract($ClassMethod(tTransfer, "Json", tBody), 1, 300))
    }
    Set tArgs = $ClassMethod(tTransfer, "FileValues", "agent.xml")
    Do tArgs.%Set("Name", ..#TABLE _ "Pat*", "string")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "MintVerdict", "InteropLookupTableExport", tArgs, .tReason), tCode, "the agent's export is refused at the mint")
    Do $$$AssertEquals(tReason, $Parameter(..#ERROR, "REASONLOOKUPEXPORTNAME"), "with its published sentence")
}

/// <p>AC8, AC9: a comma in a table's name is no separator: the screen's export to the browser answers that one table's document
/// with its two entries, and a local import of those lines puts the deleted table back with the same entries.</p>
/// <p>Mutation (Rule 19): pass the document to <code>$System.OBJ.ExportToStream</code> as a string in
/// <method>OcuPilot.Port.InteropPort.ExportTable</method> -- the export leg goes red; pass the selected document to
/// <code>$System.OBJ.LoadStream</code> as a string in <method>OcuPilot.Port.InteropPort.PerformImport</method> -- the import is
/// refused <code>IMPORTSHAPE</code>, since nothing loads.</p>
Method TestACommaInANameExportsAndImportsThatTableAlone()
{
    Set tFixture = ..#FIXTURE
    Set tTransfer = ..#TRANSFER
    Set tName = ..#TABLE _ "a,b"
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", tName, "k1", "one"), "the table is arranged")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", tName, "k2", "two"), "with two entries")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#TABLE _ "a", "decoy", "d"), "and a table named by the part before the comma")
    Do $ClassMethod(tTransfer, "Act", "export-browser", tName, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the export to the browser answers: " _ $Extract($ClassMethod(tTransfer, "Json", tBody), 1, 300))
    If '$IsObject($Get(tBody)) || '$IsObject(tBody.%Get("output")) Quit
    Set tText = ""
    Set tIterator = tBody.output.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Do $$$AssertEquals(($Length(tText, "<Document ") - 1) _ "|" _ ($Length(tText, "<entry ") - 1) _ "|" _ (tText [ ("name=""" _ tName _ ".LUT""")), "1|2|1", "its lines are that one table's document with its two entries")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Drop", tName), "the table is deleted")
    Do $ClassMethod(tTransfer, "Act", "import-local", "import", {"fileName": "comma.xml", "content": (tText)}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the local import answers: " _ $ClassMethod(tTransfer, "Json", tBody))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tName), "k1=one;k2=two", "and puts the table back with the same entries")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE _ "a"), "decoy=d", "leaving the table named by the part before the comma as it was")
}

/// <p>AC9: an import file naming a table whose name the export cannot name -- a pattern or a path character, so no export writes
/// it -- is refused <code>IMPORTSHAPE</code> from the screen's local import and the port's read, and no table is written.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.InteropPort.LookupAddressable</method> test from
/// <method>OcuPilot.Port.InteropPort.ImportFile</method> -- the read composed for the import answers 200, and this goes red.</p>
Method TestAnImportFileNamingATableTheExportCannotNameIsRefused()
{
    Set tFixture = ..#FIXTURE
    Set tTransfer = ..#TRANSFER
    Set tSource = ..#TABLE _ "Src"
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", tSource, "k", "v"), "a source table is arranged")
    Set tText = $ClassMethod(tTransfer, "ExportText", tSource _ ".LUT")
    Do $$$AssertTrue(tText [ (tSource _ ".LUT"), "and exported")
    For tName = ..#TABLE _ "Q?x", ..#TABLE _ "P/x" {
        Set tFile = $Replace(tText, tSource, tName)
        Do $ClassMethod(tTransfer, "Act", "import-local", "import", {"fileName": "bad.xml", "content": (tFile)}, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409 INTEROP.LOOKUP.IMPORTSHAPE", tName _ ": the screen's import is refused: " _ $Extract($ClassMethod(tTransfer, "Json", tBody), 1, 300))
        Do $ClassMethod(..#REFUSALS, "ImportQuery", tFile, .tQuery)
        Do $$$AssertEquals(..PortSays("LookupTables", "IMPORTTABLE", .tQuery), "409 INTEROP.LOOKUP.IMPORTSHAPE", tName _ ": and the read composed for it")
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tName), 0, tName _ ": no table is written")
    }
}

/// <p>AC4: a table held in another letter case is found whatever the names around it: behind a table named by a canonical number,
/// where the vendor's own case-insensitive lookup answers none, the add is <code>TABLECASE</code> and writes nothing; and a new table
/// that shares twenty characters with no case with another table is added at once, where the vendor's lookup doubles its work at each
/// such character (measured: about 14 seconds for twenty).</p>
/// <p>Mutation (Rule 19): look the case-variant up with <code>Ens.Util.LookupTable.%ExistsTable(pTable, 1, , .tMatch)</code> in
/// <method>OcuPilot.Port.InteropPort.LookupFactsHere</method> again -- both legs go red.</p>
Method TestATableHeldInAnotherCaseIsFoundWhateverTheNamesAroundIt()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#NUMERIC, "k", "v"), "a table named by a number is arranged")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", ..#NUMERICCASE, "k", "v"), "and one whose name begins with a number")
    Set tLower = $ZConvert(..#NUMERICCASE, "L")
    Do $$$AssertEquals($ClassMethod(tControl, "Save", tLower, "k2", "v", .tAnswer), "409 INTEROP.LOOKUP.TABLECASE", "an add to its lower-case spelling is refused TABLECASE: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tLower), 0, "and writes no second table")
    Set tStem = ..#TABLE _ ..Run("1", 20)
    Do $$$AssertStatusOK($ClassMethod(tFixture, "Put", tStem _ "A", "k", "v"), "a table with twenty digits in its name is arranged")
    Set tStart = $ZHorolog
    Set tText = $ClassMethod(tControl, "Save", tStem _ "b", "k", "v", .tAnswer)
    Set tElapsed = $ZHorolog - tStart
    Do $$$AssertEquals(tText, "201 ", "a new table sharing those digits is added: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue(tElapsed < 5, "at once, not after the vendor's walk: " _ $FNumber(tElapsed, "", 3) _ " seconds")
}

}
