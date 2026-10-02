/// <p>The source code API port in process (AD-61): the gate evaluated before any vendor call and
/// naming the failed pair, the endpoint and version checks, the list filters applied to the parsed
/// rows before the cap, the <code>docnames</code> <code>filter</code> parameter never seeded, the
/// name pattern's matching, and the read executor's atelier branch with its criterion defaults.
/// The document endpoints and the fault mapping are <class>OcuPilot.Test.AtelierPortDocument</class>'s.</p>
/// <p>The vendor is <class>OcuPilot.Test.AtelierPortFixture</class>'s canned routes; denials are
/// driven through <class>OcuPilot.Test.ScreenGate</class>, because <code>%UnitTest</code> runs as an
/// account holding <code>%All</code>. The real gate against real principals is
/// <class>OcuPilot.Test.AtelierPortDenial</class>'s. Two legs read the live instance's own routes in
/// the install namespace and in <code>USER</code>, and one reads the vendor's internal
/// <code>findmappings^%R</code> for <code>HSCUSTOM</code>, the answer the gate's mapped databases
/// come from; they write nothing of OcuPilot's.</p>
Class OcuPilot.Test.AtelierPort Extends %UnitTest.TestCase
{

/// <p>The port under test.</p>
Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

/// <p>A <code>GetNamespace</code> answer whose routines database is <code>HOME</code>.</p>
Parameter NAMESPACEANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":{""name"":""HSCUSTOM"",""db"":[{""name"":""HOME"",""default"":true},{""name"":""LIBDB"",""default"":false}]}}}";

/// <p>A <code>docnames/CLS</code> answer covering every filter.</p>
Parameter CLASSESANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Alpha.One.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""Alpha.Two.cls"",""ts"":""2026-03-10 10:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""alpha.Lower.cls"",""ts"":""2026-02-01 00:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""%Sys.Thing.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""LIBDB"",""gen"":false},{""name"":""Beta.Mapped.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""LIBDB"",""gen"":false},{""name"":""Alpha.Gen.cls"",""ts"":""2026-01-10 10:00:00.000"",""db"":""HOME"",""gen"":true}]}}";

/// <p>A <code>docnames/RTN</code> answer of every routine type.</p>
Parameter ROUTINESANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Foo.Bar.mac"",""ts"":""2026-01-01 00:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""Foo.Bar.int"",""ts"":""2026-01-01 00:00:00.000"",""db"":""HOME"",""gen"":true},{""name"":""Foo.Inc.inc"",""ts"":""2026-01-01 00:00:00.000"",""db"":""HOME"",""gen"":false},{""name"":""Other.mac"",""ts"":""2026-01-01 00:00:00.000"",""db"":""HOME"",""gen"":false}]}}";

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

/// <p>Arm the canned routes, the gate holding every pair, and the namespace's databases.</p>
ClassMethod ArmVendor()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("%DB_PROBEHOME", "%DB_PROBEGLOBALS", "%DB_PROBELIB")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetNamespace", "200 OK", ..#NAMESPACEANSWER)
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDocNames", "200 OK", ..#CLASSESANSWER)
}

/// <p>The names of a list endpoint's rows, comma-separated, or the fault's code.</p>
ClassMethod Names(pEndpoint As %String, ByRef pQuery, Output pHttp As %Integer) As %String
{
    If '$Data(pQuery("namespace")) Set pQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke(pEndpoint, "LIST", .pQuery, "", .tRows, .pHttp, .tFault, .tDocument)
    If $$$ISERR(tSC) Quit $Select($IsObject(tFault): tFault.code, 1: "?")
    Set tNames = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name
    }
    Quit tNames
}

