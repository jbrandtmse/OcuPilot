/// <p>The mint of an agent's save of one class or routine (Story 20.21, AD-6, AD-10, AD-53): the kernel's
/// mint, handed the stored text with the agent's exact replacements applied. Nothing reaches the mint
/// unchecked. In order, a refusal stores nothing and calls no write:</p>
/// <ol>
/// <li>the set is one document of the tool's kind (<method>OcuPilot.Screen.Tool.ExplorerSave.SetProblem</method>);</li>
/// <li>the document is not one of OcuPilot's own (<method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotCode</method>);</li>
/// <li>the document may be saved by the agent (<method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>);</li>
/// <li>each replacement is well formed, and its <code>New</code> carries no character the sanitizer would strip;</li>
/// <li>the document's stored text is read through the port;</li>
/// <li>each <code>Old</code> occurs exactly once in the text the earlier replacements left, compared exactly;</li>
/// <li>the result saves as different lines from the stored text, fits the port's save (a length that cannot
/// be measured counts as over), and keeps the document's name;</li>
/// <li>the change's hunk is built and fits one card;</li>
/// <li>the kernel's mint runs with the stored text, the read version, the compile choice and the hunk.</li>
/// </ol>
/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> then reads the fresh document
/// and stores the proposal; a person's Save never reaches this class.</p>
Class OcuPilot.Screen.Tool.ExplorerSaveMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The most replacements one save may carry.</p>
Parameter MAXEDITS As INTEGER = 20;

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, after the steps above.
/// The arguments and the endpoints are those the agent's dispatcher passes for the save's list.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(pToolClass, "SetProblem", pIdValue)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId($ClassMethod(pDescriptor, "PrimaryEntityType"), pIdValue)

        If ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode(tId) {
            Set tSC = ..Forbidden(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, .pHttpStatus, .pFault)
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tAgentProblem = $ClassMethod(pToolClass, "AgentProblem", tNamespace, tId)
        If tAgentProblem '= "" {
            Set tSC = ..Refuse(tAgentProblem, .pHttpStatus, .pFault)
            Quit
        }

        Set tEditProblem = ..EditProblem(pArgs)
        If tEditProblem '= "" {
            Set tSC = ..Refuse(tEditProblem, .pHttpStatus, .pFault)
            Quit
        }

        Kill tQuery
        Set tQuery("namespace") = tNamespace
        Set tQuery("name") = tId
        Set tQuery("form") = "udl"
        Set tQuery("maxRows") = 1
        Set tReadSC = ##class(OcuPilot.Port.AtelierPort).Invoke($ClassMethod(pToolClass, "DocumentEndpoint"), "LIST", .tQuery, "", .tRows, .tReadHttp, .tReadFault, .tDocument)
        If $$$ISERR(tReadSC) {
            Set pHttpStatus = +$Get(tReadHttp)
            Set pFault = $Get(tReadFault)
            Set tSC = tReadSC
            Quit
        }
        If '$IsObject($Get(tDocument)) || 'tDocument.%Get("available") {
            Set pHttpStatus = 404
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOTFOUND)
            Set tSC = $$$ERROR($$$GeneralError, "the instance keeps no text for " _ tId)
            Quit
        }
        Set tOld = ..JoinLines(tDocument.%Get("content"))
        Set tVersion = tDocument.%Get("modified")

        Set tApplyProblem = ..Apply(tOld, pArgs.%Get("Edits"), $Parameter(pToolClass, "MATCHRULE"), .tNew)
        If tApplyProblem '= "" {
            Set tSC = ..Refuse(tApplyProblem, .pHttpStatus, .pFault)
            Quit
        }
        If ..SameLines(..SaveLines(tNew), ..SaveLines(tOld)) {
            Set tSC = ..Refuse("the edits change nothing: the result saves as the stored text", .pHttpStatus, .pFault)
            Quit
        }
        Set tOneLine = []
        Do tOneLine.%Push(tNew, "string")
        Try {
            Set tTooLarge = ($Length(tOneLine.%ToJSON()) - 4) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS
        } Catch {
            Set tTooLarge = 1
        }
        If tTooLarge {
            Set tSC = ..Refuse("the edited document is longer than one save takes", .pHttpStatus, .pFault)
            Quit
        }
        If ##class(OcuPilot.Port.AtelierPort).Header(##class(OcuPilot.Port.AtelierPort).Lines(tNew)) '= tId {
            Set tSC = ..Refuse("the edits change the document's name, so the save would not be the document named '" _ tId _ "'", .pHttpStatus, .pFault)
            Quit
        }

        Set tHunk = ..Hunk(tOld, tNew)
        Try {
            Set tWide = $Length(tHunk.%ToJSON()) > $Parameter(pToolClass, "CHANGEMAXLENGTH")
        } Catch {
            Set tWide = 1
        }
        If tWide {
            Set tSC = ..Refuse("the change is wider than one card can show: make the edits narrower, or propose edits far apart as separate saves, each once the one before it is confirmed", .pHttpStatus, .pFault)
            Quit
        }

        Set tArgs = {}
        Do tArgs.%Set(pIdArgument, tId, "string")
        Do tArgs.%Set(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, tNew, "string")
        Do tArgs.%Set(##class(OcuPilot.Port.AtelierPort).#VERSIONKEY, tVersion, "string")
        Do tArgs.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY, 1, "boolean")
        Do tArgs.%Set("Namespace", tNamespace, "string")
        Do tArgs.%Set("Hunk", tHunk)
        For tName = "rationale", "expectedImpact", "reverse" {
            If pArgs.%GetTypeOf(tName) = "string" Do tArgs.%Set(tName, pArgs.%Get(tName), "string")
        }
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>What is wrong with the replacements <var>pArgs</var> carries, or <code>""</code>: the
/// <code>Edits</code> array of 1 to <parameter>MAXEDITS</parameter> objects, each with exactly
/// <code>Old</code>, a non-empty string, and <code>New</code>, a string the sanitizer would not change.</p>
ClassMethod EditProblem(pArgs As %DynamicObject) As %String
{
    Set tShape = "'Edits' is a list of one to " _ ..#MAXEDITS _ " replacements, each an object with Old and New"
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf("Edits") '= "array") Quit tShape
    Set tEdits = pArgs.%Get("Edits")
    If (tEdits.%Size() < 1) || (tEdits.%Size() > ..#MAXEDITS) Quit tShape
    Do ##class(OcuPilot.Kernel.Agent.Sanitize).Matchers(.tMatchers)
    Set tProblem = ""
    For tI = 0:1:tEdits.%Size() - 1 {
        Set tProblem = ..EditItemProblem(tEdits.%Get(tI), tI + 1, .tMatchers)
        Quit:tProblem'=""
    }
    Quit tProblem
}

/// <p>What is wrong with one replacement <var>pEdit</var>, numbered <var>pNumber</var>, or
/// <code>""</code>.</p>
ClassMethod EditItemProblem(pEdit As %DynamicObject, pNumber As %Integer, ByRef pMatchers) As %String [ Private ]
{
    If '$IsObject(pEdit) || (pEdit.%Size() '= 2) || (pEdit.%GetTypeOf("Old") '= "string") || (pEdit.%GetTypeOf("New") '= "string") Quit "edit " _ pNumber _ " is an object with exactly Old and New, both strings"
    If pEdit.%Get("Old") = "" Quit "edit " _ pNumber _ ": Old is empty"
    If ##class(OcuPilot.Kernel.Agent.Sanitize).Strip(pEdit.%Get("New"), .pMatchers) '= pEdit.%Get("New") Quit "edit " _ pNumber _ ": New holds a control or invisible character that the sanitizer removes, so the reviewed diff would not match what is saved"
    Quit ""
}

