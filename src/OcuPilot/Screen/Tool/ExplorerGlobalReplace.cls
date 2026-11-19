/// <p>Globals' find and replace (Story 21.18, AD-6, AD-10, AD-34, AD-36, AD-51, AD-53, AD-58): replace a text in the plain-text node values of
/// one whole global of the request's namespace, through <class>OcuPilot.Port.GlobalPort</class>. Two callers reach it: the Global nodes
/// page's Replace, reviewed first (<parameter>DRYRUN</parameter>) and confirmed with the global's name typed, and the agent's proposal and
/// confirmation.</p>
/// <p><b>The fresh read is composed from the text to find, its replacement and whether case matters</b> (<parameter>READSVALUES</parameter>,
/// <method>PortQuery</method>): the global's name with those three, the counts of the nodes and occurrences that change, the directories
/// they resolve to and <code>Digest</code>, a hash of their references and values. A person's action carries the digest it was reviewed at as
/// <code>Reviewed</code>, and the agent's confirm the digest its proposal was read at; the port refuses a digest that moved,
/// <code>GLOBAL.REPLACE.REVIEWCHANGED</code>, before it writes anything, and writes every change in one transaction or none.</p>
/// <p><b>Its card and review state counts only</b> (AD-36): <code>Find</code>, <code>Replace</code>, <code>MatchCase</code>,
/// <code>Nodes</code> and <code>Occurrences</code>. A node's value and subscript reach neither the card, the tool's result, the model, a log
/// line nor the ledger; <code>Digest</code> and <code>Locations</code> stay in the stored proposal. A global whose name begins with an
/// OcuPilot name stem, one with a changing node stored in OcuPilot's own or a protected system database, and OcuPilot's own code globals are
/// refused by the kernel on both callers.</p>
/// <p><b>It is destructive</b>: a replaced value cannot be restored from OcuPilot, because the replacement may already occur in the values.
/// Its governance key ships disabled (AD-22), so the agent's proposal is refused at dispatch until an administrator enables it, while the
/// person's own replace is never asked it (AD-53).</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalReplace Extends OcuPilot.Screen.Tool.ExplorerGlobalWrite
{

Parameter TOOLNAME = "explorer.globals.replace";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalList";

Parameter DESCRIPTION = "Propose replacing a text in the node values of one whole global of this namespace, as the classic Globals page's Find and Replace does once confirmed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the global as this namespace's Globals list reports it, without the ^, the text to find (Find, 1 to 1,000 characters), the text to put in its place (Replace, 0 to 1,000 characters) and whether case matters (MatchCase, default true). Only plain-text values are searched, every occurrence in a matching value is replaced, and subscripts are never searched. The proposal states only how many nodes and occurrences change, never a value or a subscript, and the replacement cannot be undone. A global that holds OcuPilot's own data or the instance's protected system data, a global of more than 20,000 nodes, a replacement that would make a value longer than 32,767 characters, a replace that changes nothing and the %SYS namespace are refused.";

/// <p>The review of a replace: the fresh read composed from the text, its replacement and whether case matters.</p>
Parameter READTYPE = "REPLACE";

/// <p>The write itself, which walks again and holds the reviewed digest.</p>
Parameter WRITETYPE = "REPLACEALL";

/// <p>The fresh read is composed from the find, the replacement and the case flag the write carries (AD-51).</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>Declared: a replaced value cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>A person's replace is reviewed through <code>POST /screens/:screen/dryrun</code> before it is sent, which counts what it changes.</p>
Parameter DRYRUN As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "replace";

/// <p>The find, the replacement, whether case matters, and the digest the review was read at.</p>
Parameter SCREENVALUES = "replace=Find:Replace:MatchCase:Reviewed";

Parameter SCREENOPTIONAL = "replace=Reviewed";

/// <p>A replacement may be empty, which deletes the text found.</p>
Parameter SCREENEMPTY = "replace=Replace";

/// <p>The classic Find and Replace page's resource (AD-44).</p>
Parameter CLASSICPAGES = "%cspapp.exp.utilexpfindreplace";

Parameter READANSWERS = "Name,Find,Replace,MatchCase,Nodes,Occurrences,Locations,Digest,Reviewed,Namespace";

/// <p>A replace acts on a global that holds a value the find changes.</p>
Parameter PRECONDITIONFIELD = "Nodes";

Parameter PRECONDITIONCODES = "GLOBAL.REPLACE.NOCHANGE";

/// <p>The reviewed change: the texts, the counts, the nodes' directories and their digest. <code>Reviewed</code> is named because the stored
/// payload is narrowed to the subject and <method>PortQuery</method> reads the digest from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Name,Find,Replace,MatchCase,Nodes,Occurrences,Locations,Digest,Reviewed,Namespace";

Parameter IDDESCRIPTION = "The global to replace in, named as this namespace's Globals list reports it in its Name column, without the ^.";

/// <p>The client maps it to the replace consequence (<code>OcuPilot.Api.GlobalError</code>'s <code>REPLACE</code>).</p>
Parameter CONSEQUENCECODE = "GLOBAL.REPLACE";

/// <p>The argument carrying the text to find, the one carrying its replacement, the case flag and the digest a person reviewed the action at,
/// which only a person's action carries.</p>
Parameter FINDARGUMENT = "Find";

Parameter REPLACEARGUMENT = "Replace";

Parameter MATCHCASEARGUMENT = "MatchCase";

Parameter REVIEWEDARGUMENT = "Reviewed";

/// <p>The endpoint the global is read and replaced through.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#ENDPOINTGLOBALS
}

