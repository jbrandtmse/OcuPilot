/// <p>A test-only OAuth 2.0 resource server authenticator (Story 12.6): a
/// <class>%OAuth2.ResourceServer.Authenticator</class> subclass with one credential-named setting,
/// <property>ApiKey</property>, and one ordinary one, <property>Claim</property>, so a test can show a
/// credential setting is never read or sent while an ordinary one is. It answers the claim's value as
/// the user name.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthProbeAuthenticator Extends %OAuth2.ResourceServer.Authenticator
{

/// <p>A credential-named setting, which the resource server port never reads back.</p>
Property ApiKey As %String(MAXLEN = 256);

/// <p>The claim whose value names the user.</p>
Property Claim As %String(MAXLEN = 256) [ InitialExpression = "sub" ];

Method Authenticate(pClaims As %DynamicObject, pOidc As %Boolean, Output pProperties As %String) As %Status
{
    Set tSC = $$$OK
    Set pProperties("Username") = pClaims.%Get(..Claim)
    If pProperties("Username") = "" Set tSC = $$$ERROR($$$GeneralError, "the probe authenticator found no user")
    Quit tSC
}

}
