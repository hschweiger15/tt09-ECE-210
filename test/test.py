# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Create a 10us period clock on port clk
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 1  # Enable learning
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Test different input current levels
    test_currents = [50, 100, 150, 200]
    for current in test_currents:
        dut._log.info(f"\nTesting with input current: {current}")
        dut.ui_in.value = current

        # Monitor for several cycles
        last_spike_time = -1
        for i in range(20):
            current_potential = int(dut.uo_out.value) & 0x7F  # Mask off refractory bit
            spike = int(dut.uio_out.value) & 1
            refractory = (int(dut.uo_out.value) >> 7) & 1
            spike_count = (int(dut.uio_out.value) >> 1) & 0x7F
            
            dut._log.info(f"Cycle {i}:")
            dut._log.info(f"  Membrane Potential: {current_potential}")
            dut._log.info(f"  Spike: {spike}")
            dut._log.info(f"  Refractory: {refractory}")
            dut._log.info(f"  Spike Count: {spike_count}")
            
            if spike:
                if last_spike_time >= 0:
                    interspike_interval = i - last_spike_time
                    dut._log.info(f"  Interspike Interval: {interspike_interval}")
                last_spike_time = i
            
            await ClockCycles(dut.clk, 1)

    dut._log.info("\nTest complete")

    # Verify some basic functionality
    assert spike_count > 0, "Should have seen some spikes during the test"