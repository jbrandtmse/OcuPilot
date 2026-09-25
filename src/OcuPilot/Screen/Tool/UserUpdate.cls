/// <p>The Users list's write tool (AD-6, AD-10): propose a change to one account on this instance.
/// It reads the account fresh through the vendor's own <code>Security.User</code> <code>GET</code>,
/// merges the arguments over that object, and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration.</p>
/// <p><b>It is also the Users list's merge write for five row actions</b> (AD-53,
/// <parameter>SCREENACTIONS</parameter>): enable, disable, the change-on-login flag the
/// set-password dialog sends before and after the password (AD-56), and adding or removing one role, which
/// <method>ScreenActionDelta</method> computes over the fresh read.</p>
/// <p><b>It admits fifteen of the sixteen fields its classified field list carries:</b> the classic
/// General tab's fourteen derived literals <parameter>PERMITTEDFIELDS</parameter> names, and
/// <code>Roles</code>, which is authored here rather than derived. <code>EscalationRoles</code> is
/// absent from the schema, so the model cannot author it, and a change to it is refused at the
/// write by <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the caller.</p>
/// <p><b>It is also the user editor's Save</b> (AD-55, <class>OcuPilot.Area.Permissions.UserSave</class>),
/// over the fourteen alone: roles change only by the role actions' delta (AD-56 (ii)). Both callers
/// apply the one rule set, <method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method> in
/// update mode (<method>ArgumentProblem</method>).</p>
/// <p><b>Why <code>Roles</code> is authored and not derived</b> (AD-3). The endpoint's template
/// answers <code>[]</code> for both of its arrays, so the derivation types no member and
/// <class>OcuPilot.Screen.Tool.Classification</class> can only call them <code>opaque</code> --
/// AD-3 names this endpoint's empty <code>Roles</code> as its own <code>opaque</code> example, and
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> admits literals alone. Teaching the
/// derivation to type an empty array would invent information the template does not carry, so the
/// element type and the description are written here once, reviewed, which is the authored half
/// AD-3 already sanctions for this same endpoint.</p>
/// <p><b><code>EscalationRoles</code> is excluded as well as unadvertised</b>, because every change
/// to it is prohibited by a predicate of its own: escalation roles grant privilege through a path
/// (AD-10). The reviewed classification calls it <code>opaque</code>, so the schema would refuse it
/// on that ground too; the exclusion is stated here because this is where a reader of the tool looks
/// for it.</p>
Class OcuPilot.Screen.Tool.UserUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose a change to one user account on this instance: any of its general settings -- full name, comment, whether it is enabled, whether it must choose a new password at its next sign-in, password and account expiry, startup namespace and routine, email, mobile phone and two-factor sign-in -- and which roles it holds. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the account exactly as the users list reports it, and send only the fields to change.";

/// <p>The derived top-level fields this tool admits, comma-separated: the
/// <code>Security.User</code> settings whose change AD-10's prohibited set has reviewed and which
/// the derivation types (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// names these and <parameter>ROLESARGUMENT</parameter>). A test asserts the two agree; the kernel
/// is never read from here.</p>
Parameter PERMITTEDFIELDS = "AccountNeverExpires,AutheEnabled,ChangePassword,Comment,EmailAddress,Enabled,ExpirationDate,FullName,HOTPKeyDisplay,NameSpace,PasswordNeverExpires,PhoneNumber,PhoneProvider,Routine";

/// <p>The Users list's row actions this merge write carries out (AD-53). Enable and disable set
/// <code>Enabled</code>; <code>require-password-change</code> sets <code>ChangePassword</code> and is
/// declared so the route admits it, though no menu draws it -- the set-password dialog sends it
/// before and after the password when its flag is checked (AD-56); the two role actions take their role as a declared value
/// (<parameter>SCREENVALUES</parameter>).</p>
Parameter SCREENACTIONS = "enable=Enabled:true,disable=Enabled:false,require-password-change=ChangePassword:true,add-role,remove-role";

/// <p>The one value each role action admits: the role, applied as a delta
/// (<method>ScreenActionDelta</method>).</p>
Parameter SCREENVALUES = "add-role=Role,remove-role=Role";

