/// <p>The port to the LLM (AD-42). It owns the outbound edge: the gate, the call-time address
/// check, the adapter the catalog row names, and the TLS, proxy and timeout configuration the
/// request carries.</p>
/// <p><b>Two entry points.</b> <method>Invoke</method> runs against a definition stored in
/// OcuPilot's protected database, which is what a turn calls. <method>InvokeDraft</method> runs
/// against values a caller supplied, which is what Story 3.4's Test connection calls so an
/// operator can check a definition as edited rather than as saved.</p>
/// <p><b>The gate, and why it is not simply <code>OcuPilotAdmin</code></b> (AD-29). The rationale
/// behind every other port's gate -- a metric, a log line and an audit row reach a user through
/// OcuPilot only if that user could have read them directly -- does not transfer, because a
/// provider call reads nothing of the instance's. What it spends is the instance's credential
/// against an endpoint an administrator already chose. So the gate is in two parts, both named and
/// both evaluated here: <b>every</b> entry refuses an unauthenticated principal
/// (<code>AUTH.ANONYMOUS</code>, AD-21), and the <b>draft</b> entry additionally requires
/// <code>OcuPilotAdmin:USE</code> (<code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>), because values that never passed the write gate have not had
/// AD-42's endpoint rules applied to them. An ordinary user running a turn goes through
/// <method>Invoke</method>, whose endpoint came from the protected database.</p>
/// <p><b>The endpoint is judged again here</b> (DW-21). Write time alone is defeated by a name
/// repointed after the save; call time alone pays a resolver lookup on every turn and tells the
/// operator nothing while they are configuring. So both, and neither closes the gap completely:
/// <class>%Net.HttpRequest</class> resolves the name itself when it connects, and there is no
/// supported way to hand it a pre-resolved address while keeping SNI and the certificate identity
/// match for that hostname, so the answer can still change between this lookup and the socket's
/// (inference). What actually contains an
/// HTTPS endpoint is the configuration's <code>VerifyPeer</code> plus the request's
/// <code>SSLCheckServerIdentity</code>: a rebound address cannot present a certificate for the
/// configured hostname. Which is why this check matters most on the marked-local plain-HTTP path,
/// where there is no TLS identity left to check.</p>
/// <p><b>Every entry returns <code>$$$OK</code></b> (AD-12, AD-39, AD-42). A failure is
/// <var>pResponse</var>'s stop reason <code>"error"</code> plus <var>pFault</var> and
/// <var>pHttpStatus</var> -- the shape <method>OcuPilot.Port.LogSourcePort.Page</method>
/// established. No exception reaches a caller.</p>
/// <p><b>Nothing here reads read-only or the kill switch.</b> Those have a single enforcement
/// point and it is Story 3.7's (AD-30); a second one here would be a second thing to keep correct.
/// Nothing here escalates, spawns, or writes to the response device.</p>
Class OcuPilot.Port.ProviderPort Extends %RegisteredObject
{

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The credential class an adapter resolves through on this port's calls.</p>
Parameter SECRETCLASS = "OcuPilot.Kernel.Secret.Ladder";

/// <p>The catalog the adapter class, the key prefix and the local escape are read from.</p>
Parameter CATALOGCLASS = "OcuPilot.Kernel.Provider.Catalog";

/// <p>The pair set <method>InvokeDraft</method> requires, comma-separated as
/// <code>resource:permission</code>: OcuPilot's own administrative resource, which is what the
/// write gate on the endpoint field requires too.</p>
Parameter DRAFTPAIRS = "OcuPilotAdmin:USE";

/// <p>The subsystem this port's log lines are written under.</p>
Parameter LOGSUBSYSTEM = "providerport";

/// <p>Make one provider call against the stored definition <var>pDefinitionId</var>.
/// <b>Always returns <code>$$$OK</code></b>; see this class's header for the output shape.</p>
/// <p><var>pMessages</var> and <var>pTools</var> are the arrays
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> documents. Epic 4's turn is the caller.</p>
/// <p>Refuses <code>PROVIDER.UNCONFIGURED</code> for an id no definition holds: a caller that
/// named a definition that has been deleted gets a named refusal rather than a 500.</p>
/// <p><b>Caller contract:</b> must not be called from an escalated frame (AD-9); the caller's
/// namespace is unchanged on return.</p>
ClassMethod Invoke(pDefinitionId As %String = "", ByRef pMessages, ByRef pTools, pSystemPrompt As %String = "", Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ..Blank(.pResponse, .pHttpStatus, .pFault)
    Try {
        If '..Authenticated(.pHttpStatus, .pFault) Quit
        Set tSC = ..ValuesFor(pDefinitionId, .tValues, .tFound)
        If $$$ISERR(tSC) {
            Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
            Do ..LogRaw("the agent definition a provider call named could not be read", tSC, ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED)
            Quit
        }
        If 'tFound {
            Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
            Quit
        }
        ; A definition Story 3.1's write path disabled is not usable, and this is the one place
        ; that decision is spent: without the test, changing an endpoint or a credential reference
        ; clears the flag and the next turn calls the definition anyway. InvokeDraft deliberately
        ; does not make it -- testing a definition that is disabled is what re-enables it.
        If '+$Get(tValues("enabled")) {
            Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
            Quit
        }
        Do ..Dispatch(.tValues, .pMessages, .pTools, pSystemPrompt, .pResponse, .pHttpStatus, .pFault)
    } Catch ex {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, .pHttpStatus, .pFault)
        Do ..LogRaw("a provider call failed inside the port", ex.AsStatus(), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
    }
    Quit $$$OK
}

