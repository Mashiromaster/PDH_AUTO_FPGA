LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.Numeric_std.ALL;
use WORK.MyPak_IIR.all;

--------------------IIR with RAM--------------------

entity IIR_with_RAM is
    generic (
        DATA_WIDTH : integer := 64;  -- 数据宽度为 64 位
        ADDR_WIDTH : integer := 5    -- 地址宽度，支持 0 到 20，共 21 个系数
    );
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        write_enable   : in  std_logic;                                -- 写使能信号(control0)
        ram_address    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);  -- 地址
        ram_data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_in        : in  std_logic_vector(15 downto 0);  -- 输入数据（control1 and control2）
        data_out       : out std_logic_vector(15 downto 0)   -- 输出数据
    );
end IIR_with_RAM;

architecture Behavioral of IIR_with_RAM is
    -- RAM 信号定义
    type ram_type is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram_memory : ram_type;
    signal ram_memory_out : std_logic_vector( DATA_WIDTH-1 downto 0);
    
    -- 系数信号定义
    signal coefX : signed_vec_44(0 to 16);
    signal coefY : signed_vec_44(0 to 3);

    -- 控制信号
    signal ram_write      : std_logic;
    signal write_enable_0 : std_logic := '0';  -- 存储写使能信号的前一状态  


begin
    -- RAM 写入进程
    ram_process: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- 重置 RAM 和系数
                for i in 0 to 2 ** ADDR_WIDTH - 1 loop -- 初始化整个RAM而非只有前21个地址
                    ram_memory(i) <= (others => '0');
                end loop;
            elsif ram_write = '1' then
                -- 写入 RAM
                ram_memory(to_integer(unsigned(ram_address))) <= ram_data; -- 为什么还要做越界判断？况且判断的比较值也不对，应该和2**ADDR_WIDTH-1或者20比较，怎么会和DATA_WIDTH-1比较？
            end if;
            ram_memory_out <= ram_memory(to_integer(unsigned(ram_address)));
        end if;
    end process;

    -----上升沿检测

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- 复位时初始化信号
                write_enable_0 <= '0';
                ram_write      <= '0';
            else
                -- 更新前一状态
                write_enable_0 <= write_enable;
                -- 检测上升沿：当前为 '1' 且前一状态为 '0'
                if write_enable = '1' and write_enable_0 = '0' then
                    ram_write <= '1';
                else
                    ram_write <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- 更新 coefX 和 coefY
    coef_gen: for i in 0 to 16 generate
        coefX(i) <= signed(ram_memory(i)(43 downto 0));
    end generate;
    
    coef_y_gen: for i in 0 to 3 generate
        coefY(i) <= signed(ram_memory(i + 17)(43 downto 0));
    end generate;


    -- 实例化 IIR (使用 IIR_4SLA_4th_order，支持 17 个 coefX)
    iir_inst : entity work.IIR_4SLA_4th_order
      
        port map (
            input => signed(data_in),
            std_logic_vector(output) => data_out,

            Reset => reset,
            Clk => clk,

            coefX => coefX,
            coefY => coefY
        );

end architecture behavioral;