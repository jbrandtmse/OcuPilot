/// <p>Test-only <class>OcuPilot.Screen.Tool.X509Update</class> subclass with two replaced seams:
/// <method>SecretArguments</method> answers the one name <method>Declare</method> stored, as a
/// descriptor declaring it would, and <method>PermittedFields</method> answers no restriction, so
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> is asked about every classified field of
/// the edit's entry. It lives outside the registry's package, so it is never a registered tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.X509SecretProbe Extends OcuPilot.Screen.Tool.X509Update
{

/// <p>Store <var>pName</var> as the one declared secret; <code>""</code> declares none.</p>
ClassMethod Declare(pName As %String)
{
    Set ^||OcuPilotSecretSpelling = pName
}

ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Set tName = $Get(^||OcuPilotSecretSpelling)
    If tName = "" Quit ""
    Quit $ListBuild(tName)
}

ClassMethod PermittedFields() As %List
{
    Quit ""
}

/// <p>The names <method>OcuPilot.Screen.Tool.Write.FieldRows</method> admits now, as a
/// <class>%List</class>.</p>
ClassMethod AdmittedNames() As %List
{
    Set tNames = ""
    Set tSC = ..FieldRows(.tRows)
    If $$$ISERR(tSC) Quit ""
    For tI = 1:1:+$Get(tRows) Set tNames = tNames _ $ListBuild($List(tRows(tI), 1))
    Quit tNames
}

}
