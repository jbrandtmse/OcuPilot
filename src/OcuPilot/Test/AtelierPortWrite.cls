/// <p>Pins Story 19.2's half of the source code API port (AD-51, AD-59, AD-61): the read of a document
/// set (<code>DOCS</code>), the compile and the delete composed from the declared values, each write's
/// fresh read refusing a missing document before any vendor write, the routines database's WRITE
/// pair gated before any route, a compile's errors answered as its output and never as a fault, a
/// delete's per-document results mapped to port-owned reasons with the vendor's text logged, a
/// privilege soft error answered <code>PORT.ACCESSDENIED</code>, the set's size and shape refused
/// before any route, the namespace restored, the <code>work</code> routes never called, and each
/// write's script form.</p>
/// <p>The vendor is <class>OcuPilot.Test.AtelierPortFixture</class>'s canned routes, read in the
/// install namespace; denials are driven through <class>OcuPilot.Test.ScreenGate</class>. Nothing is
/// written to the instance.</p>
Class OcuPilot.Test.AtelierPortWrite Extends %UnitTest.TestCase
{

/// <p>A <code>docnames/CLS</code> answer holding three probe classes.</p>
Parameter DOCSANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.Alpha.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""Probe.Beta.cls"",""ts"":""2026-02-10 10:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""Probe.Gamma.cls"",""ts"":""2026-03-10 10:00:00.000"",""db"":""HOME"",""gen"":true}]}}";

/// <p>A compile answer with no error, its console lines as the route writes them.</p>
Parameter COMPILEANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":["""",""Compilation started on 10/02/2026 05:04:33 with qualifiers 'cuk'"",""Compiling class Probe.Alpha"",""Compilation finished successfully in 0.012s.""],""result"":{""content"":[]}}";

/// <p>A compile answer whose status carries the first error alone and whose console carries both.</p>
Parameter COMPILEERRORANSWER = "{""status"":{""errors"":[{""error"":""ERROR #5030: An error occurred while compiling class 'Probe.Alpha'"",""code"":5030}],""summary"":""x""},""console"":["""",""Compiling class Probe.Alpha"",""ERROR #1003: Expected a space : at line 3"",""ERROR #5030: An error occurred while compiling class 'Probe.Alpha'"",""Detected 1 errors during compilation in 0.010s.""],""result"":{""content"":[]}}";