/// <p>Make one provider call against <var>pValues</var> -- a definition as a caller supplied it,
/// subscripted by wire field name -- rather than against a stored row. <b>Always returns
/// <code>$$$OK</code></b>.</p>
/// <p><b>Additionally requires <parameter>DRAFTPAIRS</parameter></b>, because these values have
/// not passed the write gate AD-42 puts on the endpoint field. The address rules are applied here
/// regardless, so the privilege buys the ability to try an unsaved definition, never the ability
/// to name an address the rules refuse. The definition's <code>Enabled</code> flag is not
/// consulted: testing a definition the write path disabled is how an operator re-enables it.</p>
/// <p><b><var>pValues</var> is normalized and added to in place.</b> The caller's array comes back
/// carrying the catalog row's <code>keyPrefix</code> and <code>authVersion</code>, and its
/// <code>endpointUrl</code> filled in from the row when it was empty. A caller that keeps the
/// array -- an operator's edited form, say -- sees those keys afterwards.</p>
ClassMethod InvokeDraft(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String = "", Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ..Blank(.pResponse, .pHttpStatus, .pFault)
    Try {
        If '..Authenticated(.pHttpStatus, .pFault) Quit
        Set tFailedPair = ""
        If '..Gate(..DraftPairs(), .tFailedPair) {
            Set tDetail = ""
            If tFailedPair '= "" {
                Set tDetail = {}
                Do tDetail.%Set("failedPair", tFailedPair)
            }
            Set pHttpStatus = 403
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "This account may not test an unsaved agent definition")
            If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
            Quit
        }
        Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.pValues)
        Do ..Dispatch(.pValues, .pMessages, .pTools, pSystemPrompt, .pResponse, .pHttpStatus, .pFault)
    } Catch ex {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, .pHttpStatus, .pFault)
        Do ..LogRaw("a draft provider call failed inside the port", ex.AsStatus(), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
    }
    Quit $$$OK
}

