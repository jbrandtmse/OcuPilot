/// <p>Pins Story 24.16 Batch 4's archive settings end to end against <code>HSCUSTOM</code>, whose archive target is <code>USER</code> (AD-6, AD-14, AD-15, AD-22, AD-51, AD-53, AD-55, AD-58,
/// AD-59, AD-62): a person's Set value and the agent's confirmed proposal each store a setting, which reads back through the vendor's <code>GetArchiveParameters</code> as sent with
/// <code>Stored</code> true and a read-back that matches, each recording one <code>ConfigChange</code> naming the namespace, the setting and the value, where the vendor records none;
/// a namespace with no node reads the vendor's defaults and reading them writes nothing; a value outside its kind, a target the classic page does not list (the namespace itself
/// included), the archive class and an unknown name are refused by name from every caller with nothing stored; with no other interoperability namespace Archive to namespace accepts
/// nothing; and the script form renders the vendor's own call and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropArchiveCase</class> needs. It puts both namespaces' archive trees back exactly as it found them.</p>
Class OcuPilot.Test.InteropArchiveSettingControl Extends OcuPilot.Test.InteropArchiveCase
{

/// <p>The settings the port answers, as <code>Name=Value/Stored/Kind</code>, separated by <code>;</code>, for <var>pNamespace</var>.</p>
ClassMethod Rows(pNamespace As %String = {..#SOURCE}) As %String
{
    Do ..Verdict("ArchiveSettings", "LIST", .tRows, , , , , pNamespace)
    Set tText = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Name _ "=" _ tRow.Value _ "/" _ tRow.Stored _ "/" _ tRow.Kind
        }
    }
    Quit tText
}

/// <p>The Archive settings screen is declared as the plan places it: in the Interoperability area at side bar 20 after Archive manager, with Set value as its one row action, over the
/// classic page's own <code>%Ens_ArchiveManager:READ</code> beside the portal, naming the entity type <code>interop-archive-setting</code> and the classic page it replaces.</p>
/// <p>Mutation (Rule 19): change the Archive settings screen's <code>sideBarPosition</code> to 19 -- this goes red.</p>
Method TestTheDeclarationsRegister()
{
    Set tPairs = "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ArchiveManager"",""permission"":""READ""}]"
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropArchiveSettingList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the Archive settings screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/archive-settings|20|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.toolIdentifier, "interop-archive-setting|namespace|interop.archivesettings", "its entity type, its scope and its tool identifier")
    Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.rowActions.%Get(0).id, "1|set", "its one row action is Set value")
    Do $$$AssertEquals(tDeclaration.classicPage, "EnsPortal.ArchiveManager", "its classic page")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), tPairs, "its pairs are the classic page's")
}

