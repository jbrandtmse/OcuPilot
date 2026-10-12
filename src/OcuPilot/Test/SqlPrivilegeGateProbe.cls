/// <p>The child process <class>OcuPilot.Test.SqlPrivilegeGate</class> starts to drive Story 18.9's writes as a
/// <b>real principal</b> (AD-8, AD-29). It logs in as that principal and runs each step of a plan in the process:
/// the Users and Roles lists' row actions through <class>OcuPilot.Test.SqlPrivilegeActionFixture</class>, a confirm
/// through <class>OcuPilot.Test.DatabaseConfirm</class>, and the side-bar entry's own gate. Each write reaches the
/// instance through <class>OcuPilot.Test.SqlPrivilegeSeamPort</class>, which sends a write for a probe name alone
/// and records it. Its process-private record is why the steps run here rather than over the wire.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlPrivilegeGateProbe Extends %RegisteredObject
{

Parameter SEAM = "OcuPilot.Test.SqlPrivilegeSeamPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal <code>{loggedIn, username,
/// steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A step is <code>{kind:
/// "action"|"confirm"|"entry", screen, body, proposalId, descriptor}</code>; its answer is <code>{http, code,
/// failedPair, calls, writes}</code>, where <code>calls</code> is how many vendor calls the seam was asked during
/// that step alone and <code>writes</code> the writes among them.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotDatabaseWritePort = ..#SEAM
        Do $ClassMethod(..#SEAM, "Clear")
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
    Set tBody = ""
    Set tSC = $$$OK
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tKind = pStep.%Get("kind")
    If tKind = "confirm" {
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "action" {
        Set tSC = ##class(OcuPilot.Test.SqlPrivilegeActionFixture).Act(pStep.%Get("screen"), pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf tKind = "entry" {
        Set tAllowed = ##class(OcuPilot.Screen.Gate).EvaluateEntry(pStep.%Get("descriptor"), .tFailed)
        Set tHttp = $Select(tAllowed: 200, 1: 403)
        Set tPair = $Get(tFailed)
    }
    If $$$ISERR(tSC) Do tLeg.%Set("status", $System.Status.GetErrorText(tSC))
    If tBody '= "" {
        Set tAnswer = ""
        Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
        If $IsObject(tAnswer) {
            Set tCode = tAnswer.%Get("code")
            If $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.%Get("detail").%Get("failedPair")
        }
    }
    Do tLeg.%Set("http", +tHttp, "number")
    Do tLeg.%Set("code", tCode, "string")
    Do tLeg.%Set("failedPair", tPair, "string")
    Set tCalls = $ClassMethod(..#SEAM, "Calls")
    Do tLeg.%Set("calls", $Select(tCalls = "": 0, 1: $Length(tCalls, ",")), "number")
    Do tLeg.%Set("writes", $ClassMethod(..#SEAM, "Writes"), "string")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Quit tLeg
}

}
