/// <p>The monitor port's codes (AD-39, Story 21.20): every <code>MONITOR.*</code> code
/// <class>OcuPilot.Port.MonitorPort</class> answers with, and the one sentence each carries. Each sentence is
/// published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather
/// than in it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> answers these codes through
/// <method>ReasonFor</method>.</p>
Class OcuPilot.Api.MonitorError Extends %RegisteredObject
{

/// <p>409: the System Monitor is not running, so its transaction data is not available.</p>
Parameter NOTRUNNING = "MONITOR.NOTRUNNING";

Parameter REASONNOTRUNNING = "Transaction data is not available because the System Monitor is not running.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NOTRUNNING Quit ..#REASONNOTRUNNING
    Quit ""
}

}
