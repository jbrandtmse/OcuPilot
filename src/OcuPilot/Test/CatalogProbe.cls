/// <p>Test-only <class>OcuPilot.Kernel.Provider.Catalog</class> subclass that answers the shipped
/// table plus three extra rows: one whose <code>endpointRequired</code> is true, one whose
/// <code>allowsLocal</code> is true, and one whose <code>keyPrefix</code> is the shipped row's so
/// AC6's canary has the shape of a real key. Each names a stub <code>adapterClass</code>, so no
/// call driven through any of them opens a socket.</p>
/// <p>It exists because Release 1 ships exactly one provider row, and that row exercises neither
/// column: it requires no endpoint and allows no local address. A rule with no failing case is not
/// enforced, it is merely written, so the seam is what makes both falsifiable -- and the second row
/// is what makes "the adapter comes from the row" an observation rather than an assertion against
/// one possible answer.</p>
/// <p>Overriding <method>Table</method> alone is enough: <method>Keys</method>,
/// <method>Row</method> and <method>IsKnown</method> all read the table through <code>..</code>
/// dispatch, so they answer the extra rows too.</p>
/// <p><b>Additive only.</b> <class>OcuPilot.Test.AgentRules</class> asserts that the <i>shipped</i>
/// table declares exactly <code>anthropic</code>, so a row added to the shipped XData is a
/// regression while a row added here is a fixture.</p>
Class OcuPilot.Test.CatalogProbe Extends OcuPilot.Kernel.Provider.Catalog
{

/// <p>The provider key of the endpoint-required row.</p>
Parameter PROBEKEY = "probe-endpoint-required";

/// <p>The provider key of the local-allowed row, whose adapter is the transport stub.</p>
Parameter LOCALKEY = "probe-local";

/// <p>The key prefix the local-allowed row's credentials must start with.</p>
Parameter LOCALKEYPREFIX = "probe-local-";

/// <p>The provider key of the row AC6's canary is driven through.</p>
Parameter CANARYKEY = "probe-canary";

/// <p>The key prefix that row declares. <b>Deliberately the shipped Anthropic row's own
/// prefix</b>, so AC6's canary is a value of the shape a real key has -- which is what makes it
/// pass the shape gate and reach every point a real key would reach -- while the row it travels on
/// still names the stub, so no socket is opened.</p>
Parameter CANARYKEYPREFIX = "sk-ant-";

/// <p>The adapter class the local-allowed row names -- the stub, so a call driven through this row
/// opens no socket.</p>
Parameter LOCALADAPTER = "OcuPilot.Test.ProviderStub";

/// <p>The adapter class the endpoint-required row names. <b>Deliberately a different class from
/// <parameter>LOCALADAPTER</parameter></b>: "the adapter comes from the row" is only observable
/// when two rows answer with two classes, and both being the stub would make AC1's assertion pass
/// against a port that ignored the column entirely.</p>
Parameter ALTADAPTER = "OcuPilot.Test.ProviderStubAlt";

/// <p>The shipped table with <parameter>PROBEKEY</parameter>, <parameter>LOCALKEY</parameter> and
/// <parameter>CANARYKEY</parameter> appended.</p>
ClassMethod Table(Output pObject As %DynamicObject) As %Status
{
    Set tSC = ##super(.pObject)
    If $$$ISERR(tSC) Quit tSC
    Set tRow = {}
    Do tRow.%Set("key", ..#PROBEKEY)
    Do tRow.%Set("label", "Probe (endpoint required)")
    Do tRow.%Set("defaultModel", "probe-model-1")
    Do tRow.%Set("modelSuggestions", ["probe-model-1"])
    Do tRow.%Set("defaultEndpoint", "")
    Do tRow.%Set("endpointRequired", 1, "boolean")
    Do tRow.%Set("canonicalMaxTokens", 8000, "number")
    Do tRow.%Set("canonicalTemperature", 1, "number")
    Do tRow.%Set("defaultEnvVarName", "OCUPILOT_PROBE_KEY")
    Do tRow.%Set("defaultCredentialName", "OcuPilotProbeCredential")
    Do tRow.%Set("keyPrefix", "probe-")
    Do tRow.%Set("adapterClass", ..#ALTADAPTER)
    Do tRow.%Set("allowsLocal", 0, "boolean")
    Do tRow.%Set("authVersion", "probe-version-1")
    Do pObject.providers.%Push(tRow)
    Set tLocal = {}
    Do tLocal.%Set("key", ..#LOCALKEY)
    Do tLocal.%Set("label", "Probe (local allowed)")
    Do tLocal.%Set("defaultModel", "probe-local-model-1")
    Do tLocal.%Set("modelSuggestions", ["probe-local-model-1"])
    Do tLocal.%Set("defaultEndpoint", "https://api.anthropic.com/v1/messages")
    Do tLocal.%Set("endpointRequired", 0, "boolean")
    Do tLocal.%Set("canonicalMaxTokens", 4000, "number")
    Do tLocal.%Set("canonicalTemperature", 0, "number")
    Do tLocal.%Set("defaultEnvVarName", "OCUPILOT_PROBE_LOCAL_KEY")
    Do tLocal.%Set("defaultCredentialName", "OcuPilotProbeLocalCredential")
    Do tLocal.%Set("keyPrefix", ..#LOCALKEYPREFIX)
    Do tLocal.%Set("adapterClass", ..#LOCALADAPTER)
    Do tLocal.%Set("allowsLocal", 1, "boolean")
    Do tLocal.%Set("authVersion", "probe-version-2")
    Do pObject.providers.%Push(tLocal)
    Set tCanary = {}
    Do tCanary.%Set("key", ..#CANARYKEY)
    Do tCanary.%Set("label", "Probe (canary key shape)")
    Do tCanary.%Set("defaultModel", "probe-canary-model-1")
    Do tCanary.%Set("modelSuggestions", ["probe-canary-model-1"])
    Do tCanary.%Set("defaultEndpoint", "https://api.anthropic.com/v1/messages")
    Do tCanary.%Set("endpointRequired", 0, "boolean")
    Do tCanary.%Set("canonicalMaxTokens", 4000, "number")
    Do tCanary.%Set("canonicalTemperature", 0, "number")
    Do tCanary.%Set("defaultEnvVarName", "OCUPILOT_PROBE_CANARY_KEY")
    Do tCanary.%Set("defaultCredentialName", "OcuPilotProbeCanaryCredential")
    Do tCanary.%Set("keyPrefix", ..#CANARYKEYPREFIX)
    Do tCanary.%Set("adapterClass", ..#LOCALADAPTER)
    Do tCanary.%Set("allowsLocal", 0, "boolean")
    Do tCanary.%Set("authVersion", "2023-06-01")
    Do pObject.providers.%Push(tCanary)
    Quit tSC
}

}
