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
            // Keep the device enumerable while radio transports are separate.
            Name (_STA, 0x07)
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x18000000, 0x00100000)
                // CONN reset is one keyed bit in the RGU register at +0x18.
                Memory32Fixed (ReadWrite, 0x10007018, 0x00000004)
                // WLAN DT interrupt[0]: SPI409 + 32; flags4 level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 441 }
            })
            // The CONN owner obtains SPM and GPIO through the SoC and GPIO
            // drivers. Own the WLAN aperture here once for all radio clients.
        }
    }
}
