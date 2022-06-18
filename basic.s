    #
    # solBASIC – eBPF-based BASIC interpreter
    #
    # by Richard Patel
    # heavily inspired by bootBASIC from http://nanochess.org/
    #
    # (c) Copyright 2022 Richard Patel
    # (c) Copyright 2019-2020 Oscar Toledo G.
    #
    # Creation date: Jul/19/2019. 10pm to 12am.
    # Revision date: Jul/20/2019. 10am to 2pm.
    #                             Added assignment statement. list now
    #                             works. run/goto now works. Added
    #                             system and new.
    # Revision date: Jul/22/2019. Boot image now includes 'system'
    #                             statement.
    # Revision date: Jun/13/2022. Ported to Solana

    #
    # USER'S MANUAL:
    #
    # Line entry is done with instruction data, finish the line with Enter.
    # The first account stores the system state.
    #
    # Backspace can be used, don't be fooled by the fact
    # that screen isn't deleted (it's all right in the buffer).
    #
    # All statements must be in lowercase.
    #
    # Line numbers can be 1 to 999.
    #
    # 26 variables are available (a-z)
    #
    # Numbers (0-65535) can be entered and display as unsigned.
    #
    # To enter new program lines:
    #   10 print "Hello all!"
    #
    # To erase program lines:
    #   10
    #
    # To test statements directly (interactive syntax):
    #   print "Hello all!"
    #
    # To erase the current program:
    #   new
    #
    # To run the current program:
    #   run
    #
    # To list the current program:
    #   list
    #
    # To exit to command-line:
    #   system
    #
    # Statements:
    #   var=expr        Assign expr value to var (a-z)
    #
    #   print expr      Print expression value, new line
    #   print expr#     Print expression value, continue
    #   print "hello"   Print string, new line
    #   print "hello"#  Print string, continue
    #
    #   input var       Input value into variable (a-z)
    #
    #   goto expr       Goto to indicated line in program
    #
    #   if expr1 goto expr2
    #               If expr1 is non-zero then go to line,
    #               else go to following line.
    #
    # Examples of if:
    #
    #   if c-5 goto 20  If c isn't 5, go to line 20
    #
    # Expressions:
    #
    #   The operators +, -, / and * are available with
    #   common precedence rules and signed operation.
    #   Integer-only arithmetic.
    #
    #   You can also use parentheses:
    #
    #      5+6*(10/2)
    #
    #   Variables and numbers can be used in expressions.
    #
    #   The rnd function (without arguments) returns a
    #   value between 0 and 255.
    #
    # Sample program (counting 1 to 10):
    #
    # 10 a=1
    # 20 print a
    # 30 a=a+1
    # 40 if a-11 goto 20
    #
    # Sample program (Pascal's triangle, each number is the sum
    # of the two over it):
    #
    # 10 input n
    # 20 i=1
    # 30 c=1
    # 40 j=0
    # 50 t=n-i
    # 60 if j-t goto 80
    # 70 goto 110
    # 80 print " "#
    # 90 j=j+1
    # 100 goto 50
    # 110 k=1
    # 120 if k-i-1 goto 140
    # 130 goto 190
    # 140 print c#
    # 150 c=c*(i-k)/k
    # 160 print " "#
    # 170 k=k+1
    # 180 goto 120
    # 190 print
    # 200 i=i+1
    # 210 if i-n-1 goto 30
    #
    # Sample program of guessing the dice:
    #
    # 10 print "choose "#
    # 20 print "a number "#
    # 30 print "(1-6)"
    # 40 input a
    # 50 b=rnd
    # 60 b=b-b/6*6
    # 70 b=b+1
    # 80 if a-b goto 110
    # 90 print "good"
    # 100 goto 120
    # 110 print "miss"
    # 120 print b
    #

    # --------------------------------
    # Start of code
.text

.global entrypoint
entrypoint:

main_loop:
    call get_input
    *(u64 *)(r10 - 8) = r1
0:
    call read_number
    if r1 == 0 goto statement       # No Number of zero?
    exit