/// <p>Everything both entries do once the gate has answered: resolve the provider's catalog row,
/// judge the endpoint's resolved address, resolve the instance's outbound settings, confirm the
/// TLS configuration, and hand the call to the adapter the row names.</p>
/// <p><b>The adapter comes from the row's <code>adapterClass</code> column and from nowhere
/// else.</b> No branch here reads a provider key, so a second family is one row plus one class
/// (AC1).</p>
ClassMethod Dispatch(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String, ByRef pResponse As OcuPilot.Kernel.Provider.Response, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) [ Private ]
{
    If '$ClassMethod(..CatalogClass(), "Row", $Get(pValues("provider")), .tRow) {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
        Quit
    }
    Set tAdapterClass = tRow.adapterClass
    If (tAdapterClass = "") || '##class(%Dictionary.CompiledClass).%ExistsId(tAdapterClass) {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
        Quit
    }
    Set pValues("keyPrefix") = tRow.keyPrefix
    Set pValues("authVersion") = tRow.authVersion
    Set tAllowsLocal = ''+tRow.allowsLocal
    Set tMarkedLocal = ''+$Get(pValues("markedLocal"))

    ; The endpoint a create left empty is the row's canonical one, exactly as a create resolves it.
    If $Get(pValues("endpointUrl")) = "" Set pValues("endpointUrl") = tRow.defaultEndpoint
    Set tEndpoint = $Get(pValues("endpointUrl"))
    If tEndpoint = "" {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
        Quit
    }
    ; Both halves of AD-42's endpoint rule, re-applied at the moment of the call: the scheme, and
    ; the resolved address. A stored endpoint that was accepted under a catalog row which has since
    ; stopped allowing local is refused here, not called.
    If '##class(OcuPilot.Kernel.AgentRules).SchemeAccepted(tEndpoint, tMarkedLocal, tAllowsLocal) {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDEREGRESS, .pHttpStatus, .pFault)
        Quit
    }
    If '##class(OcuPilot.Kernel.Egress).IsPermitted(tEndpoint, tMarkedLocal, tAllowsLocal, .tKind) {
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDEREGRESS, .pHttpStatus, .pFault)
        ; Which of the four kinds it was goes to the log, not to the envelope: the four are one
        ; refusal to a caller, and an operator debugging a rebound endpoint needs to know whether
        ; the name now answers loopback, link-local, this instance, or nothing at all.
        Do ..LogRaw("the endpoint this call names was refused by the address policy", $$$ERROR($$$GeneralError, "resolved address kind: " _ tKind), ##class(OcuPilot.Api.Error).#PROVIDEREGRESS)
        Quit
    }

    Set tSettingsSC = ##class(OcuPilot.Kernel.State.Egress).Resolve(.tSettings)
    If $$$ISERR(tSettingsSC) {
        ; Resolve answers the shipped defaults whatever happened, so the call proceeds; the reason
        ; it could not read the stored row goes to the log.
        Do ..LogRaw("the instance's outbound settings could not be read; the shipped defaults are in force for this call", tSettingsSC, "")
    }
    If ..IsHttps(tEndpoint) {
        If ..SslConfigurationMissing(tSettings("sslConfiguration")) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Provider.Base).HttpFor(##class(OcuPilot.Api.Error).#PROVIDERTLS)
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PROVIDERTLS, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(##class(OcuPilot.Api.Error).#PROVIDERTLS) _ ": " _ tSettings("sslConfiguration"))
            Quit
        }
    } Else {
        ; A marked-local plain-HTTP endpoint carries no TLS at all, so the configuration name is
        ; cleared rather than set on a request that will never negotiate.
        Set tSettings("sslConfiguration") = ""
    }

    Set tAdapter = $ClassMethod(tAdapterClass, "%New")
    If '$IsObject(tAdapter) || 'tAdapter.%IsA("OcuPilot.Kernel.Provider.Base") {
        Set tAdapter = ""
        Do ..Refuse(##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, .pHttpStatus, .pFault)
        Quit
    }
    Set tAdapter.SecretClassName = ..SecretClass()
    Do tAdapter.Invoke(.pValues, .pMessages, .pTools, pSystemPrompt, .tSettings, .pResponse, .pFault, .pHttpStatus)
    ; Dropped as soon as the call returns: the adapter clears its own key, and releasing the last
    ; reference to it is what ends the object's life rather than leaving it in this frame.
    Set tAdapter = ""
}

/// <p>The stored definition <var>pId</var> as the ByRef value array the adapter reads.
/// <var>pFound</var> is 0 for an id no row holds -- an ordinary answer, never an error, so a
/// deleted definition and a failed read stay distinguishable.</p>
ClassMethod ValuesFor(pId As %String, Output pValues, Output pFound As %Boolean) As %Status [ Private ]
{
    Kill pValues
    Set pFound = 0
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(pId, .tExists)
    If $$$ISERR(tSC) Quit tSC
    If 'tExists Quit $$$OK
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$OK
    Set pValues("provider") = tRow.Provider
    Set pValues("model") = tRow.Model
    Set pValues("endpointUrl") = tRow.EndpointUrl
    Set pValues("markedLocal") = ''tRow.MarkedLocal
    Set pValues("enabled") = ''tRow.Enabled
    Set pValues("credType") = tRow.CredType
    Set pValues("envVarName") = tRow.EnvVarName
    Set pValues("credentialName") = tRow.CredentialName
    Set pValues("maxTokens") = +tRow.MaxTokens
    Set pValues("temperature") = +tRow.Temperature
    Set pValues("systemPromptOverride") = tRow.SystemPromptOverride
    Set tRow = ""
    Set pFound = 1
    Quit $$$OK
}

