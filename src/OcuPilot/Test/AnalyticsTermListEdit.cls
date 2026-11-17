/// <p>Pins Story 24.2's term list editor at the port (AD-4, AD-16, AD-29, AD-54, AD-65) against <code>USER</code>, with analytics on through
/// <class>OcuPilot.Test.AnalyticsProbe</class> and lists named with this class's own marker. Each leg is a row of the story's matrix: a list
/// is created and every property reads back, the hide-value flag from its node; a name taken without regard to case writes nothing; a change
/// moves only the header; a field in use is refused; an entry is added, changed and removed and <code>%Lookup</code> answers each; a key held,
/// a list gone, a shape breach and a database that is not journaled are each refused before any vendor call, which
/// <class>OcuPilot.Test.AnalyticsTermListSeam</class> counts; a failed second value write rolls the entry back; a delete and a remove take what
/// they name; and the longest name, key and field the rules admit can be stored.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because it turns analytics on in <code>USER</code> and writes term lists there. It removes everything after the last
/// test. One class per run.</p>
Class OcuPilot.Test.AnalyticsTermListEdit Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter NAMESPACE = "USER";

/// <p>The prefix of every list this class makes: the vendor stores names in upper case, so the sweep matches the upper-cased form.</p>
Parameter MARKER = "OcuProbeTL24";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListEdit turns analytics on in USER and writes term lists there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe; a failing status when it or a marked list survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Sweep()
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListEdit left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && (..Marked() '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListEdit left term lists in USER: " _ ..Marked())
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ..Sweep()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Sweep()
    Quit $$$OK
}

/// <p>Kill every marked list in <code>USER</code>.</p>
ClassMethod Sweep()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            Set tNext = $Order(^DeepSee.TermList(tId))
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Do ##class(%DeepSee.TermList).%DeleteTermList(tId)
            Set tId = tNext
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The marked lists that remain in <code>USER</code>, comma-separated.</p>
ClassMethod Marked() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tNames = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tId
            Set tId = $Order(^DeepSee.TermList(tId))
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>The call <var>pType</var> on <var>pEndpoint</var> for the id <var>pId</var> with the body <var>pBody</var> through the seam port, as
/// <code>&lt;http&gt; &lt;code&gt;</code>; the answer is in <var>pResult</var>, the fault in <var>pFault</var>.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject, Output pResult, Output pFault, pAction As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(..#SEAM, "Invoke", pEndpoint, pType, .tQuery, pBody, .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

ClassMethod Entry(pList As %String, pKey As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pList, pKey))
}

/// <p>A term list's every node in <code>USER</code>, as one string, so that "nothing was written" is a comparison.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRef = "^DeepSee.TermList"
        Set tRef = $Query(@tRef@(""))
        While tRef '= "" {
            If $Extract($QSubscript(tRef, 1), 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Set tText = tText _ tRef _ "=" _ $Get(@tRef) _ "|"
            Set tRef = $Query(@tRef)
        }
    } Catch {
        Set tText = tText _ "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>The vendor's value of the entry <var>pKey</var> of <var>pList</var> under the field <var>pField</var> (the entry's own when
/// <code>""</code>), read in <code>USER</code>.</p>
ClassMethod Lookup(pList As %String, pKey As %String, pField As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tValue = ##class(%DeepSee.TermList).%Lookup(pList, pKey, pField, "<default>")
    Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p>Create the list <var>pName</var> with the field <code>Region</code> and two entries, as the arrangement of a leg.</p>
ClassMethod Arrange(pName As %String)
{
    Do ..Call("TermLists", "ADD", pName, {"Caption": "Caption", "Description": "Desc", "Pattern": "*", "SubjectArea": "Sales", "Fields": ["Region"], "HideValue": true}, .tRes, .tFault)
    Do ..Call("TermListEntries", "ENTRYADD", ..Entry(pName, "K1"), {"Value": "V1", "FieldValues": [{"Field": "Region", "Value": "West"}]}, .tRes, .tFault)
    Do ..Call("TermListEntries", "ENTRYADD", ..Entry(pName, "K2"), {"Value": "V2"}, .tRes, .tFault)
}

/// <p>AC1: a create makes the list, and every property reads back through the vendor's <code>%ToObj</code> and the hide-value flag from its node;
/// the read for the add found the name free (404) and then taken (409).</p>
/// <p>Mutation (Rule 19): skip the <code>hideValue</code> write in <method>OcuPilot.Port.AnalyticsPort.VendorTermListCreate</method> by
/// passing 0 -- the hide leg goes red.</p>
Method TestACreateMakesTheListAndEveryPropertyReadsBack()
{
    Set tName = ..#MARKER _ "Create"
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRes, .tFault, "ADD"), "404 PORT.NOTFOUND", "the add's read finds the name free")
    Set tStatus = ..Call("TermLists", "ADD", tName, {"Caption": "Cap", "Description": "Desc", "Pattern": "*x", "SubjectArea": "Sales", "Fields": ["Region", "Note"], "HideValue": true}, .tRes, .tFault)
    Do $$$AssertEquals(tStatus, "200 ", "the create answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRead, .tFault), "200 ", "the list reads")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Name _ "|" _ tRead.Caption _ "|" _ tRead.Description _ "|" _ tRead.Pattern _ "|" _ tRead.SubjectArea _ "|" _ tRead.Fields.%ToJSON() _ "|" _ tRead.HideValue, tName _ "|Cap|Desc|*x|Sales|[""Region"",""Note""]|1", "every property reads back, the hide-value flag included")
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tTaken, .tFault, "ADD"), "409 ANALYTICS.TERMLIST.TAKEN", "and the add's read now finds it taken")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tExists = ##class(%DeepSee.TermList).%TermListExists(tName)
    Set tNode = $Get(^DeepSee.TermList($ZConvert(tName, "U"), "hideValue"))
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tExists _ "|" _ tNode, "10|1", "the vendor holds the list and the hide-value node reads 1")
}

