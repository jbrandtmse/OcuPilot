/// <p>Pins Story 21.16's writes on both callers (AC1-AC4; AD-4, AD-6, AD-15, AD-53, AD-54, AD-56, AD-58) against the real instance: the current locale copied to a
/// custom locale by the Save route (<class>OcuPilot.Area.OsMgmt.LocaleCopySave</class>) and by the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>), each copy listed with a definition equal to the source's but its name and description; on a copy, a scalar set by
/// the screen's action route (<class>OcuPilot.Test.EcpActionFixture</class>), a table of an internal list and an input/output table added by the Save route
/// (<class>OcuPilot.Area.OsMgmt.LocaleTableSave</class>) and removed by the screen's action, and the same by the agent, each read back, with every other property, list member and input/output
/// table as it was; a table a list defaults to refused before the vendor; the current locale refused every change; and a table of the copy loaded by both callers
/// with the key on, and, with the default baseline, refused by governance for the agent and not for a person.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class
/// creates, changes and deletes custom locales and loads a table. The current locale is the one the copies are made from, and its definition lists the pattern tables
/// <code>Unicode</code> (loadable, and its list's default) and <code>Latin1</code> (built in, so not loadable). For its character set the instance lists the pattern tables
/// <code>Japanese</code> (listed but not compiled) and <code>Latin2</code>, and holds the translation tables to and from <code>Latin2</code>. It never changes the current locale. Every test
/// deletes the copies it made on every path (<method>Restore</method>) and puts the governance policy back.</p>
Class OcuPilot.Test.LocaleEditWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.LocalePort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter READ = "OcuPilot.Test.LocalePropertyRead";

Parameter COPYSAVE = "OcuPilot.Area.OsMgmt.LocaleCopySave";

Parameter TABLESAVE = "OcuPilot.Area.OsMgmt.LocaleTableSave";

Parameter LOCALESCREEN = "osmgmt.locales";

Parameter PROPERTYSCREEN = "osmgmt.localeproperties";

Parameter KEYS = "osmgmt.locales.copy,osmgmt.localeproperties.set,osmgmt.localeproperties.add,osmgmt.localeproperties.remove,osmgmt.localeproperties.load";

/// <p>The two custom locales the tests copy to: one per caller.</p>
Parameter COPYA = "yzaw";

