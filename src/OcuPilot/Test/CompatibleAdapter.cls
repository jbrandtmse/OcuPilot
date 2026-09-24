/// <p>Story 10.3's OpenAI-compatible family: the shipped <code>compatible</code> catalog row driven
/// through <method>OcuPilot.Port.ProviderPort.Invoke</method>, the keyless call that is this
/// family's reason to exist, and the endpoint normalization that lets an operator paste either the
/// base their vendor documents or the complete Chat Completions URL.</p>
/// <p><b>Needs nothing of the environment but a writable protected database.</b> No socket is
/// opened and <b>no provider is called</b>: the shipped adapter's transport, sleep and clock are
/// replaced by <class>OcuPilot.Test.CompatibleStub</class>, which the shipped row is re-adapted to
/// by <class>OcuPilot.Test.CatalogProbeShipped</class>. Every other column of that row -- its
/// tuning, its credential references, its empty key prefix -- is the shipped one. Every endpoint
/// here is a loopback address that is never connected to; the one stored definition each method
/// needs is created and removed here.</p>
Class OcuPilot.Test.CompatibleAdapter Extends %UnitTest.TestCase
{

/// <p>The port entry, with its switched catalog, gate, credential class and TLS answer.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The catalog that re-adapts the three shipped non-canonical rows to their stubs.</p>
Parameter CATALOG = "OcuPilot.Test.CatalogProbeShipped";

/// <p>The stub the <code>compatible</code> row answers under that catalog.</p>
Parameter STUB = "OcuPilot.Test.CompatibleStub";

/// <p>The shipped provider key under test.</p>
Parameter PROVIDERKEY = "compatible";

/// <p>The model, which this family's row does not supply: no vendor publishes a default, so the
/// model is always the operator's.</p>
Parameter PROBEMODEL = "llama-3.3-70b-instruct";

/// <p>The base endpoint an operator pastes, which is what every one of the four documented
/// endpoints for this family looks like.</p>
Parameter BASEENDPOINT = "http://127.0.0.1:11434/v1";

/// <p>The same base with the trailing slash a paste often carries.</p>
Parameter SLASHEDENDPOINT = "http://127.0.0.1:11434/v1/";

/// <p>The complete endpoint, which is what the shipped <code>openai</code> row stores.</p>
Parameter COMPLETEENDPOINT = "http://127.0.0.1:11434/v1/chat/completions";

/// The same complete endpoint in the case an operator's own paste may carry.
Parameter UPPERCASEENDPOINT = "http://127.0.0.1:11434/V1/CHAT/COMPLETIONS";

/// The differently-cased complete endpoint with the trailing slash a paste can carry too, so
/// the case fold and the slash collapse are pinned together and not only each alone.
Parameter UPPERSLASHENDPOINT = "http://127.0.0.1:11434/V1/CHAT/COMPLETIONS/";

/// <p>A credential the shape gate accepts: non-empty and free of whitespace, which is all a row
/// declaring no prefix can require.</p>
Parameter PROBEKEY = "probecompatiblekeyabcdefghij";

/// <p>A Chat Completions reply carrying text, a stop reason and both usage figures.</p>
Parameter REPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""the local model answered""},""finish_reason"":""stop""}],""usage"":{""prompt_tokens"":12,""completion_tokens"":5}}";

/// <p>Arm a clean port over the re-adapting catalog, a clean stub and a resolvable
/// credential.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#CATALOG)
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>Leave no switch and no stored row for the next method, or the next class, to read.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "every probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The <b>shipped</b> row for this family, read through the unsubclassed catalog so every value
/// below it is the one a turn would use.</p>
Method ShippedRow() As %DynamicObject
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row(..#PROVIDERKEY, .tRow), 1, "the shipped " _ ..#PROVIDERKEY _ " row is readable")
    Quit tRow
}

