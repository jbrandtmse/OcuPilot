/// <p><class>OcuPilot.Port.LocalePort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held set a test
/// declares, so <class>OcuPilot.Test.PortGate</class>, <class>OcuPilot.Test.LocaleRead</class> and <class>OcuPilot.Test.LocaleRules</class> drive the
/// port's refusal in a process holding <code>%All</code>. The install and the delete are recorded instead of made (<method>Calls</method>), and
/// <method>VendorRefuses</method> makes them answer an error, so a test sees what the port would send and no locale changes. The vendor's validity
/// check answers what <method>Feed</method> names, its install check what <method>FeedInstallable</method> names (every ask recorded, <method>Checks</method>),
/// the collation of IRISTEMP what <method>Collations</method> names, and a locale <method>HoldLocale</method> names is listed whether or not the instance
/// holds it. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LocaleGateSeam Extends OcuPilot.Port.LocalePort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>The shipped answers again, and no recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotLocaleCalls, ^||OcuPilotLocaleRefuses, ^||OcuPilotLocaleFed, ^||OcuPilotLocaleInstallable, ^||OcuPilotLocaleChecks, ^||OcuPilotLocaleCollation, ^||OcuPilotLocaleFaults, ^||OcuPilotLocaleHeld
    Kill ^||OcuPilotLocaleProps, ^||OcuPilotLocaleTables, ^||OcuPilotLocaleAvailable, ^||OcuPilotLocaleSent, ^||OcuPilotLocaleUncompiled
    Kill ^||OcuPilotLocaleCurrent, ^||OcuPilotLocaleImported, ^||OcuPilotLocaleImportCounts, ^||OcuPilotLocaleExportText, ^||OcuPilotLocaleExportCounts
}

/// <p>Pose <var>pLocale</var> as the current locale, loading the tables in <var>pTables</var> (<code>pTables(type, from, to)</code>) and the sub-tables in
/// <var>pSubTables</var> (<code>pSubTables(name)</code>), in <method>CurrentFootprint</method>, until <method>Reset</method>.</p>
ClassMethod HoldCurrent(pLocale As %String, ByRef pTables, ByRef pSubTables)
{
    Kill ^||OcuPilotLocaleCurrent
    Set ^||OcuPilotLocaleCurrent = pLocale
    Merge ^||OcuPilotLocaleCurrent("tables") = pTables
    Merge ^||OcuPilotLocaleCurrent("subtables") = pSubTables
}

ClassMethod CurrentFootprint(Output pLocale As %String, Output pTables, Output pSubTables) As %Status
{
    If '$Data(^||OcuPilotLocaleCurrent) Quit ##super(.pLocale, .pTables, .pSubTables)
    Set pLocale = ^||OcuPilotLocaleCurrent
    Kill pTables, pSubTables
    Merge pTables = ^||OcuPilotLocaleCurrent("tables")
    Merge pSubTables = ^||OcuPilotLocaleCurrent("subtables")
    Quit $$$OK
}

/// <p>Make the import report the vendor's counts <var>pLocales</var>, <var>pTables</var> and <var>pSubTables</var> instead of the counts of the records it was
/// handed, until <method>Reset</method>.</p>
ClassMethod FeedImportCounts(pLocales As %Integer, pTables As %Integer, pSubTables As %Integer)
{
    Set ^||OcuPilotLocaleImportCounts = $ListBuild(pLocales, pTables, pSubTables)
}

/// <p>The text the last <method>SendImport</method> was handed, the vendor's file in this seam's place.</p>
ClassMethod Imported() As %String
{
    Quit $Get(^||OcuPilotLocaleImported)
}

/// <p>Make an export answer <var>pText</var> as its text, and the vendor's counts <var>pLocales</var>, <var>pTables</var> and <var>pSubTables</var>, until
/// <method>Reset</method>.</p>
ClassMethod FeedExport(pText As %String, pLocales As %Integer = 1, pTables As %Integer = 0, pSubTables As %Integer = 0)
{
    Set ^||OcuPilotLocaleExportText = pText
    Set ^||OcuPilotLocaleExportCounts = $ListBuild(pLocales, pTables, pSubTables)
}

