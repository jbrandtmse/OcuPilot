/// <p>The X.509, LDAP / Kerberos, Wallet and Secrets lists (Story 6.3): each descriptor's declaration
/// against the grammar, the classic-link rule, the registry and the Security and secrets area's pair
/// set; each read over the wire as the configured test principal (<class>OcuPilot.Test.Http</class>),
/// the X.509 list's certificate fields included; the Secrets list's two named faults; the key set of
/// every row the four reads, the four derived tools and the raw port LISTs answer, with no secret
/// key among them; and each derived read tool, which answers the route's rows narrowed by its
/// cap.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>, the demo fixture
/// (<parameter>DEMOCERT</parameter> and the <parameter>DEMOCOLLECTION</parameter> wallet collection
/// with its one secret), at least one LDAP configuration, and both the test principal and the
/// process running this class holding <code>%Admin_Secure:USE</code>, <code>%Admin_Wallet:USE</code>
/// and <code>%DB_IRISSYS:READ</code>: the key-set and tool tests call the port in process. It issues
/// reads only and creates nothing; the pair sets' denials are
/// <class>OcuPilot.Test.WireSecurityRead</class>'s.</p>
Class OcuPilot.Test.SecurityLists Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The demo fixture's X.509 credential alias.</p>
Parameter DEMOCERT = "OcuPilotDemoCert";

/// <p>The demo fixture's wallet collection.</p>
Parameter DEMOCOLLECTION = "OcuPilotDemo";

/// <p>The demo collection's one secret.</p>
Parameter DEMOSECRET = "OcuPilotDemo.Sample";

