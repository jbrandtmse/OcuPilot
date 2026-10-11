/// <p>Interoperability's queue abort (AD-6, AD-10, AD-48, AD-51, AD-53, AD-62, Story 20.23): abort the messages waiting in one
/// queue, up to <parameter>OcuPilot.Port.InteropPort.ABORTMAX</parameter>. A message a job is already working on stays, and so
/// does one enqueued after the review.</p>
/// <p><b>It aborts exactly what was reviewed</b> (AD-48's enumerated-set rule): the port's <code>QUEUE</code> read enumerates the
/// queue's entries, <code>Digest</code> stands for them in the fingerprint, and the write takes the reviewed digest through
/// <method>PortQuery</method> from the stored payload, refuses a queue whose entries moved
/// (<code>INTEROP.QUEUE.CHANGED</code>) and calls <code>Ens.Queue.AbortItem</code> once per enumerated entry.
/// <code>Ens.Queue.AbortQueue</code> is never called: it also aborts what arrived after the review. A queue that is draining
/// closes the agent's proposal target-changed.</p>
/// <p><b>It is destructive</b>: aborted messages are never delivered and cannot be restored, so its card draws the destructive
/// treatment, its row action types the queue's name, and its governance key ships disabled (AD-22).</p>
/// <p>Two callers reach it: the Queues list's row action Abort all through <class>OcuPilot.Api.ScreenAction</class>, and the
/// agent's proposal and confirmation. The Queue tab of an item does not offer it: a business process of pool size 0 shares
/// <code>Ens.Actor</code> with every other.</p>
Class OcuPilot.Screen.Tool.InteropQueueAbort Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.queues.abort";

Parameter DESCRIPTION = "Propose aborting the messages waiting in one interoperability queue. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the queue exactly as the Queues list reports it in its Name column. The messages waiting in the queue when the proposal is made, up to the first 10,000, are taken off it and marked Aborted, so none is delivered. A message that arrives later stays, and so does one a job is already working on; if the queue's messages change before the proposal is confirmed, nothing is aborted. A queue that holds no messages is refused. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropQueueList";

/// <p>The fresh read: one queue with the count and digest of the entries it holds.</p>
Parameter READTYPE = "QUEUE";

Parameter READANSWERS = "Name,Count,Active,Created,Entries,Digest,Namespace";

Parameter SCREENACTIONS = "abort";

Parameter WRITETYPE = "ABORTQUEUE";

/// <p>Declared: aborted messages are never delivered and cannot be restored.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter WRITERESOURCE = "%Ens_Queues";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "EnsPortal.ProductionConfig";

Parameter STATEMARKER = "Entries";

Parameter FINGERPRINTSUBJECT = "Entries,Digest,Namespace";

Parameter PRECONDITIONFIELD = "Entries";

/// <p>The card's row: the queue's message count, moving by the entries the abort takes.</p>
Parameter STATEFIELD = "Count";

Parameter PRECONDITIONCODES = "INTEROP.QUEUE.EMPTY,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.QUEUE.ABORT";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTQUEUES
}

/// <p>Compose the port's read (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>), then name the digest the
/// stored payload was reviewed with under <parameter>OcuPilot.Port.InteropPort.DIGESTKEY</parameter>, so the write refuses a
/// queue whose entries no longer give it. A call's arguments carry no digest.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("Digest") = "string") Set pQuery(##class(OcuPilot.Port.InteropPort).#DIGESTKEY) = pPayload.%Get("Digest")
}

/// <p>The queue's name, which the card titles it by: the fresh read's <code>Name</code>.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    Quit ""
}

/// <p>The derived schema with the queue's description replaced: the target is one queue, named as the Queues list reports.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The queue, named exactly as the Queues list reports it in its Name column. A queue the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Count</code> moving from the queue's
/// message count to what is left once the enumerated entries are aborted. A queue holding no entries is
/// <var>pProblem</var>, the sentence of <code>INTEROP.QUEUE.EMPTY</code>; a read that answered no entry count refuses too.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Entries") '= "number") || (pFresh.%GetTypeOf("Count") '= "number") {
            Set pProblem = "this instance did not report the queue's messages"
            Quit
        }
        Set tCode = ##class(OcuPilot.Port.InteropPort).RowRefusal(..#WRITETYPE, pFresh)
        If tCode '= "" {
            Set pProblem = ##class(OcuPilot.Port.InteropPort).ReasonFor(tCode)
            Quit
        }
        Set tAfter = pFresh.%Get("Count") - pFresh.%Get("Entries")
        If tAfter < 0 Set tAfter = 0
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", pFresh.%Get("Count"), "string")
        Do tRow.%Set("after", tAfter, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
