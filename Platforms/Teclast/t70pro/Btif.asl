// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project-assigned development ID, not a MediaTek or standardized Bluetooth ID.
// Enumeration-only description of stock /soc/btif@1100c000 (mediatek,btif).
// Stock status is absent (enabled by DT default). No Windows BT driver is supplied.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70BTIF", 1)
{
    External (\_SB.WCN0, DeviceObj)

    Scope (\_SB)
    {
        Device (BTI0)
        {
            Name (_HID, "HANA6795")
            Name (_UID, Zero)
            Name (_DEP, Package () { \_SB.WCN0 })
            Name (_DDN, "MediaTek BTIF controller (enumeration only)")
            // Present, enabled, visible; do not assert functioning (bit 3).
            // Windows enumeration itself remains unverified.
            Name (_STA, 0x07)
            // DMA register resources below do not assert DMA coherency capability.
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x1100C000, 0x1000)
                // Stock BTIF reg indices 1 and 2, directly mapped by btif_drv.
                Memory32Fixed (ReadWrite, 0x10217B00, 0x80)
                Memory32Fixed (ReadWrite, 0x10217B80, 0x80)
                // Stock GIC SPI190 + 32 = GSIV222, flags4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 222 }
                // Stock IRQ indices 1 and 2: SPI184/185 + 32, flags4.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 216 }
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 217 }
            })
            // Stock btif_drv maps reg/IRQ indices 1 and 2 itself, rather than
            // requesting DMAengine channels. Preserve descriptor order without
            // assigning unverified TX/RX labels. Do not also assign the enclosing
            // APDMA 0x10217000/0x1000 window to another ACPI resource owner.
            // Register/IRQ ownership is not a functional Bluetooth driver:
            // no clock, power, reset or radio init occurs here.
        }
    }
}
