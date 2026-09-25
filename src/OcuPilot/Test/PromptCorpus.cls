/// <p>The one corpus both engines of the <code>suggestedPrompts</code> grammar run (Story 11.3's
/// contract): <method>OcuPilot.Screen.Registry.SuggestedPromptsProblem</method> in
/// <class>OcuPilot.Test.Descriptor</class>, and <code>suggestedPromptsProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk. Each case is a
/// declaration and the exact sentence both engines return for it, or <code>null</code> when it is
/// sound.</p>
Class OcuPilot.Test.PromptCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "cases": [
    {"name": "no prompts declared is sound", "declaration": {}, "expected": null},
    {"name": "a null declares none", "declaration": {"suggestedPrompts": null}, "expected": null},
    {"name": "three prompts are sound", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": "a"}, {"groupKey": "g", "textKey": "b"}, {"groupKey": "h", "textKey": "c"}]}, "expected": null},
    {"name": "an object is not an array", "declaration": {"suggestedPrompts": {"groupKey": "g", "textKey": "a"}}, "expected": "suggestedPrompts is not an array of prompts"},
    {"name": "two prompts are too few", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": "a"}, {"groupKey": "g", "textKey": "b"}]}, "expected": "suggestedPrompts declares 2, and a screen that declares prompts declares at least 3"},
    {"name": "an empty list is too few", "declaration": {"suggestedPrompts": []}, "expected": "suggestedPrompts declares 0, and a screen that declares prompts declares at least 3"},
    {"name": "a prompt that is a string", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": "a"}, "b", {"groupKey": "h", "textKey": "c"}]}, "expected": "suggestedPrompts[1] is not an object declaring its groupKey and textKey"},
    {"name": "a prompt with an unknown key", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": "a", "text": "Why?"}, {"groupKey": "g", "textKey": "b"}, {"groupKey": "h", "textKey": "c"}]}, "expected": "suggestedPrompts[0] declares the unknown key 'text'"},
    {"name": "a prompt with no group", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": "a"}, {"groupKey": "g", "textKey": "b"}, {"textKey": "c"}]}, "expected": "suggestedPrompts[2].groupKey is empty, and a prompt names the string key it reads"},
    {"name": "a prompt with an empty text key", "declaration": {"suggestedPrompts": [{"groupKey": "g", "textKey": ""}, {"groupKey": "g", "textKey": "b"}, {"groupKey": "h", "textKey": "c"}]}, "expected": "suggestedPrompts[0].textKey is empty, and a prompt names the string key it reads"}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{cases}</code>.</p>
ClassMethod Corpus(Output pCorpus As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pCorpus = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the corpus XData block is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pCorpus = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
