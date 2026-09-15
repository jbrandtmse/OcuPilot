/// <p>Test-only <class>OcuPilot.Kernel.Provider.Catalog</class> subclass that answers the shipped
/// table plus one extra row whose <code>endpointRequired</code> is true.</p>
/// <p>It exists because Release 1 ships exactly one provider row and that row does not require an
/// endpoint, so rule 8 -- "a provider whose catalog row requires an endpoint must have one" --
/// has no failing case at this floor. A rule with no failing case is not enforced, it is merely
/// written, so the seam is what makes it falsifiable.</p>
/// <p>Overriding <method>Table</method> alone is enough: <method>Keys</method>,
/// <method>Row</method> and <method>IsKnown</method> all read the table through
/// <code>..</code> dispatch, so they answer the extra row too.</p>
Class OcuPilot.Test.CatalogProbe Extends OcuPilot.Kernel.Provider.Catalog
{

/// <p>The provider key of the extra row.</p>
Parameter PROBEKEY = "probe-endpoint-required";

/// <p>The shipped table with <parameter>PROBEKEY</parameter> appended.</p>
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
    Do pObject.providers.%Push(tRow)
    Quit tSC
}

}
