/// <p>Interoperability's setting reset (AD-6, AD-44, AD-51, AD-53, AD-62, Story 20.22): remove the production's own
/// value of one Host or Adapter setting of an item, so the default applies again. It changes the stored configuration
/// and the production class only; a running production reads update pending until Productions' confirmed Update
/// applies it. A setting that holds no value of its own, one of the item's own properties, a value a service registry
/// entry supplies, and a default that names the manager directory or the directory OcuPilot serves its files from, are
/// refused.</p>
/// <p>Two callers reach it: the Item settings row action Reset to default through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. It is action-style (AD-51):
/// it sends no body, so its read-back says nothing was sent, and its card's one row moves <code>Value</code> from the
/// current value to the default. Its state, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.InteropSettingAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropSettingReset Extends OcuPilot.Screen.Tool.InteropSettingAction
{

Parameter TOOLNAME = "interop.itemsettings.reset";

Parameter DESCRIPTION = "Propose resetting one Host or Adapter setting of one item of a production of the namespace the user is working in to its default, by removing the production's own value. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it, the item as that production's Production items list reports it, and the setting with its group (Host or Adapter) and name as the item's Item settings list reports them. The change is stored in the production's configuration; a running production applies it only when it is next updated or started. A setting that already takes its default, one of the item's own Core properties, a setting whose name holds a credential, a value a service registry entry supplies, a default that names the manager directory or the directory OcuPilot serves its files from, a name the production holds more than once and a namespace under source control are refused.";

Parameter WRITETYPE = "RESET";

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "reset";

Parameter FINGERPRINTSUBJECT = "Value,Source,Default,Namespace";

Parameter STATEFIELD = "Source";

Parameter PRECONDITIONFIELD = "Source";

/// <p>The classic dialog where a reset to the default is chosen (AD-44, measured at Story 20.22's Task 0).</p>
Parameter CLASSICPAGES = "EnsPortal.Dialog.ProductionItemSettings";

Parameter PRECONDITIONCODES = "INTEROP.SETTING.SECRET,INTEROP.SETTING.CORE,INTEROP.SETTING.DEFAULTED,INTEROP.SETTING.SUPPLIED,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE,PATH.MANAGERDIR,PATH.SERVED,PATH.MANAGER,INTEROP.SETTING.DESCENT";

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>Value</code> moving from
/// the current value to the default. A read that answered no value or no default is <var>pProblem</var>, since a
/// setting nobody established is not one to reset.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Value") '= "string") || (pFresh.%GetTypeOf("Default") '= "string") {
            Set pProblem = "this instance did not report the setting's value and default"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", "Value", "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get("Value"), "string"), "string")
        Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get("Default"), "string"), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
