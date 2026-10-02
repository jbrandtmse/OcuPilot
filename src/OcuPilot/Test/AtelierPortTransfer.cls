/// <p>Pins Story 19.13's half of the source code API port in process (AD-21, AD-51, AD-59, AD-61):
/// the export of a set to a server file or as lines, the import's target, preview and write over a
/// server file or a local one, read before the write and refused when the file changed, the UDL
/// header rule, <code>selected</code> sent as listed, the file and size refusals, the import's WRITE
/// pair, the version gate at 6 with compile and delete still served, each write's script, and the
/// caller's namespace restored.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and the manager
/// directory as an allowed root. The vendor is the live instance's, read through
/// <class>OcuPilot.Test.AtelierPortFixture</class> for its version and gate seams, except where a leg
/// arms the fixture's canned routes. It creates and removes the documents and files
/// <class>OcuPilot.Test.ExplorerTransferProbe</class> names.</p>
Class OcuPilot.Test.AtelierPortTransfer Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "and the probe directory")
    Quit $$$OK
}

Method ClearFixtures()
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Invoke <var>pType</var> on <var>pEndpoint</var> in the probe namespace with the query
/// <var>pPairs</var>, a <code>key=value</code> list; a <code>namespace</code> pair names another. A
/// leg that arms the canned routes names the install namespace, where they are compiled.</p>
ClassMethod Act(pEndpoint As %String, pType As %String, pPairs As %List, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    For tI = 1:1:$ListLength(pPairs) {
        Set tQuery($Piece($List(pPairs, tI), "=", 1)) = $Piece($List(pPairs, tI), "=", 2, *)
    }
    Quit $ClassMethod(..#FIXTURE, "Invoke", pEndpoint, pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>An answer or a fault as one text.</p>
ClassMethod Said(pHttp, pResult, pFault) As %String
{
    If $IsObject($Get(pResult)) Quit $Get(pHttp) _ " " _ pResult.%ToJSON()
    If $IsObject($Get(pFault)) Quit $Get(pHttp) _ " " _ pFault.%Get("code")
    Quit $Get(pHttp)
}

/// <p>The probe documents the tests export: two classes and a routine.</p>
Method MakeDocuments()
{
    For tName = "OcuProbe1913.Alpha", "OcuProbe1913.Beta" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), tName _ " is saved")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe1913Mac.mac"), "a probe routine is saved")
}

/// <p>An export to a server file writes the vendor's XML lines as UTF-8, each ended by a line feed,
/// the same lines an export to this browser answers, and replaces a file already at the name; an
/// export to this browser writes no file; a name whose directory does not exist is refused on
/// <code>path</code>; and a set naming a missing document is refused before anything is written.</p>
/// <p>Mutation (Rule 19): drop the last line in <method>OcuPilot.Port.AtelierPort.ExportSet</method>
/// before it is written -- the file leg goes red.</p>
Method TestAnExportWritesTheVendorsLines()
{
    Set tNamespace = $Namespace
    Do ..MakeDocuments()
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tSC = ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Beta.cls,OcuProbe1913.Alpha.cls"), .tLines, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "an export to this browser answers 200: " _ ..Said(.tHttp, .tLines, .tFault))
    If '$IsObject($Get(tLines)) Quit
    Set tText = ""
    Set tIterator = tLines.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ tLine _ $Char(10)
    }
    Do $$$AssertTrue((tText [ "<Class name=""OcuProbe1913.Alpha"">") && (tText [ "<Class name=""OcuProbe1913.Beta"">"), "its lines hold both classes")
    Do $$$AssertEquals($ListLength($ListFromString(..DirectoryNames(), ",")), 0, "and no file is written")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "set.xml", "an older file"), "a file stands at the name")
    Set tSC = ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Alpha.cls,OcuProbe1913.Beta.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "set.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ {"root": (tRoot), "path": ($ClassMethod(..#PROBE, "RelativeName", "set.xml"))}.%ToJSON(), "an export to a server file answers its root and path")
    Do $$$AssertEquals(..Unstamped($ClassMethod(..#PROBE, "ReadFile", "set.xml")), ..Unstamped(tText), "and the file holds the same lines, each ended by a line feed, replacing the older one")
    Set tSC = ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Alpha.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "none/set.xml")), .tResult, .tHttp, .tFault)
    Set tViolation = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.violations.%Get(0), 1: {})
    Do $$$AssertEquals(tHttp _ " " _ tViolation.%Get("field") _ " " _ tViolation.%Get("code") _ " " _ tViolation.%Get("reason"), "400 path EXPLORER.EXPORT.DIRECTORY " _ ##class(OcuPilot.Api.AtelierError).#REASONEXPORTDIRECTORY, "a name whose directory does not exist is refused on path")
    Set tSC = ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Alpha.cls,OcuProbe1913.Gone.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "gone.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "404 EXPLORER.DOCUMENT.ABSENT", "a set naming a missing document is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "FileExists", "gone.xml"), "and nothing is written")
    Set tSC = ..Act("Routines", "EXPORTDOCS", $ListBuild("names=OcuProbe1913Mac.mac"), .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && (tResult.%Get("Present") = "OcuProbe1913Mac.mac") && (tResult.%GetTypeOf("root") = "null") && (tResult.%GetTypeOf("path") = "null") && (tResult.%GetTypeOf("KeepSource") = "unassigned"), "the export's fresh read answers the set with root and path empty: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($Namespace, tNamespace, "the caller's namespace is restored")
}

