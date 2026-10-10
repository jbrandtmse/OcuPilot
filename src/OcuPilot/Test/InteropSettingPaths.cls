/// <p>Pins Story 20.22's path rule (AD-10, AD-21's ninth case, AD-62; the orchestrator's ruling that a path setting keeps
/// <class>OcuPilot.Port.PathPort</class>'s self-protection): a directory setting may not be the manager directory
/// (<code>PATH.MANAGERDIR</code>) or the served directory or anything under it (<code>PATH.SERVED</code>); a file setting
/// may not sit directly in the manager directory (<code>PATH.MANAGER</code>) or under the served directory
/// (<code>PATH.SERVED</code>). Each refusal comes through the port, the agent's mint and the person's row action, before
/// any vendor write, and leaves the stored settings and the class as they were. A value is judged as the item's namespace
/// normalizes it, in three spellings of the manager directory; a reset is judged by the default it would leave in force;
/// and the write judges again: <class>OcuPilot.Test.InteropSettingSeam</class> moves the served directory after a mint
/// that accepted the value, and the port's set and reset then refuse it.</p>
/// <p>The directories are read from the instance, never named. The class sets values only: it starts no production,
/// creates no file or directory, and the probe item that names a path is disabled or not run. The descent of an inbound
/// file adapter is <class>OcuPilot.Test.InteropSettingDescent</class>'s.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropSettingControl</class>, whose helpers it
/// calls. One class per run.</p>
Class OcuPilot.Test.InteropSettingPaths Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter REFUSALS = "OcuPilot.Test.InteropSettingRefusals";

Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropSettingSeam";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Parameter PATHPORT = "OcuPilot.Port.PathPort";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingPaths compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
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

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Quit $ClassMethod(..#CONTROL, "Reset")
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

/// <p>The manager directory as <class>OcuPilot.Port.PathPort</class> reads it, normalized.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($ClassMethod(..#PATHPORT, "ManagerDirectory"))
}

/// <p>The directory OcuPilot serves its files from, normalized.</p>
ClassMethod Served() As %String
{
    Quit ##class(%File).NormalizeDirectory($ClassMethod(..#PATHPORT, "ServedDirectory"))
}

/// <p>The directory a relative value resolves against in <code>USER</code>, which <code>%File</code> reads as the
/// database directory of the process's namespace.</p>
ClassMethod UserDirectory() As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "USER"
    Set tDirectory = ##class(%File).NormalizeDirectory(".")
    Set $NAMESPACE = tOrigNS
    Quit tDirectory
}

