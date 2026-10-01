/// <p>The LDAP / Kerberos list's change tool (AD-4, AD-6, AD-10, AD-55): propose a change to one LDAP
/// configuration. It reads the configuration fresh through the vendor's own <code>Security.LDAP</code>
/// <code>GET</code>, merges the arguments over that object, and mints a proposal the user confirms.
/// It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's thirty keys with the changed ones applied,
/// so a field the arguments omit keeps the instance's value. The vendor's <code>PUT</code> creates
/// an absent configuration, so the fingerprint re-read is what refuses a configuration deleted since
/// the mint (AD-4, AD-6). <code>LDAPCACertFile</code> is sent back as read and never settable
/// (AD-21). The template carries no search password and the read answers none, so nothing here is
/// secret: the password is <class>OcuPilot.Screen.Tool.LdapPassword</class>'s write.</p>
/// <p>Its rules are <class>OcuPilot.Area.Security.LdapRules</class>'s, shared with the editor's Save
/// (AD-55); its merge fills a Kerberos-only configuration's empty host and search user with the
/// classic page's values (<method>OcuPilot.Area.Security.LdapRules.KerberosFilled</method>), and it
/// performs the classic editor's Save (<parameter>CLASSICPAGES</parameter>, AD-44).</p>
Class OcuPilot.Screen.Tool.LdapUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ldap.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LdapConfigList";

Parameter DESCRIPTION = "Propose a change to one LDAP configuration on this instance: its description, whether it is enabled (LDAPFlags bit 64), its host names, how users are searched for, the attributes and groups it reads, or its timeouts. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration exactly as the LDAP / Kerberos list reports it, and send only the settings to change. Its search password is security.ldap.password's; its TLS certificate file is set on the classic portal.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated: the template's thirty less
/// <code>LDAPCACertFile</code> (<method>OcuPilot.Kernel.Proposal.Prohibited.LdapFields</method> names
/// the same twenty-nine). A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,LDAPAttributes,LDAPAttributeComment,LDAPAttributeFullName,LDAPAttributeMail,LDAPAttributeMobile,LDAPAttributeMobileProvider,LDAPAttributeNameSpace,LDAPAttributeRoutine,LDAPAttributeRoles,LDAPAttributeEscalationRoles,LDAPBaseDN,LDAPBaseDNForGroups,LDAPClientTimeout,LDAPFlags,LDAPGroupId,LDAPHostNames,LDAPInstanceId,OrganizationId,GroupId,InstanceId,RoleId,EscalationRoleId,RoutineId,NamespaceId,DelimiterId,LDAPSearchUsername,LDAPServerTimeout,LDAPUniqueDNIdentifier";

/// <p>The classic editor whose Save this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.LDAP";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.LDAP"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: the edit carries no search password, so the confirm channel admits nothing (AD-6).</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema with the numbers and lists typed as the vendor's read answers them and the
/// daily fields described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("LDAPFlags") = "object" {
        Do tProperties.%Set("LDAPFlags", {"type": "integer", "description": "The configuration's flags, a whole number from 0 to 255: 1 Active Directory, 2 TLS, 4 allow the ISC_LDAP_CONFIGURATION environment variable, 8 use groups, 16 nested groups, 32 universal groups, 64 enabled, 128 Kerberos only. 64 and 128 together are refused. Send the whole value with every bit it keeps."})
    }
    For tField = "LDAPClientTimeout", "LDAPServerTimeout" {
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Do tProperties.%Set(tField, {"type": "integer", "description": "A timeout in seconds, a whole number."})
    }
    If tProperties.%GetTypeOf("LDAPHostNames") = "object" {
        Do tProperties.%Set("LDAPHostNames", {"type": "array", "items": {"type": "string"}, "description": "The LDAP server host names, replacing the whole list; each one name, optionally followed by :port, with no spaces."})
    }
    If tProperties.%GetTypeOf("Description") = "object" {
        Do tProperties.%Set("Description", {"type": "string", "maxLength": 128, "description": "What the configuration is for, at most 128 characters."})
    }
    Quit tSchema
}

/// <p>The form's own rules over the fields the arguments change, read against this tool's own fresh
/// read of <var>pIdValue</var> (<method>OcuPilot.Area.Security.LdapRules.Validate</method>), after the
/// name's own rule (<method>OcuPilot.Area.Security.LdapRules.NameViolation</method>), each broken
/// rule as its field and published sentence (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Security.LdapRules"
    Kill tViolations
    Set tViolations = 0
    Set tSC = $ClassMethod(tRules, "NameViolation", pIdValue, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations > 0 {
        Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
        Quit $$$OK
    }
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tChanged = $ClassMethod(tRules, "Changed", $ClassMethod(tRules, "KerberosFilled", pArgs, tFresh), tFresh)
    Set tSC = $ClassMethod(tRules, "Validate", pIdValue, tChanged, tFresh, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The name's own rule asked again at the agent's confirm (AD-6, AD-13): a stored name that
/// is gone by then can find another configuration by its short form, which the fingerprint's re-read
/// does not tell apart.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tViolations
    Set tViolations = 0
    Set tSC = ##class(OcuPilot.Area.Security.LdapRules).NameViolation(pIdValue, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.LdapRules).Problem(.tViolations)
    Quit $$$OK
}

/// <p>The kernel's merge over <var>pArgs</var> with a Kerberos-only configuration's empty host and
/// search user filled (<method>OcuPilot.Area.Security.LdapRules.KerberosFilled</method>), so the
/// mint, the confirm's re-merge and the Save take one payload and the diff shows what is sent.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tArgs = ##class(OcuPilot.Area.Security.LdapRules).KerberosFilled(pArgs, pFresh)
    Quit ##super(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
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
