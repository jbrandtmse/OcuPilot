/// <p>The mint of an agent's create of one new class or routine (Story 20.20, AD-6, AD-10, AD-54): the
/// kernel's create mint, handed the whole new text. Nothing reaches the mint unchecked. In order, a refusal
/// stores nothing and calls no write:</p>
/// <ol>
/// <li>the name is one new document of the tool's kind (<method>OcuPilot.Screen.Tool.ExplorerCreate.SetProblem</method>);</li>
/// <li>the name is not one of OcuPilot's own (<method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotCode</method>);</li>
/// <li>the name may be created by the agent (<method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>, with <code>pCreate</code>);</li>
/// <li>the text is non-empty, carries no character the sanitizer would strip, and its header names the name;</li>
/// <li>the one-row hunk of the whole text fits one card (<parameter>OcuPilot.Screen.Tool.ExplorerSave.CHANGEMAXLENGTH</parameter>);</li>
/// <li>the namespace holds no document the name takes (the port's <code>NEWDOC</code>, 404 when none does);</li>
/// <li>the kernel's create mint runs with the text, <code>Compile</code> on and the namespace.</li>
/// </ol>
Class OcuPilot.Screen.Tool.ExplorerCreateMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, after the steps above. The
/// arguments and endpoints are those the agent's dispatcher passes for the create's list.</p>
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
            Set tSC = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Forbidden(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, .pHttpStatus, .pFault)
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tAgentProblem = ##class(OcuPilot.Screen.Tool.ExplorerSave).AgentProblem(tNamespace, tId, 1)
        If tAgentProblem '= "" {
            Set tSC = ..Refuse(tAgentProblem, .pHttpStatus, .pFault)
            Quit
        }

        Set tTextProblem = ..TextProblem(pArgs, tId)
        If tTextProblem '= "" {
            Set tSC = ..Refuse(tTextProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tText = pArgs.%Get("Text")

        Set tHunk = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("", tText)
        Set tLimit = ##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH
        Try {
            Set tWide = $Length(tHunk.%ToJSON()) > tLimit
        } Catch {
            Set tWide = 1
        }
        If tWide {
            Set tSC = ..Refuse("the new document is wider than one card can show: a create takes one document of at most " _ $FNumber(tLimit, ",") _ " characters, so write a smaller one", .pHttpStatus, .pFault)
            Quit
        }

        ; The namespace holds no document the name takes. A 404 is free; a 200 names the held documents.
        Kill tQuery
        Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = tNamespace
        Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = tId
        Set tTakenSC = ##class(OcuPilot.Port.AtelierPort).Invoke($ClassMethod(pToolClass, "Endpoint"), ##class(OcuPilot.Port.AtelierPort).#TYPENEWDOC, .tQuery, "", .tTaken, .tTakenHttp, .tTakenFault, .tTakenDocument)
        If $$$ISOK(tTakenSC) {
            Set tSC = ..Refuse("'" _ tId _ "' is already held by this namespace as " _ tTaken.%Get("Present") _ ", so the agent does not create it", .pHttpStatus, .pFault)
            Quit
        }
        If +$Get(tTakenHttp) '= 404 {
            Set pHttpStatus = +$Get(tTakenHttp)
            Set pFault = $Get(tTakenFault)
            Set tSC = tTakenSC
            Quit
        }

        Set tArgs = {}
        Do tArgs.%Set(pIdArgument, tId, "string")
        Do tArgs.%Set(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, tText, "string")
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

/// <p>What is wrong with the text <var>pArgs</var> carries for the document <var>pId</var>, or
/// <code>""</code>: a non-empty string with no character the sanitizer would strip, whose header names
/// <var>pId</var> (<method>OcuPilot.Port.AtelierPort.Header</method>).</p>
ClassMethod TextProblem(pArgs As %DynamicObject, pId As %String) As %String
{
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf("Text") '= "string") || (pArgs.%Get("Text") = "") {
        Quit "'Text' is the new document's whole text, as one non-empty string"
    }
    Set tText = pArgs.%Get("Text")
    Do ##class(OcuPilot.Kernel.Agent.Sanitize).Matchers(.tMatchers)
    If ##class(OcuPilot.Kernel.Agent.Sanitize).Strip(tText, .tMatchers) '= tText {
        Quit "'Text' holds a control or invisible character that the sanitizer removes, so the reviewed text would not match what is created"
    }
    Set tHeader = ##class(OcuPilot.Port.AtelierPort).Header(##class(OcuPilot.Port.AtelierPort).Lines(tText))
    If tHeader '= pId {
        Quit "the text's header names '" _ tHeader _ "', not '" _ pId _ "', so the create would not be the document named '" _ pId _ "'"
    }
    Quit ""
}

}
