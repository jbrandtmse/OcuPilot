/// <p>Pins Story 21.16's rules (AC1-AC4; AD-4, AD-21, AD-29, AD-51, AD-53, AD-54, AD-56, AD-59) without touching the instance: the port runs as
/// <class>OcuPilot.Test.LocaleGateSeam</class>, which poses a custom locale and its definition, records the copy, the change and the load instead of
/// making them, and so shows what the port would send. It pins that every refusal of the matrix is answered by the port and by the mint's rules before any send
/// seam, that a send holds the complete settable set the fresh read holds with the one change applied, the governance defaults and the destructive flags, and the
/// script each write renders.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an instance whose current locale and one other locale are ones
/// InterSystems ships. The posed locale carries the current locale's definition with the tables the seam holds, among them the pattern table <code>Japanese</code> posed as
/// listed and not compiled, which the instance's own pattern table of that name is for <class>OcuPilot.Test.LocaleEditWrite</class>. That definition lists the pattern tables
/// <code>Latin1</code> and <code>Unicode</code> (its default), the identifier table <code>Latin1</code>, the collation table <code>IRIS standard</code> and the input/output tables
/// <code>CP1250</code> and <code>CP1251</code>, as the stock <code>enuw</code> does. It writes nothing to the instance; the real writes are
/// <class>OcuPilot.Test.LocaleEditWrite</class>'s.</p>
Class OcuPilot.Test.LocaleEditRules Extends %UnitTest.TestCase
{

Parameter SEAM = "OcuPilot.Test.LocaleGateSeam";

Parameter RULES = "OcuPilot.Area.OsMgmt.LocaleRules";

Parameter READ = "OcuPilot.Test.LocalePropertyRead";

/// <p>The custom locale the seam poses.</p>
Parameter POSED = "yzzw";

Parameter KEYS = "osmgmt.locales.copy,osmgmt.localeproperties.set,osmgmt.localeproperties.add,osmgmt.localeproperties.remove,osmgmt.localeproperties.load";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do ..Pose()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Quit $$$OK
}

