/// <p><code>shell.tools.find</code> (AD-5, AD-8, AD-24, AD-53): the discovery tool of a scoped turn. A
/// turn starts with the shell's tools and the screen's own, and this tool finds any other tool by
/// what it does; a tool it finds can be called from the model's next step
/// (<method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> makes it reachable).</p>
/// <p><b>The search reads the registry's listing and nothing else.</b> It scores every advertised
/// tool but itself over <method>RegistryClass</method>'s <code>ListTools</code> -- the per-process
/// cache every tool reads -- so an unadvertised tool (AD-53) is never found, and it answers only
/// what the whole tool array gave every caller. It therefore declares no privilege pair: finding a
/// tool grants no call, and every gate runs when the tool is called (AD-8).</p>
/// <p><b>The score.</b> The query is cut into words: lower-case runs of two or more letters or
/// digits, the first ten. Each word scores 2 when the tool's canonical name contains it, else 1 when
/// its description does; a tool's score is the sum, and a tool that scores 0 is dropped. Rows come by
/// score, then by canonical name.</p>
/// <p>The answer is <code>{query, rows: [{name, description}], rowsAvailable, truncated}</code>,
/// <code>name</code> the wire name the model calls. A query with no word is refused
/// <code>TOOL.ARGUMENTS</code>; a query that matches nothing answers no rows.</p>
Class OcuPilot.Screen.Tool.ToolsFind Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "shell.tools.find";

Parameter KIND = "read";

Parameter DESCRIPTION = "Search the tools you were not given at the start of this turn by what they do; a tool found can be called from your next step.";

/// <p>The most query words that are scored.</p>
Parameter MAXWORDS = 10;

/// <p>The fewest characters a query word has.</p>
Parameter MINWORDLENGTH = 2;

/// <p>The most tools one answer names, and the default.</p>
Parameter MAXLIMIT = 20;

Parameter DEFAULTLIMIT = 8;

/// <p>The longest query, in characters.</p>
Parameter MAXQUERYLENGTH = 200;

/// <p>The tool registry whose listing is searched. Overridable for a fixture; production never
/// overrides it.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p><code>query</code> is required; <code>limit</code> is optional.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "What the tool should do, in a few words, for example: permissions users read."
            },
            "limit": {
                "type": "integer",
                "minimum": 1,
                "description": ("The most tools to name; " _ ..#DEFAULTLIMIT _ " when omitted.")
            }
        },
        "required": ["query"],
        "additionalProperties": false
    }
    Do tSchema.properties.query.%Set("maxLength", ..#MAXQUERYLENGTH, "number")
    Do tSchema.properties.limit.%Set("maximum", ..#MAXLIMIT, "number")
    Quit tSchema
}

/// <p>Includes <code>rowsSent</code> and <code>truncatedFields</code>: a rows-shaped result is
/// dispatched through <class>OcuPilot.Kernel.Agent.Bound</class>, which adds them (AD-24).</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "The query as searched."},
            "rows": {"type": "array", "items": {"type": "object"}, "description": "The tools found, best first: name is the wire name to call, description what it does."},
            "rowsAvailable": {"type": "integer", "description": "How many tools matched, before the limit."},
            "truncated": {"type": "boolean", "description": "Whether more tools matched than are named."},
            "rowsSent": {"type": "integer", "description": "How many tools are named."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "The fields whose text was cut."}
        },
        "required": ["query", "rows", "rowsAvailable", "truncated"],
        "additionalProperties": false
    }
}

