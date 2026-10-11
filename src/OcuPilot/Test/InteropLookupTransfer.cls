/// <p>Pins Story 20.5's export and import end to end against probe lookup tables in <code>USER</code> (AD-6, AD-10, AD-21, AD-22,
/// AD-39, AD-53, AD-62): the Lookup tables list's actions over HTTP -- an export to a server file, the table deleted and imported back
/// with the same entries, and the same through this browser and a local file; keys the file lacks are removed by the import; the agent's
/// export and import through mint and confirm, with the import's key enabled through its stored setting; every file that is not exactly
/// one lookup table with an entry (two tables, a class beside the table, the legacy form, no entry, text that is no export) refused
/// <code>IMPORTSHAPE</code> before anything is loaded; a file whose table is held in another letter case refused <code>TABLECASE</code>;
/// a file or table changed since review refused <code>IMPORTCHANGED</code>; a file or an export past the character limit refused
/// <code>TOOLARGE</code>; and PathPort's pairs asked of a server file alone.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account, the
/// manager directory as an allowed root and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It creates and removes the
/// tables, the class and the files <class>OcuPilot.Test.InteropLookupFixture</class> and
/// <class>OcuPilot.Test.ExplorerTransferProbe</class> name, and snapshots the stored governance policy before each test and puts it
/// back after it.</p>
Class OcuPilot.Test.InteropLookupTransfer Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropLookupControl";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TABLE = "OcuProbe205Transfer";

Parameter OTHER = "OcuProbe205TransferB";

Parameter CLASS = "OcuProbe205.TransferDoc";

Parameter TABLESCREEN = "/screens/interop.lookuptables";

/// <p>The import's key, which the baseline disables.</p>
Parameter IMPORTKEY = "interop.lookuptables.import";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupTransfer writes probe lookup tables, a probe class and files on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISOK(tSC) Set tSC = ..RemoveClass()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe tables are removed")
    Do $$$AssertStatusOK(..RemoveClass(), "and the probe class")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "and the probe directory")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Remove the probe class from <code>USER</code>.</p>
ClassMethod RemoveClass() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "USER"
        If ##class(%Dictionary.ClassDefinition).%ExistsId(..#CLASS) Set tSC = $System.OBJ.Delete(..#CLASS, "-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the probe class exists in <code>USER</code>.</p>
ClassMethod ClassExists() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "USER"
        Set tExists = ##class(%Dictionary.ClassDefinition).%ExistsId(..#CLASS)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ''tExists
}

/// <p>The vendor's export of <var>pItems</var> (comma-separated document names) in <code>USER</code> as text, or <code>""</code>.</p>
ClassMethod ExportText(pItems As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = "USER"
        Set tStream = ##class(%Stream.GlobalCharacter).%New()
        Set tSC = $System.OBJ.ExportToStream(pItems, .tStream, "-d")
        If $$$ISOK(tSC) {
            Do tStream.Rewind()
            Set tText = tStream.Read(3000000)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = ""
    }
    Quit tText
}

/// <p>Create the probe class in <code>USER</code> (one property, so the export has a body).</p>
ClassMethod MakeClass() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "USER"
        Set tClass = ##class(%Dictionary.ClassDefinition).%New(..#CLASS)
        Set tClass.Super = "%RegisteredObject"
        Set tSC = tClass.%Save()
        If $$$ISOK(tSC) Set tSC = $System.OBJ.Compile(..#CLASS, "-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One screen action on the tables list: <var>pAction</var> on <var>pId</var> with <var>pValues</var>, sent as UTF-8 as a browser
/// sends it; the HTTP status and the parsed envelope.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pStatus As %Integer, Output pBody)
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Set tBytes = ##class(%Stream.GlobalBinary).%New()
    Do tBytes.Write($ZConvert(tRequest.%ToJSON(), "O", "UTF8"))
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#TABLESCREEN _ "/action?ns=USER", .pStatus, .pBody, "", "", tBytes)
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject($Get(pBody)) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>The file values naming probe file <var>pName</var>.</p>
ClassMethod FileValues(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", pName))}
}

/// <p>The probe table with a spread of keys and values: a space, markup characters, a non-ASCII letter, an empty value and a long line.</p>
ClassMethod Arrange() As %Status
{
    Set tFixture = ..#FIXTURE
    Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "first value")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "with space", "a & b < c > d ""quoted""")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "caf" _ $Char(233), "empty? no" _ $Char(233))
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "empty", "")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "long", $Translate($Justify("", 5000), " ", "x"))
    Quit tSC
}

