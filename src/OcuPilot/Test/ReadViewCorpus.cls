/// <p>The one corpus both implementations of the read view rule run (AD-36):
/// <method>OcuPilot.Screen.Read.ApplyView</method> in <class>OcuPilot.Test.ScreenRead</class> and
/// <code>applyView</code> in <file>ui/tools/screen-read.test.mjs</file>, which reads this block off
/// disk. Each case names a filter, a sort and a direction, and the row ids in the order the rule
/// produces; an empty string takes the declaration's own default. A case that carries its own
/// <code>rows</code> runs over those instead of the shared ones.</p>
/// <p>The rows mix case, carry integers, a fraction, booleans, a <code>null</code>, an absent key,
/// a non-ASCII capital written as a JSON escape, and a duplicate sort key. <code>Enabled</code>
/// and <code>Kind</code> mix kinds of value, so their cases pin the rule that only two numbers
/// compare numerically and every other pair compares by text. The <code>m</code> cases mix numbers
/// with numeric-looking text, where that comparison is not transitive, so they pin that both
/// implementations compare the same pairs in the same merge order.</p>
Class OcuPilot.Test.ReadViewCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "read": {"fields": ["Id", "Name", "Size", "Enabled", "Kind"], "filter": ["Name", "Kind"], "sort": {"fields": ["Name", "Size", "Enabled", "Kind"], "default": "Name", "direction": "asc"}},
  "rows": [
    {"Id": "r1", "Name": "alpha", "Size": 10, "Enabled": true, "Kind": "Web"},
    {"Id": "r2", "Name": "Beta", "Size": 9, "Kind": "web"},
    {"Id": "r3", "Name": "\u00c9clair", "Size": 0.5, "Enabled": null, "Kind": "CSP"},
    {"Id": "r4", "Name": "beta", "Size": null, "Enabled": true, "Kind": "REST"},
    {"Id": "r5", "Name": "alpha", "Size": 100, "Enabled": false, "Kind": 0.5},
    {"Id": "r6", "Name": null, "Size": 8, "Enabled": true, "Kind": "Web"},
    {"Id": "r7", "Name": "10", "Size": 2, "Enabled": "yes", "Kind": "\u00e9t\u00e9"},
    {"Id": "r8", "Name": true, "Size": -3, "Enabled": false, "Kind": "Web"}
  ],
  "cases": [
    {"name": "empty filter keeps every row in the declared default order", "filter": "", "sort": "", "direction": "", "expected": ["r7", "r2", "r1", "r5", "r4", "r8", "r3", "r6"]},
    {"name": "desc reverses non-null keys and keeps null last", "filter": "", "sort": "", "direction": "desc", "expected": ["r3", "r8", "r4", "r1", "r5", "r2", "r7", "r6"]},
    {"name": "numbers compare numerically, not by text", "filter": "", "sort": "Size", "direction": "asc", "expected": ["r8", "r3", "r7", "r6", "r2", "r1", "r5", "r4"]},
    {"name": "numbers descending, null still last", "filter": "", "sort": "Size", "direction": "desc", "expected": ["r5", "r1", "r2", "r6", "r7", "r3", "r8", "r4"]},
    {"name": "booleans and a string compare by text", "filter": "", "sort": "Enabled", "direction": "asc", "expected": ["r5", "r8", "r1", "r4", "r6", "r7", "r2", "r3"]},
    {"name": "filter is ASCII-case-insensitive on any filter field", "filter": "WEB", "sort": "", "direction": "", "expected": ["r2", "r1", "r8", "r6"]},
    {"name": "filter matches a substring of a later filter field", "filter": "st", "sort": "", "direction": "", "expected": ["r4"]},
    {"name": "a non-ASCII capital is not lower-cased", "filter": "\u00e9clair", "sort": "", "direction": "", "expected": []},
    {"name": "the non-ASCII capital itself matches", "filter": "\u00c9CLAIR", "sort": "", "direction": "", "expected": ["r3"]},
    {"name": "a filter matching nothing keeps nothing", "filter": "zzz", "sort": "", "direction": "", "expected": []},
    {"name": "a sort outside sort.fields takes the default", "filter": "", "sort": "Id", "direction": "desc", "expected": ["r3", "r8", "r4", "r1", "r5", "r2", "r7", "r6"]},
    {"name": "filter and sort together", "filter": "a", "sort": "Kind", "direction": "asc", "expected": ["r5", "r3", "r4", "r1", "r2"]},
    {"name": "a number is filtered by its JSON text", "filter": "0.5", "sort": "", "direction": "", "expected": ["r5"]},
    {"name": "a boolean is filtered by its text", "filter": "TRUE", "sort": "", "direction": "", "expected": ["r8"]},
    {"name": "an absent key sorts with null", "filter": "", "sort": "Enabled", "direction": "desc", "expected": ["r7", "r1", "r4", "r6", "r5", "r8", "r2", "r3"]},
    {"name": "a digit filter matches a numeric-looking string", "filter": "10", "sort": "Size", "direction": "desc", "expected": ["r7"]},
    {"name": "a number sorted against text compares by its JSON text", "rows": [{"Id": "n1", "Kind": 0.5}, {"Id": "n2", "Kind": "/a"}], "filter": "", "sort": "Kind", "direction": "asc", "expected": ["n2", "n1"]},
    {"name": "numbers among numeric-looking text sort in the shared merge order", "rows": [{"Id": "m1", "Kind": 10}, {"Id": "m2", "Kind": "9"}, {"Id": "m3", "Kind": 9}], "filter": "", "sort": "Kind", "direction": "asc", "expected": ["m3", "m1", "m2"]},
    {"name": "the shared merge order holds across a second merge width", "rows": [{"Id": "m1", "Kind": 10}, {"Id": "m2", "Kind": "9"}, {"Id": "m3", "Kind": 9}, {"Id": "m4", "Kind": "10"}, {"Id": "m5", "Kind": 8}], "filter": "", "sort": "Kind", "direction": "asc", "expected": ["m5", "m1", "m4", "m2", "m3"]}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{read, rows, cases}</code>.</p>
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