/// <p>The keys no row of these reads may carry: key material, a certificate body, a password and a
/// secret value, whatever the endpoint names them (AD-35).</p>
Parameter SECRETKEYS = "PrivateKey,PrivateKeyPassword,Certificate,HasPrivateKey,LDAPSearchPassword,Secret,Secret64,Value";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The four screens as <code>$ListBuild(descriptor, route, tool, side-bar position, entity type,
/// classic page, read fields as JSON, privileges as JSON, parent scope, the read's criterion query
/// suffix)</code>.</p>
ClassMethod Screens() As %List
{
    Set tSecure = "[{""resource"":""%Admin_Secure"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]"
    Set tWallet = "[{""resource"":""%Admin_Wallet"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]"
    Set tScreens = ""
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.X509CredentialList", "security/x509", "security.x509", 2, "x509-credential", "%CSP.UI.Portal.X509Credentials", "[""Alias"",""OwnerList"",""PeerNames"",""CAFile"",""SubjectDN"",""IssuerDN"",""ValidityNotBefore"",""ValidityNotAfter""]", tSecure, "", ""))
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.LdapConfigList", "security/ldap", "security.ldap", 3, "ldap-configuration", "%CSP.UI.Portal.LDAPs", "[""Name"",""Enabled"",""Description"",""LDAPCACertFile""]", tSecure, "", ""))
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.WalletCollectionList", "security/wallet", "security.wallet", 4, "wallet-collection", "", "[""Name"",""EditResource"",""UseResource""]", tWallet, "", ""))
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.WalletSecretList", "security/wallet/secrets", "security.secrets", 0, "wallet-secret", "", "[""Name"",""Type""]", tWallet, "security/wallet", "&collection=" _ ..#DEMOCOLLECTION))
    Quit tScreens
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var>, with <var>pQuery</var> appended, as
/// the test principal. <var>pAnswer</var> is the parsed body, or <code>""</code>, and a body that
/// does not parse is a failed assertion.</p>
Method Read(pTool As %String, pMaxRows As %Integer, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?maxRows=" _ pMaxRows _ pQuery, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The first row of <var>pRows</var> whose <var>pKey</var> is <var>pValue</var>, or
/// <code>""</code>.</p>
ClassMethod RowWhere(pRows As %DynamicArray, pKey As %String, pValue As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get(pKey) = pValue {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>The keys of <var>pRow</var>, in order, as a JSON array.</p>
ClassMethod KeysOf(pRow As %DynamicObject) As %String
{
    Set tKeys = []
    Set tIterator = pRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Quit tKeys.%ToJSON()
}

/// <p>What is wrong with <var>pRows</var>' key sets, or <code>""</code>: every row carries exactly
/// <var>pFields</var>, in that order, and no key <parameter>SECRETKEYS</parameter> names.</p>
ClassMethod KeySetProblem(pRows As %DynamicArray, pFields As %String) As %String
{
    Set tBad = ""
    Set tSecrets = $ListFromString(..#SECRETKEYS)
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            If $ListFind(tSecrets, tKey) Set tBad = "row " _ tIndex _ " carries the secret key " _ tKey
        }
        If (tBad = "") && (..KeysOf(tRow) '= pFields) Set tBad = "row " _ tIndex _ " carries " _ ..KeysOf(tRow)
        If tBad '= "" Quit
    }
    Quit tBad
}

/// <p>Each descriptor passes the read grammar, the criteria grammar and the classic-link rule; its
/// route and tool identifier resolve to it; its classic page is a class compiled on this instance
/// under the declaration's own case, or is <code>""</code> (AD-44); it is the declared Security and
/// secrets entry, on its entity type and at instance scope, with no action, no refresh and no secret
/// field; its context fields are its read fields; its pair set is the one this class pins, in that
/// order; and <code>AreaCoverageProblem("security", ...)</code> is empty.</p>
Method TestEachListIsDeclaredAsTheSecurityAreaEntryItReplaces()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": and so are its criteria")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tClass _ ": and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute($List(tCase, 2)), tClass, tClass _ ": the route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 3)), tClass, tClass _ ": and so does its tool identifier")

        Set tPage = $ClassMethod(tClass, "ClassicPage")
        Do $$$AssertEquals(tPage, $List(tCase, 6), tClass _ ": the classic page is the one this class pins")
        If tPage '= "" Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), tClass _ ": which is a compiled class on this instance, found under the declaration's own case")

        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "security", tClass _ ": in the Security and secrets area")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 4), tClass _ ": at its side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), $List(tCase, 9), tClass _ ": declaring its parent, or none")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", tClass _ ": on the list archetype")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), $List(tCase, 5), tClass _ ": on its one entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ ": at instance scope")
        Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "single", tClass _ ": keyed by one id")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tClass _ ": and it does not refresh")
        Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), $List(tCase, 7), tClass _ ": its read fields are the ones this class pins")
        Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), tClass _ ": its context fields are its read fields")
        Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, tClass _ ": with no secret field")
        Do $$$AssertEquals(tDeclaration.read.sort.direction, "asc", tClass _ ": sorting ascending")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey, "tableReadOnlyEmptyNext", tClass _ ": its empty state names what to do next")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tClass _ ": because it declares no action")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), $List(tCase, 8), tClass _ ": its pair set, in order")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", $ClassMethod(tClass, "PrivilegePairs")), "", tClass _ ": and the Security and secrets area covers it")
    }
}

