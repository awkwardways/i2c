library ieee;
use ieee.std_logic_1164.all;

entity i2c_slave is
  port(
    sda : inout std_logic := 'Z';
    scl : inout std_logic := 'Z'
  );
end entity;

architecture rtl of i2c_slave is
  type i2c_state_t is (start_cond, stop_cond, transmission, idle);
  signal i2c_state : i2c_state_t := idle;
begin
  
  start_condition: process(sda, scl)
  begin
    if falling_edge(sda) and scl = '1' then
      i2c_state <= start_cond;
    end if;
  end process;

  stop_condition: process(sda, scl)
  begin
    if falling_edge(sda) and scl = '1' then
      i2c_state <= stop_cond; 
    end if;
  end process;

end architecture rtl;