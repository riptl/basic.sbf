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
    # Revision date: Jun/13/2022. Ported to Solana.

    #
    # USER'S MANUAL:
    #
    # Line entry is done with instruction data, finish the line with Enter.
    # The first account stores the system state.
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
    # To run the current program:
    #   run
    #
    # Statements:
    #   var=expr        Assign expr value to var (a-z)
    #
    #   print expr      Print expression value, new line
    #   print expr#     Print expression value, continue
    #   print "hello"   Print string, new line
    #   print "hello"#  Print string, continue
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
    # Memory Map
    #
    # 0x1_0000_0000: Program code
    # 0x2_0000_0000: Stack
    # 0x3_0000_0000: Ptr to account
    # 0x3_0000_0008: Ptr to input cursor
    # 0x3_0000_0010: Line input buffer
    # 0x4_0000_0000: Program input

    # --------------------------------
    # Account data map
    #
    # 0x0000: Variables (0x100 bytes)
    # 0x0100: BASIC code

    # --------------------------------
    # Start of code
.text

.global entrypoint
entrypoint:
    r0 = r1                 # Pointer to metadata
    r1 = *(u64 *)(r0 + 0)   # Read number of accounts
    r0 += 8                 # Seek to accounts table

    if r1 > 0 goto 2f
    call abort              # Need at least one account
2:  r6 = r3
    # TODO account bounds checks
    r6 += 88                # Load pointer to account data
    r7 = 0x300000000 ll
    *(u64 *)(r7 + 0) = r6   # Store pointer to account data

0:  if r1 == 0 goto 1f      # Next account
    r1 -= 1

    r3 = *(u8 *)(r0 + 0)    # Is duplicate account?
    r0 += 8
    if r3 != 0xFF goto 0b

    r3 = *(u64 *)(r0 + 72)  # Read account data len
    r0 += r3                # Skip data and realloc padding
    r0 += 10331
    r0 >>= 3
    r0 <<= 3
    goto 0b
1:  r1 = *(u64 *)(r0 + 0)   # Read insn data len
    r1 = *(u64 *)(r0 + 8)
    r1 = *(u64 *)(r0 + 16)
    r1 = *(u64 *)(r0 + 0)
    r0 += 8                 # Point to insn data
    r1 += r0                # Point to end of insn data

    r7 = 0x300000010 ll         # Load pointer to input buffer
    *(u64 *)(r7 - 8) = r7       # Reset input cursor
    call read_number
    if r1 == 0 goto statement   # No Number of zero?
    exit

    #
    # Read decimal number from buffer
    #   r0 = line buffer
    #   r3 = number returned
    #
read_number:
    r1 = 0
0:  r3 = *(u8 *)(r0 + 0)    # Read digit
    r3 -= '0'
    if r3 > 9 goto return   # Digit valid?
    r1 *= 10                # Multiply by 10
    r1 += r3                # Add new digit
    goto 0b                 # Continue
return:
    exit                    # Return ptr to first non-digit

    #
    # Write decimal number to buffer
    #   r3 = number to write
    #
output_number:
    r6 = r3
    r3 /= 10                # Divide
    #r6 %= 10                # Get remainder
    .8byte 0x0000000a00000697
    *(u64 *)(r10 - 8) = r6  # Push remainder
    if r3 == 0 goto 1f
    call output_number      # Recurse to next lower digit
1:  r6 = *(u64 *)(r10 - 8)  # Pop remainder
    r6 += '0'               # Convert remainder to ASCII …

    #
    # Write character to output buffer
    #    r1 = character
    #
output:
    r3 = 0x300000008 ll
    r4 = *(u64 *)(r3 + 0)
    *(u8 *)(r4 + 0) = r1
    r4 += 1
    *(u64 *)(r3 + 0) = r4
    exit

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
2:  r0 = *(u64 *)(r10 - 8)  # Rewind to line begin
0:  w3 += 1
    r1 = *(u8 *)(r2 + 0)    # Get string length
    if r1 == 0 goto 1f      # If no match, probably var assignment
    r2 += 1                 # Avoid length byte
    call memcmp             # Compare statement to input
    r2 += r1                # Skip over mismatching bytes
    if r1 != 0 goto 2b      # No match, next
