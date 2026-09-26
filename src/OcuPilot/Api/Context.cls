/// <p>The handler behind <code>GET</code>/<code>PUT /agent/context</code> (Story 4.4, FR-11):
/// the caller's own screen-context sharing choice, the instance default, the resolved row cap, and
/// where a turn's provider call goes.</p>
/// <p><b>Caller-own and ungated beyond the router</b> -- like <code>GET /agent/restraint</code>
/// (<class>OcuPilot.Api.Switches</class>'s own header explains why): this answers the calling
/// user their own choice and the instance's public-facing facts about where context goes, never
/// another user's row and never a write to anything but the caller's own choice.</p>
Class OcuPilot.Api.Context Extends %RegisteredObject
{

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>GET /agent/context</code>: the caller's effective sharing choice, the instance
/// default, the caller's own stored choice (<code>null</code> when they have none), the resolved
/// row cap, and where a turn's provider call would go.</p>
ClassMethod HandleRead() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Body(..CallerUsername(), .tBody)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /agent/context {share: boolean}</code>: store the caller's choice and
/// answer the same body <method>HandleRead</method> would. A body carrying anything else --
/// missing, badly typed, or an extra member -- is refused 422
/// <parameter>OcuPilot.Api.Error.AGENTCONTEXTSHARE</parameter> before anything is written.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tRequestBody, .tStage)
        If $$$ISERR(tReadSC) && (tStage '= "parse") {
            ; A read or decode fault is not a share violation, so it takes the bad-body refusal
            ; rather than this route's 422. Since REASONAGENTBADBODY carries no stage, the two are
            ; told apart by their codes -- AGENT.BADBODY against AGENT.CONTEXT.SHARE -- and the
            ; raw status reaches the log through Fault.LogRaw (DW-24, DW-447).
            Set tSC = ##class(OcuPilot.Api.Switches).RenderBadBody(tReadSC)
            Quit
        }
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderShareViolation()
            Quit
        }
        If '$IsObject(tRequestBody) || 'tRequestBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..RenderShareViolation()
            Quit
        }
        Set tExtra = 0
        Set tIterator = tRequestBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tIgnored) {
            If tKey '= "share" Set tExtra = 1
        }
        If tExtra || (tRequestBody.%GetTypeOf("share") '= "boolean") {
            Set tSC = ..RenderShareViolation()
            Quit
        }
        Set tShare = ''tRequestBody.%Get("share")
        Set tUser = ..CallerUsername()
        Set tSetSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(tUser, tShare)
        If $$$ISERR(tSetSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSetSC))
            Quit
        }
        Set tSC = ..Body(tUser, .tBody)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The status body for <var>pUser</var>: <code>{share, shareDefault, userChoice, contextRowCap,
/// provider, endpointHost, leavesInstance}</code>.</p>
ClassMethod Body(pUser As %String, Output pBody As %DynamicObject) As %Status [ Private ]
{
    Set pBody = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitchValues)
        If $$$ISERR(tSC) Quit
        Set tShareDefault = ''tSwitchValues("shareContextByDefault")
        Set tRowCap = +tSwitchValues("contextRowCap")

        Set tSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(pUser, .tFound, .tShareValue)
        If $$$ISERR(tSC) Quit
        Set tUserChoice = $Select(tFound: ''tShareValue, 1: "")
        Set tEffectiveShare = $Select(tFound: ''tShareValue, 1: tShareDefault)

        Set tProvider = ""
        Set tHost = ""
        Set tLeaves = ""
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefinitionId)
        If $$$ISERR(tSC) Quit
        If tDefinitionId '= "" {
            If ##class(OcuPilot.Port.ProviderPort).ResolveEndpoint(tDefinitionId, .tProvider, .tHost, .tMarkedLocal, .tProxyHost) {
                Set tLeaves = ##class(OcuPilot.Kernel.Egress).LeavesInstance(tHost, tMarkedLocal, tProxyHost)
            } Else {
                Set tProvider = ""
                Set tHost = ""
            }
        }

        Set pBody = {}
        Do pBody.%Set("share", ''tEffectiveShare, "boolean")
        Do pBody.%Set("shareDefault", ''tShareDefault, "boolean")
        If tUserChoice = "" {
            Do pBody.%Set("userChoice", "", "null")
        } Else {
            Do pBody.%Set("userChoice", ''tUserChoice, "boolean")
        }
        Do pBody.%Set("contextRowCap", tRowCap, "number")
        Do pBody.%Set("provider", tProvider, "string")
        Do pBody.%Set("endpointHost", tHost, "string")
        If tLeaves = "" {
            Do pBody.%Set("leavesInstance", "", "null")
        } Else {
            Do pBody.%Set("leavesInstance", ''tLeaves, "boolean")
        }
    } Catch ex {
        Set pBody = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse with 422 <parameter>OcuPilot.Api.Error.AGENTCONTEXTSHARE</parameter>; nothing is
/// written.</p>
ClassMethod RenderShareViolation() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONAGENTCONTEXTSHARE, ##class(OcuPilot.Api.Error).#AGENTCONTEXTSHARE)
}

}
