/// <p>Interoperability's queued message abort (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.23): take one waiting message off its
/// queue and mark it Aborted, so it is never delivered; a synchronous caller waiting on it is answered with an error (vendor).
/// The queue's other messages stay.</p>
/// <p><b>The message is found through its header</b>: the target is the header's id, and the port reads the queue the header's own
/// <code>TargetQueueName</code> names, so a message to a business process of pool size 0 is found in the shared
/// <code>Ens.Actor</code> queue. The fresh read is the port's <code>ENTRY</code>; a header that is gone, or whose message no
/// longer waits, is 404.</p>
/// <p><b>It is destructive</b>: an aborted message is never delivered and cannot be restored, so its card draws the destructive
/// treatment, its row action types the message id, and its governance key ships disabled (AD-22).</p>
/// <p>Two callers reach it: the Queue messages list's and an item's Queue tab's row action Abort through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. The read-back's 404 is the after-state:
/// the entry has left the queue the read finds it in, so a read-back that cannot find it reads <code>nothingSent</code>
/// (<parameter>PRECONDITIONCODES</parameter>, AD-51).</p>
Class OcuPilot.Screen.Tool.InteropQueueMessageAbort Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.queuemessages.abort";

Parameter DESCRIPTION = "Propose aborting one message that is waiting in an interoperability queue. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the message by the id the Queue messages list or an item's Queue tab reports in its MessageId column. The message is taken off its queue and marked Aborted, so it is never delivered, and a caller waiting for its reply receives an error instead. The queue's other messages stay. A message that is no longer waiting in its queue is refused. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropQueueMessageList";

/// <p>The fresh read: one queue entry, found through its message header.</p>
Parameter READTYPE = "ENTRY";

Parameter READANSWERS = "Queue,Priority,Index,MessageId,Source,Target,BodyClass,TimeCreated,Status,Namespace";

Parameter SCREENACTIONS = "abort";

Parameter WRITETYPE = "ABORTMESSAGE";

/// <p>Declared: an aborted message is never delivered and cannot be restored.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter WRITERESOURCE = "%Ens_Queues";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic configuration page, whose Queue tab performs the same abort (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.ProductionConfig";

Parameter STATEMARKER = "Status";

Parameter FINGERPRINTSUBJECT = "Queue,Priority,Index,Namespace";

Parameter PRECONDITIONFIELD = "Index";

/// <p>The card's row: the message's status, moving from Queued to Aborted.</p>
Parameter STATEFIELD = "Status";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE,PORT.NOTFOUND";

Parameter CONSEQUENCECODE = "INTEROP.MESSAGE.ABORT";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTQUEUEITEMS
}

/// <p>The message's header id, which the Queue messages rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "MessageId"
}

/// <p>The derived schema with the message's description replaced: the target is one waiting message, named by the id the
/// Queue messages list reports.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The message, named by the id the Queue messages list or an item's Queue tab reports in its MessageId column. A message that is not waiting in its queue is refused.", "string")
    }
    Quit tSchema
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Status</code> moving from the
/// message's word to Aborted. A read that answered no status refuses, since a message nobody established is not one to
/// abort.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Status") '= "string") {
            Set pProblem = "this instance did not report the message's state"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", pFresh.%Get("Status"), "string")
        Do tRow.%Set("after", "Aborted", "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
