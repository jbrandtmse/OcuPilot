/// <p>Pins the percent-class access port and its agent tools (Story 18.10): the shape refusals answer before the vendor, a
/// created entry is read back as <code>STATE</code>, an instance-owned entry is refused its delete as
/// <code>PCTACCESS.SYSTEM</code>, the create path refuses an entry already held, and the agent's create and delete mint,
/// confirm and read back.</p>
/// <p>Needs the throwaway's install and the instance's own system entries. It creates one entry, named
/// <code>%OcuProbe1810.Entry</code> on <code>all-applications</code>. <code>OnBeforeOneTest</code> records the entries the
/// instance holds and the stored governance policy; <code>OnAfterOneTest</code> removes every <code>%OcuProbe1810</code>
/// entry, every entry a test added to <code>all-applications</code>, the turn and proposals the agent test seeded, and
/// restores the policy. The one test that enables the delete tool does so only for its own span.</p>
Class OcuPilot.Test.WebAppPctAccess Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Refuses to run anywhere <parameter>ARMINGVARIABLE</parameter> does not read 1: this class creates and removes percent-class access entries on this instance.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppPctAccess creates and removes percent-class access entries on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The composite ids of the entries held before the test, keyed by id.</p>
Property PreparedEntries [ MultiDimensional ];

/// <p>The stored governance policy before the test, as a <code>Snapshot</code> holds it.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The probe entry's class and the application it is granted on.</p>
Parameter PROBECLASS = "%OcuProbe1810.Entry";

Parameter PROBEAPP = "all-applications";

/// <p>The prefix every probe class carries; an entry under it is removed whichever application holds it.</p>
Parameter PROBEPREFIX = "%OcuProbe1810";

/// <p>The screen action route the percent-class access screen's row actions post to.</p>
Parameter ACTIONROUTE = "/api/ocupilot/screens/webapp.pctaccess/action";

/// <p>The composite id of the probe entry.</p>
ClassMethod ProbeId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PROBEAPP, "AllowClass", ..#PROBECLASS))
}

/// <p>The composite id of the entry <var>pRow</var> names, as the list rows carry it.</p>
ClassMethod KeyOf(pRow As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pRow.%Get("Name"), pRow.%Get("AllowType"), pRow.%Get("Class")))
}

/// <p>Every entry the instance holds, as the port's <code>LIST</code> answers them, in <var>pRows</var>.</p>
ClassMethod Entries(Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Kill tList
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.PctClassAccess", "LIST", .tList, "", .tRows, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject(tRows) Set pRows = tRows
    Quit tSC
}

/// <p>Records the entries held before the test and the stored governance policy, so the after-test can tell what
/// the test added and put the policy back.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ..PreparedEntries
    Kill ..PreparedPolicy
    Set tSC = ..Entries(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set ..PreparedEntries(..KeyOf(tRow)) = 1
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tPolicy
    Quit $$$OK
}

/// <p>Removes every probe entry, and every entry this test added to the probe application, then puts the stored policy
/// back as it was.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ..Entries(.tRows)
    If $$$ISOK(tSC) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("System") = 1 Continue
            Set tProbe = ($Extract(tRow.%Get("Class"), 1, $Length(..#PROBEPREFIX)) = ..#PROBEPREFIX)
            If 'tProbe && ((tRow.%Get("Name") '= ..#PROBEAPP) || $Data(..PreparedEntries(..KeyOf(tRow)))) Continue
            Kill tQuery
            Set tQuery("name") = ..KeyOf(tRow)
            Do ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
        }
    }
    Merge tPolicy = ..PreparedPolicy
    Set tRestoreSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy)
    Do $$$AssertStatusOK(tRestoreSC, "the stored governance policy is put back")
    Set tSeedSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSeedSC, "the turn and the proposals this test seeded are removed")
    Do $$$AssertEquals(+$Get(tRemaining), 0, "no proposal of the seeded turn survives")
    Quit $$$OK
}

/// <p>An absent application is refused 422 <code>PCTACCESS.APPLICATION</code> before the vendor.</p>
Method TestAbsentApplicationRefused()
{
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("/csp/ocuprobe1810", "AllowClass", ..#PROBECLASS))
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "an application the instance does not hold answers 422")
    Do $$$AssertEquals(tFault.code, "PCTACCESS.APPLICATION", "the refusal names the application")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.PctAccessError).#REASONAPPLICATION, "the refusal carries the published application sentence")
    Quit
}