/// <p>The role actions' value name.</p>
Parameter ROLEVALUE = "Role";

/// <p>The endpoint a role named in an add is resolved against.</p>
Parameter ROLEENDPOINT = "Security.Role";

/// <p>The one authored argument, and the other field the prohibited set has reviewed: the complete
/// replacement list of roles the account holds.</p>
Parameter ROLESARGUMENT = "Roles";

/// <p>The subtree AD-10 forbids: an account's escalation roles.</p>
Parameter EXCLUDEDFIELD = "EscalationRoles";

/// <p>The pair a change to an account requires: <code>%Admin_Secure:USE</code>, which is the
/// vendor endpoint's own <code>ResourcesOR()</code> resource and the classic Users page's resource,
/// and exactly the pair <class>OcuPilot.Screen.Descriptor.UserList</class> already declares for its
/// own read. So the resolved set is the screen's two pairs and nothing else, which is what makes
/// "the same 403 the editor would give" true by construction; no permission an IRIS-shipped role
/// does not grant appears on the path (AD-8 as amended 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.User"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level literals of this
/// tool's own field-list entry (AD-3), plus <parameter>ROLESARGUMENT</parameter>, the one array the
/// derivation cannot type and this tool authors.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#ROLESARGUMENT)
}

/// <p><parameter>EXCLUDEDFIELD</parameter>, so no path of this tool admits an escalation-role
/// grant.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild(..#EXCLUDEDFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a derived field the prohibited set has not
/// reviewed is absent from the schema and from <method>SettableFields</method> whether or not anyone
/// has thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with this tool's one authored argument added (AD-3):
/// <parameter>ROLESARGUMENT</parameter> as an array of role names, replacing the whole list; and
/// each derived field described (<method>Described</method>).</p>
/// <p>The property is added rather than emitted by <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// because its element type is not in the template -- see the class header. The schema stays closed
/// with <code>additionalProperties: false</code>, so <code>EscalationRoles</code> and every other
/// unadvertised key is refused as an unknown argument.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tRoles = {"type": "array", "description": "The complete list of roles this account is to hold after the change, each named exactly as this instance's own roles list reports it. It replaces the account's current roles rather than adding to them, so a role left out is a role removed. Adding a role that grants %All or an administrative privilege -- by name, through another role, or as a resource it carries -- is permitted: the proposal is marked destructive and names the privilege it grants, and the user confirms it on the card."}
    Do tRoles.%Set("items", {"type": "string"})
    Do tSchema.%Get("properties").%Set(..#ROLESARGUMENT, tRoles)
    Quit ..Described(tSchema)
}

/// <p><var>pSchema</var> with each of the fourteen settings described, the semantic half AD-3 has
/// authored once per tool. <code>AutheEnabled</code> is typed an integer: the instance reads and
/// stores it as a number, whatever the template's placeholder says.</p>
ClassMethod Described(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tDescriptions("AccountNeverExpires") = "Whether the account never expires, whatever its expiration date says."
    Set tDescriptions("AutheEnabled") = "How the account signs in, as the whole number this instance stores it as. Only the two two-factor bits may change: add 1048576 to turn on SMS text codes or 2097152 to turn on a time-based one-time password, and never both. Send the number the account holds now with only those bits changed."
    Set tDescriptions("ChangePassword") = "Whether the account must choose a new password at its next sign-in."
    Set tDescriptions("Comment") = "A free-text comment on the account, or an empty string for none."
    Set tDescriptions("EmailAddress") = "The account's email address, or an empty string for none."
    Set tDescriptions("Enabled") = "Whether the account may sign in."
    Set tDescriptions("ExpirationDate") = "The date the account expires, written YYYY-MM-DD, or an empty string for none."
    Set tDescriptions("FullName") = "The person's full name."
    Set tDescriptions("HOTPKeyDisplay") = "Whether the account is shown its time-based one-time password QR code at its next sign-in. It applies only while that two-factor method is on."
    Set tDescriptions("NameSpace") = "The namespace the account starts in, exactly as this instance names it, or an empty string for the default."
    Set tDescriptions("PasswordNeverExpires") = "Whether the account's password never expires."
    Set tDescriptions("PhoneNumber") = "The mobile phone number two-factor SMS text codes are sent to, or an empty string for none."
    Set tDescriptions("PhoneProvider") = "The mobile phone service provider two-factor SMS text codes are sent through, as this instance names it, or an empty string for none."
    Set tDescriptions("Routine") = "The tag^routine the account starts in, which needs a startup namespace, or an empty string for none."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("AutheEnabled") = "object" Do tProperties.%Get("AutheEnabled").%Set("type", "integer", "string")
    Quit pSchema
}

