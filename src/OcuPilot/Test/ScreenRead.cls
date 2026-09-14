/// <p>The screen read (AD-36): <method>OcuPilot.Screen.Read.Execute</method>'s cap, truncation,
/// projection and fault rows over a canned list; the same read against the instance's real
/// <code>WebApp.App</code> list; <method>OcuPilot.Screen.Read.ApplyView</method> over
/// <class>OcuPilot.Test.ReadViewCorpus</class>; the descriptor cache; the namespace list's
/// <code>DontConnect</code>; and the route's matrix rows through <class>OcuPilot.Test.Dispatch</class>
/// against <class>OcuPilot.Test.RouterFixture</class>.</p>
/// <p>Canned rows come from <class>OcuPilot.Test.EndpointFixture</class> through
/// <class>OcuPilot.Test.PortFixture</class>; privileges on the route rows come from
/// <class>OcuPilot.Test.ScreenGate</class>. Needs <code>%Admin_Operate:U</code> or
/// <code>%Admin_Manage:U</code> for the canned endpoint, <code>%Admin_Secure:U</code> and at least
/// three web applications for the real list. Reads only.</p>
Class OcuPilot.Test.ScreenRead Extends %UnitTest.TestCase
{

/// <p>The canned read-declaring descriptor.</p>
Parameter CANNED = "OcuPilot.Test.Read.Canned";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.NamespaceInfoFixture).Reset()
    Do ##class(OcuPilot.Test.Read.Readless).ResetReadCount()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Arm a canned list of <var>pCount</var> rows: each carries the four declared fields plus one
/// undeclared key, except the second, which omits <code>Enabled</code>.</p>
ClassMethod ArmRows(pCount As %Integer)
{
    Set tRows = []
    For tI = 1:1:pCount {
        Set tRow = {}
        Do tRow.%Set("Name", "/csp/canned" _ tI)
        Do tRow.%Set("NameSpace", "USER")
        If tI '= 2 Do tRow.%Set("Enabled", (tI # 2), "boolean")
        Do tRow.%Set("Secret", "secret" _ tI)
        Do tRow.%Set("Undeclared", tI, "number")
        Do tRows.%Push(tRow)
    }
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows(tRows.%ToJSON())
}

/// <p>Matrix row "Truncated": six rows under a cap of five answer five, truncated, and the port was
/// asked for six.</p>
/// <p>Mutation: pass <code>maxRows</code> rather than <code>maxRows</code> + 1 to the port in
/// <method>OcuPilot.Screen.Read.Execute</method> -> the port sees 5, answers 5, and both the
/// recorded-cap and the truncation assertions go red.</p>
Method TestAListLongerThanTheCapIsTruncated()
{
    Do ..ArmRows(6)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("maxRows"), 6, "the port was asked for one row more than the cap")
    Do $$$AssertEquals(tResult.rows.%Size(), 5, "five rows are answered")
    Do $$$AssertEquals(tResult.%GetTypeOf("truncated"), "boolean", "truncated is a boolean")
    Do $$$AssertEquals(tResult.truncated, 1, "and it is true")
}

/// <p>Matrix row "Exactly at cap": five rows under a cap of five answer five, not truncated.</p>
Method TestAListExactlyAtTheCapIsNotTruncated()
{
    Do ..ArmRows(5)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tResult.rows.%Size(), 5, "five rows are answered")
    Do $$$AssertEquals(tResult.truncated, 0, "and nothing was cut")
}

/// <p>An absent cap is the default of 1,000, so the port is asked for 1,001.</p>
Method TestAnAbsentCapIsTheDefault()
{
    Do ..ArmRows(3)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("maxRows"), ##class(OcuPilot.Screen.Read).#DEFAULTMAXROWS + 1, "the default cap plus one reached the port")
    Do $$$AssertEquals(tResult.rows.%Size(), 3, "every row is answered")
    Do $$$AssertEquals(tResult.truncated, 0, "untruncated")
}

/// <p>Matrix row "Bad cap": zero, a negative, a fraction and text are refused 400
/// <code>READ.MAXROWS</code> and the port is never constructed.</p>
Method TestABadCapIsRefusedBeforeThePort()
{
    Do ..ArmRows(3)
    For tBad = 0, -1, 2.5, "abc" {
        Do ##class(OcuPilot.Test.EndpointFixture).Clear()
        Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, tBad, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "maxRows " _ tBad _ " is refused")
        Do $$$AssertEquals(tHttp, 400, "maxRows " _ tBad _ ": at 400")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "READ.MAXROWS") && (tFault.error = "bad_request"), "maxRows " _ tBad _ ": bad_request with READ.MAXROWS")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "maxRows " _ tBad _ ": the port was not called")
    }
}

