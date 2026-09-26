/// <p>The device editor's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.DeviceCreate</class> and <class>OcuPilot.Screen.Tool.DeviceUpdate</class>
/// applies (<method>Validate</method>), the form's read (<method>HandleForm</method>) and the name
/// look-up (<method>HandleName</method>, <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording.</p>
/// <p><b>The rules are where the vendor's gaps are closed.</b> The instance accepts a type of any two
/// or three characters, a duplicate alias, a fractional alias it then truncates, and a <code>^</code>
/// in any field, which it writes raw into its configuration file; each is refused here, on both
/// callers, before the port is touched.</p>
Class OcuPilot.Area.OsMgmt.DeviceRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up, the
/// edit for a present device's read.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.DeviceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DeviceUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DeviceForm";

/// <p>The endpoint whose list is the instance's subtypes.</p>
Parameter SUBTYPEENDPOINT = "Device.SubType";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,PhysicalDevice,Type,SubType";

/// <p>The device's eight settable fields, in the classic page's order.</p>
Parameter FIELDS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

/// <p>The six types the classic device page offers, in its order.</p>
Parameter TYPEVALUES = "TRM,SPL,MT,BT,IPC,OTH";

/// <p>The longest values <class>Config.Devices</class> stores: its <code>MAXLEN</code>s on this
/// build.</p>
Parameter NAMEMAXLENGTH As INTEGER = 64;

Parameter FIELDMAXLENGTH As INTEGER = 128;

Parameter DESCRIPTIONMAXLENGTH As INTEGER = 256;

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDPHYSICALDEVICE = "PhysicalDevice";

Parameter FIELDTYPE = "Type";

Parameter FIELDSUBTYPE = "SubType";

Parameter FIELDOPENPARAMETERS = "OpenParameters";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDALIAS = "Alias";

Parameter FIELDALTERNATEDEVICE = "AlternateDevice";

Parameter FIELDPROMPT = "Prompt";

