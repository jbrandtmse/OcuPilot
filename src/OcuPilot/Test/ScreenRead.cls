/// <p>The screen read (AD-36): <method>OcuPilot.Screen.Read.Execute</method>'s cap, truncation,
/// projection and fault rows over a canned list; the same read against the instance's real
/// <code>WebApp.App</code> list; every production admin <code>LIST</code> read's declared read and
/// context fields against its live first row and, for a detail call, that row's live detail;
/// <method>OcuPilot.Screen.Read.ApplyView</method> over <class>OcuPilot.Test.ReadViewCorpus</class>; the descriptor cache; the namespace list's
/// <code>DontConnect</code>; and the route's matrix rows through <class>OcuPilot.Test.Dispatch</class>
/// against <class>OcuPilot.Test.RouterFixture</class>.</p>
/// <p>Canned rows come from <class>OcuPilot.Test.EndpointFixture</class> through
/// <class>OcuPilot.Test.PortFixture</class>; privileges on the route rows come from
/// <class>OcuPilot.Test.ScreenGate</class>. Needs <code>%Admin_Operate:U</code> or
/// <code>%Admin_Manage:U</code> for the canned endpoint, <code>%Admin_Secure:U</code>,
/// <code>%DB_IRISSYS:R</code> and at least three web applications for the real lists, plus
/// <code>%Admin_Wallet:U</code>, an LDAP configuration and the demo fixture's X.509 credential and
/// wallet collection, so the Security lists answer a row to hold their fields to. Reads only.</p>
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

