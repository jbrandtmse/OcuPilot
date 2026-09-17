/// <p>The one corpus both engines of the <code>tab</code> grammar run (AD-5):
/// <method>OcuPilot.Screen.Registry.TabProblem</method> and
/// <method>OcuPilot.Screen.Registry.TabGroupProblem</method> in <class>OcuPilot.Test.Descriptor</class>,
/// and <code>tabProblem</code> and <code>tabGroupProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk. Each
/// <code>cases</code> entry is a declaration and the exact sentence both engines return for it, or
/// <code>null</code> when it is sound; each <code>rosters</code> entry is a roster of
/// <code>{descriptor, declaration}</code> and the sentence the group rule returns for it.</p>
/// <p>No position is a JSON boolean: the two engines render one into a sentence differently, and no
/// declaration writes one.</p>
Class OcuPilot.Test.TabCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "cases": [
    {"name": "the group's first tab is sound", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": null},
    {"name": "a later tab at side-bar position 0 is sound", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": 2, "labelKey": "oauthTabClients"}}, "expected": null},
    {"name": "a first tab may itself be unlisted", "declaration": {"route": "security/oauth", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": null},
    {"name": "an absent tab is a screen that is no tab", "declaration": {"route": "security/ssl", "sideBarPosition": 1}, "expected": null},
    {"name": "a null tab is a screen that is no tab", "declaration": {"route": "security/ssl", "sideBarPosition": 1, "tab": null}, "expected": null},
    {"name": "an array is not a tab", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": []}, "expected": "tab is not an object declaring its group, position and labelKey (AD-5)"},
    {"name": "a route alone is not a tab", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": "security/oauth"}, "expected": "tab is not an object declaring its group, position and labelKey (AD-5)"},
    {"name": "an unknown key", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions", "label": "Client server descriptions"}}, "expected": "tab declares the unknown key 'label'"},
    {"name": "a group that is not lower case is not a route", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "Security/OAuth", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.group 'Security/OAuth' is not a route"},
    {"name": "a group with a leading slash is not a route", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "/security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.group '/security/oauth' is not a route"},
    {"name": "an empty group is not a route", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.group '' is not a route"},
    {"name": "a missing group is not a route", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.group '' is not a route"},
    {"name": "position 0 is refused", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 0, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.position '0' is not a whole number of at least 1"},
    {"name": "a negative position is refused", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": -1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.position '-1' is not a whole number of at least 1"},
    {"name": "a fractional position is refused", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": 1.5, "labelKey": "oauthTabClients"}}, "expected": "tab.position '1.5' is not a whole number of at least 1"},
    {"name": "a position written as a string is refused", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": "2", "labelKey": "oauthTabClients"}}, "expected": "tab.position '2' is not a whole number of at least 1"},
    {"name": "a missing position is refused", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 0, "tab": {"group": "security/oauth", "labelKey": "oauthTabClients"}}, "expected": "tab.position '' is not a whole number of at least 1"},
    {"name": "an empty labelKey is refused", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 1, "labelKey": ""}}, "expected": "tab.labelKey is empty, and a tab names the string key its label reads"},
    {"name": "a missing labelKey is refused", "declaration": {"route": "security/oauth", "sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 1}}, "expected": "tab.labelKey is empty, and a tab names the string key its label reads"},
    {"name": "position 1 away from the group's route is refused", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabClients"}}, "expected": "tab.position 1 is the group's own route, and route 'security/oauth/clients' is not tab.group 'security/oauth' (AD-5)"},
    {"name": "position 1 on a declaration with no route is refused", "declaration": {"sideBarPosition": 5, "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions"}}, "expected": "tab.position 1 is the group's own route, and route '' is not tab.group 'security/oauth' (AD-5)"},
    {"name": "a later position at the group's own route is refused", "declaration": {"route": "security/oauth", "sideBarPosition": 0, "tab": {"group": "security/oauth", "position": 2, "labelKey": "oauthTabClients"}}, "expected": "tab.group 'security/oauth' is this screen's own route, which only tab.position 1 may declare (AD-5)"},
    {"name": "a later tab that takes a side-bar position is refused", "declaration": {"route": "security/oauth/clients", "sideBarPosition": 6, "tab": {"group": "security/oauth", "position": 2, "labelKey": "oauthTabClients"}}, "expected": "tab.position 2 is a tab under its group's first, and such a tab declares sideBarPosition 0 (AD-5)"},
    {"name": "a later tab that declares no side-bar position is refused", "declaration": {"route": "security/oauth/server", "tab": {"group": "security/oauth", "position": 4, "labelKey": "oauthTabServer"}}, "expected": "tab.position 4 is a tab under its group's first, and such a tab declares sideBarPosition 0 (AD-5)"}
  ],
  "rosters": [
    {"name": "a sound group of three beside a screen that is no tab", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 3, "labelKey": "oauthTabResourceServers"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.C", "declaration": {"route": "security/tabs/c", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.D", "declaration": {"route": "security/ssl", "area": "security", "archetype": "list", "built": true, "sideBarPosition": 1}}
    ], "expected": null},
    {"name": "a group of one is sound", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}}
    ], "expected": null},
    {"name": "a group whose route no member declares", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.C", "declaration": {"route": "security/tabs/c", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 3, "labelKey": "oauthTabResourceServers"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.B: tab.group 'security/tabs' names no built member at that route, and a tab group opens at its first tab (AD-5)"},
    {"name": "a group whose first tab is not built", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": false, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.A: tab.group 'security/tabs' names no built member at that route, and a tab group opens at its first tab (AD-5)"},
    {"name": "a member in another area", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "logs/tabs/b", "area": "logs", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.B: tab.group 'security/tabs' is declared in area 'logs' with archetype 'detail', and a tab group's members share the area and archetype of 'security/tabs' (AD-5)"},
    {"name": "a member on another archetype", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.C", "declaration": {"route": "security/tabs/c", "area": "security", "archetype": "list", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 3, "labelKey": "oauthTabResourceServers"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.C: tab.group 'security/tabs' is declared in area 'security' with archetype 'list', and a tab group's members share the area and archetype of 'security/tabs' (AD-5)"},
    {"name": "a gap in the positions", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 3, "labelKey": "oauthTabClients"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.A: tab.group 'security/tabs' declares positions 1,3, and a tab group's positions run 1 to 2 with no gap or repeat (AD-5)"},
    {"name": "a repeated position", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.B", "declaration": {"route": "security/tabs/b", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabClients"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.C", "declaration": {"route": "security/tabs/c", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "security/tabs", "position": 2, "labelKey": "oauthTabResourceServers"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.A: tab.group 'security/tabs' declares positions 1,2,2, and a tab group's positions run 1 to 3 with no gap or repeat (AD-5)"},
    {"name": "a sound group before a faulty one", "screens": [
      {"descriptor": "OcuPilot.Test.TabCorpus.A", "declaration": {"route": "security/tabs", "area": "security", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "security/tabs", "position": 1, "labelKey": "oauthTabServerDescriptions"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.E", "declaration": {"route": "logs/other", "area": "logs", "archetype": "detail", "built": true, "sideBarPosition": 5, "tab": {"group": "logs/other", "position": 1, "labelKey": "oauthTabServer"}}},
      {"descriptor": "OcuPilot.Test.TabCorpus.F", "declaration": {"route": "logs/other/f", "area": "logs", "archetype": "detail", "built": true, "sideBarPosition": 0, "tab": {"group": "logs/other", "position": 1, "labelKey": "oauthTabServerClients"}}}
    ], "expected": "OcuPilot.Test.TabCorpus.E: tab.group 'logs/other' declares positions 1,1, and a tab group's positions run 1 to 2 with no gap or repeat (AD-5)"}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{cases, rosters}</code>.</p>
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