/// <p>The gate runs first, in the caller's process, and a refusal names the first failed pair:
/// <code>%Development:USE</code>, then READ on the routines database, the globals database and a
/// mapped code database in turn. No route is called on any refusal, and the answer is never an
/// empty list.</p>
/// <p>Mutation: drop the routines database's pair from
/// <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> -&gt; the second leg goes red.</p>
Method TestTheGateRunsFirstAndNamesTheFailedPair()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tLeg = $ListBuild("", "%Development:USE"), $ListBuild("%Development", "%DB_PROBEHOME:READ"), $ListBuild("%DB_PROBEHOME", "%DB_PROBEGLOBALS:READ"), $ListBuild("%DB_PROBEGLOBALS", "%DB_PROBELIB:READ") {
        Set tHold = $List(tLeg, 1)
        If tHold = "%Development" Do ##class(OcuPilot.Test.ScreenGate).Hold(tHold, "USE")
        If (tHold '= "") && (tHold '= "%Development") Do ##class(OcuPilot.Test.ScreenGate).Hold(tHold, "READ")
        Kill tQuery
        Set tQuery("namespace") = $Namespace
        Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
        Set tPair = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tLeg, 2), "a caller short of " _ $List(tLeg, 2) _ " is refused naming it")
        Do $$$AssertEquals(tRows, "", "with no rows")
        Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "and no route called")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_PROBELIB", "READ")
    Kill tQuery
    Do $$$AssertEquals(..Names("Classes", .tQuery, .tHttp), "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,%Sys.Thing.cls,Beta.Mapped.cls,Alpha.Gen.cls", "holding every pair reads the rows")
    Do $$$AssertEquals(tHttp, 200, "with 200")
}

/// <p>A namespace whose code databases' resources cannot be resolved, and a malformed namespace,
/// are refused 400 <code>PORT.VALIDATION</code> before any route; an endpoint the port does not
/// serve is 501.</p>
Method TestNamespaceAndEndpointRefusals()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("", "", "")
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code _ " " _ tFault.reason, "400 PORT.VALIDATION " _ ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, "an unresolvable namespace is refused")
    Do ..ArmVendor()
    Kill tQuery
    Set tQuery("namespace") = "no such;ns"
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "400 PORT.VALIDATION", "a malformed namespace is refused")
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Modified", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "501 PORT.NOTIMPLEMENTED", "an endpoint the port does not serve is 501")
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "PUT", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "501 PORT.NOTIMPLEMENTED", "and so is a request type it does not serve")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "no route was called")
}

/// <p>The version seam: an instance whose highest version is below an endpoint's minimum is refused
/// 501 naming both versions before any route; a higher one is called at the pinned version.</p>
/// <p>Mutation: make <method>OcuPilot.Port.AtelierPort.MinVersion</method> answer 1 for every
/// endpoint -&gt; the document read's refusal goes red.</p>
Method TestTheVersionSeam()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(1)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("name") = "Alpha.One.cls"
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Class", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tWanted = $Replace($Replace(##class(OcuPilot.Port.AtelierPort).#REASONVERSION, "{highest}", 1), "{needed}", 2)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "501 PORT.NOTIMPLEMENTED " _ tWanted, "a document read on a version 1 instance is refused naming both versions")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Kill tQuery
    Do $$$AssertEquals(..Names("Classes", .tQuery, .tHttp), "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,%Sys.Thing.cls,Beta.Mapped.cls,Alpha.Gen.cls", "a list, which needs version 1, reads there")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).ImplVersion(), 1, "at version 1")
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(11)
    Kill tQuery
    Do ..Names("Classes", .tQuery, .tHttp)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).ImplVersion(), 8, "an instance above the pin is called at version 8")
    Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).HighestVersion(), 8, "the live instance's URL map forwards to version 8")
}

