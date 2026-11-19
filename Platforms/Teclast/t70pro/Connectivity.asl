// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project development ID, not a vendor-issued or standard Wi-Fi device ID.
// One shared-aperture owner, not overlapping WLAN and consys resource claims.
// Stock wifi@18000000 maps reg[0]; consys subranges lie inside this aperture.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70WCON", 1)
{
    Scope (\_SB)
    {
        Device (WCN0)
        {
            Name (_HID, "HANA6796")
            Name (_UID, Zero)
            Name (_DDN, "MT6789 shared WLAN/conninfra AXI window")
            // Enumeration only: present/enabled/visible, not functioning.
            // No Windows driver/provider or actual enumeration is verified.
            Name (_STA, 0x07)
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x18000000, 0x00100000)
                // WLAN DT interrupt[0]: SPI409 + 32; flags4 level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 441 }
            })
            // This is NOT all conninfra resources: external consys MMIO,
            // consys IRQs and reserved memory are deliberately not assigned.
            // Stock WLAN requests this full region but ignores reservation
            // failure; consys directly maps overlapping subranges. That is
            // not a transferable ownership/interlocking contract for Windows.
            // A future shared provider must own this aperture exactly once
            // and coordinate its users before any functional driver is bound.
            // No DMA, firmware loading, radio, clock or power setup is supplied.
        }
    }
}
