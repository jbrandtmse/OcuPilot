/// <p>The child process <class>OcuPilot.Test.EcpWriteGate</class> starts to drive Story 18.20's writes as
/// a <b>real principal</b> (AD-8, AD-29). It logs in as that principal and runs each step of a plan in
/// the process: the data server form's create and update through
/// <class>OcuPilot.Test.EcpSaveFixture</class>, the list's Delete and Change status through
/// <class>OcuPilot.Test.EcpActionFixture</class>, and a confirm through
/// <class>OcuPilot.Test.DatabaseConfirm</class>. Each reaches the instance through
/// <class>OcuPilot.Test.EcpSeamPort</class>, whose process-private record is why the steps run here
/// rather than over the wire.</p>
/// <p>Story 18.21 adds ECP settings' Save (<code>settings</code>, through
/// <class>OcuPilot.Test.EcpSettingsSaveFixture</class>) and the SSL/TLS authorizations tab's
/// <code>sslauthorize</code>, <code>sslreject</code> and <code>ssldelete</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EcpWriteGateProbe Extends %RegisteredObject
{

Parameter SEAM = "OcuPilot.Test.EcpSeamPort";

Parameter SCREEN = "osmgmt.ecpdataservers";

/// <p>Story 18.21's SSL/TLS authorizations tab, whose three row actions a step names.</p>
Parameter SSLSCREEN = "osmgmt.ecpsslconnections";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A
/// step is <code>{kind: "create"|"update"|"delete"|"changestatus"|"confirm"|"settings"|"sslauthorize"|
/// "sslreject"|"ssldelete", name, body, status,
/// proposalId, mode}</code>, <code>mode</code> the seam's armed mode for that step; its answer is
/// <code>{http, code, reason, failedPair, calls, writes}</code>, where <code>calls</code> is how many vendor
/// calls the seam was asked during that step alone and <code>writes</code> the ones other than
/// reads.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotDatabaseWritePort = ..#SEAM
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Step(tStep))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run one step of the plan and answer what it was answered and what the seam was asked.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Set tHttp = 0
    Set tCode = ""
    Set tPair = ""
    Set tReason = ""
    Set tBody = ""
    Do $ClassMethod(..#SEAM, "Clear")
    If pStep.%Get("mode") '= "" Do $ClassMethod(..#SEAM, "Arm", pStep.%Get("mode"))
    Set tKind = pStep.%Get("kind")
    If tKind = "confirm" {
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "delete" {
        Set tRequest = {"action": "delete"}
        Do tRequest.%Set("id", pStep.%Get("name"), "string")
        Set tSC = ##class(OcuPilot.Test.EcpActionFixture).Act(..#SCREEN, tRequest, .tBody, .tHttp)
    } ElseIf tKind = "settings" {
        ; Story 18.21: ECP settings' Save.
        Set tSC = ##class(OcuPilot.Test.EcpSettingsSaveFixture).Handle(pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf (tKind = "sslauthorize") || (tKind = "sslreject") || (tKind = "ssldelete") {
        ; Story 18.21: the SSL/TLS authorizations tab's row actions.
        Set tRequest = {}
        Do tRequest.%Set("action", $Extract(tKind, 4, *), "string")
        Do tRequest.%Set("id", pStep.%Get("name"), "string")
        Set tSC = ##class(OcuPilot.Test.EcpActionFixture).Act(..#SSLSCREEN, tRequest, .tBody, .tHttp)
    } ElseIf tKind = "changestatus" {
        Set tRequest = {"action": "changestatus"}
        Do tRequest.%Set("id", pStep.%Get("name"), "string")
        Do tRequest.%Set("values", {"Status": (pStep.%Get("status"))})
        Set tSC = ##class(OcuPilot.Test.EcpActionFixture).Act(..#SCREEN, tRequest, .tBody, .tHttp)
    } Else {
        Set tSC = ##class(OcuPilot.Test.EcpSaveFixture).Handle(tKind, pStep.%Get("name"), pStep.%Get("body"), .tBody, .tHttp)
    }
    If $$$ISERR(tSC) Do tLeg.%Set("status", $System.Status.GetErrorText(tSC))
    If tBody '= "" {
        Set tAnswer = ""
        Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
        If $IsObject(tAnswer) {
            Set tCode = tAnswer.%Get("code")
            Set tReason = tAnswer.%Get("reason")
            If $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.%Get("detail").%Get("failedPair")
        }
    }
    Do tLeg.%Set("http", +tHttp, "number")
    Do tLeg.%Set("code", tCode, "string")
    Do tLeg.%Set("reason", tReason, "string")
    Do tLeg.%Set("failedPair", tPair, "string")
    Set tCalls = $ClassMethod(..#SEAM, "Calls")
    Do tLeg.%Set("calls", $Select(tCalls = "": 0, 1: $Length(tCalls, ",")), "number")
    Do tLeg.%Set("writes", $ClassMethod(..#SEAM, "Writes"), "string")
    Do $ClassMethod(..#SEAM, "Clear")
    Quit tLeg
}

}
