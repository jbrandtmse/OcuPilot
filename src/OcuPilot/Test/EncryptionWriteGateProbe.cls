/// <p>The child process <class>OcuPilot.Test.EncryptionWriteGate</class> and
/// <class>OcuPilot.Test.EncryptionKeyGate</class> start to drive Stories 18.7's and 18.22's writes as a
/// <b>real principal</b> (AD-8, AD-29). It logs in as that principal and runs each
/// step of a plan in the process: the create form's Save through
/// <class>OcuPilot.Test.EncryptionSaveFixture</class>, the encryption startup settings' Save through
/// <class>OcuPilot.Test.EncryptionStartupSaveFixture</class> (Story 18.23), a screen action through
/// <class>OcuPilot.Test.EncryptionActionFixture</class>, a confirm through
/// <class>OcuPilot.Test.DatabaseConfirm</class>, a declared read through
/// <class>OcuPilot.Screen.Read</class>, and the side-bar entry's own gate. Each write reaches the instance
/// through <class>OcuPilot.Test.EncryptionSeamPort</class>, whose process-private record is why the steps
/// run here rather than over the wire.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionWriteGateProbe Extends %RegisteredObject
{

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A step
/// is <code>{kind: "save"|"startupsave"|"action"|"confirm"|"read"|"entry"|"arm", screen, body, proposalId, secrets,
/// descriptor, criteria, mode, held}</code>; its answer is <code>{http, code, failedPair, calls, writes}</code>,
/// where <code>calls</code> is how many vendor calls the seam was asked during that step alone and
/// <code>writes</code> the ones other than reads. An <code>arm</code> step arms the seam in this process with
/// <code>mode</code> and holds <code>held</code>'s <code>database</code> and <code>dataElement</code> active
/// lists, which the later steps keep.</p>
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
    Set tBody = ""
    Set tSC = $$$OK
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tKind = pStep.%Get("kind")
    If tKind = "arm" {
        Do $ClassMethod(..#SEAM, "Arm", pStep.%Get("mode"))
        Set tHeld = pStep.%Get("held")
        For tList = "database", "dataElement" {
            Do $ClassMethod(..#SEAM, "Hold", tList, $Select($IsObject(tHeld) && $IsObject(tHeld.%Get(tList)): tHeld.%Get(tList), 1: []))
        }
        Set tHttp = 200
    } ElseIf tKind = "confirm" {
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pStep.%Get("proposalId"), pStep.%Get("secrets"), $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "action" {
        Set tSC = ##class(OcuPilot.Test.EncryptionActionFixture).Act(pStep.%Get("screen"), pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf tKind = "save" {
        Set tSC = ##class(OcuPilot.Test.EncryptionSaveFixture).Handle(pStep.%Get("body"), .tBody, .tHttp, .tCache)
    } ElseIf tKind = "startupsave" {
        Set tSC = ##class(OcuPilot.Test.EncryptionStartupSaveFixture).Handle(pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf tKind = "read" {
        Kill tCriteria
        Set tCriteriaObject = pStep.%Get("criteria")
        If $IsObject(tCriteriaObject) {
            Set tIterator = tCriteriaObject.%GetIterator()
            While tIterator.%GetNext(.tName, .tValue) {
                Set tCriteria(tName) = tValue
            }
        }
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(pStep.%Get("descriptor"), 100, .tResult, .tHttp, .tFault, .tCriteria)
        If $$$ISOK(tSC) Set tHttp = 200
        If $IsObject($Get(tFault)) {
            Set tCode = tFault.%Get("code")
            If $IsObject(tFault.%Get("detail")) Set tPair = tFault.%Get("detail").%Get("failedPair")
        }
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