/// <p>Create one enabled probe definition on this family's shipped row, carrying
/// <var>pEndpoint</var>, <var>pCredType</var> and the marked-local declaration a loopback endpoint
/// needs, and hand back its id.</p>
/// <p>The tuning comes from <var>pRow</var> so no value here is spelled twice; the model and the
/// endpoint cannot, because this row supplies neither. Written straight through the state class, as
/// <method>OcuPilot.Test.AgentFixture.CreateDefinition</method> does, because only Story 3.4's Test
/// connection sets the verification flag an enable needs.</p>
Method StoredDefinition(pRow As %DynamicObject, pEndpoint As %String, pCredType As %String) As %String
{
    Set tId = ""
    Try {
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Shipped" _ ..#PROVIDERKEY
        Set tRow.Provider = ..#PROVIDERKEY
        Set tRow.Model = ..#PROBEMODEL
        Set tRow.EndpointUrl = pEndpoint
        Set tRow.MarkedLocal = 1
        ; Set for the same reason an operator would have to set it: the endpoint is plain http and
        ; a keyed rung crosses it, which AC2's own rule refuses without the acknowledgment. This
        ; helper writes through GuardedCreate, which does not apply AgentRules, so without it the
        ; family's integration path would be demonstrated on a row no operator can store.
        Set tRow.HttpAcknowledged = 1
        Set tRow.CredType = pCredType
        Set tRow.EnvVarName = $Select(pCredType = "env": pRow.defaultEnvVarName, 1: "")
        Set tRow.CredentialName = ""
        Set tRow.MaxTokens = +pRow.canonicalMaxTokens
        Set tRow.Temperature = pRow.canonicalTemperature
        Set tRow.Enabled = 1
        Set tRow.ConnectionVerified = 1
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
        Do $$$AssertStatusOK(tSC, "the probe definition on the shipped row is stored")
        If $$$ISERR(tSC) Quit
        Set tId = tRow.%Id()
        Set tRow = ""
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "storing the probe definition did not raise")
    }
    Quit tId
}

/// <p>The value array a direct call reads, taking every provider fact from <var>pRow</var> --
/// including the three columns the port would otherwise copy in, <code>keyPrefix</code>,
/// <code>authVersion</code> and <code>reasoningEffort</code> -- and <var>pEndpoint</var> as the stored endpoint.</p>
ClassMethod DirectValues(pRow As %DynamicObject, pEndpoint As %String, Output pValues)
{
    Kill pValues
    Set pValues("provider") = ..#PROVIDERKEY
    Set pValues("model") = ..#PROBEMODEL
    Set pValues("endpointUrl") = pEndpoint
    Set pValues("markedLocal") = 1
    Set pValues("credType") = "env"
    Set pValues("envVarName") = pRow.defaultEnvVarName
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = +pRow.canonicalMaxTokens
    Set pValues("temperature") = pRow.canonicalTemperature
    Set pValues("keyPrefix") = pRow.keyPrefix
    Set pValues("authVersion") = pRow.authVersion
    Set pValues("reasoningEffort") = pRow.reasoningEffort
}

