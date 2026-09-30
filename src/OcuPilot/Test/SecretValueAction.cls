/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass that answers
/// <method>OcuPilot.Api.ScreenAction.Values</method> for a request body, so the screen action's
/// value channel can be asked about a tool no registry lists.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SecretValueAction Extends OcuPilot.Api.ScreenAction
{

/// <p>What <method>OcuPilot.Api.ScreenAction.Values</method> answers for <var>pBody</var> and action
/// <var>pActionId</var> of write tool <var>pToolClass</var> on screen <var>pDescriptor</var>, with the
/// values and the secrets it split out.</p>
ClassMethod ValuesOf(pBody As %DynamicObject, pToolClass As %String, pDescriptor As %String, pActionId As %String, Output pValues As %DynamicObject, Output pSecrets As %DynamicObject) As %String
{
    Set tTool = {}
    Do tTool.%Set("class", pToolClass, "string")
    Do tTool.%Set("descriptor", pDescriptor, "string")
    Quit ..Values(pBody, tTool, pToolClass, pActionId, .pValues, .pSecrets)
}

}