/// <p>Field drift -- for every production descriptor whose read is an admin <code>LIST</code> or
/// <code>UPCOMING</code>, issued with its fixed <code>source.query</code>, each declared read field and
/// context field is a key of the live endpoint's first row.
/// <method>OcuPilot.Screen.Read.Project</method> writes <code>null</code> for a missing key, so a
/// misspelt field would otherwise ship as an empty column. A read that declares
/// <code>source.rowGet</code> holds its detail fields to the live detail call of that first row's
/// key instead -- the declared <code>rowGet.type</code>, <code>GET</code> when it declares none --
/// its derived fields are exempt, and its context fields are held to the two rows' keys together. A
/// read that answers no row fails, since there is nothing to hold the fields to, and a roster with no
/// such descriptor fails rather than passing over nothing. Reads on another port or of another type
/// are not covered here, and neither is a parent-scoped read, whose LIST needs its parent's id:
/// <class>OcuPilot.Test.SecurityLists</class> holds the Secrets list's fields to its live rows. Nor are
/// the five OAuth 2.0 tabs, named here, whose rows exist only once
/// <class>OcuPilot.Test.OAuthProbe</class> has made them: <class>OcuPilot.Test.OAuthTabs</class> holds
/// those.</p>
/// <p>Mutation: declare <code>NameSpace</code> in <class>OcuPilot.Screen.Descriptor.WebAppList</class>'s
/// read -> this goes red naming the field.</p>
Method TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tChecked = 0
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tRead = $ClassMethod(tClass, "Read")
        If '$IsObject(tRead) Continue
        Set tSource = tRead.%Get("source")
        If '$IsObject(tSource) || (tSource.%Get("port") '= "admin") || '$ListFind($ListBuild("LIST", "UPCOMING"), tSource.%Get("type")) Continue
        If $ClassMethod(tClass, "ParentScope") '= "" Continue
        If $ListFind($ListBuild("OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab", "OcuPilot.Screen.Descriptor.OAuthClientTab", "OcuPilot.Screen.Descriptor.OAuthResourceServerTab", "OcuPilot.Screen.Descriptor.OAuthServerTab", "OcuPilot.Screen.Descriptor.OAuthServerClientTab"), tClass) Continue
        Set tChecked = tChecked + 1
        Kill tQuery
        Do ##class(OcuPilot.Screen.Read).SeedSourceQuery(tSource, .tQuery)
        Set tPortSC = ##class(OcuPilot.Port.AdminPort).Invoke(tSource.%Get("endpoint"), tSource.%Get("type"), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusOK(tPortSC, tClass _ ": the live " _ tSource.%Get("endpoint") _ " " _ tSource.%Get("type") _ " answers")
        If $$$ISERR(tPortSC) Continue
        Set tHasRow = $IsObject(tAnswer) && tAnswer.%IsA("%Library.DynamicArray") && (tAnswer.%Size() > 0)
        Do $$$AssertTrue(tHasRow, tClass _ ": and answers at least one row to hold the declared fields to")
        If 'tHasRow Continue
        Set tRow = tAnswer.%Get(0)

        Set tDetail = ""
        Set tDetailFields = ""
        Set tDerivedFields = ""
        Set tRowGet = tSource.%Get("rowGet")
        If $IsObject(tRowGet) {
            Set tFieldIterator = tRowGet.%Get("fields").%GetIterator()
            While tFieldIterator.%GetNext(.tIndex, .tField) {
                Set tDetailFields = tDetailFields _ $ListBuild(tField)
            }
            Set tFieldIterator = tRowGet.%Get("derived").%GetIterator()
            While tFieldIterator.%GetNext(.tIndex, .tEntry) {
                Set tDerivedFields = tDerivedFields _ $ListBuild(tEntry.%Get("field"))
            }
            Kill tQuery
            Set tQuery(tRowGet.%Get("param")) = tRow.%Get(tRowGet.%Get("key"))
            Set tDetailType = $Select(tRowGet.%Get("type") = "": "GET", 1: tRowGet.%Get("type"))
            Set tDetailSC = ##class(OcuPilot.Port.AdminPort).Invoke(tSource.%Get("endpoint"), tDetailType, .tQuery, "", .tDetail, .tHttp, .tFault)
            Do $$$AssertStatusOK(tDetailSC, tClass _ ": the live " _ tSource.%Get("endpoint") _ " " _ tDetailType _ " answers for the first row's " _ tRowGet.%Get("key"))
            Do $$$AssertTrue($IsObject(tDetail), tClass _ ": and answers an object to hold the detail fields to")
            If $$$ISERR(tDetailSC) || '$IsObject(tDetail) Continue
        }

        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If $ListFind(tDerivedFields, tField) Continue
            If $ListFind(tDetailFields, tField) {
                Do $$$AssertTrue(tDetail.%IsDefined(tField), tClass _ ": declared detail field '" _ tField _ "' is a key of the live detail")
            } Else {
                Do $$$AssertTrue($IsObject(tRow) && tRow.%IsDefined(tField), tClass _ ": declared read field '" _ tField _ "' is a key of the live row")
            }
        }
        Set tContextFields = $ClassMethod(tClass, "ContextFields")
        For tJ = 1:1:$ListLength(tContextFields) {
            Set tField = $List(tContextFields, tJ)
            If $ListFind(tDerivedFields, tField) Continue
            Set tFound = ($IsObject(tRow) && tRow.%IsDefined(tField)) || ($IsObject(tDetail) && tDetail.%IsDefined(tField))
            Do $$$AssertTrue(tFound, tClass _ ": declared context field '" _ tField _ "' is a key of the live row or detail")
        }
    }
    Do $$$AssertTrue(tChecked > 0, "at least one production descriptor declares an admin LIST read: " _ tChecked)
}

