/// <p>Interoperability's item restart (AD-6, AD-51, AD-53, AD-62, Story 20.25): stop one enabled item of the running production
/// and start it again, updating the production after each half, as the classic Production Configuration page does; each update
/// also applies any other change waiting for the production. A stop the production does not finish within
/// <parameter>OcuPilot.Port.InteropPort.STOPSECONDS</parameter> seconds is refused and nothing is changed; a start that does not
/// finish leaves the stop cleared, and the item starts at the production's next update. It is not destructive, and the key ships
/// enabled (AD-22).</p>
/// <p>Two callers reach it: the Production items row action Restart through <class>OcuPilot.Api.ScreenAction</class> and the
/// agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropItemRunAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropItemRestart Extends OcuPilot.Screen.Tool.InteropItemRunAction
{

Parameter TOOLNAME = "interop.items.restart";

Parameter DESCRIPTION = "Propose restarting one enabled item of the running production of the namespace the user is working in: its jobs are stopped and started again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it. Confirming updates the production twice, which also applies any other change waiting for it. If the item's jobs do not finish their current messages within 15 seconds, or sooner when the production's update timeout is shorter, nothing is changed; if the second update does not finish in that time, the jobs stay ended until the production is next updated. A production that is not running, a disabled item, an item that is stopped, an item that runs no jobs of its own, and a name the production holds more than once are refused.";

Parameter SCREENACTIONS = "restart";

Parameter WRITETYPE = "RESTARTITEM";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.NOTENABLED,INTEROP.ITEM.TEMPSTOPPED,INTEROP.ITEM.NOJOBS,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.RESTART";

}
