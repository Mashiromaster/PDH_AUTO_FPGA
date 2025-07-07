library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity sawtooth is
port (
    clk      : in std_logic; 
    wave_out : out std_logic_vector(15 downto 0);
    reset    : in std_logic;
    slope    : in std_logic_vector(31 downto 0);
    stop      : in std_logic
);
end sawtooth;

architecture Behavioral of sawtooth is
    signal count : unsigned(31 downto 0) := x"00000000";

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count <= x"00000000";
            elsif stop = '0' then
                count <= count + unsigned(slope);
            end if;
        end if;
    end process;
    wave_out <= std_logic_vector(count(31 downto 16));
end Behavioral;