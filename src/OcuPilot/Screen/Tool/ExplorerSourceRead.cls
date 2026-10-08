/// <p>The shared read behind the agent's source reads (Story 20.19, AD-36, AD-60, AD-61): one class's
/// or one routine's text, as the viewer shows it, answered as whole lines. A concrete subclass names
/// its viewer (<parameter>DESCRIPTORCLASS</parameter>), its document kind (<method>Endpoint</method>)
/// and its input hint (<parameter>NAMEHINT</parameter>).</p>
/// <p><b>The text is cut, and the cut is reported.</b> <method>Cut</method> keeps whole lines while
/// their JSON-escaped length, with a line feed counted as two characters, is at most
/// <parameter>SOURCEMAXLENGTH</parameter>. A first line that alone exceeds it is cut at a character
/// boundary. <code>truncated</code> and <code>linesSent</code> say what was kept.</p>
/// <p><b>It runs the viewer's checks</b>, in order: the viewer's pairs
/// (<method>OcuPilot.Screen.Gate.Evaluate</method>), then the port's own gate and document read
/// (<method>OcuPilot.Port.AtelierPort.Invoke</method>, which refuses a name it does not accept as 400
/// and a document the namespace does not hold as 404). A document whose text the instance keeps only
/// as object code answers 404 <code>PORT.NOTFOUND</code>.</p>
Class OcuPilot.Screen.Tool.ExplorerSourceRead Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

Parameter KIND = "read";

/// <p>The most characters the text of one read may escape to, quotes and backslashes included.</p>
Parameter SOURCEMAXLENGTH As INTEGER = 60000;

/// <p>The description of the <code>name</code> argument a concrete subclass sets.</p>
Parameter NAMEHINT = "";

/// <p>The port endpoint the document is read through: <code>Class</code> or <code>Routine</code>.</p>
ClassMethod Endpoint() As %String [ Abstract ]
{
    Quit ""
}

/// <p>The port the document is read through. Overridable so a fixture can answer the read; production
/// never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AtelierPort"
}

/// <p>One document's name, as the viewer's <code>name</code> criterion takes it, at most 256
/// characters. Closed: no other argument is admitted.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": ["name"], "additionalProperties": false}
    Set tName = {"type": "string", "maxLength": 256}
    Do tName.%Set("description", ..#NAMEHINT, "string")
    Do tSchema.%Get("properties").%Set("name", tName)
    Quit tSchema
}

/// <p>The viewer's effective pairs (AD-8): <parameter>DESCRIPTORCLASS</parameter>'s required pairs,
/// unioned with its classic page's custom resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>The result: <code>{name, namespace, lines, linesSent, truncated, text}</code>, all six
/// required. Closed.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "name": {"type": "string", "description": "The document the text belongs to."},
            "namespace": {"type": "string", "description": "The namespace the document was read in."},
            "lines": {"type": "integer", "description": "How many lines the document has."},
            "linesSent": {"type": "integer", "description": "How many lines the text carries, counted from the first. When the first line itself was cut, one."},
            "truncated": {"type": "boolean", "description": "True when the text does not carry every line in full."},
            "text": {"type": "string", "description": "The document's first linesSent lines, joined by line feeds, at most 60,000 characters escaped."}
        },
        "required": ["name", "namespace", "lines", "linesSent", "truncated", "text"],
        "additionalProperties": false
    }
}

