/// <p>Pins every refusal of Story 20.22's two setting writes and of the Settings read (AD-39, AD-51, AD-53, AD-55,
/// AD-62): a value the declaring class refuses or one with a space at either end; a set of the value the production
/// already holds; a Core setting a system default decides; a reset of a setting that holds no value of its own and of
/// an item's own property; a setting the item does not declare and <code>Enabled</code>; a name two items bear; a
/// namespace under source control; a body of the wrong shape; and an id that names no setting. Each is refused by its
/// own code through the port, the agent's mint and the person's row action, and each refusal comes before any vendor
/// call: the stored settings, the production class and the vendor's audit trail are as they were.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropSettingControl</class>, whose helpers it
/// calls. It starts no production and runs one class per run.</p>
Class OcuPilot.Test.InteropSettingRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropSettingSeam";

Parameter SETTOOL = "OcuPilot.Screen.Tool.InteropSettingSet";

Parameter RESETTOOL = "OcuPilot.Screen.Tool.InteropSettingReset";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingRefusals compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Quit $ClassMethod(..#CONTROL, "Reset")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left with its settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p><var>pType</var> (<code>SET</code> or <code>RESET</code>) of the probe operation's <var>pTarget</var>/<var>pName</var>
/// through the port, as <code>http code</code>.</p>
ClassMethod ByPort(pType As %String, pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, pItem As %String = {$Parameter("OcuPilot.Test.InteropSettingControl", "OPNAME")}) As %String
{
    Set tBody = $Select(pValue = $Char(0): "", 1: {})
    If pValue '= $Char(0) Do tBody.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", pType, $ClassMethod(..#CONTROL, "IdOf", pTarget, pName, pItem), tBody, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault)
}

/// <p>The agent's call of the set (<var>pType</var> <code>SET</code>) or the reset, as <code>http code</code> and, for
/// a refused argument, its problem sentence in <var>pProblem</var>; <code>minted</code> when it earned a proposal.</p>
ClassMethod ByMint(pType As %String, pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, Output pProblem As %String, pItem As %String = {$Parameter("OcuPilot.Test.InteropSettingControl", "OPNAME")}) As %String
{
    Set pProblem = ""
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", pTarget, pName, pValue, pItem)
    Set tTool = $Select(pType = "SET": ..#SETTOOL, 1: ..#RESETTOOL)
    Set tSC = $ClassMethod(..#ITEMS, "MintAs", tTool, tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    If $IsObject($Get(tProposal)) Quit "minted"
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.detail.%Get("problem")
    Quit +$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault)
}

/// <p>The person's Set value (<var>pType</var> <code>SET</code>) or Reset to default, as <code>status code</code>.</p>
ClassMethod ByScreen(pType As %String, pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, pItem As %String = {$Parameter("OcuPilot.Test.InteropSettingControl", "OPNAME")}) As %String
{
    Quit $ClassMethod(..#CONTROL, "Act", $Select(pType = "SET": "set", 1: "reset"), pTarget, pName, pValue, .tAnswer, pItem)
}

/// <p>Assert that the three callers earn <var>pPort</var>, <var>pMint</var> and <var>pScreen</var> for the write, and
/// that nothing was stored, written to the class or audited.</p>
Method Refused(pLabel As %String, pType As %String, pTarget As %String, pName As %String, pValue As %String, pPort As %String, pMint As %String, pScreen As %String)
{
    Set tBefore = $ClassMethod(..#CONTROL, "Snapshot")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..ByPort(pType, pTarget, pName, pValue), pPort, pLabel _ ": through the port")
    Do $$$AssertEquals(..ByMint(pType, pTarget, pName, pValue, .tProblem), pMint, pLabel _ ": through the agent's mint " _ tProblem)
    Do $$$AssertEquals(..ByScreen(pType, pTarget, pName, pValue), pScreen, pLabel _ ": through the person's row action")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Snapshot"), tBefore, pLabel _ ": the stored settings and the class are as they were")
    Set tAudit = $ClassMethod(..#CONTROL, "SettingAudited", tSince)
    Do $$$AssertEquals(tAudit, "", pLabel _ ": and the vendor audited no setting: " _ tAudit)
}

/// <p>AC4: a value the declaring class refuses, and a value with a space at either end, which the vendor would store
/// trimmed, are refused <code>INTEROP.SETTING.VALUE</code> on <code>Value</code>; a body whose <code>Value</code> is not
/// a string is refused for its shape.</p>
/// <p>Mutation (Rule 19): skip <code>&lt;Name&gt;IsValid</code> in
/// <method>OcuPilot.Port.InteropPort.ValueAccepted</method> -- the class-refused rows go red; drop the trimmed-value test
/// from <method>OcuPilot.Port.InteropPort.SettingViolations</method> -- the <code>ProbeFile</code> row goes red.</p>
Method TestAValueTheClassRefusesIsRefusedByItsCode()
{
    Set tValue = "422 INTEROP.SETTING.VALUE"
    Do ..Refused("InitSeconds abc", "SET", "Host", "InitSeconds", "abc", tValue, "400 TOOL.ARGUMENTS", tValue)
    Do ..Refused("InitSeconds with a leading space", "SET", "Host", "InitSeconds", " 5", tValue, "400 TOOL.ARGUMENTS", tValue)
    Do ..Refused("ProbeFile with a trailing space, which its class accepts", "SET", "Host", "ProbeFile", "x.key ", tValue, "400 TOOL.ARGUMENTS", tValue)
    Do ..Refused("PoolSize many", "SET", "Core", "PoolSize", "many", tValue, "400 TOOL.ARGUMENTS", tValue)
    Do ..ByMint("SET", "Host", "InitSeconds", "abc", .tProblem)
    Do $$$AssertEquals(tProblem, "'Value': The item's class does not accept this value for this setting.", "the mint says which field and why")
    Set tBody = {"Value": 7}
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), tBody, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "422 PORT.FIELD.SHAPE", "a Value that is a number is refused for its shape")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), {}, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "422 PORT.FIELD.SHAPE", "and so is a body with none")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "400 PORT.VALIDATION", "and a set with no body at all is a bad request")
}

