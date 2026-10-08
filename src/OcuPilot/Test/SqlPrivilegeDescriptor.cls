/// <p>Pins Stories 18.9's and 18.28's declarations: the SQL privileges descriptor and its one declared read, the
/// column and admin privilege descriptors beside it, the Users and Roles lists' two row actions, the four tools'
/// kinds, port, pairs, arguments, fingerprint subject and preconditions, the Rules the port asks (column and admin
/// privileges included), the AdminPort's six admitted writes, the four baseline keys, the <code>SQLPRIV.*</code>
/// codes and their sentences, and the kernel's code.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class, bar the namespace the Rules and the argument
/// pairs resolve on this instance.</p>
Class OcuPilot.Test.SqlPrivilegeDescriptor Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.SqlPrivilegeList";

Parameter COLUMNSCREEN = "OcuPilot.Screen.Descriptor.SqlColumnPrivilegeList";

Parameter ADMINSCREEN = "OcuPilot.Screen.Descriptor.SqlAdminPrivilegeList";

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
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Type,Object,Action,GrantedBy,GrantOption,GrantedVia,HasColumnPriv", "the seven fields, the table-held-through-columns flag among them")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "and the context carries the same seven")
    Set tCriteria = tRead.%Get("criteria").%Get("fields")
    Do $$$AssertEquals(tCriteria.%Size() _ " " _ tCriteria.%Get(0).%Get("param") _ ":" _ tCriteria.%Get(0).%Get("maxLength") _ " " _ tCriteria.%Get(1).%Get("param") _ ":" _ tCriteria.%Get(1).%Get("maxLength"), "2 grantee:160 namespace:64", "the grantee and the namespace, bounded")
    Do $$$AssertTrue((tCriteria.%Get(0).%Get("hint") '= "") && (tCriteria.%Get(1).%Get("hint") '= ""), "each carries a hint")
    Set tColumns = $ClassMethod(tClass, "Field", "table").%Get("columns")
    Do $$$AssertEquals(tColumns.%Size() _ " " _ tColumns.%Get(0).%Get("field") _ ":" _ tColumns.%Get(0).%Get("kind"), "6 Object:name", "six columns, the object the name")
}

