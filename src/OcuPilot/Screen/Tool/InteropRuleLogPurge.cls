/// <p>Interoperability's purge of the business rule log (AD-6, AD-7, AD-10, AD-48, AD-51, AD-53, AD-62, Story 24.17 Batch 2): delete the namespace's business rule log entries, and their
/// debug rows, older than the days to keep, as the classic Business Rule Log page's Purge does (<code>Ens.Purge.PurgeRuleLogsByDate</code>), in the confirming or acting request.</p>
/// <p><b>It is destructive</b>: deleted entries cannot be restored, so its card draws the destructive treatment, its governance key ships disabled (AD-22) and the screen's Purge types
/// the namespace's name. Its one declared value is <code>DaysToKeep</code>, a whole number from 0 to 99999, judged before any vendor call.</p>
/// <p><b>It purges what was reviewed</b>: the fingerprint covers the days and the namespace. The count of entries is shown in the review and is not fingerprinted, because the log grows
/// all the time.</p>
/// <p>Two callers reach it: the Business rule log screen's action Purge through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.InteropRuleLogPurge Extends OcuPilot.Screen.Tool.InteropPurgeRun
{

Parameter TOOLNAME = "interop.rulelog.purge";

Parameter DESCRIPTION = "Propose purging the business rule log of the namespace the user is working in: the entries, and their debug rows, older than the days to keep. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give DaysToKeep as a whole number from 0 to 99999, as text. With 0, everything up to the end of today is deleted. It cannot be undone.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropRuleLogList";

/// <p>The fresh read: the count of entries the purge works on.</p>
Parameter READTYPE = "RULELOGSTATE";

Parameter READANSWERS = "Count,DaysToKeep,Namespace";

Parameter WRITETYPE = "PURGERULELOG";

Parameter CLASSICPAGES = "EnsPortal.RuleLog";

/// <p>A call's arguments carry no <code>Count</code>; a stored payload does, because the reviewed fresh read did.</p>
Parameter STATEMARKER = "Count";

Parameter FINGERPRINTSUBJECT = "DaysToKeep,Namespace";

/// <p>The field the precondition reads is the namespace the purge acts in; the one refusal of the fresh read is a namespace that runs no interoperability.</p>
Parameter PRECONDITIONFIELD = "Namespace";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.RULELOG.PURGE";

Parameter CONSEQUENCEBITMAPCODE = "";

/// <p>The count of entries the purge works on, from the fresh read <var>pFresh</var>, as the review's own record.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    If '$IsObject(pFresh) Quit tReview
    Do tReview.%Set("Count", +pFresh.%Get("Count"), "number")
    Quit tReview
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTRULELOG
}

/// <p><parameter>CONSEQUENCECODE</parameter>, the only consequence this purge has.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
