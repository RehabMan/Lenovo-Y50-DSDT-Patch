// Instead of providing patched DSDT/SSDT, just include a single SSDT
// and do the rest of the work in config.plist

// A bit experimental, and a bit more difficult with laptops, but
// still possible.

// Note: No solution for missing IAOE here, but so far, not a problem.

DefinitionBlock ("SSDT-HACK.aml", "SSDT", 1, "hack", "hack", 0x00003000)
{
    External(_SB.PCI0, DeviceObj)
    External(_SB.PCI0.LPCB, DeviceObj)

    // All _OSI calls in DSDT are routed to XOSI...
    // XOSI simulates "Windows 2012" (which is Windows 8)
    // Note: According to ACPI spec, _OSI("Windows") must also return true
    //  Also, it should return true for all previous versions of Windows.
    Method(XOSI, 1)
    {
        // simulation targets
        // source: (google 'Microsoft Windows _OSI')
        //  http://download.microsoft.com/download/7/E/7/7E7662CF-CBEA-470B-A97E-CE7CE0D98DC2/WinACPI_OSI.docx
        Store(Package()
        {
            "Windows",              // generic Windows query
            "Windows 2001",         // Windows XP
            "Windows 2001 SP2",     // Windows XP SP2
            //"Windows 2001.1",     // Windows Server 2003
            //"Windows 2001.1 SP1", // Windows Server 2003 SP1
            "Windows 2006",         // Windows Vista
            "Windows 2006 SP1",     // Windows Vista SP1
            //"Windows 2006.1",     // Windows Server 2008
            "Windows 2009",         // Windows 7/Windows Server 2008 R2
            "Windows 2012",         // Windows 8/Windows Sesrver 2012
            //"Windows 2013",       // Windows 8.1/Windows Server 2012 R2
            //"Windows 2015",       // Windows 10/Windows Server TP
        }, Local0)
        Return (LNotEqual(Match(Local0, MEQ, Arg0, MTR, 0, 0), Ones))
    }

//
// ACPISensors configuration (ACPISensors.kext is not installed by default)
//

    // not implemented for the Y50

//
// USB related
//

#if 0
    // In DSDT, native XSEL is renamed XXEL with Clover binpatch.
    // Calls to it will land here.
    // ... which does nothing
    External(_SB.PCI0.XHC, DeviceObj)
    Method(_SB.PCI0.XHC.XSEL)
    {
        // nothing
    }
#endif

    // Override for USBInjectAll.kext
    Device(UIAC)
    {
        Name(_HID, "UIA00000")
        Name(RMCF, Package()
        {
            // EH01 has no ports (XHCIMux is used to force USB3 routing OFF)
            "EH01", Package()
            {
                "port-count", Buffer() { 0, 0, 0, 0 },
                "ports", Package() { },
            },
            // EH02 has a single internal port (for the RM hub)
            "EH02", Package()
            {
                //"port-count", Buffer() { 0x06, 0, 0, 0 },
                "ports", Package()
                {
                    "PR21", Package()
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x01, 0, 0, 0 },
                    },
                },
            },
            // XHC overrides
            "8086_8xxx", Package()
            {
                //"port-count", Buffer() { 0x15, 0, 0, 0 },
                "ports", Package()
                {
                    "HS01", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0x01, 0, 0, 0 },
                    },
                    "HS02", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0x02, 0, 0, 0 },
                    },
                    "HS05", Package()   // touch screen
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x05, 0, 0, 0 },
                    },
                    "HS06", Package()
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x06, 0, 0, 0 },
                    },
                    "HS07", Package()
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x07, 0, 0, 0 },
                    },
                    "HS09", Package()
                    {
                        "UsbConnector", 0,
                        "port", Buffer() { 0x09, 0, 0, 0 },
                    },
                    "SS01", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0x10, 0, 0, 0 },
                    },
                    "SS02", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0x11, 0, 0, 0 },
                    },
                },
            },
        })
    }


