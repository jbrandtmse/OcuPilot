/// <p>Pins <class>OcuPilot.Kernel.Shell.Guardrails</class> (Story 16.22): every member of the answer
/// is the enforcing declaration's own -- the prohibited set's codes and sentences, the registry's
/// advertised write tools and their secret arguments, the caller's verdict and the context caps --
/// and a part that cannot be read fails the whole answer. It also pins the Guardrails descriptor as
/// a listed, ungated Agent co-pilot screen with no read.</p>
/// <p>Sentences are compared against <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>,
/// never written here (<class>OcuPilot.Test.Prohibited</class> refuses a second copy). Needs a
/// compiled instance; makes no request and writes nothing.</p>
Class OcuPilot.Test.Guardrails Extends %UnitTest.TestCase
{

Parameter SHIPPED = "OcuPilot.Kernel.Shell.Guardrails";

Parameter FIXTURE = "OcuPilot.Test.GuardrailsFixture";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AgentGuardrails";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The one unadvertised write tool (AD-53).</p>
Parameter UNADVERTISED = "security.auditing.purge";

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuGuardrailsFault
    Quit $$$OK
}

/// <p>(a) Every code the set declares is a row, in declared order, whose reason is that code's own
/// non-empty sentence.</p>
/// <p>Mutation: blank <parameter>OcuPilot.Kernel.Proposal.Prohibited.UNCOVEREDFIELDREASON</parameter>
/// -&gt; this goes red.</p>
Method TestEveryProhibitedCodeIsARowWithItsOwnSentence()
{
    Set tSC = $ClassMethod(..#SHIPPED, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the answer is composed")
    If '$IsObject(tAnswer) Quit
    Set tCodes = $ClassMethod(..#PROHIBITED, "Codes")
    Set tRows = tAnswer.%Get("prohibited")
    Do $$$AssertEquals(tRows.%Size(), $ListLength(tCodes), "one row per declared code")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tRow = tRows.%Get(tI - 1)
        If '$IsObject(tRow) {
            Do $$$AssertTrue(0, "row " _ tI _ " is present")
            Continue
        }
        Do $$$AssertEquals(tRow.%Get("code"), tCode, "row " _ tI _ " is " _ tCode)
        Do $$$AssertNotEquals(tRow.%Get("reason"), "", tCode _ " carries a reason")
        Do $$$AssertEquals(tRow.%Get("reason"), $ClassMethod(..#PROHIBITED, "ReasonFor", tCode), tCode _ "'s reason is the set's own sentence")
    }
}

/// <p>(b) A code added to the set appears last with its sentence, with no other edit.</p>
/// <p>Mutation: iterate a fixed list in place of <method>ProhibitedClass</method>'s
/// <code>Codes()</code> in <method>OcuPilot.Kernel.Shell.Guardrails.Read</method> -&gt; this goes
/// red.</p>
Method TestACodeAddedToTheSetAppearsLastWithItsSentence()
{
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the fixture answer is composed")
    If '$IsObject(tAnswer) Quit
    Set tRows = tAnswer.%Get("prohibited")
    Do $$$AssertEquals(tRows.%Size(), $ListLength($ClassMethod(..#PROHIBITED, "Codes")) + 1, "the fixture set's extra code is one more row")
    Set tLast = tRows.%Get(tRows.%Size() - 1)
    Do $$$AssertEquals($Select($IsObject(tLast): tLast.%Get("code"), 1: ""), $Parameter(..#FIXTURE, "PROBECODE"), "and it is the last row")
    Do $$$AssertEquals($Select($IsObject(tLast): tLast.%Get("reason"), 1: ""), $ClassMethod(..#FIXTURE, "ReasonFor", $Parameter(..#FIXTURE, "PROBECODE")), "carrying its own sentence")
}

/// <p>(c) The tools that need a Confirm are the registry's advertised write tools in name order,
/// each naming a registered descriptor, and the unadvertised purge is not among them.</p>
/// <p>Mutation: drop the <code>advertised</code> filter in
/// <method>OcuPilot.Kernel.Shell.Guardrails.Read</method> -&gt; this goes red.</p>
Method TestConfirmToolsAreTheAdvertisedWriteTools()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    If $$$ISERR(tSC) Quit
    Set tExpected = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If (tTool.%Get("kind") = "write") && tTool.%Get("advertised") Set tExpected = tExpected _ $ListBuild(tTool.%Get("name"))
    }
    Do $$$AssertTrue($ListLength(tExpected) > 0, "the registry advertises write tools")

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the screen registry lists its descriptors")

    Set tSC = $ClassMethod(..#SHIPPED, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the answer is composed")
    If '$IsObject(tAnswer) Quit
    Set tActual = ""
    Set tIterator = tAnswer.%Get("confirmTools").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tActual = tActual _ $ListBuild(tRow.%Get("name"))
        Do $$$AssertTrue($ListFind(tDescriptors, tRow.%Get("descriptor")) > 0, tRow.%Get("name") _ " names a registered descriptor: " _ tRow.%Get("descriptor"))
    }
    Do $$$AssertEquals($ListToString(tActual), $ListToString(tExpected), "the advertised write tools, in name order")
    Do $$$AssertEquals($ListFind(tActual, ..#UNADVERTISED), 0, ..#UNADVERTISED _ " is not listed")
}

/// <p>(d) The secret list is each advertised write tool's declared secret arguments, listing only a
/// tool that declares one, and the password tool carries <code>Password</code>.</p>
Method TestSecretsAreEachToolsDeclaredSecretArguments()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    If $$$ISERR(tSC) Quit
    Kill tExpected
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If (tTool.%Get("kind") '= "write") || 'tTool.%Get("advertised") Continue
        Set tNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tDeclared)
        Do $$$AssertTrue(tDeclared, tTool.%Get("name") _ " declares its secret arguments")
        If $ListLength(tNames) Set tExpected(tTool.%Get("name")) = $ListToString(tNames)
    }

    Set tSC = $ClassMethod(..#SHIPPED, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the answer is composed")
    If '$IsObject(tAnswer) Quit
    Kill tActual
    Set tIterator = tAnswer.%Get("secrets").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = ""
        Set tFieldIterator = tRow.%Get("fields").%GetIterator()
        While tFieldIterator.%GetNext(.tFieldIndex, .tField) {
            Set tFields = tFields _ $ListBuild(tField)
        }
        Do $$$AssertTrue($ListLength(tFields) > 0, tRow.%Get("tool") _ " is listed with at least one field")
        Set tActual(tRow.%Get("tool")) = $ListToString(tFields)
    }
    Set tName = ""
    For {
        Set tName = $Order(tExpected(tName))
        If tName = "" Quit
        Do $$$AssertEquals($Get(tActual(tName)), tExpected(tName), tName _ "'s secret arguments")
    }
    Set tName = ""
    For {
        Set tName = $Order(tActual(tName))
        If tName = "" Quit
        Do $$$AssertTrue($Data(tExpected(tName)), tName _ " is listed because it declares a secret")
    }
    Do $$$AssertTrue($ListFind($ListFromString($Get(tActual("permissions.users.password"))), "Password"), "permissions.users.password carries Password")
}

/// <p>(e) The limits are the row cap in force and the kernel's two character caps.</p>
Method TestTheLimitsAreTheKernelsOwn()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
    Do $$$AssertStatusOK(tSC, "the switches are read")
    Set tSC = $ClassMethod(..#SHIPPED, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the answer is composed")
    If '$IsObject(tAnswer) Quit
    Set tLimits = tAnswer.%Get("limits")
    Do $$$AssertEquals(tLimits.%Get("contextRowCap"), +tValues("contextRowCap"), "the row cap in force")
    Do $$$AssertEquals(tLimits.%Get("totalMaxLength"), ##class(OcuPilot.Kernel.Agent.Limits).#TOOLRESULTMAXLENGTH, "the total character cap")
    Do $$$AssertEquals(tLimits.%Get("fieldMaxLength"), ##class(OcuPilot.Kernel.Agent.Limits).#FIELDMAXLENGTH, "the per-field character cap")
}

/// <p>(f) The switches are the caller's verdict: a kill switch held for the caller with enforced
/// read-only on reads so.</p>
Method TestTheSwitchesAreTheCallersVerdict()
{
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tAnswer)
    Do $$$AssertStatusOK(tSC, "the fixture answer is composed")
    If '$IsObject(tAnswer) Quit
    Set tSwitches = tAnswer.%Get("switches")
    Do $$$AssertEquals(tSwitches.%GetTypeOf("killSwitch"), "boolean", "the kill switch is a boolean")
    Do $$$AssertEquals(tSwitches.%Get("killSwitch"), 1, "the kill switch is on")
    Do $$$AssertEquals(tSwitches.%Get("killSwitchAudience"), "you", "for the caller")
    Do $$$AssertEquals(tSwitches.%Get("enforcedReadOnly"), 1, "and enforced read-only is on")

    Set tSC = $ClassMethod(..#SHIPPED, "Read", .tShipped)
    Do $$$AssertStatusOK(tSC, "the shipped answer is composed")
    If '$IsObject(tShipped) Quit
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Resolved($Username, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the caller's verdict is read")
    Do $$$AssertEquals(tShipped.%Get("switches").%Get("enforcedReadOnly"), +tVerdict("enforcedReadOnly"), "the shipped answer reads the verdict's enforced read-only")
    Do $$$AssertEquals(tShipped.%Get("switches").%Get("killSwitchAudience"), tVerdict("killSwitchAudience"), "and its kill-switch audience")
}

/// <p>A part that cannot be read fails the whole answer, never a partial one.</p>
Method TestAnUnreadablePartFailsTheWholeAnswer()
{
    Set ^||OcuGuardrailsFault = "verdict"
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tAnswer)
    Do $$$AssertStatusNotOK(tSC, "an unreadable verdict fails the answer")
    Do $$$AssertEquals(tAnswer, "", "and nothing is answered")
}

/// <p>A registry that cannot list its tools fails the whole answer.</p>
/// <p>Mutation: read a failed <code>ListTools</code> as an empty list in
/// <method>OcuPilot.Kernel.Shell.Guardrails.Read</method> -&gt; this goes red.</p>
Method TestAnUnlistedRegistryFailsTheWholeAnswer()
{
    Set ^||OcuGuardrailsFault = "tools"
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tAnswer)
    Do $$$AssertStatusNotOK(tSC, "a failed tool list fails the answer")
    Do $$$AssertEquals(tAnswer, "", "and nothing is answered")
}

/// <p>An advertised write tool whose secret arguments answer undeclared fails the whole answer
/// rather than reading as a tool with none.</p>
/// <p>Mutation: skip the <code>declared</code> check in
/// <method>OcuPilot.Kernel.Shell.Guardrails.Read</method> -&gt; this goes red.</p>
Method TestAnUndeclaredSecretListFailsTheWholeAnswer()
{
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tClean)
    Do $$$AssertStatusOK(tSC, "without the fault the fixture answer is composed")
    Set tListed = 0
    If $IsObject(tClean) {
        Set tIterator = tClean.%Get("confirmTools").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("name") = $Parameter(..#FIXTURE, "UNDECLAREDTOOL") Set tListed = 1
        }
    }
    Do $$$AssertTrue(tListed, $Parameter(..#FIXTURE, "UNDECLAREDTOOL") _ " is an advertised write tool")

    Set ^||OcuGuardrailsFault = "secrets"
    Set tSC = $ClassMethod(..#FIXTURE, "Read", .tAnswer)
    Do $$$AssertStatusNotOK(tSC, "an undeclared secret list fails the answer")
    Do $$$AssertEquals(tAnswer, "", "and nothing is answered")
}

/// <p>(g) The descriptor is a built, listed Agent co-pilot screen in the third position with no
/// pairs, no read and no tool of its own.</p>
/// <p>Mutation: declare <code>OcuPilotAdmin:USE</code> on the descriptor -&gt; this goes red, and
/// <class>OcuPilot.Test.Wire</class> reads it denied.</p>
Method TestTheDescriptorIsAListedUngatedAgentScreenWithNoRead()
{
    Set tDescriptor = ..#DESCRIPTOR
    Do $$$AssertTrue($ClassMethod(tDescriptor, "IsBuilt"), "the screen is built")
    Do $$$AssertEquals($ClassMethod(tDescriptor, "AreaKey"), "agent", "in the Agent co-pilot area")
    Do $$$AssertEquals($ClassMethod(tDescriptor, "SideBarPosition"), 3, "third in its side bar")
    Do $$$AssertEquals($ClassMethod(tDescriptor, "Route"), "agent/guardrails", "at its route")
    Do $$$AssertEquals($ListLength($ClassMethod(tDescriptor, "PrivilegePairs")), 0, "declaring no pairs")
    Do $$$AssertTrue('$IsObject($ClassMethod(tDescriptor, "Read")), "and no read")
    Do $$$AssertEquals($ClassMethod(tDescriptor, "PrimaryActionId"), "", "no primary action")
    Do $$$AssertEquals($ListLength($ClassMethod(tDescriptor, "RowActionIds")), 0, "and no row action")

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the screen registry lists its descriptors")
    Do $$$AssertTrue($ListFind(tDescriptors, tDescriptor) > 0, "which include this one")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    If $$$ISERR(tSC) Quit
    Set tPrefix = $ClassMethod(tDescriptor, "ToolIdentifier") _ "."
    Set tOwn = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If $Extract(tTool.%Get("name"), 1, $Length(tPrefix)) = tPrefix Set tOwn = tOwn _ $ListBuild(tTool.%Get("name"))
    }
    Do $$$AssertEquals($ListToString(tOwn), "", "no tool is the screen's own")
}

}
