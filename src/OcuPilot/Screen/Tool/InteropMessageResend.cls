/// <p>Interoperability's message resend (AD-6, AD-13, AD-22, AD-51, AD-53, AD-62, Story 20.31): send the messages of one set to their
/// targets again, as new messages in their sessions, each only if its verdict says it can go. Two callers reach it: the Messages
/// list's row action Resend over the checked rows, and the Header tab's over the one message, each through
/// <class>OcuPilot.Api.ScreenAction</class> after the dry run a person reviews (<class>OcuPilot.Api.ScreenDryRun</class>), and the
/// agent's proposal and confirmation.</p>
/// <p><b>The target is a set of 1 to <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> message ids</b> (AD-13): the
/// <code>interop-message</code> id's canonical spelling names each id once, in ascending order, so two spellings of one set are one
/// target. A set over the cap, or with a member that is not a message header id, is refused whole, never cut
/// (<method>SetProblem</method>, and the port's <code>PORT.VALIDATION</code>).</p>
/// <p><b>It resends exactly the messages reviewed as <code>resend</code></b>. The fresh read is the port's <code>RESEND</code>, whose
/// <code>Verdicts</code> stand for the set and are the fingerprint's subject; the write judges again, refuses a set none of which can go
/// (<code>INTEROP.RESEND.NONE</code>) and goes on past a vendor refusal of one message. A person's action carries the digest it was
/// reviewed at as <code>Reviewed</code>, and the port refuses it when the verdicts moved (<code>INTEROP.RESEND.CHANGED</code>). The
/// subject carries <code>Reviewed</code> too, because the stored payload is narrowed to the subject and the port query is read
/// from that payload.</p>
Class OcuPilot.Screen.Tool.InteropMessageResend Extends OcuPilot.Screen.Tool.InteropMessageAction
{

Parameter TOOLNAME = "interop.messages.resend";

Parameter DESCRIPTION = "Propose resending messages of the interoperability message store to their targets, as new messages in their own sessions. It sends nothing by itself: it answers a proposal the user reviews and confirms, and the proposal shows what each message would do. Name the messages by the ids interop.messages.read reports in its ID column, up to 100, separated by commas; a set over 100 or with a malformed id is refused, never cut. The production must be running. A message is resent only if it still exists with its body, a request's target is an enabled item of the running production, and a response's reply queue still exists; the others are listed with the reason and not resent, and a set none of which can be resent is refused. A message that was already delivered is delivered twice, and a resend cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropMessageList";

/// <p>The fresh read: the set's verdicts, composed for the action.</p>
Parameter READTYPE = "RESEND";

Parameter WRITETYPE = "RESENDMESSAGES";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Production,Messages,Verdicts,Eligible,Reviewed,Digest";

Parameter SCREENACTIONS = "resend";

/// <p>A person's action carries the digest it was reviewed at; the dry run carries none.</p>
Parameter SCREENVALUES = "resend=Reviewed";

Parameter SCREENOPTIONAL = "resend=Reviewed";

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Verdicts";

/// <p>The card's row: the lines the set reads.</p>
Parameter STATEFIELD = "Messages";

Parameter PRECONDITIONFIELD = "Verdicts";

Parameter FINGERPRINTSUBJECT = "Verdicts,Production,Namespace,Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.MESSAGE.RESEND";

/// <p>The set, comma-separated.</p>
ClassMethod IdArgument() As %String
{
    Quit "Messages"
}

/// <p><parameter>OcuPilot.Screen.Tool.InteropMessageAction.REVIEWEDARGUMENT</parameter> alone: the tool sends no body, so its field
/// list is empty by derivation, and the one value a person's action carries reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#REVIEWEDARGUMENT)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the set is checked
/// (<class>OcuPilot.Screen.Tool.InteropMessageResendMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropMessageResendMint"
}

/// <p>What is wrong with <var>pValue</var> as the set of messages a resend names, or <code>""</code>:
/// <method>OcuPilot.Port.InteropPort.MessageSet</method>'s rule, the one the port refuses a call by, and an argument carrying the
/// digest only a person's action carries.</p>
ClassMethod SetProblem(pValue As %String, pArgs As %DynamicObject) As %String
{
    If $IsObject(pValue) Quit "'" _ ..IdArgument() _ "' names the messages as a string of message ids"
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#REVIEWEDARGUMENT) '= "unassigned") Quit "'" _ ..#REVIEWEDARGUMENT _ "' is not an argument a proposal takes"
    If ##class(OcuPilot.Port.InteropPort).MessageSet(pValue, .tIds) Quit ""
    Quit "'" _ ..IdArgument() _ "' names 1 to " _ ##class(OcuPilot.Port.InteropPort).#RESENDMAX _ " message ids, separated by commas, each digits and none beginning with zero"
}

/// <p>The derived schema with the set described: the messages the Messages list reports, at most
/// <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The messages to resend, as the ids interop.messages.read reports in its ID column, separated by commas, at most " _ ##class(OcuPilot.Port.InteropPort).#RESENDMAX _ ". A set over that, or with an id that is not a message id, is refused whole.", "string")
    }
    Quit tSchema
}

/// <p>The screen's <code>Reviewed</code> value as this tool's argument (AD-56 (ii)): the digest a person's dry run answered, a
/// string as sent; none when the action carries none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#REVIEWEDARGUMENT) = "string") Do pArgs.%Set(..#REVIEWEDARGUMENT, pValues.%Get(..#REVIEWEDARGUMENT), "string")
    Quit $$$OK
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Messages</code>, whose after-value is the
/// set's lines, one for each message in id order (<method>MessageLine</method>). A set none of whose messages can be resent is
/// <var>pProblem</var>, the sentence of <code>INTEROP.RESEND.NONE</code> and then the lines; a read that answered no messages
/// refuses too.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Messages") '= "array") || (pFresh.%Get("Messages").%Size() = 0) {
            Set pProblem = "this instance did not report the messages"
            Quit
        }
        Set tLines = ""
        Set tIterator = pFresh.%Get("Messages").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMessage) {
            Set tLines = tLines _ $Select(tLines = "": "", 1: $Char(10)) _ ..MessageLine(tMessage)
        }
        If 'pFresh.%Get("Eligible") {
            Set pProblem = ##class(OcuPilot.Port.InteropPort).Sentence("INTEROP.RESEND.NONE") _ $Char(10) _ tLines
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", tLines, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
