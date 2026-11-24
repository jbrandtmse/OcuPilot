/// <p>Interoperability's managed alert update (AD-6, AD-10, AD-22, AD-51, AD-53, AD-56, AD-58, AD-62, Story 24.17 Batch 1): assign a managed alert to a user or leave it unassigned, close or reopen it,
/// move its escalation level one step, and set when its next action is due, each saved in the alert's history with the caller's username and the reason given, as the classic Alerts page's
/// Update does. Two callers reach it: the Managed alerts screen's row action Update, after the dry run a person reviews, and the agent's proposal and confirmation.</p>
/// <p><b>It is not destructive and its key ships on</b> (AD-22): every change is in the alert's history and can be changed back. The vendor records nothing but that history, so OcuPilot records its own
/// <code>ConfigChange</code> from either caller (<method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method>), never the reason.</p>
/// <p><b>Its values travel in the port's query</b> (<method>PortQuery</method>), each optional but <code>Reason</code>: an absent one means unchanged. The fresh read answers each value's own
/// current state under the value's name (<code>Owner</code>, <code>Open</code>, <code>EscalationLevel</code>), so a merge that sets a value to what the alert holds leaves it unchanged, and the
/// two it cannot answer, <code>NextActionMinutes</code> and <code>Reason</code>, empty. The port judges every value again at the write, in the proposal's namespace.</p>
/// <p><b>It updates what was reviewed</b>: the fingerprint covers the alert's owner, open state, level, next action time and number of history rows, so any update after the review closes the
/// proposal as moved.</p>
Class OcuPilot.Screen.Tool.InteropManagedAlertUpdate Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.managedalerts.update";

Parameter DESCRIPTION = "Propose updating one managed alert of the namespace the user is working in: assign it to a user (Owner, empty for unassigned), close or reopen it (Open), move its escalation level one step up or down (EscalationLevel, never below 0), or set when its next action is due (NextActionMinutes, a whole number of minutes from now, 1 to 20160). Name the alert by the ID interop.managedalerts.read reports. Reason is required, 1 to 500 characters with no control characters, and is saved in the alert's history beside the user's name. Send only the values to change; one that is left out stays as it is, and an update that would change nothing is refused. Owner must be empty, the user, or a user interop.managedalerts.read's screen offers as one who can work on managed alerts in this namespace; updating an alert another user owns also needs the right to administer alerts. It changes nothing by itself: it answers a proposal the user reviews and confirms. The alert's history shows every change, and a closed alert can be opened again.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropManagedAlertList";

/// <p>The fresh read: the alert's state and, for each value, what it holds now.</p>
Parameter READTYPE = "ALERT";

Parameter READANSWERS = "ID,CurrentOwner,IsOpen,EscalationLevel,NextActionTime,ActionCount,Namespace,Owner,Open,NextActionMinutes,Reason";

Parameter SCREENACTIONS = "update";

/// <p>The dialog sends each value it changes, and the reason. Every one is optional on the route: the dry run that opens the dialog carries none, and the write judges the reason.</p>
Parameter SCREENVALUES = "update=Owner:Open:EscalationLevel:NextActionMinutes:Reason";

Parameter SCREENOPTIONAL = "update=Owner:Open:EscalationLevel:NextActionMinutes:Reason";

/// <p>An empty owner is the request: the alert is unassigned.</p>
Parameter SCREENEMPTY = "update=Owner";

Parameter WRITETYPE = "UPDATEALERT";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter WRITERESOURCE = "%Ens_Alerts";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic Alerts page's resource, which the Update the screen replaces is gated by.</p>
Parameter CLASSICPAGES = "EnsPortal.ManagedAlerts";

/// <p>A call's arguments carry no <code>ActionCount</code>; a stored payload does, because the reviewed fresh read did.</p>
Parameter STATEMARKER = "ActionCount";

Parameter FINGERPRINTSUBJECT = "CurrentOwner,IsOpen,EscalationLevel,NextActionTime,ActionCount,Namespace,Owner,Open,NextActionMinutes,Reason";

Parameter PRECONDITIONFIELD = "ActionCount";

Parameter PRECONDITIONCODES = "INTEROP.ALERT.NOTFOUND,INTEROP.ALERT.UNCHANGED,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.ALERT.UPDATE";

