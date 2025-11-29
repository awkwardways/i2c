library ieee;
use ieee.std_logic_1164.all;

entity i2c_target_tb is
end entity i2c_target_tb;

architecture sim of i2c_target_tb is
  constant TB_SYSTEM_CLK_FREQUENCY : integer := 20e6;
  constant TB_SYSTEM_CLK_PERIOD : time := 1000 ms / TB_SYSTEM_CLK_FREQUENCY;
  constant TB_I2C_BUS_KBITPS : integer := 100000;
  signal tb_sda : std_logic := 'H';
  signal tb_scl : std_logic := 'H';
  signal tb_clk : std_logic := '0';
  signal tb_nena : std_logic := '0';
  signal tb_rw : std_logic := '1';
  signal tb_data_out : std_logic_vector(7 downto 0);
  signal tb_data_in : std_logic_vector(7 downto 0) := x"51"; --01010001
  signal tb_address : std_logic_vector(6 downto 0) := "0000011";
  signal tb_busy : std_logic;
  signal tb_nen : std_logic := '0';
begin

  CONTROLLER: entity work.i2c_controller(rtl)
  generic map (
    SYSTEM_CLK_FREQUENCY => TB_SYSTEM_CLK_FREQUENCY,
    I2C_BUS_KBITPS => TB_I2C_BUS_KBITPS
  )
  port map (
    sda => to_x01z(tb_sda),
    scl => to_x01z(tb_scl),
    clk => tb_clk,
    nena => tb_nena,
    rw => tb_rw,
    data_out => tb_data_out,
    data_in => tb_data_in,
    address => tb_address,
    busy => tb_busy
  );
  
  UUT: entity work.i2c_target(rtl)
  port map (
    sda => tb_sda,
    scl => tb_scl,
    clk => tb_clk,
    nen => tb_nen
  );

  tb_clk <= not tb_clk after TB_SYSTEM_CLK_PERIOD / 2;
  tb_sda <= 'H';
  tb_scl <= 'H';
  
  -- process
  -- begin
    -- wait for 85080 ns;
    -- tb_sda <= '0';
    -- wait for 10095 ns;
    -- tb_sda <= 'H';
    -- wait for 99825 ns;
    -- tb_sda <= '0';
    -- wait for 5000 ns;
    -- tb_sda <= 'H';
    -- 195000 ns para ack wr
    -- wait;
  -- end process;
  
  -- process
  -- begin
    -- wait for 95075 ns;
    -- tb_scl <= '0';
    -- wait for 20000 ns;
    -- tb_scl <= 'H';
    -- wait;
  -- end process;
  
  -- process
  -- begin
    -- wait for 89975 ns;
    -- tb_sda <= '0';
    -- 96975
    -- wait for 7000 ns;
    -- tb_sda <= 'H';
    -- wait;
  -- end process;

end architecture sim;