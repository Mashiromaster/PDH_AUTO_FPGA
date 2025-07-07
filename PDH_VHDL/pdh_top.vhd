---
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MyPak_IIR.all;

entity pdh_top is
    port (
        clk            : in  std_logic;                     -- 系统时钟
        rst            : in  std_logic;                     -- 复位信号
        input_signal   : in  signed(15 downto 0);           -- 透射光强输入信号
        pc_cmd         : in  std_logic_vector(1 downto 0);  -- PC 命令 (start, stop, reset)

        memory_data    : in  std_logic_vector(63 downto 0); -- 从外部接收 RAM 数据
        memory_address : in  std_logic_vector(4  downto 0); --  RAM 地址 -- 宽度错误，和你下面例化RAM用的宽度一致，否则类型不匹配
        write_enable   : in  std_logic;                     -- 写使能信号

        threshold_signal_scanning : in  signed(15 downto 0); -- 扫描状态阈值信号
        threshold_signal_locking  : in  signed(15 downto 0); -- 锁定状态阈值信号
        time_duration_scanning : in  unsigned(31 downto 0);  -- 扫描状态时间限制
        time_duration_locking  : in  unsigned(31 downto 0);  -- 锁定状态时间限制

        gain_p        : in  signed(23 downto 0); -- PID 比例增益
        gain_i        : in  signed(31 downto 0); -- PID 积分增益
        gain_d        : in  signed(23 downto 0); -- PID 微分增益
        setpoint      : in  signed(15 downto 0); -- PID 设定值
        limit_integral: in  signed(15 downto 0); -- PID 积分限幅
        limit_sum     : in  signed(15 downto 0); -- PID 输出限幅

        slope         : signed(31 downto 0); -- 锯齿波斜率
        sine_wave_out : out signed(15 downto 0);

        scale         : in  signed(23 downto 0); -- 放缩因子 (2^16)
        bias          : in  signed(15 downto 0); -- 放缩偏置
        upper_limit   : in  signed(15 downto 0); -- 放缩上限
        lower_limit   : in  signed(15 downto 0);  -- 放缩下限

        acc_variation  : in  signed(63 downto 0); -- 输入变化量，用于相位累加器

        check               : out signed(15 downto 0);
        choose              : in  signed(3 downto 0);
        modulation_signal   : out signed(15 downto 0)       -- 反馈调制信号

    );
end entity pdh_top;

architecture behavioral of pdh_top is
    -- 状态机信号
    signal pid_enable      : std_logic;
    signal rst_pid          : std_logic;
    signal mixer_enable    : std_logic;
    signal rst_mixer       : std_logic;
    signal sawtooth_enable : std_logic;

    -- 锯齿波信号
    signal sawtooth_wave          : std_logic_vector(15 downto 0);
    signal sawtooth_wave_buffer   : signed(15 downto 0);
    signal sawtooth_wave_scaled   : std_logic_vector(15 downto 0);
    signal slope_buffer           : std_logic_vector(31 downto 0);
    signal sawtooth_stop          : std_logic;

    -- 信号处理信号
    signal sum_signal        : signed(15 downto 0);       -- 输入信号与锯齿波求和
    signal demod_signal      : signed(15 downto 0);       -- 解调信号（模拟）
    signal demod_signal_buffer: std_logic_vector(15 downto 0);
    signal filtered_signal   : signed(15 downto 0);       -- 滤波器输出
    signal error_signal      : signed(15 downto 0);       -- PID 误差信号

    -- IIR 滤波器系数（从 RAM 动态加载）
    signal coefX : signed_vec_44(0 to 16);
    signal coefY : signed_vec_44(0 to 3);
    signal IIR_signal : signed(15 downto 0);
      

    -- Trigonometric 模块信号
    signal phase_in      : signed(15 downto 0) := to_signed(0, 16);     -- 相位输入
    signal sine_wave      : signed(15 downto 0);
    signal sine_wave_0    : signed(15 downto 0);
    -- signal cosine_wave   : signed(15 downto 0);                         -- 余弦波输出

    -- 缩放器参数 -- 连到control上
    signal enable_wrapping : std_logic := '0';                         -- 禁用环绕
    signal demod_signal_buffer_p    :   std_logic_vector(31 downto 0);
    signal demod_signal_buffer_0    :   std_logic_vector(15 downto 0);

