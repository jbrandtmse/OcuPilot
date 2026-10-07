/// <p>The interoperability codes and sentences (AD-29, AD-39, AD-62, Story 20.2): every
/// <code>INTEROP.*</code> code <class>OcuPilot.Port.InteropPort</class> answers with, the four
/// consequence codes the production tools' proposals carry, and the sentence each carries. Each sentence
/// is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/self-protection.test.mjs</file>. They
/// live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409:
/// the vendor would have answered each as a success or a refusal that leaves the production as it was.</p>
Class OcuPilot.Api.InteropError Extends %RegisteredObject
{

/// <p>The route's namespace does not run interoperability productions.</p>
Parameter NAMESPACE = "INTEROP.NAMESPACE";

Parameter REASONNAMESPACE = "This namespace does not run interoperability productions.";

/// <p>Start of a production that is running.</p>
Parameter RUNNING = "INTEROP.PRODUCTION.RUNNING";

Parameter REASONRUNNING = "This production is already running.";

/// <p>Start of a production while another is current in the namespace (running, suspended or
/// troubled).</p>
Parameter OTHER = "INTEROP.PRODUCTION.OTHER";

Parameter REASONOTHER = "Another production is running, suspended or troubled in this namespace, and a namespace runs one production at a time.";

/// <p>Start of a production that did not shut down cleanly.</p>
Parameter TROUBLED = "INTEROP.PRODUCTION.TROUBLED";

Parameter REASONTROUBLED = "This production did not shut down cleanly. Recover it first; once it reads Suspended it can be started.";

/// <p>Stop, restart or update of a production that is not running.</p>
Parameter NOTRUNNING = "INTEROP.PRODUCTION.NOTRUNNING";

Parameter REASONNOTRUNNING = "This production is not running.";

/// <p>Update of a production with nothing pending.</p>
Parameter UPTODATE = "INTEROP.PRODUCTION.UPTODATE";

Parameter REASONUPTODATE = "This production is up to date, so there is nothing to update.";

/// <p>Recover of a production that is not troubled.</p>
Parameter NOTTROUBLED = "INTEROP.PRODUCTION.NOTTROUBLED";

Parameter REASONNOTTROUBLED = "Only a troubled production can be recovered.";

/// <p>The vendor refused a stop, restart or update because the production's work in progress did not
/// finish within the wait; the production is as it was.</p>
Parameter BUSY = "INTEROP.PRODUCTION.BUSY";

Parameter REASONBUSY = "The production's work in progress did not finish within 15 seconds, so it was left as it was.";

/// <p>The production's state is not one of Running, Stopped, Suspended and Troubled.</p>
Parameter STATE = "INTEROP.PRODUCTION.STATE";

Parameter REASONSTATE = "This production's state does not allow that action here.";

/// <p>The consequence codes the stop, restart, update and recover proposals carry. The client maps each
/// to its warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter STOP = "INTEROP.STOP";

Parameter REASONSTOP = "Stopping this production waits up to 15 seconds for its work in progress to finish. If it takes longer, nothing is stopped.";

Parameter RESTART = "INTEROP.RESTART";

Parameter REASONRESTART = "Restarting this production stops it and starts it again. If its work in progress takes longer than 15 seconds to finish, nothing is stopped.";

Parameter UPDATE = "INTEROP.UPDATE";

Parameter REASONUPDATE = "Updating this production restarts only the items whose settings changed, and starts or stops the items enabled or disabled since it started. If an item takes longer than 15 seconds to finish its work, the update is refused and the production keeps running.";

Parameter RECOVER = "INTEROP.RECOVER";

Parameter REASONRECOVER = "Recover is the first response to a troubled production: it returns it to Suspended so it can be started again, marking messages it cannot keep queued as Discarded or Suspended and deleting none. Clean, which deletes queued messages, is a last resort OcuPilot does not offer.";

/// <p>The refusals the port answers with, as a <class>%List</class>: every code that is not a
/// consequence.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAMESPACE, ..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#BUSY, ..#STATE)
}

/// <p>The consequence codes, as a <class>%List</class>.</p>
ClassMethod ConsequenceCodes() As %List
{
    Quit $ListBuild(..#STOP, ..#RESTART, ..#UPDATE, ..#RECOVER)
}

/// <p>The codes a production tool's fresh read refuses with when the action's precondition does not
/// hold, as a <class>%List</class>: <class>OcuPilot.Screen.Tool.Write</class>'s
/// <code>PRECONDITIONCODES</code>.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit $ListBuild(..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#STATE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#RUNNING Quit ..#REASONRUNNING
    If pCode = ..#OTHER Quit ..#REASONOTHER
    If pCode = ..#TROUBLED Quit ..#REASONTROUBLED
    If pCode = ..#NOTRUNNING Quit ..#REASONNOTRUNNING
    If pCode = ..#UPTODATE Quit ..#REASONUPTODATE
    If pCode = ..#NOTTROUBLED Quit ..#REASONNOTTROUBLED
    If pCode = ..#BUSY Quit ..#REASONBUSY
    If pCode = ..#STATE Quit ..#REASONSTATE
    If pCode = ..#STOP Quit ..#REASONSTOP
    If pCode = ..#RESTART Quit ..#REASONRESTART
    If pCode = ..#UPDATE Quit ..#REASONUPDATE
    If pCode = ..#RECOVER Quit ..#REASONRECOVER
    Quit ""
}

}
