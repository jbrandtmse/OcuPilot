/// <p>The child process <class>OcuPilot.Test.DatabaseActionsGate</class> starts to drive Story 18.4's
/// disk operations as a <b>real principal</b> (AD-8, AD-29). It logs in as that principal and runs each
/// step of a plan in the process: a screen's action through <class>OcuPilot.Test.DatabaseActionFixture</class>,
/// the Local databases editor's Save through <class>OcuPilot.Test.DatabaseWriteGateProbe</class>'s route
/// handler, the agent's confirm through <class>OcuPilot.Test.DatabaseConfirm</class>, and the agent's
/// tool call through <method>OcuPilot.Test.MappingWriteGateProbe.Dispatch</method>. Each but the tool call reaches
/// the instance through <class>OcuPilot.Test.DatabaseRecordPort</class>, whose process-private record is
/// why the steps run here.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseActionsGateProbe Extends %RegisteredObject
{

Parameter ACTION = "OcuPilot.Test.DatabaseActionFixture";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A
/// step is <code>{kind: "act", screen, action, id, values}</code>, <code>{kind: "update", name,
/// body}</code>, <code>{kind: "confirm", proposalId}</code> or <code>{kind: "dispatch", turnKey, tool,
/// input}</code>; its answer is <code>{http, code, failedPair, calls, types}</code>, where
/// <code>calls</code> and <code>types</code> are what the recording port was asked during that step
/// alone, and a dispatch's <code>http</code> is 403 for a pair refusal, 400 for any other refused call
/// and 200 for an answered one.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotDatabaseWritePort = ..#RECORD
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
    Do $ClassMethod(..#RECORD, "Clear")
    Set tKind = pStep.%Get("kind")
    If tKind = "confirm" {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "dispatch" {
        Set tSC = ##class(OcuPilot.Test.MappingWriteGateProbe).Dispatch(pStep, .tHttp, .tCode, .tPair)
    } ElseIf tKind = "act" {
        Set tRequest = {}
        Do tRequest.%Set("action", pStep.%Get("action"), "string")
        Do tRequest.%Set("id", pStep.%Get("id"), "string")
        If $IsObject(pStep.%Get("values")) Do tRequest.%Set("values", pStep.%Get("values"))
        Set tSC = $ClassMethod(..#ACTION, "Act", pStep.%Get("screen"), tRequest, .tBody, .tHttp)
    } Else {
        Set tSC = ##class(OcuPilot.Test.DatabaseWriteGateProbe).Handle("update", pStep.%Get("name"), pStep.%Get("body"), .tBody, .tHttp)
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
    Do tLeg.%Set("calls", $ClassMethod(..#RECORD, "CallCount"), "number")
    Do tLeg.%Set("types", $ClassMethod(..#RECORD, "CallTypes"), "string")
    Do $ClassMethod(..#RECORD, "Clear")
    Quit tLeg
}

}
