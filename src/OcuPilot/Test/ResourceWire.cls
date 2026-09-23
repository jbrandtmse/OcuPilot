/// <p>The resource routes and the resource tools against the instance itself (AD-4, AD-10, AD-12,
/// AD-27, AD-39, AD-55): the routes' envelopes, a create then an edit that keeps the field it did
/// not send, a public permission of none created, cleared and kept through AD-27's fallback, a write
/// the vendor did not apply, an agent delete confirmed through the real port, and a system resource
/// refused at the mint.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the screen's own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> --
/// because the legs create, change and delete real resources. <method>OnBeforeAllTests</method>
/// refuses anywhere it does not, and refuses to adopt a probe name the instance already holds;
/// <method>OnAfterOneTest</method> deletes the probe resources by exact name, never by prefix.</p>
Class OcuPilot.Test.ResourceWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/resources/form";

Parameter NAMEPATH = "/resources/name";

Parameter CREATEPATH = "/resources";

/// <p>The edit route; <method>EditPath</method> fills its one segment.</p>
Parameter EDITPATH = "/resources/:id";

Parameter LIST = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.ResourceDelete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The probe resources: one created and edited over the routes, one kept private through the
/// fallback, and one the agent's delete removes.</p>
Parameter PROBE = "OcuPilotProbeResourceWire";

Parameter PRIVATEPROBE = "OcuPilotProbeResourcePrivate";

Parameter DELETEPROBE = "OcuPilotProbeResourceGone";

