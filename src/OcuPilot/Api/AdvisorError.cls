/// <p>The Security advisor's codes and sentences (AD-29, AD-39): every <code>ADVISOR.*</code> code
/// <class>OcuPilot.Port.AdvisorPort</class> answers with, and the one sentence each carries. Each sentence is published once in
/// EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file> key. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000 parameters (ERROR
/// #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method> answer
/// these codes through <method>ReasonFor</method>, so every caller still asks the one writer.</p>
Class OcuPilot.Api.AdvisorError Extends %RegisteredObject
{

/// <p>409: the recommendation is already ignored. Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug.</p>
Parameter IGNORED = "ADVISOR.IGNORED";

Parameter REASONIGNORED = "This recommendation is already ignored.";

/// <p>409: the recommendation is not ignored. Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug.</p>
Parameter NOTIGNORED = "ADVISOR.NOTIGNORED";

Parameter REASONNOTIGNORED = "This recommendation is not ignored.";

/// <p>Every <code>ADVISOR.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#IGNORED, ..#NOTIGNORED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#IGNORED Quit ..#REASONIGNORED
    If pCode = ..#NOTIGNORED Quit ..#REASONNOTIGNORED
    Quit ""
}

}