/// <p><var>pText</var>, an XML export, without its first <code> ts="..."</code> attribute: the
/// <code>Export</code> element stamps the second each export ran, so two exports of the same
/// documents differ there alone.</p>
ClassMethod Unstamped(pText As %String) As %String
{
    Set tStart = $Find(pText, " ts=""")
    If tStart = 0 Quit pText
    Set tEnd = $Find(pText, """", tStart)
    If tEnd = 0 Quit pText
    Quit $Extract(pText, 1, tStart - 6) _ $Extract(pText, tEnd, *)
}

/// <p>The probe directory's file names, comma-separated.</p>
ClassMethod DirectoryNames() As %String
{
    Set tNames = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Do tRS.Execute($ClassMethod(..#PROBE, "Directory"), "*")
    While tRS.Next() {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ ##class(%File).GetFilename(tRS.Get("Name"))
    }
    Quit tNames
}

/// <p>An XML import is previewed and written over the file it reads: the preview's summary names each
/// document new or replacing the instance's own version, sorted, and the write loads exactly those,
/// with the routine spelled as the list spells it, compiling with <code>cuk</code> or not at all; a
/// summary that differs from the file's is refused <code>CHANGED</code> with nothing loaded.</p>
/// <p>Mutation (Rule 19): skip the comparison in <method>OcuPilot.Port.AtelierPort.ImportSet</method>
/// -- the changed leg goes red.</p>
Method TestAnXmlImportLoadsWhatItsPreviewNamed()
{
    Set tNamespace = $Namespace
    Do ..MakeDocuments()
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "all.xml")
    Do ..Act("Routines", "EXPORT", $ListBuild("names=OcuProbe1913Mac.mac", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "mac.xml")), .tResult, .tHttp, .tFault)
    Do ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Alpha.cls,OcuProbe1913.Beta.cls", "root=" _ tRoot, "path=" _ tPath), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the probes are exported")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "and removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe1913.Beta"), "and Beta is saved again")
    Set tBeta = $Piece(..DocsModified("Classes", "OcuProbe1913.Beta.cls"), "=", 2)
    Set tSC = ..Act("Classes", "PREVIEW", $ListBuild("id=import", "root=" _ tRoot, "path=" _ tPath), .tPreview, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the preview answers: " _ ..Said(.tHttp, .tPreview, .tFault))
    If '$IsObject($Get(tPreview)) Quit
    Set tSummary = tPreview.documents
    Set tText = $ClassMethod(..#PROBE, "ReadFile", "all.xml")
    Do $$$AssertTrue(($Piece(tSummary, ", ", 1) = "OcuProbe1913.Alpha.cls new") && ($Piece(tSummary, ", ", 2) [ "OcuProbe1913.Beta.cls replaces ") && (tPreview.count = 2), "it names Alpha new and Beta replacing its version, sorted: " _ tSummary)
    Do $$$AssertTrue(tBeta '= "", "Beta's version is read")
    Do $$$AssertTrue($Extract($Piece($Piece(tSummary, ", ", 2), " replaces ", 2), 1, $Length(tBeta)) = tBeta, "Beta's version is the instance's own: " _ tBeta)
    Do $$$AssertEquals($Piece(tSummary, " (", 2), "sha256 " _ ##class(OcuPilot.Port.AtelierPort).Digest(..Lines(tText)) _ ")", "and the summary ends with the digest of the file's lines")
    Set tSC = ..Act("Classes", "IMPORT", $ListBuild("id=import", "root=" _ tRoot, "path=" _ tPath, "documents=" _ tSummary _ " ", "Compile=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "409 EXPLORER.IMPORT.CHANGED", "a summary that differs is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls"), "and nothing is loaded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "all.xml", tText _ $Char(10)), "the file is rewritten with the same documents and one more line")
    Set tSC = ..Act("Classes", "IMPORT", $ListBuild("id=import", "root=" _ tRoot, "path=" _ tPath, "documents=" _ tSummary, "Compile=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "409 EXPLORER.IMPORT.CHANGED", "a file whose text changed under the same documents is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls"), "and nothing is loaded from it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "all.xml", tText), "the file is put back")
    Set tSC = ..Act("Classes", "IMPORT", $ListBuild("id=import", "root=" _ tRoot, "path=" _ tPath, "documents=" _ tSummary, "Compile=0"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.imported.%ToJSON() _ " " _ tResult.errors, 1: ""), "200 [""OcuProbe1913.Alpha.cls"",""OcuProbe1913.Beta.cls""] 0", "the reviewed summary loads both: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Alpha.cls") && '$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Alpha"), "without compiling when Compile is off")
    Set tSC = ..Act("Routines", "PREVIEW", $ListBuild("id=import", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "mac.xml")), .tPreview, .tHttp, .tFault)
    Set tSC = ..Act("Routines", "IMPORT", $ListBuild("id=import", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "mac.xml"), "documents=" _ tPreview.documents, "Compile=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Piece(tPreview.documents, " (", 1) _ " " _ $Select($IsObject($Get(tResult)): tResult.imported.%ToJSON(), 1: ""), "OcuProbe1913Mac.MAC new [""OcuProbe1913Mac.MAC""]", "a routine is named and loaded as the list spells it")
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.lines.%ToJSON() [ "Compiling routine : OcuProbe1913Mac"), "compiling it when Compile is on: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($Namespace, tNamespace, "the caller's namespace is restored")
}

/// <p>The modified time <code>DOCS</code> answers for <var>pName</var>, as <code>name=time</code>.</p>
ClassMethod DocsModified(pEndpoint As %String, pName As %String) As %String
{
    Do ..Act(pEndpoint, "DOCS", $ListBuild("names=" _ pName), .tResult, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tResult)): tResult.Modified, 1: "")
}

/// <p>The load is sent the file's lines and <code>selected</code> as the list spelled it, with the
/// flags the compile choice sends, and the write lists again first (canned routes).</p>
/// <p>Mutation (Rule 19): send no <code>selected</code> in
/// <method>OcuPilot.Port.AtelierPort.ImportSet</method> -- this goes red.</p>
Method TestTheLoadIsSentTheListedNames()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "ListDocumentsInXMLFiles", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""file"":""a.xml"",""status"":"""",""documents"":[{""name"":""Probe.R.MAC"",""ts"":-1},{""name"":""Probe.A.cls"",""ts"":""2026-10-02 08:59:19.69""}]}]}}")
    Do $ClassMethod(..#FIXTURE, "Arm", "LoadXMLFiles", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[""Load started""],""result"":{""content"":[{""file"":""a.xml"",""status"":""ERROR #5475: probe"",""imported"":[""Probe.A.cls"",""Probe.R.MAC""]}]}}")
    Set tContent = $Char(65279) _ "<?xml version=""1.0""?>" _ $Char(13, 10) _ "<Export>" _ $Char(10)
    Set tSC = ..Act("Classes", "IMPORT", $ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.xml", "content=" _ tContent, "documents=Probe.A.cls replaces 2026-10-02 08:59:19.69, Probe.R.MAC new" _ ..Note(tContent), "Compile=true"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {""imported"":[""Probe.A.cls"",""Probe.R.MAC""],""lines"":[""Load started""],""errors"":true}", "a file status sets errors and is not a fault")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "#5475", "its text is logged")
    Set tList = $ClassMethod(..#FIXTURE, "CallAt", 1)
    Set tLoad = $ClassMethod(..#FIXTURE, "CallAt", 2)
    Do $$$AssertEquals(tList.method _ " " _ tList.body, "ListDocumentsInXMLFiles [{""file"":""a.xml"",""content"":[""<?xml version=\""1.0\""?>"",""<Export>""]}]", "the list is sent the lines, the mark and the carriage return dropped")
    Do $$$AssertEquals(tLoad.method _ " " _ tLoad.params.%ToJSON() _ " " _ tLoad.body, "LoadXMLFiles {""flags"":""cuk""} [{""file"":""a.xml"",""content"":[""<?xml version=\""1.0\""?>"",""<Export>""],""selected"":[""Probe.A.cls"",""Probe.R.MAC""]}]", "the load is sent the listed names and cuk")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 2, "and no other route")
}

