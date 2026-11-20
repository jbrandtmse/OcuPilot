/// <p>The SQL activity cancel's codes (AD-39, Story 21.20): every <code>SQLACTIVITY.*</code> code
/// <class>OcuPilot.Port.SqlActivityPort</class> answers a cancel with, and the one sentence each carries.
/// Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather
/// than in it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> answers these codes through
/// <method>ReasonFor</method>.</p>
Class OcuPilot.Api.SqlActivityError Extends %RegisteredObject
{

/// <p>409: the statement runs on another server, so it is not canceled from here.</p>
Parameter REMOTE = "SQLACTIVITY.REMOTE";

Parameter REASONREMOTE = "This statement runs on another server and can be canceled only there.";

/// <p>409: the statement is no longer running, so there is nothing to cancel.</p>
Parameter ENDED = "SQLACTIVITY.ENDED";

Parameter REASONENDED = "This statement is no longer running.";

/// <p>403: the instance's answer that the caller lacks the SQL privilege <code>%CANCEL_QUERY</code>, which
/// canceling another user's statement needs and which no resource pair grants.</p>
Parameter NOPRIVILEGE = "SQLACTIVITY.NOPRIVILEGE";

Parameter REASONNOPRIVILEGE = "Canceling another user's query needs the SQL privilege %CANCEL_QUERY.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#REMOTE Quit ..#REASONREMOTE
    If pCode = ..#ENDED Quit ..#REASONENDED
    If pCode = ..#NOPRIVILEGE Quit ..#REASONNOPRIVILEGE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 409 or 403, and 0 for a code that is no
/// refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If (pCode = ..#REMOTE) || (pCode = ..#ENDED) Quit 409
    If pCode = ..#NOPRIVILEGE Quit 403
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    If ..HttpStatusFor(pCode) = 403 Quit ##class(OcuPilot.Api.Error).#FORBIDDEN
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
