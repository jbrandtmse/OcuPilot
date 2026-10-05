/// <p>Test seam over <class>OcuPilot.Api.ScreenAction</class> (Story 19.11): <method>PreviewOf</method>
/// resolves a screen action's body exactly as the route does, up to the point it would write, and
/// answers the fresh read, payload and diff it built, so a test reads what the person's own action read.
/// Writes nothing.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions.</p>
Class OcuPilot.Test.ScreenActionProbe Extends OcuPilot.Api.ScreenAction
{

/// <p>The preview of <var>pBody</var>, <code>{action, id, values}</code>, on <var>pDescriptor</var>, in
/// the request's scope (<method>OcuPilot.Kernel.Scope.Current</method>).</p>
ClassMethod PreviewOf(pDescriptor As %String, pBody As %DynamicObject, Output pPreview As %DynamicObject) As %Status
{
    Quit ..Resolve(pDescriptor, pBody, 1, "", .pPreview)
}

}
