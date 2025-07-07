--状态逻辑，激光先于正弦波调制，然后进腔，锯齿波扫描透射光强（输入信号）观察是否进腔，先与锯齿波发生器进行求和扫描，
--当检测到透射光强（输入信号）和锯齿波叠加信号在一定阈值以下时停止扫描，
--状态机打开PID组件，调制后的激光经过光电探测器后进行数模转换和正弦波信号进行解调，
--解调后的信号经过滤波器得到过滤后的信号，再进入PID得到误差信号
--误差信号和锯齿波发生器求和成调制信号形成反馈调节到激光器控制端。再重复执行以上逻辑
----
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pdh_state_machine is
    port (
        clk             : in  std_logic;  -- System clock
        rst             : in  std_logic;  -- System reset
        input_signal    : in  signed(15 downto 0);  -- Input signal for validity check
        pc_cmd          : in  std_logic_vector(1 downto 0); -- PC commands (start, stop, reset)
        pid_enable      : out std_logic;  -- Enable PID controller
        mixer_enable    : out std_logic;  -- Enable mixer
        sawtooth_enable : out std_logic;  -- Sawtooth wave for scanning
        threshold_signal_locking     : in  signed(15 downto 0); -- Threshold for locking state
        threshold_signal_scanning    : in  signed(15 downto 0); -- Threshold for scanning state
        time_duration_scanning       : in  unsigned(31 downto 0); -- Time duration for scanning state
        time_duration_locking        : in  unsigned(31 downto 0) -- Time duration for locking state

    );
end entity pdh_state_machine;

architecture behavioral of pdh_state_machine is
    signal time_able                    : unsigned(31 downto 0) := (others => '0'); -- 32-bit timer for scanning duration
    signal pc_cmd_prev                  : std_logic_vector(1 downto 0) := "00";     -- 前一周期的 pc_cmd 值，初始为 "00"
    -- Define state enumeration 
    type state_type is (IDLE, SCANNING, LOCKING);
    signal current_state : state_type;

begin
    state_transition: process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then 
                    current_state <= IDLE;
                    time_able <= (others => '0');
                    pid_enable <= '0';
                    mixer_enable <= '0';
                    sawtooth_enable <= '0';
                    pc_cmd_prev <= "00";
                else
                    pc_cmd_prev <= pc_cmd;
                    --状态转移逻辑
                    case current_state is
                        when IDLE =>
                            if pc_cmd = "01" and pc_cmd_prev = "00" then  -- Start command
                                current_state <= SCANNING;
                                time_able <= (others => '0');
                            end if;

                        when SCANNING =>
                            mixer_enable <= '1';
                            pid_enable <= '0';
                            sawtooth_enable <= '1';
                            if input_signal < threshold_signal_scanning then
                                if time_able < time_duration_scanning then
                                    time_able <= time_able + x"00000001"; -- time_able用的是32位无符号整数而非integer，与1相加会导致编译报错
                                else
                                    current_state <= LOCKING;
                                    time_able <= (others => '0');
                                end if;
                            else
                                time_able <= (others => '0');
                            end if;                           

                        when LOCKING =>
                            mixer_enable      <= '1';
                            pid_enable        <= '1';
                            sawtooth_enable   <= '0';
                            if input_signal > threshold_signal_locking then
                                if time_able < time_duration_locking then
                                    time_able <= time_able + x"00000001"; -- 同上;
                                else
                                    current_state <= IDLE;
                                    time_able <= (others => '0');
                                end if;
                            else
                                time_able <= (others => '0');
                            end if;   
                            
                    end case;
                end if;      
            end if;                                 
        end process;

end architecture behavioral;