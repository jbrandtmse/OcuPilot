/// <p>Pins Story 2.2's instance-side acceptance criteria: the committed
/// <class>OcuPilot.Screen.Tool.FieldLists</class> equals a fresh derivation (AC1), the port resolves
/// a body template in AD-3's order (AC2), the three template credentials are string literals and
/// no derived list carries a wrapper credential (AC4), and the class-derived and
/// no-template lists are exactly what AD-3 names (AC5).</p>
/// <p>Needs the running instance's admin API at version 2; changes nothing on it. The order test
/// arms <class>OcuPilot.Test.PortFixture</class> and clears it after every test.</p>
Class OcuPilot.Test.DerivedFields Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Quit $$$OK
}

/// <p>AC1 -- the committed lists and the instance agree, list for list and row for row, position
/// included. A failure names each list and path that differs.</p>
/// <p>Mutation: change one row's <code>shape</code> in <file>FieldLists.cls</file> and load it ->
/// this goes red naming that list and path.</p>
Method TestTheCommittedListsEqualAFreshDerivation()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the lists derive from the instance")
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Stored(.tStored)
    Do $$$AssertStatusOK(tSC, "the committed lists parse")
    Set tDrift = ..Drift(.tLive, .tStored)
    Do $$$AssertEquals(tDrift, "", "the committed lists and the instance agree" _ $Select(tDrift = "": "", 1: ": " _ tDrift))
}

/// <p>AC1 -- one list per template endpoint (40), three wallet lists, one audit-event list and
/// three <code>none</code> entries, and every row carries a shape and an informational type.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Test.FieldDerive.WALLETTYPES</parameter> -> the wallet
/// list count goes red.</p>
Method TestEveryTemplateEndpointHasOneList()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the lists derive from the instance")
    Set tSC = ##class(OcuPilot.Test.AdminInventory).Derive(.tInventory)
    Do $$$AssertStatusOK(tSC, "the inventory derives from the instance")

    Set tMissing = ""
    Set tClass = ""
    For {
        Set tClass = $Order(tInventory(tClass))
        Quit:tClass=""
        If $Piece(tInventory(tClass), "|", 1) = "" Continue
        If $Piece($Get(tLive(tClass)), "|", 2) '= "template" Set tMissing = tMissing _ " " _ tClass
    }
    Do $$$AssertEquals(tMissing, "", "every endpoint publishing a template has a template list" _ $Select(tMissing = "": "", 1: "; missing:" _ tMissing))

    Set (tTemplate, tWallet, tAudit, tMetadata, tNone) = 0
    Set tMalformedRows = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tLive(tKey))
        Quit:tKey=""
        Set tSource = $Piece(tLive(tKey), "|", 2)
        If tSource = "template" Set tTemplate = tTemplate + 1
        If (tSource = "class") && ($Piece(tLive(tKey), "|", 1) = "Wallet.Secret") Set tWallet = tWallet + 1
        If (tSource = "class") && ($Piece(tLive(tKey), "|", 1) = "Security.Audit.Event") Set tAudit = tAudit + 1
        If (tSource = "class") && ($Piece(tLive(tKey), "|", 1) = "Security.OAuth2.Client.ServerDefinition") Set tMetadata = tMetadata + 1
        If tSource = "none" Set tNone = tNone + 1
        Set tN = ""
        For {
            Set tN = $Order(tLive(tKey, tN), 1, tRow)
            Quit:tN=""
            If '$ListFind($ListBuild("literal", "object", "array"), $Piece(tRow, "|", 2)) || ($Piece(tRow, "|", 3) = "") {
                Set tMalformedRows = tMalformedRows _ " " _ tKey _ ":" _ $Piece(tRow, "|", 1)
            }
        }
    }
    Do $$$AssertEquals(tTemplate, 40, "40 template lists")
    Do $$$AssertEquals(tWallet, 3, "3 wallet secret lists, one per Type")
    Do $$$AssertEquals(tAudit, 1, "1 audit event list")
    Do $$$AssertEquals(tMetadata, 1, "1 server description metadata list")
    Do $$$AssertEquals(tNone, 3, "3 endpoints recorded as needing no template")
    Do $$$AssertEquals(tMalformedRows, "", "every row carries a shape and a template type" _ $Select(tMalformedRows = "": "", 1: "; malformed:" _ tMalformedRows))
}