/// <p>Answer the document's text as <method>ResultSchema</method>'s object. Every refusal is an error
/// status with <var>pHttpStatus</var> and <var>pFault</var>: 400 <code>TOOL.ARGUMENTS</code> for an
/// argument the schema refuses, 403 for a missing pair, the port's own faults, and 404
/// <code>PORT.NOTFOUND</code> for a document whose text the instance does not keep.</p>
/// <p>Caller contract: not called from an escalated frame (AD-9). The caller's namespace is read from
/// <method>OcuPilot.Kernel.Scope.Current</method> and not changed.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
            Do pFault.%Set("detail", ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair))
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code())
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tName = tArgs.%Get("name")
        Kill tQuery
        Set tQuery("namespace") = tNamespace
        Set tQuery("name") = tName
        Set tQuery("form") = "udl"
        Set tQuery("maxRows") = 1
        Set tOpenSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
        If $$$ISERR(tOpenSC) {
            Set tSC = tOpenSC
            Set pHttpStatus = tHttp
            Set pFault = tFault
            Quit
        }
        If '$IsObject(tDocument) || 'tDocument.%Get("available") {
            Set tSC = $$$ERROR($$$GeneralError, "the instance keeps no text for " _ tName)
            Set pHttpStatus = 404
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOTFOUND)
            Quit
        }

        Set tLines = tDocument.%Get("content")
        Set tText = ..Cut(tLines, ..#SOURCEMAXLENGTH, .tSent, .tTruncated)
        Set tResult = {}
        Do tResult.%Set("name", tName, "string")
        Do tResult.%Set("namespace", tNamespace, "string")
        Do tResult.%Set("lines", tLines.%Size(), "number")
        Do tResult.%Set("linesSent", tSent, "number")
        Do tResult.%Set("truncated", tTruncated, "boolean")
        Do tResult.%Set("text", tText, "string")
        Set pResult = tResult
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the source read failed: " _ ex.Name, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The text of <var>pLines</var> (a %DynamicArray of strings) cut to fit <var>pMax</var> escaped
/// characters, the one home of the cut. <var>pSent</var> is how many lines the text carries and
/// <var>pTruncated</var> is 1 when the text does not carry every line in full.</p>
/// <p>Each line is measured as <method>Escaped</method> measures it, with a line feed between two
/// lines counted as two characters. The first line is kept whole when it fits; otherwise it is cut
/// by <method>CutFirst</method> and counts as one line sent.</p>
ClassMethod Cut(pLines As %DynamicArray, pMax As %Integer, Output pSent As %Integer, Output pTruncated As %Boolean) As %String
{
    Set pSent = 0
    Set pTruncated = 0
    Set tText = ""
    Set tUsed = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tEscaped = ..Escaped(tLine)
        If tIndex = 0 {
            If tEscaped > pMax {
                Set tText = ..CutFirst(tLine, pMax)
                Set pSent = 1
                Set pTruncated = 1
                Quit
            }
            Set tText = tLine
            Set tUsed = tEscaped
            Set pSent = 1
            Continue
        }
        If tUsed + 2 + tEscaped > pMax {
            Set pTruncated = 1
            Quit
        }
        Set tText = tText _ $Char(10) _ tLine
        Set tUsed = tUsed + 2 + tEscaped
        Set pSent = pSent + 1
    }
    Quit tText
}

/// <p>The length of <var>pText</var> as a JSON string, without its quotes: the count
/// <method>Cut</method> measures. It serializes the text as a pushed string, so a numeric-looking line
/// keeps its quotes.</p>
ClassMethod Escaped(pText As %String) As %Integer [ Private ]
{
    Set tOne = []
    Do tOne.%Push(pText, "string")
    Quit $Length(tOne.%ToJSON()) - 4
}

/// <p>The longest prefix of <var>pLine</var> whose escaped length is at most <var>pMax</var>, never
/// ending on the high half of a UTF-16 surrogate pair (the guard <class>OcuPilot.Kernel.Agent.Bound</class>
/// applies to a cut field).</p>
ClassMethod CutFirst(pLine As %String, pMax As %Integer) As %String [ Private ]
{
    Set tLow = 0
    Set tHigh = $Length(pLine)
    While tLow < tHigh {
        Set tMid = (tLow + tHigh + 1) \ 2
        If ..Escaped($Extract(pLine, 1, tMid)) <= pMax {
            Set tLow = tMid
        } Else {
            Set tHigh = tMid - 1
        }
    }
    Set tPrefix = $Extract(pLine, 1, tLow)
    Set tLast = $Ascii($Extract(tPrefix, *))
    If (tLast >= 55296) && (tLast <= 56319) Set tPrefix = $Extract(tPrefix, 1, *-1)
    Quit tPrefix
}

}