//
// Disabling EHCI #1 (and EHCI #2)
//

    External(_SB.PCI0.EH01, DeviceObj)
    External(_SB.PCI0.EH02, DeviceObj)
    Scope(_SB.PCI0)
    {
        // registers needed for disabling EHC#1
        Scope(EH01)
        {
            OperationRegion(PSTS, PCI_Config, 0x54, 2)
            Field(PSTS, WordAcc, NoLock, Preserve)
            {
                PSTE, 2  // bits 2:0 are power state
            }
        }
        // registers needed for disabling EHC#1
        Scope(EH02)
        {
            OperationRegion(PSTS, PCI_Config, 0x54, 2)
            Field(PSTS, WordAcc, NoLock, Preserve)
            {
                PSTE, 2  // bits 2:0 are power state
            }
        }
        Scope(LPCB)
        {
            OperationRegion(RMLP, PCI_Config, 0xF0, 4)
            Field(RMLP, DWordAcc, NoLock, Preserve)
            {
                RCB1, 32, // Root Complex Base Address
            }
            // address is in bits 31:14
            OperationRegion(FDM1, SystemMemory, Add(And(RCB1,Not(Subtract(ShiftLeft(1,14),1))),0x3418), 4)
            Field(FDM1, DWordAcc, NoLock, Preserve)
            {
                ,13,    // skip first 13 bits
                FDE2,1, // should be bit 13 (0-based) (FD EHCI#2)
                ,1,
                FDE1,1, // should be bit 15 (0-based) (FD EHCI#1)
            }
        }
        Device(RMD1)
        {
            //Name(_ADR, 0)
            Name(_HID, "RMD10000")
            Method(_INI)
            {
                // disable EHCI#1
                // put EHCI#1 in D3hot (sleep mode)
                Store(3, ^^EH01.PSTE)
                // disable EHCI#1 PCI space
                Store(1, ^^LPCB.FDE1)

                // disable EHCI#2
                // put EHCI#2 in D3hot (sleep mode)
                Store(3, ^^EH02.PSTE)
                // disable EHCI#2 PCI space
                Store(1, ^^LPCB.FDE2)
            }
        }
    }


//
// Backlight control
//

    Device(PNLF)
    {
        Name(_ADR, Zero)
        Name(_HID, EisaId ("APP0002"))
        Name(_CID, "backlight")
        Name(_UID, 10)
        Name(_STA, 0x0B)
        Name(RMCF, Package()
        {
            "PWMMax", 0,
        })
        Method(_INI)
        {
            // disable discrete graphics (Nvidia) if it is present
            External(\_SB.PCI0.PEG0.PEGP._OFF, MethodObj)
            If (CondRefOf(\_SB.PCI0.PEG0.PEGP._OFF))
            {
                \_SB.PCI0.PEG0.PEGP._OFF()
            }
        }
    }

//
// Standard Injections/Fixes
//

    Scope(_SB.PCI0)
    {
        Device(IMEI)
        {
            Name (_ADR, 0x00160000)
        }

        Device(SBUS.BUS0)
        {
            Name(_CID, "smbus")
            Name(_ADR, Zero)
            Device(DVL0)
            {
                Name(_ADR, 0x57)
                Name(_CID, "diagsvault")
                Method(_DSM, 4)
                {
                    If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }
                    Return (Package() { "address", 0x57 })
                }
            }
        }
    }