/// <p>AC3, Story 6.10 -- "No <code>ns</code> in the read" (Boundaries) means the Locks read
/// declares no <code>criteria</code> block at all, so no caller-supplied value -- <code>ns</code>
/// included -- can reach the vendor query: <method>OcuPilot.Screen.Read.SeedCriteria</method> only
/// ever seeds a param the descriptor's own <code>read.criteria</code> names. This is the whole of
/// AC3 that anything can pin. Two further mechanisms were probed and neither can carry a namespace
/// into this read either -- the admin-LIST branch of <method>OcuPilot.Screen.Read.Execute</method>
/// never reads <method>OcuPilot.Kernel.Scope.Current</method> (only the <code>mgmnt</code> branch
/// does), and <method>OcuPilot.Api.Router.OnPreDispatch</method> switches no real
/// <code>$NAMESPACE</code> -- so a two-read comparison across namespaces is green by construction
/// and was removed rather than kept as evidence (Rule 19).</p>
/// <p>Mutation: add a <code>criteria</code> block naming <code>ns</code> to
/// <class>OcuPilot.Screen.Descriptor.LockList</class>'s read -> this goes red on the type check.</p>
Method TestTheLocksReadDeclaresNoCriteriaAtAll()
{
    Set tRead = ##class(OcuPilot.Screen.Descriptor.LockList).Read()
    Do $$$AssertTrue($IsObject(tRead), "the Locks list declares a read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.%GetTypeOf("criteria"), "unassigned", "no criteria block at all, so no caller-supplied value -- ns included -- can reach the vendor query through the declared-criteria path")
}

/// <p>AC2, Story 6.10 -- the Locks read's column fields carry <b>values</b> on the live row, not
/// keys defaulted to the empty string. <method>TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow</method>
/// above asserts key presence only, and <method>OcuPilot.Screen.Read.Project</method> emits a
/// declared field the vendor row does not carry as JSON <code>null</code> -- which reads back as
/// <code>""</code> and still satisfies that key check -- so a projection or endpoint
/// change that stopped answering a column would leave every gate green with a permanently blank
/// column.</p>
/// <p>Six of the eight declared fields are asserted. <code>System</code> is empty on every local
/// lock by design (that is what the column's <code>emptyKey</code> is for, AC10), and
/// <code>RoutineInfo</code> is the vendor's own optional line-and-routine string, so neither is a
/// value this can require.
/// <code>OSUserName</code> is asserted because it is the one the vendor appends conditionally --
/// <code>%SYS.LockQuery.WebListFilterFetch</code> adds it only when
/// <code>%SYS.ProcessQuery.%OpenId</code> succeeds for the row's pid -- and so the one most likely
/// to arrive empty.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.Project</method> emit <code>""</code> for every
/// declared field -> this goes red while
/// <method>TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow</method> stays green.</p>
Method TestTheLocksReadAnswersValuesNotEmptyKeys()
{
    Kill tNoCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.LockList", 1000, .tAnswer, .tHttp, .tFault, .tNoCriteria)
    Do $$$AssertStatusOK(tSC, "the Locks read completes")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If tHttp '= 200 Quit
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.rows), "it answers a rows array")
    If '($IsObject(tAnswer) && $IsObject(tAnswer.rows)) Quit
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "with at least one row -- every running instance's daemons hold locks of their own: " _ tAnswer.rows.%Size())
    If tAnswer.rows.%Size() = 0 Quit
    Set tRow = tAnswer.rows.%Get(0)
    For tField = "Pid", "OSUserName", "ModeCount", "Reference", "Directory", "DeleteID" {
        Do $$$AssertTrue(tRow.%Get(tField) '= "", "the live first row's '" _ tField _ "' carries a value, not an empty key: " _ tRow.%ToJSON())
    }
}

/// <p>Every production <code>mgmnt</code> read's declared read and context fields are keys of the live
/// management API port's first row in this namespace; a read that declares the
/// <code>application</code> criterion is read for <code>/api/ocupilot</code>, which every install
/// serves. A read that answers no row fails, and a roster with no mgmnt read fails rather than
/// passing over nothing.</p>
/// <p>Mutation: declare <code>Spec</code> in <class>OcuPilot.Screen.Descriptor.RestApiList</class>'s
/// read -&gt; this goes red naming the field.</p>
Method TestEveryDeclaredMgmntReadFieldIsAKeyOfTheLiveRow()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tChecked = 0
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tRead = $ClassMethod(tClass, "Read")
        If '$IsObject(tRead) Continue
        Set tSource = tRead.%Get("source")
        If '$IsObject(tSource) || (tSource.%Get("port") '= "mgmnt") Continue
        Set tChecked = tChecked + 1
        Kill tQuery
        Set tQuery("namespace") = $NAMESPACE
        If $ListFind(##class(OcuPilot.Screen.Read).CriteriaParams(tClass), "application") Set tQuery("application") = "/api/ocupilot"
        Set tPortSC = ##class(OcuPilot.Port.MgmntPort).Invoke(tSource.%Get("endpoint"), "LIST", .tQuery, "", .tAnswer, .tHttp, .tFault, .tDocument)
        Do $$$AssertStatusOK(tPortSC, tClass _ ": the live " _ tSource.%Get("endpoint") _ " read answers")
        If $$$ISERR(tPortSC) Continue
        Set tHasRow = $IsObject(tAnswer) && tAnswer.%IsA("%Library.DynamicArray") && (tAnswer.%Size() > 0)
        Do $$$AssertTrue(tHasRow, tClass _ ": and answers at least one row to hold the declared fields to")
        If 'tHasRow Continue
        Set tRow = tAnswer.%Get(0)
        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Do $$$AssertTrue(tRow.%GetTypeOf(tField) '= "unassigned", tClass _ ": declared read field '" _ tField _ "' is a key of the live row")
        }
        Set tContextFields = $ClassMethod(tClass, "ContextFields")
        For tJ = 1:1:$ListLength(tContextFields) {
            Set tField = $List(tContextFields, tJ)
            Do $$$AssertTrue(tRow.%GetTypeOf(tField) '= "unassigned", tClass _ ": declared context field '" _ tField _ "' is a key of the live row")
        }
    }
    Do $$$AssertEquals(tChecked, 2, "the two production mgmnt reads are checked: " _ tChecked)
}