/// <p>Every rule a device write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's own rules and requires the physical
/// device name, the type and the subtype; <code>update</code> skips the name, which is the present
/// device's, and refuses a required field only when <var>pArgs</var> empties it. On an update
/// <var>pArgs</var> is the fields the caller changes (<method>Changed</method>) and <var>pFresh</var>
/// the device as read, which supplies the other half of the alias's comparison with the physical
/// device name. <var>pCheckTaken</var> 0 skips the name look-up, for the agent's mint, which has read
/// the target itself.</p>
/// <p>The subtype and the alias are checked against the instance: the subtype against the vendor's
/// own subtype list, and the alias against every other device's, both read through the create tool's
/// port. A read that fails is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tCreates = (pMode = "create")
        If tCreates Do ..NameViolation(pName, .pViolations)
        If tCreates && (pViolations = 0) && pCheckTaken {
            Set tSC = ..Taken(pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#DEVICENAMETAKEN)
        }
        If '$IsObject(pArgs) Set pArgs = {}

        For tI = 1:1:$Length(..#FIELDS, ",") {
            Set tField = $Piece(..#FIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If tType = "unassigned" {
                If tCreates && $ListFind($ListBuild(..#FIELDPHYSICALDEVICE, ..#FIELDTYPE, ..#FIELDSUBTYPE), tField) Do ..Add(.pViolations, tField, ..Code(tField, "REQUIRED"))
                Continue
            }
            Set tValue = ..Text(pArgs, tField)
            If tField = ..#FIELDPHYSICALDEVICE {
                If tValue = "" {
                    Do ..Add(.pViolations, tField, ..Code(tField, "REQUIRED"))
                } ElseIf $Length(tValue) > ..#FIELDMAXLENGTH {
                    Do ..Add(.pViolations, tField, ..Code(tField, "LENGTH"))
                } ElseIf '..Writable(tValue) {
                    Do ..Add(.pViolations, tField, ..Code(tField, "SHAPE"))
                }
            } ElseIf tField = ..#FIELDTYPE {
                If tValue = "" {
                    Do ..Add(.pViolations, tField, ..Code(tField, "REQUIRED"))
                } ElseIf '$ListFind($ListFromString(..#TYPEVALUES), tValue) {
                    Do ..Add(.pViolations, tField, ..Code(tField, "VALUE"))
                }
            } ElseIf tField = ..#FIELDSUBTYPE {
                If tValue = "" {
                    Do ..Add(.pViolations, tField, ..Code(tField, "REQUIRED"))
                } Else {
                    Set tSC = ..SubTypes(.tSubTypes)
                    If $$$ISERR(tSC) Quit
                    If '$ListFind(tSubTypes, tValue) Do ..Add(.pViolations, tField, ..Code(tField, "ABSENT"))
                }
            } ElseIf tField = ..#FIELDALIAS {
                If tValue = "" Continue
                If '..WholeNumber(tValue) {
                    Do ..Add(.pViolations, tField, ..Code(tField, "SHAPE"))
                    Continue
                }
                Set tSC = ..AliasHolder(+tValue, pName, .tHolder)
                If $$$ISERR(tSC) Quit
                If tHolder '= "" Do ..Add(.pViolations, tField, ..Code(tField, "TAKEN"))
            } ElseIf tField = ..#FIELDPROMPT {
                If '$ListFind($ListBuild("", "1", "2"), tValue) Do ..Add(.pViolations, tField, ..Code(tField, "VALUE"))
            } Else {
                Set tMax = $Select(tField = ..#FIELDDESCRIPTION: ..#DESCRIPTIONMAXLENGTH, 1: ..#FIELDMAXLENGTH)
                If $Length(tValue) > tMax {
                    Do ..Add(.pViolations, tField, ..Code(tField, "LENGTH"))
                } ElseIf '..Writable(tValue) {
                    Do ..Add(.pViolations, tField, ..Code(tField, "SHAPE"))
                }
            }
        }
        If $$$ISERR(tSC) Quit

        ; The alias and the physical device name are compared as the device will hold them: the
        ; field this write changes, else the one the fresh read carries.
        If (pArgs.%GetTypeOf(..#FIELDALIAS) '= "unassigned") || (pArgs.%GetTypeOf(..#FIELDPHYSICALDEVICE) '= "unassigned") {
            Set tAlias = ..Held(pArgs, pFresh, ..#FIELDALIAS)
            Set tPhysical = ..Held(pArgs, pFresh, ..#FIELDPHYSICALDEVICE)
            If ..WholeNumber(tAlias) && $IsValidNum(tPhysical) && (+tPhysical = +tAlias) && '..Has(.pViolations, ..#FIELDALIAS) {
                Do ..Add(.pViolations, ..#FIELDALIAS, ..Code(..#FIELDALIAS, "SAME"))
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, one longer
/// than <parameter>NAMEMAXLENGTH</parameter>, and one holding a <code>^</code>, an <code>=</code> or
/// a control character. A name is compared exactly, case included, so nothing here folds it.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#DEVICENAMEREQUIRED)
        Quit
    }
    If $Length(pName) > ..#NAMEMAXLENGTH {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#DEVICENAMELENGTH)
        Quit
    }
    If '..Writable(pName) || (pName [ "=") Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#DEVICENAMESHAPE)
}

/// <p>The fields among the eight that <var>pArgs</var> sets to a value other than
/// <var>pFresh</var>'s, compared as the diff renders them, as a new <class>%DynamicObject</class>.
/// With no fresh read every one <var>pArgs</var> carries is changed.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
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

/// <p>Set each field of <var>pPayload</var> to the JSON type the vendor's own read answers it with:
/// <code>Alias</code> and <code>Prompt</code> as an integer, or <code>""</code> when empty, and every
/// other field as a string. A value neither is left as it is, for the vendor to refuse; the rules
/// have already refused it on both callers.</p>
ClassMethod Shape(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Set tType = pPayload.%GetTypeOf(tField)
        If (tType = "unassigned") || (tType = "object") || (tType = "array") Continue
        Set tValue = ..Text(pPayload, tField)
        If (tField = ..#FIELDALIAS) || (tField = ..#FIELDPROMPT) {
            If tValue = "" {
                Do pPayload.%Set(tField, "", "string")
            } ElseIf ..WholeNumber(tValue) {
                Do pPayload.%Set(tField, +tValue, "number")
            }
        } ElseIf tType '= "string" {
            Do pPayload.%Set(tField, tValue, "string")
        }
    }
}