Parameter COPYB = "yzbw";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Property PreparedLocale As %String [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LocaleEditWrite creates, changes and deletes custom locales and loads a table on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set ..PreparedLocale = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do ..Restore()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ..Restore()
    Quit ..EnableKeys()
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Do $$$AssertEquals(..VendorExists(..#COPYA) _ ..VendorExists(..#COPYB), "00", "the copies are gone")
    Do $$$AssertEquals($ClassMethod(..#READ, "VendorGet", "", .tNone), ..PreparedLocale, "the current locale is as the class found it")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Delete both copies, in <code>%SYS</code>.</p>
Method Restore()
{
    For tName = ..#COPYA, ..#COPYB Do ..VendorDelete(tName)
}

Method EnableKeys() As %Status
{
    Kill tSettings
    For tI = 1:1:$Length(..#KEYS, ",") Set tSettings($Piece(..#KEYS, ",", tI)) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Create the locale <var>pName</var> from the current locale's definition, as the test's own setup.</p>
ClassMethod VendorCopy(pName As %String) As %Boolean
{
    Set tOK = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tSC = ##class(Config.NLS.Locales).Get(tCurrent, .tProps)
        Set tProps("Name") = pName
        Set tProps("Description") = "test copy"
        Set tOK = $$$ISOK(##class(Config.NLS.Locales).Create(pName, .tProps))
    } Catch {
        Set tOK = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOK
}

ClassMethod VendorDelete(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.NLS.Locales).Exists(pName) Do ##class(Config.NLS.Locales).Delete(pName)
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

ClassMethod VendorExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Config.NLS.Locales).Exists(pName)
    } Catch {
        Set tExists = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>The leaf nodes whose value differs between the definitions <var>pA</var> and <var>pB</var> (<code>Get</code> arrays), as <code>key;key;</code>, a key that
/// exists in one only included, <code>list:member</code> for a list member.</p>
ClassMethod Changed(ByRef pA, ByRef pB) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pA(tKey))
        If tKey = "" Quit
        If $Data(pA(tKey)) = 1 {
            If $Get(pB(tKey), $Char(0)) '= pA(tKey) Set tOut = tOut _ tKey _ ";"
            Continue
        }
        Set tSub = ""
        For {
            Set tSub = $Order(pA(tKey, tSub))
            If tSub = "" Quit
            If $Get(pB(tKey, tSub), $Char(0)) '= pA(tKey, tSub) Set tOut = tOut _ tKey _ ":" _ tSub _ ";"
        }
    }
    Set tKey = ""
    For {
        Set tKey = $Order(pB(tKey))
        If tKey = "" Quit
        If $Data(pB(tKey)) = 1 {
            If '$Data(pA(tKey)) Set tOut = tOut _ tKey _ ";"
            Continue
        }
        Set tSub = ""
        For {
            Set tSub = $Order(pB(tKey, tSub))
            If tSub = "" Quit
            If '$Data(pA(tKey, tSub)) Set tOut = tOut _ tKey _ ":" _ tSub _ ";"
        }
    }
    Quit tOut
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> of screen <var>pScreen</var> with <var>pValues</var>; the parsed envelope in <var>pAnswer</var>, answering the
/// HTTP status.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The composite id of the row <var>pName</var> of <var>pLocale</var>.</p>
ClassMethod RowId(pLocale As %String, pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pLocale, pName))
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with <var>pArgs</var> and confirm it; answers <code>http code</code> and the confirm's answer in <var>pResult</var>, or
/// <code>refused: &lt;problem&gt;</code> when the mint refused.</p>
ClassMethod Agent(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    ; The probe mints through the kernel's own mint, so a property tool is handed the composite id its own mint class builds.
    If pArgs.%GetTypeOf("Locale") = "string" Set pName = ..RowId(pArgs.%Get("Locale"), pName)
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, pArgs, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", tProposal, .pResult)
}

/// <p>The Save route's copy of <var>pSource</var> to <var>pName</var> with <var>pDescription</var> (<code>""</code> sends none), as the Copy dialog sends it;
/// answers the read-back verdict, or <code>http code</code> of the refusal.</p>
ClassMethod SaveCopy(pName As %String, pSource As %String, pDescription As %String = "") As %String
{
    Set tFields = {"Source": (pSource)}
    If pDescription '= "" Do tFields.%Set("Description", pDescription, "string")
    Set tSC = $ClassMethod(..#COPYSAVE, "Create", "", pName, tFields, .tHttp, .tFault, .tViolations, .tReadBack)
    If +$Get(tViolations) > 0 Quit "violations " _ $List(tViolations(1), 2)
    If $$$ISERR(tSC) Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: "(none)")
}

/// <p>The Save route's add of the row <var>pName</var> to <var>pLocale</var>, with the two sides of an input/output table when <var>pInputFrom</var> is typed, as the Add
/// table dialog sends it; answers the read-back verdict, or <code>http code</code> of the refusal.</p>
ClassMethod SaveAdd(pLocale As %String, pName As %String, pInputFrom As %String = "", pOutputTo As %String = "") As %String
{
    Set tFields = {}
    If pInputFrom '= "" {
        Do tFields.%Set("InputFrom", pInputFrom, "string")
        Do tFields.%Set("OutputTo", pOutputTo, "string")
    }
    Set tSC = $ClassMethod(..#TABLESAVE, "Create", pLocale, pName, tFields, .tHttp, .tFault, .tViolations, .tReadBack)
    If +$Get(tViolations) > 0 Quit "violations " _ $List(tViolations(1), 2)
    If $$$ISERR(tSC) Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: "(none)")
}

/// <p>The Save routes answer JSON over the wire: Copy's <code>POST /locales</code> 201 with the new locale's id, its target and a matching read-back, then a taken
/// name 409 and a malformed one 400 with the published sentence; Add table's <code>POST /locale-properties</code> 201 with the row's target, then the same row 409 and
/// an unlisted locale 404.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Api.Router</code>'s <code>LocaleCreate</code> answers the Add table's Save -> the status and target legs go red.</p>
Method TestTheSaveRoutesAnswerJsonOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tCopy = {"Name": (..#COPYA), "Source": (..PreparedLocale), "Description": "over the wire"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locales", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tCopy.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Copy Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.readBack.verdict, ..#COPYA _ "|locale|instance|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the locale's id, its target and a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locales", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tCopy.%ToJSON(), "application/json")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ tRefusal.code _ "|" _ tRefusal.reason, "409|LOCALE.COPY.TAKEN|" _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.COPY.TAKEN"), "a taken name is 409 with the published sentence")
    Set tBad = {"Name": "yzzx", "Source": (..PreparedLocale)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locales", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tBad.%ToJSON(), "application/json")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ tRefusal.code _ "|" _ tRefusal.reason, "400|LOCALE.COPY.NAME|" _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.COPY.NAME"), "a malformed name is 400 with the published sentence")
    Set tAdd = {"Locale": (..#COPYA), "Name": "PatternTables:Latin2"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locale-properties", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tAdd.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Add table Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.target.scope, "locale-property|instance", "with the row's target")
    Do $$$AssertEquals(tAnswer.target.id, ..RowId(..#COPYA, "PatternTables:Latin2"), "whose id is the composite of the locale and the row")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locale-properties", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tAdd.%ToJSON(), "application/json")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ tRefusal.code _ "|" _ tRefusal.reason, "409|LOCALE.TABLE.TAKEN|" _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.TABLE.TAKEN"), "a listed table is 409 with the published sentence")
    Set tAdd = {"Locale": "yzzx", "Name": "PatternTables:Latin2"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/locale-properties", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tAdd.%ToJSON(), "application/json")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ tRefusal.code, "404|LOCALE.NOTFOUND", "a locale the instance does not list is 404")
}

/// <p><b>AC1.</b> The current locale is copied by both callers: the Save route's copy (a person's) and the agent's confirmed proposal each create a custom locale the
/// instance lists, whose definition equals the source's in everything but its name and description, with a read-back reading <code>matches</code>; a name the
/// instance lists is refused <code>LOCALE.COPY.TAKEN</code> at both before any vendor call, a malformed one <code>LOCALE.COPY.NAME</code> and an unlisted source
/// <code>LOCALE.NOTFOUND</code>.</p>
/// <p>Mutation (Rule 19): <code>Send</code>'s copy keeps the source's <code>Description</code> when one is sent -> the description assertions go red.</p>
Method TestTheCurrentLocaleIsCopiedOnBothCallersAndTheOthersAreRefused()
{
    Set tSource = ..PreparedLocale
    Do $ClassMethod(..#READ, "VendorGet", tSource, .tSourceProps)
    Do $$$AssertEquals(..SaveCopy(..#COPYA, tSource, "by a person"), "matches", "a person's Save copies the current locale and its read-back matches")
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tPerson)
    Do $$$AssertEquals(..Changed(.tSourceProps, .tPerson) _ "|" _ tPerson("Description"), "Description;|by a person", "its definition equals the source's but the description, which is the one typed")
    Do $$$AssertEquals(..SaveCopy(..#COPYA, tSource), "409 LOCALE.COPY.TAKEN", "a person's Save of a taken name is refused before any vendor call")
    Do $$$AssertEquals(..SaveCopy("yzzx", tSource) _ "|" _ ..VendorExists("yzzx"), "400 LOCALE.COPY.NAME|0", "a malformed name is refused and creates nothing")
    Do $$$AssertEquals(..SaveCopy(..#COPYB, "ynonew") _ "|" _ ..VendorExists(..#COPYB), "404 LOCALE.NOTFOUND|0", "a source the instance does not list is refused and creates nothing")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleCopy", ..#COPYB, {"Name": (..#COPYB), "Source": (tSource), "Description": "by the agent"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..VendorExists(..#COPYB), "200 |matches|1", "the agent's confirmed copy does the same: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYB, .tCopy)
    Do $$$AssertEquals(..Changed(.tSourceProps, .tCopy), "Description;", "its definition equals the source's but the description")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleCopy", ..#COPYA, {"Name": (..#COPYA), "Source": (tSource)}, .tResult), "refused: '" _ ..#COPYA _ "' is already present on this instance", "a taken name is refused at the agent's mint by the create's own read")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleCopy", "yzzx", {"Name": "yzzx", "Source": (tSource)}, .tResult) _ "|" _ ..VendorExists("yzzx"), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.COPY.NAME") _ "|0", "a malformed name is refused at the agent's mint and creates nothing")
}

/// <p><b>AC2.</b> A set, an add and a remove round-trip on both callers over <code>Modify</code>: the screen's actions and the agent's confirmed proposals set a date
/// format, add and remove an internal table and add and remove an input/output table of a copy, each read back, and the vendor's definition changes in that one
/// node alone. Removing a table the list defaults to is refused <code>LOCALE.TABLE.DEFAULT</code> at both before the vendor, which still lists it.</p>
/// <p>Mutation (Rule 19): the default check dropped from <code>LocaleRules.RemoveCode</code> -> the default rows go red.</p>
Method TestASetAnAddAndARemoveRoundTripOnBothCallers()
{
    Do $$$AssertEquals(..VendorCopy(..#COPYA), 1, "a copy is created as the test's own setup")
    Set tLocale = ..#COPYA
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tBefore)
    Set tStatus = ..Act(..#PROPERTYSCREEN, "set", ..RowId(tLocale, "DateFormat"), {"Value": "3"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|matches", "the screen's set changes the date format and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "DateFormat;", "only the date format changed")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocalePropertySet", "DateFormat", {"Locale": (tLocale), "Name": "DateFormat", "Value": "5"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |matches", "the agent's confirmed set changes it again: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "DateFormat;", "and only it")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tBefore)
    Do $$$AssertEquals(..SaveAdd(tLocale, "PatternTables:Latin2"), "matches", "a person's Save adds an internal table and its read-back matches")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "PatternTables:Latin2;", "only that member was added")
    Do $$$AssertEquals(..SaveAdd(tLocale, "PatternTables:Latin2"), "409 LOCALE.TABLE.TAKEN", "a person's Save of a listed table is refused before any vendor call")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "remove-table", ..RowId(tLocale, "PatternTables:Latin2"), "", .tAnswer) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|notFound", "the screen's remove-table drops it")
    Do $$$AssertEquals(..SaveAdd(tLocale, "XLTTables:myio2", "Latin2", "Latin2"), "matches", "a person's Save adds an input/output table with its two sides and its read-back matches")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter) _ "|" _ $ListToString($Get(tAfter("XLTTables", "myio2")), "|"), "XLTTables:myio2;|Latin2|" _ tAfter("CharacterSet") _ "|" _ tAfter("CharacterSet") _ "|Latin2", "with the locale's character set between them")
    Do $$$AssertEquals(..SaveAdd(tLocale, "XLTTables:myio3", "", "") _ "|" _ ..SaveAdd(tLocale, "PatternTables:Japanese", "Latin2", "Latin2"), "400 PORT.VALIDATION|400 PORT.VALIDATION", "an input/output table without its sides, and sides on another list, are refused")
    Do $$$AssertEquals(..SaveAdd("yzzx", "PatternTables:Latin2"), "404 LOCALE.NOTFOUND", "a locale the instance does not list is refused")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "remove-table", ..RowId(tLocale, "XLTTables:myio2"), "", .tAnswer) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|notFound", "the screen's remove-table drops it")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "and the definition is as it was")
    Set tRow = "PatternTables:Japanese"
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleTableAdd", tRow, {"Locale": (tLocale), "Name": (tRow)}, .tResult)
    Do $$$AssertEquals($Piece(tOutcome, " ", 1), "200", "the agent's confirmed add lists the table: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "PatternTables:Japanese;", "only that member was added")
    Do $$$AssertTrue(..Agent("OcuPilot.Screen.Tool.LocaleTableAdd", tRow, {"Locale": (tLocale), "Name": (tRow)}, .tResult) [ "is already present on this instance", "a table the locale lists is refused at the mint by the create's own read")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "remove-table", ..RowId(tLocale, tRow), "", .tAnswer) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|notFound", "the screen's remove-table drops it and reads it gone")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "and the definition is as it was")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleTableAdd", "XLTTables:myio", {"Locale": (tLocale), "Name": "XLTTables:myio", "InputFrom": "Latin2", "OutputTo": "Latin2"}, .tResult)
    Do $$$AssertEquals($Piece(tOutcome, " ", 1), "200", "the agent's confirmed add lists an input/output table: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter) _ "|" _ $ListToString($Get(tAfter("XLTTables", "myio")), "|"), "XLTTables:myio;|Latin2|" _ tAfter("CharacterSet") _ "|" _ tAfter("CharacterSet") _ "|Latin2", "with its two sides and the locale's character set")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleTableRemove", "XLTTables:myio", {"Locale": (tLocale), "Name": "XLTTables:myio"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |notFound", "the agent's confirmed remove drops it: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "and the definition is as it was")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "remove-table", ..RowId(tLocale, "PatternTables:Unicode"), "", .tAnswer) _ "|" _ ..Code(tAnswer), "409|LOCALE.TABLE.DEFAULT", "a table the list defaults to is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableRemove", "PatternTables:Unicode", {"Locale": (tLocale), "Name": "PatternTables:Unicode"}, .tResult), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.TABLE.DEFAULT"), "and at the agent's mint")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "the vendor still lists it")
}

/// <p><b>AC3.</b> The current locale is refused every change at both callers, before the vendor: a set, an add and a remove are 409 <code>LOCALE.EDIT.CURRENT</code> at the
/// screen and refused with its sentence at the agent's mint, and the locale's definition is as the class found it.</p>
/// <p>Mutation (Rule 19): <code>EditCode</code> answers <code>""</code> for the current locale -> every row goes red.</p>
Method TestTheCurrentLocaleIsRefusedEveryChangeAtBothCallers()
{
    Set tLocale = ..PreparedLocale
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tBefore)
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "set", ..RowId(tLocale, "DateFormat"), {"Value": "3"}, .tAnswer) _ "|" _ ..Code(tAnswer), "409|LOCALE.EDIT.CURRENT", "the screen's set is refused")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "remove-table", ..RowId(tLocale, "PatternTables:Latin1"), "", .tAnswer) _ "|" _ ..Code(tAnswer), "409|LOCALE.EDIT.CURRENT", "the screen's remove-table is refused")
    Set tSentence = ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.EDIT.CURRENT")
    Do $$$AssertEquals(..SaveAdd(tLocale, "PatternTables:Japanese"), "409 LOCALE.EDIT.CURRENT", "a person's Save of an add is refused")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocalePropertySet", "DateFormat", {"Locale": (tLocale), "Name": "DateFormat", "Value": "3"}, .tResult), "refused: " _ tSentence, "the agent's set is refused at the mint")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableAdd", "PatternTables:Japanese", {"Locale": (tLocale), "Name": "PatternTables:Japanese"}, .tResult), "refused: " _ tSentence, "so is its add")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableRemove", "PatternTables:Latin1", {"Locale": (tLocale), "Name": "PatternTables:Latin1"}, .tResult), "refused: " _ tSentence, "and its remove")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "the current locale's definition is as it was")
}

/// <p><b>AC4.</b> A table of a copy is loaded by both callers with the key on: the screen's load-table and the agent's confirmed proposal each load the table the copy lists as
/// loadable, reading <code>nothingSent</code>; a table the locale lists that is built in is refused <code>LOCALE.TABLE.NOTLOADABLE</code> at both before the vendor. With the
/// default baseline, which ships the key off, the agent's confirm is refused by governance and a person's load is not (AD-22).</p>
/// <p>Mutation (Rule 19): <code>osmgmt.localeproperties.load</code> true in the baseline -> the baseline rows go red.</p>
Method TestATableIsLoadedOnBothCallersAndTheDefaultBaselineRefusesIt()
{
    Do $$$AssertEquals(..VendorCopy(..#COPYA), 1, "a copy is created as the test's own setup")
    Set tLocale = ..#COPYA
    Set tRow = "PatternTables:Unicode"
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "load-table", ..RowId(tLocale, "PatternTables:Latin1"), "", .tAnswer) _ "|" _ ..Code(tAnswer), "409|LOCALE.TABLE.NOTLOADABLE", "a built-in table is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableLoad", "PatternTables:Latin1", {"Locale": (tLocale), "Name": "PatternTables:Latin1"}, .tResult), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.TABLE.NOTLOADABLE"), "and at the agent's mint")
    Set tStatus = ..Act(..#PROPERTYSCREEN, "load-table", ..RowId(tLocale, tRow), "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's load-table loads the table: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleTableLoad", tRow, {"Locale": (tLocale), "Name": (tRow)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |nothingSent", "the agent's confirmed load does the same: " _ tOutcome)
    Do ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableLoad", tRow, {"Locale": (tLocale), "Name": (tRow)}, .tResult), "403 GOVERNANCE.DISABLED", "with the default baseline the agent's confirm is refused by governance")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "load-table", ..RowId(tLocale, tRow), "", .tAnswer), 200, "a person's own click is not asked the key (AD-22), as the install and the delete are not")
}

/// <p><b>AC4.</b> A table a locale lists that the instance has not compiled is not loadable: after a person adds the pattern table <code>Japanese</code> to a copy,
/// its row reads <code>Loadable</code> false, and a load of it is refused <code>LOCALE.TABLE.NOTLOADABLE</code> (409, never 500) by the screen's action and at the
/// agent's mint, with nothing changed in the definition.</p>
/// <p>Mutation (Rule 19): <code>PropertyRows</code> without its <code>TableLoadable</code> check -> the row reads loadable and the screen's load answers 500.</p>
Method TestATableTheInstanceHasNotCompiledIsNotLoadableAndIsRefused()
{
    Do $$$AssertEquals(..VendorCopy(..#COPYA), 1, "a copy is created as the test's own setup")
    Set tLocale = ..#COPYA
    Set tRow = "PatternTables:Japanese"
    Do $$$AssertEquals(..SaveAdd(tLocale, tRow), "matches", "a person's Save lists the table, as the instance's own table list allows")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tBefore)
    Set tCount = $ClassMethod(..#READ, "Rows", tLocale, .tRows, .tWhy)
    Do $$$AssertTrue(tCount > 0 && $Data(tRows(tRow)), "the port lists its row: " _ tWhy)
    If $Data(tRows(tRow)) Do $$$AssertEquals(''tRows(tRow).%Get("Loadable"), 0, "the row of a table the instance has not compiled reads not loadable")
    Do $$$AssertEquals(..Act(..#PROPERTYSCREEN, "load-table", ..RowId(tLocale, tRow), "", .tAnswer) _ "|" _ ..Code(tAnswer), "409|LOCALE.TABLE.NOTLOADABLE", "the screen's load of it is refused, not a server error")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleTableLoad", tRow, {"Locale": (tLocale), "Name": (tRow)}, .tResult), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.TABLE.NOTLOADABLE"), "and so is the agent's at the mint")
    Do $ClassMethod(..#READ, "VendorGet", tLocale, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "the definition is as it was")
}

}