//
// Keyboard/Trackpad
//

    External(_SB.PCI0.LPCB.PS2K, DeviceObj)
    Scope (_SB.PCI0.LPCB.PS2K)
    {
        // Select specific keyboard map in VoodooPS2Keyboard.kext
        Method(_DSM, 4)
        {
            If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }
            Return (Package()
            {
                "RM,oem-id", "LENOVO",
                "RM,oem-table-id", "Y50-RMCF",
            })
        }

        Name(RMCF, Package()
        {
            "Controller", Package()
            {
                "WakeDelay", 0,
            },
            "Sentelic FSP", Package()
            {
                "DisableDevice", ">y",
            },
            "ALPS GlidePoint", Package()
            {
                "DisableDevice", ">y",
            },
            "Synaptics TouchPad", Package()
            {
                "MultiFingerVerticalDivisor", 9,
                "MultiFingerHorizontalDivisor", 9,
                "MomentumScrollThreshY", 12,
            },
            "Keyboard", Package()
            {
                "Breakless PS2", Package()
                {
                    Package(){}, //indicating array
                    "e06a", //F3
                    "e06b", //F9
                    "e06c", //F10
                    "e06d", //F11
                },
                "MaximumMacroTime", 25000000,
                "Macro Inversion", Package()
                {
                    Package(){},
                    //F3
                    Buffer() { 0xff, 0xff, 0x02, 0x6a, 0x00, 0x00, 0x00, 0x00, 0x02, 0x5b, 0x01, 0x19 }, //e06a
                    Buffer() { 0xff, 0xff, 0x02, 0xea, 0x00, 0x00, 0x00, 0x00, 0x01, 0x99, 0x02, 0xdb }, //e0ea

                    //F9
                    Buffer() { 0xff, 0xff, 0x02, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x02, 0x5b, 0x01, 0x17 }, //e06b
                    Buffer() { 0xff, 0xff, 0x02, 0xeb, 0x00, 0x00, 0x00, 0x00, 0x01, 0x97, 0x02, 0xdb }, //e0eb

                    //F10
                    Buffer() { 0xff, 0xff, 0x02, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x02, 0x5b, 0x01, 0x21 }, //e06c
                    Buffer() { 0xff, 0xff, 0x02, 0xec, 0x00, 0x00, 0x00, 0x00, 0x01, 0xa1, 0x02, 0xdb }, //e0ec

                    //F11
                    Buffer() { 0xff, 0xff, 0x02, 0x6d, 0x00, 0x00, 0x00, 0x00, 0x01, 0x38, 0x01, 0x1d, 0x01, 0x0f }, //e06d
                    Buffer() { 0xff, 0xff, 0x02, 0xed, 0x00, 0x00, 0x00, 0x00, 0x01, 0xb8, 0x01, 0x9d, 0x01, 0x8f }, //e0ed
                },
                "Custom ADB Map", Package()
                {
                    Package(){},
                    "e06a=6a", //FnF3 = F16
                    "e06b=40", //FnF9 = F17
                    "e06c=4f", //FnF10 = F18
                    "e06d=50", //FnF11 = F19
                },
                "Custom PS2 Map", Package()
                {
                    Package(){},
                    "e037=64", // PrtSc=F13
                },
                "Function Keys Special", Package()
                {
                    Package(){},
                    // The following 12 items map Fn+fkeys to Fn+fkeys, Y50 and u430 differ
                    "e05f=e05f",   //F1
                    //F2 missing
                    "e06a=e06a",   //F3
                    //F4 no Fn
                    //F5 missing
                    "e073=e037",   //F6
                    //F7 no Fn
                    //F8 no Fn
                    "e06b=e06b",   //F9
                    "e06c=e06c",   //F10
                    "e06d=e06d",   //F11
                    //F12 no Fn
                    // The following 12 items map fkeys to fkeys, Y50 and u430 are the same
                    "3b=3b",
                    "3c=3c",
                    "3d=3d",
                    "3e=3e",
                    "3f=3f",
                    "40=40",
                    "41=41",
                    "42=42",
                    "43=43",
                    "44=44",
                    "57=57",
                    "58=58",
                },
                "Function Keys Standard", Package()
                {
                    Package(){},
                    // The following 12 items map Fn+fkeys to fkeys
                    "e05f=3b",   //F1
                    //F2 missing
                    "e06a=3d",   //F3
                    //F4 no Fn
                    //F5 missing
                    "e073=40",   //F6
                    //F7 no Fn
                    //F8 no Fn
                    "e06b=43",   //F9, F10 complex
                    "e06c=44",   //F10 macro
                    "e06d=57",   //F11 macro
                    //F12 no Fn
                    // The following 12 items map fkeys to Fn+fkeys
                    "3b=e05f",   //F1
                    //F2 missing
                    "3d=e06a",   //F3
                    //F4 no Fn
                    //F5 missing
                    "40=e037",   //F6
                    //F7 no Fn
                    //F8 no Fn
                    "43=e06b",   //F9, F10 complex
                    "44=e06c",   //F10 macro
                    "57=e06d",   //F11 macro
                    //F12 no Fn
                },
            },
        })
    }

    External(_SB.PCI0.LPCB.EC0, DeviceObj)
    External(TPDF, FieldUnitObj)

    Scope(_SB.PCI0.LPCB.EC0)
    {
        // The native _Qxx methods in DSDT are renamed XQxx,
        // so notifications from the EC driver will land here.

        // _Q11 called on brightness down key
        Method(_Q11)
        {
            // Brightness Down
            If (LNotEqual(TPDF,0x08))
            {
                // Synaptics/ALPS
                Notify(\_SB.PCI0.LPCB.PS2K, 0x0405)
            }
            Else
            {
                // Other(ELAN)
                Notify(\_SB.PCI0.LPCB.PS2K, 0x20)
            }
        }
        //_Q12 called on brightness up key
        Method(_Q12)
        {
            // Brightness Up
            If (LNotEqual(TPDF,0x08))
            {
                // Synaptics/ALPS
                Notify(\_SB.PCI0.LPCB.PS2K, 0x0406)
            }
            Else
            {
                // Other(ELAN)
                Notify(\_SB.PCI0.LPCB.PS2K, 0x10)
            }
        }
    }

