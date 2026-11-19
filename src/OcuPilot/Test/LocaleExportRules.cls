/// <p>Pins Story 21.15's export (AC6, DW-2606; AD-6, AD-21, AD-29, AD-39, AD-51, AD-53, AD-59) without changing a file or a locale: the port runs as
/// <class>OcuPilot.Test.LocaleGateSeam</class>, which records the export instead of making it. It pins that a locale the list does not hold, a file the allowed
/// directories refuse and a name whose directory does not exist are refused by the port, by <method>OcuPilot.Port.LocalePort.CheckExport</method> and by the mint
/// before any export is sent; that the vendor is asked for the one locale alone, and answers a file or lines with its own counts; that an export past 3,000,000
/// characters to this browser is <code>LOCALE.TOOLARGE</code>; that an export is judged against the read pairs and the tool also holds the file system pair; that
/// its key ships enabled and it is not destructive; and the script it renders.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory as an allowed root, and an instance that lists its current
/// locale. It writes only the probe directory <class>OcuPilot.Test.ExplorerTransferProbe</class> names, and removes it.</p>
Class OcuPilot.Test.LocaleExportRules Extends %UnitTest.TestCase
{

Parameter SEAM = "OcuPilot.Test.LocaleGateSeam";

Parameter TOOL = "OcuPilot.Test.LocaleExportSeam";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter READ = "OcuPilot.Test.LocalePropertyRead";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Quit $ClassMethod(..#PROBE, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Quit $$$OK
}

/// <p>The port's answer to the write or read <var>pType</var> for the locale <var>pName</var> and the file <var>pRoot</var> and <var>pPath</var>, as
/// <code>http|code</code>; the answer in <var>pOut</var>.</p>
Method Call(pType As %String, pName As %String, pRoot As %String = "", pPath As %String = "", Output pOut) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    If pRoot '= "" Set tQuery("root") = pRoot
    If pPath '= "" Set tQuery("path") = pPath
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", pType, .tQuery, "", .pOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The mint <class>OcuPilot.Test.LocaleExportSeamMint</class> gives the export of the locale <var>pName</var> to the file <var>pRoot</var> and
/// <var>pPath</var>, as <code>http|code</code>; <code>0|</code> for a proposal minted.</p>
Method Mint(pName As %String, pRoot As %String, pPath As %String) As %String
{
    Set tTool = ..#TOOL
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set tArgs = {"Name": (pName), "root": (pRoot), "path": (pPath)}
    Set tSC = $ClassMethod($ClassMethod(tTool, "MintClass"), "Mint", $Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pName, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Quit +$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p><b>AC6.</b> An export is refused before any vendor call when the locale is not one the instance lists (404 <code>LOCALE.NOTFOUND</code>), when the file's
/// allowed directory is not one (<code>PATH.ROOT</code>), when a root or a path is sent without the other, and when the name's directory does not exist
/// (<code>EXPLORER.EXPORT.DIRECTORY</code>); <method>OcuPilot.Port.LocalePort.CheckExport</method> and the mint give the file's refusals the port gives, and the mint
/// refuses an argument that names no file.</p>
/// <p>Mutation (Rule 19): the directory check dropped from <code>ExportFile</code> -> the directory rows go red.</p>
Method TestAnExportIsRefusedBeforeAnySendForAnUnknownLocaleAndABadFile()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tGood = $ClassMethod(..#PROBE, "RelativeName", "exported.xml")
    Set tNoDirectory = $ClassMethod(..#PROBE, "RelativeName", "nosuchdirectory/exported.xml")
    Do $$$AssertEquals(..Call("EXPORTLOCALE", "nosuchlocale"), "404|LOCALE.NOTFOUND", "the read of an unlisted locale is not found")
    Do $$$AssertEquals(..Call("EXPORT", "nosuchlocale"), "404|LOCALE.NOTFOUND", "and so is its export")
    Do $$$AssertEquals(..Call("EXPORT", ""), "404|LOCALE.NOTFOUND", "and an export that names none")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, "/no/such/allowed/root/", tGood), "400|PATH.ROOT", "a file under no allowed directory is refused")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, tRoot, ""), "400|PATH.NAME", "a root with no path is refused")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, "", tGood), "400|PATH.ROOT", "a path with no root is refused")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, tRoot, tNoDirectory), "409|EXPLORER.EXPORT.DIRECTORY", "a name whose directory does not exist is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no export was made by any refusal")
    Set tSC = $ClassMethod(..#SEAM, "CheckExport", tRoot, tNoDirectory, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ tHttp _ "|" _ tFault.%Get("code"), "1|409|EXPLORER.EXPORT.DIRECTORY", "CheckExport gives the file's refusal the write gives")
    Set tSC = $ClassMethod(..#SEAM, "CheckExport", tRoot, tGood, .tOkHttp, .tOkFault)
    Do $$$AssertStatusOK(tSC, "and admits a file that may be written")
    Do $$$AssertEquals(..Mint(tCurrent, "/no/such/allowed/root/", tGood), "400|PATH.ROOT", "the mint refuses the file the write would refuse, on its field")
    Do $$$AssertEquals(..Mint(tCurrent, tRoot, tNoDirectory), "409|EXPLORER.EXPORT.DIRECTORY", "including a directory that does not exist")
    Set tMinted = ..Mint(tCurrent, tRoot, tGood)
    Do $$$AssertEquals(tMinted, "200|", "and mints a proposal for a file it admits (" _ tMinted _ ")")
    Do $ClassMethod("OcuPilot.Screen.Tool.LocaleExport", "ArgumentProblem", tCurrent, {"Name": (tCurrent), "root": (tRoot)}, .tProblem)
    Do $$$AssertNotEquals(tProblem, "", "an argument that names no path is refused at the mint")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and nothing was sent")
}

/// <p><b>AC6.</b> The vendor is asked for the one locale named and nothing else, whether the locale is current, shipped or custom: to this browser the answer is the
/// vendor's text as lines with its counts, to a server file the file's root and path with the counts; the read of a locale answers its tables and sub-tables and
/// echoes the file; an export past 3,000,000 characters to this browser is 409 <code>LOCALE.TOOLARGE</code> and one to a file has no such cap; a vendor refusal is
/// a logged 500.</p>
/// <p>Mutation (Rule 19): <code>Export</code> reading the lines without the cap -> the too-large row goes red; the locale's name dropped from <code>SendExport</code>'s
/// call -> the call rows go red.</p>
Method TestTheVendorIsAskedForTheOneLocaleAndTheAnswerCarriesItsCounts()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tGood = $ClassMethod(..#PROBE, "RelativeName", "exported.xml")
    Do $ClassMethod(..#SEAM, "HoldLocale", "yqzw", "posed", 0, 1)
    Do $$$AssertEquals(..Call("EXPORTLOCALE", tCurrent, , , .tRead) _ "|" _ tRead.%Get("Name") _ "|" _ (tRead.%Get("Tables") > 0) _ "|" _ (tRead.%Get("SubTables") > 0) _ "|" _ tRead.%Get("root") _ "|" _ tRead.%Get("path"), "200||" _ tCurrent _ "|1|1||", "the read of the current locale answers its tables and sub-tables and no file")
    Do $$$AssertEquals(..Call("EXPORTLOCALE", tCurrent, tRoot, tGood, .tReadFile) _ "|" _ tReadFile.%Get("root") _ "|" _ tReadFile.%Get("path"), "200||" _ tRoot _ "|" _ tGood, "and echoes the file the query names")
    Do $ClassMethod(..#SEAM, "FeedExport", "line one" _ $Char(10) _ "line two" _ $Char(10), 1, 50, 40)
    For tName = tCurrent, "yqzw" {
        Do $ClassMethod(..#SEAM, "Reset")
        Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
        Do $ClassMethod(..#SEAM, "HoldLocale", "yqzw", "posed", 0, 1)
        Do $ClassMethod(..#SEAM, "FeedExport", "line one" _ $Char(10) _ "line two" _ $Char(10), 1, 50, 40)
        Do $$$AssertEquals(..Call("EXPORT", tName, , , .tOut) _ "|" _ tOut.%Get("lines").%ToJSON() _ "|" _ tOut.%Get("Locales") _ "/" _ tOut.%Get("Tables") _ "/" _ tOut.%Get("SubTables") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||[""line one"",""line two""]|1/50/40|EXPORT|" _ tName _ "|browser", "an export of " _ tName _ " to this browser answers the lines and the counts, for that locale alone")
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "FeedExport", "x", 1, 2, 3)
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, tRoot, tGood, .tFile) _ "|" _ tFile.%Get("root") _ "|" _ tFile.%Get("path") _ "|" _ tFile.%GetTypeOf("lines") _ "|" _ tFile.%Get("Tables") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||" _ tRoot _ "|" _ tGood _ "|unassigned|2|EXPORT|" _ tCurrent _ "|file", "an export to a server file answers the file and the counts, and no lines")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "FeedExport", $Justify("", 3000001))
    Do $$$AssertEquals(..Call("EXPORT", tCurrent), "409|LOCALE.TOOLARGE", "an export past 3,000,000 characters to this browser is too large")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "FeedExport", $Justify("", 3000001))
    Do $$$AssertEquals(..Call("EXPORT", tCurrent, tRoot, tGood), "200|", "and one to a server file is not capped")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor refusal is a logged server error")
}

/// <p><b>AC6 (the gate).</b> An export is judged against the read pairs and never the write pair: a caller holding the read pairs alone may export, one missing
/// <code>%DB_IRISSYS:READ</code> is refused with that pair named, and no export is sent. The tool also holds the file system pair
/// <code>%Admin_FileSystemAccess:USE</code>, which a principal without it fails before any call; the import's tool holds the write pair and the export's does
/// not.</p>
/// <p>Mutation (Rule 19): <code>READPAIRWRITES</code> emptied -> the read-pairs row goes red.</p>
Method TestAnExportNeedsTheReadPairsAndTheToolTheFileSystemPair()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Set tQuery("name") = tCurrent
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "EXPORT", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "403|%DB_IRISSYS:READ|", "a caller without the database read pair is refused, naming it, and nothing is sent")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do $$$AssertEquals(..Call("EXPORT", tCurrent) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||EXPORT|" _ tCurrent _ "|browser", "a caller holding the read pairs alone may export")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tQuery2("name") = "import"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "IMPORT", .tQuery2, "", .tOut2, .tHttp2, .tFault2)
    Do $$$AssertEquals(tHttp2 _ "|" _ tFault2.detail.%Get("failedPair"), "403|%DB_IRISSYS:WRITE", "an import is judged against the write pair")
    Set tExportPairs = $ClassMethod("OcuPilot.Screen.Tool.LocaleExport", "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue(tResolved && ''$ListFind(tExportPairs, $ListBuild("%Admin_FileSystemAccess", "USE")) && '$ListFind(tExportPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "the export tool holds the file system pair and not the write pair")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = ""
    Set tHeld = $ClassMethod("OcuPilot.Test.ScreenGate", "EvaluateRequired", tExportPairs, .tFailed)
    Do $$$AssertEquals(tHeld _ "|" _ tFailed, "0|%Admin_FileSystemAccess:USE", "a principal without the file system pair fails the tool's gate on it")
}

/// <p><b>AC6 (the tool).</b> The export's key ships enabled and the import's disabled; the export is not destructive and states that a file is replaced only
/// when it names one; its screen actions are the export to a server file and to this browser, which names no file; its card shows the locale's tables and sub-tables;
/// and its output is the lines or the file, never anything else.</p>
/// <p>Mutation (Rule 19): <code>Consequence</code> answering the code for an export to this browser -> the consequence row goes red.</p>
Method TestTheExportsKeyDefaultsEnabledAndItsCardOutputAndScriptAreSettled()
{
    Set tTool = "OcuPilot.Screen.Tool.LocaleExport"
    Set tExportKey = ##class(OcuPilot.Kernel.Governance.Baseline).Seed("osmgmt.locales.export", .tListed1)
    Set tImportKey = ##class(OcuPilot.Kernel.Governance.Baseline).Seed("osmgmt.locales.import", .tListed2)
    Do $$$AssertEquals(tExportKey _ tListed1 _ "|" _ tImportKey _ tListed2, "11|01", "the export's key ships enabled and the import's disabled")
    Do $$$AssertEquals($ClassMethod(tTool, "Destructive") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $Parameter(tTool, "WRITETYPE") _ "|" _ $Parameter(tTool, "CLASSICPAGES"), "0|export,export-browser|EXPORT|%CSP.UI.Portal.NLS", "it is not destructive and is reached by two screen actions")
    Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {"root": "r", "path": "p"}) _ "|" _ $ClassMethod(tTool, "Consequence", {}), "EXPLORER.EXPORT.REPLACES|", "a file already there is replaced, which only an export to a file says")
    Do $ClassMethod(tTool, "ScreenActionDelta", "export-browser", {"root": "r"}, "", .tBrowserArgs, .tBrowserProblem)
    Do $ClassMethod(tTool, "ScreenActionDelta", "export", {"root": "r", "path": "p.xml"}, "", .tFileArgs, .tFileProblem)
    Do $$$AssertEquals(tBrowserArgs.%ToJSON() _ "|" _ tBrowserProblem _ "|" _ tFileArgs.%ToJSON() _ "|" _ tFileProblem, "{}||{""root"":""r"",""path"":""p.xml""}|", "the browser export sends no file, and the file export sends its two values")
    Do $ClassMethod(tTool, "ScreenActionDelta", "export", {"root": "r"}, "", .tShortArgs, .tShortProblem)
    Do $$$AssertNotEquals(tShortProblem, "", "an export to a file that names no path is refused on the screen")
    Do $ClassMethod(tTool, "StateDiff", {"Name": "enuw", "Tables": 48, "SubTables": 40}, .tRows, .tDiffProblem)
    Do $$$AssertEquals(tDiffProblem _ "|" _ tRows.%Get(0).%Get("field") _ "=" _ tRows.%Get(0).%Get("after") _ "|" _ tRows.%Get(1).%Get("field") _ "=" _ tRows.%Get(1).%Get("after"), "|Tables=48|Subtables=40", "the card shows the tables and the sub-tables")
    Do $ClassMethod(tTool, "StateDiff", {"Name": "enuw"}, .tNoRows, .tNoProblem)
    Do $$$AssertNotEquals(tNoProblem, "", "a read that answers no counts is refused")
    Set tLines = $ClassMethod(tTool, "WriteOutput", {"Name": "enuw", "lines": ["a", "b"], "Tables": 1})
    Set tFile = $ClassMethod(tTool, "WriteOutput", {"Name": "enuw", "root": "r", "path": "p.xml", "Tables": 1})
    Do $$$AssertEquals(tLines.%ToJSON() _ "|" _ tFile.%ToJSON(), "{""lines"":[""a"",""b""]}|{""root"":""r"",""path"":""p.xml""}", "the output is the lines, or the file, and nothing else")
    Set tSeam = ..#SEAM
    Set tQuery("name") = "yqzw"
    Set tQuery("root") = "/data/"
    Set tQuery("path") = "yqzw.xml"
    Set tScript = $ClassMethod(tSeam, "Snippet", "Locales", "EXPORT", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue((tScript [ "ExportList(tFile, .tExported, .tLocales)") && (tScript [ "Set tLocales(""yqzw"") = """"") && (tScript [ "allowed directory /data/ and the name yqzw.xml"), "its script names the vendor's call, the locale alone and the file")
}

}
