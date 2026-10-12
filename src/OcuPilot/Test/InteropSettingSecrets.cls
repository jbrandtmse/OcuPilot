/// <p>Pins Story 20.22's treatment of a setting whose name the credential pattern matches (AD-3, AD-35, AD-36, AD-41,
/// AD-60, Q1): the probe operation's <code>ApiToken</code>, holding a value of the production's own and a system
/// default. Its value and its default appear in no list row, no setting read, no read-tool result, no screen payload
/// and no ledger row or step; a set or a reset of it is refused <code>INTEROP.SETTING.SECRET</code> by the port, the
/// agent's mint and the person's row action before any vendor call; and a value the agent sent under that name reads
/// as the redaction mark in the ledger row and the step, while one sent for an ordinary setting is kept.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropSettingControl</class>, whose helpers it
/// calls. It starts no production and runs one class per run.</p>
Class OcuPilot.Test.InteropSettingSecrets Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropSettingSeam";

Parameter LEDGER = "OcuPilot.Test.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The value the production holds, the default a system default supplies and the value an agent sends: none may
/// reach a surface.</p>
Parameter OWN = "ocu-own-secret-8f3a";

Parameter DEFAULT = "ocu-default-secret-5c1d";

Parameter SENT = "ocu-sent-secret-77be";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingSecrets compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
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

/// <p>The probe's <code>ApiToken</code> holds <parameter>OWN</parameter> and a system default supplies
/// <parameter>DEFAULT</parameter>.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "PutItemSetting", "OcuPilotProbeOp", "Host", "ApiToken", ..#OWN)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ApiToken", ..#DEFAULT)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left with its settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The names of the secrets this class plants that <var>pText</var> carries, <code>""</code> for none.</p>
ClassMethod Leaks(pText As %String) As %String
{
    Set tLeaks = ""
    For tName = "OWN", "DEFAULT", "SENT" {
        If pText [ $Parameter($ClassName(), tName) Set tLeaks = tLeaks _ tName _ " "
    }
    Quit tLeaks
}

/// <p>AC3: the secret-named setting is listed and read with an empty value and default and <code>Secret</code> true,
/// and neither planted value is in the list's rows, the setting's read, the screen's answer over HTTP, the read tool's
/// result or the screen context built from the rows the screen answered; the stored value and the system default are
/// there, so the emptiness is the port's doing.</p>
/// <p>Mutation (Rule 19): drop the secret blanking from <method>OcuPilot.Port.InteropPort.SettingRow</method> -- every
/// leg goes red.</p>
Method TestTheSecretAppearsInNoRowToolResultOrContext()
{
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ApiToken"), ..#OWN, "the production holds its own value")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("item") = $ClassMethod(..#CONTROL, "ItemId")
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the list answers")
    If '$IsObject($Get(tRows)) Quit
    Set tRow = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCandidate) {
        If tCandidate.Name = "ApiToken" Set tRow = tCandidate
    }
    Do $$$AssertTrue($IsObject(tRow), "ApiToken is listed")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Default _ "|" _ tRow.Secret _ "|" _ tRow.Source _ "|" _ tRow.DefaultSource, "||1|production|systemDefault", "with an empty value and default, flagged secret, its sources kept")
    Do $$$AssertEquals(..Leaks(tRows.%ToJSON()), "", "no row of the list carries a planted value")
    Set tOne = $ClassMethod(..#CONTROL, "Row", "Host", "ApiToken")
    Do $$$AssertEquals($IsObject(tOne) _ "|" _ ..Leaks($Select($IsObject(tOne): tOne.%ToJSON(), 1: "")), "1|", "the setting's own read is blank too")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Kill tCriteria
    Set tCriteria("item") = $ClassMethod(..#CONTROL, "ItemId")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.InteropItemSettingList", 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tScreenHttp) _ "|" _ ..Leaks($Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "")), "200|", "the screen's read carries none")
    Do $ClassMethod(..#ITEMS, "Call", "GET", $Parameter(..#CONTROL, "SCREEN") _ "/read?item=" _ $ZConvert($ClassMethod(..#CONTROL, "ItemId"), "O", "URL") _ "&maxRows=1000", "", .tStatus, .tWire)
    Do $$$AssertEquals(tStatus _ "|" _ ..Leaks($Select($IsObject(tWire): tWire.%ToJSON(), 1: tWire)), "200|", "nor does the screen's answer over HTTP")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.itemsettings.read", .tTool, 1)
    Kill tResult
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"item": ($ClassMethod(..#CONTROL, "ItemId")), "maxRows": 1000}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(+$Get(tToolHttp) _ "|" _ ..Leaks($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")), "200|", "the read tool's result carries none")
    If $IsObject($Get(tAnswer)) {
        Set tContext = {"route": "interoperability/productions/items/settings", "namespace": "USER", "view": {}}
        Do tContext.view.%Set("rows", tAnswer.rows)
        Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
        Do $$$AssertEquals(tBuilt _ "|" _ ..Leaks($Select($IsObject($Get(tPayload)): tPayload.%ToJSON(), 1: "")), "1|", "and neither does the screen context built from them")
    }
}

/// <p>AC3: a set and a reset of the secret-named setting are refused <code>INTEROP.SETTING.SECRET</code> through the
/// port, the agent's mint and the person's row action; the refusal is decided on the name alone, so it comes even for an
/// item the production does not hold, and nothing is stored or audited.</p>
/// <p>Mutation (Rule 19): drop the secret refusal from <method>OcuPilot.Port.InteropPort.InvokeSettings</method> and
/// from <method>OcuPilot.Screen.Tool.InteropSettingAction.SecretProblem</method> -- the port and screen rows and the
/// confirm rule go red.</p>
Method TestASetAndAResetOfItAreRefusedFromBothCallers()
{
    Set tBefore = $ClassMethod(..#CONTROL, "Snapshot")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSecret = "409 INTEROP.SETTING.SECRET"
    Set tCases = $ListBuild("SET", "RESET")
    For tI = 1:1:2 {
        Set tType = $List(tCases, tI)
        Set tValue = $Select(tType = "SET": ..#SENT, 1: $Char(0))
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropSettingRefusals).ByPort(tType, "Host", "ApiToken", tValue), tSecret, tType _ " through the port")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropSettingRefusals).ByMint(tType, "Host", "ApiToken", tValue), tSecret, tType _ " through the agent's mint")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropSettingRefusals).ByScreen(tType, "Host", "ApiToken", tValue), tSecret, tType _ " through the person's row action")
    }
    Set tId = "OcuPilotProbe.No.Such" _ $Char(1) _ "OcuPilotProbeNoSuch" _ $Char(1) _ "Host" _ $Char(1) _ "ApiToken"
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SET", tId, {"Value": "x"}, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tSecret, "even for an item the production does not hold: the refusal reads the name alone")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", "SETTING", $ClassMethod(..#CONTROL, "IdOf", "Host", "ApiToken"), "", "SET", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault), tSecret, "so is the read composed for the set")
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.InteropSettingSet", "ConfirmProblem", $ClassMethod(..#CONTROL, "IdOf", "Host", "ApiToken"), $ClassMethod(..#CONTROL, "ArgsFor", "Host", "ApiToken", ..#SENT), .tProblem)
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.SETTING.SECRET"), "and a confirm would be refused the same sentence before the claim")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ApiToken"), ..#OWN, "the stored value is as it was")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Snapshot"), tBefore, "and so are the settings and the class")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "SettingAudited", tSince), "", "the vendor audited no setting")
}

