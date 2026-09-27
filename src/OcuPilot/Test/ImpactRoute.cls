/// <p>Pins the impact of a removal (Story 16.19, AD-8, AD-10, AD-53) over
/// <code>GET /screens/:screen/impact</code> and the agent's mint: a role delete's holders and
/// granting applications, a resource delete's granting roles and guarded applications and
/// databases, a role removal's loss net of the account's other roles, a part the caller may not
/// read reported unchecked, a refused removal answering its reason, and every other action
/// answering no impact.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes accounts, roles, a resource and a web application, each named
/// <parameter>PREFIX</parameter>, and removes them all in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.ImpactRoute Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Every probe object's name begins with this.</p>
Parameter PREFIX = "OcuImpact";

Parameter RESOURCE = "OcuImpactRes";

Parameter PUBLICRESOURCE = "OcuImpactPub";

Parameter ROLEDELETE = "OcuImpactRoleDel";

Parameter ROLEA = "OcuImpactRoleA";

Parameter ROLEB = "OcuImpactRoleB";

Parameter ROLEESCALATION = "OcuImpactRoleEsc";

Parameter ROLEPUBLIC = "OcuImpactRolePub";

Parameter ROLEG1 = "OcuImpactG1";

Parameter ROLEG2 = "OcuImpactG2";

Parameter ROLEALLVIA = "OcuImpactAllVia";

/// <p>The role the least-privileged principal holds.</p>
Parameter ROLELOW = "OcuImpactRoleLow";

/// <p>The role of the principal that holds an administrative resource, so it reaches the API, but
/// not the role delete's write pair.</p>
Parameter ROLENONE = "OcuImpactRoleNone";

Parameter APP = "/csp/ocuimpactp";

Parameter USERONE = "OcuImpactU1";

Parameter USERTWO = "OcuImpactU2";

Parameter USERLATE = "OcuImpactU3";

Parameter USERLOSS = "OcuImpactU4";

Parameter USERLOW = "OcuImpactLow";

Parameter USERNONE = "OcuImpactNone";

Parameter PASSWORD = "OcuImpact-Probe-9x";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The route under test, its screen segment filled per request.</p>
Parameter ROUTE = "/api/ocupilot/screens/:screen/impact";

/// <p>The action route the impact route resolves as, its screen segment filled per request.</p>
Parameter ACTIONROUTE = "/api/ocupilot/screens/:screen/action";

Parameter USERUPDATETOOL = "OcuPilot.Screen.Tool.UserUpdate";

Parameter USERLIST = "OcuPilot.Screen.Descriptor.UserList";

