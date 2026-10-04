/// <p>Data browser's route (Story 19.7): <code>POST /explorer/sql/data</code>, answering this screen
/// only (AD-36, AD-39's sixth exception). In order: the screen gate with both classic Open Table
/// pages' custom resources (<method>Gate</method>); the body's shape
/// (<method>OcuPilot.Port.SqlPort.BrowseRequest</method>); the self-protection check on the requested
/// name; the port's plan (<method>OcuPilot.Port.SqlPort.BrowsePlan</method>), which gates again and
/// reads only the caller's catalog; the self-protection check on the composed text and the resolved
/// tables, a view's base tables among them; and only then the page
/// (<method>OcuPilot.Port.SqlPort.BrowseRun</method>).</p>
/// <p>Nothing of the request, the rows, an SQLCODE or a message is logged. The answer never enters
/// screen context, a tool, the ledger or an audit payload.</p>
Class OcuPilot.Area.Explorer.SqlData Extends %RegisteredObject
{

/// <p>The screen the route answers for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlData";

/// <p>The classic page beyond the descriptor's own whose operation the route performs: SQL Home's
/// Open Table for a view (AD-44).</p>
Parameter VIEWPAGE = "%cspapp.exp.utilsqlopenview";

/// <p>The port that plans and runs a page.</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

/// <p>Answer <code>POST /explorer/sql/data</code> in the request's scope with the port's answer
/// (<method>OcuPilot.Port.SqlPort.BrowseRun</method>): <code>rows</code>, <code>stopped</code> or
/// <code>error</code>. A refusal is one envelope: 403 <code>AUTH.NOPRIVILEGE</code> naming the pair,
/// 400 <code>EXPLORER.DATA.INPUT</code>, 403 with the self-protection set's code and sentence
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>), the port's 404
/// <code>EXPLORER.DATA.NOTFOUND</code>, or 500.</p>
ClassMethod HandleBrowse() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$ClassMethod(..#PORTCLASS, "BrowseRequest", $Get(tBody), .tRequest) {
            Set tSC = ..RenderInput()
            Quit
        }
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tName = tRequest.%Get($Parameter(..#PORTCLASS, "BROWSESCHEMAKEY")) _ "." _ tRequest.%Get($Parameter(..#PORTCLASS, "BROWSETABLEKEY"))
        Set tSC = ..Check("", $ListBuild(tName), .tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        Set tPlanSC = $ClassMethod(..#PORTCLASS, "BrowsePlan", tNamespace, tRequest, .tPlan, .tHttp, .tFault)
        If $$$ISERR(tPlanSC) {
            Set tSC = ##class(OcuPilot.Area.Explorer.SqlConsole).RenderFault(tPlanSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tTables = ""
        If tPlan.%GetTypeOf("tables") = "array" {
            Set tIterator = tPlan.%Get("tables").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tTable) {
                Set tTables = tTables _ $ListBuild(tTable)
            }
        }
        Set tSC = ..Check(tPlan.%Get("page"), tTables, .tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        Set tRunSC = $ClassMethod(..#PORTCLASS, "BrowseRun", tNamespace, tPlan, .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tRunSC) {
            Set tSC = ##class(OcuPilot.Area.Explorer.SqlConsole).RenderFault(tRunSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the data browser's read failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Refuse a caller who does not hold the screen's pairs, the custom resource on its own classic
/// page and on <parameter>VIEWPAGE</parameter> among them (AD-8, AD-44): <var>pRefused</var> 1 means
/// the envelope is written. A requirement that could not be read is refused too.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    Set tPairs = ##class(OcuPilot.Screen.Gate).WithClassicPages(##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .tResolved), ..#VIEWPAGE)
    If tResolved && ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Ask <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method> about <var>pText</var>
/// and <var>pTables</var>, the tables it reads: <var>pRefused</var> 1 means the 403 envelope, or the
/// generic 500 when the check could not be answered, is written.</p>
ClassMethod Check(pText As %String, pTables As %List, Output pRefused As %Boolean) As %Status [ Private ]
{
    Set pRefused = 0
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SqlStatement(pText, pTables, 1, .tProhibits, .tCode)
    If $$$ISERR(tSC) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
    }
    If 'tProhibits Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), tCode)
}

/// <p>The 400 <code>EXPLORER.DATA.INPUT</code> envelope.</p>
ClassMethod RenderInput() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#REASONDATAINPUT, ##class(OcuPilot.Api.AtelierError).#DATAINPUT)
}

}
