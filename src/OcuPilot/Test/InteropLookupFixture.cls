/// <p>The probe lookup tables and business partners of Story 20.5's tests, in <code>USER</code> on a throwaway container
/// (<class>OcuPilot.Test.InteropLookupControl</class> and its siblings): every table is named
/// <parameter>PREFIX</parameter> and a suffix, and <method>Clear</method> removes every one of them and both probe partners.
/// Each method switches to <parameter>NAMESPACE</parameter> by explicit save and restore and calls only vendor classes while
/// switched. A write goes through the vendor's own calls, never a direct global set.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropLookupFixture Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

/// <p>Every probe table's name begins with this.</p>
Parameter PREFIX = "OcuProbe205";

Parameter PARTNER = "OcuProbe205Partner";

/// <p>The second probe partner, so a list cut to one row has a row to leave out.</p>
Parameter PARTNERB = "OcuProbe205PartnerB";

/// <p>Every partner the business partner write tests (Story 20.26) create is named this and a suffix; <method>Clear</method>
/// removes each one.</p>
Parameter PARTNERPREFIX = "OcuProbe226";

/// <p>Store <var>pValue</var> for <var>pKey</var> of <var>pTable</var>, creating the table, as the vendor does.</p>
ClassMethod Put(pTable As %String, pKey As %String, pValue As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Util.LookupTable).%UpdateValue(pTable, pKey, pValue, 1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <var>pKey</var> from <var>pTable</var>, as the vendor does.</p>
ClassMethod Remove(pTable As %String, pKey As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Util.LookupTable).%RemoveValue(pTable, pKey)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove table <var>pTable</var>, exactly as named, and every entry it holds, as the vendor's own table delete does; no other
/// table is touched.</p>
ClassMethod Drop(pTable As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(Ens.Util.LookupTable).%ClearTable(pTable)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether table <var>pTable</var> exists under exactly that name.</p>
ClassMethod Exists(pTable As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tExists = ##class(Ens.Util.LookupTable).%ExistsTable(pTable)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ''tExists
}

/// <p>The entries of <var>pTable</var> as <code>key=value</code> joined by <code>;</code>, in the vendor's order; <code>""</code>
/// for a table that is absent or empty.</p>
ClassMethod Entries(pTable As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tKey = ""
        For {
            Set tKey = $Order(^Ens.LookupTable(pTable, tKey))
            If tKey = "" Quit
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tKey _ "=" _ $Get(^Ens.LookupTable(pTable, tKey))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>The vendor's stamp of <var>pTable</var>, raw (<code>$ZTIMESTAMP</code>), <code>""</code> for none.</p>
ClassMethod Stamp(pTable As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tStamp = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStamp = ##class(Ens.Util.LookupTable).getTimestamp(pTable)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tStamp
}

/// <p>The names of the probe tables that exist, comma-separated.</p>
ClassMethod Tables() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tName = ..#PREFIX
        Set tName = $Order(^Ens.LookupTable(tName), -1)
        For {
            Set tName = $Order(^Ens.LookupTable(tName))
            If (tName = "") || ($Extract(tName, 1, $Length(..#PREFIX)) '= ..#PREFIX) Quit
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tName
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>Remove every probe table, in any letter case, and both probe partners.</p>
ClassMethod Clear() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill tNames
        Set tName = ""
        For {
            Set tName = $Order(^Ens.LookupTable(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(..#PREFIX)), "U") = $ZConvert(..#PREFIX, "U") Set tNames(tName) = ""
        }
        Set tName = ""
        For {
            Set tName = $Order(tNames(tName))
            If tName = "" Quit
            Do ##class(Ens.Util.LookupTable).%ClearTable(tName)
        }
        For tPartnerName = ..#PARTNER, ..#PARTNERB {
            If ##class(Ens.Config.BusinessPartner).%ExistsId(tPartnerName) Set tSC = $$$ADDSC(tSC, ##class(Ens.Config.BusinessPartner).%DeleteId(tPartnerName))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit $$$ADDSC(tSC, ..DropPartners(..#PARTNERPREFIX))
}

/// <p>Remove every business partner whose name begins with <var>pPrefix</var>, in any letter case, as the vendor's own delete does
/// (Story 20.26); no other partner is touched.</p>
ClassMethod DropPartners(pPrefix As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill tNames
        Set tName = ""
        For {
            Set tName = $Order(^Ens.Config.BusinessPartnerD(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tNames(tName) = ""
        }
        Set tName = ""
        For {
            Set tName = $Order(tNames(tName))
            If tName = "" Quit
            Set tSC = $$$ADDSC(tSC, ##class(Ens.Config.BusinessPartner).%DeleteId(tName))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe partner <var>pName</var> (<parameter>PARTNER</parameter> when empty) with both contacts. Each member of
/// <var>pFields</var>, when it is an object, replaces the field of that name (<code>Description</code>, <code>PrimaryContact</code>,
/// <code>PrimaryPhone</code> and so on, as <class>OcuPilot.Port.InteropPort</class>'s <parameter>PARTNERFIELDS</parameter> names
/// them).</p>
ClassMethod PutPartner(pName As %String = "", pFields As %DynamicObject = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    If pName = "" Set pName = ..#PARTNER
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tPartner = ##class(Ens.Config.BusinessPartner).%New()
        Set tPartner.PartnerName = pName
        Set tPartner.Description = "Probe partner description"
        Set tPartner.PrimaryContact = ##class(Ens.Config.BusinessPartnerContact).%New()
        Set tPartner.PrimaryContact.Name = "Pat Primary"
        Set tPartner.PrimaryContact.Title = "Analyst"
        Set tPartner.PrimaryContact.Email = "pat@example.test"
        Set tPartner.PrimaryContact.PhoneNumber = "555-0101"
        Set tPartner.PrimaryContact.MobileNumber = "555-0102"
        Set tPartner.PrimaryContact.Notes = "Primary notes"
        Set tPartner.AlternativeContact = ##class(Ens.Config.BusinessPartnerContact).%New()
        Set tPartner.AlternativeContact.Name = "Alex Alternative"
        Set tPartner.AlternativeContact.Title = "Lead"
        Set tPartner.AlternativeContact.Email = "alex@example.test"
        Set tPartner.AlternativeContact.PhoneNumber = "555-0201"
        Set tPartner.AlternativeContact.MobileNumber = "555-0202"
        Set tPartner.AlternativeContact.Notes = "Alternative notes"
        If $IsObject(pFields) {
            Set tIterator = pFields.%GetIterator()
            While tIterator.%GetNext(.tField, .tValue) {
                If tField = "Description" {
                    Set tPartner.Description = tValue
                    Continue
                }
                Set tContact = $Select($Extract(tField, 1, 7) = "Primary": "PrimaryContact", 1: "AlternativeContact")
                Set tRest = $Extract(tField, $Select(tContact = "PrimaryContact": 8, 1: 12), *)
                Set $Property($Property(tPartner, tContact), $Case(tRest, "Contact": "Name", "Phone": "PhoneNumber", "Mobile": "MobileNumber", : tRest)) = tValue
            }
        }
        Set tSC = tPartner.%Save()
        Set tPartner = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe partner <var>pName</var> as <code>description|primary contact|primary phone|alternative notes</code>, or
/// <code>&lt;absent&gt;</code> when the namespace does not hold it (Story 20.26).</p>
ClassMethod PartnerText(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(pName)
        If $IsObject(tPartner) {
            Set tPrimary = tPartner.PrimaryContact
            Set tAlternative = tPartner.AlternativeContact
            Set tText = tPartner.Description _ "|" _ $Select($IsObject(tPrimary): tPrimary.Name, 1: "") _ "|" _ $Select($IsObject(tPrimary): tPrimary.PhoneNumber, 1: "") _ "|" _ $Select($IsObject(tAlternative): tAlternative.Notes, 1: "")
        }
        Set tPartner = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>Everything the lookup and partner reads must leave alone, as one SHA-256: the whole of <code>^Ens.LookupTable</code>
/// (stamps included) and <code>^Ens.Config.BusinessPartnerD</code>.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRoots = $ListBuild($Name(^Ens.LookupTable), $Name(^Ens.Config.BusinessPartnerD))
        For tAt = 1:1:$ListLength(tRoots) {
            Set tRoot = $List(tRoots, tAt)
            Set tText = tText _ "{" _ tRoot _ "=" _ $Get(@tRoot) _ ":"
            Set tRef = tRoot
            For {
                Set tRef = $Query(@tRef)
                If (tRef = "") || ($Name(@tRef, $QLength(tRoot)) '= tRoot) Quit
                Set tText = tText _ tRef _ "=" _ @tRef _ ";"
            }
            Set tText = tText _ "}"
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = tText _ "<error " _ ex.DisplayString() _ ">"
    }
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(tText, "O", "UTF8"))), "L") _ ":" _ $Length(tText)
}

}
