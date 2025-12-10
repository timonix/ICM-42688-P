-- tb_brute_42688.vhd
--
-- Testbench for entity brute_42688
--
-- No stimuli checking here – this is a "waveform" testbench.
-- You can extend it with assertions once you know the expected behavior.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_brute_42688 is
end entity tb_brute_42688;

architecture sim of tb_brute_42688 is

    -- Generic constants for the DUT
    constant C_CLK_FREQUENCY_HZ : integer := 27_000_000;
    constant C_NUM_UNITS        : positive := 2;

    -- Clock period (approximate for 27 MHz)
    constant C_CLK_PERIOD : time := 37 ns;  -- ~27.027 MHz

    -- DUT signals
    signal s_clk   : std_logic := '0';
    signal s_rst   : std_logic := '1';

    signal s_miso  : std_logic_vector(0 to C_NUM_UNITS-1) := (others => '1');
    signal s_mosi  : std_logic;
    signal s_cs    : std_logic;
    signal s_sck   : std_logic;
    signal s_32khz : std_logic;

begin

    -------------------------------------------------------------------------
    -- DUT instantiation
    -------------------------------------------------------------------------
    dut : entity work.brute_42688
    generic map (
        g_clk_frequency_hz => C_CLK_FREQUENCY_HZ,
        g_number_of_units  => C_NUM_UNITS
    )
    port map (
        i_clk   => s_clk,
        i_rst   => s_rst,
        i_miso  => s_miso,
        o_mosi  => s_mosi,
        o_cs    => s_cs,
        o_sck   => s_sck,
        o_32khz => s_32khz
    );
    
    process (s_clk)
    begin
        if rising_edge(s_clk) then
            if s_sck = '1' then
                s_miso <= not s_miso;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Clock generation
    -------------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            s_clk <= '0';
            wait for C_CLK_PERIOD / 2;
            s_clk <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;
    end process clk_gen;

    -------------------------------------------------------------------------
    -- Reset generation
    -------------------------------------------------------------------------
    rst_gen : process
    begin
        -- Hold reset active for a few clock cycles
        s_rst <= '1';
        wait for 10 * C_CLK_PERIOD;
        s_rst <= '0';
        wait;
    end process rst_gen;


    sim_end : process
    begin
        wait for 1 ms;
        assert false report "Simulation finished" severity failure;
    end process sim_end;

end architecture sim;
