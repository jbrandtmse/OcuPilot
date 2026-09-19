/// <p>Test-only <class>OcuPilot.Kernel.Provider.Catalog</class> subclass that answers the shipped
/// table plus seven extra rows: one whose <code>endpointRequired</code> is true, one whose
/// <code>allowsLocal</code> is true, one whose <code>keyPrefix</code> is the shipped row's so
/// AC6's canary has the shape of a real key, one whose <code>adapterClass</code> names a class
/// this instance does not compile at all, one whose adapter forces a real <code>^ERRORS</code>
/// entry from inside the shape gate, and two whose adapter translates the canonical shapes into
/// another family's dialect. All but the fourth name a stub <code>adapterClass</code>, so
/// no call driven through any of them opens a socket; the fourth is never dispatched to, which
/// is the point of it.</p>
/// <p>It exists because no <b>vendor</b> row exercises either column. Since Story 10.3 the shipped
/// <code>compatible</code> row sets both, and the rules are pinned over it directly
/// (<class>OcuPilot.Test.Egress</class>, <class>OcuPilot.Test.AgentRules</class>); these rows keep
/// what a shipped row still cannot supply -- either column paired with a provider the shipped
/// catalog does not declare. A rule with no failing case is not enforced, it is merely written, so
/// the seam is what makes both falsifiable -- and the second row is what makes "the adapter comes
/// from the row" an observation rather than an assertion against one possible answer.</p>
/// <p>Overriding <method>Table</method> alone is enough: <method>Keys</method>,
/// <method>Row</method> and <method>IsKnown</method> all read the table through <code>..</code>
/// dispatch, so they answer the extra rows too.</p>
/// <p><b>Additive only.</b> <class>OcuPilot.Test.AgentRules</class> asserts that the <i>shipped</i>
/// table declares exactly <code>anthropic</code>, <code>openai</code> and <code>gemini</code>, in
/// that order, so a row added to the shipped XData is a regression while a row added here is a
/// fixture.</p>
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

/// <p>The provider key of the row whose adapter class this instance does not compile, so
/// <class>OcuPilot.Test.ProviderPort</class> can drive <method>OcuPilot.Port.ProviderPort.Dispatch</method>'s
/// other adapter-resolution refusal -- a row naming a class rather than naming none at all.</p>
Parameter MISSINGADAPTERKEY = "probe-missing-adapter";

/// <p>A class name this instance never compiles. <code>Dispatch</code> must refuse before ever
/// reaching it, so nothing here needs to exist.</p>
Parameter MISSINGADAPTERCLASS = "OcuPilot.Test.NoSuchAdapterClassAtAll";

/// <p>The provider key of the row whose adapter forces a real <code>^ERRORS</code> entry from
/// inside <method>OcuPilot.Kernel.Provider.Base.IsApiKeyShapeValid</method>, so
/// <class>OcuPilot.Test.SecretLeak</class> can take an entry while
/// <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method> holds the posted key.</p>
Parameter SHAPELEAKKEY = "probe-shape-leak";

/// <p>The adapter that row names. Its key prefix below is the shipped Anthropic row's, so the
/// canary the shape gate is driven with is a value of the shape a real key has.</p>
Parameter SHAPELEAKADAPTER = "OcuPilot.Test.ProviderStubShapeLeak";

/// <p>The provider key of the row whose adapter translates the canonical shapes into the OpenAI
/// dialect, so <class>OcuPilot.Test.Adapter</class> can drive a family that exists only as this
/// row plus <class>OcuPilot.Test.AdapterProvider</class> (Story 10.1, AD-42). No shipped row
/// names that adapter and none is added: the families themselves arrive in Stories 10.2
/// and 10.3.</p>
Parameter OPENAIKEY = "probe-openai";

/// <p>The provider key of the row whose adapter translates into the Gemini dialect. A second row
/// for the same adapter class, because a family is a row and the dialect is that adapter's own
/// affair -- the two rows are what show one adapter serving two dialects without the port
/// reading either.</p>
Parameter GEMINIKEY = "probe-gemini";

/// <p>The adapter both those rows name.</p>
Parameter DIALECTADAPTER = "OcuPilot.Test.AdapterProvider";

/// <p>The key prefix both those rows declare, so the probe credential already in use passes
/// their shape gate.</p>
Parameter DIALECTKEYPREFIX = "probe-local-";

