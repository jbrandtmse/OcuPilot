/// <p>The mint every Worklists tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.13): the kernel's own mint, handed the worklist option's composite id
/// <code>[Page, Panel, Class]</code> built from the agent's <code>Page</code>, <code>Panel</code> and <code>Class</code>, the id the Worklists screen's rows carry, so both callers hand
/// <class>OcuPilot.Port.AnalyticsPort</class> one target grammar. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the page and the panel as its two leading parts.</p>
Class OcuPilot.Screen.Tool.AnalyticsWorklistMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The arguments that name the page and the panel the worklist is shown in.</p>
Parameter PARTARGUMENTS = "Page,Panel";

Parameter CHILDDESCRIPTION = "the worklist class";

Parameter SEPARATORNOUNS = "page, panel or class";

/// <p>What each leading part names, as the refusal for an empty one says it.</p>
ClassMethod PartDescription(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: "the page the worklist is shown on", : "the panel of that page")
}

}
