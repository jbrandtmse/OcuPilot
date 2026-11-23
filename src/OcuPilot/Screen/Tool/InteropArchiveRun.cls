/// <p>Interoperability's local archive run (AD-6, AD-7, AD-10, AD-48, AD-51, AD-53, AD-62, Story 24.16 Batch 4): move every message of the namespace older than the stored days
/// before archiving to the namespace stored as Archive to namespace, as the classic Archive Manager page's Run archive does. The port holds the vendor's lock for the whole of
/// <code>Ens.Archive.Manager.DoArchive</code>, runs it in the confirming or acting request, and reads the target and the days at that moment.</p>
/// <p><b>It is destructive</b>: an archived message cannot be restored to its namespace, so its card draws the destructive treatment, its governance key ships disabled (AD-22)
/// and the screen's Run archive types the namespace's name. It declares no value: the days and the target are the settings stored in the namespace.</p>
/// <p><b>It runs what was reviewed</b>: the fingerprint covers the target, the days, the class, the namespace and whether a run is running, so a setting changed after the review
/// closes the agent's proposal as moved, and a run already running refuses it (<code>INTEROP.ARCHIVE.RUNNING</code>).</p>
/// <p>Two callers reach it: the Archive manager screen's action Run archive through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. It extends
/// <class>OcuPilot.Screen.Tool.InteropAction</class> as <class>OcuPilot.Screen.Tool.InteropPurgeRun</class> does; the purge overrides most of what it would share, since it carries a
/// declared value and a bitmap consequence this run has neither of.</p>
Class OcuPilot.Screen.Tool.InteropArchiveRun Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.archive.run";

Parameter DESCRIPTION = "Propose archiving the messages of the namespace the user is working in: every message older than the days stored as Number of days before archiving, whatever its status, is saved in the namespace stored as Archive to namespace under its own message id, with its body as text, and then deleted here. It changes nothing by itself: it answers a proposal the user reviews and confirms. It takes no value: the days and the target are the settings stored in the namespace, which the Archive settings list shows and the Archive settings tool changes. A run already running, a namespace with no other interoperability namespace to archive to, a namespace that archives with its own archive manager class, a namespace holding too many messages for one run, and a target that already holds a message with the id of one to be moved are refused. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropArchiveList";

/// <p>The fresh read: the settings the run will use, whether one is running, and how many messages the namespace holds and a run would move.</p>
Parameter READTYPE = "ARCHIVESTATE";

Parameter READANSWERS = "Target,Classname,DaysToArchive,Running,Total,ToArchive,Namespace";

Parameter SCREENACTIONS = "archive";

Parameter WRITETYPE = "ARCHIVE";

/// <p>Declared: archived messages cannot be restored to their namespace.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter WRITERESOURCE = "%Ens_ArchiveManager";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "EnsPortal.ArchiveManager";

/// <p>A call's arguments carry no <code>Running</code>; a stored payload does, because the reviewed fresh read did.</p>
Parameter STATEMARKER = "Running";

Parameter FINGERPRINTSUBJECT = "Target,DaysToArchive,Classname,Namespace,Running";

Parameter PRECONDITIONFIELD = "Running";

Parameter PRECONDITIONCODES = "INTEROP.ARCHIVE.RUNNING,INTEROP.ARCHIVE.NOTARGET,INTEROP.ARCHIVE.CLASS,INTEROP.ARCHIVE.TOOMANY,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.ARCHIVE.RUN";

/// <p>The person's Run archive is reviewed first (<method>DryRunReview</method>): the dialog shows the target, the days, the class and how many messages the run would move.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>What the run will use and move, from the fresh read <var>pFresh</var>, as the review's own record.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    If '$IsObject(pFresh) Quit tReview
    For tName = "Target", "Classname" {
        Do tReview.%Set(tName, pFresh.%Get(tName), "string")
    }
    For tName = "DaysToArchive", "ToArchive", "Total" {
        Do tReview.%Set(tName, +pFresh.%Get(tName), "number")
    }
    Quit tReview
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTARCHIVE
}

/// <p>None: the run declares no value.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The target's name, which the card titles it by: the namespace the fresh read names.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Namespace") = "string") Quit pFresh.%Get("Namespace")
    Quit ""
}

/// <p>The derived schema with the target described as the namespace.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace to archive, which is the namespace the user is working in. Send its name.", "string")
    }
    Quit tSchema
}

/// <p>No state row: the card's rows are the review's own.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The agent's arguments refused before anything is stored (AD-55): a target that is not the namespace the request is scoped to, which the read acts in.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set tScope = ##class(OcuPilot.Kernel.Scope).Current()
    If $ZConvert(pIdValue, "U") '= $ZConvert(tScope, "U") Set pProblem = "'" _ ..IdArgument() _ "' must be " _ tScope _ ", the namespace the user is working in"
    Quit $$$OK
}

/// <p>The screen's Run archive carries no value: the arguments are the namespace alone.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Quit $$$OK
}

}