/// <p>Story 6.13 -- the executor's <code>monitor</code> branch, against the live port: the declared
/// read answers rows carrying exactly the declared fields, the cap bounds them and the truncation
/// signal follows it. A roster with no monitor read fails rather than passing over nothing.</p>
/// <p>Mutation: delete the <code>monitor</code> arm from
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the read falls through to the admin port and
/// this goes red.</p>
Method TestEveryDeclaredMonitorReadFieldIsAKeyOfTheLiveRow()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tChecked = 0
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tRead = $ClassMethod(tClass, "Read")
        If '$IsObject(tRead) Continue
        Set tSource = tRead.%Get("source")
        If '$IsObject(tSource) || (tSource.%Get("port") '= "monitor") Continue
        Set tChecked = tChecked + 1

        Kill tCriteria
        Set tExecSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 5, .tResult, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tExecSC, tClass _ ": the declared read answers through the executor")
        If $$$ISERR(tExecSC) Continue
        Do $$$AssertEquals(tHttp, 200, tClass _ ": with 200")
        Do $$$AssertEquals(tResult.fields.%ToJSON(), tRead.%Get("fields").%ToJSON(), tClass _ ": the answer's fields are the declared ones")
        Do $$$AssertTrue(tResult.rows.%Size() <= 5, tClass _ ": and at most the cap's rows: " _ tResult.rows.%Size())
        If tResult.rows.%Size() = 0 Continue
        Set tRow = tResult.rows.%Get(0)
        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Do $$$AssertTrue(tRow.%GetTypeOf(tField) '= "unassigned", tClass _ ": declared read field '" _ tField _ "' is a key of the live row")
        }
    }
    Do $$$AssertEquals(tChecked, 1, "the one production monitor read is checked: " _ tChecked)
}

