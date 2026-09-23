/// <p>The handler behind <code>POST /api/ocupilot/screens/:screen/action</code>: a person's own
/// row action, on the screen addressed by its <code>toolIdentifier</code> (AD-5, AD-53). One
/// generic route serves every screen, so adding a row action adds no route.</p>
/// <p><b>It is the screen's caller of the operation the confirm path also reaches</b> (AD-53).
/// The fresh read, the privilege pairs, AD-10's prohibited set and the port call are
/// <class>OcuPilot.Kernel.Proposal.Operation</class>'s, shared byte for byte with
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>. What this caller does <b>not</b> do is mint a
/// proposal, take a confirm token, emit an OcuPilot audit marker or consult the restraint verdict:
/// a person pressing a row action has expressed the intent directly (AD-6, AD-15, AD-49), this
/// <b>is</b> the human write an agent marker exists to be distinguished from, and FR-20 publishes
/// that all screens continue to work with the agent disabled.</p>
/// <p><b>User-originated by construction.</b> It is not a tool, is not in the registry, and is
/// reached only by an authenticated browser request -- the same barrier AD-40 puts in front of
/// confirm, arrived at the other way round.</p>
/// <p><b>Which operation an action runs is the write tool's own declaration</b>
/// (<parameter>OcuPilot.Screen.Tool.Write.SCREENACTIONS</parameter>): the route resolves the
/// descriptor's declared action id to the one registered write tool that carries it, and sends
/// that tool's own argument. Nothing here knows what "enable" means.</p>
/// <p><b>The body computed for a merge write is the instance's own merge</b> (AD-4): read fresh,
/// apply the declared argument, send the complete property set -- the same
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> the agent's proposal is built with, so no
/// second code path writes a field.</p>
/// <p>Seams a fixture subclass overrides: <method>RegistryClass</method>,
/// <method>ToolRegistryClass</method>, <method>PortClass</method> and
/// <method>ProhibitedClassName</method>. Production overrides none of them.</p>
Class OcuPilot.Api.ScreenAction Extends %RegisteredObject
{

/// <p>The screen registry the descriptor is resolved from.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>The tool registry the action's write tool is resolved from.</p>
ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>The port a tool that declares the base's own default resolves to (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>AD-10's prohibited set, named exactly as the confirm path names it so the two callers ask
/// one set.</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass()
}

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it. Never taken from the body.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer the request for <var>pScreen</var>, a <code>toolIdentifier</code>. The body is
/// <code>{action, id}</code>: the row action the descriptor declares, and the target the screen's
/// own list reports. On success, one envelope carrying
/// <code>{action, target: {type, scope, id}}</code> -- the AD-14 change event's own triple and
/// verb, which the client publishes rather than inferring.</p>
ClassMethod Handle(pScreen As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForTool", pScreen)
        If tDescriptor = "" {
            Set tSC = ..NotFound()
            Quit
        }

        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) {
            If tStage = "parse" {
                Set tSC = ..BadBody()
            } Else {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            }
            Quit
        }
        If '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..BadBody()
            Quit
        }
        Set tActionId = tBody.%Get("action")
        Set tSuppliedId = tBody.%Get("id")

        ; The action has to be one this screen declares. A screen declares what a row offers
        ; (AD-5); a request naming anything else is addressing an operation that is not there.
        If (tActionId = "") || '$ListFind($ClassMethod(tDescriptor, "RowActionIds"), tActionId) {
            Set tSC = ..NotFound()
            Quit
        }

        ; And it has to be one a registered write tool carries out. A declared action with no tool
        ; is a client-registered one -- the Definitions list's Create opens a form -- and this
        ; route is not its address.
        Set tResolveSC = ..ToolFor(tDescriptor, tActionId, .tTool, .tToolClass)
        If $$$ISERR(tResolveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tResolveSC))
            Quit
        }
        If '$IsObject(tTool) {
            Set tSC = ..NotFound()
            Quit
        }

        ; AD-13: the reference key and the id the port is asked about are both the canonical form
        ; for this entity type, so a re-cased or slash-suffixed spelling earns one verdict from the
        ; prohibited set, takes one lock and publishes one change event.
        Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
        Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, tSuppliedId)
        If tId = "" {
            Set tSC = ..Refuse("'id' names the target and cannot be empty")
            Quit
        }
        Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope"))
        Set tKeySC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, tScope, tId, .tTargetRef)
        If $$$ISERR(tKeySC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tKeySC))
            Quit
        }

        Set tSC = ..Run(tTool, tToolClass, tActionId, tType, tScope, tId, tTargetRef)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The fresh read, the body, the two shared gates and the write, in that order, answering one