/// <p>A system resource every instance holds, whose vendor <code>AllowDelete</code> is false.</p>
Parameter SYSTEMRESOURCE = "%Admin_Secure";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ResourceWire creates and deletes resources on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If ..Exists(..#PROBE) || ..Exists(..#PRIVATEPROBE) || ..Exists(..#DELETEPROBE) {
        Quit $$$ERROR($$$GeneralError, "a probe resource of OcuPilot.Test.ResourceWire already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ..Remove(..#PROBE)
    Do ..Remove(..#PRIVATEPROBE)
    Do ..Remove(..#DELETEPROBE)
    Do $$$AssertEquals(..Exists(..#PROBE) + ..Exists(..#PRIVATEPROBE) + ..Exists(..#DELETEPROBE), 0, "the probe resources are gone")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AD-12, AD-39: the two reads, the create and the edit each answer exactly one JSON envelope over
/// a real HTTP request; the form read carries the letter rules and, with a name, the resource and its
/// privileged mark; a create naming nothing is refused on its own envelope code, and an edit of a
/// resource the instance does not hold is 404 with its own.</p>
/// <p>Mutation: render <method>OcuPilot.Area.Permissions.ResourceSave.RenderViolations</method> with
/// <code>ROLEVALIDATION</code> -> the envelope-code assertion goes red.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#FORMPATH _ "?name=" _ ..Query(..#SYSTEMRESOURCE), tBase _ ..#NAMEPATH _ "?name=" _ ..#PROBE {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..Query(..#SYSTEMRESOURCE), .tStatus, .tBody)
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).ResourceViolationCodes()), "the form read carries one rule per resource code")
        Do $$$AssertEquals(tBody.%Get("letterRules").%Get("letters"), "RWU", "and the letter rules")
        Do $$$AssertEquals(tBody.%Get("resource").%Get("privileged"), 1, "and the named resource, marked privileged")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..Query(..#SYSTEMRESOURCE), .tStatus, .tBody)
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("taken") _ " " _ tBody.%Get("privileged"), "1 1", "the name look-up answers a held administrative name as taken and privileged")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertEquals(tStatus, 422, "a create naming nothing is refused at 422")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#RESOURCEVALIDATION, "with the create's own envelope code")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(..#PROBE), tUser, tPassword, .tStatus, .tBody, .tHeaders, "{""Description"":""x""}", "application/json")
    Do $$$AssertEquals(tStatus, 404, "an edit of a resource the instance does not hold is 404")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#RESOURCENAMEABSENT, "with the absent code")
}

/// <p>AC3, AC4 over the wire: <code>POST /resources</code> creates the resource with the sent
/// values, and <code>PUT /resources/:id</code> with a Description alone keeps the public permission
/// the instance holds.</p>
/// <p>Mutation: remove <code>Security.Resource/PUT</code> from
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> -> the port answers 501 and this goes
/// red.</p>
Method TestACreateThenAnEditKeepsTheOtherField()
{
    Set tRequest = {"Name": (..#PROBE), "Description": "OcuPilot wire probe", "PublicPermission": "RU"}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    Do $$$AssertEquals(..Read(..#PROBE), "OcuPilot wire probe|RU", "the instance holds the sent values")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath($ZConvert(..#PROBE, "L")), .tStatus, .tBody, "{""Description"":""edited""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200, the name in another case")
    Do $$$AssertEquals(..Read(..#PROBE), "edited|RU", "the description changed and the public permission kept")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a second create of the name is refused")
    Do $$$AssertEquals(..Read(..#PROBE), "edited|RU", "and the resource was not rewritten")
}

/// <p>P1, AD-27's fallback: a public permission of none, which the admin API refuses on every
/// encoding, reaches the instance through each route the editor uses -- a create, a clear of a
/// held permission, and a description edit of a private resource, whose merged body carries the
/// empty permission (AD-4). Each leg starts from a resource made directly, so each fails on its own
/// when the fallback is removed.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Port.AdminPort.CLASSCOMPLETEDTYPES</parameter> -> the
/// vendor refuses the empty permission and all three legs go red.</p>
Method TestAPublicPermissionOfNoneIsCreatedClearedAndKept()
{
    Set tRequest = {"Name": (..#PRIVATEPROBE), "Description": "OcuPilot private probe", "PublicPermission": ""}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "create-private: a resource with no public permission is created")
    Do $$$AssertEquals(..Read(..#PRIVATEPROBE), "OcuPilot private probe|", "create-private: and holds none")

    Set tPath = ..EditPath(..#PRIVATEPROBE)
    Do ..Remove(..#PRIVATEPROBE)
    Do $$$AssertStatusOK(..Make(..#PRIVATEPROBE, "R"), "clear: a resource holding Read is made")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", tPath, .tStatus, .tBody, "{""PublicPermission"":""""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "clear: the public permission is cleared")
    Do $$$AssertEquals(..Read(..#PRIVATEPROBE), "OcuPilot probe|", "clear: and reads none")

    Do ..Remove(..#PRIVATEPROBE)
    Do $$$AssertStatusOK(..Make(..#PRIVATEPROBE, ""), "edit-private: a private resource is made")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", tPath, .tStatus, .tBody, "{""Description"":""still private""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "edit-private: a description edit of a private resource is applied")
    Do $$$AssertEquals(..Read(..#PRIVATEPROBE), "still private|", "edit-private: and it stays private")
}

/// <p>AD-27, AC5: a vendor <code>PUT</code> that answers 200 without storing the sent value -- a
/// description longer than the vendor stores -- fails <code>PORT.NOTAPPLIED</code> through the real
/// port; public-permission letters the vendor stores in its own order read back as applied.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Port.AdminPort.VERIFIEDWRITES</parameter> -> the write
/// reads as made and this goes red; compare <code>PublicPermission</code> verbatim in
/// <method>OcuPilot.Port.AdminPort.SameValue</method> -> the letter-order leg goes red.</p>
Method TestARealWriteTheVendorDidNotApplyFailsNotApplied()
{
    Do $$$AssertStatusOK(..Make(..#PROBE, "R"), "a probe resource is created")
    Kill tQuery
    Set tQuery("name") = ..#PROBE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "PUT", .tQuery, {"Description": ($Translate($Justify("", 300), " ", "x"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a description the vendor did not store is not a success")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, "as PORT.NOTAPPLIED")
    Do $$$AssertEquals(..Read(..#PROBE), "OcuPilot probe|R", "and the resource is unchanged")

    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "PUT", .tQuery, {"PublicPermission": "UR"}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "letters the vendor stores in its own order read back as sent: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    Do $$$AssertEquals(..Read(..#PROBE), "OcuPilot probe|RU", "and the resource holds both letters")
}

/// <p>AC5: <code>permissions.resources.delete</code> minted and confirmed through the shipped mint,
/// confirm and port removes the resource; and a system resource is refused at the mint through the
/// real port's list.</p>
/// <p>Mutation: remove <code>Security.Resource/DELETE</code> from
/// <parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter> -> the bodyless delete is refused
/// and this goes red.</p>
Method TestAnAgentDeleteThroughTheRealPortRemovesTheResource()
{
    Do $$$AssertStatusOK(..Make(..#DELETEPROBE, "R"), "a probe resource is created")
    Set tSC = ..Mint(..#DELETEPROBE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted against the live resource")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "answering the deleted action")
    Do $$$AssertEquals(..Exists(..#DELETEPROBE), 0, "and the instance no longer holds the resource")

    Set tSC = ..Mint(..#SYSTEMRESOURCE, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a system resource's delete is refused at the mint")
    Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#RESOURCENAMESYSTEM), "with the system-resource sentence: " _ tProblem)
    Do $$$AssertEquals(..Exists(..#SYSTEMRESOURCE), 1, "and it is still there")
}

/// <p>Mint one delete of <var>pName</var> through the shipped mint and port.</p>
Method Mint(pName As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tTool = ..#DELETETOOL
    Set tArgs = {"Name": (pName)}
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pName, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
}

/// <p><parameter>EDITPATH</parameter> for resource <var>pName</var>, its segment encoded by the one
/// shared encoder (AD-13).</p>
ClassMethod EditPath(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p><var>pName</var> percent-encoded once, for a query string.</p>
ClassMethod Query(pName As %String) As %String
{
    Quit $ZConvert(pName, "O", "URL")
}

/// <p>Resource <var>pName</var> as <code>description|letters</code>, read through
/// <class>Security.Resources</class>, or <code>""</code>.</p>
ClassMethod Read(pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Resources).Get(pName, .tProps)) Set tValue = $Get(tProps("Description")) _ "|" _ $Get(tProps("PublicPermission"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Create resource <var>pName</var> with <var>pPublic</var> directly, for a leg that needs one to
/// exist.</p>
ClassMethod Make(pName As %String, pPublic As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Resources).Create(pName, "OcuPilot probe", pPublic)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds a resource named <var>pName</var>, in any case.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Resources).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Delete the resource named exactly <var>pName</var>, if there is one.</p>
ClassMethod Remove(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(pName) Do ##class(Security.Resources).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
