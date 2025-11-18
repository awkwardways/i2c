library ieee;
use ieee.std_logic_1164.all;


/*

  QUITAR IF NENA = '0'.
  ROMPE EL ESTADO STOP_SYM!!!1! :O

*/


entity i2c_controller is
  generic (
    SYSTEM_CLK_FREQUENCY : integer := 27e6;
    I2C_BUS_KBITPS : integer := 100000
  );
  port (
    sda : inout std_logic := 'Z';
    scl : inout std_logic := 'Z';
    clk : in std_logic;  --System clock
    nena : in std_logic;  --Enable i2c controller. Active low
    rw  : in std_logic;  --Read/write pin. As stated in the i2c-bus specification, write is active low, and read is active high
    data_out : out std_logic_vector(7 downto 0);  --Data received from target
    data_in : in std_logic_vector(7 downto 0);  --Data to be sent from controller to target
    address : in std_logic_vector(6 downto 0)   --Target address
  );  
end entity i2c_controller;

architecture rtl of i2c_controller is 
  type scl_fsm_state_t is (scl_idle, pull_line, release_line, stretch);
  type sda_fsm_state_t is (sda_idle, start_sym, set_sda_addr, hd_sda_addr, addr_ack, set_sda_rd, hd_sda_rd, set_ack_rd, hd_ack_rd_low, hd_ack_rd_hi, set_sda_wr, hd_sda_wr, ack_wr, stop_sym_scl, stop_sym_sda);
  signal scl_en : std_logic := '1';
  signal scl_state : scl_fsm_state_t := scl_idle;
  signal sda_state : sda_fsm_state_t := sda_idle;
  -- type controller_state_t is (scl_idle, start_condition, addressing, addr_ack, wr_data, rd_data, wr_ack, rd_ack, scl_hold, stop_symbol);
  constant SYSTEM_CLK_CYCLES_IN_I2C_SPEED : integer := (SYSTEM_CLK_FREQUENCY) / (I2C_BUS_KBITPS);
  constant SYSTEM_CLK_CYCLES_IN_2US : integer := SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 5;
  -- signal controller_state : controller_state_t := scl_idle;
  signal wr_data_latch : std_logic_vector(7 downto 0) := x"00";
  signal address_latch : std_logic_vector(6 downto 0) := 7x"00";
  signal rw_latch : std_logic;

begin
  
  -- scl_en <= nena;

  scl_fsm: process(clk, scl_en, scl)
    variable scl_counter : integer := 0;
  begin
    if rising_edge(clk) then
      if scl_en = '0' then
        case scl_state is
        when scl_idle => 
          scl_counter := 0;
          scl <= '0';
          scl_state <= pull_line;
        
        when pull_line => 
          scl_counter := scl_counter + 1;
          scl <= '0' when scl_counter < (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) else 'Z';
          scl_state <= pull_line when scl_counter < (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) else stretch;
          
        when stretch => 
          scl_counter := scl_counter when scl = '0' else (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) + 1;
          scl_state <= stretch when scl = '0' else release_line;
          
        when release_line => 
          scl_counter := scl_counter + 1;
          scl <= 'Z' when scl_counter < (SYSTEM_CLK_CYCLES_IN_I2C_SPEED) else '0';
          scl_state <= release_line when scl_counter < (SYSTEM_CLK_CYCLES_IN_I2C_SPEED) else pull_line;
          if scl_counter = SYSTEM_CLK_CYCLES_IN_I2C_SPEED then
            scl_counter := 0;
          end if;
        end case;
      else
        scl_state <= scl_idle;
        scl <= 'Z';
      end if;
    end if;
  end process;

  sda_fsm: process(clk, nena, scl, sda)
    variable hd_sta : integer := 0;
    variable su_sto : integer := 0;
    variable ack : std_logic := '0';
    variable i : integer := 0;
  begin
    if rising_edge(clk) then
      case sda_state is 
      when sda_idle => 
        if nena = '0' then
          sda <= '0';
          sda_state <= start_sym;
        else
          sda <= 'Z';
          sda_state <= sda_state;
        end if;
        
      when start_sym => 
        hd_sta := hd_sta + 1;
        sda <= '0';
        if hd_sta = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) then
          scl_en <= '0';
          hd_sta := 0;
          sda_state <= set_sda_addr;
          address_latch <= address;
          wr_data_latch <= data_in;
          rw_latch <= rw;
        end if;

      when set_sda_addr => 
        if scl = '0' then
          if i < 7 then
            sda <= address_latch(i);
            sda_state <= hd_sda_addr;
            i := i + 1;
          elsif i = 7 then
            sda <= rw_latch;
            sda_state <= hd_sda_addr;
            i := i + 1;
          else 
            sda <= 'Z';
            sda_state <= addr_ack;
            i := 0;
          end if;
        end if;
      
      when hd_sda_addr =>
        sda_state <= set_sda_addr when scl = '1' else hd_sda_addr;
      
      when addr_ack => 
        if scl = '1' then
          if sda = '0' then
            sda_state <= hd_sda_rd when rw = '1' else set_sda_wr;
          else 
            scl_en <= '1';
            sda_state <= start_sym;
          end if;
        end if;
  
      when set_sda_wr => 
        if scl_state = pull_line then
          if i < 8 then
            sda <= wr_data_latch(i);
            sda_state <= hd_sda_wr;
            i := i + 1;
          else 
            sda <= 'Z';
            sda_state <= ack_wr;
            i := 0;
          end if;
        end if;
        
      when hd_sda_wr =>
        sda_state <= set_sda_wr when scl = '1' else hd_sda_wr;
  
      when ack_wr => 
        if scl = '1' then
          if sda = '0' then
            sda_state <= stop_sym_scl when nena = '1' else set_sda_wr;
          else
            scl_en <= '1';
            sda_state <= start_sym;
          end if;
        end if;
  
      when set_sda_rd => 
        if scl_state = release_line then
          if i < 8 then
            data_out(7 - i) <= sda;
            sda_state <= hd_sda_rd;
            i := i + 1;
          end if;
        end if;
        
      when hd_sda_rd => 
        if i >= 8 then
          sda_state <= set_ack_rd;
          i := 0;
        else
          sda_state <= hd_sda_rd when scl = '1' else set_sda_rd;
        end if;
        
      when set_ack_rd => 
        if scl = '0' then
          sda <= 'Z' when nena = '1' else '0';
          ack := nena;
          sda_state <= hd_ack_rd_low;
        end if;
        
      when hd_ack_rd_low => 
        sda_state <= hd_ack_rd_low when scl = '0' else hd_ack_rd_hi;
        
      when hd_ack_rd_hi => 
        if scl = '0' then
          sda_state <= stop_sym_scl when ack = '1' else set_sda_rd;
          sda <= 'Z';
        end if;
      
      when stop_sym_scl => 
        sda <= '0';
        if scl = '1' then 
          scl_en <= '1';  --Disable scl
          su_sto := 1;
          sda_state <= stop_sym_sda;
        end if;
  
      when stop_sym_sda => 
        su_sto := su_sto + 1;
        if su_sto = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) then
          sda <= 'Z';
          sda_state <= sda_idle;
        end if;
  
      when others => sda_state <= sda_idle;
      end case;
    end if;
  end process;
end architecture;


