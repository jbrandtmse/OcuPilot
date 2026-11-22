/// <p>Pins Story 24.15's Compare default settings (DW-2636) against probe system default settings in <code>USER</code> and
/// <code>HSCUSTOM</code> (AD-5, AD-29, AD-36, AD-62): the screen's read route over the wire, the read tool
/// <code>interop.defaultsettingsdiff.read</code> and the port list exactly the settings held in one namespace only, and those held in both
/// with a different value, description or deployable flag, and not those held alike; the other namespace's side swaps with the route's;
/// a side with more settings than a comparison covers is refused <code>INTEROP.DEFAULTSETTING.TOOMANY</code> naming it; and the two new
/// screens' declarations are the ones the plan places.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP
/// test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every setting it creates in both.</p>
Class OcuPilot.Test.InteropDefaultSettingDiff Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropDefaultSettingSeam";

Parameter PRODUCTION = "OcuProbe2415.Production";

Parameter SCREEN = "/screens/interop.defaultsettingsdiff";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropDefaultSettingDiff writes probe system default settings in USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe settings are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION) + $ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION, "HSCUSTOM"), 0, "and none survives in either namespace")
    Quit $$$OK
}

/// <p>The comparison's probe rows as <code>setting:change:value:othervalue</code> in key order, read from <var>pRows</var>.</p>
ClassMethod Summary(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject($Get(pRows)) Quit "<no rows>"
    For tI = 0:1:pRows.%Size() - 1 {
        Set tRow = pRows.%Get(tI)
        If tRow.Production '= ..#PRODUCTION Continue
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Setting _ ":" _ tRow.Change _ ":" _ tRow.Value _ ":" _ tRow.OtherValue
    }
    Quit tText
}

/// <p>Probe settings: one held in <code>USER</code> only, one in <code>HSCUSTOM</code> only, one in both with different values, one in both
/// that differs by its description alone, one by its flag alone, and one held alike (<code>Same</code>).</p>
ClassMethod Arrange() As %Status
{
    Set tFixture = ..#FIXTURE
    Set tP = ..#PRODUCTION
    Set tSC = $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "OnlyHere", "1", "d")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "OnlyThere", "9", "d", 0, "HSCUSTOM"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Value", "1", "d"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Value", "2", "d", 0, "HSCUSTOM"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Words", "same", "here"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Words", "same", "there", 0, "HSCUSTOM"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Flag", "same", "d", 1))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Flag", "same", "d", 0, "HSCUSTOM"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Same", "same", "d", 1))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFixture, "PutDefault", tP, "*", "*", "Same", "same", "d", 1, "HSCUSTOM"))
    Quit tSC
}

/// <p>AC4 (Integration, Rule 1): the comparison lists exactly the only-here, only-there and differing settings, from the port, the screen's
/// read route and the read tool alike, in key order, with the values shown; the setting held alike is not listed, and swapping the route's
/// namespace with the other swaps each setting's side.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListDefaultSettingDiff</method> compare the values alone -- the description
/// and flag rows go red.</p>
Method TestTheDiffListsEachDifferenceAndNotTheSameSetting()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe settings are arranged")
    Set tWant = "Flag:differs:same:same;OnlyHere:only here:1:;OnlyThere:only there::9;Value:differs:1:2;Words:differs:same:same"
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("target") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the port answers 200")
    Do $$$AssertEquals(..Summary(tRows), tWant, "and lists the five differing settings with their values, and not the one held alike")
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "GET", ..#SCREEN _ "/read?target=HSCUSTOM&maxRows=1000", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's read route answers 200")
    Do $$$AssertEquals(..Summary($Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: "")), tWant, "and lists the same rows")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.defaultsettingsdiff.read", .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), "the derived read tool is registered")
    If $IsObject($Get(tTool)) {
        Do ##class(OcuPilot.Kernel.Scope).Set("USER")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"target": "HSCUSTOM"}, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(+$Get(tToolHttp), 200, "the read tool answers 200: " _ $Select($IsObject($Get(tToolFault)): tToolFault.%ToJSON(), 1: ""))
        Do $$$AssertEquals(..Summary($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")), tWant, "and lists the same rows")
    }
    Kill tQuery
    Set tQuery("namespace") = "HSCUSTOM"
    Set tQuery("target") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tSwapped, .tHttp, .tFault)
    Do $$$AssertEquals(..Summary(tSwapped), "Flag:differs:same:same;OnlyHere:only there::1;OnlyThere:only here:9:;Value:differs:2:1;Words:differs:same:same", "read from HSCUSTOM, each setting's side swaps")
}

