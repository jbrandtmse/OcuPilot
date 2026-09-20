/// <p>Test-only <class>OcuPilot.Screen.Tool.WebAppUpdate</class> subclass that excludes one
/// top-level <code>ordinary</code> field of the shipped tool's own field-list entry by name.</p>
/// <p><b>What it pins:</b> that <method>OcuPilot.Screen.Tool.Write.FieldRows</method>'s exclusion
/// filter removes a name from the advertised schema and from the settable list, while an unlisted
/// sibling stays -- the comparison the shipped tool cannot make, because every name it excludes is
/// one no path of its own admits. It also lifts the parent's positive
/// <method>OcuPilot.Screen.Tool.Write.PermittedFields</method> restriction, so the shape of a row
/// the shipped tool no longer advertises -- an array field among them -- still has a tool to be
/// read on.</p>
/// <p><b>What it needs from the environment:</b> nothing the parent does not. It is under
/// <code>OcuPilot.Test.</code>, which the registry's class scan skips, so it is never advertised.</p>
Class OcuPilot.Test.WriteExclusion Extends OcuPilot.Screen.Tool.WebAppUpdate
{

ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild("Description")
}

/// <p>No positive restriction, so every <code>ordinary</code> top-level field of the entry is
/// admitted here and the one excluded name is the only thing missing.</p>
ClassMethod PermittedFields() As %List
{
    Quit ""
}

}
