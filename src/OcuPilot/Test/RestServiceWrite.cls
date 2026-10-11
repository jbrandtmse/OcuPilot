/// <p>Pins Story 18.32's two writes end to end in <code>USER</code>, on both callers (AD-6, AD-10, AD-22, AD-53, AD-54,
/// AD-55, AD-58, AD-59): the agent's create minted and confirmed, with its three classes and its listed row and a
/// read-back that matches, refused at the mint and at the confirm for a name the namespace lists in any case, and an
/// existing implementation class keeping its code; the rules, the code saves' rules and OcuPilot's own code refused
/// before anything is stored or sent; a document the management API cannot build leaving no class; the delete through
/// the explorer's action and through the agent's proposal, the latter governed at the baseline, each removing the
/// specification and dispatch classes and keeping the implementation class; and a deployed service, a web application's
/// path and a name listed in another case refused with nothing deleted.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because it creates and deletes REST services named <code>OcuProbe1832*</code> and a probe web
/// application under <code>/api/ocuprobe1832</code>. The stored governance policy is put back after every test, and every
/// probe object is removed and read back gone.</p>
Class OcuPilot.Test.RestServiceWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RestServiceProbe";

Parameter NAMESPACE = "USER";

/// <p>The scope a confirm is sent from to pin that it writes where the proposal read.</p>
Parameter OTHERSCOPE = "HSCUSTOM";

Parameter CREATE = "webapp.restapis.create";

Parameter DELETE = "webapp.restapis.delete";

/// <p>The explorer's action route, relative to the API base.</p>
Parameter ACTIONPATH = "/screens/webapp.restapis/action";

/// <p>The probe web application's path.</p>
Parameter APPLICATION = "/api/ocuprobe1832c";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

/// <p>The probe objects the instance held before the test.</p>
Property PreparedFacts As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, $ClassName() _ " creates and deletes REST services and a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE)
    Quit $$$OK
}

/// <p>The policy and the probes are put back and read back, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe service, class and web application is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#OTHERSCOPE), "and none is left in " _ ..#OTHERSCOPE)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining", ..#NAMESPACE) + $ListLength($ClassMethod(..#PROBE, "ClassNames", ..#OTHERSCOPE)), 0, "in either")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE), ..PreparedFacts, "the probe state reads as before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The agent's call of tool <var>pTool</var> with <var>pInput</var>, scoped to <var>pNamespace</var>, through the
/// dispatcher inside a completed turn: <var>pContent</var> is the tool result, <var>pIsError</var> whether it is an
/// error and <var>pProposal</var> the result parsed (<class>OcuPilot.Test.ExplorerWrite</class>'s).</p>
Method Dispatch(pTool As %String, pInput As %DynamicObject, Output pContent, Output pIsError, Output pProposal, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Quit tWrite.DispatchFor(pTool, pNamespace, pInput, .pContent, .pIsError, .pProposal)
}

/// <p>The create's input for <var>pName</var>, with <var>pDocument</var> (<method>OcuPilot.Test.RestServiceProbe.Document</method>
/// when none is given) and the agent's own words.</p>
ClassMethod CreateInput(pName As %String, pDocument As %DynamicObject = "") As %DynamicObject
{
    If '$IsObject(pDocument) Set pDocument = $ClassMethod(..#PROBE, "Document")
    Quit {"Name": (pName), "Document": (pDocument), "rationale": "a probe create", "expectedImpact": "the probe service is held", "reverse": "delete the probe service"}
}

/// <p>The delete's input for <var>pName</var>.</p>
ClassMethod DeleteInput(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "rationale": "a probe delete", "expectedImpact": "the probe service is gone"}
}

