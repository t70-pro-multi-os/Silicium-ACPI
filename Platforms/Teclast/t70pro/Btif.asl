// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project-assigned development ID, not a MediaTek or standardized Bluetooth ID.
// Enumeration-only description of stock /soc/btif@1100c000 (mediatek,btif).
// Stock status is absent (enabled by DT default). No Windows BT driver is supplied.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70BTIF", 1)
{
    Scope (\_SB)
    {
        Device (BTI0)
        {
            Name (_HID, "HANA6795")
            Name (_UID, Zero)
            Name (_DDN, "MediaTek BTIF controller (enumeration only)")
            // Present, enabled, visible; do not assert functioning (bit 3).
            // Windows enumeration itself remains unverified.
            Name (_STA, 0x07)
            // No DMA resource or DMA coherency capability is advertised here.
            Name (_CRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x1100C000, 0x1000)
                // Stock GIC SPI190 + 32 = GSIV222, flags4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 222 }
            })
            // Intentionally omitted: DMA windows 0x10217B00/0x80 and
            // 0x10217B80/0x80, plus DMA completion GSIV216 and GSIV217.
            // Stock apdma@10217000 also describes the enclosing 0x1000 range;
            // shared APDMA channel ownership has not been established for ACPI.
            // This partial resource contract must be completed before binding
            // a functional driver. No clock, power, reset or radio init occurs.
        }
    }
}
