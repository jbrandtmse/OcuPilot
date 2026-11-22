/// <p>Interoperability's purge of management data (AD-6, AD-7, AD-10, AD-48, AD-51, AD-53, AD-62, Story 24.16): delete the namespace's event log entries, messages, completed
/// business process records, business rule log entries, I/O log entries, host monitor data and managed alerts older than the days to keep, and their message bodies when
/// Include message bodies is on, as the classic Purge Management Data page's Start Purge does. The port holds the classic page's lock for the whole of the vendor's
/// <code>Ens.Purge.PurgeAll</code>, reads the three purge settings at that moment, and runs it in the confirming or acting request (a purge that outlasts the Web Gateway's
/// response timeout runs to its end and its audit row is written then).</p>
/// <p><b>It is destructive</b>: deleted records cannot be restored, so its card draws the destructive treatment, its governance key ships disabled (AD-22) and the screen's Purge types
/// the namespace's name. Its one declared value is <code>DaysToKeep</code>, a whole number from 0 to 99999, judged before any vendor call.</p>
/// <p><b>It purges what was reviewed</b>: the fingerprint covers the three settings, the days, the namespace and whether a purge is running, so a setting changed after the review closes
/// the agent's proposal as moved, and a purge already running refuses it (<code>INTEROP.PURGE.RUNNING</code>).</p>
/// <p>Two callers reach it: the Purge management data screen's action Purge through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.InteropPurgeRun Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.purge.run";

Parameter DESCRIPTION = "Propose purging the interoperability management data of the namespace the user is working in: event log entries, messages, completed business process records, business rule log entries, I/O log entries, host monitor data and managed alerts older than the days to keep, and their message bodies when the Include message bodies setting is on. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give DaysToKeep as a whole number from 0 to 99999, as text. With 0, everything up to the end of today is deleted. The three purge settings stored in the namespace are used as they stand when the purge runs. A purge already running in the namespace is refused. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropPurgeList";

/// <p>The fresh read: the settings the purge will use and whether one is running.</p>
Parameter READTYPE = "PURGESTATE";

Parameter READANSWERS = "BodiesToo,KeepIntegrity,NamespaceBitmapMaint,Description,DaysToKeep,Running,Namespace";

Parameter SCREENACTIONS = "purge";

/// <p>The dialog sends the days to keep as this action's one value.</p>
Parameter SCREENVALUES = "purge=DaysToKeep";

Parameter WRITETYPE = "PURGE";

/// <p>Declared: deleted records cannot be restored.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter WRITERESOURCE = "%Ens_Purge";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.PurgeAll";

/// <p>A call's arguments carry no <code>Running</code>; a stored payload does, because the reviewed fresh read did.</p>
Parameter STATEMARKER = "Running";

Parameter FINGERPRINTSUBJECT = "BodiesToo,KeepIntegrity,NamespaceBitmapMaint,DaysToKeep,Namespace,Running";

Parameter PRECONDITIONFIELD = "Running";

Parameter PRECONDITIONCODES = "INTEROP.PURGE.RUNNING,INTEROP.NAMESPACE";

/// <p>The consequence a proposal carries: the purge's reach, and, when Run bitmap cleanup for namespace is stored, the bitmap cleanup's.</p>
Parameter CONSEQUENCECODE = "INTEROP.PURGE.RUN";

Parameter CONSEQUENCEBITMAPCODE = "INTEROP.PURGE.BITMAP";

/// <p>The person's Purge is reviewed first (<method>DryRunReview</method>): the dialog shows the settings the purge will use before the days are asked.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The three settings and the description the purge will use, from the fresh read <var>pFresh</var>, as the review's own record.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    If '$IsObject(pFresh) Quit tReview
    For tName = "BodiesToo", "KeepIntegrity", "NamespaceBitmapMaint" {
        Do tReview.%Set(tName, ''pFresh.%Get(tName), "boolean")
    }
    Do tReview.%Set("Description", pFresh.%Get("Description"), "string")
    Quit tReview
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTPURGE
}

