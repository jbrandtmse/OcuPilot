/// <p>What the listing group editor's four group write tools share (AD-6, AD-51, AD-52, AD-53, AD-61, AD-65, Story 24.11): a write of one listing group of the request's
/// namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Listing groups screen's own actions and the agent's proposal and confirmation.
/// It extends <class>OcuPilot.Screen.Tool.AnalyticsAction</class>, whose port query it keeps, and differs by the global it needs WRITE on
/// (<parameter>DESTINATIONGLOBAL</parameter>), its screen, its reads and its classic page.</p>
/// <p><b>The fresh read is the port's <code>LISTINGGROUP</code></b>, composed for the action at the mint and at a screen action (<method>PortQuery</method>): an add reads
/// absent, and the others are refused by the port's own codes when the group is not there or two classes declare it. The row carries the class's <code>Version</code>, so
/// a class changed after the mint closes the proposal through the fingerprint.</p>
/// <p><b>It declares</b> the screen's own pairs, <code>%DeepSee_ListingGroupEdit:USE</code>, the pairs <code>AtelierPort.WritePairs</code> names for the namespace (the write saves,
/// compiles and deletes a class), WRITE on the resource guarding the database <code>^DeepSee.ListingGroups</code> maps to, READ on the routines database and the custom resource
/// of the classic Listing Group Manager, each refused by name before any port call (AD-8, AD-44). The vendor checks none of them.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingGroupAction Extends OcuPilot.Screen.Tool.AnalyticsAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsListingGroupList";

Parameter DESTINATIONGLOBAL = "^DeepSee.ListingGroups";

Parameter CLASSICPAGES = "%DeepSee.UI.ListingGroupManager";

/// <p>The fresh read: one listing group.</p>
Parameter READTYPE = "LISTINGGROUP";

Parameter READANSWERS = "Name,Class,Caption,Description,TargetCubes,Resource,DefaultResource,Disabled,Compiled,Listings,Version,Namespace";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Version";

Parameter STATEFIELD = "";

/// <p>The consequence every write states unless it declares its own: the class is saved and compiled (published once in EXPERIENCE.md's Fixed strings).</p>
Parameter CONSEQUENCECODE = "ANALYTICS.LISTINGGROUP.SAVE";

/// <p>The consequence of a listing that sets SQL, which the listing then runs with the rights of whoever opens it.</p>
Parameter SQLCONSEQUENCECODE = "ANALYTICS.LISTINGGROUP.SQL";

/// <p>The pairs the write needs beyond the screen's own and the source code API's: the classic page's edit resource, <code>""</code> for none. A method, not a parameter, so the
/// port is not needed while this class compiles.</p>
ClassMethod EditPairs() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#LISTINGGROUPEDITPAIRS
}

/// <p>The port methods <method>RuleProblem</method> calls for the shape rules and for the state's first refusal; a subclass for another definition names its own, of the same signatures.</p>
Parameter VIOLATIONSMETHOD = "ListingGroupViolations";

Parameter PROBLEMMETHOD = "ListingGroupProblem";

/// <p>The removal rows the card shows.</p>
Parameter REMOVALROWS = "";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTLISTINGGROUPS
}

/// <p>The listing group's name, which the rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The pairs <method>OcuPilot.Screen.Tool.AnalyticsAction.PrivilegePairs</method> names, then <method>EditPairs</method>, the source code API's own pairs
/// (<code>AtelierPort.Pairs</code>, which carry <code>%Development:USE</code>) and the pairs <code>AtelierPort.WritePairs</code> names for the namespace the request is scoped to, each once. <var>pResolved</var> is 0 when a database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tWrite = ##class(OcuPilot.Port.AtelierPort).WritePairs(##class(OcuPilot.Kernel.Scope).Current())
    If tWrite = "" {
        Set pResolved = 0
        Quit ""
    }
    Set tExtra = ##class(OcuPilot.Screen.Gate).ParsePairSpec(..EditPairs()) _ ##class(OcuPilot.Port.AtelierPort).Pairs() _ tWrite
    For tAt = 1:1:$ListLength(tExtra) {
        If '$ListFind(tPairs, $List(tExtra, tAt)) Set tPairs = tPairs _ $ListBuild($List(tExtra, tAt))
    }
    Quit tPairs
}

/// <p>The read always asks for the write it precedes, at the mint, at a screen action and at the confirm's re-read, so each carries the class's <code>Version</code>, which the
/// fingerprint covers (AD-52); then the namespace the payload holds, and for an add the new class, which the read refuses when it is one of OcuPilot's own (AD-10).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
    If (..#WRITETYPE = ##class(OcuPilot.Port.AnalyticsPort).#TYPEADD) && (pPayload.%GetTypeOf("Class") = "string") Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWCLASSKEY) = pPayload.%Get("Class")
}

