library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

architecture behavioral of CustomWrapper is

begin
    DUT:Entity WORK.pdh_top PORT MAP(
        
        clk                         =>  clk, 
        rst                         =>  Reset,
          
        check                       =>  OutputA,
        modulation_signal           =>  OutputB, 
        sine_wave_out               =>  OutputC,
        input_signal                =>  InputA,
        pc_cmd                      =>  Control0(6 downto 5),
        
        write_enable                =>  Control0(0), 
        choose                      =>  signed(Control0(4 downto 1)),

        memory_data                 => std_logic_vector(resize(signed(Control1) + signed(Control2), 64)),
        memory_address              =>  (Control3(4 downto 0)),

        threshold_signal_scanning   =>  signed(Control4(31 downto 16)),
        threshold_signal_locking    =>  signed(Control4(15 downto 0)),

        time_duration_scanning      =>  unsigned(Control5(31 downto 16))& x"0000",
        time_duration_locking      =>   unsigned(Control5(15 downto 0))& x"0000",

        gain_p                      =>  signed(Control6(23 downto 0)),
        gain_i                      =>  signed(Control7(31 downto 0)),
        gain_d                      =>  signed(Control8(23 downto 0)),
        setpoint                    =>  signed(Control9(15 downto 0)),
        limit_integral              =>  signed(Control10(31 downto 16)),
        limit_sum                   =>  signed(Control10(15 downto 0)),
        slope                       =>  signed(Control11(31 downto 0)),
        scale                       =>  signed(Control12(23 downto 0)),
        bias                        =>  signed(Control13(15 downto 0)),
        upper_limit                 =>  signed(Control14(15 downto 0)),
        lower_limit                 =>  signed(Control14(31 downto 16)),
        acc_variation               =>  signed(Control15(31 downto 0))& x"00000000"

    );

end architecture behavioral;