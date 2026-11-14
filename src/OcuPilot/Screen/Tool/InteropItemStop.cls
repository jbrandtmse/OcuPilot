/// <p>Interoperability's item stop (AD-6, AD-51, AD-53, AD-62, Story 20.25): stop one enabled item of the running production, so
/// its jobs end until it is started again. The production is then updated, which also applies any other change waiting for it; an
/// update the production does not finish within <parameter>OcuPilot.Port.InteropPort.STOPSECONDS</parameter> seconds is refused and
/// nothing is changed. It is not destructive: Start undoes it, and the key ships enabled (AD-22).</p>
/// <p>Two callers reach it: the Production items row action Stop through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropItemRunAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemStop Extends OcuPilot.Screen.Tool.InteropItemRunAction
{

Parameter TOOLNAME = "interop.items.stop";

Parameter DESCRIPTION = "Propose stopping one enabled item of the running production of the namespace the user is working in, so its jobs end until it is started again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. Confirming updates the production now, which also applies any other change waiting for it. The item stays enabled, messages sent to it wait in its queue, and the stop ends when the production next restarts. If the item's jobs do not finish their current messages within 15 seconds, or sooner when the production's update timeout is shorter, nothing is changed. A production that is not running, a disabled item, an item that is already stopped, an item that runs no jobs of its own, and a name the production holds more than once are refused.";

Parameter SCREENACTIONS = "stop";

Parameter WRITETYPE = "STOPITEM";

Parameter AFTERSTOPPED As BOOLEAN = 1;

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.NOTENABLED,INTEROP.ITEM.TEMPSTOPPED,INTEROP.ITEM.NOJOBS,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.STOP";

}
