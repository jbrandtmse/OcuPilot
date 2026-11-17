/// <p>Pins Story 21.14's writes on both callers (AC1, AC3, AC4; AD-4, AD-6, AD-15, AD-53, AD-58) against the real instance: the locale-format switch set by the
/// screen's own action route (<class>OcuPilot.Test.EcpActionFixture</class>) and by the agent's mint and confirm (<class>OcuPilot.Test.LicenseProbe</class>), with the
/// current locale reloaded; another locale installed by both callers and the original installed again, the answer naming the collation of IRISTEMP before and
/// after; a custom locale the class creates deleted by both, and a locale InterSystems ships, the current locale and an unlisted name refused 409 or 404 before the
/// vendor's delete, which would carry them out; a configured table read as configured; Validate's verdict and counts read from the vendor's <code>IsValid</code>
/// for a custom definition it accepts and one it refuses; and Validate and the install mint leaving <code>^SYS("NLS")</code> as it was, on a locale whose vendor install
/// check writes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, and a second locale the
/// instance can install (<parameter>OTHER</parameter>), because the class installs locales, creates and deletes one, sets the locale-format switch and a configured table
/// and sets the governance policy. Every test restores the current locale, the switch and the configured table it found, and deletes the custom locale it made, on
/// every path (<method>Restore</method>).</p>
Class OcuPilot.Test.LocaleWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.LocalePort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter READ = "OcuPilot.Test.LocaleRead";

Parameter DEFAULTSSCREEN = "osmgmt.nlsdefaults";

Parameter LOCALESCREEN = "osmgmt.locales";

Parameter KEYS = "osmgmt.nlsdefaults.set,osmgmt.locales.install,osmgmt.locales.delete";

/// <p>The locale the install tests switch to, which a person's own instance lists and whose date format differs from the original's, and the custom locale the
/// class creates.</p>
Parameter OTHER = "deuw";

Parameter CUSTOM = "yzzw";

/// <p>A custom locale whose name the vendor's <code>IsValid</code> refuses (it is not a <code>y</code>, a language and a character set).</p>
Parameter REFUSEDCUSTOM = "yzzp";

/// <p>The configured table the read test sets, a <code>CSP</code> translation table every locale of this build lists.</p>
Parameter CONFIGURED = "CP1252";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The current locale, the switch's node (<code>$Data</code>, then its value) and the configured <code>CSP</code> node (<code>$Data</code>, then its value) as the
/// class found them.</p>
Property PreparedLocale As %String [ InitialExpression = "" ];

Property PreparedNode As %String [ InitialExpression = "" ];