/// <p>AC2 -- an endpoint class defining more than one template method resolves to the earliest in
/// AD-3's order, evaluated on an endpoint constructed at API version 2; a class defining none is
/// refused with an error status. Four fixtures pin each adjacent pair of AD-3's order, and
/// <class>OcuPilot.Test.TemplateFixtureLate</class> pins that an inherited template does not
/// count.</p>
/// <p>Mutation: swap any two adjacent names in
/// <parameter>OcuPilot.Port.AdminPort.TEMPLATENAMES</parameter> -> a fixture assertion goes red;
/// accept an inherited definition in <method>OcuPilot.Port.AdminPort.TemplateMethod</method> ->
/// the <code>TemplateFixtureLate</code> assertion goes red.</p>
Method TestTheEarliestTemplateInOrderIsUsed()
{
    For tCase = "TemplateFixture:PutRequestBodySchema", "TemplateFixtureLate:PutAndPostSchema", "TemplateFixtureMiddle:PutRequestBodySchema", "TemplateFixtureEarly:RequestBodySchema" {
        Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test." _ $Piece(tCase, ":", 1))
        Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TemplateMethod("Fixture"), $Piece(tCase, ":", 2), $Piece(tCase, ":", 1) _ " resolves to " _ $Piece(tCase, ":", 2))
    }

    Set tOrigNS = $Namespace
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.TemplateFixture")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TemplateMethod("Fixture"), "PutRequestBodySchema", "the earlier of two template methods is the template")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Template("Fixture", .tTemplate, .tMethod)
    Do $$$AssertStatusOK(tSC, "the template evaluates")
    Do $$$AssertEquals(tMethod, "PutRequestBodySchema", "and names the method it called")
    Do $$$AssertEquals($Select($IsObject(tTemplate): tTemplate.marker, 1: ""), "PutRequestBodySchema", "and returns that method's answer")
    Do $$$AssertEquals($Select($IsObject(tTemplate): tTemplate.apiVersion, 1: ""), 2, "from an endpoint constructed at API version 2")
    Do $$$AssertEquals($Namespace, tOrigNS, "the caller's namespace is restored")

    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TemplateMethod("Fixture"), "", "a class defining no template method has none")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Template("Fixture", .tTemplate, .tMethod)
    Do $$$AssertStatusNotOK(tSC, "and evaluating its template is refused")
    Do $$$AssertEquals(tTemplate, "", "with no template returned")
}

/// <p>AC4 -- derivation reads templates only. The three template credentials are present as string
/// literals, <code>SSLConfig</code>'s only because its template is called with argument 1;
/// <code>Security.User</code>'s list holds no <code>Password</code>, no derived list holds a
/// <code>NewPassword</code>, and <code>Security.User</code>'s <code>ChangePassword</code> is a
/// boolean.</p>
/// <p>Mutation: remove <code>Security.SSLConfig:1</code> from
/// <parameter>OcuPilot.Port.AdminPort.TEMPLATEARGUMENTS</parameter> -> the
/// <code>SSLConfig</code> assertion goes red.</p>
Method TestTheTemplateCredentialsAreStringLiterals()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the lists derive from the instance")

    Do $$$AssertEquals(..Row(.tLive, "Security.Encryption.Settings", "AdminPassword"), "literal|string", "Security.Encryption.Settings AdminPassword is a string literal")
    Do $$$AssertEquals(..Row(.tLive, "Security.X509Credential", "PrivateKeyPassword"), "literal|string", "Security.X509Credential PrivateKeyPassword is a string literal")
    Do $$$AssertEquals(..Row(.tLive, "Security.SSLConfig", "PrivateKeyPassword"), "literal|string", "Security.SSLConfig PrivateKeyPassword is a string literal")

    Set tWrapper = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tLive(tKey))
        Quit:tKey=""
        Set tN = ""
        For {
            Set tN = $Order(tLive(tKey, tN), 1, tRow)
            Quit:tN=""
            Set tPath = $Piece(tRow, "|", 1)
            Set tLast = $Piece($Piece(tPath, ".", $Length(tPath, ".")), "[", 1)
            If (tLast = "NewPassword") || ((tKey = "Security.User") && (tLast = "Password")) Set tWrapper = tWrapper _ " " _ tKey _ ":" _ tPath
        }
    }
    Do $$$AssertTrue($Data(tLive("Security.User", 1)), "Security.User's list has rows")
    Do $$$AssertEquals(tWrapper, "", "no derived list carries a wrapper credential" _ $Select(tWrapper = "": "", 1: "; found:" _ tWrapper))
    Do $$$AssertEquals(..Row(.tLive, "Security.User", "ChangePassword"), "literal|boolean", "and ChangePassword is a boolean, not a credential")
}

