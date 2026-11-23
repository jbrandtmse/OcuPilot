/// <p>Interoperability's edit and resubmit of one suspended message (AD-6, AD-11, AD-22, AD-35, AD-51, AD-53, AD-62, Story 24.16): save an edited copy of the message's body and
/// put the message back on its target's queue with it, under its own message id, as the classic Edit and Resend page does for a suspended message. The original body stays as
/// it was. It extends the edit and resend of Story 20.31 (<class>OcuPilot.Screen.Tool.InteropMessageEditResend</class>): the same form, fields, digest and refusals, over
/// the port's <code>SuspendedMessages</code> endpoint, which reads the message as <code>notsuspended</code> when it is no longer suspended. Two callers reach it: the Suspended
/// messages list's row action Edit and resubmit, through <class>OcuPilot.Api.ScreenAction</class> after the dry run a person reviews, and the agent's proposal and
/// confirmation.</p>
/// <p><b>Destructive, key <code>false</code></b> (AD-22). The vendor audits the resubmit itself, so OcuPilot records no row of its own.</p>
Class OcuPilot.Screen.Tool.InteropSuspendedEditResubmit Extends OcuPilot.Screen.Tool.InteropMessageEditResend
{

Parameter TOOLNAME = "interop.suspendedmessages.editresubmit";

Parameter DESCRIPTION = "Propose resubmitting one suspended message of the interoperability message store with an edited copy of its body: the copy is saved, and the message goes back on its target's queue with it under its own message id; the original body stays as it is. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the message by the id interop.suspendedmessages.read reports in its ID column, and the fields to change in Fields, an object of path to new text value, exactly as the Test tab of a production item lists a request class's fields: a dotted path for a field inside an embedded object, and an empty text to clear a field. An HL7 v2 message has one field, content, its whole raw text with segments on separate lines. Only an HL7 v2 message and the plain fields of a message object can be edited; the body of any other kind, a field named like a credential, and an edit that changes nothing are refused. The production must be running, and the message must still be suspended and be one that can be resubmitted. A resubmit cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropSuspendedMessageList";

/// <p>The fresh read: one message, its form and the supplied fields, composed for the action.</p>
Parameter READTYPE = "EDITSUBMIT";

Parameter WRITETYPE = "EDITRESUBMIT";

Parameter SCREENACTIONS = "editresubmit";

/// <p>The dialog sends the fields it changed as JSON object text, and a confirm the digest it was reviewed at (AD-56 (ii)); the dry run that reads the form carries neither.</p>
Parameter SCREENVALUES = "editresubmit=fields:Reviewed";

Parameter SCREENOPTIONAL = "editresubmit=fields:Reviewed";

/// <p>The classic Suspended Messages page, and the Edit and Resend page that opens from it (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.SuspendedMsg,EnsPortal.MessageResendEdit";

Parameter CONSEQUENCECODE = "INTEROP.SUSPENDED.EDIT";

/// <p>A resubmit keeps the header, which the Suspended messages list reads again.</p>
Parameter CHANGEACTION = "updated";

Parameter OUTCOMEKIND = "edit";

Parameter OKVERDICT = "resubmit";

Parameter NONECODE = "INTEROP.SUSPENDED.NONE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTSUSPENDEDMESSAGES
}

/// <p>The derived schema of the edit and resend, with the message described as a suspended one.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The suspended message to edit and resubmit, as the id interop.suspendedmessages.read reports in its ID column. A message that is no longer suspended, or cannot be resubmitted, is refused.", "string")
    }
    Quit tSchema
}

}
