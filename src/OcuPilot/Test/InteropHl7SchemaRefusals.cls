/// <p>Pins Story 24.18 Batch 1's refusals and failures (AD-6, AD-14, AD-29, AD-36, AD-39, AD-54, AD-55, AD-58, AD-62): a new schema's name, base and description, an import file's shape, size, standard mark,
/// letter case and age, and an export's schema, size and directory are each refused by name before any vendor call and with nothing written, from the person's Save and actions, the agent's mint and the port;
/// a namespace under source control refuses every write on every shipped path; a held lock refuses each write; a vendor error or fault is 500 <code>INTERNAL</code>, never 200, with an audit row that
/// reads not completed; and no line the port logs carries a description, a file's text or a vendor's text, or is written while the namespace is switched.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs, and the manager directory as an allowed root;
/// <class>OcuPilot.Test.SourceControlProbe</class> puts <code>USER</code> under source control for one test, which it takes away again.</p>
Class OcuPilot.Test.InteropHl7SchemaRefusals Extends OcuPilot.Test.InteropHl7Case
{

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter ERROR = "OcuPilot.Api.InteropError";

/// <p>A description and a vendor text no log line may carry.</p>
Parameter SECRETTEXT = "OcuSecretText2418";

Parameter KEYS = "interop.hl7schemas.delete,interop.hl7schemas.import";

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##super()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SC, "Disable", ..#SOURCE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Quit ##super()
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The code of <var>pAnswer</var>, an envelope.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The code of the agent's mint of the tool <var>pTool</var>, the sentence in <var>pReason</var>; its turn is cleaned up.</p>
ClassMethod MintCode(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set tCode = ..Mint(pTool, pName, pArgs, .pReason, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Quit tCode
}

/// <p>The import write of the file text <var>pText</var> held under the name <var>pId</var> in the port <var>pClass</var>, with the reviewed values the plain read answered unless
/// <var>pReviewed</var> says to leave them out: <code>status code</code>.</p>
ClassMethod ImportWrite(pText As %String, pId As %String = "import", pClass As %String = {..#PORT}, pReviewed As %Boolean = 1) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = pId
    Set tQuery("fileName") = "f.xml"
    Set tQuery("content") = pText
    Set tSC = $ClassMethod(pClass, "Invoke", ..#ENDPOINT, "HL7IMPORTFILE", .tQuery, "", .tRow, .tHttp, .tFault)
    If pReviewed && $IsObject($Get(tRow)) {
        Set tQuery("digest") = tRow.Digest
        Set tQuery("present") = +tRow.Present
        Set tQuery("modified") = tRow.Modified
    }
    Set tSC = $ClassMethod(pClass, "Invoke", ..#ENDPOINT, "IMPORTHL7SCHEMA", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>AC5: a new schema's name, base or description the port refuses is refused by its code from the Save, the port and the agent's mint (as the tool's arguments), a name the namespace holds in any
/// letter case is <code>TAKEN</code> from each and from the read composed for an add, and nothing is stored, logged or audited.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Hl7FactsHere</method> compare the name exactly -- the other-letter-case legs go red.</p>
Method TestAddValuesTheNamespaceCannotTakeAreRefusedByName()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "held"), "a probe is held")
    Set tSince = ..AuditNow()
    Set tName = "INTEROP.HL7.NAME"
    Set tLong = $Translate($Justify("", 65), " ", "n")
    For tCase = $ListBuild("a space", "a b"), $ListBuild("a leading hyphen", "-x"), $ListBuild("65 characters", tLong), $ListBuild("a tab", "a" _ $Char(9)), $ListBuild("a slash", "a/b") {
        Set tId = $List(tCase, 2)
        Do ..Save({"Name": (tId)}, .tAnswer)
        Do $$$AssertEquals(..CodeOf(tAnswer), tName, $List(tCase, 1) _ ": the Save is refused")
        Do $$$AssertEquals(..Put("ADDHL7SCHEMA", tId, {}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tName, $List(tCase, 1) _ ": the port refuses the add")
        Do $$$AssertEquals(..MintCode("Add", tId, {}, .tReason), tName, $List(tCase, 1) _ ": and the agent's mint, by the same code")
        Do $$$AssertTrue(tReason [ ..Reason("HL7NAME"), $List(tCase, 1) _ ": naming the published sentence: " _ $Extract(tReason, 1, 200))
    }
    Set tTaken = "INTEROP.HL7.TAKEN"
    For tHeld = ..#NAMEA, $ZConvert(..#NAMEA, "U"), $ZConvert(..#NAMEA, "L") {
        Do ..Save({"Name": (tHeld)}, .tAnswer)
        Do $$$AssertEquals(..CodeOf(tAnswer) _ " " _ tAnswer.reason, tTaken _ " " _ ..Reason("HL7TAKEN"), tHeld _ ": the Save is refused with the published sentence")
        Do $$$AssertEquals(..Put("ADDHL7SCHEMA", tHeld, {}, .tResult, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, tHeld _ ": the port refuses the add")
        Do $$$AssertEquals(..Read(tHeld, "ADDHL7SCHEMA", .tRow, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, tHeld _ ": and the read composed for an add")
        Do $$$AssertEquals(..MintCode("Add", tHeld, {}, .tReason), tTaken, tHeld _ ": and the agent's mint")
    }
    Set tBase = "INTEROP.HL7.BASE"
    Do ..Save({"Name": (..#NAMEB), "Base": "nope"}, .tAnswer)
    Do $$$AssertEquals(..CodeOf(tAnswer), tBase, "a base the namespace does not hold: the Save is refused")
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Base": "nope"}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tBase, "and the port")
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Base": ($ZConvert(..#NAMEA, "L"))}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tBase, "a base held only in another letter case is refused too")
    Do $$$AssertEquals(..MintCode("Add", ..#NAMEB, {"Base": "nope"}, .tReason), "TOOL.ARGUMENTS", "and the agent's mint, as the tool's arguments")
    Do $$$AssertTrue(tReason [ ..Reason("HL7BASE"), "naming the published sentence: " _ $Extract(tReason, 1, 200))
    Set tDescription = "INTEROP.HL7.DESCRIPTION"
    Set tBig = $Translate($Justify("", 2001), " ", "d")
    Do ..Save({"Name": (..#NAMEB), "Description": (tBig)}, .tAnswer)
    Do $$$AssertEquals(..CodeOf(tAnswer), tDescription, "a description of 2,001 characters: the Save is refused")
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Description": (tBig)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tDescription, "and the port")
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Description": ($Extract(tBig, 1, 2000))}, .tOk, .tFault, ..#SOURCE, tSeam), "200 ", "a description of 2,000 is taken")
    Do $ClassMethod(tFx, "DropSchemas")
    Do $$$AssertEquals($ClassMethod(tFx, "SchemasLeft") _ "|" _ $ClassMethod(tSeam, "Logged") _ "|" _ ..OwnRows(tSince, "OcuProbe2418", .tData, 1, 1, "OcuProbe2418"), "0|0|0", "nothing was stored, logged or audited by a refusal")
}

/// <p>AC5: an import file that is not exactly one HL7 schema is refused <code>IMPORTSHAPE</code> before any load (a class beside the schema, two schemas, the legacy form with no document, text that is
/// no export, a schema other than the one named), a file over 3,000,000 characters <code>TOOLARGE</code>, a file whose name is held in another letter case <code>CASE</code>, and a reviewed digest, presence or
/// time that moved <code>IMPORTCHANGED</code>; the screen's action, the agent's mint and the port each refuse, and nothing is written.</p>
/// <p>Mutation (Rule 19): accept the first document the listing names in <method>OcuPilot.Port.InteropPort.ImportShape</method>, without requiring that it is the only one -- the two-schema leg goes
/// red; drop the digest comparison from <method>OcuPilot.Port.InteropPort.PerformHl7Import</method> -- the first changed leg goes red.</p>
Method TestAnImportFileOfAnotherShapeSizeOrAgeIsRefusedBeforeAnyLoad()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "kept"), "a probe is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEB, ..#SOURCE, "2.5.1", "second"), "and a second")
    Set tNL = $Char(10)
    Set tHead = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ tNL _ "<Export generator=""IRIS"" version=""26"">" _ tNL
    Set tOne = tHead _ "<Document name=""" _ ..#NAMEA _ ".HL7"">" _ tNL _ "<Category name=""" _ ..#NAMEA _ """ base=""2.5"">" _ tNL _ "</Category>" _ tNL _ "</Document></Export>"
    Set tTwo = tHead _ "<Document name=""" _ ..#NAMEA _ ".HL7"">" _ tNL _ "<Category name=""" _ ..#NAMEA _ """ base=""2.5"">" _ tNL _ "</Category>" _ tNL _ "</Document>" _ tNL _ "<Document name=""" _ ..#NAMEB _ ".HL7"">" _ tNL _ "<Category name=""" _ ..#NAMEB _ """ base=""2.5"">" _ tNL _ "</Category>" _ tNL _ "</Document></Export>"
    Set tClass = tHead _ "<Class name=""OcuProbe2418.Zzz""><Super>%RegisteredObject</Super></Class>" _ tNL _ "<Document name=""" _ ..#NAMEA _ ".HL7"">" _ tNL _ "<Category name=""" _ ..#NAMEA _ """ base=""2.5"">" _ tNL _ "</Category>" _ tNL _ "</Document></Export>"
    Set tRaw = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ tNL _ "<Category name=""" _ ..#NAMEA _ """ base=""2.5"">" _ tNL _ "</Category>" _ tNL
    Set tBefore = $ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Text", ..#NAMEB)
    Set tShape = "409 INTEROP.HL7.IMPORTSHAPE"
    For tCase = $ListBuild("a class beside the schema", tClass), $ListBuild("two schemas", tTwo), $ListBuild("the raw Category form", tRaw), $ListBuild("text that is no export", "not xml at all") {
        Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "c.xml", "content": ($List(tCase, 2))}, .tAnswer), tShape, $List(tCase, 1) _ " is refused for its shape by the screen")
        Do $$$AssertEquals(..ImportWrite($List(tCase, 2), "import", tSeam), tShape, $List(tCase, 1) _ " is refused by the port")
    }
    Do $$$AssertEquals(..ImportWrite(tOne, ..#NAMEB, tSeam), tShape, "a file that holds another schema than the one named is refused")
    Do $ClassMethod(..#PROBE, "WriteFile", "two.xml", tTwo)
    Set tArgs = {"Name": (..#NAMEA), "root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "two.xml"))}
    Do $$$AssertEquals(..MintCode("Import", ..#NAMEA, tArgs, .tReason), "INTEROP.HL7.IMPORTSHAPE", "the agent's import of the two-schema file is refused at the mint")
    Do $$$AssertEquals(..Reason("HL7IMPORTSHAPE"), tReason, "with the published sentence")
    Set tBig = $Translate($Justify("", 3000001), " ", "x")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "big.xml", "content": (tBig)}, .tAnswer), "409 INTEROP.HL7.TOOLARGE", "a local file over 3,000,000 characters is refused for its size")
    Do $ClassMethod(..#PROBE, "WriteFile", "big.xml", tBig)
    Do $$$AssertEquals(..Act("import", "import", {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "big.xml"))}, .tAnswer), "409 INTEROP.HL7.TOOLARGE", "and so is a server file")
    Set tUpper = $Replace(tOne, ..#NAMEA, $ZConvert(..#NAMEA, "U"))
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "u.xml", "content": (tUpper)}, .tAnswer), "409 INTEROP.HL7.CASE", "a file whose schema is held in another letter case is refused for it")
    Do $$$AssertEquals(..ImportWrite(tUpper, "import", tSeam), "409 INTEROP.HL7.CASE", "by the port too")
    Do $$$AssertEquals(..ImportWrite(tOne, "import", tSeam, 0), "409 INTEROP.HL7.IMPORTCHANGED", "a write that names no reviewed values is refused as changed")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "f.xml"
    Set tQuery("content") = tOne
    Do $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "HL7IMPORTFILE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRow.Category _ "|" _ tRow.Present _ "|" _ tRow.%IsDefined("content") _ ($Length(tRow.%Get("content")) > 0) _ "|" _ $Length(tRow.Digest), "200|" _ ..#NAMEA _ "|1|10|64", "the plain read answers the file's schema as held, never the text, and its SHA-256")
    For tMove = $ListBuild("digest", "0" _ $Extract(tRow.Digest, 2, *)), $ListBuild("present", 0), $ListBuild("modified", "2001-01-01 00:00:00.000") {
        Set tQuery("digest") = tRow.Digest
        Set tQuery("present") = +tRow.Present
        Set tQuery("modified") = tRow.Modified
        Set tQuery($List(tMove, 1)) = $List(tMove, 2)
        Do $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "IMPORTHL7SCHEMA", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.HL7.IMPORTCHANGED", "a reviewed " _ $List(tMove, 1) _ " that moved is refused")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Text", ..#NAMEB), tBefore, "nothing was loaded")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("ran"), 0), 0, "and no vendor call ran")
}

/// <p>AC5: an export of a schema the namespace does not hold is 404, one whose text is over 3,000,000 characters <code>TOOLARGE</code> and one to a directory that does not exist
/// <code>EXPLORER.EXPORT.DIRECTORY</code>, from the screen's actions and the agent's mint.</p>
/// <p>Mutation (Rule 19): drop the size test from <method>OcuPilot.Port.InteropPort.Hl7VendorExport</method> -- the oversize leg goes red.</p>
Method TestAnExportOfAMissingSchemaAnOversizeOneOrAMissingDirectoryIsRefused()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "held"), "a probe is held")
    Do $$$AssertEquals(..Act("export-browser", ..#NAMEB, "", .tAnswer), "404 PORT.NOTFOUND", "an export of a schema the namespace does not hold is 404")
    Do $$$AssertEquals(..MintCode("Export", ..#NAMEB, {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "x.xml"))}, .tReason), "TOOL.ARGUMENTS", "and so is the agent's, at the mint")
    Set tFiles = {"root": ($ClassMethod(..#PROBE, "Root")), "path": "nodir/x.xml"}
    Do $$$AssertEquals(..Act("export", ..#NAMEA, tFiles, .tAnswer), "409 EXPLORER.EXPORT.DIRECTORY", "an export to a directory that does not exist is refused")
    Do $$$AssertEquals(..MintCode("Export", ..#NAMEA, {"Name": (..#NAMEA), "root": (tFiles.root), "path": (tFiles.path)}, .tReason), "EXPLORER.EXPORT.DIRECTORY", "and so is the agent's, at the mint")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "FileExists", "x.xml"), 0, "and no file was written")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#SOURCE
    Set ^EnsHL7.Description(..#NAMEA) = $Translate($Justify("", 3000001), " ", "d")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(..Act("export-browser", ..#NAMEA, "", .tAnswer), "409 INTEROP.HL7.TOOLARGE", "a schema whose export is over 3,000,000 characters is refused for its size")
    Do $$$AssertTrue(..Reason("HL7TOOLARGE") [ "3,000,000", "and the sentence states that limit")
}

/// <p>AC5: with <code>USER</code> really under source control every write is refused <code>SOURCECONTROL</code> on every shipped path before anything is stored: the person's Save, Delete and Import,
/// and the agent's mint of the add, the delete and the import, and a delete minted before is refused at the confirm; reads and exports still answer.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.ReadHl7Schema</method> -- the mint legs go red; from
/// <method>OcuPilot.Port.InteropPort.PerformHl7Schema</method> -- the confirm leg goes red.</p>
Method TestEveryShippedWritePathIsRefusedUnderSourceControl()
{
    Set tFx = ..#FIXTURE
    Set tRefusal = "INTEROP.HL7.SOURCECONTROL"
    Set tReason = ..Reason("HL7SOURCECONTROL")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "held"), "a probe is held")
    Do $$$AssertStatusOK(..EnableKeys(..#KEYS), "the delete and import keys are turned on")
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ $Char(10) _ "<Document name=""" _ ..#NAMEB _ ".HL7"">" _ $Char(10) _ "<Category name=""" _ ..#NAMEB _ """ base=""2.5"">" _ $Char(10) _ "</Category>" _ $Char(10) _ "</Document></Export>"
    Do $ClassMethod(..#PROBE, "WriteFile", "b.xml", tText)
    Do $$$AssertEquals(..Mint("Delete", ..#NAMEA, {}, .tDeleteReason, .tDelete, .tDeleteTurn), "minted", "a delete mints while the namespace is not under source control")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#SOURCE), ..#SOURCE _ " is put under source control")
    Do ..Save({"Name": (..#NAMEB)}, .tAnswer)
    Do $$$AssertEquals(..CodeOf(tAnswer) _ "|" _ tAnswer.reason, tRefusal _ "|" _ tReason, "the person's Save is refused with the published sentence")
    Do $$$AssertEquals(..Act("delete", ..#NAMEA, "", .tAnswer), "409 " _ tRefusal, "and the person's Delete")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "b.xml", "content": (tText)}, .tAnswer), "409 " _ tRefusal, "and the person's Import")
    Set tFile = {"root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "b.xml")), "Name": (..#NAMEB)}
    For tCase = $ListBuild("Add", ..#NAMEB, "{}"), $ListBuild("Delete", ..#NAMEA, "{}"), $ListBuild("Import", ..#NAMEB, tFile.%ToJSON()) {
        Do $$$AssertEquals(..MintCode($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), .tMintReason) _ "|" _ tMintReason, tRefusal _ "|" _ tReason, "the agent's " _ $List(tCase, 1) _ " is refused at the mint")
    }
    If $IsObject($Get(tDelete)) {
        Do ..Confirm(tDelete.proposalId, .tHttp, .tRaw, .tConfirmed)
        Do $$$AssertTrue(tHttp '= 200, "the delete minted before is refused at the confirm: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals(..Act("export-browser", ..#NAMEA, "", .tAnswer), "200 ", "an export still answers under source control")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#SOURCE), "the probe's source control is taken out of " _ ..#SOURCE)
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEB), "2.5|held|0|0", "the held schema is unchanged and nothing was added")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tDeleteTurn))
}

/// <p>AC5, AC6: the seam answers source-controlled, a held lock and a vendor error status or fault; each write is refused by its code or is 500 <code>INTERNAL</code>, never 200, with nothing stored and no
/// vendor call made for the first two, and an attempted write that failed leaves an audit row that reads not completed. No log line carries a description, a vendor's text or a file's text.</p>
/// <p>Mutation (Rule 19): drop the status test after <method>OcuPilot.Port.InteropPort.Hl7VendorWrite</method> in <method>OcuPilot.Port.InteropPort.PerformHl7Schema</method> -- the status legs go red.</p>
Method TestALockASourceControlledSeamAndAVendorErrorNeverAnswer200()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Set tSecret = ..#SECRETTEXT
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", tSecret), "a probe holding a description is stored")
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ $Char(10) _ "<Document name=""" _ ..#NAMEB _ ".HL7"">" _ $Char(10) _ "<Category name=""" _ ..#NAMEB _ """ base=""2.5"">" _ $Char(10) _ "</Category>" _ $Char(10) _ "</Document></Export>"
    Set ^IRIS.Temp.OcuProbe2417wMode("source") = 1
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Description": (tSecret)}, .tResult, .tFault, ..#SOURCE, tSeam) _ "|" _ ..Put("DELETEHL7SCHEMA", ..#NAMEA, "", .tResult, .tFault, ..#SOURCE, tSeam) _ "|" _ ..ImportWrite(tText, "import", tSeam), "409 INTEROP.HL7.SOURCECONTROL|409 INTEROP.HL7.SOURCECONTROL|409 INTEROP.HL7.SOURCECONTROL", "the seam answering source-controlled refuses each write by name")
    Kill ^IRIS.Temp.OcuProbe2417wMode("source")
    Set ^IRIS.Temp.OcuProbe2417wMode = "lock"
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {}, .tResult, .tFault, ..#SOURCE, tSeam) _ "|" _ ..Put("DELETEHL7SCHEMA", ..#NAMEA, "", .tResult, .tFault, ..#SOURCE, tSeam) _ "|" _ ..ImportWrite(tText, "import", tSeam), "409 INTEROP.HL7.LOCKED|409 INTEROP.HL7.LOCKED|409 INTEROP.HL7.LOCKED", "a held lock refuses each write by name")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("ran"), 0) _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEB) _ "|" _ $ClassMethod(tFx, "Text", ..#NAMEA), "0|0|2.5|" _ tSecret _ "|0", "no vendor call ran and nothing was written")
    Set tSince = ..AuditNow()
    For tMode = "status", "fault" {
        Set ^IRIS.Temp.OcuProbe2417wMode = tMode
        Do $ClassMethod(tSeam, "ClearLog")
        Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {"Description": (tSecret)}, .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", tMode _ ": a failed add is 500, never 200")
        Do $$$AssertEquals(..Put("DELETEHL7SCHEMA", ..#NAMEA, "", .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", tMode _ ": and a failed delete")
        Do $$$AssertEquals(..ImportWrite(tText, "import", tSeam), "500 INTERNAL", tMode _ ": and a failed import")
        Kill tExportQuery
        Set tExportQuery("id") = ..#NAMEA
        Do $$$AssertEquals(..Verdict("EXPORTHL7SCHEMA", .tExported, .tFault, .tExportQuery, "", ..#SOURCE, tSeam), "500 INTERNAL", tMode _ ": and a failed export")
        Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 4, tMode _ ": each failure was logged once")
        Set tLogged = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue((tLogged '[ $Parameter(tSeam, "HL7MARKER")) && (tLogged '[ tSecret) && (tLogged '[ "<Category"), tMode _ ": and no line carries a vendor's text, a description or a file's text: " _ $Extract(tLogged, 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEB) _ "|" _ $ClassMethod(tFx, "Text", ..#NAMEA), "0|2.5|" _ tSecret _ "|0", "the seam's vendor calls changed nothing")
    Set tAddRows = ..OwnRows(tSince, ..#NAMEB, .tAddData, 4, 1)
    Do $$$AssertEquals(tAddRows, 4, "the failed adds and imports left four ConfigChange rows naming the new schema: " _ tAddRows _ " " _ $Extract(tAddData, 1, 300))
    Do $$$AssertTrue((tAddData [ """completed"":false") && (tAddData '[ tSecret), "each reading not completed and carrying no description: " _ tAddData)
    Set tDeleteRows = ..OwnRows(tSince, ..#NAMEA, .tDeleteData, 4, 1)
    Do $$$AssertEquals(tDeleteRows, 4, "and the failed deletes and exports four naming the held one: " _ tDeleteRows _ " " _ $Extract(tDeleteData, 1, 300))
    Do $$$AssertTrue(tDeleteData [ """completed"":false", "reading not completed too")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("locked"), 0) _ "|" _ $Get(^IRIS.Temp.OcuProbe2417wMode("unlocked"), 0), "6|6", "every vendor lock a failed write took was released, on the status path and on the fault path")
}

/// <p>AC5, AC8: a fault raised in a later namespace-switched block of an add, a delete, an import or an export (an add's or an import's re-read after the vendor write, or the export's own block; a delete has one block) is logged once, after the
/// namespace is restored, in the caller's namespace and without the vendor's text, a 500 is always logged, and a run that no fault reaches answers 200 and logs nothing at all. The probes carry
/// names of their own, so no row another test counts is written.</p>
/// <p>Mutation (Rule 19): add a <code>LogFault</code> call to the end of the switched block of <method>OcuPilot.Port.InteropPort.ExportHl7Schema</method> -- the quiet-success leg goes red.</p>
Method TestAFaultInAnyLaterSwitchedBlockIsLoggedOnceInTheCallersNamespace()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Set tHome = $NAMESPACE
    Set tHeld = "OcuProbe2418c"
    Set tNew = "OcuProbe2418d"
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ $Char(10) _ "<Document name=""" _ tNew _ ".HL7"">" _ $Char(10) _ "<Category name=""" _ tNew _ """ base=""2.5"">" _ $Char(10) _ "</Category>" _ $Char(10) _ "</Document></Export>"
    For tKind = "add", "delete", "import", "export" {
        Set tFaulted = 0
        Set tQuiet = 0
        For tSkip = 1:1:8 {
            Do $ClassMethod(tFx, "DropSchemas")
            Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", tHeld, ..#SOURCE, "2.5", "held"), tKind _ " " _ tSkip _ ": a probe is held")
            Kill ^IRIS.Temp.OcuProbe2417wMode
            Set ^IRIS.Temp.OcuProbe2417wMode = "here"
            Set ^IRIS.Temp.OcuProbe2417wMode("hereSkip") = tSkip
            Do $ClassMethod(tSeam, "ClearLog")
            Kill tQuery
            If tKind = "add" Set tVerdict = ..Put("ADDHL7SCHEMA", tNew, {}, .tResult, .tFault, ..#SOURCE, tSeam)
            If tKind = "delete" Set tVerdict = ..Put("DELETEHL7SCHEMA", tHeld, "", .tResult, .tFault, ..#SOURCE, tSeam)
            If tKind = "import" Set tVerdict = ..ImportWrite(tText, "import", tSeam)
            If tKind = "export" {
                Set tQuery("id") = tHeld
                Set tVerdict = ..Verdict("EXPORTHL7SCHEMA", .tResult, .tFault, .tQuery, "", ..#SOURCE, tSeam)
            }
            Set tLogged = $ClassMethod(tSeam, "Logged")
            Do $$$AssertEquals($NAMESPACE, tHome, tKind _ " " _ tSkip _ ": the process is back in the caller's namespace")
            Do $$$AssertTrue(tLogged '> 1, tKind _ " " _ tSkip _ ": at most one line was logged: " _ tLogged)
            If tVerdict = "500 INTERNAL" Do $$$AssertEquals(tLogged, 1, tKind _ " " _ tSkip _ ": a 500 was logged once")
            If tLogged = 1 {
                Set tFaulted = tFaulted + 1
                Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), tHome, tKind _ " " _ tSkip _ ": and logged in the caller's namespace, never the switched one")
                Do $$$AssertTrue($ClassMethod(tSeam, "LoggedText") '[ $Parameter(tSeam, "HL7MARKER"), tKind _ " " _ tSkip _ ": with no vendor text")
            } ElseIf tVerdict = "200 " {
                Set tQuiet = tQuiet + 1
            }
        }
        If tKind '= "delete" Do $$$AssertTrue(tFaulted '< 1, tKind _ ": a fault in a block after the first was logged: " _ tFaulted)
        Do $$$AssertTrue(tQuiet '< 1, tKind _ ": and a run that no fault reaches answered 200 and logged nothing: " _ tQuiet)
    }
    Kill ^IRIS.Temp.OcuProbe2417wMode
}

/// <p>AC5, AC8: a fault raised inside each namespace-switched block is 500 <code>INTERNAL</code>, raised in the schema's namespace and logged once after the namespace is restored, in the caller's namespace
/// and with no vendor text, for the add, the delete, the import, the one-schema read and the list; <method>TestAFaultInAnyLaterSwitchedBlockIsLoggedOnceInTheCallersNamespace</method> covers the later blocks and the export.</p>
/// <p>Mutation (Rule 19): log from inside the switched block of <method>OcuPilot.Port.InteropPort.ListHl7Schemas</method> -- the logged namespaces go red.</p>
Method TestNothingIsLoggedWhileTheNamespaceIsSwitched()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "held"), "a probe is held")
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ $Char(10) _ "<Document name=""" _ ..#NAMEB _ ".HL7"">" _ $Char(10) _ "<Category name=""" _ ..#NAMEB _ """ base=""2.5"">" _ $Char(10) _ "</Category>" _ $Char(10) _ "</Document></Export>"
    Set tHome = $NAMESPACE
    Do $ClassMethod(tSeam, "ClearLog")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tOkRows, .tFault, .tQuery, "", ..#SOURCE, tSeam) _ "|" _ ..Read(..#NAMEA, "", .tOkRow, .tFault, ..#SOURCE, tSeam) _ "|" _ $ClassMethod(tSeam, "Logged"), "200 |200 |0", "a list and a read that succeed log nothing")
    Set ^IRIS.Temp.OcuProbe2417wMode = "here"
    Do $ClassMethod(tSeam, "ClearLog")
    Kill tQuery
    Do $$$AssertEquals(..Put("ADDHL7SCHEMA", ..#NAMEB, {}, .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault in an add's switched block is 500")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("hereIn")), ..#SOURCE, "it was raised in the namespace the write is for")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace")
    Do $$$AssertEquals(..Put("DELETEHL7SCHEMA", ..#NAMEA, "", .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "and in a delete's")
    Do $$$AssertEquals(..ImportWrite(tText, "import", tSeam), "500 INTERNAL", "and in an import's read")
    Do $$$AssertEquals(..Read(..#NAMEA, "", .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "and in the one-schema read")
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery, "", ..#SOURCE, tSeam), "500 INTERNAL", "and in the list")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace after each")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 6, "each fault was logged once, the import's read and write each")
    Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), tHome _ "," _ tHome _ "," _ tHome _ "," _ tHome _ "," _ tHome _ "," _ tHome, "every line was written in the caller's namespace, never the switched one")
    Do $$$AssertTrue($ClassMethod(tSeam, "LoggedText") '[ $Parameter(tSeam, "HL7MARKER"), "and none carries the fault's text")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEB), "2.5|held|0|0", "the held schema is unchanged and nothing was added")
}

}