/// <p>AC3: a create whose name matches an existing list without regard to case is refused <code>TAKEN</code> before the vendor's create, which
/// would kill that list: its entries are as they were and no vendor call was made.</p>
/// <p>Mutation (Rule 19): skip the held check for an add in <method>OcuPilot.Port.AnalyticsPort.TermListRefusal</method> -- the list is
/// killed and this goes red.</p>
Method TestANameTakenWithoutRegardToCaseWritesNothing()
{
    Set tName = ..#MARKER _ "Taken"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Call("TermLists", "ADD", $ZConvert(tName, "L"), {"Caption": "Other"}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.TAKEN", "a create whose name differs only in case is refused")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and the list and its entries are as they were")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "with no vendor write attempted")
}

/// <p>AC1: a change moves the header only: the caption changes and a field is added, every entry is as it was, and the answer is the list read
/// again.</p>
/// <p>Mutation (Rule 19): send the header through <code>%CreateTermList</code>, which kills the list, in <method>OcuPilot.Port.AnalyticsPort.VendorTermListHeader</method> --
/// the entries leg goes red.</p>
Method TestAChangeMovesOnlyTheHeader()
{
    Set tName = ..#MARKER _ "Change"
    Do ..Arrange(tName)
    Set tStatus = ..Call("TermLists", "UPDATE", tName, {"Caption": "Changed", "Fields": ["Region", "Note"], "HideValue": false}, .tRes, .tFault)
    Do $$$AssertEquals(tStatus, "200 ", "the change answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Caption _ "|" _ tRes.Fields.%ToJSON() _ "|" _ tRes.HideValue, "Changed|[""Region"",""Note""]|0", "the answer is the changed header")
    Do $$$AssertEquals(..Lookup(tName, "K1") _ "|" _ ..Lookup(tName, "K1", "Region") _ "|" _ ..Lookup(tName, "K2"), "V1|West|V2", "and every entry is unchanged")
}

/// <p>AC3: a field leaves the list only when no entry holds a value for it: <code>Region</code>, held by one entry, is refused 422
/// <code>FIELDINUSE</code> and nothing is written; once that value is cleared the field leaves.</p>
/// <p>Mutation (Rule 19): drop the removed-field test in <method>OcuPilot.Port.AnalyticsPort.TermListStateViolations</method> -- the first leg goes red.</p>
Method TestAFieldInUseIsRefusedAndNothingIsWritten()
{
    Set tName = ..#MARKER _ "InUse"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Call("TermLists", "UPDATE", tName, {"Fields": []}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.FIELDINUSE", "removing Region while an entry holds a value is refused")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "with nothing written and no vendor write attempted")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYSET", ..Entry(tName, "K1"), {"FieldValues": [{"Field": "Region", "Value": ""}]}, .tRes, .tFault), "200 ", "the value is cleared")
    Do $$$AssertEquals(..Call("TermLists", "UPDATE", tName, {"Fields": []}, .tRes, .tFault), "200 ", "and the field then leaves")
}

/// <p>AC2: an entry add stores its value and its field value, which <code>%Lookup</code> answers, and a change sets the value and clears the
/// field, which reads empty; a remove makes the key answer the default again.</p>
/// <p>Mutation (Rule 19): drop the field argument of <code>%SetValue</code> in <method>OcuPilot.Port.AnalyticsPort.VendorTermListSetValue</method> -- the field legs go red.</p>
Method TestAnEntryIsAddedChangedAndRemoved()
{
    Set tName = ..#MARKER _ "Entry"
    Do ..Arrange(tName)
    Set tId = ..Entry(tName, "K3")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", tId, {"Value": "V3", "FieldValues": [{"Field": "Region", "Value": "East"}]}, .tRes, .tFault), "200 ", "the add answers 200")
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Fields, "Region: East", "and the row it answers joins its fields")
    Do $$$AssertEquals(..Lookup(tName, "K3") _ "|" _ ..Lookup(tName, "K3", "Region"), "V3|East", "%Lookup answers the value and the field value")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYSET", tId, {"Value": "V4", "FieldValues": [{"Field": "Region", "Value": ""}]}, .tRes, .tFault), "200 ", "the change answers 200")
    Do $$$AssertEquals(..Lookup(tName, "K3") _ "|" _ ..Lookup(tName, "K3", "Region"), "V4|", "the value changed and the field reads empty")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYREMOVE", tId, "", .tRes, .tFault), "200 ", "the remove answers 200")
    Do $$$AssertEquals(..Lookup(tName, "K3"), "<default>", "the key answers the vendor's default")
    Do $$$AssertEquals(..Lookup(tName, "K1") _ "|" _ ..Lookup(tName, "K2"), "V1|V2", "and the other entries are untouched")
}

