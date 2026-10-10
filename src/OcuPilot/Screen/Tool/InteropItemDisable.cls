/// <p>Interoperability's item disable (AD-6, AD-51, AD-53, AD-62, Story 20.3): disable one enabled item of a
/// production. It changes the stored configuration and the production class only; a running production reads
/// update pending until Productions' confirmed Update stops the item's jobs. A business process that runs in
/// the shared actor pool, and an item a system default decides, are refused.</p>
/// <p>Two callers reach it: the Production items row action Disable through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint
/// and refusals are <class>OcuPilot.Screen.Tool.InteropItemAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemDisable Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.items.disable";

Parameter DESCRIPTION = "Propose disabling one enabled item of a production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. The change is stored in the production's configuration; a running production stops the item only when it is next updated. An item that is already disabled, a business process that runs in the shared actor pool, an item a system default setting decides, a name the production holds more than once, and a namespace under source control are refused.";

Parameter SCREENACTIONS = "disable";

Parameter WRITETYPE = "DISABLE";

Parameter FINGERPRINTSUBJECT = "Enabled,EnabledSource,Namespace";

Parameter PRECONDITIONFIELD = "Enabled";

Parameter STATEFIELD = "Enabled";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.DISABLED,INTEROP.ITEM.DEFAULTSETTING,INTEROP.ITEM.POOLZERO,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

}