/// <p>A delete answer: one document deleted, one refused for want of a privilege and one held by
/// another process.</p>
Parameter DELETEANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":[{""name"":""Probe.Alpha.cls"",""db"":""HOME"",""status"":""""},{""name"":""Probe.Beta.cls"",""db"":""HOME"",""status"":""ERROR #5883: Item 'Probe.Beta.CLS' is mapped from a database that you do not have write permission on""},{""name"":""Probe.Gamma.cls"",""db"":""HOME"",""status"":""ERROR #5864: Probe.Gamma.cls is locked""}]}";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Arm the canned routes, the namespace's databases and the three probe classes.</p>
ClassMethod ArmVendor()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("%DB_PROBEHOME", "%DB_PROBEGLOBALS", "")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDocNames", "200 OK", ..#DOCSANSWER)
}

/// <p>Invoke <var>pType</var> on the classes list for the set <var>pNames</var>, with the three
/// compile values where <var>pFlags</var> spells them as three digits.</p>
ClassMethod Act(pType As %String, pNames As %String, pFlags As %String, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("names") = pNames
    If pFlags '= "" {
        Set tQuery("KeepSource") = $Extract(pFlags, 1)
        Set tQuery("CompileDependents") = $Extract(pFlags, 2)
        Set tQuery("SkipUpToDate") = $Extract(pFlags, 3)
    }
    Quit ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The methods the canned routes were called for, comma-separated in call order.</p>
ClassMethod Methods() As %String
{
    Set tMethods = ""
    For tI = 1:1:##class(OcuPilot.Test.AtelierPortFixture).CallCount() {
        Set tMethods = tMethods _ $Select(tMethods = "": "", 1: ",") _ ##class(OcuPilot.Test.AtelierPortFixture).CallAt(tI).method
    }
    Quit tMethods
}

/// <p><code>DOCS</code> answers which documents of the set the namespace holds, from one
/// <code>docnames</code> read with its generated documents and no filter: the held and the missing
/// names in the set's canonical order, each held name's modified time, the namespace read, and the
/// three compile values empty beside them.</p>
/// <p>Mutation (Rule 19): drop <code>generated=1</code> from <method>OcuPilot.Port.AtelierPort.Docs</method>
/// -- the call assertion goes red.</p>
Method TestTheSetReadAnswersHeldAndMissingDocuments()
{
    Do ..ArmVendor()
    Set tSC = ..Act("DOCS", "Probe.Gamma.cls,Probe.Missing.cls,Probe.Alpha.cls,Probe.Alpha.cls", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the set reads")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), "{""Present"":""Probe.Alpha.cls,Probe.Gamma.cls"",""Modified"":""Probe.Alpha.cls=2026-01-10 10:00:00.000,Probe.Gamma.cls=2026-03-10 10:00:00.000"",""Absent"":""Probe.Missing.cls"",""Namespace"":""" _ $Namespace _ """,""KeepSource"":null,""CompileDependents"":null,""SkipUpToDate"":null}", "held, modified and missing names, a generated class among the held")
    Do $$$AssertEquals(..Methods(), "GetDocNames", "one route")
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Do $$$AssertEquals(tCall.arg _ " " _ tCall.params.%ToJSON() _ " in " _ tCall.current, "CLS {""generated"":1} in " _ $Namespace, "docnames with its generated documents and no filter, in the namespace read")
}

/// <p>AC1: a compile sends <code>c</code> plus exactly the declared flags -- <code>u</code>,
/// <code>k</code> and <code>b</code> for SkipUpToDate, KeepSource and CompileDependents -- as one call
/// over the canonical set, after the fresh read, with the body a JSON array and no source asked back;
/// it answers the console lines, and the caller's namespace and objects are as they were.</p>
/// <p>Mutation (Rule 19): drop <code>k</code> from <method>OcuPilot.Port.AtelierPort.CompileFlags</method>
/// -- the <code>cuk</code> leg goes red.</p>
Method TestACompileSendsCPlusTheDeclaredFlags()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Compile", "200 OK", ..#COMPILEANSWER)
    Set tNamespace = $Namespace
    For tCase = $ListBuild("101", "cuk"), $ListBuild("000", "c"), $ListBuild("010", "cb"), $ListBuild("111", "cukb"), $ListBuild("100", "ck"), $ListBuild("001", "cu") {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ..ArmVendor()
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Compile", "200 OK", ..#COMPILEANSWER)
        Set tSC = ..Act("COMPILE", "Probe.Beta.cls,Probe.Alpha.cls", $List(tCase, 1), .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the compile is made")
        Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
        Do $$$AssertEquals(tCall.method _ " " _ tCall.params.%ToJSON() _ " " _ tCall.contentType _ " " _ tCall.body, "Compile {""flags"":""" _ $List(tCase, 2) _ """,""source"":0} application/json [""Probe.Alpha.cls"",""Probe.Beta.cls""]", $List(tCase, 1) _ ": the vendor receives flags " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(..Methods(), "GetDocNames,Compile", "the fresh read, then the one compile, and no other route")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), "{""lines"":["""",""Compilation started on 10/02/2026 05:04:33 with qualifiers 'cuk'"",""Compiling class Probe.Alpha"",""Compilation finished successfully in 0.012s.""],""errors"":false}", "it answers the console lines")
    Do $$$AssertEquals($Namespace, tNamespace, "the namespace is restored")
}