/// <p>AC3: an entry add of a key the list holds is <code>ENTRYTAKEN</code>, and an add to a list that is not there is 404
/// <code>ANALYTICS.TERMLIST.ABSENT</code>, each before any vendor write.</p>
Method TestAKeyHeldAndAListGoneAreRefused()
{
    Set tName = ..#MARKER _ "Held"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, "K1"), {"Value": "again"}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.ENTRYTAKEN", "a key the list holds is refused")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(..#MARKER _ "Gone", "K1"), {"Value": "x"}, .tRes, .tFault), "404 ANALYTICS.TERMLIST.ABSENT", "an add to a list that is not there is refused")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYSET", ..Entry(tName, "nokey"), {"Value": "x"}, .tRes, .tFault), "404 PORT.NOTFOUND", "a change of a key the list does not hold is 404")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "and nothing was written")
}

/// <p>AC3: each shape breach is refused 422 naming its rule before any vendor call: a key with <code>^</code>, a field named <code>value</code>, a
/// value of 32,001 characters, a field value naming a field the list does not hold, a name with a control character.</p>
/// <p>Mutation (Rule 19): admit <code>^</code> in a key in <method>OcuPilot.Port.AnalyticsPort.NameShaped</method> -- the key leg goes red.</p>
Method TestAShapeBreachNeverReachesTheVendor()
{
    Set tName = ..#MARKER _ "Shape"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, "a^b"), {"Value": "x"}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.KEY", "a key holding ^")
    Do $$$AssertEquals(..Call("TermLists", "UPDATE", tName, {"Fields": ["value"]}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.FIELD", "a field named value")
    Do $$$AssertEquals(..Call("TermLists", "UPDATE", tName, {"Fields": ["Region", "REGION"]}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.FIELD", "a field named twice")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, "K9"), {"Value": ($Translate($Justify("", 32001), " ", "v"))}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.VALUE", "a value of 32,001 characters")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, "K9"), {"FieldValues": [{"Field": "Nope", "Value": "x"}]}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.NOFIELD", "a field value naming a field the list does not hold")
    Do $$$AssertEquals(..Call("TermLists", "ADD", ..#MARKER _ "Bad" _ $Char(7), {}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.NAME", "a name with a control character")
    Do $$$AssertEquals(..Call("TermLists", "ADD", ..#MARKER _ "Bad", {"Caption": ($Translate($Justify("", 256), " ", "c"))}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.VALUE", "a caption of 256 characters")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "nothing was written and no vendor write was attempted")
}

/// <p>AC4: with the second value write of an entry change failed, the entry reads as it did before, the write answers its failure and no
/// audit row is made. A property change whose hide-value write fails after the header was written leaves the header as it was.</p>
/// <p>Mutation (Rule 19): remove the <code>TROLLBACK</code> in <method>OcuPilot.Port.AnalyticsPort.PerformTermList</method> -- the entry keeps the new value and this goes red;
/// remove the property change's <code>TSTART</code> there -- the header keeps its new caption and the last leg goes red.</p>
Method TestAFailedSecondValueWriteRollsTheEntryBack()
{
    Set tName = ..#MARKER _ "Rollback"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "failsecond")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Call("TermListEntries", "ENTRYSET", ..Entry(tName, "K1"), {"Value": "changed", "FieldValues": [{"Field": "Region", "Value": "East"}]}, .tRes, .tFault)
    Do $$$AssertEquals(tStatus, "500 INTERNAL", "the write answers its failure")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and the entry reads as it did before")
    Do $$$AssertEquals($TLevel, 0, "with no transaction left open")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "term-list-entry", tName _ "\u0001K1", "analytics.termlistentries.set", .tData), 0, "and no audit row is made")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "failhide")
    Set tStatus = ..Call("TermLists", "UPDATE", tName, {"Caption": "Changed", "HideValue": false}, .tRes, .tFault)
    Do $$$AssertEquals(tStatus, "500 INTERNAL", "a property change whose hide-value write fails answers its failure")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $TLevel, tBefore _ "|0", "and the header reads as it did before, with no transaction left open")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "throwsecond")
    Set tStatus = ..Call("TermListEntries", "ENTRYSET", ..Entry(tName, "K1"), {"Value": "changed", "FieldValues": [{"Field": "Region", "Value": "East"}]}, .tRes, .tFault)
    Do $$$AssertEquals(tStatus, "500 INTERNAL", "an entry change whose second value write raises answers its failure")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $TLevel, tBefore _ "|0", "and the entry reads as it did before, with no transaction left open")
}

