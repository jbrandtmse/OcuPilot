/// <p>The processes list's broadcast tool (AD-6, AD-51, AD-52, AD-53): send one line of text to the
/// terminals of a set of processes. Two callers reach it: the Broadcast command on Processes, over
/// the rows checked there, through <class>OcuPilot.Api.ScreenAction</class> with the message as the
/// action's one value (AD-56 (ii)), and the agent's proposal and confirmation.</p>
/// <p><b>The target is a pid set</b> (AD-13): the <code>process</code> id's canonical spelling names
/// each pid once, in ascending order, so two spellings of one set are one target.
/// <method>PidsProblem</method> refuses a set that is not 1 to
/// <parameter>OcuPilot.Port.ProcessPort.BROADCASTMAXPIDS</parameter> process ids.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.ProcessPort</class> composes the vendor's <code>{Message, PidList}</code> from
/// <parameter>MESSAGEFIELD</parameter>, which travels in the port query
/// (<method>PortQuery</method>), and the target's canonical set. The fresh read is the port's
/// <code>RECIPIENTS</code>; its fingerprint subject is the recipients, the pids no process carries
/// and the message, so a recipient that ends, or whose <code>Username</code> or
/// <code>CanReceiveBroadcast</code> moves, refuses the confirm. The message is in the subject because
/// the stored payload is narrowed to it, and the port query is read from that payload.</p>
/// <p><b>Only a terminal session can receive one</b>, which the vendor's own
/// <code>CanReceiveBroadcast</code> reports. A set holding an ended or ineligible pid is refused
/// whole: by <method>MergeUpdate</method> at the mint, with the published sentence; at the
/// confirm's re-read as a target that changed; and by the port at the write, for both callers, with
/// the published sentence. Nothing is ever sent to part of a set.</p>
/// <p><b>The message</b> is one <method>MessageProblem</method> for every caller: at least one
/// character other than a space, at most <parameter>MESSAGEMAX</parameter> characters, no
/// <code>\p{Cc}</code> control character and no unpaired surrogate. It is sent exactly as given,
/// and each recipient's terminal shows it framed by the vendor.</p>
/// <p>IRIS records no audit event for a broadcast (measured with auditing on), so the agent's marker
/// is its only record and a screen broadcast leaves none (AD-15, AD-53). It is not destructive.</p>
Class OcuPilot.Screen.Tool.ProcessBroadcast Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.processes.broadcast";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Propose sending a one-line message to the terminals of up to 20 processes this instance is running. It changes nothing by itself: it answers a proposal the user reviews and confirms. Only a terminal session can receive one, which the processes list reports as CanReceiveBroadcast true. A set naming any other process, or one that has ended, is refused whole and nothing is sent. The message is at most 255 characters on one line, with no control characters, and each terminal shows it once.";

/// <p>The port that reads the recipients and composes the vendor body (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.ProcessPort";

/// <p>The Processes list's Broadcast, whose one value is <parameter>MESSAGEFIELD</parameter>.</p>
Parameter SCREENACTIONS = "broadcast";

Parameter SCREENVALUES = "broadcast=Message";

/// <p>The fresh read: the set's recipients, answered by the port with the message empty.</p>
Parameter READTYPE = "RECIPIENTS";

Parameter WRITETYPE = "BROADCAST";

/// <p>No body: the port composes it (<parameter>OcuPilot.Port.ProcessPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>What <parameter>READTYPE</parameter> answers (DW-1475).</p>
Parameter READANSWERS = "Recipients,Absent,Message";

/// <p>The read field this tool's precondition reads: the recipients, each present and able to
/// receive.</p>
Parameter PRECONDITIONFIELD = "Recipients";

Parameter FINGERPRINTSUBJECT = "Recipients,Absent,Message";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Recipients";

/// <p>The one argument this tool admits: the message.</p>
Parameter MESSAGEFIELD = "Message";

/// <p>The longest message, in characters, as the dialog's field counts them.</p>
Parameter MESSAGEMAX = 255;

/// <p>The pair the send requires: <code>%Admin_Operate:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one of the three the screen declares, so the resolved set
/// is the screen's own. Measured: <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>
/// send, and the recipients' <code>LIST</code> also needs <code>%Admin_Manage:USE</code>.</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.ProcessPort).#PROCESSENDPOINT
}

/// <p>The pid set, comma-separated.</p>
ClassMethod IdArgument() As %String
{
    Quit "Pids"
}

/// <p>The query parameter the port reads the pid set from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.ProcessPort).#IDPARAM
}

/// <p><parameter>MESSAGEFIELD</parameter> alone: the tool sends no body, so its field list is empty
/// by derivation, and the one argument it takes reaches the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#MESSAGEFIELD)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the pid set and the
/// message are checked (<class>OcuPilot.Screen.Tool.ProcessBroadcastMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ProcessBroadcastMint"
}