/// <p>An application name with a trailing slash is refused 422 <code>PCTACCESS.APPLICATION</code> before any vendor call. The
/// delete goes through <class>OcuPilot.Test.PctAccessVendorFault</class>, so a slash name the shape let through would be counted
/// and the leg would go red.</p>
/// <p>Mutation (Rule 19): remove the <code>$Extract(tName, *) = "/"</code> clause from <class>OcuPilot.Port.PctAccessPort</class>'s
/// shape check -- this leg goes red.</p>
Method TestTrailingSlashApplicationRefused()
{
    Do ##class(OcuPilot.Test.PctAccessVendorFault).ResetVendorDeletes()
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("/csp/user/", "AllowClass", ..#PROBECLASS))
    Set tSC = ##class(OcuPilot.Test.PctAccessVendorFault).Invoke("WebApp.PctClassAccess", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "an application name ending in a slash answers 422")
    Do $$$AssertEquals(tFault.code, "PCTACCESS.APPLICATION", "the refusal names the application")
    Do $$$AssertEquals(##class(OcuPilot.Test.PctAccessVendorFault).VendorDeletes(), 0, "the slash-suffixed name never reaches the vendor")
    Quit
}

/// <p>A class without a percent sign, and an allow type other than AllowClass or AllowPrefix, are refused 422 on
/// their own field.</p>
/// <p>Mutation (Rule 19): drop the percent-sign check in <class>OcuPilot.Port.PctAccessPort</class>'s shape check -- the
/// class leg goes red, and the entry it would have written is the one the after-test removes.</p>
Method TestShapeRefused()
{
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PROBEAPP, "AllowClass", "Ens.Director"))
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "PUT", .tQuery, {"AllowAccess": true}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a class without a leading percent sign answers 422")
    Do $$$AssertEquals(tFault.code, "PCTACCESS.CLASS", "the refusal names the class")
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PROBEAPP, "AllowEverything", ..#PROBECLASS))
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "PUT", .tQuery, {"AllowAccess": true}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "an allow type other than AllowClass or AllowPrefix answers 422")
    Do $$$AssertEquals(tFault.code, "PCTACCESS.ALLOWTYPE", "the refusal names the allow type")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.PctAccessError).#REASONALLOWTYPE, "the allow type refusal carries its published sentence")
    Quit
}

/// <p>The composite id's first part is folded to lower case for a percent-class access entry, and the access type and the
/// class are kept as spelled.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.EntityRef</class>'s <method>NormalizedId</method>, change
/// <code>|| (tRule = ..#RULEFOLDFIRST)</code> to <code>|| 0</code>. The application part then keeps its case, and this
/// leg goes red on the spelling.</p>
Method TestFoldFirstFoldsOnlyTheApplication()
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("All-Applications", "AllowClass", "%Utility.Example"))
    Set tFolded = ##class(OcuPilot.Kernel.EntityRef).NormalizedId("pct-class-access", tId)
    Set tExpected = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("all-applications", "AllowClass", "%Utility.Example"))
    Do $$$AssertEquals(tFolded, tExpected, "the application is folded and the access type and class keep their spelling")
    Quit
}

/// <p>Each refusal code the percent-class access port and its save route answer carries its published sentence, read from
/// <class>OcuPilot.Api.PctAccessError</class>; a changed sentence reddens here.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Api.PctAccessError</class>, change the parameter
/// <code>REASONALLOWTYPE = "Choose Allow access ..."</code> to <code>"Pick Allow access ..."</code>. The allow type leg goes
/// red, which is this test's own leg.</p>
Method TestRefusalSentencesArePublished()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.ALLOWTYPE"), "Choose Allow access to a class or to a package of classes.", "the allow type sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.ID"), "Name an entry by its application, its allow type and its class.", "the id sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.NOTFOUND"), "The application holds no entry for that allow type and class.", "the not-found sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.CLASS"), "Name a class or package that begins with a percent sign, such as %Utility.Example.", "the class sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.APPLICATION"), "Name a web application this instance holds, or all applications.", "the application sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.EXISTS"), "This application already has an entry for that allow type and class, so it is not added again.", "the exists sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PCTACCESS.SYSTEM"), "This entry belongs to the instance and goes only with its application, so it cannot be deleted on its own.", "the system sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PRIVROUTINE.TYPE"), "This application is not a privileged routine application, so this endpoint does not read or change it.", "the privileged routine type sentence is the published one")
    Quit
}

/// <p>A created entry reads back through STATE with its access, and a delete removes it, after which STATE answers 404.</p>
Method TestCreateReadDelete()
{
    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "PUT", .tQuery, {"AllowAccess": true}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe entry is created")
    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the created entry is read back")
    Do $$$AssertEquals(tResult.AllowAccess, 1, "the read-back entry grants access")
    Do $$$AssertEquals(tResult.System, 0, "the probe entry is not the instance's own")
    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe entry is deleted")
    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "a deleted entry reads 404")
    Quit
}

