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
@- Configurar o TZIC
@  .set TZIC_BASE,             0x0FFFC000
@  .set TZIC_INTCTRL,          0x0
@  .set TZIC_INTSEC1,          0x84 
@  .set TZIC_ENSET1,           0x104
@  .set TZIC_PRIOMASK,         0xC
@  .set TZIC_PRIORITY9,        0x424
@
@- Configurar GPT (Com tempo razoável)
@  .set TIME_SZ,            0x00000010 @ decimal = 16 
@  .set GPT_CR,             0x53FA0000
@  .set GPT_PR,             0x53FA0004
@  .set GPT_SR,             0x53FA0008
@  .set GPT_IR,             0x53FA000C
@  .set GPT_OCR1,           0x53FA0010
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

.org 0x100
.text

.set DATA_BASE_ADDR, 0x77801800 @ Parte da memoria destinada aos dados (definido no Makefile do projeto)

@Configuracao de pilhas - cada uma tem 0x800 enderecos = 2KB
.set USER_STACK,       DATA_BASE_ADDR
.set FIQ_STACK,        0x77801000
.set SUPERVISOR_STACK, 0x77800800
.set ABORT_STACK,      0x77800000
.set IRQ_STACK,        0x777FF800
.set UNDEFINED_STACK,  0x777FF000

@ Configurar GPIO (entradas e saidas)
.set REG_DR,           0x53F84000     @Data Register
.set REG_GDIR,         0x53F84004     @Direction Register (n-bit = 0 -> entrada, n-bit = 1 -> saida)
.set REG_PSR,          0x53F84008     @Pad status register - apenas para leitura

RESET_HANDLER:
    @Set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

    b SET_GPT @ pula para o bloco de codigo que configura o GPT (e logo depois ja confiugra o TZIC)


.data