/// <p>The one argument this tool admits: the days to keep.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("DaysToKeep")
}

/// <p>Compose the port's read as <class>OcuPilot.Screen.Tool.InteropAction</class> does, then name the days the payload carries under
/// <parameter>OcuPilot.Port.InteropPort.PURGEDAYSKEY</parameter>, so the write judges and uses what was reviewed. The read ignores them.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("DaysToKeep") = "string") Set pQuery(##class(OcuPilot.Port.InteropPort).#PURGEDAYSKEY) = pPayload.%Get("DaysToKeep")
}

/// <p>The target's name, which the card titles it by: the namespace the fresh read names.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Namespace") = "string") Quit pFresh.%Get("Namespace")
    Quit ""
}

/// <p>The derived schema with the target described as the namespace and <code>DaysToKeep</code> added, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace to purge, which is the namespace the user is working in. Send its name.", "string")
    }
    Do tProperties.%Set("DaysToKeep", {"type": "string", "maxLength": 5, "description": "The days of records to keep, as a whole number from 0 to 99999: records older than that many days are deleted. With 0, everything up to the end of today is deleted."})
    Do tSchema.%Get("required").%Push("DaysToKeep")
    Quit tSchema
}

/// <p>No state row: the merge's <code>DaysToKeep</code> row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The days judged by the port's own rule (<method>OcuPilot.Port.InteropPort.PurgeDaysOK</method>), as the sentence of <code>INTEROP.PURGE.DAYS</code>, or <code>""</code>.</p>
ClassMethod DaysProblem(pValue As %String) As %String
{
    If ##class(OcuPilot.Port.InteropPort).PurgeDaysOK(pValue) Quit ""
    Quit ##class(OcuPilot.Port.InteropPort).PurgeDaysReason()
}

/// <p>The agent's arguments refused before anything is stored (AD-55): a target that is not the namespace the request is scoped to, which the read acts in, then the days
/// (<method>DaysProblem</method>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set tScope = ##class(OcuPilot.Kernel.Scope).Current()
    If $ZConvert(pIdValue, "U") '= $ZConvert(tScope, "U") {
        Set pProblem = "'" _ ..IdArgument() _ "' must be " _ tScope _ ", the namespace the user is working in"
        Quit $$$OK
    }
    Set pProblem = ..DaysProblem($Select(pArgs.%GetTypeOf("DaysToKeep") = "string": pArgs.%Get("DaysToKeep"), 1: ""))
    Quit $$$OK
}

/// <p>The screen's <code>DaysToKeep</code> value as this tool's argument, judged as the agent's is (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = $Select($IsObject(pValues) && (pValues.%GetTypeOf("DaysToKeep") = "string"): pValues.%Get("DaysToKeep"), 1: "")
    Set pProblem = ..DaysProblem(tValue)
    If pProblem = "" Do pArgs.%Set("DaysToKeep", tValue, "string")
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCEBITMAPCODE</parameter> when the fresh read of the namespace the payload names says Run bitmap cleanup for namespace is on, else
/// <parameter>CONSEQUENCECODE</parameter>.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("NamespaceBitmapMaint") = "boolean") Quit $Select(pPayload.%Get("NamespaceBitmapMaint"): ..#CONSEQUENCEBITMAPCODE, 1: ..#CONSEQUENCECODE)
    Kill tQuery
    Set tQuery(..IdParam()) = $Select($IsObject(pPayload) && (pPayload.%GetTypeOf("Namespace") = "string"): pPayload.%Get("Namespace"), 1: ##class(OcuPilot.Kernel.Scope).Current())
    Do ..PortQuery(pPayload, .tQuery)
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tRow, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject($Get(tRow)) && (tRow.%GetTypeOf("NamespaceBitmapMaint") = "boolean") && tRow.%Get("NamespaceBitmapMaint") Quit ..#CONSEQUENCEBITMAPCODE
    Quit ..#CONSEQUENCECODE
}

}
