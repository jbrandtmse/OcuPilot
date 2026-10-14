/// <p>Pins Story 18.48's form-to-read coverage (DW-2335; AD-5, AD-36): every field of the superserver tools
/// (<code>security.superservers.create</code> and <code>.update</code>), of <code>osmgmt.localdatabases.update</code> and of
/// <code>permissions.users.copy</code> that <class>OcuPilot.Screen.Tool.ToolFields</class> classifies is either answered by
/// the declared read of the screen whose read tool the agent has -- <code>security.superservers.read</code>,
/// <code>osmgmt.databasedetails.read</code>, <code>permissions.users.read</code> -- or listed here as form-only with its
/// reason. A form-only field is held to be unanswered, so the list cannot go stale, and it must still be a field of its
/// tool; and a real run of <code>permissions.users.read</code> answers the copy form's twelve fields on its rows, the
/// eleven the detail call adds among them.</p>
/// <p><b>Reads only.</b> It needs <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code> and changes
/// nothing.</p>
Class OcuPilot.Test.FormReadCoverage Extends %UnitTest.TestCase
{

/// <p>The user list's declared descriptor.</p>
Parameter USERS = "OcuPilot.Screen.Descriptor.UserList";

/// <p>The copy form's fields the user list's detail call adds to a row, which the list's own row lacks.</p>
Parameter DETAILFIELDS = "AccountNeverExpires,AutheEnabled,ChangePassword,Comment,EmailAddress,HOTPKeyDisplay,NameSpace,PasswordNeverExpires,PhoneNumber,PhoneProvider,EscalationRoles";

/// <p>Why a superserver field is form-only: the vendor's <code>LIST</code> row carries four fields, and the editor reads the
/// rest through its own form route, keyed by port and bind address, which a read tool's one-key detail call cannot send.</p>
Parameter SUPERSERVERREASON = "the vendor's LIST row lacks it, and only a GET keyed by port and bind address answers it, which a one-key rowGet cannot send";

/// <p>The write tool's fields <var>pTool</var> classifies, by name, <code>[]</code> stripped, in
/// <var>pNames</var> (<code>pNames(name) = ""</code>), read from the generated block.</p>
ClassMethod ToolFieldNames(pTool As %String, Output pNames) As %Status
{
    Kill pNames
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools", , .tOpenSC)
    If '$IsObject(tXData) Quit $$$ERROR($$$GeneralError, "the generated tool field lists cannot be read")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    Set tXData = ""
    If tTools.%GetTypeOf(pTool) '= "object" Quit $$$ERROR($$$GeneralError, pTool _ " has no entry in the generated tool field lists")
    Set tIterator = tTools.%Get(pTool).%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tPath = tField.%Get("path")
        If $Extract(tPath, *-1, *) = "[]" Set tPath = $Extract(tPath, 1, *-2)
        Set pNames(tPath) = ""
    }
    Quit $$$OK
}

/// <p>The names <var>pDescriptor</var>'s declared read answers, in <var>pNames</var>
/// (<code>pNames(name) = ""</code>).</p>
ClassMethod ReadFieldNames(pDescriptor As %String, Output pNames) As %Status
{
    Kill pNames
    Set tSC = $ClassMethod(pDescriptor, "DeclarationJson", .tDeclaration)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tDeclaration.read.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set pNames(tName) = ""
    }
    Quit $$$OK
}