/// <p>Matrix "X.509", AC2 -- the whole read answers the eight declared fields, and the
/// <parameter>DEMOCERT</parameter> row carries the certificate read's subject and issuer, each naming
/// <code>CN=OcuPilotDemo</code>, and both validity dates, equal to the live <code>CERTINFO</code>'s
/// own answer for that alias.</p>
/// <p>Mutation: issue a fixed <code>GET</code> in <method>OcuPilot.Screen.Read.DetailRow</method>
/// -&gt; the subject, issuer and validity assertions go red.</p>
Method TestTheX509ListReadsItsCertificateFieldsOverTheWire()
{
    Set tSC = ..Read("security.x509", 1000, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Screens(), 1), 7), "fields are the eight declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Set tRow = ..RowWhere(tAnswer.rows, "Alias", ..#DEMOCERT)
    Do $$$AssertTrue($IsObject(tRow), "the demo credential is listed among " _ tAnswer.rows.%Size() _ " rows")
    If '$IsObject(tRow) Quit
    Do $$$AssertTrue(tRow.SubjectDN [ "CN=OcuPilotDemo", "its SubjectDN names CN=OcuPilotDemo: " _ tRow.SubjectDN)
    Do $$$AssertTrue(tRow.IssuerDN [ "CN=OcuPilotDemo", "and so does its IssuerDN: " _ tRow.IssuerDN)
    Do $$$AssertTrue(tRow.ValidityNotBefore '= "", "its validity start is present: " _ tRow.ValidityNotBefore)
    Do $$$AssertTrue(tRow.ValidityNotAfter '= "", "and so is its end: " _ tRow.ValidityNotAfter)

    Kill tQuery
    Set tQuery("alias") = ..#DEMOCERT
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.X509Credential", "CERTINFO", .tQuery, "", .tInfo, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live CERTINFO answers for the demo alias")
    If $$$ISERR(tSC) || '$IsObject(tInfo) Quit
    For tField = "SubjectDN", "IssuerDN", "ValidityNotBefore", "ValidityNotAfter" {
        Do $$$AssertEquals(tRow.%Get(tField), tInfo.%Get(tField), "the row's " _ tField _ " is the certificate read's")
    }
}

/// <p>Matrix "LDAP" -- the whole read answers the four declared fields, untruncated, with at least
/// one row and a boolean <code>Enabled</code> on every row.</p>
Method TestTheLdapListReadsOverTheWire()
{
    Set tSC = ..Read("security.ldap", 1000, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Screens(), 2), 7), "fields are the four declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "the instance's LDAP configurations are listed: " _ tAnswer.rows.%Size())
    Set tBad = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%GetTypeOf("Enabled") '= "boolean" Set tBad = tRow.Name _ " has an Enabled that is " _ tRow.%GetTypeOf("Enabled")
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row's Enabled is a boolean")
}

/// <p>Matrix "Wallet" -- the whole read answers the three declared fields, untruncated, with the
/// demo collection among its rows.</p>
Method TestTheWalletListReadsOverTheWire()
{
    Set tSC = ..Read("security.wallet", 1000, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Screens(), 3), 7), "fields are the three declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Do $$$AssertTrue($IsObject(..RowWhere(tAnswer.rows, "Name", ..#DEMOCOLLECTION)), "the demo collection is listed among " _ tAnswer.rows.%Size() _ " rows")
}

/// <p>Matrix "Secrets", "Unknown collection" and "No collection" -- read for the demo collection, the
/// list answers its two declared fields with the demo secret typed <code>%Wallet.KeyValue</code>; for
/// a collection that does not exist it answers 404 and for no collection 400, each a named fault
/// with no rows.</p>
Method TestTheSecretsListReadsOneCollection()
{
    Set tSC = ..Read("security.secrets", 1000, "&collection=" _ ..#DEMOCOLLECTION, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers for the demo collection")
    If (tStatus = 200) && $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Name"",""Type""]", "fields are the two declared fields")
        Set tRow = ..RowWhere(tAnswer.rows, "Name", ..#DEMOSECRET)
        Do $$$AssertTrue($IsObject(tRow), "the demo secret is listed: " _ tAnswer.rows.%ToJSON())
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Type, "%Wallet.KeyValue", "as a key-value secret")
    }

    For tCase = $ListBuild("&collection=NoSuchCollection", 404, "an unknown collection"), $ListBuild("", 400, "no collection") {
        Set tSC = ..Read("security.secrets", 1000, $List(tCase, 1), .tFaultStatus, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 3) _ ": the request completes")
        Do $$$AssertEquals(tFaultStatus, $List(tCase, 2), $List(tCase, 3) _ ": answers " _ $List(tCase, 2))
        If '$IsObject(tFault) Continue
        Do $$$AssertTrue(tFault.%Get("code") '= "", $List(tCase, 3) _ ": with a named fault: " _ tFault.%ToJSON())
        Do $$$AssertEquals(tFault.%GetTypeOf("rows"), "unassigned", $List(tCase, 3) _ ": and no rows")
    }
}

