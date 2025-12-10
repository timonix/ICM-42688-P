library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.brute_pkg.all;
entity top_brute is
    port (
        clk    : in std_logic;
        reset  : in std_logic;
        i_miso : in std_logic_vector(0 to 0);
        o_mosi : out std_logic;
        o_cs   : out std_logic;
        o_sck  : out std_logic;
        o_status : out std_logic_vector(1 downto 0);
        o_debug : out std_logic_vector(5 downto 0)
    );
end entity top_brute;

architecture rtl of top_brute is
    signal s_status : status_code_t;
    signal s_debug : std_logic_vector(5 downto 0) := "000000";
begin
    o_debug <= not s_debug;
    o_status <= s_status;

    u_brute_42688 : entity work.brute_42688
    generic map (
        g_speed_divider => 4,
        g_clk_frequency_hz => 27_000_000,
        g_number_of_units  => 1
    )
    port map (
        i_clk   => clk,
        i_rst   => reset,  -- Active-HIGH synchronous reset
        o_status => s_status,
        i_miso  => i_miso,
        o_mosi  => o_mosi,
        o_cs    => o_cs,
        o_sck   => o_sck,
        o_32khz => open
    );

end architecture;