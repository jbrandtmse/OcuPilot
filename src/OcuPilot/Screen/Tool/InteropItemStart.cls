/// <p>Interoperability's item start (AD-6, AD-51, AD-53, AD-62, Story 20.25): start the jobs of an item stopped with Stop. The
/// production is then updated, which also applies any other change waiting for it. An update the production does not finish
/// within <parameter>OcuPilot.Port.InteropPort.STOPSECONDS</parameter> seconds leaves the stop cleared, and the item starts at the
/// production's next update. It is not destructive, and the key ships enabled (AD-22).</p>
/// <p>Two callers reach it: the Production items row action Start through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropItemRunAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemStart Extends OcuPilot.Screen.Tool.InteropItemRunAction
{

Parameter TOOLNAME = "interop.items.start";

Parameter DESCRIPTION = "Propose starting the jobs of one item of the running production of the namespace the user is working in that was stopped with Stop. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. Confirming updates the production now, which also applies any other change waiting for it. An item that was not stopped with Stop, a disabled item, a production that is not running, and a name the production holds more than once are refused.";

Parameter SCREENACTIONS = "start";

Parameter WRITETYPE = "STARTITEM";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.NOTENABLED,INTEROP.ITEM.NOTTEMPSTOPPED,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.START";

}
