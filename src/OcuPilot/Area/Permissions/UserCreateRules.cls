/// <p>The User form's rules (AD-39, AD-55): the one rule set both callers of
/// <class>OcuPilot.Screen.Tool.UserCreate</class> and <class>OcuPilot.Screen.Tool.UserUpdate</class>
/// apply (<method>Validate</method>, in create or update mode), the form's bootstrap read
/// (<method>HandleForm</method>), and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Everything the vendor's post-create <code>Modify</code> reads is validated first.</b>
/// <code>%Api.Admin.Endpoints.Security.User:RunPost</code> calls <method>Security.Users.Create</method>
/// with the password and only then <code>Modify</code> with the other fields, so a field
/// <code>Modify</code> refuses would leave an account created with none of them.</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the
/// bootstrap read serves the same sentences, so an inline blur refusal and a failed Save are one
/// wording. No sentence names a password or any part of one (AD-35).</p>
Class OcuPilot.Area.Permissions.UserCreateRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.UserCreate";

/// <p>The form screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserForm";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Password";

/// <p>The vendor class whose property definitions the length bounds are read from.</p>
Parameter SECURITYCLASS = "Security.Users";

/// <p>The properties whose <code>MAXLEN</code> the form renders, comma-separated.</p>
Parameter LENGTHFIELDS = "Name,FullName,NameSpace,Routine,Comment,EmailAddress,PhoneNumber,PhoneProvider";

/// <p>The edit tool whose fresh read the form read answers with a name
/// (<method>HandleForm</method>).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.UserUpdate";

/// <p>The account settings an edit may carry, comma-separated: the classic General tab.</p>
Parameter SETTINGFIELDS = "AccountNeverExpires,AutheEnabled,ChangePassword,Comment,EmailAddress,Enabled,ExpirationDate,FullName,HOTPKeyDisplay,NameSpace,PasswordNeverExpires,PhoneNumber,PhoneProvider,Routine";

/// <p>The settings among <parameter>SETTINGFIELDS</parameter> whose value is a boolean.</p>
Parameter BOOLEANFIELDS = "AccountNeverExpires,ChangePassword,Enabled,HOTPKeyDisplay,PasswordNeverExpires";

/// <p>The <code>AutheEnabled</code> bits an edit may move: SMS text (<code>2**20</code>) and a
/// time-based one-time password (<code>2**21</code>), <file>%sySecurityMacros.inc</file>'s
/// <code>AutheTwoFactorSMS</code> and <code>AutheTwoFactorPW</code>.</p>
Parameter TWOFACTORSMSBIT As INTEGER = 1048576;

Parameter TWOFACTORTOTPBIT As INTEGER = 2097152;

/// <p>The field the edit form read carries the account in, and the member it never answers.</p>
Parameter FORMUSERKEY = "user";

Parameter FIELDESCALATIONROLES = "EscalationRoles";

/// <p>The longest a user name may be: <class>%Library.Username</class>'s own <code>MAXLEN</code>,
/// the type <property>Security.Users.Name</property> is declared with.</p>
Parameter NAMEMAXLENGTH As INTEGER = 160;

/// <p>The characters a user name may not carry beyond the control characters, as
/// <class>Security.Users</class> documents them.</p>
Parameter NAMEFORBIDDEN = "@*";

/// <p>The endpoint and request type the role picker lists through, on the tool's own port.</p>
Parameter ROLEENDPOINT = "Security.Role";

Parameter ROLELISTTYPE = "LIST";

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDPASSWORD = "Password";

Parameter FIELDFULLNAME = "FullName";

Parameter FIELDEXPIRY = "ExpirationDate";

Parameter FIELDNAMESPACE = "NameSpace";

Parameter FIELDROUTINE = "Routine";

Parameter FIELDROLES = "Roles";

Parameter FIELDCOMMENT = "Comment";

Parameter FIELDEMAIL = "EmailAddress";

Parameter FIELDPHONENUMBER = "PhoneNumber";

Parameter FIELDPHONEPROVIDER = "PhoneProvider";

Parameter FIELDAUTHE = "AutheEnabled";