/// <p>AC4: a comparison with no difference answers no rows, and a comparison is read-only: it writes nothing in either namespace.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListDefaultSettingDiff</method> list the settings held alike -- this goes red.</p>
Method TestTwoNamespacesHoldingTheSameSettingsHaveNoDifference()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "Same", "same", "d", 1), "a setting is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "Same", "same", "d", 1, "HSCUSTOM"), "and alike in HSCUSTOM")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("target") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Summary(tRows), "200|", "no probe row is listed")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION) + $ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION, "HSCUSTOM"), 2, "and the read wrote nothing")
}

/// <p>AC4: a side with more settings than a comparison covers is refused <code>INTEROP.DEFAULTSETTING.TOOMANY</code> with the published
/// sentence, naming that side's namespace, and lists no row. The cap is lowered to two by a seam.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DefaultSettingSide</method> keep every row -- both legs go red.</p>
Method TestASideOverTheCapIsRefusedNamingItsNamespace()
{
    Set tFixture = ..#FIXTURE
    For tSetting = "A", "B", "C" {
        Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", tSetting, "1"), "the probe setting " _ tSetting _ " is held in USER")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("target") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.detail.namespace _ " " _ tFault.reason, 1: ""), "409 INTEROP.DEFAULTSETTING.TOOMANY USER " _ $Parameter("OcuPilot.Api.InteropError", "REASONDEFAULTSETTINGTOOMANY"), "the route's side is refused naming USER, with the published sentence")
    Set tQuery("namespace") = "HSCUSTOM"
    Set tQuery("target") = "USER"
    ; The route's own side is read first, so the namespace named follows from what HSCUSTOM holds against the seam's cap.
    Set tHscCount = $ClassMethod(tFixture, "DefaultCount", "", "HSCUSTOM")
    Set tNamed = $Select(tHscCount > $Parameter(..#SEAM, "DEFAULTSETTINGSIDEMAX"): "HSCUSTOM", 1: "USER")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.detail.namespace, 1: ""), "409 INTEROP.DEFAULTSETTING.TOOMANY " _ tNamed, "and the refused side is the first over the cap, read from HSCUSTOM's " _ tHscCount _ " settings: " _ tNamed)
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("target") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "while the shipped cap covers the same three")
}

/// <p>AC4: the two new screens are declared as the plan places them: the list at side bar 12 with its composite key, its New default setting
/// and its Edit and Remove, over <code>%Ens_SystemDefaultConfig:READ</code>; the comparison at side bar 13 with no action, the one criterion
/// <code>target</code> and no classic page. Both are in the Interoperability area and name the entity type <code>default-setting</code>.</p>
/// <p>Mutation (Rule 19): change the comparison's <code>sideBarPosition</code> to 12 -- this goes red.</p>
Method TestTheTwoDeclarationsRegister()
{
    For tCase = $ListBuild("InteropDefaultSettingList", "interoperability/default-settings", 12, "list", "add", "edit,remove", "EnsPortal.DefaultSettings", "interop.defaultsettings"), $ListBuild("InteropDefaultSettingDiff", "interoperability/default-settings-diff", 13, "list (server criteria)", "", "", "", "interop.defaultsettingsdiff") {
        Set tClass = "OcuPilot.Screen.Descriptor." _ $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " declares JSON")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4) _ "|interoperability", $List(tCase, 1) _ ": its route, place, archetype and area")
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON() _ "|" _ tDeclaration.toolIdentifier, "default-setting|composite|[""Production"",""Item"",""HostClass"",""Setting""]|" _ $List(tCase, 8), $List(tCase, 1) _ ": its entity type, its composite key and its tool identifier")
        Do $$$AssertEquals(tDeclaration.primaryAction.id, $List(tCase, 5), $List(tCase, 1) _ ": its primary action")
        Set tRows = ""
        For tI = 0:1:tDeclaration.rowActions.%Size() - 1 {
            Set tRows = tRows _ $Select(tRows = "": "", 1: ",") _ tDeclaration.rowActions.%Get(tI).id
        }
        Do $$$AssertEquals(tRows, $List(tCase, 6), $List(tCase, 1) _ ": its row actions")
        Do $$$AssertEquals(tDeclaration.classicPage, $List(tCase, 7), $List(tCase, 1) _ ": its classic page")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_SystemDefaultConfig"",""permission"":""READ""}]", $List(tCase, 1) _ ": its pairs are the classic page's")
        Kill tDeclaration
    }
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropDefaultSettingDiff).DeclarationJson(.tDiff)
    Set tCriteria = tDiff.read.criteria.fields
    Do $$$AssertEquals(tCriteria.%Size() _ "|" _ tCriteria.%Get(0).param, "1|target", "the comparison's one criterion is the other namespace")
}

}