/// <p>An instance-owned entry is refused its delete as <code>PCTACCESS.SYSTEM</code> before the vendor, and the list holds at
/// least one such entry to ask about. The delete goes through <class>OcuPilot.Test.PctAccessVendorFault</class>, which counts
/// a vendor <code>DELETE</code> instead of sending it.</p>
/// <p>Mutation (Rule 19, P11): in <class>OcuPilot.Port.PctAccessPort</class>'s <method>Invoke</method>, change
/// <code>If pType = "DELETE" {</code> to <code>If 0 {</code> and recompile it and the seam -- the leg goes red on the status
/// (200, not 409) and on the vendor count (one delete reached the vendor).</p>
Method TestSystemEntryRefused()
{
    Kill tList
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.PctClassAccess", "LIST", .tList, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the percent-class access list reads")
    Set tSystem = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.System = 1 Set tSystem = tRow Quit
    }
    Do $$$AssertTrue($IsObject(tSystem), "the instance lists at least one of its own entries")
    If '$IsObject(tSystem) Quit
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tSystem.Name, tSystem.AllowType, tSystem.Class))
    ; The seam counts the vendor's DELETE and never sends it, so a port that lets the delete through is seen, not run.
    Do ##class(OcuPilot.Test.PctAccessVendorFault).ResetVendorDeletes()
    Set tSC = ##class(OcuPilot.Test.PctAccessVendorFault).Invoke("WebApp.PctClassAccess", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.PctAccessVendorFault).VendorDeletes(), 0, "the refused delete never reaches the vendor")
    Do $$$AssertEquals(tHttp, 409, "a delete of an instance-owned entry answers 409")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "PCTACCESS.SYSTEM"), "the refusal names the system entry")
    Quit
}

/// <p>The first instance-owned entry the port's list holds, as its composite id in <var>pId</var>; the function answers 0 when
/// the instance lists none.</p>
ClassMethod FirstSystemEntry(Output pId As %String) As %Boolean
{
    Set pId = ""
    Set tSC = ..Entries(.tRows)
    If $$$ISERR(tSC) Quit 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("System") = 1 Set pId = ..KeyOf(tRow) Quit
    }
    Quit (pId '= "")
}

/// <p>Whether the port's list holds the entry <var>pId</var>.</p>
ClassMethod Holds(pId As %String) As %Boolean
{
    Set tSC = ..Entries(.tRows)
    If $$$ISERR(tSC) Quit 0
    Set tFound = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ..KeyOf(tRow) = pId Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Clicked or proposed, a delete of an instance-owned entry is refused with the <code>PCTACCESS.SYSTEM</code> sentence
/// before anything is sent: the screen action route and the agent's mint each answer 400 <code>TOOL.ARGUMENTS</code> whose
/// problem is that sentence, and the entry is still listed afterwards.</p>
/// <p>Mutation (Rule 19): drop the <code>System</code> branch in <class>OcuPilot.Screen.Tool.WebAppPctAccessDelete</class>'s
/// <method>StateDiff</method> -- the route and the mint no longer refuse at the diff and both legs go red; the port's own
/// refusal still stops the vendor.</p>
Method TestADeleteOfASystemEntryIsRefusedOnTheRouteAndTheMint()
{
    Set tHeld = ..FirstSystemEntry(.tId)
    Do $$$AssertTrue(tHeld, "the instance lists at least one of its own entries to ask about")
    If 'tHeld Quit
    Set tReason = ##class(OcuPilot.Api.PctAccessError).#REASONSYSTEM

    Set tRequest = {"action": "delete", "id": (tId)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#ACTIONROUTE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the delete is sent over the screen action route")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
    Do $$$AssertEquals(tStatus, 400, "the route refuses a delete of an instance-owned entry")
    Do $$$AssertTrue($IsObject(tBody) && (tBody.%Get("code") = "TOOL.ARGUMENTS"), "the route's refusal is the tool arguments refusal")
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("detail")) && (tBody.%Get("detail").%Get("problem") = tReason), "and its problem is the system sentence")
    Do $$$AssertTrue(..Holds(tId), "the entry is still listed after the route's refusal")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
    Set tArgs = {"Name": ($List(tParts, 1)), "AllowType": ($List(tParts, 2)), "Class": ($List(tParts, 3))}
    Set tSC = ..MintFor("OcuPilot.Screen.Tool.WebAppPctAccessDelete", tTurn, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the agent's delete of an instance-owned entry does not mint")
    Do $$$AssertEquals(tHttp, 400, "the mint refuses it as a tool arguments refusal")
    Do $$$AssertTrue($IsObject(tFault) && $IsObject(tFault.%Get("detail")) && (tFault.%Get("detail").%Get("problem") = tReason), "and its problem is the system sentence")
    Do $$$AssertTrue(..Holds(tId), "the entry is still listed after the mint's refusal")
    Quit
}

/// <p>The delete tool's state diff refuses an entry the instance marks as its own, before anything is sent, with the
/// port's published sentence and no row.</p>
/// <p>Mutation (Rule 19): drop the <code>System</code> branch in <class>OcuPilot.Screen.Tool.WebAppPctAccessDelete</class>'s
/// <method>StateDiff</method> -- the problem is empty and the row is shown, so this leg goes red.</p>
Method TestStateDiffRefusesASystemEntry()
{
    Set tFresh = {"AllowAccess": 1, "System": 1}
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.WebAppPctAccessDelete", "StateDiff", tFresh, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the state diff answers")
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Port.PctAccessPort).SystemReason(), "an instance-owned entry is refused with the system sentence")
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Api.PctAccessError).#REASONSYSTEM, "and that sentence is the PCTACCESS.SYSTEM reason")
    Do $$$AssertEquals(tRows.%Size(), 0, "and no removal row is shown for it")
    Quit
}

