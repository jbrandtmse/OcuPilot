/// <p>The navigation codes the browser authors (AD-11 rule 3, AD-39): every <code>NAV.*</code> code
/// that is not in <class>OcuPilot.Api.Error</class>'s own set, and the sentence each carries. They live
/// beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's
/// limit of 1,000 parameters (ERROR #5290). <method>OcuPilot.Api.Error.ReasonForToolCode</method>
/// reaches them through the <code>NAV.</code> prefix after its own <code>NAV.*</code> codes.</p>
Class OcuPilot.Api.NavError Extends %RegisteredObject
{

/// <p>Terminal tool-result code for the navigation announce step: the browser could not load the
/// screen it was sent to (its code chunk failed to load). The announcement is withdrawn, and the
/// call's own <code>tool_result</code> is an ordinary refusal. A browser authors it, with
/// <parameter>OcuPilot.Api.Error.NAVREFUSEDUNSAVED</parameter>, through
/// <code>POST /turn/:id/navigation</code>.</p>
Parameter NAVLOADFAILED = "NAV.LOADFAILED";

Parameter REASONNAVLOADFAILED = "The browser could not load that screen, so the move was not made.";

/// <p>Every code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAVLOADFAILED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAVLOADFAILED Quit ..#REASONNAVLOADFAILED
    Quit ""
}

}
