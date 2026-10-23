/// <p>The guided-workflow codes (AD-39, AD-66, Story 20.12): every <code>WORKFLOW.*</code> code a turn start
/// and a workflow turn's write call answer, and the one sentence each carries. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> answers these codes through
/// <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.WorkflowError Extends %RegisteredObject
{

/// <p>Violation code (422) on the start body's <code>workflow</code> member: it is not a string, or it names no
/// catalog workflow. Nothing is reserved.</p>
Parameter UNKNOWN = "WORKFLOW.UNKNOWN";

Parameter REASONUNKNOWN = "That guided workflow is not one OcuPilot offers.";

/// <p>Tool result: a workflow turn called a write tool that no step of its workflow names. Nothing is
/// minted.</p>
Parameter NOTASTEP = "WORKFLOW.NOTASTEP";

Parameter REASONNOTASTEP = "This guided workflow makes no change with that tool; describe the change instead of proposing it.";

/// <p>Tool result: a workflow turn called a write tool after the turn already holds a proposal. Nothing is
/// minted.</p>
Parameter ONECHANGE = "WORKFLOW.ONECHANGE";

Parameter REASONONECHANGE = "This turn has already proposed its change; end the turn so the user can confirm it before the next.";

/// <p>Every <code>WORKFLOW.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#UNKNOWN, ..#NOTASTEP, ..#ONECHANGE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#UNKNOWN Quit ..#REASONUNKNOWN
    If pCode = ..#NOTASTEP Quit ..#REASONNOTASTEP
    If pCode = ..#ONECHANGE Quit ..#REASONONECHANGE
    Quit ""
}

}
