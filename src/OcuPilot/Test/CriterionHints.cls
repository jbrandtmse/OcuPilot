/// <p>Pins Story 19.18's DW-1001 (AD-5, AD-24, AD-36): what a provider request tells the model about
/// each derived read tool's <code>text</code> criteria. Every one either declares a hint or is one of
/// the eight criteria that really are comma lists; a hinted one is described by its hint and the
/// "At most N characters." sentence, with no comma-list wording; and a hinted criterion of a
/// parent-scoped read names the parent's read tool as the source of its value.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>. It reads
/// descriptors and the emitted tool list, and writes nothing.</p>
Class OcuPilot.Test.CriterionHints Extends %UnitTest.TestCase
{

/// <p>The criteria that are comma lists, <code>&lt;tool&gt;:&lt;param&gt;</code> pipe-separated, and
/// keep the generic description.</p>
Parameter COMMALISTS = "logs.audit.read:eventSources|logs.audit.read:eventTypes|logs.audit.read:events|logs.audit.read:usernames|logs.audit.read:pids|logs.audit.read:namespaces|explorer.classes.read:pattern|explorer.routines.read:pattern";

Parameter GENERIC = "A server-search criterion, as a comma-separated list of names.";

/// <p>Every derived read tool's text criteria into <var>pRows</var>:
/// <code>pRows(n)</code> = <code>$ListBuild(tool, wireName, param, hint, maxLength, descriptorClass)</code>,
/// and the emitted description of each into <code>pRows(n, "description")</code>.</p>
ClassMethod Criteria(Output pRows) As %Status
{
    Kill pRows
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tProvider)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tProvider {
        Set tSchemas(tProvider(tI, "name")) = tProvider(tI, "inputSchema")
    }
    Set tReadClass = ##class(OcuPilot.Screen.Tool.Registry).ReadToolClass()
    Set tN = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If (tTool.%Get("class") '= tReadClass) || (tTool.%Get("descriptor") = "") Continue
        Set tClass = tTool.%Get("descriptor")
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tDeclaration.%Get("read")) || '$IsObject(tDeclaration.read.%Get("criteria")) Continue
        Set tFields = tDeclaration.read.criteria.%Get("fields")
        If '$IsObject(tFields) Continue
        Set tWire = ##class(OcuPilot.Screen.Tool.Registry).WireName(tTool.%Get("name"))
        Set tProperties = ""
        If $Data(tSchemas(tWire)) Set tProperties = ##class(%DynamicObject).%FromJSON(tSchemas(tWire)).properties
        Set tFieldIterator = tFields.%GetIterator()
        While tFieldIterator.%GetNext(.tFieldIndex, .tField) {
            If tField.kind '= "text" Continue
            Set tN = tN + 1
            Set pRows(tN) = $ListBuild(tTool.%Get("name"), tWire, tField.param, tField.%Get("hint"), tField.%Get("maxLength"), tClass)
            Set pRows(tN, "description") = $Select($IsObject(tProperties) && $IsObject(tProperties.%Get(tField.param)): tProperties.%Get(tField.param).description, 1: "")
        }
        If $$$ISERR(tSC) Quit
    }
    Set pRows = tN
    Quit tSC
}

/// <p>DW-1001: every text criterion of a derived read tool declares a hint, except exactly the eight
/// comma lists, which declare none. Two-sided: a criterion added without a hint is named, and so is a
/// comma list that gained one.</p>
/// <p>Mutation (Rule 19): delete a hint from a descriptor -- this names the tool and criterion.</p>
Method TestEveryTextCriterionHasAHintOrIsACommaList()
{
    Set tSC = ..Criteria(.tRows)
    Do $$$AssertStatusOK(tSC, "the criteria are read")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tRows > 40, "the roster is not empty: " _ tRows)
    Set tLists = "|" _ ..#COMMALISTS _ "|"
    Set tSeenLists = 0
    For tI = 1:1:tRows {
        Set tKey = $List(tRows(tI), 1) _ ":" _ $List(tRows(tI), 3)
        Set tIsList = (tLists [ ("|" _ tKey _ "|"))
        If tIsList Set tSeenLists = tSeenLists + 1
        If tIsList {
            Do $$$AssertEquals($List(tRows(tI), 4), "", tKey _ " is a comma list and declares no hint")
        } Else {
            Do $$$AssertTrue($Length($List(tRows(tI), 4)) > 0, tKey _ " declares a hint")
        }
    }
    Do $$$AssertEquals(tSeenLists, $Length(..#COMMALISTS, "|"), "every comma list on the roster is a criterion that exists")
}

/// <p>DW-1001: a hinted criterion's description in the schema a provider request carries is its hint and
/// the length sentence; a comma list's starts with the generic sentence.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Read.AddCriteria</method> ignore a text
/// criterion's hint -- the description leg goes red.</p>
Method TestAHintedCriterionIsDescribedByItsHint()
{
    Set tSC = ..Criteria(.tRows)
    Do $$$AssertStatusOK(tSC, "the criteria are read")
    If $$$ISERR(tSC) Quit
    Set tLists = "|" _ ..#COMMALISTS _ "|"
    For tI = 1:1:tRows {
        Set tKey = $List(tRows(tI), 1) _ ":" _ $List(tRows(tI), 3)
        Set tDescription = tRows(tI, "description")
        If tLists [ ("|" _ tKey _ "|") {
            Do $$$AssertEquals($Extract(tDescription, 1, $Length(..#GENERIC)), ..#GENERIC, tKey _ " keeps the generic comma-list description")
            Continue
        }
        Set tHint = $List(tRows(tI), 4)
        If tHint = "" Continue
        Do $$$AssertEquals(tDescription, tHint _ " At most " _ $List(tRows(tI), 5) _ " characters.", tKey _ " is described by its hint")
        Do $$$AssertTrue(tDescription '[ "comma-separated", tKey _ " is not called a comma list")
    }
}

/// <p>DW-1001: a hinted criterion of a parent-scoped read names the parent's read tool as the source of
/// its value: <code>&lt;parent tool&gt;.read answers its </code>.</p>
/// <p>Mutation (Rule 19): point a hint at another tool's read -- this names the criterion.</p>
Method TestAParentScopedHintNamesTheParentsRead()
{
    Set tSC = ..Criteria(.tRows)
    Do $$$AssertStatusOK(tSC, "the criteria are read")
    If $$$ISERR(tSC) Quit
    Set tChecked = 0
    For tI = 1:1:tRows {
        Set tClass = $List(tRows(tI), 6)
        Set tHint = $List(tRows(tI), 4)
        Set tParentRoute = $ClassMethod(tClass, "ParentScope")
        If (tHint = "") || (tParentRoute = "") Continue
        Set tParent = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tParentRoute)
        If tParent = "" {
            Do $$$AssertTrue(0, tClass _ ": its parent scope '" _ tParentRoute _ "' resolves to a descriptor")
            Continue
        }
        Set tExpected = $ClassMethod(tParent, "ToolIdentifier") _ ".read answers its "
        Set tKey = $List(tRows(tI), 1) _ ":" _ $List(tRows(tI), 3)
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(tHint [ tExpected, tKey _ " names its parent's read: " _ tExpected)
    }
    Do $$$AssertTrue(tChecked > 0, "at least one parent-scoped hint was checked")
}

}
