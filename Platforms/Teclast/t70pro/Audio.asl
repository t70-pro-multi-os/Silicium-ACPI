// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project-assigned development ID, not a MediaTek vendor ID.
// Describes existing AFE hardware only; no power, clock, DMA or codec setup.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70AUDIO", 1)
{
    Scope (\_SB)
    {
        Device (AFE0)
        {
            Name (_HID, "HANA6793")
            Name (_UID, Zero)
            // Stock DT/kernel use noncoherent DMA policy; do not advertise
            // automatic hardware cache coherency to the ARM OS.
            Name (_CCA, Zero)
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11210000, 0x00002000)
                // Stock GIC SPI 234 + 32 = GSI 266, flags 4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 266 }
            })
        }
    }
}