/// <p>Enable the delete's governance key through its stored setting.</p>
ClassMethod EnableDelete()
{
    Kill tSettings
    Set tSettings(..#DELETE) = "enabled"
    Do ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The explorer's action <var>pAction</var> on <var>pId</var> over the wire, scoped to <parameter>NAMESPACE</parameter>.</p>
ClassMethod Act(pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody)
{
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH _ "?ns=" _ ..#NAMESPACE, .pStatus, .pBody, {"action": (pAction), "id": (pId)}.%ToJSON())
}

/// <p>The member <var>pMember</var> of the parsed result <var>pBody</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pContent As %String) As %String
{
    Quit ##class(OcuPilot.Test.ExplorerCreateFlow).CodeOf(pContent)
}

/// <p>Confirm <var>pProposal</var> in process as the running account, scoped to <var>pScope</var>.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String, pScope As %String = {..#NAMESPACE}) As %Status
{
    Quit ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(pScope, pProposal, .pResult, .pHttp, .pCode)
}

/// <p>The three classes of <var>pName</var> in <parameter>NAMESPACE</parameter> as three digits: specification,
/// dispatch, implementation.</p>
ClassMethod Classes(pName As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, pName)
}

/// <p>AC C1, the matrix's Create row: the agent's create of <code>OcuProbe1832A</code> is minted as a card showing the
/// whole formatted document, stores nothing and writes nothing; confirmed from another namespace's scope, it builds the
/// three classes in the namespace the proposal read, lists the service, and reads back matching, marked (AD-15).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MgmntPort.Build</method> hand the vendor <code>{}</code> in place of
/// the document -- the vendor cannot build it, every seed and the confirm answer 422 <code>RESTSERVICE.BUILD</code> and
/// this goes red; empty <method>OcuPilot.Screen.Tool.RestServiceWrite.PortQuery</method> -- the confirm builds in
/// <parameter>OTHERSCOPE</parameter> and this goes red.</p>
Method TestTheAgentsCreateConfirmsAndTheServiceIsListed()
{
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832A"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the create is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id, "rest-service|OcuProbe1832A", "its target is the REST service, named as typed")
    Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.changed.%Get(0).kind _ " " _ tProposal.changed.%Get(0).line _ " [" _ tProposal.changed.%Get(0).before _ "]", "1 lines 1 []", "its card is one lines row from line 1 with nothing before")
    Do $$$AssertEquals(tProposal.changed.%Get(0).after, $ClassMethod("OcuPilot.Screen.Tool.RestServiceCreateMint", "FormattedDocument", $ClassMethod(..#PROBE, "Document")) _ $Char(10), "holding the whole document, formatted")
    Set tShown = tProposal.changed.%Get(0).after
    Do $$$AssertEquals(##class(%DynamicAbstractObject).%FromJSON(tShown).%ToJSON(), $ClassMethod(..#PROBE, "Document").%ToJSON(), "which parses back to the document the agent sent")
    Do $$$AssertTrue($Length(tShown, $Char(10)) > 2, "over several lines, not the compact text")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the proposal is stored")
    Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "0 RESTSERVICE.CREATE.COMPILES", "it is not destructive and its consequence is the compile")
    Do $$$AssertTrue(($Get(tValues("requiredPairs")) [ "%Development:USE") && ($Get(tValues("requiredPairs")) [ "%DB_USER:WRITE"), "it requires the code editors' resource and WRITE on the routines database: " _ $Get(tValues("requiredPairs")))
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "000", "nothing is built before Confirm")

    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertStatusOK(tSC, "and confirms from " _ ..#OTHERSCOPE _ "'s scope: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ "|" _ tResult.action _ "|" _ tResult.auditMarked _ "|" _ tResult.readBack.verdict, "confirmed|created|1|matches", "creating it, marked (AD-15) and read back matching")
    Do $$$AssertEquals(..Classes("OcuProbe1832A") _ " " _ $ClassMethod(..#PROBE, "HasClass", ..#OTHERSCOPE, "OcuProbe1832A.spec"), "111 0", "the three classes exist in the namespace the proposal read, and not in the confirm's scope")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Listed", ..#NAMESPACE, "OcuProbe1832A") && $ListFind($ClassMethod(..#PROBE, "Services", ..#NAMESPACE), "OcuProbe1832A"), "and the explorer lists the service")
}

/// <p>The matrix's Delete row and C1's second half: at the baseline the dispatcher refuses the agent's delete (C4); once
/// its key is enabled, the card names the package as removed, and the confirmed delete removes the specification and
/// dispatch classes, keeps the implementation class, and reads back gone.</p>
/// <p>Mutation (Rule 19): set <code>webapp.restapis.delete</code> to <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the dispatcher mints and this goes red; make
/// <method>OcuPilot.Port.MgmntPort.Service</method> skip the vendor delete -- the classes survive and this goes red.</p>
Method TestTheAgentsDeleteIsGovernedThenConfirmedAndKeepsTheImplementation()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832A"), "a probe service is built")
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "111", "with its three classes")
    Set tSC = ..Dispatch(..#DELETE, ..DeleteInput("OcuProbe1832A"), .tRefused, .tIsError, .tAnswer)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tRefused)) = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), "at the baseline the dispatcher refuses the agent's delete: " _ $Get(tRefused))
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "111", "with nothing deleted")

    Do ..EnableDelete()
    Set tSC = ..Dispatch(..#DELETE, ..DeleteInput("OcuProbe1832A"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "once its key is enabled the delete is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id _ "|" _ tProposal.changed.%ToJSON(), "rest-service|OcuProbe1832A|[{""field"":""Name"",""before"":""OcuProbe1832A"",""after"":"""",""removed"":true}]", "its card names the package, removed")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("destructive")), 1, "and is destructive")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertStatusOK(tSC, "and its confirm deletes the service from " _ ..#OTHERSCOPE _ "'s scope: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.action _ "|" _ tResult.auditMarked _ "|" _ tResult.readBack.verdict, "deleted|1|notFound", "marked (AD-15) and read back gone")
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "001", "the specification and dispatch classes are gone and the implementation class is kept")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Listed", ..#NAMESPACE, "OcuProbe1832A"), 0, "and the explorer no longer lists the service")
}

/// <p>The explorer's Delete over the wire removes the service and answers the change: the action <code>deleted</code>, the
/// REST service target and a read-back that finds it gone, with the implementation class kept.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MgmntPort.Service</method> skip the vendor delete -- the classes
/// survive and this goes red.</p>
Method TestTheScreensDeleteRemovesTheServiceOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832A"), "a probe service is built")
    Do ..Act("delete", "OcuProbe1832A", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the Delete answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.action _ "|" _ tBody.target.type _ "|" _ tBody.target.id _ "|" _ tBody.readBack.verdict, "deleted|rest-service|OcuProbe1832A|notFound", "naming the removed service, read back gone")
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "001", "its specification and dispatch classes are gone, its implementation class is kept")
}

/// <p>The matrix's Delete refused rows: a service a web application dispatches to, in the case it is listed and in
/// another, and a web application's path are each 409 <code>RESTSERVICE.DEPLOYED</code> on the screen and at the agent's
/// mint with nothing deleted; a name listed in another case is 404 <code>PORT.NOTFOUND</code>; and once the web application
/// is gone the same service deletes.</p>
/// <p>Mutation (Rule 19): drop the deployed check from <method>OcuPilot.Port.MgmntPort.Resolved</method> -- the deployed
/// legs delete the service and go red.</p>
Method TestADeployedServiceAndAWebApplicationPathAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832C"), "a probe service is built")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832D"), "and a second one, never deployed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Deploy", ..#NAMESPACE, "OcuProbe1832C", ..#APPLICATION), "a web application dispatches to the first")
    Set tDeployed = ##class(OcuPilot.Api.RestServiceError).#DEPLOYED
    For tId = "OcuProbe1832C", "ocuprobe1832c", ..#APPLICATION {
        Do ..Act("delete", tId, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ "|" _ tBody.reason, 1: ""), "409 " _ tDeployed _ "|" _ ##class(OcuPilot.Api.RestServiceError).#REASONDEPLOYED, tId _ ": the Delete is refused with the published sentence")
    }
    Do ..Act("delete", "ocuprobe1832d", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code, 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a service listed in another case is not found")
    Do ..EnableDelete()
    Set tSC = ..Dispatch(..#DELETE, ..DeleteInput("OcuProbe1832C"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = tDeployed), "the agent's delete of the deployed service is refused at the mint: " _ $Extract($Get(tContent), 1, 200))
    Do $$$AssertEquals(..Classes("OcuProbe1832C") _ " " _ ..Classes("OcuProbe1832D"), "111 111", "nothing was deleted")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "the probes are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832C"), "the service is built again, deployed to nothing")
    Do ..Act("delete", "OcuProbe1832C", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and its Delete is accepted")
}

/// <p>A delete minted for a service nothing deploys is refused at the confirm as a changed target once a web application
/// has been made to dispatch to it, and the service stands (C3: no vendor delete is sent).</p>
/// <p>Mutation (Rule 19): drop the dispatch-class comparison from <method>OcuPilot.Port.MgmntPort.Resolved</method> -- the
/// confirm's re-read and the port's delete both pass the deployed service, the service is deleted and this goes red.</p>
Method TestAServiceDeployedAfterTheMintIsNotDeleted()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832C"), "a probe service is built")
    Do ..EnableDelete()
    Set tSC = ..Dispatch(..#DELETE, ..DeleteInput("OcuProbe1832C"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the delete is minted while nothing deploys it: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Deploy", ..#NAMESPACE, "OcuProbe1832C", ..#APPLICATION), "a web application then dispatches to it")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertEquals(..Classes("OcuProbe1832C"), "111", "and the service stands")
}

/// <p>The matrix's Rules row: a package that is no package or holds a percent sign, a document sent as text, one whose
/// <code>swagger</code> is not 2.0 or is absent, and one whose formatted text is over one card are each refused by the
/// agent's call 400 <code>TOOL.ARGUMENTS</code>, with no proposal stored and nothing built.</p>
/// <p>Mutation (Rule 19): drop the card-width check from <method>OcuPilot.Screen.Tool.RestServiceCreateMint.Mint</method>
/// -- the wide leg is minted and goes red.</p>
Method TestTheRulesRefuseTheAgentBeforeAnythingIsStored()
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATE)
    Do $$$AssertTrue(tBefore >= 0, "the proposal count reads")
    Set tWide = $ClassMethod(..#PROBE, "Document")
    Do tWide.%Set("description", $Translate($Justify("", 31000), " ", "x"))
    Set tAsText = $ClassMethod(..#PROBE, "Document").%ToJSON()
    Kill tInputs
    Set tInputs(1) = ..CreateInput("Bad Name")
    Set tInputs(2) = ..CreateInput("%OcuProbe1832X")
    Set tInputs(3) = ..CreateInput("OcuProbe1832_X")
    Set tInputs(4) = {"Name": "OcuProbe1832X", "Document": (tAsText)}
    Set tInputs(5) = ..CreateInput("OcuProbe1832X", {"swagger": "3.0", "paths": {}})
    Set tInputs(6) = ..CreateInput("OcuProbe1832X", {"info": {"title": "none"}})
    Set tInputs(7) = ..CreateInput("OcuProbe1832X", tWide)
    Set tInputs(8) = {"Name": "OcuProbe1832X"}
    For tI = 1:1:8 {
        Set tSC = ..Dispatch(..#CREATE, tInputs(tI), .tContent, .tIsError, .tProposal)
        Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS"), "input " _ tI _ " is refused 400 TOOL.ARGUMENTS: " _ $Extract($Get(tContent), 1, 200))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATE), tBefore, "none of them stored a proposal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE), ..PreparedFacts, "and nothing was built")
}

/// <p>A name the namespace lists in another case is refused at the mint; a free name is minted, and refused at the confirm
/// as a changed target once another session has built the same package in another case, whose three classes stand.</p>
/// <p>Mutation (Rule 19): make the state read exact (<code>Listed</code> with <code>pExact</code> 1 in
/// <method>OcuPilot.Port.MgmntPort.Service</method>) -- the mint accepts the other case, the confirm no longer sees the
/// name taken and this goes red.</p>
Method TestANameListedInAnyCaseIsRefusedAtTheMintAndTheConfirm()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832A"), "a probe service is built")
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("ocuprobe1832a"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS") && ($Get(tContent) [ "already present"), "a create of the name in another case is refused at the mint: " _ $Extract($Get(tContent), 1, 240))
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832B"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "a free name is minted: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OCUPROBE1832B", $ClassMethod(..#PROBE, "Document", "other")), "another session builds it in another case")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target")
    Do $$$AssertEquals(..Classes("OCUPROBE1832B"), "111", "and the other session's service stands")
}

