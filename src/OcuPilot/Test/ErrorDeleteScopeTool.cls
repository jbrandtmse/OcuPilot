/// <p>Test-only <class>OcuPilot.Screen.Tool.ErrorDelete</class> subclass whose port is
/// <class>OcuPilot.Test.ErrorLogFixture</class>, which counts every query the port opens. Handed to
/// the mint as its tool class, it turns "the mint refused before anything was read" into a counter
/// that stays at zero. Nothing else changes, and it is outside the tool package, so the registry
/// never lists it.</p>
Class OcuPilot.Test.ErrorDeleteScopeTool Extends OcuPilot.Screen.Tool.ErrorDelete
{

Parameter PORTCLASS = "OcuPilot.Test.ErrorLogFixture";

}