/// <p>The title the card gives the target: the fresh read's name, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..IdArgument()) = "string") Quit pFresh.%Get(..IdArgument())
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..IdArgument()) = "string") Quit pArgs.%Get(..IdArgument())
    Quit ""
}

/// <p>No state rows: a merge's card shows what it moves, and a removal's rows come from <method>RemovalRows</method>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    If ..#REMOVALROWS = "" Quit tSC
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Namespace") '= "string") {
            Set pProblem = "this instance did not report the target, and a target whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The answer reaches the screen as the port's row: no output lines.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Quit ""
}

/// <p>The write type the port's rules judge this tool's call under.</p>
ClassMethod PortWriteType() As %String
{
    Quit ..#WRITETYPE
}

/// <p>The listing group the call acts on and the listing it names (<code>""</code> for a group tool): the id <var>pIdValue</var> split as this tool's target grammar has it.</p>
ClassMethod TargetParts(pIdValue As %String, Output pGroup As %String, Output pListing As %String)
{
    Set pGroup = pIdValue
    Set pListing = ""
}

/// <p>The rules over the call as one sentence naming each field and its published sentence, appended to <var>pProblem</var>: the port's shape rules
/// (<method>OcuPilot.Port.AnalyticsPort.ListingGroupViolations</method>), then, when <var>pChecksState</var>, the first refusal the write would meet against the instance's own
/// state (<method>OcuPilot.Port.AnalyticsPort.ListingGroupProblem</method>, nothing written).</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, ByRef pProblem As %String, pChecksState As %Boolean = 1) As %Status
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit $$$OK
    Do ..TargetParts(pIdValue, .tGroup, .tListing)
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If ..#WRITETYPE = ##class(OcuPilot.Port.AnalyticsPort).#TYPEADD Do tBody.%Set("Name", tGroup, "string")
    Set tSC = $ClassMethod(..#PORTCLASS, ..#VIOLATIONSMETHOD, ..PortWriteType(), tGroup, tListing, tBody, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    If (pProblem '= "") || 'pChecksState Quit $$$OK
    Kill tQuery
    Do ..ExtraQuery(pArgs, .tQuery)
    Set pProblem = $ClassMethod(..#PORTCLASS, ..#PROBLEMMETHOD, ..ArgumentNamespace(pArgs), ..PortWriteType(), tGroup, tListing, .tQuery, tBody)
    Quit $$$OK
}

/// <p>A copy of <var>pArgs</var> whose <code>TargetCubes</code>, when a string, is the form the port stores (<method>OcuPilot.Port.AnalyticsPort.NormalizedCubes</method>), so the
/// payload both callers send reads back as sent (AD-58).</p>
ClassMethod CubesNormalized(pArgs As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit pArgs
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tArgs.%GetTypeOf("TargetCubes") = "string" Do tArgs.%Set("TargetCubes", ##class(OcuPilot.Port.AnalyticsPort).NormalizedCubes(tArgs.%Get("TargetCubes")), "string")
    Quit tArgs
}

/// <p>The query members the port's judgement reads beyond the body: none here; a copy adds its new name, class and cubes.</p>
ClassMethod ExtraQuery(pArgs As %DynamicObject, ByRef pQuery)
{
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The rules over the call: <method>RuleProblem</method>, state included.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The text of a screen action's value as the argument it is: <var>pValues</var>' member <var>pName</var> when it is a string, set on <var>pArgs</var>.</p>
ClassMethod CarryText(pValues As %DynamicObject, pArgs As %DynamicObject, pName As %String)
{
    If $IsObject(pValues) && (pValues.%GetTypeOf(pName) = "string") Do pArgs.%Set(pName, pValues.%Get(pName), "string")
}

/// <p>The dialog's boolean value <var>pName</var>, <code>true</code> or <code>false</code>, as a boolean argument; the sentence refusing any other text, else <code>""</code>.</p>
ClassMethod CarryBoolean(pValues As %DynamicObject, pArgs As %DynamicObject, pName As %String) As %String
{
    If '$IsObject(pValues) || (pValues.%GetTypeOf(pName) '= "string") Quit ""
    If '$ListFind($ListBuild("true", "false"), pValues.%Get(pName)) Quit "'" _ pName _ "' is true or false"
    Do pArgs.%Set(pName, (pValues.%Get(pName) = "true"), "boolean")
    Quit ""
}

/// <p>The dialog's <code>Disabled</code> value as a boolean argument (<method>CarryBoolean</method>).</p>
ClassMethod CarryDisabled(pValues As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Quit ..CarryBoolean(pValues, pArgs, "Disabled")
}

}