/// <p>AC4: a set of the value the production already holds is refused <code>INTEROP.SETTING.SAME</code> at the write,
/// and the mint's own "nothing would change" refuses an equal value first.</p>
/// <p>Mutation (Rule 19): drop the <code>SAME</code> refusal from
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> -- the port and screen rows go red.</p>
Method TestASetOfTheHeldValueIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", "OcuPilotProbeOp", "Host", "InitSeconds", 7), "InitSeconds is stored at 7")
    Do ..Refused("InitSeconds already 7", "SET", "Host", "InitSeconds", "7", "409 INTEROP.SETTING.SAME", "400 TOOL.ARGUMENTS", "409 INTEROP.SETTING.SAME")
    Do ..ByMint("SET", "Host", "InitSeconds", "7", .tProblem)
    Do $$$AssertTrue(tProblem [ "nothing would change", "the mint says nothing would change: " _ tProblem)
    Do $$$AssertEquals(..ByPort("SET", "Core", "Comment", ""), "409 INTEROP.SETTING.SAME", "a Core property holding the value is the same too")
}

/// <p>AC4: a Core setting a system default decides is refused <code>INTEROP.SETTING.SUPPLIED</code> at the fresh read,
/// by both callers and the port, and a Host setting a system default supplies can still be set.</p>
/// <p>Mutation (Rule 19): drop the Core arm of <code>SUPPLIED</code> from
/// <method>OcuPilot.Port.InteropPort.SettingRefusalToken</method> -- the Core rows go red.</p>
Method TestACoreSettingASystemDefaultDecidesIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Core", "PoolSize", "3"), "a system default decides PoolSize")
    Set tRow = $ClassMethod(..#CONTROL, "Row", "Core", "PoolSize")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source, "3|systemDefault", "the row reads the default's value, from the system default")
    Do ..Refused("PoolSize decided by a default", "SET", "Core", "PoolSize", "2", "409 INTEROP.SETTING.SUPPLIED", "409 INTEROP.SETTING.SUPPLIED", "409 INTEROP.SETTING.SUPPLIED")
    Do ..Refused("the same reset", "RESET", "Core", "PoolSize", $Char(0), "409 INTEROP.SETTING.SUPPLIED", "409 INTEROP.SETTING.SUPPLIED", "409 INTEROP.SETTING.SUPPLIED")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "InitSeconds", "9"), "a system default supplies InitSeconds")
    Set tRow = $ClassMethod(..#CONTROL, "Row", "Host", "InitSeconds")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default _ "|" _ tRow.DefaultSource, "9|systemDefault|9|systemDefault", "a Host setting reads the default from the system default")
    Do $$$AssertEquals(..ByPort("SET", "Host", "InitSeconds", "4"), "200 ", "and can still be set: the production's own value then decides")
    Set tRow = $ClassMethod(..#CONTROL, "Row", "Host", "InitSeconds")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default, "4|production|9", "over the default, which stays the default")
}

/// <p>AC4: a reset of a setting that holds no value of its own is refused <code>INTEROP.SETTING.DEFAULTED</code>, and
/// one of the item's own properties <code>INTEROP.SETTING.CORE</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>DEFAULTED</code> line from
/// <method>OcuPilot.Port.InteropPort.SettingRefusalToken</method> -- the defaulted rows go red.</p>
Method TestAResetThatHasNothingToResetIsRefused()
{
    Do ..Refused("InitSeconds holds no value of its own", "RESET", "Host", "InitSeconds", $Char(0), "409 INTEROP.SETTING.DEFAULTED", "409 INTEROP.SETTING.DEFAULTED", "409 INTEROP.SETTING.DEFAULTED")
    Do ..Refused("Comment is the item's own", "RESET", "Core", "Comment", $Char(0), "409 INTEROP.SETTING.CORE", "409 INTEROP.SETTING.CORE", "409 INTEROP.SETTING.CORE")
    Do ..Refused("PoolSize is the item's own", "RESET", "Core", "PoolSize", $Char(0), "409 INTEROP.SETTING.CORE", "409 INTEROP.SETTING.CORE", "409 INTEROP.SETTING.CORE")
}

/// <p>AC4: a setting the item does not declare, <code>Enabled</code> (the item write's own, not a setting here), a
/// group that is none of the three and an item or production the configuration does not hold are refused without a
/// word in the log: 404 <code>PORT.NOTFOUND</code>, or 400 for an id of the wrong shape.</p>
/// <p>Mutation (Rule 19): list <code>Enabled</code> among <code>GatherSettings</code>' rows -- the Enabled rows go
/// red; make <method>OcuPilot.Port.InteropPort.Absent</method> log a fault -- the last two rows go red.</p>
Method TestASettingNobodyDeclaresIsNotFound()
{
    Set tGone = "404 PORT.NOTFOUND"
    Do ..Refused("a setting the class does not declare", "SET", "Host", "NoSuchSetting", "1", tGone, "400 TOOL.ARGUMENTS", tGone)
    Do ..Refused("Enabled is not a setting here", "SET", "Core", "Enabled", "0", tGone, "400 TOOL.ARGUMENTS", tGone)
    Do ..Refused("a Core name in the Host group", "SET", "Host", "Comment", "x", tGone, "400 TOOL.ARGUMENTS", tGone)
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds", "OcuPilotProbeNoSuch"), {"Value": "7"}, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tGone, "an item the production does not hold")
    Set tId = "OcuPilotProbe.No.Such" _ $Char(1) _ "OcuPilotProbeOp" _ $Char(1) _ "Host" _ $Char(1) _ "InitSeconds"
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SETTING", tId, "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tGone, "nor a production the namespace does not hold")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SETTING", $ClassMethod(..#CONTROL, "IdOf", "Nowhere", "InitSeconds"), "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "400 PORT.VALIDATION", "a group that is none of the three is a bad request")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SETTING", "OcuPilotProbe.Interop.Production" _ $Char(1) _ "OcuPilotProbeOp", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "400 PORT.VALIDATION", "and so is an id with two parts")
    Do ##class(OcuPilot.Test.InteropSettingPaths).HoldTheWriterPairs()
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", $ClassMethod(..#CONTROL, "IdOf", "Host", "NoSuchSetting"), {"Value": "x"}, "", .tResult, .tHttp, .tFault, ..#SEAM)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tGone, "a set of it through the gate-armed port, holding every pair, is the same 404")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>AC4: a name two items bear, whatever the letter case, is refused <code>INTEROP.ITEM.AMBIGUOUS</code> by the
/// list, the read and both writes, because the vendor would change the first it finds.</p>
/// <p>Mutation (Rule 19): drop the count test from <method>OcuPilot.Port.InteropPort.SettingRefusalToken</method> --
/// the write rows go red.</p>
Method TestANameTwoItemsBearIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "ocupilotprobeop", "OcuPilotProbe.Interop.Op", 1, 0), "a second item bears the name in another letter case")
    Set tAmbiguous = "409 INTEROP.ITEM.AMBIGUOUS"
    Do ..Refused("two items of the name", "SET", "Host", "InitSeconds", "7", tAmbiguous, tAmbiguous, tAmbiguous)
    Do ..Refused("and a reset of it", "RESET", "Host", "HangSeconds", $Char(0), tAmbiguous, tAmbiguous, tAmbiguous)
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("item") = $ClassMethod(..#CONTROL, "ItemId")
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tAmbiguous, "the list refuses the name too")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SETTING", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), "", "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tAmbiguous, "and so does the read")
}

