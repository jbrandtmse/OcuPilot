/// <p>Pins the governance baseline (AD-22, Story 14.2): every key a registered write tool yields
/// has a line in <class>OcuPilot.Kernel.Governance.Baseline</class>, the audit purge's, the
/// namespace delete's, the database delete's, the task import's, Story 18.4's eight disk
/// operations', Story 18.15's enable of interoperability's, Story 19.2's two document deletes' and
/// Story 19.13's two document imports' and Story 18.6's license key activation's and license server
/// delete's lines are <code>false</code>, and every other line is
/// <code>true</code>.</p>
/// <p><b>What it needs from the environment:</b> the compiled tool registry. Live-safe: it reads
/// the registry and the baseline and writes nothing.</p>
Class OcuPilot.Test.GovernanceBaseline Extends %UnitTest.TestCase
{

/// <p>The lines some story's criteria ship disabled, in the baseline's own line order,
/// comma-separated.</p>
Parameter DISABLED = "osmgmt.databasedetails.compact, osmgmt.databasedetails.defragment, osmgmt.databasedetails.dismount, osmgmt.databasedetails.mount, osmgmt.databasedetails.truncate, osmgmt.databases.integrity, osmgmt.ecpdataservers.changestatus, osmgmt.ecpdataservers.delete, osmgmt.ecpsslconnections.delete, osmgmt.licensekey.activate, osmgmt.licenseservers.delete, osmgmt.localdatabases.delete, osmgmt.localdatabases.expand, osmgmt.localdatabases.grow, osmgmt.namespaces.delete, osmgmt.namespaces.enableinterop, osmgmt.remotedatabases.delete, security.auditing.purge, security.encryptionkeyfile.addkey, security.encryptionkeyfile.create, security.encryptionkeyfile.removekey, security.encryptionkeyfileadmins.addadministrator, security.encryptionkeyfileadmins.removeadministrator, tasks.schedule.import, explorer.classes.delete, explorer.routines.delete, explorer.classes.import, explorer.classes.save, explorer.routines.save, explorer.sqlquery.run, explorer.routines.import";

/// <p>AC2: a registered write key with no baseline line fails here, naming the key. The count is
/// asserted too, so an empty registry cannot pass by looping zero times.</p>
/// <p>Mutation (Rule 19): delete one line from the baseline's XData -> this goes red naming that
/// key.</p>
Method TestEveryRegisteredWriteKeyHasABaselineLine()
{
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).WriteKeys(.tKeys)
    Do $$$AssertStatusOK(tSC, "the registered write keys are read")
    Set tCount = 0
    Set tMissing = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        Set tCount = tCount + 1
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        If 'tListed Set tMissing = tMissing _ $ListBuild(tKey)
    }
    Do $$$AssertTrue(tCount >= 76, "the registry yields the write keys the baseline shipped with, and any added since (" _ tCount _ ")")
    Do $$$AssertEquals($ListToString(tMissing, ", "), "", "every registered write key has a baseline line; add one for each of: " _ $ListToString(tMissing, ", "))
}

/// <p>Every write tool yields at least one key: a tool declaring an action argument with no
/// <code>enum</code> would yield none and escape the check above.</p>
Method TestEveryWriteToolYieldsAKey()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools), "the registry lists")
    If '$IsObject($Get(tTools)) Quit
    Set tEmpty = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        If $ListLength(##class(OcuPilot.Kernel.Governance.Policy).KeysOf(tEntry)) = 0 Set tEmpty = tEmpty _ $ListBuild(tEntry.%Get("name"))
    }
    Do $$$AssertEquals($ListToString(tEmpty, ", "), "", "every write tool yields a key")
}

/// <p>The purge's line (Story 12.3's routed criterion), the namespace delete's (Story 18.2), the
/// database delete's (Story 18.3), the task import's (DW-1827) and the eight disk operations'
/// (Story 18.4) are <code>false</code> and every other line is <code>true</code>, and a key the
/// baseline does not list reads disabled.</p>
/// <p>The expected list is the set of lines some story's criteria ship disabled. A story that adds
/// a line listed <code>false</code> (Epic 18's are) adds its key to that list, in name order, in
/// the same change; this failing on such a line is the prompt to do so, never to delete it.</p>
Method TestThePurgeIsTheOneDisabledLine()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tList), "the baseline reads")
    If '$IsObject($Get(tList)) Quit
    Set tDisabled = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do $$$AssertEquals(tList.%GetTypeOf(tKey), "boolean", tKey _ ": the line is a JSON boolean")
        If 'tValue Set tDisabled = tDisabled _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListToString(tDisabled, ", "), ..#DISABLED, "the purge, the namespace delete, the database delete, the task import, the eight disk operations, the enable of interoperability, the remote database delete, the two document deletes, the two document imports, the license key's activation, the license server delete, the SQL query's run, the ECP data server status change and delete, and the five key file writes are the lines listed false")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("probe.not.listed", .tListed) _ "|" _ tListed, "0|0", "an unlisted key reads disabled and unlisted")
}

}
