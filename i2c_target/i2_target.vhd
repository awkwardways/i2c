library ieee;
use ieee.std_logic_1164.all;

entity i2c_target is
port (
  sda : inout std_logic := 'Z';
  scl : inout std_logic := 'Z';
  clk : in std_logic;
  en  : in std_logic   --Active low enable 
);
end entity i2c_target;

architecture rtl of i2c_target is
  signal edge_register : std_logic_vector(1 downto 0) := "11";
  signal start : std_logic := '1';
  signal stop  : std_logic := '1'; 
begin

  ststdet : process(sda, scl, clk, en)
  begin
    if en = '0' then
      if rising_edge(clk) then
        edge_register <= to_x01z(sda) & edge_register(1);
        start <= '0' when edge_register = "01" and to_x01z(scl) = '1' else '1';
        stop  <= '0' when edge_register = "10" and to_x01z(scl) = '1' else '1';
      end if;
    end if;
  end process ststdet;

end architecture rtl;