get_input:
    r0 = 0x400000000 ll
    r1 = *(u64 *)(r0 + 0)   # Read number of accounts
    r0 += 8                 # Seek to accounts table
0:
    if r1 == 0 goto 1f      # Next account
    r1 -= 1

    r3 = *(u8 *)(r0 + 0)    # Is duplicate account?
    r0 += 8
    if r3 == 0xFF goto 0b

    r3 = *(u64 *)(r3 + 80)  # Read account data len
    r0 += r3                # Skip data and realloc padding
    r0 += 10103
    r0 >>= 3
    r0 <<= 3
    goto 0b
1:
    r1 = *(u64 *)(r0 + 0)   # Read insn data len
    r0 += 8                 # Point to insn data
    r1 += r0                # Point to end of insn data
    exit

read_number:
    r1 = 0
0:
    r3 = *(u8 *)(r0 + 0)    # Read digit
    r3 -= '0'
    if r3 > 9 goto return   # Digit valid?
    r1 *= 10                # Multiply by 10
    r1 += r3                # Add new digit
    goto 0b                 # Continue
return:
    exit                    # Return ptr to first non-digit

    #
    # Interpret statement
    #    r0 = line buffer
    #
statement:
    call spaces             # Avoid spaces

    r1 = *(u8 *)(r0 + 0)    # Return if line empty
    if r1 == 0 goto return
    if r1 == '\n' goto return

    # Scan command table
    *(u64 *)(r10 - 8) = r0  # Backup line ptr
    r2 = command_strs ll    # Load ptr to command strs
    w3 = -1                 # Command index
2:
    r0 = *(u64 *)(r10 - 8)  # Rewind to line begin
0:
    w3 += 1
    r1 = *(u8 *)(r2 + 0)    # Get string legnth
    if r1 == 0 goto 1f      # If no match, probably var assignment
    r2 += 1                 # Avoid length byte
    call memcmp             # Compare statement to input
    if r1 != 0 goto 2b      # No match, next
3:
    call spaces_2           # Avoid spaces
    r4 = command_ptrs ll    # Load command ptr from list
    r3 <<= 3
    r4 += r3
    .8byte 0x000000040000008d # callx r4
    # callx r4
    exit
1:
    call get_variable
    r1 = *(u8 *)(r0 + 0)
    if r1 == '=' goto assignment

error:
    r1 = error_message ll
    r2 = 4
    call sol_log_           # Show error message
    goto main_loop          # Exit to main loop

stmt_print:
    r1 = *(u8 *)(r0 + 0)
    r0 += 1
    if r1 == '\n' goto new_line
    if r1 != '"' goto 0f
1:
    r1 = *(u8 *)(r0 + 0)
    r0 += 1
    if r1 != '"' goto 0f

0:
    call expr               # Handle expression
    call output_number
    exit

new_line:
    r1 = newline_string ll
    r2 = 1
    call sol_log_
    exit

expr:
output_number:
get_variable:
assignment:
stmt_run:
stmt_if:
stmt_goto:
    exit

spaces_2:
    r0 += 1
spaces:
    r1 = *(u8 *)(r0 + 0)
    if r1 == ' ' goto spaces_2
    exit

    #
    # Compares two pieces of memory.
    #    r0: ptr   r1: len   r2: ptr
    # Returns r1 == 0 if equal.
    #
memcmp:
    if r1 == 0 goto return
    r4 = *(u8 *)(r0 + 0)
    r5 = *(u8 *)(r2 + 0)
    if r4 != r5 goto return
    r0 += 1
    r1 -= 1
    r2 += 1
    goto memcmp

    # --------------------------------
    # Start of read-only data
.section .rodata

command_strs:
    .byte 3
    .ascii "run"
    .byte 5
    .ascii "print"
    .byte 2
    .ascii "if"
    .byte 4
    .ascii "goto"
    .byte 0

command_ptrs:
    .align 8
    .8byte stmt_run
    .8byte stmt_print
    .8byte stmt_if
    .8byte stmt_goto

error_message:
    .ascii "@#!"    # Guess the words :P
newline_string:
    .ascii "\n"
