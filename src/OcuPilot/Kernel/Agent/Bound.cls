/// <p>The one bounds cutter serving screen context and descriptor-derived read tool results
/// (AD-24, DW-281, DW-452). Given a payload object carrying a <code>rows</code> array of flat row
/// objects, it cuts rows to a row cap, cuts each row's over-long string values to a per-field
/// maximum with a trailing U+2026, and then cuts whole rows from the end until the serialized
/// payload fits a total character budget.</p>
/// <p><b>Bounds truncate and never refuse.</b> The one case a caller must treat as a refusal is
/// <method>Apply</method> answering 0: the payload cannot fit inside its total budget even with
/// zero rows.</p>
Class OcuPilot.Kernel.Agent.Bound Extends %RegisteredObject
{

/// <p>The mark a cut string ends with: U+2026, one character.</p>
ClassMethod Ellipsis() As %String [ CodeMode = expression ]
{
$Char(8230)
}

/// <p>Bound <var>pPayload</var>'s <code>rows</code> array in place, in this order: the row cap,
/// the per-field cut, then the total-size cut.</p>
/// <p><var>pRowCap</var> is the row cap (a whole number above zero). <var>pFieldMaxLengths</var>,
/// subscripted by field name, is each field's declared maximum; a field absent from it uses
/// <var>pDefaultFieldMax</var>. <var>pTotalMax</var> is the serialized payload's character
/// ceiling.</p>
/// <p><var>pPayload</var> gains <code>rowsSent</code> (the row count actually kept),
/// <code>rowsAvailable</code> (the row count before this call's own row cap -- <var>pPayload</var>'s
/// own <code>rows</code> size at the call, unless the caller already set a larger
/// <code>rowsAvailable</code> of its own), <code>truncated</code> (true when this call cut
/// anything, ORed with whatever the caller already set) and <code>truncatedFields</code> (sorted,
/// unique field names, ORed with whatever the caller already set).</p>
/// <p>Returns 0, with <var>pJson</var> <code>""</code>, when the payload cannot fit inside
/// <var>pTotalMax</var> even with zero rows.</p>
ClassMethod Apply(pPayload As %DynamicObject, pRowCap As %Integer, ByRef pFieldMaxLengths, pDefaultFieldMax As %Integer, pTotalMax As %Integer, Output pJson As %String) As %Boolean
{
    Set pJson = ""
    Set tRows = pPayload.%Get("rows")
    Set tHasRows = $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray")
    If 'tHasRows Set tRows = []

    Set tRowsAvailable = tRows.%Size()
    If (pPayload.%GetTypeOf("rowsAvailable") = "number") && (pPayload.%Get("rowsAvailable") > tRowsAvailable) {
        Set tRowsAvailable = pPayload.%Get("rowsAvailable")
    }

    Set tTruncated = ''pPayload.%Get("truncated")

    Kill tFieldSet
    If $IsObject(pPayload.%Get("truncatedFields")) {
        Set tIterator = pPayload.%Get("truncatedFields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If tName '= "" Set tFieldSet(tName) = ""
        }
    }

    ; 1. Row cap.
    If tRows.%Size() > pRowCap {
        Set tKept = []
        For tI = 0:1:pRowCap - 1 {
            Do tKept.%Push(tRows.%Get(tI))
        }
        Set tRows = tKept
        Set tTruncated = 1
    }

    ; 2. Per-field cut.
    Set tCutRows = []
    Set tRowIterator = tRows.%GetIterator()
    While tRowIterator.%GetNext(.tRowIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") {
            Do tCutRows.%Push(tRow)
            Continue
        }
        Set tNewRow = {}
        Set tFieldIterator = tRow.%GetIterator()
        While tFieldIterator.%GetNext(.tField, .tValue, .tValueType) {
            If tValueType = "string" {
                Set tMax = pDefaultFieldMax
                If $Data(pFieldMaxLengths(tField)) Set tMax = +pFieldMaxLengths(tField)
                If (tMax > 0) && ($Length(tValue) > tMax) {
                    Set tValue = $Extract(tValue, 1, tMax - 1) _ ..Ellipsis()
                    Set tTruncated = 1
                    Set tFieldSet(tField) = ""
                }
                Do tNewRow.%Set(tField, tValue, "string")
            } ElseIf (tValueType = "object") || (tValueType = "array") {
                ; %Set's type-hint argument disambiguates a scalar (is "5" a string or a number,
                ; is 1 a boolean or a number); passed alongside an already-object-valued OREF, as
                ; the iterator answers for a nested object or array, it raises <ILLEGAL VALUE> --
                ; the object's own nature already says which kind it is.
                Do tNewRow.%Set(tField, tValue)
            } Else {
                Do tNewRow.%Set(tField, tValue, tValueType)
            }
        }
        Do tCutRows.%Push(tNewRow)
    }
    Set tRows = tCutRows

    Set tFieldsArray = []
    Set tField = $Order(tFieldSet(""))
    While tField '= "" {
        Do tFieldsArray.%Push(tField)
        Set tField = $Order(tFieldSet(tField))
    }

    Do pPayload.%Set("rows", tRows)
    Do pPayload.%Set("rowsSent", tRows.%Size(), "number")
    Do pPayload.%Set("rowsAvailable", tRowsAvailable, "number")
    Do pPayload.%Set("truncated", ''tTruncated, "boolean")
    Do pPayload.%Set("truncatedFields", tFieldsArray)

    ; 3. Total-size cut.
    Set tFits = 0
    Try {
        Set pJson = pPayload.%ToJSON()
        Set tFits = ($Length(pJson) <= pTotalMax)
    } Catch {
        Set tFits = 0
    }
    If tFits Quit 1
    Set pJson = ""

    Set tCount = tRows.%Size()
    Do pPayload.%Set("rows", [])
    Do pPayload.%Set("rowsSent", 0, "number")
    Do pPayload.%Set("truncated", 1, "boolean")
    Set tBase = $Length(pPayload.%ToJSON())
    Set tKeep = 0
    For tI = 0:1:tCount - 1 {
        Set tHolder = []
        Do tHolder.%Push(tRows.%Get(tI))
        Set tAdd = ($Length(tHolder.%ToJSON()) - 2) + (tKeep > 0)
        If (tBase + tAdd) > pTotalMax Quit
        Set tBase = tBase + tAdd
        Set tKeep = tKeep + 1
    }
    If tBase > pTotalMax Quit 0
    Set tKept = []
    For tI = 0:1:tKeep - 1 {
        Do tKept.%Push(tRows.%Get(tI))
    }
    Do pPayload.%Set("rows", tKept)
    Do pPayload.%Set("rowsSent", tKeep, "number")
    Set pJson = pPayload.%ToJSON()
    If $Length(pJson) > pTotalMax {
        Set pJson = ""
        Quit 0
    }
    Quit 1
}

}
