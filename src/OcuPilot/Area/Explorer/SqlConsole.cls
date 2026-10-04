/// <p>SQL query's two routes (Story 19.6): <code>POST /explorer/sql/run</code> and
/// <code>POST /explorer/sql/plan</code>, each answering this screen only (AD-36, AD-39's sixth
/// exception). Each gates on the screen (<method>Gate</method>), reads the body, checks its bounds,
/// classifies the statement through <class>OcuPilot.Port.SqlPort</class>, asks
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>, and only then answers. The same
/// read (<method>Read</method>) and checks (<method>Check</method>) serve the background run
/// (<class>OcuPilot.Area.Explorer.SqlBackground</class>, Story 19.15).</p>
/// <p><b>Only a statement the instance types as a query runs here.</b> A statement of any other kind
/// is answered <code>confirm</code> before any execution; the confirmed run is the screen action of
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class>, which classifies it again (AD-11, AD-53). A
/// function a query calls can still change state, which its statement type does not show (named
/// limit).</p>
/// <p>The body is <code>{statement, parameters?, maxRows?}</code>: a string, an array of strings
/// (none when absent) and a whole number from 1 to 1,000 (1,000 when absent); any other key or shape
/// is refused 400 <code>EXPLORER.SQL.INPUT</code> before anything is prepared. Nothing of the
/// statement, its values, its rows, its SQL error or its plan is logged.</p>
Class OcuPilot.Area.Explorer.SqlConsole Extends %RegisteredObject
{

/// <p>The screen both routes answer for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

/// <p>The port that classifies, runs and explains a statement.</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

/// <p>The outcomes the run route answers beside the port's own.</p>
Parameter OUTCOMECONFIRM = "confirm";

Parameter OUTCOMEPARAMETERS = "parameters";

/// <p>Answer <code>POST /explorer/sql/run</code> in the request's scope: <code>{outcome:
/// error}</code> for a statement the instance would not prepare; <code>{outcome: parameters,
/// count}</code> when the values do not number its value positions; <code>{outcome: confirm, kind,
/// statementType, tables}</code> for a kind that changes something, nothing run; and for a query the
/// port's run answer (<method>OcuPilot.Port.SqlPort.Run</method>). A refusal is one envelope.</p>
ClassMethod HandleRun() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Prepare(.tRefused, .tNamespace, .tText, .tValues, .tMaxRows, .tGuard, .tAnswer)
        If tRefused Quit
        If $IsObject(tAnswer) {
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        If tValues.%Size() '= tGuard.%Get("Parameters") {
            Set tAnswer = {}
            Do tAnswer.%Set("outcome", ..#OUTCOMEPARAMETERS, "string")
            Do tAnswer.%Set("count", +tGuard.%Get("Parameters"), "number")
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        Set tKind = tGuard.%Get("Kind")
        If $ClassMethod(..#PORTCLASS, "Mutating", tKind) {
            Set tAnswer = {}
            Do tAnswer.%Set("outcome", ..#OUTCOMECONFIRM, "string")
            Do tAnswer.%Set("kind", tKind, "string")
            Do tAnswer.%Set("statementType", tGuard.%Get("StatementType"))
            Do tAnswer.%Set("tables", tGuard.%Get("Tables"))
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        Set tRunSC = $ClassMethod(..#PORTCLASS, "Run", tNamespace, tText, tValues, tMaxRows, "query", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tRunSC) {
            Set tSC = ..RenderFault(tRunSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the SQL console's run failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Answer <code>POST /explorer/sql/plan</code> in the request's scope: the port's plan answer
/// (<method>OcuPilot.Port.SqlPort.Plan</method>), nothing executed, after the same gate, bounds,
/// refusals and self-protection the run route applies.</p>
ClassMethod HandlePlan() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Prepare(.tRefused, .tNamespace, .tText, .tValues, .tMaxRows, .tGuard, .tAnswer)
        If tRefused Quit
        If $IsObject(tAnswer) {
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        Set tPlanSC = $ClassMethod(..#PORTCLASS, "Plan", tNamespace, tText, .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tPlanSC) {
            Set tSC = ..RenderFault(tPlanSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the SQL console's plan failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>What both routes do first: the screen gate, the body, the bounds (<method>Read</method>), then
/// the port's classification and the self-protection check (<method>Check</method>), in that order.
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else. Otherwise
/// <var>pGuard</var> is the port's guard, and <var>pAnswer</var> is the <code>error</code> outcome when
/// the instance would not prepare the statement, or <code>""</code>.</p>
ClassMethod Prepare(Output pRefused As %Boolean, Output pNamespace As %String, Output pText As %String, Output pValues As %DynamicArray, Output pMaxRows As %Integer, Output pGuard As %DynamicObject, Output pAnswer As %DynamicObject) As %Status [ Private ]
{
    Set pGuard = ""
    Set pAnswer = ""
    Set tSC = ..Read(.pRefused, .pNamespace, .pText, .pValues, .pMaxRows)
    If pRefused Quit tSC
    Set pRefused = 1
    Set tCheckSC = ..Check(pNamespace, pText, .pGuard, .tHttp, .tFault)
    If $$$ISERR(tCheckSC) {
        If '$IsObject($Get(tFault)) Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tCheckSC))
        Quit ..RenderFault(tCheckSC, $Get(tHttp), tFault)
    }
    Set pRefused = 0
    Set pAnswer = ..ErrorOutcome(pGuard)
    Quit $$$OK
}

/// <p>The screen gate, the body and its bounds, as both routes and the background run's start read
/// them. <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else;
/// otherwise <var>pNamespace</var> is the request's scope and <var>pText</var>, <var>pValues</var> and
/// <var>pMaxRows</var> the body's statement, values and row cap, nothing yet prepared.</p>
ClassMethod Read(Output pRefused As %Boolean, Output pNamespace As %String, Output pText As %String, Output pValues As %DynamicArray, Output pMaxRows As %Integer) As %Status
{
    Set pRefused = 1
    Set (pNamespace, pText) = ""
    Set pValues = []
    Set pMaxRows = ##class(OcuPilot.Port.SqlPort).#MAXROWS
    Set tSC = ..Gate(.tGateRefused)
    If tGateRefused || $$$ISERR(tSC) Quit tSC
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") Quit ..RenderInput()
    If '..Body(tBody, .pText, .pValues, .pMaxRows) Quit ..RenderInput()
    If ##class(OcuPilot.Port.SqlPort).InputProblem(pText, pValues, pMaxRows) '= "" Quit ..RenderInput()
    Set pNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set pRefused = 0
    Quit $$$OK
}

/// <p>Classify <var>pText</var> in <var>pNamespace</var> through the port and ask
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>, rendering nothing: the step both
/// routes take after <method>Read</method>, and the one the background run's job repeats in its own
/// process. On success <var>pGuard</var> is the port's guard, its <code>error</code> set when the
/// instance would not prepare the statement. A refusal is an error status with <var>pHttp</var> and
/// <var>pFault</var>: the port's own, or 403 with the self-protection code the set answers. A self-protection
/// check that could not be answered is an error status with <var>pFault</var> <code>""</code>.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9).</p>
ClassMethod Check(pNamespace As %String, pText As %String, Output pGuard As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pGuard = ""
    Set pHttp = 0
    Set pFault = ""
    Set tSC = $ClassMethod(..#PORTCLASS, "Classify", pNamespace, pText, .pGuard, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tTables = ""
    If pGuard.%GetTypeOf("Tables") = "array" {
        Set tIterator = pGuard.%Get("Tables").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTable) {
            Set tTables = tTables _ $ListBuild(tTable)
        }
    }
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SqlStatement(pText, tTables, ''pGuard.%Get("RecordsTables"), .tProhibits, .tCode, pGuard.%Get("DefaultSchema"))
    If $$$ISERR(tSC) {
        Set pHttp = 500
        Quit tSC
    }
    If tProhibits {
        Set pHttp = 403
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
        Quit $$$ERROR($$$GeneralError, tCode)
    }
    Quit $$$OK
}

/// <p>The <code>error</code> outcome of a statement the instance would not prepare, from the port's
/// guard <var>pGuard</var>, or <code>""</code> when it prepared.</p>
ClassMethod ErrorOutcome(pGuard As %DynamicObject) As %DynamicObject
{
    If '$IsObject($Get(pGuard)) || (pGuard.%GetTypeOf("error") '= "object") Quit ""
    Set tAnswer = {}
    Do tAnswer.%Set("outcome", ##class(OcuPilot.Port.SqlPort).#OUTCOMEERROR, "string")
    Do tAnswer.%Set("kind", "", "string")
    Do tAnswer.%Set("sqlcode", pGuard.%Get("error").%Get("sqlcode"), "number")
    Do tAnswer.%Set("message", pGuard.%Get("error").%Get("message"), "string")
    Quit tAnswer
}

/// <p>Read <var>pBody</var> into the statement, its values and its row cap, answering 0 for any key
/// but the three or a value of the wrong shape. A missing <code>parameters</code> is no values, a
/// missing <code>maxRows</code> the default.</p>
ClassMethod Body(pBody As %DynamicObject, Output pText As %String, Output pValues As %DynamicArray, Output pMaxRows As %Integer) As %Boolean [ Private ]
{
    Set pText = ""
    Set pValues = []
    Set pMaxRows = ##class(OcuPilot.Port.SqlPort).#MAXROWS
    Set tPort = "OcuPilot.Port.SqlPort"
    Set tKeys = $ListBuild($Parameter(tPort, "STATEMENTKEY"), $Parameter(tPort, "PARAMETERSKEY"), $Parameter(tPort, "MAXROWSKEY"))
    Set tStray = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeys, tKey) Set tStray = 1
    }
    If tStray Quit 0
    If pBody.%GetTypeOf($Parameter(tPort, "STATEMENTKEY")) '= "string" Quit 0
    Set pText = pBody.%Get($Parameter(tPort, "STATEMENTKEY"))
    Set tType = pBody.%GetTypeOf($Parameter(tPort, "PARAMETERSKEY"))
    If tType = "array" {
        Set pValues = pBody.%Get($Parameter(tPort, "PARAMETERSKEY"))
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Set tType = pBody.%GetTypeOf($Parameter(tPort, "MAXROWSKEY"))
    If tType = "number" {
        Set pMaxRows = pBody.%Get($Parameter(tPort, "MAXROWSKEY"))
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Quit 1
}

/// <p>Refuse a caller who does not hold the screen's pairs, the classic page's custom resource among
/// them (AD-8, AD-44): <var>pRefused</var> 1 means the envelope is written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>The 400 <code>EXPLORER.SQL.INPUT</code> envelope.</p>
ClassMethod RenderInput() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#REASONSQLINPUT, ##class(OcuPilot.Api.AtelierError).#SQLINPUT)
}

/// <p>Render a port refusal as the one envelope it already is (AD-12, AD-39); an internal failure
/// renders the generic reason, the port having logged its own line.</p>
ClassMethod RenderFault(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If '$IsObject($Get(pFault)) || (pFault.%Get("code") = "") || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).Render(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, ##class(OcuPilot.Api.Error).#INTERNAL)
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttpStatus: +pHttpStatus, 1: 500), pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), pFault.%Get("detail"))
}

}
