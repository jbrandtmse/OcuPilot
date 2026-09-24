/// <p>The Web applications list's write tool (AD-6, AD-10): propose a change to one web
/// application's configuration. It reads the application fresh through the vendor's own
/// <code>WebApp.App</code> <code>GET</code>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration.</p>
/// <p><b>It admits twenty-five of the forty-five ordinary top-level fields its classified field list
/// carries</b> (<parameter>PERMITTEDFIELDS</parameter>) and the application roles
/// (<parameter>MATCHROLESARGUMENT</parameter>), which are exactly the ones
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> has reviewed. Every
/// other field is absent from the tool set, so the model cannot author it, and a change to it is
/// refused at the write whatever the caller. <code>Path</code> and <code>WSGIAppLocation</code> are
/// among the absent ones: no caller names a filesystem path (AD-21).</p>
/// <p><b>On OcuPilot's own applications every change is refused</b> (AD-10). On any other
/// application, a change that makes it reachable without signing in, drops its resource or changes
/// which code answers at its address is permitted and confirmed as a delete is: the mint marks the
/// proposal destructive and names the effect
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>), as it does a privileged
/// application role (<method>Consequence</method>).</p>
/// <p><b>It is also the web application editor's Save</b> (AD-55,
/// <class>OcuPilot.Area.WebApp.WebAppSave</class>), over the twenty-five alone: application roles
/// change only through the four role actions' delta (AD-56 (ii), <method>ScreenActionDelta</method>).
/// Both callers apply one rule set, <method>OcuPilot.Area.WebApp.Create.Validate</method> in update
/// mode (<method>ArgumentProblem</method>).</p>
Class OcuPilot.Screen.Tool.WebAppUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.list.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DESCRIPTION = "Propose a change to one web application's configuration on this instance: its description, namespace, whether it is enabled and the namespace default, its dispatch class, CSP package and superclass, Python application, callable and protocol, its resource, group, authentication methods, session timeout, JWT and CORS settings, how it serves files, and its application and matching roles. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the web applications list reports it, and send only the fields to change. Changes to OcuPilot's own web applications are refused.";

/// <p>The derived subtree this tool never admits as a derived field: a web application's
/// application and matching roles, which <parameter>MATCHROLESARGUMENT</parameter> authors
/// instead.</p>
Parameter EXCLUDEDFIELD = "MatchRoles";

/// <p>The one authored argument: the application's roles, each entry
/// <code>{MatchRole, TargetRoles}</code>, the vendor's own shape and the complete list after the
/// change. An entry whose <code>MatchRole</code> is empty grants its <code>TargetRoles</code> to
/// every request the application serves.</p>
Parameter MATCHROLESARGUMENT = "MatchRoles";

/// <p>The only derived top-level fields this tool admits, comma-separated: the web-application
/// settings whose change AD-10's prohibited set has reviewed
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names these and
/// <parameter>MATCHROLESARGUMENT</parameter>). A test asserts the two agree; the kernel is never read
/// from here.</p>
Parameter PERMITTEDFIELDS = "AutheEnabled,AutoCompile,CorsAllowlist,CorsCredentialsAllowed,CorsHeadersList,Description,DispatchClass,Enabled,GroupById,IsNameSpaceDefault,JWTAccessTokenTimeout,JWTAuthEnabled,JWTRefreshTokenTimeout,LockCSPName,NameSpace,Package,Recurse,Resource,ServeFiles,ServeFilesTimeout,SuperClass,Timeout,WSGIAppName,WSGICallable,WSGIType";

/// <p>The row actions this tool carries out (AD-5, AD-53). Enable and disable set
/// <code>Enabled</code>; the four role actions take their roles as declared values
/// (<parameter>SCREENVALUES</parameter>) and change <code>MatchRoles</code> by a delta over the fresh
/// read (<method>ScreenActionDelta</method>).</p>
Parameter SCREENACTIONS = "enable=Enabled:true,disable=Enabled:false,add-application-role,remove-application-role,add-matching-role,remove-matching-role";

/// <p>The values each role action admits: an application role names the role alone; a matching role
/// names the role a caller must hold and the role it then receives.</p>
Parameter SCREENVALUES = "add-application-role=Role,remove-application-role=Role,add-matching-role=MatchRole:Role,remove-matching-role=MatchRole:Role";

/// <p>The role actions' value names.</p>
Parameter ROLEVALUE = "Role";

