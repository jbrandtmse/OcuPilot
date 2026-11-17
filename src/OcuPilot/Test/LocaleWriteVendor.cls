/// <p>The vendor calls <class>OcuPilot.Test.LocaleWrite</class> makes as its own setup, teardown and independent reads, each switching to <code>%SYS</code> by save and
/// restore and answering a string (<code>"error: ..."</code> when the call raised). <b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no
/// tests. It is the only test class that writes a locale, the switch's node or a configured table directly, and only the armed <class>OcuPilot.Test.LocaleWrite</class>
/// and the throwaway-only browser spec <file>ui/browser/nls-locales.browser-spec.mjs</file> call it.</p>
Class OcuPilot.Test.LocaleWriteVendor Extends %RegisteredObject
{

/// <p>The current locale's name.</p>
ClassMethod Current(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = $Get(^%SYS("LOCALE", "CURRENT"))
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The switch's node as <code>""</code> when it is not defined, else <code>=value</code>.</p>
ClassMethod NodeText(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = $Select($Data(^SYS("NLS", "Config", "LocaleFormat")): "=" _ ^SYS("NLS", "Config", "LocaleFormat"), 1: "")
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The configured <code>CSP</code> node as <code>""</code> when it is not defined, else <code>=value</code>.</p>
ClassMethod CspText(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = $Select($Data(^SYS("NLS", "Config", "CSP")): "=" _ ^SYS("NLS", "Config", "CSP"), 1: "")
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Set the switch's node to the text <var>pArg</var> a <method>NodeText</method> answered, or remove it for <code>""</code>; 1.</p>
ClassMethod SetNode(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pArg = "" {
            Kill ^SYS("NLS", "Config", "LocaleFormat")
        } Else {
            Set ^SYS("NLS", "Config", "LocaleFormat") = $Extract(pArg, 2, *)
        }
        Set tAnswer = 1
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Set the configured <code>CSP</code> table to the text <var>pArg</var> a <method>CspText</method> answered or to a table's name, or remove it for <code>""</code>, through the vendor's own object; 1 or 0.</p>
ClassMethod SetCsp(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pArg = "" {
            Kill ^SYS("NLS", "Config", "CSP")
            Set tAnswer = 1
        } Else {
            Set tTable = $Select($Extract(pArg) = "=": $Extract(pArg, 2, *), 1: pArg)
            Set tConfig = ##class(%SYS.NLS.Table).%New("Config")
            Set tAnswer = ''$$$ISOK(tConfig.CSPSet(tTable))
        }
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Whether the locale <var>pArg</var> exists.</p>
ClassMethod Exists(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = ''##class(Config.NLS.Locales).Exists(pArg)
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Create the custom locale <var>pArg</var> from the current locale's own properties; 1 or 0.</p>
ClassMethod Create(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = ##class(Config.NLS.Locales).Get($Get(^%SYS("LOCALE", "CURRENT")), .tProps)
        If $$$ISERR(tSC) Quit
        Set tProps("Description") = "OcuPilot test locale (throwaway)"
        Set tAnswer = ''$$$ISOK(##class(Config.NLS.Locales).Create(pArg, .tProps))
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Install the locale <var>pArg</var> through the vendor; 1 or 0.</p>
ClassMethod Install(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = ''$$$ISOK(##class(Config.NLS.Locales).Install(pArg))
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Reload the current locale through the vendor; 1 or 0.</p>
ClassMethod Reload(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = ''$$$ISOK(##class(Config.NLS.Locales).Reload())
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Delete the custom locale <var>pArg</var> when it exists and is not the current one; 1 when it is gone.</p>
ClassMethod RemoveCustom(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.NLS.Locales).Exists(pArg) {
            Set tAnswer = 1
            Quit
        }
        If $Get(^%SYS("LOCALE", "CURRENT")) = pArg Quit
        Set tAnswer = ''$$$ISOK(##class(Config.NLS.Locales).Delete(pArg))
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The default collation of IRISTEMP, as the vendor's own page reads it, or <code>""</code>.</p>
ClassMethod Collation(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do GetCacheDirs^STU(.tTempDir)
        If $$GetDatabaseInfo^%SYS.DATABASE(tTempDir, .tInfo) '= 1 Quit
        Set tAnswer = $$GetName^COLLATE(+$Piece(tInfo, ",", 13))
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The decimal separator the instance's number format gives a process now.</p>
ClassMethod Decimal(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = $ZUtil(174, 6)
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>A checksum of everything under <code>^SYS("NLS")</code>, answered, with a copy of the definition node of the locale <var>pName</var> in <var>pNode</var>;
/// <code>"error"</code> when the read raised.</p>
ClassMethod NlsState(pName As %String, Output pNode) As %String
{
    Kill pNode
    Set tCrc = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Merge pNode = ^SYS("NLS", "LocalesD", pName)
        Set tRef = $Name(^SYS("NLS"))
        For {
            Set tRef = $Query(@tRef)
            If (tRef = "") || ($QSubscript(tRef, 1) '= "NLS") Quit
            Set tCrc = $ZCRC(tRef _ $Char(0) _ $Get(@tRef) _ $Char(0), 7, tCrc)
        }
    } Catch {
        Set tCrc = "error"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCrc
}

/// <p>Put the definition node of the locale <var>pName</var> back to the copy <method>NlsState</method> made in <var>pNode</var>.</p>
ClassMethod RestoreNlsNode(pName As %String, ByRef pNode)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill ^SYS("NLS", "LocalesD", pName)
        Merge ^SYS("NLS", "LocalesD", pName) = pNode
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>The vendor's <code>IsInstallable</code> of the locale <var>pArg</var>, which writes the definition of some shipped locales; 1 or 0.</p>
ClassMethod Installable(pArg As %String = "") As %String
{
    Set tAnswer = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAnswer = ''##class(Config.NLS.Locales).IsInstallable(pArg)
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

}
