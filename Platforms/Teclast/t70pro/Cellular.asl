// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project development IDs, not vendor-issued or standardized WWAN IDs.
// AP-facing controllers from stock T70 DT; enumeration only, no WWAN driver.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70CELL", 1)
{
    Scope (\_SB)
    {
        Device (DPM0)
        {
            Name (_HID, "HANA6797")
            Name (_CCA, Zero)
            Name (_UID, Zero)
            Name (_DDN, "MT6789 DPMAIF AP interface (enumeration only)")
            // Present/enabled/visible, not a claim of functioning hardware.
            Name (_STA, 0x0F)
            Name (_CRS, ResourceTemplate ()
            {
                // dpmaif@10014000 reg[0..3], preserve stock order.
                // No reg-names or interrupt-names: do not infer TX/RX roles.
                Memory32Fixed (ReadWrite, 0x10014000, 0x1000)
                Memory32Fixed (ReadWrite, 0x1022D000, 0x1000)
                Memory32Fixed (ReadWrite, 0x1022C000, 0x1000)
                Memory32Fixed (ReadWrite, 0x1022E000, 0x1000)
                // SPI241 + 32, flags4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 273 }
                // Reserved UEFI handoff record for the dynamic LK MD_SYS1 range.
                Memory32Fixed (ReadOnly, 0x43F7F180, 0x40)
            })
        }
        Device (CCF0)
        {
            Name (_HID, "HANA6798")
            Name (_UID, Zero)
            Name (_DDN, "MT6789 CCCI CCIF AP interface (enumeration only)")
            Name (_STA, 0x0F)
            Name (_CRS, ResourceTemplate ()
            {
                // ccifdriver@10209000 reg[0..1], interrupts[0..1].
                Memory32Fixed (ReadWrite, 0x10209000, 0x1000)
                Memory32Fixed (ReadWrite, 0x1020A000, 0x1000)
                // SPI226/227 + 32, flags4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 258 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 259 }
            })
        }
        // Stock status is absent for both nodes (DT default enabled).
        // Do not duplicate these resources in infra_dpmaif or AP/MD-CCIF aliases.
        // No reserved/shared modem RAM, DMA buffers, modem firmware or boot,
        // clock/power setup, radio endpoint or SIM/network service is supplied.
        // A Windows driver/provider and actual enumeration remain unverified.
    }
}
