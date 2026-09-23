/// <p>The wallet secret form's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.WalletSecretCreate</class> and
/// <class>OcuPilot.Screen.Tool.WalletSecretUpdate</class> applies (<method>Validate</method>), the
/// form's read (<method>HandleForm</method>) and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording. No
/// sentence quotes a value, and the rules read the value's length alone (AD-35).</p>
Class OcuPilot.Area.Security.WalletRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up and
/// a collection's existence, the edit for a present secret's read.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.WalletSecretCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WalletSecretUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretForm";

/// <p>The endpoint a collection's existence is read from, through the create tool's port.</p>
Parameter COLLECTIONENDPOINT = "Wallet.Collection";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Secret";

/// <p>The longest full name <class>%Wallet.Secret</class> stores (its <code>Name</code>'s
/// <code>MAXLEN</code> on this build), the longest value the form accepts, the longest allowed host,
/// and the highest <code>Usage</code>, every use added together.</p>
Parameter NAMEMAXLENGTH As INTEGER = 128;

Parameter SECRETMAXLENGTH As INTEGER = 32768;

Parameter HOSTMAXLENGTH As INTEGER = 255;

Parameter USAGEMAX As INTEGER = 15;

/// <p>The one secret type the form edits.</p>
Parameter KEYVALUETYPE = "%Wallet.KeyValue";

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDSECRET = "Secret";

Parameter FIELDUSAGE = "Usage";

Parameter FIELDREQUIRETLS = "RequireTLS";

Parameter FIELDALLOWEDHOSTS = "AllowedHosts";

Parameter FIELDTYPE = "Type";

