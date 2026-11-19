/// <p>Pins Story 21.16's read (AC1, AC3, AC5; AD-5, AD-21, AD-29, AD-36, AD-53): the Locale properties list equals the vendor's own <code>Get</code> of
/// a locale property by property and list by list, each table's <code>Loadable</code> equals the vendor's <code>Tables</code> query over the tables it holds compiled, every row of a
/// locale carries that locale's refusal, a missing or unlisted locale and an absent row are refused as the grammar says, and the screen and the five write
/// tools declare their port, pairs, destructive flags and consequences.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an instance that lists its current locale, at least one other locale
/// InterSystems ships, and the locale <code>enuw</code> with its pattern tables <code>Latin1</code> and <code>Unicode</code>. It reads only; it creates nothing.</p>
Class OcuPilot.Test.LocalePropertyRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.LocalePort";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LocalePropertyList";

Parameter GROUPS = "basic,formats,tables,iotables,tabledefaults,iodefaults,strings";

/// <p>The vendor's <code>Get</code> of <var>pLocale</var> in <var>pProps</var>, and the current locale's name, read in <code>%SYS</code> independently of the port.</p>
ClassMethod VendorGet(pLocale As %String, Output pProps) As %String
{
    Kill pProps
    Set tCurrent = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tSC = ##class(Config.NLS.Locales).Get(pLocale, .pProps)
    } Catch {
        Kill pProps
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCurrent
}

/// <p>The names of the tables of type <var>pType</var> the vendor's <code>Tables</code> query lists for <var>pLocale</var> as not built in, comma-joined.</p>
ClassMethod VendorTables(pLocale As %String, pType As %String) As %String
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.NLS.Locales:Tables")
        Set tSC = tRS.Execute(pLocale, pType, 0)
        While $$$ISOK(tSC) && tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.GetData(1)
        }
        Set tRS = ""
    } Catch {
        Set tRS = ""
        Set tNames = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>Whether the vendor holds the table <var>pTable</var> of type <var>pType</var> of a locale of character set <var>pCharacterSet</var> compiled, by
/// <code>Config.NLS.Tables.IsLoadable</code> over the sides a load reads: an input/output table's two sides from its stored entry
/// <var>pEntry</var>, a collation table both ways, any other type from the character set to the table.</p>
ClassMethod VendorHolds(pType As %String, pTable As %String, pCharacterSet As %String, pEntry As %String = "") As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pType = "XLT" {
            Set tHeld = ''##class(Config.NLS.Tables).IsLoadable("XLT", $List(pEntry, 1), $List(pEntry, 2)) && ''##class(Config.NLS.Tables).IsLoadable("XLT", $List(pEntry, 3), $List(pEntry, 4))
        } ElseIf pType = "COL" {
            Set tHeld = ''##class(Config.NLS.Tables).IsLoadable("COL", pTable, pCharacterSet) && ''##class(Config.NLS.Tables).IsLoadable("COL", pCharacterSet, pTable)
        } Else {
            Set tHeld = ''##class(Config.NLS.Tables).IsLoadable(pType, pCharacterSet, pTable)
        }
    } Catch {
        Set tHeld = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tHeld
}

/// <p>The port's rows of <var>pLocale</var>, each in <var>pRows</var> by its <code>Name</code>; answers their count, or <code>-1</code> with the HTTP status
/// and fault code in <var>pWhy</var> when the port refuses.</p>
ClassMethod Rows(pLocale As %String, Output pRows, Output pWhy As %String) As %Integer
{
    Kill pRows
    Set pWhy = ""
    Kill tQuery
    Set tQuery("locale") = pLocale
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Set pWhy = tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Quit -1
    }
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows(tRow.%Get("Name")) = tRow
    }
    Quit tList.%Size()
}

/// <p>The first locale the port lists that InterSystems ships and that is not current, or <code>""</code>.</p>
ClassMethod ShippedNotCurrent() As %String
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Set tFound = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If 'tRow.%Get("Custom") && 'tRow.%Get("Current") {
            Set tFound = tRow.%Get("Name")
            Quit
        }
    }
    Quit tFound
}

