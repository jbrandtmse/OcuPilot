/// <p>The user copy's codes (AD-39, Story 18.29): the two <code>USERCOPY.*</code> codes a copy answers
/// and the sentence each carries. They live beside <class>OcuPilot.Api.Error</class> because that class
/// holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.UserCopyError Extends %RegisteredObject
{

/// <p>Violation code, on <code>CopyFrom</code>: the source is absent, a directory-service or delegated
/// account, which the classic user list does not offer to copy (AD-39).</p>
Parameter SOURCE = "USERCOPY.SOURCE";

Parameter REASONSOURCE = "Copy from a local user this instance holds, not a directory-service or delegated account.";

/// <p>Refusal (409): the source's roles or escalation roles changed between the proposal and the write, so
/// the copy is not the one the user reviewed. Nothing is created.</p>
Parameter SOURCECHANGED = "USERCOPY.SOURCECHANGED";

Parameter REASONSOURCECHANGED = "The source user's roles changed after this copy was proposed. Propose the copy again to review them.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#SOURCE Quit ..#REASONSOURCE
    If pCode = ..#SOURCECHANGED Quit ..#REASONSOURCECHANGED
    Quit ""
}

}
