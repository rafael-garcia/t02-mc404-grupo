@Camada SOUL:
@00 FLAG            Entrada
@01 TRIGGER         Saida
@02 SONAR_MUX[0]    Saida
@03 SONAR_MUX[1]    Saida
@04 SONAR_MUX[2]    Saida
@05 SONAR_MUX[3]    Saida
@06 SONAR_DATA[0]   Entrada
@07 SONAR_DATA[1]   Entrada
@08 SONAR_DATA[2]   Entrada
@09 SONAR_DATA[3]   Entrada
@10 SONAR_DATA[4]   Entrada
@11 SONAR_DATA[5]   Entrada
@12 SONAR_DATA[6]   Entrada
@13 SONAR_DATA[7]   Entrada
@14 SONAR_DATA[8]   Entrada
@15 SONAR_DATA[9]   Entrada
@16 SONAR_DATA[10]  Entrada
@17 SONAR_DATA[11]  Entrada
@18 MOTOR0_WRITE    Saida
@19 MOTOR0_SPEED[0] Saida
@20 MOTOR0_SPEED[1] Saida
@21 MOTOR0_SPEED[2] Saida
@22 MOTOR0_SPEED[3] Saida
@23 MOTOR0_SPEED[4] Saida
@24 MOTOR0_SPEED[5] Saida
@25 MOTOR1_WRITE    Saida
@26 MOTOR1_SPEED[0] Saida
@27 MOTOR1_SPEED[1] Saida
@28 MOTOR1_SPEED[2] Saida
@29 MOTOR1_SPEED[3] Saida
@30 MOTOR1_SPEED[4] Saida
@31 MOTOR1_SPEED[5] Saida
@
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

@Configuracao de mascaras para o GPIO
.set MASK_GDIR,        0b00000000000000000000000000000000

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

@ Configura frequencia para fazer a contagem (system time)
.set TIME_SZ,          100

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
    msr CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled
    ldr sp, =SUPERVISOR_STACK

    msr CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled
    ldr sp, =SUPERVISOR_STACK


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

.data
  CONTADOR_TEMPO: .word 0