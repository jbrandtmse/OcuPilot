/// <p>System Explorer's pair set against the <b>real</b> <code>$System.Security.Check</code> (AD-8,
/// AD-29, AD-61): over the wire, and at <class>OcuPilot.Port.AtelierPort</class> called directly, as
/// it is on the tool path, one leg per pair the port's gate evaluates.</p>
/// <ul>
/// <li>A principal holding the measured set -- <code>%Development:USE</code> and READ on each
/// namespace's code databases -- reads both lists and both viewers in the install namespace and the
/// Classes list in <code>USER</code>.</li>
/// <li>Without <code>%Development:USE</code> it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// that pair, by the route and by the port, with no route called.</li>
/// <li>Without READ on <code>USER</code>'s database the port refuses a <code>USER</code> read naming
/// that pair, before any route.</li>
/// <li>With a database the install namespace maps code from made non-public, the port and the
/// route refuse naming its pair, rather than answering an empty list.</li>
/// <li>Search and Macros (Story 19.4): without <code>%Development:USE</code> both reads, and the
/// Search, Compare and Macros screens on the navigation map, are refused naming that pair; without
/// READ on <code>USER</code>'s database the port refuses both there naming that pair, before any
/// route.</li>
/// <li>The SQL catalog (Story 19.5): without <code>%Development:USE</code> a list's and a tab's reads,
/// and the four lists on the navigation map, are refused naming that pair; without READ on
/// <code>USER</code>'s database the port refuses both there naming that pair, before any route.</li>
/// </ul>
/// <p>The direct calls run in a child process (<class>OcuPilot.Test.AtelierDenialProbe</class>) that
/// logs in as the principal, so this process never changes identity.</p>
/// <p><b>It creates security principals and changes one database resource's public permission, so it
/// runs on a throwaway container only</b>, and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Each principal also holds
/// <code>%Admin_Operate:USE</code>, which clears the API's administrative floor, and READ on the
/// install namespace's code database. Their password is generated for the run and never written to
/// source; both principals are deleted, and the permission restored, in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.AtelierPortDenial Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding the measured set.</p>
Parameter FULLUSER = "OcuPilotAtelierFull";

/// <p>See <parameter>FULLUSER</parameter>.</p>
Parameter FULLROLE = "OcuPilotAtelierFullRole";

/// <p>The principal holding the set but <code>%Development:USE</code>.</p>
Parameter NODEVUSER = "OcuPilotAtelierNoDev";

/// <p>See <parameter>NODEVUSER</parameter>.</p>
Parameter NODEVROLE = "OcuPilotAtelierNoDevRole";

/// <p>The principal holding the set but READ on <code>USER</code>'s database.</p>
Parameter NOUSERUSER = "OcuPilotAtelierNoUser";

/// <p>See <parameter>NOUSERUSER</parameter>.</p>
Parameter NOUSERROLE = "OcuPilotAtelierNoUserRole";

/// <p>The second namespace read.</p>
Parameter OTHERNAMESPACE = "USER";

/// <p>The principals' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back each principal's pairs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The publicly readable database resource the install namespace maps code from that the mapped
/// leg makes non-public, and its public permission before the leg.</p>
Property PreparedMapped As %String;

/// <p>See <property>PreparedMapped</property>.</p>
Property PreparedMappedPublic As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedMapped = ""
    Set ..PreparedMappedPublic = ""
    Quit $$$OK
}