/// <p>The body the stub recorded on call <var>pCall</var>, parsed.</p>
ClassMethod RecordedBody(pCall As %Integer = 1) As %DynamicObject
{
    Set tBody = ""
    Try {
        Set tText = ##class(OcuPilot.Test.ProviderStub).Recorded("body", pCall)
        If tText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8"))
        If $IsObject(tParsed) Set tBody = tParsed
    } Catch ex {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>An adapter instance for a direct call, so the normalization legs run against settings this
/// class states rather than against whatever the instance has stored.</p>
ClassMethod Adapter() As OcuPilot.Kernel.Provider.Base
{
    Set tAdapter = $ClassMethod(..#STUB, "%New")
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Quit tAdapter
}

/// <p><var>pFault</var>'s machine code, or <code>""</code> when the call produced no fault.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p><var>pFault</var>'s whole rendered envelope, or <code>""</code>.</p>
ClassMethod Rendered(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.%ToJSON()
}

/// <p>Integration AC -- a stored definition on the shipped <code>compatible</code> row reaches this
/// family's own adapter through the port: the row's <code>adapterClass</code> column selects it,
/// one POST is issued to the normalized endpoint, the body is a Chat Completions body built from
/// the definition's model and the row's own tuning, and the reply comes back as a canonical
/// <class>OcuPilot.Kernel.Provider.Response</class>. Observed through the port and through the
/// recorded request, never by reading the adapter's own state.</p>
/// <p>mutation: point <parameter>OcuPilot.Test.CatalogProbeShipped.COMPATIBLESTUB</parameter> at
/// <class>OcuPilot.Test.ProviderStub</class>, the canonical family's stub, so the row this call
/// resolves names a canonical adapter -- red on the served-by assertion, on the recorded header
/// name, and on the <code>messages</code> and <code>max_completion_tokens</code> body
/// assertions.</p>
Method TestTheShippedCompatibleRowIsCalledThroughThePort()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tId = ..StoredDefinition(tRow, ..#BASEENDPOINT, "env")
    If tId = "" Quit
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), $Parameter(..#STUB, "STUBIDENTITY"), "the call was served by the class the row's adapterClass column named")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the POST seam was entered exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#COMPLETEENDPOINT, "at the stored base endpoint with this dialect's operation appended")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "Authorization", "the credential travels on this family's header and on no other family's")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("contentType", 1), "application/json", "with a JSON content type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("sslConfiguration", 1), "", "and no TLS configuration, because a plain-http endpoint negotiates none")

    Set tBody = ..RecordedBody(1)
    Do $$$AssertTrue($IsObject(tBody), "the outbound body was recorded and is JSON")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.model, ..#PROBEMODEL, "the body carries the definition's own model, which this row supplies no default for")
    Do $$$AssertEquals(+tBody."max_completion_tokens", +tRow.canonicalMaxTokens, "the token cap is the row's own canonical maximum, under this dialect's own name")
    Do $$$AssertEquals(tBody.%GetTypeOf("max_tokens"), "unassigned", "and the deprecated spelling is not sent at all")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "messages.0.role"), "user", "the messages are this dialect's own")
    Do $$$AssertEquals(tBody.%GetTypeOf("contents"), "unassigned", "and no field of another dialect appears")

    Do $$$AssertEquals(tResponse.Text, "the local model answered", "the reply's text becomes canonical text")
    Do $$$AssertEquals(tResponse.StopReason, "end_turn", "its stop reason becomes the canonical one")
    Do $$$AssertEquals(tResponse.RequestTokens, 12, "with this dialect's own usage field names read")
    Do $$$AssertEquals(tResponse.ResponseTokens, 5, "in both directions")
}

/// <p>AC1 -- a definition on this row whose <code>credType</code> is <code>none</code> reaches the
/// provider through the port with <b>no authentication header at all</b>, and answers. The whole
/// point of the family: a keyless model on the operator's own network, configured with no
/// credential anywhere.</p>
/// <p>mutation: have <method>OcuPilot.Port.ProviderPort.ValuesFor</method> leave
/// <code>keySource</code> unset for a <code>none</code> <code>credType</code> -- red on the
/// expected call, because <method>OcuPilot.Kernel.Provider.Base.Invoke</method> then resolves a
/// stored credential, finds none and faults <code>PROVIDER.CREDENTIAL</code> before a request is
/// built.</p>
Method TestAKeylessCallSendsNoAuthorizationHeader()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(+tRow.allowsLocal, 1, "the shipped row allows local, which is what licenses both the loopback endpoint and the keyless credential type")
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tId = ..StoredDefinition(tRow, ..#BASEENDPOINT, ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE)
    If tId = "" Quit
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the keyless call returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault, so no credential was looked for: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport was entered once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "", "carrying no authentication header of any family")
    Do $$$AssertEquals(tResponse.Text, "the local model answered", "and the reply is the canonical one")
    Do $$$AssertEquals(tResponse.StopReason, "end_turn", "with its own stop reason")
}

