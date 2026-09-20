/// <p>A stub whose <method>OcuPilot.Kernel.Provider.Base.RequestUrl</method> answers a well-formed
/// URL on a <b>different authority</b> from the endpoint it was handed, so the second arm of the
/// base's built-URL containment check has a failing case (AD-42).</p>
/// <p>It exists because no shipped adapter can reach that arm: the only shipped override is
/// <method>OcuPilot.Kernel.Provider.Gemini.RequestUrl</method>, whose
/// <parameter>OcuPilot.Kernel.Provider.Gemini.MODELPATTERN</parameter> admits no character that
/// could change a scheme or an authority, so every shipped refusal lands on the empty-result arm.
/// A rule with no failing case is not enforced, it is merely written -- and this seam is the one
/// Story 10.3 reuses for endpoint normalization, where moving the authority is exactly the mistake
/// to refuse.</p>
/// <p>Extends <class>OcuPilot.Test.GeminiStub</class> so the transport, the sleep and the clock are
/// already replaced: <b>no socket is opened by anything here</b>, and a call that reached the
/// transport records itself, which is what lets a test assert that none did.</p>
Class OcuPilot.Test.ProviderOriginProbe Extends OcuPilot.Test.GeminiStub
{

/// <p>The authority this probe moves the call to -- a host the address policy was never asked
/// about, which is the whole point. Nothing connects to it.</p>
Parameter MOVEDORIGIN = "https://elsewhere.example.net";

/// <p>The path the moved URL carries, so the answer is a well-formed absolute URL and the check
/// under test is the authority comparison rather than a parse failure.</p>
Parameter MOVEDPATH = "/v1beta/models/probe-model-1:generateContent";

/// <p>A well-formed URL on <parameter>MOVEDORIGIN</parameter>, whatever endpoint was judged.</p>
Method RequestUrl(ByRef pValues) As %String
{
    Quit ..#MOVEDORIGIN _ ..#MOVEDPATH
}

}
