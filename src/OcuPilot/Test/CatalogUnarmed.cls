/// <p>Test-only <class>OcuPilot.Kernel.Provider.Catalog</class> subclass that is never armed,
/// whatever this process's environment holds, so the refusal of the <code>ArmedProviders</code> rows
/// is observable on an armed throwaway as well as on an unarmed instance.</p>
Class OcuPilot.Test.CatalogUnarmed Extends OcuPilot.Kernel.Provider.Catalog
{

/// <p>Never armed.</p>
ClassMethod ArmedRowsEnabled() As %Boolean [ Private ]
{
    Quit 0
}

}