/// <p>The read-back compares what the update set with what the alert holds afterward. The next action time is set from the clock at the write, so it is not compared.</p>
Parameter READBACKFIELDS = "Owner,Open,EscalationLevel";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p>The person's Update is reviewed first (<method>DryRunReview</method>): the dialog shows the alert's owner, state and level and the owners it may be given to.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The review: the alert's owner, open state and level from the fresh read <var>pFresh</var>, and the owners the classic form offers for its namespace, read through the port as the caller.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    If '$IsObject(pFresh) Quit tReview
    Do tReview.%Set("CurrentOwner", pFresh.%Get("CurrentOwner"), "string")
    Do tReview.%Set("IsOpen", ''pFresh.%Get("IsOpen"), "boolean")
    Do tReview.%Set("EscalationLevel", +pFresh.%Get("EscalationLevel"), "number")
    Do tReview.%Set("Owners", [])
    Try {
        Kill tQuery
        Set tQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pFresh.%Get("Namespace")
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ##class(OcuPilot.Port.InteropPort).#TYPEALERTOWNERS, .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISOK(tSC) && $IsObject($Get(tRows)) {
            Set tOwners = []
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Do tOwners.%Push(tRow.%Get("Name"), "string")
            }
            Do tReview.%Set("Owners", tOwners)
        }
    } Catch {
        Do tReview.%Set("Owners", [])
    }
    Quit tReview
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTMANAGEDALERTS
}

/// <p>The target is the alert, named by its ID.</p>
ClassMethod IdArgument() As %String
{
    Quit "ID"
}

/// <p>The five values an update may carry.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("Owner", "Open", "EscalationLevel", "NextActionMinutes", "Reason")
}

/// <p>The target's name, which the card titles it by: none, so the card reads the alert's ID.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    Quit ""
}

