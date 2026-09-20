/// <p>Test-only <class>OcuPilot.Test.CatalogProbeShipped</class> subclass whose
/// <parameter>OPENAIKEYSHIPPED</parameter> names a key the shipped table does not declare, so its
/// inherited <method>Table</method> takes the fail-closed arm.</p>
/// <p>It exists to give that arm a caller. The drift it stands for -- a shipped provider key
/// renamed in <class>OcuPilot.Kernel.Provider.Catalog</class>'s XData, or a parameter here left
/// pointing at the old spelling -- would otherwise leave a row this class could not re-adapt
/// naming the shipped adapter, and the next call on it carrying the probe credential to the
/// vendor.</p>
Class OcuPilot.Test.CatalogProbeDrift Extends OcuPilot.Test.CatalogProbeShipped
{

/// <p>A key no shipped row declares, which is what makes the inherited guard refuse.</p>
Parameter OPENAIKEYSHIPPED = "openai-renamed-by-the-vendor";

}