/// <p>Every list filter is applied to the parsed rows before the cap, and the vendor's own
/// <code>filter</code> parameter is never sent: the pattern (case-sensitive, a comma union, a
/// leading <code>'</code> excluding), <code>system</code>, <code>mapped</code> (which reads the
/// namespace's routines database from <code>GetNamespace</code>), <code>from</code> and
/// <code>to</code>; <code>generated</code> travels as the vendor's <code>generated=1</code>.</p>
/// <p>Mutation: seed <code>filter</code> into the <code>GetDocNames</code> call -&gt; the
/// never-seeded assertion goes red.</p>
Method TestListFiltersApplyBeforeTheCapAndFilterIsNeverSent()
{
    Do ..ArmVendor()
    For tCase = $ListBuild("pattern", "Alpha.*", "Alpha.One.cls,Alpha.Two.cls,Alpha.Gen.cls"), $ListBuild("pattern", "Alpha.*,'Alpha.T*", "Alpha.One.cls,Alpha.Gen.cls"), $ListBuild("pattern", "'Alpha.*", "alpha.Lower.cls,%Sys.Thing.cls,Beta.Mapped.cls"), $ListBuild("pattern", "Beta.Mapped.cls,alpha.*", "alpha.Lower.cls,Beta.Mapped.cls"), $ListBuild("system", "no", "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,Beta.Mapped.cls,Alpha.Gen.cls"), $ListBuild("mapped", "no", "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,Alpha.Gen.cls"), $ListBuild("from", "2026-02-01 00:00:00", "Alpha.Two.cls,alpha.Lower.cls"), $ListBuild("to", "2026-01-31 23:59:59", "Alpha.One.cls,%Sys.Thing.cls,Beta.Mapped.cls,Alpha.Gen.cls") {
        Kill tQuery
        Set tQuery($List(tCase, 1)) = $List(tCase, 2)
        Do $$$AssertEquals(..Names("Classes", .tQuery, .tHttp), $List(tCase, 3), $List(tCase, 1) _ "=" _ $List(tCase, 2))
    }
    ; Four rows: the first four raw rows hold %Sys.Thing.cls, so a cap counted before the filter
    ; answers three.
    Kill tQuery
    Set tQuery("system") = "no"
    Set tQuery("maxRows") = 4
    Do $$$AssertEquals(..Names("Classes", .tQuery, .tHttp), "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,Beta.Mapped.cls", "the cap cuts after the filters")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmVendor()
    Kill tQuery
    Set tQuery("generated") = "yes"
    Set tQuery("pattern") = "*"
    Set tQuery("mapped") = "no"
    Do ..Names("Classes", .tQuery, .tHttp)
    Set tSeen = ""
    For tI = 1:1:##class(OcuPilot.Test.AtelierPortFixture).CallCount() {
        Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(tI)
        If tCall.method '= "GetDocNames" Continue
        Set tSeen = tCall.arg _ " typePassed=" _ tCall.typePassed _ " " _ tCall.params.%ToJSON() _ " in " _ tCall.current
    }
    Do $$$AssertEquals(tSeen, "CLS typePassed=0 {""generated"":1} in " _ $Namespace, "docnames is called with CLS and no type, generated=1, and never the filter parameter")
}

/// <p>A routine pattern piece with no routine type matches every type, and one with a type matches
/// that type alone.</p>
Method TestRoutinePatternsMatchByType()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDocNames", "200 OK", ..#ROUTINESANSWER)
    For tCase = $ListBuild("Foo.Bar", "Foo.Bar.mac,Foo.Bar.int"), $ListBuild("*.mac", "Foo.Bar.mac,Other.mac"), $ListBuild("Foo.*", "Foo.Bar.mac,Foo.Bar.int,Foo.Inc.inc"), $ListBuild("*.inc,Other", "Foo.Inc.inc,Other.mac"), $ListBuild("*", "Foo.Bar.mac,Foo.Bar.int,Foo.Inc.inc,Other.mac") {
        Kill tQuery
        Set tQuery("pattern") = $List(tCase, 1)
        Do $$$AssertEquals(..Names("Routines", .tQuery, .tHttp), $List(tCase, 2), "pattern " _ $List(tCase, 1))
    }
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(##class(OcuPilot.Test.AtelierPortFixture).CallCount())
    Do $$$AssertEquals(tCall.arg _ " " _ tCall.typePassed, "RTN 0", "docnames is called with RTN and no type")
}