Parameter MATCHROLEVALUE = "MatchRole";

/// <p>The endpoint a role named in an add is resolved against, on this tool's own port.</p>
Parameter ROLEENDPOINT = "Security.Role";

/// <p>The two members of one <parameter>MATCHROLESARGUMENT</parameter> entry.</p>
Parameter ENTRYMATCH = "MatchRole";

Parameter ENTRYTARGETS = "TargetRoles";

/// <p>The pair a change to a web application requires: <code>%Admin_Secure:USE</code>, which is
/// exactly what <method>%CSP.Portal.Application.CheckSecurity</method> checks before the classic
/// editor saves, and exactly the pair
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> already declares for its own read (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

/// <p>The field names the merge may set: every <code>ordinary</code> top-level literal of this
/// tool's own field-list entry that <method>PermittedFields</method> admits, derived rather than
/// transcribed (AD-3), plus <parameter>MATCHROLESARGUMENT</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#MATCHROLESARGUMENT)
}

/// <p><parameter>EXCLUDEDFIELD</parameter>, so the derived role subtree never reaches the
/// schema as a derived field.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild(..#EXCLUDEDFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed is
/// absent from the schema and from <method>SettableFields</method> whether or not anyone has
/// thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with each setting described (<method>Described</method>) and
/// <parameter>MATCHROLESARGUMENT</parameter> added as an array of <code>{MatchRole, TargetRoles}</code>
/// entries, whose shape <method>ArgumentProblem</method> refuses, because the schema subset a
/// provider is sent describes no member below a property.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tEntry = {"type": "object", "description": "One entry, an object with exactly two members: MatchRole, empty to grant the target roles to every request the application serves or a role a caller must hold to receive them, and TargetRoles, an array of role names as this instance's own roles list reports them."}
    Set tRoles = {"type": "array", "description": "The application's roles after the change, replacing the whole list, so an entry left out is removed. Granting %All, or a role that carries an administrative privilege, is proposable and is confirmed as a delete is. Application roles are refused on OcuPilot's own web applications."}
    Do tRoles.%Set("items", tEntry)
    Do tSchema.%Get("properties").%Set(..#MATCHROLESARGUMENT, tRoles)
    Quit ..Described(tSchema)
}