/// <p>AC1's negative arm -- a keyless definition still sends no header even when its row carries a
/// leftover credential reference and a secret is resolvable under it. <method>AgentRules.Normalize</method>
/// clears both references for <code>credType</code> <code>none</code> on every write the API path
/// makes, so a row shaped like this should not exist through ordinary use; this method writes the
/// state row directly, as <method>StoredDefinition</method> already does, to show that
/// <method>OcuPilot.Port.ProviderPort.ValuesFor</method>'s <code>keySource</code> rides
/// <code>credType</code> alone and is never overridden by what a reference names or by whether a
/// secret happens to answer it.</p>
/// <p>mutation: have <method>OcuPilot.Port.ProviderPort.ValuesFor</method> set
/// <code>keySource</code> to <parameter>OcuPilot.Kernel.Provider.Base.KEYSOURCENONE</parameter>
/// only when <code>envVarName</code> and <code>credentialName</code> are both empty -- red on the
/// recorded header, because the populated reference then leaves <code>keySource</code> unset,
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> resolves the stored credential through
/// the ladder as it would for an ordinary rung, and the armed secret answers it.</p>
Method TestAKeylessRowWithALeftoverReferenceAndAResolvableSecretStillSendsNoHeader()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tId = ""
    Try {
        Set tDef = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tDef.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "ShippedCompatibleLeftover"
        Set tDef.Provider = ..#PROVIDERKEY
        Set tDef.Model = ..#PROBEMODEL
        Set tDef.EndpointUrl = ..#BASEENDPOINT
        Set tDef.MarkedLocal = 1
        Set tDef.HttpAcknowledged = 1
        Set tDef.CredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE
        ; A reference AgentRules.Normalize would have cleared on the way in, left in place on
        ; purpose: this row is written straight through the state class, as every fixture on
        ; this class is.
        Set tDef.EnvVarName = tRow.defaultEnvVarName
        Set tDef.CredentialName = tRow.defaultCredentialName
        Set tDef.MaxTokens = +tRow.canonicalMaxTokens
        Set tDef.Temperature = tRow.canonicalTemperature
        Set tDef.Enabled = 1
        Set tDef.ConnectionVerified = 1
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tDef)
        Do $$$AssertStatusOK(tSC, "the leftover-reference definition is stored")
        If $$$ISERR(tSC) Quit
        Set tId = tDef.%Id()
        Set tDef = ""
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "storing the leftover-reference definition did not raise")
    }
    If tId = "" Quit
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault, so the leftover reference was never consulted: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport was entered once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "", "carrying no authentication header, although the row names a reference and the armed secret would have resolved it")
}

/// <p>AC1's header half -- the adapter writes no header when the key is absent, rather than an
/// empty <code>Bearer</code> the vendor would read as a malformed credential. Driven directly, with
/// the key source stated, so the assertion is about <code>ApplyAuth</code> and not about how the
/// port resolved anything.</p>
/// <p>mutation: drop the <code>If ..ApiKey = "" Quit</code> guard from
/// <method>OcuPilot.Kernel.Provider.OpenAI.ApplyAuth</method>, which this family inherits -- red on
/// the recorded header names, which then carry this family's header with the scheme and nothing
/// after it.</p>
Method TestTheAdapterWritesNoHeaderWhenTheKeyIsAbsent()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ..DirectValues(tRow, ..#BASEENDPOINT, .tValues)
    Set tValues("keySource") = $Parameter("OcuPilot.Kernel.Provider.Base", "KEYSOURCENONE")
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)

    Set tNoKey = ..Adapter()
    Do $$$AssertStatusOK(tNoKey.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the keyless call returns $$$OK")
    Set tNoKey = ""
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport was entered once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "", "carrying no authentication header at all")

    ; The control: the same adapter with a key does send the header, so the assertion above is
    ; about the absent key and not about a family that never sets one.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Kill tValues("keySource")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tKeyed = ..Adapter()
    Do $$$AssertStatusOK(tKeyed.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tKeyedResponse, .tKeyedFault, .tKeyedStatus), "the keyed call returns $$$OK")
    Set tKeyed = ""
    Do $$$AssertEquals(..FaultCode(tKeyedFault), "", "and is accepted: " _ ..Rendered(tKeyedFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "Authorization", "sending this family's own header when there is a credential to send")
}

