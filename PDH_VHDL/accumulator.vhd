-- ///////////////Documentation////////////////////
-- Simple accumulator providing stimulus for testing
-- purposes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator is
    port(
        clk             :   in  std_logic;
        rst             :   in  std_logic;
        variation_in    :   in  signed(63 downto 0);
        acc_out         :   out signed(15 downto 0)
    );
end entity accumulator;

architecture behavioral of accumulator is
    signal acc          :   signed(63 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc <= (others => '0');
            else
                acc <= acc + variation_in;
            end if;
        end if;
    end process;
    acc_out <= acc(63 downto 48);
end architecture behavioral;