/// <p>The editor's own rules (<method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method>,
/// update mode) over the fields the agent's arguments change, read against this tool's own fresh
/// read of <var>pIdValue</var>, each broken rule as its field and published sentence (AD-55). An
/// account the read no longer finds has every supplied field checked; the mint has already refused
/// one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Permissions.UserCreateRules"
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tSC = $ClassMethod(tRules, "Validate", pIdValue, $ClassMethod(tRules, "Changed", pArgs, tFresh), .tViolations, 0, 0, "update", tFresh)
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
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>. The pairs are
/// checked against the caller's current grants by the dispatcher before this tool runs, and again
/// at the write (AD-8, AD-40).</p>
/// <p><b>Each pair once.</b> The write's own pair is one the screen already declares, so appending
/// it unconditionally would put <code>%Admin_Secure:USE</code> in the resolved set twice and the
/// ledger row's pair column would record one check as two.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The arguments a screen action sends (AD-56 (ii)): for <code>add-role</code> and
/// <code>remove-role</code>, the complete <code>Roles</code> list built from the fresh read
/// <var>pFresh</var> plus or minus the one role <var>pValues</var> names, so a role another session
/// added after the list loaded is kept; for every other action, the static argument.</p>
/// <p>The role is matched case-insensitively, as the instance resolves a role name, and a held role
/// keeps the instance's own spelling. Refused in <var>pProblem</var>: an empty role, adding a role
/// the account already holds, removing one it does not, and adding a name the
/// <parameter>ROLEENDPOINT</parameter> read, through this tool's own port, answers 404 for. Whether
/// the add grants privilege, or the removal strips <code>%All</code> from a protected account, is the
/// prohibited set's question at the write, never this method's. No problem sentence names the
/// role, so a refused request echoes no value (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If (pActionId '= "add-role") && (pActionId '= "remove-role") {
            Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        Set pArgs = {}
        Set tRole = ""
        If $IsObject(pValues) Set tRole = pValues.%Get(..#ROLEVALUE)
        If $ZStrip(tRole, "<>W") = "" {
            Set pProblem = "'" _ ..#ROLEVALUE _ "' names the role and cannot be empty"
            Quit
        }
        Set tWanted = $ZConvert(tRole, "U")
        Set tRoles = []
        Set tHeld = 0
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#ROLESARGUMENT) = "array") {
            Set tIterator = pFresh.%Get(..#ROLESARGUMENT).%GetIterator()
            While tIterator.%GetNext(.tIndex, .tOne) {
                If $IsObject(tOne) || (tOne = "") Continue
                If $ZConvert(tOne, "U") = tWanted {
                    Set tHeld = 1
                    If pActionId = "remove-role" Continue
                }
                Do tRoles.%Push(tOne)
            }
        }
        If pActionId = "remove-role" {
            If 'tHeld Set pProblem = "the account does not hold that role"
        } Else {
            If tHeld {
                Set pProblem = "the account already holds that role"
                Quit
            }
            Kill tQuery
            Set tQuery("name") = tRole
            Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ..#ROLEENDPOINT, "GET", .tQuery, "", .tRoleObject, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                If +$Get(tHttp) = 404 {
                    Set pProblem = "this instance holds no role by that name"
                    Quit
                }
                Set tSC = tReadSC
                Quit
            }
            Do tRoles.%Push(tRole)
        }
        If pProblem '= "" Quit
        Do pArgs.%Set(..#ROLESARGUMENT, tRoles)
    } Catch ex {
        Set pArgs = {}
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
