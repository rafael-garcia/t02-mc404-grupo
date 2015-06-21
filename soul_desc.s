@Mudar para nivel usuario
@Chamar codigo de controle

.org 0x0
.section .iv,"a"

_start:     

interrupt_vector:
    b RESET_HANDLER
.org 0x08
    b SVC_HANDLER

.set DATA_BASE_ADDR, 0x77801800 @ Parte da memoria destinada aos dados (definido no Makefile do projeto)

@Configuracao de pilhas - cada uma tem 0x800 enderecos = 2KB
.set USER_STACK,       DATA_BASE_ADDR
.set FIQ_STACK,        0x77801000
.set SUPERVISOR_STACK, 0x77800800
.set ABORT_STACK,      0x77800000
.set IRQ_STACK,        0x777FF800
.set LOCO_STACK,       0x777FF000

@ Configura enderecos GPIO (entradas e saidas)
.set REG_DR,           0x53F84000     @Data Register
.set REG_GDIR,         0x53F84004     @Direction Register (n-bit = 0 -> entrada, n-bit = 1 -> saida)
.set REG_PSR,          0x53F84008     @Pad status register - apenas para leitura

@ Configuracao de mascaras para o GPIO
.set MASK_GDIR,                  0b11111111111111000000000000111110 @ 1 = saida, 0 = entrada

.set MASK_MOTOR_0,                0b00000001111110000000000000000000 @ 7 bits(18:24) = 1+6 bits = write + speed[0:5]
.set MASK_MOTOR_0_WRITE,          0b00000000000001000000000000000000
.set MASK_MOTOR_1,                0b11111100000000000000000000000000 @ MSB 7 bits = 1+6 bits = write + speed[0:5]
.set MASK_MOTOR_1_WRITE,          0b00000010000000000000000000000000
.set MASK_MOTORS,                 0b11111101111110000000000000000000 @ MSB 14 bits = 1+6 bits para cada motor
.set MASK_MOTORS_WRITE,           0b00000010000001000000000000000000
.set MASK_SONAR_MUX,              0b00000000000000000000000000111110
.set MASK_SIG_HIGH_TRIGGER,       0b00000000000000000000000000000010
.set MASK_SIG_LOW_TRIGGER,        0b11111111111111111111111111111101
.set MASK_FLAG,                   0b00000000000000000000000000000001
.set MASK_SONAR_DATA,             0b00000000000000111111111111000000

@ Configura enderecos TZIC
.set TZIC_BASE,        0x0FFFC000
.set TZIC_INTCTRL,     0x0
.set TZIC_INTSEC1,     0x84 
.set TZIC_ENSET1,      0x104
.set TZIC_PRIOMASK,    0xC
.set TZIC_PRIORITY9,   0x424

@ Configura enderecos GPT
.set GPT_CR,           0x53FA0000
.set GPT_PR,           0x53FA0004
.set GPT_SR,           0x53FA0008
.set GPT_OCR1,         0x53FA0010
.set GPT_IR,           0x53FA000C

@ Configura valores das syscalls
.set ID_READ_SONAR,       08
.set ID_SET_MOTOR_SPEED,  09
.set ID_SET_MOTORS_SPEED, 10
.set ID_GET_TIME,         11
.set ID_SET_TIME,         12
.set ID_SET_ALARM,        13

@ Configura frequencia para fazer a contagem (system time)
.set TIME_SZ,          100


