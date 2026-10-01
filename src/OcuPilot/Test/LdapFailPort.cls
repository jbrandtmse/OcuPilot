/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass that refuses every
/// <code>Security.LDAP</code> <code>CHANGEPWD</code>, the search password's write, at HTTP
/// <parameter>REFUSEDSTATUS</parameter> with <parameter>REFUSEDREASON</parameter>, without reaching
/// the vendor, and counts each refusal. Every other call goes through the shipped port. It lets a test
/// drive the LDAP Save's answer to a password write refused after its configuration write, which the
/// instance cannot be made to give on demand. The count is process-private and lasts until
/// <method>Clear</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LdapFailPort Extends OcuPilot.Port.AdminPort
{

/// <p>The HTTP status every refused password write answers.</p>
Parameter REFUSEDSTATUS As %Integer = 503;

/// <p>The reason every refused password write's fault carries.</p>
Parameter REFUSEDREASON = "OcuPilot.Test.LdapFailPort refuses every search password write.";

/// <p>Forget the count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLdapFail
}

/// <p>How many password writes were refused since <method>Clear</method>.</p>
ClassMethod Reached() As %Integer
{
    Quit +$Get(^||OcuPilotLdapFail)
}

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint '= "Security.LDAP") || (pType '= "CHANGEPWD") Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotLdapFail = $Get(^||OcuPilotLdapFail) + 1
    Set pResult = ""
    Set pHttpStatus = ..#REFUSEDSTATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, ..#REFUSEDREASON)
    Quit $$$ERROR($$$GeneralError, ..#REFUSEDREASON)
}

}
