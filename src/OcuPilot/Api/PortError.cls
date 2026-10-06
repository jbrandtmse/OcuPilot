/// <p>The codes a port answers beyond its vendor's own faults (AD-39): today the one a queued
/// write carries when it has started and is still running at the port's bound (AD-26). They live
/// beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290), as <class>OcuPilot.Api.LockError</class>
/// does.</p>
Class OcuPilot.Api.PortError Extends %RegisteredObject
{

/// <p>The ledger code of a confirmed write the port answered as started (HTTP 202): it was applied,
/// and it finishes on the instance in the background. A finished write carries no code.</p>
Parameter STARTED = "PORT.STARTED";

/// <p>The sentence <parameter>STARTED</parameter> carries, published once in EXPERIENCE.md's Fixed
/// strings and pinned equal to <code>auditDatabaseStillRunning</code>.</p>
Parameter REASONSTARTED = "Still running on the instance. It finishes in the background.";

/// <p>Every code this class declares, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#STARTED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#STARTED Quit ..#REASONSTARTED
    Quit ""
}

}