/// <p>AC1, AC2 (AD-59): each write's script form, run line by line in <code>USER</code>, makes the same change the write makes: the create, an entry add with a
/// field value and one with none of its own, the entry change, the property change (every header member, the list named in its stored spelling), the entry removal
/// and the delete, each read back through the vendor. Each script refuses what the port refuses: a create over a held name, an entry add over a held key, and a
/// removal from a list that is gone, each leaving the list as it was.</p>
/// <p>Mutation (Rule 19): drop the field argument of the value write in <method>OcuPilot.Port.AnalyticsPort.TermListSnippet</method> -- the entry legs go red; drop the
/// free-name gate of the create there -- the held-name leg goes red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tName = ..#MARKER _ "Script"
    Set tUpper = $ZConvert(tName, "U")
    Set tEntry = ..Entry(tName, "K1")
    Do ..Run("TermLists", "ADD", tName, {"Caption": "Cap", "Description": "Desc", "Pattern": "*", "SubjectArea": "Sales", "Fields": ["Region"], "HideValue": true})
    Do $$$AssertEquals(..Marked(), tUpper, "the create script makes the list")
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRes, .tFault), "200 ", "the list reads")
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Caption _ "|" _ tRes.Description _ "|" _ tRes.Pattern _ "|" _ tRes.SubjectArea _ "|" _ tRes.Fields.%ToJSON() _ "|" _ tRes.HideValue, "Cap|Desc|*|Sales|[""Region""]|1", "with every property the create script set")
    Do ..Run("TermListEntries", "ENTRYADD", tEntry, {"Value": "V1", "FieldValues": [{"Field": "Region", "Value": "West"}]})
    Do $$$AssertEquals(..Lookup(tName, "K1") _ "|" _ ..Lookup(tName, "K1", "Region"), "V1|West", "the entry add script writes the value and the field value")
    Do ..Run("TermLists", "ADD", $ZConvert(tName, "L"), {"Caption": "Other"}, 0)
    Do ..Run("TermListEntries", "ENTRYADD", tEntry, {"Value": "Over"}, 0)
    Do $$$AssertEquals(..Lookup(tName, "K1") _ "|" _ ..Lookup(tName, "K1", "Region"), "V1|West", "a create over the held name and an add over the held key change nothing")
    Do ..Run("TermListEntries", "ENTRYADD", ..Entry(tName, "K2"), {"FieldValues": [{"Field": "Region", "Value": "North"}]})
    Do $$$AssertEquals(..Lookup(tName, "K2") _ "|" _ ..Lookup(tName, "K2", "Region"), "|North", "an add with no value of its own writes an empty value, as the write does")
    Do ..Run("TermListEntries", "ENTRYSET", tEntry, {"Value": "V2", "FieldValues": [{"Field": "Region", "Value": "East"}]})
    Do $$$AssertEquals(..Lookup(tName, "K1") _ "|" _ ..Lookup(tName, "K1", "Region"), "V2|East", "the entry change script changes both")
    Do ..Run("TermLists", "UPDATE", $ZConvert(tName, "L"), {"Name": (tName), "Caption": "Changed", "Description": "D2", "Pattern": "*", "SubjectArea": "S2", "Fields": ["Region"], "HideValue": false})
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRes, .tFault), "200 ", "the list reads")
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Caption _ "|" _ tRes.Description _ "|" _ tRes.Pattern _ "|" _ tRes.SubjectArea _ "|" _ tRes.HideValue _ "|" _ ..Lookup(tName, "K1"), tName _ "|Changed|D2|*|S2|0|V2", "the property change script changes the header in the stored spelling and keeps the entry")
    Do ..Run("TermListEntries", "ENTRYREMOVE", tEntry, "")
    Do $$$AssertEquals(..Lookup(tName, "K1"), "<default>", "the removal script takes the entry")
    Do ..Run("TermLists", "DELETE", tName, "")
    Do $$$AssertEquals(..Marked(), "", "the delete script takes the list")
    Do ..Run("TermListEntries", "ENTRYREMOVE", ..Entry(tName, "K2"), "", 0)
    Do $$$AssertEquals(..Marked(), "", "and a removal from the list that is gone writes nothing")
}

