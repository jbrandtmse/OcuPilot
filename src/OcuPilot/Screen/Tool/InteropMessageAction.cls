/// <p>What Interoperability's two message resend writes share (AD-6, AD-13, AD-51, AD-52, AD-53, AD-62, Story 20.31): a resend of
/// messages of the request's namespace through <class>OcuPilot.Port.InteropPort</class>'s <code>Messages</code> endpoint, reached by
/// two callers -- a person's action, which is reviewed first (<parameter>DRYRUN</parameter>), and the agent's proposal and
/// confirmation.</p>
/// <p><b>The dry run is the fresh read</b>: the port judges each message before any vendor call, and the verdicts are the rows the
/// agent's proposal card shows and the dialog a person reviews. A person's action then carries the reviewed digest
/// (<code>Reviewed</code>) and the port refuses it when the verdicts moved, <code>INTEROP.RESEND.CHANGED</code>; the agent's proposal
/// is held to the fingerprint instead. <method>PortQuery</method> names the digest under
/// <parameter>OcuPilot.Port.InteropPort.DIGESTKEY</parameter>.</p>
/// <p><b>Both are destructive</b>: a delivered copy cannot be recalled by proposing the opposite, so each card draws the destructive
/// treatment, each person's action types the count or the id, and each governance key ships disabled (AD-22). The vendor audits each
/// new header, so OcuPilot records no row of its own.</p>
Class OcuPilot.Screen.Tool.InteropMessageAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>A person's action is reviewed through <code>POST /screens/:screen/dryrun</code> before it is sent.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The classic Resend page's resource (<code>EnsPortal.MessageResend</code>, AD-8, AD-44).</p>
Parameter WRITERESOURCE = "%Ens_MessageResend";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.MessageResend";

/// <p>A resend creates new message headers, which the Messages list and a message's tabs read again.</p>
Parameter CHANGEACTION = "created";

/// <p>The argument carrying the digest a person reviewed the action at. Only a person's action carries it; the agent's proposal does
/// not, and its schema does not offer it.</p>
Parameter REVIEWEDARGUMENT = "Reviewed";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTMESSAGES
}

/// <p>Compose the port's read (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>), then name the digest a person
/// reviewed under <parameter>OcuPilot.Port.InteropPort.DIGESTKEY</parameter>: the payload's <code>Reviewed</code>, else its
/// <code>Digest</code>. An empty one names nothing, so the agent's proposal, whose payload carries <code>Reviewed</code> empty, is
/// read without a review to hold it to.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tDigest = ""
    If pPayload.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Set tDigest = pPayload.%Get(..#REVIEWEDARGUMENT)
    If (tDigest = "") && (pPayload.%GetTypeOf("Digest") = "string") Set tDigest = pPayload.%Get("Digest")
    If tDigest '= "" Set pQuery(##class(OcuPilot.Port.InteropPort).#DIGESTKEY) = tDigest
}

/// <p>What a reviewed action answers beside its rows: the digest the person's action carries back.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    Do tReview.%Set("Digest", $Select($IsObject(pFresh): pFresh.%Get("Digest"), 1: ""), "string")
    Quit tReview
}

/// <p>The fresh read as the payload and nothing to merge: the card's rows are <method>StateDiff</method>'s, and the arguments are
/// carried to the port by <method>PortQuery</method>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The line a message reads on a card or in a dialog: <code>&lt;ID&gt; &middot; &lt;Source&gt; &rarr; &lt;Target&gt;: &lt;verdict
/// sentence&gt;</code>, or <code>&lt;ID&gt;: &lt;verdict sentence&gt;</code> for a message that is gone, which has neither. It is
/// text: the names are the instance's own and are drawn as text, never as markup (AD-11).</p>
ClassMethod MessageLine(pMessage As %DynamicObject) As %String
{
    Set tSentence = ##class(OcuPilot.Port.InteropPort).VerdictSentence(pMessage.%Get("Verdict"))
    If (pMessage.%Get("Source") = "") && (pMessage.%Get("Target") = "") Quit pMessage.%Get("ID") _ ": " _ tSentence
    Quit pMessage.%Get("ID") _ " " _ $Char(183) _ " " _ pMessage.%Get("Source") _ " " _ $Char(8594) _ " " _ pMessage.%Get("Target") _ ": " _ tSentence
}

/// <p>The outcome a confirmed write shows a person, <code>{lines}</code>, one line for each message the write sent:
/// <code>&lt;id&gt;: resent as &lt;new&gt;</code> or <code>&lt;id&gt;: not resent: &lt;text&gt;</code>. It reaches the screen alone
/// (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tLines = []
    If pWritten.%GetTypeOf("Messages") = "array" {
        Set tIterator = pWritten.%Get("Messages").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.%GetTypeOf("NewId") = "string" {
                Do tLines.%Push(tEntry.%Get("ID") _ ": " _ ##class(OcuPilot.Port.InteropPort).OutcomeWord(1) _ " " _ tEntry.%Get("NewId"), "string")
            } Else {
                Do tLines.%Push(tEntry.%Get("ID") _ ": " _ ##class(OcuPilot.Port.InteropPort).OutcomeWord(0) _ ": " _ tEntry.%Get("Error"), "string")
            }
        }
    } ElseIf pWritten.%GetTypeOf("NewId") = "string" {
        Do tLines.%Push(pWritten.%Get("Message") _ ": " _ ##class(OcuPilot.Port.InteropPort).OutcomeWord(1) _ " " _ pWritten.%Get("NewId"), "string")
    }
    Set tOutput = {}
    Do tOutput.%Set("lines", tLines)
    Quit tOutput
}

}