/// <p>An XML file the list answers with no document and no <code>status</code> is
/// <code>UNREADABLE</code> at the preview and at the write, and the load is never called (canned
/// routes).</p>
Method TestAFileListingNoDocumentIsUnreadable()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "ListDocumentsInXMLFiles", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""file"":""a.xml"",""status"":"""",""documents"":[]}]}}")
    For tType = "PREVIEW", "IMPORT" {
        Do ..Act("Classes", tType, $ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.xml", "content=<Export/>", "documents=x", "Compile=1"), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "422 EXPLORER.IMPORT.UNREADABLE", tType _ ": a file listing no document is unreadable")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount") _ " " _ $ClassMethod(..#FIXTURE, "CallAt", 1).method _ " " _ $ClassMethod(..#FIXTURE, "CallAt", 2).method, "2 ListDocumentsInXMLFiles ListDocumentsInXMLFiles", "only the list route is called, never the load")
}

/// <p>The UDL header rule (Design Notes): skipped lines, a class, a routine and its two other types,
/// and lines that name nothing.</p>
Method TestTheUdlHeaderNamesTheDocument()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    For tCase = $ListBuild($ListBuild("", "/// Doc", "Include %occStatus", "IncludeGenerator X", "Import Y", "Class Pkg.Name Extends %RegisteredObject"), "Pkg.Name.cls"), $ListBuild($ListBuild("class Pkg.Low [ Abstract ]"), "Pkg.Low.cls"), $ListBuild($ListBuild("ROUTINE Name"), "Name.mac"), $ListBuild($ListBuild("routine Name [Type=INC]"), "Name.inc"), $ListBuild($ListBuild(" ROUTINE  Name  [Type=INT]"), "Name.int"), $ListBuild($ListBuild("ROUTINE Name [Type=BAS]"), ""), $ListBuild($ListBuild("// comment", "Class A.B"), ""), $ListBuild($ListBuild("Class 1Bad"), ""), $ListBuild($ListBuild("ROUTINE Name extra"), ""), $ListBuild($ListBuild(""), "") {
        Set tLines = []
        For tI = 1:1:$ListLength($List(tCase, 1)) {
            Do tLines.%Push($List($List(tCase, 1), tI))
        }
        Do $$$AssertEquals($ClassMethod(tPort, "Header", tLines), $List(tCase, 2), tLines.%ToJSON() _ " names '" _ $List(tCase, 2) _ "'")
    }
}

/// <p>A UDL file is previewed new, written with <code>PUT</code> and compiled, previewed again as
/// replacing its version, and replaced by a second text of the same class; a header that does not
/// parse is <code>UNREADABLE</code> with nothing put.</p>
/// <p>Mutation (Rule 19): drop <code>ignoreConflict</code> from the UDL branch of
/// <method>OcuPilot.Port.AtelierPort.ImportSet</method> -- the replacement leg goes red.</p>
Method TestAUdlFileIsPutAndCompiled()
{
    Set tText = "/// Probe" _ $Char(13, 10) _ "Class OcuProbe1913.Udl Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)
    Do ..Act("Classes", "PREVIEW", $ListBuild("id=import", "fileName=Udl.CLS", "content=" _ tText), .tPreview, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tPreview, .tFault), "200 {""documents"":""OcuProbe1913.Udl.cls new" _ ..Note(tText) _ """,""count"":1}", "a UDL class previews new")
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=Udl.CLS", "content=" _ tText, "documents=OcuProbe1913.Udl.cls new" _ ..Note(tText), "Compile=true"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.imported.%ToJSON() _ " " _ tResult.errors, 1: ""), "200 [""OcuProbe1913.Udl.cls""] 0", "is put: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Udl"), "and compiled")
    Set tSource = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Udl.cls")
    Do $$$AssertEquals($Piece(tSource, $Char(10), 1, 3), "/// Probe" _ $Char(10) _ "Class OcuProbe1913.Udl Extends %RegisteredObject" _ $Char(10) _ "{", "with the file's lines: " _ tSource)
    Do ..Act("Classes", "PREVIEW", $ListBuild("id=import", "fileName=Udl.cls", "content=" _ tText), .tPreview, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tPreview)) && (tPreview.documents = ("OcuProbe1913.Udl.cls replaces " _ $Piece(..DocsModified("Classes", "OcuProbe1913.Udl.cls"), "=", 2) _ ..Note(tText))), "and previews again as replacing its version")
    Set tSecond = "/// Probe replaced" _ $Char(10) _ "Class OcuProbe1913.Udl Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "}" _ $Char(10)
    Do ..Act("Classes", "PREVIEW", $ListBuild("id=import", "fileName=Udl.cls", "content=" _ tSecond), .tPreview, .tHttp, .tFault)
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=Udl.cls", "content=" _ tSecond, "documents=" _ $Select($IsObject($Get(tPreview)): tPreview.documents, 1: ""), "Compile=false"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.imported.%ToJSON() _ " " _ tResult.errors, 1: ""), "200 [""OcuProbe1913.Udl.cls""] 0", "a second text of the class replaces it: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Udl.cls"), $Char(10), 1), "/// Probe replaced", "with that text's lines")
    Do ..Act("Routines", "PREVIEW", $ListBuild("id=import", "fileName=x.mac", "content=OcuProbe1913X ; no header"), .tPreview, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tPreview, .tFault), "422 EXPLORER.IMPORT.UNREADABLE", "a header that does not parse is unreadable")
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=bad.xml", "content=<Export><Class name=""OcuProbe1913.Stub"">", "documents=OcuProbe1913.Stub.cls new", "Compile=true"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "422 EXPLORER.IMPORT.UNREADABLE", "malformed XML is unreadable")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Stub.cls"), "and leaves no stub")
}