/// <p>Run the script form of the write <var>pType</var> on <var>pEndpoint</var> for <var>pId</var> with <var>pBody</var>, one line at a time, in the namespace it names,
/// and assert its final status is OK, or, when <var>pExpectOK</var> is 0, that it is not.</p>
Method Run(pEndpoint As %String, pType As %String, pId As %String, pBody, pExpectOK As %Boolean = 1)
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSteps = ##class(OcuPilot.Port.AnalyticsPort).Snippet(pEndpoint, pType, .tQuery, pBody)
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 1), pType _ " renders one script step")
    If '$IsObject(tSteps) || (tSteps.%Size() '= 1) Quit
    Set tOrigNS = $NAMESPACE
    Set tLevel = $TLevel
    XECUTE "Kill tSC"
    Try {
        For tI = 1:1:$Length(tSteps.%Get(0).text, $Char(10)) {
            Set tLine = $Piece(tSteps.%Get(0).text, $Char(10), tI)
            If tLine '= "" XECUTE tLine
        }
    } Catch ex {
        While $TLevel > tLevel {
            TROLLBACK 1
        }
        Do $$$AssertTrue(0, pType _ " script ran: " _ ex.DisplayString())
    }
    Set $NAMESPACE = tOrigNS
    ; The script's variables are public: a procedure-block method reads them by indirection.
    Set tScriptStatus = $Get(@"tSC")
    Do $$$AssertEquals(''$System.Status.IsOK(tScriptStatus), ''pExpectOK, pType _ " script ends with its status " _ $Select(pExpectOK: "OK", 1: "refused") _ ": " _ $System.Status.GetErrorText(tScriptStatus))
    Do $$$AssertEquals($TLevel, tLevel, pType _ " script leaves no transaction open")
}

/// <p>AC1, AC2: a delete takes the list and its entries, a remove the one entry; the audit row of each names the tool, the namespace and the
/// target, and carries no value.</p>
Method TestADeleteAndARemoveTakeWhatTheyNameAndAreAudited()
{
    Set tName = ..#MARKER _ "Delete"
    Do ..Arrange(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYREMOVE", ..Entry(tName, "K1"), "", .tRes, .tFault), "200 ", "the remove answers 200")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "term-list-entry", tName _ "\u0001K1", "analytics.termlistentries.remove", .tData), 1, "one audit row names the remove")
    Do $$$AssertTrue((tData [ """namespace"":""USER"""), "naming the namespace: " _ tData)
    Do $$$AssertTrue((tData '[ "V1") && (tData '[ "West"), "and no value")
    Do $$$AssertEquals(..Call("TermLists", "DELETE", tName, "", .tRes, .tFault), "200 ", "the delete answers 200")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "term-list", tName, "analytics.termlists.delete", .tData2), 1, "one audit row names the delete")
    Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tGone, .tFault), "404 PORT.NOTFOUND", "the list is gone")
    Do $$$AssertEquals(..Marked(), "", "and no marked list remains")
}