/// <p><var>pSchema</var> with each of the twenty-five settings described, the semantic half AD-3 has
/// authored once per tool. The mask and the four timeouts are typed integers, because the instance
/// reads and stores them as numbers whatever the template's placeholder says, and the two
/// choice-valued settings carry their enums: <code>ServeFiles</code>'s display list as
/// <property>Security.Applications.ServeFiles</property> publishes it, and <code>WSGIType</code>'s
/// two protocols.</p>
ClassMethod Described(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tEffect = " Confirmed as a delete is, and refused on OcuPilot's own web applications."
    Set tDescriptions("AutheEnabled") = "The authentication methods, as the whole number this instance stores them as: add 32 for password, 64 for unauthenticated, 4 for Kerberos, 2048 for LDAP, 8192 for delegated and 16384 for a login cookie. Send the number the application holds now with only the bits to change. Adding 64 makes the application reachable without signing in." _ tEffect
    Set tDescriptions("AutoCompile") = "Whether CSP pages are compiled automatically when their source changes."
    Set tDescriptions("CorsAllowlist") = "The origins allowed to make cross-origin requests to the application, replacing the whole list; an empty list allows none."
    Set tDescriptions("CorsCredentialsAllowed") = "Whether a cross-origin request may carry credentials."
    Set tDescriptions("CorsHeadersList") = "The request headers a cross-origin request may carry, replacing the whole list."
    Set tDescriptions("Description") = "A description of the application, at most 256 characters."
    Set tDescriptions("DispatchClass") = "The %CSP.REST class that answers every request, which makes the application a REST application, or an empty string for none. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("Enabled") = "Whether the application answers requests."
    Set tDescriptions("GroupById") = "The group whose applications share one sign-in, at most 64 characters, or an empty string for none."
    Set tDescriptions("IsNameSpaceDefault") = "Whether this is the namespace's default application."
    Set tDescriptions("JWTAccessTokenTimeout") = "How long a JWT access token lasts, in seconds."
    Set tDescriptions("JWTAuthEnabled") = "Whether the application accepts JWT authentication."
    Set tDescriptions("JWTRefreshTokenTimeout") = "How long a JWT refresh token lasts, in seconds."
    Set tDescriptions("LockCSPName") = "Whether a CSP page is served only from this application's own path."
    Set tDescriptions("NameSpace") = "The namespace the application runs in, exactly as this instance names it. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("Package") = "The package name prefix of the CSP classes the application serves, at most 64 characters, or an empty string for none. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("Recurse") = "Whether the application also serves its subdirectories."
    Set tDescriptions("Resource") = "The resource a caller must hold to use the application, or an empty string for none. Clearing a resource the application holds lets anyone who can sign in use it." _ tEffect
    Set tDescriptions("ServeFiles") = "How the application serves static files."
    Set tDescriptions("ServeFilesTimeout") = "How long a browser may cache a static file, in seconds."
    Set tDescriptions("SuperClass") = "The superclass of the CSP pages the application compiles, or an empty string for the default. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("Timeout") = "How long an idle session lasts, in seconds."
    Set tDescriptions("WSGIAppName") = "For a Python application: the name of its application file, without the .py extension. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("WSGICallable") = "For a Python application: the name of the callable in its application file. Changing it changes which code answers at the application's address." _ tEffect
    Set tDescriptions("WSGIType") = "For a Python application: its protocol."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    For tField = "AutheEnabled", "Timeout", "ServeFilesTimeout", "JWTAccessTokenTimeout", "JWTRefreshTokenTimeout" {
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Do tProperties.%Get(tField).%Set("type", "integer", "string")
        Do tProperties.%Get(tField).%Set("minimum", 0, "number")
    }
    For tPair = $ListBuild("ServeFiles", ##class(OcuPilot.Area.WebApp.FormRules).#SERVEFILESCHOICES), $ListBuild("WSGIType", ##class(OcuPilot.Area.WebApp.FormRules).#WSGITYPES) {
        Set tField = $List(tPair, 1)
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Set tValues = []
        For tI = 1:1:$Length($List(tPair, 2), ",") Do tValues.%Push($Piece($List(tPair, 2), ",", tI))
        Do tProperties.%Get(tField).%Set("enum", tValues)
    }
    Quit pSchema
}

/// <p>The kernel-owned consequence code this change's payload <var>pPayload</var> carries, or
/// <code>""</code>: the create's own combined code
/// (<method>OcuPilot.Screen.Tool.WebAppCreate.Consequence</method>) when the mint found the change
/// granting privilege (<var>pPrivileged</var>), which names an application that is, or is being
/// made, unauthenticated with one line. Otherwise <code>""</code>, and the mint falls back to
/// <code>GRANT.PRIVILEGED</code> or to <var>pEffect</var>, the weakening effect
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> ordered.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If 'pPrivileged Quit ""
    Quit ##class(OcuPilot.Screen.Tool.WebAppCreate).Consequence(pPayload, 1)
}