/// <p>The shipped table with <parameter>PROBEKEY</parameter>, <parameter>LOCALKEY</parameter>,
/// <parameter>CANARYKEY</parameter>, <parameter>MISSINGADAPTERKEY</parameter>,
/// <parameter>SHAPELEAKKEY</parameter>, <parameter>OPENAIKEY</parameter> and
/// <parameter>GEMINIKEY</parameter> appended.</p>
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
    Set tMissing = {}
    Do tMissing.%Set("key", ..#MISSINGADAPTERKEY)
    Do tMissing.%Set("label", "Probe (missing adapter)")
    Do tMissing.%Set("defaultModel", "probe-missing-model-1")
    Do tMissing.%Set("modelSuggestions", ["probe-missing-model-1"])
    Do tMissing.%Set("defaultEndpoint", "https://api.anthropic.com/v1/messages")
    Do tMissing.%Set("endpointRequired", 0, "boolean")
    Do tMissing.%Set("canonicalMaxTokens", 4000, "number")
    Do tMissing.%Set("canonicalTemperature", 0, "number")
    Do tMissing.%Set("defaultEnvVarName", "OCUPILOT_PROBE_MISSING_KEY")
    Do tMissing.%Set("defaultCredentialName", "OcuPilotProbeMissingCredential")
    Do tMissing.%Set("keyPrefix", "")
    Do tMissing.%Set("adapterClass", ..#MISSINGADAPTERCLASS)
    Do tMissing.%Set("allowsLocal", 0, "boolean")
    Do tMissing.%Set("authVersion", "probe-version-3")
    Do pObject.providers.%Push(tMissing)
    Set tShapeLeak = {}
    Do tShapeLeak.%Set("key", ..#SHAPELEAKKEY)
    Do tShapeLeak.%Set("label", "Probe (shape gate forces an error entry)")
    Do tShapeLeak.%Set("defaultModel", "probe-shape-leak-model-1")
    Do tShapeLeak.%Set("modelSuggestions", ["probe-shape-leak-model-1"])
    Do tShapeLeak.%Set("defaultEndpoint", "https://api.anthropic.com/v1/messages")
    Do tShapeLeak.%Set("endpointRequired", 0, "boolean")
    Do tShapeLeak.%Set("canonicalMaxTokens", 4000, "number")
    Do tShapeLeak.%Set("canonicalTemperature", 0, "number")
    Do tShapeLeak.%Set("defaultEnvVarName", "OCUPILOT_PROBE_SHAPE_LEAK_KEY")
    Do tShapeLeak.%Set("defaultCredentialName", "OcuPilotProbeShapeLeakCredential")
    Do tShapeLeak.%Set("keyPrefix", ..#CANARYKEYPREFIX)
    Do tShapeLeak.%Set("adapterClass", ..#SHAPELEAKADAPTER)
    Do tShapeLeak.%Set("allowsLocal", 0, "boolean")
    Do tShapeLeak.%Set("authVersion", "2023-06-01")
    Do pObject.providers.%Push(tShapeLeak)
    For tDialectKey = ..#OPENAIKEY, ..#GEMINIKEY {
        Set tDialect = {}
        Do tDialect.%Set("key", tDialectKey)
        Do tDialect.%Set("label", "Probe (" _ tDialectKey _ " dialect)")
        Do tDialect.%Set("defaultModel", tDialectKey _ "-model-1")
        Do tDialect.%Set("modelSuggestions", [(tDialectKey _ "-model-1")])
        ; The shipped row's endpoint, deliberately: the endpoint is not what these rows exercise,
        ; and a host the address policy cannot resolve would refuse the call before any adapter ran.
        Do tDialect.%Set("defaultEndpoint", "https://api.anthropic.com/v1/messages")
        Do tDialect.%Set("endpointRequired", 0, "boolean")
        Do tDialect.%Set("canonicalMaxTokens", 4000, "number")
        Do tDialect.%Set("canonicalTemperature", 0, "number")
        Do tDialect.%Set("defaultEnvVarName", "OCUPILOT_PROBE_LOCAL_KEY")
        Do tDialect.%Set("defaultCredentialName", "OcuPilotProbeDialectCredential")
        Do tDialect.%Set("keyPrefix", ..#DIALECTKEYPREFIX)
        Do tDialect.%Set("adapterClass", ..#DIALECTADAPTER)
        Do tDialect.%Set("allowsLocal", 0, "boolean")
        Do tDialect.%Set("authVersion", "probe-version-4")
        Do pObject.providers.%Push(tDialect)
    }
    Quit tSC
}

}