/// <p><b>AC1.</b> The current locale's rows equal the vendor's <code>Get</code> property by property: every editable property of the seven groups
/// and every shown one reads its value (the leading space of a weekday or month text is not shown), each of the eight table lists and the input/output
/// tables has one row per member and none more, and the row count is exactly those. A table is <code>Loadable</code> exactly when its type is one a
/// load accepts and the vendor's <code>Tables</code> query lists it.</p>
/// <p>Mutation (Rule 19): <code>PropertyRows</code> sets <code>Loadable</code> true for every table -> the loadable assertions go red.</p>
Method TestTheRowsEqualTheVendorsGetAndItsTablesQuery()
{
    Set tLocale = ..VendorGet("", .tNone)
    Do ..VendorGet(tLocale, .tProps)
    Do $$$AssertTrue($Data(tProps) > 1, "the vendor reads the current locale " _ tLocale)
    Set tCount = ..Rows(tLocale, .tRows, .tWhy)
    Do $$$AssertTrue(tCount > 0, "the port lists its rows: " _ tWhy)
    Set tExpected = 0
    Set tScalars = ""
    For tGroup = "basic", "formats", "strings", "tabledefaults", "iodefaults" {
        Set tScalars = tScalars _ $ListToString($ClassMethod(..#PORT, "GroupNames", tGroup)) _ ","
    }
    Set tScalars = tScalars _ $Parameter(..#PORT, "SHOWN")
    Set tScalars = $Select($Extract(tScalars, *) = ",": $Extract(tScalars, 1, *-1), 1: tScalars)
    For tI = 1:1:$Length(tScalars, ",") {
        Set tName = $Piece(tScalars, ",", tI)
        If $Data(tProps(tName)) '= 1 Continue
        Set tExpected = tExpected + 1
        Set tValue = tProps(tName)
        If $ClassMethod(..#PORT, "NameCount", tName) && ($Extract(tValue) = " ") Set tValue = $Extract(tValue, 2, *)
        Do $$$AssertTrue($Data(tRows(tName)), tName _ " has a row")
        If $Data(tRows(tName)) Do $$$AssertEquals(tRows(tName).%Get("Value"), tValue, tName _ "'s value is the vendor's")
    }
    Set tLists = $Parameter(..#PORT, "TABLELISTS")
    Set tTypes = ""
    For tI = 1:1:$Length(tLists, ",") Set tTypes = tTypes _ $ListBuild($Piece($Piece(tLists, ",", tI), ":", 1))
    Set tTypes = tTypes _ $ListBuild("XLTTables")
    Set tLoadTypes = $Parameter(..#PORT, "LOADTYPES")
    For tI = 1:1:$ListLength(tTypes) {
        Set tList = $List(tTypes, tI)
        Set tType = $ClassMethod(..#PORT, "TypeOf", tList)
        Set tTables = ..VendorTables(tLocale, tType)
        Set tKey = ""
        For {
            Set tKey = $Order(tProps(tList, tKey))
            If tKey = "" Quit
            Set tExpected = tExpected + 1
            Set tRowName = tList _ ":" _ tKey
            Do $$$AssertTrue($Data(tRows(tRowName)), tRowName _ " has a row")
            If '$Data(tRows(tRowName)) Continue
            Set tWant = (("," _ tLoadTypes _ ",") [ ("," _ tType _ ",")) && (("," _ tTables _ ",") [ ("," _ tKey _ ","))
            If tWant Set tWant = ..VendorHolds(tType, tKey, $Get(tProps("CharacterSet")), $Get(tProps(tList, tKey)))
            Do $$$AssertEquals(tRows(tRowName).%Get("Kind") _ "|" _ tRows(tRowName).%Get("ReadOnly") _ "|" _ ''tRows(tRowName).%Get("Loadable"), "table|1|" _ ''tWant, tRowName _ " is a read-only table row whose Loadable is the vendor's Tables answer and its compiled table")
        }
    }
    Do $$$AssertEquals(tCount, tExpected, "the port lists exactly the vendor's properties, tables and input/output tables")
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        Do $$$AssertTrue($ListFind($ListFromString(..#GROUPS), tRows(tName).%Get("Group")), tName _ " names one of the seven groups")
    }
}

/// <p><b>AC1.</b> One row is asserted by its literal: on <code>enuw</code> the pattern table <code>Unicode</code> reads <code>Loadable</code> true and the built-in pattern table
/// <code>Latin1</code> false, whatever the port's own list of loadable types holds.</p>
/// <p>Mutation (Rule 19): <code>LOADTYPES</code> without <code>Pattern</code> -> the <code>Unicode</code> row goes red, while the derived assertions of
/// <method>TestTheRowsEqualTheVendorsGetAndItsTablesQuery</method> stay green.</p>
Method TestAPatternTableReadsLoadableByItsLiteral()
{
    Set tCount = ..Rows("enuw", .tRows, .tWhy)
    Do $$$AssertTrue(tCount > 0, "the port lists the rows of enuw: " _ tWhy)
    Do $$$AssertTrue($Data(tRows("PatternTables:Unicode")) && $Data(tRows("PatternTables:Latin1")), "enuw lists the pattern tables Unicode and Latin1")
    If '$Data(tRows("PatternTables:Unicode")) || '$Data(tRows("PatternTables:Latin1")) Quit
    Do $$$AssertEquals(''tRows("PatternTables:Unicode").%Get("Loadable"), 1, "PatternTables:Unicode reads loadable")
    Do $$$AssertEquals(''tRows("PatternTables:Latin1").%Get("Loadable"), 0, "PatternTables:Latin1, a built-in table, reads not loadable")
}

/// <p><b>AC3.</b> Every row of a locale carries that locale's refusal: <code>LOCALE.EDIT.CURRENT</code> for the current locale and
/// <code>LOCALE.EDIT.SYSTEM</code> for another locale InterSystems ships. The screen's own read answers the same rows as the port.</p>
/// <p>Mutation (Rule 19): <code>EditCode</code> answers <code>""</code> for the current locale -> the current assertion goes red.</p>
Method TestEveryRowCarriesTheLocalesRefusal()
{
    Set tCurrent = ..VendorGet("", .tNone)
    Set tCount = ..Rows(tCurrent, .tRows)
    Set tSeen = ""
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        If tSeen '[ ("|" _ tRows(tName).%Get("Refusal") _ "|") Set tSeen = tSeen _ "|" _ tRows(tName).%Get("Refusal") _ "|"
    }
    Do $$$AssertEquals(tSeen, "|LOCALE.EDIT.CURRENT|", "every row of the current locale carries the current locale's refusal")
    Set tOther = ..ShippedNotCurrent()
    Do $$$AssertNotEquals(tOther, "", "the instance lists a shipped locale that is not current")
    Set tCount = ..Rows(tOther, .tOtherRows)
    Set tSeen = ""
    Set tName = ""
    For {
        Set tName = $Order(tOtherRows(tName))
        If tName = "" Quit
        If tSeen '[ ("|" _ tOtherRows(tName).%Get("Refusal") _ "|") Set tSeen = tSeen _ "|" _ tOtherRows(tName).%Get("Refusal") _ "|"
    }
    Do $$$AssertEquals(tSeen, "|LOCALE.EDIT.SYSTEM|", "every row of " _ tOther _ " carries the shipped locale's refusal")
    Kill tCriteria
    Set tCriteria("locale") = tCurrent
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tHttp, "1|200", "the screen's read of the current locale succeeds")
    If $IsObject($Get(tResult)) Do $$$AssertEquals(tResult.%Get("rows").%Size(), ..Rows(tCurrent, .tAgain), "and answers the port's rows")
}

/// <p><b>AC1.</b> The criterion and the absent cases: no locale and an unlisted one are 404 <code>LOCALE.NOTFOUND</code>, a name that is a pattern is compared
/// exactly, a cap of the wrong shape is 400 <code>PORT.VALIDATION</code> and a cap of 3 answers 3 rows; a row the locale does not hold is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>, a held row reads as its list row, and a create's read of a held table is 409 <code>LOCALE.TABLE.TAKEN</code>; the screen
/// refuses a read that names no locale as a missing required criterion.</p>
/// <p>Mutation (Rule 19): <code>State</code> compares the locale as a prefix -> the pattern row goes red.</p>
Method TestTheCriterionAndTheAbsentCases()
{
    Set tCurrent = ..VendorGet("", .tNone)
    Do $$$AssertEquals(..Rows("", .tRows, .tWhy) _ "|" _ tWhy, "-1|404|LOCALE.NOTFOUND", "no locale is not found")
    Do $$$AssertEquals(..Rows("nosuchlocale", .tRows, .tWhy) _ "|" _ tWhy, "-1|404|LOCALE.NOTFOUND", "an unlisted locale is not found")
    Do $$$AssertEquals(..Rows($Extract(tCurrent, 1, 2) _ "*", .tRows, .tWhy) _ "|" _ tWhy, "-1|404|LOCALE.NOTFOUND", "a pattern is compared exactly")
    Kill tQuery
    Set tQuery("locale") = tCurrent
    Set tQuery("maxRows") = "x"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|PORT.VALIDATION", "a cap of the wrong shape is refused")
    Set tQuery("maxRows") = 3
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tList.%Size(), "200|3", "a cap of 3 answers three rows")
    Kill tQuery
    Set tQuery("locale") = tCurrent
    Set tQuery("name") = "DateFormat"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tRow)): tRow.%Get("Name") _ "|" _ tRow.%Get("Group"), 1: ""), "200|DateFormat|formats", "a held row reads as its list row")
    Set tQuery("name") = "NoSuchProperty"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "404|CONFIG.SETTING.NOTFOUND", "a row the locale does not hold is not found")
    Set tQuery("name") = "PatternTables:Unicode"
    Set tQuery("action") = "ADD"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Properties", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "409|LOCALE.TABLE.TAKEN", "a create's read of a held table is taken")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, "", .tResult, .tScreenHttp, .tScreenFault, .tCriteria)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ tScreenHttp, "1|400", "the screen refuses a read that names no locale")
}

/// <p><b>AC5.</b> The screen and the five write tools declare what the client and the agent rely on: the screen's route, parent, id, actions, read source and
/// criterion; each tool's name, screen actions (none for the two creates, which a person reaches through their Save routes), port, endpoint, request type,
/// destructive flag, consequence and classic page; the write pair on each
/// tool; and the nine refusal sentences and the load consequence the client pins.</p>
Method TestTheScreenAndToolsDeclareTheirPageActionsAndConsequences()
{
    Set tClass = ..#SCREEN
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "SideBarPosition") _ "|" _ $ClassMethod(tClass, "ClassicPage"), "os-management/locales/properties|0|%CSP.UI.Portal.NLSEdit", "its route, position and classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.NLSEdit", "O", "URL")), "%CSP.UI.Portal.NLSEdit", "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "locale-property|set,remove-table,load-table", "its entity type and its row actions")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "locale|Properties|LIST", "it reads through the locale port")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Get(0).param, "locale", "its one criterion is the locale")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    For tCase = $ListBuild("LocaleCopy", "osmgmt.locales.copy", "", "COPY", "Locales", 0, "%CSP.UI.Portal.NLS"), $ListBuild("LocalePropertySet", "osmgmt.localeproperties.set", "set", "SET", "Properties", 0, "%CSP.UI.Portal.NLSEdit"), $ListBuild("LocaleTableAdd", "osmgmt.localeproperties.add", "", "ADD", "Properties", 0, "%CSP.UI.Portal.NLSEdit"), $ListBuild("LocaleTableRemove", "osmgmt.localeproperties.remove", "remove-table", "REMOVE", "Properties", 0, "%CSP.UI.Portal.NLSEdit"), $ListBuild("LocaleTableLoad", "osmgmt.localeproperties.load", "load-table", "LOAD", "Properties", 1, "%CSP.UI.Portal.NLS") {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ ..#PORT _ "|" _ $List(tCase, 5) _ "|" _ $List(tCase, 4), $List(tCase, 1) _ ": its name, screen action, port, endpoint and request type")
        Do $$$AssertEquals(''$ClassMethod(tTool, "Destructive") _ "|" _ $Parameter(tTool, "CLASSICPAGES"), $List(tCase, 6) _ "|" _ $List(tCase, 7), $List(tCase, 1) _ ": its destructive flag and classic page")
        Set tToolPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue($ListFind(tToolPairs, $ListBuild("%DB_IRISSYS", "WRITE")), $List(tCase, 1) _ ": its tool adds the write pair")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.LocaleTableLoad", "CONSEQUENCECODE") _ "|" _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.LOAD"), "LOCALE.LOAD|Loading makes this table available to every process on this instance until the next restart; on the current locale it can also change the instance's defaults.", "the load tool states its consequence, the published sentence")
    Set tCodes = "LOCALE.COPY.NAME,LOCALE.COPY.TAKEN,LOCALE.EDIT.SYSTEM,LOCALE.EDIT.CURRENT,LOCALE.TABLE.UNAVAILABLE,LOCALE.TABLE.TAKEN,LOCALE.TABLE.DEFAULT,LOCALE.TABLE.ROW,LOCALE.TABLE.NOTLOADABLE"
    Set tStatuses = ""
    For tI = 1:1:$Length(tCodes, ",") {
        Set tCode = $Piece(tCodes, ",", tI)
        Do $$$AssertNotEquals(##class(OcuPilot.Api.LocaleError).ReasonFor(tCode), "", tCode _ " carries its sentence")
        Set tStatuses = tStatuses _ ##class(OcuPilot.Api.LocaleError).HttpStatusFor(tCode) _ ","
    }
    Do $$$AssertEquals(tStatuses, "400,409,409,409,409,409,409,409,409,", "the copy name is 400 and the other eight refusals 409")
}

}
