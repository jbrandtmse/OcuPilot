/// <p>The LDAP / Kerberos list's create tool (AD-54, AD-55): propose creating one LDAP or Kerberos
/// configuration. It reads the intended name fresh through the vendor's own <code>Security.LDAP</code>
/// <code>GET</code>, requires that read to answer <b>nothing</b>, composes the complete body and
/// mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b> that answers 201 on a create, so the absence
/// fingerprint is what stops a confirmed create overwriting a configuration somebody made since the
/// mint (AD-54). The vendor refuses a partial body on an absent name (#1482, measured), so the body is
/// the complete set: the arguments over a new configuration's values
/// (<method>OcuPilot.Area.Security.LdapRules.Compose</method>), whose unnamed fields are counted
/// unchanged.</p>
/// <p><b>The name is the one the instance stores</b>: a name
/// <code>Security.LDAPConfigs.FormatName</code> would store differently is refused
/// (<parameter>OcuPilot.Api.LdapError.NAMEFORM</parameter>, AD-13). The search password is
/// <class>OcuPilot.Screen.Tool.LdapPassword</class>'s write, and <code>LDAPCACertFile</code> is never
/// settable (AD-21).</p>
Class OcuPilot.Screen.Tool.LdapCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ldap.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LdapConfigList";

Parameter DESCRIPTION = "Propose creating an LDAP or Kerberos configuration on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name it with the full name the instance stores, a lower-case domain such as example.com, and give its host names, the search user's DN and the base DNs; any setting you omit takes a new configuration's own default. A Kerberos-only configuration (LDAPFlags with 128) needs no host. Its search password is set afterwards with security.ldap.password.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The vendor request type a create is issued with: <code>Security.LDAP</code>'s <code>PUT</code>,
/// which creates an absent configuration and answers 201.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated: the template's thirty less
/// <code>LDAPCACertFile</code>, as <class>OcuPilot.Screen.Tool.LdapUpdate</class> admits them.</p>
Parameter PERMITTEDFIELDS = "Description,LDAPAttributes,LDAPAttributeComment,LDAPAttributeFullName,LDAPAttributeMail,LDAPAttributeMobile,LDAPAttributeMobileProvider,LDAPAttributeNameSpace,LDAPAttributeRoutine,LDAPAttributeRoles,LDAPAttributeEscalationRoles,LDAPBaseDN,LDAPBaseDNForGroups,LDAPClientTimeout,LDAPFlags,LDAPGroupId,LDAPHostNames,LDAPInstanceId,OrganizationId,GroupId,InstanceId,RoleId,EscalationRoleId,RoutineId,NamespaceId,DelimiterId,LDAPSearchUsername,LDAPServerTimeout,LDAPUniqueDNIdentifier";

/// <p>The classic editor, whose create this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.LDAP";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.LDAP"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: the create carries no search password, so the confirm channel admits nothing (AD-6).</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p><class>OcuPilot.Screen.Tool.LdapUpdate</class>'s schema, with the identifying property
/// described for a create.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tShared = ##class(OcuPilot.Screen.Tool.LdapUpdate).InputSchema(pDescriptor)
    If $IsObject(tShared) && (tShared.%GetTypeOf("properties") = "object") {
        For tField = "LDAPFlags", "LDAPClientTimeout", "LDAPServerTimeout", "LDAPHostNames", "Description" {
            If (tProperties.%GetTypeOf(tField) = "object") && (tShared.%Get("properties").%GetTypeOf(tField) = "object") Do tProperties.%Set(tField, tShared.%Get("properties").%Get(tField))
        }
    }
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The name the new configuration will take: the full name the instance stores, a lower-case domain such as example.com. A bare name such as example is refused, and so is a name this instance already holds.", "string")
    }
    Quit tSchema
}

/// <p>The complete body (<method>OcuPilot.Area.Security.LdapRules.Compose</method>).</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.Security.LdapRules).Compose(pArgs, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The editor's own rules (AD-55): the name's
/// (<method>OcuPilot.Area.Security.LdapRules.NameViolation</method>), then every rule over the
/// complete body the create composes, each broken rule as its field and published sentence. The
/// name's look-up is the mint's absence read, not this.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Security.LdapRules"
    Kill tViolations
    Set tViolations = 0
    Set tSC = $ClassMethod(tRules, "NameViolation", pIdValue, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations = 0 {
        Set tSC = $ClassMethod(tRules, "Compose", pArgs, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit tSC
        Set tSC = $ClassMethod(tRules, "Validate", pIdValue, tPayload, "", .tViolations)
        If $$$ISERR(tSC) Quit tSC
    }
    Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and the custom
/// resource of the <parameter>CLASSICPAGES</parameter> page, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