ClassMethod SendImport(pKept As %Stream.TmpCharacter, Output pCounts) As %Status [ Private ]
{
    Kill pCounts
    Do pKept.Rewind()
    Set tText = ""
    While 'pKept.AtEnd {
        Set tText = tText _ pKept.Read(32000)
    }
    Set ^||OcuPilotLocaleImported = tText
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "IMPORT"
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    If $Data(^||OcuPilotLocaleImportCounts) {
        Set pCounts("Locales") = $List(^||OcuPilotLocaleImportCounts, 1)
        Set pCounts("Tables") = $List(^||OcuPilotLocaleImportCounts, 2)
        Set pCounts("SubTables") = $List(^||OcuPilotLocaleImportCounts, 3)
    } Else {
        Set pCounts("Locales") = $Length(tText, "<Locales>") - 1
        Set pCounts("Tables") = $Length(tText, "<Tables>") - 1
        Set pCounts("SubTables") = $Length(tText, "<SubTables>") - 1
    }
    Quit $$$OK
}

ClassMethod SendExport(pName As %String, pResolved As %String, Output pCounts, Output pText As %String, Output pTooLarge As %Boolean) As %Status [ Private ]
{
    Kill pCounts
    Set pText = ""
    Set pTooLarge = 0
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "EXPORT|" _ pName _ "|" _ $Select(pResolved = "": "browser", 1: "file")
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Set tCounts = $Get(^||OcuPilotLocaleExportCounts, $ListBuild(1, 0, 0))
    Set pCounts("Locales") = $List(tCounts, 1)
    Set pCounts("Tables") = $List(tCounts, 2)
    Set pCounts("SubTables") = $List(tCounts, 3)
    If pResolved = "" {
        Set pText = $Get(^||OcuPilotLocaleExportText)
        If $Length(pText) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS {
            Set pText = ""
            Set pTooLarge = 1
        }
    }
    Quit $$$OK
}

/// <p>Pose the definition <var>pProps</var> (a <code>Get</code> array) as the fresh read of <var>pLocale</var> in <method>LocaleProperties</method>, until
/// <method>Reset</method>.</p>
ClassMethod HoldProperties(pLocale As %String, ByRef pProps)
{
    Kill ^||OcuPilotLocaleProps(pLocale)
    Merge ^||OcuPilotLocaleProps(pLocale) = pProps
}

/// <p>Make <method>LocaleTables</method> answer the names in <var>pNames</var> (a <code>%List</code>) for tables of type <var>pType</var>, whatever the
/// locale, until <method>Reset</method>.</p>
ClassMethod HoldTables(pType As %String, pNames As %List)
{
    Set ^||OcuPilotLocaleTables(pType) = pNames
}

/// <p>Make <method>TableAvailable</method> answer <var>pAvailable</var> whatever it is asked, until <method>Reset</method>.</p>
ClassMethod FeedAvailable(pAvailable As %Boolean)
{
    Set ^||OcuPilotLocaleAvailable = ''pAvailable
}

/// <p>The complete set the last <method>SendModify</method> or <method>SendCreate</method> was given, in <var>pSet</var>.</p>
ClassMethod Sent(Output pSet)
{
    Kill pSet
    Merge pSet = ^||OcuPilotLocaleSent
}

ClassMethod LocaleProperties(pLocale As %String, ByRef pProps) As %Status
{
    If '$Data(^||OcuPilotLocaleProps(pLocale)) Quit ##super(pLocale, .pProps)
    Kill pProps
    Merge pProps = ^||OcuPilotLocaleProps(pLocale)
    Quit $$$OK
}

ClassMethod LocaleTables(pLocale As %String, pType As %String, pBuiltIn As %Boolean = 0) As %List
{
    If $Data(^||OcuPilotLocaleTables(pType)) Quit ^||OcuPilotLocaleTables(pType)
    Quit ##super(pLocale, pType, pBuiltIn)
}

