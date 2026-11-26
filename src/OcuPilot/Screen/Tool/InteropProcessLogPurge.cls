/// <p>Interoperability's purge of the business process log (AD-6, AD-7, AD-10, AD-48, AD-51, AD-53, AD-62, Story 24.17 Batch 2): delete the namespace's completed business process records
/// older than the days to keep, as the classic Business Process Instances page's Purge does (<code>Ens.Purge.PurgeBusinessProcessesByDate</code> with integrity kept), in the confirming or
/// acting request. A business process still running is kept.</p>
/// <p><b>It is destructive</b>: deleted records cannot be restored, so its card draws the destructive treatment, its governance key ships disabled (AD-22) and the screen's Purge types
/// the namespace's name. Its one declared value is <code>DaysToKeep</code>, a whole number from 0 to 99999, judged before any vendor call.</p>
/// <p><b>It purges what was reviewed</b>: the fingerprint covers the days and the namespace. The count of records is shown in the review and is not fingerprinted, because the log grows
/// all the time.</p>
/// <p>Two callers reach it: the Business process log screen's action Purge through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.InteropProcessLogPurge Extends OcuPilot.Screen.Tool.InteropRuleLogPurge
{

Parameter TOOLNAME = "interop.processlog.purge";

Parameter DESCRIPTION = "Propose purging the business process log of the namespace the user is working in: the completed business process records older than the days to keep. A business process still running is kept. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give DaysToKeep as a whole number from 0 to 99999, as text. With 0, every completed record up to the end of today is deleted. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropProcessLogList";

Parameter READTYPE = "PROCESSLOGSTATE";

Parameter WRITETYPE = "PURGEPROCESSLOG";

Parameter CLASSICPAGES = "EnsPortal.BPInstances";

Parameter CONSEQUENCECODE = "INTEROP.PROCESSLOG.PURGE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTPROCESSLOG
}

}
