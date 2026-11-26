/// <p><class>OcuPilot.Test.InteropWorkflowSeam</class> with the two list caps lowered to three, so a test pins the cap and one over without storing ten thousand workflow users (Story 24.17
/// Batch 3a). A parameter overridden here is compiled into this class's own copy of each method, so this class is recompiled with the port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropWorkflowCapSeam Extends OcuPilot.Test.InteropWorkflowSeam
{

Parameter WORKFLOWUSERSMAX As INTEGER = 3;

Parameter WORKFLOWUSERCHOICESMAX As INTEGER = 3;

Parameter WORKFLOWROLESMAX As INTEGER = 3;

Parameter WORKFLOWMEMBERSMAX As INTEGER = 3;

}
