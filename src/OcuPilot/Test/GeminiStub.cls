/// <p>The shipped <class>OcuPilot.Kernel.Provider.Gemini</class> adapter with its transport, its
/// sleep and its clock replaced, so a whole call runs with <b>no socket opened</b>.</p>
/// <p><b>Nothing else is overridden</b>, <method>OcuPilot.Kernel.Provider.Gemini.RequestUrl</method>
/// included: the recorded URL is the one the shipped adapter built, which is what AC2's and AC3's
/// assertions are about.</p>
/// <p>Reached through <class>OcuPilot.Test.CatalogProbeShipped</class>, which re-adapts the
/// shipped <code>gemini</code> row to this class and changes no other column. The script and the
/// recording are <class>OcuPilot.Test.ProviderStub</class>'s, through
/// <class>OcuPilot.Test.ProviderStubTransport</class>.</p>
Class OcuPilot.Test.GeminiStub Extends OcuPilot.Kernel.Provider.Gemini
{

/// <p>The identity this stub reports through
/// <method>OcuPilot.Test.ProviderStub.ServedBy</method>.</p>
Parameter STUBIDENTITY = "geministub";

/// <p>The headers <method>OcuPilot.Test.ProviderStub.Recorded</method>'s
/// <code>headerNames</code> reports the presence of: the one this family's
/// <method>OcuPilot.Kernel.Provider.Gemini.ApplyAuth</method> sets, and the three this family does
/// not -- the other new family's and the canonical family's two -- so a test asserts their absence
/// rather than assuming it.</p>
Parameter WATCHEDHEADERS = "x-goog-api-key,Authorization,x-api-key,anthropic-version";

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