/// <p>The column screen is an unlisted, instance-scoped <code>list (server criteria)</code> under Permissions,
/// reading the column family's list with system objects included, with the classic column dialog as its page and
/// three criteria each carrying a hint; the admin screen the same over the admin family's list with two criteria
/// and the user page.</p>
/// <p>Mutation (Rule 19): change the column read's fixed <code>includeSystem</code> to 0 -- the include-system leg
/// goes red.</p>
Method TestTheColumnAndAdminScreensAreDeclared()
{
    For tCase = $ListBuild(..#COLUMNSCREEN, "permissions/sql-column-privileges", "permissions.sqlcolumnprivileges", "%CSP.UI.Portal.Dialog.ColumnPriv", "Security.SQLPrivilege.Column", "1", "Column,Action,GrantedVia,GrantedBy", "Column,Action,GrantedBy,GrantOption,GrantedVia", "grantee:160,namespace:64,object:257"), $ListBuild(..#ADMINSCREEN, "permissions/sql-admin-privileges", "permissions.sqladminprivileges", "%CSP.UI.Portal.User", "Security.SQLPrivilege.Admin", "", "Privilege,GrantedVia", "Privilege,GrantOption,GrantedVia", "grantee:160,namespace:64") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(tClass, "Route") _ " " _ $ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), $List(tCase, 2) _ " permissions 0", tClass _ " is an unlisted Permissions screen")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "Field", "entityType"), "list (server criteria)|instance|", tClass _ " is an instance-scoped list with no entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier") _ " " _ $ClassMethod(tClass, "Field", "classicPage"), $List(tCase, 3) _ " " _ $List(tCase, 4), tClass _ " names its tool and its classic page")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", tClass _ " needs Permissions' two pairs")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "rowActions").%Size() _ " " _ $ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), "0 3", tClass _ " has no action and three prompts")
        Set tRead = $ClassMethod(tClass, "Read")
        Set tSource = tRead.%Get("source")
        Do $$$AssertEquals(tSource.%Get("port") _ " " _ tSource.%Get("endpoint") _ " " _ tSource.%Get("type") _ "|" _ $Select($IsObject(tSource.%Get("query")): tSource.%Get("query").%Get("includeSystem"), 1: ""), "admin " _ $List(tCase, 5) _ " LIST|" _ $List(tCase, 6), tClass _ " reads its family's list" _ $Select($List(tCase, 6) = "1": ", system objects included", 1: ""))
        Set tId = $ClassMethod(tClass, "Field", "id")
        Do $$$AssertEquals(tId.%Get("kind") _ " " _ ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tId.%Get("parts")), "composite " _ $List(tCase, 7), tClass _ "'s composite id")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), $List(tCase, 8), tClass _ "'s fields")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), $List(tCase, 8), tClass _ "'s context")
        Set tCriteria = tRead.%Get("criteria").%Get("fields")
        Set tSeen = ""
        Set tHints = 1
        For tI = 0:1:tCriteria.%Size() - 1 {
            Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tCriteria.%Get(tI).%Get("param") _ ":" _ tCriteria.%Get(tI).%Get("maxLength")
            If tCriteria.%Get(tI).%Get("hint") = "" Set tHints = 0
        }
        Do $$$AssertEquals(tSeen, $List(tCase, 9), tClass _ "'s criteria, bounded")
        Do $$$AssertTrue(tHints, tClass _ "'s criteria each carry a hint")
    }
    Set tObjectHint = $ClassMethod(..#COLUMNSCREEN, "Read").%Get("criteria").%Get("fields").%Get(2).%Get("hint")
    Do $$$AssertTrue(tObjectHint [ "SQL privileges read", "the object criterion's hint says to spell it as the SQL privileges read does")
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
    For tCase = $ListBuild(..#USERGRANT, "permissions.users.grantsql", "grant-sql", "grant-sql=Namespace:Type:Object:Action:Column:WithGrant", "GRANTSTATE", "GRANT", "SQLPRIV.HELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,Column,WithGrant", "%CSP.UI.Portal.User,%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv,%CSP.UI.Portal.Dialog.ColumnPriv"), $ListBuild(..#ROLEGRANT, "permissions.roles.grantsql", "grant-sql", "grant-sql=Namespace:Type:Object:Action:Column:WithGrant", "GRANTSTATE", "GRANT", "SQLPRIV.HELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,Column,WithGrant", "%CSP.UI.Portal.Role,%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv,%CSP.UI.Portal.Dialog.ColumnPriv"), $ListBuild(..#USERREVOKE, "permissions.users.revokesql", "revoke-sql", "revoke-sql=Namespace:Type:Object:Action:Column", "REVOKESTATE", "REVOKE", "SQLPRIV.NOTHELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,Column", "%CSP.UI.Portal.User,%CSP.UI.Portal.Dialog.ColumnPriv"), $ListBuild(..#ROLEREVOKE, "permissions.roles.revokesql", "revoke-sql", "revoke-sql=Namespace:Type:Object:Action:Column", "REVOKESTATE", "REVOKE", "SQLPRIV.NOTHELD,SQLPRIV.SUPERUSER", "Namespace,Type,Object,Action,Column", "%CSP.UI.Portal.Role,%CSP.UI.Portal.Dialog.ColumnPriv") {
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
        Do $$$AssertEquals(tProperties.%IsDefined("Name") _ tProperties.%IsDefined("Namespace") _ tProperties.%IsDefined("Type") _ tProperties.%IsDefined("Object") _ tProperties.%IsDefined("Action") _ tProperties.%IsDefined("Column") _ tProperties.%IsDefined("WithGrant"), "111111" _ $Select(tClass [ "Grant": 1, 1: 0), $List(tCase, 2) _ "'s schema carries the arguments, the optional column, and the grant option on a grant alone")
        Set tRequired = $ClassMethod(tClass, "InputSchema").%Get("required")
        Set tRequiredText = ""
        For tR = 0:1:tRequired.%Size() - 1 Set tRequiredText = tRequiredText _ "," _ tRequired.%Get(tR)
        Do $$$AssertEquals(tRequiredText, ",Name,Namespace,Type,Action", $List(tCase, 2) _ " requires the grantee, namespace, type and action; the object is the Rules' to judge, because an ADMIN has none")
        Set tTypes = tProperties.%Get("Type").%Get("enum")
        Set tTypeText = ""
        For tR = 0:1:tTypes.%Size() - 1 Set tTypeText = tTypeText _ $Select(tTypeText = "": "", 1: ",") _ tTypes.%Get(tR)
        Do $$$AssertEquals(tTypeText, $Parameter(..#PORT, "TYPES"), $List(tCase, 2) _ " offers the port's types, ADMIN among them")
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
    Set tCases($Increment(tCases)) = $ListBuild("a table with no object", "USER|g|TABLE||SELECT||", "SQLPRIV.OBJECT")
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
    Set tCases($Increment(tCases)) = $ListBuild("a column on a table", "USER|g|TABLE|S.T|SELECT||||ID", "")
    Set tCases($Increment(tCases)) = $ListBuild("a column on a view, REFERENCES included", "USER|g|VIEW|S.V|REFERENCES||||ID", "")
    Set tCases($Increment(tCases)) = $ListBuild("a column on a schema", "USER|g|SCHEMA|S|SELECT||||ID", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("a column on a procedure", "USER|g|STORED PROCEDURE|S.P|EXECUTE||||ID", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("a column named by two parts", "USER|g|TABLE|S.T|SELECT||||A.B", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("a column with a space", "USER|g|TABLE|S.T|SELECT||||A B", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("a wildcard column", "USER|g|TABLE|S.T|SELECT||||*", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("DELETE on a column", "USER|g|TABLE|S.T|DELETE||||ID", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("%ALTER on a column", "USER|g|TABLE|S.T|%ALTER||||ID", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("an admin privilege", "USER|g|ADMIN||%CREATE_TABLE||", "")
    Set tCases($Increment(tCases)) = $ListBuild("the last of the admin privileges", "USER|g|ADMIN||%USE_EMBEDDING||", "")
    Set tCases($Increment(tCases)) = $ListBuild("%DEFER, which the instance's admin privilege store refuses", "USER|g|ADMIN||%DEFER||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("an admin privilege in lower case", "USER|g|ADMIN||%create_table||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("an admin privilege outside the list", "USER|g|ADMIN||%CREATE_DATABASE||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("a table action on ADMIN", "USER|g|ADMIN||SELECT||", "SQLPRIV.ACTION")
    Set tCases($Increment(tCases)) = $ListBuild("ADMIN with an object", "USER|g|ADMIN|S.T|%CREATE_TABLE||", "SQLPRIV.OBJECT")
    Set tCases($Increment(tCases)) = $ListBuild("ADMIN with a column", "USER|g|ADMIN||%CREATE_TABLE||||ID", "SQLPRIV.COLUMN")
    Set tCases($Increment(tCases)) = $ListBuild("an admin grant with the grant option", "USER|g|ADMIN||%CREATE_TABLE|1|", "")
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
        If $Piece(tFields, "|", 9) '= "" Set tQuery("column") = $Piece(tFields, "|", 9)
        Set tCodes = $ClassMethod(..#PORT, "Violations", .tQuery, +$Piece(tFields, "|", 7))
        Do $$$AssertEquals($ListToString(tCodes), $List(tCase, 3), $List(tCase, 1) _ ": " _ $Select($List(tCase, 3) = "": "accepted", 1: "refused with " _ $List(tCase, 3)))
    }
}

/// <p>AD-27: the admin port admits the six writes (the standard, column and admin families' grants and revokes) as
/// bodyless mutating types, guards the three endpoints' calls, and maps the SQLCODEs the matrix names, the admin
/// family's grantor refusal (status 516, SQLCODE its second parameter) among them.</p>
/// <p>Mutation (Rule 19): drop <code>Security.SQLPrivilege.Admin|-99</code> from
/// <parameter>OcuPilot.Port.AdminPort.SQLCODEFAULTS</parameter> -- the admin grantor leg goes red.</p>
Method TestTheAdminPortAdmitsTheWritesAndMapsTheCodes()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    For tPair = "Security.SQLPrivilege.Standard/GRANT", "Security.SQLPrivilege.Standard/REVOKE", "Security.SQLPrivilege.Column/GRANT", "Security.SQLPrivilege.Column/REVOKE", "Security.SQLPrivilege.Admin/GRANT", "Security.SQLPrivilege.Admin/REVOKE" {
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(tPort, "MUTATINGTYPES")), tPair) > 0, tPair _ " is a mutating type")
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(tPort, "BODYLESSTYPES")), tPair) > 0, tPair _ " reads no body")
    }
    Do $$$AssertEquals($ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.SQLPrivilege.Standard") _ $ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.SQLPrivilege.Column") _ $ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.SQLPrivilege.Admin") _ $ClassMethod(tPort, "IsSqlPrivilegeEndpoint", "Security.User"), "1110", "the three SQL privilege families are guarded, and no other endpoint")
    For tCase = $ListBuild(5540, 1, -112, 403, "SQLPRIV.GRANTOR"), $ListBuild(5035, 2, -112, 403, "SQLPRIV.GRANTOR"), $ListBuild(5035, 2, -99, 403, "SQLPRIV.GRANTOR"), $ListBuild(5540, 1, -30, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -187, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -428, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -473, 404, "SQLPRIV.NOOBJECT"), $ListBuild(5540, 1, -118, 404, "SQLPRIV.NOGRANTEE"), $ListBuild(5035, 2, -126, 409, "SQLPRIV.DEPENDENT"), $ListBuild(5540, 1, -60, 0, ""), $ListBuild(5002, 1, -30, 0, "") {
        If $List(tCase, 2) = 1 Set tStatus = $$$ERROR(+$List(tCase, 1), $List(tCase, 3), "Message")
        If $List(tCase, 2) = 2 Set tStatus = $$$ERROR(+$List(tCase, 1), "GrantObjPriv Error", $List(tCase, 3), "SQL Error Code")
        Set tHttp = $ClassMethod(tPort, "SqlCodeFault", "Security.SQLPrivilege.Standard", tStatus, .tCode)
        Do $$$AssertEquals(tHttp _ " " _ tCode, $List(tCase, 4) _ " " _ $List(tCase, 5), "vendor status " _ $List(tCase, 1) _ " carrying SQLCODE " _ $List(tCase, 3) _ " reads as " _ $Select($List(tCase, 5) = "": "an internal failure", 1: $List(tCase, 5)))
    }
    Set tStatus = $$$ERROR(516, "Grant", -99, "SQL Error Code")
    Set tHttp = $ClassMethod(tPort, "SqlCodeFault", "Security.SQLPrivilege.Admin", tStatus, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 SQLPRIV.GRANTOR", "the admin family's #516 with -99 as its second parameter is the grantor refusal")
    Set tStatus = $$$ERROR(516, "Grant", -112, "SQL Error Code")
    Set tHttp = $ClassMethod(tPort, "SqlCodeFault", "Security.SQLPrivilege.Admin", tStatus, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "0 ", "and another SQLCODE under that status is not mapped")
}

/// <p>AD-59: a grant's script is the vendor call with <code>withGrant</code> only when asked; a revoke's is the
/// call naming a placeholder grantor and a comment saying it is sent for each direct grantor; a column script ends
/// with a comment saying to name the object and its type as the instance lists them, which the port does itself.</p>
/// <p>Mutation (Rule 19): drop the column family's spelling comment from
/// <method>OcuPilot.Port.SqlPrivilegePort.Snippet</method> -- the column legs go red.</p>
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
    Set tQuery("column") = "ID"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "REVOKE", .tQuery, "", {"origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(1).%Get("kind") _ " " _ $Select(tSteps.%Size() > 2: tSteps.%Get(2).%Get("kind"), 1: ""), "3 rest comment comment", "a column revoke is a rest step, the grantor's comment and the spelling's")
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue((tText [ "/security/sql-column-privilege/revoke") && (tText [ "asGrantor=<grantor>") && (tText [ "column=ID") && (tText '[ "cascade"), "to the column route, naming a placeholder grantor and the column")
    Do $$$AssertTrue($Select(tSteps.%Size() > 2: tSteps.%Get(2).%Get("text"), 1: "") [ "exactly as the instance", "whose last comment says to name the object and its type as the instance lists them")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "GRANT", .tQuery, "", {"origin": "http://h", "user": "u"})
    Do $$$AssertTrue((tSteps.%Size() = 2) && (tSteps.%Get(0).%Get("text") [ "/security/sql-column-privilege/grant") && (tSteps.%Get(0).%Get("text") [ "withGrant=1"), "a column grant is one call to the column route, with the grant option asked")
    Do $$$AssertTrue($Select(tSteps.%Size() > 1: (tSteps.%Get(1).%Get("kind") = "comment") && (tSteps.%Get(1).%Get("text") [ "exactly as the instance"), 1: 0), "and the spelling comment")
    Kill tQuery
    Set tQuery("grantee") = "g"
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "ADMIN"
    Set tQuery("action") = "%CREATE_TABLE"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.SQLPrivilege.Standard", "REVOKE", .tQuery, "", {"origin": "http://h", "user": "u"})
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue((tSteps.%Size() = 1) && (tText [ "/security/sql-admin-privilege/revoke") && (tText [ "privilege=%25CREATE_TABLE") && (tText '[ "asGrantor"), "an admin revoke is the one call, naming no grantor")
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
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each field-level code names its field; the refusal codes
/// the matrix names, and the revoke's dependent-grant refusal, exist.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.SqlPrivilegeError.REASONNOTAPPLIED</parameter> -- its
/// sentence leg goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 17, "seventeen codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), 7, "seven of them are field codes")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    For tName = "HELD", "NOTHELD", "SUPERUSER", "NOTAPPLIED", "GRANTOR", "NOOBJECT", "NOGRANTEE", "DEPENDENT", "LIST", "COLUMN" {
        Do $$$AssertTrue($ListFind(tCodes, $Parameter(tClass, tName)) > 0, "SQLPRIV." _ tName _ " is declared")
    }
    Do $$$AssertEquals($ClassMethod(tClass, "FieldOf", $Parameter(tClass, "COLUMN")) _ " " _ $Parameter(tClass, "REASONCOLUMN"), "Column The column is one name of letters, digits and _ @ # $, on a table or view only.", "the column code names its field and carries its sentence")
    Do $$$AssertTrue(($Parameter(tClass, "REASONTYPE") [ "ADMIN") && ($Parameter(tClass, "REASONOBJECT") [ "ADMIN"), "and the type and object sentences name ADMIN")
}

/// <p>AD-10: the kernel declares the arm's code once, with its published sentence, among thirty-three codes, and
/// refuses a grant or revoke on one of OcuPilot's own schemas or for one of its own roles from the stored
/// payload alone, for a whole object and for one of its columns.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SqlPrivilege</method> skip
/// <method>IsOcuPilotCode</method> -- the object legs go red.</p>
Method TestTheKernelRefusesOcuPilotsOwn()
{
    Set tProhibited = ..#PROHIBITED
    Set tCode = $Parameter(tProhibited, "OCUPILOTSQLPRIVILEGE")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTSQLPRIVILEGE", "the code")
    Do $$$AssertEquals($ClassMethod(tProhibited, "ReasonFor", tCode), $Parameter(tProhibited, "OCUPILOTSQLPRIVILEGEREASON"), "its one sentence")
    Do $$$AssertTrue($ClassMethod(tProhibited, "ReasonFor", tCode) [ "SQL tables keep the privileges its installer grants", "which says what the installer keeps")
    Do $$$AssertEquals($ListLength($ClassMethod(tProhibited, "Codes")), 33, "among thirty-three codes")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), tCode) > 0, "which lists it")
    For tTool = ..#USERGRANT, ..#USERREVOKE, ..#ROLEGRANT, ..#ROLEREVOKE {
        Set tType = $Select(tTool [ "User": "user", 1: "role")
        For tCase = $ListBuild("OcuSqlPrivProbeU", "OcuSqlPrivProbe.T1", "", 0), $ListBuild("OcuSqlPrivProbeU", "OcuPilot_Kernel_State.Turn", tCode, 1), $ListBuild("OcuSqlPrivProbeU", "ocupilot_kernel_state.turn", tCode, 1), $ListBuild("OcuSqlPrivProbeU", "OcuPilot_Kernel_State", tCode, 1), $ListBuild("OcuPilotAdmin", "OcuSqlPrivProbe.T1", "PROHIBITED.OCUPILOTROLE", 1), $ListBuild("%DB_OCUPILOT", "OcuSqlPrivProbe.T1", "PROHIBITED.OCUPILOTROLE", 1) {
            Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, "instance", $List(tCase, 1), .tRef)
            For tColumn = "", "Turn" {
                Set tPayload = {"Namespace": "USER", "Type": "TABLE", "Object": ($List(tCase, 2)), "Action": "SELECT"}
                If tColumn '= "" Do tPayload.%Set("Column", tColumn)
                Set tSC = $ClassMethod(tProhibited, "Prohibits", $Parameter(tTool, "TOOLNAME"), tRef, tPayload.%ToJSON(), "[]", .tProhibits, .tAnswer)
                Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " is asked about " _ $List(tCase, 1) _ " and " _ $List(tCase, 2) _ " column '" _ tColumn _ "'")
                Do $$$AssertEquals(tProhibits _ " " _ tAnswer, $List(tCase, 4) _ " " _ $List(tCase, 3), $Parameter(tTool, "TOOLNAME") _ " for " _ $List(tCase, 1) _ " on " _ $List(tCase, 2) _ " column '" _ tColumn _ "'")
            }
        }
    }
}

}