/// <p>Answer <code>GET /device/form[?name=&lt;n&gt;]</code>: everything the form needs before it can
/// draw a field (AD-39): <code>{requiredFields, maxLengths, rules, typeValues, subTypes}</code>. With
/// a name it adds <code>device: {Name, ...eight}</code> from the edit tool's fresh read; a name this
/// instance does not hold is 404 <parameter>OcuPilot.Api.Error.DEVICENAMEABSENT</parameter>.</p>
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
        For tField = ..#FIELDPHYSICALDEVICE, ..#FIELDOPENPARAMETERS, ..#FIELDALTERNATEDEVICE {
            Do tLengths.%Set(tField, ..#FIELDMAXLENGTH, "number")
        }
        Do tLengths.%Set(..#FIELDDESCRIPTION, ..#DESCRIPTIONMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Set tTypes = []
        For tI = 1:1:$Length(..#TYPEVALUES, ",") Do tTypes.%Push($Piece(..#TYPEVALUES, ",", tI))
        Do tBody.%Set("typeValues", tTypes)
        Set tListSC = ..SubTypes(.tSubTypes)
        If $$$ISERR(tListSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tListSC))
            Quit
        }
        Set tNames = []
        For tI = 1:1:$ListLength(tSubTypes) Do tNames.%Push($List(tSubTypes, tI))
        Do tBody.%Set("subTypes", tNames)
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tDevice = {}
            Do tDevice.%Set(..#FIELDNAME, tName, "string")
            For tI = 1:1:$Length(..#FIELDS, ",") {
                Set tField = $Piece(..#FIELDS, ",", tI)
                Set tType = tFresh.%GetTypeOf(tField)
                If (tType = "unassigned") || (tType = "null") {
                    Do tDevice.%Set(tField, "", "string")
                } Else {
                    Do tDevice.%Set(tField, tFresh.%Get(tField), tType)
                }
            }
            Do ..Shape(tDevice)
            Do tBody.%Set("device", tDevice)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /device/name?name=&lt;n&gt;</code>: whether that name is taken, in
/// <code>{name, taken, reason}</code>. A look-up that cannot be made is a refusal envelope, never an
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
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.DeviceSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#DEVICENAMEREQUIRED)
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
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#DEVICENAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a device already carries <var>pName</var>, in <var>pTaken</var>, read through the
/// create tool's own port, endpoint and read type (AD-52). The vendor's single read opens a name
/// exactly, case included; its list's <code>names</code> filter does not, so it is never asked
/// this.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#CREATETOOL, pName, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present device <var>pName</var>, read through the edit tool's own port, endpoint and read
/// type (AD-52), in <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var>
/// 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.DEVICENAMEABSENT</parameter>, any
/// other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONDEVICENAMEABSENT, ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port and endpoint, at
/// <var>pType</var> or, when that is empty, at the tool's own read type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, pType As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tType = $Select(pType '= "": pType, 1: $ClassMethod(pToolClass, "ReadType"))
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), tType, .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The names of the subtypes this instance defines, as a <class>%List</class> in the vendor's
/// order, read through the create tool's port from <parameter>SUBTYPEENDPOINT</parameter>'s list.</p>
ClassMethod SubTypes(Output pNames As %List) As %Status
{
    Set pNames = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tPort = $ClassMethod(..#CREATETOOL, "PortClass")
        Set tSC = $ClassMethod(tPort, "Invoke", ..#SUBTYPEENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") {
            Set tSC = $$$ERROR($$$GeneralError, "the subtype list did not answer an array")
            Quit
        }
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get("Name")
            If (tName '= "") && '$ListFind(pNames, tName) Set pNames = pNames _ $ListBuild(tName)
        }
    } Catch ex {
        Set pNames = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The name of a device other than <var>pName</var> whose alias is <var>pAlias</var>, in
/// <var>pHolder</var>, or <code>""</code>, read through the create tool's port from the devices list.
/// Names are compared exactly, so a device differing from <var>pName</var> only in case is another
/// device.</p>
ClassMethod AliasHolder(pAlias As %Integer, pName As %String, Output pHolder As %String) As %Status
{
    Set pHolder = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tPort = $ClassMethod(..#CREATETOOL, "PortClass")
        Set tSC = $ClassMethod(tPort, "Invoke", $ClassMethod(..#CREATETOOL, "Endpoint"), "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") {
            Set tSC = $$$ERROR($$$GeneralError, "the devices list did not answer an array")
            Quit
        }
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            If tRow.%Get(..#FIELDNAME) = pName Continue
            Set tHeld = ..Text(tRow, ..#FIELDALIAS)
            If ..WholeNumber(tHeld) && (+tHeld = +pAlias) {
                Set pHolder = tRow.%Get(..#FIELDNAME)
                Quit
            }
        }
    } Catch ex {
        Set pHolder = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).DeviceViolationCodes()
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

/// <p>The form field a <code>DEVICE.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "NAME" Quit ..#FIELDNAME
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        If $ZConvert(tField, "U") = tPart Quit
        Set tField = ""
    }
    Quit tField
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

/// <p>The violation code <code>DEVICE.&lt;FIELD&gt;.&lt;RULE&gt;</code> for <var>pField</var>.</p>
ClassMethod Code(pField As %String, pRule As %String) As %String [ Private ]
{
    Quit "DEVICE." _ $ZConvert(pField, "U") _ "." _ pRule
}

/// <p><var>pObject</var>'s <var>pField</var> as text: a number in its canonical spelling, a null or
/// absent field as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>The value <var>pField</var> will hold after this write: <var>pArgs</var>'s where it sets one,
/// else <var>pFresh</var>'s, else <code>""</code>.</p>
ClassMethod Held(pArgs As %DynamicObject, pFresh As %DynamicObject, pField As %String) As %String [ Private ]
{
    If pArgs.%GetTypeOf(pField) '= "unassigned" Quit ..Text(pArgs, pField)
    If $IsObject(pFresh) Quit ..Text(pFresh, pField)
    Quit ""
}

/// <p>Whether <var>pValue</var> is a whole number of at least 1, spelled without a sign, a fraction
/// or a leading zero.</p>
ClassMethod WholeNumber(pValue As %String) As %Boolean [ Private ]
{
    Quit $Match(pValue, "[1-9][0-9]{0,17}")
}

/// <p>Whether <var>pValue</var> can be written into the instance's configuration file as it is: no
/// <code>^</code> and no control character.</p>
ClassMethod Writable(pValue As %String) As %Boolean [ Private ]
{
    If pValue [ "^" Quit 0
    Set tWritable = 1
    For tI = 1:1:$Length(pValue) {
        Set tCode = $Ascii(pValue, tI)
        If (tCode < 32) || (tCode = 127) Set tWritable = 0 Quit
    }
    Quit tWritable
}

/// <p>Whether <var>pViolations</var> already refuses <var>pField</var>.</p>
ClassMethod Has(ByRef pViolations, pField As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    For tI = 1:1:$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