/// <p>C3's build failure: a 2.0 document the management API cannot build passes the rules and the mint, and its confirm
/// is refused 422 <code>RESTSERVICE.BUILD</code> with no class left behind.</p>
/// <p>Mutation (Rule 19): answer success for a vendor 404 in <method>OcuPilot.Port.MgmntPort.Outcome</method> -- the
/// confirm reads created and this goes red.</p>
Method TestABuildFailureLeavesNoClassBehind()
{
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832B", $ClassMethod(..#PROBE, "Unbuildable")), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the document passes the rules and is minted: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "422 " _ ##class(OcuPilot.Api.RestServiceError).#BUILD, "the confirm is refused 422 RESTSERVICE.BUILD")
    Do $$$AssertEquals(..Classes("OcuProbe1832B"), "000", "and no class is left")
}

/// <p>C2: an agent create in <code>%SYS</code>, of a package stored in another database, and of a package beginning with
/// <code>OcuPilot</code> in any case, is refused at the mint with nothing stored (400 <code>TOOL.ARGUMENTS</code>, or 403
/// <code>PROHIBITED.OCUPILOTCODE</code>); the confirm refuses stored arguments naming <code>%SYS</code>, and the
/// prohibited set refuses OcuPilot's own package on either tool, from either caller's stored payload.</p>
/// <p>Mutation (Rule 19): remove the <code>rest-service</code> arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the prohibited-set legs go red; make
/// <method>OcuPilot.Screen.Tool.RestServiceCreate.ConfirmProblem</method> answer <code>""</code> -- the stored-arguments
/// leg goes red; drop <code>impl</code> from <parameter>OcuPilot.Screen.Tool.RestServiceCreate.CLASSPARTS</parameter> --
/// the roster leg of <class>OcuPilot.Test.RestServiceDescriptor</class> goes red.</p>
Method TestTheCodeRulesAndOcuPilotsOwnCodeAreRefusedOnBothTools()
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATE)
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832C"), .tContent, .tIsError, .tProposal, "%SYS")
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS") && ($Get(tContent) [ "in %SYS"), "a create in %SYS is refused at the mint: " _ $Extract($Get(tContent), 1, 240))
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("Ens.OcuProbe1832C"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS") && ($Get(tContent) [ "database ENSLIB"), "a package stored in another database is refused, naming it: " _ $Extract($Get(tContent), 1, 240))
    Set tOwn = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE
    For tName = "OcuPilotProbe1832", "ocupilot.probe1832", "OCUPILOTX" {
        Set tSC = ..Dispatch(..#CREATE, ..CreateInput(tName), .tContent, .tIsError, .tProposal)
        Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = tOwn), tName _ " is refused " _ tOwn _ " at the mint: " _ $Extract($Get(tContent), 1, 240))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATE), tBefore, "no refusal stored a proposal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE), ..PreparedFacts, "and nothing was built")
    Set tSC = ##class(OcuPilot.Screen.Tool.RestServiceCreate).ConfirmProblem("OcuProbe1832C", {"Namespace": "%SYS"}, .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "in %SYS"), "the confirm refuses stored arguments naming %SYS: " _ $Get(tProblem))
    Set tSC = ##class(OcuPilot.Screen.Tool.RestServiceCreate).ConfirmProblem("OcuProbe1832C", "", .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "could not be read"), "and stored arguments that are not an object: " _ $Get(tProblem))
    For tCase = $ListBuild("webapp.restapis.create", "OcuPilotProbe1832", 1), $ListBuild("webapp.restapis.create", "ocupilot.probe1832", 1), $ListBuild("webapp.restapis.delete", "OCUPILOTX", 1), $ListBuild("webapp.restapis.delete", "OcuProbe1832A", 0) {
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("rest-service", ..#NAMESPACE, $List(tCase, 2), .tRef)
        Set tPayload = {"Name": ($List(tCase, 2)), "Document": {"swagger": "2.0"}, "Namespace": (..#NAMESPACE)}.%ToJSON()
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($List(tCase, 1), tRef, tPayload, "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for " _ $List(tCase, 1) _ " " _ $List(tCase, 2))
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 3): "1 " _ tOwn, 1: "0 "), $List(tCase, 1) _ " " _ $List(tCase, 2) _ $Select($List(tCase, 3): " is refused", 1: " is not"))
    }
}