@ Configura valor maximo de velocidade (sao 6 bits = 0b111111 = #63)
.set MAX_SPEED_MOTOR   63

@ Configura valor de iteracoes para aguardar algo entre 10-15 ms
.set LOOP_WAITING_VAL  15000

.org 0x100
.text
.align 4
@ Zera o contador de tempo
  ldr r2, =CONTADOR_TEMPO
  mov r0, #0
  str r0, [r2]

RESET_HANDLER:
    @Set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

@ enderecos encontrados no datasheet IMX53-gpt.pdf na pagina do lab08 (tabela da pag 06)
SET_GPT:     
    ldr r3, =GPT_CR
    mov r4, #0x00000041         @ clock_src periferico
    str r4, [r3]

    ldr r3, =GPT_PR
    mov r4, #0                  @ zera o prescaler
    str r4, [r3]

    ldr r3, =GPT_OCR1
    ldr r4, =TIME_SZ             @ conta ate a constante definida
    str r4, [r3]

    ldr r3, =GPT_IR
    mov r4, #1                  @ habilita interrupcao do tipo Output Compare Channel 1
    str r4, [r3]

SET_TZIC:
    @ Liga o controlador de interrupcoes
    @ R1 <= TZIC_BASE

    ldr r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov r0, #(1 << 7)
    str r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov r0, #(1 << 7)
    str r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov r0, #1
    str r0, [r1, #TZIC_INTCTRL]

SET_STACKS:

    @instrucao msr - habilita interrupcoes
    msr CPSR_c, #0xDF       @ SYSTEM mode, IRQ/FIQ disabled
    ldr sp, =USER_STACK

    msr CPSR_c, #0xD2       @ IRQ mode, IRQ/FIQ disabled
    ldr sp, =IRQ_STACK

    msr CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled
    ldr sp, =SUPERVISOR_STACK

    msr CPSR_c, #0x10       @ USER mode, IRQ/FIQ enabled
    ldr sp, =LOCO


SVC_HANDLER:
    cmp r7, #ID_READ_SONAR
    beq READ_SONAR

    cmp r7, #ID_SET_MOTOR_SPEED
    beq SET_MOTOR_SPEED

    cmp r7, #ID_SET_MOTORS_SPEED
    beq SET_MOTORS_SPEED

    cmp r7, #ID_GET_TIME
    beq GET_TIME

    cmp r7, #ID_SET_TIME
    beq SET_TIME

    cmp r7, #ID_SET_ALARM
    beq SET_ALARM

READ_SONAR:
    stmfd sp!, {lr}

    cmp r0, #15         @ Verifica se o sonar escolhido é válido
    bhi err_sonar_id

    mov r1, =REG_DR     @ Carrega o valor do registrador DR
    ldr r2, [r1]






    err_sonar_id:
        mov r0, #-1
    
    ldmfd sp!, {lr}
    movs pc, lr

SET_MOTOR_SPEED:
    stmfd sp!, {lr}
    cmp r0, #MAX_SPEED_MOTOR
    movgt r0, #-1
    bgt fim_set_motor

    cmp r0, #0
    beq set_motor_0
    cmp r0, #1
    beq set_motor_1
    mov r0, #-2
    b fim_set_motor

    set_motor_0:
        mov r0, r0, LSL #19     @ move o sexto bit ate o 24 bit
        ldr r2, =MASK_MOTOR_0   @ carrega a mascara que aceita o motor 0
        and r2, r2, r0          @ combina o valor do motor 0 ja deslocado com a mascara

        ldr r0, =REG_DR         @ carrega o endereco de DR
        ldr r3, [r0]            @ carrega o valor de DR
        and r2, r2, r3          @ combina os valores ja pre combinados de ambos os motores com o de DR
        str r2, [r0]            @ guarda do novo valor no endereco correspondente a DR

        mov r0, #0              @ velocidade motor 0 OK
        b fim_set_motor

    set_motor_1:
        mov r0, r0, LSL #26     @ move o sexto bit ate o 32 bit
        ldr r2, =MASK_MOTOR_1   @ carrega a mascara que aceita o motor 0
        and r2, r2, r0          @ combina o valor do motor 1 ja deslocado com a mascara

        ldr r0, =REG_DR         @ carrega o endereco de DR
        ldr r3, [r0]            @ carrega o valor de DR
        and r2, r2, r3          @ combina os valores ja pre combinados de ambos os motores com o de DR
        str r2, [r0]            @ guarda do novo valor no endereco correspondente a DR

        mov r0, #0              @ velocidade motor 1 OK
        b fim_set_motor

    fim_set_motor:
        ldmfd sp!, {lr}
        movs pc, lr

SET_MOTORS_SPEED:
    stmfd sp!, {lr}
    cmp r0, #MAX_SPEED_MOTOR
    movgt r0, #-1
    bgt fim_set_motors

    cmp r1, #MAX_SPEED_MOTOR
    movgt r0, #-2
    bgt fim_set_motors


    mov r0, r0, LSL #19  @ move o sexto bit ate o 24 bit
    ldr r2, =MASK_MOTORS @ carrega a mascara que aceita ambos os motores
    and r3, r2, r0       @ combina o valor do motor 0 ja deslocado com a mascara

    mov r1, r1, LSL #26  @ move o sexto bit ate o 32 bit
    and r2, r2, r1       @ combina o valor do motor 1 ja deslocado com a mascara

    orr r2, r2, r3       @ combina a velocidade dos dois motores
    ldr r3, =MASK_MOTORS_WRITE
    orr r2, r2, r3       @ combina com as flags de write

    ldr r0, =REG_DR      @ carrega o endereco de DR
    ldr r3, [r0]         @ carrega o valor de DR
    orr r2, r2, r3       @ combina os valores ja pre combinados de ambos os motores com o de DR
    str r2, [r0]         @ guarda o novo valor no endereco correspondente a DR

    mov r0, #0 @ velocidade ok

    fim_set_motors:
      ldmfd sp!, {lr}
      movs pc, lr

GET_TIME:
    ldr r1, =CONTADOR_TEMPO
    ldr r0, [r1]
    movs pc, lr

SET_TIME:
    ldr r1, =CONTADOR_TEMPO
    str r0, [r1]
    movs pc, lr

SET_ALARM:

@ funcao que faz LOOP_WAITING_VAL iteracoes para alcancar um delay desejavel de 10-15ms
LOOP_WAITING:
    mov r0, #0
    ldr r1, =LOOP_WAITING_VAL

    do:
      add r0, r0, #1
      cmp r0, r1
      ble do
    mov pc, lr


.data
  CONTADOR_TEMPO: .word 0
