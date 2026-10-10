/// <p>Pins Story 20.22's descent rule (AD-21's ninth case, AD-62): an inbound file adapter, <code>EnsLib.File.InboundAdapter</code>,
/// reads the directories below its <code>FilePath</code> as many levels down as its <code>SubdirectoryLevels</code>, and
/// measured on a throwaway a parent directory with one level took, then moved, files lying directly in the manager
/// directory and in the served directory. So a set or a reset of either setting that would let the adapter enter the
/// manager directory or the served directory is refused <code>INTEROP.SETTING.DESCENT</code>, from the three callers, at
/// the mint and again at the write: <code>FilePath</code> as the manager directory's parent with one level, one level over
/// that stored path, and a reset to a default that does either. Zero levels, the grandparent with one level, and
/// lowering the levels are accepted.</p>
/// <p>It runs on a disabled <code>EnsLib.File.PassthroughService</code> item, sets values only, starts no production and
/// creates no file or directory. The directories are read from the instance.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropSettingControl</class>, whose helpers it
/// calls. One class per run.</p>
Class OcuPilot.Test.InteropSettingDescent Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter REFUSALS = "OcuPilot.Test.InteropSettingRefusals";

Parameter PATHS = "OcuPilot.Test.InteropSettingPaths";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropSettingSeam";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

/// <p>The disabled inbound file item the class adds to the probe production.</p>
Parameter ITEM = "OcuPilotProbeFileSvc";

Parameter SERVICE = "EnsLib.File.PassthroughService";

/// <p>A directory no rule protects, where the adapter starts.</p>
Parameter SAFE = "/tmp/ocupilot-descent/";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingDescent compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Quit $ClassMethod(..#PROBE, "Remove")
}

/// <p>The probe production gains a disabled inbound file item whose adapter starts at <parameter>SAFE</parameter>.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddFileItem", ..#ITEM, ..#SERVICE, ..#SAFE, 0)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left with its settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The manager directory's parent, and its parent in turn.</p>
ClassMethod Parent() As %String
{
    Quit ##class(%File).ParentDirectoryName($ClassMethod(..#PATHS, "Manager"))
}

ClassMethod Grandparent() As %String
{
    Quit ##class(%File).ParentDirectoryName(..Parent())
}