/// <p>Every row carries exactly the declared fields other than the secret ones, in declared order:
/// an absent key is <code>null</code>, and an undeclared key and a secret field are dropped.</p>
Method TestRowsAreProjectedToTheDeclaredFields()
{
    Do ..ArmRows(2)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Name"",""NameSpace"",""Enabled""]", "fields are the declared fields without the secret one")
    Do $$$AssertEquals(tResult.rows.%Get(0).%ToJSON(), "{""Name"":""/csp/canned1"",""NameSpace"":""USER"",""Enabled"":true}", "a row carries the declared keys with their JSON types, and no secret")
    Do $$$AssertEquals(tResult.rows.%Get(1).%GetTypeOf("Enabled"), "null", "an absent key is null")
    Do $$$AssertEquals(tResult.rows.%Get(1).%GetTypeOf("Undeclared"), "unassigned", "an undeclared key is dropped")
}

/// <p>Matrix row "Port fault": a 404 from the endpoint passes through with its status and fault.</p>
Method TestAPortFaultPassesThroughUnchanged()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("notfound")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp, 404, "with the endpoint's 404")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "PORT.NOTFOUND"), "and the port's fault")
    Do $$$AssertEquals(tResult, "", "and no result")
}

/// <p>An endpoint that answers an object rather than a list is an internal fault, never a
/// one-row success.</p>
/// <p>Mutation: drop the <code>%DynamicArray</code> check in
/// <method>OcuPilot.Screen.Read.Execute</method> -> the read answers 200 and the assertions go
/// red.</p>
Method TestAnAnswerThatIsNotAListIsAnInternalFault()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("ok")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CANNED, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "INTERNAL"), "with the internal fault")
    Do $$$AssertEquals(tResult, "", "and no result")
}

/// <p>AC5 -- against the real <code>WebApp.App</code> list at <code>maxRows</code> 2, the read
/// answers two rows and reports truncation.</p>
Method TestTheRealWebApplicationListTruncatesAtTwo()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Test.Read.WebApps", 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the real read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(tResult.rows.%Size(), 2, "two rows are answered")
    Do $$$AssertEquals(tResult.truncated, 1, "and the instance has more")
    Do $$$AssertTrue(tResult.rows.%Get(0).Name '= "", "each row carries its application name")
}

/// <p>AC7 -- <method>OcuPilot.Screen.Read.ApplyView</method> produces every corpus case's order.</p>
/// <p>Mutation: lower-case with <code>$ZConvert</code> instead of the ASCII translate in
/// <method>OcuPilot.Screen.Read.ApplyView</method> and <code>Matches</code> -> the
/// "a non-ASCII capital is not lower-cased" case goes red.</p>
Method TestEveryCorpusCaseProducesItsOrder()
{
    Set tSC = ##class(OcuPilot.Test.ReadViewCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    Do $$$AssertTrue(tCorpus.cases.%Size() >= 10, "the corpus carries its cases")
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tRows = $Select($IsObject(tCase.rows): tCase.rows, 1: tCorpus.rows)
        Set tView = ##class(OcuPilot.Screen.Read).ApplyView(tRows, tCorpus.read, tCase.filter, tCase.sort, tCase.direction)
        Set tIds = []
        Set tRowIterator = tView.%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            Do tIds.%Push(tRow.Id)
        }
        Do $$$AssertEquals(tIds.%ToJSON(), tCase.expected.%ToJSON(), tCase.name)
    }
}

/// <p>AC8 -- every descriptor accessor run twice reads the declaration once, and a cached entry
/// whose hash is not the compiled class's is read again.</p>
/// <p>Mutation: drop the hash comparison from
/// <method>OcuPilot.Screen.Descriptor.Base.Declaration</method>'s cache hit -> the stale-hash
/// count goes red.</p>
Method TestEveryAccessorReadsTheDeclarationOnce()
{
    Set tClass = "OcuPilot.Test.Read.Readless"
    Do $ClassMethod(tClass, "ForgetDeclaration")
    Do $ClassMethod(tClass, "ResetReadCount")
    Set tAccessors = $ListBuild("Route", "AreaKey", "LabelKey", "SideBarPosition", "Archetype", "IsBuilt", "PrivilegePairs", "PrimaryEntityType", "SecondaryEntityTypes", "EntityTypes", "Scope", "ParentScope", "IdKind", "IdParts", "ContextFields", "ContextSecretFields", "PrimaryActionId", "PrimaryActionSelfProtection", "RowActionIds", "EmptyStateKey", "CommandAliases", "ClassicPage", "ClassicLinkExempt", "ClassicLinkExemptionReason", "ClassicLinkHref", "ClassicLinkLabel", "Refreshes", "RefreshRates", "ToolIdentifier", "Read")
    For tRound = 1, 2 {
        For tI = 1:1:$ListLength(tAccessors) {
            Set tIgnored = $ClassMethod(tClass, $List(tAccessors, tI))
        }
        Set tIgnored = $ClassMethod(tClass, "Field", "route")
    }
    Do $$$AssertEquals($ClassMethod(tClass, "ReadCount"), 1, "the XData was read once across " _ ($ListLength(tAccessors) + 1) _ " accessors run twice")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "and the accessors answer from it")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 1, "including the nested ones")

    Do $ClassMethod(tClass, "ForgetDeclaration")
    Set tIgnored = $ClassMethod(tClass, "Route")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadCount"), 2, "a forgotten declaration is read again")

    Set %OcuPilotDeclarations(tClass, "hash") = "stale"
    Set tIgnored = $ClassMethod(tClass, "Route")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadCount"), 3, "a cached declaration under a stale hash is read again")
    Set tIgnored = $ClassMethod(tClass, "Route")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadCount"), 3, "and cached again under the compiled hash")
}

