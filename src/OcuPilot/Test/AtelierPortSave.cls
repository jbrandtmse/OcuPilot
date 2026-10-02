/// <p>Pins Story 19.3's half of the source code API port in process (AD-51, AD-59, AD-61): the save of
/// one document's text against the version the editor read -- stored when the version matches, refused
/// <code>CONFLICT</code> when another writer changed the document since and <code>LOCKED</code> while
/// another process holds it, neither logged as a fault (the lock's text at information severity) and
/// the instance's text kept, refused <code>ABSENT</code>
/// for a document deleted since, which is never created again -- the header, size and argument
/// refusals before any route, a soft refusal under 200, the version sent as the vendor's
/// <code>If-None-Match</code> and never <code>ignoreConflict</code>, a class saved under its comment
/// banner and a final empty line kept, the compile after the save, the
/// WRITE pair, the version gate, the save's script, and the caller's namespace restored; and an
/// import's put of a held document refused <code>LOCKED</code> as the save's is.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace. The vendor is the live
/// instance's, read through <class>OcuPilot.Test.AtelierPortFixture</class> for its version and gate
/// seams, except where a leg arms the fixture's canned routes. It creates and removes the documents
/// <class>OcuPilot.Test.ExplorerSaveProbe</class> names, and one lock job, released before its test
/// ends.</p>
Class OcuPilot.Test.AtelierPortSave Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveProbe";

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

/// <p>The probe class every live leg saves.</p>
Parameter ALPHA = "OcuProbe193.Alpha";

