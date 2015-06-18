.org 0x0
.section .iv,"a"

_start:     

interrupt_vector:
    b RESET_HANDLER
.org 0x18
    b IRQ_HANDLER

.org 0x100
.text
    @ Zera o contador
    ldr r2, =CONTADOR
    mov r0, #0
    str r0, [r2]

RESET_HANDLER:
    @Set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

    b SET_GPT @ pula para o bloco de codigo que configura o GPT (e logo depois ja confiugra o TZIC)

    @@@...continua tratando o reset

IRQ_HANDLER:
    ldr r3, =GPT_SR
    mov r4, #0
    str r4, [r3]                @ informa que o processador esta ciente da interrupcao

    ldr r3, =CONTADOR           @ carrega em r3 a posicao de memoria do contador
    ldr r4, [r3]                @ carrega em r4 o conteudo que esta na posicao de memoria apontada por r3
    add r4, r4, #1              @ incrementa o contador em 1
    str r4, [r3]                @ guarda o valor atualizado na posicao de memoria do contador

    sub lr, lr, #4              @ correcao do valor de lr = pc + 8
    movs pc, lr                 @ volta para o modo correto com o CPSR antigo tambem

SET_GPT: @ enderecos encontrados no datasheet IMX53-gpt.pdf na pagina do lab (tabela da pag 06)
    .set GPT_CR,                0x53FA0000
    .set GPT_PR,                0x53FA0004
    .set GPT_SR,                0x53FA0008
    .set GPT_OCR1,              0x53FA0010 
    .set GPT_IR,                0x53FA000C
    
    ldr r3, =GPT_CR
    mov r4, #0x00000041          @ clock_src periferico
    str r4, [r3]

    ldr r3, =GPT_PR
    mov r4, #0                  @ zera o prescaler
    str r4, [r3]

    ldr r3, =GPT_OCR1
    mov r4, #100                @ conta ate 100ms
    str r4, [r3]

    ldr r3, =GPT_IR
    mov r4, #1                  @ habilita interrupcao do tipo Output Compare Channel 1
    str r4, [r3]

SET_TZIC:
    @ Constantes para os enderecos do TZIC
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84 
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

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

    @instrucao msr - habilita interrupcoes
    msr  CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled

laco:
    b laco

.data
    CONTADOR: .word 0
