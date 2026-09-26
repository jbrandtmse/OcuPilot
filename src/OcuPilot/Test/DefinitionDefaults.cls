/// <p>A new agent definition is read/write and a new Anthropic definition's model is
/// <code>claude-opus-5-5</code>, and neither a stored read-only flag nor a stored model is ever
/// rewritten: <property>OcuPilot.Kernel.State.Agent.ReadOnly</property>'s class default, read
/// through <method>%New</method> and through a stored row, the verdict
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> answers for such a row, a stored 1 and 0 and a
/// stored model each surviving a production install, and an explicit model kept through a create
/// and an update over <code>/agent/definitions</code>.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives; the switch row is
/// reset the same way, so no kill switch or enforced read-only decides the verdict.</p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it.</p>
Class OcuPilot.Test.DefinitionDefaults Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The prefix every definition this class creates is named with, so
/// <class>OcuPilot.Test.AgentFixture</class>'s teardown finds them all.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The user the verdict is asked for. A weak reference (AD-37): no principal of this name
/// exists, and none is needed.</p>
Parameter PROBEUSER = "OcuPilotProbeDefaultsUser";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DefinitionDefaults runs OcuPilot's PRODUCTION install on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row is reset")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Do $$$AssertStatusOK(tSC, "the probe definitions are removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    Quit $$$OK
}

/// <p>The stored flag of definition <var>pId</var>, read fresh, or <code>""</code> when the row
/// cannot be opened. The caller holds no reference to the row, so the open reads storage.</p>
ClassMethod StoredReadOnly(pId As %String) As %String
{
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit ""
    Set tValue = +tRow.ReadOnly
    Set tRow = ""
    Quit tValue
}

/// <p>The stored model of definition <var>pId</var>, read fresh, or <code>""</code> when the row
/// cannot be opened. The caller holds no reference to the row, so the open reads storage.</p>
ClassMethod StoredModel(pId As %String) As %String
{
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit ""
    Set tValue = tRow.Model
    Set tRow = ""
    Quit tValue
}

/// <p>A new definition is read/write: <method>%New</method> starts at 0, a row created without
/// the flag stores 0, and the verdict for that row does not block.</p>
Method TestANewDefinitionIsReadWrite()
{
    Set tNew = ##class(OcuPilot.Kernel.State.Agent).%New()
    Do $$$AssertEquals(+tNew.ReadOnly, 0, "%New() starts read/write")
    Set tNew = ""

    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Default", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a probe definition is created without the flag")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertEquals(..StoredReadOnly(tId), 0, "and stores read/write")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 0, "and does not block a write")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", "with the off footer key")
}

/// <p>A stored 1 and a stored 0 each survive a production install and every registered migration
/// step, run from schema version 0: nothing in the install or upgrade path rewrites the flag.</p>
Method TestAStoredFlagSurvivesAnInstall()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "KeptOn", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tOnId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(tOnId, 1), "and is stored read-only")

    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "KeptOff", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a second probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tOffId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(tOffId, 0), "and is stored read/write")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the production install runs")

    Do $$$AssertEquals(..StoredReadOnly(tOnId), 1, "the stored read-only flag is still 1")
    Do $$$AssertEquals(..StoredReadOnly(tOffId), 0, "and the stored read/write flag is still 0")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).RunMigrations("", 0, .tReports), "every migration step runs from schema version 0")
    Do $$$AssertEquals(..StoredReadOnly(tOnId), 1, "the stored read-only flag is still 1 after the migrations")
    Do $$$AssertEquals(..StoredReadOnly(tOffId), 0, "and the stored read/write flag is still 0 after them")
}

/// <p>An Anthropic definition created over <code>POST /agent/definitions</code> without a model
/// takes the catalog row's default, <code>claude-opus-5-5</code>.</p>
Method TestAnOmittedAnthropicModelIsClaudeOpus55()
{
    Set tSC = ##class(OcuPilot.Test.AgentWire).Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Opus"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201 Created: " _ $Get(tBody))
    If tStatus '= 201 Quit
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tCreated.model, "claude-opus-5-5", "the omitted model is claude-opus-5-5")
    Do $$$AssertEquals(..StoredModel(tCreated.id), "claude-opus-5-5", "and is stored so")
}

/// <p>A model named on the create is stored as named, an update that omits the model leaves it,
/// and a read answers it.</p>
Method TestAnExplicitModelIsKeptThroughACreateAndAnUpdate()
{
    Set tSC = ##class(OcuPilot.Test.AgentWire).Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Kept"",""provider"":""anthropic"",""model"":""claude-opus-5"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201 Created: " _ $Get(tBody))
    If tStatus '= 201 Quit
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Set tId = tCreated.id
    Do $$$AssertEquals(tCreated.model, "claude-opus-5", "an explicit model is kept on the create")

    Set tSC = ##class(OcuPilot.Test.AgentWire).Call("PUT", "/" _ tId, "{""maxTokens"":4000}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the update request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Get(tBody))
    If tStatus = 200 {
        Set tUpdated = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tUpdated.maxTokens, 4000, "the update was applied")
        Do $$$AssertEquals(tUpdated.model, "claude-opus-5", "an update that omits the model keeps it")
    }

    Set tSC = ##class(OcuPilot.Test.AgentWire).Call("GET", "/" _ tId, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Get(tBody))
    If tStatus = 200 {
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).model, "claude-opus-5", "and the read answers the kept model")
    }
    Do $$$AssertEquals(..StoredModel(tId), "claude-opus-5", "the stored model is the one named")
}

/// <p>A stored model survives a production install and every registered migration step, run from
/// schema version 0: nothing in the install or upgrade path rewrites it to the catalog default.</p>
Method TestAStoredModelSurvivesAnInstallAndEveryMigration()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Stored", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertEquals(..StoredModel(tId), "claude-opus-5", "the probe stores the former default")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the production install runs")
    Do $$$AssertEquals(..StoredModel(tId), "claude-opus-5", "the stored model is unchanged by the install")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).RunMigrations("", 0, .tReports), "every migration step runs from schema version 0")
    Do $$$AssertEquals(..StoredModel(tId), "claude-opus-5", "and unchanged by the migrations")
}

}