/// <p>The delete tool's state diff refuses an entry whose origin the instance did not report, with the origin-unknown
/// problem and no row.</p>
Method TestStateDiffRefusesAnUnknownOrigin()
{
    Set tFresh = {"AllowAccess": 1}
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.WebAppPctAccessDelete", "StateDiff", tFresh, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the state diff answers")
    Do $$$AssertEquals(tProblem, "this instance did not report whether that entry belongs to it, and an entry whose origin is unknown is not one to remove", "an entry with no origin is refused")
    Do $$$AssertEquals(tRows.%Size(), 0, "and no removal row is shown for it")
    Quit
}

/// <p>The agent's create and delete, each minted and then confirmed, read back as <code>matches</code> and
/// <code>notFound</code> respectively, with a non-empty snippet. The delete tool is disabled in the baseline, so this
/// test enables it in the stored policy for its own span only; <code>OnAfterOneTest</code> restores the policy.</p>
/// <p>The snippet is taken from the port's <code>Snippet</code> directly, not from a copy-out draft, which would close
/// the proposal.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Port.PctAccessPort</class>'s <method>State</method>, change
/// <code>If '$IsObject(tEntry)</code> to <code>If 0</code> -- an absent entry no longer reads 404, so the create's mint or
/// the delete's read-back goes red.</p>
Method TestAgentCreateAndDeleteMintConfirmAndReadBack()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    If $$$ISERR(tSC) Quit

    Set tCreateArgs = {"Name": (..#PROBEAPP), "AllowType": "AllowClass", "Class": (..#PROBECLASS), "AllowAccess": true}
    Set tSC = ..MintFor("OcuPilot.Screen.Tool.WebAppPctAccessCreate", tTurn, tCreateArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create mints")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the create confirms: " _ $Get(tCode))
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "the create reads back as matches")

    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSteps = ##class(OcuPilot.Port.PctAccessPort).Snippet("WebApp.PctClassAccess", "PUT", .tQuery, {"AllowAccess": true}, {})
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() > 0), "the create's snippet is non-empty")
    Kill tQuery
    Set tQuery("name") = ..ProbeId()
    Set tSteps = ##class(OcuPilot.Port.PctAccessPort).Snippet("WebApp.PctClassAccess", "DELETE", .tQuery, "", {})
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() > 0), "the delete's snippet is non-empty")

    Kill tPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do $$$AssertStatusOK(tSC, "the stored policy is cleared for this span")
    Kill tSettings
    Set tSettings("webapp.pctaccess.delete") = $Parameter("OcuPilot.Kernel.State.Policy", "VALUEENABLED")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Do $$$AssertStatusOK(tSC, "the delete tool is enabled for this span")

    Set tDeleteArgs = {"Name": (..#PROBEAPP), "AllowType": "AllowClass", "Class": (..#PROBECLASS)}
    Set tSC = ..MintFor("OcuPilot.Screen.Tool.WebAppPctAccessDelete", tTurn, tDeleteArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's delete mints")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the delete confirms: " _ $Get(tCode))
    Do $$$AssertEquals(..Verdict($Get(tResult)), "notFound", "the delete reads back as notFound")
    Quit
}

/// <p>The read-back verdict of a confirm's answer, or <code>""</code>.</p>
ClassMethod Verdict(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("readBack")) Quit ""
    Quit pBody.%Get("readBack").%Get("verdict")
}

/// <p>One mint of <var>pToolClass</var> over the turn <var>pTurn</var> with <var>pArgs</var>, the id taken from the
/// composite of the entry's three arguments, the way the agent's dispatch mints it.</p>
ClassMethod MintFor(pToolClass As %String, pTurn As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pArgs.%Get("Name"), pArgs.%Get("AllowType"), pArgs.%Get("Class")))
    Quit $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurn, pArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), tId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

}
