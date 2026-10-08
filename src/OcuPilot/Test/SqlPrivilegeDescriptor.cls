/// <p>Pins Story 18.9's declarations: the SQL privileges descriptor and its one declared read, the Users and Roles
/// lists' two new row actions, the four tools' kinds, port, pairs, arguments, fingerprint subject and
/// preconditions, the Rules the port asks, the AdminPort's two admitted writes, the four baseline keys, the
/// <code>SQLPRIV.*</code> codes and their sentences, and the kernel's new code.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class, bar the namespace the Rules and the argument
/// pairs resolve on this instance.</p>
Class OcuPilot.Test.SqlPrivilegeDescriptor Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.SqlPrivilegeList";

Parameter USERLIST = "OcuPilot.Screen.Descriptor.UserList";

Parameter ROLELIST = "OcuPilot.Screen.Descriptor.RoleList";

Parameter USERGRANT = "OcuPilot.Screen.Tool.UserSqlGrant";

Parameter USERREVOKE = "OcuPilot.Screen.Tool.UserSqlRevoke";

Parameter ROLEGRANT = "OcuPilot.Screen.Tool.RoleSqlGrant";

Parameter ROLEREVOKE = "OcuPilot.Screen.Tool.RoleSqlRevoke";

Parameter PORT = "OcuPilot.Port.SqlPrivilegePort";

Parameter ERRORS = "OcuPilot.Api.SqlPrivilegeError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The screen is an unlisted <code>list (server criteria)</code> under Permissions, instance-scoped, with the
/// entity type left empty, Permissions' two pairs and no own pair, no actions, three prompts, the user page's
/// classic key, and a composite id over the five fields that tell the rows apart.</p>
/// <p>Mutation (Rule 19): change <code>sideBarPosition</code> to 5 -- the position leg goes red.</p>
Method TestTheScreenIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#SCREEN
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "permissions/sql-privileges", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "permissions 0", "Permissions' unlisted screen")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list (server criteria)", "a list with server criteria")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.User", "the user page's classic key")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "permissions.sqlprivileges", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "entityType") _ "|" _ $ClassMethod(tClass, "Scope"), "|instance", "no entity type, instance scope")
    Set tId = $ClassMethod(tClass, "Field", "id")
    Do $$$AssertEquals(tId.%Get("kind") _ " " _ ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tId.%Get("parts")), "composite Type,Object,Action,GrantedVia,GrantedBy", "a composite id over the five fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Permissions' two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "rowActions").%Size() _ "|" _ $ClassMethod(tClass, "Field", "primaryAction").%Get("id"), "0|", "no action of its own")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Set tRead = $ClassMethod(tClass, "Read")
    Set tSource = tRead.%Get("source")
    Do $$$AssertEquals(tSource.%Get("port") _ " " _ tSource.%Get("endpoint") _ " " _ tSource.%Get("type") _ " " _ tSource.%Get("query").%Get("includeSystem"), "admin Security.SQLPrivilege.Standard LIST 0", "the standard list with system objects left out")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Type,Object,Action,GrantedBy,GrantOption,GrantedVia", "the six fields")
    Set tCriteria = tRead.%Get("criteria").%Get("fields")
    Do $$$AssertEquals(tCriteria.%Size() _ " " _ tCriteria.%Get(0).%Get("param") _ ":" _ tCriteria.%Get(0).%Get("maxLength") _ " " _ tCriteria.%Get(1).%Get("param") _ ":" _ tCriteria.%Get(1).%Get("maxLength"), "2 grantee:160 namespace:64", "the grantee and the namespace, bounded")
    Do $$$AssertTrue((tCriteria.%Get(0).%Get("hint") '= "") && (tCriteria.%Get(1).%Get("hint") '= ""), "each carries a hint")
    Set tColumns = $ClassMethod(tClass, "Field", "table").%Get("columns")
    Do $$$AssertEquals(tColumns.%Size() _ " " _ tColumns.%Get(0).%Get("field") _ ":" _ tColumns.%Get(0).%Get("kind"), "6 Object:name", "six columns, the object the name")
}

