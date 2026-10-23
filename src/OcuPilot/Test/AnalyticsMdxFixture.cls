/// <p><class>OcuPilot.Area.Analytics.MdxQuery</class> with a two-second bound and one pivot variable, so a test stops the slow grid
/// query in seconds and drives the check on the variable-resolved text: <code>$variable.v</code> resolves to a
/// <code>%SEARCH</code> expression whose braces would increment <code>^OcuPilotProbeMdxSplice(5)</code>. Everything else -- the
/// store, the spawn, the job's checks -- is the production class's, and the job applies these seams because the spawn hands it this
/// class's name.</p>
Class OcuPilot.Test.AnalyticsMdxFixture Extends OcuPilot.Area.Analytics.MdxQuery
{

/// <p>The seconds the fixture's run is bounded to.</p>
Parameter BOUNDSECONDS = 2;

/// <p>The splice node the variable's braces would increment.</p>
Parameter SPLICENODE = 5;

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
