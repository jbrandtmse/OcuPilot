/// <p>Pins the governance baseline (AD-22, Story 14.2): every key a registered write tool yields
/// has a line in <class>OcuPilot.Kernel.Governance.Baseline</class>, the audit purge's line is
/// <code>false</code>, and every other line is <code>true</code>.</p>
/// <p><b>What it needs from the environment:</b> the compiled tool registry. Live-safe: it reads
/// the registry and the baseline and writes nothing.</p>
Class OcuPilot.Test.GovernanceBaseline Extends %UnitTest.TestCase
{

Parameter PURGE = "security.auditing.purge";

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

/// <p>The purge's line is <code>false</code> (Story 12.3's routed criterion) and every other line
/// is <code>true</code>, and a key the baseline does not list reads disabled.</p>
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
    Do $$$AssertEquals($ListToString(tDisabled, ", "), ..#PURGE, "the purge is the one line listed false")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("probe.not.listed", .tListed) _ "|" _ tListed, "0|0", "an unlisted key reads disabled and unlisted")
}

}