/// <p>Each of the three screens' write tools' fields is answered by the screen's read or listed form-only with its
/// reason, and a field listed form-only is not answered and is a field of its tool.</p>
/// <p>Mutation (Rule 19): remove <code>AutheEnabled</code> from <code>read.fields</code> in
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -- the copy tool's leg names it and goes red; list a field the read
/// answers as form-only -- the form-only leg goes red.</p>
Method TestEveryFormFieldIsAnsweredOrListedFormOnly()
{
    Set tSuperserver = ..SuperserverFormOnly()
    Set tCases = $ListBuild($ListBuild("permissions.users.copy", ..#USERS, $ListBuild("Password"), "write-only: typed on the form and supplied at the confirm, so no read answers a secret (AD-35)"), $ListBuild("osmgmt.localdatabases.update", "OcuPilot.Screen.Descriptor.DatabaseDetails", "", ""), $ListBuild("security.superservers.update", "OcuPilot.Screen.Descriptor.SuperserverList", tSuperserver, ..#SUPERSERVERREASON), $ListBuild("security.superservers.create", "OcuPilot.Screen.Descriptor.SuperserverList", tSuperserver, ..#SUPERSERVERREASON))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tTool = $List(tCase, 1)
        Set tFormOnly = $List(tCase, 3)
        Do $$$AssertStatusOK(..ToolFieldNames(tTool, .tFields), tTool _ ": its classified fields read")
        Do $$$AssertTrue($Order(tFields("")) '= "", tTool _ " classifies at least one field, so the loop below checks something")
        Do $$$AssertStatusOK(..ReadFieldNames($List(tCase, 2), .tRead), tTool _ ": its read tool's declared read reads")
        Set tName = ""
        For {
            Set tName = $Order(tFields(tName))
            If tName = "" Quit
            If $ListFind(tFormOnly, tName) {
                Do $$$AssertTrue('$Data(tRead(tName)), tTool _ "." _ tName _ " is listed form-only (" _ $List(tCase, 4) _ ") and the read does not answer it")
            } Else {
                Do $$$AssertTrue($Data(tRead(tName)) > 0, tTool _ "." _ tName _ " is answered by the read of " _ $List(tCase, 2))
            }
        }
        For tJ = 1:1:$ListLength(tFormOnly) {
            Do $$$AssertTrue($Data(tFields($List(tFormOnly, tJ))) > 0, tTool _ ": the form-only " _ $List(tFormOnly, tJ) _ " is a field of the tool")
        }
    }
}

/// <p>The user list's agent screen context carries the copy form's twelve fields too, so the model reads on the Users
/// screen what the declared read answers.</p>
/// <p>Mutation (Rule 19): drop <code>PhoneNumber</code> from <code>context.fields</code> in
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -- this goes red naming it.</p>
Method TestTheUsersScreenContextCarriesTheCopyFormsFields()
{
    Set tSC = $ClassMethod(..#USERS, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the user list's declaration reads")
    If $$$ISERR(tSC) Quit
    Kill tContext
    Set tIterator = tDeclaration.context.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tContext(tName) = ""
    }
    Set tCount = $Length(..#DETAILFIELDS, ",")
    For tJ = 1:1:tCount + 1 {
        Set tField = $Select(tJ > tCount: "Routine", 1: $Piece(..#DETAILFIELDS, ",", tJ))
        Do $$$AssertTrue($Data(tContext(tField)) > 0, "the screen context carries " _ tField)
    }
}

/// <p>The superserver tools' form-only fields: every classified field except the four the vendor's <code>LIST</code> row
/// carries.</p>
ClassMethod SuperserverFormOnly() As %List
{
    Set tList = ""
    Set tSC = ..ToolFieldNames("security.superservers.update", .tFields)
    Set tSC = ..ToolFieldNames("security.superservers.create", .tCreate)
    Set tName = ""
    For {
        Set tName = $Order(tCreate(tName))
        If tName = "" Quit
        Set tFields(tName) = ""
    }
    Set tName = ""
    For {
        Set tName = $Order(tFields(tName))
        If tName = "" Quit
        If (tName = "Port") || (tName = "BindAddress") || (tName = "Enabled") || (tName = "SystemDefault") Continue
        Set tList = tList _ $ListBuild(tName)
    }
    Quit tList
}

/// <p>The user list's detail call (<code>read.source.rowGet.fields</code>) asks for the eleven copy fields the list row
/// lacks, and a real run of <code>permissions.users.read</code> answers, on each row, the copy form's twelve fields: those
/// eleven and <code>Routine</code>, the list row's own. A row carries every declared field, empty when the detail call did
/// not ask for it, so the detail call's own field list is the part that decides whether a value arrives.</p>
/// <p>Mutation (Rule 19): drop <code>PhoneProvider</code> from the user list's <code>rowGet.fields</code> -- the detail
/// call stops asking for it and this goes red.</p>
Method TestAUsersReadRowCarriesTheCopyFormsFields()
{
    Set tSC = $ClassMethod(..#USERS, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the user list's declaration reads")
    If $$$ISERR(tSC) Quit
    Kill tAsked
    Set tIterator = tDeclaration.read.source.rowGet.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tAsked(tName) = ""
    }
    For tJ = 1:1:$Length(..#DETAILFIELDS, ",") {
        Set tField = $Piece(..#DETAILFIELDS, ",", tJ)
        Do $$$AssertTrue($Data(tAsked(tField)) > 0, "the detail call asks for " _ tField)
    }
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the users read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If $$$ISERR(tSC) || ('$IsObject($Get(tResult))) Quit
    Do $$$AssertTrue(tResult.rows.%Size() > 0, "and answers rows")
    Set tCount = $Length(..#DETAILFIELDS, ",")
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tMissing = ""
        For tJ = 1:1:tCount + 1 {
            Set tField = $Select(tJ > tCount: "Routine", 1: $Piece(..#DETAILFIELDS, ",", tJ))
            If 'tRow.%IsDefined(tField) Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ",") _ tField
        }
        Do $$$AssertEquals(tMissing, "", "row " _ tIndex _ " (" _ tRow.%Get("Name") _ ") carries every copy field")
    }
}

}
