/// <p>Test-only helper for the wallet secret suites: creates and removes the probe collection
/// <parameter>COLLECTION</parameter> and its secrets by exact name, in <code>%SYS</code> by explicit
/// save and restore. It never touches the demo collection <code>OcuPilotDemo</code>.</p>
/// <p><b>It reads a stored value in one place</b>, <method>StoredValue</method>, which a test uses to
/// prove that an edit without a new value kept the stored one. No shipped class reads a value; this
/// helper is not shipped.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletProbe Extends %RegisteredObject
{

/// <p>The probe collection every wallet suite writes into.</p>
Parameter COLLECTION = "OcuPilotProbe86";

/// <p>The probe collection's use and edit resource.</p>
Parameter RESOURCE = "%Admin_Wallet:USE";

/// <p>Create <parameter>COLLECTION</parameter> when it is absent; <var>pCreated</var> says whether
/// this call made it.</p>
ClassMethod EnsureCollection(Output pCreated As %Boolean) As %Status
{
    Set pCreated = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(%Wallet.Collection).Exists(..#COLLECTION) {
            Set tSC = ##class(%Wallet.Collection).Create(..#COLLECTION, {"Resource": (..#RESOURCE)})
            Set pCreated = $$$ISOK(tSC)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store the key-value secret <var>pName</var> with the properties <var>pProperties</var>
/// (<code>Secret</code> among them), as the vendor class's own <code>Create</code> does.</p>
ClassMethod AddKeyValue(pName As %String, pProperties As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%Wallet.KeyValue).Create(pName, pProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store a generated 16-byte symmetric key as <var>pName</var>: a secret of a type other than
/// key-value.</p>
ClassMethod AddSymmetricKey(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%Wallet.SymmetricKey).Create(pName, {"Length": 16})
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds a secret named exactly <var>pName</var>.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''$ListFind(..Names(), pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>The stored value of <var>pName</var>, read through the vendor class, or <code>""</code>. For a
/// test's own comparison only.</p>
ClassMethod StoredValue(pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValue = ##class(%Wallet.KeyValue).GetSecretValue(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>The names of every secret in <parameter>COLLECTION</parameter>, exact, as a
/// <class>%List</class>. <b>Caller contract:</b> <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod Names() As %List [ Private ]
{
    Set tNames = ""
    Set tRS = ##class(%ResultSet).%New("%SYS.Wallet.Secret:List")
    If $$$ISERR(tRS.Execute(..#COLLECTION, "*")) Quit ""
    While tRS.Next() {
        Set tNames = tNames _ $ListBuild(tRS.Get("Name"))
    }
    Do tRS.Close()
    Quit tNames
}

/// <p>Remove the secret named exactly <var>pName</var> when it is present.</p>
ClassMethod RemoveSecret(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $ListFind(..Names(), pName) Set tSC = ##class(%Wallet.Secret).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every secret in <parameter>COLLECTION</parameter>, each by its exact name, then the
/// collection itself. <var>pRemaining</var> is how many secrets survived, and the status is an error
/// when anything, the collection included, is still there.</p>
ClassMethod Remove(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(%Wallet.Collection).Exists(..#COLLECTION) {
            Set tNames = ..Names()
            For tI = 1:1:$ListLength(tNames) {
                Set tSC = $$$ADDSC(tSC, ##class(%Wallet.Secret).Delete($List(tNames, tI)))
            }
            Set pRemaining = $ListLength(..Names())
            If pRemaining = 0 Set tSC = $$$ADDSC(tSC, ##class(%Wallet.Collection).Delete(..#COLLECTION))
            If ##class(%Wallet.Collection).Exists(..#COLLECTION) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe collection " _ ..#COLLECTION _ " is still present after its removal"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