//
// Battery Status
//

    // Override for ACPIBatteryManager.kext
    External(_SB.PCI0.LPCB.BAT1, DeviceObj)
    Name(_SB.PCI0.LPCB.BAT1.RMCF, Package()
    {
        "StartupDelay", 10,
    })

    Scope(_SB.PCI0.LPCB.EC0)
    {
        // This is an override for battery methods that access EC fields
        // larger than 8-bit.
        
        External(ERBD, FieldUnitObj)

        OperationRegion (RMEC, EmbeddedControl, 0x5D, 2)
        Field (RMEC, ByteAcc, Lock, Preserve)
        {
            ERI0,8,ERI1,8, 
        }
        
        External(FAMX, MutexObj)
        
        // FANG and FANW are renamed to XANG and XANW
        // calls to them will land here
        Method (FANG, 1, NotSerialized)
        {
            Acquire (FAMX, 0xFFFF)
            Store(Arg0, ERI0) Store(ShiftRight(Arg0, 8), ERI1)
            Store (ERBD, Local0)
            Release (FAMX)
            Return (Local0)
        }

        Method (FANW, 2, NotSerialized)
        {
            Acquire (FAMX, 0xFFFF)
            Store(Arg0, ERI0) Store(ShiftRight(Arg0, 8), ERI1)
            Store (Arg1, ERBD)
            Release (FAMX)
            Return (Arg1)
        }
                    
        Method (\B1B2, 2, NotSerialized) { Return (Or (Arg0, ShiftLeft (Arg1, 8))) }
        
        Method (WE1B, 2, Serialized)
        {
            OperationRegion(ERAM, EmbeddedControl, Arg0, 1)
            Field(ERAM, ByteAcc, NoLock, Preserve) { BYTE, 8 }
            Store(Arg1, BYTE)
        }
        Method (WECB, 3, Serialized)
        // Arg0 - offset in bytes from zero-based EC
        // Arg1 - size of buffer in bits
        // Arg2 - value to write
        {
            ShiftRight(Arg1, 3, Arg1)
            Name(TEMP, Buffer(Arg1) { })
            Store(Arg2, TEMP)
            Add(Arg0, Arg1, Arg1)
            Store(0, Local0)
            While (LLess(Arg0, Arg1))
            {
                WE1B(Arg0, DerefOf(Index(TEMP, Local0)))
                Increment(Arg0)
                Increment(Local0)
            }
        }
        Method (RE1B, 1, Serialized)
        {
            OperationRegion(ERAM, EmbeddedControl, Arg0, 1)
            Field(ERAM, ByteAcc, NoLock, Preserve) { BYTE, 8 }
            Return(BYTE)
        }
        Method (RECB, 2, Serialized)
        // Arg0 - offset in bytes from zero-based EC
        // Arg1 - size of buffer in bits
        {
            ShiftRight(Arg1, 3, Arg1)
            Name(TEMP, Buffer(Arg1) { })
            Add(Arg0, Arg1, Arg1)
            Store(0, Local0)
            While (LLess(Arg0, Arg1))
            {
                Store(RE1B(Arg0), Index(TEMP, Local0))
                Increment(Arg0)
                Increment(Local0)
            }
            Return(TEMP)
        }

        External(CTSL, PkgObj)
        External(CFMX, MutexObj)
        External(\SMID, FieldUnitObj)
        External(\SMIC, FieldUnitObj)
        External(\SFNO, FieldUnitObj)
        External(\BFDT, FieldUnitObj)
        External(\CAVR, FieldUnitObj)
        External(\STDT, FieldUnitObj)
       
        External(SMAD, FieldUnitObj)
        External(SMCM, FieldUnitObj)
        External(SMPR, FieldUnitObj)
        External(SMST, FieldUnitObj)

        External(\P80H, FieldUnitObj)
        External(BCNT, FieldUnitObj)

        // CFUN is renamed XFUN
        // calls to it will land here

        Method (CFUN, 4, Serialized)
        {
            Store(Arg3, Local0) //REVIEW: just to remove the warning (Arg3 is not used)

            Name (ESRC, 0x05)
            If (LNotEqual (Match (CTSL, MEQ, DerefOf (Index (Arg0, Zero)), MTR, 
                Zero, Zero), Ones))
            {
                Acquire (CFMX, 0xFFFF)
                Store (Arg0, SMID)
                Store (Arg1, SFNO)
                Store (Arg2, BFDT)
                Store (0xCE, SMIC)
                Release (CFMX)
            }
            Else
            {
                If (LEqual (DerefOf (Index (Arg0, Zero)), 0x10))
                {
                    If (LEqual (DerefOf (Index (Arg1, Zero)), One))
                    {
                        CreateByteField (Arg2, Zero, CAPV)
                        Store (CAPV, CAVR)
                        Store (One, STDT)
                    }
                    Else
                    {
                        If (LEqual (DerefOf (Index (Arg1, Zero)), 0x02))
                        {
                            Store (Buffer (0x80) {}, Local0)
                            CreateByteField (Local0, Zero, BFD0)
                            Store (0x11, BFD0)
                            Store (One, STDT)
                            Store (Local0, BFDT)
                        }
                        Else
                        {
                            Store (Zero, STDT)
                        }
                    }
                }
                Else
                {
                    If (LEqual (DerefOf (Index (Arg0, Zero)), 0x18))
                    {
                        Acquire (CFMX, 0xFFFF)
                        If (LEqual (DerefOf (Index (Arg1, Zero)), 0x02))
                        {
                            WECB(0x64,256,Zero)
                            Store (DerefOf (Index (Arg2, One)), SMAD)
                            Store (DerefOf (Index (Arg2, 0x02)), SMCM)
                            Store (DerefOf (Index (Arg2, Zero)), SMPR)
                            While (LAnd (Not (LEqual (ESRC, Zero)), Not (LEqual (And (SMST, 0x80), 0x80))))
                            {
                                Sleep (0x14)
                                Subtract (ESRC, One, ESRC)
                            }

                            Store (SMST, Local2)
                            If (LEqual (And (Local2, 0x80), 0x80))
                            {
                                Store (Buffer (0x80) {}, Local1)
                                Store (Local2, Index (Local1, Zero))
                                If (LEqual (Local2, 0x80))
                                {
                                    Store (0xC4, P80H)
                                    Store (BCNT, Index (Local1, One))
                                    Store (RECB(0x64,256), Local3)
                                    Store (DerefOf (Index (Local3, Zero)), Index (Local1, 0x02))
                                    Store (DerefOf (Index (Local3, One)), Index (Local1, 0x03))
                                    Store (DerefOf (Index (Local3, 0x02)), Index (Local1, 0x04))
                                    Store (DerefOf (Index (Local3, 0x03)), Index (Local1, 0x05))
                                    Store (DerefOf (Index (Local3, 0x04)), Index (Local1, 0x06))
                                    Store (DerefOf (Index (Local3, 0x05)), Index (Local1, 0x07))
                                    Store (DerefOf (Index (Local3, 0x06)), Index (Local1, 0x08))
                                    Store (DerefOf (Index (Local3, 0x07)), Index (Local1, 0x09))
                                    Store (DerefOf (Index (Local3, 0x08)), Index (Local1, 0x0A))
                                    Store (DerefOf (Index (Local3, 0x09)), Index (Local1, 0x0B))
                                    Store (DerefOf (Index (Local3, 0x0A)), Index (Local1, 0x0C))
                                    Store (DerefOf (Index (Local3, 0x0B)), Index (Local1, 0x0D))
                                    Store (DerefOf (Index (Local3, 0x0C)), Index (Local1, 0x0E))
                                    Store (DerefOf (Index (Local3, 0x0D)), Index (Local1, 0x0F))
                                    Store (DerefOf (Index (Local3, 0x0E)), Index (Local1, 0x10))
                                    Store (DerefOf (Index (Local3, 0x0F)), Index (Local1, 0x11))
                                    Store (DerefOf (Index (Local3, 0x10)), Index (Local1, 0x12))
                                    Store (DerefOf (Index (Local3, 0x11)), Index (Local1, 0x13))
                                    Store (DerefOf (Index (Local3, 0x12)), Index (Local1, 0x14))
                                    Store (DerefOf (Index (Local3, 0x13)), Index (Local1, 0x15))
                                    Store (DerefOf (Index (Local3, 0x14)), Index (Local1, 0x16))
                                    Store (DerefOf (Index (Local3, 0x15)), Index (Local1, 0x17))
                                    Store (DerefOf (Index (Local3, 0x16)), Index (Local1, 0x18))
                                    Store (DerefOf (Index (Local3, 0x17)), Index (Local1, 0x19))
                                    Store (DerefOf (Index (Local3, 0x18)), Index (Local1, 0x1A))
                                    Store (DerefOf (Index (Local3, 0x19)), Index (Local1, 0x1B))
                                    Store (DerefOf (Index (Local3, 0x1A)), Index (Local1, 0x1C))
                                    Store (DerefOf (Index (Local3, 0x1B)), Index (Local1, 0x1D))
                                    Store (DerefOf (Index (Local3, 0x1C)), Index (Local1, 0x1E))
                                    Store (DerefOf (Index (Local3, 0x1D)), Index (Local1, 0x1F))
                                    Store (DerefOf (Index (Local3, 0x1E)), Index (Local1, 0x20))
                                    Store (DerefOf (Index (Local3, 0x1F)), Index (Local1, 0x21))
                                }

                                Store (Local1, BFDT)
                                Store (One, STDT)
                            }
                            Else
                            {
                                Store (0xC5, P80H)
                                Store (Zero, STDT)
                            }
                        }
                        Else
                        {
                            Store (0xC6, P80H)
                            Store (Zero, STDT)
                        }

                        Release (CFMX)
                    }
                    Else
                    {
                        Store (Zero, STDT)
                    }
                }
            }
        }
    }
}