/// <p>An implementation class that exists keeps its code (AD-53): the create of a package whose <code>.impl</code> a
/// delete kept builds the specification and dispatch classes and leaves the body the author wrote in an operation's
/// method as the author left it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MgmntPort.Service</method> delete the <code>.impl</code> class after
/// the vendor's delete -- the kept-implementation leg goes red.</p>
Method TestAnExistingImplementationKeepsItsCode()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832A"), "a probe service is built")
    Set tSC = $ClassMethod(..#PROBE, "SetMethodBody", ..#NAMESPACE, "OcuProbe1832A.impl", "ping", "    Quit ""kept by the author""")
    Do $$$AssertStatusOK(tSC, "the author's code is saved in the operation's method of the implementation class")
    Do ..EnableDelete()
    Set tSC = ..Dispatch(..#DELETE, ..DeleteInput("OcuProbe1832A"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the delete is minted: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "001", "the delete keeps the implementation class")
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832A"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the create is minted: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals(..Classes("OcuProbe1832A"), "111", "the three classes exist")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "MethodBody", ..#NAMESPACE, "OcuProbe1832A.impl", "ping"), "Quit ""kept by the author""", "and the implementation class still holds the author's code")
}

/// <p>AD-59: the copy-out draft of the agent's create renders one <code>curl</code> step posting the document to the
/// management API's route for the namespace and package the proposal read, closes the proposal as a draft, and builds
/// nothing.</p>
Method TestTheCopyOutDraftNamesTheCreate()
{
    Set tSC = ..Dispatch(..#CREATE, ..CreateInput("OcuProbe1832E"), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the agent's create mints: " _ $Extract($Get(tContent), 1, 240))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, $Username, "https://draft.example:52773", .tAnswer, .tDraftHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the draft is taken: " _ $Get(tCode))
    If '$IsObject($Get(tAnswer)) Quit
    Set tText = tAnswer.draft.steps.%Get(0).text
    Do $$$AssertEquals(tAnswer.state _ "|" _ tAnswer.closedReason _ "|" _ tAnswer.draft.steps.%Get(0).kind, "canceled|draft|rest", "a rest draft that closes the proposal")
    Do $$$AssertTrue((tText [ "-X POST 'https://draft.example:52773/api/mgmnt/v2/USER/OcuProbe1832E'") && (tText [ "-d '{""swagger"":""2.0"""), "posting the document to the namespace and package: " _ tText)
    Do $$$AssertEquals(..Classes("OcuProbe1832E"), "000", "and nothing is built")
}

}
