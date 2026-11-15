/// <p>Interoperability's shutdown group (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.3): set the shutdown group a production of the
/// namespace stops in when the instance stops, as the classic Production Shutdown Group page does. Running productions stop one group at a
/// time, and those in the same group together; the default group is 2. Name the production as the Productions list reports it and give
/// <code>ShutdownGroup</code>, a whole number of at most nine digits with a minus sign if negative. A production already in that group is
/// refused.</p>
/// <p>Two callers reach it: the Productions row action Shutdown group through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. Its read, pairs and refusals are <class>OcuPilot.Screen.Tool.InteropStartupAction</class>'s, and its
/// read-back compares <code>ShutdownGroup</code>.</p>
Class OcuPilot.Screen.Tool.InteropProductionShutdownGroup Extends OcuPilot.Screen.Tool.InteropStartupAction
{

Parameter TOOLNAME = "interop.productions.shutdowngroup";

Parameter DESCRIPTION = "Propose setting the shutdown group of one production of the namespace the user is working in, which decides the order the instance stops productions in when it stops: running productions stop one group at a time, and those in the same group together; the default group is 2. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. ShutdownGroup is a whole number of at most nine digits, with a minus sign if negative. A production already in that group is refused.";

Parameter WRITETYPE = "SHUTDOWNGROUP";

Parameter WRITERESOURCE = "%Admin_Manage";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.ProductionShutdownGroup";

Parameter SCREENACTIONS = "shutdowngroup";

Parameter SCREENVALUES = "shutdowngroup=ShutdownGroup";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "ShutdownGroup";

Parameter CONSEQUENCECODE = "INTEROP.SHUTDOWNGROUP";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#GROUPFIELD)
}

ClassMethod RequiredFields() As %List
{
    Quit $ListBuild(..#GROUPFIELD)
}

ClassMethod FieldDescription(pField As %String) As %String
{
    Quit "The shutdown group, a whole number of at most nine digits with a minus sign if negative. The default is 2."
}

}
