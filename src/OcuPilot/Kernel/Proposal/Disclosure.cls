/// <p>The proposal card's unchanged-field disclosure (DW-1223, FR-17): the
/// <code>{field, value}</code> rows behind the published "N unchanged fields" caption, projected
/// from the payload a mint already stored.</p>
/// <p><b>Why it is its own class.</b> <class>OcuPilot.Kernel.State.Propose</class> writes the wire
/// shape and may name neither a screen nor a tool (AD-9), and the classification that decides
/// which values may travel is a screen-tool artifact. This class is the one place the two meet: it
/// names <class>OcuPilot.Screen.Tool.ToolFields</class>' generated block,
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> and the tool registry, and it reaches no
/// port, no tool body and no area.</p>
/// <p><b>It masks rather than withholds.</b> Every field the payload sends is disclosed and every
/// value the classification does not admit reads as the published mask, so the caption's count and
/// the rows behind it are one population, every field stays available (FR-17), and no secret value
/// reaches the wire (AD-3, AD-35).</p>
/// <p><b>A write that sends no body discloses nothing</b> (AD-51). The stored payload of an
/// action-style write is the fresh read the fingerprint covers, not a payload the confirm will
/// send, so disclosing its properties would tell the user that fields are being written which
/// are not. Such a proposal's stored <code>UnchangedCount</code> is 0 and this answers an empty
/// array, which is the same population read twice.</p>
Class OcuPilot.Kernel.Proposal.Disclosure Extends %RegisteredObject
{

/// <p>The published mask's code point, U+2022 BULLET, and how many of them the mask carries.
/// Non-ASCII is built from its code point, never written as a literal byte (Consistency
/// Conventions: client asset homes).</p>
Parameter MASKCODEPOINT As %Integer = 8226;

Parameter MASKWIDTH As %Integer = 8;

/// <p>The disclosure's rows (DW-1223, FR-17): one <code>{field, value}</code> per top-level
/// property of the stored payload <var>pDiff</var> does not name, in the payload's own order, for
/// the write tool <var>pToolName</var>.</p>
/// <p><b>A projection of data already in hand, not a second read.</b> The payload and the diff both
/// come from the one row read <class>OcuPilot.Kernel.State.Propose</class> already makes, and the
/// stored <code>UnchangedCount</code> is untouched -- the invariant the suite pins is that this
/// array's length equals it.</p>
/// <p><b>It masks, it does not withhold</b> (AD-3, AD-35, Conventions &gt; Secrets). A property
/// whose path this tool's field list classifies <code>ordinary</code> and shapes
/// <code>literal</code> -- as itself or as an array of literals -- carries its value, rendered by
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> so the disclosure and the diff read one
/// value the same way. Every other path carries <method>Mask</method> instead: a
/// <code>secret</code> or <code>opaque</code> row, a subtree the list describes only member by
/// member, and a property with no row at all. So the caption's count and the rows behind it are
/// one population, every field stays available, and no secret value reaches the wire. An
/// unreadable field list masks everything rather than disclosing anything.</p>
ClassMethod Rows(pToolName As %String, pPayload As %String, pDiff As %String) As %DynamicArray
{
    Set tRows = []
    Try {
        If pPayload = "" Quit
        If '..SendsBody(pToolName) Quit
        Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(pPayload)
        If '$IsObject(tPayload) || 'tPayload.%IsA("%Library.DynamicObject") Quit
        Kill tChanged
        Set tDiff = ..ParsedArray(pDiff)
        Set tDiffIterator = tDiff.%GetIterator()
        While tDiffIterator.%GetNext(.tDiffIndex, .tDiffRow) {
            If '$IsObject(tDiffRow) Continue
            Set tChanged(tDiffRow.%Get("field")) = 1
        }
        Set tReadable = ..OrdinaryPaths(pToolName, .tOrdinary)
        Set tIterator = tPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $Data(tChanged(tKey)) Continue
            Set tRow = {}
            Do tRow.%Set("field", tKey, "string")
            If tReadable && +$Get(tOrdinary(tKey)) {
                Do tRow.%Set("value", ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, tPayload.%GetTypeOf(tKey)), "string")
            } Else {
                Do tRow.%Set("value", ..Mask(), "string")
            }
            Do tRows.%Push(tRow)
        }
    } Catch {
        Set tRows = []
    }
    Quit tRows
}