/// <p>AC5 -- the class-derived lists are exactly AD-3's: <code>%Wallet.KeyValue</code> 5,
/// <code>%Wallet.SymmetricKey</code> 4, <code>%Wallet.RSA</code> 12 and <code>Security.Events</code>
/// 2, and <code>OAuth2.Server.Metadata</code> 44 under the <code>Metadata</code> envelope (Story
/// 12.4), each wallet list recording its <code>Type</code> value and body member; and the wallet
/// <code>Type</code>s derived are exactly the instance's concrete <code>%Wallet.Secret</code>
/// subclasses.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Test.FieldDerive.WALLETIDENTIFYING</parameter> -> the
/// three wallet list assertions go red; drop <code>%Wallet.RSA</code> from
/// <parameter>OcuPilot.Test.FieldDerive.WALLETTYPES</parameter> -> the subclass assertion goes
/// red.</p>
Method TestTheClassDerivedListsAreExact()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the lists derive from the instance")

    Set tConcrete = ""
    Set tStmt = ##class(%SQL.Statement).%New()
    Set tSC = tStmt.%Prepare("SELECT %EXACT(Name) AS Name FROM %Dictionary.CompiledClass WHERE PrimarySuper [ ? AND Abstract = 0 ORDER BY %EXACT(Name)")
    Do $$$AssertStatusOK(tSC, "the wallet subclass query prepares")
    If $$$ISOK(tSC) {
        Set tRs = tStmt.%Execute("~%Wallet.Secret~")
        While tRs.%Next() {
            Set tConcrete = tConcrete _ $Select(tConcrete = "": "", 1: ",") _ tRs.%Get("Name")
        }
        Do $$$AssertTrue(tRs.%SQLCODE >= 0, "the wallet subclass query runs to its end")
    }
    Do $$$AssertEquals(tConcrete, ##class(OcuPilot.Test.FieldDerive).#WALLETTYPES, "one wallet list per concrete %Wallet.Secret subclass on the instance")

    Do $$$AssertEquals(..Paths(.tLive, "Wallet.Secret:%Wallet.KeyValue"), "AllowedHosts,RequireTLS,Secret,Secret64,Usage", "%Wallet.KeyValue is 5 fields")
    Do $$$AssertEquals(..Paths(.tLive, "Wallet.Secret:%Wallet.SymmetricKey"), "KeyId,Length,Secret,Secret64", "%Wallet.SymmetricKey is 4 fields")
    Do $$$AssertEquals(..Paths(.tLive, "Wallet.Secret:%Wallet.RSA"), "Certificate,CertificateFile,HasCertificate,HasPrivateKey,Length,Password,PrivateKey,PrivateKeyFile,PublicKey,PublicKeyFile,Secret,Secret64", "%Wallet.RSA is 12 fields")
    Do $$$AssertEquals(..Paths(.tLive, "Security.Audit.Event:Security.Events"), "Description,Enabled", "Security.Events is 2 fields")
    ; Story 12.4: the server description's Metadata members, derived from the class its endpoint
    ; imports them into, under the Metadata envelope.
    Set tKey = "Security.OAuth2.Client.ServerDefinition:OAuth2.Server.Metadata"
    Do $$$AssertEquals($Piece($Get(tLive(tKey)), "|", 2, 6), "class||OAuth2.Server.Metadata||Metadata", "the metadata list is class-derived under the Metadata envelope")
    Kill tShapes
    Set tN = ""
    For {
        Set tN = $Order(tLive(tKey, tN), 1, tRow)
        Quit:tN=""
        Set tShapes($Piece(tRow, "|", 2, 3)) = $Get(tShapes($Piece(tRow, "|", 2, 3))) + 1
    }
    Do $$$AssertEquals($Get(tShapes("literal|string")) _ "/" _ $Get(tShapes("array|array")) _ "/" _ $Get(tShapes("literal|boolean")), "12/26/6", "OAuth2.Server.Metadata is 44 members: 12 URIs, 26 lists and 6 flags")

    For tType = "%Wallet.KeyValue", "%Wallet.RSA", "%Wallet.SymmetricKey" {
        Set tHeader = $Get(tLive("Wallet.Secret:" _ tType))
        Do $$$AssertEquals($Piece(tHeader, "|", 5, 6), tType _ "|WalletSecretConfig", tType _ " records its Type value and the WalletSecretConfig member")
    }
    Do $$$AssertEquals(..Row(.tLive, "Wallet.Secret:%Wallet.KeyValue", "AllowedHosts"), "array|array", "a LIST property is an array")
    Do $$$AssertEquals(..Row(.tLive, "Wallet.Secret:%Wallet.RSA", "Password"), "literal|string", "and the RSA password is a string literal")
}