/// <p>AC4 -- every row the four reads answer over the wire and every row the four read tools answer
/// carries exactly the declared fields, and none carries a key <parameter>SECRETKEYS</parameter>
/// names; and for the LDAP / Kerberos, Wallet and Secrets lists, every raw port LIST row's key set is
/// the declared fields, so nothing is projected away there. The X.509 LIST row's own
/// <code>HasPrivateKey</code> is the one key a read projects away.</p>
/// <p>Mutation: add <code>Value</code> to <class>OcuPilot.Screen.Descriptor.WalletSecretList</class>'s
/// read and context fields -&gt; the raw key-set and route key-set assertions go red.</p>
Method TestEveryRowCarriesTheDeclaredFieldsAndNoSecret()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tClass = $List(tCase, 1)
        Set tTool = $List(tCase, 3)
        Set tFields = $List(tCase, 7)
        Set tQuery = $List(tCase, 10)

        Set tSC = ..Read(tTool, 1000, tQuery, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers")
        If (tStatus = 200) && $IsObject(tAnswer) {
            Do $$$AssertTrue(tAnswer.rows.%Size() > 0, tTool _ ": with rows: " _ tAnswer.rows.%Size())
            Do $$$AssertEquals(..KeySetProblem(tAnswer.rows, tFields), "", tTool _ ": every route row carries exactly the declared fields and no secret")
        }

        Set tArgs = {}
        If tQuery '= "" Do tArgs.%Set("collection", ..#DEMOCOLLECTION)
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, tArgs, 1000, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISOK(tSC) && $IsObject(tView) {
            Do $$$AssertTrue(tView.rows.%Size() > 0, tTool _ ": the tool answers rows: " _ tView.rows.%Size())
            Do $$$AssertEquals(..KeySetProblem(tView.rows, tFields), "", tTool _ ": every tool row carries exactly the declared fields and no secret")
        }

        If tClass = "OcuPilot.Screen.Descriptor.X509CredentialList" Continue
        Kill tPortQuery
        If tQuery '= "" Set tPortQuery("collection") = ..#DEMOCOLLECTION
        Set tRead = $ClassMethod(tClass, "Read")
        Set tEndpoint = tRead.source.endpoint
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(tEndpoint, "LIST", .tPortQuery, "", .tRaw, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tClass _ ": the live " _ tEndpoint _ " LIST answers")
        If $$$ISERR(tSC) || '$IsObject(tRaw) Continue
        Do $$$AssertTrue(tRaw.%Size() > 0, tClass _ ": with raw rows to hold the declared fields to")
        Do $$$AssertEquals(..KeySetProblem(tRaw, tRead.fields.%ToJSON()), "", tClass _ ": every raw LIST row's key set is the declared fields " _ tRead.fields.%ToJSON())
    }
}

/// <p>Matrix "Tool", and the integration AC -- the read tool over each screen, the Secrets list's
/// with <code>collection</code>, at a context cap of one, answers only <code>fields</code>,
/// <code>rows</code> and <code>truncated</code>: the route's fields and the first row of the route's
/// rows in the declared default order.</p>
/// <p>Each of these lists answers one row on a fresh throwaway, so no cap here cuts a row: the cap
/// cutting rows is <method>OcuPilot.Test.PermissionsLists.TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap</method>'s,
/// over the same <method>OcuPilot.Screen.Tool.Read.View</method>.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 3) _ ".read"
        Set tQuery = $List(tCase, 10)
        Set tCap = 1

        Set tArgs = {}
        If tQuery '= "" Do tArgs.%Set("collection", ..#DEMOCOLLECTION)
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, tArgs, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tSC = ..Read($List(tCase, 3), 1000, tQuery, .tStatus, .tRoute)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Do $$$AssertTrue(tOrdered.%Size() >= tCap, tTool _ ": the route has at least the cap's rows: " _ tOrdered.%Size())
        Set tWanted = []
        For tJ = 0:1:(tCap - 1) Do tWanted.%Push(tOrdered.%Get(tJ))

        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the route's fields")
        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Do $$$AssertEquals(tView.truncated, (tOrdered.%Size() > tCap), tTool _ ": reporting a cut exactly when the route has more rows")
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "fields,rows,truncated,rowsAvailable", tTool _ ": and nothing else")
    }
}

}
