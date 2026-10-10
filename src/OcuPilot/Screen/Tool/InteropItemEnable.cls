/// <p>Interoperability's item enable (AD-6, AD-51, AD-53, AD-62, Story 20.3): enable one disabled item of a
/// production. It changes the stored configuration and the production class only; a running production reads
/// update pending until Productions' confirmed Update starts the item. An item a system default decides is
/// refused, because the vendor would change the default's row and leave the production alone.</p>
/// <p>Two callers reach it: the Production items row action Enable through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint
/// and refusals are <class>OcuPilot.Screen.Tool.InteropItemAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemEnable Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.items.enable";

Parameter DESCRIPTION = "Propose enabling one disabled item of a production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. The change is stored in the production's configuration; a running production starts the item only when it is next updated or started. An item that is already enabled, an item a system default setting decides, a name the production holds more than once, and a namespace under source control are refused.";

Parameter SCREENACTIONS = "enable";

Parameter WRITETYPE = "ENABLE";

Parameter FINGERPRINTSUBJECT = "Enabled,EnabledSource,Namespace";

Parameter PRECONDITIONFIELD = "Enabled";

Parameter STATEFIELD = "Enabled";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.ENABLED,INTEROP.ITEM.DEFAULTSETTING,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

}
