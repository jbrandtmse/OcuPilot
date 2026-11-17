/// <p>Pins every refusal of Story 21.14's locale writes as <class>OcuPilot.Area.OsMgmt.LocaleRules</class> judges it (AC3, AC4; AD-21, AD-29, AD-51, AD-55,
/// AD-59): an install the vendor's own check refuses is 409 <code>LOCALE.NOTINSTALLABLE</code>, a delete of a locale InterSystems ships is
/// <code>LOCALE.SYSTEM</code> and of the current locale <code>LOCALE.CURRENT</code>, and a locale the list does not hold is 404
/// <code>LOCALE.NOTFOUND</code>; each is asked at the port, at the agent's mint and at the screen's own action route, always before the vendor's install or
/// delete, which <class>OcuPilot.Test.LocaleGateSeam</class> records instead of making. The allowed paths send exactly one call with the locale's name, an
/// install names the collation of IRISTEMP before and after, a vendor refusal is logged and answered 500, and the copy-out scripts name the locale as a literal.</p>
/// <p><b>Live-safe.</b> No locale is installed or deleted: a delete of a locale that exists is only ever asked through the seam, because the vendor itself refuses
/// nothing. <b>What it needs from the environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.LocaleRules Extends %UnitTest.TestCase
{

Parameter RULES = "OcuPilot.Area.OsMgmt.LocaleRules";

Parameter ERROR = "OcuPilot.Api.LocaleError";

Parameter SEAM = "OcuPilot.Test.LocaleGateSeam";

Parameter INSTALLTOOL = "OcuPilot.Test.LocaleInstallSeam";

Parameter DELETETOOL = "OcuPilot.Test.LocaleDeleteSeam";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter SCREEN = "osmgmt.locales";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

/// <p>Hold every pair the port's two sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The code of the port's refusal of <var>pType</var> for <var>pName</var> through the seam, with the status: <code>http|code</code>.</p>
ClassMethod Refusal(pType As %String, pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", pType, .tQuery, "", .tOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> through the action fixture, answering <code>status|code</code>.</p>
ClassMethod Act(pAction As %String, pId As %String) As %String
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set tAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of <var>pToolClass</var> for <var>pName</var>, answering <code>minted</code> or the refusal sentence.</p>
ClassMethod Minted(pToolClass As %String, pName As %String) As %String
{
    Set tSC = $ClassMethod(..#RULES, "WriteProblem", pToolClass, pName, {}, .tProblem)
    Quit $Select($$$ISERR(tSC): "error", 1: tProblem)
}

/// <p><b>AC3, AC4.</b> The rules' own matrix: an install is refused exactly when the vendor's check refuses it; a delete is refused for a locale whose name does
/// not start with <code>y</code> first, then for the current locale, and holds for a custom locale that is not current; an unknown write type is judged by
/// nothing.</p>
/// <p>Mutation (Rule 19): <code>Code</code> judges the current locale before the system one -> the system-and-current row goes red.</p>
Method TestTheRulesMatrix()
{
    Set tRules = ..#RULES
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "INSTALL", {"Name": "x", "Custom": false, "Current": false}, 0), "LOCALE.NOTINSTALLABLE", "an install the vendor refuses")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "INSTALL", {"Name": "x", "Custom": false, "Current": true}, 1), "", "an install the vendor admits, the current locale included")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "DELETE", {"Name": "enuw", "Custom": false, "Current": false}), "LOCALE.SYSTEM", "a delete of a locale InterSystems ships")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "DELETE", {"Name": "enuw", "Custom": false, "Current": true}), "LOCALE.SYSTEM", "and of the current one, judged as the system locale first")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "DELETE", {"Name": "yzzw", "Custom": true, "Current": true}), "LOCALE.CURRENT", "a delete of the current custom locale")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "DELETE", {"Name": "yzzw", "Custom": true, "Current": false}), "", "a delete of a custom locale that is not current holds")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "DELETE", {"Name": "yzzw"}), "LOCALE.SYSTEM", "a row that says nothing is not custom")
    Do $$$AssertEquals($ClassMethod(tRules, "Code", "OTHER", {}), "", "another write type is judged by nothing")
    Set tError = ..#ERROR
    Do $$$AssertEquals($ClassMethod(tError, "HttpStatusFor", "LOCALE.NOTFOUND") _ $ClassMethod(tError, "HttpStatusFor", "LOCALE.NOTINSTALLABLE") _ $ClassMethod(tError, "HttpStatusFor", "LOCALE.SYSTEM") _ $ClassMethod(tError, "HttpStatusFor", "LOCALE.CURRENT") _ "|" _ $ClassMethod(tError, "HttpStatusFor", "LOCALE.INSTALL") _ $ClassMethod(tError, "HttpStatusFor", "LOCALE.DELETE"), "404409409409|00", "the statuses, a consequence code being no refusal")
    Do $$$AssertEquals($ClassMethod(tError, "ReasonFor", "LOCALE.NOTINSTALLABLE") _ "|" _ $ClassMethod(tError, "ReasonFor", "LOCALE.SYSTEM") _ "|" _ $ClassMethod(tError, "ReasonFor", "LOCALE.CURRENT"), "This locale cannot be installed on this instance.|A locale InterSystems ships cannot be deleted; only a custom locale, whose name starts with y, can.|The current locale cannot be deleted.", "the three published refusal sentences")
    Do $$$AssertEquals($ClassMethod(tError, "SlugFor", "LOCALE.NOTFOUND") _ "|" _ $ClassMethod(tError, "SlugFor", "LOCALE.SYSTEM"), ##class(OcuPilot.Api.Error).#NOTFOUND _ "|" _ ##class(OcuPilot.Api.Error).#CONFLICT, "and the slugs")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode("LOCALE.SYSTEM") _ "|" _ ##class(OcuPilot.Api.Error).ReasonForViolation("LOCALE.CURRENT"), $ClassMethod(tError, "ReasonFor", "LOCALE.SYSTEM") _ "|" _ $ClassMethod(tError, "ReasonFor", "LOCALE.CURRENT"), "the kernel's resolvers answer the LOCALE codes")
}

