/// <p>Database details' dismount (Story 18.4, AD-51, AD-53): dismount one mounted database, so no
/// process reads or writes it until it is mounted again. The agent reaches it through a proposal the
/// user confirms; Database details reaches it through its <code>dismount</code> row action. It sends no
/// body, and the vendor dismounts synchronously.</p>
/// <p><b>Its pairs are Database details' own and <parameter>OWNSETRESOURCE</parameter></b>. The vendor's
/// dismount needs Database details' pairs alone (measured on <code>ocupilot-b-ci</code>). The classic
/// Database details page performs the dismount itself, so it names no other replaced page (AD-44).</p>
/// <p>Dismounting OcuPilot's own database, the install namespace's globals or routines database or a
/// system database is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTDATABASE</parameter>) on both callers. That
/// refusal reads the install namespace and the database configurations through the port as the caller,
/// and a read it cannot make refuses, so the tool declares the pair those reads need.</p>
Class OcuPilot.Screen.Tool.DatabaseDismount Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databasedetails.dismount";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter DESCRIPTION = "Propose dismounting one mounted database, which stops every process from reading or writing it until it is mounted again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database by its directory as the databases list reports it. A database that is already dismounted, OcuPilot's own database, the databases OcuPilot runs from and the instance's system databases are refused.";

Parameter WRITETYPE = "DISMOUNT";

Parameter SCREENACTIONS = "dismount";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Mounted";

Parameter STATEFIELD = "Mounted";

/// <p>The resource the prohibited set's own-database read needs, at <code>USE</code>:
/// <code>Namespace.Namespace</code> <code>GET</code> and <code>Database.ConfigCRUD</code>
/// <code>LIST</code> answer <code>ResourcesOR()</code> <code>%Admin_Manage</code> alone (measured on
/// <code>ocupilot-b-ci</code>).</p>
Parameter OWNSETRESOURCE = "%Admin_Manage";

/// <p>The base class's pairs, then <parameter>OWNSETRESOURCE</parameter>.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tOwnSet = $ListBuild(..#OWNSETRESOURCE, "USE")
    If '$ListFind(tPairs, tOwnSet) Set tPairs = tPairs _ $ListBuild(tOwnSet)
    Quit tPairs
}

/// <p>One state row: <code>Mounted</code> from <code>true</code> to <code>false</code>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = [{"field": "Mounted", "before": "true", "after": "false"}]
    Set pProblem = ""
    Quit $$$OK
}

}
