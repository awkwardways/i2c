library ieee;
use ieee.std_logic_1164.all;

entity i2c_target is
generic (
  TARGET_ADDRESS : std_logic_vector(6 downto 0) := 7x"08"
);
port (
  sda : inout std_logic := 'Z';
  scl : inout std_logic := 'Z';
  clk : in std_logic;
  en  : in std_logic   --Active low enable 
);
end entity i2c_target;

architecture rtl of i2c_target is
  type target_state_t is (standby, listen_addr, mode, write_ack);
  signal target_state : target_state_t := standby;
  signal sda_edge_register : std_logic_vector(1 downto 0) := "11";
  signal scl_edge_register : std_logic_vector(1 downto 0) := "11";
  signal start : std_logic := '1';
  signal stop  : std_logic := '1'; 
  signal op_mode : std_logic := '1';
begin

  ststdet : process(sda, scl, clk, en, sda_edge_register)
  begin
    if en = '0' then
      if rising_edge(clk) then
        sda_edge_register <= to_x01z(sda) & sda_edge_register(1);
        start <= '0' when sda_edge_register = "01" and to_x01z(scl) = '1' else '1';
        stop  <= '0' when sda_edge_register = "10" and to_x01z(scl) = '1' else '1';
      end if;
    end if;
  end process ststdet;

  main : process(sda, scl, clk, en, scl_edge_register)
    variable i : integer := 6;
  begin
  
    if en = '0' then
      if rising_edge(clk) then
        scl_edge_register <= to_x01z(scl) & scl_edge_register(1);
        case target_state is
          
          when standby =>
            target_state <= standby when start = '1' else listen_addr;
            
          when listen_addr =>
            if scl_edge_register = "10" then 
              if TARGET_ADDRESS(i) = to_x01z(sda) then
                target_state <= mode when i = 0 else listen_addr;
                i := i - 1 when i > 0 else 6;
              else 
                i := 6;
                target_state <= standby;
              end if;
            end if;
          
          when mode => 
            if scl_edge_register = "10" then
              op_mode <= to_x01z(sda);
              target_state <= write_ack; 
            end if;

          when write_ack => 
            if scl_edge_register = "01" then 
              sda <= '0';
            end if;
        end case;
        
      end if;
    end if;
  
  end process main;
  
end architecture rtl;