/// <p>The application error log's <b>per-namespace</b> gate over the wire, against the real
/// <code>$System.Security.Check</code> (AD-8, AD-29, AD-48). Four measurements on four
/// purpose-built principals:</p>
/// <ul>
/// <li>a principal holding <code>%Admin_Operate:USE</code> but not both database permissions on the
/// target namespace's globals database is refused 403, with the pair it lacks named;</li>
/// <li>a principal holding both database permissions but not <code>%Admin_Operate:USE</code> --
/// which still clears the API's own administrative gate, on another resource -- is refused 403
/// naming <code>%Admin_Operate:USE</code>, because that pair is declared first;</li>
/// <li>a principal holding both of those and <b>not</b> <code>%DB_IRISSYS:READ</code> is refused 403
/// naming it. <b>This one is why that pair is in the set at all</b>: measured here first as a 500
/// naming no pair, because database READ is routine-execution permission and
/// <code>SYS.ApplicationError</code> lives in <code>%SYS</code>, whose routine database is IRISSYS
/// -- so IRIS refused the class load before OcuPilot's gate had anything to say (AD-29's rule that
/// a declared set is established by measurement, not by reading a vendor gate);</li>
/// <li>and the per-namespace measurement itself: <b>one principal, in one session, served 200 for
/// the namespace whose whole pair set it holds and refused 403 for one it holds only READ on</b>,
/// with that namespace's own <code>%DB_*:WRITE</code> named.</li>
/// </ul>
/// <p>That last is what "the requirement is a function of the selected namespace" means in
/// evidence: a single static descriptor resource could not produce both answers for one caller.</p>
/// <p><b>The refused namespace is one the principal can READ, and that is measured rather than
/// chosen for neatness.</b> <code>SYS.ApplicationError</code>'s own <code>NamespaceList</code>
/// filters by what the caller can read -- observed here: a principal without
/// <code>%DB_USER:R</code> is not offered <code>USER</code> at all -- so a namespace it cannot read
/// never reaches the gate and is refused 404 by the enumeration instead. The pair set's own
/// per-namespace half therefore bites exactly where AD-48 says it should: on the WRITE this screen
/// requires and the data's own readability does not.</p>
/// <p><b>It creates security principals and writes one application error, so it runs on a throwaway
/// container only</b> (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>).
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does not
/// arm it, and the write goes through
/// <method>OcuPilot.Test.ErrorLogSeed.SeedInto</method>, which carries its own arming guard. The
/// write is needed because the refused-namespace leg needs a <i>second</i> namespace that actually
/// holds errors: a namespace the instance records none for is refused 404 before the gate is
/// reached, which measures nothing about privilege.</p>
/// <p>Each principal also holds read on the install namespace's code database, without which IRIS
/// cannot load the dispatch class for that request at all. Their password is generated for the run
/// and never written to source; all four are deleted in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.ErrorLogDenial Extends %UnitTest.TestCase
{

/// <p>The errors level's route, which every leg here reads.</p>
Parameter LISTPATH = "/api/ocupilot/logs/errors/list";

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_Operate:U</code> and not the full database pair set for
/// the namespace it reads -- refused on the database pair it lacks.</p>
Parameter DBUSER = "OcuPilotErrDb";

/// <p>See <parameter>DBUSER</parameter>.</p>
Parameter DBROLE = "OcuPilotErrDbRole";

/// <p>The principal holding the database pairs and <code>%Admin_Secure:U</code> -- which clears the
/// API's administrative gate -- but not <code>%Admin_Operate:U</code>.</p>
Parameter OPERATEUSER = "OcuPilotErrOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotErrOperateRole";

/// <p>The principal holding everything but <code>%DB_IRISSYS:READ</code> -- the measurement that
/// puts that pair in the set.</p>
Parameter SYSUSER = "OcuPilotErrSys";

/// <p>See <parameter>SYSUSER</parameter>.</p>
Parameter SYSROLE = "OcuPilotErrSysRole";

/// <p>The resource guarding the database <code>SYS.ApplicationError</code> is executed from.</p>
Parameter SYSRESOURCE = "%DB_IRISSYS";

/// <p>The principal holding the whole set for one namespace and nothing for the other -- the
/// per-namespace measurement.</p>
Parameter SERVEDUSER = "OcuPilotErrServed";

/// <p>See <parameter>SERVEDUSER</parameter>.</p>
Parameter SERVEDROLE = "OcuPilotErrServedRole";

/// <p>The four accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>The namespace the served principal holds the whole set for, and the date and entry it
/// reads.</p>
Property PreparedServedNamespace As %String;

/// <p>The namespace the served principal holds READ but not WRITE on -- seeded here so it is in the
/// instance's own namespace list, which is what makes its refusal the gate's rather than the
/// enumeration's.</p>
Property PreparedRefusedNamespace As %String;

/// <p>A date <property>PreparedServedNamespace</property> records errors for.</p>
Property PreparedServedDate As %String;

/// <p>A date <property>PreparedRefusedNamespace</property> records errors for.</p>
Property PreparedRefusedDate As %String;

/// <p>The resource guarding <property>PreparedServedNamespace</property>'s globals database.</p>
Property PreparedServedResource As %String;

/// <p>The resource guarding <property>PreparedRefusedNamespace</property>'s globals database.</p>
Property PreparedRefusedResource As %String;

/// <p>The pair the database-denied principal is expected to be refused on: whichever of READ and
/// WRITE it does not hold, read back from the instance rather than predicted.</p>
Property PreparedDbFailedPair As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedServedNamespace = ""
    Set ..PreparedRefusedNamespace = ""
    Set ..PreparedServedDate = ""
    Set ..PreparedRefusedDate = ""
    Set ..PreparedServedResource = ""
    Set ..PreparedRefusedResource = ""
    Set ..PreparedDbFailedPair = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless this instance is armed for throwaway principals, then seed the
/// second namespace, resolve both namespaces' guarding resources and create the four accounts.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorLogDenial creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedServedNamespace = tInstallNs
        Set ..PreparedRefusedNamespace = ##class(OcuPilot.Test.ErrorLogSeed).#TARGETNAMESPACE
        Set ..PreparedPassword = "OcuPilotErr" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        ; The refused namespace must actually hold errors, or it is refused 404 by the
        ; enumeration before the gate is reached and this class would measure nothing.
        Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..PreparedRefusedNamespace, .tDay, .tNumber)
        If $$$ISERR(tSC) Quit
        Set ..PreparedRefusedDate = $ZDate(tDay, 1)

        Set tSC = ..ResolveDate(..PreparedServedNamespace, .tServedDate)
        If $$$ISERR(tSC) Quit
        Set ..PreparedServedDate = tServedDate

        If '##class(OcuPilot.Api.Namespaces).GlobalDatabase(..PreparedServedNamespace, .tServedResource, .tServedReadOnly) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the globals-database resource for " _ ..PreparedServedNamespace)
            Quit
        }
        Set ..PreparedServedResource = tServedResource
        If '##class(OcuPilot.Api.Namespaces).GlobalDatabase(..PreparedRefusedNamespace, .tRefusedResource, .tRefusedReadOnly) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the globals-database resource for " _ ..PreparedRefusedNamespace)
            Quit
        }
        Set ..PreparedRefusedResource = tRefusedResource
        If tRefusedResource = tServedResource {
            Set tSC = $$$ERROR($$$GeneralError, "The two namespaces share one guarding resource (" _ tServedResource _ "), so no principal can be served one and refused the other")
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set tCodeRead = tSysDb.ResourceName _ ":R"

        ; %DB_IRISSYS:R on every principal but the one that measures its absence: without it IRIS
        ; refuses to load SYS.ApplicationError at all, and the refusal that reaches the caller is a
        ; 500 naming no pair rather than this port's own 403.
        Set tSysRead = "," _ ..#SYSRESOURCE _ ":R"
        Set tSC = ..EnsurePrincipal(..#DBROLE, ..#DBUSER, ..MergedResources(tCodeRead _ ",%Admin_Operate:U" _ tSysRead), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OPERATEROLE, ..#OPERATEUSER, ..MergedResources(tCodeRead _ ",%Admin_Secure:U," _ tServedResource _ ":RW" _ tSysRead), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#SYSROLE, ..#SYSUSER, ..MergedResources(tCodeRead _ ",%Admin_Operate:U," _ tServedResource _ ":RW"), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        ; READ, not RW, on the refused namespace: NamespaceList only offers a namespace the caller
        ; can read, so a principal without READ is refused 404 by the enumeration and the gate is
        ; never reached. READ without WRITE is where the per-namespace half of the set actually
        ; bites -- and it is AD-48's own consequence, that a caller who could read ^ERRORS directly
        ; is still refused by OcuPilot.
        Set tSC = ..EnsurePrincipal(..#SERVEDROLE, ..#SERVEDUSER, ..MergedResources(tCodeRead _ ",%Admin_Operate:U," _ tServedResource _ ":RW," _ tRefusedResource _ ":R" _ tSysRead), ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        ; Read back what each account actually holds, rather than predicting it: the code database
        ; and the globals database may be one database, so the database-denied principal may hold
        ; READ already and be refused on WRITE instead. Which pair is named is the gate's answer,
        ; and this is where it is established.
        Set ..PreparedDbFailedPair = ""
        If $SYSTEM.Security.CheckUserPermission(..#DBUSER, tServedResource, "READ") '= 1 {
            Set ..PreparedDbFailedPair = tServedResource _ ":READ"
        } ElseIf $SYSTEM.Security.CheckUserPermission(..#DBUSER, tServedResource, "WRITE") '= 1 {
            Set ..PreparedDbFailedPair = tServedResource _ ":WRITE"
        }
        Set tOperateOk = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Secure", "USE") = 1)
        Set tSysOk = ($SYSTEM.Security.CheckUserPermission(..#SYSUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SYSUSER, tServedResource, "WRITE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SYSUSER, ..#SYSRESOURCE, "READ") '= 1)
        Set tServedOk = ($SYSTEM.Security.CheckUserPermission(..#SERVEDUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SERVEDUSER, tServedResource, "WRITE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SERVEDUSER, ..#SYSRESOURCE, "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SERVEDUSER, tRefusedResource, "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SERVEDUSER, tRefusedResource, "WRITE") '= 1)
        If (..PreparedDbFailedPair = "") || 'tOperateOk || 'tSysOk || 'tServedOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the four principals' pairs: db '" _ ..PreparedDbFailedPair _ "', operate " _ tOperateOk _ ", sys " _ tSysOk _ ", served " _ tServedOk)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>A date <var>pNamespace</var> records errors for, read through the port as this suite's own
/// account.</p>
Method ResolveDate(pNamespace As %String, Output pDate As %String) As %Status
{
    Set pDate = ""
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("dates", pNamespace, "", "", "", .tDates, .tStatus, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If tDates.rows.%Size() = 0 {
        Quit $$$ERROR($$$GeneralError, "This instance records no application errors for " _ pNamespace _ ", so there is nothing for a served principal to read")
    }
    Set pDate = tDates.rows.%Get(0).date
    Quit $$$OK
}

/// <p>Remove the four accounts and their roles, and <b>return a failing status</b> if any
/// survives. Reported through the status rather than assertions, which
/// <code>%UnitTest.Manager</code> does not record from this method.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#DBUSER, ..#OPERATEUSER, ..#SYSUSER, ..#SERVEDUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#DBROLE, ..#OPERATEROLE, ..#SYSROLE, ..#SERVEDROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorLogDenial teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p><var>pSpecs</var>, a comma-separated list of <code>resource:permissions</code>, with entries
/// naming one resource twice merged into a single entry carrying the union of their
/// permissions.</p>
/// <p><b>Not cosmetic.</b> <code>Security.Roles.Create</code> refuses a list naming a resource
/// twice with <code>ERROR #895: Duplicate resource</code>, and the install namespace's routine
/// database and its globals database are the <i>same</i> database on this image -- so the code read
/// each principal needs and the globals pairs the gate tests are the same resource, and spelling
/// them as two entries makes every role creation here fail.</p>
ClassMethod MergedResources(pSpecs As %String) As %String
{
    Kill tOrder
    Kill tHeld
    Set tCount = 0
    For tI = 1:1:$Length(pSpecs, ",") {
        Set tSpec = $Piece(pSpecs, ",", tI)
        If tSpec = "" Continue
        Set tResource = $Piece(tSpec, ":", 1)
        Set tPermissions = $Piece(tSpec, ":", 2)
        If '$Data(tHeld(tResource)) {
            Set tCount = tCount + 1
            Set tOrder(tCount) = tResource
            Set tHeld(tResource) = ""
        }
        For tJ = 1:1:$Length(tPermissions) {
            Set tLetter = $Extract(tPermissions, tJ)
            If tHeld(tResource) '[ tLetter Set tHeld(tResource) = tHeld(tResource) _ tLetter
        }
    }
    Set tMerged = ""
    For tI = 1:1:tCount {
        Set tResource = tOrder(tI)
        Set tMerged = tMerged _ $Select(tMerged = "": "", 1: ",") _ tResource _ ":" _ tHeld(tResource)
    }
    Quit tMerged
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: application error log principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot application error log test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ErrorLogDenial; deleted in OnAfterAllTests")
}

/// <p>Request the errors level for <var>pNamespace</var> and <var>pDate</var> as
/// <var>pUser</var>.</p>
Method Fetch(pUser As %String, pNamespace As %String, pDate As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tPath = ..#LISTPATH _ "?namespace=" _ $ZConvert(pNamespace, "O", "URL") _ "&date=" _ $ZConvert(pDate, "O", "URL")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, pUser, ..PreparedPassword, .pStatus, .pBody, .pHeaders)
}

/// <p>The fault's <code>detail.failedPair</code>, or <code>""</code>.</p>
ClassMethod FailedPairOf(pBody As %String) As %String
{
    Set tFault = ##class(%DynamicObject).%FromJSON(pBody)
    If '$IsObject(tFault.detail) Quit ""
    Quit tFault.detail.failedPair
}

/// <p>AC6 -- a principal holding <code>%Admin_Operate:USE</code> and not the whole database pair
/// set on the target namespace's globals database is refused 403, with the pair it lacks named. It
/// clears the API's own administrative gate, so what refuses it is the port's per-namespace
/// set.</p>
/// <p><b>Which of READ and WRITE it is named on is the instance's answer, not this method's
/// name.</b> On an image where the install namespace's routine and globals database are one -- this
/// one -- the code read every principal here needs already grants READ on the resource the gate
/// tests, so the pair this account lacks is WRITE and WRITE is what the gate names.
/// <method>OnBeforeAllTests</method> reads back which one it is
/// (<property>PreparedDbFailedPair</property>) rather than predicting it, and the assertion below
/// compares against that. The claim under test is "the port's own per-namespace database pair
/// refuses it, and the gate names that pair" -- not one particular permission letter.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.PairsFor</method> ignore its namespace and
/// answer the operate pair alone -&gt; this principal is served and every assertion here goes red,
/// while <method>TestAPrincipalWithoutAdminOperateIsRefused</method> stays green.</p>
Method TestAPrincipalWithoutDatabaseReadIsRefused()
{
    Do $$$AssertNotEquals(..PreparedDbFailedPair, "", "setup established which database pair this principal lacks")
    Set tSC = ..Fetch(..#DBUSER, ..PreparedServedNamespace, ..PreparedServedDate, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the read is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code, not the router's AUTH.NOADMIN")
    Do $$$AssertEquals(..FailedPairOf(tBody), ..PreparedDbFailedPair, "naming the database pair that failed")
    Do $$$AssertEquals(tFault.%IsDefined("rows"), 0, "and no rows come back with it")
}

/// <p>AC6 -- a principal holding the database pairs but not <code>%Admin_Operate:USE</code> is
/// refused 403 naming that pair. It holds <code>%Admin_Secure:USE</code>, so the API's own
/// administrative gate admits it and the refusal is the port's; and the pair order is what decides
/// which pair is named, so a set that prepended the database pairs would name one of those
/// instead.</p>
/// <p>Mutation: drop <parameter>OcuPilot.Port.LogSourcePort.ERRORSINSTANCEPAIRS</parameter> from the
/// per-namespace set -&gt; this principal is served and every assertion here goes red.</p>
Method TestAPrincipalWithoutAdminOperateIsRefused()
{
    Set tSC = ..Fetch(..#OPERATEUSER, ..PreparedServedNamespace, ..PreparedServedDate, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the read is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals(..FailedPairOf(tBody), "%Admin_Operate:USE", "naming the pair declared first")
}

/// <p>AC6, AD-29 -- a principal holding everything this screen declares <b>except</b>
/// <code>%DB_IRISSYS:READ</code> is refused 403 naming that pair, rather than answered a 500 naming
/// none.</p>
/// <p><b>This leg is why the pair is declared.</b> <code>SYS.ApplicationError</code> exists only in
/// <code>%SYS</code>, whose routine database is IRISSYS, and database READ <i>is</i>
/// routine-execution permission -- so without the pair in the set, IRIS refuses the class load
/// inside the port's own <code>%SYS</code> window and the caller is answered the generic internal
/// envelope. Measured on this principal before the pair was added, and this is the assertion that
/// keeps it added (AD-29: a declared set is established by running as a real least-privileged
/// principal and adding what the instance still refuses, never by reading a vendor gate).</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from
/// <parameter>OcuPilot.Port.LogSourcePort.ERRORSINSTANCEPAIRS</parameter> -&gt; this principal is
/// answered 500 <code>INTERNAL</code> and both the status and the code assertions go red, while
/// every other leg here stays green.</p>
Method TestAPrincipalWithoutTheSystemDatabaseReadIsRefusedByTheGate()
{
    Set tSC = ..Fetch(..#SYSUSER, ..PreparedServedNamespace, ..PreparedServedDate, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the read is refused by the gate rather than raised inside the %SYS window")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code, never the generic INTERNAL a <PROTECT> produces")
    Do $$$AssertEquals(..FailedPairOf(tBody), ..#SYSRESOURCE _ ":READ", "naming the database the query is executed from")
}

/// <p>AC6, the per-namespace measurement -- <b>one principal, one session, two answers</b>: served
/// 200 for the namespace whose whole pair set it holds, refused 403 for a namespace it holds only
/// READ on, with that namespace's own WRITE named.</p>
/// <p>That a single caller gets both answers is what no static descriptor resource could express,
/// and it is the whole of AD-48's per-namespace rule in evidence. The refused namespace is one the
/// instance's own enumeration carries and this principal can read -- setup seeds an entry into it
/// and grants READ on it -- so its refusal is the gate's and not the enumeration's 404, and it is
/// the WRITE half AD-48 mandates that does the refusing.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.PairsFor</method> ignore its namespace
/// -&gt; both namespaces answer 200 and the refused leg goes red, while the served leg stays
/// green.</p>
Method TestOneNamespaceIsServedAndAnotherRefusedInOneSession()
{
    Set tSC = ..Fetch(..#SERVEDUSER, ..PreparedServedNamespace, ..PreparedServedDate, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the served request completes")
    Do $$$AssertEquals(tStatus, 200, "the namespace whose pairs this principal holds is served")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus = 200 {
        Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tPage.namespace, ..PreparedServedNamespace, "with that namespace's own rows")
        Do $$$AssertTrue(tPage.rows.%Size() > 0, "and its errors: " _ tPage.rows.%Size())
    }

    Set tRefusedSC = ..Fetch(..#SERVEDUSER, ..PreparedRefusedNamespace, ..PreparedRefusedDate, .tRefusedStatus, .tRefusedBody, .tRefusedHeaders)
    Do $$$AssertStatusOK(tRefusedSC, "the refused request completes")
    Do $$$AssertEquals(tRefusedStatus, 403, "and the same principal is refused the namespace it holds nothing for")
    Do $$$AssertEquals((tRefusedBody [ "}{"), 0, "exactly one envelope")
    Set tRefusedFault = ##class(%DynamicObject).%FromJSON(tRefusedBody)
    Do $$$AssertEquals(tRefusedFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code rather than a 404")
    Do $$$AssertEquals(..FailedPairOf(tRefusedBody), ..PreparedRefusedResource _ ":WRITE", "naming that namespace's own database pair -- the WRITE this screen requires and the data's own readability does not")
}

}
