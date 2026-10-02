/// <p>The child process <class>OcuPilot.Test.RemoteDatabaseWriteGate</class> starts to drive the remote
/// database form's Save, the Remote databases list's Delete and the agent's confirm as a <b>real
/// principal</b> (AD-8, AD-29, Story 18.16). It logs in as that principal and runs each step of a plan
/// in the process: the form's create and re-point through
/// <class>OcuPilot.Test.RemoteDatabaseSaveFixture</class>'s route handlers, its delete through
/// <class>OcuPilot.Test.RemoteDatabaseActionFixture</class>, and a confirm through
/// <class>OcuPilot.Test.DatabaseConfirm</class>. Each reaches the instance through
/// <class>OcuPilot.Test.RemoteDatabaseListingPort</class>, licensed, whose process-private record is why
/// the steps run here rather than over the wire.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process
/// ends when <method>Run</method> returns.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseWriteGateProbe Extends %RegisteredObject
{

Parameter SAVE = "OcuPilot.Test.RemoteDatabaseSaveFixture";

Parameter ACTION = "OcuPilot.Test.RemoteDatabaseActionFixture";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter SEAM = "OcuPilot.Test.RemoteDatabaseListingPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps}</code> to process <var>pParent</var>, or <code>{error}</code>
/// when something raised. A step is <code>{kind: "create"|"update"|"delete"|"confirm", name, body,
/// proposalId}</code>; its answer is <code>{http, code, failedPair, calls, types}</code>, where
/// <code>calls</code> and <code>types</code> are what the recording port was asked during that step
/// alone, reads included, and <code>listings</code> how many listings it asked for.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotDatabaseWritePort = ..#SEAM
        Set ^||OcuPilotRemoteLicensed = 1
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
    Kill ^||OcuPilotRemoteListings
    Set tKind = pStep.%Get("kind")
    If tKind = "confirm" {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "delete" {
        Set tRequest = {}
        Do tRequest.%Set("action", "delete", "string")
        Do tRequest.%Set("id", pStep.%Get("name"), "string")
        Set tSC = $ClassMethod(..#ACTION, "Act", "osmgmt.remotedatabases", tRequest, .tBody, .tHttp)
    } Else {
        Set tSC = ..Handle(tKind, pStep.%Get("name"), pStep.%Get("body"), .tBody, .tHttp)
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
    Do tLeg.%Set("listings", $ClassMethod(..#SEAM, "Listings"), "number")
    Do $ClassMethod(..#RECORD, "Clear")
    Quit tLeg
}

/// <p>Run the form's route handler for <var>pKind</var> -- <code>create</code> is
/// <code>POST /remote-database</code>, <code>update</code> is <code>PUT /remote-database/:id</code> for
/// <var>pName</var> -- against <class>%CSP.Request</class>/<class>%CSP.Response</class> stubs
/// carrying <var>pBody</var> as the request's content, and capture what it writes.</p>
/// <p><b>Caller contract:</b> <var>pName</var> is letters and digits alone, so the path segment the
/// CSP server would deliver is the name itself (AD-13). <var>pAnswer</var> is the unparsed response
/// body and <var>pStatus</var> the numeric status <code>%response.Status</code> was left at.</p>
ClassMethod Handle(pKind As %String, pName As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = $Select(pKind = "create": "POST", 1: "PUT")
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotRemoteGateCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        If pKind = "create" {
            Set tSC = $ClassMethod(..#SAVE, "HandleCreate")
        } Else {
            Set tSC = $ClassMethod(..#SAVE, "HandleUpdate", pName)
        }

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotRemoteGateCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotRemoteGateCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotRemoteGateCap = $Get(%OcuPilotRemoteGateCap, "") _ s Quit
wchr(a) Set %OcuPilotRemoteGateCap = $Get(%OcuPilotRemoteGateCap, "") _ $Char(a) Quit
wnl Set %OcuPilotRemoteGateCap = $Get(%OcuPilotRemoteGateCap, "") _ $Char(10) Quit
wff Set %OcuPilotRemoteGateCap = $Get(%OcuPilotRemoteGateCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotRemoteGateCap = $Get(%OcuPilotRemoteGateCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
