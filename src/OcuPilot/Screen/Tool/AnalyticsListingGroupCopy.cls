/// <p>Analytics' listing group copy (AD-6, AD-10, AD-51, AD-53, AD-54, AD-61, AD-65, Story 24.11): the classic Listing Group Manager's Save As, as a new group under a new name
/// and in a new class, with the source's listings, and optionally other target cubes. Two callers reach it: the Listing groups row action Copy, whose values are the new
/// name, the new class and the optional cubes, and the agent's proposal and confirmation.</p>
/// <p><b>It only creates, and it compiles.</b> A name or class in use is refused <code>ANALYTICS.LISTINGGROUP.TAKEN</code> before anything is saved, and so is a copy whose
/// listings a target cube or another group already defines (<code>ANALYTICS.LISTINGGROUP.LISTINGTAKEN</code>), which is every copy of an enabled group into its own cubes. The
/// source is only read.</p>
/// <p><b>The reviewed state</b> is the source's version and listing count and the new name, class and cubes: the fresh read composes them (<code>COPYTARGET</code>), and the
/// fingerprint holds them.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingGroupCopy Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction
{

Parameter TOOLNAME = "analytics.listinggroups.copy";

Parameter DESCRIPTION = "Propose copying one listing group to a new listing group in the namespace the user is working in: the new group takes the source's caption, description, resources and every listing, and the source is not changed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the source as the Listing groups list reports it, and give the new group's name in `NewName`, the new class in `NewClass` and, to copy into other cubes, `NewCubes`. The new class is saved and compiled. A name or class the namespace already holds, a class name that is malformed or begins with % or OcuPilot, a target cube that does not exist, and listings that a target cube or another group already defines (which includes the source's own cubes while the source is enabled) are refused.";

/// <p>The fresh read: the source, with the new name, class and cubes, composed from the call's own values.</p>
Parameter READTYPE = "COPYTARGET";

Parameter READANSWERS = "Name,Version,Listings,NewName,NewClass,NewCubes,Present,Namespace";

Parameter SCREENACTIONS = "copy";

Parameter SCREENVALUES = "copy=NewName:NewClass:NewCubes";

Parameter SCREENOPTIONAL = "copy=NewCubes";

Parameter WRITETYPE = "COPY";

/// <p>The copy creates a group, so the change event is a creation.</p>
Parameter CHANGEACTION = "created";

/// <p>The source as reviewed and the new name, class and cubes.</p>
Parameter FINGERPRINTSUBJECT = "Name,Version,Listings,NewName,NewClass,NewCubes,Present,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.TAKEN,ANALYTICS.LISTINGGROUP.LISTINGTAKEN,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

/// <p>The new group's name, class and cubes: the arguments beyond the source, reaching the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("NewName", "NewClass", "NewCubes")
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The listing group to copy, named as this namespace's Listing groups list reports it in its Name column. A group the namespace does not hold is refused.", "string")
    }
    Do tProperties.%Set("NewName", {"type": "string", "description": "The new listing group's name: 1 to 250 characters with no control character. A name the namespace already holds is refused, compared without regard to case."})
    Do tProperties.%Set("NewClass", {"type": "string", "description": "The new class that holds the copy: dotted letters and digits with a package, beginning with neither % nor OcuPilot. A class the namespace already holds is refused."})
    Do tProperties.%Set("NewCubes", {"type": "string", "description": "Optional. The cubes the copy adds listings to, comma-separated. Omit it to keep the source's cubes, which is refused while the source is enabled."})
    Do tSchema.%Get("required").%Push("NewName")
    Do tSchema.%Get("required").%Push("NewClass")
    Quit tSchema
}

/// <p>The screen's values as this tool's arguments.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tName = "NewName", "NewClass", "NewCubes" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Quit $$$OK
}

/// <p>The new name, class and cubes the arguments carry, as the port's query members.</p>
ClassMethod ExtraQuery(pArgs As %DynamicObject, ByRef pQuery)
{
    If pArgs.%GetTypeOf("NewName") = "string" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWNAMEKEY) = pArgs.%Get("NewName")
    If pArgs.%GetTypeOf("NewClass") = "string" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWCLASSKEY) = pArgs.%Get("NewClass")
    If pArgs.%GetTypeOf("NewCubes") = "string" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#TARGETCUBESKEY) = pArgs.%Get("NewCubes")
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then the new name, class and cubes the payload holds, so the
/// mint, the confirm's re-read and its write all read one state (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Do ..ExtraQuery(pPayload, .pQuery)
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>NewName</code>, <code>NewClass</code> and <code>Listings</code> (the listings the copy holds).</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Listings") '= "number") || (pFresh.%GetTypeOf("NewName") '= "string") {
            Set pProblem = "this instance did not report the source's listings, and a source whose state is unknown is not one to copy"
            Quit
        }
        For tField = "NewName", "NewClass", "Listings" {
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", $Select(tField = "Listings": 0, 1: ""), "string")
            Do tRow.%Set("after", pFresh.%Get(tField), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The name of the group the confirmed copy <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