/// <p>A nested value an accessor hands out is a copy: changing it does not change what the next
/// caller reads.</p>
Method TestAHandedOutReadIsACopy()
{
    Set tRead = $ClassMethod(..#CANNED, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the canned descriptor declares a read")
    Do tRead.fields.%Push("Injected")
    Do tRead.%Set("paging", "cursor")
    Set tAgain = $ClassMethod(..#CANNED, "Read")
    Do $$$AssertEquals(tAgain.fields.%Size(), 4, "the cached fields are unchanged")
    Do $$$AssertEquals(tAgain.paging, "cap", "and so is the cached paging")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Read.Readless", "Read"), "", "a descriptor with no read answers the empty string")
}

/// <p>AC9 -- the namespace list asks for database information without connecting.</p>
/// <p>Mutation: call <method>OcuPilot.Api.Namespaces.NamespaceInfo</method> with 0 in
/// <method>OcuPilot.Api.Namespaces.GlobalDatabase</method> -> this goes red.</p>
Method TestTheNamespaceListAsksWithoutConnecting()
{
    Set tResolved = ##class(OcuPilot.Test.NamespaceInfoFixture).GlobalDatabase($Namespace, .tResource, .tReadOnly)
    Do $$$AssertTrue(tResolved, "the namespace's global database still resolves")
    Do $$$AssertTrue(tResource '= "", "with its resource")
    Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceInfoFixture).RecordedDontConnect(), 1, "and GetAllNSInfo was handed DontConnect 1")
}

/// <p>The route's success row: <code>{fields, rows, truncated}</code> over the canned list, through
/// the one success writer, with no secret field's name or value in the body.</p>
/// <p>Mutation: project <code>read.fields</code> without removing <code>context.secretFields</code>
/// in <method>OcuPilot.Screen.Read.Execute</method> -> the field count and both secret assertions go
/// red.</p>
Method TestTheRouteAnswersTheRead()
{
    Do ..ArmRows(6)
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", {"maxRows": "5"}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "the route answers")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.rows.%Size(), 5, "five rows")
    Do $$$AssertEquals(tObj.truncated, 1, "truncated")
    Do $$$AssertEquals(tObj.fields.%Size(), 3, "and the declared fields other than the secret one")
    Do $$$AssertEquals((tBody [ "secret"), 0, "no secret value reaches the browser")
    Do $$$AssertEquals((tBody [ "Secret"), 0, "nor the secret field's name")
}

/// <p>Matrix row "Unknown or readless screen": both are the framework's 404.</p>
Method TestAnUnknownOrReadlessScreenIsNotFound()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    For tScreen = "nosuch.screen", "webapp.readless" {
        Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/" _ tScreen _ "/read", "GET", , .tBody, .tStatus)
        Do $$$AssertStatusOK(tSC, tScreen _ ": dispatch completes")
        Do $$$AssertEquals(tStatus, 404, tScreen _ ": 404")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.code, "ROUTE.NOTFOUND", tScreen _ ": ROUTE.NOTFOUND")
    }
}

/// <p>Matrix row "Denied": a caller not holding the descriptor's pair is refused 403 naming it, and
/// the port is never called.</p>
/// <p>Mutation: move the gate below <method>OcuPilot.Screen.Read.Execute</method> in
/// <method>OcuPilot.Api.ScreenRead.Handle</method> -> the port-not-called assertion goes red.</p>
Method TestADeniedCallerIsRefusedBeforeThePort()
{
    Do ..ArmRows(3)
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 403, "the caller is refused")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "AUTH.NOPRIVILEGE", "with the screen-privilege code")
    Do $$$AssertEquals(tObj.detail.failedPair, "%Admin_Secure:USE", "naming the failed pair")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "and the port was not called")
}

/// <p>Matrix row "Bad cap", through the route: 400 <code>READ.MAXROWS</code>.</p>
Method TestTheRouteRefusesABadCap()
{
    Do ..ArmRows(3)
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", {"maxRows": "abc"}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 400, "a bad cap is a bad request")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "bad_request", "on the bad_request slug")
    Do $$$AssertEquals(tObj.code, "READ.MAXROWS", "with READ.MAXROWS")
}

/// <p>Matrix row "Port fault", through the route: the port's status and envelope.</p>
Method TestTheRouteRendersAPortFault()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("notfound")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 404, "at the endpoint's status")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "PORT.NOTFOUND", "with the port's code")
    Do $$$AssertEquals(tObj.error, "not_found", "and slug")
}

}
