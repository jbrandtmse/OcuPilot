/// <p>The one provider base (AD-42). <method>Invoke</method> is the template every family's
/// adapter is driven through: resolve the credential, gate its shape, build the request, issue it,
/// retry only where a retry is warranted, and hand back a
/// <class>OcuPilot.Kernel.Provider.Response</class> and, on a failure, a wire fault carrying a
/// <code>PROVIDER.*</code> code.</p>
/// <p><b><method>Invoke</method> returns <code>$$$OK</code> on every path.</b> A failure is
/// <property>OcuPilot.Kernel.Provider.Response.StopReason</property> <code>"error"</code> plus the
/// fault and HTTP status in the two output arguments -- the shape
/// <method>OcuPilot.Port.LogSourcePort.Page</method> already established (AD-12, AD-39, AD-42). An
/// exception never reaches a caller, and <class>OcuPilot.Test.Provider</class> asserts the
/// <code>$$$OK</code> on every failure class, which is what makes "never throws" falsifiable
/// rather than a claim about code nothing made fail.</p>
/// <p><b>The credential lives on <property>ApiKey</property> and nowhere else</b> (AD-35, AD-48).
/// An <code>^%ETN</code> entry captures every local variable at every stack level, and OcuPilot
/// renders that log on its own screens (AD-46), so a frame that held the key in a local would put
/// it on a screen. It is resolved straight onto the property, written from the property onto the
/// request's headers by <method>ApplyAuth</method>, and cleared on every exit including the
/// throwing one. It is never interpolated into a URL, a reason, a status or a log line.</p>
/// <p><b>Retry, and what is never retried.</b> A retry happens only when the provider answered a
/// status <class>OcuPilot.Kernel.Provider.Retry</class> declares retryable, only while attempts
/// remain, and after the greater of the provider's honoured hint and the exponential backoff. A
/// call that <b>raised</b>, and a call that <b>timed out</b>, are never retried at all: the
/// request may already have been processed, so sending it again risks doing the work twice.</p>
/// <p>Seams a subclass overrides: <method>ProviderName</method>, <method>CallMessages</method>,
/// <method>ApplyAuth</method>, <method>IsApiKeyShapeValid</method>, <method>MapResponse</method>
/// and <method>ProviderMessage</method> are the family contract; <method>IssueHttpsPost</method>
/// is the one transport seam, which <class>OcuPilot.Test.ProviderStub</class> replaces so the whole
/// path runs with no socket; <method>SecretClass</method> and <method>Wait</method> are the
/// credential and the sleep. Production overrides none of them.</p>
Class OcuPilot.Kernel.Provider.Base Extends %RegisteredObject [ Abstract ]
{

/// <p>The subsystem every provider log line is written under.</p>
Parameter LOGSUBSYSTEM = "providerport";

/// <p>The resolved credential, for the life of one <method>Invoke</method> and no longer.</p>
/// <p><code>Internal</code> keeps it out of the published class reference; what actually keeps it
/// off a log screen is that it is a <b>property</b> rather than a local, because
/// <code>^%ETN</code> captures the local symbol table and not an object's properties (AD-48). The
/// OREF a local holds stringifies to <code>"5@OcuPilot.Kernel.Provider.Anthropic"</code>.</p>
Property ApiKey As %String(MAXLEN = "") [ Internal ];

/// <p>The prefix <method>IsApiKeyShapeValid</method> requires, taken from the provider's catalog
/// row by <method>Invoke</method> rather than read here, so no adapter reads the catalog.</p>
Property KeyPrefix As %String(MAXLEN = 32);

/// <p>The API version this family's adapter sends, from the same row.</p>
Property AuthVersion As %String(MAXLEN = 32);

/// <p>The credential class this one call resolves through, set by the caller;
/// <code>""</code> means <method>SecretClass</method>'s own answer. It is how
/// <class>OcuPilot.Port.ProviderPort</class>'s own <method>SecretClass</method> seam reaches the
/// adapter, so there is one place a test replaces the ladder rather than one per layer.</p>
Property SecretClassName As %String(MAXLEN = 128);

/// <p>The class a credential reference is resolved through when the caller named none.
/// <b>Overridable</b> so a test can put a canary in play without setting anything on the instance;
/// production never overrides it, and Story 3.3 replaces the class behind it without changing
/// anything here.</p>
ClassMethod SecretClass() As %String
{
    Quit "OcuPilot.Kernel.Secret.Ladder"
}

/// <p>The credential class this call actually uses: the caller's choice where there is one,
/// <method>SecretClass</method>'s otherwise.</p>
Method ResolvedSecretClass() As %String [ Private ]
{
    If ..SecretClassName '= "" Quit ..SecretClassName
    Quit ..SecretClass()
}

/// <p>Make one provider call. <b>Always returns <code>$$$OK</code>.</b></p>
/// <p><var>pValues</var> is the definition as a ByRef array subscripted by wire field name --
/// <code>provider</code>, <code>model</code>, <code>endpointUrl</code>, <code>credType</code>,
/// <code>envVarName</code>, <code>credentialName</code>, <code>maxTokens</code>,
/// <code>temperature</code> -- plus the two the caller took from the provider's catalog row,
/// <code>keyPrefix</code> and <code>authVersion</code>.</p>
/// <p><var>pMessages</var> is <code>pMessages(n, "role")</code> / <code>(n, "content")</code> with
/// <code>pMessages</code> the count; <var>pTools</var> is <code>pTools(n, "name")</code> /
/// <code>("description")</code> / <code>("inputSchema")</code>, the schema a JSON string, with
/// <code>pTools</code> the count. Either may be absent, which means none.
/// <var>pSystemPrompt</var> is sent only when non-empty.</p>
/// <p><var>pSettings</var> is <method>OcuPilot.Kernel.State.Egress.Resolve</method>'s array. The
/// caller resolves it, so the timeout, the attempt bound, the proxy and the TLS configuration name
/// are the instance's stored configuration and never a parameter of this class (AD-32).</p>
/// <p>On success <var>pResponse</var> carries the provider's own stop reason and
/// <var>pFault</var> is <code>""</code>. On any failure <var>pResponse</var>'s stop reason is
/// <code>"error"</code>, <var>pFault</var> is <code>{error, reason, code}</code> plus
/// <code>detail</code> where there is one, and <var>pHttpStatus</var> is the numeric status a
/// route should answer with.</p>
/// <p><b>Caller contract:</b> the endpoint has already been judged
/// (<class>OcuPilot.Kernel.Egress</class>) and the TLS configuration has already been confirmed to
/// exist; this method opens the socket the caller authorized. Must not be called from an escalated
/// frame (AD-9).</p>
/// <p><b>The last two outputs are <code>(pFault, pHttpStatus)</code>, which is the opposite order
/// from <method>OcuPilot.Port.ProviderPort.Invoke</method>'s</b> -- that one follows
/// <method>OcuPilot.Port.LogSourcePort.Page</method>'s established
/// <code>(pResult, pHttpStatus, pFault)</code>. Both are outputs of compatible types, so a
/// transposed call compiles and silently fills the wrong variables. The port is the surface a
/// consumer holds; this method has one caller, and it is that port.</p>
Method Invoke(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String = "", ByRef pSettings, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pFault As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set pResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set pResponse.StopReason = "error"
    Set pFault = ""
    Set pHttpStatus = 0
    Set tStarted = $ZHorolog
    Try {
        Set ..KeyPrefix = $Get(pValues("keyPrefix"))
        Set ..AuthVersion = $Get(pValues("authVersion"))
        ; Assigned straight onto the property: the resolution's value is never bound to a local,
        ; because a local is what an ^%ETN entry captures (AD-48). The ladder's transient flag is
        ; a boolean and carries no text, so binding it is safe; it travels out on pValues, which
        ; is the caller's own array, so the port can tell a reference that resolves to nothing from
        ; one it could not read (DW-343).
        Set ..ApiKey = $ClassMethod(..ResolvedSecretClass(), "Resolve", $Get(pValues("credType")), $Get(pValues("envVarName")), $Get(pValues("credentialName")), .tTransient)
        Set pValues("credentialTransient") = ''+$Get(tTransient)
        If ..ApiKey = "" {
            Do ..Fault(##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL, ..CredentialReason(.pValues), "", .pFault, .pHttpStatus)
            Quit
        }
        If '..IsApiKeyShapeValid() {
            Do ..Fault(##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, ..KeyShapeReason(), "", .pFault, .pHttpStatus)
            Quit
        }
        Do ..Attempts(.pValues, .pMessages, .pTools, pSystemPrompt, .pSettings, .pResponse, .pFault, .pHttpStatus)
    } Catch ex {
        ; Cleared first, before anything that could itself fail: a raise inside this block would
        ; leave the credential on the instance and carry the exception past the $$$OK the signature
        ; promises. The clear below then runs on the ordinary exits.
        Set ..ApiKey = ""
        ; The last resort, and the reason the signature promises $$$OK: anything this method did
        ; not anticipate becomes the same turn error every other failure is. The raw status goes to
        ; the log alone (AD-39).
        Do ..Fault(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "", "", .pFault, .pHttpStatus)
        Do ..LogRaw("the provider call failed inside the adapter", ex.AsStatus(), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
    }
    ; Runs on every exit, the throwing one included.
    Try {
        Set ..ApiKey = ""
        Set tElapsed = $ZHorolog - tStarted
        If tElapsed < 0 Set tElapsed = 0
        Set pResponse.LatencyMs = tElapsed * 1000 \ 1
    } Catch clearEx {
        Set ..ApiKey = ""
    }
    Quit $$$OK
}

/// <p>The attempt loop. Sets <var>pResponse</var> on success and <var>pFault</var> /
/// <var>pHttpStatus</var> on failure; never throws past its own caller, which is
/// <method>Invoke</method>'s outer <code>Catch</code>.</p>
/// <p><b>The exits, and which of them may try again.</b> A request whose body could not be built,
/// a call that raised, and a call that timed out all leave immediately. A non-retryable status
/// leaves immediately with the provider's own message in <code>detail.providerText</code> and its
/// raw body in the log alone. Only a retryable status loops, and only while attempts remain.</p>
Method Attempts(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String, ByRef pSettings, ByRef pResponse As OcuPilot.Kernel.Provider.Response, ByRef pFault As %DynamicObject, ByRef pHttpStatus As %Integer) [ Private ]
{
    Set tUrl = $Get(pValues("endpointUrl"))
    Set tMaxAttempts = +$Get(pSettings("maxAttempts"))
    If tMaxAttempts < 1 Set tMaxAttempts = 1
    Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT
    Set tProviderText = ""
    For tAttempt = 1:1:tMaxAttempts {
        Set tStatus = 0
        Set tBody = ""
        Set tRetryAfter = ""
        Set tThrew = 0
        Set tIssueSC = $$$OK
        Set tRequest = ..NewRequest(.pSettings)
        Set tBuildSC = ..CallMessages(tRequest, .pValues, .pMessages, .pTools, pSystemPrompt)
        If $$$ISERR(tBuildSC) {
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT
            Do ..LogRaw("the provider request body could not be built", tBuildSC, tCode)
            Set tRequest = ""
            Quit
        }
        Do ..ApplyAuth(tRequest)
        Try {
            Set tIssueSC = ..IssueHttpsPost(tRequest, tUrl, .tStatus, .tBody, .tRetryAfter)
        } Catch attemptEx {
            Set tThrew = 1
            Set tIssueSC = attemptEx.AsStatus()
        }
        Set tRequest = ""
        If tThrew {
            ; AD-42: a call that threw mid-flight is never retried -- the request may already have
            ; been processed. The loop ends here rather than continuing.
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT
            Do ..LogRaw("the provider call raised mid-flight", tIssueSC, tCode)
            Quit
        }
        If $$$ISERR(tIssueSC) {
            Set tCode = $Select($System.Status.Equals(tIssueSC, $$$ERRORCODE($$$CSPTimeout)): ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT, 1: ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
            Do ..LogRaw("the provider call failed in transport", tIssueSC, tCode)
            Quit
        }
        Set pResponse.HttpStatus = +tStatus
        If (+tStatus >= 200) && (+tStatus < 300) {
            Set tMapSC = ..MapResponse(tBody, pResponse)
            If $$$ISOK(tMapSC) {
                Set tCode = ""
                Quit
            }
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT
            Do ..LogRaw("the provider answered a body this adapter could not read", tMapSC, tCode)
            Quit
        }
        If '##class(OcuPilot.Kernel.Provider.Retry).IsRetryable(tStatus) {
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERREFUSED
            Set tProviderText = ..ProviderMessage(tBody)
            Do ..LogRaw("the provider refused the request with HTTP " _ +tStatus, $$$ERROR($$$GeneralError, tBody), tCode)
            Quit
        }
        If tAttempt >= tMaxAttempts {
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE
            Do ..LogRaw("the provider answered a retryable status on every attempt, the last HTTP " _ +tStatus, $$$ERROR($$$GeneralError, tBody), tCode)
            Quit
        }
        Do ..Wait(##class(OcuPilot.Kernel.Provider.Retry).DelaySec(tAttempt, tRetryAfter))
    }
    If tCode = "" Quit
    Set pResponse.StopReason = "error"
    Do ..Fault(tCode, "", tProviderText, .pFault, .pHttpStatus)
}

/// <p>A configured <class>%Net.HttpRequest</class> for one attempt.</p>
/// <p>Every value comes from <var>pSettings</var> -- the instance's stored outbound settings --
/// and none from a parameter of this class (AD-32). <property>SSLCheckServerIdentity</property> is
/// set unconditionally: it is what makes the certificate's identity match the hostname (RFC 2818
/// section 3.1), which is the check that actually contains a rebound address, and it is a separate
/// thing from the configuration's own <code>VerifyPeer</code> chain check.</p>
/// <p><var>pSettings</var>'s <code>sslConfiguration</code> is <code>""</code> for a plain-HTTP
/// local endpoint, where there is no TLS to configure; the caller is what blanks it, so this
/// method has no scheme rule of its own.</p>
Method NewRequest(ByRef pSettings) As %Net.HttpRequest
{
    Set tRequest = ##class(%Net.HttpRequest).%New()
    Set tRequest.SSLCheckServerIdentity = 1
    ; A redirect is a host this instance's address policy never judged, and the credential header
    ; travels to it: %Net.HttpRequest re-sends method, body and headers on 307 and 308 without
    ; resetting them. The shipped default is already off for a POST -- it is set here so the
    ; endpoint OcuPilot judged is the only endpoint the key reaches, whatever that default becomes.
    Set tRequest.FollowRedirect = 0
    ; The shipped default is read from the class that owns it rather than spelled again here, and
    ; a non-positive stored value takes it too: %Net.HttpRequest reads Timeout 0 as no wait at all.
    Set tRequest.Timeout = $Select(+$Get(pSettings("timeoutSeconds")) > 0: +pSettings("timeoutSeconds"), 1: ##class(OcuPilot.Kernel.State.Egress).#DEFAULTTIMEOUT)
    If $Get(pSettings("sslConfiguration")) '= "" {
        Set tRequest.SSLConfiguration = pSettings("sslConfiguration")
    }
    If $Get(pSettings("proxyServer")) '= "" {
        Set tRequest.ProxyServer = pSettings("proxyServer")
        If +$Get(pSettings("proxyPort")) > 0 Set tRequest.ProxyPort = +pSettings("proxyPort")
        Set tRequest.ProxyHTTPS = ''+$Get(pSettings("proxyHttps"))
        Set tRequest.ProxyTunnel = ''+$Get(pSettings("proxyTunnel"))
    }
    Quit tRequest
}

/// <p><b>The one transport seam.</b> Issues <var>pRequest</var> as a POST to <var>pUrl</var> and
/// reports the HTTP status, the response body and the <code>Retry-After</code> header value.</p>
/// <p>Returns an error <class>%Status</class> when there was no HTTP answer at all; the three
/// outputs are then meaningless. It may also raise, which the caller treats as a mid-flight
/// failure and never retries.</p>
/// <p><class>OcuPilot.Test.ProviderStub</class> overrides this to answer a queued script of canned
/// triples, so every path above it is exercised with no socket opened. That is why it is an
/// instance method and why it takes the request object rather than building one:
/// <b>the stub records what the request actually carried</b>, which is how AC3's configured-request
/// assertions are made at all.</p>
/// <p><method>%Net.HttpResponse.GetHeader</method> upper-cases the name it is given, so the header
/// matches whatever case the provider sent it in.</p>
Method IssueHttpsPost(pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Set pStatus = 0
    Set pBody = ""
    Set pRetryAfter = ""
    Set tSC = pRequest.Post(pUrl)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pRequest.HttpResponse) {
        Quit $$$ERROR($$$GeneralError, "the provider call returned no response object")
    }
    Set pStatus = +pRequest.HttpResponse.StatusCode
    Set pRetryAfter = pRequest.HttpResponse.GetHeader("Retry-After")
    If $IsObject(pRequest.HttpResponse.Data) {
        Do pRequest.HttpResponse.Data.Rewind()
        While 'pRequest.HttpResponse.Data.AtEnd {
            Set pBody = pBody _ pRequest.HttpResponse.Data.Read(32000)
        }
    }
    Quit $$$OK
}

/// <p>Sleep <var>pSeconds</var> between attempts. Its own method so a test can drive the retry
/// path without waiting out a real backoff; production never overrides it.</p>
Method Wait(pSeconds As %Numeric)
{
    If +pSeconds <= 0 Quit
    Hang +pSeconds
}

/// <p>The provider key this adapter serves. A constant per adapter, and the only place an adapter
/// names its own family -- nothing reads it to choose behaviour, which is the catalog row's
/// <code>adapterClass</code> column's job.</p>
Method ProviderName() As %String [ Abstract ]
{
    Quit ""
}

/// <p>Render this call's model, tuning, system prompt, messages and tools into
/// <var>pRequest</var>'s body. An error <class>%Status</class> means no call is made.</p>
/// <p><b>The body's media type is this method's too</b>, and it must be set <i>after</i> the body
/// is written: <property>%Net.HttpRequest.ContentType</property> is a calculated property over an
/// attribute of the entity-body stream, so clearing that stream clears the media type with it.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status [ Abstract ]
{
    Quit $$$OK
}

/// <p>Write this family's authentication headers onto <var>pRequest</var>.</p>
/// <p><b>Caller contract: read <property>ApiKey</property> and write it onto the request in one
/// statement.</b> Copying it into a local first -- even to build a header list -- puts it in the
/// symbol table an <code>^%ETN</code> entry captures (AD-48, AD-35).</p>
Method ApplyAuth(pRequest As %Net.HttpRequest) [ Abstract ]
{
    Quit
}

/// <p>Whether <property>ApiKey</property> has the shape this family's keys have, which is
/// <property>KeyPrefix</property> at this floor.</p>
/// <p><b>It takes no argument, and that is the contract.</b> The credential is read from the
/// property inside the comparison; passing it in would bind it to a local in this frame, and
/// <code>^%ETN</code> captures every local at every stack level (AD-48, AD-35). Read it the way
/// <method>ApplyAuth</method> does -- straight into the expression that uses it, never into a
/// local first.</p>
Method IsApiKeyShapeValid() As %Boolean [ Abstract ]
{
    Quit 0
}

/// <p>Map a successful response body onto <var>pResponse</var>. An error <class>%Status</class>
/// means the body was not one this adapter could read, which the caller reports as a transport
/// failure rather than as a reply.</p>
Method MapResponse(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status [ Abstract ]
{
    Quit $$$OK
}

/// <p>The provider's own message out of an error body, for the fault's
/// <code>detail.providerText</code>, or <code>""</code>. The <b>message</b> alone: the raw body
/// goes to the log and nowhere else (AD-39).</p>
Method ProviderMessage(pBody As %String) As %String [ Abstract ]
{
    Quit ""
}

/// <p>Build the wire fault for <var>pCode</var> and the HTTP status to answer with.</p>
/// <p><b>Every <code>PROVIDER.*</code> fault carries the <code>unavailable</code> slug.</b> To both
/// consumers of the envelope -- a screen and a tool result -- the event is the same one: the
/// provider is not serving this call. What tells them apart is the code, which is exactly the
/// division of labour AD-39 draws between the two halves.</p>
ClassMethod Fault(pCode As %String, pReason As %String = "", pProviderText As %String = "", Output pFault As %DynamicObject, Output pHttpStatus As %Integer)
{
    Set pHttpStatus = ..HttpFor(pCode)
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, pCode, $Select(pReason = "": ..ReasonFor(pCode), 1: pReason))
    If pProviderText = "" Quit
    Set tDetail = {}
    Do tDetail.%Set("providerText", pProviderText)
    Do pFault.%Set("detail", tDetail)
}

/// <p>The numeric status a route answers <var>pCode</var> with. A failure of the upstream provider
/// is a gateway failure (502); a failure of this instance's own configuration is 503; a provider
/// that did not answer in time is 504.</p>
ClassMethod HttpFor(pCode As %String) As %Integer
{
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT Quit 504
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED Quit 503
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL Quit 503
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE Quit 503
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERTLS Quit 503
    Quit 502
}

/// <p>OcuPilot's own written reason for <var>pCode</var> -- the one home of these sentences, so
/// the port and the base cannot word the same code two ways.</p>
/// <p>None of them names a credential value, an endpoint the caller did not supply, or any part of
/// a vendor message (AD-35, AD-39).</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED Quit "OcuPilot has no usable agent definition for this call"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDEREGRESS Quit "The endpoint this definition names resolves to an address OcuPilot will not call"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL Quit "The credential this definition names could not be resolved"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE Quit "The credential this definition names is not shaped like a key for this provider"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERREFUSED Quit "The provider refused the request"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE Quit "The provider did not serve this request on any attempt"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT Quit "The provider did not answer within the time this instance allows"
    If pCode = ##class(OcuPilot.Api.Error).#PROVIDERTLS Quit "The TLS configuration this instance's provider calls are made through is not present"
    Quit "The provider call did not complete"
}

