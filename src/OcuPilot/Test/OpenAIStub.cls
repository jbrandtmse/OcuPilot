/// <p>The shipped <class>OcuPilot.Kernel.Provider.OpenAI</class> adapter with its transport, its
/// sleep and its clock replaced, so a whole call runs with <b>no socket opened</b>.</p>
/// <p><b>Nothing of the wire is replaced.</b> The body, the authentication header, the key-shape
/// gate and the response mapping are the shipped adapter's own, which is what makes an assertion
/// about the recorded request an observation of shipped code rather than of a fixture.
/// <method>ApplyAuth</method> is overridden only to add the armed error-log leg after delegating
/// to it.</p>
/// <p>Reached through <class>OcuPilot.Test.CatalogProbeShipped</class>, which re-adapts the
/// shipped <code>openai</code> row to this class and changes no other column. The script and the
/// recording are <class>OcuPilot.Test.ProviderStub</class>'s, through
/// <class>OcuPilot.Test.ProviderStubTransport</class>.</p>
Class OcuPilot.Test.OpenAIStub Extends OcuPilot.Kernel.Provider.OpenAI
{

/// <p>The identity this stub reports through
/// <method>OcuPilot.Test.ProviderStub.ServedBy</method>.</p>
Parameter STUBIDENTITY = "openaistub";

/// <p>The headers <method>OcuPilot.Test.ProviderStub.Recorded</method>'s
/// <code>headerNames</code> reports the presence of: the one this family's
/// <method>OcuPilot.Kernel.Provider.OpenAI.ApplyAuth</method> sets, and the three this family does
/// not -- the other new family's and the canonical family's two -- so a test asserts their absence
/// rather than assuming it. The content type is recorded
/// from its own property, because <method>%Net.HttpRequest.SetHeader</method> diverts that
/// one.</p>
Parameter WATCHEDHEADERS = "Authorization,x-goog-api-key,x-api-key,anthropic-version";

/// <p>Write this family's own authentication header through the shipped
/// <method>OcuPilot.Kernel.Provider.OpenAI.ApplyAuth</method>, then force the armed
/// application-error entry <b>in this frame</b>, so AD-48's sweep captures whatever
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> and <code>Attempts</code> are holding
/// while this family serves the call. A run nothing armed is unchanged by it.</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    Do ##super(pRequest)
    Do ##class(OcuPilot.Test.ProviderStubTransport).ForceErrorLog()
}

Method IssueHttpsPost(pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Quit ##class(OcuPilot.Test.ProviderStubTransport).Transport(..#STUBIDENTITY, ..#WATCHEDHEADERS, pRequest, pUrl, .pStatus, .pBody, .pRetryAfter)
}

Method Wait(pSeconds As %Numeric)
{
    Do ##class(OcuPilot.Test.ProviderStubTransport).Wait(pSeconds)
}

Method NowSeconds() As %Numeric
{
    Quit ##class(OcuPilot.Test.ProviderStubTransport).NowSeconds()
}

}
