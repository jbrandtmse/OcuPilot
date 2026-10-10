/// <p>Pins Story 18.29's user copy where it refuses or disagrees (AD-2, AD-35, AD-39, AD-58): the port's mapping of a
/// vendor refusal (<method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method>) reached through the port's public
/// <method>OcuPilot.Port.UserCopyPort.Invoke</method>, and the read-back that names each field of a copy the instance
/// holds differently from what was sent (<class>OcuPilot.Kernel.Proposal.ReadBack</class>).</p>
/// <p>#837 is raised by the vendor itself, on a real taken name. #838, #845, #958 and an unlisted code cannot be raised
/// through the port, because the port refuses an absent source and a refused password before the vendor is called, so
/// they are answered by <class>OcuPilot.Test.UserCopyVendorFault</class>, the port with only its vendor call replaced.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and
/// deletes accounts with the <code>OcuProbe1829Rf</code> prefix. <method>OnBeforeAllTests</method> refuses anywhere it
/// does not. Every account it creates is removed by its own test's teardown or by <method>OnAfterAllTests</method>.</p>
/// <p>It also pins the mint's refusal of a directory-service or delegated source, a source read that fails without
/// being an absence, and the password's absence from a logged refusal's text.</p>
/// <p>Mutations (Rule 19): drop the #958 clause from <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> -- the
/// mapped-codes leg reddens. Remove the <code>EscalationRoles</code> row of <code>permissions.users.copy</code> from
/// <class>OcuPilot.Screen.Tool.ToolFields</class> -- the escalation-roles field leg reddens.</p>
Class OcuPilot.Test.UserCopyRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The source every copy in this class takes, and the copy's target, which each test creates and removes.</p>
Parameter SOURCE = "OcuProbe1829RfSrc";

Parameter TARGET = "OcuProbe1829RfDst";

/// <p>A directory-service source and a delegated source, created with the vendor's flags 2 and 4.</p>
Parameter LDAPSOURCE = "OcuProbe1829RfLdap";

Parameter DELEGATEDSOURCE = "OcuProbe1829RfDlg";

Parameter SOURCEROLE = "%Developer";

Parameter SOURCEESCALATION = "%Operator";

Parameter SOURCEFULLNAME = "Refusals Source";

/// <p>The probe marker written as each probe account's comment.</p>
Parameter MARKER = "OcuPilot.Test.UserCopyRefusals probe";

/// <p>A password the instance's policy accepts (the throwaway's pattern is the vendor's default).</p>
Parameter GOODPASSWORD = "Ocu-Probe-1829xyz!";

/// <p>The port that answers a vendor refusal by code, and the endpoint and type a copy is issued with.</p>
Parameter FAULTPORT = "OcuPilot.Test.UserCopyVendorFault";

Parameter REALPORT = "OcuPilot.Port.UserCopyPort";

Parameter TOOL = "OcuPilot.Screen.Tool.UserCopy";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserCopyRefusals creates and deletes accounts on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do ..RemoveProbes()
    Quit ..MakeAccount(..#SOURCE, ..#SOURCEFULLNAME, 1)
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbes()
}

/// <p>Remove the target and the flagged sources and stop the seam answering an error, whatever the test did.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.UserCopyVendorFault).ClearCode()
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Quit $$$OK
}