/// <p>The derived schema with the pid set described and <parameter>MESSAGEFIELD</parameter> added,
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The processes to send the message to, as their numeric process ids separated by commas, at most " _ ##class(OcuPilot.Port.ProcessPort).#BROADCASTMAXPIDS _ ". Name only processes this instance's own processes list reports with CanReceiveBroadcast true; a set naming any other, or one that has ended, is refused whole.", "string")
    }
    Do tProperties.%Set(..#MESSAGEFIELD, {"type": "string", "description": ("The line each terminal shows, sent exactly as given: at least one character other than a space and at most " _ ..#MESSAGEMAX _ " characters, with no tab, line break, escape or other control character.")})
    Do tSchema.%Get("required").%Push(..#MESSAGEFIELD)
    Quit tSchema
}

/// <p>The screen's own pairs (<method>OcuPilot.Screen.Gate.RequiredPairs</method>) and
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>What is wrong with <var>pValue</var> as a broadcast's message, or <code>""</code>. It holds a
/// character other than a space, is at most <parameter>MESSAGEMAX</parameter> characters, and holds
/// no <code>\p{Cc}</code> control character (C0, tab, carriage return and line feed among them, DEL,
/// C1) and no unpaired surrogate, each of which a terminal acts on or cannot show. It is never
/// trimmed.</p>
ClassMethod MessageProblem(pValue As %String) As %String
{
    If $IsObject(pValue) Quit "'" _ ..#MESSAGEFIELD _ "' is the line to send, as a string"
    If $ZStrip(pValue, "*W") = "" Quit "'" _ ..#MESSAGEFIELD _ "' holds no character other than a space, and a broadcast sends at least one"
    If $Length(pValue) > ..#MESSAGEMAX Quit "'" _ ..#MESSAGEFIELD _ "' is longer than " _ ..#MESSAGEMAX _ " characters"
    If $Locate(pValue, "\p{Cc}") Quit "'" _ ..#MESSAGEFIELD _ "' holds a control character, such as a tab, a line break or an escape, which a terminal acts on rather than shows"
    Set tIndex = 1
    While tIndex <= $Length(pValue) {
        Set tCode = $Ascii(pValue, tIndex)
        If (tCode >= 55296) && (tCode <= 56319) && ($Ascii(pValue, tIndex + 1) >= 56320) && ($Ascii(pValue, tIndex + 1) <= 57343) {
            Set tIndex = tIndex + 2
            Continue
        }
        If (tCode >= 55296) && (tCode <= 57343) Quit
        Set tIndex = tIndex + 1
    }
    If tIndex <= $Length(pValue) Quit "'" _ ..#MESSAGEFIELD _ "' holds half of a surrogate pair, which is not a character"
    Quit ""
}

/// <p>What is wrong with <var>pValue</var> as the pid set a broadcast targets, or <code>""</code>:
/// <method>OcuPilot.Port.ProcessPort.PidSetProblem</method>'s rule, the one the port refuses a write
/// by.</p>
ClassMethod PidsProblem(pValue As %String) As %String
{
    If $IsObject(pValue) Quit "'" _ ..IdArgument() _ "' names the processes as a string of process ids"
    If ##class(OcuPilot.Port.ProcessPort).PidSetProblem(pValue, .tPids) = "" Quit ""
    Quit "'" _ ..IdArgument() _ "' names 1 to " _ ##class(OcuPilot.Port.ProcessPort).#BROADCASTMAXPIDS _ " processes by their numeric process ids, separated by commas"
}

/// <p>The agent's message refused by <method>MessageProblem</method> after the fresh read, as it is
/// before the mint (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..MessageProblem(pArgs.%Get(..#MESSAGEFIELD))
    Quit $$$OK
}

/// <p>The screen's <code>broadcast</code> value as this tool's argument, refused by
/// <method>MessageProblem</method> exactly as the agent's is (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) Set tValue = pValues.%Get(..#MESSAGEFIELD)
    Set pProblem = ..MessageProblem(tValue)
    If pProblem = "" Do pArgs.%Set(..#MESSAGEFIELD, tValue, "string")
    Quit $$$OK
}

/// <p>The stored payload's <parameter>MESSAGEFIELD</parameter>, under the port's own query key, so
/// the confirm's write and the screen's carry the message the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#MESSAGEFIELD) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.ProcessPort).#MESSAGEQUERY) = pPayload.%Get(..#MESSAGEFIELD)
}

/// <p>The kernel's merge of the message over the <code>RECIPIENTS</code> read <var>pFresh</var>,
/// refused with the published sentence the port refuses the write with when a pid of the set has
/// ended or cannot receive (<method>OcuPilot.Port.ProcessPort.Receivable</method>).</p>
/// <p><b>Caller contract:</b> the mint and the confirm's fingerprint re-read call it, so the agent's
/// proposal for such a set is refused before anything is stored and a set that moved since the mint
/// refuses the confirm. A screen's Broadcast reaches the port's own 409 instead, since its route
/// merges through the kernel directly.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tRecipients = ""
    Set tAbsent = ""
    If $IsObject(pFresh) {
        Set tRecipients = pFresh.%Get("Recipients")
        Set tAbsent = pFresh.%Get("Absent")
    }
    If '$IsObject(tRecipients) || '$IsObject(tAbsent) || '##class(OcuPilot.Port.ProcessPort).Receivable(tRecipients, tAbsent) {
        Set pProblem = ##class(OcuPilot.Api.Error).#REASONPROCESSBROADCASTRECIPIENT
    }
    Quit tSC
}

/// <p>The one state row this proposal's card shows, from the fresh read <var>pFresh</var>:
/// <code>Recipients</code>, whose after-value names the count and the pids
/// (<code>3 processes: 812, 907, 1033</code>, <code>1 process: 812</code>). A read that answered no
/// recipients is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tRecipients = ""
        If $IsObject(pFresh) Set tRecipients = pFresh.%Get("Recipients")
        If '$IsObject(tRecipients) || 'tRecipients.%IsA("%Library.DynamicArray") || (tRecipients.%Size() = 0) {
            Set pProblem = "this instance did not report the processes the set names"
            Quit
        }
        Set tPids = ""
        Set tIterator = tRecipients.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRecipient) {
            Set tPids = tPids _ $Select(tPids = "": "", 1: ", ") _ tRecipient.%Get("Pid")
        }
        Set tCount = tRecipients.%Size()
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", tCount _ " " _ $Select(tCount = 1: "process", 1: "processes") _ ": " _ tPids, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