/// <p>Story 2.8 -- the declared banner is evaluated inside the read, against the real port, and it
/// is chrome rather than rows: a matching value answers its <code>messageKey</code>, a value the
/// declaration does not name answers <code>""</code>, and a banner whose endpoint no compiled class
/// answers also answers <code>""</code> <b>while the list still returns its rows and 200</b>.</p>
/// <p><b>It asserts, and never changes, that the instance's Task Manager is running.</b> The
/// matching arm is exercised by a fixture comparing <code>Status</code> to <code>Running</code>,
/// which is what the live endpoint then answers; the shipped descriptor compares it to
/// <code>Suspended</code>, so the same run exercises the non-matching arm. Both readings mean what
/// they claim only while the scheduler runs, so the precondition is checked rather than stated.
/// Suspending an instance to see the strip is the browser spec's, on the throwaway.</p>
/// <p>Mutations: make <method>OcuPilot.Screen.Read.BannerKey</method> return the
/// <code>messageKey</code> without comparing -> the non-matching assertion goes red. Let a port
/// failure out of it instead of answering <code>""</code> -> the faulting fixture's status, rows and
/// banner assertions go red together, and a vendor rename would take a screen's list down with
/// its strip.</p>
Method TestADeclaredBannerIsResolvedInsideTheReadAndNeverFailsIt()
{
    Do $$$AssertEquals(##class(%SYS.Task).TASKMGRStatus(), 1, "the Task Manager is running, which is what makes the Running fixture match and the shipped descriptor's empty banner a non-match rather than a suppressed fault")

    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Test.ReadBanner.Matching", 5, .tMatch, .tMatchHttp, .tMatchFault)
    Do $$$AssertStatusOK(tSC, "the matching fixture's read succeeds")
    Do $$$AssertEquals(tMatchHttp, 200, "and answers 200")
    If $IsObject(tMatch) {
        Do $$$AssertTrue(tMatch.rows.%Size() > 0, "with the instance's tasks listed: " _ tMatch.rows.%Size())
        ; DW-270: the fixture declares two cases and the matching one is the SECOND, so an engine
        ; that read cases[0] and stopped would answer "" here rather than this key.
        Do $$$AssertEquals(tMatch.banner, "taskManagerSuspendedBanner", "and the second declared case's messageKey, because Task.Manager answers the value that case names")
    }

    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.TaskScheduleList", 5, .tShipped, .tShippedHttp, .tShippedFault)
    Do $$$AssertStatusOK(tSC, "the shipped descriptor's read succeeds")
    Do $$$AssertEquals(tShippedHttp, 200, "and answers 200")
    If $IsObject(tShipped) {
        Do $$$AssertEquals(tShipped.%GetTypeOf("banner"), "string", "its answer carries the banner key")
        Do $$$AssertEquals(tShipped.banner, "", "and it is empty, because the Task Manager is not suspended on this instance")
    }

    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Test.ReadBanner.Faulting", 5, .tFaulted, .tFaultedHttp, .tFaultedFault)
    Do $$$AssertStatusOK(tSC, "a banner whose endpoint does not exist does not fail the read")
    Do $$$AssertEquals(tFaultedHttp, 200, "which still answers 200")
    If $IsObject(tFaulted) {
        Do $$$AssertTrue(tFaulted.rows.%Size() > 0, "with the full list of rows: " _ tFaulted.rows.%Size())
        Do $$$AssertEquals(tFaulted.banner, "", "and no strip, because the fault suppresses it rather than propagating")
    }

    ; A screen that declares no banner carries the key too, empty: the client reads one shape.
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.SslConfigList", 1, .tNone, .tNoneHttp, .tNoneFault)
    Do $$$AssertStatusOK(tSC, "a descriptor with no banner reads")
    If $IsObject(tNone) Do $$$AssertEquals(tNone.banner, "", "and answers an empty banner key rather than omitting it")
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
    Set tAccessors = $ListBuild("Route", "AreaKey", "LabelKey", "SideBarPosition", "Archetype", "IsBuilt", "PrivilegePairs", "PrimaryEntityType", "SecondaryEntityTypes", "EntityTypes", "Scope", "ParentScope", "IdKind", "IdParts", "ContextFields", "ContextSecretFields", "PrimaryActionId", "PrimaryActionSelfProtection", "RowActionIds", "EmptyStateKey", "CommandAliases", "ClassicPage", "ClassicLinkExempt", "ClassicLinkExemptionReason", "ClassicLinkHref", "ClassicLinkLabel", "Refreshes", "RefreshRates", "ToolIdentifier", "Read", "RowTarget")
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
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
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
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
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
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 404, "at the endpoint's status")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "PORT.NOTFOUND", "with the port's code")
    Do $$$AssertEquals(tObj.error, "not_found", "and slug")
}

