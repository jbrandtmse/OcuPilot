/// <p>The Definition form's own declaration (AD-24, AD-35) -- the one property no other test in
/// the tree reads. <class>OcuPilot.Screen.Descriptor.AgentDefinitionForm</class> declares no
/// <code>read</code>, and <method>OcuPilot.Screen.Registry.ReadProblem</method> validates
/// <code>context.secretFields</code> only inside its read-declaring branch, so a screen with no
/// read carries its <code>context</code> block entirely unchecked by the registry: an install
/// still succeeds, and every other suite in this tree stays green, whether the key is declared
/// secret, misspelled, or dropped. <method>OcuPilot.Test.Descriptor</method> and
/// <method>OcuPilot.Test.Wire</method> pin this descriptor's route, its privilege pair and its
/// <code>sideBarPosition</code> 0 against the real navigation map; neither reads
/// <code>context</code> at all.</p>
/// <p>No fixture and no HTTP call: the declaration is read straight off the compiled class, the
/// same way every other declaration-value test in this tree does.</p>
Class OcuPilot.Test.AgentDefinitionForm Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AgentDefinitionForm";

/// <p>AD-24, AD-35 -- the key is the form's one secret-typed field, declared so the context
/// serializer can never emit it, and <code>context.fields</code> is empty today, which is the
/// class comment's own point: there is nothing yet for the declaration to strip, so its being
/// declared now is the guarantee that a field added to <code>context.fields</code> later meets a
/// serializer already told to withhold it.</p>
/// <p>Mutation: change <code>"secretFields": ["apiKey"]</code> to <code>[]</code> in
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionForm</class> -> this goes red, and nothing
/// else in the tree does, which is the gap this class closes.</p>
Method TestTheFormDeclaresApiKeyAsItsOneSecretField()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 1, "exactly one secret field is declared")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Get(0), "apiKey", "and it is the key, named by its wire field")
    Do $$$AssertEquals(tDeclaration.context.fields.%Size(), 0, "context.fields is empty: nothing is served to strip yet")
}

/// <p>The rest of the declaration a form-page reached from its own list carries: no
/// <code>read</code> and no <code>table</code> (AD-36 -- a form is one entity, not a list of
/// rows), a single id (the route's own id segment), and no classic equivalent (AD-44).</p>
/// <p>Mutation: give the declaration a <code>"table"</code> key -> the first assertion below goes
/// red on the unknown-key refusal <method>OcuPilot.Screen.Registry.DeclarationProblem</method>
/// reports for it, since <code>table</code> with no <code>read</code> is what that rule exists
/// to catch.</p>
Method TestTheFormDeclaresNoReadOrTableAndOneIdAndNoClassicPage()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read"), "unassigned", "a form loads one entity by id, not a declared read")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("table"), "unassigned", "and renders no table")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""single"",""parts"":[]}", "the route's own id segment names the definition")
    Do $$$AssertEquals(tDeclaration.classicPage, "", "the classic portal has no agent definition")
    Do $$$AssertEquals(''tDeclaration.classicLinkExemption.exempt, 0, "so the exemption is declared false, not left absent (AD-44)")

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration's own top-level keys are sound")
}

}