ClassMethod TableAvailable(pType As %String, pCharacterSet As %String, pTable As %String) As %Boolean
{
    If $Data(^||OcuPilotLocaleAvailable) Quit ^||OcuPilotLocaleAvailable
    Quit ##super(pType, pCharacterSet, pTable)
}

/// <p>Make <method>TableLoadable</method> answer 0 for a table named <var>pTable</var> on either side, until <method>Reset</method>: the instance lists it
/// for the locale and has not compiled it. A type whose names <method>HoldTables</method> poses answers 1 for every other table.</p>
ClassMethod HoldUncompiled(pTable As %String)
{
    Set ^||OcuPilotLocaleUncompiled(pTable) = 1
}

ClassMethod TableLoadable(pType As %String, pFrom As %String, pTo As %String) As %Boolean
{
    If $Data(^||OcuPilotLocaleUncompiled(pFrom)) || $Data(^||OcuPilotLocaleUncompiled(pTo)) Quit 0
    If $Data(^||OcuPilotLocaleTables(pType)) Quit 1
    Quit ##super(pType, pFrom, pTo)
}

ClassMethod SendCreate(pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "CREATE|" _ pName
    Kill ^||OcuPilotLocaleSent
    Merge ^||OcuPilotLocaleSent = pProps
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

ClassMethod SendModify(pLocale As %String, ByRef pSet) As %Status [ Private ]
{
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "MODIFY|" _ pLocale
    Kill ^||OcuPilotLocaleSent
    Merge ^||OcuPilotLocaleSent = pSet
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

ClassMethod SendLoad(pLocale As %String, pType As %String, pTable As %String) As %Status [ Private ]
{
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "LOAD|" _ pLocale _ "|" _ pType _ "|" _ pTable
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

/// <p>Answer an error from <method>SendInstall</method> and <method>SendDelete</method> until <method>Reset</method>.</p>
ClassMethod VendorRefuses()
{
    Set ^||OcuPilotLocaleRefuses = 1
}

/// <p>The calls recorded, as <code>operation|name</code>, comma-joined.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotLocaleCalls(tI))
        If tI = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotLocaleCalls(tI)
    }
    Quit tOut
}

/// <p>Make <method>ReadValidation</method> answer <var>pValid</var> and the line lists <var>pErrors</var> and <var>pWarnings</var>
/// (<code>%List</code>s) whatever the locale, until <method>Reset</method>.</p>
ClassMethod Feed(pValid As %Boolean, pErrors As %List = "", pWarnings As %List = "")
{
    Set ^||OcuPilotLocaleFed = $ListBuild(pValid, pErrors, pWarnings)
}

/// <p>Make <method>ReadInstallable</method> answer <var>pInstallable</var> whatever the locale, until <method>Reset</method>.</p>
ClassMethod FeedInstallable(pInstallable As %Boolean)
{
    Set ^||OcuPilotLocaleInstallable = ''pInstallable
}

/// <p>The locales <method>ReadInstallable</method> was asked about since <method>Reset</method>, comma-joined, answered or not.</p>
ClassMethod Checks() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotLocaleChecks(tI))
        If tI = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotLocaleChecks(tI)
    }
    Quit tOut
}

/// <p>Make the first <method>TempCollation</method> after this answer <var>pBefore</var> and every later one <var>pAfter</var>, until
/// <method>Reset</method>.</p>
ClassMethod Collations(pBefore As %String, pAfter As %String)
{
    Set ^||OcuPilotLocaleCollation = $ListBuild(pBefore, pAfter, 0)
}