Parameter ROLELIST = "OcuPilot.Screen.Descriptor.RoleList";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ImpactRoute creates and deletes accounts, roles, a resource and a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do ..RemoveAll()
    Set tSC = ..CreateAll()
    If $$$ISERR(tSC) Do ..RemoveAll()
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do ..RemoveAll()
    Set tLeft = ..Left()
    Quit $Select(tLeft = "": $$$OK, 1: $$$ERROR($$$GeneralError, "probe objects survived: " _ tLeft))
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Create the probe objects: the resource (and a public one), the roles, the web application
/// granting and guarded by them, and the accounts.</p>
Method CreateAll() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCode = ..CodeDatabaseResource()
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Resources).Create(..#RESOURCE, "OcuPilot impact probe", "", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Resources).Create(..#PUBLICRESOURCE, "OcuPilot impact probe", "R", "")
        If $$$ISERR(tSC) Quit
        For tRole = $ListBuild(..#ROLEDELETE, ""), $ListBuild(..#ROLEA, ..#RESOURCE _ ":R"), $ListBuild(..#ROLEB, ..#RESOURCE _ ":W"), $ListBuild(..#ROLEESCALATION, ..#RESOURCE _ ":R"), $ListBuild(..#ROLEPUBLIC, ..#PUBLICRESOURCE _ ":R"), $ListBuild(..#ROLEG2, ..#RESOURCE _ ":U"), $ListBuild(..#ROLELOW, "%Admin_Secure:U,%DB_IRISSYS:R," _ tCode _ ":R"), $ListBuild(..#ROLENONE, "%Admin_Operate:U,%DB_IRISSYS:R," _ tCode _ ":R") {
            Set tSC = ##class(Security.Roles).Create($List(tRole, 1), "OcuPilot impact probe", $List(tRole, 2), "")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Roles).Create(..#ROLEG1, "OcuPilot impact probe", "", ..#ROLEG2)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Roles).Create(..#ROLEALLVIA, "OcuPilot impact probe", "", "%All")
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("NameSpace") = "USER"
        Set tProps("Enabled") = 1
        Set tProps("AutheEnabled") = 32
        Set tProps("Resource") = ..#RESOURCE
        Set tProps("MatchRoles") = ":" _ ..#ROLEDELETE
        Set tProps("Description") = "OcuPilot impact probe"
        Set tSC = ##class(Security.Applications).Create(..#APP, .tProps)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#USERONE, ..#ROLEDELETE, ..#PASSWORD, "OcuPilot impact probe")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#USERTWO, "", ..#PASSWORD, "OcuPilot impact probe")
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("EscalationRoles") = ..#ROLEDELETE
        Set tSC = ##class(Security.Users).Modify(..#USERTWO, .tProps)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#USERLOSS, ..#ROLEA _ "," _ ..#ROLEB _ "," _ ..#ROLEG1 _ "," _ ..#ROLEG2 _ "," _ ..#ROLEPUBLIC _ "," _ ..#ROLEALLVIA, ..#PASSWORD, "OcuPilot impact probe")
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("EscalationRoles") = ..#ROLEESCALATION
        Set tSC = ##class(Security.Users).Modify(..#USERLOSS, .tProps)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#USERLOW, ..#ROLELOW, ..#PASSWORD, "OcuPilot impact probe")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#USERNONE, ..#ROLENONE, ..#PASSWORD, "OcuPilot impact probe")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete every probe object this class names, where it exists.</p>
Method RemoveAll()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#USERONE, ..#USERTWO, ..#USERLATE, ..#USERLOSS, ..#USERLOW, ..#USERNONE {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        If ##class(Security.Applications).Exists(..#APP) Do ##class(Security.Applications).Delete(..#APP)
        For tRole = ..#ROLEDELETE, ..#ROLEA, ..#ROLEB, ..#ROLEESCALATION, ..#ROLEPUBLIC, ..#ROLEG1, ..#ROLEG2, ..#ROLEALLVIA, ..#ROLELOW, ..#ROLENONE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        For tResource = ..#RESOURCE, ..#PUBLICRESOURCE {
            If ##class(Security.Resources).Exists(tResource) Do ##class(Security.Resources).Delete(tResource)
        }
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Which probe objects the instance still holds, <code>""</code> when none: every account,
/// role, resource and web application whose name begins <parameter>PREFIX</parameter>.</p>
Method Left() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tQuery = "SELECT Name FROM Security.Users WHERE Name %STARTSWITH ?", "SELECT Name FROM Security.Roles WHERE Name %STARTSWITH ?", "SELECT Name FROM Security.Resources WHERE Name %STARTSWITH ?" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tQuery, ..#PREFIX)
            While tRS.%Next() {
                Set tLeft = tLeft _ " " _ tRS.%Get("Name")
            }
        }
        If ##class(Security.Applications).Exists(..#APP) Set tLeft = tLeft _ " " _ ..#APP
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>The resource guarding the install namespace's code database, whose read a principal needs to
/// reach OcuPilot's dispatch class at all (AD-9, AD-21).</p>
Method CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
    } Catch ex {
        Set tResource = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

/// <p>The route's answer for <var>pAction</var> on <var>pId</var> of <var>pScreen</var>, as the
/// test account or, with <var>pUser</var>, as that account; its headers in <var>pHeaders</var>.</p>
Method Impact(pScreen As %String, pAction As %String, pId As %String, pValue As %String = "", Output pStatus As %Integer, pUser As %String = "", Output pHeaders) As %DynamicObject
{
    Set tPath = $Replace(..#ROUTE, ":screen", pScreen) _ "?action=" _ $ZConvert(pAction, "O", "URL") _ "&id=" _ $ZConvert(pId, "O", "URL") _ $Select(pValue = "": "", 1: "&value=" _ $ZConvert(pValue, "O", "URL"))
    Set pStatus = 0
    Set tBody = ""
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..#PASSWORD)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .pStatus, .tRaw, .pHeaders)
    Try {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>The part named <var>pName</var> of <var>pImpact</var>, or <code>""</code>.</p>
Method Part(pImpact As %DynamicObject, pName As %String) As %DynamicObject
{
    If '$IsObject(pImpact) || (pImpact.%GetTypeOf("parts") '= "array") Quit ""
    Set tIterator = pImpact.%Get("parts").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPart) {
        If $IsObject(tPart) && (tPart.%Get("part") = pName) Quit
        Set tPart = ""
    }
    Quit $Get(tPart)
}

/// <p><var>pPart</var>'s count, names and unchecked, as <code>count|name,name|unchecked</code>.</p>
Method Said(pPart As %DynamicObject) As %String
{
    If '$IsObject(pPart) Quit "(no part)"
    Set tNames = ""
    Set tIterator = pPart.%Get("names").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
    }
    Quit pPart.%Get("count") _ "|" _ tNames _ "|" _ pPart.%Get("unchecked")
}

/// <p>AC1 over the route: a role two accounts hold, one of them as an escalation role, and one web
/// application grants answers both parts, and an account added after one read is present at the
/// next.</p>
Method TestARoleDeleteNamesItsHoldersAndGrantingApplications()
{
    Set tBody = ..Impact("permissions.roles", "delete", ..#ROLEDELETE, "", .tStatus, "", .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tImpact = $Select($IsObject(tBody): tBody.%Get("impact"), 1: "")
    Do $$$AssertTrue($IsObject(tImpact), "with an impact")
    If '$IsObject(tImpact) Quit
    Do $$$AssertEquals(tImpact.%Get("kind"), "role-delete", "of a role delete")
    Do $$$AssertEquals(tImpact.%GetTypeOf("refused"), "null", "that is not refused")
    Do $$$AssertEquals(tImpact.%Get("parts").%Get(0).%Get("part"), "holders", "holders first")
    Do $$$AssertEquals(..Said(..Part(tImpact, "holders")), "2|" _ ..#USERONE _ "," _ ..#USERTWO _ "|", "two accounts hold it, the escalation holder counted")
    Do $$$AssertEquals(..Said(..Part(tImpact, "grantingApplications")), "1|" _ ..#APP _ "|", "one web application grants it")

    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tSC = ##class(Security.Users).Create(..#USERLATE, ..#ROLEDELETE, ..#PASSWORD, "OcuPilot impact probe")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "a third holder is added")
    Set tBody = ..Impact("permissions.roles", "delete", ..#ROLEDELETE, "", .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "holders")), "3|" _ ..#USERONE _ "," _ ..#USERTWO _ "," _ ..#USERLATE _ "|", "and the next read counts it")
    Set $NAMESPACE = "%SYS"
    Do ##class(Security.Users).Delete(..#USERLATE)
    Set $NAMESPACE = tOrigNS
}

/// <p>AC1 through the agent's mint: the minted role delete's wire row carries the impact read at
/// the mint, and a holder added afterwards does not reach it.</p>
/// <p>Mutation (Rule 19): drop the <code>impact</code> member from
/// <method>OcuPilot.Kernel.State.Propose.WireRow</method> -- this goes red.</p>
Method TestAMintedRoleDeleteCarriesTheImpactOfItsMint()
{
    Set tTool = "OcuPilot.Screen.Tool.RoleDelete"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#ROLEDELETE, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#ROLELIST, $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), ..#ROLEDELETE, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit

    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tSC = ##class(Security.Users).Create(..#USERLATE, ..#ROLEDELETE, ..#PASSWORD, "OcuPilot impact probe")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "a holder is added after the mint")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, $Username, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tRow = $Select($IsObject($Get(tRows)) && (tRows.%Size() = 1): tRows.%Get(0), 1: "")
    Do $$$AssertTrue($IsObject(tRow), "one wire row comes back")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.%GetTypeOf("impact"), "object", "carrying an impact")
        Do $$$AssertEquals(..Said(..Part(tRow.%Get("impact"), "holders")), "2|" _ ..#USERONE _ "," _ ..#USERTWO _ "|", "counted at the mint, without the later holder")
        Do $$$AssertEquals(..Said(..Part(tRow.%Get("impact"), "grantingApplications")), "1|" _ ..#APP _ "|", "and naming the granting application")
    }
    Set $NAMESPACE = "%SYS"
    Do ##class(Security.Users).Delete(..#USERLATE)
    Set $NAMESPACE = tOrigNS
}

/// <p>AC3 over the route: a resource two roles grant, guarding one web application, answers its
/// three parts; a database the resource does not guard is counted as none.</p>
Method TestAResourceDeleteNamesItsGrantingRolesAndWhatItGuards()
{
    Set tBody = ..Impact("permissions.resources", "delete", ..#RESOURCE, "", .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Set tImpact = $Select($IsObject(tBody): tBody.%Get("impact"), 1: "")
    Do $$$AssertTrue($IsObject(tImpact), "with an impact")
    If '$IsObject(tImpact) Quit
    Do $$$AssertEquals(tImpact.%Get("kind"), "resource-delete", "of a resource delete")
    Do $$$AssertEquals(tImpact.%Get("parts").%Size(), 3, "in three parts")
    Do $$$AssertEquals(..Said(..Part(tImpact, "grantingRoles")), "4|" _ ..#ROLEG2 _ "," _ ..#ROLEA _ "," _ ..#ROLEB _ "|", "four roles grant it, the first three by name")
    Do $$$AssertEquals(..Said(..Part(tImpact, "guardedApplications")), "1|" _ ..#APP _ "|", "it guards one web application")
    Do $$$AssertEquals(..Said(..Part(tImpact, "guardedDatabases")), "0||", "and no database, read and counted")
}

/// <p>AC3's database half, in process: a database's guarding resource names that database by its
/// directory.</p>
Method TestAGuardedDatabaseIsNamedByItsDirectory()
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("resource", "instance", "%DB_USER", .tRef)
    Do $$$AssertStatusOK(tSC, "the reference is built")
    Set tImpact = ##class(OcuPilot.Kernel.Proposal.Impact).Of("permissions.resources.delete", tRef, "{}", "{}", "[]")
    Set tPart = ..Part(tImpact, "guardedDatabases")
    Do $$$AssertTrue($IsObject(tPart) && (tPart.%Get("count") >= 1), "%DB_USER guards at least one database: " _ ..Said(tPart))
    Set tNamed = 0
    If $IsObject(tPart) {
        Set tIterator = tPart.%Get("names").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If $ZConvert(tName, "L") [ "/user/" Set tNamed = 1
        }
    }
    Do $$$AssertTrue(tNamed, "named by its directory")
}

/// <p>AC4: a caller holding the Resources screen's pairs but not <code>%Admin_Manage:USE</code>
/// gets the databases part unchecked, naming the pair, and the other parts read.</p>
/// <p>Mutation (Rule 19): skip the pair gate in <method>OcuPilot.Kernel.Proposal.Impact.ListRows</method>
/// -- the database read is refused inside the port and this goes red.</p>
Method TestAPartTheCallerCannotReadIsUncheckedNamingThePair()
{
    Set tBody = ..Impact("permissions.resources", "delete", ..#RESOURCE, "", .tStatus, ..#USERLOW)
    Do $$$AssertEquals(tStatus, 200, "the route answers the least-privileged caller 200")
    Set tImpact = $Select($IsObject(tBody): tBody.%Get("impact"), 1: "")
    Do $$$AssertTrue($IsObject(tImpact), "with an impact")
    If '$IsObject(tImpact) Quit
    Do $$$AssertEquals(..Said(..Part(tImpact, "guardedDatabases")), "0||%Admin_Manage:USE", "the databases part is unchecked, naming the pair")
    Do $$$AssertEquals(..Said(..Part(tImpact, "guardedApplications")), "1|" _ ..#APP _ "|", "the applications part is read")
    Do $$$AssertEquals(+..Part(tImpact, "grantingRoles").%Get("count"), 4, "and so is the roles part")
}

/// <p>AC2 over the route: a role's removal loses only what no remaining role grants -- directly,
/// through a granted role, through <code>%All</code> or publicly -- and an escalation role counts
/// for nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>GrantedRoles</code> walk from
/// <method>OcuPilot.Kernel.Shell.Effective.Compose</method> -- the transitive leg goes red.</p>
Method TestARoleRemovalLosesOnlyWhatNoOtherRoleGrants()
{
    Set tUser = ..#USERLOSS
    ; The account holds AllVia (%All), so while it does no removal loses anything.
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEB, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Do $$$AssertEquals(tBody.%Get("impact").%Get("kind"), "role-removal", "a role removal")
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "0||", "%All held elsewhere: nothing is lost")
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEALLVIA, .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "1|%All|", "removing AllVia loses %All alone")

    ; Without AllVia, the other legs.
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tProps("Roles") = ..#ROLEA _ "," _ ..#ROLEB _ "," _ ..#ROLEG1 _ "," _ ..#ROLEG2 _ "," _ ..#ROLEPUBLIC
    Set tSC = ##class(Security.Users).Modify(tUser, .tProps)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "the account drops AllVia")
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEB, .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "1|" _ ..#RESOURCE _ ":W|", "removing B loses the W A does not grant")
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEG2, .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "0||", "removing G2 loses nothing G1 still grants")
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEPUBLIC, .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "0||", "removing the public resource's grant loses nothing")
    Set tBody = ..Impact("permissions.users", "remove-role", tUser, ..#ROLEA, .tStatus)
    Do $$$AssertEquals(..Said(..Part(tBody.%Get("impact"), "loses")), "1|" _ ..#RESOURCE _ ":R|", "removing A loses R: the escalation role that grants it counts for nothing")

    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tProps("Roles") = ..#ROLEA _ "," _ ..#ROLEB _ "," _ ..#ROLEG1 _ "," _ ..#ROLEG2 _ "," _ ..#ROLEPUBLIC _ "," _ ..#ROLEALLVIA
    Do ##class(Security.Users).Modify(tUser, .tProps)
    Set $NAMESPACE = tOrigNS
}

/// <p>AC2 and AC5 through the agent's mint: a minted user update whose <code>Roles</code> drops a
/// held role carries the role removal's loss, read from the mint's own fresh read and payload, and
/// one the prohibited set refuses carries that refusal.</p>
/// <p>Mutation (Rule 19): pass <code>""</code> for the fresh read in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>'s <method>ImpactValue</method> call -- this goes
/// red.</p>
Method TestAMintedRoleRemovalCarriesItsLoss()
{
    Set tUser = ..#USERLOSS
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tProps("Roles") = ..#ROLEA _ "," _ ..#ROLEB _ "," _ ..#ROLEG1 _ "," _ ..#ROLEG2 _ "," _ ..#ROLEPUBLIC
    Set tSC = ##class(Security.Users).Modify(tUser, .tProps)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "the account drops AllVia")
    Try {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
        Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
        If $$$ISERR(tSC) Quit
        Set tRow = ..MintRoles(tTurnKey, tUser, [(..#ROLEA), (..#ROLEG1), (..#ROLEG2), (..#ROLEPUBLIC)])
        Do $$$AssertTrue($IsObject(tRow), "one wire row comes back for the removal")
        If $IsObject(tRow) {
            Do $$$AssertEquals(tRow.%Get("impact").%Get("kind"), "role-removal", "carrying a role removal's impact")
            Do $$$AssertEquals(..Said(..Part(tRow.%Get("impact"), "loses")), "1|" _ ..#RESOURCE _ ":W|", "which loses the W no remaining role grants")
        }
        Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
        If $$$ISERR(tSC) Quit
        Set tRow = ..MintRoles(tTurnKey, "_SYSTEM", [])
        Do $$$AssertTrue($IsObject(tRow) && $IsObject(tRow.%Get("impact")) && $IsObject(tRow.%Get("impact").%Get("refused")), "taking every role from _SYSTEM mints with a refused impact")
        If $IsObject(tRow) && $IsObject(tRow.%Get("impact")) && $IsObject(tRow.%Get("impact").%Get("refused")) {
            Do $$$AssertEquals(tRow.%Get("impact").%Get("refused").%Get("code"), ##class(OcuPilot.Kernel.Proposal.Prohibited).#SYSTEMACCOUNT, "as the system account")
            Do $$$AssertEquals(tRow.%Get("impact").%Get("parts").%Size(), 0, "and no parts")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the mint legs ran")
    }
    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tProps("Roles") = ..#ROLEA _ "," _ ..#ROLEB _ "," _ ..#ROLEG1 _ "," _ ..#ROLEG2 _ "," _ ..#ROLEPUBLIC _ "," _ ..#ROLEALLVIA
    Do ##class(Security.Users).Modify(tUser, .tProps)
    Set $NAMESPACE = tOrigNS
}

/// <p>Mint a <code>permissions.users.update</code> of <var>pUser</var> sending <var>pRoles</var> in
/// the turn <var>pTurnKey</var>, and answer its one wire row, or <code>""</code>.</p>
Method MintRoles(pTurnKey As %String, pUser As %String, pRoles As %DynamicArray) As %DynamicObject
{
    Set tTool = ..#USERUPDATETOOL
    Set tArgs = {}
    Do tArgs.%Set("Name", pUser, "string")
    Do tArgs.%Set("Roles", pRoles)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#USERLIST, $Parameter(tTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pUser, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the update of " _ pUser _ " is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(pTurnKey, $Username, .tRows)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) || (tRows.%Size() '= 1) Quit ""
    Quit tRows.%Get(0)
}

/// <p>The impact route refuses a caller the action route refuses, with the same status and code,
/// before anything is read: a principal that reaches the API but lacks the role delete's write
/// pair.</p>
/// <p>Mutation (Rule 19): move the preview's early answer in
/// <method>OcuPilot.Api.ScreenAction.Run</method> above the write pairs' gate -- this goes red.</p>
Method TestTheImpactRouteRefusesWhomTheActionRouteRefuses()
{
    Set tBody = ..Impact("permissions.roles", "delete", ..#ROLEDELETE, "", .tStatus, ..#USERNONE)
    Set tPath = $Replace(..#ACTIONROUTE, ":screen", "permissions.roles")
    Set tRequest = {}
    Do tRequest.%Set("action", "delete", "string")
    Do tRequest.%Set("id", ..#ROLEDELETE, "string")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ..#USERNONE, ..#PASSWORD, .tActionStatus, .tActionRaw, .tActionHeaders, tRequest.%ToJSON(), "application/json")
    Set tAction = ""
    Try {
        Set tAction = ##class(%DynamicAbstractObject).%FromJSON(tActionRaw)
    } Catch {
        Set tAction = ""
    }
    Do $$$AssertEquals(tActionStatus, 403, "the action route refuses the caller")
    Do $$$AssertEquals(tStatus, tActionStatus, "and the impact route answers the same status")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: "(none)"), $Select($IsObject(tAction): tAction.%Get("code"), 1: "(none)"), "with the same code")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tExists = ##class(Security.Roles).Exists(..#ROLEDELETE)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tExists, "and the role is still there")
}

/// <p>AC5: a removal the prohibited set refuses answers that refusal's sentence and no parts --
/// one of OcuPilot's own roles, and <code>%All</code> taken from <code>_SYSTEM</code>.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> in
/// <method>OcuPilot.Kernel.Proposal.Impact.Of</method> -- this goes red.</p>
Method TestARefusedRemovalAnswersItsReasonAndNoParts()
{
    Set tShell = $List(##class(OcuPilot.Test.ImpactRoute).OwnRole(), 1)
    Set tBody = ..Impact("permissions.roles", "delete", tShell, "", .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200 for OcuPilot's own role")
    Set tImpact = $Select($IsObject(tBody): tBody.%Get("impact"), 1: "")
    Do $$$AssertTrue($IsObject(tImpact) && $IsObject(tImpact.%Get("refused")), "with a refused impact")
    If $IsObject(tImpact) && $IsObject(tImpact.%Get("refused")) {
        Do $$$AssertEquals(tImpact.%Get("refused").%Get("code"), ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTROLE, "refused as OcuPilot's own role")
        Do $$$AssertEquals(tImpact.%Get("refused").%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTROLE), "in the prohibited set's own sentence")
        Do $$$AssertEquals(tImpact.%Get("parts").%Size(), 0, "and no parts")
    }
    Set tBody = ..Impact("permissions.users", "remove-role", "_SYSTEM", "%All", .tStatus)
    Set tImpact = $Select($IsObject(tBody): tBody.%Get("impact"), 1: "")
    Do $$$AssertTrue($IsObject(tImpact) && $IsObject(tImpact.%Get("refused")), "%All from _SYSTEM is refused")
    If $IsObject(tImpact) && $IsObject(tImpact.%Get("refused")) {
        Do $$$AssertEquals(tImpact.%Get("refused").%Get("code"), ##class(OcuPilot.Kernel.Proposal.Prohibited).#SYSTEMACCOUNT, "as the system account")
    }
}

/// <p>One of OcuPilot's own roles, as the prohibited set declares them, in a one-element list.</p>
ClassMethod OwnRole() As %List
{
    Do ##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotRoles(.tRoles)
    Quit $ListBuild($List(tRoles, 1))
}

/// <p>An action whose write removes nothing covered answers <code>impact: null</code>, and a
/// request naming no action is refused before any read.</p>
Method TestOtherActionsAnswerNoImpact()
{
    Set tBody = ..Impact("webapp.list", "delete", ..#APP, "", .tStatus)
    Do $$$AssertEquals(tStatus, 200, "a web application delete answers 200")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%GetTypeOf("impact"), 1: ""), "null", "with no impact")
    Set tBody = ..Impact("permissions.users", "add-role", ..#USERONE, ..#ROLEA, .tStatus)
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%GetTypeOf("impact"), 1: ""), "null", "a role add has none either")
    Set tBody = ..Impact("permissions.roles", "", ..#ROLEDELETE, "", .tStatus)
    Do $$$AssertEquals(tStatus, 400, "no action is refused 400")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "as the action route refuses it")
}

}