/// <p>Compose the port's read as <class>OcuPilot.Screen.Tool.InteropAction</class> does, then name each value the payload or the arguments carry under the port's own query keys, so the
/// read, the write and the draft judge and use one set of values. A value that is left out is left out of the query, which the port reads as unchanged.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.InteropPort"
    If pPayload.%GetTypeOf("Owner") = "string" Set pQuery($Parameter(tPort, "ALERTOWNERKEY")) = pPayload.%Get("Owner")
    Set tType = pPayload.%GetTypeOf("Open")
    If tType = "boolean" {
        Set pQuery($Parameter(tPort, "ALERTOPENKEY")) = ''pPayload.%Get("Open")
    } ElseIf (tType = "string") && (pPayload.%Get("Open") '= "") {
        Set tOpen = pPayload.%Get("Open")
        Set pQuery($Parameter(tPort, "ALERTOPENKEY")) = $Select(tOpen = "true": 1, tOpen = "false": 0, 1: tOpen)
    }
    Set tType = pPayload.%GetTypeOf("EscalationLevel")
    If (tType = "number") || ((tType = "string") && (pPayload.%Get("EscalationLevel") '= "")) Set pQuery($Parameter(tPort, "ALERTLEVELKEY")) = pPayload.%Get("EscalationLevel")
    Set tType = pPayload.%GetTypeOf("NextActionMinutes")
    If ((tType = "number") || (tType = "string")) && (pPayload.%Get("NextActionMinutes") '= "") Set pQuery($Parameter(tPort, "ALERTMINUTESKEY")) = pPayload.%Get("NextActionMinutes")
    If (pPayload.%GetTypeOf("Reason") = "string") && (pPayload.%Get("Reason") '= "") Set pQuery($Parameter(tPort, "ALERTREASONKEY")) = pPayload.%Get("Reason")
}

/// <p>The derived schema with the target described as the alert's ID and the five values added, <code>Reason</code> required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The managed alert to update, by the ID interop.managedalerts.read reports, a whole number sent as text.", "string")
    }
    Do tProperties.%Set("Owner", {"type": "string", "maxLength": 256, "description": "The user the alert is assigned to: empty for unassigned, the user, or a user who can work on managed alerts in this namespace. Leave it out to keep the owner."})
    Do tProperties.%Set("Open", {"type": "boolean", "description": "False to close the alert, true to open it again. Leave it out to keep it as it is."})
    Do tProperties.%Set("EscalationLevel", {"type": "integer", "minimum": 0, "description": "The alert's escalation level after the update: one more or one less than it holds now, and never below 0. Leave it out to keep the level."})
    Do tProperties.%Set("NextActionMinutes", {"type": "integer", "minimum": 1, "maximum": 20160, "description": "How many minutes from now the alert's next action is due, a whole number from 1 to 20160. Leave it out to keep the time."})
    Do tProperties.%Set("Reason", {"type": "string", "maxLength": 500,"description": "Why the alert is being updated, 1 to 500 characters with no control characters. It is saved in the alert's history."})
    Do tSchema.%Get("required").%Push("Reason")
    Quit tSchema
}

/// <p>No state row: the merge's rows, one for each value changed, are the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>What is wrong with the agent's arguments by the port's own shape rules, as the sentence of the matching code, or <code>""</code>: the alert's ID, an owner, a level, the minutes and the
/// reason. The port judges each again, against the alert, at the write.</p>
ClassMethod ValueProblem(pIdValue As %String, pArgs As %DynamicObject) As %String
{
    Set tPort = "OcuPilot.Port.InteropPort"
    If '$ClassMethod(tPort, "AlertIdOK", pIdValue) Quit $ClassMethod(tPort, "AlertProblem", "id")
    If '$IsObject(pArgs) Quit ""
    If (pArgs.%GetTypeOf("Owner") = "string") && '$ClassMethod(tPort, "AlertOwnerShapeOK", pArgs.%Get("Owner")) Quit $ClassMethod(tPort, "AlertProblem", "owner")
    If (pArgs.%GetTypeOf("EscalationLevel") '= "unassigned") && '$ClassMethod(tPort, "AlertLevelShapeOK", pArgs.%Get("EscalationLevel")) Quit $ClassMethod(tPort, "AlertProblem", "level")
    If (pArgs.%GetTypeOf("NextActionMinutes") '= "unassigned") && '$ClassMethod(tPort, "AlertMinutesOK", pArgs.%Get("NextActionMinutes")) Quit $ClassMethod(tPort, "AlertProblem", "minutes")
    If '$ClassMethod(tPort, "AlertReasonOK", $Select(pArgs.%GetTypeOf("Reason") = "string": pArgs.%Get("Reason"), 1: "")) Quit $ClassMethod(tPort, "AlertProblem", "reason")
    Quit ""
}

/// <p>The agent's arguments refused before anything is stored (AD-55): <method>ValueProblem</method>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..ValueProblem(pIdValue, pArgs)
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): the owner as sent (empty for unassigned), the open state as a boolean, the level and the minutes as numbers and the reason
/// as text, each only when the person sent it. A value that fails the port's shape rule is <var>pProblem</var>, the sentence of its code, so the screen refuses it as the mint does. The
/// dry run that opens the dialog carries none, and the write judges that a reason was given.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    Set tPort = "OcuPilot.Port.InteropPort"
    If pValues.%GetTypeOf("Owner") = "string" {
        If '$ClassMethod(tPort, "AlertOwnerShapeOK", pValues.%Get("Owner")) {
            Set pProblem = $ClassMethod(tPort, "AlertProblem", "owner")
            Quit $$$OK
        }
        Do pArgs.%Set("Owner", pValues.%Get("Owner"), "string")
    }
    If pValues.%GetTypeOf("Open") = "string" {
        Set tOpen = pValues.%Get("Open")
        If (tOpen '= 0) && (tOpen '= 1) {
            Set pProblem = "'Open' must be 0 or 1"
            Quit $$$OK
        }
        Do pArgs.%Set("Open", +tOpen, "boolean")
    }
    If pValues.%GetTypeOf("EscalationLevel") = "string" {
        If '$ClassMethod(tPort, "AlertLevelShapeOK", pValues.%Get("EscalationLevel")) {
            Set pProblem = $ClassMethod(tPort, "AlertProblem", "level")
            Quit $$$OK
        }
        Do pArgs.%Set("EscalationLevel", +pValues.%Get("EscalationLevel"), "number")
    }
    If pValues.%GetTypeOf("NextActionMinutes") = "string" {
        If '$ClassMethod(tPort, "AlertMinutesOK", pValues.%Get("NextActionMinutes")) {
            Set pProblem = $ClassMethod(tPort, "AlertProblem", "minutes")
            Quit $$$OK
        }
        Do pArgs.%Set("NextActionMinutes", +pValues.%Get("NextActionMinutes"), "number")
    }
    If pValues.%GetTypeOf("Reason") = "string" {
        If '$ClassMethod(tPort, "AlertReasonOK", pValues.%Get("Reason")) {
            Set pProblem = $ClassMethod(tPort, "AlertProblem", "reason")
            Quit $$$OK
        }
        Do pArgs.%Set("Reason", pValues.%Get("Reason"), "string")
    }
    Quit $$$OK
}

}