/// <p>List the locale <var>pName</var> with <var>pDescription</var>, current when <var>pCurrent</var> and custom when <var>pCustom</var>, in
/// <method>LocaleRows</method> until <method>Reset</method>, in place of any instance row of that name; every other row is the instance's, with
/// <code>Current</code> cleared when the held locale is current.</p>
ClassMethod HoldLocale(pName As %String, pDescription As %String, pCurrent As %Boolean, pCustom As %Boolean)
{
    Set ^||OcuPilotLocaleHeld(pName) = $ListBuild(pDescription, ''pCurrent, ''pCustom)
}

/// <p>The codes <method>LogFault</method> was given since <method>Reset</method>, comma-joined; the raw status is still logged as shipped.</p>
ClassMethod Faults() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotLocaleFaults(tI))
        If tI = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotLocaleFaults(tI)
    }
    Quit tOut
}

ClassMethod LocaleRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = ##super(.pRows)
    If $$$ISERR(tSC) || '$Data(^||OcuPilotLocaleHeld) Quit tSC
    Set tHeldCurrent = 0
    Set tName = ""
    For {
        Set tName = $Order(^||OcuPilotLocaleHeld(tName))
        If tName = "" Quit
        If $List(^||OcuPilotLocaleHeld(tName), 2) Set tHeldCurrent = 1
    }
    Set tKept = []
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Data(^||OcuPilotLocaleHeld(tRow.%Get("Name"))) Continue
        If tHeldCurrent Do tRow.%Set("Current", 0, "boolean")
        Do tKept.%Push(tRow)
    }
    Set pRows = tKept
    Set tName = ""
    For {
        Set tName = $Order(^||OcuPilotLocaleHeld(tName))
        If tName = "" Quit
        Set tRow = {}
        Do tRow.%Set("Name", tName, "string")
        Do tRow.%Set("Description", $List(^||OcuPilotLocaleHeld(tName), 1), "string")
        Do tRow.%Set("Current", $List(^||OcuPilotLocaleHeld(tName), 2), "boolean")
        Do tRow.%Set("Custom", $List(^||OcuPilotLocaleHeld(tName), 3), "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotLocaleFaults($Increment(^||OcuPilotLocaleFaults)) = pCode _ "|" _ $Select($$$ISERR(pStatus): "error", 1: "ok")
    Do ##super(pMessage, pStatus, pCode)
}

ClassMethod ReadValidation(pName As %String, Output pValid As %Boolean, Output pErrors As %List, Output pWarnings As %List) As %Status
{
    If $Data(^||OcuPilotLocaleFed) {
        Set pValid = $List(^||OcuPilotLocaleFed, 1)
        Set pErrors = $List(^||OcuPilotLocaleFed, 2)
        Set pWarnings = $List(^||OcuPilotLocaleFed, 3)
        Quit $$$OK
    }
    Quit ##super(pName, .pValid, .pErrors, .pWarnings)
}

ClassMethod ReadInstallable(pName As %String, Output pInstallable As %Boolean) As %Status
{
    Set ^||OcuPilotLocaleChecks($Increment(^||OcuPilotLocaleChecks)) = pName
    If $Data(^||OcuPilotLocaleInstallable) {
        Set pInstallable = ^||OcuPilotLocaleInstallable
        Quit $$$OK
    }
    Quit ##super(pName, .pInstallable)
}

ClassMethod TempCollation() As %String
{
    If '$Data(^||OcuPilotLocaleCollation) Quit ##super()
    Set tAsked = $List(^||OcuPilotLocaleCollation, 3)
    Set ^||OcuPilotLocaleCollation = $List(^||OcuPilotLocaleCollation, 1, 2) _ $ListBuild(tAsked + 1)
    Quit $List(^||OcuPilotLocaleCollation, $Select(tAsked = 0: 1, 1: 2))
}

ClassMethod SendInstall(pName As %String) As %Status [ Private ]
{
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "INSTALL|" _ pName
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

ClassMethod SendDelete(pName As %String) As %Status [ Private ]
{
    Set ^||OcuPilotLocaleCalls($Increment(^||OcuPilotLocaleCalls)) = "DELETE|" _ pName
    If $Get(^||OcuPilotLocaleRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

}
