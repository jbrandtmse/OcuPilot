/// <p>The child process <class>OcuPilot.Test.MappingWriteGate</class> and
/// <class>OcuPilot.Test.ClassicPageGate</class> start to drive the mapping editor's Save, a list's
/// row action, the agent's confirm and the agent's tool dispatch as a <b>real principal</b> (AD-8,
/// AD-29, Story 18.14). It logs in as that principal and runs each step of a plan in the process: the
/// Save through <class>OcuPilot.Test.MappingSaveFixture</class>'s route handlers, a row action through
/// <class>OcuPilot.Test.MappingActionFixture</class>, a confirm through
/// <class>OcuPilot.Test.NamespaceConfirm</class>, and a tool call through
/// <class>OcuPilot.Kernel.Agent.Dispatch</class>. Each reaches the instance through the port a step
/// names, <class>OcuPilot.Test.MappingRecordPort</class> by default, whose process-private record is
/// why the steps run here rather than over the wire.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process
/// ends when <method>Run</method> returns.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingWriteGateProbe Extends %RegisteredObject
{

Parameter SAVE = "OcuPilot.Test.MappingSaveFixture";

Parameter ACTION = "OcuPilot.Test.MappingActionFixture";

Parameter CONFIRM = "OcuPilot.Test.NamespaceConfirm";

Parameter RECORD = "OcuPilot.Test.MappingRecordPort";

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, steps, tasks}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised. A step is one of <code>{kind: "create", mappingKind, body}</code>,
/// <code>{kind: "update", mappingKind, id, body}</code>, <code>{kind: "action", screen, body}</code>,
/// <code>{kind: "confirm", proposalId}</code> and <code>{kind: "dispatch", turnKey, tool,
/// input}</code>; its answer is <code>{http, code, failedPair, calls, types}</code>, where
/// <code>calls</code> and <code>types</code> are what the recording port was asked during that step
/// alone, reads included, and a dispatch's <code>http</code> is 403 for a pair refusal, 400 for any
/// other refused call and 200 for an answered one.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotNamespaceWritePort = ..#RECORD
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Step(tStep))
        }
        Do tOut.%Set("steps", tSteps)
        Do tOut.%Set("tasks", ..QueuedCopies())
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>The GUIDs of the copies of mappings this process's user has in the vendor's task store, read
/// from the port's task list (AD-27), or an empty array when the list cannot be read. The shipped
/// port reads a copy's finished row once and leaves it for a caller without
/// <code>%DB_IRISLOCALDATA:WRITE</code> (DW-1025); the parent deletes each one unread.</p>
ClassMethod QueuedCopies() As %DynamicArray
{
    Set tGuids = []
    Try {
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("AsyncResult", "LIST", , , .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit
        If 'tRows.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && ($Piece(tRow.%Get("TaskName"), " ", 1) = "MAPPINGS") Do tGuids.%Push(tRow.%Get("GUID"))
        }
    } Catch {
        Set tGuids = []
    }
    Quit tGuids
}

/// <p>Run one step of the plan and answer what it was answered and what the port was asked.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Set tHttp = 0
    Set tCode = ""
    Set tPair = ""
    Set tBody = ""
    Set tRecord = $Select(pStep.%Get("port") '= "": pStep.%Get("port"), 1: ..#RECORD)
    Set ^||OcuPilotNamespaceWritePort = tRecord
    Do $ClassMethod(tRecord, "Clear")
    Set tKind = pStep.%Get("kind")
    If tKind = "confirm" {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf tKind = "action" {
        Set tSC = $ClassMethod(..#ACTION, "Act", pStep.%Get("screen"), pStep.%Get("body"), .tBody, .tHttp)
    } ElseIf tKind = "dispatch" {
        Set tSC = ..Dispatch(pStep, .tHttp, .tCode, .tPair)
    } Else {
        Set tSC = ..Handle(tKind, pStep.%Get("mappingKind"), pStep.%Get("id"), pStep.%Get("body"), .tBody, .tHttp)
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
    Do tLeg.%Set("calls", $ClassMethod(tRecord, "CallCount"), "number")
    Do tLeg.%Set("types", $ClassMethod(tRecord, "CallTypes"), "string")
    Do $ClassMethod(tRecord, "Clear")
    Quit tLeg
}

/// <p>Send the step's tool call through the shipped dispatcher as this process's user, over the
/// step's turn: <var>pHttp</var> 403 with <var>pCode</var> and <var>pFailedPair</var> for a pair
/// refusal, 400 with the code for any other refusal, 200 for an answered call.</p>
ClassMethod Dispatch(pStep As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFailedPair As %String) As %Status
{
    Set pHttp = 0
    Set pCode = ""
    Set pFailedPair = ""
    Set tSC = $$$OK
    Try {
        Set tUse = {"type": "tool_use", "id": "toolu_gate"}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pStep.%Get("tool")), "string")
        Do tUse.%Set("input", $Select($IsObject(pStep.%Get("input")): pStep.%Get("input"), 1: {}))
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pStep.%Get("turnKey"))
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pStep.%Get("turnKey"), $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        If $$$ISERR(tSC) Quit
        Set tResult = tResults.%Get(0)
        Set tDetail = tDetails.%Get(0)
        Set pFailedPair = tDetail.%Get("failedPair")
        If 'tResult.%Get("is_error") {
            Set pHttp = 200
            Quit
        }
        Set tContent = ""
        Try { Set tContent = ##class(%DynamicObject).%FromJSON(tResult.%Get("content")) } Catch {}
        If $IsObject(tContent) Set pCode = tContent.%Get("code")
        Set pHttp = $Select(pFailedPair '= "": 403, 1: 400)
    } Catch ex {
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run the Save route handler for <var>pKind</var> -- <code>create</code> is <code>POST
/// /mapping/:kind</code>, <code>update</code> is <code>PUT /mapping/:kind/:id</code> for
/// <var>pId</var> -- for mapping kind <var>pMappingKind</var>, against
/// <class>%CSP.Request</class>/<class>%CSP.Response</class> stubs carrying <var>pBody</var> as the
/// request's content, and capture what it writes.</p>
/// <p><b>Caller contract:</b> <var>pId</var> holds no <code>%</code>, so the value the CSP server
/// would deliver after its one decode is the id itself (AD-13). <var>pAnswer</var> is the unparsed
/// response body and <var>pStatus</var> the numeric status <code>%response.Status</code> was left
/// at.</p>
ClassMethod Handle(pKind As %String, pMappingKind As %String, pId As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
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
        Set %OcuPilotMappingGateCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        If pKind = "create" {
            Set tSC = $ClassMethod(..#SAVE, "HandleCreate", pMappingKind)
        } Else {
            Set tSC = $ClassMethod(..#SAVE, "HandleUpdate", pMappingKind, pId)
        }

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotMappingGateCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotMappingGateCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotMappingGateCap = $Get(%OcuPilotMappingGateCap, "") _ s Quit
wchr(a) Set %OcuPilotMappingGateCap = $Get(%OcuPilotMappingGateCap, "") _ $Char(a) Quit
wnl Set %OcuPilotMappingGateCap = $Get(%OcuPilotMappingGateCap, "") _ $Char(10) Quit
wff Set %OcuPilotMappingGateCap = $Get(%OcuPilotMappingGateCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotMappingGateCap = $Get(%OcuPilotMappingGateCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