/// <p>The matrix's two normalization rows -- a stored base endpoint has this dialect's operation
/// appended, with one trailing slash tolerated, and a stored endpoint that already ends in it is
/// issued unchanged rather than gaining a second path segment. The scheme and the authority are
/// byte-identical either way, which is what
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s origin check requires and what a call
/// reaching the transport at all demonstrates.</p>
/// <p>The refusal arm is the other half: a stored endpoint whose path reduces to nothing makes
/// <method>RequestUrl</method> answer <code>""</code>, which
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> refuses as
/// <code>PROVIDER.EGRESS</code> with no call made. An override answering another
/// <b>authority</b> is pinned on the shared seam by
/// <method>OcuPilot.Test.GeminiAdapter.TestABuiltUrlOnAnotherAuthorityIsRefused</method>, which
/// this family reaches through the same <method>Attempts</method> check.</p>
/// <p>mutation: have <method>OcuPilot.Kernel.Provider.Compatible.RequestUrl</method> answer the
/// stored endpoint unchanged -- red on the recorded URL for the two base rows, the
/// already-complete row staying green.</p>
Method TestABaseEndpointIsNormalizedAndAnAuthorityChangeIsRefused()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)
    For tStored = ..#BASEENDPOINT, ..#SLASHEDENDPOINT, ..#COMPLETEENDPOINT {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
        Do ..DirectValues(tRow, tStored, .tValues)
        Set tAdapter = ..Adapter()
        Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), tStored _ ": the call returns $$$OK")
        Set tAdapter = ""
        Do $$$AssertEquals(..FaultCode(tFault), "", tStored _ ": with no fault, so the built URL was the judged endpoint's own origin: " _ ..Rendered(tFault))
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, tStored _ ": the transport was entered once")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#COMPLETEENDPOINT, tStored _ ": and the POST went to the complete Chat Completions URL")
    }

    ; A query the operator stored is kept after the appended segment rather than written into.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Do ..DirectValues(tRow, ..#BASEENDPOINT _ "?api-version=1", .tQueryValues)
    Set tQuery = ..Adapter()
    Do $$$AssertStatusOK(tQuery.Invoke(.tQueryValues, .tMessages, .tTools, "", .tSettings, .tQueryResponse, .tQueryFault, .tQueryStatus), "the call on an endpoint carrying a query returns $$$OK")
    Set tQuery = ""
    Do $$$AssertEquals(..FaultCode(tQueryFault), "", "with no fault: " _ ..Rendered(tQueryFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#COMPLETEENDPOINT _ "?api-version=1", "and the operation is appended to the path, leaving the query where it was")

    ; A fragment is split off on the same terms as a query.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Do ..DirectValues(tRow, ..#BASEENDPOINT _ "#frag", .tFragValues)
    Set tFrag = ..Adapter()
    Do $$$AssertStatusOK(tFrag.Invoke(.tFragValues, .tMessages, .tTools, "", .tSettings, .tFragResponse, .tFragFault, .tFragStatus), "the call on an endpoint carrying a fragment returns $$$OK")
    Set tFrag = ""
    Do $$$AssertEquals(..FaultCode(tFragFault), "", "with no fault: " _ ..Rendered(tFragFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#COMPLETEENDPOINT _ "#frag", "and the fragment is left where it was too")

    ; An endpoint the operator's own case differs on is the operation already named: appending a
    ; second copy would reach the wire as a path no server serves.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Do ..DirectValues(tRow, ..#UPPERCASEENDPOINT, .tUpperValues)
    Set tUpper = ..Adapter()
    Do $$$AssertStatusOK(tUpper.Invoke(.tUpperValues, .tMessages, .tTools, "", .tSettings, .tUpperResponse, .tUpperFault, .tUpperStatus), "the call on a differently-cased complete endpoint returns $$$OK")
    Set tUpper = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#UPPERCASEENDPOINT, "and is issued unchanged rather than gaining a second operation segment")

    ; The same cased spelling with the trailing slash a paste can carry too: the slash is
    ; collapsed before the case-blind suffix comparison runs, so the two never interact badly
    ; and the stored form still reaches the wire with no second operation segment.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Do ..DirectValues(tRow, ..#UPPERSLASHENDPOINT, .tUpperSlashValues)
    Set tUpperSlash = ..Adapter()
    Do $$$AssertStatusOK(tUpperSlash.Invoke(.tUpperSlashValues, .tMessages, .tTools, "", .tSettings, .tUpperSlashResponse, .tUpperSlashFault, .tUpperSlashStatus), "the call on a differently-cased complete endpoint with a trailing slash returns $$$OK")
    Set tUpperSlash = ""
    Do $$$AssertEquals(..FaultCode(tUpperSlashFault), "", "with no fault: " _ ..Rendered(tUpperSlashFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), ..#UPPERCASEENDPOINT, "and the trailing slash is dropped rather than left inside the path")

    ; The refusal arm: a stored endpoint whose path reduces to nothing is refused before a socket.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ..DirectValues(tRow, "/", .tEmptyValues)
    Set tEmpty = ..Adapter()
    Do $$$AssertStatusOK(tEmpty.Invoke(.tEmptyValues, .tMessages, .tTools, "", .tSettings, .tEmptyResponse, .tEmptyFault, .tEmptyStatus), "the refused call still returns $$$OK, because this family never throws")
    Set tEmpty = ""
    Do $$$AssertEquals(..FaultCode(tEmptyFault), "PROVIDER.EGRESS", "an endpoint that builds no URL is refused as egress: " _ ..Rendered(tEmptyFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no call was made at all")
}


/// <p>AC1's other half, and AC2's disabling half -- both at the surface that decides them, neither
/// of which a port call reaches.</p>
/// <p><b>Why this exists:</b> a keyless definition is storable and callable, but until Test
/// connection can record a verification it can never be <i>enabled</i>
/// (<code>AGENT.ENABLE.UNVERIFIED</code>), so the configuration the story ships would be unusable.
/// Two class methods decide it -- <method>OcuPilot.Api.Definitions.KeySourceFor</method>, which
/// answers <code>none</code> for this rung, and
/// <method>OcuPilot.Api.Definitions.KeySourceIsTheStoredOne</method>, which is what makes that
/// answer count as the stored configuration's own rather than a test made without its key.</p>
/// <p><b>Precedence is asserted, not assumed</b>: a body key still wins over the rung, so a
/// pasted key can be tested against a keyless definition without the row being changed.</p>
/// <p>mutation: drop the second arm of
/// <method>OcuPilot.Api.Definitions.KeySourceIsTheStoredOne</method> (<code>Quit (pKeySource =
/// ..#KEYSOURCESTORED)</code>) -- red on the stored-answer assertion; drop
/// <method>KeySourceFor</method>'s <code>none</code> return -- red on the key-source assertion.
/// Removing <code>HttpAcknowledged</code> from
/// <method>OcuPilot.Kernel.State.Agent.SecurityFields</method> -- red on the last assertion.</p>
Method TestAKeylessDefinitionIsTestableAsStoredAndTheAcknowledgmentDisables()
{
    Set tNone = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE
    Set tStoredSource = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCESTORED
    Set tNoneSource = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCENONE

    Set tValues("provider") = ..#PROVIDERKEY
    Set tValues("endpointUrl") = ..#BASEENDPOINT
    Set tValues("credType") = tNone
    Set tValues("envVarName") = ""
    Set tValues("credentialName") = ""
    Merge tStored = tValues
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceFor(.tValues, .tStored), tNoneSource, "a keyless definition resolves a key source of none, because it names nothing to resolve")
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceIsTheStoredOne(tNoneSource, .tStored), 1, "and that IS the stored configuration's own answer, which is what lets the verification be recorded and the definition enabled")

    ; The control: the same key source against a keyed stored row is NOT the stored answer, so a
    ; test made without a key cannot verify a definition that names one.
    Set tKeyed("credType") = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPECREDS
    Set tKeyed("credentialName") = "OcuPilotCompatible"
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceIsTheStoredOne(tNoneSource, .tKeyed), 0, "no key at all is not the stored answer for a definition that names a credential")
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceIsTheStoredOne(tStoredSource, .tKeyed), 1, "and the stored credential is")

    ; Precedence: a pasted key wins over the rung, so the none arm is a fallback and not a gate.
    Set tBody = {"apiKey": "probecompatiblekeyabcdefghij"}
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceFor(.tValues, .tStored, tBody), ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCEBODY, "a body key is tested even on a keyless definition, and is not the stored answer")
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).KeySourceIsTheStoredOne(##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCEBODY, .tStored), 0, "so it cannot record a verification")

    ; AC2's disabling half: the acknowledgment is a security field, so turning it on -- which
    ; widens what may cross an unencrypted endpoint -- disables the definition until Test
    ; connection passes again. Asserted over the list, because the list is what GuardedUpdate reads.
    Set tFields = ##class(OcuPilot.Kernel.State.Agent).SecurityFields()
    Do $$$AssertTrue($ListFind(tFields, "HttpAcknowledged") > 0, "HttpAcknowledged is a security field, so a change to it clears ConnectionVerified and Enabled (" _ $ListToString(tFields) _ ")")
    Do $$$AssertTrue($ListFind(tFields, "MarkedLocal") > 0, "beside the local declaration it travels with")
}

}
