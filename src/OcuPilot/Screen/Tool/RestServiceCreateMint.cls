/// <p>The mint of an agent's create of one spec-based REST service (Story 18.32, AD-6, AD-10, AD-53, AD-54): the
/// kernel's create mint, handed the whole document. Nothing reaches the mint unchecked. In order, a refusal stores
/// nothing and calls no write:</p>
/// <ol>
/// <li>the package and the document meet the port's rules (<method>OcuPilot.Screen.Tool.RestServiceCreate.ArgumentProblem</method>);</li>
/// <li>the package is not one of OcuPilot's own (<method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotCode</method>);</li>
/// <li>the three classes may be created by the agent in the turn's namespace
/// (<method>OcuPilot.Screen.Tool.RestServiceCreate.AgentProblems</method>);</li>
/// <li>the one-row hunk of the formatted document fits one card
/// (<parameter>OcuPilot.Screen.Tool.ExplorerSave.CHANGEMAXLENGTH</parameter>);</li>
/// <li>the kernel's create mint runs with the document and the namespace; its fresh read finds no service of the
/// package's name, and no class of its specification's or dispatch class's name, in any letter case.</li>
/// </ol>
Class OcuPilot.Screen.Tool.RestServiceCreateMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, after the steps above. The arguments and
/// endpoint are those the agent's dispatcher passes for the create.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tRuleSC = $ClassMethod(pToolClass, "ArgumentProblem", pIdValue, pArgs, .tProblem)
        If $$$ISERR(tRuleSC) {
            Set tSC = ..Internal("the tool's field rules could not be evaluated: " _ $System.Status.GetErrorText(tRuleSC), .pHttpStatus, .pFault)
            Quit
        }
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }

        If ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode(pIdValue) {
            Set tSC = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Forbidden(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, .pHttpStatus, .pFault)
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tAgentProblem = $ClassMethod(pToolClass, "AgentProblems", tNamespace, pIdValue)
        If tAgentProblem '= "" {
            Set tSC = ..Refuse(tAgentProblem, .pHttpStatus, .pFault)
            Quit
        }

        Set tHunk = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("", ..FormattedDocument(pArgs.%Get("Document")))
        Set tLimit = ##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH
        Try {
            Set tWide = $Length(tHunk.%ToJSON()) > tLimit
        } Catch {
            Set tWide = 1
        }
        If tWide {
            Set tSC = ..Refuse("the document is wider than one card can show: a create takes one document of at most " _ $FNumber(tLimit, ",") _ " characters once formatted and escaped for the card, so send a smaller one", .pHttpStatus, .pFault)
            Quit
        }

        Set tArgs = {}
        Do tArgs.%Set(pIdArgument, pIdValue, "string")
        Do tArgs.%Set("Document", pArgs.%Get("Document"))
        Do tArgs.%Set("Namespace", tNamespace, "string")
        Do tArgs.%Set("Hunk", tHunk)
        For tName = "rationale", "expectedImpact", "reverse" {
            If pArgs.%GetTypeOf(tName) = "string" Do tArgs.%Set(tName, pArgs.%Get(tName), "string")
        }
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The document <var>pDocument</var> as the indented text the card shows, one member to a line, lines ended by a line
/// feed. A document that cannot be formatted is its compact text.</p>
ClassMethod FormattedDocument(pDocument As %DynamicObject) As %String
{
    Set tText = ""
    Try {
        Set tFormatter = ##class(%JSON.Formatter).%New()
        Set tFormatter.LineTerminator = $Char(10)
        Set tSC = tFormatter.FormatToString(pDocument, .tText)
        If $$$ISERR(tSC) Set tText = pDocument.%ToJSON()
    } Catch {
        Set tText = pDocument.%ToJSON()
    }
    Quit tText
}

}
