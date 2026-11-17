/// <p>Analytics' folder item delete (AD-6, AD-10, AD-51, AD-53, AD-65, Story 24.10): remove one folder item for every user, which is the classic Folder
/// Manager's Delete. Dashboards that show it can no longer display it, which the card says (<code>ANALYTICS.FOLDERITEM.DELETE</code>).</p>
/// <p><b>It is destructive</b>: a deleted item cannot be restored from OcuPilot, so its card draws the destructive treatment, the Folder items
/// screen's row action Delete types the item's name, and its governance key ships disabled (AD-22). The fingerprint covers the item's name, type, owner,
/// stamp and lock, so an item changed after the mint closes the proposal target-changed. A locked item and an item that is not there are refused before the
/// vendor call. Its read-back reads the item gone on the port's 404. Two callers reach it: that row action through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsFolderItemDelete Extends OcuPilot.Screen.Tool.AnalyticsFolderItemAction
{

Parameter TOOLNAME = "analytics.folderitems.delete";

Parameter DESCRIPTION = "Propose deleting one folder item (a pivot, dashboard or other item of the Folder items list) of the namespace the user is working in, for every user, which cannot be restored from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the item by its full name exactly as the Folder items list reports it in its Name column, folder and extension included. Dashboards that show the item can no longer display it. An item the namespace does not hold or does not show the user, a locked item, and a database that is read-only or not journaled are refused. If the item changes before the proposal is confirmed, nothing is deleted.";

Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter FINGERPRINTSUBJECT = "Name,Type,Owner,Modified,Locked,Namespace";

Parameter PRECONDITIONFIELD = "Modified";

Parameter CONSEQUENCECODE = "ANALYTICS.FOLDERITEM.DELETE";

Parameter REMOVALROWS = "Name,Type,Owner";

Parameter PRECONDITIONCODES = "ANALYTICS.FOLDERITEM.ABSENT,ANALYTICS.FOLDERITEM.LOCKED,ANALYTICS.FOLDERITEM.READONLY,ANALYTICS.FOLDERITEM.NOTJOURNALED,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The folder item, named by its full name exactly as this namespace's Folder items list reports it in its Name column, folder and extension included. An item it does not report is refused.", "string")
    }
    Quit tSchema
}

}
