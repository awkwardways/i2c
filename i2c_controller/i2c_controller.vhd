library ieee;
use ieee.std_logic_1164.all;

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
    busy : out std_logic := '1';
    data_out : out std_logic_vector(7 downto 0);  --Data received from target
    data_in : in std_logic_vector(7 downto 0);  --Data to be sent from controller to target
    address : in std_logic_vector(6 downto 0)   --Target address
  );  
end entity i2c_controller;

architecture rtl of i2c_controller is 
  type scl_fsm_state_t is (scl_idle, pull_line, release_line, stretch);
  type sda_fsm_state_t is (sda_idle, repeat_start_sym, set_up_start_sym, start_sym, addressing, addr_ack, set_sda_rd, hd_sda_rd, set_ack_rd, hd_ack_rd_low, hd_ack_rd_hi, sda_wr, ack_wr, stop_sym_scl, stop_sym_sda, buffer_time);
  constant SYSTEM_CLK_CYCLES_IN_I2C_SPEED : integer := (SYSTEM_CLK_FREQUENCY) / (I2C_BUS_KBITPS);
  constant SYSTEM_CLK_CYCLES_IN_2US : integer := SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 5;
  signal scl_en : std_logic := '1';
  signal trans : std_logic := '1';
  signal scl_state : scl_fsm_state_t := scl_idle;
  signal sda_state : sda_fsm_state_t := sda_idle;
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
          
          trans <= '0' when scl_counter = (SYSTEM_CLK_CYCLES_IN_2US - 1) else '1';
          
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
    variable su_sta : integer := 0;
    variable su_sto : integer := 0;
    variable buf : integer := 0;
    variable i : integer := 0;
  begin
    if rising_edge(clk) then
        case sda_state is

        when sda_idle => 
          sda <= '0' when nena = '0' else 'Z';
          sda_state <= start_sym when nena = '0' else sda_idle;
          busy <= nena;
          address_latch <= address when nena = '0' else (others => '0');
          wr_data_latch <= data_in when nena = '0' else (others => '0');
          rw_latch <= rw when nena = '0' else '0';
          
        when start_sym => 
          hd_sta := hd_sta + 1;
          if hd_sta = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) - 1 then
            hd_sta := 0;
            scl_en <= '0';
            sda_state <= addressing;
          end if;
        
        when addressing => 
          if scl_state = pull_line and trans = '0' then
            sda <= address_latch(i) when i < 7 else 
                   rw when i = 7 else 'Z';
            sda_state <= addressing when i <= 7 else addr_ack;
            i := i + 1 when i <= 7 else 0;
          end if;
          
          when addr_ack =>
            if scl_state = release_line then
              if sda = '0' then --ack
                sda_state <= sda_wr;
              else --nack
                sda_state <= repeat_start_sym;
              end if;
            end if;
            
          when sda_wr => 
            if scl_state = pull_line and trans = '0' then
              sda <= wr_data_latch(i) when i < 8 else 'Z';
              sda_state <= sda_wr when i < 8 else ack_wr;
              i := i + 1 when i < 8 else 0;
            end if;
          
          when ack_wr => 
            if scl_state = release_line then
              sda_state <= stop_sym_sda;
            end if;
          
          when repeat_start_sym => 
            if scl_state = stretch then
              scl_en <= '1';
              sda_state <= set_up_start_sym;
            end if;
            
          when set_up_start_sym => 
            su_sta := su_sta + 1;
            if su_sta = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) - 1 then
              su_sta := 0;
              sda_state <= sda_idle;
              sda <= '0';
            end if;

          when stop_sym_sda => 
            if scl_state = stretch then
              scl_en <= '1';
              sda_state <= stop_sym_scl;
            elsif scl_state = pull_line and trans = '0' then
              sda <= '0';
            end if;
            
          when stop_sym_scl => 
            su_sto := su_sto + 1;
            if su_sto = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) - 1 then 
              su_sto := 0;
              sda_state <= buffer_time;
              sda <= 'Z';
            end if;
            
          when buffer_time => 
            buf := buf + 1;
            if buf = (SYSTEM_CLK_CYCLES_IN_I2C_SPEED / 2) - 1 then
              sda_state <= sda_idle;
              buf := 0;
            end if;
          when others => sda_state <= sda_idle;
        end case;
        
    end if; 
  end process;
end architecture;


