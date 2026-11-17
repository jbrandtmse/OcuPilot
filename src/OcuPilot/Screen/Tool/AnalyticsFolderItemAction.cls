/// <p>What the folder manager's three tools share (AD-6, AD-51, AD-52, AD-53, AD-65, Story 24.10): an export, import or delete of the folder items
/// of the request's namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Folder items screen's own actions and
/// the agent's proposal and confirmation. It extends <class>OcuPilot.Screen.Tool.AnalyticsAction</class>, whose pairs and port query it keeps, and
/// differs by the global it needs access to (<parameter>DESTINATIONGLOBAL</parameter>), its screen, its reads and its classic page.</p>
/// <p><b>The fresh read is the port's <code>FOLDERITEM</code></b>, composed for the action at the mint and at a screen action
/// (<method>PortQuery</method>): an item that is not there is refused by the port's own code, and a locked one is refused a delete, before any
/// vendor call. The confirm's re-read carries the reviewed state, so an item that moved closes the proposal through the fingerprint.</p>
/// <p><b>It declares</b> the screen's own pairs, access to the database <code>^DeepSee.FolderItemD</code> maps to, READ on the routines database and the
/// custom resource of the classic Folder Manager, each refused by name before any port call. The vendor checks none of them.</p>
Class OcuPilot.Screen.Tool.AnalyticsFolderItemAction Extends OcuPilot.Screen.Tool.AnalyticsAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsFolderItemList";

Parameter DESTINATIONGLOBAL = "^DeepSee.FolderItemD";

Parameter CLASSICPAGES = "%DeepSee.UI.FolderManager";

/// <p>The fresh read: one folder item.</p>
Parameter READTYPE = "FOLDERITEM";

Parameter READANSWERS = "Name,Type,Owner,Modified,Locked,Namespace";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Modified";

Parameter STATEFIELD = "";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTFOLDERITEMS
}

/// <p>The folder item's full name, which the rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The title the card gives the target: the fresh read's name, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..IdArgument()) = "string") Quit pFresh.%Get(..IdArgument())
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..IdArgument()) = "string") Quit pArgs.%Get(..IdArgument())
    Quit ""
}

/// <p>No state rows: an import's card shows what it creates, and a removal's rows come from <method>RemovalRows</method>.</p>
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

}
