/// <p>Test-only helper for the device suites: creates and removes devices named with
/// <parameter>PREFIX</parameter>, each by its exact name, through <class>Config.Devices</class> in
/// <code>%SYS</code> by explicit save and restore, and reads the instance's configuration file back.
/// It never touches a device whose name does not start with <parameter>PREFIX</parameter>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DeviceProbe Extends %RegisteredObject
{

/// <p>The prefix every probe device's name starts with.</p>
Parameter PREFIX = "OcuPilotProbe88";

/// <p>The subtype and type a probe is created with unless its properties say otherwise: the classic
/// page's own defaults.</p>
Parameter SUBTYPE = "P-DEC";

Parameter TYPE = "OTH";

/// <p>Create the device <var>pName</var> with <var>pProperties</var> over a physical device, type and
/// subtype of its own, as the vendor class's own <code>Create</code> does. A name outside
/// <parameter>PREFIX</parameter> is refused.</p>
ClassMethod Add(pName As %String, pProperties As %DynamicObject = "") As %Status
{
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "a probe device's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Kill tProperties
        Set tProperties("PhysicalDevice") = "/tmp/" _ pName _ ".txt"
        Set tProperties("Type") = ..#TYPE
        Set tProperties("SubType") = ..#SUBTYPE
        If $IsObject(pProperties) {
            Set tIterator = pProperties.%GetIterator()
            While tIterator.%GetNext(.tKey, .tValue) { Set tProperties(tKey) = tValue }
        }
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Devices).Create(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds a device named exactly <var>pName</var>.</p>
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

/// <p>The device <var>pName</var>'s stored value of <var>pProperty</var>, read through the vendor
/// class, or <code>""</code>.</p>
ClassMethod Stored(pName As %String, pProperty As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        If $$$ISOK(##class(Config.Devices).Get(pName, .tProperties)) Set tValue = $Get(tProperties(pProperty))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Remove the device named exactly <var>pName</var> when it is present; an error when it
/// survives. A name outside <parameter>PREFIX</parameter> is refused.</p>
ClassMethod Remove(pName As %String) As %Status
{
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "a probe device's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $ListFind(..Names(), pName) Set tSC = ##class(Config.Devices).Delete(pName)
        If $ListFind(..Names(), pName) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe device " _ pName _ " is still present after its removal"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every device whose name starts with <parameter>PREFIX</parameter>, each by its exact
/// name. <var>pRemaining</var> is how many survived, and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNames = ..Names()
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If $Extract(tName, 1, $Length(..#PREFIX)) '= ..#PREFIX Continue
            Set tSC = $$$ADDSC(tSC, ##class(Config.Devices).Delete(tName))
        }
        Set tNames = ..Names()
        For tI = 1:1:$ListLength(tNames) {
            If $Extract($List(tNames, tI), 1, $Length(..#PREFIX)) = ..#PREFIX Set pRemaining = pRemaining + 1
        }
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe device(s) survived their removal"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance's configuration file validates (<code>Config.CPF.Validate</code>), and
/// whether it names any probe device, in <var>pNamesProbe</var>.</p>
ClassMethod CpfValid(Output pNamesProbe As %Boolean) As %Boolean
{
    Set pNamesProbe = 0
    Set tValid = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFile = ##class(%SYS.System).GetCPFFileName()
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If $$$ISOK(tStream.LinkToFile(tFile)) {
            While 'tStream.AtEnd {
                If tStream.ReadLine() [ ..#PREFIX Set pNamesProbe = 1
            }
        }
        Set tStream = ""
        Set tValid = $$$ISOK(##class(Config.CPF).Validate())
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValid = 0
    }
    Quit tValid
}

/// <p>The names of every device, exact, as a <class>%List</class>. <b>Caller contract:</b>
/// <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod Names() As %List [ Private ]
{
    Set tNames = ""
    Set tRS = ##class(%ResultSet).%New("Config.Devices:List")
    If $$$ISERR(tRS.Execute("*")) Quit ""
    While tRS.Next() {
        Set tNames = tNames _ $ListBuild(tRS.Get("Name"))
    }
    Do tRS.Close()
    Quit tNames
}

}
