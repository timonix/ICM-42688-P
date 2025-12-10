library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package ICM_timing_pkg is

  ---------------------------------------------------------------------------
  -- Fixed timing requirements in ns (from datasheet)
  ---------------------------------------------------------------------------
    constant c_cs_setup_time_ns  : real := 39.0;       -- min 39 ns
    constant c_sdi_setup_time_ns : real := 13.0;       -- min 13 ns

    constant c_sclk_high_time_ns : real := 17.0;       -- min 17 ns
    constant c_sclk_low_time_ns  : real := 17.0;       -- min 17 ns
    constant c_sclk_period_ns    : real := 41.666666; -- min 41.6667 ns
  -- with the additional constraint:
  --   (high_time + low_time) >= c_sclk_period_ns

  ---------------------------------------------------------------------------
  -- Types
  ---------------------------------------------------------------------------

  -- SCLK timing in cycles
    type sclk_cycles_t is record
        high   : natural;
        low    : natural;
        period : natural;
    end record;

  ---------------------------------------------------------------------------
  -- Public function declarations
  ---------------------------------------------------------------------------

  -- Clock period in ns from frequency in MHz
    function clk_period_ns(clk_frequency_mhz : real) return real;

  -- Setup-time requirements (in cycles) for a given clock frequency
    function cs_setup_cycles (clk_frequency_mhz : real) return natural;
    function sdi_setup_cycles(clk_frequency_mhz : real) return natural;

  -- Compute SCLK high/low/period in cycles with all constraints enforced
    function compute_sclk_cycles(clk_frequency_mhz : real) return sclk_cycles_t;

end package ICM_timing_pkg;


package body ICM_timing_pkg is

  ---------------------------------------------------------------------------
  -- Local helper functions (not visible outside the package)
  ---------------------------------------------------------------------------

  -- Convert a time in ns to an integer number of clock cycles, rounding UP
    function cycles_for_time(
        i_time_ns       : real;
        i_clk_period_ns : real
    ) return natural is
    begin
        return natural(integer(ceil(i_time_ns / i_clk_period_ns)));
    end function cycles_for_time;

  -- Simple max() for naturals
    function max_nat(a, b : natural) return natural is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function max_nat;

  ---------------------------------------------------------------------------
  -- Public function implementations
  ---------------------------------------------------------------------------

    function clk_period_ns(clk_frequency_mhz : real) return real is
    begin
    -- 1000 ns / MHz → ns
        return 1000.0 / clk_frequency_mhz;
    end function clk_period_ns;


    function cs_setup_cycles(clk_frequency_mhz : real) return natural is
        variable tclk_ns : real;
    begin
        tclk_ns := clk_period_ns(clk_frequency_mhz);
        return cycles_for_time(c_cs_setup_time_ns, tclk_ns);
    end function cs_setup_cycles;


    function sdi_setup_cycles(clk_frequency_mhz : real) return natural is
        variable tclk_ns : real;
    begin
        tclk_ns := clk_period_ns(clk_frequency_mhz);
        return cycles_for_time(c_sdi_setup_time_ns, tclk_ns);
    end function sdi_setup_cycles;


    function compute_sclk_cycles(clk_frequency_mhz : real) return sclk_cycles_t is
        variable tclk_ns : real;

        variable high_min_cycles   : natural;
        variable low_min_cycles    : natural;
        variable period_min_cycles : natural;

        variable sum_min_cycles    : natural;
        variable sum_req_cycles    : natural;
        variable extra_cycles      : natural;

        variable result : sclk_cycles_t;
    begin
        tclk_ns := clk_period_ns(clk_frequency_mhz);

    -- Individual minimums in cycles
        high_min_cycles   := cycles_for_time(c_sclk_high_time_ns, tclk_ns);
        low_min_cycles    := cycles_for_time(c_sclk_low_time_ns,  tclk_ns);
        period_min_cycles := cycles_for_time(c_sclk_period_ns,    tclk_ns);

    -- Sum of individual minimums
        sum_min_cycles := high_min_cycles + low_min_cycles;

    -- Required sum to also satisfy the overall SCLK period constraint
        sum_req_cycles := max_nat(sum_min_cycles, period_min_cycles);

    -- Extra cycles we must add to (high + low) over their individual mins
        extra_cycles := sum_req_cycles - sum_min_cycles;

    -- Distribute the extra cycles:
    --   keep HIGH at its minimum and give all extra cycles to LOW
        result.high   := high_min_cycles;
        result.low    := low_min_cycles + extra_cycles;
        result.period := sum_req_cycles;

        return result;
    end function compute_sclk_cycles;

end package body ICM_timing_pkg;
