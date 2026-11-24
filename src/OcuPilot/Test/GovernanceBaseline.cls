/// <p>Pins the governance baseline (AD-22, Story 14.2): every key a registered write tool yields
/// has a line in <class>OcuPilot.Kernel.Governance.Baseline</class>, the audit purge's, the
/// namespace delete's, the database delete's, the task import's, Story 18.4's eight disk
/// operations', Story 18.15's enable of interoperability's, Story 19.2's two document deletes' and
/// Story 19.13's two document imports' and Story 18.6's license key activation's and license server
/// delete's and Story 18.25's superserver delete's and Story 18.42's allowed directories update's lines are <code>false</code>, and every other line is
/// <code>true</code>. It also pins that a governance read resolves every row from one parsed baseline.</p>
/// <p><b>What it needs from the environment:</b> the compiled tool registry. Live-safe: it reads
/// the registry and the baseline and writes nothing.</p>
Class OcuPilot.Test.GovernanceBaseline Extends %UnitTest.TestCase
{

/// <p>The lines some story's criteria ship disabled, in the baseline's own line order,
/// comma-separated.</p>
Parameter DISABLED = "osmgmt.databasedetails.compact, osmgmt.databasedetails.defragment, osmgmt.databasedetails.dismount, osmgmt.databasedetails.mount, osmgmt.databasedetails.truncate, osmgmt.databases.integrity, osmgmt.ecpdataservers.changestatus, osmgmt.ecpdataservers.delete, osmgmt.ecpsslconnections.delete, osmgmt.licensekey.activate, osmgmt.licenseservers.delete, osmgmt.localdatabases.delete, osmgmt.localdatabases.expand, osmgmt.localdatabases.grow, osmgmt.namespaces.delete, osmgmt.namespaces.enableinterop, osmgmt.remotedatabases.delete, permissions.resources.import, security.alloweddirectories.update, security.auditing.purge, security.databaseencryption.activate, security.databaseencryption.deactivate, security.dataelementencryption.activate, security.dataelementencryption.deactivate, security.encryptionkeyfile.addkey, security.encryptionkeyfile.create, security.encryptionkeyfile.removekey, security.encryptionkeyfileadmins.addadministrator, security.encryptionkeyfileadmins.removeadministrator, security.encryptionstartup.update, security.mftconnections.delete, security.mftconnections.revoketoken, security.phoneproviders.delete, security.secrets.replacersa, security.secrets.replacesymmetric, security.superservers.delete, security.systemsecurity.set, webapp.docdbapps.delete, webapp.pctaccess.delete, webapp.restapis.delete, webapp.routineapps.delete, tasks.schedule.import, explorer.classes.delete, explorer.routines.delete, explorer.classes.import, explorer.sqlquery.run, explorer.routines.import, explorer.sqldata.save, explorer.docdb.delete, explorer.namespacediff.promote, explorer.unittests.run, explorer.command.run, explorer.classmethod.run, explorer.globals.delete, explorer.globalnodes.save, explorer.globalnodes.delete, explorer.globals.import, explorer.globals.replace, explorer.classes.answer, explorer.routines.answer, explorer.sqlstatements.clearstatistics, explorer.sqlstatements.clean, explorer.sqlindices.rebuild, explorer.sqltable.rebuildindices, explorer.sqltable.clearstatistics, explorer.sqlschematables.tune, explorer.sqltable.setextentsize, explorer.sqlindices.setmapsize, explorer.sqlfieldstatistics.setselectivity, interop.items.remove, interop.items.changeclass, interop.queuemessages.abort, interop.queues.abort, interop.jobs.abort, interop.lookupentries.remove, interop.lookuptables.delete, interop.lookuptables.import, interop.messages.resend, interop.messageheader.editresend, analytics.cubemanager.build, analytics.termlists.delete, analytics.termlistentries.remove, analytics.folderitems.delete, analytics.listinggroups.delete, analytics.listinggrouplistings.remove, analytics.qualitymeasures.delete, analytics.qualitymeasureelements.remove, analytics.qualitymeasuremetas.remove, analytics.runtimevariables.remove, analytics.usericons.remove, interop.businesspartners.remove, interop.defaultsettings.remove, interop.credentials.remove, interop.schedules.remove, interop.purge.run, interop.suspendedmessages.resubmit, interop.suspendedmessages.editresubmit, interop.suspendedmessages.delete, interop.archive.run, osmgmt.backuptasks.run, osmgmt.backuptasks.freeze, osmgmt.backuptasks.thaw, osmgmt.backupdatabases.add, osmgmt.backupdatabases.remove, osmgmt.systemddlmappings.delete, osmgmt.userddlmappings.delete, osmgmt.locales.install, osmgmt.locales.delete, osmgmt.localeproperties.load, osmgmt.locales.import";

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
/// database delete's (Story 18.3), the task import's and the eight disk operations'
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
    Do $$$AssertEquals($ListToString(tDisabled, ", "), ..#DISABLED, "the purge, the namespace delete, the database delete, the task import, the eight disk operations, the enable of interoperability, the remote database delete, the two document deletes, the two document imports, the license key's activation, the license server delete, the SQL query's run, the data browser's save, the ECP data server status change and delete, the five key file writes, the four encryption key writes, the encryption startup settings' update, the two wallet key replaces, the superserver delete, the mobile phone provider delete, the Doc DB application delete, the privileged routine application delete, the REST service delete, the document database drop, the production item remove and change of class, the two queue aborts, the job abort, the lookup entry remove, the lookup table delete, the lookup table import, the allowed directories update, the cube build, the folder item delete and the two DDL mapping deletes and the locale install and delete and the globals delete and the two node writes and the two source-control answers and the three suspended message writes are the lines listed false")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("probe.not.listed", .tListed) _ "|" _ tListed, "0|0", "an unlisted key reads disabled and unlisted")
}

/// <p>A governance read resolves every row from one parsed baseline: <method>OcuPilot.Kernel.Governance.Policy.Rows</method>
/// reads the list it is given and no baseline of its own. Given the baseline's list plus a <code>.x2</code>
/// copy of each write key at its original's value, it answers twice the rows, each copy resolving as
/// its original; a key neither the registry nor the list holds reads absent and disabled, and
/// <method>OcuPilot.Kernel.Governance.Policy.Cascade</method> reads a key only the given list holds from that list.</p>
/// <p>Mutation (Rule 19): <code>Rows</code> calling <code>Baseline.Seed</code> instead of <code>SeedFrom</code> -> the copies read absent
/// and this goes red; <code>Cascade</code> ignoring <var>pBaseline</var> -> the copies read disabled and this goes red on
/// <code>enabled</code>.</p>
Method TestOneReadResolvesEveryRowFromOneParse()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Policy).WriteKeys(.tKeys), "the registered write keys are read")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tList), "the baseline reads")
    If '$IsObject($Get(tList)) Quit
    Set tCount = 0
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        Set tCount = tCount + 1
        Set tAll(tKey) = ""
        Set tAll(tKey _ ".x2") = ""
        If tList.%GetTypeOf(tKey) = "boolean" Do tList.%Set(tKey _ ".x2", tList.%Get(tKey), "boolean")
    }
    Do $$$AssertTrue(tCount > 0, "the registry yields write keys (" _ tCount _ ")")
    Set tAll("probe.render.absent") = ""
    Do ##class(OcuPilot.Kernel.Governance.Policy).Rows(.tAll, .tValues, tList, .tRows)
    Do $$$AssertEquals(tRows.%Size(), 2 * tCount + 1, "Rows answers one row per key given")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tBy(tRow.%Get("key")) = $ListBuild(tRow.%Get("baseline"), tRow.%Get("enabled"), tRow.%Get("source"))
    }
    Set tMismatch = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        If $Get(tBy(tKey)) '= $Get(tBy(tKey _ ".x2")) Set tMismatch = tMismatch _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListLength(tMismatch), 0, "every .x2 row resolves as its original; the first that differs is " _ $ListGet(tMismatch, 1))
    Do $$$AssertEquals($ListGet($Get(tBy("probe.render.absent")), 1) _ "|" _ $ListGet($Get(tBy("probe.render.absent")), 2), "absent|0", "a key in neither the registry's baseline nor the list reads absent and disabled")
    Do ##class(OcuPilot.Kernel.Governance.Policy).Rows(.tKeys, .tValues, {}, .tEmptyRows)
    Set tNotAbsent = 0
    Set tEmptyIterator = tEmptyRows.%GetIterator()
    While tEmptyIterator.%GetNext(.tEmptyIndex, .tEmptyRow) {
        If (tEmptyRow.%Get("baseline") '= "absent") || tEmptyRow.%Get("enabled") Set tNotAbsent = tNotAbsent + 1
    }
    Do $$$AssertEquals(tEmptyRows.%Size() _ "|" _ tNotAbsent, tCount _ "|0", "given an empty list, every row reads absent and disabled, as when the baseline cannot be read")
    Do tList.%Set("probe.render.only", 1, "boolean")
    Do ##class(OcuPilot.Kernel.Governance.Policy).Cascade(.tValues, "probe.render.only", "write", .tEnabled, .tSource, tList)
    Do $$$AssertEquals(tEnabled _ "|" _ tSource, "1|baseline", "Cascade resolves a key only the given list holds from that list")
    Do ##class(OcuPilot.Kernel.Governance.Policy).Cascade(.tValues, "probe.render.only", "write", .tEnabled, .tSource)
    Do $$$AssertEquals(tEnabled _ "|" _ tSource, "0|baseline", "Cascade without a list reads the baseline itself, which does not list that key")
}

}
