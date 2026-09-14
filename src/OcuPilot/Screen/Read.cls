/// <p>The one executor of a descriptor-declared read (AD-36). A screen's list and its read tool
/// both resolve through <method>Execute</method>, so they cannot differ in field set, and both
/// narrow its rows through <method>ApplyView</method>, so they cannot differ in filter or sort.</p>
/// <p><b>Every read is bounded.</b> <method>Execute</method> asks the port for one row more than
/// the cap: the vendor class query stops at <code>maxRows</code> and signals nothing, so the extra
/// row is the only truncation signal that costs no second query. The answer carries at most
/// <code>maxRows</code> rows and <code>truncated</code> true exactly when more came back.</p>
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
        Set tRows = []
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRows.%Size() = tMax Quit
            Do tRows.%Push(..Project(tRow, tFields))
        }
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
/// <code>true</code> or <code>false</code>, and <code>null</code>, an absent key, an object or an
/// array is empty.</p>
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
    If tType = "string" Quit pRow.%Get(pKey)
    If tType = "boolean" Quit $Select(pRow.%Get(pKey): "true", 1: "false")
    If tType = "number" {
        Set tHolder = []
        Do tHolder.%Push(pRow.%Get(pKey), "number")
        Set tJson = tHolder.%ToJSON()
        Quit $Extract(tJson, 2, *-1)
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