/// <p>The replacements of <var>pEdits</var> applied in order to <var>pText</var>, as <var>pNew</var>,
/// or the problem with them in the return value: an <code>Old</code> that does not occur exactly once
/// in the text the earlier replacements left, named by its edit, its count and the match rule.</p>
ClassMethod Apply(pText As %String, pEdits As %DynamicArray, pRule As %String, Output pNew As %String) As %String
{
    Set pNew = pText
    Set tProblem = ""
    For tI = 0:1:pEdits.%Size() - 1 {
        Set tEdit = pEdits.%Get(tI)
        Set tOld = tEdit.%Get("Old")
        Set tCount = ..Occurrences(pNew, tOld)
        If tCount '= 1 {
            Set tProblem = "edit " _ (tI + 1) _ ": Old occurs " _ tCount _ " times in the stored text" _ $Select(tI = 0: "", 1: " as the earlier edits left it") _ ", and must occur exactly once. " _ pRule
            Quit
        }
        Set pNew = ..Replace(pNew, tOld, tEdit.%Get("New"))
    }
    Quit tProblem
}

/// <p>The number of times <var>pOld</var> occurs in <var>pText</var>, overlaps counted, compared exactly.</p>
ClassMethod Occurrences(pText As %String, pOld As %String) As %Integer
{
    Set tCount = 0
    Set tFrom = 1
    For {
        Set tFound = $Find(pText, pOld, tFrom)
        Quit:tFound=0
        Set tCount = tCount + 1
        Set tFrom = tFound - $Length(pOld) + 1
    }
    Quit tCount
}

