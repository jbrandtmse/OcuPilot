/// <p>The mobile phone provider port (AD-29, AD-52, AD-53, AD-54, AD-58, Story 21.10): the one product class that lists the
/// instance's mobile phone providers, reads one, creates one, changes its SMS gateway and deletes it, over the vendor's
/// <code>%SYS.PhoneProviders</code>. It switches <code>$NAMESPACE</code> to <code>%SYS</code> by save and restore around
/// each vendor call (AD-16).</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter> for a read, <parameter>WRITEPAIRS</parameter> for
/// a write, evaluated through <method>GateClass</method> in the calling process before any vendor call. A caller missing
/// one is refused 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>.</p>
/// <p><b>Endpoint and request types.</b> <parameter>ENDPOINT</parameter>: <code>LIST</code> (the vendor's <code>List</code>
/// query, <code>{Name, SMSGateway}</code> per row, capped), <code>GET</code> (one provider, its id the query's
/// <code>name</code>, compared exactly), <code>CREATE</code> and <code>SET</code> (the body names <code>SMSGateway</code>
/// and nothing else) and <code>DELETE</code> (no body). A <code>GET</code> is the fresh read of the write tools (AD-51).</p>
/// <p><b>Every write is judged before any vendor call.</b> A name or a gateway that
/// <class>OcuPilot.Area.Security.PhoneProviderRules</class> refuses is 400 <code>PORT.VALIDATION</code>; a provider that is
/// absent is 404 <code>PHONEPROVIDER.NOTFOUND</code>, and a create under a name that exists is 409
/// <code>PHONEPROVIDER.TAKEN</code>. <b>A delete first counts the users that name the provider</b>, by the vendor's own
/// predicate (<method>UsersNaming</method>), which compares without regard to case, as the vendor's refusal does, though a
/// provider is found by its exact name; a count above zero is 409 <code>PHONEPROVIDER.INUSE</code> and nothing is sent.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method> and <method>LogFault</method>. Production overrides
/// neither.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on
/// return.</p>
Class OcuPilot.Port.PhoneProviderPort Extends %RegisteredObject
{

/// <p>The pair set every read requires, comma-separated as <code>resource:permission</code>, in the order the gate
/// reports in (AD-8, AD-29).</p>
Parameter PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

/// <p>The pair set every write requires: the same two, which the vendor's <code>Create</code>, <code>Modify</code> and
/// <code>Delete</code> were measured to need.</p>
Parameter WRITEPAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The vendor class this port reads and writes.</p>
Parameter VENDORCLASS = "%SYS.PhoneProviders";

/// <p>The endpoint, and the one a screen's declared read lists.</p>
Parameter ENDPOINT = "PhoneProviders";

Parameter ENDPOINTS = "PhoneProviders";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPECREATE = "CREATE";

Parameter TYPESET = "SET";

Parameter TYPEDELETE = "DELETE";

/// <p>The write request types.</p>
Parameter WRITETYPES = "CREATE,SET,DELETE";

/// <p>The query keys: the provider named, and the rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter MAXROWSKEY = "maxRows";

/// <p>The one body member a create or a set carries, and the name member a merge write's body repeats from its fresh read.</p>
Parameter GATEWAYFIELD = "SMSGateway";

Parameter NAMEFIELD = "Name";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The vendor's refusal of a provider that does not exist (#1414) and of a delete while users name it (#1447).</p>
Parameter CODENOTFOUND = 1414;

Parameter CODEINUSE = 1447;

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "phoneproviderport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONBODY = "The body names the SMS gateway, and the provider's own name, and nothing else.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process;
/// production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line;
/// production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The pairs <var>pSpec</var> names as the <code>%List</code> the gate evaluates.</p>
ClassMethod Pairs(pSpec As %String) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(pSpec)
}