/// <p>DW-270 -- a stopped Task Manager raises the task schedule's <b>own stopped sentence</b>,
/// resolved from the value rather than read off the declaration.</p>
/// <p><b>This is the case DW-270 exists for, and it was the unasserted one.</b> Every other
/// assertion about it compares the declaration to a typed copy of itself, or searches the vendor's
/// compiled source for the three words; none of them puts <code>Not running</code> through
/// <method>OcuPilot.Screen.Read.BannerKey</method>. The live endpoint answers <code>Running</code>
/// on any instance a test may touch, so the value is armed on
/// <class>OcuPilot.Test.EndpointFixture</class> instead, behind
/// <class>OcuPilot.Test.ReadBanner.Stopped</class> -- which carries the shipped block verbatim,
/// asserted here before it is driven, so a drifted fixture pins nothing.</p>
/// <p>Mutation (Rule 19): delete the <code>Not running</code> case from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -&gt; the block comparison and the
/// stopped assertion both go red here, while the suspended and running assertions stay green.
/// Change <method>BannerKey</method> to answer the first case's <code>messageKey</code> without
/// comparing -&gt; the stopped assertion reads the suspended key and goes red.</p>
Method TestTheStoppedTaskManagerRaisesItsOwnSentence()
{
    Set tShippedBanner = ##class(OcuPilot.Screen.Descriptor.TaskScheduleList).Banner()
    Set tFixtureBanner = ##class(OcuPilot.Test.ReadBanner.Stopped).Banner()
    Do $$$AssertTrue($IsObject(tShippedBanner) && $IsObject(tFixtureBanner), "both banners read")
    If '($IsObject(tShippedBanner) && $IsObject(tFixtureBanner)) Quit
    Do $$$AssertEquals(tFixtureBanner.cases.%ToJSON(), tShippedBanner.cases.%ToJSON(), "the fixture carries the shipped task schedule's cases verbatim, so what is driven below is the shipped mapping")
    Set tDeclSC = ##class(OcuPilot.Test.ReadBanner.Stopped).DeclarationJson(.tFixtureDecl)
    Do $$$AssertStatusOK(tDeclSC, "the fixture's declaration reads")
    If $$$ISOK(tDeclSC) Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tFixtureDecl), "", "and its banner is grammatical")

    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[{""Name"": ""OcuPilot fixture task""}]")

    ; The banner's GET carries no `name`, so the fixture answers the detail armed under the empty
    ; key -- which is how one endpoint fixture serves both the list and the banner in one read.
    Set tExpected("Not running") = "taskManagerStoppedBanner"
    Set tExpected("Suspended") = "taskManagerSuspendedBanner"
    Set tExpected("Running") = ""
    Set tStatus = ""
    For {
        Set tStatus = $Order(tExpected(tStatus))
        If tStatus = "" Quit
        Do ##class(OcuPilot.Test.EndpointFixture).SetDetails("{"""": {""Status"": """ _ tStatus _ """}}")
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Test.ReadBanner.Stopped", 5, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the read succeeds with Status '" _ tStatus _ "'")
        Do $$$AssertEquals(tHttp, 200, "and answers 200, because a banner is chrome over the rows")
        If $IsObject(tResult) {
            Do $$$AssertTrue(tResult.rows.%Size() > 0, "with its rows listed, whatever the banner says")
            Do $$$AssertEquals(tResult.banner, tExpected(tStatus), "Status '" _ tStatus _ "' raises the sentence the shipped descriptor declares for it")
        }
    }

    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>DW-274, the wire half -- a port fault that carries a structured <code>detail</code> reaches
