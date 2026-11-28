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

/// <p>Every system default setting the default setting tests (Story 24.15) create has a production named this and a suffix, in
/// <parameter>NAMESPACE</parameter> or <parameter>OTHERNAMESPACE</parameter>; <method>Clear</method> removes each one in both.</p>
Parameter DEFAULTPREFIX = "OcuProbe2415";

/// <p>Every credential the credential tests (Story 24.15) create is named this and a suffix, in <parameter>NAMESPACE</parameter> or
/// <parameter>OTHERNAMESPACE</parameter>; <method>Clear</method> removes each one in both, with its password node.</p>
Parameter CREDENTIALPREFIX = "OcuProbe2415";

/// <p>The second namespace a comparison of default settings reads.</p>
Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>Store <var>pValue</var> for <var>pKey</var> of <var>pTable</var> in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when
/// empty), creating the table, as the vendor does.</p>
ClassMethod Put(pTable As %String, pKey As %String, pValue As %String, pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
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

/// <p>Remove table <var>pTable</var>, exactly as named, and every entry it holds, from <var>pNamespace</var>
/// (<parameter>NAMESPACE</parameter> when empty), as the vendor's own table delete does; no other table is touched.</p>
ClassMethod Drop(pTable As %String, pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Do ##class(Ens.Util.LookupTable).%ClearTable(pTable)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether table <var>pTable</var> exists under exactly that name in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when
/// empty).</p>
ClassMethod Exists(pTable As %String, pNamespace As %String = "") As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tExists = ##class(Ens.Util.LookupTable).%ExistsTable(pTable)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ''tExists
}

/// <p>The entries of <var>pTable</var> in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) as <code>key=value</code>
/// joined by <code>;</code>, in the vendor's order; <code>""</code> for a table that is absent or empty.</p>
ClassMethod Entries(pTable As %String, pNamespace As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
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
    Set tSC = $$$ADDSC(tSC, ..DropPartners(..#PARTNERPREFIX))
    Set tSC = $$$ADDSC(tSC, ..DropCredentials(..#CREDENTIALPREFIX))
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.InteropScheduleFixture).DropSchedules())
    Quit $$$ADDSC(tSC, ..DropDefaults(..#DEFAULTPREFIX))
}

/// <p>Store the system default setting of the key <var>pProduction</var>, <var>pItem</var>, <var>pHostClass</var>, <var>pSetting</var> in
/// <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty), with <var>pValue</var>, <var>pDescription</var> and
/// <var>pDeployable</var>, through the vendor's own save, which updates a setting the namespace already holds (Story 24.15).</p>
ClassMethod PutDefault(pProduction As %String, pItem As %String, pHostClass As %String, pSetting As %String, pValue As %String, pDescription As %String = "", pDeployable As %Boolean = 0, pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    If pNamespace = "" Set pNamespace = ..#NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSetting = ##class(Ens.Config.DefaultSettings).%OpenId(pProduction _ "||" _ pItem _ "||" _ pHostClass _ "||" _ pSetting)
        If '$IsObject(tSetting) {
            Set tSetting = ##class(Ens.Config.DefaultSettings).%New()
            Set tSetting.ProductionName = pProduction
            Set tSetting.ItemName = pItem
            Set tSetting.HostClassName = pHostClass
            Set tSetting.SettingName = pSetting
        }
        Set tSetting.SettingValue = pValue
        Set tSetting.Description = pDescription
        Set tSetting.Deployable = pDeployable
        Set tSC = tSetting.%Save()
        Set tSetting = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The system default setting of the key <var>pProduction</var>, <var>pItem</var>, <var>pHostClass</var>, <var>pSetting</var> in
/// <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) as <code>value|description|deployable</code>, or
/// <code>&lt;absent&gt;</code> when the namespace does not hold it (Story 24.15).</p>
ClassMethod DefaultText(pProduction As %String, pItem As %String, pHostClass As %String, pSetting As %String, pNamespace As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    If pNamespace = "" Set pNamespace = ..#NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tSetting = ##class(Ens.Config.DefaultSettings).%OpenId(pProduction _ "||" _ pItem _ "||" _ pHostClass _ "||" _ pSetting)
        If $IsObject(tSetting) Set tText = tSetting.SettingValue _ "|" _ tSetting.Description _ "|" _ (''tSetting.Deployable)
        Set tSetting = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>How many system default settings of <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) have a production whose
/// name begins with <var>pPrefix</var>, in any letter case (Story 24.15).</p>
ClassMethod DefaultCount(pPrefix As %String, pNamespace As %String = "") As %Integer
{
    Set tOrigNS = $NAMESPACE
    If pNamespace = "" Set pNamespace = ..#NAMESPACE
    Set tCount = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tProduction = ""
        For {
            Set tProduction = $Order(^Ens.Config.DefaultSettingsD(tProduction))
            If tProduction = "" Quit
            If $ZConvert($Extract(tProduction, 1, $Length(pPrefix)), "U") '= $ZConvert(pPrefix, "U") Continue
            Set tItem = ""
            For {
                Set tItem = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem))
                If tItem = "" Quit
                Set tClass = ""
                For {
                    Set tClass = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem, tClass))
                    If tClass = "" Quit
                    Set tName = ""
                    For {
                        Set tName = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem, tClass, tName))
                        If tName = "" Quit
                        Set tCount = tCount + 1
                    }
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove every system default setting whose production begins with <var>pPrefix</var>, in any letter case, from
/// <parameter>NAMESPACE</parameter> and <parameter>OTHERNAMESPACE</parameter>, as the vendor's own delete does; no other setting is touched
/// (Story 24.15).</p>
ClassMethod DropDefaults(pPrefix As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Try {
            Set $NAMESPACE = tNamespace
            Kill tIds
            Set tProduction = ""
            For {
                Set tProduction = $Order(^Ens.Config.DefaultSettingsD(tProduction))
                If tProduction = "" Quit
                If $ZConvert($Extract(tProduction, 1, $Length(pPrefix)), "U") '= $ZConvert(pPrefix, "U") Continue
                Set tItem = ""
                For {
                    Set tItem = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem))
                    If tItem = "" Quit
                    Set tClass = ""
                    For {
                        Set tClass = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem, tClass))
                        If tClass = "" Quit
                        Set tName = ""
                        For {
                            Set tName = $Order(^Ens.Config.DefaultSettingsD(tProduction, tItem, tClass, tName))
                            If tName = "" Quit
                            Set tIds($Increment(tIds)) = tProduction _ "||" _ tItem _ "||" _ tClass _ "||" _ tName
                        }
                    }
                }
            }
            For tI = 1:1:$Get(tIds) {
                Set tSC = $$$ADDSC(tSC, ##class(Ens.Config.DefaultSettings).%DeleteId(tIds(tI)))
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ADDSC(tSC, ex.AsStatus())
        }
    }
    Quit tSC
}

