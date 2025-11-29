library ieee;
use ieee.std_logic_1164.all;

entity i2c_target is
  generic (
    DEVICE_ADDRESS : std_logic_vector(6 downto 0) := "1100000"
  );
  port(
    sda : inout std_logic := 'Z';
    scl : inout std_logic := 'Z';
    nen : in std_logic;
    clk : in std_logic
  );
end entity;

architecture rtl of i2c_target is
  type target_state_t is (idle, start_sym, listen_addr, hd_addr, ack_addr, hd_ack_addr);
  type start_stop_t is (idle, start_sym, wait_for_stop, stop_sym);
  signal target_state : target_state_t := idle;
  signal start_stop : start_stop_t := idle;
  signal start : std_logic := '1';
  signal stop : std_logic := '1';
  signal data_in : std_logic_vector(7 downto 0) := x"00";
begin
  
  start_stop_detection: process(sda, scl, clk)
  begin

    if nen = '0' then
      if rising_edge(clk) then
        
        case start_stop is
          
          when idle => 
            start_stop <= start_sym when to_x01z(sda) = '0' and to_x01z(scl) = '1' else idle;
            
          when start_sym => 
            start <= '0';
            start_stop <= wait_for_stop;
          
          when wait_for_stop => 
            start <= '1';
            start_stop <= stop_sym when to_x01z(scl) = '1' and to_x01z(sda) = '0' else wait_for_stop;
            
          when stop_sym => 
            stop <= '0' when to_x01z(scl) = '1' and to_x01z(sda) = '1' else '1';
            start_stop <= idle when to_x01z(scl) = '1' and to_x01z(sda) = '1' else wait_for_stop;
          
        end case;
        
      end if;
    end if;

  end process start_stop_detection;
  
  fsm: process(clk, scl, sda, nen)
    variable i : integer := 0;
  begin
    if rising_edge(clk) then
      case target_state is

        when idle => 
          target_state <= start_sym when start = '0' else idle;

        when start_sym => 
          target_state <= start_sym when to_x01z(scl) = '1' else listen_addr;
          
        when listen_addr => 
          if to_x01z(scl) = '1' then
            data_in(7 - i) <= to_x01z(sda);
            target_state <= hd_addr when i < 7 else ack_addr;
            i := i + 1 when i < 7 else 0;
          end if;
          
        when hd_addr => 
          target_state <= hd_addr when to_x01z(scl) = '1' else listen_addr;
          
        when ack_addr =>
          if data_in(7 downto 1) = DEVICE_ADDRESS then
            sda <= '0' when to_x01z(scl) = '0' else 'Z';
            target_state <= ack_addr when to_x01z(scl) = '1' else hd_ack_addr;
          else
            sda <= 'Z';
            target_state <= idle;
          end if;
          
        when hd_ack_addr => 
          if to_x01z(scl) = '0' then
            target_state <= idle;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;