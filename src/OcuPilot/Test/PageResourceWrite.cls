/// <p>Pins Story 21.37's Page resources writes against the instance's real classic-page store (AD-8, AD-15, AD-29, AD-34, AD-44, AD-51, AD-53, AD-58, AD-59,
/// AD-64): the person's Change and Clear over HTTP as a principal holding exactly <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>, and the
/// agent's <code>permissions.pageresources.assign</code> and <code>.clear</code> through the dispatcher and the confirm. Each stores under the normalized
/// class name, reads back, and records one <code>SecurityChange</code> with the resource before and after, the agent's also marked; a refused write stores and
/// records nothing; a confirm after the page moved writes nothing; the gate reads a page's resource on the next call; each tool renders its script; and a
/// caller short of either pair is refused naming it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: the class
/// assigns custom resources to classic portal pages and creates two resources and three accounts. <method>OnBeforeAllTests</method> refuses anywhere it does
/// not, records every page it touches, <method>OnAfterOneTest</method> restores each, failing the test when a page does not read its recorded value, and
/// <method>OnAfterAllTests</method> deletes the accounts and resources. Assertions are on the rows it plants, never on the store's size.</p>
Class OcuPilot.Test.PageResourceWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.PageResourceFixture";

Parameter PORT = "OcuPilot.Port.PortalResourcePort";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter LISTSCREEN = "permissions.pageresources";

Parameter ASSIGN = "permissions.pageresources.assign";

Parameter CLEAR = "permissions.pageresources.clear";

/// <p>The pages the probe is taken from: the first the vendor resolves to a portal page and no screen declares.</p>
Parameter CANDIDATES = "%CSP.UI.Portal.About,%UnitTest.Portal.Index";

/// <p>A page one built screen declares, the Resources list's, and that screen's identifier.</p>
Parameter GATEPAGE = "%CSP.UI.Portal.Resources";

Parameter GATESCREEN = "permissions.resources";

/// <p>The two resources the class creates and assigns.</p>
Parameter FIRST = "OcuProbe2137ResA";

Parameter SECOND = "OcuProbe2137ResB";

Parameter ORIGIN = "https://draft.example:52773";

Property PreparedPassword As %String;

Property PreparedProbe As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>Each page's custom resource as it stood before the class ran, keyed by page.</p>
Property PreparedPages [ MultiDimensional ];

