/// <p>The analytics codes and sentences (AD-29, AD-39, AD-65, Story 20.11): every <code>ANALYTICS.*</code> code
/// <class>OcuPilot.Port.AnalyticsPort</class> answers with, and the sentence each carries. Each sentence is
/// published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/analytics.test.mjs</file>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409: the
/// vendor's analytics classes check no <code>%DeepSee_*</code> resource, so the port decides before any call.</p>
Class OcuPilot.Api.AnalyticsError Extends %RegisteredObject
{

/// <p>The route's namespace does not report analytics.</p>
Parameter NAMESPACE = "ANALYTICS.NAMESPACE";

Parameter REASONNAMESPACE = "Analytics is not enabled in this namespace.";

/// <p>The sentence for <var>pCode</var>, or <code>""</code> for a code this class does not hold.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    Quit ""
}

}