/// <p>The envelope a canned docnames route answers, holding <code>Probe.A.cls</code>.</p>
Parameter CANNEDDOCS = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.A.cls"",""ts"":""2026-10-02 09:00:00.120"",""db"":""HOME"",""gen"":false}]}}";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertTrue($ClassMethod(..#PROBE, "ReleaseLock", ..#PROBENAMESPACE), "no lock job is left holding a probe")
    Do ..ClearFixtures()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
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
/// <var>pPairs</var>, a <code>key=value</code> list; a <code>namespace</code> pair names another.</p>
ClassMethod Act(pEndpoint As %String, pType As %String, pPairs As %List, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    For tI = 1:1:$ListLength(pPairs) {
        Set tQuery($Piece($List(pPairs, tI), "=", 1)) = $Piece($List(pPairs, tI), "=", 2, *)
    }
    Quit $ClassMethod(..#FIXTURE, "Invoke", pEndpoint, pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>A save of <var>pText</var> as <var>pName</var> at <var>pVersion</var>, compiled when
/// <var>pCompile</var> is 1.</p>
ClassMethod Save(pEndpoint As %String, pName As %String, pText As %String, pVersion As %String, pCompile As %Boolean, Output pResult, Output pHttp As %Integer, Output pFault, pNamespace As %String = {..#PROBENAMESPACE}) As %Status
{
    Quit ..Act(pEndpoint, "SAVE", $ListBuild("namespace=" _ pNamespace, "names=" _ pName, "content=" _ pText, "version=" _ pVersion, "Compile=" _ pCompile), .pResult, .pHttp, .pFault)
}

/// <p>An answer or a fault as one text.</p>
ClassMethod Said(pHttp, pResult, pFault) As %String
{
    If $IsObject($Get(pResult)) Quit $Get(pHttp) _ " " _ pResult.%ToJSON()
    If $IsObject($Get(pFault)) Quit $Get(pHttp) _ " " _ pFault.%Get("code")
    Quit $Get(pHttp)
}

/// <p>AC1: the class's text saved at the version its read answered is stored as sent, under a new
/// version, uncompiled when Compile is off, with nothing logged; and the save's fresh read answers the
/// document with its three declared values empty.</p>
/// <p>Mutation (Rule 19): drop the <code>If-None-Match</code> seed from
/// <method>OcuPilot.Port.AtelierPort.Route</method> -- the vendor answers 409 and this goes red.</p>
Method TestAMatchingVersionSavesTheText()
{
    Set tNamespace = $Namespace
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue(tVersion '= "", "the viewer's read answers its version: " _ tVersion)
    Do ..Act("Classes", "SAVEDOCS", $ListBuild("names=" _ ..#ALPHA _ ".cls"), .tFresh, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tFresh, .tFault), "200 " _ {"Present": (..#ALPHA _ ".cls"), "Modified": (..#ALPHA _ ".cls=" _ tVersion), "Absent": "", "Namespace": (..#PROBENAMESPACE), "content": null, "version": null, "Compile": null}.%ToJSON(), "the fresh read answers the document at the version the viewer read, its values empty")
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2")
    Do ..Save("Classes", ..#ALPHA _ ".cls", tText, tVersion, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", "the save answers 200 with no output when it does not compile")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tText, "the instance holds the text as sent, in the class's own form")
    Set tAfter = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue((tAfter '= "") && (tAfter '= tVersion), "under a new version: " _ tAfter)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and uncompiled, as Compile is off")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged")
    Do $$$AssertEquals($Namespace, tNamespace, "the caller's namespace is restored")
}

/// <p>AC1: a save at the version read before another writer changed the class is refused 409
/// <code>EXPLORER.DOCUMENT.CONFLICT</code> with its published sentence, unlogged, and the other
/// writer's text stands.</p>
/// <p>Mutation (Rule 19): send <code>ignoreConflict=1</code> from
/// <method>OcuPilot.Port.AtelierPort.SaveSet</method> -- the save overwrites and this goes red.</p>
Method TestAStaleVersionIsRefusedAndTheTextKept()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Hang 0.1
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, ..#ALPHA, "3"), "another writer changes the class")
    Set tTheirs = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue(($ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls") '= tVersion) && (tTheirs [ "Quit 3"), "so its version moves")
    Do ..Save("Classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), tVersion, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $Select($IsObject($Get(tFault)): tFault.reason, 1: ""), "409 EXPLORER.DOCUMENT.CONFLICT " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTCONFLICT, "the stale save is refused with its sentence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tTheirs, "and the other writer's text stands")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged")
}

/// <p>AC5: a save of a class deleted since its read is refused 404 <code>EXPLORER.DOCUMENT.ABSENT</code>,
/// and the class is not created again.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AtelierPort.PresentSet</method> in
/// <method>OcuPilot.Port.AtelierPort.SaveSet</method> -- the vendor creates it and this goes red.</p>
Method TestADocumentDeletedSinceTheReadIsNotCreated()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "and deleted after its read")
    Do ..Save("Classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), tVersion, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "404 EXPLORER.DOCUMENT.ABSENT", "the save is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "and the class is not created")
}

/// <p>AC5: a save of a class another process holds is refused 409 <code>EXPLORER.DOCUMENT.LOCKED</code>
/// with its published sentence and nothing of the vendor's message, which is logged at information
/// severity and never as a fault (AD-61 rule 6), and the class is unchanged.</p>
Method TestALockedDocumentIsRefusedAndKept()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tBefore = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldLock", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "another process holds the class")
    Do ..Save("Classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), tVersion, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $Select($IsObject($Get(tFault)): tFault.reason _ " " _ tFault.%GetTypeOf("detail"), 1: ""), "409 EXPLORER.DOCUMENT.LOCKED " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTLOCKED _ " unassigned", "the save is refused with its sentence alone")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "ReleaseLock", ..#PROBENAMESPACE), "the lock is released")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tBefore, "and the class is unchanged")
    Set tLogged = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue((##class(OcuPilot.Test.LogProbe).Captured("severity") = "0") && (tLogged [ "5864"), "the vendor's lock message is logged at information severity, not as a fault: " _ tLogged)
}

/// <p>AD-61 rule 6: an import of one UDL file replacing a class another process holds is refused 409
/// <code>EXPLORER.DOCUMENT.LOCKED</code> as a save is, the vendor's lock message logged at information
/// severity, and the class is unchanged.</p>
Method TestAnImportOfAHeldDocumentIsRefusedLocked()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tBefore = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "6")
    Do ..Act("Classes", "PREVIEW", $ListBuild("id=import", "fileName=Alpha.cls", "content=" _ tText), .tPreview, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && $IsObject($Get(tPreview)), "the file previews: " _ ..Said(.tHttp, .tPreview, .tFault))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldLock", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "another process holds the class")
    Do ..Act("Classes", "IMPORT", $ListBuild("id=import", "fileName=Alpha.cls", "content=" _ tText, "documents=" _ $Select($IsObject($Get(tPreview)): tPreview.documents, 1: ""), "Compile=false"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "409 EXPLORER.DOCUMENT.LOCKED", "the import is refused as the save is")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "ReleaseLock", ..#PROBENAMESPACE), "the lock is released")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tBefore, "and the class is unchanged")
    Set tLogged = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue((##class(OcuPilot.Test.LogProbe).Captured("severity") = "0") && (tLogged [ "5864"), "the vendor's lock message is logged at information severity: " _ tLogged)
}

/// <p>AC5: before any route, a header naming another class, a routine header without the include
/// type for an include file, text above three million characters, two documents, a compile choice
/// that is not true or false and an empty version are refused; three million characters naming the
/// document reach the routes (canned routes).</p>
/// <p>Mutation (Rule 19): make the header check in <method>OcuPilot.Port.AtelierPort.SaveSet</method>
/// <code>If 0</code> -- the header legs go red.</p>
Method TestTheTextIsCheckedBeforeAnyRoute()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Set tHere = "namespace=" _ $Namespace
    Set tClass = "Class Probe.A Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "}" _ $Char(10)
    For tCase = $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls", "content=Class Probe.B Extends %RegisteredObject", "version=v", "Compile=0"), "422 EXPLORER.SAVE.HEADER"), $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls", "content=/// doc" _ $Char(10) _ "class Probe.a", "version=v", "Compile=0"), "422 EXPLORER.SAVE.HEADER"), $ListBuild("Routines", $ListBuild(tHere, "names=Probe.A.inc", "content=ROUTINE Probe.A", "version=v", "Compile=0"), "422 EXPLORER.SAVE.HEADER"), $ListBuild("Routines", $ListBuild(tHere, "names=Probe.A.mac", "content=ROUTINE Probe.A [Type=INT]", "version=v", "Compile=0"), "422 EXPLORER.SAVE.HEADER"), $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls", "content=" _ tClass _ $Justify("", 3000001 - $Length(tClass)), "version=v", "Compile=0"), "400 EXPLORER.SAVE.TOOLARGE"), $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls,Probe.B.cls", "content=" _ tClass, "version=v", "Compile=0"), "400 PORT.VALIDATION"), $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls", "content=" _ tClass, "version=v", "Compile=maybe"), "400 PORT.VALIDATION"), $ListBuild("Classes", $ListBuild(tHere, "names=Probe.A.cls", "content=" _ tClass, "version=", "Compile=0"), "400 PORT.VALIDATION") {
        Do ..Act($List(tCase, 1), "SAVE", $List(tCase, 2), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), $List(tCase, 3), $Extract($ListToString($List(tCase, 2), " "), 1, 90) _ ": " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do $$$AssertEquals(##class(OcuPilot.Api.AtelierError).#REASONSAVEHEADER _ "|" _ ##class(OcuPilot.Api.AtelierError).#REASONSAVETOOLARGE, "The first line no longer names this document, so the text was not saved.|The text is longer than 3,000,000 characters, the most one save sends.", "with their published sentences")
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", ..#CANNEDDOCS)
    Do ..Act("Classes", "SAVE", $ListBuild(tHere, "names=Probe.A.cls", "content=" _ tClass _ $Justify("", 3000000 - $Length(tClass)), "version=v", "Compile=0"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#FIXTURE, "CallAt", 1).method _ " " _ $ClassMethod(..#FIXTURE, "CallAt", 2).method, "200 {} GetDocNames PutDoc", "three million characters naming the document are saved")
}

/// <p>AC1: the put carries the version as <code>If-None-Match</code>, no query parameter (so never
/// <code>ignoreConflict</code>), and the text's lines; a save that compiles then compiles the one
/// document with <code>cuk</code> and answers its lines (canned routes).</p>
/// <p>Mutation (Rule 19): drop the <code>If-None-Match</code> seed from
/// <method>OcuPilot.Port.AtelierPort.Route</method> -- this goes red.</p>
Method TestTheVersionIsSentAsIfNoneMatch()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", ..#CANNEDDOCS)
    Do $ClassMethod(..#FIXTURE, "Arm", "Compile", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[""Compiling class Probe.A""],""result"":{""content"":[]}}")
    Set tText = "Class Probe.A Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)
    Do ..Save("Classes", "Probe.A.cls", tText, "2026-10-02 09:00:00.120", 1, .tResult, .tHttp, .tFault, $Namespace)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {""lines"":[""Compiling class Probe.A""],""errors"":false}", "a save that compiles answers the compiler's lines")
    Set tPut = $ClassMethod(..#FIXTURE, "CallAt", 2)
    Do $$$AssertEquals(tPut.method _ " " _ tPut.arg _ " " _ tPut.ifNoneMatch _ " " _ tPut.params.%ToJSON() _ " " _ tPut.contentType, "PutDoc Probe.A.cls 2026-10-02 09:00:00.120 {} application/json", "the put carries the version as If-None-Match and no query parameter")
    Do $$$AssertEquals(tPut.body, "{""enc"":false,""content"":[""Class Probe.A Extends %RegisteredObject"",""{"",""}"",""""]}", "and the text's lines, its final line feed keeping an empty last line")
    Set tCompile = $ClassMethod(..#FIXTURE, "CallAt", 3)
    Do $$$AssertEquals(tCompile.method _ " " _ tCompile.params.%ToJSON() _ " " _ tCompile.body, "Compile {""flags"":""cuk"",""source"":0} [""Probe.A.cls""]", "then the compile of the one document")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", ..#CANNEDDOCS)
    Do ..Save("Classes", "Probe.A.cls", tText, "v", 0, .tResult, .tHttp, .tFault, $Namespace)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), "200 {} 2", "with Compile off nothing is compiled")
}

/// <p>A soft refusal under 200 is 422 <code>EXPLORER.SAVE.REFUSED</code> and an access refusal 403
/// <code>PORT.ACCESSDENIED</code>, each logged as a fault; the vendor's 409 and 423 are
/// <code>CONFLICT</code>, unlogged, and <code>LOCKED</code>, its text logged at information severity
/// (AD-61 rule 6); nothing is compiled after any of them (canned routes).</p>
/// <p>Mutation (Rule 19): log the 423 through <method>OcuPilot.Port.AtelierPort.LogFault</method> --
/// the <code>LOCKED</code> leg goes red.</p>
Method TestTheVendorsRefusalsAreAnsweredByName()
{
    Set tText = "Class Probe.A Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "}"
    Set tSoft = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Probe.A.cls"",""ts"":"""",""status"":""ERROR #CODE: probe refusal""}}"
    For tCase = $ListBuild("200 OK", $Replace(tSoft, "CODE", "16021"), "422 EXPLORER.SAVE.REFUSED", "2"), $ListBuild("200 OK", $Replace(tSoft, "CODE", "5883"), "403 PORT.ACCESSDENIED", "2"), $ListBuild("409 Conflict", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Probe.A.cls"",""status"":"""",""content"":[""Class Probe.A""]}}", "409 EXPLORER.DOCUMENT.CONFLICT", ""), $ListBuild("423 Locked", $Replace(tSoft, "CODE", "5864"), "409 EXPLORER.DOCUMENT.LOCKED", "0") {
        Do ..ClearFixtures()
        Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
        Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
        Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", ..#CANNEDDOCS)
        Do $ClassMethod(..#FIXTURE, "Arm", "PutDoc", $List(tCase, 1), $List(tCase, 2))
        Do ..Save("Classes", "Probe.A.cls", tText, "v", 1, .tResult, .tHttp, .tFault, $Namespace)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $ClassMethod(..#FIXTURE, "CallCount"), $List(tCase, 3) _ " 2", $List(tCase, 1) _ " is " _ $List(tCase, 3) _ ", with nothing compiled")
        Set tLogged = ##class(OcuPilot.Test.LogProbe).Captured("message")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), $List(tCase, 4), $List(tCase, 3) _ $Case($List(tCase, 4), "": " is not logged", "0": " is logged at information severity", : " is logged as a fault") _ ": " _ tLogged)
        If $List(tCase, 4) '= "" Do $$$AssertTrue(tLogged [ $Piece($Piece($List(tCase, 2), "#", 2), ":", 1), "with the vendor's text: " _ tLogged)
        If $IsObject($Get(tFault)) Do $$$AssertTrue(tFault.reason '[ "#", "and its reason carries no vendor text: " _ tFault.reason)
    }
}

/// <p>Each kind is saved by its header: a routine, an include file and an intermediate routine, each
/// read, changed and saved back with an empty last line, read back as saved.</p>
/// <p>Mutation (Rule 19): drop the empty last line <method>OcuPilot.Port.AtelierPort.SaveSet</method>
/// keeps for a final line feed -- this goes red.</p>
Method TestEachRoutineKindIsSavedByItsHeader()
{
    For tName = "OcuProbe193Mac.mac", "OcuProbe193Inc.inc", "OcuProbe193Int.int" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, tName), tName _ " is saved")
        Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, tName)
        Set tRead = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, tName)
        Do $$$AssertTrue((tVersion '= "") && ($Piece(tRead, $Char(10), 1) [ "ROUTINE"), tName _ " reads with its header: " _ $Piece(tRead, $Char(10), 1))
        Set tText = tRead _ $Char(10) _ " ; saved by Story 19.3's probe" _ $Char(10)
        Do ..Save("Routines", tName, tText, tVersion, 0, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", tName _ " is saved")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, tName), tText, tName _ " reads back as saved")
    }
}

/// <p>AC1: a class whose text the vendor keeps under a <code>/* ... */</code> banner is read, changed
/// and saved with its banner, and the header rule skips a one-line or a multi-line comment but not
/// one left open.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Port.AtelierPort.Header</method> skipping a
/// <code>/*</code> line -- this goes red.</p>
Method TestAClassUnderACommentBannerIsSaved()
{
    Set tBanner = "/* Probe banner" _ $Char(10) _ "   kept above the class */" _ $Char(10) _ $Char(10)
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#PROBENAMESPACE, ..#ALPHA, tBanner _ $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "1"), $Char(10)), "a probe class under a banner is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tRead = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertTrue(($Extract(tRead, 1, 2) = "/*") && (tRead [ "Quit 1"), "the vendor's text keeps the banner: " _ $Piece(tRead, $Char(10), 1))
    Set tText = $Replace(tRead, "Quit 1", "Quit 2")
    Do ..Save("Classes", ..#ALPHA _ ".cls", tText, tVersion, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", "the class is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tText, "with its banner")
    For tCase = $ListBuild($ListBuild("/* one line */", "Class A.B"), "A.B.cls"), $ListBuild($ListBuild("/* opened", " closed */", "", "Class A.B"), "A.B.cls"), $ListBuild($ListBuild("/* never closed", "Class A.B"), "") {
        Set tLines = []
        For tI = 1:1:$ListLength($List(tCase, 1)) {
            Do tLines.%Push($List($List(tCase, 1), tI))
        }
        Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).Header(tLines), $List(tCase, 2), tLines.%ToJSON() _ " names '" _ $List(tCase, 2) _ "'")
    }
}

/// <p>AC4: a save that compiles answers the compiler's lines; a text that does not compile is still
/// saved, its lines reporting errors.</p>
Method TestASaveCompilesWhenAsked()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Do ..Save("Classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "4"), tVersion, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && $IsObject($Get(tResult)) && (tResult.lines.%ToJSON() [ ("Compiling class " _ ..#ALPHA)) && (tResult.errors = 0), "the save compiles: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and the class is compiled")
    Set tVersion = $ClassMethod(..#PROBE, "Version", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tBroken = "Class " _ ..#ALPHA _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "Property Broken As OcuProbe193.NoSuchType;" _ $Char(10) _ "}"
    Do ..Save("Classes", ..#ALPHA _ ".cls", tBroken, tVersion, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && $IsObject($Get(tResult)) && (tResult.errors = 1) && (tResult.lines.%ToJSON() [ "ERROR"), "a text that does not compile answers its errors: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls") [ "Property Broken As OcuProbe193.NoSuchType;", "and is saved all the same")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and neither compile's lines are logged")
}

/// <p>AC6: a save requires WRITE on the namespace's routines database before any route; its fresh read
/// the read pairs alone (canned routes, the fixture's gate).</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.AtelierPort.TYPESAVE</parameter> from the
/// write types in <method>OcuPilot.Port.AtelierPort.Invoke</method> -- this goes red.</p>
Method TestASaveRequiresTheWritePair()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "SetResources", "%DB_PROBEHOME", "%DB_PROBEGLOBALS", "")
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tPair = $ListBuild("%Development", "USE"), $ListBuild("%DB_PROBEHOME", "READ"), $ListBuild("%DB_PROBEGLOBALS", "READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do ..Save("Classes", "Probe.A.cls", "Class Probe.A", "v", 0, .tResult, .tHttp, .tFault, $Namespace)
    Set tPair = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ tPair, "403 AUTH.NOPRIVILEGE %DB_PROBEHOME:WRITE", "a save is refused naming the routines database's WRITE pair")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do $ClassMethod(..#FIXTURE, "Arm", "GetDocNames", "200 OK", ..#CANNEDDOCS)
    Do ..Act("Classes", "SAVEDOCS", $ListBuild("namespace=" _ $Namespace, "names=Probe.A.cls"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "its fresh read needs the read pairs alone: " _ ..Said(.tHttp, .tResult, .tFault))
}

/// <p>On an instance whose source code API answers no version the save's read and write are each
/// refused 501 naming both versions, with no route called.</p>
Method TestAnInstanceWithoutTheRoutesRefusesTheSave()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 0)
    Set tWanted = "501 PORT.NOTIMPLEMENTED " _ $Replace($Replace(##class(OcuPilot.Port.AtelierPort).#REASONVERSION, "{highest}", 0), "{needed}", 1)
    For tType = "SAVEDOCS", "SAVE" {
        Do ..Act("Routines", tType, $ListBuild("namespace=" _ $Namespace, "names=Probe.mac", "content=ROUTINE Probe", "version=v", "Compile=0"), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), tWanted, tType _ " is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).MinVersion("Classes", "SAVE") _ " " _ ##class(OcuPilot.Port.AtelierPort).MinVersion("Classes", "SAVEDOCS"), "1 1", "both need version 1, the docnames, put and compile routes'")
}

/// <p>AD-59: a save renders the namespace, the class's <code>SetTextFromString</code> or the routine's
/// <code>%Routine</code> with the text as the placeholder <code>"&lt;content&gt;"</code>, never the
/// text, then its compile when Compile is on; its read renders nothing.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from
/// <method>OcuPilot.Port.AtelierPort.SnippetForm</method> for the save -- this goes red.</p>
Method TestTheSaveRendersItsScript()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Classes", "SAVE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Routines", "SAVE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Classes", "SAVEDOCS"), "objectscript|objectscript|", "the save has a script form and its read none")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("names") = "Pkg.Name.cls"
    Set tQuery("content") = "Class Pkg.Name { ClassMethod Probe() { Quit ""TEXTMARKER"" } }"
    Set tQuery("version") = "2026-10-02 09:00:00.120"
    Set tQuery("Compile") = 1
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "SAVE", .tQuery).%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, ""Pkg.Name"", ""<content>"", $Char(10))" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)" _ $Char(10) _ " Set tSC = $System.OBJ.CompileList(""Pkg.Name.cls"", ""cuk"")" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)", "a class")
    Set tQuery("names") = "Name.inc"
    Set tQuery("Compile") = 0
    Set tText = $ClassMethod(tPort, "Snippet", "Routines", "SAVE", .tQuery).%Get(0).text
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tRoutine = ##class(%Routine).%New(""Name.inc"")" _ $Char(10) _ " Do tRoutine.Clear()" _ $Char(10) _ " Do tRoutine.Write(""<content>"")" _ $Char(10) _ " Set tSC = tRoutine.Save()" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)", "a routine, not compiled when Compile is off")
    Do $$$AssertTrue((tText '[ "TEXTMARKER") && (tText '[ "2026-10-02"), "and the text and version are never rendered")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "SAVEDOCS", .tQuery).%Size(), 0, "a read renders no step")
}

}
