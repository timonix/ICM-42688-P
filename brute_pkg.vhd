
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package brute_pkg is
    type rom_data is record
        mosi : std_logic;
        miso : std_logic;
        cs   : std_logic;
        sck  : std_logic;
    end record;
    
    type xyz_16 is record
        x : signed(15 downto 0);
        y : signed(15 downto 0);
        z : signed(15 downto 0);
    end record;
    
    
    subtype status_code_t is std_logic_vector(1 downto 0);
    constant c_unilitilized       : status_code_t := "00";
    constant c_connection_success : status_code_t := "01";
    constant c_device_configured  : status_code_t := "10";
    constant c_failed_to_connect  : status_code_t := "11";
    
    type ROM_T is array (natural range<>) of rom_data;
    
    constant c_idle : ROM_T(0 to 0) := (
        0 => (mosi => '0', miso => '0',cs=> '1',sck => '1')
    );
    
    constant c_init : ROM_T(0 to 1) := (
        0 to 1 => (mosi => '0', miso => '0',cs=> '0',sck => '1')
    );
    
    pure function make_read_8_bits return ROM_T;
    
    function max(a:integer;b:integer) return integer;
    function make_cmd_rom(cmd : std_logic_vector) return ROM_T;
    function write_reg(reg : std_logic_vector; data:std_logic_vector) return ROM_T;
    function read_reg(reg : std_logic_vector) return ROM_T;
    
    constant c_read_8_bits : ROM_T(0 to 15);

    function append_rom(
        constant a : ROM_T;
        constant d : rom_data
    ) return ROM_T;

    function concat_rom(
        constant a : ROM_T;
        constant b : ROM_T
    ) return ROM_T;
    
    
end package;

package body brute_pkg is
    
    function max(a:integer;b:integer) return integer is
begin
    if a > b then return a; end if;
    return b;
end function;

pure function make_read_8_bits return ROM_T is
    variable tmp : ROM_T(0 to 15);
begin
    for i in tmp'range loop
        if (i mod 2 = 0) then
            tmp(i) := (mosi => '0', miso => '0', cs => '0', sck => '0');
        else
            tmp(i) := (mosi => '0', miso => '1', cs => '0', sck => '1');
        end if;
    end loop;
    return tmp;
end function;

constant c_read_8_bits : ROM_T(0 to 15) := make_read_8_bits;

function make_cmd_rom(cmd : std_logic_vector) return ROM_T is
    variable result : ROM_T(0 to (cmd'length * 2) - 1);
    variable idx    : natural := 0;
begin
    -- Loop from MSB down to LSB
    for bit_index in cmd'range loop
        -- First half-cycle: sck = '0'
        result(idx) := (
            mosi => cmd(bit_index),
            miso => '0',
            cs   => '0',
            sck  => '0'
        );
        idx := idx + 1;

        -- Second half-cycle: sck = '1'
        result(idx) := (
            mosi => cmd(bit_index),
            miso => '0',
            cs   => '0',
            sck  => '1'
        );
        idx := idx + 1;
    end loop;

    return result;
end function;

function write_reg(reg : std_logic_vector; data:std_logic_vector) return ROM_T is
begin
    return c_init & make_cmd_rom(reg) & make_cmd_rom(data) & c_idle;
end function;

function read_reg(reg : std_logic_vector) return ROM_T is
begin
    return c_init & make_cmd_rom(reg) & c_read_8_bits & c_idle;
end function;

function append_rom(
    constant a : ROM_T;
    constant d : rom_data
) return ROM_T is
    variable result : ROM_T(0 to a'length);  -- one extra element
begin
    -- Copy old elements
    for i in a'range loop
        result(i - a'low) := a(i);  -- normalize indices starting at 0
    end loop;

    -- Append new element
    result(result'high) := d;

    return result;
end function;

function concat_rom(
    constant a : ROM_T;
    constant b : ROM_T
) return ROM_T is
    variable result : ROM_T(0 to a'length + b'length - 1);
begin
    -- Copy first array
    for i in a'range loop
        result(i - a'low) := a(i);
    end loop;

    -- Copy second array
    for i in b'range loop
        result(a'length + (i - b'low)) := b(i);
    end loop;

    return result;
end function;

end package body;