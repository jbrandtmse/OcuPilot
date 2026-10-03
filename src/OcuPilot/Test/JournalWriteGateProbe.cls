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

/// <p>Journal settings' Save, whose port records each call as <parameter>SEAM</parameter> does
/// (Story 18.18).</p>
Parameter SAVE = "OcuPilot.Test.JournalSettingsSaveFixture";

Parameter SETTINGSPORT = "OcuPilot.Test.JournalSettingsPort";

/// <p>The confirm a settings proposal is confirmed through, whose port is
/// <parameter>SETTINGSPORT</parameter>, so a settings write a step reaches is held there too.</p>
Parameter SETTINGSCONFIRM = "OcuPilot.Test.DatabaseConfirm";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A
/// step is <code>{kind: "action"|"confirm"|"save"|"savesent"|"confirmsettings", action, id, values,
/// proposalId, body}</code>, a <code>save</code> being Journal settings' Save of <code>body</code>, held
/// at the port, a <code>savesent</code> the same Save sent to the instance, and a
/// <code>confirmsettings</code> a settings proposal's confirm through
/// <parameter>SETTINGSCONFIRM</parameter>; its answer is
/// <code>{http, code, failedPair, calls, types, verdict?}</code>, what the port was asked during that
/// step alone and the read-back's verdict when the answer carries one.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        ; Story 18.18: a settings write a step reaches is recorded and never sent.
        Do $ClassMethod(..#SETTINGSPORT, "Hold")
        Set ^||OcuPilotDatabaseWritePort = ..#SETTINGSPORT
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
    If pStep.%Get("kind") = "save" {
        Set tSC = ..Save(pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf pStep.%Get("kind") = "savesent" {
        Do $ClassMethod(..#SETTINGSPORT, "Release")
        Set tSC = ..Save(pStep.%Get("body"), .tBody, .tHttp)
        Do $ClassMethod(..#SETTINGSPORT, "Hold")
    } ElseIf pStep.%Get("kind") = "confirmsettings" {
        Set tSC = $ClassMethod(..#SETTINGSCONFIRM, "Confirm", pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf pStep.%Get("kind") = "confirm" {
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
            If $IsObject(tAnswer.%Get("readBack")) Do tLeg.%Set("verdict", tAnswer.%Get("readBack").%Get("verdict"), "string")
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

/// <p>Run Journal settings' <code>PUT /journal/settings</code> handler (<parameter>SAVE</parameter>)
/// against <class>%CSP.Request</class>/<class>%CSP.Response</class> stubs carrying <var>pBody</var>
/// as the request's content, and capture what it writes: <var>pAnswer</var> is the unparsed response
/// body and <var>pStatus</var> the numeric status <code>%response.Status</code> was left at.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "PUT"
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotJournalGateCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = $ClassMethod(..#SAVE, "HandleUpdate")
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotJournalGateCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotJournalGateCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Save</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotJournalGateCap = $Get(%OcuPilotJournalGateCap, "") _ s Quit
wchr(a) Set %OcuPilotJournalGateCap = $Get(%OcuPilotJournalGateCap, "") _ $Char(a) Quit
wnl Set %OcuPilotJournalGateCap = $Get(%OcuPilotJournalGateCap, "") _ $Char(10) Quit
wff Set %OcuPilotJournalGateCap = $Get(%OcuPilotJournalGateCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotJournalGateCap = $Get(%OcuPilotJournalGateCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