/// <p>Every rule a create applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pCheckTaken</var> 0 skips the name look-up and <var>pCheckPassword</var> 0 skips the
/// password rules, for the agent's mint, which has read the target's absence and never holds a
/// password (<method>OcuPilot.Screen.Tool.UserCreate.ArgumentProblem</method>).</p>
/// <p><var>pMode</var> <code>update</code> is an edit of the existing account whose fresh read is
/// <var>pFresh</var>, over the fields <var>pArgs</var> changes (<method>Changed</method>): the name
/// and password rules are skipped, each setting is held to its shape and stored length, a routine
/// needs the namespace the edit leaves, and <code>AutheEnabled</code> may move only its two
/// two-factor bits, with at most one of them on (<method>AutheViolation</method>).</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pCheckTaken As %Boolean = 1, pCheckPassword As %Boolean = 1, pMode As %String = "create", pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If pMode = "update" {
            Set tSC = ..UpdateViolations(pArgs, pFresh, .pViolations)
            Quit
        }
        Do ..NameViolation(pName, .pViolations)
        If (pViolations = 0) && pCheckTaken {
            Set tTakenSC = ..Taken(pName, .tTaken)
            If $$$ISERR(tTakenSC) {
                Set tSC = tTakenSC
                Quit
            }
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMETAKEN)
        }

        If pCheckPassword {
            Set tPassword = ""
            If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#FIELDPASSWORD) = "string") Set tPassword = pArgs.%Get(..#FIELDPASSWORD)
            If tPassword = "" {
                Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#USERPASSWORDREQUIRED)
            } ElseIf '..MeetsPolicy(tPassword) {
                Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY)
            }
            Set tPassword = ""
        }

        For tField = ..#FIELDFULLNAME, ..#FIELDEXPIRY, ..#FIELDNAMESPACE, ..#FIELDROUTINE {
            If '..IsScalar(pArgs, tField) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }

        Set tMax = ..Lengths()
        Set tFullNameMax = +tMax.%Get(..#FIELDFULLNAME)
        If (tFullNameMax > 0) && ($Length(..Text(pArgs, ..#FIELDFULLNAME)) > tFullNameMax) Do ..Add(.pViolations, ..#FIELDFULLNAME, ##class(OcuPilot.Api.Error).#USERFULLNAMELENGTH)

        Set tExpiry = ..Text(pArgs, ..#FIELDEXPIRY)
        If (tExpiry '= "") && '..IsDate(tExpiry) Do ..Add(.pViolations, ..#FIELDEXPIRY, ##class(OcuPilot.Api.Error).#USEREXPIRATIONDATESHAPE)

        Set tNamespace = ..Text(pArgs, ..#FIELDNAMESPACE)
        If (tNamespace '= "") && '..NamespaceExists(tNamespace) Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#USERNAMESPACEUNKNOWN)

        Set tRoutine = ..Text(pArgs, ..#FIELDROUTINE)
        If tRoutine '= "" {
            If tNamespace = "" Do ..Add(.pViolations, ..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINENAMESPACE)
            Set tRoutineMax = +tMax.%Get(..#FIELDROUTINE)
            If (tRoutineMax > 0) && ($Length(tRoutine) > tRoutineMax) Do ..Add(.pViolations, ..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINELENGTH)
        }

        Set tRolesSC = ..RoleViolation(pArgs, .pViolations)
        If $$$ISERR(tRolesSC) Set tSC = tRolesSC
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The update-mode rules of <method>Validate</method> over the changed fields <var>pArgs</var>,
/// against the fresh read <var>pFresh</var>.</p>
ClassMethod UpdateViolations(pArgs As %DynamicObject, pFresh As %DynamicObject, ByRef pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    For tI = 1:1:$Length(..#SETTINGFIELDS, ",") {
        Set tField = $Piece(..#SETTINGFIELDS, ",", tI)
        If '..IsScalar(pArgs, tField) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Continue
        }
        If '$ListFind($ListFromString(..#BOOLEANFIELDS), tField) Continue
        If '$IsObject(pArgs) || (pArgs.%GetTypeOf(tField) = "unassigned") Continue
        Set tValue = ..Text(pArgs, tField)
        If '((tValue = "true") || (tValue = "false") || (tValue = "0") || (tValue = "1")) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    }
    Set tMax = ..Lengths()
    For tPair = $ListBuild(..#FIELDFULLNAME, ##class(OcuPilot.Api.Error).#USERFULLNAMELENGTH), $ListBuild(..#FIELDCOMMENT, ##class(OcuPilot.Api.Error).#USERCOMMENTLENGTH), $ListBuild(..#FIELDEMAIL, ##class(OcuPilot.Api.Error).#USEREMAILADDRESSLENGTH), $ListBuild(..#FIELDPHONENUMBER, ##class(OcuPilot.Api.Error).#USERPHONENUMBERLENGTH), $ListBuild(..#FIELDPHONEPROVIDER, ##class(OcuPilot.Api.Error).#USERPHONEPROVIDERLENGTH) {
        Set tField = $List(tPair, 1)
        Set tBound = +tMax.%Get(tField)
        If (tBound > 0) && ($Length(..Text(pArgs, tField)) > tBound) Do ..Add(.pViolations, tField, $List(tPair, 2))
    }
    Set tExpiry = ..Text(pArgs, ..#FIELDEXPIRY)
    If (tExpiry '= "") && '..IsDate(tExpiry) Do ..Add(.pViolations, ..#FIELDEXPIRY, ##class(OcuPilot.Api.Error).#USEREXPIRATIONDATESHAPE)
    Set tNamespace = ..Text(pArgs, ..#FIELDNAMESPACE)
    If (tNamespace '= "") && '..NamespaceExists(tNamespace) Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#USERNAMESPACEUNKNOWN)
    Set tRoutine = ..Held(pArgs, pFresh, ..#FIELDROUTINE)
    If ($IsObject(pArgs) && ((pArgs.%GetTypeOf(..#FIELDROUTINE) '= "unassigned") || (pArgs.%GetTypeOf(..#FIELDNAMESPACE) '= "unassigned"))) && (tRoutine '= "") {
        If ..Held(pArgs, pFresh, ..#FIELDNAMESPACE) = "" Do ..Add(.pViolations, ..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINENAMESPACE)
        Set tRoutineMax = +tMax.%Get(..#FIELDROUTINE)
        If (tRoutineMax > 0) && ($Length(tRoutine) > tRoutineMax) Do ..Add(.pViolations, ..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINELENGTH)
    }
    Do ..AutheViolation(pArgs, pFresh, .pViolations)
    Set tRolesSC = ..RoleViolation(pArgs, .pViolations)
    If $$$ISERR(tRolesSC) Set tSC = tRolesSC
    Quit tSC
}

/// <p>Add <code>AutheEnabled</code>'s violation to <var>pViolations</var>, or none. A value that is
/// not a whole number of at most fifteen digits, or that differs from <var>pFresh</var>'s stored mask in any bit but
/// <parameter>TWOFACTORSMSBIT</parameter> and <parameter>TWOFACTORTOTPBIT</parameter>, is
/// <code>USER.AUTHEENABLED.SCOPE</code>; one with both of those on is
/// <code>USER.TWOFACTOR.BOTH</code>. An absent member changes nothing.</p>
ClassMethod AutheViolation(pArgs As %DynamicObject, pFresh As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..#FIELDAUTHE) = "unassigned") Quit
    If '..IsScalar(pArgs, ..#FIELDAUTHE) Quit
    Set tWanted = ..Text(pArgs, ..#FIELDAUTHE)
    If '$Match(tWanted, "^[0-9]{1,15}$") {
        Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#USERAUTHEENABLEDSCOPE)
        Quit
    }
    Set tStored = +..Text(pFresh, ..#FIELDAUTHE)
    Set tTwoFactor = ..#TWOFACTORSMSBIT + ..#TWOFACTORTOTPBIT
    Set tMoved = $ZBoolean(+tWanted, tStored, 6)
    If $ZBoolean(tMoved, tTwoFactor, 2) '= 0 {
        Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#USERAUTHEENABLEDSCOPE)
        Quit
    }
    If $ZBoolean(+tWanted, tTwoFactor, 1) = tTwoFactor Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#USERTWOFACTORBOTH)
}

/// <p>The members of <var>pArgs</var> an edit changes: each of <parameter>SETTINGFIELDS</parameter>
/// and <parameter>FIELDROLES</parameter> it carries whose value differs from <var>pFresh</var>'s,
/// compared as the diff renders them, as a new <class>%DynamicObject</class>. With no fresh read
/// every one <var>pArgs</var> carries is changed.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tFields = $ListFromString(..#SETTINGFIELDS) _ $ListBuild(..#FIELDROLES)
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "unassigned" Continue
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(tField) '= "unassigned") {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField))
            Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(tField), tType)
            If tAfter = tBefore Continue
        }
        If (tType = "object") || (tType = "array") {
            Do tChanged.%Set(tField, pArgs.%Get(tField))
        } Else {
            Do tChanged.%Set(tField, pArgs.%Get(tField), tType)
        }
    }
    Quit tChanged
}

/// <p>Add the name's own shape violation to <var>pViolations</var>, or none: an absent name, and
/// one longer than <parameter>NAMEMAXLENGTH</parameter> or carrying a control character or a
/// character of <parameter>NAMEFORBIDDEN</parameter>. Run first by the create route, because everything after it
/// addresses the target by this name.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMEREQUIRED)
        Quit
    }
    If '..NameIsUsable(pName) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMESHAPE)
}

/// <p>Whether <var>pName</var> is a name this instance can hold.</p>
ClassMethod NameIsUsable(pName As %String) As %Boolean
{
    If $Length(pName) > ..#NAMEMAXLENGTH Quit 0
    Set tUsable = 1
    For tI = 1:1:$Length(..#NAMEFORBIDDEN) {
        If pName [ $Extract(..#NAMEFORBIDDEN, tI) Set tUsable = 0 Quit
    }
    If 'tUsable Quit 0
    For tI = 1:1:$Length(pName) {
        Set tCode = $Ascii(pName, tI)
        If (tCode < 32) || (tCode = 127) Set tUsable = 0 Quit
    }
    Quit tUsable
}

/// <p>Whether <var>pPassword</var> matches <property>Security.System.PasswordPattern</property>,
/// read in <code>%SYS</code> by AD-16's explicit save and restore and matched with the pattern
/// operator. An instance with no pattern accepts any non-empty password. The value is never
/// logged, returned or placed in a status (AD-35).</p>
ClassMethod MeetsPolicy(pPassword As %String) As %Boolean
{
    Set tMeets = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPattern = ""
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set tPattern = tSystem.PasswordPattern
        Set tSystem = ""
        Set $NAMESPACE = tOrigNS
        If tPattern = "" {
            Set tMeets = 1
        } Else {
            Set tMeets = ''(pPassword?@tPattern)
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tMeets = 0
    }
    Quit tMeets
}

/// <p>Whether <var>pValue</var> is a real calendar date written <code>YYYY-MM-DD</code>: the
/// shape, and a round trip through the instance's own date conversion, so
/// <code>2027-02-30</code> is refused.</p>
ClassMethod IsDate(pValue As %String) As %Boolean
{
    If '$Match(pValue, "^\d{4}-\d{2}-\d{2}$") Quit 0
    Set tDay = $ZDateH(pValue, 3, , , , , , , "")
    If tDay = "" Quit 0
    Quit ($ZDate(tDay, 3) = pValue)
}

/// <p>Whether <var>pNamespace</var> is a namespace this instance holds.</p>
ClassMethod NamespaceExists(pNamespace As %String) As %Boolean
{
    Set tExists = 0
    Try {
        Set tExists = ''##class(%SYS.Namespace).Exists(pNamespace)
    } Catch {
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Add the roles' violation to <var>pViolations</var>, or none: a <code>Roles</code> member that
/// is not an array of strings, or one naming a role the instance does not hold
/// (<method>Security.Users.Create</method> would accept it silently). An absent member names no
/// role.</p>
ClassMethod RoleViolation(pArgs As %DynamicObject, Output pViolations) As %Status
{
    Set tSC = $$$OK
    If '$IsObject(pArgs) Quit tSC
    Set tType = pArgs.%GetTypeOf(..#FIELDROLES)
    If tType = "unassigned" Quit tSC
    If tType '= "array" {
        Do ..Add(.pViolations, ..#FIELDROLES, ##class(OcuPilot.Api.Error).#USERROLESSHAPE)
        Quit tSC
    }
    Set tNames = ""
    Set tIterator = pArgs.%Get(..#FIELDROLES).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        If $IsObject(tRole) || (tRole = "") {
            Set tNames = ""
            Do ..Add(.pViolations, ..#FIELDROLES, ##class(OcuPilot.Api.Error).#USERROLESSHAPE)
            Quit
        }
        Set tNames = tNames _ $ListBuild(tRole)
    }
    If tNames = "" Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tUnknown = 0
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            If '##class(Security.Roles).Exists($List(tNames, tI)) Set tUnknown = 1 Quit
        }
        Set $NAMESPACE = tOrigNS
        If tUnknown Do ..Add(.pViolations, ..#FIELDROLES, ##class(OcuPilot.Api.Error).#USERROLESUNKNOWN)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer <code>GET /users/form[?name=&lt;n&gt;]</code>: everything the create form and the
/// editor need before they can draw a field (AD-39): <code>{requiredFields, maxLengths, rules,
/// roles}</code>, and with a name <code>user</code>, the edit tool's own fresh read of that account
/// less its escalation roles (<method>Account</method>); a name this instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.USERNAMEABSENT</parameter>. <code>rules</code> is
/// one <code>{field, code, reason}</code> per rule, each field's required rule first;
/// <code>roles</code> is <code>[{name, privileged}]</code>, listed through the tool's own port and
/// each marked by <method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsAdministrativePrivilege</method>,
/// the one answer the agent's proposal is marked destructive by too, so the form's consequence line
/// and the card's cannot disagree (AD-10).</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tRolesSC = ..Roles(.tRoles)
        If $$$ISERR(tRolesSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tRolesSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("requiredFields", ..Names(..#REQUIREDFIELDS))
        Do tBody.%Set("maxLengths", ..Lengths())
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("roles", tRoles)
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Account(tName, .tUser, .tHttp, .tFault)
            If $$$ISERR(tReadSC) && (+$Get(tHttp) = 404) {
                Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONUSERNAMEABSENT, ##class(OcuPilot.Api.Error).#USERNAMEABSENT)
                Quit
            }
            If $$$ISERR(tReadSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
                Quit
            }
            Do tBody.%Set(..#FORMUSERKEY, tUser)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /users/name?name=&lt;n&gt;</code>: whether that name is free, in
/// <code>{name, available, reason}</code>. A look-up that cannot be made is a refusal envelope,
/// never an assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.Permissions.UserCreate).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("available", 'tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#USERNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether an account already carries <var>pName</var>, in <var>pTaken</var>, read through the
/// create tool's own port, endpoint and read type (AD-52). <class>Security.Users</class> keys on
/// the lower-cased name, so the read answers for a name in any case.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#TOOLCLASS
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tReadSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tHttp) = 404 Quit
            Set tSC = tReadSC
            Quit
        }
        Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    } Catch ex {
        Set pTaken = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The account <var>pName</var> as <parameter>UPDATETOOL</parameter>'s own read answers it,
/// through its own port (AD-52), without <parameter>FIELDESCALATIONROLES</parameter>, in
/// <var>pUser</var>. An absent account is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Account(pName As %String, Output pUser As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pUser = ""
    Set tClass = ..#UPDATETOOL
    Kill tQuery
    Set tQuery($ClassMethod(tClass, "IdParam")) = pName
    Set tSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
        Set pHttpStatus = 404
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#USERNAMEABSENT)
    }
    Do tFresh.%Remove(..#FIELDESCALATIONROLES)
    Set pUser = tFresh
    Quit $$$OK
}

/// <p>The roles this instance holds, as <code>[{name, privileged}]</code> in the order the vendor
/// lists them, read through the create tool's own port (AD-52).</p>
ClassMethod Roles(Output pRoles As %DynamicArray) As %Status
{
    Set pRoles = []
    Set tSC = $$$OK
    Try {
        Set tClass = ..#TOOLCLASS
        Kill tQuery
        Set tSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", ..#ROLEENDPOINT, ..#ROLELISTTYPE, .tQuery, "", .tList, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get("Name")
            If tName = "" Continue
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("privileged", ##class(OcuPilot.Kernel.Proposal.Prohibited).RoleGrantsAdministrativePrivilege(tName), "boolean")
            Do pRoles.%Push(tEntry)
        }
    } Catch ex {
        Set pRoles = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The length each field stores, as <code>{field: length}</code>, read from
/// <parameter>SECURITYCLASS</parameter>'s compiled property definitions in <code>%SYS</code>; the
/// name's bound is <parameter>NAMEMAXLENGTH</parameter>, its datatype's own.</p>
ClassMethod Lengths() As %DynamicObject
{
    Set tObject = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#LENGTHFIELDS, ",") {
            Set tField = $Piece(..#LENGTHFIELDS, ",", tI)
            If tField = ..#FIELDNAME {
                Do tObject.%Set(tField, ..#NAMEMAXLENGTH, "number")
                Continue
            }
            Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(..#SECURITYCLASS _ "||" _ tField)
            If '$IsObject(tProperty) Continue
            Set tMax = tProperty.Parameters.GetAt("MAXLEN")
            Set tProperty = ""
            If tMax = "" Continue
            Do tObject.%Set(tField, +tMax, "number")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tObject = {}
    }
    Quit tObject
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>, each field's
/// required-ness rule first. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tSpec = $ListBuild($ListBuild(..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMEREQUIRED))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMESHAPE))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDNAME, ##class(OcuPilot.Api.Error).#USERNAMETAKEN))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#USERPASSWORDREQUIRED))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDFULLNAME, ##class(OcuPilot.Api.Error).#USERFULLNAMELENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDEXPIRY, ##class(OcuPilot.Api.Error).#USEREXPIRATIONDATESHAPE))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#USERNAMESPACEUNKNOWN))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINENAMESPACE))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDROUTINE, ##class(OcuPilot.Api.Error).#USERROUTINELENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDROLES, ##class(OcuPilot.Api.Error).#USERROLESUNKNOWN))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDROLES, ##class(OcuPilot.Api.Error).#USERROLESSHAPE))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDCOMMENT, ##class(OcuPilot.Api.Error).#USERCOMMENTLENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDEMAIL, ##class(OcuPilot.Api.Error).#USEREMAILADDRESSLENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDPHONENUMBER, ##class(OcuPilot.Api.Error).#USERPHONENUMBERLENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDPHONEPROVIDER, ##class(OcuPilot.Api.Error).#USERPHONEPROVIDERLENGTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#USERTWOFACTORBOTH))
    Set tSpec = tSpec _ $ListBuild($ListBuild(..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#USERAUTHEENABLEDSCOPE))
    For tI = 1:1:$ListLength(tSpec) {
        Set tPair = $List(tSpec, tI)
        Set tCode = $List(tPair, 2)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", $List(tPair, 1), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Refuse a caller who does not hold the form screen's declared pairs (AD-8):
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Whether <var>pArgs</var>'s member <var>pName</var> is absent or a literal, never an object or
/// an array.</p>
ClassMethod IsScalar(pArgs As %DynamicObject, pName As %String) As %Boolean [ Private ]
{
    If '$IsObject(pArgs) Quit 1
    Set tType = pArgs.%GetTypeOf(pName)
    Quit '((tType = "object") || (tType = "array"))
}

/// <p><var>pArgs</var>'s member <var>pName</var> as the rules read it: a literal verbatim and
/// anything else <code>""</code>.</p>
ClassMethod Text(pArgs As %DynamicObject, pName As %String) As %String [ Private ]
{
    If '$IsObject(pArgs) Quit ""
    Set tType = pArgs.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(pName), tType)
}

/// <p><var>pArgs</var>'s member <var>pField</var> as the rules read it where it carries one, else
/// <var>pFresh</var>'s.</p>
ClassMethod Held(pArgs As %DynamicObject, pFresh As %DynamicObject, pField As %String) As %String [ Private ]
{
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(pField) '= "unassigned") Quit ..Text(pArgs, pField)
    Quit ..Text(pFresh, pField)
}

/// <p>A comma-separated list as a <class>%DynamicArray</class> of strings.</p>
ClassMethod Names(pList As %String) As %DynamicArray [ Private ]
{
    Set tRows = []
    For tI = 1:1:$Length(pList, ",") {
        Set tName = $Piece(pList, ",", tI)
        If tName '= "" Do tRows.%Push(tName)
    }
    Quit tRows
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