/// <p>AC4: a namespace under source control refuses a set, a reset and a read composed for either by
/// <code>INTEROP.ITEM.SOURCECONTROL</code> before the vendor is called, the list is still readable, and nothing is
/// logged as a fault.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the write rows go red.</p>
Method TestASourceControlledNamespaceRefusesEverySettingWrite()
{
    Set tSeam = ..#SEAM
    Do ##class(OcuPilot.Test.InteropSettingPaths).HoldTheWriterPairs()
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Set tBefore = $ClassMethod(..#CONTROL, "Snapshot")
    Set tId = $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("item") = $ClassMethod(..#CONTROL, "ItemId")
    Set tSC = $ClassMethod(tSeam, "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the list is readable")
    For tCase = $ListBuild("SETTING", "", "SET"), $ListBuild("SETTING", "", "RESET"), $ListBuild("SET", "7", ""), $ListBuild("RESET", "", "") {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = tId
        If $List(tCase, 3) '= "" Set tQuery("action") = $List(tCase, 3)
        Set tBody = $Select($List(tCase, 2) = "": "", 1: {"Value": ($List(tCase, 2))})
        Set tSC = $ClassMethod(tSeam, "Invoke", "Settings", $List(tCase, 1), .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), "409 INTEROP.ITEM.SOURCECONTROL", $List(tCase, 1) _ $Select($List(tCase, 3) = "": "", 1: " for " _ $List(tCase, 3)) _ " is refused for source control")
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Snapshot"), tBefore, "no refused call changed a setting")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

}
