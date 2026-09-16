/// <p>Test-only <class>OcuPilot.Kernel.AgentRules</class> subclass that reads its provider
/// vocabulary from <class>OcuPilot.Test.CatalogProbe</class> instead of the shipped catalog, so
/// rule 8 can be driven against a row that requires an endpoint.</p>
/// <p>Every rule runs unchanged: only the catalog seam is replaced, so a violation this subclass
/// reports is one the shipped validator would report for the same values against the same
/// table.</p>
Class OcuPilot.Test.AgentRulesProbe Extends OcuPilot.Kernel.AgentRules
{

ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Test.CatalogProbe"
}

}