/// envelope.</p>
/// <p><b>Nothing sits between the gates and the write</b> (AD-34, AD-53): the prohibited set reads
/// live state, so the answer cannot be separated from the effect it decides.</p>
ClassMethod Run(pTool As %DynamicObject, pToolClass As %String, pActionId As %String, pType As %String, pScope As %String, pId As %String, pTargetRef As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tEndpoint = $ClassMethod(pToolClass, "Endpoint")
        Set tIdParam = $ClassMethod(pToolClass, "IdParam")
        If (tEndpoint = "") || (tIdParam = "") {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the screen action could not address the target of '" _ $ClassMethod(pToolClass, "ToolClass") _ "'")))
            Quit
        }

        Set tFreshSC = ##class(OcuPilot.Kernel.Proposal.Operation).Read(pToolClass, ..PortClass(), tEndpoint, tIdParam, pId, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tFreshSC) {
            Set tSC = ..Fault(tFreshSC, tReadHttp, .tReadFault)
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = ..NotFound()
            Quit
        }

        Set tArgs = $ClassMethod(pToolClass, "ScreenActionArguments", pActionId, .tServes)
        Set tBuildSC = ..Body(pToolClass, tFresh, tArgs, .tPayload, .tDiff, .tProblem)
        If $$$ISERR(tBuildSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tBuildSC))
            Quit
        }
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem)
            Quit
        }

        Set tPayloadJson = tPayload.%ToJSON()
        Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(pTool, pTargetRef, tPayloadJson, tDiff.%ToJSON(), tArgs.%ToJSON(), ..CallerUsername(), ..ProhibitedClassName(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
        If $$$ISERR(tGateSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tGateSC))
            Quit
        }
        If tRefused {
            Set tSC = ##class(OcuPilot.Api.Error).Render(tGateHttp, ##class(OcuPilot.Api.Error).#FORBIDDEN, ..ReasonFor(tGateCode), tGateCode, tGateDetail)
            Quit
        }

        Set tSendsBody = ##class(OcuPilot.Kernel.Proposal.Operation).SendsBody(pToolClass)
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).Apply(pToolClass, ..PortClass(), tEndpoint, tIdParam, pId, tPayloadJson, $Select(tSendsBody: tPayload, 1: ""), .tWritten, .tWriteHttp, .tWriteFault)
        If $$$ISERR(tWriteSC) {
            Set tSC = ..Fault(tWriteSC, tWriteHttp, .tWriteFault)
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Wire(pType, pScope, pId, .tTarget)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tResult = {}
        ; AD-14: the verb is the tool's declaration, never the client's inference from the shape of
        ; a diff, and the triple is the canonical one the write was made against.
        Do tResult.%Set("action", ##class(OcuPilot.Kernel.Proposal.Operation).ChangeAction(pToolClass), "string")
        Do tResult.%Set("target", tTarget)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The body this action sends and the diff it makes, from the fresh read <var>pFresh</var> and
/// the tool's own declared arguments <var>pArgs</var>.</p>
/// <p>A <b>merge</b> write's body is the whole property set with the argument applied (AD-4), as
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> computes it for the agent's own proposal.
/// An <b>action-style</b> write sends none, so its stored payload is the fresh read projected to
/// the fingerprint subject and its rows are the tool's own <method>StateDiff</method> (AD-51) --
/// which is what the prohibited set's changed-field sweep is then handed, exactly as at a
/// confirm.</p>
ClassMethod Body(pToolClass As %String, pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pProblem As %String) As %Status [ Private ]
{
    Set pPayload = {}
    Set pDiff = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), .pPayload, .pDiff, .tUnchanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        If ##class(OcuPilot.Kernel.Proposal.Operation).SendsBody(pToolClass) Quit

        Set tStateSC = $ClassMethod(pToolClass, "StateDiff", pFresh, .tRows, .pProblem)
        If $$$ISERR(tStateSC) {
            Set tSC = tStateSC
            Quit
        }
        If pProblem '= "" Quit
        Set pDiff = []
        If $IsObject(tRows) {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If $IsObject(tRow) Do pDiff.%Push(tRow)
            }
        }
        Set tSubject = $ClassMethod(pToolClass, "FingerprintSubject")
        If tSubject = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Projection(pPayload, tSubject, .pPayload)
    } Catch ex {
        Set pPayload = {}
        Set pDiff = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The one write tool registered against <var>pDescriptor</var> that carries out
/// <var>pActionId</var> (<parameter>OcuPilot.Screen.Tool.Write.SCREENACTIONS</parameter>), or
/// <code>""</code> in <var>pTool</var> when no tool declares it.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set pTool = ""
    Set pToolClass = ""
    Set tSC = $ClassMethod(..ToolRegistryClass(), "ListTools", .tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) Continue
        If tEntry.%Get("kind") '= "write" Continue
        Set tClass = tEntry.%Get("class")
        If tClass = "" Continue
        If $Parameter(tClass, "DESCRIPTORCLASS") '= pDescriptor Continue
        If '$ListFind($ClassMethod(tClass, "ScreenActionIds"), pActionId) Continue
        Set pTool = tEntry
        Set pToolClass = tClass
        Quit
    }
    Quit $$$OK
}

/// <p>The written sentence <var>pCode</var> carries, from the proposal family's own resolver --
/// which is where the <code>PROHIBITED.*</code> reasons live -- else the tool-result vocabulary's,
/// where <code>AUTH.NOPRIVILEGE</code> already is (AD-39).</p>
ClassMethod ReasonFor(pCode As %String) As %String [ Private ]
{
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(pCode)
    If tReason '= "" Quit tReason
    Quit ##class(OcuPilot.Api.Error).ReasonForToolCode(pCode)
}

/// <p>Render a port fault as the one envelope it already is, carrying its own status, code and
/// structured detail (AD-12, AD-39). A fault the port did not name is an internal error rather
/// than an envelope with an empty code.</p>
ClassMethod Fault(pStatus As %Status, pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%Get("code") = "") || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pStatus))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttpStatus: +pHttpStatus, 1: 500), pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), pFault.%Get("detail"))
}

/// <p>The framework's own not-found envelope: an unknown screen, an action the screen does not
/// declare, an action no write tool carries out, and a target this instance no longer holds are
/// the same answer -- there is no operation at that address.</p>
ClassMethod NotFound() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
}

/// <p>A refusal the request or the target's own state earned: 400 <code>TOOL.ARGUMENTS</code> with
/// <var>pProblem</var> as <code>detail.problem</code>, the shape the mint answers its own
/// refusals in.</p>
ClassMethod Refuse(pProblem As %String) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
}

/// <p>The unreadable-body refusal, the same envelope every other JSON handler gives it.</p>
ClassMethod BadBody() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
}

}
