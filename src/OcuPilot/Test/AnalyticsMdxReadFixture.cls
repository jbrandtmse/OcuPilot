/// <p><class>OcuPilot.Screen.Tool.AnalyticsMdxRead</class> over <class>OcuPilot.Test.AnalyticsPortRecorder</class>, with a two-second bound and one
/// pivot variable, so a test stops the slow grid query in seconds, counts what reaches the port's prepare, and drives the detection on the
/// variable-resolved text: <code>$variable.v</code> resolves to a <code>%SEARCH</code> expression whose braces would increment
/// <code>^OcuPilotProbeMdxSplice(358)</code>. The registry lists no <code>OcuPilot.Test</code> class, so this is never a tool the agent is
/// offered. Everything else is the tool's.</p>
Class OcuPilot.Test.AnalyticsMdxReadFixture Extends OcuPilot.Screen.Tool.AnalyticsMdxRead
{

Parameter PORTCLASS = "OcuPilot.Test.AnalyticsPortRecorder";

/// <p>The seconds the fixture's run is bounded to.</p>
Parameter BOUNDSECONDS = 2;

/// <p>The splice node the variable's braces would increment.</p>
Parameter SPLICENODE = 358;

ClassMethod BoundSeconds() As %Numeric
{
    Quit ..#BOUNDSECONDS
}

ClassMethod Variables(Output pVariables)
{
    Kill pVariables
    Set pVariables("v") = "%SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(" _ ..#SPLICENODE _ "))}]"
}

}