/// <p>AC3: dispatched through the agent's tool loop, a set whose value the agent sent for the secret-named setting is
/// refused, and neither its ledger row nor its step carries the value, which reads as the redaction mark; a value sent
/// for an ordinary setting is kept in both.</p>
/// <p>Mutation (Rule 19): drop the <code>CallSecretNames</code> union from
/// <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> -- the secret's ledger and step legs go red.</p>
Method TestAValueTheAgentSentIsRedactedInTheLedgerRowAndTheStep()
{
    Set tWire = ##class(OcuPilot.Screen.Tool.Registry).WireName("interop.itemsettings.set")
    For tCase = $ListBuild("ApiToken", ..#SENT, 1), $ListBuild("InitSeconds", "bad7777", 0) {
        Set tKey = $ClassMethod(..#LEDGER, "NewTurnKey")
        Set tUse = {"id": "toolu_setting"}
        Do tUse.%Set("name", tWire, "string")
        Do tUse.%Set("input", $ClassMethod(..#CONTROL, "ArgsFor", "Host", $List(tCase, 1), $List(tCase, 2)))
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "interoperability/productions/items/settings")
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the dispatcher answers the call")
        Do $$$AssertEquals(tResults.%Size() _ "|" _ tResults.%Get(0).%Get("is_error"), "1|1", $List(tCase, 1) _ ": the call is refused, the secret by its code and the ordinary setting for a value its class refuses")
        Set tText = $ClassMethod(..#LEDGER, "RowText", tKey)
        Set tStepArgs = $Select(tDetails.%Size() = 1: tDetails.%Get(0).arguments, 1: "")
        Do $$$AssertTrue(tText '= "", $List(tCase, 1) _ ": the row was stored: " _ tText)
        If $List(tCase, 3) {
            Do $$$AssertEquals(tText [ $List(tCase, 2), 0, "no column of the ledger row carries the value sent: " _ tText)
            Do $$$AssertEquals(tStepArgs [ $List(tCase, 2), 0, "and the step's arguments do not: " _ tStepArgs)
            Do $$$AssertTrue((tText [ "[redacted]") && (tStepArgs [ "[redacted]"), "the value reads as redacted in both")
            Do $$$AssertTrue((tText [ "ApiToken") && (tStepArgs [ "ApiToken"), "while the setting's name is kept")
        } Else {
            Do $$$AssertTrue((tText [ $List(tCase, 2)) && (tStepArgs [ $List(tCase, 2)), "a value sent for an ordinary setting is kept in the row and the step")
        }
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
    }
}

}