begin
        slope_buffer               <= std_logic_vector(slope);
        demod_signal               <= signed(demod_signal_buffer);
        sawtooth_wave_buffer       <=signed(sawtooth_wave);
    -- 状态机实例
    state_machine_inst : entity work.pdh_state_machine
        port map (
            clk              => clk,
            rst              => rst,
            input_signal     => input_signal,  -- 使用求和信号作为输入
            pc_cmd           => pc_cmd,
            pid_enable       => pid_enable,
            mixer_enable     => mixer_enable,
            sawtooth_enable  => sawtooth_enable,
            threshold_signal_scanning => threshold_signal_scanning, -- 修改过后左边是pdh_state_machine的端口，右边是top_pdh的端口
            threshold_signal_locking  => threshold_signal_locking,
            time_duration_scanning => time_duration_scanning,
            time_duration_locking  => time_duration_locking
        );

    -- 锯齿波发生器实例
    sawtooth_inst : entity work.sawtooth
        port map (
            clk      => clk,
            std_logic_vector(wave_out) => sawtooth_wave,
            reset    => rst,
            slope    => slope_buffer,       -- 这个slope还是我帮你在接口里定义的，原来根本找不到
            stop     => sawtooth_stop -- sawtooth_stop这个东西的driver数量为0，见最下面
        );

    -- IIR 滤波器实例（使用 RAM 动态加载系数）
    iir_with_ram_inst : entity work.IIR_with_RAM
        generic map (
            DATA_WIDTH => 64,
            ADDR_WIDTH => 5
        )
        port map ( -- 端口全部错误，又忘了改？
            data_in      => demod_signal_buffer,
            signed(data_out)     => IIR_signal,
            clk          => clk,
            reset        => rst_mixer,
            ram_address  => memory_address,
            ram_data     => memory_data,
            write_enable => write_enable
        );

    -- PID 控制器实例
    pid_inst : entity work.pid_controller
        port map (
            clk               => clk,
            rst               => rst_pid,
            gain_p_in         => gain_p,
            gain_i_in         => gain_i,
            gain_d_in         => gain_d,
            setpoint_in       => setpoint,
            limit_integral_in => limit_integral,
            limit_sum_in      => limit_sum,
            error_in          => IIR_signal,
            feedback_out      => error_signal
        );

    acc_inst : entity work.accumulator
        port map (
            clk      => clk,
            rst      => rst,
            variation_in => acc_variation,
            acc_out => phase_in
        );

    -- Trigonometric 实例（生成正弦波用于解调）
    trig_inst : entity work.trigonometric
        port map (
            clk      => clk,
            rst      => rst,
            phase_in => phase_in, -- 相位输入呢？不是说了可以用accumulator生成吗？
            sin_out  => sine_wave,
            cos_out  => open  -- 余弦未使用，标记为 open
        );
        sine_wave_out <= sine_wave;

    --线性放缩实例化
    scaler_inst : entity work.scaler
    port map (
        clk             => clk,
        rst             => rst,
        scale_in        => scale,
        bias_in         => bias,
        upper_limit_in  => upper_limit,
        lower_limit_in  => lower_limit,
        enable_wrapping_in => enable_wrapping,
        sig_in          => sawtooth_wave_buffer,
        std_logic_vector(sig_out)         => sawtooth_wave_scaled
    );
    --从这里往下都懒得改了，要动的地方太多。

    -- 解调信号
    process(clk)
    begin
        if rising_edge(clk) then
            sine_wave_0 <= sine_wave;
        end if;
    end process;
    demod_signal_buffer_p <= std_logic_vector((signed(input_signal) * signed(sine_wave_0)));
    demod_signal_buffer_0   <= demod_signal_buffer_p(31 downto 16); -- 左侧16位，右侧32位，报错
    process(clk)
    begin
        if rising_edge(clk) then
            demod_signal_buffer<=demod_signal_buffer_0;
        end if;
    end process;


    -- 反馈调制信号（误差信号与锯齿波求和）
    modulation_signal<= error_signal + signed(sawtooth_wave_scaled); -- 信号命名混乱，应该是error_signal
    --modulation_signal 有multi-driver，一个是这行，一个是上面的scaler实例，应该也是命名混乱造成的
    
    --状态机
    rst_pid              <= not pid_enable;
    rst_mixer            <= not mixer_enable; -- 这个信号从头到尾没有被使用过
    sawtooth_stop        <= not sawtooth_enable; -- 没有定义，你想说的是sawtooth_stop吧


    check   <= demod_signal when choose="0000" else 
                filtered_signal when choose="0001" else
                error_signal when choose="0010" else
                phase_in when choose="0100" else
                sine_wave when choose="0101" else
                signed(sawtooth_wave) when choose="0110" else
                signed(sawtooth_wave_scaled) when choose="0111" else
                input_signal when choose="1000" else
                (others => '0');

end architecture behavioral;