/// <p>A compile whose status carries an error answers 200 with <code>errors</code> true and every
/// error line in <code>lines</code>, which the status alone does not hold; it is not a fault and
/// logs nothing (AD-39's fifth exception).</p>
Method TestACompileErrorIsTheCompilesOwnOutput()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Compile", "200 OK", ..#COMPILEERRORANSWER, $$$ERROR($$$GeneralError, "first error only"))
    Set tSC = ..Act("COMPILE", "Probe.Alpha.cls", "101", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a compile error is not a fault")
    Do $$$AssertEquals(tHttp, 200, "it answers 200")
    Do $$$AssertTrue($IsObject($Get(tResult)) && tResult.errors, "errors is true")
    Set tText = $Select($IsObject($Get(tResult)): tResult.lines.%ToJSON(), 1: "")
    Do $$$AssertTrue((tText [ "ERROR #1003") && (tText [ "ERROR #5030"), "every error line is in the output: " _ tText)
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and no console line reaches the log")
}

/// <p>Each write reads the set first and refuses one naming a document the namespace does not hold,
/// 404 <code>EXPLORER.DOCUMENT.ABSENT</code> naming it, with nothing sent.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AtelierPort.PresentSet</method> in the compile --
/// the compile leg goes red.</p>
Method TestAMissingDocumentRefusesTheWriteBeforeAnythingIsSent()
{
    For tType = "COMPILE", "DELETE" {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ..ArmVendor()
        Set tSC = ..Act(tType, "Probe.Alpha.cls,Probe.Missing.cls", $Select(tType = "COMPILE": "101", 1: ""), .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tType _ ": refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason _ " " _ tFault.detail.%ToJSON(), 1: ""), "404 EXPLORER.DOCUMENT.ABSENT " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTABSENT _ " {""documents"":[""Probe.Missing.cls""]}", tType _ ": naming the missing document")
        Do $$$AssertEquals(..Methods(), "GetDocNames", tType _ ": only the fresh read was made")
    }
}

/// <p>A delete is one call over the canonical set, and each document's own result maps to a
/// port-owned reason -- the access, locked and absent sentences, and the failed one for anything else
/// -- while the vendor's text is logged and never answered.</p>
/// <p>Mutation (Rule 19): answer the vendor's status as the reason in
/// <method>OcuPilot.Port.AtelierPort.DeleteSet</method> -- the documents leg goes red.</p>
Method TestADeleteAnswersEachDocumentWithAPortOwnedReason()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("DeleteDocs", "200 OK", ..#DELETEANSWER)
    Set tSC = ..Act("DELETE", "Probe.Gamma.cls,Probe.Beta.cls,Probe.Alpha.cls", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a delete with refused documents is not a fault")
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
    Do $$$AssertEquals(tCall.method _ " " _ tCall.contentType _ " " _ tCall.body _ " " _ tCall.params.%ToJSON(), "DeleteDocs application/json [""Probe.Alpha.cls"",""Probe.Beta.cls"",""Probe.Gamma.cls""] {}", "one call over the canonical set")
    Set tWant = [{"name": "Probe.Alpha.cls", "deleted": true, "reason": ""}]
    Do tWant.%Push({"name": "Probe.Beta.cls", "deleted": false, "reason": (##class(OcuPilot.Api.AtelierError).#DELETEACCESS)})
    Do tWant.%Push({"name": "Probe.Gamma.cls", "deleted": false, "reason": (##class(OcuPilot.Api.AtelierError).#DELETELOCKED)})
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), {"documents": (tWant)}.%ToJSON(), "each document's result, in port-owned words")
    Set tLogged = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLogged [ "#5864", "the vendor's text is logged: " _ tLogged)
    Do $$$AssertTrue(tResult.%ToJSON() '[ "#58", "and never answered")
    For tCase = $ListBuild("", ""), $ListBuild("ERROR #5838: You need %Development", ##class(OcuPilot.Api.AtelierError).#DELETEACCESS), $ListBuild("ERROR #302: write denied", ##class(OcuPilot.Api.AtelierError).#DELETEACCESS), $ListBuild("ERROR #5002: ObjectScript error: <PROTECT>x", ##class(OcuPilot.Api.AtelierError).#DELETEACCESS), $ListBuild("ERROR #5001: Document Does Not Exist: User.X.cls", ##class(OcuPilot.Api.AtelierError).#DELETEABSENT), $ListBuild("ERROR #16005: Document 'X.cls' does NOT exist", ##class(OcuPilot.Api.AtelierError).#DELETEABSENT), $ListBuild("ERROR #5001: something else", ##class(OcuPilot.Api.AtelierError).#DELETEFAILED) {
        Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).DeleteReason($List(tCase, 1)), $List(tCase, 2), "the reason for '" _ $List(tCase, 1) _ "'")
    }
}

/// <p>AC6: a compile or delete requires WRITE on the namespace's routines database beside the read
/// pairs, refused naming it before any route; a <code>DOCS</code> read does not require it.</p>
/// <p>Mutation (Rule 19): answer <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> from
/// <method>OcuPilot.Port.AtelierPort.WritePairs</method> -- the two write legs go red.</p>
Method TestAWriteRequiresTheRoutinesDatabasesWritePair()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_PROBEHOME", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_PROBEGLOBALS", "READ")
    For tType = "COMPILE", "DELETE" {
        Set tSC = ..Act(tType, "Probe.Alpha.cls", $Select(tType = "COMPILE": "101", 1: ""), .tResult, .tHttp, .tFault)
        Set tPair = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE %DB_PROBEHOME:WRITE", tType _ ": refused naming the routines database's WRITE pair")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Set tSC = ..Act("DOCS", "Probe.Alpha.cls", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a set read needs the read pairs alone")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_PROBEHOME", "WRITE")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Compile", "200 OK", ..#COMPILEANSWER)
    Set tSC = ..Act("COMPILE", "Probe.Alpha.cls", "101", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "and holding the WRITE pair compiles")
    Do $$$AssertEquals(..Methods(), "GetDocNames,GetDocNames,Compile", "no work route is ever called")
}

/// <p>A set of no document, of more than one hundred, or naming a document of the other kind, and a
/// compile value spelled any way but true or false, are refused 400 <code>PORT.VALIDATION</code>
/// before any route. A namespace left out is the request's own scope.</p>
Method TestTheSetAndTheFlagsAreCheckedBeforeAnyRoute()
{
    Do ..ArmVendor()
    Set tMany = ""
    For tI = 1:1:101 Set tMany = tMany _ $Select(tI = 1: "", 1: ",") _ "Probe.N" _ tI _ ".cls"
    For tCase = $ListBuild("DOCS", "", "", ##class(OcuPilot.Port.AtelierPort).#REASONNAMES), $ListBuild("DOCS", ",,", "", ##class(OcuPilot.Port.AtelierPort).#REASONNAMES), $ListBuild("DELETE", tMany, "", ##class(OcuPilot.Port.AtelierPort).#REASONNAMES), $ListBuild("COMPILE", "Probe.Alpha.mac", "101", ##class(OcuPilot.Port.AtelierPort).#REASONNAMES), $ListBuild("COMPILE", "Probe.Alpha.cls", "1x1", ##class(OcuPilot.Port.AtelierPort).#REASONFLAGS), $ListBuild("COMPILE", "Probe.Alpha.cls", "", ##class(OcuPilot.Port.AtelierPort).#REASONFLAGS) {
        Set tSC = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ $List(tCase, 4), $List(tCase, 1) _ " of '" _ $Extract($List(tCase, 2), 1, 40) _ "' with '" _ $List(tCase, 3) _ "'")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "no route was called")
    Set tMax = ""
    For tI = 1:1:100 Set tMax = tMax _ $Select(tI = 1: "", 1: ",") _ "Probe.N" _ tI _ ".cls"
    Set tSC = ..Act("DOCS", tMax, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "one hundred documents read")
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Kill tQuery
    Set tQuery("names") = "Probe.Alpha.cls"
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "DOCS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.Namespace, 1: "") _ " " _ tHttp, $Namespace _ " 200", "a set read with no namespace reads the request's scope")
}

/// <p>AD-61 rule 6: a read the vendor refuses with a privilege soft error under 200 (#5838, #5883,
/// #302) is 403 <code>PORT.ACCESSDENIED</code>, with the vendor's text logged.</p>
Method TestAPrivilegeSoftErrorIsAccessDenied()
{
    For tCode = 5838, 5883, 302 {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ..ArmVendor()
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDocNames", "200 OK", "{""status"":{""errors"":[{""error"":""ERROR #" _ tCode _ ": refused"",""code"":" _ tCode _ "}],""summary"":""x""},""console"":[],""result"":{""content"":[]}}")
        Set tSC = ..Act("DOCS", "Probe.Alpha.cls", "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 PORT.ACCESSDENIED", "#" _ tCode _ " is the vendor's privilege refusal")
    }
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "#302", "with its text in the log")
}

/// <p>AD-59: each write renders its script, an ObjectScript step in the proposal's namespace, the
/// compile's flags built as the write builds them and every value a string literal; a read has no
/// script form.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Port.AtelierPort.SnippetForm</method>
/// for the delete -- the delete leg goes red.</p>
Method TestEachWriteRendersItsScript()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Classes", "COMPILE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Routines", "DELETE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Classes", "DOCS") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Class", "LIST"), "objectscript|objectscript||", "the two writes have a script form and the reads none")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("names") = "Probe.Alpha.cls,Probe.Beta.cls"
    Set tQuery("KeepSource") = 1
    Set tQuery("CompileDependents") = 0
    Set tQuery("SkipUpToDate") = 1
    Set tSteps = $ClassMethod(tPort, "Snippet", "Classes", "COMPILE", .tQuery)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).kind, "1 objectscript", "the compile is one ObjectScript step")
    Do $$$AssertEquals(tSteps.%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tSC = $System.OBJ.CompileList(""Probe.Alpha.cls,Probe.Beta.cls"", ""cuk"")" _ $Char(10) _ " Do $System.Status.DisplayError(tSC)", "it compiles the set with the flags the write sends")
    Set tSteps = $ClassMethod(tPort, "Snippet", "Routines", "DELETE", .tQuery)
    Do $$$AssertTrue((tSteps.%Size() = 1) && (tSteps.%Get(0).text [ "##class(%RoutineMgr).Delete(") && (tSteps.%Get(0).text [ """Probe.Alpha.cls,Probe.Beta.cls"""), "the delete deletes each document of the set")
    Set tQuery("names") = "A.cls"",$ZF(-1,""x"")"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Classes", "DELETE", .tQuery)
    Do $$$AssertTrue(tSteps.%Get(0).text [ """A.cls"""",$ZF(-1,""""x"""")""", "a value is rendered as a string literal")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "DOCS", .tQuery).%Size(), 0, "a read renders no step")
}

}