/// <p>Refuse to run unless this instance is armed for throwaway principals, then create the three
/// principals, read their pairs back and choose the mapped database.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortDenial creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#OTHERNAMESPACE, .tOther, .tOtherGlobals, .tOtherMapped, .tOtherResolved)
        If 'tResolved || 'tOtherResolved {
            Set tSC = $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
            Quit
        }
        Set ..PreparedPassword = "OcuPilotAtelier" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        ; The mapped leg takes a publicly readable mapped database other than IRISLIB, whose code
        ; every process runs.
        For tI = 1:1:$ListLength(tMapped) {
            Set tCandidate = $List(tMapped, tI)
            If tCandidate = "%DB_IRISLIB" Continue
            Kill tProps
            If '##class(Security.Resources).Get(tCandidate, .tProps) Continue
            If $Get(tProps("PublicPermission")) '[ "R" Continue
            Set ..PreparedMapped = tCandidate
            Set ..PreparedMappedPublic = tProps("PublicPermission")
            Quit
        }
        Set tBase = "%Admin_Operate:U," _ tHome _ ":R"
        Set tSC = ..EnsurePrincipal(..#FULLROLE, ..#FULLUSER, tBase _ ",%Development:U," _ tOther _ ":R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NODEVROLE, ..#NODEVUSER, tBase _ "," _ tOther _ ":R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOUSERROLE, ..#NOUSERUSER, tBase _ ",%Development:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tFull = ($SYSTEM.Security.CheckUserPermission(..#FULLUSER, "%Development", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#FULLUSER, tOther, "READ") = 1)
        Set tNoDev = ($SYSTEM.Security.CheckUserPermission(..#NODEVUSER, "%Development", "USE") '= 1)
        Set tNoUser = ($SYSTEM.Security.CheckUserPermission(..#NOUSERUSER, tOther, "READ") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOUSERUSER, "%Development", "USE") = 1)
        Set ..PreparedSetupOk = tFull && tNoDev && tNoUser
        If '..PreparedSetupOk Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principals' pairs: full " _ tFull _ ", no-development " _ tNoDev _ ", no-user " _ tNoUser)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Restore the mapped database's public permission, remove the principals and their roles, and
/// return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ..PreparedMapped '= "" {
            Kill tProps
            Set tProps("PublicPermission") = ..PreparedMappedPublic
            Do ##class(Security.Resources).Modify(..PreparedMapped, .tProps)
            Kill tRead
            Do ##class(Security.Resources).Get(..PreparedMapped, .tRead)
            If $Get(tRead("PublicPermission")) '= ..PreparedMappedPublic Set tLeft = tLeft _ " the public permission of " _ ..PreparedMapped
        }
        For tUser = ..#FULLUSER, ..#NODEVUSER, ..#NOUSERUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ tUser
        }
        For tRole = ..#FULLROLE, ..#NODEVROLE, ..#NOUSERROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ " role " _ tRole
        }
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortDenial teardown left the instance changed:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: source code API principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot source code API test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AtelierPortDenial; deleted in OnAfterAllTests")
}

/// <p>Set the mapped database's public permission to <var>pPermission</var>.</p>
Method SetMappedPublic(pPermission As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("PublicPermission") = pPermission
        Set tSC = ##class(Security.Resources).Modify(..PreparedMapped, .tProps)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p><var>pTool</var>'s read with <var>pQuery</var> as <var>pUser</var>, as
/// <code>http code failedPair</code> plus <code>rows=n</code> on a 200.</p>
Method Read(pUser As %String, pTool As %String, pQuery As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?" _ pQuery, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit "unreached " _ $System.Status.GetErrorText(tSC)
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set tAnswer = ""
    }
    If '$IsObject(tAnswer) Quit tStatus _ " unparsed"
    If tStatus = 200 Quit "200 rows=" _ $Select($IsObject(tAnswer.%Get("rows")): tAnswer.rows.%Size(), 1: "none")
    Quit tStatus _ " " _ tAnswer.%Get("code") _ " " _ $Select($IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: "")
}

/// <p>The navigation map's verdict, as <code>allowed failedPair</code>, on each of
/// <var>pRoutes</var> (comma-separated) for <var>pUser</var>, joined by <code>,</code>.</p>
Method Verdicts(pUser As %String, pRoutes As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit "unreached " _ $Get(tStatus)
    Set tMap = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    Kill tSeen
    Set tAreas = tMap.areas.%GetIterator()
    While tAreas.%GetNext(.tIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If tScreen.route '= "" Set tSeen(tScreen.route) = ''tScreen.allowed _ " " _ tScreen.%Get("failedPair")
        }
    }
    Set tOut = ""
    For tI = 1:1:$Length(pRoutes, ",") {
        Set tOut = tOut _ $Select(tI = 1: "", 1: ",") _ $Get(tSeen($Piece(pRoutes, ",", tI)), "absent")
    }
    Quit tOut
}

