@ padroes adotados:
@   - funcoes: palavras separadas por underscore
@   - funcoes internas: lower case
@   - syscalls, funcoes de inicializacao e valores fixos: upper case

@Mudar para nivel usuario
@Chamar codigo de controle

.org 0x0
.section .iv,"a"

_start:     

@ Configura o vetor de interrupcoes
interrupt_vector:
  b RESET_HANDLER
.org 0x08
  b SVC_HANDLER

@ Inicio do codigo do usuario
SETS:
  .set LOCO_CODE,                  0x77802000

  .set DATA_BASE_ADDR, 0x77801900 @ Parte da memoria destinada aos dados (definido no Makefile do projeto)

  @Configuracao de pilhas - cada uma tem 0x800 enderecos = 2KB
  .set USER_STACK,       0x77802100
  .set SUPERVISOR_STACK, 0x77802900
  .set IRQ_STACK,        0x77803100
  .set LOCO_STACK,       0x77803900

  @ Configura enderecos dos registradores do GPIO (entradas e saidas)
  .set GPIO_DR,           0x53F84000     @Data Register
  .set GPIO_GDIR,         0x53F84004     @Direction Register (n-bit = 0 -> entrada, n-bit = 1 -> saida)
  .set GPIO_PSR,          0x53F84008     @Pad status register - apenas para leitura

  @ Configuracao de mascaras para o GPIO
  .set MASK_GDIR,                   0b11111111111111000000000000111110 @ 1 = saida, 0 = entrada

  .set MASK_MOTOR_0_WRITE,          0b11111110000000111111111111111111
  .set MASK_MOTOR_1_WRITE,          0b00000001111111111111111111111111
  .set MASK_SONAR_MUX,              0b11111111111111111111111111000011
  .set MASK_SIG_HIGH_TRIGGER,       0b00000000000000000000000000000010
  .set MASK_SIG_LOW_TRIGGER,        0b11111111111111111111111111111101
  .set MASK_FLAG_READ,              0b00000000000000000000000000000001
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
  .set ID_READ_SONAR,       8
  .set ID_SET_MOTOR_SPEED,  9
  .set ID_SET_MOTORS_SPEED, 10
  .set ID_GET_TIME,         11
  .set ID_SET_TIME,         12
  .set ID_SET_ALARM,        13

  @ Definicao de valores para o CPSR para cada modo de operacao
            @7    6    5    4    [3:0]   
  @disabled IRQ   FIQ THUMB mode
  .set USER_MODE,           0xDF @(1101 1111)
  .set IRQ_MODE,            0xD2 @(1101 0010)
  .set SUPERVISOR_MODE,     0x13 @(0001 0011)
  .set LOCO_MODE,           0x10 @(0001 0000)

  @ Configura frequencia para fazer a contagem (system time)
  .set TIME_SZ,          100

  .set MAX_ALARMS,        10
  .set MAX_ALARMS_ARRAY_SIZE, 20 @ tem que ser o dobro da variavel anterior porque
                  @ o vetor de alarmes precisa de 2 bytes para cada elemento

  @ Configura valor maximo de velocidade (sao 6 bits = 0b111111 = #63)
  .set MAX_SPEED_MOTOR,   63

  @ Configura valor de iteracoes para aguardar algo entre 10-15 ms
  .set LOOP_WAITING_VAL,  70000

.org 0x100
.text
.align 4
@ Zera o contador de tempo
  ldr r2, =CONTADOR_TEMPO
  mov r0, #0
  str r0, [r2]

  ldr r2, =CONTADOR_ALARM
  str r0, [r2] 

RESET_HANDLER:
  @Set interrupt table base address on coprocessor 15.
  ldr r0, =interrupt_vector
  mcr p15, 0, r0, c12, c0, 0

@ Configura o registrador GDIR do GPIO, para definir quais perifericos estarao em modo de entrada ou saida.
SET_GPIO:
  ldr r0, =GPIO_GDIR
  ldr r1, =MASK_GDIR
  str r1, [r0]

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
  msr CPSR_c, #USER_MODE       @ SYSTEM mode, IRQ/FIQ disabled
  ldr sp, =USER_STACK

  msr CPSR_c, #IRQ_MODE       @ IRQ mode, IRQ/FIQ disabled
  ldr sp, =IRQ_STACK

  msr CPSR_c, #SUPERVISOR_MODE       @ SUPERVISOR mode, IRQ/FIQ enabled
  ldr sp, =SUPERVISOR_STACK

  msr CPSR_c, #LOCO_MODE       @ USER mode, IRQ/FIQ enabled
  ldr sp, =LOCO_STACK

  @ Pula para o endereco inicial da camada LOCO
  ldr r0, =LOCO_CODE
  bx r0

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

  cmp r0, #15                     @ Verifica se o sonar escolhido eh valido
    movhi r0, #-1
  bhi fim_read_sonar

  ldr r1, =GPIO_DR                 @ Carrega o valor do registrador DR
  ldr r2, [r1]

  lsl r0, r0, #2                  @ Desloca o numero do sonar para a posicao correta
  and r2, r2, #MASK_SONAR_MUX     @ Aplica a mascara no valor do registrador
  orr r2, r2, r0

  and r2, r2, #MASK_SIG_LOW_TRIGGER @ Zera o trigger
  str r2, [r1]

  stmfd sp!, {r0-r1}              @ A funcao LOOP_WAITING ira sujar os registradores r0-r1
  bl LOOP_WAITING                 @ Aguarda 10-15ms
  ldmfd sp!, {r0-r1}

  ldr r2, [r1]
  ldr r3, =MASK_SIG_HIGH_TRIGGER
  orr r2, r2, r3          @ Seta o trigger
  str r2, [r1]

  stmfd sp!, {r0-r1}              @ A funcao LOOP_WAITING ira sujar os registradores r0-r1
  bl LOOP_WAITING                 @ Aguarda 10-15ms
  ldmfd sp!, {r0-r1}

  ldr r2, [r1]
  and r2, r2, #MASK_SIG_LOW_TRIGGER @ Zera o trigger
  str r2, [r1]

  wait_flag:                      @ Le a flag, e aguarda ela ser setada
    ldr r1, =GPIO_DR
    ldr r2, [r1]
    and r2, r2, #MASK_FLAG_READ
    cmp r2, #1
    beq sonar_value
    
    stmfd sp!, {r0-r1}              @ A funcao LOOP_WAITING ira sujar os registradores r0-r1
    bl LOOP_WAITING                 @ Aguarda 10-15ms
    ldmfd sp!, {r0-r1}

    b wait_flag

  sonar_value:                    @ Recebe o valor lido do registrador
    ldr r1, =GPIO_DR
    ldr r2, [r1]
    ldr r3, =MASK_SONAR_DATA
    and r2, r2, r3
    lsr r0, r2, #6              @ Apos utilizar a mascara, desloca o valor e move para r0

  fim_read_sonar:
    ldmfd sp!, {lr}
    movs pc, lr
  
SET_MOTOR_SPEED:
  cmp r1, #MAX_SPEED_MOTOR
  movhi r0, #-1
  bhi fim_set_motor

  cmp r0, #0
  beq set_motor_0
  cmp r0, #1
  beq set_motor_1
  mov r0, #-2
  b fim_set_motor

  set_motor_0:
    lsl r1, r1, #19          @ move o sexto bit ate o 24 bit
    ldr r0, =MASK_MOTOR_0_WRITE  @ carrega a mascara para ativar o motor 0

    ldr r2, =GPIO_DR             @ carrega o endereco do DR
    ldr r3, [r2]                 @ carrega o valor de DR em r3

    and r3, r3, r0               @ preserva todos os bits que nao sao 18:24 (motor0_x) do GPIO_DR
    orr r3, r3, r1               @ combina a velocidade com o resultado anterior

    str r3, [r2]                 @ guarda do novo valor no endereco correspondente a DR

    mov r0, #0                   @ velocidade motor 0 OK
    b fim_set_motor

  set_motor_1:
    lsl r1, r1, #26          @ move o sexto bit ate o 24 bit
    ldr r0, =MASK_MOTOR_1_WRITE  @ carrega a mascara para ativar o motor 0

    ldr r2, =GPIO_DR             @ carrega o endereco do DR
    ldr r3, [r2]                 @ carrega o valor de DR em r3

    and r3, r3, r0               @ preserva todos os bits que nao sao 25:31 (motor1_x) do GPIO_DR
    orr r3, r3, r1               @ combina a velocidade com o resultado anterior

    str r3, [r2]                 @ guarda do novo valor no endereco correspondente a DR

    mov r0, #0                   @ velocidade motor 0 OK
    b fim_set_motor

  fim_set_motor:
    movs pc, lr

SET_MOTORS_SPEED:
  cmp r0, #MAX_SPEED_MOTOR
  movhi r0, #-1
  bhi fim_set_motors

  cmp r1, #MAX_SPEED_MOTOR
  movhi r0, #-2
  bhi fim_set_motors

  lsl r0, r0, #19  @ move o sexto bit ate o 24 bit
  lsl r1, r1, #26  @ move o sexto bit ate o 32 bit
  
  orr r3, r0, #0       @ combina a velocidade dos dois motores
  orr r3, r3, r1       @ combina a velocidade dos dois motores
  
  ldr r2, =GPIO_DR
  str r3, [r2]         @ guarda o novo valor no endereco correspondente a DR

  mov r0, #0 @ velocidade ok

  fim_set_motors:
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
  stmfd sp!, {r0-r1, lr}
  
  bl GET_TIME
  mov r2, r0 @ guarda o tempo que foi buscado pela funcao GET_TIME
  ldmfd sp!, {r0-r1}

  cmp r1, r2
  movge r0, #-2
  bhs fim_set_alarm

  ldr r2, =CONTADOR_ALARM
  ldr r3, [r2]

  cmp r3, #MAX_ALARMS
  movhi r0, #-1
  bhi fim_set_alarm

  add r3, r3, #1 @ incrementa em um o contador de alarmes
  str r3, [r2]

  @ lida com o vetor de alarmes
  ldr r2, =VETOR_ALARM @ carrega o endereco de memoria do vetor
  percorre_vetor_alarm:
    ldr r3, [r2]         @ carrega o valor da posicao atual do vetor
    cmp r3, #0 @ as posicoes sao iniciadas com 0, entao 0 = posicao vazia
    
    beq guarda_alarm @ ja encontrou uma posicao disponivel no vetor
    add r2, r2, #8 @ desloca o cursor do vetor uma posicao para frente
    b percorre_vetor_alarm

  guarda_alarm:
    str r0, [r2]      @ guarda o endereco do ponteiro da funcao
    str r1, [r2, #4]  @ guarda o tempo em que o alarme deve ser acionado

  fim_set_alarm:
    ldmfd sp!, {lr}
    movs pc, lr

@ funcao que faz LOOP_WAITING_VAL iteracoes para alcancar um delay desejavel de 10-15ms
LOOP_WAITING:
    mov r0, #0
    ldr r1, =LOOP_WAITING_VAL

    do:
      add r0, r0, #1
      cmp r0, r1
      ble do
    mov pc, lr

@OTHER_HANDLER:
@IRQ_HANDLER:
@  ldr r0, =LOCO_CODE
@  bx r0

.data
  CONTADOR_TEMPO: .word 0
  CONTADOR_ALARM: .word 0
  VETOR_ALARM:    .space MAX_ALARMS_ARRAY_SIZE