/// <p>A malformed pattern or include choice is refused 400 <code>PORT.VALIDATION</code> before any
/// route.</p>
Method TestMalformedListArgumentsAreRefused()
{
    Do ..ArmVendor()
    For tCase = $ListBuild("pattern", "a;b"), $ListBuild("pattern", "a b"), $ListBuild("pattern", "a""b"), $ListBuild("pattern", "a,,b"), $ListBuild("system", "maybe"), $ListBuild("to", "2026-01-01"), $ListBuild("maxRows", "0") {
        Kill tQuery
        Set tQuery($List(tCase, 1)) = $List(tCase, 2)
        Do $$$AssertEquals(..Names("Classes", .tQuery, .tHttp) _ " " _ tHttp, "PORT.VALIDATION 400", $List(tCase, 1) _ "=" _ $List(tCase, 2) _ " is refused")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "with no route called")
}

/// <p>The pattern matcher: <code>*</code> is the one wildcard, the match is case-sensitive, and a
/// class is matched without its <code>.cls</code>.</p>
Method TestThePatternMatcher()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Do $$$AssertTrue($ClassMethod(tPort, "GlobMatches", "OcuPilot.Kernel.EntityId", "OcuPilot.Kernel.Entity*"), "a trailing star")
    Do $$$AssertTrue('$ClassMethod(tPort, "GlobMatches", "OcuPilot.Kernel.EntityId", "ocupilot.*"), "case-sensitive")
    Do $$$AssertTrue($ClassMethod(tPort, "GlobMatches", "abcabc", "a*c*c"), "several stars")
    Do $$$AssertTrue('$ClassMethod(tPort, "GlobMatches", "abc", "a*bc*bc"), "segments do not overlap")
    Do $$$AssertTrue('$ClassMethod(tPort, "GlobMatches", "a?c", "abc"), "? is a character, not a wildcard")
    Do $$$AssertTrue($ClassMethod(tPort, "PatternMatches", "OcuPilot.Kernel.EntityId.cls", "CLS", "OcuPilot.Kernel.Entity*.cls"), "a class piece's own .cls is ignored")
    Do $$$AssertTrue($ClassMethod(tPort, "PatternMatches", "X.cls", "CLS", "'Y*"), "a pattern of exclusions alone keeps the rest")
}

/// <p>The read executor's atelier branch: the route's scope is the port's namespace, an omitted
/// criterion takes its declared default and <code>criteria</code> reports it, one sent empty stays
/// unset, and a document read carries <code>document</code> beside the rows.</p>
/// <p>Mutation: drop the <code>default</code> line from
/// <method>OcuPilot.Screen.Read.SeedCriteria</method> -&gt; the defaults assertion goes red.</p>
Method TestTheReadExecutorAppliesDefaultsAndCarriesTheDocument()
{
    Do ..ArmVendor()
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Test.AtelierReadFixture).Execute("OcuPilot.Screen.Descriptor.ExplorerClassList", "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the Classes read answers")
    Do $$$AssertEquals(tResult.criteria.%ToJSON(), "{""pattern"":""*"",""system"":""no"",""generated"":""no"",""mapped"":""yes"",""from"":"""",""to"":""""}", "an omitted criterion takes its declared default")
    Set tNames = ""
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name
    }
    Do $$$AssertEquals(tNames, "Alpha.One.cls,Alpha.Two.cls,alpha.Lower.cls,Beta.Mapped.cls,Alpha.Gen.cls", "and the port applied them")
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(##class(OcuPilot.Test.AtelierPortFixture).CallCount())
    Do $$$AssertEquals(tCall.namespace, $Namespace, "the route's scope is the port's namespace")
    Do $$$AssertEquals(tCall.method _ " " _ tCall.params.%ToJSON(), "GetDocNames {}", "generated no sends no generated parameter")
    Do $$$AssertTrue('tResult.%IsDefined("document"), "a list read carries no document")

    Kill tCriteria
    Set tCriteria("system") = ""
    Set tCriteria("pattern") = ""
    Set tSC = ##class(OcuPilot.Test.AtelierReadFixture).Execute("OcuPilot.Screen.Descriptor.ExplorerClassList", "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tResult.criteria.system _ "|" _ tResult.criteria.pattern _ "|" _ tResult.rows.%Size(), "||6", "one sent empty stays unset and filters nothing")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Index", "200 OK", ##class(OcuPilot.Test.AtelierPortDocument).IndexAnswer("Alpha.One.cls", "[""Alpha.One.1.int""]"))
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", ##class(OcuPilot.Test.AtelierPortDocument).DocAnswer("Alpha.One.cls"))
    Kill tCriteria
    Set tCriteria("name") = "Alpha.One.cls"
    Set tSC = ##class(OcuPilot.Test.AtelierReadFixture).Execute("OcuPilot.Screen.Descriptor.ExplorerClassDocument", "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the Class read answers")
    Do $$$AssertEquals(tResult.criteria.form, "udl", "form opens on its default")
    Do $$$AssertTrue($IsObject(tResult.%Get("document")) && (tResult.document.name = "Alpha.One.cls"), "and the document rides beside the rows")
}

/// <p>Against the live instance: the port reads <code>USER</code>, whose code the install namespace
/// does not hold, and leaves the caller in the namespace it was called from; a canned route there
/// cannot be reached, and the fault leaves it restored too, with no capture open.</p>
/// <p>Mutation: delete the namespace restore from <method>OcuPilot.Port.AtelierPort.Route</method>'s
/// <code>Catch</code> -&gt; the fault leg reads <code>USER</code>.</p>
Method TestTheNamespaceIsRestoredAfterSuccessAndAfterAFault()
{
    Set tOrigin = $Namespace
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("pattern") = "%Library.String"
    Set tQuery("maxRows") = 5
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tAfterSuccess = $Namespace
    If $Namespace '= tOrigin Set $Namespace = tOrigin
    Do $$$AssertStatusOK(tSC, "the live port reads USER")
    Do $$$AssertEquals($Select($IsObject(tRows) && (tRows.%Size() = 1): tRows.%Get(0).Name, 1: ""), "%Library.String.cls", "its one matching row")
    Do $$$AssertEquals(tAfterSuccess, tOrigin, "and restores the caller's namespace after success")
    Do $$$AssertEquals($Data(^||%capture) _ " " _ $ZUtil(82, 12), "0 0", "with no capture open")

    Do ..ArmVendor()
    Set tAfter = ""
    Try {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Set tAfter = $Namespace
    } Catch ex {
        Set tAfter = $Namespace _ " after " _ ex.DisplayString()
    }
    If $Namespace '= tOrigin Set $Namespace = tOrigin
    Do $$$AssertEquals(tAfter, tOrigin, "a route that cannot run in USER leaves the caller where it was")
    Do $$$AssertEquals(tHttp, 500, "and answers the internal fault")
    Do $$$AssertEquals($Data(^||%capture) _ " " _ $ZUtil(82, 12), "0 0", "with no capture open")
}

/// <p>The vendor's internal <code>findmappings^%R</code>, called for <code>HSCUSTOM</code> as
/// <method>OcuPilot.Port.AtelierPort.DatabaseResources</method> calls it: its second argument
/// answers one subscript per database the namespace maps code from, each an implied namespace
/// (<code>^^directory</code>, or <code>^system^directory</code> for a remote one) that
/// <method>%SYS.Namespace.GetAllNSInfo</method> resolves to a resource, holding a <code>%List</code>
/// of two-element ranges. HSLIB's directory is among them and resolves to HSLIB's resource, and the
/// system database appears as <code>^^</code> and the manager directory, the form the port's
/// exclusion compares. The port's own reading names HSLIB's resource and leaves the system
/// database's out.</p>
/// <p>Mutation: make the port read <code>findmappings^%R</code>'s third argument, the namespace's
/// own directory, in place of its second -&gt; HSLIB's resource leaves the mapped set.</p>
Method TestFindMappingsAnswersTheShapeThePortReads()
{
    Set tNamespace = "HSCUSTOM"
    Set tHslib = ""
    Set tHslibResource = ""
    Set tSystemResource = ""
    Set tOrigin = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Kill tProperties
        If $$$ISOK(##class(Config.Databases).Get("HSLIB", .tProperties)) Set tHslib = "^^" _ ##class(%File).NormalizeDirectory(tProperties("Directory"))
        Set tDatabase = ##class(SYS.Database).%OpenId($Extract(tHslib, 3, *))
        If $IsObject(tDatabase) Set tHslibResource = tDatabase.ResourceName
        Set tDatabase = ##class(SYS.Database).%OpenId($System.Util.ManagerDirectory())
        If $IsObject(tDatabase) Set tSystemResource = tDatabase.ResourceName
        Set tDatabase = ""
        Set $Namespace = tOrigin
    } Catch {
        Set $Namespace = tOrigin
    }
    Do $$$AssertTrue((tHslib '= "") && (tHslibResource '= "") && (tSystemResource '= ""), "the instance names HSLIB's directory and resource and the system database's resource")

    Kill tDirectories
    Do findmappings^%R(tNamespace, .tDirectories)
    Set tCount = 0
    Set tMisshapen = ""
    Set tDirectory = ""
    For {
        Set tDirectory = $Order(tDirectories(tDirectory), 1, tRanges)
        If tDirectory = "" Quit
        Set tCount = tCount + 1
        Set tWell = ($Extract(tDirectory) = "^") && ($Length(tDirectory, "^") = 3) && ($Piece(tDirectory, "^", 3) '= "") && $ListValid(tRanges) && ($ListLength(tRanges) > 0)
        If tWell {
            For tI = 1:1:$ListLength(tRanges) {
                Set tRange = $ListGet(tRanges, tI)
                If '($ListValid(tRange) && ($ListLength(tRange) = 2)) Set tWell = 0
            }
        }
        Kill tInfo
        Do ##class(%SYS.Namespace).GetAllNSInfo(tDirectory, .tInfo, 1)
        If $Get(tInfo("RoutineDB", "Resource")) = "" Set tWell = 0
        If 'tWell Set tMisshapen = tMisshapen _ $Select(tMisshapen = "": "", 1: ",") _ tDirectory
    }
    Do $$$AssertTrue(tCount > 0, "findmappings^%R answers at least one mapped code database for " _ tNamespace)
    Do $$$AssertEquals(tMisshapen, "", "every subscript is an implied namespace that resolves to a resource and holds two-element ranges")
    Do $$$AssertTrue($Select(tHslib = "": 0, 1: $Data(tDirectories(tHslib)) > 0), "HSLIB's directory " _ tHslib _ " is among the mapped code databases")
    Kill tInfo
    If tHslib '= "" Do ##class(%SYS.Namespace).GetAllNSInfo(tHslib, .tInfo, 1)
    Do $$$AssertEquals($Get(tInfo("RoutineDB", "Resource")), tHslibResource, "and resolves to HSLIB's own resource")
    Do $$$AssertTrue($Data(tDirectories("^^" _ $System.Util.ManagerDirectory())) > 0, "the system database appears in the form the port's exclusion compares")

    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    Do $$$AssertTrue(tResolved, "the port resolves every code database " _ tNamespace _ " reads")
    Do $$$AssertTrue((tHslibResource '= "") && $ListFind(tMapped, tHslibResource), "the port's mapped set names " _ tHslibResource)
    Do $$$AssertTrue((tSystemResource '= "") && '$ListFind(tMapped, tSystemResource), "and leaves the system database's " _ tSystemResource _ " out")
}

}
