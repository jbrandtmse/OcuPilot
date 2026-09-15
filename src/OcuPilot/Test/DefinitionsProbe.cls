/// <p>Test-only <class>OcuPilot.Api.Definitions</class> subclass that replaces all four of the
/// handler's seams: the change record goes into <class>OcuPilot.Test.LogProbe</class>'s capture
/// instead of the console log, and the catalog a create falls back to is
/// <class>OcuPilot.Test.CatalogProbe</class>.</p>
/// <p>The record Story 3.8 builds its audit row from is emitted from inside the HTTP worker
/// process, where a process-private capture cannot reach it. Overriding the one seam
/// <method>OcuPilot.Api.Definitions.LogChange</method> writes through lets a test call the real
/// <method>LogChange</method> -- the real change-set computation, the real subsystem name, the
/// real redaction -- and read back exactly the line it produced.</p>
/// <p>The catalog seam is there for the same reason: against the shipped provider row two of the
/// four canonical fallbacks land on the value the state class's own
/// <code>InitialExpression</code> already held, so they could be deleted from
/// <method>OcuPilot.Api.Definitions.CatalogDefaults</method> without moving an assertion. The
/// probe row's tuning differs from both, which makes the fallback observable.</p>
/// <p>The credential seam is the third, and it is there because the rung-unavailable refusal cannot
/// be reached over the wire on an instance that <i>has</i> the rung:
/// <class>OcuPilot.Test.SecretProbe</class> can answer the availability predicate with a switch.</p>
/// <p>The port seam is the fourth: <class>OcuPilot.Test.ProviderPortProbe</class> drives Test
/// connection's provider call through the probe catalog's stub adapter, so every leg of it runs in
/// process with no socket opened.</p>
Class OcuPilot.Test.DefinitionsProbe Extends OcuPilot.Api.Definitions
{

ClassMethod LogInfo(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Test.LogProbe).Info(pSubsystem, pMessage, pData)
}

ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Test.CatalogProbe"
}

ClassMethod SecretClass() As %String
{
    Quit "OcuPilot.Test.SecretProbe"
}

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProviderPortProbe"
}

}
