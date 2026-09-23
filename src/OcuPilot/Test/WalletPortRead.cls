/// <p>Pins <class>OcuPilot.Port.WalletPort</class>'s completed <code>Wallet.Secret</code>
/// <code>GET</code> (AD-27's third case, AD-35) and the vendor facts Story 8.6 relies on (AC6): the
/// answer's exact key set for a key-value secret and for another type, the exact-case name match
/// against a case-variant sibling, the absent name and the absent collection, no stored value in any
/// answer, and how the vendor's <code>PUT</code> stores <code>Usage</code> and <code>Secret</code>
/// in each published shape.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and an account holding
/// <code>%Admin_Wallet</code>. It creates the probe collection of
/// <class>OcuPilot.Test.WalletProbe</class> and its secrets, and removes them by exact name.</p>
Class OcuPilot.Test.WalletPortRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.WalletPort";

Parameter PROBE = "OcuPilot.Test.WalletProbe";

Method OnBeforeAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletPortRead")
    Quit tSC
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $Parameter(..#PROBE, "COLLECTION") _ "." _ pPart
}

/// <p>Read <var>pName</var> through the port's completed <code>GET</code>.</p>
ClassMethod Read(pName As %String, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery("name") = pName
    Quit $ClassMethod(..#PORT, "Invoke", "Wallet.Secret", "GET", .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p><var>pObject</var>'s keys, sorted, comma-separated.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Kill tSeen
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tSeen(tKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>AD-27's third case: a key-value secret reads back as exactly <code>{Type, Usage, RequireTLS,
/// AllowedHosts}</code>, each as the vendor stored it, and the answer carries the stored value
/// nowhere -- not as a key and not as text.</p>
/// <p>Mutation (Rule 19): set <code>Secret</code> from the vendor class's stored value on
/// <method>OcuPilot.Port.WalletPort.KeyValueSettings</method>'s answer -> the key set and the value
/// scan go red.</p>
Method TestTheComposedReadNeverCarriesTheStoredValue()
{
    Set tValue = "OcuPilotProbe86Value" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(12), 1), "+/=", "")
    Set tName = ..Name("ReadKv")
    Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", tName, {"Secret": (tValue), "Usage": 5, "RequireTLS": false, "AllowedHosts": ["h1.example", "h2"]})
    Do $$$AssertStatusOK(tSC, "the probe secret is stored")
    Set tSC = ..Read(tName, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the completed read answers")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Keys(tResult), "AllowedHosts,RequireTLS,Type,Usage", "the answer's keys are exactly the type and the three settings")
    Do $$$AssertEquals(tResult.%Get("Type"), "%Wallet.KeyValue", "the type is the vendor's class name")
    Do $$$AssertEquals(tResult.%Get("Usage") _ "|" _ tResult.%GetTypeOf("Usage"), "5|number", "Usage is the stored number")
    Do $$$AssertEquals(tResult.%Get("RequireTLS") _ "|" _ tResult.%GetTypeOf("RequireTLS"), "0|boolean", "RequireTLS is the stored boolean")
    Do $$$AssertEquals(tResult.%Get("AllowedHosts").%ToJSON(), "[""h1.example"",""h2""]", "AllowedHosts is the stored list as an array")
    Do $$$AssertEquals(tResult.%ToJSON() [ tValue, 0, "and the stored value appears nowhere in the answer")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tName), tValue, "while the instance still holds it")
}

/// <p>AC6: the vendor's own name filter ignores case, and the port's does not -- a secret and its
/// case-variant sibling each read as themselves, and a third spelling of the same name is absent.
/// An absent name and an absent collection are 404 on their own codes.</p>
/// <p>Mutation (Rule 19): fold case in <method>OcuPilot.Port.WalletPort.Completed</method>'s name
/// comparison -> a third spelling of the name is found, and this goes red.</p>
Method TestTheNameIsComparedExactly()
{
    Set tUpper = ..Name("Probe86A")
    Set tLower = ..Name("probe86a")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tUpper, {"Secret": "a", "Usage": 1}), "the upper-case secret is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tLower, {"Secret": "b", "Usage": 2}), "and its lower-case sibling beside it")
    Set tSC = ..Read(tUpper, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("Usage"), 1: ""), 1, "the upper-case name reads its own secret")
    Set tSC = ..Read(tLower, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("Usage"), 1: ""), 2, "and the lower-case name its own")
    Set tSC = ..Read(..Name("PROBE86A"), .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a third spelling of the name is not read as either")
    Do $$$AssertEquals(tHttp, 404, "it is absent")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT, "on the absent-name code")

    Set tSC = ..Read("OcuPilotProbe86Missing.Anything", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "a name in a collection that does not exist is 404")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT, "on the absent-collection code")
    Set tSC = ..Read("NoDotAtAll", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "and a name with no collection part is absent")
}

/// <p>A secret of another type reads as its <code>Type</code> alone: the class read is only for a
/// key-value secret.</p>
Method TestAnotherTypeAnswersItsTypeAlone()
{
    Set tName = ..Name("ReadSym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tName), "a symmetric key is stored")
    Set tSC = ..Read(tName, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the completed read answers")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.%ToJSON(), "{""Type"":""%Wallet.SymmetricKey""}", "with its type and nothing else")
}

/// <p>AC6: the vendor's <code>PUT</code>, sent through the admin port's wrapper, stores
/// <code>Usage</code> as one number whether it was sent as a list of use names or as the number, and
/// stores a <code>Secret</code> sent as an object and one sent as that object's JSON text
/// alike.</p>
Method TestTheVendorStoresUsageAndSecretInOneForm()
{
    Set tArrayName = ..Name("FactArray")
    Set tNumberName = ..Name("FactNumber")
    Kill tQuery
    Set tQuery("name") = tArrayName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Wallet.Secret", "PUT", .tQuery, {"Type": "%Wallet.KeyValue", "Usage": ["HTTP"], "Secret": {"user": "u86", "password": "p86"}}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a PUT with a list of uses and an object value is accepted")
    Do $$$AssertEquals(tHttp, 201, "and creates the secret")
    Kill tQuery
    Set tQuery("name") = tNumberName
    Set tText = {"user": "u86", "password": "p86"}.%ToJSON()
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Wallet.Secret", "PUT", .tQuery, {"Type": "%Wallet.KeyValue", "Usage": 1, "Secret": (tText)}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a PUT with the number and the object's JSON text is accepted")
    Do $$$AssertEquals(tHttp, 201, "and creates that secret too")
    Set tSC = ..Read(tArrayName, .tArray, .tHttp, .tFault)
    Set tSC = ..Read(tNumberName, .tNumber, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tArray)): tArray.%Get("Usage"), 1: ""), 1, "the list of uses is stored as the number 1")
    Do $$$AssertEquals($Select($IsObject($Get(tNumber)): tNumber.%Get("Usage"), 1: ""), 1, "and so is the number")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tArrayName), tText, "the object is stored as its JSON text")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tNumberName), tText, "and so is that text sent as a string")
}

}
