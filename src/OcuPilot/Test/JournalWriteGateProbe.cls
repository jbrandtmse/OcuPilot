/// <p>The child process <class>OcuPilot.Test.JournalWriteGate</class> starts to drive Journals' three
/// screen actions and the agent's confirm as a <b>real principal</b> (AD-8, AD-29, Story 18.5). It logs
/// in as that principal and runs each step of a plan in the process: a screen action through
/// <class>OcuPilot.Test.JournalIntegrityAction</class>, and a confirm through
/// <class>OcuPilot.Test.JournalIntegrityConfirm</class>. Each reaches the instance through
/// <class>OcuPilot.Test.JournalIntegrityPort</class>, whose process-private record of the calls it made
/// is why the steps run here rather than over the wire.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalWriteGateProbe Extends %RegisteredObject
{

Parameter ACTION = "OcuPilot.Test.JournalIntegrityAction";

Parameter CONFIRM = "OcuPilot.Test.JournalIntegrityConfirm";

Parameter SEAM = "OcuPilot.Test.JournalIntegrityPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A
/// step is <code>{kind: "action"|"confirm", action, id, values, proposalId}</code>; its answer is
/// <code>{http, code, failedPair, calls, types}</code>, what the port was asked during that step
/// alone.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
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

/// <p>Run one step of the plan and answer what it was answered and what the port was asked.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Set tHttp = 0
    Set tCode = ""
    Set tPair = ""
    Set tBody = ""
    Do $ClassMethod(..#SEAM, "Clear")
    If pStep.%Get("kind") = "confirm" {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } Else {
        Set tRequest = {}
        Do tRequest.%Set("action", pStep.%Get("action"), "string")
        Do tRequest.%Set("id", pStep.%Get("id"), "string")
        If $IsObject(pStep.%Get("values")) Do tRequest.%Set("values", pStep.%Get("values"))
        Set tSC = $ClassMethod(..#ACTION, "Act", "osmgmt.journals", tRequest, .tBody, .tHttp)
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
    Do tLeg.%Set("calls", $ClassMethod(..#SEAM, "Calls", .tTypes), "number")
    Do tLeg.%Set("types", tTypes, "string")
    Do $ClassMethod(..#SEAM, "Clear")
    Quit tLeg
}

}