/// <p>The query key the port reads the global's name from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#NAMEKEY
}

/// <p>The four values a call carries beyond the global.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#FINDARGUMENT, ..#REPLACEARGUMENT, ..#MATCHCASEARGUMENT, ..#REVIEWEDARGUMENT)
}

/// <p><class>OcuPilot.Screen.Tool.ExplorerGlobalReplaceMint</class>, which refuses unsound arguments before the instance is read.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerGlobalReplaceMint"
}

/// <p>The schema: the global, the text to find, its replacement and the case flag, and the agent's own words. <code>Reviewed</code> is not
/// offered.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tMax = ##class(OcuPilot.Port.GlobalPort).#MAXTEXT
    Do tProperties.%Set(..#FINDARGUMENT, {"type": "string", "maxLength": (tMax), "description": "The text to find in the plain-text node values: 1 to 1,000 characters, no control character. Subscripts are never searched."})
    Do tProperties.%Set(..#REPLACEARGUMENT, {"type": "string", "maxLength": (tMax), "description": "The text that replaces every occurrence: 0 to 1,000 characters, no control character. An empty text deletes what was found."})
    Do tProperties.%Set(..#MATCHCASEARGUMENT, {"type": "boolean", "description": "Whether upper and lower case must match. True when omitted."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push(..#FINDARGUMENT)
        Do tSchema.%Get("required").%Push(..#REPLACEARGUMENT)
    }
    Quit tSchema
}

/// <p>What is wrong with the call's own arguments, as one sentence, or <code>""</code>: a name that is no global name, a find that is not a
/// string of 1 to 1,000 characters with no control character, a replacement that is not one of 0 to 1,000, a case flag that is not a boolean,
/// and the digest only a person's action carries. The port judges the rest.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tPort = "OcuPilot.Port.GlobalPort"
    If '$ClassMethod(tPort, "NameValid", pIdValue) {
        Set pProblem = $Parameter(tPort, "REASONNAME")
        Quit $$$OK
    }
    If '$IsObject(pArgs) Quit $$$OK
    If (pArgs.%GetTypeOf(..#FINDARGUMENT) '= "string") || '$ClassMethod(tPort, "TextValid", pArgs.%Get(..#FINDARGUMENT), 1) || (pArgs.%GetTypeOf(..#REPLACEARGUMENT) '= "string") || '$ClassMethod(tPort, "TextValid", pArgs.%Get(..#REPLACEARGUMENT), 0) {
        Set pProblem = $ClassMethod(tPort, "ReasonFor", "GLOBAL.VALUE.SHAPE")
        Quit $$$OK
    }
    If (pArgs.%GetTypeOf(..#MATCHCASEARGUMENT) '= "unassigned") && (pArgs.%GetTypeOf(..#MATCHCASEARGUMENT) '= "boolean") {
        Set pProblem = "'" _ ..#MATCHCASEARGUMENT _ "' is true or false"
        Quit $$$OK
    }
    If pArgs.%GetTypeOf(..#REVIEWEDARGUMENT) '= "unassigned" Set pProblem = "'" _ ..#REVIEWEDARGUMENT _ "' is not an argument a proposal takes"
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): the find and the replacement as sent, the case flag from <code>true</code>
/// or <code>false</code> to a boolean, and the digest a person's review answered, when the action carries one. A value that is not a string,
/// or a case flag that is neither spelling, is <var>pProblem</var>; the texts themselves are judged by the port.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tCase = $Select($IsObject(pValues) && (pValues.%GetTypeOf(..#MATCHCASEARGUMENT) = "string"): pValues.%Get(..#MATCHCASEARGUMENT), 1: "")
    If '$IsObject(pValues) || (pValues.%GetTypeOf(..#FINDARGUMENT) '= "string") || (pValues.%GetTypeOf(..#REPLACEARGUMENT) '= "string") || ((tCase '= "true") && (tCase '= "false")) {
        Set pProblem = "'" _ ..#FINDARGUMENT _ "', '" _ ..#REPLACEARGUMENT _ "' and '" _ ..#MATCHCASEARGUMENT _ "' are the text to find, its replacement and true or false"
        Quit $$$OK
    }
    Do pArgs.%Set(..#FINDARGUMENT, pValues.%Get(..#FINDARGUMENT), "string")
    Do pArgs.%Set(..#REPLACEARGUMENT, pValues.%Get(..#REPLACEARGUMENT), "string")
    Do pArgs.%Set(..#MATCHCASEARGUMENT, (tCase = "true"), "boolean")
    If pValues.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Do pArgs.%Set(..#REVIEWEDARGUMENT, pValues.%Get(..#REVIEWEDARGUMENT), "string")
    Quit $$$OK
}

/// <p>The namespace, the texts and the case flag, and the digest the replace was reviewed at (the payload's <code>Reviewed</code>, else its
/// <code>Digest</code>), from the payload <var>pPayload</var> under the port's own query keys, so the mint, a screen action and the confirm's
/// re-read each compose the fresh read through it (<parameter>READSVALUES</parameter>) and the write replaces what was reviewed where it was
/// read (AD-52). A key the payload does not carry is left out, and the port refuses a call without its texts.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Do ##super(pPayload, .pQuery)
    Set tPort = "OcuPilot.Port.GlobalPort"
    If pPayload.%GetTypeOf(..#FINDARGUMENT) = "string" Set pQuery($Parameter(tPort, "FINDKEY")) = pPayload.%Get(..#FINDARGUMENT)
    If pPayload.%GetTypeOf(..#REPLACEARGUMENT) = "string" Set pQuery($Parameter(tPort, "REPLACEKEY")) = pPayload.%Get(..#REPLACEARGUMENT)
    If pPayload.%GetTypeOf(..#MATCHCASEARGUMENT) = "boolean" Set pQuery($Parameter(tPort, "MATCHCASEKEY")) = $Select(pPayload.%Get(..#MATCHCASEARGUMENT): 1, 1: 0)
    Set tDigest = ""
    If pPayload.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Set tDigest = pPayload.%Get(..#REVIEWEDARGUMENT)
    If (tDigest = "") && (pPayload.%GetTypeOf("Digest") = "string") Set tDigest = pPayload.%Get("Digest")
    If tDigest '= "" Set pQuery($Parameter(tPort, "DIGESTKEY")) = tDigest
}

/// <p>What a reviewed action answers beside its rows: the digest the person's action carries back.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    Do tReview.%Set("Digest", $Select($IsObject(pFresh): pFresh.%Get("Digest"), 1: ""), "string")
    Quit tReview
}

/// <p>The rows the card and the review show, from the fresh read <var>pFresh</var>: <code>Find</code>, <code>Replace</code>,
/// <code>MatchCase</code>, <code>Nodes</code> and <code>Occurrences</code>, each as the read answers it, and nothing a node holds. A read
/// that answers no <code>Nodes</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Nodes") '= "number") || (pFresh.%GetTypeOf("Occurrences") '= "number") {
        Set pProblem = "this instance did not report what the replace would change"
        Quit $$$OK
    }
    For tField = "Find", "Replace", "MatchCase", "Nodes", "Occurrences" {
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