/// <p>Declared: none (AD-3). A query is a description of a capability, never a credential.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The words of <var>pQuery</var> that are scored, as a <class>%List</class>: its lower-case
/// runs of letters and digits that are <parameter>MINWORDLENGTH</parameter> long or longer, the
/// first <parameter>MAXWORDS</parameter>, in order. Any other character, a non-ASCII letter
/// included, ends a run.</p>
ClassMethod Words(pQuery As %String) As %List
{
    Set tWords = ""
    Set tLower = $ZConvert(pQuery, "L")
    Set tRun = ""
    For tI = 1:1:$Length(tLower) + 1 {
        Set tChar = $Extract(tLower, tI)
        If (tChar '= "") && $Match(tChar, "[a-z0-9]") {
            Set tRun = tRun _ tChar
            Continue
        }
        If $Length(tRun) >= ..#MINWORDLENGTH Set tWords = tWords _ $ListBuild(tRun)
        Set tRun = ""
        If $ListLength(tWords) >= ..#MAXWORDS Quit
    }
    Quit tWords
}

/// <p>Search the listing for <var>pArgs</var>' <code>query</code> and answer the best
/// <code>limit</code> tools. <var>pDescriptor</var> and <var>pContextCap</var> are ignored: the
/// dispatcher bounds the rows. Refuses <code>TOOL.ARGUMENTS</code> for arguments the input schema
/// does not admit and for a query with no word.</p>
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
        Set tQuery = tArgs.%Get("query")
        Set tLimit = $Select(tArgs.%GetTypeOf("limit") = "number": tArgs.%Get("limit"), 1: ..#DEFAULTLIMIT)
        Set tWords = ..Words(tQuery)
        If tWords = "" {
            Set tSC = ..ArgumentsRefusal("query has no word of " _ ..#MINWORDLENGTH _ " or more letters or digits", .pHttpStatus, .pFault)
            Quit
        }
        Set tRegistry = ..RegistryClass()
        Set tListSC = $ClassMethod(tRegistry, "ListTools", .tList)
        If $$$ISERR(tListSC) {
            Set tSC = ..InternalRefusal("the tool listing could not be read: " _ $System.Status.GetErrorText(tListSC), .pHttpStatus, .pFault)
            Quit
        }
        Kill tRanked
        Set tAvailable = 0
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$ClassMethod(tRegistry, "IsAdvertised", tEntry) Continue
            Set tName = tEntry.%Get("name")
            If tName = ..#TOOLNAME Continue
            Set tDescription = $ClassMethod(tRegistry, "DescriptionOf", tEntry)
            Set tScore = ..Score(tWords, tName, tDescription)
            If tScore = 0 Continue
            Set tRanked(-tScore, tName) = tDescription
            Set tAvailable = tAvailable + 1
        }
        Set tRows = []
        Set tScoreKey = ""
        For {
            Set tScoreKey = $Order(tRanked(tScoreKey))
            If (tScoreKey = "") || (tRows.%Size() >= tLimit) Quit
            Set tName = ""
            For {
                Set tName = $Order(tRanked(tScoreKey, tName))
                If (tName = "") || (tRows.%Size() >= tLimit) Quit
                Set tRow = {}
                Do tRow.%Set("name", $ClassMethod(tRegistry, "WireName", tName), "string")
                Do tRow.%Set("description", tRanked(tScoreKey, tName), "string")
                Do tRows.%Push(tRow)
            }
        }
        Set pResult = {}
        Do pResult.%Set("query", tQuery, "string")
        Do pResult.%Set("rows", tRows)
        Do pResult.%Set("rowsAvailable", tAvailable, "number")
        Do pResult.%Set("truncated", (tAvailable > tRows.%Size()), "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the tool search failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The score of the tool <var>pName</var> (canonical) with <var>pDescription</var> for the query
/// words <var>pWords</var>: per word, 2 when the name contains it, else 1 when the description
/// does, summed.</p>
ClassMethod Score(pWords As %List, pName As %String, pDescription As %String) As %Integer [ Private ]
{
    Set tScore = 0
    Set tName = $ZConvert(pName, "L")
    Set tDescription = $ZConvert(pDescription, "L")
    For tI = 1:1:$ListLength(pWords) {
        Set tWord = $List(pWords, tI)
        If tName [ tWord {
            Set tScore = tScore + 2
        } ElseIf tDescription [ tWord {
            Set tScore = tScore + 1
        }
    }
    Quit tScore
}

}