/// <p><b>AC3.</b> At the port an install of a locale the vendor refuses is 409 <code>LOCALE.NOTINSTALLABLE</code> and one the list does not hold is 404, each with
/// the install seam never called; an install the vendor admits sends one call naming the locale and answers the collation of IRISTEMP before and after.</p>
/// <p>Mutation (Rule 19): <code>Install</code> asks the rules without the installable answer -> the refusal row goes red; <code>SendInstall</code> is called
/// before the rules -> the calls assertion goes red.</p>
Method TestAnInstallIsRefusedBeforeTheVendorAndAnswersTheCollationBeforeAndAfter()
{
    Set tNames = ##class(OcuPilot.Test.LocaleRead).VendorList(.tCurrent)
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "Feed", 1, 0, "", $ListBuild("a warning"))
    Do $$$AssertEquals(..Refusal("INSTALL", tCurrent) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|LOCALE.NOTINSTALLABLE|", "an install the vendor's check refuses is 409 and calls nothing")
    Do $$$AssertEquals(..Refusal("INSTALL", "NoSuchLocale") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "404|LOCALE.NOTFOUND|", "an unlisted name is 404 and calls nothing")
    Do $$$AssertEquals(..Refusal("INSTALL", $ZConvert(tCurrent, "U")) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "404|LOCALE.NOTFOUND|", "a name in another letter case is not the listed locale")
    Do $ClassMethod(..#SEAM, "Feed", 1, 1, "", "")
    Do $ClassMethod(..#SEAM, "Collations", "IRIS standard", "German3")
    Kill tQuery
    Set tQuery("name") = tCurrent
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "INSTALL", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Calls") _ "|" _ tOut.%Get("Name") _ "|" _ tOut.%Get("TempCollationBefore") _ "|" _ tOut.%Get("TempCollationAfter"), "200|INSTALL|" _ tCurrent _ "|" _ tCurrent _ "|IRIS standard|German3", "an admitted install makes one call and names IRISTEMP's collation before and after")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "INSTALL", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor refusal is logged and answered 500 INTERNAL")
}

/// <p><b>AC4.</b> At the port a delete of a locale InterSystems ships is 409 <code>LOCALE.SYSTEM</code> and of the current locale <code>LOCALE.CURRENT</code>, and a
/// name the list does not hold is 404, each with the delete seam never called; a custom locale that is not current is deleted by one call naming it. The
/// vendor refuses none of these, so the rules are the only guard.</p>
/// <p>Mutation (Rule 19): the <code>y</code> check dropped from <code>Code</code> -> the system rows go red.</p>
Method TestADeleteIsRefusedBeforeTheVendorForASystemAndTheCurrentLocale()
{
    Set tNames = ##class(OcuPilot.Test.LocaleRead).VendorList(.tCurrent)
    Do $$$AssertTrue(($Extract(tCurrent) '= "y") && ($Extract($Piece(tNames, ",", 1)) '= "y"), "precondition: the current locale and the first listed one are locales InterSystems ships: " _ tCurrent _ ", " _ $Piece(tNames, ",", 1))
    Do ..HoldAll()
    Do $$$AssertEquals(..Refusal("DELETE", tCurrent) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|LOCALE.SYSTEM|", "the current system locale is a locale InterSystems ships")
    Do $$$AssertEquals(..Refusal("DELETE", $Piece(tNames, ",", 1)) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|LOCALE.SYSTEM|", "so is every other listed one")
    Do $$$AssertEquals(..Refusal("DELETE", "NoSuchLocale") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "404|LOCALE.NOTFOUND|", "an unlisted name is 404")
    Do $ClassMethod(..#SEAM, "HoldLocale", "yzzw", "probe", 1, 1)
    Do $$$AssertEquals(..Refusal("DELETE", "yzzw") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|LOCALE.CURRENT|", "a custom locale that is current is refused as current")
    Do $ClassMethod(..#SEAM, "HoldLocale", "yzzw", "probe", 0, 1)
    Kill tQuery
    Set tQuery("name") = "yzzw"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "DELETE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Calls") _ "|" _ tOut.%Get("Name"), "200|DELETE|yzzw|yzzw", "a custom locale that is not current is deleted by one call naming it")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "DELETE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor refusal is logged and answered 500 INTERNAL")
}

/// <p><b>AC3, AC4 (AD-55).</b> The agent's mint asks the same rules before anything is stored: a delete of a locale InterSystships or of the current locale is
/// refused in the published sentence, an unlisted name in the port's 404 sentence, and an install the vendor's check refuses in its own sentence; the ones the
/// rules admit mint.</p>
/// <p>Mutation (Rule 19): <code>WriteProblem</code> never reads the installable answer -> the install row goes red.</p>
Method TestTheMintAsksTheSameRules()
{
    Set tNames = ##class(OcuPilot.Test.LocaleRead).VendorList(.tCurrent)
    Do $$$AssertTrue(($Extract(tCurrent) '= "y") && ($Extract($Piece(tNames, ",", 1)) '= "y"), "precondition: the current locale and the first listed one are locales InterSystems ships: " _ tCurrent _ ", " _ $Piece(tNames, ",", 1))
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "Feed", 1, 0, "", "")
    Do $$$AssertEquals(..Minted(..#INSTALLTOOL, tCurrent), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.NOTINSTALLABLE"), "an install the vendor refuses is refused at the mint")
    Do $ClassMethod(..#SEAM, "Feed", 1, 1, "", "")
    Do $$$AssertEquals(..Minted(..#INSTALLTOOL, tCurrent), "", "one it admits mints")
    Do $$$AssertEquals(..Minted(..#INSTALLTOOL, "NoSuchLocale"), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.NOTFOUND"), "an unlisted name is refused in the port's sentence")
    Do $$$AssertEquals(..Minted(..#DELETETOOL, tCurrent), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.SYSTEM"), "a delete of a system locale is refused")
    Do $ClassMethod(..#SEAM, "HoldLocale", "yzzw", "probe", 1, 1)
    Do $$$AssertEquals(..Minted(..#DELETETOOL, "yzzw"), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.CURRENT"), "a delete of the current custom locale is refused")
    Do $ClassMethod(..#SEAM, "HoldLocale", "yzzw", "probe", 0, 1)
    Do $$$AssertEquals(..Minted(..#DELETETOOL, "yzzw"), "", "a custom locale that is not current mints")
    Do $$$AssertEquals($Select($ClassMethod("OcuPilot.Screen.Tool.LocaleDelete", "ArgumentProblem", tCurrent, {}, .tProblem) = 1: tProblem, 1: "error"), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.SYSTEM"), "the shipped delete tool's mint refuses the current system locale through the real port")
    Do $$$AssertEquals($Select($ClassMethod("OcuPilot.Screen.Tool.LocaleInstall", "ArgumentProblem", "NoSuchLocale", {}, .tProblem2) = 1: tProblem2, 1: "error"), ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.NOTFOUND"), "and the shipped install tool's mint refuses an unlisted name")
}

/// <p><b>AC3, AC4.</b> The screen's own action route asks the shipped port before any vendor call: an install or a delete of an unlisted name is 404
/// <code>LOCALE.NOTFOUND</code>. A delete of a locale that exists is the case the vendor itself would carry out, so the screen's refusal of the current
/// system locale is asked in <class>OcuPilot.Test.LocaleWrite</class> (armed) and nowhere live.</p>
/// <p>Mutation (Rule 19): <code>LocaleDelete</code> declares no screen action -> every row goes red.</p>
Method TestTheScreensActionRouteAsksTheSameRules()
{
    Set tNames = ##class(OcuPilot.Test.LocaleRead).VendorList(.tCurrent)
    Do $$$AssertEquals(..Act("delete", "NoSuchLocale"), "404|LOCALE.NOTFOUND", "its delete of an unlisted name is 404")
    Do $$$AssertEquals(..Act("install", "NoSuchLocale"), "404|LOCALE.NOTFOUND", "and so is its install")
    Set tAfter = ##class(OcuPilot.Test.LocaleRead).VendorList(.tCurrentAfter)
    Do $$$AssertEquals(tAfter _ "|" _ tCurrentAfter, tNames _ "|" _ tCurrent, "no locale was deleted and the current one is as it was")
}

/// <p><b>AD-59.</b> The copy-out script of an install or a delete is the vendor's call with the locale named as a string literal, so a hostile name renders
/// quoted and never as code; a read renders none.</p>
/// <p>Mutation (Rule 19): <code>Snippet</code> concatenates the name unquoted -> the literal assertions go red.</p>
Method TestTheCopyOutScriptsNameTheLocaleAsALiteral()
{
    Set tHead = " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tSC = ##class(Config.NLS.Locales)."
    Kill tQuery
    Set tQuery("name") = "yzzw"
    Set tInstall = $ClassMethod(..#SEAM, "Snippet", "Locales", "INSTALL", .tQuery)
    Set tDelete = $ClassMethod(..#SEAM, "Snippet", "Locales", "DELETE", .tQuery)
    Do $$$AssertEquals($Select(tInstall.%Size() = 1: tInstall.%Get(0).%Get("text"), 1: ""), tHead _ "Install(""yzzw"")", "the install script calls the vendor's Install with the name as a literal")
    Do $$$AssertEquals($Select(tDelete.%Size() = 1: tDelete.%Get(0).%Get("text"), 1: ""), tHead _ "Delete(""yzzw"")", "the delete script calls the vendor's Delete with the name as a literal")
    Set tQuery("name") = "y"" Kill ^X ;"
    Set tHostile = $ClassMethod(..#SEAM, "Snippet", "Locales", "DELETE", .tQuery)
    Do $$$AssertEquals($Select(tHostile.%Size() = 1: tHostile.%Get(0).%Get("text"), 1: ""), tHead _ "Delete(" _ ##class(OcuPilot.Port.AdminPort).Literal(tQuery("name")) _ ")", "a hostile name renders as one string literal, its quote doubled, so nothing after it runs")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Snippet", "Locales", "GET", .tQuery).%Size(), 0, "a read renders no script")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "SnippetForm", "Locales", "INSTALL") _ "|" _ $ClassMethod(..#SEAM, "SnippetForm", "Locales", "LIST"), "objectscript|", "a write has an objectscript form and a read none")
}

}