/// <p>AD-39, AD-2: a copy to a name the instance already holds is refused by the vendor itself with #837, which the port
/// answers 422 <code>USER.NAME.TAKEN</code> on <code>Name</code> with the published sentence, and the existing account is
/// left as it was.</p>
/// <p>Mutation (Rule 19): change the <code>837</code> in <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> to a
/// number the vendor never answers -- this reddens, because the real refusal then falls to a 500.</p>
Method TestATakenNameIsMappedFromTheRealVendorsRefusal()
{
    Set tSC = ..MakeAccount(..#TARGET, "Existing Account", 0)
    Do $$$AssertStatusOK(tSC, "the account the copy would overwrite exists")
    If $$$ISERR(tSC) Quit
    Do ..Copy(..#REALPORT, ..#TARGET, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a copy to a taken name is 422")
    Do ..AssertViolation(tFault, ##class(OcuPilot.Api.Error).#USERNAMETAKEN, "Name", ##class(OcuPilot.Api.Error).#REASONUSERNAMETAKEN)
    Do $$$AssertEquals(..Setting(..#TARGET, "FullName"), "Existing Account", "and the existing account is untouched")
}

/// <p>AD-39, AD-2: each vendor code the port names answers its own 422 on its own field with the published sentence, and
/// no answer carries the vendor's text: #837 is <code>USER.NAME.TAKEN</code> on <code>Name</code>, #838 is
/// <code>USERCOPY.SOURCE</code> on <code>CopyFrom</code>, and #845 and #958 are <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code>.</p>
/// <p>Mutation (Rule 19): drop the #958 clause from <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> -- the
/// #958 leg reddens.</p>
Method TestEachMappedVendorCodeAnswersItsOwnRefusalOnItsOwnField()
{
    Set tError = "OcuPilot.Api.Error"
    Set tCopyError = "OcuPilot.Api.UserCopyError"
    Set tLegs = $ListBuild($ListBuild(837, $Parameter(tError, "USERNAMETAKEN"), "Name", $Parameter(tError, "REASONUSERNAMETAKEN")))
    Set tLegs = tLegs _ $ListBuild($ListBuild(838, $Parameter(tCopyError, "SOURCE"), "CopyFrom", $Parameter(tCopyError, "REASONSOURCE")))
    Set tLegs = tLegs _ $ListBuild($ListBuild(845, $Parameter(tError, "USERPASSWORDPOLICY"), "Password", $Parameter(tError, "REASONUSERPASSWORDPOLICY")))
    Set tLegs = tLegs _ $ListBuild($ListBuild(958, $Parameter(tError, "USERPASSWORDPOLICY"), "Password", $Parameter(tError, "REASONUSERPASSWORDPOLICY")))
    For tI = 1:1:$ListLength(tLegs) {
        Set tLeg = $List(tLegs, tI)
        Set tCode = $List(tLeg, 1)
        Do ##class(OcuPilot.Test.UserCopyVendorFault).SetCode(tCode)
        Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 422, "vendor #" _ tCode _ " is 422")
        Do ..AssertViolation(tFault, $List(tLeg, 2), $List(tLeg, 3), $List(tLeg, 4))
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ $Parameter(..#FAULTPORT, "TEXTMARKER")), "and the answer to #" _ tCode _ " carries none of the vendor's text")
        Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created by #" _ tCode)
    }
}

/// <p>AD-2: a vendor code the port does not name is a 500 whose answer carries none of the vendor's text.</p>
/// <p>Mutation (Rule 19): make the final arm of <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> answer the
/// source refusal instead of <method>OcuPilot.Port.AdminPort.Fail</method> -- this reddens on the status.</p>
Method TestAnUnlistedVendorCodeIsA500WithoutTheVendorsText()
{
    Do ##class(OcuPilot.Test.UserCopyVendorFault).SetCode(5001)
    Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "an unlisted vendor code is 500")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#INTERNAL, "on the internal code")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ $Parameter(..#FAULTPORT, "TEXTMARKER")), "and the answer carries none of the vendor's text")
}

/// <p>AD-35, AD-2: a password the policy refuses is answered 422 <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code> with the policy's own reason before the vendor is called, so a vendor that would fail with
/// a code the port does not name is never reached.</p>
/// <p>Mutation (Rule 19): delete the <method>OcuPilot.Port.AdminPort.PasswordGuard</method> call in
/// <method>OcuPilot.Port.UserCopyPort.Copy</method> -- this reddens, because the vendor's unlisted code is then
/// answered 500.</p>
Method TestAWeakPasswordIsRefusedBeforeTheVendorIsCalled()
{
    Do ##class(OcuPilot.Test.UserCopyVendorFault).SetCode(5001)
    Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault, .tResult, "", "a")
    Set tReason = ""
    Set tVerdict = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict("a", ..#TARGET, .tReason)
    Do $$$AssertTrue('tVerdict, "the policy refuses the password")
    Do $$$AssertEquals(tHttp, 422, "a refused password is 422 and the vendor's 500 is not reached")
    Do ..AssertViolation(tFault, ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "Password", tReason)
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-2, AD-35: only the refusal the port does not name reaches the log, with the vendor's text, and the four it names
/// write nothing. The log window opens before the five refusals and is read after a flush, and the unlisted refusal's
/// own line is the positive control that the window sees a line of this kind.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> answer #838 through
/// <method>OcuPilot.Port.AdminPort.Fail</method> -- the unlogged leg reddens on #838's text in the log.</p>
Method TestOnlyTheUnlistedRefusalIsLoggedAndNeverTheMappedOnes()
{
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Set tCodes = $ListBuild(837, 838, 845, 958, 5001)
    For tI = 1:1:$ListLength(tCodes) {
        Do ##class(OcuPilot.Test.UserCopyVendorFault).SetCode($List(tCodes, tI))
        Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault)
    }
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written past the refusals")
    Set tLog = ##class(OcuPilot.Test.SslSinks).LogSince(tOffset)
    Set tMarker = $Parameter(..#FAULTPORT, "TEXTMARKER")
    Do $$$AssertTrue(tLog [ (tMarker _ 5001), "the unlisted refusal is logged with the vendor's text, so the window sees this kind of line")
    For tI = 1:1:4 {
        Do $$$AssertTrue(tLog '[ (tMarker _ $List(tCodes, tI)), "and #" _ $List(tCodes, tI) _ " is not logged")
    }
}

/// <p>The matrix's source row, AD-39: the copy tool's composition, which the agent's mint runs, refuses a
/// directory-service source and a delegated source with the source sentence and composes nothing, so no proposal is
/// minted for either.</p>
/// <p>Mutation (Rule 19): refuse only an absent source in <method>OcuPilot.Screen.Tool.UserCopy.ComposeCreate</method>
/// (drop its <method>OcuPilot.Port.UserCopyPort.Unsupported</method> test) -- this reddens.</p>
Method TestTheMintsCompositionRefusesADirectoryOrDelegatedSource()
{
    For tPair = $ListBuild(..#LDAPSOURCE, 2), $ListBuild(..#DELEGATEDSOURCE, 4) {
        Set tName = $List(tPair, 1)
        Set tSC = ..MakeFlagged(tName, $List(tPair, 2))
        Do $$$AssertStatusOK(tSC, tName _ " is created with the vendor's flag " _ $List(tPair, 2))
        Set tArgs = {"Name": (..#TARGET), "CopyFrom": (tName)}
        Set tPayload = ""
        Set tSC = $ClassMethod(..#TOOL, "ComposeCreate", tArgs, "Name", $ClassMethod(..#TOOL, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        Do $$$AssertStatusOK(tSC, "the composition completes for " _ tName)
        Do $$$AssertTrue($Get(tProblem) [ ##class(OcuPilot.Api.UserCopyError).#REASONSOURCE, "and refuses " _ tName _ " with the source sentence: " _ $Get(tProblem))
        Do $$$AssertTrue('$IsObject($Get(tPayload)), "and composes no payload for " _ tName)
    }
}

/// <p>AD-36: a source read that fails for any reason but the account's absence is a fault, answered 500 on the
/// internal code and never as the source refusal, and nothing is created.</p>
/// <p>Mutation (Rule 19): answer every unread source with <method>OcuPilot.Port.UserCopyPort.SourceRefusal</method> in
/// <method>OcuPilot.Port.UserCopyPort.Copy</method> -- this reddens.</p>
Method TestASourceReadThatFailsIsAFaultNotARefusalOfTheSource()
{
    Do ##class(OcuPilot.Test.UserCopyVendorFault).SetSourceFault()
    Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "a source read that fails is 500")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#INTERNAL, "on the internal code, not USERCOPY.SOURCE")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-35: an unlisted vendor refusal whose text quotes the new password is logged with the password masked.</p>
/// <p>Mutation (Rule 19): call <method>OcuPilot.Port.AdminPort.Fail</method> without the copy's body in
/// <method>OcuPilot.Port.UserCopyPort.MapVendorRefusal</method> -- this reddens.</p>
Method TestAnUnlistedRefusalQuotingThePasswordIsLoggedWithoutIt()
{
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Do ##class(OcuPilot.Test.UserCopyVendorFault).SetCode(5001, 1)
    Do ..Copy(..#FAULTPORT, ..#TARGET, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "the unlisted refusal is 500")
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written past the refusal")
    Set tLog = ##class(OcuPilot.Test.SslSinks).LogSince(tOffset)
    Do $$$AssertTrue(tLog [ ($Parameter(..#FAULTPORT, "TEXTMARKER") _ 5001), "the refusal is logged, so the window sees its line")
    Do $$$AssertTrue(tLog '[ ..#GOODPASSWORD, "and the line does not carry the password")
}

/// <p>AD-58: the read-back of a copy the instance holds as sent answers <code>matches</code>, and one that differs on a
/// single field names that field alone: the full name, the roles, or the escalation roles. The copy is a real one, made
/// through the port, and its read-back is the one the copy's route and the confirm answer.</p>
/// <p>Mutation (Rule 19): remove the <code>EscalationRoles</code> row of <code>permissions.users.copy</code> from
/// <class>OcuPilot.Screen.Tool.ToolFields</class> -- the escalation-roles leg reddens, because that field is then not
/// compared.</p>
Method TestTheReadBackNamesEachFieldThatDisagreesWithTheCopy()
{
    Do ..Copy(..#REALPORT, ..#TARGET, .tHttp, .tFault, .tResult, "Refusals Copy")
    Do $$$AssertEquals(tHttp, 200, "the copy is made through the port")
    If tHttp '= 200 Quit

    Set tSent = ..Sent("Refusals Copy", ["%Developer"], ["%Operator"])
    Do tSent.%Set("Password", ..#GOODPASSWORD, "string")
    Set tAnswer = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#TOOL, ..#TARGET, tSent, "", ..#REALPORT, tResult, tHttp)
    Do $$$AssertEquals(tAnswer.%Get("verdict"), "matches", "a copy held as sent reads back matches")
    Do $$$AssertEquals(tAnswer.%Get("fields").%ToJSON(), "[]", "naming no field")
    Do $$$AssertTrue(tAnswer.%Get("written").%ToJSON() [ "Password", "and the password is listed as written, never compared")

    ; A leg's sent payload is held in its own array node: an object put in a $List loses its identity.
    Set tNames = $ListBuild("FullName", "Roles", "EscalationRoles")
    Set tLegSent(1) = ..Sent("Another Name", ["%Developer"], ["%Operator"])
    Set tLegSent(2) = ..Sent("Refusals Copy", ["%Operator"], ["%Operator"])
    Set tLegSent(3) = ..Sent("Refusals Copy", ["%Developer"], [])
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Do tLegSent(tI).%Set("Password", ..#GOODPASSWORD, "string")
        Set tAnswer = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#TOOL, ..#TARGET, tLegSent(tI), "", ..#REALPORT, tResult, tHttp)
        Do $$$AssertEquals(tAnswer.%Get("verdict"), "differs", "a copy whose " _ tName _ " differs reads back differs")
        Do $$$AssertEquals(tAnswer.%Get("fields").%ToJSON(), "[""" _ tName _ """]", "naming " _ tName _ " alone")
    }
}

/// <p>The copy of <parameter>SOURCE</parameter> to <var>pName</var> through port class <var>pPort</var>, with the
/// source's roles and escalation role as the body names them and <var>pPassword</var> as its password. <var>pHttp</var> and <var>pFault</var> are the port's
/// answer, and <var>pResult</var> the account it read back.</p>
ClassMethod Copy(pPort As %String, pName As %String, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pResult, pFullName As %String = "", pPassword As %String = {..#GOODPASSWORD})
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = ..Sent(pFullName, [(..#SOURCEROLE)], [(..#SOURCEESCALATION)])
    Do tBody.%Set("Password", pPassword, "string")
    Set pResult = ""
    Set tSC = $ClassMethod(pPort, "Invoke", "Security.User", "COPY", .tQuery, tBody, .pResult, .pHttp, .pFault)
}

/// <p>A copy's sent payload: the source, the full name, the roles and the escalation roles.</p>
ClassMethod Sent(pFullName As %String, pRoles As %DynamicArray, pEscalation As %DynamicArray) As %DynamicObject
{
    Set tSent = {}
    Do tSent.%Set("CopyFrom", ..#SOURCE, "string")
    Do tSent.%Set("FullName", pFullName, "string")
    Do tSent.%Set("Roles", pRoles)
    Do tSent.%Set("EscalationRoles", pEscalation)
    Quit tSent
}

/// <p>Assert that <var>pFault</var> is a validation envelope with one violation of code <var>pCode</var> on
/// <var>pField</var> carrying <var>pReason</var>.</p>
Method AssertViolation(pFault As %DynamicObject, pCode As %String, pField As %String, pReason As %String)
{
    Do $$$AssertEquals($Select($IsObject(pFault): pFault.%Get("code"), 1: ""), pCode, "the answer's code is " _ pCode)
    Do $$$AssertEquals($Select($IsObject(pFault): pFault.%Get("reason"), 1: ""), pReason, "with the published sentence as its reason")
    Set tViolation = ""
    If $IsObject(pFault) && $IsObject(pFault.%Get("detail")) && $IsObject(pFault.%Get("detail").%Get("violations")) Set tViolation = pFault.%Get("detail").%Get("violations").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.%Get("field"), 1: ""), pField, "on the " _ pField _ " field")
}

/// <p>Whether the instance holds an account named <var>pName</var>, read in <code>%SYS</code> by AD-16's save and
/// restore.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Get(pName, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$ISOK(tSC)
}

/// <p>The value of setting <var>pKey</var> on account <var>pName</var> as the instance holds it, or <code>""</code> when
/// the account is absent.</p>
ClassMethod Setting(pName As %String, pKey As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Users).Get(pName, .tProps)) Set tValue = $Get(tProps(pKey)) _ ""
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p>Create account <var>pName</var> with the source's role and the full name <var>pFullName</var>; when
/// <var>pEscalate</var> is true it also holds the escalation role. In <code>%SYS</code>, by AD-16's save and restore.</p>
ClassMethod MakeAccount(pName As %String, pFullName As %String, pEscalate As %Boolean) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(pName, ..#SOURCEROLE, ..#GOODPASSWORD, pFullName, "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) && pEscalate {
            Kill tProps
            Set tProps("EscalationRoles") = ..#SOURCEESCALATION
            Set tSC = ##class(Security.Users).Modify(pName, .tProps)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove one account the test created, in <code>%SYS</code>; an absent account is not an error.</p>
ClassMethod RemoveAccount(pName As %String)
{
    If '..Exists(pName) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(Security.Users).Delete(pName)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Create a directory-service or delegated account <var>pName</var>, <var>pFlags</var> being the vendor's flag, in
/// <code>%SYS</code>.</p>
ClassMethod MakeFlagged(pName As %String, pFlags As %Integer) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(pName, ..#SOURCEROLE, ..#GOODPASSWORD, "Probe flagged source", "", "", "", 0, 1, ..#MARKER, pFlags)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the probe accounts this class creates.</p>
ClassMethod RemoveProbes() As %Status
{
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Do ..RemoveAccount(..#SOURCE)
    Quit $$$OK
}

}
