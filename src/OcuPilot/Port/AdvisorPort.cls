/// <p>The Security advisor port (AD-29, AD-52, AD-53, AD-58): the instance's security recommendations and the ignore flag each
/// one carries, over the classic Security Advisor page's own methods, <parameter>PANECLASS</parameter>
/// <code>GetRecommendations</code> and <code>SetIgnoreFlag</code>, both in <code>%SYS</code> (AD-16). It is
/// <class>OcuPilot.Port.AdminPort</class> with one pseudo-endpoint, <parameter>ENDPOINT</parameter>, carried out here; every other
/// call is the admin port's own.</p>
/// <p><b>Why a port.</b> The vendor's <code>%SYS.SECURITY</code> labels the page calls refuse user code (error 795), so the
/// page's own two methods are the only way in.</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, checked in order in the calling process before any
/// read or vendor call, for a read and for both writes. The page's recommendations raise <code>&lt;PROTECT&gt;</code> for a
/// caller that lacks <code>%DB_IRISSYS:WRITE</code>, so the read holds all three pairs. A caller missing one is refused 403
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> naming it.</p>
/// <p><b>A row</b> is <code>{Type, Area, Element, Code, Recommendation, Ignored}</code>: the page's own type, element and code,
/// the area and the sentence each is published as (<parameter>ADVISORAREAS</parameter>, <parameter>ADVISORTEXTS</parameter>; a
/// type or a code the rosters do not know answers itself) and whether the recommendation is ignored. <code>Element</code> is
/// the page's own, a single space for a type's general row. Its id is composite (AD-13): the type, the element and the
/// code.</p>
/// <p><b>Two refusals are published</b>, both 409 on the conflict slug: <code>ADVISOR.IGNORED</code> for an ignore of a
/// recommendation already ignored and <code>ADVISOR.NOTIGNORED</code> for the opposite.</p>
/// <p>Seams a test subclass overrides: <method>Recommendations</method> and <method>SetFlag</method>, with the admin port's own
/// <method>HoldsPair</method> and <method>LogFault</method>. Production overrides none of them. Every seam that reaches the
/// vendor is private, so <method>Invoke</method>, behind the gate, is the only way in.</p>
Class OcuPilot.Port.AdvisorPort Extends OcuPilot.Port.AdminPort
{

/// <p>The pseudo-endpoint this port carries out itself.</p>
Parameter ENDPOINT = "SecurityAdvisor";

/// <p>The read type: every row.</p>
Parameter LISTTYPE = "LIST";

/// <p>The read type of one row, named by <parameter>IDPARAM</parameter>.</p>
Parameter ROWTYPE = "ROW";

/// <p>The write that ignores a recommendation.</p>
Parameter IGNORETYPE = "IGNORE";

/// <p>The write that stops ignoring a recommendation.</p>
Parameter UNIGNORETYPE = "UNIGNORE";

/// <p>The query parameter a row's composite id travels under.</p>
Parameter IDPARAM = "id";

/// <p>The query parameter a list's row cap travels under.</p>
Parameter MAXROWSPARAM = "maxRows";

/// <p>The row cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The port's own pair set for a read and for both writes, checked in this order before any read or vendor call (AD-29).</p>
Parameter PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE";

/// <p>The classic page's class, whose methods this port calls in <code>%SYS</code>.</p>
Parameter PANECLASS = "%CSP.UI.System.SecurityAdvisorPane";

/// <p>The area each type is published under, as <code>Type=label</code> entries joined by <code>|</code>.</p>
Parameter ADVISORAREAS = "Auditing=Auditing|Services=Services|Roles=Roles|Users=Users|AppsCSP=Web applications|AppsRoutine=Privileged routine applications|AppsExecutable=Client applications";

/// <p>The sentence each code is published as, as <code>Code=sentence</code> entries joined by <code>|</code>.</p>
Parameter ADVISORTEXTS = "AuditingSBON=Auditing should be enabled|AuditingTypeSBON=Auditing for this event type should be enabled|AuditingON=Auditing is enabled|AuditingOFF=Auditing is disabled|ServiceSBOFF=Service should be disabled unless required|UnauthenticatedSBOFF=Unauthenticated should be off|ServiceSHClientIPS=Service should have client IP addresses assigned|ServiceSHKerberos=Service should use Kerberos authentication where possible|ServicePublic=Service should not be Public where possible|ServiceOneAuthentication=Service should only have one authentication mode on|ServiceNoAuthentication=Service has no authentication modes enabled|PasswordSBChanged=Password should be changed from default password|DormantCount=Dormant users should be disabled or deleted|NotUsedCount=Users who never logged in should be disabled or deleted|UserIsDormant=User appears dormant and should be disabled or deleted|UserNotUsed=User has never logged in and should be disabled or deleted|UserNoNamespace=User has a default namespace which does not exist|AllCountMinMax=At least 2 and at most 5 users should have the %All role|PUBLICHasRoles=_PUBLIC user should not have roles|PUBLICRolesList=All users are granted the following roles from _PUBLIC:|MGRCount=WRITE privilege to IRISSYS should be restricted|SecureCount=WRITE privilege to system security settings should be restricted|AuditCount=READ and WRITE privilege to the audit database should be restricted|UnknownUserHasAll=UnknownUser user should not have the %All role|AAllUsersInherit=All user's inherit the following roles from _PUBLIC|PercentGlobalWrite=Ability to set % globals should be turned off|UserHasAll=This user holds the %All role|UserHasAudit=This user holds READ or WRITE privileges on the Audit database|UserHasSys=This user holds WRITE privilege on the IRISSYS database|UserHasSecure=This user holds WRITE privilege on the system security settings|RoleHasAudit=This role holds READ or WRITE privileges on the Audit database|RoleHasSys=This role holds WRITE privilege on the IRISSYS database|RoleHasSecure=This role holds WRITE privilege on the system security settings|AppIsPublic=Application is Public|AppCondGrantsAll=Application conditionally grants the %All role|AppGrantsAll=Application grants the %All role|AppSHKerberos=Application should use Kerberos authentication where possible|AppOneAuthentication=Application should only have one authentication mode on|AppNoAuthentication=Application has no authentication modes enabled";

/// <p>The admin port's call, except for <parameter>ENDPOINT</parameter>: <parameter>LISTTYPE</parameter> answers the rows, at
/// most <parameter>MAXROWSPARAM</parameter> of them, ordered by type, then element, then code;
/// <parameter>ROWTYPE</parameter> answers the one row the composite id <parameter>IDPARAM</parameter> names as an object, and 404
/// <code>PORT.NOTFOUND</code> when none does; <parameter>IGNORETYPE</parameter> and <parameter>UNIGNORETYPE</parameter> set or
/// clear the flag of that row and answer <code>{}</code> at 200. Any other type is 501 <code>PORT.NOTIMPLEMENTED</code>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s.
/// <parameter>ENDPOINT</parameter> takes no body. Must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return (AD-16).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a security advisor call takes no body"), pFault.code)
            Quit
        }
        If pType = ..#LISTTYPE {
            Set tSC = ..Rows($Get(pQuery(..#MAXROWSPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#ROWTYPE {
            Set tSC = ..Row($Get(pQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pType '= ..#IGNORETYPE) && (pType '= ..#UNIGNORETYPE) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Control(pType, $Get(pQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in order through
/// <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names the first it lacks, or is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The rows, at most <var>pMax</var> of them (<parameter>DEFAULTMAXROWS</parameter> when it is empty), in <var>pRows</var> at
/// 200, in the order the page lists them: by type, then element, then code. A cap that is not a whole number above zero is 500.</p>
ClassMethod Rows(pMax As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tMax = $Select(pMax = "": ..#DEFAULTMAXROWS, 1: pMax)
    If '$Match(tMax, "^[1-9][0-9]*$") Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the list was asked for '" _ pMax _ "' rows"), .pHttpStatus, .pFault)
    Set tSC = ..Recommendations(.tRec)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set pRows = []
    Set tType = ""
    For {
        Set tType = $Order(tRec(tType))
        If (tType = "") || (pRows.%Size() >= tMax) Quit
        Set tElement = ""
        For {
            Set tElement = $Order(tRec(tType, tElement))
            If (tElement = "") || (pRows.%Size() >= tMax) Quit
            Set tCode = ""
            For {
                Set tCode = $Order(tRec(tType, tElement, "list", tCode), 1, tIgnored)
                If (tCode = "") || (pRows.%Size() >= tMax) Quit
                Do pRows.%Push(..Listed(tType, tElement, tCode, tIgnored))
            }
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one row the composite id <var>pKey</var> names, in <var>pRow</var> at 200, or 404 <code>PORT.NOTFOUND</code> for a
/// malformed id and a recommendation the instance does not list.</p>
ClassMethod Row(pKey As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Find(pKey, .tType, .tElement, .tCode, .tIgnored, .tFound, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tFound Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set pRow = ..Listed(tType, tElement, tCode, tIgnored)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the instance lists the recommendation the composite id <var>pKey</var> names, in <var>pFound</var>, with its
/// parts and whether it is ignored. A malformed id is not found. An error status is a list that could not be read, and is
/// answered as a 500.</p>
ClassMethod Find(pKey As %String, Output pType As %String, Output pElement As %String, Output pCode As %String, Output pIgnored As %Boolean, Output pFound As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set (pType, pElement, pCode) = ""
    Set pIgnored = 0
    Set pFound = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pKey)
    If $ListLength(tParts) '= 3 Quit $$$OK
    Set pType = $ListGet(tParts, 1)
    Set pElement = $ListGet(tParts, 2)
    Set pCode = $ListGet(tParts, 3)
    If (pType = "") || (pElement = "") || (pCode = "") Quit $$$OK
    Set tSC = ..Recommendations(.tRec)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If '$Data(tRec(pType, pElement, "list", pCode), tFlag) Quit $$$OK
    Set pFound = 1
    Set pIgnored = ''tFlag
    Quit $$$OK
}

/// <p>The row for a recommendation: its parts, the area and the sentence it is published as (the raw type or code where the
/// rosters name none) and <code>Ignored</code> as a boolean.</p>
ClassMethod Listed(pType As %String, pElement As %String, pCode As %String, pIgnored As %Boolean) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Type", pType _ "", "string")
    Do tRow.%Set("Area", ..Published(..#ADVISORAREAS, pType), "string")
    Do tRow.%Set("Element", pElement _ "", "string")
    Do tRow.%Set("Code", pCode _ "", "string")
    Do tRow.%Set("Recommendation", ..Published(..#ADVISORTEXTS, pCode), "string")
    Do tRow.%Set("Ignored", ''pIgnored, "boolean")
    Quit tRow
}

/// <p>The value <var>pKey</var> maps to in <var>pRoster</var>, entries <code>key=value</code> joined by <code>|</code>, or
/// <var>pKey</var> itself when the roster has no such entry.</p>
ClassMethod Published(pRoster As %String, pKey As %String) As %String [ Private ]
{
    For tI = 1:1:$Length(pRoster, "|") {
        Set tEntry = $Piece(pRoster, "|", tI)
        If $Piece(tEntry, "=", 1) = pKey Quit
    }
    If $Piece(tEntry, "=", 1) '= pKey Quit pKey _ ""
    Quit $Piece(tEntry, "=", 2, *)
}

/// <p>Carry out write type <var>pType</var> on the recommendation the composite id <var>pKey</var> names, read fresh here: a
/// malformed id and a recommendation the instance no longer lists are 404 <code>PORT.NOTFOUND</code>; an ignore of an ignored
/// recommendation is 409 <code>ADVISOR.IGNORED</code> and a stop of one that is not ignored is 409
/// <code>ADVISOR.NOTIGNORED</code>, each before the flag is touched. The page's method reports no failure, so the flag is read
/// again, and a flag that did not take the new state is 500.</p>
ClassMethod Control(pType As %String, pKey As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Find(pKey, .tType, .tElement, .tCode, .tIgnored, .tFound, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tFound Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tIgnore = (pType = ..#IGNORETYPE)
    If tIgnore && tIgnored Quit ..StateRefusal(##class(OcuPilot.Api.AdvisorError).#IGNORED, .pHttpStatus, .pFault)
    If 'tIgnore && 'tIgnored Quit ..StateRefusal(##class(OcuPilot.Api.AdvisorError).#NOTIGNORED, .pHttpStatus, .pFault)
    Set tSC = ..SetFlag(tType, tElement, tCode, tIgnore)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set tSC = ..Find(pKey, .tType, .tElement, .tCode, .tAfter, .tFound, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tFound || (tAfter '= tIgnore) Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the recommendation's ignore flag did not change"), .pHttpStatus, .pFault)
    Set pResult = {}
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The 409 <var>pCode</var> of <class>OcuPilot.Api.AdvisorError</class> on its published sentence.</p>
ClassMethod StateRefusal(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.AdvisorError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in <code>detail.failedPair</code> (AD-8,
/// AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The page's recommendations as <code>pRecommend(&lt;type&gt;, &lt;element&gt;, "list", &lt;code&gt;) = &lt;ignored&gt;</code>,
/// <code>1</code> for an ignored recommendation and <code>""</code> otherwise: <parameter>PANECLASS</parameter>'s
/// <code>GetRecommendations</code>, called in <code>%SYS</code> by save and restore (AD-16). The page's other nodes are
/// dropped. A failed read is an error status.</p>
ClassMethod Recommendations(Output pRecommend) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pRecommend
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#PANECLASS, "GetRecommendations", .tRec)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        Set tType = ""
        For {
            Set tType = $Order(tRec(tType))
            If tType = "" Quit
            Set tElement = ""
            For {
                Set tElement = $Order(tRec(tType, tElement))
                If tElement = "" Quit
                Set tCode = ""
                For {
                    Set tCode = $Order(tRec(tType, tElement, "list", tCode), 1, tFlag)
                    If tCode = "" Quit
                    Set pRecommend(tType, tElement, "list", tCode) = ''tFlag
                }
            }
        }
    } Catch ex {
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        Kill pRecommend
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the ignore flag of the recommendation <var>pType</var>, <var>pElement</var>, <var>pCode</var> to <var>pFlag</var>
/// through <parameter>PANECLASS</parameter>'s <code>SetIgnoreFlag</code>, in <code>%SYS</code> by save and restore (AD-16),
/// with the null device current: the method writes a line of JavaScript to the current device, which in a request is the
/// response. The status is the call's own failure, if it raised one; the method reports none for a flag it could not store.</p>
/// <p>The process is left as it was found. The null device is opened only when the process does not hold it, and closed only
/// when this method opened it. The caller's device, with its mnemonic space and output redirection, is restored on every path,
/// a raise included.</p>
ClassMethod SetFlag(pType As %String, pElement As %String, pCode As %String, pFlag As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tDevice = $IO
    Set tMnemonic = ##class(%Library.Device).GetMnemonicRoutine()
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set (tOpened, tSwitched) = 0
    Set tRedirected = ##class(%Library.Device).ReDirectIO(0)
    Try {
        If $Piece(tDevice, ":", 1) '= tNull {
            If '##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull) {
                Open tNull::1
                If '$Test {
                    Set tSC = $$$ERROR($$$GeneralError, "the null device could not be opened")
                    Quit
                }
                Set tOpened = 1
            }
            Use tNull
            Set tSwitched = 1
        }
        Set $NAMESPACE = "%SYS"
        Do $ClassMethod(..#PANECLASS, "SetIgnoreFlag", pType, pElement, pCode, $Select(pFlag: 1, 1: 0), "")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tSwitched {
        If tMnemonic '= "" {
            Use tDevice::("^" _ tMnemonic)
        } Else {
            Use tDevice
        }
    }
    If tOpened Close tNull
    Do ##class(%Library.Device).ReDirectIO(tRedirected)
    Quit tSC
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for a write type of
/// <parameter>ENDPOINT</parameter>; the admin port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINT) && ((pType = ..#IGNORETYPE) || (pType = ..#UNIGNORETYPE)) Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s write as a script (AD-59): <parameter>PANECLASS</parameter>'s <code>SetIgnoreFlag</code> for the
/// type, element and code the composite id names, in <code>%SYS</code>. A malformed id answers no step. Every other call is the
/// admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#ENDPOINT) || ((pType '= ..#IGNORETYPE) && (pType '= ..#UNIGNORETYPE)) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDPARAM)))
    If $ListLength(tParts) '= 3 Quit []
    Set tCall = "Do ##class(" _ ..#PANECLASS _ ").SetIgnoreFlag(" _ ..Literal($List(tParts, 1)) _ ", " _ ..Literal($List(tParts, 2)) _ ", " _ ..Literal($List(tParts, 3)) _ ", " _ $Select(pType = ..#IGNORETYPE: 1, 1: 0) _ ", """")"
    Quit [(..ObjectScriptStep($ListBuild(tCall)))]
}

}
