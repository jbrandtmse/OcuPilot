/// <p>Pins Story 21.19's export and import on both callers (AD-6, AD-10, AD-21, AD-51, AD-53, AD-58) against the real instance: a resource the test made is exported
/// by the screen's action and, by the agent's confirmed proposal, to a server file that already holds another text, which it replaces; every resource is exported to a file by
/// the screen; the resource is deleted and imported back from the file's text by the screen's <code>import-local</code> and, from the server file, by the agent's proposal,
/// each listing it again with the description and public permission it had; an agent's import is refused once its file has changed after the mint, with nothing imported;
/// an import that opens one of OcuPilot's own resources is refused on both callers with that resource unchanged; and no transfer directory is left.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an allowed directory, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class creates, exports, deletes and imports a resource named <parameter>RESOURCEA</parameter>. Every test deletes it and the files it wrote on every path
/// (<method>Restore</method>) and puts the governance policy back.</p>
Class OcuPilot.Test.ResourceTransferWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ResourceTransferPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter SCREEN = "permissions.resources";

Parameter KEYS = "permissions.resources.import,permissions.resources.export";

/// <p>The resource every test makes.</p>
Parameter RESOURCEA = "T21Pm24Probe";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>How many transfer directories the port had in the temporary directory before the test, which the test leaves as it found.</p>
Property PreparedTransferFiles As %Integer [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ResourceTransferWrite creates, exports, deletes and imports a resource on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Do ..Restore()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ..Restore()
    Set ..PreparedTransferFiles = ..TransferFiles()
    Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    For tI = 1:1:$Length(..#KEYS, ",") Set tSettings($Piece(..#KEYS, ",", tI)) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Do $$$AssertEquals(..VendorExists(..#RESOURCEA), 0, "the resource is gone")
    Do $$$AssertEquals(..TransferFiles(), ..PreparedTransferFiles, "no transfer directory of this test is left in the temporary directory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Delete the resource, in <code>%SYS</code>.</p>
Method Restore()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(Security.Resources).Delete(..#RESOURCEA)
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>How many transfer directories the port has left in the operating system's temporary directory.</p>
ClassMethod TransferFiles() As %Integer
{
    Set tCount = 0
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Set tSC = tRS.Execute($ClassMethod(..#PORT, "TransferParent"), $Parameter(..#PORT, "TRANSFERDIRECTORY") _ "-*", "", 0)
    While tRS.Next() {
        If tRS.Get("Type") = "D" Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Create the resource <var>pName</var> with a description and the public permission <var>pPermission</var>, as the test's own setup.</p>
ClassMethod VendorCreate(pName As %String, pPermission As %String = "R") As %Boolean
{
    Set tOK = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tOK = $$$ISOK(##class(Security.Resources).Create(pName, "t21 pm24 probe", pPermission))
    } Catch {
        Set tOK = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOK
}

ClassMethod VendorExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Resources).Exists(pName)
    } Catch {
        Set tExists = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>The resource <var>pName</var> as <code>description|permission</code>, or <code>absent</code>.</p>
ClassMethod VendorRead(pName As %String) As %String
{
    Set tOut = "absent"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(pName, .tResource) Set tOut = tResource.Description _ "|" _ tResource.PublicPermission
        Set tResource = ""
    } Catch {
        Set tOut = "error"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> with <var>pValues</var>; the parsed envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with <var>pArgs</var> and confirm it; answers <code>http code</code> and the confirm's answer in <var>pResult</var>, or
/// <code>refused: &lt;problem&gt;</code> when the mint refused.</p>
ClassMethod Agent(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, pArgs, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", tProposal, .pResult)
}

/// <p><b>PM-24, AD-53, AD-58.</b> A resource the test made is exported by the screen and by the agent, to a file that already holds another text, which the agent's export replaces;
/// every resource is exported by the screen; the resource is deleted and imported back from its text by the screen's local import and, from the file, by the agent's confirmed
/// proposal, listed again with the description and permission it had; an agent's import whose file changes after the mint is refused with nothing imported. No temporary file
/// is left.</p>
/// <p>Mutation (Rule 19): <code>Transfer</code> passing flags 1 on the import -> the listed-again rows go red.</p>
Method TestAnExportIsImportedBackOnBothCallersAndAChangedFileIsRefused()
{
    Do $$$AssertTrue(..VendorCreate(..#RESOURCEA, "RW"), "the resource is made as the test's own setup")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "one.xml")
    Set tStatus = ..Act("export", ..#RESOURCEA, {"root": (tRoot), "path": (tPath)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "200|", "the screen's export of the resource answers: " _ $Extract($Get(tAnswer), 1, 200))
    Set tText = $ClassMethod(..#PROBE, "ReadFile", "one.xml")
    Do $$$AssertTrue((tText [ ("<Name>" _ ..#RESOURCEA _ "</Name>")) && (tText [ "<ResourcesExport>") && ($Length(tText, "<Resources>") = 2), "its file holds the one resource in the vendor's export form")
    Do $ClassMethod(..#PROBE, "WriteFile", "two.xml", "an older file")
    Set tTwo = $ClassMethod(..#PROBE, "RelativeName", "two.xml")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.ResourceExport", ..#RESOURCEA, {"Name": (..#RESOURCEA), "root": (tRoot), "path": (tTwo)}, .tResult)
    Do $$$AssertEquals(tOutcome, "200 ", "the agent's confirmed export to a file that holds another text answers: " _ tOutcome)
    Set tFile = $ClassMethod(..#PROBE, "ReadFile", "two.xml")
    Do $$$AssertTrue((tFile '[ "an older file") && (tFile [ ("<Name>" _ ..#RESOURCEA _ "</Name>")), "the file at that name is replaced by the resource's export")
    Set tAllPath = $ClassMethod(..#PROBE, "RelativeName", "all.xml")
    Set tStatus = ..Act("export-all", "*", {"root": (tRoot), "path": (tAllPath)}, .tAll)
    Set tEvery = $ClassMethod(..#PROBE, "ReadFile", "all.xml")
    Do $$$AssertEquals(tStatus _ "|" _ ($Length(tEvery, "<Resources>") - 1), "200|" _ ##class(OcuPilot.Test.ResourceTransferRead).VendorCount(), "the screen's export of every resource writes as many as the vendor lists")
    Do $$$AssertTrue(tEvery [ ("<Name>" _ ..#RESOURCEA _ "</Name>"), "and the probe resource is among them")
    Set tBefore = ..VendorRead(..#RESOURCEA)
    Do $$$AssertEquals(tBefore, "t21 pm24 probe|3", "the resource reads with its description and permission")
    Do ..Restore()
    Set tStatus = ..Act("import-local", "import", {"fileName": "one.xml", "content": (tText)}, .tImported)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tImported) _ "|" _ ..VendorRead(..#RESOURCEA), "200||" _ tBefore, "the screen's import of the local text lists the resource again as it was: " _ $Extract($Get(tImported), 1, 200))
    Do $$$AssertEquals($Select($IsObject(tImported.%Get("output")): tImported.%Get("output").%Get("Count"), 1: -1), 1, "and the vendor's count of imported resources is answered")
    Do ..Restore()
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.ResourceImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..VendorRead(..#RESOURCEA), "200 |" _ tBefore, "the agent's confirmed import of the server file lists the resource again: " _ tOutcome)
    Do ..Restore()
    Set ^||OcuPilotDatabaseWritePort = $Parameter("OcuPilot.Screen.Tool.ResourceImport", "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.ResourceImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's mint of the import is a proposal: " _ $Get(tProblem))
    Do $ClassMethod(..#PROBE, "WriteFile", "one.xml", tText _ " ")
    Set tChanged = $ClassMethod(..#AGENT, "Confirm", tProposal, .tChangedResult)
    Do $$$AssertEquals(tChanged _ "|" _ ..VendorExists(..#RESOURCEA), "409 PROPOSAL.TARGETCHANGED|0", "a file that changed after the mint is refused (" _ tChanged _ "), and nothing is imported")
}

/// <p><b>PM-24, AD-10.</b> A file that gives one of OcuPilot's own resources a public permission it does not hold is refused as every own-resource write is, on both
/// callers: the screen's local import answers 403 and the agent's confirm refuses, with the resource's public permission as it was and the other resource of the file
/// not imported; the kernel's own set refuses the server file by itself, apart from the port's check at the write.</p>
/// <p>Mutation (Rule 19): <code>Prohibits</code> not routing a resource import to <code>ResourceImport</code> -> the kernel's own row goes red (the port still refuses
/// both callers).</p>
Method TestAnImportThatOpensAnOwnResourceIsRefusedOnBothCallers()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotResources(.tOwn)
    Set tName = $List(tOwn, 1)
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "OCUPILOTRESOURCE")
    Set tHeldBefore = ..VendorRead(tName)
    Set tText = ##class(OcuPilot.Test.ResourceTransferRead).Text($ListBuild($ListBuild(..#RESOURCEA, 1), $ListBuild(tName, 7)))
    Set tStatus = ..Act("import-local", "import", {"fileName": "own.xml", "content": (tText)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "403|" _ tCode, "the screen's import of a file that opens an own resource is refused: " _ $Extract($Get(tAnswer), 1, 200))
    Do $$$AssertEquals(..VendorExists(..#RESOURCEA) _ "|" _ (..VendorRead(tName) = tHeldBefore), "0|1", "nothing of the file is imported and the own resource is as it was")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "own.xml")
    Do $ClassMethod(..#PROBE, "WriteFile", "own.xml", tText)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("resource", "instance", "import", .tImportRef), "the import's target key is built")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("permissions.resources.import", tImportRef, {"root": (tRoot), "path": (tPath)}.%ToJSON(), "[]", .tProhibits, .tFound), "the kernel's set answers")
    Do $$$AssertEquals($Get(tProhibits) _ "|" _ $Get(tFound), "1|" _ tCode, "the kernel's own set refuses the file")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.ResourceImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tResult)
    Do $$$AssertTrue(tOutcome [ tCode, "the agent's confirmed import of the same file is refused: " _ tOutcome)
    Do $$$AssertEquals(..VendorExists(..#RESOURCEA) _ "|" _ (..VendorRead(tName) = tHeldBefore), "0|1", "and nothing is imported by it either")
}

}