/// <p>AC1: a person's Set value stores the target and the agent's confirmed proposal stores the days, each reading back through <code>GetArchiveParameters</code> as sent with
/// <code>Stored</code> true and a read-back that matches, the archive class staying the vendor's, each recording one <code>ConfigChange</code> that names the namespace, the setting
/// and the value, and the vendor recording none. The agent's write is marked and ledgered once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformArchiveSetting</method> pass the stored days to <code>SetArchiveParameters</code> whatever the setting --
/// the days leg goes red.</p>
Method TestASettingSetFromEitherCallerReadsBackAsSent()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), "<absent>|<absent>|<absent>", "no setting is stored in HSCUSTOM to begin with")
    Set tText = ..ActSet(..#TARGETNAME, ..#TARGET, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Set value answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-archive-setting|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|Ens.Archive.Manager|30", "the vendor holds the target as sent, and the two others at their effective values, as the classic Save stores all three")
    Do ..Verdict("ArchiveSettings", "SETTING", .tRow, , ..#TARGETNAME)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.Value _ "|" _ tRow.Stored _ "|" _ tRow.Namespace, 1: ""), ..#TARGET _ "|1|" _ ..#SOURCE, "the single read answers it as stored")
    Do $$$AssertEquals(..OwnRows(tSince, "interop-archive-setting", .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ ..#SOURCE) && (tData [ ..#TARGETNAME) && (tData [ ..#TARGET), "naming the namespace, the setting and the value: " _ tData)
    Set tVerdict = ..MintSet(..#DAYSNAME, "90", .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tVerdict, "minted", "the agent's set of the days mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-archive-setting|" _ ..#SOURCE _ "|" _ ..#DAYSNAME, "the target is the setting, by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|Ens.Archive.Manager|30", "nothing is written by the mint")
    Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropItemControl).LedgerCount(tTurn, ..#SETKEY), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|Ens.Archive.Manager|90", "the vendor holds the days as the agent sent them, and the target as the person did")
    Do $$$AssertEquals(..OwnRows(tSince, "interop-archive-setting", .tData), 2, "OcuPilot records a second ConfigChange")
    Do $$$AssertTrue(tData [ "90", "naming the days: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, "ArchiveManager"), 0, "and the vendor records none")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#TARGET), "<absent>|<absent>|<absent>", "USER's own settings are untouched")
}

/// <p>AC1: a namespace with no <code>^Ens.ArchiveManager</code> node reads the vendor's three defaults in the classic order, none stored, the class read-only, and reading them
/// writes nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveSettingRoster</method> default the days to 0 -- this goes red.</p>
Method TestANamespaceWithNoNodesReadsTheVendorDefaults()
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), "<absent>|<absent>|<absent>", "HSCUSTOM stores no archive setting")
    Do $$$AssertEquals(..Rows(), ..#TARGETNAME _ "=/0/choice;" _ ..#CLASSNAME _ "=Ens.Archive.Manager/0/text;" _ ..#DAYSNAME _ "=30/0/integer", "three rows, the vendor's defaults, none stored")
    Do ..Verdict("ArchiveSettings", "LIST", .tRows)
    Set tAccepts = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tAccepts = tAccepts _ $Select(tAccepts = "": "", 1: "|") _ tRow.ReadOnly _ ":" _ tRow.Accepts
    }
    Do $$$AssertEquals(tAccepts, "0:One of USER.|1:Shown here and never changed here.|0:A whole number from 0 to 36500.", "each row says what it accepts, and the class is read-only")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..#EMPTYTREES, "and reading them wrote no node")
}

/// <p>AC1, AC3: a target the classic page does not list (the namespace itself, an unknown one, none), days outside 0 to 36500 or not a whole number, the archive class and an unknown
/// name are refused from the port, the person's Set value and the agent's mint, each by its own code and the sentence the instance publishes, with nothing stored; 0 and 36500 days
/// are accepted and stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveSettingLimits</method> answer the days' maximum as 36501 -- the days leg goes red.</p>
Method TestABadValueOrNameIsRefusedAndNothingIsStored()
{
    Set tValueReason = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.VALUE")
    Set tReadOnlyReason = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.READONLY")
    For tCase = $ListBuild(..#TARGETNAME, ..#SOURCE), $ListBuild(..#TARGETNAME, "NOPE"), $ListBuild(..#TARGETNAME, ""), $ListBuild(..#DAYSNAME, "-1"), $ListBuild(..#DAYSNAME, "36501"), $ListBuild(..#DAYSNAME, "x"), $ListBuild(..#DAYSNAME, "3.5"), $ListBuild(..#DAYSNAME, "") {
        Set tName = $List(tCase, 1)
        Set tValue = $List(tCase, 2)
        Set tLabel = tName _ " '" _ tValue _ "'"
        Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , tName, {"Value": (tValue)}), "400 CONFIG.SETTING.VALUE", tLabel _ ": the port refuses the value")
        Set tText = ..ActSet(tName, tValue, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: tText), "CONFIG.SETTING.VALUE " _ tValueReason, tLabel _ ": the person's Set value is refused with the published sentence")
        Do $$$AssertEquals(..MintSet(tName, tValue, .tReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", tLabel _ ": the agent's mint is refused")
        Do $$$AssertTrue(tReason [ tValueReason, tLabel _ ": naming the sentence: " _ tReason)
    }
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#CLASSNAME, {"Value": "User.Probe.Archiver"}), "409 CONFIG.SETTING.READONLY", "the archive class is refused by the port, whatever the value")
    Set tText = ..ActSet(..#CLASSNAME, "User.Probe.Archiver", .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: tText), "CONFIG.SETTING.READONLY " _ tReadOnlyReason, "and by the person's Set value")
    Do $$$AssertEquals(..MintSet(..#CLASSNAME, "User.Probe.Archiver", .tReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", "and by the agent's mint")
    Do $$$AssertTrue(tReason [ tReadOnlyReason, "naming the sentence: " _ tReason)
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , "Not a setting", {"Value": "1"}), "404 CONFIG.SETTING.NOTFOUND", "an unknown name is refused by the port")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTING", , , "Not a setting"), "404 CONFIG.SETTING.NOTFOUND", "and by the single read")
    Do $$$AssertEquals(..MintSet("Not a setting", "1", .tReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", "and by the agent's mint")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#DAYSNAME, {"Value": 1}), "400 PORT.VALIDATION", "a value that is not text is refused")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..#EMPTYTREES, "no refusal stored a node")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#DAYSNAME, {"Value": "0"}), "200 ", "0 days is accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), "<absent>|Ens.Archive.Manager|0", "and stored")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#DAYSNAME, {"Value": "36500"}), "200 ", "36,500 days is accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), "<absent>|Ens.Archive.Manager|36500", "and stored")
}

/// <p>AC1: in a namespace that has no other interoperability namespace to archive to (<code>USER</code>, whose list holds nothing but itself) Archive to namespace says so and accepts
/// nothing, from the port and the agent's mint; nothing is written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveTargets</method> keep the namespace itself in the list -- this goes red.</p>
Method TestWithNoOtherNamespaceTheTargetAcceptsNothing()
{
    Do ..Verdict("ArchiveSettings", "SETTING", .tRow, , ..#TARGETNAME, , , ..#TARGET)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.Accepts, 1: ""), ##class(OcuPilot.Api.InteropError).#ACCEPTSNOARCHIVETARGET, "the row says there is no other interoperability namespace")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#TARGETNAME, {"Value": (..#SOURCE)}, , ..#TARGET), "400 CONFIG.SETTING.VALUE", "HSCUSTOM is not a namespace the page lists for USER, so it is refused")
    Do $$$AssertEquals(..Verdict("ArchiveSettings", "SETTINGSET", , , ..#TARGETNAME, {"Value": (..#TARGET)}, , ..#TARGET), "400 CONFIG.SETTING.VALUE", "nor is USER itself")
    Do $$$AssertEquals(..MintSet(..#TARGETNAME, ..#SOURCE, .tReason, .tProposal, .tTurn, ..#TARGET), "TOOL.ARGUMENTS", "and the agent's mint is refused")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..#EMPTYTREES, "nothing was written in either namespace")
}

/// <p>AC1: the script form of the write names the namespace, reads the vendor's three values and sets the one that changes through <code>SetArchiveParameters</code>, a target as a string
/// literal and the days as a number, and runs nothing; a value, a name or the class the port would refuse renders no script.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveSettingSnippet</method> set the days for every setting -- this goes red.</p>
Method TestTheScriptFormRendersTheVendorsCallAndRunsNothing()
{
    Kill tScript
    Set tScript("namespace") = ..#SOURCE
    Set tScript("id") = ..#TARGETNAME
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "ArchiveSettings", "SETTINGSET", .tScript, {"Value": (..#TARGET)})
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step is rendered")
    Set tText = ..StepText(tSteps)
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""HSCUSTOM""", "it names the namespace: " _ tText)
    Do $$$AssertTrue(tText [ "GetArchiveParameters(.tTarget, .tClass, .tDays)", "it reads the three values: " _ tText)
    Do $$$AssertTrue((tText [ "Set tTarget = ""USER""") && (tText '[ "Set tDays"), "it sets the target as a string literal: " _ tText)
    Do $$$AssertTrue(tText [ "SetArchiveParameters(tTarget, tClass, tDays)", "and calls the vendor's own set: " _ tText)
    Set tScript("id") = ..#DAYSNAME
    Set tText = ..StepText($ClassMethod(..#PORT, "Snippet", "ArchiveSettings", "SETTINGSET", .tScript, {"Value": "90"}))
    Do $$$AssertTrue((tText [ "Set tDays = 90") && (tText '[ "Set tTarget"), "the days are a number: " _ tText)
    For tCase = $ListBuild(..#TARGETNAME, "NOPE"), $ListBuild(..#DAYSNAME, "x"), $ListBuild(..#DAYSNAME, "36501"), $ListBuild(..#CLASSNAME, "User.Probe.Archiver"), $ListBuild("Not a setting", "1") {
        Set tScript("id") = $List(tCase, 1)
        Set tNone = $ClassMethod(..#PORT, "Snippet", "ArchiveSettings", "SETTINGSET", .tScript, {"Value": ($List(tCase, 2))})
        Do $$$AssertEquals(tNone.%Size(), 0, $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' renders no script")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..#EMPTYTREES, "no draft stored a node")
}

}