/// <p>Whether the calling process is an authenticated principal; sets the
/// <code>AUTH.ANONYMOUS</code> refusal when it is not (AD-21).</p>
/// <p>The test itself is <method>OcuPilot.Screen.Gate.IsAuthenticatedPrincipal</method>'s, which
/// the router's identity gate calls too, so the two cannot drift.</p>
ClassMethod Authenticated(ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Boolean [ Private ]
{
    If $ClassMethod(..GateClass(), "IsAuthenticatedPrincipal", ..ResolvedUsername()) Quit 1
    Set pHttpStatus = 401
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAUTHORIZED, ##class(OcuPilot.Api.Error).#AUTHANONYMOUS, "Authentication required")
    Quit 0
}

/// <p>Whether the calling process holds every pair in <var>pPairs</var>, asked of
/// <method>GateClass</method>'s evaluator so the check and the spelling of a failure are the
/// gate's and not a second copy.</p>
ClassMethod Gate(pPairs As %List, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Quit $ClassMethod(..GateClass(), "EvaluatePairs", pPairs, .pFailedPair)
}

/// <p><parameter>DRAFTPAIRS</parameter> as the <code>(resource, permission)</code> list the gate
/// takes.</p>
ClassMethod DraftPairs() As %List
{
    Set tPairs = ""
    For tI = 1:1:$Length(..#DRAFTPAIRS, ",") {
        Set tPair = $Piece(..#DRAFTPAIRS, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

/// <p>The class <method>Gate</method> and <method>Authenticated</method> ask. Overridable so a
/// fixture can drive a denial in process -- <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real <code>$System.Security.Check</code> answers yes to every
/// resource name. Production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The credential class this port's calls resolve through, handed to the adapter for the life
/// of one call. Overridable so <class>OcuPilot.Test.ProviderSecret</class> can put a canary in
/// play without setting anything on the instance. Production never overrides it.</p>
ClassMethod SecretClass() As %String
{
    Quit ..#SECRETCLASS
}

/// <p>The catalog the adapter class and the local escape are read from. Overridable so a test can
/// drive the registry against a second row at a floor whose shipped table holds one; production
/// never overrides it.</p>
ClassMethod CatalogClass() As %String
{
    Quit ..#CATALOGCLASS
}

/// <p>The authenticated user this call is made as. Its own method for the reason
/// <method>OcuPilot.Api.Router.ResolvedUsername</method> is: it is the one thing a test has to be
/// able to answer differently to drive the anonymous refusal at all.</p>
ClassMethod ResolvedUsername() As %String
{
    Quit $Username
}

/// <p>Whether <var>pUrl</var>'s scheme is <code>https</code>, matched case-insensitively the way
/// a URI scheme is.</p>
ClassMethod IsHttps(pUrl As %String) As %Boolean [ Private ]
{
    Quit ($ZConvert($Piece(pUrl, "://", 1), "L") = "https")
}

/// <p>Whether <var>pName</var> is <b>known</b> to be absent from this instance's TLS
/// configurations: 1 only when the check ran and answered "no such configuration".</p>
/// <p><b>A check that could not run answers 0, and the call proceeds.</b>
/// <class>Security.SSLConfigs</class> exists only in <code>%SYS</code> (probed: it is not compiled
/// into the install namespace) and lives behind the security database, so a caller without
/// privilege on it cannot perform this read -- and this port escalates for nothing (AD-8). Refusing
/// on a check that did not happen would refuse every turn for every ordinary user; proceeding
/// leaves such a caller with the transport error the missing configuration causes anyway, while an
/// administrator -- who is who configures this, and who AC3's scenario is about -- gets the named
/// <code>PROVIDER.TLS</code> refusal. OcuPilot still never falls back to another configuration and
/// never proceeds unencrypted: the request carries the name it was given, and nothing else.</p>
/// <p>The namespace is entered once, by explicit save and restore, with the restore as the first
/// line of the <code>Catch</code> (AD-16), and no OcuPilot class is dispatched to inside the
/// window. Overridable so a fixture can drive the refusal without touching <code>%SYS</code>.</p>
ClassMethod SslConfigurationMissing(pName As %String) As %Boolean
{
    Set tMissing = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If pName = "" Quit
        Set $NAMESPACE = "%SYS"
        Set tMissing = '##class(Security.SSLConfigs).Exists(pName, .tConfig, .tStatus)
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tMissing = 0
    }
    Quit tMissing
}

/// <p>Set the three outputs to the shape a failure carries, so every refusal below can set only
/// what it changes and a caller always has a response object to read.</p>
ClassMethod Blank(Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) [ Private ]
{
    Set pResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set pResponse.StopReason = "error"
    Set pHttpStatus = 0
    Set pFault = ""
}

/// <p>A refusal this port decided itself, with the written reason and the HTTP status
/// <class>OcuPilot.Kernel.Provider.Base</class> holds for the code -- one home for those
/// sentences, so the port and the adapter cannot word the same code two ways.</p>
ClassMethod Refuse(pCode As %String, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) [ Private ]
{
    Do ##class(OcuPilot.Kernel.Provider.Base).Fault(pCode, "", "", .pFault, .pHttpStatus)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39).</p>
ClassMethod LogRaw(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

}