3:  call spaces_2           # Avoid spaces
    r4 = command_ptrs ll    # Load command ptr from list
    r3 <<= 3
    r4 += r3
    r4 = *(u64 *)(r4 + 0)
    .8byte 0x000000040000008d # callx r4 (LLVM AsmParser broken here)
    exit
1:  call get_variable
    r1 = *(u8 *)(r0 + 0)
    if r1 == '=' goto assignment

error:
    r1 = error_message ll
    r2 = 3
    call sol_log_           # Show error message
    call abort

stmt_print:
    r1 = *(u8 *)(r0 + 0)
    r0 += 1
    if r1 == '\n' goto flush
    if r1 != '"' goto 0f
1:  r1 = *(u8 *)(r0 + 0)
    r0 += 1
    if r1 == '"' goto flush
    call output
    goto 1b

0:  call expr               # Handle expression
    call output_number
    exit

flush:
    r1 = 0x300000010 ll
    r2 = *(u64 *)(r1 - 8)
    r2 -= r1
    call sol_log_
    exit

    #
    # Expression, first tier: addition & subtraction.
    #
expr:
    call expr1                  # Eval left expression
    *(u64 *)(r10 - 8) = r3      # Push left expression value
0:  if r1 == '-' goto 2f        # Jump to subtraction
    if r1 != '+' goto return    # Done if not addition

    call expr1_2                # Eval right expression
1:  r4 = *(u64 *)(r10 - 8)      # Pop left expression value
    r4 += r3                    # Addition
    goto 0b                     # Find more operators
    
2:  call expr1_2                # Eval right expression
    r3 = -r3                    # convert (r4 - r3) to (r4 + -r3)
    goto 1b                     # Go to addition branch

    #
    # Expression, second tier: division & multiplication.
    #
expr1_2:
    r0 += 1                     # Avoid operator
    r1 = *(u8 *)(r0 + 0)
expr1:
    call expr2                  # Eval left expression
    *(u64 *)(r10 - 8) = r3      # Push left expression value
0:  if r1 == '/' goto 1f        # Jump to division
    if r1 != '*' goto return    # Done if not multiplication

    call expr2_2                # Eval right expression
    r4 = *(u64 *)(r10 - 8)      # Pop left expression value
    r4 *= r3                    # Multiplication
    goto 0b                     # Find more operators

1:  call expr2_2                # Eval right expression
    r4 = *(u64 *)(r10 - 8)      # Pop left expression value
    r4 /= r3                    # Division
    goto 0b                     # Find more operators

    #
    # Expression, third tier: parentheses, numbers and vars.
    #
expr2_2:
    r0 += 1                     # Avoid operator
    r1 = *(u8 *)(r0 + 0)
expr2:
    call spaces                 # Jump spaces
    r0 += 1
    r1 = *(u8 *)(r0 + 0)        # Read character

    if r1 != '(' goto 0f        # Skip ahead if not opening parenthesis
    call expr                   # Process inner expr.
    if r1 != ')' goto error     # Expect closing parenthesis
    call spaces_2               # Avoid spaces after parenthesis

0:  if r1 >= 0x40 goto 1f       # Jump to variable
    r0 -= 1                     # Back one letter …
    call read_number            # … to read number
    goto spaces

1:  call get_variable_2         # Get variable address
    r4 = *(u64 *)(r2 + 0)       # Read variable
    exit

    #
    # Return address of variable from buffer.
    #    r2 = return variable address
    #
get_variable:
    r3 = *(u8 *)(r0 + 0)    # Read digit
    r0 += 1

    #
    # Return address of variable.
    #    r2 = return variable address
    #    r3 = variable char
    #
get_variable_2:
    r3 &= 0x1f              # Map ASCII to array index
    r3 <<= 3                # 8 byte stride
    r2 = 0x300000000 ll     # Load ptr to account ptr
    r2 = *(u64 *)(r2 + 0)   # Follow account ptr
    r2 += r3                # Seek to variable
    exit

    #
    # Evaluate expression and assign to given variable.
    #
assignment:
    call expr

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

    .align 8
command_ptrs:
    .8byte stmt_run
    .8byte stmt_print
    .8byte stmt_if
    .8byte stmt_goto

error_message:
    .ascii "@#!"    # Guess the words :P
