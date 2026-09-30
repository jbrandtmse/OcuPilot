/// <p>The lock removals' codes (AD-39, Story 16.12): every <code>LOCK.*</code> code a removal answers,
/// and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in
/// it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290), as
/// <class>OcuPilot.Api.LanguageServerError</class> does; <method>OcuPilot.Api.Error.ReasonForLock</method>
/// answers these codes through <method>ReasonFor</method>, so every caller still asks the one
/// writer.</p>
Class OcuPilot.Api.LockError Extends %RegisteredObject
{

/// <p>Envelope code: the lock's owner is in an open transaction, so the vendor's own
/// <code>Lock</code> <code>DELETE</code>, sent with its in-transaction check, refused it and removed
/// nothing (DW-1073). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with
/// 409, by <class>OcuPilot.Port.LockPort</class>. It is also the consequence code an overriding
/// proposal carries.</p>
Parameter INTRANSACTION = "LOCK.INTRANSACTION";

/// <p>The sentence <parameter>INTRANSACTION</parameter> carries, published once in EXPERIENCE.md's
/// Fixed strings and pinned equal to <code>lockRemoveInTransaction</code>.</p>
Parameter REASONINTRANSACTION = "Its owner is in an open transaction. Removing the lock leaves that transaction running without it.";

/// <p>Every <code>LOCK.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#INTRANSACTION)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#INTRANSACTION Quit ..#REASONINTRANSACTION
    Quit ""
}

}
