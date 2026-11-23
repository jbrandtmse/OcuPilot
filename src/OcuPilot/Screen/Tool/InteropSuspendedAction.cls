/// <p>What the Suspended messages screen's three set writes share (AD-6, AD-13, AD-21, AD-22, AD-51, AD-52, AD-53, AD-62, Story 24.16): resubmit, discard and
/// delete of a reviewed set of suspended message headers of the request's namespace through <class>OcuPilot.Port.InteropPort</class>'s
/// <code>SuspendedMessages</code> endpoint, reached by two callers -- a person's action, reviewed first (<parameter>DRYRUN</parameter>), and the agent's proposal and
/// confirmation. It extends the resend of Story 20.31 (<class>OcuPilot.Screen.Tool.InteropMessageAction</class>): the same reviewed digest, card lines and
/// outcome lines, with the action's own verdict and outcome words.</p>
/// <p><b>The target is a set of 1 to <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> message ids</b> (AD-13), named once each in ascending order, refused whole
/// when it is over the cap or holds a member that is not a message header id (<method>SetProblem</method>). <b>It acts on exactly the messages reviewed as the
/// action's own verdict</b>: the fresh read is the port's, whose <code>Verdicts</code> stand for the set and are the fingerprint's
/// subject, the write judges again and refuses a set none of which can be acted on (<code>INTEROP.SUSPENDED.NONE</code>), and a person's action carries the digest it was
/// reviewed at, which the port refuses when the verdicts moved (<code>INTEROP.SUSPENDED.CHANGED</code>). The subject carries <code>Reviewed</code> and <code>Namespace</code>
/// too: the stored payload is narrowed to the subject and the port query is read from it, so a confirm judges in the namespace the proposal read.</p>
Class OcuPilot.Screen.Tool.InteropSuspendedAction Extends OcuPilot.Screen.Tool.InteropMessageAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropSuspendedMessageList";

/// <p>The classic Suspended Messages page, which every write here has a classic counterpart on.</p>
Parameter CLASSICPAGES = "EnsPortal.SuspendedMsg";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Production,Messages,Verdicts,Eligible,Reviewed,Digest";

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Verdicts";

/// <p>The card's row: the lines the set reads.</p>
Parameter STATEFIELD = "Messages";

Parameter PRECONDITIONFIELD = "Verdicts";

Parameter FINGERPRINTSUBJECT = "Verdicts,Production,Namespace,Reviewed";

/// <p>One sentence for the model: what the set names, in this action's words.</p>
Parameter SETDESCRIPTION;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTSUSPENDEDMESSAGES
}

/// <p>The set, comma-separated.</p>
ClassMethod IdArgument() As %String
{
    Quit "Messages"
}

/// <p><parameter>OcuPilot.Screen.Tool.InteropMessageAction.REVIEWEDARGUMENT</parameter> alone: the tool sends no body, so the one value a person's action carries
/// reaches the port through <method>OcuPilot.Screen.Tool.InteropMessageAction.PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#REVIEWEDARGUMENT)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the set is checked
/// (<class>OcuPilot.Screen.Tool.InteropSuspendedMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropSuspendedMint"
}

/// <p>What is wrong with <var>pValue</var> as the set of messages this action names, or <code>""</code>:
/// <method>OcuPilot.Port.InteropPort.MessageSet</method>'s rule, the one the port refuses a call by, and an argument carrying the digest only a person's action
/// carries.</p>
ClassMethod SetProblem(pValue As %String, pArgs As %DynamicObject) As %String
{
    If $IsObject(pValue) Quit "'" _ ..IdArgument() _ "' names the messages as a string of message ids"
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#REVIEWEDARGUMENT) '= "unassigned") Quit "'" _ ..#REVIEWEDARGUMENT _ "' is not an argument a proposal takes"
    If ##class(OcuPilot.Port.InteropPort).MessageSet(pValue, .tIds) Quit ""
    Quit "'" _ ..IdArgument() _ "' names 1 to " _ ##class(OcuPilot.Port.InteropPort).#RESENDMAX _ " message ids, separated by commas, each digits and none beginning with zero"
}

/// <p>The derived schema with the set described: the messages the Suspended messages list reports, at most
/// <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..#SETDESCRIPTION _ " Name them by the ids interop.suspendedmessages.read reports in its ID column, separated by commas, at most " _ ##class(OcuPilot.Port.InteropPort).#RESENDMAX _ ". A set over that, or with an id that is not a message id, is refused whole.", "string")
    }
    Quit tSchema
}

/// <p>The screen's <code>Reviewed</code> value as this tool's argument (AD-56 (ii)): the digest a person's dry run answered, a string as sent; none when the action
/// carries none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#REVIEWEDARGUMENT) = "string") Do pArgs.%Set(..#REVIEWEDARGUMENT, pValues.%Get(..#REVIEWEDARGUMENT), "string")
    Quit $$$OK
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Messages</code>, whose after-value is the set's lines, one for each message in
/// id order (<method>OcuPilot.Screen.Tool.InteropMessageAction.MessageLine</method>). A set none of whose messages can be acted on is <var>pProblem</var>, the sentence
/// of <code>INTEROP.SUSPENDED.NONE</code> and then the lines; a read that answered no messages refuses too.</p>
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
            Set pProblem = ##class(OcuPilot.Port.InteropPort).Sentence("INTEROP.SUSPENDED.NONE") _ $Char(10) _ tLines
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
