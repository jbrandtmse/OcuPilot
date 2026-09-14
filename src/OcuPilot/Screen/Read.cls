/// <p>The one executor of a descriptor-declared read (AD-36). A screen's list and its read tool
/// both resolve through <method>Execute</method>, so they cannot differ in field set, and both
/// narrow its rows through <method>ApplyView</method>, so they cannot differ in filter or sort.</p>
/// <p><b>Every read is bounded.</b> <method>Execute</method> asks the port for one row more than
/// the cap: the vendor class query stops at <code>maxRows</code> and signals nothing, so the extra
/// row is the only truncation signal that costs no second query. The answer carries at most
/// <code>maxRows</code> rows and <code>truncated</code> true exactly when more came back.</p>
/// <p><b>A read may name one per-row detail call</b> (<code>source.rowGet</code>, AD-36), issued
/// only for the rows that survive the cap. Its declared detail fields are merged into each row and
/// its derived fields are computed here, on the instance clock, so a screen and a tool see the same
/// value.</p>
/// <p><b>One view rule, two implementations.</b> <method>ApplyView</method> is mirrored by
/// <file>ui/src/app/core/screen-read.ts</file>'s <code>applyView</code>, because the screen sorts
/// and filters on the client and a tool runs in-process on the server; both are pinned by the one
/// corpus in <class>OcuPilot.Test.ReadViewCorpus</class>.</p>
/// <p>The port is reached through <method>PortClass</method> alone (AD-2, AD-27); a tool never
/// touches <code>%session</code>, <code>%request</code> or <code>$NAMESPACE</code>, and neither
/// does this.</p>
Class OcuPilot.Screen.Read Extends %RegisteredObject
{

/// <p>The cap a read is bounded by when its caller names none.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The one request type a Release 1 read issues.</p>
Parameter READTYPE = "LIST";

/// <p>The request type a declared <code>rowGet</code> issues once per surviving row.</p>
Parameter DETAILTYPE = "GET";

/// <p>The ASCII capitals the view rule lower-cases, and nothing else.</p>
Parameter UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// <p>What <parameter>UPPER</parameter> lower-cases to.</p>
Parameter LOWER = "abcdefghijklmnopqrstuvwxyz";

/// <p>The port class every read is issued through. Overridable so a fixture can reach
/// <class>OcuPilot.Test.PortFixture</class>; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>What is wrong with <var>pMaxRows</var>, or <code>""</code>. Absent (<code>""</code>) is
/// sound and means <parameter>DEFAULTMAXROWS</parameter>; anything else must be a whole number
/// above zero, written without sign, fraction or leading zero.</p>
ClassMethod MaxRowsProblem(pMaxRows As %String) As %String
{
    If pMaxRows = "" Quit ""
    If $Match(pMaxRows, "^[1-9][0-9]*$") Quit ""
    Quit "maxRows must be a whole number above zero"
}

/// <p>Run <var>pDescriptor</var>'s declared read, bounded by <var>pMaxRows</var>.</p>
/// <p>On success <var>pResult</var> is <code>{fields, rows, truncated}</code>: <code>fields</code>
/// the declared field names without the descriptor's <code>context.secretFields</code>, each row an
/// object carrying exactly those keys (an absent key is <code>null</code>), and at most the cap's
/// rows. A secret field's value is dropped here, so neither the screen route nor the read tool can
/// return it (Conventions, Secrets). <var>pHttpStatus</var> is 200.</p>
/// <p>When the read declares <code>source.rowGet</code>, each surviving row's detail is read with
/// one <code>GET</code> carrying <code>param</code> set to that row's <code>key</code> value. Its
/// <code>fields</code> replace the row's with their JSON types, and each <code>derived</code> field
/// is set from its rule (<method>Derive</method>). A row whose <code>GET</code> answers 404 was
/// deleted between the calls and is dropped; <code>truncated</code> still follows the list. Any
/// other detail fault fails the whole read with that fault and no rows, and a row with no string
/// key, a detail that is not an object or a value its rule cannot read is a 500.</p>
/// <p>A bad cap is refused before the port is called: 400 with <code>READ.MAXROWS</code>. A port
/// failure passes through unchanged -- its status, its HTTP status and its
/// <code>{error, reason, code}</code> fault. A descriptor with no read, or an answer that is not a
/// list, is a 500 with the internal fault. <var>pFault</var> is set exactly when the status is an
/// error.</p>
ClassMethod Execute(pDescriptor As %String, pMaxRows As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tMaxProblem = ..MaxRowsProblem(pMaxRows)
        If tMaxProblem '= "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#READMAXROWS, tMaxProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Select(pMaxRows = "": ..#DEFAULTMAXROWS, 1: +pMaxRows)

        Set tRead = $ClassMethod(pDescriptor, "Read")
        Set tSource = $Select($IsObject(tRead): tRead.%Get("source"), 1: "")
        If '$IsObject(tSource) || (tSource.%Get("type") '= ..#READTYPE) {
            Set tSC = ..Internal(pDescriptor _ " declares no read this executor can issue", .pHttpStatus, .pFault)
            Quit
        }

        Set tQuery("maxRows") = tMax + 1
        Set tPortSC = $ClassMethod(..PortClass(), "Invoke", tSource.%Get("endpoint"), ..#READTYPE, .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tPortSC) {
            Set tSC = tPortSC
            Quit
        }
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicArray") {
            Set tSC = ..Internal(pDescriptor _ "'s read answered something other than a list", .pHttpStatus, .pFault)
            Quit
        }

        Set tSecrets = $ClassMethod(pDescriptor, "ContextSecretFields")
        Set tFields = []
        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$ListFind(tSecrets, tField) Do tFields.%Push(tField)
        }
        Set tRowGet = tSource.%Get("rowGet")
        Set tHasRowGet = $IsObject(tRowGet) && tRowGet.%IsA("%Library.DynamicObject")
        Set tRows = []
        Set tSurviving = 0
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tSurviving = tMax Quit
            Set tSurviving = tSurviving + 1
            If 'tHasRowGet {
                Do tRows.%Push(..Project(tRow, tFields))
                Continue
            }
            Set tSC = ..DetailRow(pDescriptor, tSource.%Get("endpoint"), tRowGet, tRow, tFields, .tOut, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If $IsObject(tOut) Do tRows.%Push(tOut)
        }
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set("fields", tFields)
        Do pResult.%Set("rows", tRows)
        Do pResult.%Set("truncated", tAnswer.%Size() > tMax, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the read failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One surviving list row with its detail merged, as <var>pOut</var>, or <var>pOut</var>
/// <code>""</code> when the row's <code>GET</code> answered 404. An error status carries the
/// detail call's fault, or the internal fault, in <var>pHttpStatus</var> and <var>pFault</var>,
/// which are left alone otherwise.</p>
ClassMethod DetailRow(pDescriptor As %String, pEndpoint As %String, pRowGet As %DynamicObject, pRow As %DynamicObject, pFields As %DynamicArray, Output pOut As %DynamicObject, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pOut = ""
    Try {
        Set tKeyField = pRowGet.%Get("key")
        If ('$IsObject(pRow)) || ('pRow.%IsA("%Library.DynamicObject")) || (pRow.%GetTypeOf(tKeyField) '= "string") || (pRow.%Get(tKeyField) = "") {
            Set tSC = ..Internal(pDescriptor _ "'s list row carries no string " _ tKeyField _ " to read its detail by", .pHttpStatus, .pFault)
            Quit
        }
        Set tQuery(pRowGet.%Get("param")) = pRow.%Get(tKeyField)
        Set tDetail = ""
        Set tPortSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, ..#DETAILTYPE, .tQuery, "", .tDetail, .tHttp, .tFault)
        If $$$ISERR(tPortSC) {
            If tHttp = 404 Quit
            Set pHttpStatus = tHttp
            Set pFault = tFault
            Set tSC = tPortSC
            Quit
        }
        If '$IsObject(tDetail) || 'tDetail.%IsA("%Library.DynamicObject") {
            Set tSC = ..Internal(pDescriptor _ "'s detail call answered something other than an object", .pHttpStatus, .pFault)
            Quit
        }

        Kill tDerived
        Set tEntries = pRowGet.%Get("derived").%GetIterator()
        While tEntries.%GetNext(.tIndex, .tEntry) {
            Set tValue = ..Derive(tEntry.%Get("rule"), tDetail, tEntry.%Get("from"), .tReadable)
            If 'tReadable {
                Set tSC = ..Internal(pDescriptor _ "'s derived field " _ tEntry.%Get("field") _ " cannot be read from " _ tEntry.%Get("from"), .pHttpStatus, .pFault)
                Quit
            }
            Set tDerived(tEntry.%Get("field")) = tValue
        }
        If $$$ISERR(tSC) Quit

        Set tDetailFields = ""
        Set tNames = pRowGet.%Get("fields").%GetIterator()
        While tNames.%GetNext(.tIndex, .tName) {
            Set tDetailFields = tDetailFields _ $ListBuild(tName)
        }
        Set tOut = {}
        Set tIterator = pFields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If $Data(tDerived(tField)) {
                Do tOut.%Set(tField, tDerived(tField), "boolean")
            } ElseIf $ListFind(tDetailFields, tField) {
                Do ..CopyValue(tDetail, tField, tOut)
            } Else {
                Do ..CopyValue(pRow, tField, tOut)
            }
        }
        Set pOut = tOut
    } Catch ex {
        Set pOut = ""
        Set tSC = ..Internal("the detail call failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The value derived rule <var>pRule</var> computes from <var>pDetail</var>'s
/// <var>pFrom</var>, with <var>pReadable</var> 0 when the value is not one the rule reads.</p>
/// <p><code>beforeToday</code> is true exactly when the value is a <code>YYYY-MM-DD</code> date
/// earlier than <code>+$Horolog</code>, the instance's own date, and false for <code>""</code>, a
/// <code>null</code> or an absent key.</p>
ClassMethod Derive(pRule As %String, pDetail As %DynamicObject, pFrom As %String, Output pReadable As %Boolean) As %Boolean
{
    Set pReadable = 0
    If pRule '= "beforeToday" Quit 0
    Set tType = pDetail.%GetTypeOf(pFrom)
    If (tType = "unassigned") || (tType = "null") {
        Set pReadable = 1
        Quit 0
    }
    If tType '= "string" Quit 0
    Set tValue = pDetail.%Get(pFrom)
    If tValue = "" {
        Set pReadable = 1
        Quit 0
    }
    If '$Match(tValue, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Quit 0
    Set tDate = $ZDateH(tValue, 3, , , , , , , -1)
    If tDate = -1 Quit 0
    Set pReadable = 1
    Quit tDate < (+$Horolog)
}

/// <p><var>pRow</var> projected to <var>pFields</var>: a new object with exactly those keys, in
/// that order, each value copied with its JSON type and an absent one <code>null</code>.</p>
ClassMethod Project(pRow As %DynamicObject, pFields As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Set tIterator = pFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Do ..CopyValue(pRow, tField, tOut)
    }
    Quit tOut
}

/// <p>Copy <var>pKey</var> from <var>pFrom</var> to <var>pTo</var> keeping its JSON type;
/// <code>null</code> when <var>pFrom</var> is not an object or does not carry the key.</p>
ClassMethod CopyValue(pFrom As %DynamicObject, pKey As %String, pTo As %DynamicObject) [ Private ]
{
    Set tType = "unassigned"
    If $IsObject(pFrom) && pFrom.%IsA("%Library.DynamicObject") Set tType = pFrom.%GetTypeOf(pKey)
    If (tType = "unassigned") || (tType = "null") {
        Do pTo.%Set(pKey, "", "null")
    } ElseIf (tType = "string") || (tType = "number") || (tType = "boolean") {
        Do pTo.%Set(pKey, pFrom.%Get(pKey), tType)
    } Else {
        Do pTo.%Set(pKey, pFrom.%Get(pKey))
    }
}

/// <p>The view rule (AD-36): <var>pRows</var> filtered by <var>pFilter</var> and sorted by
/// <var>pSort</var> in <var>pDirection</var>, as a new array holding the same row objects.</p>
/// <p><b>Filter.</b> An empty filter keeps every row. Otherwise a row stays when the text of any
/// field <var>pRead</var>'s <code>filter</code> names contains the filter text, both with only the
/// ASCII capitals lower-cased. A string's text is itself, a number's its JSON text, a boolean's
/// <code>true</code> or <code>false</code>, an array's its members' texts by the same rule joined by
/// <code>, </code>, and <code>null</code>, an absent key or an object is empty.</p>
/// <p><b>Sort.</b> Stable, on one member of <code>sort.fields</code>, in one direction; a
/// <var>pSort</var> that is not a member, or a <var>pDirection</var> that is neither
/// <code>asc</code> nor <code>desc</code>, takes the declared <code>default</code> and
/// <code>direction</code>. Two numbers compare numerically, anything else by text in code-unit
/// order, and <code>null</code> sorts last in either direction. That comparison is not transitive
/// over a column mixing numbers with numeric-looking text, so the order depends on which pairs are
/// compared: the client's <code>applyView</code> runs this same bottom-up merge rather than its
/// engine's sort.</p>
ClassMethod ApplyView(pRows As %DynamicArray, pRead As %DynamicObject, pFilter As %String = "", pSort As %String = "", pDirection As %String = "") As %DynamicArray
{
    Set tNeedle = $Translate(pFilter, ..#UPPER, ..#LOWER)
    Set tFilterFields = pRead.%Get("filter")
    Set tSortDecl = pRead.%Get("sort")
    If '$IsObject(tSortDecl) Set tSortDecl = {}
    Set tKey = tSortDecl.%Get("default")
    If (pSort '= "") && ..ArrayHas(tSortDecl.%Get("fields"), pSort) Set tKey = pSort
    Set tDescending = (tSortDecl.%Get("direction") = "desc")
    If pDirection = "asc" Set tDescending = 0
    If pDirection = "desc" Set tDescending = 1

    ; Keep the filtered rows, and each one's sort key: type (0 null, 1 number, 2 text), value, and
    ; the view rule's text, which is what a number compares by against anything but a number.
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tNeedle '= "") && '..Matches(tRow, tFilterFields, tNeedle) Continue
        Set tCount = tCount + 1
        Set tKept(tCount) = tRow
        Set tText(tCount) = ..TextOf(tRow, tKey)
        Set tType = ..TypeOf(tRow, tKey)
        If tType = "null" {
            Set tKind(tCount) = 0
            Set tValue(tCount) = ""
        } ElseIf tType = "number" {
            Set tKind(tCount) = 1
            Set tValue(tCount) = tRow.%Get(tKey)
        } Else {
            Set tKind(tCount) = 2
            Set tValue(tCount) = ..TextOf(tRow, tKey)
        }
    }

    ; Bottom-up merge sort over positions, which is stable: a tie keeps the left run's row.
    For tI = 1:1:tCount Set tOrder(tI) = tI
    Set tWidth = 1
    While tWidth < tCount {
        Set tLeft = 1
        While tLeft <= tCount {
            Set tMid = tLeft + tWidth - 1
            Set tRight = tLeft + (2 * tWidth) - 1
            If tRight > tCount Set tRight = tCount
            If tMid < tRight {
                Set tA = tLeft, tB = tMid + 1, tK = tLeft
                While (tA <= tMid) || (tB <= tRight) {
                    If tB > tRight {
                        Set tNext = tOrder(tA), tA = tA + 1
                    } ElseIf tA > tMid {
                        Set tNext = tOrder(tB), tB = tB + 1
                    } ElseIf ..Compare(tKind(tOrder(tB)), tValue(tOrder(tB)), tText(tOrder(tB)), tKind(tOrder(tA)), tValue(tOrder(tA)), tText(tOrder(tA)), tDescending) < 0 {
                        Set tNext = tOrder(tB), tB = tB + 1
                    } Else {
                        Set tNext = tOrder(tA), tA = tA + 1
                    }
                    Set tMerged(tK) = tNext
                    Set tK = tK + 1
                }
                For tI = tLeft:1:tRight Set tOrder(tI) = tMerged(tI)
            }
            Set tLeft = tLeft + (2 * tWidth)
        }
        Set tWidth = tWidth * 2
    }

    Set tOut = []
    For tI = 1:1:tCount Do tOut.%Push(tKept(tOrder(tI)))
    Quit tOut
}

/// <p>Negative when the first key sorts before the second, positive when after, 0 on a tie.
/// <var>pKindA</var> and <var>pKindB</var> are 0 for null, 1 for a number, 2 for text;
/// <var>pTextA</var> and <var>pTextB</var> are each key's <method>TextOf</method> text.</p>
ClassMethod Compare(pKindA As %Integer, pValueA As %String, pTextA As %String, pKindB As %Integer, pValueB As %String, pTextB As %String, pDescending As %Boolean) As %Integer [ Private ]
{
    If (pKindA = 0) && (pKindB = 0) Quit 0
    If pKindA = 0 Quit 1
    If pKindB = 0 Quit -1
    Set tOrder = 0
    If (pKindA = 1) && (pKindB = 1) {
        Set tOrder = $Select(pValueA < pValueB: -1, pValueA > pValueB: 1, 1: 0)
    } Else {
        Set tOrder = $Select(pTextA = pTextB: 0, pTextB ] pTextA: -1, 1: 1)
    }
    Quit $Select(pDescending: -tOrder, 1: tOrder)
}

/// <p>Whether any of <var>pFields</var>' texts on <var>pRow</var>, lower-cased, contains
/// <var>pNeedle</var>.</p>
ClassMethod Matches(pRow As %DynamicObject, pFields As %DynamicArray, pNeedle As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    If '$IsObject(pFields) Quit 0
    Set tIterator = pFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If $Translate(..TextOf(pRow, tField), ..#UPPER, ..#LOWER) [ pNeedle {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>The JSON type of <var>pKey</var> on <var>pRow</var>, <code>null</code> when the row is not
/// an object or does not carry it.</p>
ClassMethod TypeOf(pRow As %DynamicObject, pKey As %String) As %String [ Private ]
{
    If '$IsObject(pRow) || 'pRow.%IsA("%Library.DynamicObject") Quit "null"
    Set tType = pRow.%GetTypeOf(pKey)
    If tType = "unassigned" Quit "null"
    Quit tType
}

/// <p>The view rule's text of <var>pKey</var> on <var>pRow</var>.</p>
ClassMethod TextOf(pRow As %DynamicObject, pKey As %String) As %String
{
    Set tType = ..TypeOf(pRow, pKey)
    If tType = "null" Quit ""
    Quit ..ValueText(pRow.%Get(pKey), tType)
}

/// <p>The view rule's text of <var>pValue</var>, whose JSON type is <var>pType</var>: a string is
/// itself, a number its JSON text, a boolean <code>true</code> or <code>false</code>, an array its
/// members' texts joined by <code>, </code>, and anything else empty.</p>
ClassMethod ValueText(pValue As %RawString, pType As %String) As %String [ Private ]
{
    If pType = "string" Quit pValue
    If pType = "boolean" Quit $Select(pValue: "true", 1: "false")
    If pType = "number" {
        Set tHolder = []
        Do tHolder.%Push(pValue, "number")
        Set tJson = tHolder.%ToJSON()
        Quit $Extract(tJson, 2, *-1)
    }
    If pType = "array" {
        Set tText = ""
        Set tIterator = pValue.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMember, .tMemberType) {
            Set tText = tText _ $Select(tIndex = 0: "", 1: ", ") _ ..ValueText(tMember, tMemberType)
        }
        Quit tText
    }
    Quit ""
}

/// <p>Whether <var>pArray</var> holds the string <var>pValue</var>.</p>
ClassMethod ArrayHas(pArray As %DynamicArray, pValue As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    If '$IsObject(pArray) Quit 0
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry = pValue {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>A refusal this executor decided, with no port behind it.</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An internal failure: the generic fault on the wire, the detail in the status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