/// <p>The longest name, key and field the rules admit are stored: a 255-character name with a 5-character field takes a key of at most 226
/// characters (measured), and the rule refuses the next one before the vendor would raise <code>&lt;SUBSCRIPT&gt;</code>.</p>
Method TestTheLongestNameKeyAndFieldAreStored()
{
    Set tName = ..#MARKER _ $Translate($Justify("", 255 - $Length(..#MARKER)), " ", "N")
    Do $$$AssertEquals($Length(tName), 255, "the name is 255 characters")
    Do $$$AssertEquals(..Call("TermLists", "ADD", tName, {"Fields": ["Notes"]}, .tRes, .tFault), "200 ", "the longest name is created")
    Set tKey = $Translate($Justify("", 226), " ", "k")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, tKey), {"Value": "v", "FieldValues": [{"Field": "Notes", "Value": "n"}]}, .tRes, .tFault), "200 ", "a 226-character key is stored")
    Do $$$AssertEquals(..Lookup(tName, tKey), "v", "and read back")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, tKey _ "k"), {"Value": "v"}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.KEY", "a longer key is refused by the rule")
    Do $$$AssertEquals(..Call("TermLists", "ADD", ..#MARKER _ "FieldTooLong", {"Fields": [($Translate($Justify("", 256), " ", "f"))]}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.FIELD", "a field of 256 characters is refused")
}

/// <p>The ruling of the spec gate: each of the six writes is refused 409 <code>NOTJOURNALED</code> with the ruled sentence before any vendor call
/// or transaction when the term list database is not journaled, and 400 <code>PORT.VALIDATION</code> when its journal state cannot be read.
/// <method>OcuPilot.Port.AnalyticsPort.JournaledFrom</method> reads the flag the instance sets, measured on a database with journaling off.</p>
/// <p>Mutation (Rule 19): drop the journal test in <method>OcuPilot.Port.AnalyticsPort.AdmitJournaled</method> -- every refusal leg goes red; make
/// <method>OcuPilot.Port.AnalyticsPort.DestinationJournaled</method> always answer journaled -- the last leg goes red.</p>
Method TestAWriteIsRefusedWhenTheDatabaseIsNotJournaled()
{
    Set tName = ..#MARKER _ "Journal"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "nonjournaled")
    For tCase = $ListBuild("TermLists", "ADD", ..#MARKER _ "New"), $ListBuild("TermLists", "UPDATE", tName), $ListBuild("TermLists", "DELETE", tName), $ListBuild("TermListEntries", "ENTRYADD", ..Entry(tName, "K7")), $ListBuild("TermListEntries", "ENTRYSET", ..Entry(tName, "K1")), $ListBuild("TermListEntries", "ENTRYREMOVE", ..Entry(tName, "K1")) {
        Do $$$AssertEquals(..Call($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), {"Caption": "x", "Value": "x"}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.NOTJOURNALED", $List(tCase, 2) _ " is refused")
        If $IsObject(tFault) Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTNOTJOURNALED, $List(tCase, 2) _ ": with the ruled sentence")
    }
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls") _ "|" _ $TLevel, tBefore _ "|0|0", "and nothing was written, called or left open")
    Do $ClassMethod(..#SEAM, "Arm", "unknownjournal")
    Do $$$AssertEquals(..Call("TermLists", "DELETE", tName, "", .tRes, .tFault), "400 PORT.VALIDATION", "a journal state the instance cannot read is refused")
    Set tJournaled = 0
    Do $$$AssertTrue(##class(OcuPilot.Port.AnalyticsPort).JournaledFrom("12,8192,0,11,0,0,3,16,0,0,50,1,5,12,1,320,128,8194", .tJournaled) && tJournaled, "a record without the no-journal flag reads journaled")
    Do $$$AssertTrue(##class(OcuPilot.Port.AnalyticsPort).JournaledFrom("14,8192,0,1,0,0,3,16,0,0,50,1,5,14,1,320,4224,8194", .tJournaled) && 'tJournaled, "a record with it reads not journaled")
    Do $$$AssertTrue('##class(OcuPilot.Port.AnalyticsPort).JournaledFrom("-1", .tJournaled), "an answer that is not a record reads unknown")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertTrue(##class(OcuPilot.Port.AnalyticsPort).DestinationJournaled(..#NAMESPACE, "^DeepSee.TermList", .tUserJournaled) && tUserJournaled, "and the instance reports USER's term list database journaled")
    Do $$$AssertTrue(##class(OcuPilot.Port.AnalyticsPort).DestinationJournaled(..#NAMESPACE, "^IRIS.Temp", .tTempJournaled) && 'tTempJournaled, "and the instance's temporary database, which journals nothing, reads not journaled through the production method")
}

/// <p>AC3: a key that fits beside the entry's value but not beside a long field the call writes is refused 422 <code>KEY</code> before any vendor call, because
/// the instance's limit counts the key and the field together.</p>
/// <p>Mutation (Rule 19): drop the key-beside-field check in <method>OcuPilot.Port.AnalyticsPort.TermListViolations</method> -- the write reaches the vendor, which
/// raises, and this goes red.</p>
Method TestAKeyTooLongBesideAFieldIsRefusedBeforeTheVendor()
{
    Set tName = ..#MARKER _ "Fit"
    Set tField = $Translate($Justify("", 255), " ", "F")
    Set tKey = $Translate($Justify("", 255), " ", "k")
    Do $$$AssertEquals(..Call("TermLists", "ADD", tName, {"Fields": [(tField)]}, .tRes, .tFault), "200 ", "a list with a 255-character field is made")
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Call("TermListEntries", "ENTRYADD", ..Entry(tName, tKey), {"Value": "v", "FieldValues": [{"Field": (tField), "Value": "x"}]}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.KEY", "a 255-character key beside that field is refused by its rule")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "and nothing was written or called")
}

/// <p>AC3: a field leaves the list only when no entry holds a value for it, read by the field's piece of the stored list even when that list holds an empty piece.</p>
/// <p>Mutation (Rule 19): index the entry's values by the compacted field position in <method>OcuPilot.Port.AnalyticsPort.TermListStateViolations</method> -- this goes red.</p>
Method TestAFieldInUseIsFoundBesideAnEmptyPieceOfTheStoredList()
{
    Kill tData
    Set tData("exists") = 1, tData("fieldList") = "^Region", tData("keys") = 1, tData("key", 1) = "K1", tData("val", 1, 0) = "v", tData("val", 1, 2) = "West"
    Set tSC = ##class(OcuPilot.Port.AnalyticsPort).TermListStateViolations("UPDATE", .tData, {"Fields": []}, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rule runs")
    Do $$$AssertEquals(+$Get(tViolations) _ "|" _ $ListGet($Get(tViolations(1)), 2), "1|ANALYTICS.TERMLIST.FIELDINUSE", "removing the field that holds a value is refused")
}

/// <p>AC3: the read a mint or a screen action makes for a write is gated as the write is: under a read-only or a not journaled term list database it is refused
/// with that write's code, so no proposal is minted that could never be confirmed, while a plain read still answers.</p>
/// <p>Mutation (Rule 19): stop counting a term list read that carries an action as a write in <method>OcuPilot.Port.AnalyticsPort.Invoke</method> -- this goes red.</p>
Method TestAReadComposedForAWriteIsGatedAsTheWrite()
{
    Set tName = ..#MARKER _ "Composed"
    Do ..Arrange(tName)
    For tMode = "readonly", "nonjournaled" {
        Set tCode = $Select(tMode = "readonly": "409 ANALYTICS.TERMLIST.READONLY", 1: "409 ANALYTICS.TERMLIST.NOTJOURNALED")
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", tMode)
        Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRes, .tFault, "UPDATE"), tCode, tMode _ ": the read for a change is refused")
        Do $$$AssertEquals(..Call("TermListEntries", "TERMLISTENTRY", ..Entry(tName, "K1"), "", .tRes, .tFault, "ENTRYSET"), tCode, tMode _ ": the read for an entry change is refused")
        Do $$$AssertEquals(..Call("TermLists", "TERMLIST", tName, "", .tRes, .tFault), "200 ", tMode _ ": a plain read still answers")
    }
}

}