/// the response body with that detail intact.</p>
/// <p><b>This is the last hop, and it was the unasserted one.</b>
/// <method>OcuPilot.Port.AdminPort.Denied</method> puts <code>detail.failedPair</code> on the
/// fault and <method>OcuPilot.Screen.Read.Execute</method> passes the fault straight through, but
/// the route builds the envelope itself: before this story it called
/// <method>OcuPilot.Api.Error.Render</method> with four arguments and dropped the detail. A 403
/// whose <code>failedPair</code> named the missing privilege at the port and lost it here is the
/// same unnamed denial AD-8 exists to prevent, and the sibling assertion at
/// <method>TestADeniedCallerIsRefusedBeforeThePort</method> cannot see it -- that one is the
/// <b>gate</b>'s own <code>Render</code> call, a different line.</p>
/// <p>Mutation (Rule 19): drop the <code>tFault.%Get("detail")</code> argument from
/// <method>OcuPilot.Api.ScreenRead.Handle</method>'s port-fault branch -&gt; the
/// <code>failedPair</code> assertion below goes red while
/// <method>TestTheRouteRendersAPortFault</method> stays green, because its fixture fault carries
/// no detail to lose.</p>
Method TestTheRouteCarriesAPortFaultsDetailOntoTheWire()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("errorstatus")
    Do ##class(OcuPilot.Test.PortFixture).SetQueryPairs("%Admin_Manage:USE|%DB_IRISSYS:WRITE")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 403, "the refused backing query answers 403 on the route, not 500")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "PORT.ACCESSDENIED", "with the port's own code")
    Do $$$AssertEquals(tObj.error, "forbidden", "and slug")
    Do $$$AssertTrue($IsObject(tObj.%Get("detail")), "and the envelope carries the fault's structured detail")
    If $IsObject(tObj.%Get("detail")) {
        Do $$$AssertEquals(tObj.detail.%Get("failedPair"), "%Admin_Manage:USE", "naming the pair the backing query requires")
    }
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>AC5, Story 6.11 -- against the real <code>Database.SysCRUD</code> endpoint, the Free-space
/// view's per-row <code>INFO</code> detail call is a genuine async hand-off (verified against the
/// instance: <code>ShouldRunAsync()</code> is true only for <code>TYPEINFO</code>), so the fixture
/// leaves the endpoint resolution and the 202 hand-off real and only arms the poll: every poll
/// answers <code>Running</code>, forever, and the bound is lowered to one second. The whole read is
/// refused, never partial, with the vendor task row left in place (no <code>forgot</code> record).</p>
/// <p>Mutation: make <method>OcuPilot.Port.AdminPort.AwaitTask</method> return the last poll's
/// <code>Result</code> on timeout instead of refusing -> this goes red on the status and the empty
/// result.</p>
Method TestTheFreeSpaceReadRefusesWholeWhenTheAsyncWaitIsExceeded()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Set tAnswer = {"State": "Running", "TaskName": "", "FailureReason": "", "Result": {}}
    Do ##class(OcuPilot.Test.PortFixture).SetCannedAnswer(tAnswer.%ToJSON())
    Do ##class(OcuPilot.Test.PortFixture).SetAsyncTimeout(1)
    Set tStart = $ZHorolog
    Kill tNoCriteria
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Screen.Descriptor.DatabaseFreeSpace", "", .tResult, .tHttp, .tFault, .tNoCriteria)
    Set tElapsed = $ZHorolog - tStart
    Do $$$AssertStatusNotOK(tSC, "the whole read is refused")
    Do $$$AssertEquals(tHttp, 503, "HTTP 503")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "PORT.TIMEOUT"), "code PORT.TIMEOUT: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: "(no fault)"))
    Do $$$AssertEquals(tResult, "", "no row carries a partial figure -- there is no partial result at all")
    Do $$$AssertTrue(tElapsed >= 1, "the port waited out the bound (" _ tElapsed _ "s)")
    Do $$$AssertTrue(tElapsed < 10, "and the bound is the fixture's one second, not the 30-second default")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("forgot"), "", "the vendor task row is left in place for whichever worker still owns it")
    Do ##class(OcuPilot.Test.PortFixture).Clear()
}

/// <p>AC8, Story 6.11 -- against a live database directory, Database details' read seeds
/// <code>Directory</code> from the route-id criterion (neither <code>GET</code> nor <code>INFO</code>
/// answers it), and the eight declared fields a live database always populates -- the four
/// <code>GET</code> properties <code>MaxSize</code>, <code>ExpansionSize</code>,
/// <code>ResourceName</code> and <code>GlobalJournalState</code>, and all four of the
/// <code>rowGet</code>'s -- carry real values on the live row rather than null-filled keys -- <method>TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow</method>
/// asserts key presence only, which a projection bug emitting <code>null</code> for a live key would
/// still satisfy.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.Project</method> emit every declared field as
/// JSON <code>null</code> -> this goes red naming the null-filled row, while the key-presence test
/// stays green.</p>
Method TestDatabaseDetailsSeedsDirectoryAndAnswersRealValues()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "LIST", .tQuery, "", .tDatabases, .tHttp, .tFault)
    Do $$$AssertStatusOK(tListSC, "the live database list answers")
    If $$$ISERR(tListSC) || (tDatabases.%Size() = 0) Quit
    Set tDir = tDatabases.%Get(0).Directory

    Kill tCriteria
    Set tCriteria("dir") = tDir
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.DatabaseDetails", "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "Database details reads a live directory")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If tHttp '= 200 Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "one row")
    If tResult.rows.%Size() = 0 Quit
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertEquals(tRow.%Get("Directory"), tDir, "Directory is seeded from the route-id criterion, since neither GET nor INFO answers it")
    For tField = "MaxSize", "ExpansionSize", "ResourceName", "GlobalJournalState", "Size", "AvailableSpace", "DiskFree", "Mounted" {
        Do $$$AssertTrue((tRow.%GetTypeOf(tField) '= "null") && (tRow.%GetTypeOf(tField) '= "unassigned"), "the live row's '" _ tField _ "' carries a real value, not a null-filled key: " _ tRow.%ToJSON())
    }
}

