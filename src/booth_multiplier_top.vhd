----------------------------------------------------------------------------------
-- File: booth_multiplier_top.vhd
-- Description: Structural Top-Level module for the 16-bit Radix-4 Booth Multiplier.
--              Instantiates and interconnects the Control Unit (CU) and Execution Unit (EU).
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity booth_multiplier_top is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        multiplicand : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        multiplier   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ready        : out std_logic;
        done         : out std_logic;
        product      : out std_logic_vector((2 * DATA_WIDTH)-1 downto 0)
    );
end entity booth_multiplier_top;

architecture Structural of booth_multiplier_top is

    -- Component declaration for Control Unit (CU)
    component booth_radix4_cu is
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            start        : in  std_logic;
            count_zero   : in  std_logic;
            init_regs    : out std_logic;
            add_sub_en   : out std_logic;
            op_select    : out std_logic_vector(1 downto 0);
            shift_en     : out std_logic;
            done         : out std_logic;
            ready        : out std_logic
        );
    end component;

    -- Component declaration for Execution Unit (EU)
    component booth_radix4_eu is
        generic (
            DATA_WIDTH : integer := 16
        );
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            multiplicand : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            multiplier   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            init_regs    : in  std_logic;
            add_sub_en   : in  std_logic;
            shift_en     : in  std_logic;
            count_zero   : out std_logic;
            product      : out std_logic_vector((2 * DATA_WIDTH)-1 downto 0)
        );
    end component;

    -- Internal interconnection signals
    signal sig_count_zero  : std_logic;
    signal sig_init_regs   : std_logic;
    signal sig_add_sub_en  : std_logic;
    signal sig_op_select   : std_logic_vector(1 downto 0);
    signal sig_shift_en    : std_logic;

begin

    -- Instantiate Control Unit (CU)
    CU_INST : booth_radix4_cu
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            count_zero   => sig_count_zero,
            init_regs    => sig_init_regs,
            add_sub_en   => sig_add_sub_en,
            op_select    => sig_op_select,
            shift_en     => sig_shift_en,
            done         => done,
            ready        => ready
        );

    -- Instantiate Execution Unit (EU)
    EU_INST : booth_radix4_eu
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            multiplicand => multiplicand,
            multiplier   => multiplier,
            init_regs    => sig_init_regs,
            add_sub_en   => sig_add_sub_en,
            shift_en     => sig_shift_en,
            count_zero   => sig_count_zero,
            product      => product
        );

end architecture Structural;