/// <p>AC5 -- <code>Process</code>, <code>Lock</code> and <code>Task.Manager</code> are recorded as
/// needing no template, and none of them publishes one.</p>
/// <p>Mutation: remove <code>Lock</code> from
/// <parameter>OcuPilot.Test.FieldDerive.NOTEMPLATE</parameter> -> this goes red.</p>
Method TestTheActionEndpointsNeedNoTemplate()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the lists derive from the instance")
    For tEndpoint = "Process", "Lock", "Task.Manager" {
        Do $$$AssertEquals($Piece($Get(tLive(tEndpoint)), "|", 2), "none", tEndpoint _ " is recorded as needing no template")
        Do $$$AssertEquals($Data(tLive(tEndpoint, 1)), 0, tEndpoint _ " carries no rows")
        Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).TemplateMethod(tEndpoint), "", tEndpoint _ " publishes no template")
    }
}

/// <p>Regeneration determinism -- the premise <file>scripts/field-lists.sh</file> runs on:
/// two calls to <method>OcuPilot.Test.FieldDerive.Regenerate</method> against the same instance
/// state produce byte-identical source, so running the script twice writes the same file and a
/// rerun never shows spurious drift.</p>
/// <p>Mutation: append <code>$ZTimeStamp</code> to the generated text in
/// <method>OcuPilot.Test.FieldDerive.Regenerate</method>, just before <code>Set pSource = tText</code>
/// -> this goes red.</p>
Method TestRegenerationIsDeterministic()
{
    Set tSC1 = ##class(OcuPilot.Test.FieldDerive).Regenerate(.tSource1)
    Do $$$AssertStatusOK(tSC1, "the first regeneration succeeds")
    Set tSC2 = ##class(OcuPilot.Test.FieldDerive).Regenerate(.tSource2)
    Do $$$AssertStatusOK(tSC2, "the second regeneration succeeds")
    Do $$$AssertEquals(tSource2, tSource1, "two regenerations against the same instance state are byte-identical")
}

/// <p>AC1 -- the committed <class>OcuPilot.Screen.Tool.FieldLists</class> is what
/// <file>scripts/field-lists.sh</file> would write: its source, as the class compiler renders it
/// back, equals a regeneration apart from trailing line ends, so a hand-edited header, a reordered
/// list or a reformatted row fails here rather than at the next regeneration.</p>
/// <p>Mutation: change the two-space row indent in
/// <method>OcuPilot.Test.FieldDerive.Regenerate</method> to one space -> this goes red.</p>
Method TestTheCommittedClassIsARegeneration()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Regenerate(.tSource)
    Do $$$AssertStatusOK(tSC, "the class regenerates")
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, ##class(OcuPilot.Test.FieldDerive).#FIELDLISTSCLASS, .tCommitted)
    Do $$$AssertStatusOK(tSC, "the committed class's source reads back")
    Set tCommitted = $ZStrip($Replace(tCommitted, $Char(13, 10), $Char(10)), ">", $Char(10))
    Set tFirst = ""
    If tCommitted '= tSource {
        Set tLines = $Length(tSource, $Char(10))
        If $Length(tCommitted, $Char(10)) > tLines Set tLines = $Length(tCommitted, $Char(10))
        For tI = 1:1:tLines {
            If $Piece(tSource, $Char(10), tI) '= $Piece(tCommitted, $Char(10), tI) {
                Set tFirst = "line " _ tI _ " committed=" _ $Piece(tCommitted, $Char(10), tI) _ " regenerated=" _ $Piece(tSource, $Char(10), tI)
                Quit
            }
        }
    }
    Do $$$AssertEquals(tFirst, "", "the committed class equals a regeneration" _ $Select(tFirst = "": "", 1: "; first difference at " _ tFirst))
}