/// <p>AC9, Story 6.11 -- against a live single-file database, the new <code>VOLUMELIST</code>
/// source type answers one row through Database details' Volume files read, whose <code>File</code>
/// is <code>IRIS.DAT</code> and whose <code>VolumeNumber</code> is 0 -- the consumer exercising the
/// new source type against a real vendor answer, not the declaration alone
/// (<method>OcuPilot.Test.Descriptor.TestDatabaseVolumesDeclaresTheVendorSixAndNoDetailCall</method>
/// covers the shape).</p>
/// <p>Mutation: change <code>DatabaseVolumeList</code>'s source type to <code>LIST</code> -> this
/// goes red, since the endpoint then answers the database list's own fields rather than a volume
/// row; drop <code>VOLUMELIST</code> from <code>AdminPort.TYPESUFFIXES</code> -> the read fails at
/// <code>EndpointType</code> with <code>PORT.NOTIMPLEMENTED</code>.</p>
Method TestDatabaseVolumesAnswersOneRowForASingleFileDatabase()
{
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "LIST", .tQuery, "", .tDatabases, .tHttp, .tFault)
    Do $$$AssertStatusOK(tListSC, "the live database list answers")
    If $$$ISERR(tListSC) || (tDatabases.%Size() = 0) Quit
    Set tDir = tDatabases.%Get(0).Directory

    Kill tCriteria
    Set tCriteria("dir") = tDir
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.DatabaseVolumeList", "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "Database volumes reads a live directory")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If tHttp '= 200 Quit
    Do $$$AssertTrue(tResult.rows.%Size() > 0, "at least one volume file")
    If tResult.rows.%Size() = 0 Quit
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertEquals(tRow.%Get("VolumeNumber"), 0, "the vendor's own ordinal for the primary file")
    Do $$$AssertEquals(tRow.%Get("File"), "IRIS.DAT", "the primary volume file's own name")
    Do $$$AssertTrue(tRow.%Get("Size") > 0, "a real size, not a null-filled key")
}

/// <p>AC2, Story 6.12 -- against the live <code>Device.Standard</code> LIST, the Devices read
/// answers real values on <code>Name</code>, <code>PhysicalDevice</code>, <code>Type</code>,
/// <code>SubType</code> and <code>Description</code>, not null-filled keys, and reports no
/// truncation at the default cap (a stock instance carries a handful of devices, verified on the
/// throwaway at twelve).
/// <code>Alias</code> is not asserted here: it is empty on every stock row, which is exactly why
/// it declares no <code>emptyKey</code> and why <code>TestTheDevicesListDeclaresExactlyItsSixFieldsAndSixColumns</code>
/// (<class>OcuPilot.Test.Descriptor</class>) is the one that pins it as a declared field rather
/// than a live-valued one.</p>
/// <p>Mutation: drop <code>SubType</code> from <code>DeviceList</code>'s <code>read.fields</code>
/// -> this goes red on a declared field absent from the live row.</p>
Method TestTheDevicesReadAnswersRealValuesNotEmptyKeys()
{
    Kill tNoCriteria
    ; An empty cap, not the literal 1000, so the assertion below reads whatever
    ; OcuPilot.Screen.Read.DEFAULTMAXROWS currently is rather than a copy of it.
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.DeviceList", "", .tAnswer, .tHttp, .tFault, .tNoCriteria)
    Do $$$AssertStatusOK(tSC, "the Devices read completes")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If tHttp '= 200 Quit
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.rows), "it answers a rows array")
    If '($IsObject(tAnswer) && $IsObject(tAnswer.rows)) Quit
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "with at least one row -- every instance configures at least the standard devices: " _ tAnswer.rows.%Size())
    Do $$$AssertEquals(tAnswer.truncated, 0, "and reports no truncation at the default cap")
    If tAnswer.rows.%Size() = 0 Quit
    Set tRow = tAnswer.rows.%Get(0)
    For tField = "Name", "PhysicalDevice", "Type", "SubType", "Description" {
        Do $$$AssertTrue(tRow.%Get(tField) '= "", "the live first row's '" _ tField _ "' carries a value, not an empty key: " _ tRow.%ToJSON())
    }
}

}
