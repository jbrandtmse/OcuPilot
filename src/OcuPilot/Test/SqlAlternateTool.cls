/// <p><class>OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead</class> reaching <class>OcuPilot.Test.SqlAlternateFixture</class> instead of the production
/// port, so a test counts what reaches the instance (Story 21.28). Everything else is the tool's own.</p>
Class OcuPilot.Test.SqlAlternateTool Extends OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead
{

Parameter PORTCLASS = "OcuPilot.Test.SqlAlternateFixture";

}