/// <p>The stored value of the file item's adapter setting <var>pName</var>.</p>
ClassMethod StoredOf(pName As %String) As %String
{
    Set tText = "<none>"
    Set tProductionName = $Parameter(..#CONTROL, "PRODUCTION")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tProduction = ##class(Ens.Config.Production).%OpenId(tProductionName)
        Set tItem = tProduction.FindItemByConfigName(..#ITEM)
        Set tSetting = tItem.FindSettingByName(pName, "Adapter")
        If $IsObject(tSetting) Set tText = tSetting.Value
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>Assert that the three callers earn <var>pPort</var>, <var>pMint</var> and <var>pScreen</var> for the write of the
/// file item's <var>pName</var>, and that the item's stored settings and the class are as they were.</p>
Method Refused(pLabel As %String, pType As %String, pName As %String, pValue As %String, pPort As %String, pMint As %String, pScreen As %String)
{
    Set tBefore = ..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", pType, "Adapter", pName, pValue, ..#ITEM), pPort, pLabel _ ": through the port")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", pType, "Adapter", pName, pValue, .tProblem, ..#ITEM), pMint, pLabel _ ": through the agent's mint " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByScreen", pType, "Adapter", pName, pValue, ..#ITEM), pScreen, pLabel _ ": through the person's row action")
    Do $$$AssertEquals(..StoredOf("FilePath") _ "|" _ ..StoredOf("SubdirectoryLevels") _ "|" _ $ClassMethod(..#CONTROL, "ClassText"), tBefore, pLabel _ ": the stored settings and the class are as they were")
    Set tAudit = $ClassMethod(..#CONTROL, "SettingAudited", tSince)
    Do $$$AssertEquals(tAudit, "", pLabel _ ": and the vendor audited no setting: " _ tAudit)
}

/// <p>AC9: with one level of subdirectories, <code>FilePath</code> as the manager directory's parent is refused
/// <code>INTEROP.SETTING.DESCENT</code> by the three callers, and one level over a stored <code>FilePath</code> of that
/// parent is refused the same; the item's rows list both settings with their classes' types.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DescentReaches</method> stop one level short -- both
/// legs go red; make a set of <code>SubdirectoryLevels</code> not judged -- the levels leg goes red.</p>
Method TestAParentDirectoryWithOneLevelIsRefused()
{
    Set tDescent = "422 INTEROP.SETTING.DESCENT"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do ..Refused("FilePath as the manager directory's parent, one level", "SET", "FilePath", ..Parent(), tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "the adapter descends no level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "and starts in the manager directory's parent")
    Do ..Refused("one level over that parent", "SET", "SubdirectoryLevels", "1", tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do ..Refused("two levels over it", "SET", "SubdirectoryLevels", "2", tDescent, "400 TOOL.ARGUMENTS", tDescent)
    Do $ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "SubdirectoryLevels", "1", .tProblem, ..#ITEM)
    Do $$$AssertEquals(tProblem, "'Value': " _ ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.SETTING.DESCENT"), "the mint says why, in the story's own sentence")
}

/// <p>AC9: no level, the grandparent with one level (the manager directory lies two levels down), a protected directory
/// deeper than the levels, and lowering the levels are all accepted; the stored path and levels are what the callers set.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DescentReaches</method> ignore the levels -- the
/// grandparent and the lowering rows go red.</p>
Method TestTheLevelsThatDoNotReachAProtectedDirectoryAreAccepted()
{
    Set tManager = $ClassMethod(..#PATHS, "Manager")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", ..Parent(), .tProblem, ..#ITEM), "minted", "the parent with no level is accepted at the mint: the manager directory is not entered")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "FilePath", ..Grandparent(), .tProblem, ..#ITEM), "minted", "the grandparent with one level is accepted: the manager directory lies two levels down")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", ..Grandparent(), ..#ITEM), "200 ", "and the port stores it")
    Do $$$AssertEquals(..StoredOf("FilePath"), ..Grandparent(), "as given")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "SubdirectoryLevels", "2", ..#ITEM), "422 INTEROP.SETTING.DESCENT", "a second level over it reaches the manager directory and is refused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the path is moved to the parent behind the rule's back")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "SubdirectoryLevels", "0", ..#ITEM), "200 ", "lowering the levels from one to none is accepted, as it can only lessen what the adapter reads")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "0", "and stored")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Adapter", "FilePath", tManager _ "sub/", ..#ITEM), "200 ", "a path below the manager directory is judged by the directory rules alone, and passes")
}

/// <p>AC9: a reset is judged by the default it would leave in force, by descent too. The production holds its own
/// <code>FilePath</code> and a system default names the manager directory's parent: with one level the reset is refused
/// <code>INTEROP.SETTING.DESCENT</code> by the three callers; and a reset of the levels to a default of one over a
/// stored path that reaches the manager directory is refused the same.</p>
/// <p>Mutation (Rule 19): judge the current value, not the default, in a reset -- both legs go red.</p>
Method TestAResetThatLeavesADescentInForceIsRefused()
{
    Set tDescent = "409 INTEROP.SETTING.DESCENT"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 1), "the adapter descends one level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", ..#ITEM, "Adapter", "FilePath", ..Parent()), "a system default names the manager directory's parent")
    Do ..Refused("a reset of FilePath to that default", "RESET", "FilePath", $Char(0), tDescent, tDescent, tDescent)
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "FilePath", ..Parent()), "the item starts in the manager directory's parent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", ..#ITEM, "Adapter", "SubdirectoryLevels", "1"), "a system default sets one level")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 0), "and the production holds none")
    Do ..Refused("a reset of the levels to that default", "RESET", "SubdirectoryLevels", $Char(0), tDescent, tDescent, tDescent)
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "SubdirectoryLevels", 3), "the production holds three levels")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "RESET", "Adapter", "SubdirectoryLevels", $Char(0), ..#ITEM), "200 ", "a reset to the class default of none is accepted: lowering is never refused")
}

/// <p>AC9: the write judges descent again. A mint accepts one level over a path; the served directory then moves to a
/// directory directly under the path, through <class>OcuPilot.Test.InteropSettingSeam</class>, and the port's set of the
/// levels refuses it <code>INTEROP.SETTING.DESCENT</code>, storing nothing.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.InteropPort.ChangeProblem</method> in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> and in <method>OcuPilot.Port.InteropPort.SettingViolations</method> --
/// this goes red.</p>
Method TestTheWriteJudgesTheDescentAgain()
{
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Adapter", "SubdirectoryLevels", "1", .tProblem, ..#ITEM), "minted", "the mint accepts one level over the safe path")
    Do $ClassMethod(..#PATHS, "HoldTheWriterPairs")
    Do $ClassMethod(..#SEAM, "UsePathPortFixture")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", ..#SAFE _ "served")
    Set tHttpCode = $ClassMethod(..#PATHS, "BySeam", "SET", "Adapter", "SubdirectoryLevels", "1", ..#ITEM)
    Do $$$AssertEquals(tHttpCode, "422 INTEROP.SETTING.DESCENT", "the served directory has moved one level below the path: the port refuses the levels")
    Do $$$AssertEquals(..StoredOf("SubdirectoryLevels"), "0", "and stores nothing")
}

}
