;====================================================================
; Power supply time limiter
;
; Created:   2018-12-12
; Processor: ATtiny13
; Compiler:  AVRASM (Proteus)
;====================================================================

; CONSTANTS
.equ LedPin = $00
.equ OutPin = $01
.equ OutInvPin = $02
.equ ButtonPin = $03

; Output pins: LED, Output and Inverted Output
.equ PortConfig = (1 << LedPin) | (1 << OutPin) | (1 << OutInvPin)

; Timer configuration
.equ SleepConfig = $30
.equ Timer0Config1 = $04
.equ Timer0Config2 = $02

; Delays
.equ LedDelay = $05
.equ TimeDelay = $82 		; Approx. 30 minutes

; Port bits
.equ PressedBit = 0
.equ LedActiveBit = 1
.equ LoadOnBit = 2

; VARIABLES
.def SavedSREG = r1			; Saved SREG during interrupt handling
.def TempReg = r16			; Temp register for store configurations
.def TimeRegCount = r20		; Number of active 30 min intervals left
.def TimeRegHi = r21		; Main timer value (high)
.def TimeRegLo = r22		; Main timer value (low)
.def TickReg = r10			; Number of LED ticks
.def DelayReg = r18			; LED ticks intrval
.def FlagsReg = r17			; State flags

; RESET and INTERRUPT VECTORS
.org 0
      ; Reset Vector
      rjmp  Start
      
.org 3
      ; Timer0 overflow
      rjmp T0_ovf

; CODE SEGMENT
.cseg

T0_ovf:
      ; Save original SREG value
      in SavedSREG, SREG
      bst FlagsReg, LoadOnBit
      brtc T0_ovf_exit
      ; Decrement timer
      dec TimeRegLo
      brne T0_ovf_dec_delay
      ldi TimeRegLo, $ff
      mov TickReg, TimeRegCount
      dec TimeRegHi
      brne T0_ovf_dec_delay
      ; Decrement intervals count
      dec TimeRegCount
      ldi TimeRegHi, TimeDelay
      mov TickReg, TimeRegCount
      brne T0_ovf_dec_delay
      clr FlagsReg
      rjmp T0_ovf_exit
T0_ovf_dec_delay:
      ; Decrement LED blink rate
      tst DelayReg
      breq T0_ovf_dec_tick
      dec DelayReg
      cpi DelayReg, $02
      brsh T0_ovf_exit
      cbr FlagsReg, (1 << LedActiveBit)
      rjmp T0_ovf_exit
T0_ovf_dec_tick:
      ; Decrement LED blinks number
      tst TickReg
      breq T0_ovf_exit
      dec TickReg
      ldi DelayReg, LedDelay
      sbr FlagsReg, (1 << LedActiveBit)
      rjmp T0_ovf_exit
T0_ovf_exit:
      ; Restore SREG and exit
      out SREG, SavedSREG
      reti

Start:
      ; Setup port state
      ldi TempReg, PortConfig
      out DDRB, TempReg
      ldi TempReg, 0
      out PORTB, TempReg
      ; Setup sleep mode (TODO)
      ldi TempReg, SleepConfig
      out MCUCR, TempReg
      ; Setup Timer0
      ldi TempReg, Timer0Config1
      out TCCR0B, r16
      ldi TempReg, Timer0Config2
      out TIMSK0, TempReg
      ; Initialize data
      ldi FlagsReg, 0
      ldi TimeRegCount, 0
      
Loop:
      wdr
      ; LED
      bst FlagsReg, LedActiveBit
      brtc Loop_Clear_Led
      sbi PORTB, LedPin
      rjmp Loop_Control_Load
Loop_Clear_Led:
      cbi PORTB, LedPin
Loop_Control_Load:
      ; Set output pins if load active
      bst FlagsReg, LoadOnBit
      brtc Loop_Off_Load
      sbi PORTB, OutPin
      cbi PORTB, OutInvPin
      rjmp Loop_Check_Button
Loop_Off_Load:
      cbi PORTB, OutPin
      sbi PORTB, OutInvPin
      ; Load inactive - disable timer
      cli
Loop_Check_Button:
      ; Check button state
      sbic PINB, ButtonPin
      sbr FlagsReg, (1 << PressedBit)
      sbrc FlagsReg, PressedBit
      rjmp Loop_Check_Release
      rjmp  Loop
Loop_Check_Release:
      in TempReg, PINB
      bst TempReg, ButtonPin
      brts Loop
      ; Button is pressed and then relased
	  ; Activate load and increment time
      inc TimeRegCount
      ldi TimeRegHi, TimeDelay
      ldi TimeRegLo, $ff
      mov TickReg, TimeRegCount
      cbr FlagsReg, (1 << PressedBit)
      sbr FlagsReg, (1 << LoadOnBit)
      ; Enable timer
      sei
	  ; Continue activities
      rjmp Loop
