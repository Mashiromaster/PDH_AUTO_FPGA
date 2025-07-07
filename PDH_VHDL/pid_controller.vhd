-- ///////////////Documentation////////////////////
-- Simple PID controller. Optimized for speed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pid_controller is
    port(
        clk             :   in  std_logic;
        rst             :   in  std_logic;
        
        gain_p_in       :   in  signed(23 downto 0);
        gain_i_in       :   in  signed(31 downto 0);
        gain_d_in       :   in  signed(23 downto 0);
        setpoint_in     :   in  signed(15 downto 0);
        limit_integral_in   : in  signed(15 downto 0); -- __ xxxx ____ ____
        limit_sum_in        : in  signed(15 downto 0); -- __ xxxx ____ ____

        -- data flow ports
        error_in        :   in  signed(15 downto 0);
        feedback_out    :   out signed(15 downto 0) 
    );
end entity pid_controller;

architecture behavioural of pid_controller is
    -- Each "x" "_" "z" and "y" represents 4 bits, with the "x" aligned with final output,
    -- "y" representing dont care, "z" representing bits to be discarded and "_" representing unused bits.
    signal error_from_setpoint   :   signed(15 downto 0);
    signal error_1      :   signed(15 downto 0);
    signal differential :   signed(15 downto 0);
    signal integral     :   signed(47 downto 0); -- yy xxxx yzzz zz__

    signal gain_p       :   signed(23 downto 0); -- When gain_p equals gain_i, PI corner at clk / 2pi / 65536 = 300Hz for 125MHz clock
    signal gain_i       :   signed(31 downto 0);
    signal gain_d       :   signed(23 downto 0);
    
    signal product_p    :   signed(39 downto 0); -- yy xxxx yzzz ____
    signal product_i    :   signed(47 downto 0); -- __ xxxx yyyy yyzz
    signal product_d    :   signed(39 downto 0); -- yy xxxx yzzz ____

    signal setpoint         :   signed(15 downto 0);
    signal limit_integral   :   signed(47 downto 0); -- yy xxxx yyyy yy__ pad with zeros
    signal limit_sum        :   signed(27 downto 0); -- yy xxxx y___ ____ pad with zeros

    signal integral_buf         :   signed(47 downto 0); -- yy xxxx yyyy yy__
    signal integral_buf_limited :   signed(47 downto 0); -- yy xxxx yyyy yy__
    signal sum_buf              :   signed(27 downto 0); -- yy xxxx y___ ____
    signal sum_buf_limited      :   signed(27 downto 0); -- yy xxxx y___ ___

begin
    gain_p <= gain_p_in;
    gain_i <= gain_i_in;
    gain_d <= gain_d_in;
    setpoint <= setpoint_in;
    limit_integral <= x"00" & limit_integral_in & x"000000";
    limit_sum <= x"00" & limit_sum_in & x"0";

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                integral <= (others => '0');
            else
                error_from_setpoint <= error_in - setpoint;
                error_1 <= error_in;
                differential <= error_in - error_1;
                integral <= integral_buf_limited;
                product_p <= gain_p * error_from_setpoint;
                product_i <= gain_i * error_from_setpoint;
                product_d <= gain_d * differential;
                feedback_out <= sum_buf_limited(19 downto 4);
            end if;
        end if;
    end process;

    integral_buf <= integral + ((7 downto 0 => product_i(47)) & product_i(47 downto 8)) + ((46 downto 0 => '0') & product_i(7));
    integral_buf_limited <= limit_integral when integral_buf > limit_integral else
                            -limit_integral when integral_buf < -limit_integral else
                            integral_buf;

    sum_buf <= product_p(39 downto 12) + integral(47 downto 20) + product_d(39 downto 12);
    sum_buf_limited <= limit_sum when sum_buf > limit_sum else
                    -limit_sum when sum_buf < -limit_sum else
                    sum_buf;
end architecture behavioural;






