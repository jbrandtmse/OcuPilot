/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam:
/// the live read goes to <class>OcuPilot.Test.ProposalFixture</class>'s armed object instead of the
/// admin port, so the <b>shipped</b> predicates run against a target a test composed.</p>
/// <p>Everything else -- the covered-type refusal, the predicate order, the rendered comparison, the
/// diff scoping and the serving-path read -- is the shipped code.</p>
/// <p>It also holds the builders the two prohibited suites share: one web application as the
/// vendor's <code>GET</code> shapes it, one stored diff, one target reference, the digest the
/// shipped confirm re-computes for a target, and one direct question to the set. They are here
/// rather than duplicated in each suite, and they assert nothing.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProhibitedFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

/// <p>The write tool both suites drive the set through.</p>
Parameter TOOL = "webapp.list.update";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

/// <p>One web application as the vendor's own <code>GET</code> shapes it, as compact JSON: the six
/// properties the named predicates read, in the types the instance answers with, plus any further
/// <var>pExtra</var> members a test needs (<code>pExtra(&lt;name&gt;) = $ListBuild(value, type)</code>)
/// -- which is how a property this build's endpoint does not carry is put in front of the set.</p>
ClassMethod App(pPath As %String, pAuthe As %Integer, pResource As %String, pDispatch As %String, pRoles As %String, pEnabled As %Boolean, pDescription As %String = "before", ByRef pExtra) As %String
{
    Set tObject = {}
    Do tObject.%Set("Name", pPath, "string")
    Do tObject.%Set("AutheEnabled", pAuthe, "number")
    Do tObject.%Set("Resource", pResource, "string")
    Do tObject.%Set("DispatchClass", pDispatch, "string")
    Do tObject.%Set("MatchRoles", pRoles, "string")
    Do tObject.%Set("Enabled", ''pEnabled, "boolean")
    Do tObject.%Set("Description", pDescription, "string")
    Set tName = ""
    For {
        Set tName = $Order(pExtra(tName))
        If tName = "" Quit
        Do tObject.%Set(tName, $List(pExtra(tName), 1), $List(pExtra(tName), 2))
    }
    Quit tObject.%ToJSON()
}

/// <p>A stored diff naming every field of the comma-separated <var>pFields</var>, as the mint's own
/// <code>[{field, before, after}]</code>.</p>
/// <p>The values are not what the set reads -- it compares the payload against the live target --
/// so they are placeholders and the names are the contract. A test that needs the set to ignore a
/// field leaves it out of this list, which is the state a third party's change after the mint
/// leaves behind.</p>
ClassMethod Diff(pFields As %String) As %String
{
    Set tRows = []
    For tI = 1:1:$Length(pFields, ",") {
        Set tField = $Piece(pFields, ",", tI)
        If tField = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", "before", "string")
        Do tRow.%Set("after", "after", "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows.%ToJSON()
}

/// <p>The reference key for <var>pPath</var> as a proposal's target of type <var>pType</var>, or
/// <code>""</code> when the kernel refuses to build one.</p>
ClassMethod Reference(pPath As %String, pType As %String = "web-application") As %String
{
    Set tRef = ""
    Do ##class(OcuPilot.Kernel.EntityRef).Key(pType, "instance", pPath, .tRef)
    Quit tRef
}

/// <p>The digest the shipped confirm re-computes for the target <var>pFresh</var> (compact JSON)
/// when the row's stored arguments are empty: the shipped merge over that read, hashed with the
/// tool's own descriptor exclusions, through the same methods
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> calls. <code>""</code> when
/// any of them refuses.</p>
ClassMethod Digest(pFresh As %String) As %String
{
    Set tDigest = ""
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "Resolve", ..#TOOL, .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) Quit
        Set tClass = tTool.%Get("class")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(##class(%DynamicAbstractObject).%FromJSON(pFresh), {}, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) || (tProblem '= "") Quit
        Set tExcludes = ""
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, tExcludes, .tDigest)
        If $$$ISERR(tSC) Set tDigest = ""
    } Catch {
        Set tDigest = ""
    }
    Quit tDigest
}

/// <p>Ask this set about <var>pPayload</var> and <var>pDiff</var> against the armed target
/// <var>pFresh</var>, for the target <var>pPath</var> of type <var>pType</var>.</p>
ClassMethod Ask(pFresh As %String, pPayload As %String, pDiff As %String, pPath As %String, pType As %String = "web-application", Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(pFresh)
    Quit ..Prohibits(..#TOOL, ..Reference(pPath, pType), pPayload, pDiff, .pProhibits, .pCode)
}

}
