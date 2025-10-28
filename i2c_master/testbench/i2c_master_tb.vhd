library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_tb is
end entity i2c_master_tb;

architecture sim of i2c_master_tb is
  constant CLK_FREQUENCY_TB : integer := 1e6;
  constant CLK_PERIOD_TB : time := 1000 ms / CLK_FREQUENCY_TB;
  signal ena_tb : std_logic := '1';
  signal sys_clk_tb : std_logic := '0';
  signal sda_tb : std_logic := 'H';
  signal scl_tb : std_logic := 'H';
  signal rw_tb : std_logic := '1';
  signal address_tb : std_logic_vector(6 downto 0) := "1010110"; 
  signal data_tb : std_logic_vector(7 downto 0) := "00110000";
begin

  UUT: entity work.i2c_master(rtl)
  generic map(
    SYS_CLK_FREQUENCY => CLK_FREQUENCY_TB,
    SCL_CLK_FREQUENCY => 100000
  )
  port map(
    sda => sda_tb,
    scl => scl_tb,
    sys_clk => sys_clk_tb,
    ena => ena_tb,
    rw => rw_tb,
    address => address_tb,
    data => data_tb
  );

  sys_clk_tb <= not sys_clk_tb after CLK_PERIOD_TB / 2;
  sda_tb <= 'H';
  scl_tb <= 'H';

  process
  begin
    wait for 86500 ns;
    sda_tb <= '0';
    ena_tb <= '0';
    wait for 10000 ns;
    sda_tb <= 'H';
    wait for 40000 ns;
    sda_tb <= '0';
    wait for 10000 ns;
    sda_tb <= 'H';
    wait for 10000 ns;
    sda_tb <= '0';  
    wait for 10000 ns;
    sda_tb <= 'H';
    wait;
  end process;



end architecture sim;