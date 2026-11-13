----------------------------------------------------------------------------------
-- File: math_unit_top.vhd
-- Description: Integrated Structural Top-Level Arithmetic Unit (16-bit).
--              Combines the 16-bit Radix-4 Booth Multiplier and the 16-bit
--              Signed Radix-4 SRT Divider selected via 'op_sel':
--                - op_sel = '0': Multiplication -> result(31:0) = Product
--                - op_sel = '1': Division       -> result(31:16) = Remainder,
--                                                  result(15:0)  = Quotient
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity math_unit_top is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        op_sel       : in  std_logic; -- '0': Multiply (Booth Radix-4), '1': Divide (SRT Radix-4)
        operand_a    : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Multiplicand or Dividend
        operand_b    : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Multiplier or Divisor
        ready        : out std_logic;
        done         : out std_logic;
        div_zero_err : out std_logic;
        result       : out std_logic_vector((2 * DATA_WIDTH)-1 downto 0)
    );
end entity math_unit_top;

architecture Structural of math_unit_top is

    -- Component declaration for 16-bit Radix-4 Booth Multiplier
    component booth_multiplier_top is
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
    end component;

    -- Component declaration for 16-bit Radix-4 SRT Divider
    component srt_divider_top is
        generic (
            DATA_WIDTH : integer := 16
        );
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            start        : in  std_logic;
            dividend     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            divisor      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            ready        : out std_logic;
            done         : out std_logic;
            div_zero_err : out std_logic;
            quotient     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            remainder    : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Internal routing signals for Multiplier unit
    signal sig_mult_start : std_logic;
    signal sig_mult_ready : std_logic;
    signal sig_mult_done  : std_logic;
    signal sig_mult_prod  : std_logic_vector((2 * DATA_WIDTH)-1 downto 0);

    -- Internal routing signals for Divider unit
    signal sig_div_start  : std_logic;
    signal sig_div_ready  : std_logic;
    signal sig_div_done   : std_logic;
    signal sig_div_err    : std_logic;
    signal sig_div_quot   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sig_div_rem    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sig_div_packed : std_logic_vector((2 * DATA_WIDTH)-1 downto 0);

begin

    -- Demultiplex start pulse based on selected operation
    sig_mult_start <= start when op_sel = '0' else '0';
    sig_div_start  <= start when op_sel = '1' else '0';

    -- Instantiate Radix-4 Booth Multiplier
    MULT_UNIT : booth_multiplier_top
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => sig_mult_start,
            multiplicand => operand_a,
            multiplier   => operand_b,
            ready        => sig_mult_ready,
            done         => sig_mult_done,
            product      => sig_mult_prod
        );

    -- Instantiate Radix-4 SRT Divider
    DIV_UNIT : srt_divider_top
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => sig_div_start,
            dividend     => operand_a,
            divisor      => operand_b,
            ready        => sig_div_ready,
            done         => sig_div_done,
            div_zero_err => sig_div_err,
            quotient     => sig_div_quot,
            remainder    => sig_div_rem
        );

    -- Pack remainder (upper 16 bits) and quotient (lower 16 bits) into 32-bit bus
    sig_div_packed <= sig_div_rem & sig_div_quot;

    -- Output multiplexers controlled by op_sel
    ready        <= sig_mult_ready when op_sel = '0' else sig_div_ready;
    done         <= sig_mult_done  when op_sel = '0' else sig_div_done;
    div_zero_err <= '0'            when op_sel = '0' else sig_div_err;
    result       <= sig_mult_prod  when op_sel = '0' else sig_div_packed;

end architecture Structural;