/// <p>Whether <var>pType</var> is one of <parameter>WRITETYPES</parameter>.</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#WRITETYPES), pType)
}

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint '= ..#ENDPOINT Quit 0
    Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || ..IsWrite(pType)
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A <code>LIST</code> answers <var>pResult</var> as an array of rows (at most <parameter>DEFAULTMAXROWS</parameter>
/// unless <var>pQuery</var> carries <parameter>MAXROWSKEY</parameter>); a <code>GET</code>, <code>CREATE</code> and
/// <code>SET</code> answer one provider as <code>{Name, SMSGateway}</code>; a <code>DELETE</code> answers
/// <code>{Name}</code>. A read takes no body, a <code>DELETE</code> takes none, and a <code>CREATE</code> and a
/// <code>SET</code> take the one member <parameter>GATEWAYFIELD</parameter>.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and <var>pFault</var>
/// the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; 400 <code>PORT.VALIDATION</code> for a cap, a body or
/// a value of the wrong shape; each <code>PHONEPROVIDER.*</code> refusal on the status
/// <class>OcuPilot.Api.PhoneProviderError</class> names; and 500 <code>INTERNAL</code>, logged, for any other
/// failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(pType, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tBodyTaken = (pType = ..#TYPECREATE) || (pType = ..#TYPESET)
        If 'tBodyTaken && ($IsObject(pBody) || (pBody '= "")) {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a phone provider read or delete takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
            Set tSC = ..Listing(tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $Get(pQuery(..#NAMEKEY))
        If pType = ..#TYPEGET Set tSC = ..ProviderState(tName, .pResult, .pHttpStatus, .pFault)
        If pType = ..#TYPECREATE Set tSC = ..Create(tName, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = ..#TYPESET Set tSC = ..Change(tName, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = ..#TYPEDELETE Set tSC = ..Remove(tName, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>The rows of the list, after the read gate, at most <var>pMax</var> of them: the call the screen's and the read
/// tool's reads are issued through (AD-36). <var>pCut</var> is always 0, the port leaving no row out itself. Otherwise
/// <method>Invoke</method>'s answers.</p>
ClassMethod Rows(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pCut = 0
    Set tSC = ..Admit(..#TYPELIST, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Listing(pMax, .pRows, .pHttpStatus, .pFault)
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The gate: <parameter>WRITEPAIRS</parameter> for a write type, otherwise <parameter>PAIRS</parameter>.</p>
ClassMethod Admit(pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs($Select(..IsWrite(pType): ..#WRITEPAIRS, 1: ..#PAIRS)), .tFailedPair) Quit $$$OK
    Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
}

/// <p>The vendor's providers as <code>{Name, SMSGateway}</code>, at most <var>pMax</var> of them.</p>
ClassMethod Listing(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Set pHttpStatus = 200
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(..#VENDORCLASS _ ":List")
        Set tSC = tRS.Execute()
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If pRows.%Size() >= pMax Quit
            Set tRow = {}
            Do tRow.%Set("Name", tRS.GetData(1), "string")
            Do tRow.%Set(..#GATEWAYFIELD, tRS.GetData(2), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) {
        Set pRows = ""
        Quit ..Fail("the mobile phone providers could not be read", tSC, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The provider <var>pName</var>, found by its exact name, as <code>{Name, SMSGateway}</code> in
/// <var>pState</var>. A name the instance does not hold is 404 <code>PHONEPROVIDER.NOTFOUND</code>.</p>
ClassMethod ProviderState(pName As %String, Output pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pState = ""
    Set tSC = ..Lookup(pName, .tFound, .tGateway)
    If $$$ISERR(tSC) Quit ..Fail("the mobile phone provider could not be read", tSC, .pHttpStatus, .pFault)
    If 'tFound Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#NOTFOUND, .pHttpStatus, .pFault)
    Set pState = {}
    Do pState.%Set("Name", pName, "string")
    Do pState.%Set(..#GATEWAYFIELD, tGateway, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the instance holds a provider under exactly <var>pName</var>, in <var>pFound</var>, with its SMS gateway in
/// <var>pGateway</var>. A vendor failure other than the provider's being absent is the status.</p>
ClassMethod Lookup(pName As %String, Output pFound As %Boolean, Output pGateway As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pFound = 0
    Set pGateway = ""
    If pName = "" Quit $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(%SYS.PhoneProviders).Exists(pName, .tProvider, .tVendor)
        If tExists {
            Set pFound = 1
            Set pGateway = tProvider.SMSGateway
        } ElseIf '$ListFind($ListFromString($System.Status.GetErrorCodes(tVendor)), ..#CODENOTFOUND) {
            Set tSC = tVendor
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The number of users that name the provider <var>pName</var> for two-factor text messages, in <var>pCount</var>: the users
/// whose <code>PhoneProvider</code> equals the name without regard to case, which is the vendor's own predicate
/// (<code>PhoneProvider = :Name</code> over <code>Security.Users</code>). The users are read through the vendor's
/// <code>Security.Users:Detail</code> query, which a caller holding this port's pairs can run; the table itself needs a read of the
/// security database that no role can hold.</p>
ClassMethod UsersNaming(pName As %String, Output pCount As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCount = 0
    Set tKey = $ZConvert(pName, "U")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Users:Detail")
        Set tSC = tRS.Execute("*", "*", "*", 0)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            If $ZConvert(tRS.Get("PhoneProvider"), "U") = tKey Set pCount = pCount + 1
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create the provider <var>pName</var> with the SMS gateway <var>pBody</var> names: both are judged, an existing name is
/// 409 <code>PHONEPROVIDER.TAKEN</code>, and the answer is the provider as the instance now holds it.</p>
ClassMethod Create(pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..JudgeWrite(pName, pBody, 1, .tGateway, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Lookup(pName, .tFound, .tHeld)
    If $$$ISERR(tSC) Quit ..Fail("the mobile phone provider could not be read", tSC, .pHttpStatus, .pFault)
    If tFound Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#TAKEN, .pHttpStatus, .pFault)
    Set tVendor = ..VendorWrite(pName, tGateway, 1)
    If $$$ISERR(tVendor) Quit ..Fail("the mobile phone provider was not created", tVendor, .pHttpStatus, .pFault)
    Quit ..ProviderState(pName, .pResult, .pHttpStatus, .pFault)
}

/// <p>Change the SMS gateway of the provider <var>pName</var>: both are judged, an absent provider is 404
/// <code>PHONEPROVIDER.NOTFOUND</code>, and the answer is the provider as the instance now holds it.</p>
ClassMethod Change(pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..JudgeWrite(pName, pBody, 0, .tGateway, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Lookup(pName, .tFound, .tHeld)
    If $$$ISERR(tSC) Quit ..Fail("the mobile phone provider could not be read", tSC, .pHttpStatus, .pFault)
    If 'tFound Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tVendor = ..VendorWrite(pName, tGateway, 0)
    If $$$ISERR(tVendor) Quit ..Fail("the mobile phone provider was not changed", tVendor, .pHttpStatus, .pFault)
    Quit ..ProviderState(pName, .pResult, .pHttpStatus, .pFault)
}

/// <p>Delete the provider <var>pName</var>: an absent provider is 404 <code>PHONEPROVIDER.NOTFOUND</code>; users that
/// name it are 409 <code>PHONEPROVIDER.INUSE</code>, counted before any vendor call. The vendor's own refusal of the same
/// state, reached when a user is given the provider between the count and the call, is answered on the same code. Answers
/// <code>{Name}</code>.</p>
ClassMethod Remove(pName As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..Lookup(pName, .tFound, .tHeld)
    If $$$ISERR(tSC) Quit ..Fail("the mobile phone provider could not be read", tSC, .pHttpStatus, .pFault)
    If 'tFound Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..UsersNaming(pName, .tCount)
    If $$$ISERR(tSC) Quit ..Fail("the users naming the provider could not be counted", tSC, .pHttpStatus, .pFault)
    If tCount > 0 Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#INUSE, .pHttpStatus, .pFault)
    Set tVendor = ..VendorDelete(pName)
    If $$$ISERR(tVendor) {
        If $ListFind($ListFromString($System.Status.GetErrorCodes(tVendor)), ..#CODEINUSE) Quit ..Refused(##class(OcuPilot.Api.PhoneProviderError).#INUSE, .pHttpStatus, .pFault)
        Quit ..Fail("the mobile phone provider was not deleted", tVendor, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The judgement every <code>CREATE</code> and <code>SET</code> passes before any vendor call: the body is an object
/// that names <parameter>GATEWAYFIELD</parameter> as text and nothing else, and the name and the gateway pass
/// <class>OcuPilot.Area.Security.PhoneProviderRules</class>. The gateway is <var>pGateway</var>. A refusal is 400
/// <code>PORT.VALIDATION</code> and names each field with its sentence.</p>
ClassMethod JudgeWrite(pName As %String, pBody As %DynamicAbstractObject, pCreate As %Boolean, Output pGateway As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pGateway = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf(..#GATEWAYFIELD) '= "string") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONBODY, .pHttpStatus, .pFault)
    Set tOther = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey '= ..#GATEWAYFIELD) && ((tKey '= ..#NAMEFIELD) || (tValue '= pName)) Set tOther = 1
    }
    If tOther Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONBODY, .pHttpStatus, .pFault)
    Set tSC = ##class(OcuPilot.Area.Security.PhoneProviderRules).Problem(pName, pBody, "", $Select(pCreate: "create", 1: "update"), $ClassName(), .tProblem, 1)
    If $$$ISERR(tSC) Quit ..Fail("the mobile phone provider's fields could not be judged", tSC, .pHttpStatus, .pFault)
    If (tProblem = "") && 'pCreate && '##class(OcuPilot.Area.Security.PhoneProviderRules).IsName(pName) {
        Set tProblem = "'Name': " _ ##class(OcuPilot.Api.PhoneProviderError).#REASONNAME
    }
    If (tProblem = "") && (pBody.%Get(..#GATEWAYFIELD) = "") Set tProblem = "'" _ ..#GATEWAYFIELD _ "': " _ ##class(OcuPilot.Api.PhoneProviderError).#REASONGATEWAY
    If tProblem '= "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, tProblem, .pHttpStatus, .pFault)
    Set pGateway = pBody.%Get(..#GATEWAYFIELD)
    Quit $$$OK
}

/// <p>The vendor's <code>Create</code> of <var>pName</var> when <var>pCreate</var> is 1, otherwise its <code>Modify</code>,
/// with <var>pGateway</var> as <code>SMSGateway</code>, in <code>%SYS</code> by save and restore.</p>
ClassMethod VendorWrite(pName As %String, pGateway As %String, pCreate As %Boolean) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps(..#GATEWAYFIELD) = pGateway
        If pCreate {
            Set tVendor = ##class(%SYS.PhoneProviders).Create(pName, .tProps)
        } Else {
            Set tVendor = ##class(%SYS.PhoneProviders).Modify(pName, .tProps)
        }
    } Catch ex {
        Set tVendor = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tVendor
}

/// <p>The vendor's <code>Delete</code> of <var>pName</var>, in <code>%SYS</code> by save and restore.</p>
ClassMethod VendorDelete(pName As %String) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tVendor = ##class(%SYS.PhoneProviders).Delete(pName)
    } Catch ex {
        Set tVendor = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tVendor
}

/// <p>The 403 the gate answers, <code>AUTH.NOPRIVILEGE</code> with the pair in <code>detail.failedPair</code> (AD-8,
/// AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>A refusal this port decided, with a written reason (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.PhoneProviderError</class>, on the status and slug that class
/// names and with its sentence. Nothing is logged: a refusal is an answer, not a fault.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Refuse(##class(OcuPilot.Api.PhoneProviderError).HttpStatusFor(pCode), ##class(OcuPilot.Api.PhoneProviderError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.PhoneProviderError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for each write; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ..IsWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    Quit ""
}

/// <p>The write as a script (AD-59), in <code>%SYS</code>: <code>%SYS.PhoneProviders</code>' <code>Create</code> or
/// <code>Modify</code> with the SMS gateway as the one property, a create gated on one line by a free-name check, or its
/// <code>Delete</code>, which refuses a provider that users name, as the port's own count does; each step shows its status. A value is a string literal, so nothing the query or the body carries runs as
/// code.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tName = $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY)))
    Set tShow = "Do $System.Status.DisplayError(tSC)"
    If pType = ..#TYPEDELETE Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild("Set tSC = ##class(" _ ..#VENDORCLASS _ ").Delete(" _ tName _ ")", tShow)))]
    Set tGateway = $Select($IsObject(pBody) && (pBody.%GetTypeOf(..#GATEWAYFIELD) = "string"): pBody.%Get(..#GATEWAYFIELD), 1: "")
    Set tLines = $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", ..#GATEWAYFIELD) _ ") = " _ $ClassMethod(tAdmin, "Literal", tGateway))
    If pType = ..#TYPECREATE {
        Set tLines = tLines _ $ListBuild("Set tSC = $System.Status.Error(5001, " _ $ClassMethod(tAdmin, "Literal", ##class(OcuPilot.Api.PhoneProviderError).#REASONTAKEN) _ ")")
        Set tLines = tLines _ $ListBuild("If '##class(" _ ..#VENDORCLASS _ ").Exists(" _ tName _ ") Set tSC = ##class(" _ ..#VENDORCLASS _ ").Create(" _ tName _ ", .tProps)")
    } Else {
        Set tLines = tLines _ $ListBuild("Set tSC = ##class(" _ ..#VENDORCLASS _ ").Modify(" _ tName _ ", .tProps)")
    }
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines _ $ListBuild(tShow)))]
}

}
