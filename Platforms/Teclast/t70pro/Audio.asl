// SPDX-License-Identifier: BSD-2-Clause-Patent
// Project-assigned development ID, not a MediaTek vendor ID.
// AFE and its stock amplifier control connections.
DefinitionBlock ("", "SSDT", 2, "T70PRO", "T70AUDIO", 1)
{
    External (\_SB.I2T1, DeviceObj)
    External (\_SB.I2T1.IRDY, MethodObj)
    Scope (\_SB)
    {
        Device (AFE0)
        {
            Name (_HID, "HANA6793")
            Name (_UID, Zero)
            // Stock DT/kernel use noncoherent DMA policy; do not advertise
            // automatic hardware cache coherency to the ARM OS.
            Name (_CCA, Zero)
            Name (AFRS, ResourceTemplate ()
            {
                Memory32Fixed (ReadWrite, 0x11210000, 0x00002000)
                // Stock GIC SPI 234 + 32 = GSI 266, flags 4: level/high.
                Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 266 }
            })
            // Keep resource order identical to the stock channel tuple.
            Name (AMPS, ResourceTemplate ()
            {
                I2cSerialBusV2 (0x34, ControllerInitiated, 400000, AddressingMode7Bit,
                    "\\_SB.I2T1", 0, ResourceConsumer, , Exclusive, )
                I2cSerialBusV2 (0x35, ControllerInitiated, 400000, AddressingMode7Bit,
                    "\\_SB.I2T1", 0, ResourceConsumer, , Exclusive, )
            })
            Method (_DEP, 0, NotSerialized)
            {
                If (\_SB.I2T1.IRDY ()) { Return (Package () { \_SB.I2T1 }) }
                Return (Package () {})
            }
            Method (_CRS, 0, Serialized)
            {
                If (\_SB.I2T1.IRDY ()) { Return (ConcatenateResTemplate (AFRS, AMPS)) }
                Return (AFRS)
            }
        }
    }
}