/// <p>Run <class>OcuPilot.Test.AtelierDenialProbe</class> as <var>pUser</var> over
/// <var>pNamespaces</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pNamespaces As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AtelierDenialProbe).Run($Job, pUser, pNamespaces)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>A probe leg as <code>http calls code failedPair</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pNamespace As %String, pLeg As %String) As %String
{
    Set tLegs = pProbe.%Get(pNamespace)
    If '$IsObject(tLegs) || '$IsObject(tLegs.%Get(pLeg)) Quit "absent"
    Set tLeg = tLegs.%Get(pLeg)
    Quit tLeg.http _ $Select(tLeg.%IsDefined("calls"): " calls=" _ tLeg.calls, 1: "") _ $Select(tLeg.%IsDefined("rows"): " rows=" _ tLeg.rows, 1: "") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>AC5: a principal holding the measured set reads both lists and both viewers in the install
/// namespace and the Classes list in <code>USER</code>, over the wire and through the port.</p>
Method TestTheMeasuredSetReadsEveryScreen()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tHere = $Namespace
    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.classes", "maxRows=1&ns=" _ tHere), "200 rows=1", "the Classes list")
    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.routines", "maxRows=1&pattern=*&ns=" _ tHere), "200 rows=1", "the Routines list")
    Do $$$AssertTrue(..Read(..#FULLUSER, "explorer.class", "name=OcuPilot.Kernel.EntityId.cls&ns=" _ tHere) [ "200 rows=", "the class viewer")
    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.routine", "name=HS.HC.Info.mac&ns=" _ tHere), "200 rows=1", "the routine viewer")
    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.classes", "maxRows=1&ns=" _ ..#OTHERNAMESPACE), "200 rows=1", "and the Classes list in USER")
    Set tProbe = ..ProbeAs(..#FULLUSER, tHere _ "," _ ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("username"), ..#FULLUSER, "as the principal")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Port"), "200 rows=1  ", "the port reads the install namespace")
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Port"), "200 rows=1  ", "and USER")
}

/// <p>AC5: without <code>%Development:USE</code> every read is refused 403 naming it, by the route
/// and by the port before any route.</p>
/// <p>Mutation: drop <code>EvaluateRequired</code> on <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>
/// -&gt; the port legs go red.</p>
Method TestWithoutDevelopmentEveryReadIsRefusedNamingIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tHere = $Namespace
    For tTool = "explorer.classes", "explorer.routines" {
        Do $$$AssertEquals(..Read(..#NODEVUSER, tTool, "maxRows=1&ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", tTool _ " is refused by the route, naming the pair")
    }
    Do $$$AssertEquals(..Read(..#NODEVUSER, "explorer.class", "name=OcuPilot.Kernel.EntityId.cls&ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", "and so is the class viewer")
    Set tProbe = ..ProbeAs(..#NODEVUSER, tHere)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Classes"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "the port refuses a list before any route")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Class"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "and a document")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Port"), "403 rows=-1 AUTH.NOPRIVILEGE %Development:USE", "and so does the production port")
}

/// <p>AC5: without READ on <code>USER</code>'s database the port refuses a <code>USER</code> read
/// naming that pair before any route, and still reads the install namespace.</p>
/// <p>Mutation: drop the namespace's own routines and globals database pairs from
/// <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> -&gt; the USER legs read the vendor's
/// <code>&lt;PROTECT&gt;</code> instead of the pair.</p>
Method TestWithoutTheNamespacesDatabaseTheReadIsRefusedNamingIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#OTHERNAMESPACE, .tOther, .tGlobals, .tMapped, .tResolved)
    Set tProbe = ..ProbeAs(..#NOUSERUSER, $Namespace _ "," _ ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Classes"), "403 calls=0 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "a USER list is refused naming the database's pair")
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Port"), "403 rows=-1 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "by the production port too")
    Do $$$AssertEquals(..LegText(tProbe, $Namespace, "Port"), "200 rows=1  ", "while the install namespace still reads")
}

/// <p>AC5: with a database the install namespace maps code from made non-public, a principal that
/// does not hold it is refused naming its pair -- where the vendor answers an empty list -- by the
/// port and by the route.</p>
/// <p>Mutation: drop the mapped databases from
/// <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> -&gt; the route's and the port's
/// refusals go red.</p>
Method TestAMappedDatabaseIsGatedRatherThanReadEmpty()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Do $$$AssertNotEquals(..PreparedMapped, "", "the install namespace maps code from a publicly readable database other than IRISLIB")
    If ..PreparedMapped = "" Quit
    Set tSC = ..SetMappedPublic("")
    Do $$$AssertStatusOK(tSC, ..PreparedMapped _ " is made non-public")
    Set tHere = $Namespace
    Set tRoute = ..Read(..#FULLUSER, "explorer.classes", "maxRows=1&ns=" _ tHere)
    Set tProbe = ..ProbeAs(..#FULLUSER, tHere)
    Do ..SetMappedPublic(..PreparedMappedPublic)
    Do $$$AssertEquals(tRoute, "403 AUTH.NOPRIVILEGE " _ ..PreparedMapped _ ":READ", "the route refuses naming the mapped database's pair")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Classes"), "403 calls=0 AUTH.NOPRIVILEGE " _ ..PreparedMapped _ ":READ", "and so does the port, before any route")
}

/// <p>Story 19.4 AC8: without <code>%Development:USE</code> the Search and Macros reads are refused
/// 403 naming it by the route and by the port before any route, and the navigation map draws Search,
/// Compare and Macros unavailable naming it; without READ on <code>USER</code>'s database the port
/// refuses both there naming that pair before any route, and the full principal searches and looks
/// a macro up in <code>USER</code>.</p>
/// <p>Mutation (Rule 19): give <class>OcuPilot.Screen.Descriptor.ExplorerSearch</class> an empty
/// pair set -&gt; the navigation map opens Search and the verdict assertion goes red.</p>
Method TestSearchAndMacrosAreRefusedNamingThePair()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tHere = $Namespace
    Do $$$AssertEquals(..Read(..#NODEVUSER, "explorer.search", "text=Quit&ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", "the search is refused by the route, naming the pair")
    Do $$$AssertEquals(..Read(..#NODEVUSER, "explorer.macro", "document=%25Library.Persistent.cls&macro=OK&ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", "and so is the macro lookup")
    Do $$$AssertEquals(..Verdicts(..#NODEVUSER, "system-explorer/search,system-explorer/compare,system-explorer/macros"), "0 %Development:USE,0 %Development:USE,0 %Development:USE", "the map draws Search, Compare and Macros unavailable, naming the pair")
    Set tProbe = ..ProbeAs(..#NODEVUSER, tHere)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Search"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "the port refuses a search before any route")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Macro"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "and a macro lookup")

    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#OTHERNAMESPACE, .tOther, .tGlobals, .tMapped, .tResolved)
    Set tProbe = ..ProbeAs(..#NOUSERUSER, ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Search"), "403 calls=0 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "a USER search is refused naming the database's pair")
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Macro"), "403 calls=0 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "and so is a USER lookup")

    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.search", "text=Quit&maxRows=1&ns=" _ ..#OTHERNAMESPACE), "200 rows=1", "the full principal searches USER")
    Do $$$AssertEquals(..Read(..#FULLUSER, "explorer.macro", "document=%25Library.Persistent.cls&macro=OK&ns=" _ ..#OTHERNAMESPACE), "200 rows=1", "and looks a macro up there")
}

/// <p>Story 19.5 AC7: without <code>%Development:USE</code> the SQL tables and Triggers reads are
/// refused 403 naming it by the route and by the port before any route, and the navigation map draws
/// the four catalog lists unavailable naming it; without READ on <code>USER</code>'s database the port
/// refuses both there naming that pair before any route; and the full principal is answered the schemas
/// in <code>USER</code>.</p>
/// <p>Mutation (Rule 19): give <class>OcuPilot.Screen.Descriptor.ExplorerSqlTables</class> an empty
/// pair set -&gt; the navigation map opens SQL tables and the verdict assertion goes red.</p>
Method TestTheCatalogIsRefusedNamingThePair()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tHere = $Namespace
    Do $$$AssertEquals(..Read(..#NODEVUSER, "explorer.sqltables", "ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", "the tables read is refused by the route, naming the pair")
    Do $$$AssertEquals(..Read(..#NODEVUSER, "explorer.sqltriggers", "table=%25Dictionary.ClassDefinition&ns=" _ tHere), "403 AUTH.NOPRIVILEGE %Development:USE", "and so is a tab's")
    Do $$$AssertEquals(..Verdicts(..#NODEVUSER, "system-explorer/sql-schemas,system-explorer/sql-tables,system-explorer/sql-views,system-explorer/sql-procedures"), "0 %Development:USE,0 %Development:USE,0 %Development:USE,0 %Development:USE", "the map draws the four catalog lists unavailable, naming the pair")
    Set tProbe = ..ProbeAs(..#NODEVUSER, tHere)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Catalog.Tables"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "the port refuses a list before any route")
    Do $$$AssertEquals(..LegText(tProbe, tHere, "Catalog.Triggers"), "403 calls=0 AUTH.NOPRIVILEGE %Development:USE", "and a tab")

    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#OTHERNAMESPACE, .tOther, .tGlobals, .tMapped, .tResolved)
    Set tProbe = ..ProbeAs(..#NOUSERUSER, ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Catalog.Tables"), "403 calls=0 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "a USER list is refused naming the database's pair")
    Do $$$AssertEquals(..LegText(tProbe, ..#OTHERNAMESPACE, "Catalog.Triggers"), "403 calls=0 AUTH.NOPRIVILEGE " _ tOther _ ":READ", "and so is a USER tab")

    Set tRead = ..Read(..#FULLUSER, "explorer.sqlschemas", "maxRows=1&system=yes&ns=" _ ..#OTHERNAMESPACE)
    Do $$$AssertTrue($Extract(tRead, 1, 9) = "200 rows=", "the full principal reads the schemas in USER, which its SQL privileges filter: " _ tRead)
}

}
