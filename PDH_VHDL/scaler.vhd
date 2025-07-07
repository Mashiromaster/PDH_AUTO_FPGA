-- ///////////////Documentation////////////////////
-- Linearly scales & adds bias to an input signal.
-- Choose to clamp or wrap the output by setting the enable_wrapping signal.
-- Each "x" "_" "z" and "y" represents 4 bits, with the "x" aligned with final output,
-- "y" representing dont care, "z" representing bits to be discarded and "_" representing unused bits.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scaler is
    port(
        clk             :   in  std_logic;
        rst             :   in  std_logic;

        scale_in            :   in  signed(23 downto 0); -- Scalling factor = scale / 2^16, from 2^-16 to 2^8
        bias_in             :   in  signed(15 downto 0); -- __ xxxx ____
        upper_limit_in      :   in  signed(15 downto 0); -- __ xxxx ____
        lower_limit_in      :   in  signed(15 downto 0); -- __ xxxx ____
        enable_wrapping_in  :   in  std_logic; -- Enable wrapping of the output

        sig_in          :   in  signed(15 downto 0);
        sig_out         :   out signed(15 downto 0)
    );
end entity scaler;

architecture behavioral of scaler is
    signal scale            :   signed(23 downto 0); -- Scalling factor = scale / 2^16, from 2^-16 to 2^8
    signal bias             :   signed(27 downto 0); -- yy xxxx y___
    signal product          :   signed(39 downto 0); -- yy xxxx yzzz
    signal product_1        :   signed(27 downto 0); -- yy xxxx y___
    signal sum_buf          :   signed(27 downto 0); -- yy xxxx y___
    signal sum_buf_limited  :   signed(27 downto 0); -- yy xxxx y___
    signal upper_limit      :   signed(27 downto 0); -- yy xxxx y___
    signal lower_limit      :   signed(27 downto 0); -- yy xxxx y___

    signal enable_wrapping  :   std_logic;
begin
    scale <= scale_in;
    bias <= (7 downto 0 => bias_in(15)) & bias_in(15 downto 0) & x"0";
    upper_limit <= (7 downto 0 => upper_limit_in(15)) & upper_limit_in(15 downto 0) & x"0";
    lower_limit <= (7 downto 0 => lower_limit_in(15)) & lower_limit_in(15 downto 0) & x"0";
    enable_wrapping <= enable_wrapping_in;

    product <= sig_in * scale;
    sum_buf <= product_1 + bias;
    sum_buf_limited <= upper_limit when sum_buf > upper_limit else
                        lower_limit when sum_buf < lower_limit else
                        sum_buf;

    process(clk)
    begin
        if rising_edge(clk) then
             -- No need to round because it's the same as flooring in terms of uniformity
             -- and the half bit bias is unimportant in this case.
             -- Plus it will cause timing failure.
            product_1 <= product(39 downto 12);
            if enable_wrapping = '1' then
                sig_out <= sum_buf(19 downto 4);
            else
                sig_out <= sum_buf_limited(19 downto 4);
            end if;
        end if;
    end process;
end architecture behavioral;