/// <p>The Users and Roles lists each carry the two row actions, after the actions they had.</p>
/// <p>Mutation (Rule 19): drop <code>revoke-sql</code> from the Roles list -- this goes red.</p>
Method TestTheListsDeclareTheRowActions()
{
    For tList = ..#USERLIST, ..#ROLELIST {
        Set tActions = $ClassMethod(tList, "Field", "rowActions")
        Set tIds = ""
        Set tIterator = tActions.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAction) {
            Set tIds = tIds _ "," _ tAction.%Get("id")
        }
        Do $$$AssertTrue(tIds [ ",grant-sql", tList _ " declares grant-sql")
        Do $$$AssertTrue(tIds [ ",revoke-sql", tList _ " declares revoke-sql")
        Do $$$AssertEquals($Piece(tIds, ",", $Length(tIds, ",")), "revoke-sql", tList _ " declares them last")
    }
}

/// <p>The four tools are advertised action writes on <class>OcuPilot.Port.SqlPrivilegePort</class>, naming the
/// grantee by <code>Name</code> and <code>grantee</code>, sending no body, reading their composed state from their
/// own arguments, over the screen's two pairs and the editor's classic pages; a grant adds the grant option to
/// its arguments and the two schema dialogs to its pages.</p>
/// <p>Mutation (Rule 19): set <code>SENDSBODY</code> 1 on the revoke tool -- the body leg goes red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndArguments()
{
    For tClass = ..#USERGRANT, ..#USERREVOKE, ..#ROLEGRANT, ..#ROLEREVOKE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), ..#PORT, tName _ " reaches the instance through the privilege port")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), "Name grantee", tName _ " names its target by the grantee")
        Do $$$AssertEquals($ClassMethod(tClass, "SendsBody") _ $Parameter(tClass, "READSVALUES") _ $Parameter(tClass, "DESTRUCTIVE"), "010", tName _ " sends no body, reads from its values and is not destructive")
        Do $$$AssertEquals($Parameter(tClass, "STATEFIELD") _ " " _ $Parameter(tClass, "PRECONDITIONFIELD"), "Privilege Held", tName _ " labels its rows and reads Held")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", tName _ " needs the screen's two pairs and no other")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint"), "Security.SQLPrivilege.Standard", tName _ " addresses the standard family")
    }
    Do $$$AssertEquals($Parameter(..#USERGRANT, "DESCRIPTORCLASS") _ " " _ $Parameter(..#USERREVOKE, "DESCRIPTORCLASS"), ..#USERLIST _ " " _ ..#USERLIST, "the user tools belong to the Users list")
    Do $$$AssertEquals($Parameter(..#ROLEGRANT, "DESCRIPTORCLASS") _ " " _ $Parameter(..#ROLEREVOKE, "DESCRIPTORCLASS"), ..#ROLELIST _ " " _ ..#ROLELIST, "the role tools to the Roles list")
    For tCase = $ListBuild(..#USERGRANT, "permissions.users.grantsql", "grant-sql", "grant-sql=Namespace:Type:Object:Action:WithGrant", "GRANTSTATE", "GRANT", "SQLPRIV.HELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,WithGrant", "%CSP.UI.Portal.User,%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv"), $ListBuild(..#ROLEGRANT, "permissions.roles.grantsql", "grant-sql", "grant-sql=Namespace:Type:Object:Action:WithGrant", "GRANTSTATE", "GRANT", "SQLPRIV.HELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,WithGrant", "%CSP.UI.Portal.Role,%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv"), $ListBuild(..#USERREVOKE, "permissions.users.revokesql", "revoke-sql", "revoke-sql=Namespace:Type:Object:Action", "REVOKESTATE", "REVOKE", "SQLPRIV.NOTHELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action", "%CSP.UI.Portal.User"), $ListBuild(..#ROLEREVOKE, "permissions.roles.revokesql", "revoke-sql", "revoke-sql=Namespace:Type:Object:Action", "REVOKESTATE", "REVOKE", "SQLPRIV.NOTHELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action", "%CSP.UI.Portal.Role") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME") _ "|" _ $Parameter(tClass, "SCREENACTIONS") _ "|" _ $Parameter(tClass, "SCREENVALUES"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 2) _ " names its row action and its values")
        Do $$$AssertEquals($Parameter(tClass, "READTYPE") _ " " _ $Parameter(tClass, "WRITETYPE") _ "|" _ $Parameter(tClass, "PRECONDITIONCODES"), $List(tCase, 5) _ " " _ $List(tCase, 6) _ "|" _ $List(tCase, 7), $List(tCase, 2) _ " reads the composed state and names its preconditions")
        Set tSubject = $Parameter(tClass, "FINGERPRINTSUBJECT")
        Do $$$AssertEquals($Piece(tSubject, ",Held", 1), $List(tCase, 8), $List(tCase, 2) _ " fingerprints its arguments")
        Do $$$AssertEquals($Piece(tSubject, $List(tCase, 8) _ ",", 2), "Held,GrantOption,GrantedBy,Rows", $List(tCase, 2) _ " and the state it read")
        Do $$$AssertEquals($Parameter(tClass, "READANSWERS"), tSubject, $List(tCase, 2) _ " reads every name it fingerprints")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $List(tCase, 9), $List(tCase, 2) _ " declares the editor's classic page, and a grant the two schema dialogs")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 8), $List(tCase, 2) _ " sets its arguments")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PreconditionCodes")), $List(tCase, 7), $List(tCase, 2) _ " reads its precondition codes as a list")
        Set tProperties = $ClassMethod(tClass, "InputSchema").%Get("properties")
        Do $$$AssertEquals(tProperties.%IsDefined("Name") _ tProperties.%IsDefined("Namespace") _ tProperties.%IsDefined("Type") _ tProperties.%IsDefined("Object") _ tProperties.%IsDefined("Action") _ tProperties.%IsDefined("WithGrant"), "11111" _ $Select(tClass [ "Grant": 1, 1: 0), $List(tCase, 2) _ "'s schema carries the arguments, and the grant option on a grant alone")
    }
}

/// <p>AD-8: the tools add READ on the resources guarding the namespace's databases, resolved at the call; a call
/// naming no namespace, or one the instance does not define, adds none; every namespace the argument names that
/// the instance defines resolves.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.SqlPrivilegeWrite.ArgumentPairs</method> answer none --
/// the pair leg goes red.</p>
Method TestTheArgumentPairsAreTheNamespacesDatabases()
{
    Do $ClassMethod(..#PORT, "NamespaceResources", "USER", .tResources, .tResolved)
    Do $$$AssertTrue(tResolved && ($ListLength(tResources) > 0), "USER's databases report their resources")
    Set tExpected = ""
    For tI = 1:1:$ListLength(tResources) Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ $List(tResources, tI) _ ":READ"
    Set tPairs = $ClassMethod(..#USERGRANT, "ArgumentPairs", "", {"Name": "u", "Namespace": "USER"}, .tPairsResolved)
    Do $$$AssertEquals(tPairsResolved _ " " _ ##class(OcuPilot.Test.EncryptionDescriptor).Pairs(tPairs), "1 " _ tExpected, "a defined namespace adds READ on each of its databases")
    Set tPairs = $ClassMethod(..#ROLEREVOKE, "ArgumentPairs", "", {"Name": "r", "Namespace": "NoSuchNamespace"}, .tPairsResolved)
    Do $$$AssertEquals(tPairsResolved _ " " _ ##class(OcuPilot.Test.EncryptionDescriptor).Pairs(tPairs), "1 ", "an undefined namespace adds none: the port refuses it")
    Set tPairs = $ClassMethod(..#USERREVOKE, "ArgumentPairs", "", {"Name": "u"}, .tPairsResolved)
    Do $$$AssertEquals(tPairsResolved _ " " _ ##class(OcuPilot.Test.EncryptionDescriptor).Pairs(tPairs), "1 ", "a call naming no namespace adds none")
}

/// <p>The Rules (Story 18.9), asked of the query the port reads: each field's refusal, and the matrix's accepted
/// shapes. The grant option is a grant's alone.</p>
/// <p>Mutation (Rule 19): drop the action check from <method>OcuPilot.Port.SqlPrivilegePort.Violations</method> --
/// the action legs go red.</p>
Method TestTheRulesRefuseEachField()
{
    Set tCases = 0
    Set tCases($Increment(tCases)) = $ListBuild("a valid table grant", "USER|g|TABLE|S.T|SELECT||", "")
    Set tCases($Increment(tCases)) = $ListBuild("an undefined namespace", "NoSuchNs|g|TABLE|S.T|SELECT||", "SQLPRIV.NAMESPACE")
    Set tCases($Increment(tCases)) = $ListBuild("no namespace", "|g|TABLE|S.T|SELECT||", "SQLPRIV.NAMESPACE")
    Set tCases($Increment(tCases)) = $ListBuild("an implied namespace", "^^/tmp|g|TABLE|S.T|SELECT||", "SQLPRIV.NAMESPACE")
    Set tCases($Increment(tCases)) = $ListBuild("no grantee", "USER||TABLE|S.T|SELECT||", "SQLPRIV.GRANTEE")
    Set tCases($Increment(tCases)) = $ListBuild("a wildcard grantee", "USER|g*|TABLE|S.T|SELECT||", "SQLPRIV.GRANTEE")
    Set tCases($Increment(tCases)) = $ListBuild("a list of grantees", "USER|a,b|TABLE|S.T|SELECT||", "SQLPRIV.GRANTEE")
    Set tCases($Increment(tCases)) = $ListBuild("a grantee over 160 characters", "USER|" _ $Justify("", 161) _ "|TABLE|S.T|SELECT||", "SQLPRIV.GRANTEE")
    Set tCases($Increment(tCases)) = $ListBuild("a type outside the six", "USER|g|COLUMN|S.T|SELECT||", "SQLPRIV.TYPE")
    Set tCases($Increment(tCases)) = $ListBuild("a lower-case type", "USER|g|table|S.T|SELECT||", "SQLPRIV.TYPE")
    Set tCases($Increment(tCases)) = $ListBuild("a table named by one part", "USER|g|TABLE|T|SELECT||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("a schema named by two parts", "USER|g|SCHEMA|S.T|SELECT||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("a name with a space", "USER|g|TABLE|S.T x|SELECT||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("a name starting with a digit", "USER|g|TABLE|S.1T|SELECT||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("a wildcard object", "USER|g|TABLE|S.*|SELECT||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("a view with REFERENCES", "USER|g|VIEW|S.V|REFERENCES||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("EXECUTE on a table", "USER|g|TABLE|S.T|EXECUTE||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("a list of actions", "USER|g|TABLE|S.T|SELECT,INSERT||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("ALTER read as %ALTER", "USER|g|TABLE|S.T|ALTER||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("%ALTER", "USER|g|TABLE|S.T|%ALTER||", "")
    Set tCases($Increment(tCases)) = $ListBuild("EXECUTE on a schema", "USER|g|SCHEMA|S|EXECUTE||", "")
    Set tCases($Increment(tCases)) = $ListBuild("EXECUTE on a procedure", "USER|g|STORED PROCEDURE|S.P|EXECUTE||", "")
    Set tCases($Increment(tCases)) = $ListBuild("USE on a foreign server", "USER|g|FOREIGN SERVER|S.F|USE||", "")
    Set tCases($Increment(tCases)) = $ListBuild("USE on an ML configuration", "USER|g|ML CONFIGURATION|M|USE||", "")
    Set tCases($Increment(tCases)) = $ListBuild("SELECT on an ML configuration", "USER|g|ML CONFIGURATION|M|SELECT||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("a grant option that is not boolean", "USER|g|TABLE|S.T|SELECT|maybe|", "SQLPRIV.WITHGRANT")
    Set tCases($Increment(tCases)) = $ListBuild("a grant option of 1", "USER|g|TABLE|S.T|SELECT|1|", "")
    Set tCases($Increment(tCases)) = $ListBuild("a grant option on a revoke", "USER|g|TABLE|S.T|SELECT|maybe|1", "")
    For tI = 1:1:tCases {
        Set tCase = tCases(tI)
        Set tFields = $List(tCase, 2)
        Kill tQuery
        Set tQuery("namespace") = $Piece(tFields, "|", 1)
        Set tQuery("grantee") = $Piece(tFields, "|", 2)
        Set tQuery("type") = $Piece(tFields, "|", 3)
        Set tQuery("object") = $Piece(tFields, "|", 4)
        Set tQuery("action") = $Piece(tFields, "|", 5)
        If $Piece(tFields, "|", 6) '= "" Set tQuery("withGrant") = $Piece(tFields, "|", 6)
        Set tCodes = $ClassMethod(..#PORT, "Violations", .tQuery, +$Piece(tFields, "|", 7))
        Do $$$AssertEquals($ListToString(tCodes), $List(tCase, 3), $List(tCase, 1) _ ": " _ $Select($List(tCase, 3) = "": "accepted", 1: "refused with " _ $List(tCase, 3)))
    }
}

/// <p>AD-27: the admin port admits the two writes as bodyless mutating types, guards the standard endpoint's
/// calls, and maps the SQLCODEs the matrix names.</p>
/// <p>Mutation (Rule 19): drop <code>-112</code> from <parameter>OcuPilot.Port.AdminPort.SQLCODEFAULTS</parameter>
/// -- the grantor leg goes red.</p>
Method TestTheAdminPortAdmitsTheWritesAndMapsTheCodes()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    For tPair = "Security.SQLPrivilege.Standard/GRANT", "Security.SQLPrivilege.Standard/REVOKE" {
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(tPort, "MUTATINGTYPES")), tPair) > 0, tPair _ " is a mutating type")
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(tPort, "BODYLESSTYPES")), tPair) > 0, tPair _ " reads no body")
    }
    Do $$$AssertEquals($ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.SQLPrivilege.Standard") _ $ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.User"), "10", "only the standard family is guarded here")
    For tCase = $ListBuild(5540, 1, -112, 403, "SQLPRIV.GRANTOR"), $ListBuild(5035, 2, -112, 403, "SQLPRIV.GRANTOR"), $ListBuild(5035, 2, -99, 403, "SQLPRIV.GRANTOR"), $ListBuild(5540, 1, -30, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -187, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -428, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -473, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -118, 404, "SQLPRIV.NOGRANTEE"), $ListBuild(5540, 1, -60, 0, ""), $ListBuild(5002, 1, -30, 0, "") {
        If $List(tCase, 2) = 1 Set tStatus = $$$ERROR(+$List(tCase, 1), $List(tCase, 3), "Message")
        If $List(tCase, 2) = 2 Set tStatus = $$$ERROR(+$List(tCase, 1), "GrantObjPriv Error", $List(tCase, 3), "SQL Error Code")
        Set tHttp = $ClassMethod(tPort, "SqlCodeFault", "Security.SQLPrivilege.Standard", tStatus, .tCode)
        Do $$$AssertEquals(tHttp _ " " _ tCode, $List(tCase, 4) _ " " _ $List(tCase, 5), "vendor status " _ $List(tCase, 1) _ " carrying SQLCODE " _ $List(tCase, 3) _ " reads as " _ $Select($List(tCase, 5) = "": "an internal failure", 1: $List(tCase, 5)))
    }
}

/// <p>AD-59: a grant's script is the vendor call with <code>withGrant</code> only when asked; a revoke's is the
/// call naming a placeholder grantor and a comment saying it is sent for each direct grantor.</p>
Method TestTheScriptsMirrorTheBranches()
{
    Kill tQuery
    Set tQuery("grantee") = "g"
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = "S.T"
    Set tQuery("action") = "SELECT"
    Set tQuery("withGrant") = 0
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "GRANT", .tQuery, "", {"origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind"), "1 rest", "a grant is one rest step")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") '[ "withGrant", "which names no grant option that was not asked")
    Set tQuery("withGrant") = 1
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "GRANT", .tQuery, "", {"origin": "http://h", "user": "u"})
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "withGrant=1", "and one that was asked names it")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "REVOKE", .tQuery, "", {"origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(1).%Get("kind"), "2 rest comment", "a revoke is a rest step and a comment")
    Do $$$AssertTrue((tSteps.%Get(0).%Get("text") [ "asGrantor=<grantor>") && (tSteps.%Get(0).%Get("text") [ "cascade=0"), "naming a placeholder grantor and no cascade")
}

/// <p>AD-22: the four keys are in the baseline and enabled.</p>
/// <p>Mutation (Rule 19): set <code>permissions.users.revokesql</code> to false in the baseline -- this goes
/// red.</p>
Method TestTheBaselineKeysShipEnabled()
{
    For tKey = "permissions.users.grantsql", "permissions.users.revokesql", "permissions.roles.grantsql", "permissions.roles.revokesql" {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 1", tKey _ " is listed and enabled")
    }
}

/// <p>AD-39: every <code>SQLPRIV.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each field-level code names its field; the nine refusal
/// codes the matrix names exist.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.SqlPrivilegeError.REASONNOTAPPLIED</parameter> -- its
/// sentence leg goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 15, "fifteen codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), 6, "six of them are field codes")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    For tName = "HELD", "NOTHELD", "SUPERUSER", "NOTAPPLIED", "GRANTOR", "NOOBJECT", "NOGRANTEE", "LIST" {
        Do $$$AssertTrue($ListFind(tCodes, $Parameter(tClass, tName)) > 0, "SQLPRIV." _ tName _ " is declared")
    }
}

/// <p>AD-10: the kernel declares the arm's code once, with its published sentence, among thirty-two codes, and
/// refuses a grant or revoke on one of OcuPilot's own schemas or for one of its own roles from the stored
/// payload alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SqlPrivilege</method> skip
/// <method>IsOcuPilotCode</method> -- the object legs go red.</p>
Method TestTheKernelRefusesOcuPilotsOwn()
{
    Set tProhibited = ..#PROHIBITED
    Set tCode = $Parameter(tProhibited, "OCUPILOTSQLPRIVILEGE")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTSQLPRIVILEGE", "the code")
    Do $$$AssertEquals($ClassMethod(tProhibited, "ReasonFor", tCode), $Parameter(tProhibited, "OCUPILOTSQLPRIVILEGEREASON"), "its one sentence")
    Do $$$AssertTrue($ClassMethod(tProhibited, "ReasonFor", tCode) [ "SQL tables keep the privileges its installer grants", "which says what the installer keeps")
    Do $$$AssertEquals($ListLength($ClassMethod(tProhibited, "Codes")), 32, "among thirty-two codes")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), tCode) > 0, "which lists it")
    For tTool = ..#USERGRANT, ..#USERREVOKE, ..#ROLEGRANT, ..#ROLEREVOKE {
        Set tType = $Select(tTool [ "User": "user", 1: "role")
        For tCase = $ListBuild("OcuSqlPrivProbeU", "OcuSqlPrivProbe.T1", "", 0), $ListBuild("OcuSqlPrivProbeU", "OcuPilot_Kernel_State.Turn", tCode, 1), $ListBuild("OcuSqlPrivProbeU", "ocupilot_kernel_state.turn", tCode, 1), $ListBuild("OcuSqlPrivProbeU", "OcuPilot_Kernel_State", tCode, 1), $ListBuild("OcuPilotAdmin", "OcuSqlPrivProbe.T1", "PROHIBITED.OCUPILOTROLE", 1), $ListBuild("%DB_OCUPILOT", "OcuSqlPrivProbe.T1", "PROHIBITED.OCUPILOTROLE", 1) {
            Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, "instance", $List(tCase, 1), .tRef)
            Set tPayload = {"Namespace": "USER", "Type": "TABLE", "Object": ($List(tCase, 2)), "Action": "SELECT"}
            Set tSC = $ClassMethod(tProhibited, "Prohibits", $Parameter(tTool, "TOOLNAME"), tRef, tPayload.%ToJSON(), "[]", .tProhibits, .tAnswer)
            Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " is asked about " _ $List(tCase, 1) _ " and " _ $List(tCase, 2))
            Do $$$AssertEquals(tProhibits _ " " _ tAnswer, $List(tCase, 4) _ " " _ $List(tCase, 3), $Parameter(tTool, "TOOLNAME") _ " for " _ $List(tCase, 1) _ " on " _ $List(tCase, 2))
        }
    }
}

}