/// <p>Every rule a wallet secret write applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pCheckName</var> 0 skips the name's own rules and its collection's existence, for an
/// edit, whose name is the present secret's; <var>pCheckTaken</var> 0 skips the look-up, for an
/// edit and for the agent's mint, which has read the target itself; <var>pCheckSecret</var> 0 makes
/// the value optional, for an edit and for the agent's mint, whose value arrives at confirm. A value
/// that is supplied is held to its length whatever <var>pCheckSecret</var> says.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pCheckName As %Boolean = 1, pCheckTaken As %Boolean = 1, pCheckSecret As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If pCheckName {
            Do ..NameViolation(pName, .pViolations)
            If pViolations = 0 {
                Set tSC = ..CollectionPresent($Piece(pName, ".", 1), .tPresent)
                If $$$ISERR(tSC) Quit
                If 'tPresent Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT)
            }
        }
        If (pViolations = 0) && pCheckTaken {
            Set tSC = ..Taken(pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#WALLETNAMETAKEN)
        }
        If '$IsObject(pArgs) Quit

        Set tType = pArgs.%GetTypeOf(..#FIELDSECRET)
        If (tType = "unassigned") || (tType = "null") || ((tType = "string") && (pArgs.%Get(..#FIELDSECRET) = "")) {
            If pCheckSecret Do ..Add(.pViolations, ..#FIELDSECRET, ##class(OcuPilot.Api.Error).#WALLETSECRETREQUIRED)
        } ElseIf tType '= "string" {
            Do ..Add(.pViolations, ..#FIELDSECRET, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        } ElseIf $Length(pArgs.%Get(..#FIELDSECRET)) > ..#SECRETMAXLENGTH {
            Do ..Add(.pViolations, ..#FIELDSECRET, ##class(OcuPilot.Api.Error).#WALLETSECRETLENGTH)
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDUSAGE)
        If tType '= "unassigned" {
            Set tUsage = pArgs.%Get(..#FIELDUSAGE)
            If (tType '= "number") || (tUsage '= (tUsage \ 1)) || (tUsage < 0) || (tUsage > ..#USAGEMAX) {
                Do ..Add(.pViolations, ..#FIELDUSAGE, ##class(OcuPilot.Api.Error).#WALLETUSAGERANGE)
            }
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDREQUIRETLS)
        If (tType '= "unassigned") && (tType '= "boolean") {
            Do ..Add(.pViolations, ..#FIELDREQUIRETLS, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDALLOWEDHOSTS)
        If tType '= "unassigned" {
            Set tShape = (tType = "array")
            If tShape {
                Set tHosts = pArgs.%Get(..#FIELDALLOWEDHOSTS)
                Set tItems = tHosts.%GetIterator()
                While tItems.%GetNext(.tIndex, .tHost) {
                    If '..HostUsable(tHosts.%GetTypeOf(tIndex), tHost) Set tShape = 0 Quit
                }
            }
            If 'tShape Do ..Add(.pViolations, ..#FIELDALLOWEDHOSTS, ##class(OcuPilot.Api.Error).#WALLETALLOWEDHOSTSSHAPE)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether one allowed host, of JSON type <var>pType</var>, is usable: a string that is not
/// empty, at most <parameter>HOSTMAXLENGTH</parameter> characters, and holds no whitespace and no
/// comma.</p>
ClassMethod HostUsable(pType As %String, pHost) As %Boolean [ Private ]
{
    If pType '= "string" Quit 0
    If (pHost = "") || ($Length(pHost) > ..#HOSTMAXLENGTH) Quit 0
    If pHost [ "," Quit 0
    Quit '$Locate(pHost, "\s")
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, one longer
/// than <parameter>NAMEMAXLENGTH</parameter>, and one that is not a collection's name, a dot and a
/// secret name of letters, digits, dots, hyphens and underscores. A name is compared exactly, case
/// included, so nothing here folds it.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#WALLETNAMEREQUIRED)
        Quit
    }
    If $Length(pName) > ..#NAMEMAXLENGTH {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#WALLETNAMELENGTH)
        Quit
    }
    If ($Piece(pName, ".", 1) = "") || '$Match($Piece(pName, ".", 2, *), "[A-Za-z0-9._-]+") {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#WALLETNAMESHAPE)
    }
}

/// <p>Answer <code>GET /wallet/secret/form[?name=&lt;n&gt;|?collection=&lt;c&gt;]</code>: everything
/// the form needs before it can draw a field (AD-39): <code>{requiredFields, maxLengths, rules}</code>.
/// With a name it adds <code>secret: {Name, Collection, Type, Usage, RequireTLS, AllowedHosts,
/// editable}</code>, read through the edit tool's own port, which never reads a value; a secret of
/// another type carries its <code>Name</code>, <code>Collection</code> and <code>Type</code> alone,
/// with <code>editable</code> false. With a collection it adds <code>collection</code> once that
/// collection is found. An absent name is 404
/// <parameter>OcuPilot.Api.Error.WALLETNAMEABSENT</parameter>, and an absent collection 404
/// <parameter>OcuPilot.Api.Error.WALLETCOLLECTIONABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDNAME, ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDSECRET, ..#SECRETMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Set tName = $Get(%request.Data("name", 1))
        Set tCollection = $Get(%request.Data("collection", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tSecret = {}
            Do tSecret.%Set(..#FIELDNAME, tName, "string")
            Do tSecret.%Set("Collection", $Piece(tName, ".", 1), "string")
            Do tSecret.%Set(..#FIELDTYPE, tFresh.%Get(..#FIELDTYPE), "string")
            Set tEditable = (tFresh.%Get(..#FIELDTYPE) = ..#KEYVALUETYPE)
            If tEditable {
                Do tSecret.%Set(..#FIELDUSAGE, tFresh.%Get(..#FIELDUSAGE), "number")
                Do tSecret.%Set(..#FIELDREQUIRETLS, ''tFresh.%Get(..#FIELDREQUIRETLS), "boolean")
                Do tSecret.%Set(..#FIELDALLOWEDHOSTS, $Select(tFresh.%GetTypeOf(..#FIELDALLOWEDHOSTS) = "array": tFresh.%Get(..#FIELDALLOWEDHOSTS), 1: []))
            }
            Do tSecret.%Set("editable", tEditable, "boolean")
            Do tBody.%Set("secret", tSecret)
        } ElseIf tCollection '= "" {
            Set tPresentSC = ..CollectionPresent(tCollection, .tPresent)
            If $$$ISERR(tPresentSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPresentSC))
                Quit
            }
            If 'tPresent {
                Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONWALLETCOLLECTIONABSENT, ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT)
                Quit
            }
            Do tBody.%Set("collection", tCollection, "string")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /wallet/secret/name?name=&lt;n&gt;</code>: whether that full name is taken,
/// compared exactly, in <code>{name, taken, reason}</code>. A name that breaks its own rules is the
/// 422 envelope for that rule; a look-up that cannot be made is a refusal envelope, never an
/// assertion that the name is free.</p>
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
        Kill tViolations
        Set tViolations = 0
        Do ..NameViolation(tName, .tViolations)
        If tViolations > 0 {
            Set tSC = ##class(OcuPilot.Area.Security.WalletSave).RenderViolations(.tViolations)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#WALLETNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a secret already carries exactly <var>pName</var>, in <var>pTaken</var>, read through
/// the create tool's own port, endpoint and read type (AD-52).</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>Whether the wallet collection <var>pCollection</var> exists, in <var>pPresent</var>, read from
/// <parameter>COLLECTIONENDPOINT</parameter>'s <code>GET</code> through the create tool's own port.
/// An error status means the question was not answered; only a 404 is "absent".</p>
ClassMethod CollectionPresent(pCollection As %String, Output pPresent As %Boolean) As %Status
{
    Set pPresent = 0
    If pCollection = "" Quit $$$OK
    Kill tQuery
    Set tQuery("name") = pCollection
    Set tSC = $ClassMethod($ClassMethod(..#CREATETOOL, "PortClass"), "Invoke", ..#COLLECTIONENDPOINT, "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pPresent = ($IsObject($Get(tAnswer)) && tAnswer.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present secret <var>pName</var>, read through the edit tool's own port, endpoint and read
/// type (AD-52), in <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var>
/// 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: an absent collection as
/// <parameter>OcuPilot.Api.Error.WALLETCOLLECTIONABSENT</parameter>, any other 404 as
/// <parameter>OcuPilot.Api.Error.WALLETNAMEABSENT</parameter>, any other refusal as the port's own
/// envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        If $IsObject($Get(pFault)) && (pFault.code = ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT) {
            Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONWALLETCOLLECTIONABSENT, ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT)
        }
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONWALLETNAMEABSENT, ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read
/// type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).WalletViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>WALLET.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String [ Private ]
{
    Set tPart = $Piece(pCode, ".", 2)
    If (tPart = "NAME") || (tPart = "COLLECTION") Quit ..#FIELDNAME
    If tPart = "SECRET" Quit ..#FIELDSECRET
    If tPart = "USAGE" Quit ..#FIELDUSAGE
    If tPart = "ALLOWEDHOSTS" Quit ..#FIELDALLOWEDHOSTS
    If tPart = "TYPE" Quit ..#FIELDTYPE
    Quit ""
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
