library ieee;
use ieee.std_logic_1164.all;

entity i2c_master is 
  generic(
    SYS_CLK_FREQUENCY : integer := 27e6;
    SCL_CLK_FREQUENCY : integer := 100e3
  );
  port(
    sys_clk : in std_logic;
    sda : inout std_logic := 'Z';
    scl : inout std_logic := 'Z';
    ena : in std_logic := '0';
    rw : in std_logic;
    address : in std_logic_vector(6 downto 0);
    data : in std_logic_vector(7 downto 0)
  );
end entity i2c_master;

architecture rtl of i2c_master is
  type i2c_state_t is (idle, start, addressing, wr_message, rd_message, acknowledge, rd_acknowledge, stop_symbol);
  constant SYS_PERIODS_IN_2_uS : integer := (SYS_CLK_FREQUENCY / SCL_CLK_FREQUENCY) / 5; 
  constant SYS_PERIODS_IN_SCL : integer := (SYS_CLK_FREQUENCY / SCL_CLK_FREQUENCY);
  signal i2c_state : i2c_state_t := idle;
  signal goto_stop : std_logic := '0';
  signal rw_latch : std_logic;
  signal rd_register : std_logic_vector(7 downto 0) := x"00";
begin

  process(ena, sys_clk)
    variable HD_STA_counter : integer := 0;
    variable SCL_counter : integer := 0;
    variable SDA_bit_counter : integer := 0;
    variable ACK_return : std_logic := '0'; --If '1' return to addressing, if '0' return to message
  begin
    if rising_edge(sys_clk) then
      case i2c_state is
        when idle => 
        if ena = '0' then
          sda <= 'Z';
          scl <= 'Z';
        else 
          sda <= '0';
          i2c_state <= start;
        end if;

        when start =>
        HD_STA_counter := HD_STA_counter + 1;
        if HD_STA_counter = (SYS_PERIODS_IN_2_uS) * 2 then
          scl <= '0';
          HD_STA_counter := 0;
          i2c_state <= addressing;
          rw_latch <= rw;
        end if;

        when addressing => 
        SCL_counter := SCL_counter + 1;
        --Generate SCL clock
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then 
          scl <= 'Z';
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          scl <= '0';
          SCL_counter := 0;
          if SDA_bit_counter = 8 then
            sda <= 'Z';
            i2c_state <= acknowledge;
            SDA_bit_counter := 0;
          end if;
        end if;

        --SDA timing
        if SCL_counter = SYS_PERIODS_IN_2_uS then
          if SDA_bit_counter < 7 then
            sda <= address(SDA_bit_counter);
          elsif SDA_bit_counter = 7 then
            sda <= 'Z' when rw_latch = '1' else '0';
          end if;
          SDA_bit_counter := SDA_bit_counter + 1;
        end if;

        when acknowledge => 
        SCL_counter := SCL_counter + 1;
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then
          scl <= 'Z';
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          scl <= '0';
          SCL_counter := 0;
          if sda = '0' and goto_stop = '0' then --acknowledge received 
            i2c_state <= rd_message when rw_latch = '1' else wr_message;
            sda <= 'Z';
          elsif sda = '0' and goto_stop = '1' then
            i2c_state <= stop_symbol;
            sda <= '0';
          else --nack received 
            i2c_state <= idle;
            scl <= 'Z';
          end if;
        end if;

        when wr_message => 
        SCL_counter := SCL_counter + 1;
        --Generate SCL clock
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then 
          scl <= 'Z';
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          scl <= '0';
          SCL_counter := 0;
          if SDA_bit_counter = 8 then
            sda <= 'Z';
            goto_stop <= not ena;
            i2c_state <= acknowledge;
            SDA_bit_counter := 0;
          end if;
        end if;

        --SDA timing
        if SCL_counter = SYS_PERIODS_IN_2_uS then
          if SDA_bit_counter < 8 then
            sda <= 'Z' when data(SDA_bit_counter) = '1' else '0'  ;
          end if;
          SDA_bit_counter := SDA_bit_counter + 1;
        end if;

        when rd_message => 
        SCL_counter := SCL_counter + 1;
        sda <= 'Z';
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then
          scl <= 'Z';
          if SDA_bit_counter < 8 then
            rd_register(SDA_bit_counter) <= sda;
            SDA_bit_counter := SDA_bit_counter + 1;
          end if;
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          scl <= '0';
          SCL_counter := 0;
          if SDA_bit_counter = 8 then
            i2c_state <= rd_acknowledge;
            SDA_bit_counter := 0;
          end if;
        end if;

        when rd_acknowledge => 
        SCL_counter := SCL_counter + 1;
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then
          scl <= 'Z';
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          scl <= '0';
          SCL_counter := 0;
          i2c_state <= rd_message when ena = '1' else stop_symbol;
          sda <= 'Z' when ena = '1' else '0';
        end if;

        if SCL_counter = SYS_PERIODS_IN_2_uS * 2 then 
          sda <= '0' when ena = '1' else 'Z';
        end if;

        when stop_symbol => 
        SCL_counter := SCL_counter + 1;
        if SCL_counter = SYS_PERIODS_IN_SCL / 2 then
          scl <= 'Z';
        elsif SCL_counter = SYS_PERIODS_IN_SCL then
          SCL_counter := 0;
          sda <= 'Z';
          i2c_state <= idle;
        end if;
      end case;
    end if;
  end process;
  
end architecture rtl;
