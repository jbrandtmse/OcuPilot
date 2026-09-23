/// <p>The Web application form's own bootstrap read (DW-376): the authentication methods this
/// instance offers for a web application, the fields a create requires, the length each field
/// stores, and the <b>sentence</b> each of those rules refuses with.</p>
/// <p><b>It exists because no validate-only route does, and OcuPilot adds none.</b> The admin API
/// publishes no validate operation for any of its 305 paths, and the vendor's own shape layer
/// produces exactly four field-level refusals, of which only a missing and an unexpected field are
/// reachable from a form over a fixed field list -- and the first is required-ness, which is
/// declarative rather than a sentence. What DW-376 actually needs is a way to hand the client a
/// <b>server-authored</b> sentence with no save, and the shipped precedent for that is
/// <code>keyShapeReason</code> travelling on <code>GET /agent/providers</code>. So every rule and
/// its sentence ship here, authored once beside the refusal they mirror (AD-39), and the client
/// publishes no per-field copy of its own.</p>
/// <p><b>The one rule that is not a shape rule is a read, not a validation.</b> Whether a name is
/// already taken is answered by <method>Taken</method> over <code>GET /web-applications/name</code>,
/// because it is a question about the instance rather than about the value -- and it matters more
/// than the rest, since the vendor's PUT is an upsert and a taken name is the difference between a
/// create and overwriting somebody's application (AD-54).</p>
/// <p><b>Every word it publishes is the vendor's own or OcuPilot's own refusal sentence.</b> The
/// authentication methods carry the labels <class>%CSP.UI.Portal.Applications.Web</class> draws
/// them with, read from the instance's own message dictionary in that page's own order, so the two
/// surfaces cannot name one method two ways; the sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</p>
Class OcuPilot.Area.WebApp.FormRules Extends %RegisteredObject
{

/// <p>The message domain the instance holds a web application's authentication-method labels in,
/// and the routine that reads it. <class>%CSP.UI.Portal.Applications.Web</class> resolves the same
/// strings through the <code>$$$Authe&lt;X&gt;Str</code> macros, which expand to this domain.</p>
Parameter SERVICESDOMAIN = "%SECURITY.Services";

/// <p>The authentication bits a web application may carry, as
/// <code>&lt;bit&gt;:&lt;messageKey&gt;</code> pairs in the order
/// <method>%CSP.UI.Portal.Applications.Web.BuildAutheArray</method> inserts them, comma-separated.</p>
/// <p><b>The set is the vendor's <code>$$$CSPApplicationValidAuthe</code></b>, which is what an
/// application's own mask may hold; the list a caller is offered is that set intersected with the
/// bits <property>Security.System.AutheEnabled</property> reports, so a method the instance has
/// turned off is never offered. The two X.509 and TLS bits the macro also names carry no row in
/// the classic page's own array and carry none here either, for the same reason: neither is a
/// method that page lets an operator pick.</p>
/// <p>The numeric values are <file>irissys/%sySecurityMacros.inc</file>'s and
/// <file>irissys/%sySecurity.inc</file>'s: Kerberos API 4, password 32, unauthenticated 64, LDAP
/// 2048, delegated 8192, login cookie 16384, two-factor SMS 1048576, two-factor one-time password
/// 2097152, OAuth 2.0 67108864.</p>
/// <p>The two bits <method>DefaultMethod</method> reasons about by name: the option that lets an
/// application be reached without signing in, and password authentication. Their values are
/// <file>irissys/%sySecurityMacros.inc</file>'s.</p>
Parameter UNAUTHENTICATEDBIT As INTEGER = 64;

Parameter PASSWORDBIT As INTEGER = 32;

Parameter AUTHEMETHODS = "64:AutheUnauthenticatedStr,32:AutheCacheStr,4:AutheK5APIStr,8192:AutheDelegatedStr,2048:AutheLDAPStr,67108864:AutheOAuth2Str,2097152:AutheTwoFactorPWStr,1048576:AutheTwoFactorSMSStr,16384:AutheLoginTokenStr";

/// <p>The fields a create must carry whatever type of application it is, comma-separated. The
/// two type-dependent ones -- a REST application's dispatch class and a WSGI application's own
/// three -- are conditional and are declared by <method>Conditional</method> instead.</p>
Parameter REQUIREDFIELDS = "Name,NameSpace,AutheEnabled";

/// <p>The two protocol values <property>Security.Applications.WSGIType</property> publishes, in
/// its own <code>DISPLAYLIST</code> order. They travel as display strings because the endpoint
/// runs <code>WSGITypeDisplayToLogical</code> over the body's value.</p>
Parameter WSGITYPES = "WSGI,ASGI";

/// <p>The vendor class whose property definitions the length bounds are read from, so a bound the
/// instance changes is a bound the form changes.</p>
Parameter SECURITYCLASS = "Security.Applications";

/// <p>The properties whose <code>MAXLEN</code> the form renders, comma-separated.</p>
Parameter LENGTHFIELDS = "Name,Description,NameSpace,Resource,DispatchClass,WSGIAppName,WSGICallable,WSGIAppLocation";

/// <p>The endpoint and request type the application-roles picker lists roles through, on the
/// create tool's own port (AD-52).</p>
Parameter ROLEENDPOINT = "Security.Role";

Parameter ROLELISTTYPE = "LIST";

/// <p>The longest a web application's own name may be. <property>Security.Applications.Name</property>
/// is the id key and carries no <code>MAXLEN</code> of its own, so the bound the form renders for
/// it is the one <method>OcuPilot.Area.WebApp.Create</method> refuses at.</p>
Parameter NAMEMAXLENGTH As INTEGER = 64;

/// <p>Answer <code>GET /web-applications/form</code>: everything the create form needs before it
/// can draw a field (AD-39, DW-376).</p>
/// <p>The body is
/// <code>{authenticationMethods, defaultMethod, requiredFields, conditionalFields, wsgiTypes, maxLengths, rules, wsgiRoot, roles}</code>.
/// <code>rules</code> is one <code>{field, code, reason}</code> per rule the server applies, in the
/// same shape a refusal's own <code>detail.violations</code> row takes -- so the client renders an
/// inline blur refusal and a failed Save through one path and holds no copy of its own.
/// <code>roles</code> is <method>Roles</method>'s <code>[{name, privileged}]</code>, for the
/// application-roles control.</p>
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
        Do tBody.%Set("authenticationMethods", ..Methods())
        Do tBody.%Set("defaultMethod", ..DefaultMethod(), "number")
        Do tBody.%Set("requiredFields", ..Names(..#REQUIREDFIELDS))
        Do tBody.%Set("conditionalFields", ..Conditional())
        Do tBody.%Set("wsgiTypes", ..Names(..#WSGITYPES))
        Do tBody.%Set("maxLengths", ..Lengths())
        Do tBody.%Set("rules", ..Rules())
        ; AD-21: the root a WSGI or ASGI directory name resolves under, computed for this read, so
        ; the form can show the resolved path read-only. The server resolves again at the write.
        Do tBody.%Set("wsgiRoot", ##class(OcuPilot.Area.WebApp.Location).Root(), "string")
        Do tBody.%Set("roles", tRoles)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /web-applications/name?name=&lt;n&gt;</code>: whether that name is free,
/// in <code>{name, available, reason}</code>.</p>
/// <p><b>It is the blur check, and it is a read rather than a validation.</b> A look-up that
/// cannot be made leaves the field unmarked rather than asserting availability: the answer is
/// <code>available</code> true with an empty reason only when the instance said the name is free,
/// and a refused or faulted read is a refusal envelope the client renders as nothing on the field.
/// Asserting "free" from a read that failed is the one answer that would let a create overwrite
/// somebody's application (AD-54).</p>
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
            Set tSC = ##class(OcuPilot.Area.WebApp.Create).RenderOne("Name", ##class(OcuPilot.Api.Error).#WEBAPPNAMEREQUIRED)
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
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#WEBAPPNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a web application already answers <var>pName</var>, in <var>pTaken</var>, read
/// through the declared port at the create tool's own endpoint and read type (AD-52).</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered and
/// <var>pTaken</var> says nothing; only a 404 from the port is "free". Every other refusal is a
/// refusal, never an absence.</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ##class(OcuPilot.Area.WebApp.Create).ToolClass()
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

/// <p>The authentication methods this instance offers for a web application, as
/// <code>[{bit, label}]</code> in the classic page's own order (AD-8's "listed and named" applied
/// to a choice rather than a control).</p>
/// <p>The set is <parameter>AUTHEMETHODS</parameter> intersected with
/// <property>Security.System.AutheEnabled</property>, read in <code>%SYS</code> by AD-16's explicit
/// save and restore. A method the instance has turned off is absent rather than offered and
/// refused.</p>
ClassMethod Methods() As %DynamicArray
{
    Set tRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tEnabled = 0
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set tEnabled = +tSystem.AutheEnabled
        Set tSystem = ""
        For tI = 1:1:$Length(..#AUTHEMETHODS, ",") {
            Set tPair = $Piece(..#AUTHEMETHODS, ",", tI)
            Set tBit = +$Piece(tPair, ":", 1)
            If tBit = 0 Continue
            If '((tEnabled \ tBit) # 2) Continue
            Set tRow = {}
            Do tRow.%Set("bit", tBit, "number")
            Do tRow.%Set("label", $$FormatMessage^%occMessages("", ..#SERVICESDOMAIN, $Piece(tPair, ":", 2)), "string")
            Do tRows.%Push(tRow)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = []
    }
    Quit tRows
}

/// <p>The bit a create form starts on: password authentication where the instance offers it, and
/// the first offered method that is not <parameter>UNAUTHENTICATEDBIT</parameter> otherwise;
/// <code>0</code> where the instance offers nothing else.</p>
/// <p><b>It is a server decision, and it is the one the vendor's own default makes wrong.</b>
/// <property>Security.Applications.AutheEnabled</property> carries
/// <code>InitialExpression = 64</code>, and the classic page lists the unauthenticated option
/// first, so a form that started on "whatever is offered first" would start every create on an
/// application anybody can reach. A form that started on nothing would make the first Save a
/// refusal every time. Choosing here rather than in the client keeps both out of the client's
/// hands.</p>
ClassMethod DefaultMethod() As %Integer
{
    Set tDefault = 0
    Set tIterator = ..Methods().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tBit = +tRow.%Get("bit")
        If tBit = ..#UNAUTHENTICATEDBIT Continue
        If tBit = ..#PASSWORDBIT {
            Set tDefault = tBit
            Quit
        }
        If tDefault = 0 Set tDefault = tBit
    }
    Quit tDefault
}

/// <p>Every bit <method>Methods</method> offers, as one mask, so a supplied value can be judged
/// against what the instance actually offers rather than against a constant.</p>
ClassMethod Mask() As %Integer
{
    Set tMask = 0
    Set tIterator = ..Methods().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tMask = tMask + tRow.%Get("bit")
    }
    Quit tMask
}

/// <p>The fields only one kind of application sends, as <code>{rest: [...], wsgi: [...]}</code>.
/// The form's type control decides which list applies, and a field on the other list is not sent.
/// Every field listed is required for its kind except <code>WSGICallable</code>, which the
/// vendor defaults; <method>OcuPilot.Area.WebApp.Create</method> applies the same rules.</p>
ClassMethod Conditional() As %DynamicObject
{
    Set tObject = {}
    Do tObject.%Set("rest", ..Names("DispatchClass"))
    Do tObject.%Set("wsgi", ..Names("WSGIAppName,WSGICallable,WSGIAppLocation,WSGIType"))
    Quit tObject
}

/// <p>The length each field stores, as <code>{field: length}</code>, read from
/// <parameter>SECURITYCLASS</parameter>'s own compiled property definitions so a bound the
/// instance changes is a bound the form changes. A property with no declared bound is absent
/// rather than given one this class invented; the name's own bound is
/// <parameter>NAMEMAXLENGTH</parameter>, which <method>OcuPilot.Area.WebApp.Create</method>
/// refuses at.</p>
ClassMethod Lengths() As %DynamicObject
{
    Set tObject = {}
    Set tOrigNS = $NAMESPACE
    Try {
        ; The vendor class lives in %SYS and nowhere else, so the dictionary read is made there by
        ; AD-16's explicit save and restore. Read from the install namespace it answers nothing,
        ; which would publish a form with no bound on any field but the name.
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#LENGTHFIELDS, ",") {
            Set tField = $Piece(..#LENGTHFIELDS, ",", tI)
            If tField = "Name" {
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

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code> -- the same shape a
/// refusal's own <code>detail.violations</code> row takes (AD-39). Each field's required-ness rule
/// is its first row, which is the one the form renders on a blurred empty field.</p>
/// <p><b>The sentences are <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so the
/// inline check a blur runs and the refusal a Save earns are one wording rather than two. A rule
/// whose code carries no published sentence is absent, which is the fail-closed direction: a field
/// with no sentence renders nothing rather than an empty one.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tSpec = "Name:" _ ##class(OcuPilot.Api.Error).#WEBAPPNAMEREQUIRED
    Set tSpec = tSpec _ ",Name:" _ ##class(OcuPilot.Api.Error).#WEBAPPNAMESHAPE
    Set tSpec = tSpec _ ",Name:" _ ##class(OcuPilot.Api.Error).#WEBAPPNAMETAKEN
    Set tSpec = tSpec _ ",NameSpace:" _ ##class(OcuPilot.Api.Error).#WEBAPPNAMESPACEREQUIRED
    Set tSpec = tSpec _ ",AutheEnabled:" _ ##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED
    Set tSpec = tSpec _ ",AutheEnabled:" _ ##class(OcuPilot.Api.Error).#WEBAPPAUTHEUNKNOWN
    Set tSpec = tSpec _ ",DispatchClass:" _ ##class(OcuPilot.Api.Error).#WEBAPPDISPATCHREQUIRED
    Set tSpec = tSpec _ ",WSGIAppName:" _ ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPNAME
    Set tSpec = tSpec _ ",WSGIAppLocation:" _ ##class(OcuPilot.Api.Error).#WEBAPPWSGILOCATION
    Set tSpec = tSpec _ ",WSGIAppLocation:" _ ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPLOCATIONSHAPE
    Set tSpec = tSpec _ ",WSGIType:" _ ##class(OcuPilot.Api.Error).#WEBAPPWSGITYPE
    Set tSpec = tSpec _ ",MatchRoles:" _ ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESSHAPE
    Set tSpec = tSpec _ ",MatchRoles:" _ ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESUNKNOWN
    For tI = 1:1:$Length(tSpec, ",") {
        Set tPair = $Piece(tSpec, ",", tI)
        Set tCode = $Piece(tPair, ":", 2)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", $Piece(tPair, ":", 1), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The roles this instance holds, as <code>[{name, privileged}]</code> in the order the vendor
/// lists them, read through the create tool's own port (AD-52). <code>privileged</code> is
/// <method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsAdministrativePrivilege</method>'s answer,
/// the one the agent's proposal is marked destructive by, so the form's consequence line and the
/// card's cannot disagree (AD-10).</p>
ClassMethod Roles(Output pRoles As %DynamicArray) As %Status
{
    Set pRoles = []
    Set tSC = $$$OK
    Try {
        Set tClass = ##class(OcuPilot.Area.WebApp.Create).ToolClass()
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

/// <p>Refuse a caller who does not hold the form screen's own declared pairs (AD-8)
/// (<method>OcuPilot.Area.WebApp.Create.Gate</method>): <var>pRefused</var> 1 means the refusal
/// is rendered and the caller quits on it.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Quit ##class(OcuPilot.Area.WebApp.Create).Gate(.pRefused)
}

}