/// <p>The proposal card's privilege line (AD-8, Story 11.8): <code>{requires, missing}</code> for
/// the pair specification <var>pRequired</var> a mint recorded, or <code>""</code> when it parses
/// to no pair -- nothing recorded, or a malformed specification -- or cannot be evaluated, which
/// logs a fault.</p>
/// <p><code>requires</code> is every pair spelled <code>resource:permission</code>, in recorded
/// order. <code>missing</code> is <method>OcuPilot.Kernel.Proposal.Operation.MissingPair</method>'s
/// answer for <var>pUser</var>, the check Confirm's gate makes, asked at this call and never
/// stored; <code>""</code> when every pair is held. <var>pHolderClass</var> is that method's seam.
/// <b>Caller contract:</b> call it outside any escalated frame (AD-9), so the answer is about the
/// user's own current grants.</p>
ClassMethod Privilege(pRequired As %String, pUser As %String, pHolderClass As %String = "") As %DynamicObject
{
    Set tPrivilege = ""
    Try {
        Set tPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec(pRequired)
        If tPairs = "" Quit
        Set tRequires = []
        For tI = 1:1:$ListLength(tPairs) {
            Set tPair = $List(tPairs, tI)
            Do tRequires.%Push($List(tPair, 1) _ ":" _ $List(tPair, 2), "string")
        }
        Set tPrivilege = {}
        Do tPrivilege.%Set("requires", tRequires)
        Do tPrivilege.%Set("missing", ##class(OcuPilot.Kernel.Proposal.Operation).MissingPair(pUser, tPairs, pHolderClass), "string")
    } Catch ex {
        Set tPrivilege = ""
        Do ##class(OcuPilot.Kernel.Fault).LogRaw("proposal", "the proposal's privilege line could not be evaluated", ex.AsStatus(), "")
    }
    Quit tPrivilege
}

/// <p>Whether the write tool <var>pToolName</var> sends a body at all (AD-51), resolved through
/// the tool registry as <method>OcuPilot.Kernel.Proposal.Mint.DestructiveTool</method> resolves
/// that tool's own destructive declaration. A name the registry does not carry, or a class that
/// answers nothing, sends one -- which discloses and masks rather than withholding, the direction
/// this class fails in everywhere else.</p>
ClassMethod SendsBody(pToolName As %String) As %Boolean [ Private ]
{
    Set tSends = 1
    Try {
        If $$$ISERR(##class(OcuPilot.Screen.Tool.Registry).Resolve(pToolName, .tTool)) Quit
        If '$IsObject(tTool) Quit
        If tTool.%Get("class") = "" Quit
        Set tSends = ''$ClassMethod(tTool.%Get("class"), "SendsBody")
    } Catch {
        Set tSends = 1
    }
    Quit tSends
}

/// <p>The top-level property names the write tool <var>pToolName</var>'s generated field list
/// classifies <code>ordinary</code> and shapes <code>literal</code>, as
/// <code>pPaths(name) = 1</code>. Answers 0 -- with <var>pPaths</var> empty -- when that block
/// cannot be read, because an unreadable field list is not a negative result and the caller masks
/// everything on it.</p>
/// <p>A top-level property is admitted by a row whose path is the name itself or the name with
/// <code>[]</code> (an array of literals). A deeper path never admits the property it sits under:
/// <code>MatchRoles[].MatchRole</code> does not make <code>MatchRoles</code> disclosable, which is
/// the fail-closed rule AD-3 states for the classification itself.</p>
/// <p>It reads <class>OcuPilot.Screen.Tool.ToolFields</class>' generated block directly and never
/// a tool class, which is why this projection lives here rather than in the store that calls it:
/// nothing under <package>OcuPilot.Kernel.State</package> may name a screen or a tool (AD-9), and
/// this class names one code-free generated block and no port at all.</p>
ClassMethod OrdinaryPaths(pToolName As %String, Output pPaths) As %Boolean [ Private ]
{
    Kill pPaths
    If pToolName = "" Quit 0
    Set tRead = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools", , .tOpenSC)
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        If '$IsObject(tTools) Quit
        Set tEntry = tTools.%Get(pToolName)
        If '$IsObject(tEntry) || (tEntry.%GetTypeOf("fields") '= "array") Quit
        Set tIterator = tEntry.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$IsObject(tField) Continue
            If tField.%Get("class") '= "ordinary" Continue
            If tField.%Get("shape") '= "literal" Continue
            Set tPath = tField.%Get("path")
            If tPath [ "." Continue
            If $Extract(tPath, *-1, *) = "[]" Set tPath = $Extract(tPath, 1, *-2)
            If tPath [ "[" Continue
            If tPath = "" Continue
            Set pPaths(tPath) = 1
        }
        Set tRead = 1
    } Catch {
        Kill pPaths
        Set tRead = 0
    }
    Quit tRead
}

/// <p>The published eight-bullet mask -- <code>MASKED_VALUE</code> in
/// <file>ui/src/app/core/proposal-view.ts</file>, which
/// <file>ui/tools/proposal-view.test.mjs</file> holds equal to this method's two parameters.</p>
ClassMethod Mask() As %String
{
    Quit $Translate($Justify("", ..#MASKWIDTH), " ", $Char(..#MASKCODEPOINT))
}

/// <p><var>pText</var> parsed as a JSON array, or an empty array when it is empty or unreadable --
/// a stored diff that cannot be read names no changed field, so every property discloses as
/// unchanged rather than the poll failing.</p>
ClassMethod ParsedArray(pText As %String) As %DynamicArray [ Private ]
{
    Set tArray = []
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tArray = tParsed
    } Catch {
        Set tArray = []
    }
    Quit tArray
}

}