/// <p>AC1 -- a template the derivation cannot write as rows is an error status, never a shorter
/// list: an array with more than one element, or a member name that is not a path segment
/// <file>ui/tools/field-lists.mjs</file> accepts. A writable template walks to one row per node,
/// in template order.</p>
/// <p>Mutation: delete the <code>%Size() &gt; 1</code> refusal in
/// <method>OcuPilot.Test.FieldDerive.WalkMembers</method> -> this goes red.</p>
Method TestAnUnwritableTemplateIsAnErrorNotAShorterList()
{
    Set tSC = ##class(OcuPilot.Test.FieldDerive).WalkMembers([{"a":""},{"b":""}], "", "Probe", .tRows)
    Do $$$AssertStatusNotOK(tSC, "an array with more than one element is refused")
    For tMember = "a.b", "Content-Type", "a b" {
        Set tTemplate = {}
        Do tTemplate.%Set(tMember, "")
        Kill tRows
        Set tSC = ##class(OcuPilot.Test.FieldDerive).WalkMembers(tTemplate, "", "Probe", .tRows)
        Do $$$AssertStatusNotOK(tSC, "a member named '" _ tMember _ "' is refused")
    }
    Kill tRows
    Set tSC = ##class(OcuPilot.Test.FieldDerive).WalkMembers({"A":{"B":""},"C":[true]}, "", "Probe", .tRows)
    Do $$$AssertStatusOK(tSC, "a writable template walks")
    Set tWalked = ""
    For tN = 1:1:5 Set tWalked = tWalked _ $Get(tRows("Probe", tN)) _ ";"
    Do $$$AssertEquals(tWalked, "A|object|object|;A.B|literal|string|;C|array|array|boolean;C[]|literal|boolean|;;", "one row per node, in template order, and no more")
}

/// <p>Every difference between two list sets, as one <code>; </code>-joined string naming list and
/// path; <code>""</code> when they agree.</p>
Method Drift(ByRef pLive, ByRef pStored) As %String [ Private ]
{
    Set tDrift = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pLive(tKey))
        Quit:tKey=""
        If '$Data(pStored(tKey)) {
            Set tDrift = tDrift _ "; " _ tKey _ " is derived and not committed"
            Continue
        }
        If pLive(tKey) '= pStored(tKey) Set tDrift = tDrift _ "; " _ tKey _ " header committed=" _ pStored(tKey) _ " derived=" _ pLive(tKey)
        Kill tLiveRows, tStoredRows
        Do ..IndexRows(.pLive, tKey, .tLiveRows)
        Do ..IndexRows(.pStored, tKey, .tStoredRows)
        Set tPath = ""
        For {
            Set tPath = $Order(tLiveRows(tPath))
            Quit:tPath=""
            If '$Data(tStoredRows(tPath)) {
                Set tDrift = tDrift _ "; " _ tKey _ " " _ tPath _ " is derived and not committed"
            } ElseIf tStoredRows(tPath) '= tLiveRows(tPath) {
                Set tDrift = tDrift _ "; " _ tKey _ " " _ tPath _ " committed=" _ tStoredRows(tPath) _ " derived=" _ tLiveRows(tPath)
            }
        }
        Set tPath = ""
        For {
            Set tPath = $Order(tStoredRows(tPath))
            Quit:tPath=""
            If '$Data(tLiveRows(tPath)) Set tDrift = tDrift _ "; " _ tKey _ " " _ tPath _ " is committed and not derived"
        }
    }
    Set tKey = ""
    For {
        Set tKey = $Order(pStored(tKey))
        Quit:tKey=""
        If '$Data(pLive(tKey)) Set tDrift = tDrift _ "; " _ tKey _ " is committed and not derived"
    }
    Quit $Extract(tDrift, 3, *)
}

/// <p>List <var>pKey</var>'s rows keyed by path, each <code>position|shape|templateType|itemType</code>.</p>
Method IndexRows(ByRef pLists, pKey As %String, Output pRows) [ Private ]
{
    Kill pRows
    Set tN = ""
    For {
        Set tN = $Order(pLists(pKey, tN), 1, tRow)
        Quit:tN=""
        Set pRows($Piece(tRow, "|", 1)) = tN _ "|" _ $Piece(tRow, "|", 2, 4)
    }
}

/// <p>The <code>shape|templateType</code> of the row at <var>pPath</var> in list <var>pKey</var>,
/// or <code>""</code> when there is none.</p>
Method Row(ByRef pLists, pKey As %String, pPath As %String) As %String [ Private ]
{
    Set tFound = ""
    Set tN = ""
    For {
        Set tN = $Order(pLists(pKey, tN), 1, tRow)
        Quit:tN=""
        If $Piece(tRow, "|", 1) = pPath {
            Set tFound = $Piece(tRow, "|", 2, 3)
            Quit
        }
    }
    Quit tFound
}

/// <p>List <var>pKey</var>'s paths in row order, comma-joined.</p>
Method Paths(ByRef pLists, pKey As %String) As %String [ Private ]
{
    Set tPaths = ""
    Set tN = ""
    For {
        Set tN = $Order(pLists(pKey, tN), 1, tRow)
        Quit:tN=""
        Set tPaths = tPaths _ $Select(tPaths = "": "", 1: ",") _ $Piece(tRow, "|", 1)
    }
    Quit tPaths
}

}
