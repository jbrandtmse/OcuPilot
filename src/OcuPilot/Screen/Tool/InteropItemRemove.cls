/// <p>Interoperability's item remove (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.3): remove one disabled item
/// of a production, with every setting it holds. It changes the stored configuration and the production class
/// only. An enabled item is refused, so no job is affected and a running production does not read update
/// pending.</p>
/// <p><b>It is destructive</b>: a removed item and its settings cannot be restored from OcuPilot, so its card
/// draws the destructive treatment, its row action types the item's name, and its governance key ships
/// disabled (AD-22). Its read-back reads the item gone on the port's 404.</p>
/// <p>Two callers reach it: the Production items row action Remove through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint
/// and refusals are <class>OcuPilot.Screen.Tool.InteropItemAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemRemove Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.items.remove";

Parameter DESCRIPTION = "Propose removing one disabled item of a production of the namespace the user is working in, with every setting it holds, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. An item that is enabled must be disabled first, and is refused; so are a name the production holds more than once and a namespace under source control.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVE";

/// <p>Declared: a removed item and its settings cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.REMOVE";

Parameter FINGERPRINTSUBJECT = "Enabled,ClassName,Namespace";

Parameter PRECONDITIONFIELD = "Enabled";

/// <p>The removal rows the card shows: what the removed item held.</p>
Parameter REMOVALROWS = "ClassName,Enabled";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.ENABLEDREMOVE,INTEROP.ITEM.DEFAULTSETTING,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state. A read
/// that answered no <code>Enabled</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Enabled") '= "boolean") {
            Set pProblem = "this instance did not report the item's state, and an item whose state is unknown is not one to remove"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>What the schema says of the item's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The item to remove, named exactly as this production's Production items list reports it. It must be disabled. An item the list does not report is refused."
}

}