/// <p>The editor's own rules (<method>OcuPilot.Area.WebApp.Create.Validate</method>, update mode)
/// over the agent's arguments, read against this tool's own fresh read of <var>pIdValue</var>, each
/// broken rule as its field and published sentence (AD-55). An application the read no longer
/// finds has every supplied field checked; the mint has already refused one that was absent when it
/// read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.WebApp.Create"
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tChanged = $ClassMethod(tRules, "Changed", pArgs, tFresh, ..IdArgument())
    Set tSC = $ClassMethod(tRules, "Validate", pIdValue, tChanged, .tViolations, 0, "update", tFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once. The
/// pairs are checked against the caller's current grants by the dispatcher before this tool runs,
/// and again at the write (AD-8, AD-40).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The arguments a screen action sends (AD-56 (ii)): for the four role actions, the complete
/// <parameter>MATCHROLESARGUMENT</parameter> list built from the fresh read <var>pFresh</var> with
/// one target role added to, or removed from, one entry -- the entry whose <code>MatchRole</code> is
/// empty for an application role, the entry naming <parameter>MATCHROLEVALUE</parameter> for a
/// matching role. An add creates the entry it needs and a remove that empties one drops it, so an
/// entry another session changed after the editor loaded is kept. Every other action answers its
/// static argument.</p>
/// <p>Roles are matched case-insensitively, as the instance resolves a role name, and a held role
/// keeps the instance's own spelling. Refused in <var>pProblem</var>: an empty value, adding a role
/// the entry already holds, removing one it does not, and adding a name the
/// <parameter>ROLEENDPOINT</parameter> read, through this tool's own port, answers 404 for. Whether
/// the grant is privileged, or refused on one of OcuPilot's own applications, is the prohibited
/// set's question at the write, never this method's. No problem sentence names a role, so a refused
/// request echoes no value.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tAdd = ((pActionId = "add-application-role") || (pActionId = "add-matching-role"))
        Set tRemove = ((pActionId = "remove-application-role") || (pActionId = "remove-matching-role"))
        If 'tAdd && 'tRemove {
            Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        Set pArgs = {}
        Set tMatching = ((pActionId = "add-matching-role") || (pActionId = "remove-matching-role"))
        Set tRole = ""
        Set tMatch = ""
        If $IsObject(pValues) {
            Set tRole = $ZStrip(pValues.%Get(..#ROLEVALUE), "<>W")
            If tMatching Set tMatch = $ZStrip(pValues.%Get(..#MATCHROLEVALUE), "<>W")
        }
        If tRole = "" {
            Set pProblem = "'" _ ..#ROLEVALUE _ "' names the role and cannot be empty"
            Quit
        }
        If tMatching && (tMatch = "") {
            Set pProblem = "'" _ ..#MATCHROLEVALUE _ "' names the role a caller must hold and cannot be empty"
            Quit
        }
        Set tWanted = $ZConvert(tRole, "U")
        Set tWantedMatch = $ZConvert(tMatch, "U")
        Set tEntries = []
        Set tHeld = 0
        Set tFound = 0
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#MATCHROLESARGUMENT) = "array") {
            Set tIterator = pFresh.%Get(..#MATCHROLESARGUMENT).%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Continue
                Set tEntryMatch = $Select(tEntry.%GetTypeOf(..#ENTRYMATCH) = "string": tEntry.%Get(..#ENTRYMATCH), 1: "")
                Set tTargets = []
                If tEntry.%GetTypeOf(..#ENTRYTARGETS) = "array" {
                    Set tTargetIterator = tEntry.%Get(..#ENTRYTARGETS).%GetIterator()
                    While tTargetIterator.%GetNext(.tTargetIndex, .tOne) {
                        If $IsObject(tOne) || (tOne = "") Continue
                        Do tTargets.%Push(tOne)
                    }
                }
                If ('tFound) && ($ZConvert(tEntryMatch, "U") = tWantedMatch) {
                    Set tFound = 1
                    Set tKept = []
                    Set tTargetIterator = tTargets.%GetIterator()
                    While tTargetIterator.%GetNext(.tTargetIndex, .tOne) {
                        If $ZConvert(tOne, "U") = tWanted {
                            Set tHeld = 1
                            If tRemove Continue
                        }
                        Do tKept.%Push(tOne)
                    }
                    If tAdd && 'tHeld Do tKept.%Push(tRole)
                    Set tTargets = tKept
                }
                If tTargets.%Size() = 0 Continue
                Set tOut = {}
                Do tOut.%Set(..#ENTRYMATCH, tEntryMatch, "string")
                Do tOut.%Set(..#ENTRYTARGETS, tTargets)
                Do tEntries.%Push(tOut)
            }
        }
        If tRemove {
            If 'tHeld Set pProblem = "the application does not grant that role there"
            If pProblem '= "" Quit
        } Else {
            If tHeld {
                Set pProblem = "the application already grants that role there"
                Quit
            }
            For tName = tRole, tMatch {
                If tName = "" Continue
                Kill tQuery
                Set tQuery("name") = tName
                Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ..#ROLEENDPOINT, "GET", .tQuery, "", .tRoleObject, .tHttp, .tFault)
                If $$$ISERR(tReadSC) {
                    If +$Get(tHttp) = 404 {
                        Set pProblem = "this instance holds no role by that name"
                        Quit
                    }
                    Set tSC = tReadSC
                    Quit
                }
            }
            If (pProblem '= "") || $$$ISERR(tSC) Quit
            If 'tFound {
                Set tOut = {}
                Do tOut.%Set(..#ENTRYMATCH, tMatch, "string")
                Do tOut.%Set(..#ENTRYTARGETS, [(tRole)])
                Do tEntries.%Push(tOut)
            }
        }
        Do pArgs.%Set(..#MATCHROLESARGUMENT, tEntries)
    } Catch ex {
        Set pArgs = {}
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