/// <p>Assert that the three callers earn <var>pPort</var>, <var>pMint</var> and <var>pScreen</var> for the write of the
/// probe operation's <var>pTarget</var>/<var>pName</var>, and that nothing was stored, written to the class or audited.
/// <var>pMint</var> <code>minted</code> means the mint accepted the value.</p>
Method Refused(pLabel As %String, pType As %String, pTarget As %String, pName As %String, pValue As %String, pPort As %String, pMint As %String, pScreen As %String)
{
    Set tBefore = $ClassMethod(..#CONTROL, "Snapshot")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", pType, pTarget, pName, pValue), pPort, pLabel _ ": through the port")
    Set tMinted = $ClassMethod(..#REFUSALS, "ByMint", pType, pTarget, pName, pValue, .tProblem)
    Do $$$AssertEquals(tMinted, pMint, pLabel _ ": through the agent's mint " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByScreen", pType, pTarget, pName, pValue), pScreen, pLabel _ ": through the person's row action")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Snapshot"), tBefore, pLabel _ ": the stored settings and the class are as they were")
    Set tAudit = $ClassMethod(..#CONTROL, "SettingAudited", tSince)
    Do $$$AssertEquals(tAudit, "", pLabel _ ": and the vendor audited no setting: " _ tAudit)
}

/// <p>AC9: a directory setting that normalizes to the manager directory is refused <code>PATH.MANAGERDIR</code>, from
/// the three callers, in the three spellings that reach it: without its trailing separator, through a <code>..</code>
/// segment, and as <code>../</code>, which resolves to it from <code>USER</code>'s
/// database directory.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LocationProblem</method> answer <code>""</code> -- every
/// leg goes red; judge the raw value -- the spelling legs go red.</p>
Method TestTheManagerDirectoryIsRefusedInEverySpelling()
{
    Set tManager = ..Manager()
    Set tUserDirectory = ..UserDirectory()
    Do $$$AssertEquals(##class(%File).ParentDirectoryName(tUserDirectory), tManager, "USER's database directory sits directly under the manager directory, which the ../ leg relies on")
    Set tRefused = "422 PATH.MANAGERDIR"
    For tSpelling = $Extract(tManager, 1, *-1), tManager _ "user/..", "../", tManager {
        Do ..Refused("the manager directory as '" _ tSpelling _ "'", "SET", "Host", "ProbeDirectory", tSpelling, tRefused, "400 TOOL.ARGUMENTS", tRefused)
    }
    Do ..ByMintProblem("SET", "Host", "ProbeDirectory", tManager, .tProblem)
    Do $$$AssertEquals(tProblem, "'Value': " _ ##class(OcuPilot.Api.Error).ReasonForPath("PATH.MANAGERDIR"), "the mint says why, in PathPort's own sentence")
}

/// <p>AC9: the served directory, a directory under it and a file under it are refused <code>PATH.SERVED</code>, and a
/// directory beside it that merely shares its name's beginning is not.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LocationKind</method> drop <code>fileSelector</code> -- the
/// file row goes red.</p>
Method TestTheServedDirectoryAndAnythingUnderItIsRefused()
{
    Set tServed = ..Served()
    Set tRefused = "422 PATH.SERVED"
    Do ..Refused("the served directory", "SET", "Host", "ProbeDirectory", tServed, tRefused, "400 TOOL.ARGUMENTS", tRefused)
    Do ..Refused("a directory under it", "SET", "Host", "ProbeDirectory", tServed _ "sub/deeper", tRefused, "400 TOOL.ARGUMENTS", tRefused)
    Do ..Refused("a file under it", "SET", "Host", "ProbeFile", tServed _ "probe.key", tRefused, "400 TOOL.ARGUMENTS", tRefused)
    Set tSibling = $Extract(tServed, 1, *-1) _ "-beside/"
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Host", "ProbeDirectory", tSibling), "minted", "a sibling that shares the beginning of its name is accepted at the mint")
}

/// <p>AC9: a file setting directly in the manager directory is refused <code>PATH.MANAGER</code>; a file one
/// subdirectory below it, and a directory setting under it, are accepted at the mint; and a value of any other path, and
/// an empty one, is judged by its declaring class alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LocationProblem</method> test a file with
/// <code>IsManagerDirectory</code> -- the file row goes red.</p>
Method TestAFileDirectlyInTheManagerDirectoryIsRefused()
{
    Set tManager = ..Manager()
    Set tRefused = "422 PATH.MANAGER"
    Do ..Refused("a file directly in the manager directory", "SET", "Host", "ProbeFile", tManager _ "probe.key", tRefused, "400 TOOL.ARGUMENTS", tRefused)
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Host", "ProbeFile", tManager _ "sub/probe.key"), "minted", "a file in a subdirectory of it is accepted at the mint")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Host", "ProbeDirectory", tManager _ "sub"), "minted", "so is a directory under it")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Host", "ProbeDirectory", "/tmp/ocupilot-elsewhere"), "minted", "and any other path")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Host", "ProbeFile", "/tmp/ocupilot-elsewhere.key"), "200 ", "which the port stores")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeFile"), "/tmp/ocupilot-elsewhere.key", "as given")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "SET", "Host", "ProbeFile", ""), "200 ", "an empty value is not a location")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeFile"), "", "and clears it")
}

/// <p>AC9: a reset is judged by the default it would leave in force. The production holds its own directory and a system
/// default names the manager directory, a file directly in it, and the served directory: the reset's fresh read and the
/// port's reset refuse each by the path code, 409; a default that names a safe path resets.</p>
/// <p>Mutation (Rule 19): judge the current value, not the default, in
/// <method>OcuPilot.Port.InteropPort.ReadSetting</method> -- the three callers' rows go red.</p>
Method TestAResetToAProtectedDefaultIsRefused()
{
    Set tManager = ..Manager()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", "OcuPilotProbeOp", "Host", "ProbeDirectory", "/tmp/ocupilot-own-dir"), "the production holds its own directory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", "OcuPilotProbeOp", "Host", "ProbeFile", "/tmp/ocupilot-own.key"), "and its own file")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ProbeDirectory", tManager), "a system default names the manager directory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ProbeFile", tManager _ "default.key"), "and a file directly in it")
    Set tRow = $ClassMethod(..#CONTROL, "Row", "Host", "ProbeDirectory")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default _ "|" _ tRow.DefaultSource, "/tmp/ocupilot-own-dir|production|" _ tManager _ "|systemDefault", "the row reads the production's value over the default")
    Do ..Refused("a reset to the manager directory", "RESET", "Host", "ProbeDirectory", $Char(0), "409 PATH.MANAGERDIR", "409 PATH.MANAGERDIR", "409 PATH.MANAGERDIR")
    Do ..Refused("a reset to a file in it", "RESET", "Host", "ProbeFile", $Char(0), "409 PATH.MANAGER", "409 PATH.MANAGER", "409 PATH.MANAGER")
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ProbeDirectory", ..Served()), "a system default names the served directory")
    Do ..Refused("a reset to the served directory", "RESET", "Host", "ProbeDirectory", $Char(0), "409 PATH.SERVED", "409 PATH.SERVED", "409 PATH.SERVED")
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ProbeDirectory", "/tmp/ocupilot-default-dir"), "a system default names a safe directory")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByPort", "RESET", "Host", "ProbeDirectory"), "200 ", "which a reset returns to")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeDirectory"), "<none>", "removing the production's own value")
}

