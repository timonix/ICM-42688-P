library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.brute_pkg.all;

entity brute_42688 is
    generic (
        g_speed_divider : integer := 1;
        g_clk_frequency_hz : integer range 0 to 48000000*g_speed_divider := 27000000;
        g_number_of_units : positive := 2

    );
    
    port (
        i_clk   : in std_logic;
        i_rst   : in std_logic;
        
        o_status : out status_code_t;
        
        o_gyro : out xyz_16;
        o_acc  : out xyz_16;
        
        i_miso  : in  std_logic_vector(0 to g_number_of_units-1);
        o_mosi  : out std_logic;
        o_sck   : out std_logic;
        o_cs    : out std_logic;
        o_32khz : out std_logic
        
    );
end entity brute_42688;

architecture rtl of brute_42688 is

    constant WHO_AM_I_CMD : STD_LOGIC_VECTOR(7 downto 0) := x"F5";
    constant WHO_AM_I_EXPECTED : STD_LOGIC_VECTOR(7 downto 0) := x"47";
    
    constant SET_BANK_0_ADDR   : STD_LOGIC_VECTOR(7 downto 0) := x"75";
    constant INTF_CONFIG1_ADDR : STD_LOGIC_VECTOR(7 downto 0) := x"4D";
    constant INTF_CONFIG5_ADDR : STD_LOGIC_VECTOR(7 downto 0) := x"7B"; --BANK 1
    constant GYRO_CONFIG_ADDR0  : STD_LOGIC_VECTOR(7 downto 0) := x"4F";
    constant ACC_CONFIG_ADDR0   : STD_LOGIC_VECTOR(7 downto 0) := x"50";
    
    constant READ_ACCEL_DATA_X1 : std_logic_vector(7 downto 0) := x"9F";
    
    
    constant c_check_connection_rom : ROM_T :=
    c_idle &
    read_reg(WHO_AM_I_CMD) &
    c_idle;
    
    constant c_initilize_rom : ROM_T :=
    c_idle &
    read_reg(WHO_AM_I_CMD) &
    write_reg(SET_BANK_0_ADDR,   x"00") &                    -- REG_BANK_SEL = 0
    write_reg(INTF_CONFIG1_ADDR, "0000" & "0" & "1" & "01")& -- INTF_CONFIG1: RTC_MODE=1, CLKSEL=01
    
    write_reg(SET_BANK_0_ADDR,   x"01") &                    -- REG_BANK_SEL = 1
    write_reg(INTF_CONFIG5_ADDR, x"04") &                    -- INTF_CONFIG5: PIN9_FUNCTION = CLKIN
    
    write_reg(SET_BANK_0_ADDR,   x"00") &                    -- REG_BANK_SEL = 0
    write_reg(GYRO_CONFIG_ADDR0, x"01") &                    -- GYRO_CONFIG0: ±2000 dps, 32kHz ODR
    write_reg(ACC_CONFIG_ADDR0,  x"01") &                    -- ACCEL_CONFIG0: ±16 g, 32kHz ODR
    c_idle;
    
    constant c_poll_data_rom :ROM_T :=
    c_idle &
    make_cmd_rom(READ_ACCEL_DATA_X1) &
    make_read_8_bits & --ACC_X
    make_read_8_bits &
    make_read_8_bits & --ACC_Y
    make_read_8_bits &
    make_read_8_bits & --ACC_Z
    make_read_8_bits &
    make_read_8_bits & --GYRO_X
    make_read_8_bits &
    make_read_8_bits & --GYRO_Y
    make_read_8_bits &
    make_read_8_bits & --GYRO_Z
    make_read_8_bits &
    c_idle;
    
    constant c_select_width : integer := max(c_poll_data_rom'length,c_initilize_rom'length);
    signal rom_select : integer range 0 to c_select_width-1 := 0;
    signal rom_output : rom_data;
    
    type state_T is (CHECK_CONN,INIT,POLL,FAILED);
    signal state : state_T := CHECK_CONN;
    
    subtype shift_reg_T is STD_LOGIC_VECTOR(16*6-1 downto 0);
    type shift_reg_arr_T is array (natural range<>) of shift_reg_T;
    
    signal shift_reg_arr : shift_reg_arr_T(0 to g_number_of_units-1);
    
    signal s_32khz : std_logic := '0';
    signal s_rom_miso_last : std_logic := '0';
    
begin
    
    o_32khz <= s_32khz;
    
    proc_32khz: process (i_clk)
    constant C_DIV : integer := g_clk_frequency_hz / 32000;
    variable v_cnt : integer range 0 to C_DIV/2-1 := 0;
    begin
        if rising_edge(i_clk) then
            if v_cnt = C_DIV/2 - 1 then
                s_32khz <= not s_32khz;
                v_cnt   := 0;
            else
                v_cnt := v_cnt + 1;
            end if;
        end if;
    end process;
    
    process (i_clk)
    variable v_sensor_ok : BOOLEAN_VECTOR(0 to g_number_of_units-1);
    variable v_all_sensors_ok : boolean;
    begin
        if rising_edge(i_clk) then
            
            o_mosi <= rom_output.mosi;
            o_sck  <= rom_output.sck;
            o_cs   <= rom_output.cs;
            s_rom_miso_last <= rom_output.miso;
            
            if rom_output.miso = '1' and s_rom_miso_last = '0' then
                for i in shift_reg_arr'range loop
                    shift_reg_arr(i) <= shift_reg_arr(i)(shift_reg_T'high-1 downto 0) & i_miso(i);
                end loop;
            end if;
            
            if state = CHECK_CONN and rom_select < c_check_connection_rom'length*g_speed_divider then
                rom_output <= c_check_connection_rom(rom_select/g_speed_divider);
                rom_select <= rom_select + 1;
            elsif state = CHECK_CONN and rom_select = c_check_connection_rom'length*g_speed_divider then
                rom_select <= 0;
                
                v_all_sensors_ok := true;
                for i in shift_reg_arr'range loop
                    v_sensor_ok(i) := shift_reg_arr(i)(7 downto 0) = WHO_AM_I_EXPECTED;
                    v_all_sensors_ok := v_all_sensors_ok AND v_sensor_ok(i);
                end loop;
                
                if v_all_sensors_ok then
                    o_status <= c_connection_success;
                    state <= INIT;
                else
                    o_status <= c_failed_to_connect;
                    state <= FAILED;
                end if;
            end if;
            
            
            -- first go through the c_check_connection_rom,
            -- shift in the result, check that it is equal to WHO_AM_I_EXPECTED
            -- set o_status to c_failed_to_connect or c_connection_success
            
            -- if successful go through c_initilize_rom and set o_status to c_device_configured
            -- then start looping c_poll_data_rom
            
            if i_rst = '1' then
                state <= CHECK_CONN;
                o_status <= c_unilitilized;
                rom_select <= 0;
            end if;
            
        end if;
    end process;

    

end architecture;