/// <p>Interoperability's message edit-and-resend (AD-6, AD-11, AD-22, AD-35, AD-51, AD-53, AD-62, Story 20.31): save an edited copy of
/// one message's body and send the message to its target again with it, as a new message in its session. The original message and
/// body stay as they were. Two callers reach it: the Header tab's row action Edit and resend, through
/// <class>OcuPilot.Api.ScreenAction</class> after the dry run a person reviews (<class>OcuPilot.Api.ScreenDryRun</class>), and the
/// agent's proposal and confirmation.</p>
/// <p><b>What it edits</b>: an HL7 v2 message as one field, <code>content</code>, its raw text, and the plain fields of any other
/// persistent message object, by the path the host test's Test tab lists (<class>OcuPilot.Port.InteropPort</class>'s
/// <code>EDIT</code> read answers them as <code>Form</code>, with each current value). Another document kind, a stream, a body
/// OcuPilot's own class names, and a body with no field a person can set are refused <code>INTEROP.EDIT.NOTEDITABLE</code>. A field
/// named like a credential is never changed (<code>INTEROP.EDIT.SECRET</code>): its value is not shown and not accepted.</p>
/// <p><b>The fresh read is the port's <code>EDIT</code></b>, composed from the message and the fields the call carries: its
/// <code>Verdict</code> (a message that cannot be resent is not edited), <code>Original</code> (a digest of the form, so a body that
/// changed after the review closes the proposal) and the supplied <code>Fields</code>, which the stored payload keeps because the port
/// query is read from it. A person's action also carries the digest it was reviewed at as <code>Reviewed</code>
/// (<class>OcuPilot.Screen.Tool.InteropMessageAction</class>).</p>
/// <p><b>It declares</b> the Messages screen's pairs, then <code>%Ens_MessageContent:USE</code>, <code>%Ens_MessageResend:USE</code>
/// and <code>%Ens_MessageEditResend:USE</code>, then WRITE on the namespace's globals database, in the order the port evaluates them
/// (AD-8, AD-62), then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropMessageEditResend Extends OcuPilot.Screen.Tool.InteropMessageAction
{

Parameter TOOLNAME = "interop.messageheader.editresend";

Parameter DESCRIPTION = "Propose resending one message of the interoperability message store to its target with an edited copy of its body, as a new message in its own session; the original message and body stay as they are. It sends nothing by itself: it answers a proposal the user reviews and confirms. Name the message by the id interop.messages.read reports in its ID column, and the fields to change in Fields, an object of path to new text value, exactly as the Test tab of a production item lists a request class's fields: a dotted path for a field inside an embedded object, and an empty text to clear a field. An HL7 v2 message has one field, content, its whole raw text with segments on separate lines. Only an HL7 v2 message and the plain fields of a message object can be edited; the body of any other kind, a field named like a credential, and an edit that changes nothing are refused. The production must be running, and the message must be one that can be resent. A resend cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropMessageHeaderTab";

/// <p>The fresh read: one message, its form and the supplied fields, composed for the action.</p>
Parameter READTYPE = "EDIT";

Parameter WRITETYPE = "EDITRESEND";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Production,Message,Type,Source,Target,BodyClass,Kind,Verdict,Form,Fields,Changed,Before,After,Original,Reviewed,Digest";

Parameter SCREENACTIONS = "editresend";

/// <p>The dialog sends the fields it changed as JSON object text, and a confirm the digest it was reviewed at (AD-56 (ii)); the
/// dry run that reads the form carries neither.</p>
Parameter SCREENVALUES = "editresend=fields:Reviewed";

Parameter SCREENOPTIONAL = "editresend=fields:Reviewed";

/// <p>The Edit and Resend page too, beside the Resend page (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.MessageResend,EnsPortal.MessageResendEdit";

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Verdict";

/// <p>The card's row: the changed fields of the body.</p>
Parameter STATEFIELD = "Body";

Parameter PRECONDITIONFIELD = "Verdict";

Parameter FINGERPRINTSUBJECT = "Verdict,Original,Namespace,Fields,Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE,INTEROP.EDIT.NOTEDITABLE";

Parameter CONSEQUENCECODE = "INTEROP.MESSAGE.EDITRESEND";

/// <p>The argument holding the fields to change, and its read answer.</p>
Parameter FIELDSARGUMENT = "Fields";

/// <p>The message, by its header id.</p>
ClassMethod IdArgument() As %String
{
    Quit "Message"
}

/// <p>The fields and the digest a person's action carries: the tool sends no body, so its field list is empty by derivation, and the
/// two arguments reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#FIELDSARGUMENT, ..#REVIEWEDARGUMENT)
}

/// <p>The screen's pairs, then the three the edit needs in the port's order, then WRITE on the globals database
/// (<method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method>), each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    Set tAt = $ListFind(tPairs, tOwn)
    If 'tAt Quit tPairs
    Set tOut = ""
    For tI = 1:1:$ListLength(tPairs) {
        If tI '= tAt {
            Set tOut = tOut _ $ListBuild($List(tPairs, tI))
            Continue
        }
        Set tOut = tOut _ $ListBuild($ListBuild("%Ens_MessageContent", "USE"), tOwn, $ListBuild("%Ens_MessageEditResend", "USE"))
    }
    Quit tOut
}