/// <p>Pose a custom, non-current locale whose definition is the current locale's, with the translation table <code>CP1250</code> as an input/output default
/// the classic editor shows and <code>CP1251</code> as one it does not (<code>TranDDP</code>), and the tables its <code>Tables</code> query lists: <code>Unicode</code>
/// and <code>Japanese</code> of type <code>Pattern</code>, <code>CP1250</code> and <code>CP1251</code> of type <code>XLT</code>.</p>
Method Pose()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do $ClassMethod(..#READ, "VendorGet", tCurrent, .tProps)
    Set tProps("TranZCVT") = "CP1250"
    Set tProps("TranDDP") = "CP1251"
    Do $ClassMethod(..#SEAM, "HoldLocale", ..#POSED, "a posed copy", 0, 1)
    Do $ClassMethod(..#SEAM, "HoldProperties", ..#POSED, .tProps)
    Do $ClassMethod(..#SEAM, "HoldTables", "Pattern", $ListBuild("Unicode", "Japanese"))
    Do $ClassMethod(..#SEAM, "HoldTables", "XLT", $ListBuild("CP1250", "CP1251"))
    Do $ClassMethod(..#SEAM, "FeedAvailable", 1)
}

/// <p>The write <var>pType</var> through the seam for the row <var>pName</var> of <var>pLocale</var> (a copy's <var>pLocale</var> is the new name), with
/// <var>pBody</var>; answers <code>http|code</code>, the code <code>""</code> for a write that was made.</p>
Method Call(pType As %String, pLocale As %String, pName As %String = "", pBody = "", Output pOut) As %String
{
    Set pBody = ..Body(pBody)
    Kill tQuery
    If pType = "COPY" {
        Set tEndpoint = "Locales"
        Set tQuery("name") = pLocale
    } Else {
        Set tEndpoint = "Properties"
        Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pLocale, pName))
    }
    Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, pType, .tQuery, pBody, .pOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The sentence the mint's rules give the write <var>pType</var> of the tool <var>pTool</var> for the same row, through the seam, or <code>""</code>
/// for no refusal; a call that fails is no refusal either, so a rule that errors does not read as one that refused.</p>
Method Mint(pType As %String, pLocale As %String, pName As %String = "", pBody = "") As %String
{
    Set pBody = ..Body(pBody)
    Set tId = $Select(pType = "COPY": pLocale, 1: ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pLocale, pName)))
    Set tSC = $ClassMethod(..#RULES, "PropertyProblem", ..#SEAM, pType, tId, pBody, .tProblem)
    Quit $Select($$$ISOK(tSC): tProblem, 1: "")
}

/// <p>The body <var>pBody</var> as an object: a case list holds a body as JSON text, because a list does not keep an object's identity.</p>
ClassMethod Body(pBody) As %DynamicAbstractObject
{
    If $IsObject(pBody) || (pBody = "") Quit pBody
    Quit ##class(%DynamicAbstractObject).%FromJSON(pBody)
}

/// <p>The script the seam renders for the write <var>pType</var>, as JSON text.</p>
Method Script(pEndpoint As %String, pType As %String, ByRef pQuery, pBody = "") As %String
{
    Set tSteps = $ClassMethod(..#SEAM, "Snippet", pEndpoint, pType, .pQuery, pBody)
    Quit tSteps.%ToJSON()
}

/// <p><b>AC1.</b> A copy is judged before any create: a name that is not <code>y</code>, two lowercase letters or digits and the source's last character is
/// <code>LOCALE.COPY.NAME</code> (400), a listed name <code>LOCALE.COPY.TAKEN</code> (409), an unlisted source <code>LOCALE.NOTFOUND</code> (404) and a body
/// without <code>Source</code> or with a description over the vendor's 128 characters <code>PORT.VALIDATION</code> (400), each with no call recorded and the mint's rules giving the same sentence. A copy that is
/// allowed creates the name from the source's whole definition, <code>Name</code> and <code>Description</code> replaced, the description the source's when none is sent.</p>
/// <p>Mutation (Rule 19): <code>SendCreate</code>'s set keeps the source's description when one is sent -> the description assertion goes red; the description length check dropped
/// from <code>Judge</code> -> the over-length row goes red.</p>
Method TestACopyIsJudgedBeforeAnyCreateAndCopiesTheWholeDefinition()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    For tCase = $ListBuild("yzz8", tCurrent, "400|LOCALE.COPY.NAME"), $ListBuild("enuw", tCurrent, "400|LOCALE.COPY.NAME"), $ListBuild("YAAW", tCurrent, "400|LOCALE.COPY.NAME"), $ListBuild("yaaaw", tCurrent, "400|LOCALE.COPY.NAME"), $ListBuild("yzz", tCurrent, "400|LOCALE.COPY.NAME"), $ListBuild(..#POSED, tCurrent, "409|LOCALE.COPY.TAKEN"), $ListBuild("yaaw", "nosuchlocale", "404|LOCALE.NOTFOUND") {
        Set tOutcome = ..Call("COPY", $List(tCase, 1), "", {"Source": ($List(tCase, 2))})
        Do $$$AssertEquals(tOutcome, $List(tCase, 3), "a copy of " _ $List(tCase, 2) _ " to " _ $List(tCase, 1) _ " is refused " _ $List(tCase, 3))
        Do $$$AssertNotEquals(..Mint("COPY", $List(tCase, 1), "", {"Source": ($List(tCase, 2))}), "", "and the mint's rules refuse it")
    }
    Do $$$AssertEquals(..Call("COPY", "yaaw", "", {"Description": "x"}), "400|PORT.VALIDATION", "a copy that names no source is a validation fault")
    Set tLong = $Translate($Justify("", 129), " ", "d")
    Do $$$AssertEquals(..Call("COPY", "yaaw", "", {"Source": (tCurrent), "Description": (tLong)}), "400|PORT.VALIDATION", "a description over the vendor's 128 characters is a validation fault, not a server error")
    Do $$$AssertNotEquals(..Mint("COPY", "yaaw", "", {"Source": (tCurrent), "Description": (tLong)}), "", "and the mint's rules refuse it")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no create was made by any refusal")
    Do $$$AssertEquals(..Call("COPY", "yaaw", "", {"Source": (tCurrent)}, .tOut) _ "|" _ tOut.%Get("Name") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||yaaw|CREATE|yaaw", "a well-formed copy is made")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $ClassMethod(..#READ, "VendorGet", tCurrent, .tSource)
    Set tDifferent = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSource(tKey))
        If tKey = "" Quit
        If ($Data(tSource(tKey)) = 1) && (tKey '= "Description") && ($Get(tSent(tKey)) '= tSource(tKey)) Set tDifferent = tDifferent _ tKey _ ";"
    }
    Do $$$AssertEquals(tDifferent, "", "the created definition equals the source's in every scalar but the description")
    Do $$$AssertEquals($Get(tSent("Description")), tSource("Description"), "and its description is the source's when none is sent")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do ..Call("COPY", "yaaw", "", {"Source": (tCurrent), "Description": "mine"})
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $$$AssertEquals($Get(tSent("Description")), "mine", "a description that is sent replaces it")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $$$AssertEquals(..Call("COPY", "yaaw", "", {"Source": (tCurrent), "Description": ($Extract(tLong, 1, 128))}), "200|", "a description of exactly 128 characters is accepted")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("COPY", "yaaw", "", {"Source": (tCurrent)}) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor refusal of the create is logged and answered 500")
}

/// <p><b>AC3.</b> A set, an add and a remove are refused for the current locale (<code>LOCALE.EDIT.CURRENT</code>) and for a locale InterSystems ships that is not
/// current (<code>LOCALE.EDIT.SYSTEM</code>), 409 with no call recorded, and the mint's rules refuse each with the published sentence. A load is not refused for them:
/// it is recorded, never made.</p>
/// <p>Mutation (Rule 19): the <code>y</code> check dropped from <code>LocaleRules.EditCode</code> -> the shipped-locale rows go red.</p>
Method TestAChangeIsRefusedForTheCurrentAndShippedLocalesBeforeAnySend()
{
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Set tShipped = $ClassMethod(..#READ, "ShippedNotCurrent")
    Do $$$AssertNotEquals(tShipped, "", "the instance lists a shipped locale that is not current")
    For tCase = $ListBuild(tCurrent, "LOCALE.EDIT.CURRENT"), $ListBuild(tShipped, "LOCALE.EDIT.SYSTEM") {
        Set tLocale = $List(tCase, 1)
        Set tCode = $List(tCase, 2)
        For tWrite = $ListBuild("SET", "DateFormat", "{""Value"":""3""}"), $ListBuild("ADD", "PatternTables:Japanese", "{}"), $ListBuild("REMOVE", "PatternTables:Latin1", "") {
            Do $$$AssertEquals(..Call($List(tWrite, 1), tLocale, $List(tWrite, 2), $List(tWrite, 3)), "409|" _ tCode, $List(tWrite, 1) _ " on " _ tLocale _ " is refused " _ tCode)
            Do $$$AssertEquals(..Mint($List(tWrite, 1), tLocale, $List(tWrite, 2), $List(tWrite, 3)), ##class(OcuPilot.Api.LocaleError).ReasonFor(tCode), "and the mint's rules give its sentence")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no call was made")
    Do $$$AssertEquals(..Call("LOAD", tCurrent, "PatternTables:Unicode") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||LOAD|" _ tCurrent _ "|Pattern|Unicode", "a load of the current locale's table is allowed, and recorded")
}

/// <p><b>AC2.</b> A set is judged against the row and its limits before any send: a row shown and never changed and a table row are
/// <code>CONFIG.SETTING.READONLY</code>, an unknown row is 404 <code>CONFIG.SETTING.NOTFOUND</code>, a value outside the limits (a date format of 99, a default that is
/// no member of its list, a month text of eleven names, a currency over its length) is <code>CONFIG.SETTING.VALUE</code>, and a body without <code>Value</code> a validation
/// fault. A set that is allowed sends the complete settable set the fresh read holds with the one change applied (a weekday or month text with its leading space), and a vendor
/// refusal of it is 400 <code>CONFIG.SETTING.VALUE</code>, logged.</p>
/// <p>Mutation (Rule 19): <code>SettableSet</code> omits the lists -> the unchanged-lists assertion goes red.</p>
Method TestASetIsJudgedAgainstItsRowAndSendsTheCompleteSetWithOneChange()
{
    Set tLocale = ..#POSED
    For tCase = $ListBuild("Country", "x", "409|CONFIG.SETTING.READONLY"), $ListBuild("PatternTables:Unicode", "x", "409|CONFIG.SETTING.READONLY"), $ListBuild("NoSuchProperty", "x", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("DateFormat", "99", "400|CONFIG.SETTING.VALUE"), $ListBuild("DateFormat", "-1", "400|CONFIG.SETTING.VALUE"), $ListBuild("DateFormat", "x", "400|CONFIG.SETTING.VALUE"), $ListBuild("TimeFormat", "5", "400|CONFIG.SETTING.VALUE"), $ListBuild("PatternTable", "Nope", "400|CONFIG.SETTING.VALUE"), $ListBuild("TranZCVT", "Nope", "400|CONFIG.SETTING.VALUE"), $ListBuild("MonthAbbr", "Ja Fe Ma Ap My Jn Jl Au Se Oc No", "400|CONFIG.SETTING.VALUE"), $ListBuild("WeekdayAbbr", "Su Mo  We Th Fr Sa", "400|CONFIG.SETTING.VALUE"), $ListBuild("Currency", $Justify("", 51), "400|CONFIG.SETTING.VALUE") {
        Do $$$AssertEquals(..Call("SET", tLocale, $List(tCase, 1), {"Value": ($List(tCase, 2))}), $List(tCase, 3), "a set of " _ $List(tCase, 1) _ " to '" _ $List(tCase, 2) _ "' is refused " _ $List(tCase, 3))
        Do $$$AssertNotEquals(..Mint("SET", tLocale, $List(tCase, 1), {"Value": ($List(tCase, 2))}), "", "and the mint's rules refuse it")
    }
    Do $$$AssertEquals(..Call("SET", tLocale, "DateFormat", {}), "400|PORT.VALIDATION", "a set that names no value is a validation fault")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no call was made by any refusal")
    Do $$$AssertEquals(..Call("SET", tLocale, "WeekdayAbbr", {"Value": "Su Mo Tu We Th Fr Sa"}) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||MODIFY|" _ tLocale, "a weekday text of seven names is sent")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $$$AssertEquals($Get(tSent("WeekdayAbbr")), " Su Mo Tu We Th Fr Sa", "the text is sent with its leading space")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $$$AssertEquals(..Call("SET", tLocale, "DateFormat", {"Value": "3"}, .tOut) _ "|" _ tOut.%Get("Name") _ "|" _ tOut.%Get("Value") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||DateFormat|3|MODIFY|" _ tLocale, "a date format of 3 is sent")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $ClassMethod(..#SEAM, "LocaleProperties", tLocale, .tFresh)
    Set tDifferent = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSent(tKey))
        If tKey = "" Quit
        If $Data(tSent(tKey)) = 1 {
            If tKey = "DateFormat" Continue
            If $Get(tFresh(tKey)) '= tSent(tKey) Set tDifferent = tDifferent _ tKey _ ";"
        } Else {
            Set tSub = ""
            For {
                Set tSub = $Order(tSent(tKey, tSub))
                If tSub = "" Quit
                If $Get(tFresh(tKey, tSub)) '= tSent(tKey, tSub) Set tDifferent = tDifferent _ tKey _ ":" _ tSub _ ";"
            }
        }
    }
    Do $$$AssertEquals(tDifferent, "", "every other scalar, every list member and every input/output table is sent as the fresh read holds it")
    Do $$$AssertEquals(tSent("DateFormat") _ "|" _ $Order(tSent("PatternTables", "")) _ "|" _ $Order(tSent("XLTTables", "")) _ "|" _ $Data(tSent("Country")), "3|Latin1|CP1250|0", "the one change is applied, the lists are sent, and a shown property is not")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("SET", tLocale, "DateFormat", {"Value": "4"}) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "400|CONFIG.SETTING.VALUE|CONFIG.SETTING.VALUE|error", "a vendor refusal of a set value is 400 CONFIG.SETTING.VALUE, logged")
}

/// <p><b>AC2.</b> An add and a remove are deltas over the fresh read: an add sends the lists as read with the one member added (an input/output table with its
/// two sides and the locale's character set), a remove sends them with the one member dropped, and each is judged first: an added table the locale lists is
/// <code>LOCALE.TABLE.TAKEN</code>, one the instance does not hold <code>LOCALE.TABLE.UNAVAILABLE</code>, a malformed row or sides on the wrong list a validation
/// fault; a removed table that is a default of its list or of an input/output default, one the classic editor does not show included, is
/// <code>LOCALE.TABLE.DEFAULT</code> and a row that is no table <code>LOCALE.TABLE.ROW</code>.</p>
/// <p>Mutation (Rule 19): the default check dropped from <code>LocaleRules.RemoveCode</code> -> the default rows go red; <code>IOHIDDENDEFAULTS</code> left out
/// of it -> the <code>CP1251</code> row goes red.</p>
Method TestAnAddAndARemoveAreDeltasOverTheFreshReadAndAreJudgedFirst()
{
    Set tLocale = ..#POSED
    Set tLong = $Translate($Justify("", 65), " ", "a")
    Set tSides = "{""InputFrom"":""Latin2"",""OutputTo"":""Latin2""}"
    For tCase = $ListBuild("ADD", "PatternTables:Unicode", "{}", "409|LOCALE.TABLE.TAKEN"), $ListBuild("ADD", "XLTTables:CP1250", tSides, "409|LOCALE.TABLE.TAKEN"), $ListBuild("ADD", "PatternTables:Japanese", "{""InputFrom"":""a"",""OutputTo"":""b""}", "400|PORT.VALIDATION"), $ListBuild("ADD", "XLTTables:myio", "{""InputFrom"":""Latin2""}", "400|PORT.VALIDATION"), $ListBuild("ADD", "XLTTables:myio", "{}", "400|PORT.VALIDATION"), $ListBuild("ADD", "NoSuchList:x", "{}", "400|PORT.VALIDATION"), $ListBuild("ADD", "PatternTables", "{}", "400|PORT.VALIDATION"), $ListBuild("ADD", "XLTTables:" _ tLong, tSides, "400|PORT.VALIDATION"), $ListBuild("ADD", "XLTTables:a" _ $Char(7) _ "b", tSides, "400|PORT.VALIDATION"), $ListBuild("REMOVE", "PatternTables:Unicode", "", "409|LOCALE.TABLE.DEFAULT"), $ListBuild("REMOVE", "XLTTables:CP1250", "", "409|LOCALE.TABLE.DEFAULT"), $ListBuild("REMOVE", "XLTTables:CP1251", "", "409|LOCALE.TABLE.DEFAULT"), $ListBuild("REMOVE", "DateFormat", "", "409|LOCALE.TABLE.ROW"), $ListBuild("REMOVE", "PatternTables:Nope", "", "404|CONFIG.SETTING.NOTFOUND") {
        Do $$$AssertEquals(..Call($List(tCase, 1), tLocale, $List(tCase, 2), $List(tCase, 3)), $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused " _ $List(tCase, 4))
        Do $$$AssertNotEquals(..Mint($List(tCase, 1), tLocale, $List(tCase, 2), $List(tCase, 3)), "", "and the mint's rules refuse it")
    }
    Do $ClassMethod(..#SEAM, "FeedAvailable", 0)
    Do $$$AssertEquals(..Call("ADD", tLocale, "PatternTables:Japanese", {}), "409|LOCALE.TABLE.UNAVAILABLE", "a table the instance does not hold for the character set is unavailable")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no call was made by any refusal")
    Do $ClassMethod(..#SEAM, "FeedAvailable", 1)
    Do $ClassMethod(..#SEAM, "LocaleProperties", tLocale, .tFresh)
    Do $$$AssertEquals(..Call("ADD", tLocale, "PatternTables:Japanese", {}, .tOut) _ "|" _ tOut.%Get("Value"), "200||Japanese", "an internal table is added")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Set tMembers = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSent("PatternTables", tKey))
        If tKey = "" Quit
        Set tMembers = tMembers _ tKey _ ","
    }
    Do $$$AssertEquals(tMembers _ "|" _ $Data(tSent("IdentifierTables", "Latin1")) _ "|" _ $Data(tSent("XLTTables", "CP1251")), "Japanese,Latin1,Unicode,|1|1", "the list is sent as read with the member added, and the other lists as read")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $$$AssertEquals(..Call("ADD", tLocale, "XLTTables:myio", {"InputFrom": "Latin2", "OutputTo": "Latin2"}, .tOut) _ "|" _ tOut.%Get("Value"), "200||Latin2 / Latin2", "an input/output table is added")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $ClassMethod(..#SEAM, "LocaleProperties", tLocale, .tFresh)
    Do $$$AssertEquals($ListToString(tSent("XLTTables", "myio"), "|") _ "|" _ $Data(tSent("XLTTables", "CP1250")), "Latin2|" _ tFresh("CharacterSet") _ "|" _ tFresh("CharacterSet") _ "|Latin2|1", "it carries its sides and the locale's character set, beside the tables already listed")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $$$AssertEquals(..Call("REMOVE", tLocale, "PatternTables:Latin1", "", .tOut) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||MODIFY|" _ tLocale, "a table that is no default is removed")
    Do $ClassMethod(..#SEAM, "Sent", .tSent)
    Do $$$AssertEquals($Data(tSent("PatternTables", "Latin1")) _ "|" _ $Data(tSent("PatternTables", "Unicode")) _ "|" _ $Data(tSent("XLTTables", "CP1250")), "0|1|1", "it is dropped from its list and every other member is sent")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Pose()
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("REMOVE", tLocale, "PatternTables:Latin1") _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor refusal of a table change is logged and answered 500")
}

/// <p><b>AC4.</b> A load is judged by the vendor's <code>Tables</code> query: a table the locale lists that the query lists as not built in is loaded with the locale,
/// the type its list fixes and the table, as the call the seam records; a built-in table, an accent table, a row that is no table, a table the locale lists
/// that the instance has not compiled and an unlisted row are <code>LOCALE.TABLE.NOTLOADABLE</code> (409) or 404, with no call recorded and the mint's rules
/// refusing the same; a vendor refusal of a load the judgement admitted is the same 409, never 500.</p>
/// <p>Mutation (Rule 19): <code>LoadCode</code> admits every row -> the not-loadable rows go red; <code>PropertyRows</code> without its
/// <code>TableLoadable</code> check -> the uncompiled table's row goes red.</p>
Method TestALoadIsJudgedByTheTablesQueryAndSendsTheTypeItsListFixes()
{
    Set tLocale = ..#POSED
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do $ClassMethod(..#READ, "VendorGet", tCurrent, .tProps)
    Set tProps("TranZCVT") = "CP1250"
    Set tProps("PatternTables", "Japanese") = ""
    Do $ClassMethod(..#SEAM, "HoldProperties", tLocale, .tProps)
    Do $ClassMethod(..#SEAM, "HoldUncompiled", "Japanese")
    For tCase = $ListBuild("PatternTables:Latin1", "409|LOCALE.TABLE.NOTLOADABLE"), $ListBuild("AccentTables:Unicode", "409|LOCALE.TABLE.NOTLOADABLE"), $ListBuild("DateFormat", "409|LOCALE.TABLE.NOTLOADABLE"), $ListBuild("CollationTables:IRIS standard", "409|LOCALE.TABLE.NOTLOADABLE"), $ListBuild("PatternTables:Japanese", "409|LOCALE.TABLE.NOTLOADABLE"), $ListBuild("PatternTables:Nope", "404|CONFIG.SETTING.NOTFOUND") {
        Do $$$AssertEquals(..Call("LOAD", tLocale, $List(tCase, 1)), $List(tCase, 2), "a load of " _ $List(tCase, 1) _ " is refused " _ $List(tCase, 2))
        Do $$$AssertNotEquals(..Mint("LOAD", tLocale, $List(tCase, 1)), "", "and the mint's rules refuse it")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no call was made by any refusal")
    Do $$$AssertEquals(..Call("LOAD", tLocale, "PatternTables:Unicode", "", .tOut) _ "|" _ tOut.%Get("Name") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||PatternTables:Unicode|LOAD|" _ tLocale _ "|Pattern|Unicode", "a loadable pattern table is loaded with its locale, type and table")
    Do $$$AssertEquals(..Call("LOAD", tLocale, "XLTTables:CP1250") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||LOAD|" _ tLocale _ "|Pattern|Unicode,LOAD|" _ tLocale _ "|XLT|CP1250", "an input/output table is loaded as type XLT")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("LOAD", tLocale, "PatternTables:Unicode") _ "|" _ $ClassMethod(..#SEAM, "Faults"), "409|LOCALE.TABLE.NOTLOADABLE|LOCALE.TABLE.NOTLOADABLE|error", "a vendor refusal of a load is logged and answered as the refusal of a table that cannot be loaded, never 500")
}

/// <p><b>AC4.</b> A load names the vendor's spelling of the type its list fixes, whatever the port's own names: one recorded load per upper-case, lower-case, title-case,
/// identifier, collation and <code>XY</code> table carries <code>UpperCase</code>, <code>LowerCase</code>, <code>TitleCase</code>, <code>Ident</code>, <code>COL</code> and <code>XY</code>;
/// and an accent table is never loadable, though the held <code>Accent</code> query lists it: its load is <code>LOCALE.TABLE.NOTLOADABLE</code> with no call recorded.</p>
/// <p>Mutation (Rule 19): <code>LOADTYPES</code> with <code>Accent</code> added -> the accent row goes red; <code>TABLELISTS</code> spells <code>UpperCaseTables</code>'s type
/// <code>Upper</code> -> the upper-case row goes red.</p>
Method TestEachListLoadsUnderTheVendorsTypeSpellingAndAnAccentTableNeverLoads()
{
    Set tLocale = ..#POSED
    Set tCurrent = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do $ClassMethod(..#READ, "VendorGet", tCurrent, .tProps)
    Set tProps("TranZCVT") = "CP1250"
    Set tLoads =$ListBuild($ListBuild("UpperCaseTables", "UpperCase"), $ListBuild("LowerCaseTables", "LowerCase"), $ListBuild("TitleCaseTables", "TitleCase"), $ListBuild("IdentifierTables", "Ident"), $ListBuild("CollationTables", "COL"), $ListBuild("XYTables", "XY"), $ListBuild("AccentTables", "Accent"))
    For tI = 1:1:$ListLength(tLoads) {
        Set tList = $List($List(tLoads, tI), 1)
        Kill tProps(tList)
        Set tProps(tList, "Mine") = ""
        Do $ClassMethod(..#SEAM, "HoldTables", $List($List(tLoads, tI), 2), $ListBuild("Mine"))
    }
    Do $ClassMethod(..#SEAM, "HoldProperties", tLocale, .tProps)
    For tI = 1:1:$ListLength(tLoads) {
        Set tList = $List($List(tLoads, tI), 1)
        Set tType = $List($List(tLoads, tI), 2)
        Set tName = tList _ ":Mine"
        If tType = "Accent" {
            Do $$$AssertEquals(..Call("LOAD", tLocale, tName), "409|LOCALE.TABLE.NOTLOADABLE", "a load of an accent table is refused although its query lists it")
            Do $$$AssertNotEquals(..Mint("LOAD", tLocale, tName), "", "and the mint's rules refuse it")
            Continue
        }
        Set tOutcome = ..Call("LOAD", tLocale, tName)
        Set tCalls = $ClassMethod(..#SEAM, "Calls")
        Do $$$AssertEquals(tOutcome _ "|" _ $Piece(tCalls, ",", $Length(tCalls, ",")), "200||LOAD|" _ tLocale _ "|" _ tType _ "|Mine", "a load of " _ tName _ " is sent as type " _ tType)
    }
    Do $$$AssertEquals($Length($ClassMethod(..#SEAM, "Calls"), ","), 6, "six loads were made, and none of the accent table")
}

/// <p><b>AC1-AC4.</b> The five keys ship as the story rules: the copy, the set, the add and the remove enabled, the load disabled, so the agent's call of the load
/// is refused at dispatch with the default baseline; and only the load is declared destructive, stating <code>LOCALE.LOAD</code>.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.localeproperties.load</code> true in the baseline -> the load key row goes red.</p>
Method TestTheKeysShipAsRuledAndOnlyTheLoadIsDestructive()
{
    Set tWant = $ListBuild("1|baseline", "1|baseline", "1|baseline", "1|baseline", "0|baseline")
    Set tTools = $ListBuild("LocaleCopy", "LocalePropertySet", "LocaleTableAdd", "LocaleTableRemove", "LocaleTableLoad")
    For tI = 1:1:$Length(..#KEYS, ",") {
        Set tKey = $Piece(..#KEYS, ",", tI)
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), $List(tWant, tI), tKey _ " ships as ruled")
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tTools, tI)
        Do $$$AssertEquals(''$ClassMethod(tTool, "Destructive"), $Select(tI = 5: 1, 1: 0), tKey _ ": its destructive flag")
    }
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.LocaleTableLoad", "Consequence", {}), "LOCALE.LOAD", "the load states its consequence")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tUse = {"type": "tool_use", "id": "toolu_locale", "input": {"Locale": "yzzw", "Name": "PatternTables:Unicode", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("osmgmt.localeproperties.load"), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tAnswer = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
    Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", "the agent's load is refused by the governance gate and nothing is minted")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
}

/// <p><b>AC1-AC4 (AD-59).</b> Each write renders the script the port would run, with its names and values as string literals: the copy's <code>Get</code>
/// and <code>Create</code>, gated on one line by the free-name check and refused with the taken sentence when the name is listed; a change's <code>Get</code>,
/// the one key and <code>Modify</code>, an emptied list sent as <code>""</code> as the port sends it; a load's <code>Tables.Load</code>; and nothing the
/// caller typed runs as code.</p>
/// <p>Mutation (Rule 19): the load's snippet omits the table -> the load row goes red; the copy's <code>Create</code> line without its <code>Exists</code>
/// gate -> the copy's gate row goes red; the remove's empty-list line dropped -> the remove's row goes red.</p>
Method TestEachWriteRendersItsScriptWithLiteralValues()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("yzzw", "PatternTables:Japanese"))
    Kill tQuery
    Set tQuery("name") = "yaaw"
    Set tCopy = ..Script("Locales", "COPY", .tQuery, {"Source": "enuw", "Description": "d"})
    Do $$$AssertTrue((tCopy [ "Config.NLS.Locales).Get(\""enuw\"""), "the copy reads its source: " _ tCopy)
    Do $$$AssertTrue((tCopy [ "'##class(Config.NLS.Locales).Exists(\""yaaw\"") Set tSC = ##class(Config.NLS.Locales).Create(\""yaaw\"""), "and creates the new name only while it is free")
    Do $$$AssertTrue((tCopy [ ##class(OcuPilot.Api.LocaleError).#REASONCOPYTAKEN), "a taken name answers the taken sentence")
    Do $$$AssertTrue((tCopy '[ "tProps(\""Name\"")"), "the copy sends no Name, as the port's create does not")
    Kill tQuery
    Set tQuery("name") = tId
    Set tAdd = ..Script("Properties", "ADD", .tQuery, {})
    Do $$$AssertTrue((tAdd [ "Config.NLS.Locales).Modify(\""yzzw\"""), "an add modifies the locale: " _ tAdd)
    Do $$$AssertTrue((tAdd [ "tProps(\""PatternTables\"", \""Japanese\"")"), "with the one member added")
    Set tRemove = ..Script("Properties", "REMOVE", .tQuery, "")
    Do $$$AssertTrue((tRemove [ "Kill tProps(\""PatternTables\"", \""Japanese\"")"), "a remove kills the one member: " _ tRemove)
    Do $$$AssertTrue((tRemove [ "If '$Data(tProps(\""PatternTables\"")) Set tProps(\""PatternTables\"") = \""\"""), "and sends a list it empties as \""\"", as the port does")
    Set tSet = ..Script("Properties", "SET", .tQuery, {"Value": "3"})
    Do $$$AssertTrue((tSet [ "= \""3\"""), "a set assigns its value as a literal: " _ tSet)
    Set tLoad = ..Script("Properties", "LOAD", .tQuery, "")
    Do $$$AssertTrue((tLoad [ "Config.NLS.Tables).Load(\""yzzw\"", \""Pattern\"", \""Japanese\"")"), "a load calls Tables.Load with its locale, type and table: " _ tLoad)
}

}