/// <p>A file is checked before any route: both files or neither named, a malformed local name, an
/// extension the import does not read, text above three million characters, and a target other than
/// <code>import</code>; and a server file's resolve refuses on its own field.</p>
Method TestAFileIsCheckedBeforeAnyRoute()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    For tCase = $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "root=" _ tRoot, "path=a.xml", "fileName=a.xml", "content=x"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a/b.xml", "content=x"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a\b.xml", "content=x"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a" _ $Char(9) _ ".xml", "content=x"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=" _ $Translate($Justify("", 252), " ", "a") _ ".xml", "content=x"), "400 PORT.VALIDATION"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.txt", "content=x"), "422 EXPLORER.IMPORT.UNREADABLE"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a", "content=x"), "422 EXPLORER.IMPORT.UNREADABLE"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.xml", "content=" _ $Justify("", 3000001)), "400 EXPLORER.IMPORT.TOOLARGE"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=export", "fileName=a.xml", "content=x"), "404 PORT.NOTFOUND"), $ListBuild($ListBuild("namespace=" _ $Namespace, "id=import", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "absent.xml")), "400 PATH.NOFILE") {
        Do ..Act("Classes", "PREVIEW", $List(tCase, 1), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), $List(tCase, 2), $Extract($ListToString($List(tCase, 1), " "), 1, 80) _ ": " _ $List(tCase, 2))
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "big.xml", $Justify("", 3000001)), "a server file one character over the limit is written")
    Do ..Act("Classes", "PREVIEW", $ListBuild("namespace=" _ $Namespace, "id=import", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "big.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "400 EXPLORER.IMPORT.TOOLARGE 0", "a server file over the limit is refused before any route")
    Do ..Act("Classes", "PREVIEW", $ListBuild("namespace=" _ $Namespace, "id=import", "fileName=" _ $Translate($Justify("", 251), " ", "a") _ ".xml", "content=" _ $Justify("", 3000000)), .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "CallCount") = 1, "a 255-character name and three million characters reach the list route: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallAt", 1).method, "ListDocumentsInXMLFiles", "and no other route was called")
    Do ..Act("Classes", "IMPORT", $ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.xml", "content=x", "Compile=maybe"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "400 PORT.VALIDATION", "an import's compile choice is true or false")
    Do $$$AssertEquals(..Lines("a" _ $Char(13, 10) _ $Char(10) _ "b").%ToJSON(), "[""a"","""",""b""]", "lines split on line feeds, a blank line kept")
}

/// <p>A UDL document that does not compile is still put: the import answers 200 naming it, with
/// <code>errors</code> true and the compiler's lines.</p>
Method TestAUdlFileThatDoesNotCompileIsPutWithErrors()
{
    Set tText = "Class OcuProbe1913.Broken Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "Property Broken As OcuProbe1913.NoSuchType;" _ $Char(10) _ "}" _ $Char(10)
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=Broken.cls", "content=" _ tText, "documents=OcuProbe1913.Broken.cls new" _ ..Note(tText), "Compile=true"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.imported.%ToJSON() _ " " _ tResult.errors, 1: ""), "200 [""OcuProbe1913.Broken.cls""] 1", "the document is put and the import reports errors: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.lines.%ToJSON() [ "ERROR"), "with the compiler's lines")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe1913.Broken.cls") && '$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Broken"), "it is saved, uncompiled")
}

/// <p>A server file is read as UTF-8 and an export is written as UTF-8: a UDL class whose comment
/// holds a non-ASCII character imports with it intact, and its export holds that character as its
/// two UTF-8 bytes.</p>
Method TestFilesAreReadAndWrittenAsUtf8()
{
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tText = "/// caf" _ $Char(233) _ $Char(10) _ "Class OcuProbe1913.Accent Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "}" _ $Char(10)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "Accent.cls", tText), "a UTF-8 file is written")
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "Accent.cls"), "documents=OcuProbe1913.Accent.cls new" _ ..Note(tText), "Compile=false"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "it imports: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe1913.Accent"), "without compiling, as Compile is off")
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Accent.cls"), $Char(10), 1), "/// caf" _ $Char(233), "its comment keeps the character")
    Do ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Accent.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "accent.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "it exports: " _ ..Said(.tHttp, .tResult, .tFault))
    Set tStream = ##class(%Stream.FileBinary).%New()
    Do $$$AssertStatusOK(tStream.LinkToFile($ClassMethod(..#PROBE, "Directory") _ "accent.xml"), "the export file opens as bytes")
    Do $$$AssertTrue(tStream.Read(1000000) [ ("caf" _ $Char(195, 169)), "and holds the character as two UTF-8 bytes")
}

/// <p>The port's lines of <var>pText</var>.</p>
ClassMethod Lines(pText As %String) As %DynamicArray
{
    Quit ##class(OcuPilot.Port.AtelierPort).Lines(pText)
}

/// <p>AC1: a class holding a line longer than the vendor's export reads whole is exported with that
/// line whole, and imports back from the exported text as it was.</p>
/// <p>Mutation (Rule 19): answer the vendor's lines unchanged from
/// <method>OcuPilot.Port.AtelierPort.WholeLines</method> -- this goes red.</p>
Method TestALongLineIsExportedWhole()
{
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = ..#PROBENAMESPACE
        Set tClass = ##class(%Dictionary.ClassDefinition).%New()
        Set tClass.Name = "OcuProbe1913.Long"
        Set tClass.Super = "%RegisteredObject"
        Set tMethod = ##class(%Dictionary.MethodDefinition).%New()
        Set tMethod.Name = "Big"
        Set tMethod.ClassMethod = 1
        Set tMethod.ReturnType = "%String"
        Do tMethod.Implementation.WriteLine(" Quit """ _ $Translate($Justify("", 40000), " ", "a") _ """")
        Do tClass.Methods.Insert(tMethod)
        Set tSC = tClass.%Save()
        Set $Namespace = tOrigNS
    } Catch ex {
        Set $Namespace = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "a class with a 40,000-character line is saved")
    Set tBefore = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Long.cls")
    Do ..Act("Classes", "EXPORT", $ListBuild("names=OcuProbe1913.Long.cls"), .tLines, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "it exports: " _ ..Said(.tHttp, .tLines, .tFault))
    If '$IsObject($Get(tLines)) Quit
    Set tExported = ""
    Set tLongest = 0
    Set tIterator = tLines.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tExported = tExported _ tLine _ $Char(10)
        If $Length(tLine) > tLongest Set tLongest = $Length(tLine)
    }
    Do $$$AssertTrue(tLongest > 40000, "the long line is answered whole: " _ tLongest)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "the class is removed")
    Do ..Act("Classes", "PREVIEW", $ListBuild("id=import", "fileName=long.xml", "content=" _ tExported), .tPreview, .tHttp, .tFault)
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=long.xml", "content=" _ tExported, "documents=" _ $Select($IsObject($Get(tPreview)): tPreview.documents, 1: ""), "Compile=0"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the exported text imports: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe1913.Long.cls"), tBefore, "and the class reads back as it was")
}

/// <p>The digest note an import's summary of the text <var>pText</var> ends with.</p>
ClassMethod Note(pText As %String) As %String
{
    Quit " (sha256 " _ ##class(OcuPilot.Port.AtelierPort).Digest(..Lines(pText)) _ ")"
}

/// <p>The matrix row "Export to this browser above the capture ceiling": an export whose answer passes
/// the capture's ceiling is refused 503 <code>PORT.UNAVAILABLE</code>, with the caller's namespace
/// restored (canned routes).</p>
/// <p>Mutation (Rule 19): carry on after a failed route in
/// <method>OcuPilot.Port.AtelierPort.ExportSet</method> -- this goes red.</p>
Method TestAnExportAboveTheCeilingIsUnavailable()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.A.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":false}]}}")
    Do $ClassMethod(..#FIXTURE, "ArmOversize", "ExportToXMLFile")
    Set tNamespace = $Namespace
    Do ..Act("Classes", "EXPORT", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "503 PORT.UNAVAILABLE", "an export above the ceiling is unavailable")
    Do $$$AssertEquals($Namespace, tNamespace, "with the caller's namespace restored")
}

/// <p>An export whose file cannot be written answers 500 <code>INTERNAL</code>, deleting a file it
/// created and leaving one that already stood at the name (canned routes, the fixture's failing
/// write).</p>
/// <p>Mutation (Rule 19): drop the delete in <method>OcuPilot.Port.AtelierPort.ExportSet</method> --
/// the new-file leg goes red; drop its <code>tAbsent</code> guard -- the existing-file leg goes
/// red.</p>
Method TestAFailedExportWriteDeletesOnlyTheFileItCreated()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.A.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":false}]}}")
    Do $ClassMethod(..#FIXTURE, "Arm", "ExportToXMLFile", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[""<Export>"",""</Export>""]}}")
    Do $ClassMethod(..#FIXTURE, "FailWrites")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Do ..Act("Classes", "EXPORT", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "new.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#PROBE, "FileExists", "new.xml"), "500 INTERNAL 0", "a failed write answers 500 and deletes the file it created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "WriteFile", "old.xml", "an older file"), "a file stands at the name")
    Do ..Act("Classes", "EXPORT", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls", "root=" _ tRoot, "path=" _ $ClassMethod(..#PROBE, "RelativeName", "old.xml")), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#PROBE, "ReadFile", "old.xml"), "500 INTERNAL an older file", "and leaves a file that already stood there")
}

/// <p>An import requires WRITE on the namespace's routines database before any route; an export, its
/// preview and the import's target the read pairs alone.</p>
/// <p>Mutation (Rule 19): answer <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> for the
/// import in <method>OcuPilot.Port.AtelierPort.Invoke</method> -- the import leg goes red.</p>
Method TestAnImportRequiresTheWritePair()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "SetResources", "%DB_PROBEHOME", "%DB_PROBEGLOBALS", "")
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tPair = $ListBuild("%Development", "USE"), $ListBuild("%DB_PROBEHOME", "READ"), $ListBuild("%DB_PROBEGLOBALS", "READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do ..Act("Classes", "IMPORT", $ListBuild("namespace=" _ $Namespace, "id=import", "fileName=a.xml", "content=x", "documents=x", "Compile=1"), .tResult, .tHttp, .tFault)
    Set tPair = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ tPair, "403 AUTH.NOPRIVILEGE %DB_PROBEHOME:WRITE", "an import is refused naming the routines database's WRITE pair")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do ..Act("Classes", "IMPORTTARGET", $ListBuild("namespace=" _ $Namespace, "id=import"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "its target needs the read pairs alone")
    Do ..Act("Classes", "EXPORT", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls"), .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp '= 403) && ($ClassMethod(..#FIXTURE, "CallCount") > 0), "and so does an export: " _ ..Said(.tHttp, .tResult, .tFault))
}

/// <p>AC2: on an instance answering version 6 every export and import type is refused 501 naming
/// both versions with no route called, while a compile and a delete are still served.</p>
/// <p>Mutation (Rule 19): <code>ExportToXMLFile:1</code> in
/// <parameter>OcuPilot.Port.AtelierPort.MINVERSIONS</parameter> -- the export legs go red.</p>
Method TestAnOlderInstanceRefusesEveryTransfer()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 6)
    Set tWanted = "501 PORT.NOTIMPLEMENTED " _ $Replace($Replace(##class(OcuPilot.Port.AtelierPort).#REASONVERSION, "{highest}", 6), "{needed}", 7)
    Do $$$AssertEquals(tWanted, "501 PORT.NOTIMPLEMENTED This instance's source code API answers version 6, and this operation needs version 7 or later.", "the reason names both versions")
    For tCase = $ListBuild("EXPORTDOCS", "names=Probe.A.cls"), $ListBuild("EXPORT", "names=Probe.A.cls"), $ListBuild("IMPORTTARGET", "id=import"), $ListBuild("PREVIEW", "id=import"), $ListBuild("IMPORT", "id=import") {
        Do ..Act("Classes", $List(tCase, 1), $ListBuild("namespace=" _ $Namespace, $List(tCase, 2), "fileName=a.xml", "content=x", "Compile=1"), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), tWanted, $List(tCase, 1) _ " is refused at version 6")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.A.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":false}]}}")
    Do $ClassMethod(..#FIXTURE, "Arm", "DeleteDocs", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":[{""name"":""Probe.A.cls"",""db"":""HOME"",""status"":""""}]}")
    Do ..Act("Classes", "COMPILE", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls", "KeepSource=1", "CompileDependents=0", "SkipUpToDate=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a compile is still served at version 6")
    Do ..Act("Classes", "DELETE", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "and so is a delete")
}

/// <p>AD-59: an export renders the file and <code>$System.OBJ.Export</code> of the set, an import the
/// file and <code>$System.OBJ.Load</code> with its compile flags, every value a literal; the reads
/// render nothing.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Port.AtelierPort.SnippetForm</method>
/// for the import -- the import leg goes red.</p>
Method TestEachTransferRendersItsScript()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Set tForms = ""
    For tType = "EXPORT", "IMPORT", "EXPORTDOCS", "IMPORTTARGET", "PREVIEW" {
        Set tForms = tForms _ $Select(tForms = "": "", 1: "|") _ $ClassMethod(tPort, "SnippetForm", "Routines", tType)
    }
    Do $$$AssertEquals(tForms, "objectscript|objectscript|||", "the two writes have a script form and the reads none")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("names") = "A.cls,B.cls"
    Set tQuery("root") = "/data/"
    Set tQuery("path") = "x/a.xml"
    Set tQuery("Compile") = 1
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "EXPORT", .tQuery).%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tFile = ##class(%File).NormalizeFilename(""x/a.xml"", ""/data/"")" _ $Char(10) _ " Set tSC = $System.OBJ.Export(""A.cls,B.cls"", tFile, ""-d"")" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)", "the export")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "IMPORT", .tQuery).%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tFile = ##class(%File).NormalizeFilename(""x/a.xml"", ""/data/"")" _ $Char(10) _ " Set tSC = $System.OBJ.Load(tFile, ""cuk"")" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)", "the import")
    Set tQuery("Compile") = 0
    Set tQuery("path") = "a"",$ZF(-1,""x"")"
    Set tText = $ClassMethod(tPort, "Snippet", "Classes", "IMPORT", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "$System.OBJ.Load(tFile, """")") && (tText [ """a"""",$ZF(-1,""""x"""")"""), "no flags when Compile is off, and every value a literal: " _ tText)
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "PREVIEW", .tQuery).%Size(), 0, "a read renders no step")
}

}