/// <p>The reason a <code>PROVIDER.KEYSHAPE</code> refusal carries: it states the prefix the
/// provider's catalog row declares, so an operator is told what shape was expected, and never any
/// part of the resolved value (AD-35). The prefix is a table entry, not a secret.</p>
Method KeyShapeReason() As %String [ Private ]
{
    If ..KeyPrefix = "" Quit ..ReasonFor(##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE)
    Quit ..ReasonFor(##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE) _ ": keys for this provider begin with " _ ..KeyPrefix
}

/// <p>The reason a <code>PROVIDER.CREDENTIAL</code> refusal carries: it names the
/// <b>reference</b> -- the credential type and the variable or entry the definition points at --
/// and never a value, because there is no value to name (AD-35).</p>
ClassMethod CredentialReason(ByRef pValues) As %String [ Private ]
{
    Set tType = $Get(pValues("credType"))
    Set tName = $Select(tType = "env": $Get(pValues("envVarName")), 1: $Get(pValues("credentialName")))
    If tName = "" Quit ..ReasonFor(##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL)
    Quit ..ReasonFor(##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL) _ ": " _ tType _ " " _ tName
}

/// <p>Send a raw status to the log, and nowhere else (AD-39), the way
/// <method>OcuPilot.Port.LogSourcePort.LogFault</method> does.</p>
ClassMethod LogRaw(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

}
