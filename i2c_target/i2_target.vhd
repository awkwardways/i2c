library ieee;
use ieee.std_logic_1164.all;

entity i2c_target is
generic (
  TARGET_ADDRESS : std_logic_vector(6 downto 0) := 7x"08"
);
port (
  data_in : in std_logic_vector(7 downto 0) := x"00";
  data_out : out std_logic_vector(7 downto 0) := x"00";
  sda : inout std_logic := 'Z';
  scl : inout std_logic := 'Z';
  clk : in std_logic;
  en  : in std_logic   --Active low enable 
);
end entity i2c_target;

architecture rtl of i2c_target is
  type target_state_t is (standby, listen_addr, mode, write_ack, read_ack, transfer, receive);
  signal target_state : target_state_t := standby;
  signal sda_edge_register : std_logic_vector(1 downto 0) := "11";
  signal scl_edge_register : std_logic_vector(1 downto 0) := "11";
  signal start : std_logic := '1';
  signal stop  : std_logic := '1'; 
  signal op_mode : std_logic := '1';
  signal data_reg : std_logic_vector(7 downto 0) := x"ff";
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
    variable address_bit : integer := 6;
    variable data_bit    : integer := 0;
  begin
  
    if en = '0' then
      if rising_edge(clk) then
        scl_edge_register <= to_x01z(scl) & scl_edge_register(1);
          if stop = '0' then
            target_state <= standby;
        end if;
        case target_state is
          
          when standby =>
            target_state <= standby when start = '1' else listen_addr;
            
          when listen_addr =>
            if scl_edge_register = "10" then 
              if TARGET_ADDRESS(address_bit) = to_x01z(sda) then
                target_state <= mode when address_bit = 0 else listen_addr;
                address_bit := address_bit - 1 when address_bit > 0 else 6;
              else 
                address_bit := 6;
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
            elsif scl_edge_register = "10" then
              data_reg <= data_in when op_mode = '1' else x"ff";
              target_state <= transfer when op_mode = '1' else receive;
              data_bit := 0;
            end if;
            
          when transfer =>
            if scl_edge_register = "01" then
              sda <= data_reg(0);
              data_reg <= '0' & data_reg(7 downto 1);
              data_bit := data_bit + 1; 
            elsif scl_edge_register = "10" then
              target_state <= transfer when data_bit < 8 else read_ack;
            end if;
            
          when receive => 
            if scl_edge_register = "10" then
              data_reg <= data_reg(6 downto 0) & to_x01z(sda);
              data_bit := data_bit + 1;
            elsif scl_edge_register = "01" then
              sda <= 'Z' when data_bit < 8 else '0';
              target_state <= receive when data_bit < 8 else write_ack;
              data_out <= data_out when data_bit < 8 else data_reg;
            end if;
            
          when read_ack => 
            if scl_edge_register = "01" then
              sda <= 'Z';
            elsif scl_edge_register = "10" then
              target_state <= standby when to_x01z(sda) = '1' else transfer;
              data_reg <= data_in;
              data_bit := 0;
            end if;
        end case;
        
      end if;
    end if;
  
  end process main;
  
end architecture rtl;