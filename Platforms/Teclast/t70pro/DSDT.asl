// SPDX-License-Identifier: BSD-2-Clause-Patent
DefinitionBlock ("", "DSDT", 2, "TECLST", "T70PRO  ", 1)
{
    Scope (\_SB)
    {
        // Firmware/driver contract. BootShim clears this area on every entry.
        // T70I2cPlatformDxe validates inherited clocks, pins and idle DMA, then
        // publishes readiness at ExitBootServices. Only validated inherited
        // resources are exposed; inclusion in the FV alone never sets readiness.
        OperationRegion (I2HO, SystemMemory, 0x43F7F080, 0x10)
        Field (I2HO, DWordAcc, NoLock, Preserve)
        {
            IRAD, 32,
            ICL0, 32,
            ICL6, 32,
            IREV, 32
        }

        // Read-only retained-I2C validation. No clock/PLL/pin restoration is
        // attempted here. Addresses and polarities match the MT6789 clock and
        // I2C board providers; neither IRAD nor ICL0/6 proves runtime retention.
        OperationRegion (ITOP, SystemMemory, 0x10000000, 0x100)
        Field (ITOP, DWordAcc, NoLock, Preserve)
        { Offset (0x10), IAXI, 32, Offset (0xA0), MUMX, 32,
          Offset (0xA8), MUTC, 32, Offset (0xB0), IMUX, 32 }
        OperationRegion (IINF, SystemMemory, 0x10001090, 0x4C)
        Field (IINF, DWordAcc, NoLock, Preserve)
        { IFG0, 32, Offset (0x18), MUGC, 32, MUGT, 32, Offset (0x48), IFG2, 32 }
        OperationRegion (IPLL, SystemMemory, 0x1000C308, 0x48)
        Field (IPLL, DWordAcc, NoLock, Preserve)
        {
            UPC0, 32, UPC1, 32, Offset (0x0C), UPWR, 32,
            Offset (0x38), MPC0, 32, MPC1, 32,
            Offset (0x44), MPWR, 32
        }
        OperationRegion (IWST, SystemMemory, 0x11E02E00, 4)
        Field (IWST, DWordAcc, NoLock, Preserve) { IWG0, 32 }
        OperationRegion (ICST, SystemMemory, 0x1101BE00, 4)
        Field (ICST, DWordAcc, NoLock, Preserve) { IWG6, 32 }
        OperationRegion (IPIO, SystemMemory, 0x10005240, 0x1D4)
        Field (IPIO, DWordAcc, NoLock, Preserve)
        { IPIN, 32, Offset (0x1C0), IPM0, 32, Offset (0x1D0), IPM6, 32 }
        OperationRegion (ICS0, SystemMemory, 0x11E00024, 2)
        Field (ICS0, WordAcc, NoLock, Preserve) { IST0, 16 }
        OperationRegion (ICS6, SystemMemory, 0x1101A024, 2)
        Field (ICS6, WordAcc, NoLock, Preserve) { IST6, 16 }
        OperationRegion (IDS0, SystemMemory, 0x10217088, 4)
        Field (IDS0, DWordAcc, NoLock, Preserve) { IDM0, 32 }
        OperationRegion (IDS6, SystemMemory, 0x10217488, 4)
        Field (IDS6, DWordAcc, NoLock, Preserve) { IDM6, 32 }

        // Same 26MHz/22-bit PCW and post-divider arithmetic as ClockDxe.
        Method (IPLF, 1, NotSerialized)
        {
            If (Arg0) { Store (UPC0, Local0) Store (UPC1, Local1) Store (UPWR, Local2) }
            Else { Store (MPC0, Local0) Store (MPC1, Local1) Store (MPWR, Local2) }
            // Enabled, reset released, all divider outputs enabled, no isolation.
            If (LOr (LNotEqual (And (Local0, 0xFF800001), 0xFF800001),
                LNotEqual (And (Local2, 3), One))) { Return (Zero) }
            Store (ShiftRight (Multiply (And (Local1, 0x3FFFFF), 26000000), 14), Local3)
            If (LOr (LLess (Local3, 1500000000), LGreater (Local3, 3800000000))) { Return (Zero) }
            Store (ShiftLeft (One, And (ShiftRight (Local1, 24), 7)), Local4)
            Divide (Add (Local3, Subtract (Local4, One)), Local4, , Local3)
            Divide (Add (Local3, 50000), 100000, , Local3)
            Multiply (Local3, 100000, Local3)
            If (Arg0)
            {
                If (LOr (LNotEqual (UPC0, Local0), LOr (LNotEqual (UPC1, Local1),
                    LNotEqual (UPWR, Local2)))) { Return (Zero) }
            }
            Else
            {
                If (LOr (LNotEqual (MPC0, Local0), LOr (LNotEqual (MPC1, Local1),
                    LNotEqual (MPWR, Local2)))) { Return (Zero) }
            }
            Return (Local3)
        }
        Method (ICFR, 0, NotSerialized)
        {
            Store (IAXI, Local0) Store (IMUX, Local1)
            // AXI selectors 1..5 use MAINPLL. OSC_D4 is not qualified here.
            If (LGreater (And (Local0, 7), 5)) { Return (Zero) }
            If (And (Local0, 7)) { If (LEqual (IPLF (Zero), Zero)) { Return (Zero) } }
            If (LOr (And (Local1, 0x8000), LOr (And (IFG0, 0x1800),
                And (IFG2, 0x80000000)))) { Return (Zero) }
            Store (And (ShiftRight (Local1, 8), 3), Local2)
            If (LEqual (Local2, Zero)) { Store (26000000, Local3) }
            ElseIf (LEqual (Local2, One)) { Divide (IPLF (Zero), 32, , Local3) }
            ElseIf (LEqual (Local2, 2)) { Divide (IPLF (One), 20, , Local3) }
            Else { Return (Zero) }
            If (LOr (LNotEqual (IAXI, Local0), LNotEqual (IMUX, Local1))) { Return (Zero) }
            If (LOr (LLess (Local3, 1000000), LGreater (Local3, 1000000000))) { Return (Zero) }
            Return (Local3)
        }
        Method (ILCK, 1, Serialized)
        {
            If (LGreater (Arg0, One)) { Return (Zero) }
            Store (ICFR (), Local0)
            If (LEqual (Local0, Zero)) { Return (Zero) }
            Store (Zero, Local1)
            While (LLess (Local1, 2))
            {
                // Check every upstream/endpoint clock before controller MMIO.
                If (LNotEqual (ICFR (), Local0)) { Return (Zero) }
                If (Arg0)
                {
                    If (LOr (And (IWG6, 4), LOr (LNotEqual (And (IPM6, 0xFF000000), 0x11000000),
                        LNotEqual (And (IPIN, 0xC000), 0xC000)))) { Return (Zero) }
                    If (LOr (And (IST6, One), And (IDM6, One))) { Return (Zero) }
                }
                Else
                {
                    If (LOr (And (IWG0, One), LOr (LNotEqual (And (IPM0, 0xFF00), 0x1100),
                        LNotEqual (And (IPIN, 0x0C), 0x0C)))) { Return (Zero) }
                    If (LOr (And (IST0, One), And (IDM0, One))) { Return (Zero) }
                }
                Increment (Local1)
                If (LLess (Local1, 2)) { Stall (10) }
            }
            If (LNotEqual (ICFR (), Local0)) { Return (Zero) }
            Return (Local0)
        }

        // Initial-D0 GPIO handoff, published only after board validation.
        OperationRegion (GPHO, SystemMemory, 0x43F7F090, 0x10)
        Field (GPHO, DWordAcc, NoLock, Preserve)
        {
            GRAD, 32,
            GPIN, 32,
            GIRQ, 32,
            GREV, 32
        }
        // A valid post-start report is required; BootShim clears stale state.
        OperationRegion (HXHO, SystemMemory, 0x43F7F0A0, 0x10)
        Field (HXHO, DWordAcc, NoLock, Preserve)
        {
            HRAD, 32,
            HADR, 32,
            HIRQ, 32,
            HREV, 32
        }
        OperationRegion (UFHO, SystemMemory, 0x43F7F0B0, 0x10)
        Field (UFHO, DWordAcc, NoLock, Preserve)
        {
            URAD, 32,
            UBAR, 32,
            ULUN, 32,
            UREV, 32
        }
        // GOP only publishes a validated, reserved, still-owned inherited scanout.
        OperationRegion (DFHO, SystemMemory, 0x43F7F0C0, 0x30)
        Field (DFHO, DWordAcc, NoLock, Preserve)
        {
            DRAD, 32, DREV, 32,
            DBLO, 32, DBHI, 32, DSLO, 32, DSHI, 32,
            DWID, 32, DHEI, 32, DPIT, 32, DFMT, 32,
            DRL0, 32, DRL1, 32
        }

        // MH248 provenance and inherited GPIO0 input, published by GpioPlatformDxe.
        OperationRegion (HLHO, SystemMemory, 0x43F7F0F0, 0x10)
        Field (HLHO, DWordAcc, NoLock, Preserve)
        { LRAD, 32, LPIN, 32, LFAR, 32, LREV, 32 }

        // USBPLL CON0 and power/enable. The MT6789 clock driver places the
        // USB output gate in PWR (bit 2); CON0 bit 0 belongs to the PCW.
        OperationRegion (MUPL, SystemMemory, 0x1000C3C4, 0x0C)
        Field (MUPL, DWordAcc, NoLock, Preserve)
        { MUPC, 32, MUPD, 32, MUPW, 32 }

        // MUSB boot ownership, published after the firmware host has stopped.
        OperationRegion (MHHO, SystemMemory, 0x43F7F100, 0x40)
        Field (MHHO, DWordAcc, NoLock, Preserve)
        {
            MRAD, 32, MREV, 32, MFLG, 32, MBAR, 32,
            MLEN, 32, MPHY, 32, MPLN, 32, MIRQ, 32,
            MEPS, 32, MPRT, 32, MFIF, 32, MEVT, 32,
            MPST, 32, MPCH, 32, MPSV, 32, MHPW, 32 // 0 legacy, 1 Type-C source, 2 ID-low hub, 3 Type-C-only
        }
        // Non-GPIO button state injection is supported by the Windows inbox
        // button driver. The actual KPD/PMIC provider is a separate device;
        // never fabricate one GPIO interrupt per physical button.
        // https://learn.microsoft.com/windows-hardware/drivers/gpiobtn/button-implementation
        Device (BTN0)
        {
            Name (_HID, "HANA6791")
            Name (_CID, "PNP0C40")
            Name (_UID, Zero)
            Name (_STA, 0x0F)
        }

        Device (KPD0)
        {
            Name (_HID, "HANA6790")
            Name (_UID, Zero)
            Name (_STA, 0x0F)
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadOnly, 0x10010000, 0x1000)
                // Stock kp@10010000: GIC SPI106, rising edge (GSIV138).
                // One controller IRQ; this does not create per-button GPIOs.
                Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive) { 138 }
            })
            // TOPSTATUS is read through the shared PMIC PRM broker, not a
            // second PWRAP mapping. PMIC power-key IRQ/wake is a separate path.
            // Ordinary KPD IRQ assignment does not assert retained sleep power
            // or system wake; no wake flag or _PRW is fabricated here.
        }

        // Render-only Mali-G57 JM device. Presence is not a power handoff:
        // no AML MMIO or assumed firmware ownership. Before touching GPU MMIO,
        // the Windows miniport needs the same-PDO qualified board lease, shared
        // PMIC/SPM/clock owner, IRQ association and cache/address proofs.
        // Stock DT lists five IRQs; the stock JM probe requests GPU/MMU/JOB.
        // EVENT/PWR belong to other paths and are not allocated to this driver.
        // One Windows owner for SPM/clock regions; PMIC uses the shared PRM
        // executor, with no second OS PWRAP mapping or raw WACS2 path.
        // Presence and resource assignment never approve firmware exclusion,
        // direct GPU DMA, adjusted OPP, thermal or battery operating limits.
        Device (MFG0)
        {
            Name (_HID, "HANA678F")
            Name (_UID, Zero)
            Name (_STA, 0x0F)
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x10006000, 0x1000) // SPM
                Memory32Fixed (ReadWrite, 0x10001000, 0x1000) // INFRACFG_AO
                Memory32Fixed (ReadWrite, 0x13FBF000, 0x1000) // MFG_TOP
                Memory32Fixed (ReadWrite, 0x10000000, 0x1000) // TOPCKGEN
                Memory32Fixed (ReadWrite, 0x1000C000, 0x1000) // APMIXED
            })
        }

        Device (GPU0)
        {
            Name (_HID, "HANA678E")
            Name (_DEP, Package () { \_SB.MFG0 })
            Name (_UID, Zero)
            Name (_STA, 0x0F)
            Name (_CCA, Zero)
            Name (_CLS, Package () { 0x03, 0x02, 0x00 })
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x13000000, 0x4000)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 428 } // GPU
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 429 } // MMU
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 430 } // JOB
            })
        }

        Device (USB0)
        {
            Name (_HID, "HANA678D")
            Name (_UID, Zero)
            Name (_CCA, Zero)
            // Custom UCX USB2 controller, rather than an xHCI-compatible device.
            Name (_CLS, Package () { 0x0C, 0x03, 0x00 })
            // Mux selector and the exact shared parent PCW/post-divider.
            // The one-based encoding reserves zero for an unstable sample.
            Method (MREF, 0, NotSerialized)
            {
                Store (And (MUMX, 0x03000000), Local0)
                Store (ShiftRight (Local0, 24), Local2)
                Store (Zero, Local3)
                If (Local2)
                {
                    Store (And (UPC1, 0x073FFFFF), Local4)
                    If (LNot (IPLF (One))) { Return (Zero) }
                    // The supported VCO range fits in 21 bits after removing
                    // 0x80000 from the PCW. Keep all three post-divider bits.
                    Store (Subtract (And (Local4, 0x3FFFFF), 0x80000), Local5)
                    If (LGreater (Local5, 0x1FFFFF)) { Return (Zero) }
                    Store (Or (Local5, ShiftRight (And (Local4, 0x07000000), 3)), Local3)
                    If (LNotEqual (And (UPC1, 0x073FFFFF), Local4)) { Return (Zero) }
                }
                If (LNotEqual (And (MUMX, 0x03000000), Local0)) { Return (Zero) }
                Return (Add (Or (ShiftLeft (Local3, 8), Local2), One))
            }

            // 24 bits of parent rate, 6 bits of USBPLL PCW and 2 bits of
            // selector. The identity survives loss of USBPLL power.
            Method (MCID, 0, NotSerialized)
            {
                Store (And (MUPC, 0x073FFFFF), Local0)
                // USBPLL PCWs that round to the observed 2496 MHz.
                If (LOr (LLess (Local0, 0x17FFE1), LGreaterEqual (Local0, 0x180020))) { Return (Zero) }
                Store (MREF (), Local1)
                If (LOr (LNot (Local1), LNotEqual (And (MUPC, 0x073FFFFF), Local0))) { Return (Zero) }
                Return (Add (Local1, ShiftLeft (Subtract (Local0, 0x17FFE1), 2)))
            }

            Method (MCON, 0, NotSerialized)
            {
                // USBPLL's stock HAVE_RST_BAR flag makes CON0 bit 23
                // part of the live-clock proof.
                Return (LAnd (LEqual (And (MUPW, 7), 5),
                    LAnd (And (MUPC, 0x00800000),
                        LNot (LOr (And (MUMX, 0x80000000), And (MUGT, 2))))))
            }

            Method (MCLK, 0, Serialized)
            {
                If (LNot (MCON ())) { Return (Zero) }
                Store (MCID (), Local0)
                If (LNot (MCON ())) { Return (Zero) }
                Return (Local0)
            }

            Method (MPCK, 2, NotSerialized)
            {
                Return (LAnd (LEqual (MCID (), Arg0), LEqual (And (MUPW, 7), Arg1)))
            }

            Method (MISO, 0, NotSerialized)
            {
                Return (LAnd (LEqual (And (MUPW, 7), 2),
                    LAnd (And (MUMX, 0x80000000), And (MUGT, 2))))
            }

            // clk-common.ko mtk_pll_set_rate with the stock USBPLL
            // descriptor: CON0 PCW/post-divider, CON1 PCW_CHG, 20 us delay.
            // Only a blank dedicated PLL with its outputs isolated and both
            // USB gates closed may inherit the previous D0 rate.
            Method (MPRG, 1, NotSerialized)
            {
                Store (And (Subtract (Arg0, One), 0xFC), Local0)
                If (LEqual (Local0, 0xFC)) { Return (Zero) }
                Store (MREF (), Local1)
                If (LOr (LNot (Local1), LNotEqual (Local1, Subtract (Arg0, Local0)))) { Return (Zero) }
                Store (MUPC, Local2)
                If (LOr (And (Local2, 0x07BFFFFF), LNot (MISO ()))) { Return (Zero) }
                If (LNotEqual (MUPC, Local2)) { Return (Zero) }
                Store (Or (Local2, Add (0x17FFE1, ShiftRight (Local0, 2))), MUPC)
                If (LOr (LNot (MPCK (Arg0, 2)), LNot (MISO ()))) { Return (Zero) }
                Store (Or (MUPD, 0x80000000), MUPD)
                Stall (20)
                Return (LAnd (MPCK (Arg0, 2), MISO ()))
            }

            // clk-common.ko mtk_pll_prepare and CLK_CFG_9_CLR. MPRG can
            // restore a blank USBPLL. The shared UNIVPLL and selector are read-only.
            Method (MGON, 1, Serialized)
            {
                If (LOr (LEqual (Arg0, Zero), LGreater (Arg0, 0xFFFFFFFF))) { Return (Zero) }
                If (LNotEqual (MCID (), Arg0))
                {
                    If (LNot (MPRG (Arg0))) { Return (Zero) }
                }
                Store (MUPW, Local0)
                If (LNotEqual (And (Local0, 7), 5))
                {
                    // Begin in the fully isolated stock off state.
                    If (LOr (LNotEqual (And (Local0, 7), 2), And (MUPC, 0x00800000))) { Return (Zero) }
                    Store (Or (Local0, One), MUPW)
                    Stall (One)
                    If (LNot (MPCK (Arg0, 3))) { Return (Zero) }
                    Store (And (MUPW, 0xFFFFFFFD), MUPW)
                    Stall (One)
                    If (LNot (MPCK (Arg0, One))) { Return (Zero) }
                    Store (Or (MUPW, 4), MUPW)
                    Stall (20)
                    If (LNot (MPCK (Arg0, 5))) { Return (Zero) }
                    Store (Or (MUPC, 0x00800000), MUPC)
                    If (LNot (And (MUPC, 0x00800000))) { Return (Zero) }
                }

                If (LOr (LNot (MPCK (Arg0, 5)), LNot (And (MUPC, 0x00800000)))) { Return (Zero) }
                If (And (MUMX, 0x80000000)) { Store (0x80000000, MUTC) }
                If (And (MUMX, 0x80000000)) { Return (Zero) }
                If (LOr (LNot (MPCK (Arg0, 5)), LNot (And (MUPC, 0x00800000)))) { Return (Zero) }
                If (And (MUGT, 2)) { Store (2, MUGC) }
                Store (MCLK (), Local0)
                If (LNotEqual (Local0, Arg0)) { Return (Zero) }
                Return (Local0)
            }

            Method (MHRD, 0, Serialized)
            {
                If (LAnd (LEqual (MRAD, One),
                    LOr (
                        LAnd (LEqual (MREV, One),
                            LAnd (LEqual (MFLG, 0x7F), LEqual (MHPW, Zero))),
                        LAnd (LEqual (MREV, 2),
                            LOr (
                                LAnd (LEqual (MFLG, 0x7F),
                                    LOr (LEqual (MHPW, One), LEqual (MHPW, 3))),
                                LAnd (LEqual (MFLG, 0xEF), LEqual (MHPW, 2))
                            )
                        )
                    )
                ))
                {
                    If (LAnd (LEqual (MBAR, 0x11200000), LAnd (LEqual (MLEN, 0x10000),
                        LAnd (LEqual (MPHY, 0x11F40000), LEqual (MPLN, 0x10000)))))
                    {
                        If (LAnd (LEqual (MIRQ, 160), LAnd (LEqual (MEPS, 16),
                            LAnd (LEqual (MPRT, One), LAnd (LEqual (MFIF, One), LEqual (MEVT, 0x30))))))
                        {
                            If (LAnd (LEqual (MPSV, One),
                                LAnd (LEqual (And (MPST, 0xFFFFF8FC), Zero),
                                LAnd (And (MPST, 0x100), LLessEqual (MPCH, 0x1F)))))
                            {
                                If (LNotEqual (And (MPST, 0x600), 0x600))
                                {
                                    If (LOr (And (MPST, One), LEqual (MPST, 0x100)))
                                    {
                                        If (LEqual (MRAD, One)) { Return (One) }
                                    }
                                }
                            }
                        }
                    }
                }
                Return (Zero)
            }
            Method (_STA, 0, NotSerialized)
            {
                If (MHRD ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11200000, 0x10000)
                Memory32Fixed (ReadOnly, 0x43F7F100, 0x40)
                // T70 USB2 PHY, used to verify the live host data path.
                // Stock generic TPHY child owns 0x700 bytes at this base.
                Memory32Fixed (ReadWrite, 0x11F40000, 0x700)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 160 }
            })
        }

        Device (DISP)
        {
            Name (_HID, "HANA678C")
            Name (_UID, Zero)
            Name (_CLS, Package () { 3, 0, 0 })
            Name (_CCA, Zero)
            Method (DRDY, 0, NotSerialized)
            {
                If (LAnd (LEqual (DRAD, One), LAnd (LEqual (DREV, One),
                    LAnd (LEqual (DFMT, One), LAnd (LEqual (DRL0, Zero), LEqual (DRL1, Zero))))))
                {
                    If (LAnd (LGreater (DWID, Zero), LAnd (LLessEqual (DWID, 4096),
                        LAnd (LGreater (DHEI, Zero), LLessEqual (DHEI, 4096)))))
                    {
                        If (LAnd (LGreaterEqual (DPIT, Multiply (DWID, 4)),
                            LAnd (LLessEqual (DPIT, 65536), LEqual (And (DPIT, 3), Zero))))
                        {
                            If (LAnd (LEqual (DSHI, Zero), LAnd (LLessEqual (DSLO, 0x04000000),
                                LGreaterEqual (DSLO, Multiply (DPIT, DHEI)))))
                            {
                                If (LAnd (LLess (DBHI, 16), LEqual (And (DBLO, 0xFFF), Zero)))
                                {
                                    If (LOr (LGreater (DBHI, Zero), LGreaterEqual (DBLO, 0x40000000)))
                                    {
                                        If (LLessEqual (Add (Add (ShiftLeft (DBHI, 32), DBLO), DSLO), 0x1000000000))
                                        { Return (One) }
                                    }
                                }
                            }
                        }
                    }
                }
                Return (Zero)
            }
            Method (_STA, 0, NotSerialized)
            {
                If (DRDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (INFO, Buffer (0x30) {})
            CreateDWordField (INFO, 0, RRDY)
            CreateDWordField (INFO, 4, RREV)
            CreateDWordField (INFO, 8, RBLO)
            CreateDWordField (INFO, 12, RBHI)
            CreateDWordField (INFO, 16, RSLO)
            CreateDWordField (INFO, 20, RSHI)
            CreateDWordField (INFO, 24, RWID)
            CreateDWordField (INFO, 28, RHEI)
            CreateDWordField (INFO, 32, RPIT)
            CreateDWordField (INFO, 36, RFMT)
            Method (DFBI, 0, Serialized)
            {
                Store (DRDY (), RRDY)
                Store (DREV, RREV)
                Store (DBLO, RBLO) Store (DBHI, RBHI)
                Store (DSLO, RSLO) Store (DSHI, RSHI)
                Store (DWID, RWID) Store (DHEI, RHEI)
                Store (DPIT, RPIT) Store (DFMT, RFMT)
                Return (INFO)
            }
            Name (_CRS, ResourceTemplate ()
            { Memory32Fixed (ReadOnly, 0x43F7F0C0, 0x30) })
        }

        Device (UFS0)
        {
            Name (_HID, "HANA678B")
            Name (_UID, Zero)
            Name (_CCA, Zero)
            Method (URDY, 0, NotSerialized)
            {
                If (LAnd (LEqual (UREV, One), LAnd (LEqual (URAD, One),
                    LAnd (LEqual (UBAR, 0x11270000), LEqual (ULUN, 2)))))
                { Return (One) }
                Return (Zero)
            }
            Method (_STA, 0, NotSerialized)
            {
                If (URDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11270000, 0x2300)
                Memory32Fixed (ReadOnly, 0x43F7F0B0, 0x10)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 169 }
            })
        }

        // Stock /soc/mmc@11240000: MSDC1 is a custom host, not SDHCI.
        // _STA describes the fixed controller, independently of card presence.
        // The OS host driver must own card events, clocks and VMCH/VMC power;
        // this namespace does not claim that such a Windows driver is installed.
        Device (SDC1)
        {
            Name (_HID, "HANA6792")
            Name (_UID, One)
            Name (_CCA, Zero)
            Name (_RMV, Zero)
            Name (_DEP, Package () { GPO0 })
            Method (_STA, 0, NotSerialized)
            {
                If (\_SB.GPO0.GRDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11240000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11EF0000, 0x1000)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 167 }
                GpioIo (Exclusive, PullDefault, 0, 0, IoRestrictionInputOnly,
                    "\\_SB.GPO0", 0, ResourceConsumer, , ) { 7 }
            })
            Name (_DSD, Package ()
            {
                ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package ()
                {
                    Package () { "bus-width", 4 },
                    Package () { "max-frequency", 200000000 },
                    Package () { "cd-gpios", Package () { SDC1, Zero, Zero, Zero } }
                }
            })
        }

        Device (HXT0)
        {
            Name (_HID, "HANA8313")
            Name (_UID, Zero)
            Name (_DEP, Package () { \_SB.I2T0, \_SB.GPO0 })
            Method (HMXR, 0, NotSerialized)
            {
                If (LAnd (\_SB.I2T0.IRDY (), \_SB.GPO0.GRDY ()))
                {
                    If (LAnd (LEqual (HREV, One), LAnd (LEqual (HRAD, One),
                        LAnd (LEqual (HADR, 0x48), LEqual (HIRQ, 9)))))
                    { Return (One) }
                }
                Return (Zero)
            }
            Method (_STA, 0, NotSerialized)
            {
                If (HMXR ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                I2cSerialBusV2 (0x48, ControllerInitiated, 400000,
                    AddressingMode7Bit, "\\_SB.I2T0", 0, ResourceConsumer, , Exclusive)
                GpioInt (Edge, ActiveLow, Exclusive, PullDefault, 0,
                    "\\_SB.GPO0", 0, ResourceConsumer, , ) { 9 }
            })
        }

        Device (GPO0)
        {
            Name (_HID, "HANA678A")
            Name (_UID, Zero)
            Method (GRDY, 0, NotSerialized)
            {
                If (LAnd (LEqual (GREV, One), LAnd (LEqual (GRAD, One),
                    LAnd (LEqual (GPIN, 188), LEqual (GIRQ, 126)))))
                { Return (One) }
                Return (Zero)
            }
            Method (_STA, 0, NotSerialized)
            {
                If (GRDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (HREG, Zero)
            Method (HLRD, 0, NotSerialized)
            {
                If (LAnd (GRDY (), LAnd (LEqual (LRAD, One),
                    LAnd (LEqual (LPIN, Zero), LAnd (LEqual (LFAR, Zero), LEqual (LREV, One))))))
                { Return (One) }
                Return (Zero)
            }
            // MH248 asserts high when closed; override GpioClx's active-low default.
            Method (_DSM, 4, Serialized)
            {
                If (LEqual (Arg0, ToUUID ("4F248F40-D5E2-499F-834C-27758EA1CD3F")))
                {
                    If (LEqual (Arg2, Zero)) { Return (Buffer (1) { 0x03 }) }
                    If (LEqual (Arg2, One)) { Return (Package () { Zero }) }
                }
                Return (Buffer (1) { Zero })
            }
            OperationRegion (HLIO, GeneralPurposeIO, Zero, One)
            Field (HLIO, ByteAcc, NoLock, Preserve)
            {
                Connection (GpioIo (Shared, PullDefault, 0, 0, IoRestrictionInputOnly,
                    "\\_SB.GPO0", 0, ResourceConsumer, , ) { 0 }),
                HPIN, 1
            }
            Method (_REG, 2, Serialized)
            {
                If (LEqual (Arg0, 0x08))
                {
                    Store (LEqual (Arg1, One), HREG)
                    If (LAnd (HREG, HLRD ())) { Notify (\_SB.LID0, 0x80) }
                }
            }
            Method (_AEI, 0, Serialized)
            {
                If (HLRD ())
                {
                    Return (ResourceTemplate ()
                    {
                        GpioInt (Edge, ActiveBoth, ExclusiveAndWake, PullDefault, 1000,
                            "\\_SB.GPO0", 0, ResourceConsumer, , ) { 0 }
                    })
                }
                Return (Buffer (2) { 0x79, 0x00 })
            }
            Method (_EVT, 1, Serialized)
            {
                If (LAnd (LEqual (Arg0, Zero), LAnd (HREG, HLRD ())))
                { Notify (\_SB.LID0, 0x80) }
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x10005000, 0x1000)
                Memory32Fixed (ReadWrite, 0x1000B000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11C30000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11D10000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11D40000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11E20000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11E60000, 0x1000)
                Memory32Fixed (ReadWrite, 0x11EA0000, 0x1000)
                // GpioClx requires one shared resource per logical bank.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Shared) { 276 }
            })
        }

        Device (LID0)
        {
            Name (_HID, EisaId ("PNP0C0D"))
            Name (_UID, Zero)
            Name (_DEP, Package () { \_SB.GPO0 })
            Method (_STA, 0, NotSerialized)
            {
                If (\_SB.GPO0.HLRD ()) { Return (0x0F) }
                Return (Zero)
            }
            Method (_LID, 0, Serialized)
            {
                If (LAnd (\_SB.GPO0.HREG, \_SB.GPO0.HLRD ()))
                { If (\_SB.GPO0.HPIN) { Return (Zero) } }
                // Handler unavailable: do not invent a closed-cover event.
                Return (One)
            }
            // GPIO event index zero. S0 idle only; no S3/S4 wake claim.
            Name (_PRW, Package () { Package () { \_SB.GPO0, Zero }, Zero })
        }

        Device (I2T0)
        {
            Name (_HID, "HANA6789")
            Name (_UID, 0)
            Name (_CCA, Zero) // conservative noncoherent DMA buffers
            Method (IRDY, 0, NotSerialized)
            {
                If (LAnd (LEqual (IREV, One), LAnd (And (IRAD, 1),
                    LAnd (LGreaterEqual (ICL0, 1000000), LLessEqual (ICL0, 1000000000)))))
                { Return (One) }
                Return (Zero)
            }
            Method (ICLK, 0, NotSerialized) { Return (ICL0) }
            Method (IRCK, 0, Serialized)
            {
                If (LNot (IRDY ())) { Return (Zero) }
                Return (\_SB.ILCK (Zero))
            }
            Method (_STA, 0, NotSerialized)
            {
                If (IRDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11E00000, 0x1000)
                Memory32Fixed (ReadWrite, 0x10217080, 0x80)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 176 }
            })
        }

        Device (I2C6)
        {
            Name (_HID, "HANA6789")
            Name (_UID, 6)
            Name (_CCA, Zero) // conservative noncoherent DMA buffers
            Method (IRDY, 0, NotSerialized)
            {
                If (LAnd (LEqual (IREV, One), LAnd (And (IRAD, 2),
                    LAnd (LGreaterEqual (ICL6, 1000000), LLessEqual (ICL6, 1000000000)))))
                { Return (One) }
                Return (Zero)
            }
            Method (ICLK, 0, NotSerialized) { Return (ICL6) }
            Method (IRCK, 0, Serialized)
            {
                If (LNot (IRDY ())) { Return (Zero) }
                Return (\_SB.ILCK (One))
            }
            Method (_STA, 0, NotSerialized)
            {
                If (IRDY ()) { Return (0x0F) }
                Return (Zero)
            }
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x1101A000, 0x1000)
                Memory32Fixed (ReadWrite, 0x10217480, 0x80)
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 182 }
            })
        }

        // MT6789 PSCI CPU_SUSPEND states from the stock DT /cpus/idle-states.
        // Core-off stops the local timer and loses core context (Arm DEN0048).
        // Include entry plus exit time because the DT has no wakeup-latency-us.
        // These are leaf states; cluster and system idle need a wake contract.
        Name (LPNC, ResourceTemplate ()
        {
            Register (SystemMemory, 0, 0, 0, 0)
        })
        Name (LPWF, Package ()
        {
            One, One, One, Zero, Zero, Zero,
            ResourceTemplate () { Register (FFixedHW, 32, 0, 0xFFFFFFFF, 3) },
            LPNC, LPNC, "WFI"
        })
        Name (LPIE, Package ()
        {
            Zero, Zero, 2, LPWF,
            Package ()
            {
                1600, 150, One, One, Zero, Zero,
                ResourceTemplate () { Register (FFixedHW, 32, 0, 0x00010001, 3) },
                LPNC, LPNC, "A55 core off"
            }
        })
        Name (LPIP, Package ()
        {
            Zero, Zero, 2, LPWF,
            Package ()
            {
                1400, 150, One, One, Zero, Zero,
                ResourceTemplate () { Register (FFixedHW, 32, 0, 0x00010002, 3) },
                LPNC, LPNC, "A76 core off"
            }
        })

        Device (CPU0)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 0)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU1)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 1)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU2)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 2)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU3)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 3)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU4)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 4)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU5)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 5)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIE) }
        }

        Device (CPU6)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 6)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIP) }
        }

        Device (CPU7)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, 7)
            Name (_STA, 0x0F)
            Method (_LPI, 0, NotSerialized) { Return (\_SB.LPIP) }
        }
    }
}