Property PreparedCsp As %String [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LocaleWrite installs locales, creates and deletes one and sets the locale-format switch and a configured table on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Do ..VendorFind(.tLocale, .tNode, .tCsp)
    Set ..PreparedLocale = tLocale
    Set ..PreparedNode = tNode
    Set ..PreparedCsp = tCsp
    Do ..VendorRemoveCustom()
    Do ..Sys("RemoveCustom", ..#REFUSEDCUSTOM)
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Kill tSettings
    For tI = 1:1:$Length(..#KEYS, ",") Set tSettings($Piece(..#KEYS, ",", tI)) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Do ..Sys("RestoreLocales", 1)
    Do $$$AssertEquals(..VendorExists(..#CUSTOM) _ ..VendorExists(..#REFUSEDCUSTOM), "00", "the custom locales are gone")
    Do $$$AssertEquals(..VendorCurrent() _ "|" _ ..VendorNodeText() _ "|" _ ..VendorCspText(), ..PreparedLocale _ "|" _ ..PreparedNode _ "|" _ ..PreparedCsp, "the current locale, the switch and the configured table are as the class found them")
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

/// <p>Put back what the class found: the custom locale deleted, the original locale current, the switch's node and the configured table as they were, and the
/// current locale reloaded when the node or the locale moved.</p>
Method Restore()
{
    Set tMoved = (..VendorCurrent() '= ..PreparedLocale)
    If tMoved Do ..VendorInstall(..PreparedLocale)
    Do ..VendorRemoveCustom()
    Do ..Sys("RemoveCustom", ..#REFUSEDCUSTOM)
    If ..VendorNodeText() '= ..PreparedNode {
        Do ..VendorSetNode(..PreparedNode)
        Set tMoved = 1
    }
    Do ..VendorSetCsp(..PreparedCsp)
    If tMoved Do ..VendorReload()
}

/// <p>The helper call <var>pMethod</var> of <class>OcuPilot.Test.LocaleWriteVendor</class> with <var>pArg</var>, answering what it answers.</p>
ClassMethod Sys(pMethod As %String, pArg As %String = "") As %String
{
    Quit $ClassMethod("OcuPilot.Test.LocaleWriteVendor", pMethod, pArg)
}

ClassMethod VendorFind(Output pLocale As %String, Output pNode As %String, Output pCsp As %String)
{
    Set pLocale = ..VendorCurrent()
    Set pNode = ..VendorNodeText()
    Set pCsp = ..VendorCspText()
}

ClassMethod VendorCurrent() As %String
{
    Quit ..Sys("Current")
}

/// <p>The switch's node as <code>""</code> when it is not defined, else <code>=value</code>.</p>
ClassMethod VendorNodeText() As %String
{
    Quit ..Sys("NodeText")
}

ClassMethod VendorCspText() As %String
{
    Quit ..Sys("CspText")
}

ClassMethod VendorSetNode(pText As %String) As %String
{
    Quit ..Sys("SetNode", pText)
}

ClassMethod VendorSetCsp(pText As %String) As %String
{
    Quit ..Sys("SetCsp", pText)
}

ClassMethod VendorExists(pName As %String) As %Boolean
{
    Quit ''..Sys("Exists", pName)
}

ClassMethod VendorCreate(pName As %String) As %String
{
    Quit ..Sys("Create", pName)
}

ClassMethod VendorInstall(pName As %String) As %String
{
    Quit ..Sys("Install", pName)
}

ClassMethod VendorReload() As %String
{
    Quit ..Sys("Reload")
}

ClassMethod VendorRemoveCustom() As %String
{
    Quit ..Sys("RemoveCustom", ..#CUSTOM)
}

ClassMethod VendorCollation() As %String
{
    Quit ..Sys("Collation")
}

/// <p>The decimal separator the instance's formats give a process now.</p>
ClassMethod VendorDecimal() As %String
{
    Quit ..Sys("Decimal")
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> of screen <var>pScreen</var> through the action fixture, with <var>pValues</var>; the answer's parsed
/// envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> of screen <var>pScreen</var> over the web application, as <method>Act</method>. An install runs the
/// vendor's own install in the request's process, which resets the process's device state, so the action fixture's in-process capture of the answer does not survive
/// it; a request to the web application does.</p>
ClassMethod ActHttp(pScreen As %String, pAction As %String, pId As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action", .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with <var>pArgs</var> and confirm it; answers <code>http code</code> and the confirm's answer in <var>pResult</var>, or
/// <code>refused: &lt;problem&gt;</code> when the mint refused.</p>
ClassMethod Agent(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    ; The confirm fixture's port is the shipped one the tool declares, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, pArgs, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", tProposal, .pResult)
}

/// <p>Whether the port reads <var>pName</var> as the current locale: <code>1</code>, <code>0</code>, or <code>-1</code> when it is not listed.</p>
ClassMethod IsCurrent(pName As %String) As %Integer
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): ''tRow.%Get("Current"), 1: -1)
}

/// <p>The switch's row as the port reads it: <code>Value|Source</code>.</p>
ClassMethod SwitchRow() As %String
{
    Kill tQuery
    Set tQuery("name") = "LocaleFormat"
    Set tSC = $ClassMethod("OcuPilot.Port.ConfigPort", "Invoke", "NLSDefaults", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("Value") _ "|" _ tRow.%Get("Source"), 1: "(none: " _ $Get(tHttp) _ ")")
}

/// <p><b>AC1.</b> The locale-format switch round-trips over its node on both callers: the screen's Set value and the agent's confirmed proposal each write the
/// node, the current locale is reloaded (the instance's decimal separator follows, the other locale's being a comma), and the read-back reads <code>matches</code>; a
/// table row's set is refused <code>CONFIG.SETTING.READONLY</code> at both before the vendor is called, and the node stays as it was.</p>
/// <p>Mutation (Rule 19): <code>ReloadAfterSet</code> reloads nothing -> the separator assertions go red; <code>Apply</code> writes the value 1 whatever it is given ->
/// the screen's turn-off row goes red.</p>
Method TestTheSwitchRoundTripsOverTheNodeAndReloadsOnBothCallers()
{
    Do $$$AssertEquals(..VendorInstall(..#OTHER), 1, "the other locale is installed as the test's own setup")
    Do ..VendorSetNode("=0")
    Do ..VendorReload()
    Do $$$AssertEquals(..VendorDecimal(), ".", "its own separator is a comma and the standard one a point: with the switch off a process reads the point")
    Set tStatus = ..Act(..#DEFAULTSSCREEN, "set", "LocaleFormat", {"Value": "1"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|matches", "the screen's set writes the switch and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..VendorNodeText() _ "|" _ ..SwitchRow() _ "|" _ ..VendorDecimal(), "=1|1|config|,", "the node holds 1, the row reads it as configured, and the reloaded locale gives the comma")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.NlsDefaultSet", "LocaleFormat", {"Name": "LocaleFormat", "Value": "0"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |matches", "the agent's confirmed set turns it off and reads it back: " _ tOutcome)
    Do $$$AssertEquals(..VendorNodeText() _ "|" _ ..SwitchRow() _ "|" _ ..VendorDecimal(), "=0|0|config|.", "the node holds 0, still defined, and the point is back")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.NlsDefaultSet", "LocaleFormat", {"Name": "LocaleFormat", "Value": "1"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..VendorDecimal(), "200 |,", "the agent's confirmed set turns it on")
    Set tStatus = ..Act(..#DEFAULTSSCREEN, "set", "LocaleFormat", {"Value": "0"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..VendorDecimal(), "200|.", "and the screen's turns it off")
    Set tBefore = ..VendorNodeText()
    Do $$$AssertEquals(..Act(..#DEFAULTSSCREEN, "set", "Accent", {"Value": "Unicode"}, .tAnswer) _ "|" _ ..Code(tAnswer) _ "|" _ ..VendorNodeText(), "409|CONFIG.SETTING.READONLY|" _ tBefore, "a table row's set is refused at the screen before the vendor")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.NlsDefaultSet", "Accent", {"Name": "Accent", "Value": "Unicode"}, .tResult), "refused: " _ ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.READONLY"), "and at the agent's mint")
}

/// <p><b>AC1.</b> A configured table wins over the current locale's and its source reads <code>config</code>: with the configured <code>CSP</code> table set, the read
/// answers it, and when it is cleared the row is the default <code>UTF8</code> from the locale again.</p>
/// <p>Mutation (Rule 19): <code>CollectNls</code> answers the locale's table even when a configured one is set -> the configured row goes red.</p>
Method TestAConfiguredTableWinsOverTheLocalesAndSaysConfig()
{
    Do $$$AssertEquals(..VendorSetCsp(..#CONFIGURED), 1, "a configured CSP table is set as the test's own setup")
    Set tResult = ##class(OcuPilot.Test.NlsDefaultRead).Read(.tHttp)
    Do ##class(OcuPilot.Test.NlsDefaultRead).RowsByName(tResult, .tRows)
    Do $$$AssertEquals($Select($Data(tRows("CSP")): tRows("CSP").%Get("Value") _ "|" _ tRows("CSP").%Get("Source") _ "|" _ tRows("CSP").%Get("ReadOnly"), 1: "none"), ..#CONFIGURED _ "|config|1", "the configured table is read as configured, and still shown and never changed")
    Do $$$AssertEquals(..VendorSetCsp(""), 1, "it is cleared")
    Set tResult = ##class(OcuPilot.Test.NlsDefaultRead).Read(.tHttp)
    Do ##class(OcuPilot.Test.NlsDefaultRead).RowsByName(tResult, .tRows)
    Do $$$AssertEquals($Select($Data(tRows("CSP")): tRows("CSP").%Get("Value") _ "|" _ tRows("CSP").%Get("Source"), 1: "none"), "UTF8|locale", "and the default UTF8 from the locale reads again")
}

/// <p><b>AC3.</b> Another locale is installed by both callers and the original installed again: the screen's install and the agent's confirmed one each make the
/// locale current (the port's <code>Current</code> reads it, the vendor's own current locale names it) with a read-back reading <code>nothingSent</code>; the port's own
/// answer names the collation of IRISTEMP before and after, each equal to the collation read around the call; an install of the current locale is a reload.</p>
/// <p>Mutation (Rule 19): <code>SendInstall</code> installs the locale the list names first -> the current assertions go red; <code>TempCollation</code> answers its first read
/// twice -> the after assertion goes red.</p>
Method TestAnotherLocaleIsInstalledOnBothCallersAndTheOriginalComesBack()
{
    Set tOriginal = ..PreparedLocale
    Set tBefore = ..VendorCollation()
    Kill tQuery
    Set tQuery("name") = ..#OTHER
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "INSTALL", .tQuery, "", .tOut, .tHttp, .tFault)
    Set tAfter = ..VendorCollation()
    Do $$$AssertEquals(tHttp _ "|" _ tOut.%Get("Name") _ "|" _ tOut.%Get("TempCollationBefore") _ "|" _ tOut.%Get("TempCollationAfter"), "200|" _ ..#OTHER _ "|" _ tBefore _ "|" _ tAfter, "the port's answer names IRISTEMP's collation before and after the install")
    Do $$$AssertEquals(..IsCurrent(..#OTHER) _ "|" _ ..IsCurrent(tOriginal) _ "|" _ ..VendorCurrent(), "1|0|" _ ..#OTHER, "the other locale is current")
    Set tStatus = ..ActHttp(..#LOCALESCREEN, "install", tOriginal, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..IsCurrent(tOriginal) _ "|" _ ..VendorCurrent(), "200|nothingSent|1|" _ tOriginal, "the screen's install makes the original current again: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleInstall", ..#OTHER, {"Name": (..#OTHER)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..IsCurrent(..#OTHER), "200 |nothingSent|1", "the agent's confirmed install makes the other locale current: " _ tOutcome)
    Set tStatus = ..ActHttp(..#LOCALESCREEN, "install", ..#OTHER, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..IsCurrent(..#OTHER), "200|1", "an install of the current locale is allowed")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleInstall", tOriginal, {"Name": (tOriginal)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..IsCurrent(tOriginal) _ "|" _ ..VendorCurrent(), "200 |1|" _ tOriginal, "and the agent's confirmed install puts the original back")
    Do $$$AssertEquals(..Act(..#LOCALESCREEN, "install", "NoSuchLocale", "", .tAnswer) _ "|" _ ..Code(tAnswer) _ "|" _ ..VendorCurrent(), "404|LOCALE.NOTFOUND|" _ tOriginal, "an unlisted name is refused at the screen and installs nothing")
}

/// <p><b>AC4.</b> A custom locale the class creates is deleted by both callers: the screen's delete and the agent's confirmed one each remove it, the read-back reads
/// <code>notFound</code> and the vendor no longer holds it. A locale InterSystems ships and the current locale are refused 409 <code>LOCALE.SYSTEM</code> and
/// <code>LOCALE.CURRENT</code> at both callers, and an unlisted name 404, each before the vendor's delete: the vendor refuses none of them. The custom locale made
/// current is refused as current, and deleted once the original is current again.</p>
/// <p>Mutation (Rule 19): the <code>y</code> check dropped from <code>Code</code> -> the system rows go red (the throwaway's own locale list shows nothing was deleted
/// by the refused rows, because the class never asks the vendor for them).</p>
Method TestACustomLocaleIsDeletedOnBothCallersAndTheOthersAreRefused()
{
    Set tOriginal = ..PreparedLocale
    Do $$$AssertEquals(..VendorCreate(..#CUSTOM), 1, "the custom locale is created from the original's definition, as the test's own setup")
    Do $$$AssertEquals(..VendorExists(..#CUSTOM), 1, "it exists")
    Kill tQuery
    Set tQuery("name") = ..#CUSTOM
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.%Get("Custom") _ "|" _ tRow.%Get("Current"), 1: "none"), "1|0", "the port lists it as custom and not current")
    Do $$$AssertEquals(..Act(..#LOCALESCREEN, "delete", tOriginal, "", .tAnswer) _ "|" _ ..Code(tAnswer) _ "|" _ ..VendorExists(tOriginal), "409|LOCALE.SYSTEM|1", "the screen's delete of the current system locale is refused and it stays")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleDelete", tOriginal, {"Name": (tOriginal)}, .tResult) _ "|" _ ..VendorExists(tOriginal), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.SYSTEM") _ "|1", "and so is the agent's")
    Do $$$AssertEquals(..Act(..#LOCALESCREEN, "delete", "NoSuchLocale", "", .tAnswer) _ "|" _ ..Code(tAnswer), "404|LOCALE.NOTFOUND", "an unlisted name is 404 at the screen")
    Do $$$AssertEquals(..VendorInstall(..#CUSTOM), 1, "the custom locale is made current, as the test's own setup")
    Do $$$AssertEquals(..Act(..#LOCALESCREEN, "delete", ..#CUSTOM, "", .tAnswer) _ "|" _ ..Code(tAnswer) _ "|" _ ..VendorExists(..#CUSTOM), "409|LOCALE.CURRENT|1", "the screen's delete of the current custom locale is refused")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleDelete", ..#CUSTOM, {"Name": (..#CUSTOM)}, .tResult) _ "|" _ ..VendorExists(..#CUSTOM), "refused: " _ ##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.CURRENT") _ "|1", "and so is the agent's")
    Do $$$AssertEquals(..VendorInstall(tOriginal), 1, "the original is current again")
    Set tStatus = ..Act(..#LOCALESCREEN, "delete", ..#CUSTOM, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..VendorExists(..#CUSTOM), "200|notFound|0", "the screen's delete removes it and the read-back reads it gone: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tGone, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404|LOCALE.NOTFOUND", "the port reads it as unlisted")
    Do $$$AssertEquals(..VendorCreate(..#CUSTOM), 1, "it is created again")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleDelete", ..#CUSTOM, {"Name": (..#CUSTOM)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..VendorExists(..#CUSTOM), "200 |notFound|0", "the agent's confirmed delete removes it too: " _ tOutcome)
    Do $$$AssertEquals(..VendorCurrent() _ "|" _ ..VendorExists(tOriginal), tOriginal _ "|1", "the original locale was never touched")
}

/// <p><b>AC2.</b> Validate's verdict and counts are the vendor's <code>IsValid</code> answer: for a custom locale made from the current one, which <code>IsValid</code>
/// accepts, the port reads <code>Valid</code> true; for one whose name it refuses, <code>Valid</code> false with at least one error counted, and in both the answer holds
/// the vendor's own counts and no line.</p>
/// <p>Mutation (Rule 19): <code>ReadValidation</code> answers <code>Valid</code> true whatever <code>IsValid</code> says -> the refused-name row goes red.</p>
Method TestValidateReadsIsValidsAnswerForAnAcceptedAndARefusedDefinition()
{
    Do $$$AssertEquals(..VendorCreate(..#CUSTOM), 1, "a custom locale is created from the current one, as the test's own setup")
    Do $$$AssertEquals(..VendorCreate(..#REFUSEDCUSTOM), 1, "and one whose name IsValid refuses")
    Set tAccepted = $ClassMethod(..#READ, "VendorChecks", ..#CUSTOM)
    Set tRefused = $ClassMethod(..#READ, "VendorChecks", ..#REFUSEDCUSTOM)
    Do $$$AssertEquals($Piece(tAccepted, "|", 1), 1, "IsValid accepts the locale made from the current one")
    Do $$$AssertEquals($Piece(tRefused, "|", 1) _ "|" _ ($Piece(tRefused, "|", 2) > 0), "0|1", "and refuses the other with at least one error")
    For tName = ..#CUSTOM, ..#REFUSEDCUSTOM {
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Validation", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, "the port validates " _ tName)
        If '$IsObject($Get(tAnswer)) Continue
        Set tChecks = $Select(tName = ..#CUSTOM: tAccepted, 1: tRefused)
        Do $$$AssertEquals(tAnswer.%Get("Valid") _ "|" _ tAnswer.%Get("ErrorCount") _ "|" _ tAnswer.%Get("WarningCount"), tChecks, tName _ ": Valid and the counts are IsValid's own")
        Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tAnswer), "ErrorCount,Name,Valid,WarningCount", tName _ ": the answer holds no line")
    }
}

/// <p><b>AC2, AC3.</b> Validate and the install mint write nothing, on a locale whose vendor install check writes. Every locale's definition is copied first and put
/// back after the test on every path (<method>OnAfterOneTest</method>). The control comes next: the vendor's own <code>IsInstallable</code> of <code>jpnw</code>, one of
/// the nine shipped locales whose check fills two accent-table fields of its definition, moves the checksum of <code>^SYS("NLS")</code> on this instance, and the
/// definitions are put back. Then the port's validation of every listed locale, each <code>Valid</code> and count equal to the vendor's <code>IsValid</code>, the
/// screen's route, the agent's tool and the install tool's mint for <code>jpnw</code> leave the checksum as it was.</p>
/// <p>Mutation (Rule 19): <code>ReadValidation</code> also calls <code>IsInstallable</code> -> the checksum assertion goes red; <code>ReadValidation</code> also requires
/// <code>IsLoadable</code> -> the per-locale verdict assertion goes red.</p>
Method TestValidateAndTheInstallMintLeaveTheNlsDefinitionsAsTheyWere()
{
    Set tLocale = "jpnw"
    Set tNames = $ClassMethod(..#READ, "VendorList", .tCurrent)
    Do $$$AssertTrue(("," _ tNames _ ",") [ ("," _ tLocale _ ","), tLocale _ " is a locale this instance lists")
    Set tBefore = ..Sys("SnapLocales")
    Do $$$AssertNotEquals(tBefore, "error", "the definitions are copied and their checksum read")
    Do ..Sys("Installable", tLocale)
    Set tControl = ..Sys("NlsState")
    Do $$$AssertNotEquals(tControl, tBefore, "control: the vendor's install check writes " _ tLocale _ " on this instance, so the checksum below can move")
    Do $$$AssertEquals(..Sys("RestoreLocales"), tBefore, "and the control's write is put back")
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Validation", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Set tGot = tHttp _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("Valid") _ "|" _ tAnswer.%Get("ErrorCount") _ "|" _ tAnswer.%Get("WarningCount"), 1: "")
        Set tWant = "200|" _ $ClassMethod(..#READ, "VendorChecks", tName)
        If tGot '= tWant Do $$$AssertEquals(tGot, tWant, "the port validates " _ tName _ " with IsValid's own verdict and counts")
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/locales/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tLocale) _ "/validation", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the screen's route validates " _ tLocale)
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.LocaleValidate", "View", "", {"name": (tLocale)}, 100, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(tToolHttp, 200, "the agent's tool validates " _ tLocale)
    Set tSC = $ClassMethod("OcuPilot.Area.OsMgmt.LocaleRules", "WriteProblem", "OcuPilot.Screen.Tool.LocaleInstall", tLocale, {}, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tProblem, "1|", "the install tool's mint admits it")
    Do $$$AssertEquals(..Sys("NlsState"), tBefore, "^SYS(""NLS"") is as it was after Validate on every listed locale and on the other paths, and an install mint")
}

}