/// <p>AC8: the table exported to a server file over the screen's action, deleted, and imported back from that file, with the same
/// entries; keys the file lacks are removed by the import; the file is the vendor's own export of that one <code>.LUT</code> document;
/// and the export answers its file and nothing else.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ExportTable</method> write the legacy
/// <code>%Export</code> form -- the import is refused for its shape and this goes red.</p>
Method TestTheServerRoundTripRestoresTheSameEntries()
{
    Set tFixture = ..#FIXTURE
    Set tProbe = ..#PROBE
    Do $$$AssertStatusOK(..Arrange(), "the probe table is arranged")
    Set tBefore = $ClassMethod(tFixture, "Entries", ..#TABLE)
    Do $$$AssertTrue($Length(tBefore, ";") >= 5, "its entries read")
    Do ..Act("export", ..#TABLE, ..FileValues("table.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the export answers: " _ ..Json(tBody))
    Do $$$AssertEquals($Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.action _ " " _ tBody.output.root _ " " _ tBody.output.path, 1: ""), "updated " _ ..FileValues("table.xml").root _ " " _ ..FileValues("table.xml").path, "naming the file and nothing else")
    Set tFile = $ClassMethod(tProbe, "ReadFile", "table.xml")
    Do $$$AssertTrue((tFile [ "<Document name=""" _ ..#TABLE _ ".LUT"">") && (tFile [ "<lookupTable>") && (tFile [ "key=""with space""") && (tFile '[ "<Class"), "the file is the vendor's export of that one .LUT document")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "extra", "not in the file")
    Do ..Act("import", "import", ..FileValues("table.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the import replaces the table: " _ ..Json(tBody))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), tBefore, "keys the file lacks are removed and the entries are the file's")
    Do ..Act("delete", ..#TABLE, "", .tStatus, .tBody)
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "the table is deleted")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Act("import", "import", ..FileValues("table.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.action _ " " _ tBody.target.type _ " " _ tBody.target.id, 1: ""), "200 updated lookup-table import", "the import creates it again: " _ ..Json(tBody))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), tBefore, "with the same entries")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropLookupControl).Audited(tSince, "import", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue((tData [ ..#TABLE) && (tData '[ "first value"), "naming the table and carrying no value: " _ tData)
}

/// <p>AC8: the table exported to this browser answers its XML lines, writes no file, and imports back as a local file whose text is
/// those lines joined by line feeds, with the same entries.</p>
/// <p>Mutation (Rule 19): drop <code>content</code> in <method>OcuPilot.Screen.Tool.InteropLookupTableImport.ScreenActionDelta</method>
/// -- this goes red.</p>
Method TestTheBrowserRoundTripRestoresTheSameEntries()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(), "the probe table is arranged")
    Set tBefore = $ClassMethod(tFixture, "Entries", ..#TABLE)
    Do ..Act("export-browser", ..#TABLE, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the export to this browser answers: " _ $Extract(..Json(tBody), 1, 300))
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("output")) Quit
    Set tText = ""
    Set tIterator = tBody.output.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Do $$$AssertTrue((tText [ "<Export") && (tText [ ..#TABLE _ ".LUT") && (tBody.output.%GetTypeOf("root") = "unassigned"), "its output is the XML lines and no file")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "FileExists", "table.xml"), 0, "and writes no file")
    Do ..Act("delete", ..#TABLE, "", .tStatus, .tBody)
    Do ..Act("import-local", "import", {"fileName": "table.xml", "content": (tText)}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the local file imports: " _ ..Json(tBody))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), tBefore, "with the same entries")
}

/// <p>AC9: a file that is not exactly one lookup table with an entry and nothing else is refused <code>IMPORTSHAPE</code> before any
/// load, from the screen's import and the agent's mint: two tables, a class beside the table, the legacy form, a table with no entry
/// and text that is no export. The class is not loaded and no table is written.</p>
/// <p>Mutation (Rule 19): accept the first document the listing names in <method>OcuPilot.Port.InteropPort.ImportShape</method>, without
/// requiring that it is the only one -- the two-tables leg goes red.</p>
Method TestAFileOfAnotherShapeIsRefusedBeforeAnyLoad()
{
    Set tFixture = ..#FIXTURE
    Set tProbe = ..#PROBE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "keep", "me")
    Do $ClassMethod(tFixture, "Put", ..#OTHER, "keep", "too")
    Do $$$AssertStatusOK(..MakeClass(), "a probe class is saved")
    Set tTwo = ..ExportText(..#TABLE _ ".LUT," _ ..#OTHER _ ".LUT")
    Set tBoth = ..ExportText(..#TABLE _ ".LUT," _ ..#CLASS _ ".cls")
    Do $$$AssertTrue((tTwo [ ..#OTHER) && (tBoth [ "<Class name=""" _ ..#CLASS _ """"), "the two multi-document exports read")
    Do $$$AssertStatusOK(..RemoveClass(), "the class is removed before the import")
    Set tLegacy = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<lookupTable>" _ $Char(10) _ "<entry table=""" _ ..#TABLE _ """ key=""legacy"">1</entry>" _ $Char(10) _ "</lookupTable>"
    Set tEmpty = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26""><Document name=""" _ ..#TABLE _ ".LUT""><lookupTable></lookupTable></Document></Export>"
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    For tCase = $ListBuild("two tables", tTwo), $ListBuild("a class beside the table", tBoth), $ListBuild("the legacy form", tLegacy), $ListBuild("a table with no entry", tEmpty), $ListBuild("text that is no export", "not xml at all") {
        Do ..Act("import-local", "import", {"fileName": "case.xml", "content": ($List(tCase, 2))}, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409 INTEROP.LOOKUP.IMPORTSHAPE", $List(tCase, 1) _ " is refused for its shape: " _ $Extract(..Json(tBody), 1, 200))
    }
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("reason"), 1: ""), $Parameter("OcuPilot.Api.InteropError", "REASONLOOKUPIMPORTSHAPE"), "with the published sentence")
    Do $$$AssertEquals(..ClassExists(), 0, "the class beside the table was never loaded")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "and no table was written")
    Do $ClassMethod(tProbe, "WriteFile", "two.xml", tTwo)
    Set tSC = $ClassMethod(..#CONTROL, "Mint", "InteropLookupTableImport", {"Name": (..#TABLE), "root": (..FileValues("two.xml").root), "path": (..FileValues("two.xml").path)}, .tProposal, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tFault)) && ('$IsObject($Get(tProposal))) && (tFault.%Get("code") = "INTEROP.LOOKUP.IMPORTSHAPE"), "the agent's import of the two-table file is refused at the mint: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "minted"))
    Do $ClassMethod(tProbe, "WriteFile", "one.xml", ..ExportText(..#TABLE _ ".LUT"))
    Set tSC = $ClassMethod(..#CONTROL, "Mint", "InteropLookupTableImport", {"Name": (..#OTHER), "root": (..FileValues("one.xml").root), "path": (..FileValues("one.xml").path)}, .tProposal, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tFault)) && ('$IsObject($Get(tProposal))) && (tFault.%Get("code") = "INTEROP.LOOKUP.IMPORTSHAPE"), "and so is an import naming a table the file does not hold: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "minted"))
}

/// <p>AC9: an import whose reviewed digest, entry count or stamp is not what the file and table read at the write is refused
/// <code>IMPORTCHANGED</code> with nothing loaded, and a local file, a server file and an export over the character limit are refused
/// <code>TOOLARGE</code>.</p>
/// <p>Mutation (Rule 19): drop the digest comparison from <method>OcuPilot.Port.InteropPort.PerformImport</method> -- the first leg goes
/// red; drop the size test of a server file's text from <method>OcuPilot.Port.InteropPort.ImportText</method> -- the server file leg
/// does.</p>
Method TestAChangedFileOrTableAndAnOversizeFileAreRefused()
{
    Set tFixture = ..#FIXTURE
    Set tPort = ..#PORT
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "v")
    Set tText = ..ExportText(..#TABLE _ ".LUT")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "t.xml"
    Set tQuery("content") = tText
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORTTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the import read answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tRow)) Quit
    Do $$$AssertEquals(tRow.Table _ "|" _ tRow.FileEntries _ "|" _ tRow.Present _ "|" _ tRow.Entries _ "|" _ tRow.%IsDefined("content") _ ($Length(tRow.%Get("content")) > 0), ..#TABLE _ "|1|1|1|10", "it reads the file's table, its entries and the table as it stands, and carries the text never: its content is empty")
    Do $$$AssertEquals($Length(tRow.Digest), 64, "and the file's SHA-256")
    Kill tWrite
    Merge tWrite = tQuery
    Set tWrite("digest") = tRow.Digest
    Set tWrite("entries") = tRow.Entries
    Set tWrite("modified") = tRow.Modified
    Set tWrite("digest") = $Select($Extract(tRow.Digest) = "0": "1", 1: "0") _ $Extract(tRow.Digest, 2, *)
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.LOOKUP.IMPORTCHANGED", "a file that is not the one reviewed is refused")
    Set tWrite("digest") = tRow.Digest
    Set tWrite("entries") = tRow.Entries + 1
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.LOOKUP.IMPORTCHANGED", "so is a table whose entry count is not the one reviewed")
    Set tWrite("entries") = tRow.Entries
    Set tWrite("modified") = "2001-01-01T00:00:00.000"
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.LOOKUP.IMPORTCHANGED", "and a stamp that is not the one reviewed")
    Kill tWrite("digest")
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 409, "a write that names no reviewed digest is refused")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was loaded")
    Set tQuery("content") = $Translate($Justify("", 3000001), " ", "x")
    Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORTTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.LOOKUP.TOOLARGE", "a local file over 3,000,000 characters is refused for its size")
    Do $$$AssertTrue($Parameter("OcuPilot.Api.InteropError", "REASONLOOKUPTOOLARGE") [ "3,000,000", "and the sentence states that limit")
    Do $ClassMethod(..#PROBE, "WriteFile", "big.xml", $Translate($Justify("", 3000001), " ", "x"))
    Do ..Act("import", "import", ..FileValues("big.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409 INTEROP.LOOKUP.TOOLARGE", "a server file over 3,000,000 characters is refused for its size: " _ $Extract(..Json(tBody), 1, 200))
    For tI = 1:1:110 Do $ClassMethod(tFixture, "Put", ..#OTHER, "k" _ tI, $Translate($Justify("", 32000), " ", "v"))
    Do ..Act("export-browser", ..#OTHER, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409 INTEROP.LOOKUP.TOOLARGE", "an export to this browser past the limit is refused for its size")
}

/// <p>AC9: a file whose table is absent under exactly that name but held in another letter case is refused <code>TABLECASE</code>
/// rather than creating a second table: at the read composed for the import (the screen's action and the agent's mint) and at the
/// write under the lock, which a caller that reviewed the import's plain read can still reach. Nothing is loaded: the case variant
/// keeps its entries and no table of the file's name appears.</p>
/// <p>Mutation (Rule 19): drop the check from <method>OcuPilot.Port.InteropPort.ReadImportTable</method> -- the screen and mint legs go
/// red; drop it from <method>OcuPilot.Port.InteropPort.PerformImport</method> -- the write leg does.</p>
Method TestAFileWhoseTableIsHeldInAnotherLetterCaseIsRefusedBeforeAnyLoad()
{
    Set tFixture = ..#FIXTURE
    Set tProbe = ..#PROBE
    Set tVariant = $ZConvert(..#TABLE, "U")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "file value")
    Set tText = ..ExportText(..#TABLE _ ".LUT")
    Do $ClassMethod(tFixture, "Clear")
    Do $ClassMethod(tFixture, "Put", tVariant, "keep", "me")
    Do $ClassMethod(tProbe, "WriteFile", "case.xml", tText)
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tReason = $Parameter("OcuPilot.Api.InteropError", "REASONLOOKUPTABLECASE")
    Do ..Act("import-local", "import", {"fileName": "case.xml", "content": (tText)}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("reason"), 1: ""), "409 INTEROP.LOOKUP.TABLECASE|" _ tReason, "the screen's import of the file is refused for the table held in another case, with the published sentence")
    Set tSC = $ClassMethod(..#CONTROL, "Mint", "InteropLookupTableImport", {"Name": (..#TABLE), "root": (..FileValues("case.xml").root), "path": (..FileValues("case.xml").path)}, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), $IsObject($Get(tProposal)): "minted", 1: "refused"), "INTEROP.LOOKUP.TABLECASE|" _ tReason, "and so is the agent's")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    ; A caller that reviewed the import without an action reads no refusal; the write still refuses it under the lock.
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "case.xml"
    Set tQuery("content") = tText
    Set tSC = $ClassMethod(..#PORT, "Invoke", "LookupTables", "IMPORTTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRow)): tRow.Present _ "|" _ tRow.Entries, 1: ""), "200 0|0", "the import's plain read answers that the file's table is not there")
    If '$IsObject($Get(tRow)) Quit
    Kill tWrite
    Merge tWrite = tQuery
    Set tWrite("digest") = tRow.Digest
    Set tWrite("entries") = tRow.Entries
    Set tWrite("modified") = tRow.Modified
    Set tSC = $ClassMethod(..#PORT, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 INTEROP.LOOKUP.TABLECASE|" _ tReason, "the write is refused under the lock for it too")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was loaded: the case variant keeps its entries")
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "and no table of the file's own spelling was created")
}

/// <p>AC8, AC9: PathPort's pairs are asked of a server file alone: the export and the import ask them when they name a root, and the
/// browser export and the local import ask none.</p>
Method TestPathPortsPairsAreAskedOfAServerFileAlone()
{
    For tTool = "InteropLookupTableExport", "InteropLookupTableImport" {
        Set tClass = "OcuPilot.Screen.Tool." _ tTool
        Set tFile = $ClassMethod(tClass, "ArgumentPairs", "", {"root": "/some/dir", "path": "f.xml"}, .tResolved)
        Do $$$AssertTrue(tResolved && ($ListLength(tFile) > 0), tTool _ ": a server file asks PathPort's pairs")
        Set tNone = $ClassMethod(tClass, "ArgumentPairs", "", {"Name": "T"}, .tResolved)
        Do $$$AssertTrue(tResolved && ($ListLength(tNone) = 0), tTool _ ": a call naming no root asks none")
    }
}

/// <p>AC8: the agent's export through mint and confirm writes the file, with the replacement consequence and no destructive treatment,
/// and audits it with no value; a file name outside the allowed directories is refused at the mint on its field.</p>
/// <p>Mutation (Rule 19): drop the resolve from <method>OcuPilot.Screen.Tool.InteropLookupTableExportMint.Mint</method> -- the refusal
/// leg goes red.</p>
Method TestTheAgentsExportConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $$$AssertStatusOK(..Arrange(), "the probe table is arranged")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBadArgs = {"Name": (..#TABLE), "root": "/not/an/allowed/dir/", "path": "agent.xml"}
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupTableExport", tBadArgs, .tRefused, .tFault, .tBadTurn)
    Do $$$AssertTrue($IsObject($Get(tFault)) && ('$IsObject($Get(tRefused))) && ($Extract(tFault.%Get("code"), 1, 5) = "PATH."), "a directory that is not allowed is refused at the mint with PathPort's code: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "minted"))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tArgs = ..FileValues("agent.xml")
    Do tArgs.%Set("Name", ..#TABLE, "string")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupTableExport", tArgs, .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the export mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "EXPLORER.EXPORT.REPLACES|0", "its consequence says a file at the name is replaced, and it is not destructive")
    Do $$$AssertTrue(tProposal.changed.%ToJSON() [ "agent.xml", "its card names the file: " _ tProposal.changed.%ToJSON())
    Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the export confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "FileExists", "agent.xml") && ($ClassMethod(..#PROBE, "ReadFile", "agent.xml") [ "<lookupTable>"), "and writes the file")
    Do $$$AssertTrue($Get(tRaw) '[ "<lookupTable>", "the confirm's answer holds no XML")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropLookupControl).Audited(tSince, "export", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue(tData '[ "first value", "carrying no value: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tBadTurn))
}

/// <p>AC9: the agent's import through mint and confirm: at the baseline the import's key is off and the confirm is refused; with the key
/// on, the mint's card is destructive and names the file, the table and the counts, and the confirm replaces the table with the file's
/// entries; a file changed after the mint closes the proposal target-changed with the table untouched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ImportFile</method> answer a constant digest -- the target-changed leg goes
/// red. (A subject that omits <code>Digest</code> is refused by the tool registry itself.)</p>
Method TestTheAgentsImportConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Set tProbe = ..#PROBE
    Do $$$AssertStatusOK(..Arrange(), "the probe table is arranged")
    Set tBefore = $ClassMethod(tFixture, "Entries", ..#TABLE)
    Set tFileText = ..ExportText(..#TABLE _ ".LUT")
    Do $ClassMethod(tProbe, "WriteFile", "agent.xml", tFileText)
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "extra", "will be removed")
    Set tArgs = ..FileValues("agent.xml")
    Do tArgs.%Set("Name", ..#TABLE, "string")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupTableImport", tArgs, .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the import mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.LOOKUP.IMPORT|1", "its consequence says the table's entries are replaced, and it is destructive")
    Set tCard = tProposal.changed.%ToJSON()
    Do $$$AssertTrue((tCard [ "agent.xml") && (tCard [ ..#TABLE) && (tCard [ """Entries"""), "its card names the file, the table and the counts: " _ tCard)
    Do $$$AssertTrue($Get(tCard) '[ "with space", "and holds no entry of the file")
    Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
    Do $$$AssertNotEquals(tStatus, 200, "the confirm is refused while the import's key is off: " _ $Extract($Get(tRaw), 1, 200))
    Kill tSettings
    Set tSettings(..#IMPORTKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
    ; A file changed after the mint closes the proposal target-changed.
    Do $ClassMethod(tProbe, "WriteFile", "agent.xml", tFileText _ "<!-- changed after the mint -->")
    Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a file changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertTrue($ClassMethod(tFixture, "Entries", ..#TABLE) [ "extra=", "and the table is untouched")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do $ClassMethod(tFixture, "Remove", ..#TABLE, "extra")
    Do $ClassMethod(tProbe, "WriteFile", "agent.xml", ..ExportText(..#TABLE _ ".LUT"))
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "changed after the file")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupTableImport", tArgs, .tFresh, .tFault, .tFreshTurn)
    Do $$$AssertStatusOK(tSC, "a fresh import mints")
    If '$IsObject($Get(tFresh)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = $ClassMethod(tControl, "Confirm", tFresh, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "and confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, 1: ""), "1|updated", "marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), tBefore, "the table holds the file's entries again")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropLookupControl).Audited(tSince, "import", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tFreshTurn))
}

}