/// <p>Remove every business partner whose name begins with <var>pPrefix</var>, in any letter case, as the vendor's own delete does
/// (Story 20.26), from <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty); no other partner is touched.</p>
ClassMethod DropPartners(pPrefix As %String, pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
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
/// them). It is created in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty).</p>
ClassMethod PutPartner(pName As %String = "", pFields As %DynamicObject = "", pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    If pName = "" Set pName = ..#PARTNER
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
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
/// <code>&lt;absent&gt;</code> when <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) does not hold it (Story 20.26).</p>
ClassMethod PartnerText(pName As %String, pNamespace As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
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

/// <p>The probe partner <var>pName</var>'s primary email, or <code>&lt;absent&gt;</code> when the namespace does not hold it (Story 24.3).</p>
ClassMethod PartnerEmail(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(pName)
        If $IsObject(tPartner) Set tText = $Select($IsObject(tPartner.PrimaryContact): tPartner.PrimaryContact.Email, 1: "")
        Set tPartner = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>Store the credential <var>pName</var> in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) with <var>pUsername</var> and
/// <var>pPartner</var>, and the password <var>pPassword</var> when it is not empty, through the vendor's own calls (Story 24.15).</p>
ClassMethod PutCredential(pName As %String, pUsername As %String = "", pPartner As %String = "", pPassword As %String = "", pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tCredential = ##class(Ens.Config.Credentials).%New()
        Set tCredential.SystemName = pName
        Set tCredential.Username = pUsername
        Set tCredential.BusinessPartner = pPartner
        If pPassword '= "" Set tSC = tCredential.PasswordSet(pPassword)
        If $$$ISOK(tSC) Set tSC = tCredential.%Save()
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The credential <var>pName</var> of <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) as
/// <code>username|partner|stored</code>, the last 1 when the vendor's password node holds something and 0 when it does not, or
/// <code>&lt;absent&gt;</code> when the namespace does not hold it exactly. It reads only whether the node is empty and never holds what it holds
/// (Story 24.15).</p>
ClassMethod CredentialText(pName As %String, pNamespace As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tCredential = ##class(Ens.Config.Credentials).%OpenId(pName)
        If $IsObject(tCredential) Set tText = tCredential.Username _ "|" _ tCredential.BusinessPartner _ "|" _ ($Length($Get(^Ens.SecondaryData.Password(pName))) > 0)
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>Whether the vendor holds a password node, empty or not, for <var>pName</var> in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when
/// empty): what a removal must leave none of (Story 24.15).</p>
ClassMethod PasswordNode(pName As %String, pNamespace As %String = "") As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = 1
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tHeld = ''$Data(^Ens.SecondaryData.Password(pName))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHeld
}

/// <p>How many credentials and password nodes of <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) are named with
/// <var>pPrefix</var>, in any letter case (Story 24.15).</p>
ClassMethod CredentialCount(pPrefix As %String, pNamespace As %String = "") As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = 0
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tName = ""
        For {
            Set tName = $Order(^Ens.Conf.CredentialsD(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tCount = tCount + 1
        }
        Set tName = ""
        For {
            Set tName = $Order(^Ens.SecondaryData.Password(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove every credential, and every password node, named with <var>pPrefix</var>, in any letter case, from <parameter>NAMESPACE</parameter>
/// and <parameter>OTHERNAMESPACE</parameter>, as the vendor's own delete does; no other credential is touched (Story 24.15).</p>
ClassMethod DropCredentials(pPrefix As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Try {
            Set $NAMESPACE = tNamespace
            Kill tIds
            Set tName = ""
            For {
                Set tName = $Order(^Ens.Conf.CredentialsD(tName))
                If tName = "" Quit
                If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tIds($Increment(tIds)) = tName
            }
            For tI = 1:1:$Get(tIds) {
                Set tSC = $$$ADDSC(tSC, ##class(Ens.Config.Credentials).%DeleteId(tIds(tI)))
            }
            Kill tNodes
            Set tName = ""
            For {
                Set tName = $Order(^Ens.SecondaryData.Password(tName))
                If tName = "" Quit
                If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tNodes($Increment(tNodes)) = tName
            }
            For tI = 1:1:$Get(tNodes) {
                Kill ^Ens.SecondaryData.Password(tNodes(tI))
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ADDSC(tSC, ex.AsStatus())
        }
    }
    Quit tSC
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