/// <p>The derived schema with the message described and the fields added and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The message to edit and resend, as the id interop.messages.read reports in its ID column. A message that cannot be resent is refused.", "string")
    }
    Do tProperties.%Set(..#FIELDSARGUMENT, {"type": "object", "description": "The fields to change: an object whose members are field paths, as the Test tab of a production item lists a request class's fields (a dotted path for a field inside an embedded object), and whose values are the new text, as a person would type it; an empty text clears the field. An HL7 v2 message takes one member, content, holding the whole message text. A field named like a credential, a path that is not a field and a value its field refuses are each refused."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#FIELDSARGUMENT)
    Quit tSchema
}

/// <p>What is wrong with the call's own arguments, as one sentence, or <code>""</code>: no digest comes with it, and
/// <code>Fields</code> is as the host test's fields are (<method>OcuPilot.Screen.Tool.InteropItemTestSend.FieldsProblem</method>) and
/// names at least one field. The port judges the rest, from the instance.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    If pArgs.%GetTypeOf(..#REVIEWEDARGUMENT) '= "unassigned" {
        Set pProblem = "'" _ ..#REVIEWEDARGUMENT _ "' is not an argument a proposal takes"
        Quit $$$OK
    }
    Set pProblem = ##class(OcuPilot.Screen.Tool.InteropItemTestSend).FieldsProblem(pArgs, ..#FIELDSARGUMENT)
    If (pProblem = "") && (pArgs.%Get(..#FIELDSARGUMENT).%Size() = 0) Set pProblem = "'" _ ..#FIELDSARGUMENT _ "' names at least one field to change"
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the
/// proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): <code>fields</code> from JSON object text to an object of text
/// values, as the host test reads them (<method>OcuPilot.Screen.Tool.InteropItemTestSend.FieldsFromText</method>), any other
/// spelling refused; and <code>Reviewed</code> as sent. A call that carries neither asks for the form.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf("fields") = "string" {
        Set pProblem = ##class(OcuPilot.Screen.Tool.InteropItemTestSend).FieldsFromText(pValues.%Get("fields"), .tFields)
        If pProblem '= "" Quit $$$OK
        Do pArgs.%Set(..#FIELDSARGUMENT, tFields)
    }
    If pValues.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Do pArgs.%Set(..#REVIEWEDARGUMENT, pValues.%Get(..#REVIEWEDARGUMENT), "string")
    Quit $$$OK
}

/// <p>The supplied fields, from the payload <var>pPayload</var> -- the call's arguments, or a stored payload, which carries the
/// fresh read's -- under the port's own query key (AD-52, <method>OcuPilot.Screen.Tool.InteropItemTestSend.FieldsQuery</method>), so
/// the mint, a screen action and the confirm's re-read each read, and the write sends, one edit. The action key and the digest are
/// <method>OcuPilot.Screen.Tool.InteropMessageAction.PortQuery</method>'s.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Do ##class(OcuPilot.Screen.Tool.InteropItemTestSend).FieldsQuery(pPayload, ..#FIELDSARGUMENT, .pQuery)
}

/// <p>What a reviewed edit answers beside its rows: the digest, the body's kind and the form the dialog is built from.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = ##super(pFresh)
    If '$IsObject(pFresh) Quit tReview
    Do tReview.%Set("Kind", pFresh.%Get("Kind"), "string")
    Do tReview.%Set("Form", $Select(pFresh.%GetTypeOf("Form") = "array": pFresh.%Get("Form"), 1: []))
    Quit tReview
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Body</code>, the changed fields before
/// and after (a document's as the changed lines). A message that cannot be resent is <var>pProblem</var>, the sentence of
/// <code>INTEROP.RESEND.NONE</code> and then its line; fields that change nothing are <var>pProblem</var>, the sentence of
/// <code>INTEROP.EDIT.NOCHANGE</code>. A read that supplied no field answers no row: it is the request for the form.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Verdict") '= "string") || (pFresh.%GetTypeOf("Changed") '= "array") {
            Set pProblem = "this instance did not report the message"
            Quit
        }
        If pFresh.%Get("Verdict") '= "resend" {
            Set tMessage = {}
            Do tMessage.%Set("ID", pFresh.%Get("Message"), "string")
            Do tMessage.%Set("Source", pFresh.%Get("Source"), "string")
            Do tMessage.%Set("Target", pFresh.%Get("Target"), "string")
            Do tMessage.%Set("Verdict", pFresh.%Get("Verdict"), "string")
            Set pProblem = ##class(OcuPilot.Port.InteropPort).Sentence("INTEROP.RESEND.NONE") _ $Char(10) _ ..MessageLine(tMessage)
            Quit
        }
        If pFresh.%Get("Fields") = "{}" Quit
        If pFresh.%Get("Changed").%Size() = 0 {
            Set pProblem = ##class(OcuPilot.Port.InteropPort).Sentence("INTEROP.EDIT.NOCHANGE")
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", pFresh.%Get("Before"), "string")
        Do tRow.%Set("after", pFresh.%Get("After"), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
