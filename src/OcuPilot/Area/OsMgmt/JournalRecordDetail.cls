/// <p>The journal record detail dialog's read (Story 18.19, AD-36): <code>GET /journal/record</code>
/// answers one record of one journal file, its values included, to the screen alone. It is not a
/// declared read, so no tool reaches it, and nothing of its answer reaches screen context, the model,
/// the ledger or a log line.</p>
/// <p>It is gated by Journal records' declared pairs (AD-8) before any port call, and reads through
/// <method>PortClass</method>'s <code>Journal.Record</code> <code>GET</code>, so the port's address
/// rule and its journal file guard apply (AD-21's eighth case).</p>
Class OcuPilot.Area.OsMgmt.JournalRecordDetail Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate this route (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.JournalRecordList";

/// <p>The port the record is read through; a test subclass names a counting seam.</p>
Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

Parameter ENDPOINT = "Journal.Record";

Parameter FILEPARAM = "file";

Parameter ADDRESSPARAM = "address";

/// <p>The vendor answer's two objects whose members are flattened into the record beside its
/// top-level scalars.</p>
Parameter MEMBEROBJECTS = "SetKill,VectorSetKill";

/// <p>The longest string the record carries, in characters; a longer one keeps one fewer and ends
/// with U+2026 (AD-24's field bound).</p>
Parameter VALUEMAXLENGTH As INTEGER = 1000;

/// <p>The port <method>HandleGet</method> reads through.</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p>Answer <code>GET /journal/record?file=&lt;f&gt;&amp;address=&lt;a&gt;</code> as
/// <code>{record}</code> (<method>Record</method>). A caller without Journal records' pairs is
/// refused naming the pair, with no port call. The port's 404 <code>PORT.NOTFOUND</code> -- no record
/// at that address, or one on a database the caller cannot read -- is 404
/// <code>JOURNAL.RECORD.UNREADABLE</code>; any other refusal, <code>JOURNAL.FILE.UNLISTED</code> and
/// <code>JOURNAL.OFFSET.SHAPE</code> among them, is rendered as the port answered it.</p>
ClassMethod HandleGet() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Kill tQuery
        Set tQuery(..#FILEPARAM) = $Get(%request.Data(..#FILEPARAM, 1))
        Set tQuery(..#ADDRESSPARAM) = $Get(%request.Data(..#ADDRESSPARAM, 1))
        Set tAnswer = ""
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderRefusal(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON({"record": (..Record(tAnswer))})
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The record the dialog shows, built from the vendor's answer <var>pAnswer</var>: its top-level
/// scalars, then each <parameter>MEMBEROBJECTS</parameter> object's members, every value keeping its
/// JSON type and every string longer than <parameter>VALUEMAXLENGTH</parameter> cut to that length,
/// its last character U+2026.</p>
ClassMethod Record(pAnswer As %DynamicObject) As %DynamicObject
{
    Set tRecord = {}
    If '$IsObject(pAnswer) Quit tRecord
    Set tObjects = $ListFromString(..#MEMBEROBJECTS)
    Do ..CopyScalars(pAnswer, tRecord)
    For tI = 1:1:$ListLength(tObjects) {
        Set tMember = pAnswer.%Get($List(tObjects, tI))
        If $IsObject(tMember) && tMember.%IsA("%Library.DynamicObject") Do ..CopyScalars(tMember, tRecord)
    }
    Quit tRecord
}

/// <p>Copy <var>pFrom</var>'s scalar members into <var>pTo</var>, keeping a member already there, each
/// string cut to <parameter>VALUEMAXLENGTH</parameter>.</p>
ClassMethod CopyScalars(pFrom As %DynamicObject, pTo As %DynamicObject) [ Private ]
{
    Set tIterator = pFrom.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tType = pFrom.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") || (tType = "unassigned") || pTo.%IsDefined(tKey) Continue
        If tType = "null" {
            Do pTo.%Set(tKey, "", "null")
        } ElseIf tType = "string" {
            Do pTo.%Set(tKey, ..Cut(tValue), "string")
        } Else {
            Do pTo.%Set(tKey, tValue, tType)
        }
    }
}

/// <p><var>pValue</var> cut to <parameter>VALUEMAXLENGTH</parameter> characters, its last U+2026, when
/// it is longer.</p>
ClassMethod Cut(pValue As %String) As %String
{
    If $Length(pValue) <= ..#VALUEMAXLENGTH Quit pValue
    Quit $Extract(pValue, 1, ..#VALUEMAXLENGTH - 1) _ $Char(8230)
}

/// <p>Render a refused read: the port's <code>PORT.NOTFOUND</code> as 404
/// <code>JOURNAL.RECORD.UNREADABLE</code>, an internal failure generically, and anything else as the
/// port's own envelope.</p>
ClassMethod RenderRefusal(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status [ Private ]
{
    If $IsObject(pFault) && (+pHttpStatus = 404) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTNOTFOUND) {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.JournalError).#REASONRECORDUNREADABLE, ##class(OcuPilot.Api.JournalError).#RECORDUNREADABLE)
    }
    If '$IsObject(pFault) || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttpStatus: +pHttpStatus, 1: 500), pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), pFault.%Get("detail"))
}

}
