/// <p>The <class>%Net.HttpRequest</class> chunk reader behind a streamed model call (AD-42, AD-33).
/// <method>ReadChunk</method> receives the raw bytes of each piece of the response body as it
/// arrives -- only once a status line has been parsed -- and, in order: decodes UTF-8 carrying a
/// split character across chunks, splits lines on LF with any CR stripped, parses server-sent
/// events, feeds each event to the family's <class>OcuPilot.Kernel.Provider.StreamAdapter</class>,
/// and hands the text so far to the <class>OcuPilot.Kernel.Provider.StreamSink</class> whenever it
/// has grown.</p>
/// <p>A body whose first non-blank character is <code>{</code> is JSON -- an error answer, or a
/// server that ignored <code>stream</code> -- and is kept whole, up to
/// <parameter>JSONMAXLENGTH</parameter> characters, as the body of record.</p>
/// <p><b>Caller contract.</b> One reader per attempt, created empty. It never raises and never does
/// device I/O: while <method>ReadChunk</method> runs the provider's socket is the current device.
/// A sink that raises stops publishing for the call and never fails it. After the call the caller
/// runs <method>Finish</method>, reads <method>Body</method> or <method>Raw</method>, and runs
/// <method>Release</method>.</p>
Class OcuPilot.Kernel.Provider.StreamReader Extends %Net.ChunkedReader
{

/// <p>The most characters of a JSON body this reader keeps.</p>
Parameter JSONMAXLENGTH = 3000000;

/// <p>The most characters of a non-JSON body kept for the log.</p>
Parameter RAWHEADLENGTH = 4096;

/// <p>The family's assembler.</p>
Property Adapter As OcuPilot.Kernel.Provider.StreamAdapter;

/// <p>Where the text so far goes, or <code>""</code>.</p>
Property Sink As OcuPilot.Kernel.Provider.StreamSink;

/// <p>How many raw bytes arrived.</p>
Property Received As %Integer [ InitialExpression = 0 ];

/// <p><code>""</code> until the first non-blank character, then <code>json</code> or
/// <code>sse</code>.</p>
Property Mode As %String(MAXLEN = 8);

/// <p>Blank text read before the mode was known.</p>
Property Leading As %String(MAXLEN = "");

/// <p>The UTF-8 bytes of a character split across chunks, carried to the next one.</p>
Property Utf8Carry As %String(MAXLEN = "");

/// <p>The last line of the text so far, not yet ended by LF.</p>
Property LineTail As %String(MAXLEN = "");

/// <p>The event being read: its name, its data lines joined by LF, and whether a data line
/// arrived.</p>
Property EventName As %String(MAXLEN = 256);

Property EventData As %String(MAXLEN = "");

Property HasData As %Boolean [ InitialExpression = 0 ];

/// <p>A JSON body, whole up to <parameter>JSONMAXLENGTH</parameter>.</p>
Property JsonBody As %String(MAXLEN = "");

/// <p>The first <parameter>RAWHEADLENGTH</parameter> characters of any body, for the log.</p>
Property RawHead As %String(MAXLEN = "");

/// <p>The length of the text last handed to the sink.</p>
Property Published As %Integer [ InitialExpression = 0 ];

/// <p>Set once the sink raised; nothing more is handed to it.</p>
Property SinkOff As %Boolean [ InitialExpression = 0 ];

/// <p>Set when this reader's own processing raised, which ends the call as a broken stream.</p>
Property Faulted As %Boolean [ InitialExpression = 0 ];

/// <p>A fresh, empty reader for <var>pFamily</var>, publishing to <var>pSink</var>.</p>
Method %OnNew(pFamily As %String = "", pSink As OcuPilot.Kernel.Provider.StreamSink = "") As %Status
{
    Set ..Adapter = ##class(OcuPilot.Kernel.Provider.StreamAdapter).%New(pFamily)
    Set ..Sink = pSink
    Quit $$$OK
}

/// <p>Take one piece of the raw response body. Never raises.</p>
Method ReadChunk(pChunk As %String)
{
    Try {
        If pChunk = "" Quit
        Set ..Received = ..Received + $Length(pChunk)
        Set tCarry = ..Utf8Carry
        Set tText = $ZConvert(pChunk, "I", "UTF8", tCarry)
        Set ..Utf8Carry = tCarry
        Do ..Consume(tText)
    } Catch ex {
        Set ..Faulted = 1
    }
}

/// <p>Route decoded text by the body's shape, then publish.</p>
Method Consume(pText As %String) [ Private ]
{
    If pText = "" Quit
    If $Length(..RawHead) < ..#RAWHEADLENGTH Set ..RawHead = $Extract(..RawHead _ pText, 1, ..#RAWHEADLENGTH)
    Set tText = pText
    If ..Mode = "" {
        If $ZStrip(tText, "<W") = "" {
            Set ..Leading = ..Leading _ tText
            Quit
        }
        Set ..Mode = $Select($Extract($ZStrip(tText, "<W")) = "{": "json", 1: "sse")
        Set tText = ..Leading _ tText
        Set ..Leading = ""
    }
    If ..Mode = "json" {
        If $Length(..JsonBody) < ..#JSONMAXLENGTH Set ..JsonBody = ..JsonBody _ $Extract(tText, 1, ..#JSONMAXLENGTH - $Length(..JsonBody))
        Quit
    }
    Set tLines = $ListFromString(..LineTail _ tText, $Char(10))
    Set tCount = $ListLength(tLines)
    For tI = 1:1:(tCount - 1) {
        Do ..Line($List(tLines, tI))
    }
    Set ..LineTail = $List(tLines, tCount)
    Do ..Publish()
}

/// <p>One SSE line, its LF already removed.</p>
Method Line(pLine As %String) [ Private ]
{
    Set tLine = pLine
    If $Extract(tLine, *) = $Char(13) Set tLine = $Extract(tLine, 1, * - 1)
    If tLine = "" {
        Do ..Dispatch()
        Quit
    }
    If $Extract(tLine) = ":" Quit
    Set tField = $Piece(tLine, ":")
    Set tValue = $Select(tLine [ ":": $Extract(tLine, $Length(tField) + 2, *), 1: "")
    If $Extract(tValue) = " " Set tValue = $Extract(tValue, 2, *)
    If tField = "event" {
        Set ..EventName = tValue
    } ElseIf tField = "data" {
        Set ..EventData = $Select(..HasData: ..EventData _ $Char(10) _ tValue, 1: tValue)
        Set ..HasData = 1
    }
}

/// <p>Hand the event read so far to the assembler, and start the next.</p>
Method Dispatch() [ Private ]
{
    If ..HasData Do ..Adapter.Take(..EventName, ..EventData)
    Set ..EventName = ""
    Set ..EventData = ""
    Set ..HasData = 0
}

/// <p>Hand the text so far to the sink when it has grown since the last hand-over.</p>
Method Publish() [ Private ]
{
    If ..SinkOff || '$IsObject(..Sink) Quit
    Set tLength = $Length(..Adapter.TextSoFar)
    If tLength <= ..Published Quit
    Set ..Published = tLength
    Try {
        Do ..Sink.Publish(..Adapter.TextSoFar)
    } Catch ex {
        Set ..SinkOff = 1
    }
}

/// <p>End the body: decode any bytes still carried, read a last line with no LF, and dispatch an
/// event that no blank line ended. Never raises.</p>
Method Finish()
{
    Try {
        If ..Utf8Carry '= "" {
            Set tRest = $ZConvert(..Utf8Carry, "I", "UTF8")
            Set ..Utf8Carry = ""
            Do ..Consume(tRest)
        }
        If ..Mode = "sse" {
            If ..LineTail '= "" {
                Set tLast = ..LineTail
                Set ..LineTail = ""
                Do ..Line(tLast)
            }
            Do ..Dispatch()
        }
    } Catch ex {
        Set ..Faulted = 1
    }
}

/// <p>Whether the body was JSON rather than a stream of events.</p>
Method IsJson() As %Boolean
{
    Quit (..Mode = "json")
}

/// <p>The body of record for a streamed 2xx answer: the family's assembled non-streamed body, with
/// <var>pStatus</var> an error when the stream carried an error event, had no terminator, or
/// could not be read.</p>
Method Body(Output pStatus As %Status) As %String
{
    Set pStatus = $$$OK
    If ..Faulted {
        Set pStatus = $$$ERROR($$$GeneralError, "the provider's stream could not be read")
        Quit ""
    }
    If ..IsJson() Quit ..JsonBody
    Quit ..Adapter.Body(.pStatus)
}

/// <p>The body as received, for an answer that is not a streamed success: the JSON body whole, or
/// the head of anything else.</p>
Method Raw() As %String
{
    If ..IsJson() Quit ..JsonBody
    Quit ..RawHead
}

/// <p>Drop the sink and the assembler, so nothing the call held outlives it.</p>
Method Release()
{
    Set ..Sink = ""
    Set ..Adapter = ""
}

}