/// <p><var>pText</var> with the first occurrence of <var>pOld</var> replaced by <var>pNew</var>. The
/// caller has checked that exactly one occurrence exists.</p>
ClassMethod Replace(pText As %String, pOld As %String, pNew As %String) As %String
{
    Set tEnd = $Find(pText, pOld)
    Set tStart = tEnd - $Length(pOld)
    Quit $Extract(pText, 1, tStart - 1) _ pNew _ $Extract(pText, tEnd, *)
}

/// <p>The lines of a document as one text, joined by line feeds, with no line feed after the last line.</p>
ClassMethod JoinLines(pLines As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pLines) Quit tText
    For tI = 0:1:pLines.%Size() - 1 {
        If tI > 0 Set tText = tText _ $Char(10)
        Set tText = tText _ pLines.%Get(tI)
    }
    Quit tText
}

/// <p>The lines <var>pText</var> saves as: <method>OcuPilot.Port.AtelierPort.Lines</method>, plus an empty
/// last line when the text ends with a line feed, as the port's save puts them.</p>
ClassMethod SaveLines(pText As %String) As %DynamicArray
{
    Set tLines = ##class(OcuPilot.Port.AtelierPort).Lines(pText)
    If $Extract(pText, *) = $Char(10) Do tLines.%Push("", "string")
    Quit tLines
}

/// <p>Whether the line lists <var>pA</var> and <var>pB</var> hold the same lines in the same order.</p>
ClassMethod SameLines(pA As %DynamicArray, pB As %DynamicArray) As %Boolean
{
    If pA.%Size() '= pB.%Size() Quit 0
    Set tSame = 1
    For tI = 0:1:pA.%Size() - 1 {
        If pA.%Get(tI) '= pB.%Get(tI) {
            Set tSame = 0
            Quit
        }
    }
    Quit tSame
}

/// <p>The one changed-lines row a card shows for the change from <var>pOld</var> to <var>pNew</var>, over
/// the lines each text saves as (<method>SaveLines</method>): the lines both share at their start
/// (<var>p</var>) and end (<var>s</var>) are left out, and three lines of context on each side are kept,
/// with <code>line</code> the first line shown (1-based). Each side's lines are followed by a line feed.</p>
/// <p><b>Caller contract:</b> a pure function of its two texts, asked by the tests as well as the mint.
/// The row is <code>{field: "Text", kind: "lines", line, before, after}</code>.</p>
ClassMethod Hunk(pOld As %String, pNew As %String) As %DynamicObject
{
    Set tA = ..SaveLines(pOld)
    Set tB = ..SaveLines(pNew)
    Set tNA = tA.%Size()
    Set tNB = tB.%Size()
    Set tMin = $Select(tNA < tNB: tNA, 1: tNB)
    Set tP = 0
    While (tP < tMin) && (tA.%Get(tP) = tB.%Get(tP)) {
        Set tP = tP + 1
    }
    Set tS = 0
    While (tP + tS < tMin) && (tA.%Get(tNA - 1 - tS) = tB.%Get(tNB - 1 - tS)) {
        Set tS = tS + 1
    }
    Set tFirst = $Select(tP - 2 > 1: tP - 2, 1: 1)
    Set tBeforeLast = $Select(tNA - tS + 3 < tNA: tNA - tS + 3, 1: tNA)
    Set tAfterLast = $Select(tNB - tS + 3 < tNB: tNB - tS + 3, 1: tNB)
    Set tRow = {}
    Do tRow.%Set("field", "Text", "string")
    Do tRow.%Set("kind", "lines", "string")
    Do tRow.%Set("line", tFirst, "number")
    Do tRow.%Set("before", ..Span(tA, tFirst, tBeforeLast), "string")
    Do tRow.%Set("after", ..Span(tB, tFirst, tAfterLast), "string")
    Quit tRow
}

/// <p>The lines <var>pFrom</var> to <var>pTo</var> (1-based, inclusive) of <var>pLines</var>, each followed
/// by a line feed.</p>
ClassMethod Span(pLines As %DynamicArray, pFrom As %Integer, pTo As %Integer) As %String [ Private ]
{
    Set tText = ""
    For tI = pFrom:1:pTo {
        Set tText = tText _ pLines.%Get(tI - 1) _ $Char(10)
    }
    Quit tText
}

/// <p>The refusal of an agent's save or create that the instance's own code rule names, 403 with the rule's code and
/// its published sentence, before anything is read or stored.</p>
ClassMethod Forbidden(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), pCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(pCode))
    Quit $$$ERROR($$$GeneralError, pCode)
}

}
