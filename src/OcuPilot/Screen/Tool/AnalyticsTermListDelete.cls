/// <p>Analytics' term list delete (AD-6, AD-10, AD-51, AD-53, AD-65, Story 24.2): remove one term list and every entry in it. Anything that
/// uses the list can no longer read them, which the card says (<code>ANALYTICS.TERMLIST.DELETE</code>).</p>
/// <p><b>It is destructive</b>: a deleted list cannot be restored from OcuPilot, so its card draws the destructive treatment, the Term lists
/// screen's row action Delete types the list's name, and its governance key ships disabled (AD-22). The fingerprint covers the list's
/// header and stamp, so a list changed after the mint closes the proposal target-changed. Its read-back reads the list gone on the port's
/// 404. Two callers reach it: that row action through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and
/// confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListDelete Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.delete";

Parameter DESCRIPTION = "Propose deleting one term list of the namespace the user is working in, with every entry in it, which cannot be restored from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the list exactly as the Term lists list reports it in its Name column. Anything that uses the list can no longer read its entries. A list the namespace does not hold and a database that is read-only or not journaled are refused. If the list changes before the proposal is confirmed, nothing is deleted.";

Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter FINGERPRINTSUBJECT = "Name,Caption,Fields,HideValue,Modified,Namespace";

Parameter PRECONDITIONFIELD = "Modified";

Parameter CONSEQUENCECODE = "ANALYTICS.TERMLIST.DELETE";

Parameter REMOVALROWS = "Name,Caption,Fields";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The term list, named exactly as this namespace's Term lists list reports it in its Name column. A list it does not report is refused.", "string")
    }
    Quit tSchema
}

}
