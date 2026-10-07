/// <p>The authentication and web session options' edit (Story 18.8, AD-4, AD-6, AD-52, AD-55): propose a
/// change to the methods this instance accepts, the login cookies, two-factor authentication or the JWT
/// settings. It reads the options fresh through <class>OcuPilot.Port.AdminPort</class>, merges the
/// arguments over that object and mints a proposal the user confirms; the screen's Save
/// (<class>OcuPilot.Area.Security.AuthOptionsSave</class>) is its second caller. It writes nothing.</p>
/// <p><b>A merge write over the singleton</b> (AD-13): the body is the fresh read's twenty-one settings
/// with the change applied, <b>less an unchanged <code>AutheKB</code></b> (AD-4's named exception): sending
/// it true sets all seven Kerberos bits, which adds one a stock instance leaves off. The SMTP password is
/// never one of them: it travels only through
/// <class>OcuPilot.Screen.Tool.AuthOptionsSmtpPassword</class>.</p>
/// <p><b>Every rule is decided before the port is touched</b>
/// (<class>OcuPilot.Area.Security.AuthOptionsRules</class>), on both callers, over the payload the merge
/// would send. A change that leaves OcuPilot's own sign-in without a method, or turns O/S authentication
/// off, is refused by the prohibited set. A changed <code>JWTIssuer</code> or <code>JWTSigAlg</code> is
/// permitted and carries <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTTOKENSIGNOUT</parameter>: every token session
/// ends.</p>
/// <p><b>Its pairs</b> are Authentication options' own, which a principal holding exactly them proved
/// sufficient for the read and the write (AD-8, measured at Task 0). The descriptor's own classic page
/// performs the save, so it names no other (AD-44).</p>
Class OcuPilot.Screen.Tool.AuthOptionsUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.authoptions.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuthOptions";

Parameter DESCRIPTION = "Propose a change to this instance's authentication and web session options: which authentication methods it allows, the login cookie and its expire time, two-factor authentication with its SMTP server, and the JWT issuer and signature algorithm. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the name and only the options to change. A change that would leave OcuPilot's own sign-in with no method, or turn O/S authentication off, is refused. Changing the JWT issuer or signature algorithm ends every token session. The SMTP password is never an argument of this tool.";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The twenty-one fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "AutheUnauthenticated,AutheOS,AutheOSDelegated,AutheOSLDAP,AutheCache,AutheDelegated,AutheAlwaysTryDelegated,AutheKB,AutheLDAP,AutheLDAPCache,AutheOAuth2,AutheLoginToken,AutheTwoFactorSMS,AutheTwoFactorPW,LoginCookieTimeout,SMTPServer,SMTPUsername,TwoFactorFrom,TwoFactorTimeout,JWTIssuer,JWTSigAlg";

/// <p>The pair this tool requires beyond Authentication options' own: none, and the declaration keeps the
/// idiom of every tool of the area (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.AuthOptionsRules";

/// <p>The flag the vendor's <code>PUT</code> expands to seven bits, which the merge sends only when it
/// changes.</p>
Parameter KERBEROSFIELD = "AutheKB";

ClassMethod Endpoint() As %String
{
    Quit "Security.WebAuth"
}

/// <p>The twenty-one admitted fields, from the generated field list (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the target named as the singleton's literal id and the two JWT settings
/// described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions(..IdArgument()) = "Send the literal 'SYSTEM': the instance has one set of authentication options."
    Set tDescriptions("LoginCookieTimeout") = "Seconds a login cookie lives: a whole number, 0 or more; 0 makes it a session cookie."
    Set tDescriptions("TwoFactorTimeout") = "Seconds a two-factor code is valid: a whole number, 0 or more."
    Set tDescriptions("JWTIssuer") = "The JWT issuer, at most 1,024 characters. Changing it ends every token session."
    Set tDescriptions("JWTSigAlg") = "The JWT signature algorithm: RS256, RS384, RS512, ES256, ES384 or ES512. Changing it ends every token session and replaces the instance's signing keys."
    Set tDescriptions("AutheTwoFactorSMS") = "Needs SMTPServer and TwoFactorFrom, both not empty."
    Set tDescriptions("AutheAlwaysTryDelegated") = "Needs AutheDelegated on."
    Set tDescriptions("AutheLDAPCache") = "Needs AutheLDAP or AutheOSLDAP on."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        If tField = "" Quit
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit tSchema
}

/// <p>The names a call carries beside the settings: the identifying property and the agent's own words,
/// which the rules do not judge.</p>
ClassMethod Ignored() As %List
{
    Quit $ListBuild(..IdArgument(), "rationale", "expectedImpact", "reverse")
}

/// <p>The kernel's merge over the fresh read without an unchanged <parameter>KERBEROSFIELD</parameter>: it
/// is left out of the fresh read, and of the arguments, when the arguments carry no value or the value the
/// instance holds, so the payload, the diff and the body agree for the mint, the confirm and the Save.</p>
ClassMethod MergeRaw(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tFresh = pFresh
    Set tArgs = pArgs
    If $IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject") {
        Set tSent = $IsObject(pArgs) && (pArgs.%GetTypeOf(..#KERBEROSFIELD) '= "unassigned")
        If 'tSent || (##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(..#KERBEROSFIELD), pArgs.%GetTypeOf(..#KERBEROSFIELD)) = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#KERBEROSFIELD), pFresh.%GetTypeOf(..#KERBEROSFIELD))) {
            Set tFresh = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
            Do tFresh.%Remove(..#KERBEROSFIELD)
            If tSent {
                Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
                Do tArgs.%Remove(..#KERBEROSFIELD)
            }
        }
    }
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p><method>MergeRaw</method>, then the rules over the payload it would send
/// (<method>OcuPilot.Area.Security.AuthOptionsRules.Problem</method>), whose first refusal is
/// <var>pProblem</var>: so the mint, the confirm's fingerprint re-merge and the Save take one payload and
/// one refusal, before the port is touched.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ..MergeRaw(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Problem", pPayload, .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>The rules that need no fresh read, over the agent's arguments
/// (<method>OcuPilot.Area.Security.AuthOptionsRules.Problem</method>), so a refusal costs no port call
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", pArgs, .pProblem, 0)
}

/// <p>The same rules asked again at the confirm (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p><parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTTOKENSIGNOUT</parameter> when the payload changes
/// <code>JWTIssuer</code> or <code>JWTSigAlg</code> from the value the instance holds now, read as the
/// caller through this tool's port, and <code>""</code> otherwise. A read that fails states the
/// consequence.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Set tSignOut = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTTOKENSIGNOUT
    If pEffect = tSignOut Quit tSignOut
    If '$IsObject(pPayload) Quit ""
    Kill tQuery
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) Quit tSignOut
    Set tEffectSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).WeakensByEffect(##class(OcuPilot.Kernel.Proposal.Prohibited).#TYPEAUTHOPTIONS, pPayload, tHeld, .tEffect)
    If $$$ISERR(tEffectSC) Quit tSignOut
    Quit tEffect
}

/// <p>What the caller must hold: Authentication options' own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and the custom resource of
/// each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
