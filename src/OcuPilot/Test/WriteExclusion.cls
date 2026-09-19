/// <p>Test-only <class>OcuPilot.Screen.Tool.WebAppUpdate</class> subclass that excludes one
/// top-level <code>ordinary</code> field of the shipped tool's own field-list entry by name.</p>
/// <p><b>What it pins:</b> that <method>OcuPilot.Screen.Tool.Write.FieldRows</method>'s exclusion
/// filter removes a name from the advertised schema and from the settable list. The shipped tool
/// excludes only <code>MatchRoles</code>, whose field-list rows are both dotted and so are dropped
/// by the nested-path filter one line earlier, leaving the exclusion filter itself unexercised.</p>
/// <p><b>What it needs from the environment:</b> nothing the parent does not. It is under
/// <code>OcuPilot.Test.</code>, which the registry's class scan skips, so it is never advertised.</p>
Class OcuPilot.Test.WriteExclusion Extends OcuPilot.Screen.Tool.WebAppUpdate
{

ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild("Description")
}

}