/// <p>The seeded turns' keys, so their ledger rows are removed after the test.</p>
Property PreparedTurns As %List;

Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedProbe = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedTurns = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PageResourceWrite assigns custom resources to classic portal pages and creates IRIS users and resources, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was assigned or created.")
    }
    For tI = 1:1:$Length(..#CANDIDATES, ",") {
        Set tCandidate = $Piece(..#CANDIDATES, ",", tI)
        Set tSC = $ClassMethod(..#PORT, "Normalized", tCandidate, .tNormalized)
        If $$$ISERR(tSC) Quit
        If tNormalized = "" Continue
        Set tDeclaring = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(tNormalized, .tResolved)
        If tResolved && ($ListLength(tDeclaring) = 0) {
            Set ..PreparedProbe = tNormalized
            Quit
        }
    }
    If $$$ISERR($Get(tSC, $$$OK)) Quit tSC
    If ..PreparedProbe = "" Quit $$$ERROR($$$GeneralError, "none of the candidate pages (" _ ..#CANDIDATES _ ") resolves to a portal page that no screen declares")
    For tPage = ..PreparedProbe, ..#GATEPAGE {
        Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
    }
    Set tSC = ..EnsureResource(..#FIRST)
    If $$$ISOK(tSC) Set tSC = ..EnsureResource(..#SECOND)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPageRes" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Prepare", ..PreparedPassword)
    Set ..PreparedSetupOk = $$$ISOK(tSC)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set ..PreparedTurns = ""
    Set tSC = $$$OK
    For tPage = ..PreparedProbe, ..#GATEPAGE {
        Set tSC = $$$ADDSC(tSC, ..Plant(tPage, ""))
    }
    If $$$ISERR(tSC) Quit tSC
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(..RestorePages(), "every page reads its recorded custom resource again")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    For tI = 1:1:$ListLength(..PreparedTurns) Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($List(..PreparedTurns, tI))
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tSC = ..RestorePages()
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    Do ..RemoveResource(..#FIRST)
    Do ..RemoveResource(..#SECOND)
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PageResourceWrite teardown left:" _ tLeft)
    Quit tSC
}

/// <p>Create the resource <var>pName</var> unless the instance holds it, with no public permission.</p>
ClassMethod EnsureResource(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(pName) Set tSC = ##class(Security.Resources).Create(pName, "OcuPilot test: Page resources probe resource (throwaway)", "")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the resource <var>pName</var> when the instance holds it.</p>
ClassMethod RemoveResource(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(pName) Do ##class(Security.Resources).Delete(pName)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Put every recorded page back to its recorded custom resource; an error when one does not read it afterwards.</p>
Method RestorePages() As %Status
{
    Set tSC = $$$OK
    Set tPage = ""
    For {
        Set tPage = $Order(..PreparedPages(tPage), 1, tRecorded)
        If tPage = "" Quit
        Set tEncoded = $ZConvert(tPage, "O", "URL")
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, ##class(%CSP.Portal.Utils).%SetCustomResource(tEncoded, tRecorded))
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, tPage _ " does not read its recorded custom resource '" _ tRecorded _ "'"))
    }
    Quit tSC
}

/// <p>The custom resource the instance stores for <var>pPage</var> now.</p>
ClassMethod Held(pPage As %String) As %String
{
    Quit ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(pPage, "O", "URL"))
}

/// <p>Assign <var>pResource</var> to <var>pPage</var> as another party would, without OcuPilot.</p>
ClassMethod Plant(pPage As %String, pResource As %String) As %Status
{
    Quit ##class(%CSP.Portal.Utils).%SetCustomResource($ZConvert(pPage, "O", "URL"), pResource)
}

/// <p>One request as <var>pUser</var>; <var>pObject</var> is the parsed body, or <code>""</code>.</p>
Method As(pUser As %String, pMethod As %String, pPath As %String, Output pStatus As %Integer, Output pObject, pBody As %String = "") As %Status
{
    Set pObject = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, pUser, ..PreparedPassword, .pStatus, .tText, pBody)
    Try {
        If $Get(tText) '= "" Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tText)
    } Catch {
        Set pObject = ""
    }
    Quit tSC
}

/// <p>One action of the Page resources list as <var>pUser</var>: <var>pAction</var> on <var>pPage</var>, with <var>pResource</var> as the one value of a
/// change.</p>
Method Act(pUser As %String, pAction As %String, pPage As %String, pResource As %String, Output pStatus As %Integer, Output pObject) As %Status
{
    Set tBody = {"action": (pAction), "id": (pPage)}
    If pAction = "change" Do tBody.%Set("values", {"Resource": (pResource)})
    Quit ..As(pUser, "POST", "/screens/" _ ..#LISTSCREEN _ "/action", .pStatus, .pObject, tBody.%ToJSON())
}

/// <p>The code, the failed pair and the field of the first violation of the refusal <var>pObject</var>, joined by bars.</p>
ClassMethod Refusal(pObject) As %String
{
    If '$IsObject(pObject) Quit "||"
    Set tViolation = $Select($IsObject(pObject.%Get("detail")) && $IsObject(pObject.detail.%Get("violations")): pObject.detail.violations.%Get(0), 1: "")
    Quit pObject.%Get("code") _ "|" _ $Select($IsObject(pObject.%Get("detail")): pObject.detail.%Get("failedPair"), 1: "") _ "|" _ $Select($IsObject(tViolation): tViolation.%Get("field"), 1: "")
}

/// <p>The list's row for <var>pPage</var> as <var>pUser</var> reads it, or <code>""</code>.</p>
Method Row(pUser As %String, pPage As %String) As %DynamicObject
{
    Set tSC = ..As(pUser, "GET", "/screens/" _ ..#LISTSCREEN _ "/read", .tStatus, .tRead)
    If $$$ISERR(tSC) || (tStatus '= 200) || '$IsObject(tRead) Quit ""
    Set tFound = ""
    Set tRows = tRead.rows.%GetIterator()
    While tRows.%GetNext(.tIndex, .tRow) {
        If tRow.Page = pPage {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>Whether the map opens <var>pTool</var>'s screen to <var>pUser</var>, in <var>pAllowed</var>, and the pair it names when it does not.</p>
Method Verdict(pUser As %String, pTool As %String, Output pAllowed As %Boolean, Output pFailedPair As %String) As %Status
{
    Set pAllowed = -1
    Set pFailedPair = ""
    Set tRoute = $ClassMethod(##class(OcuPilot.Screen.Registry).DescriptorForTool(pTool), "Route")
    Set tSC = ..As(pUser, "GET", "/navigation", .tStatus, .tMap)
    If $$$ISERR(tSC) || (tStatus '= 200) || '$IsObject(tMap) Quit $$$ERROR($$$GeneralError, "the navigation map answered " _ tStatus)
    Set tAreas = tMap.areas.%GetIterator()
    While tAreas.%GetNext(.tIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If tScreen.route '= tRoute Continue
            Set pAllowed = ''tScreen.allowed
            Set pFailedPair = tScreen.%Get("failedPair")
        }
    }
    Quit $$$OK
}

/// <p>The agent's call of <var>pTool</var> for <var>pPage</var> through the dispatcher on a seeded turn: <var>pContent</var> is the answer's content parsed,
/// <var>pIsError</var> its error flag. <var>pResource</var> is sent as <code>Resource</code> when the call names one.</p>
Method Dispatch(pTool As %String, pPage As %String, pResource As %String, Output pContent, Output pIsError As %Boolean, Output pTurn As %String) As %Status
{
    Set pContent = ""
    Set pIsError = 1
    Set pTurn = ""
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTurns = ..PreparedTurns _ $ListBuild(pTurn)
    Set tUse = {"type": "tool_use", "id": "toolu_pageresource", "input": {"Page": (pPage), "rationale": "probe", "expectedImpact": "probe"}}
    If pResource '= $c(0) Do tUse.input.%Set("Resource", pResource, "string")
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set pIsError = ''tResults.%Get(0).%Get("is_error")
    Try { Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tResults.%Get(0).%Get("content")) } Catch { Set pContent = tResults.%Get(0).%Get("content") }
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> in process as the running account.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The proposal's stored <code>destructive</code>, <code>consequence</code> and <code>targetName</code>, joined by bars.</p>
ClassMethod Treatment(pContent As %DynamicObject) As %String
{
    If '$IsObject(pContent) Quit "<none>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pContent.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit "<absent>"
    Quit +$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")) _ "|" _ $Get(tValues("targetName"))
}

/// <p>The card's one row <var>pField</var> as <code>before -&gt; after</code>, or <code>""</code>.</p>
ClassMethod RowOf(pContent As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pContent) || '$IsObject(pContent.%Get("changed")) Quit ""
    Set tIterator = pContent.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.field = pField Quit
    }
    Quit $Select($IsObject($Get(tRow)): tRow.before _ " -> " _ tRow.after, 1: "")
}

/// <p>How many <code>SecurityChange</code> rows since <var>pSince</var> record the page <var>pPage</var> going from <var>pOld</var> to <var>pNew</var>, and
/// the one row's verb when there is one, in <var>pVerb</var>.</p>
ClassMethod ChangeRows(pSince As %String, pPage As %String, pOld As %String, pNew As %String, Output pVerb As %String) As %Integer
{
    Set pVerb = ""
    Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """id"":""" _ pPage _ """", .tData, """resource"":{""old"":""" _ pOld _ """,""new"":""" _ pNew _ """}")
    If tRows = 1 Set pVerb = ##class(%DynamicAbstractObject).%FromJSON(tData).verb
    Quit tRows
}

/// <p>How many agent markers since <var>pSince</var> carry the proposal <var>pProposalId</var>.</p>
ClassMethod Markers(pSince As %String, pProposalId As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, ##class(OcuPilot.Test.AuditMarker).MarkerName(), pProposalId, .tData)
}

/// <p><b>The person (AC1, AC2, AC10, AC13).</b> The principal holding exactly the two pairs assigns a resource to the probe page by a spelling the vendor
/// normalizes, which the instance stores under the class name, the list shows with the read-back matching and one security change records; changes it; clears
/// it, which reads back gone and records one more; and a clear of a page with none is refused 409 with its sentence and records nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PortalResourcePort.ClearResource</method> stores the old resource -> the clear assertions go red; the audit call is skipped on
/// either branch -> its row assertion goes red. (The vendor normalizes a <code>.cls</code> spelling itself, so the port's own normalization is pinned over
/// <class>OcuPilot.Test.PageResourceStoreSeam</class> by <class>OcuPilot.Test.PageResourceProhibited</class>; a refused clear records nothing: the composed read refuses it before the port's write is called, so the port's own refusal is pinned by
/// <class>OcuPilot.Test.PageResourceProhibited</class>.)</p>
Method TestAPersonAssignsChangesAndClearsAPage()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tUser = $Parameter(..#FIXTURE, "LEASTUSER")
    Set tPage = ..PreparedProbe
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Act(tUser, "change", tPage _ ".cls", ..#FIRST, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the assignment is accepted: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..Held(tPage), ..#FIRST, "the instance stores it under the normalized class name")
    Do $$$AssertEquals(tAnswer.%Get("action") _ "|" _ tAnswer.readBack.verdict, "updated|matches", "the answer carries AD-14's action and a read-back that matches")
    Set tRow = ..Row(tUser, tPage)
    Do $$$AssertTrue($IsObject(tRow), "the list shows the page")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Resource _ "|" _ tRow.Screen, ..#FIRST _ "|", "with its resource and no screen")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, "", ..#FIRST, .tVerb) _ "|" _ tVerb, "1|updated", "one security change records the page going from none to the resource")

    Set tSC = ..Act(tUser, "change", tPage, ..#SECOND, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a change is accepted")
    Do $$$AssertEquals(..Held(tPage), ..#SECOND, "and stored")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, ..#FIRST, ..#SECOND, .tVerb) _ "|" _ tVerb, "1|updated", "one security change records the resource before and after")

    Set tSC = ..Act(tUser, "clear", tPage, "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a clear is accepted: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("action") _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "it reads back gone")
    Do $$$AssertEquals(..Held(tPage), "", "the instance holds no resource for the page")
    Do $$$AssertEquals(..Row(tUser, tPage), "", "and the list no longer shows it")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, ..#SECOND, "", .tVerb) _ "|" _ tVerb, "1|deleted", "one security change records the clear")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Act(tUser, "clear", tPage, "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tAnswer), "409|ACCESS.PAGE.NOTASSIGNED||", "a clear of a page with none is refused 409 with its code")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("reason"), ##class(OcuPilot.Api.AccessError).ReasonFor("ACCESS.PAGE.NOTASSIGNED"), "and its sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """id"":""" _ tPage _ """", .tNone), 0, "and records no security change")
}

/// <p><b>The agent (AC1, AC2, AC13).</b> A confirmed assign stores under the class name and reads back <code>matches</code>; a confirmed change and a confirmed
/// clear do the same, each with its card summary and the removal row, one security change and one agent marker; the card of an assign to a page with none is
/// not destructive; and a clear of a page with none is refused at the mint with its code and stores no proposal.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.PageResourceClear.PortQuery</method> always sets the clear key -> the confirm's re-read is refused and the clear
/// assertions go red.</p>
Method TestTheAgentAssignsChangesAndClears()
{
    Set tPage = ..PreparedProbe
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Dispatch(..#ASSIGN, tPage, ..#FIRST, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the assign mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..RowOf(tContent, "Resource"), " -> " _ ..#FIRST, "its card's row reads the resource before and after")
    Do $$$AssertEquals(..Treatment(tContent), "0||Assign " _ ..#FIRST _ " to " _ tPage, "an assignment to a page with none is not destructive, and its card says what it does")
    Do $$$AssertEquals(..Held(tPage), "", "nothing was stored at the mint")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Held(tPage), ..#FIRST, "the instance stores it")
    Do $$$AssertEquals(tResult.readBack.verdict _ "|" _ tResult.%Get("action") _ "|" _ tResult.%Get("auditMarked"), "matches|updated|1", "it reads back, answers AD-14's action and is marked")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, "", ..#FIRST, .tVerb) _ "|" _ tVerb, "1|updated", "one security change records it")
    Do $$$AssertEquals(..Markers(tSince, tContent.proposalId), 1, "and one agent marker carries the proposal")

    Set tSC = ..Dispatch(..#ASSIGN, tPage, ..#SECOND, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "a change mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..Treatment(tContent), "0||Change the resource of " _ tPage _ " to " _ ..#SECOND, "a change of the page nothing declares is not destructive, and its card says what it does")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the change's confirm answers: " _ $Get(tCode))
    Do $$$AssertEquals(..Held(tPage), ..#SECOND, "the instance stores it")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, ..#FIRST, ..#SECOND, .tVerb) _ "|" _ tVerb, "1|updated", "one security change records the resource before and after")

    Set tSC = ..Dispatch(..#CLEAR, tPage, $c(0), .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the clear mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..RowOf(tContent, "Resource"), ..#SECOND _ " -> ", "its card's one row shows the resource taken away")
    Do $$$AssertEquals(..Treatment(tContent), "0||Clear the resource of " _ tPage, "a clear of the page nothing declares is not destructive, and its card says what it does")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the clear's confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Held(tPage), "", "the instance holds no resource for the page")
    Do $$$AssertEquals(tResult.readBack.verdict _ "|" _ tResult.%Get("action"), "notFound|deleted", "the read-back reads it gone")
    Do $$$AssertEquals(..ChangeRows(tSince, tPage, ..#SECOND, "", .tVerb) _ "|" _ tVerb, "1|deleted", "one security change records the clear")
    Do $$$AssertEquals(..Markers(tSince, tContent.proposalId), 1, "and one agent marker carries the proposal")

    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLEAR)
    Set tSC = ..Dispatch(..#CLEAR, tPage, $c(0), .tContent, .tIsError, .tTurn)
    Set tText = $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent)
    Do $$$AssertTrue(tIsError && (tText [ "ACCESS.PAGE.NOTASSIGNED"), "a clear of a page with none is refused at the mint: " _ tText)
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLEAR), tBefore, "and no proposal is added")
}

/// <p><b>Bad input (AC5).</b> Over the real vendor, each of the person's and the agent's requests that names a page the portal does not have, no resource, or a
/// resource the instance does not define is refused on its own field with its published sentence, stores nothing and records no security change.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PortalResourcePort.Normalized</method> skips the portal-page resolution -> the unknown-page leg goes red.</p>
Method TestABadRequestIsRefusedOnItsFieldAndStoresNothing()
{
    Set tUser = $Parameter(..#FIXTURE, "LEASTUSER")
    Set tPage = ..PreparedProbe
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tCase = $ListBuild("Nope.Nada", ..#FIRST, "ACCESS.PAGE.UNKNOWN|Page"), $ListBuild(tPage, "", "ACCESS.PAGE.RESOURCEREQUIRED|Resource"), $ListBuild(tPage, "OcuProbe2137NoSuchResource", "ACCESS.RESOURCE.UNKNOWN|Resource") {
        Set tSC = ..Act(tUser, "change", $List(tCase, 1), $List(tCase, 2), .tStatus, .tAnswer)
        Set tRefusal = ..Refusal(tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $Piece(tRefusal, "|", 1) _ "|" _ $Piece(tRefusal, "|", 3), "422|" _ $Piece($List(tCase, 3), "|", 1) _ "|" _ $Piece($List(tCase, 3), "|", 2), "the person's request for '" _ $List(tCase, 1) _ "' / '" _ $List(tCase, 2) _ "' is refused on its field")
        If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("reason"), ##class(OcuPilot.Api.AccessError).ReasonFor($Piece($List(tCase, 3), "|", 1)), "with its published sentence")
    }
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN)
    For tCase = $ListBuild("Nope.Nada", ..#FIRST, "ACCESS.PAGE.UNKNOWN"), $ListBuild(tPage, "", "ACCESS.PAGE.RESOURCEREQUIRED"), $ListBuild(tPage, "OcuProbe2137NoSuchResource", "ACCESS.RESOURCE.UNKNOWN") {
        Set tSC = ..Dispatch(..#ASSIGN, $List(tCase, 1), $List(tCase, 2), .tContent, .tIsError, .tTurn)
        Set tText = $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent)
        Do $$$AssertTrue(tIsError && (tText [ $List(tCase, 3)), "the agent's call for '" _ $List(tCase, 1) _ "' / '" _ $List(tCase, 2) _ "' is refused at the mint with its code: " _ tText)
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN), tBefore, "no proposal is stored")
    Do $$$AssertEquals(..Held(tPage), "", "the probe page holds no resource")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """id"":""" _ tPage _ """", .tNone), 0, "and no security change was recorded")
}

/// <p><b>Stale (AC6).</b> A proposal minted while the page held one resource is refused <code>PROPOSAL.TARGETCHANGED</code> when another party changed the page
/// before the confirm, for a clear and for an assign, and writes nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.PageResourceAction</method> declares no <code>FINGERPRINTSUBJECT</code> naming <code>Current</code> -> this goes
/// red.</p>
Method TestAConfirmAfterThePageMovedIsRefusedAndWritesNothing()
{
    Set tPage = ..PreparedProbe
    Do $$$AssertStatusOK(..Plant(tPage, ..#FIRST), "the page holds the first resource")
    Set tSC = ..Dispatch(..#CLEAR, tPage, $c(0), .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "a clear mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertStatusOK(..Plant(tPage, ..#SECOND), "another party changes the page")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "409|" _ $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "the confirm is refused as stale")
    Do $$$AssertEquals(..Held(tPage), ..#SECOND, "and writes nothing")

    Set tSC = ..Dispatch(..#ASSIGN, tPage, ..#FIRST, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "an assign mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertStatusOK(..Plant(tPage, ""), "another party clears the page")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "409|" _ $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "the assign's confirm is refused as stale")
    Do $$$AssertEquals(..Held(tPage), "", "and writes nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """id"":""" _ tPage _ """", .tNone), 0, "and records no security change")
}

/// <p><b>The gate honors it (AC7), and a declared page is destructive (AC4).</b> A resource the port assigns to the Resources list's page is a requirement of
/// that screen on the next call: <code>RequiredPairs</code> holds it at <code>USE</code> and an account without it is refused the screen by name, with
/// nothing cached; the agent's clear of that page is minted destructive with <code>PAGERESOURCE.CLEARED</code> and, once confirmed, the account is admitted
/// again.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Gate.ClassicResource</method> reads a process-cached copy -> the refused-then-admitted legs go red.</p>
Method TestTheGateFollowsThePageResourceOnTheNextCall()
{
    Set tUser = $Parameter(..#FIXTURE, "LEASTUSER")
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(..#GATESCREEN)
    Set tSC = ..Verdict(tUser, ..#GATESCREEN, .tAllowed, .tFailed)
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "1|", "the account opens the screen before any assignment")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor, .tResolved)
    Do $$$AssertTrue(tResolved && '$ListFind(tPairs, $ListBuild(..#FIRST, "USE")), "and its requirement lacks the resource")

    Kill tQuery
    Set tQuery("id") = ..#GATEPAGE
    Set tQuery("resource") = ..#FIRST
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PortalResource", "PUT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the port assigns the resource to the screen's page")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor, .tResolved)
    Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild(..#FIRST, "USE")), "the next call's requirement holds the resource at USE")
    Set tSC = ..Verdict(tUser, ..#GATESCREEN, .tAllowed, .tFailed)
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "0|" _ ..#FIRST _ ":USE", "the account is refused the screen, naming the resource")

    Set tSC = ..Dispatch(..#CLEAR, ..#GATEPAGE, $c(0), .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the agent's clear mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..Treatment(tContent), "1|PAGERESOURCE.CLEARED|Clear the resource of " _ ..#GATEPAGE, "a clear of a declared page is destructive and names its consequence")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    Do $$$AssertEquals(..Held(..#GATEPAGE), "", "the page's resource is gone")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor, .tResolved)
    Do $$$AssertTrue(tResolved && '$ListFind(tPairs, $ListBuild(..#FIRST, "USE")), "the next call's requirement lacks it")
    Set tSC = ..Verdict(tUser, ..#GATESCREEN, .tAllowed, .tFailed)
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "1|", "and the account is admitted again")
}

/// <p><b>The script form (AC8).</b> Each tool's copy-out draft renders the vendor's <code>%SetCustomResource</code> call with the page, URL-encoded, and the
/// resource, empty for the clear, and runs no write.</p>
/// <p>Mutation (Rule 19): remove the clear branch of <method>OcuPilot.Port.PortalResourcePort.Snippet</method> -> this goes red, naming the tool.</p>
Method TestEachToolRendersItsScript()
{
    Set tPage = ..PreparedProbe
    Do $$$AssertStatusOK(..Plant(tPage, ..#FIRST), "the page holds the first resource")
    For tCase = $ListBuild(..#ASSIGN, ..#SECOND, ..#SECOND), $ListBuild(..#CLEAR, $c(0), "") {
        Set tTool = $List(tCase, 1)
        Set tSC = ..Dispatch(tTool, tPage, $List(tCase, 2), .tContent, .tIsError, .tTurn)
        Do $$$AssertEquals(tIsError, 0, tTool _ " mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
        If '$IsObject(tContent) || tIsError Continue
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tContent.proposalId, .tFound, .tRow)
        Do ##class(OcuPilot.Screen.Tool.Registry).Resolve(tTool, .tResolvedTool)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Render(tResolvedTool, .tRow, ..#ORIGIN, $Username, .tDraft, .tBody, .tQuery)
        Do $$$AssertStatusOK(tSC, tTool _ ": the draft renders")
        If '$IsObject($Get(tDraft)) {
            Do $$$AssertTrue(0, tTool _ " has a script form")
            Continue
        }
        Set tText = ""
        Set tSteps = tDraft.%Get("steps").%GetIterator()
        While tSteps.%GetNext(.tIndex, .tStep) {
            Set tText = tText _ tStep.%Get("text") _ $Char(10)
        }
        Do $$$AssertTrue(tText [ ("##class(%CSP.Portal.Utils).%SetCustomResource(""" _ $ZConvert(tPage, "O", "URL") _ """, """ _ $List(tCase, 3) _ """)"), tTool _ ": the script is the vendor's call with the encoded page and the resource: " _ tText)
        Do $$$AssertEquals(..Held(tPage), ..#FIRST, tTool _ ": and rendering it wrote nothing")
    }
}

/// <p><b>The port gate (AC10).</b> An account without <code>%Admin_Secure:USE</code>, and one without <code>%DB_IRISSYS:READ</code>, is refused each request 403
/// <code>AUTH.NOPRIVILEGE</code> naming the first pair it lacks, before any vendor call. Nothing is stored, and the navigation map refuses the screen by that
/// pair. (The port's own gate, <code>PORT.ACCESSDENIED</code>, is pinned by <class>OcuPilot.Test.PageResourceRead</class>.)</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>PAIRS</code> loses <code>%DB_IRISSYS:READ</code> -> this goes red.</p>
Method TestAnAccountShortOfAPairIsRefusedNamingIt()
{
    Set tPage = ..PreparedProbe
    For tCase = $ListBuild($Parameter(..#FIXTURE, "NOSECUREUSER"), "%Admin_Secure:USE", ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE), $ListBuild($Parameter(..#FIXTURE, "NOIRISUSER"), "%DB_IRISSYS:READ", ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE) {
        Set tUser = $List(tCase, 1)
        Set tSC = ..Act(tUser, "change", tPage, ..#FIRST, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tAnswer), "403|" _ $List(tCase, 3) _ "|" _ $List(tCase, 2) _ "|", tUser _ ": the change is refused naming " _ $List(tCase, 2))
        Set tSC = ..Act(tUser, "clear", tPage, "", .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tAnswer), "403|" _ $List(tCase, 3) _ "|" _ $List(tCase, 2) _ "|", tUser _ ": and so is the clear")
        Set tSC = ..As(tUser, "GET", "/screens/" _ ..#LISTSCREEN _ "/read", .tStatus, .tRead)
        Do $$$AssertEquals(tStatus, 403, tUser _ ": and the list read")
        Set tSC = ..Verdict(tUser, ..#LISTSCREEN, .tAllowed, .tFailed)
        Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "0|" _ $List(tCase, 2), tUser _ ": the map refuses the screen by that pair")
    }
    Do $$$AssertEquals(..Held(tPage), "", "nothing was stored")
}

}