/// <p>AC9: the write judges again. A mint accepts a directory; the served directory then moves onto it, through
/// <class>OcuPilot.Test.InteropSettingSeam</class>; the port's set refuses it <code>PATH.SERVED</code> and nothing is
/// stored. A system default the served directory then covers makes the reset refuse too, and the seam places the served
/// directory at <code>USER</code>'s database directory to show the value <code>.</code> is read where the production's
/// jobs read it.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.InteropPort.ChangeProblem</method> in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> -- the reset row goes red; normalize in the install namespace --
/// the <code>.</code> row goes red.</p>
Method TestTheWriteJudgesTheValueAgain()
{
    Set tDirectory = "/tmp/ocupilot-moved/"
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "SET", "Host", "ProbeDirectory", tDirectory), "minted", "the mint accepts the directory")
    Do ..HoldTheWriterPairs()
    Do $ClassMethod(..#SEAM, "UsePathPortFixture")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", tDirectory)
    Do $$$AssertEquals(..BySeam("SET", "Host", "ProbeDirectory", tDirectory _ "inside"), "422 PATH.SERVED", "the served directory has moved onto it: the port's set refuses it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeDirectory"), "<none>", "and stores nothing")
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", "OcuPilotProbeOp", "Host", "ProbeDirectory", "/tmp/ocupilot-own-dir"), "the production holds its own directory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutDefault", "OcuPilotProbeOp", "Host", "ProbeDirectory", tDirectory _ "default"), "and a system default names one beside it")
    Do $$$AssertEquals($ClassMethod(..#REFUSALS, "ByMint", "RESET", "Host", "ProbeDirectory"), "minted", "the mint accepts the reset")
    Do ..HoldTheWriterPairs()
    Do $ClassMethod(..#SEAM, "UsePathPortFixture")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", tDirectory)
    Do $$$AssertEquals(..BySeam("RESET", "Host", "ProbeDirectory"), "409 PATH.SERVED", "the default is now served: the port's reset refuses it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeDirectory"), "/tmp/ocupilot-own-dir", "and leaves the production's own value")
    Do $ClassMethod(..#FIXTURE, "UseServedDirectory", ..UserDirectory())
    Do $$$AssertEquals(..BySeam("SET", "Host", "ProbeDirectory", "."), "422 PATH.SERVED", "with the served directory at USER's database directory, the value . is refused: it is read in USER")
    Do $$$AssertEquals(..BySeam("SET", "Host", "ProbeFile", "x.key"), "422 PATH.SERVED", "and so is a bare file name, which USER resolves into it")
}

/// <p>The seam's gate holds the pairs a setting write needs for <code>USER</code>.</p>
ClassMethod HoldTheWriterPairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p><var>pType</var> of the probe operation's <var>pTarget</var>/<var>pName</var> through
/// <class>OcuPilot.Test.InteropSettingSeam</class>, as <code>http code</code>.</p>
ClassMethod BySeam(pType As %String, pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, pItem As %String = {$Parameter("OcuPilot.Test.InteropSettingControl", "OPNAME")}) As %String
{
    Set tBody = $Select(pValue = $Char(0): "", 1: {})
    If pValue '= $Char(0) Do tBody.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#CONTROL, "Invoke", pType, $ClassMethod(..#CONTROL, "IdOf", pTarget, pName, pItem), tBody, "", .tResult, .tHttp, .tFault, ..#SEAM)
    Quit +$Get(tHttp) _ " " _ $ClassMethod(..#CONTROL, "CodeOf", tFault)
}

/// <p>The agent's call's problem sentence in <var>pProblem</var>.</p>
ClassMethod ByMintProblem(pType As %String, pTarget As %String, pName As %String, pValue As %String, Output pProblem As %String)
{
    Do $ClassMethod(..#REFUSALS, "ByMint", pType, pTarget, pName, pValue, .pProblem)
}

}
