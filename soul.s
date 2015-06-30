@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Descricao: camada SOUL, o sistema operacional do robo UoLi.
@   Aqui estao as implementacoes de syscalls conforme definidas anteriormente no
@     enunciado do trabalho. Essas syscalls serao expostas para a API a fim de 
@     permitir o uso de funcoes do UoLi que dependem de seus perifericos, como 
@     ler valores de seus sonares, definir velocidades de motores e lidar com o 
@     tempo do sistema (pegar, definir e agendar)
@
@ Autores: Rafael Matheus Garcia RA 121295
@          Thiago Lugli          RA 157413
@ 
@ Padroes adotados:
@   - Funcoes: palavras separadas por underscore
@   - Funcoes internas: lower case
@   - Syscalls, funcoes de inicializacao e valores fixos: upper case
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.text
.org 0x0
.section .iv, "a"

SETS: @ Conjunto de definicoes de constantes para usarmos no resto do codigo
  @ Parte de memoria destinada ao LoCo (definido no Makefile do projeto)
  .set LOCO_CODE,        0x77802000 

  @ Enderecos das pilhas - cada uma tem 0x800 enderecos = 2KB
  .set IRQ_STACK,        0x7FFFFFFF@0x7FFFFFFF
  .set SUPERVISOR_STACK, 0x7A802000@0x7DFFFFFF
  .set LOCO_STACK,       0x78802000@0x7BFFFFFF

  @ Enderecos dos registradores do GPIO (entradas e saidas)
  @ Data Register
  .set GPIO_DR,          0x53F84000
  @ Direction Register (n-bit = 0 -> entrada, n-bit = 1 -> saida)
  .set GPIO_GDIR,        0x53F84004
  @ Pad status register - apenas para leitura
  .set GPIO_PSR,         0x53F84008

  @ Mascaras do GPIO para alterar/ler valores do motor/sonar (1 = out | 0 = in)
  .set MASK_GDIR,             0b11111111111111000000000000111110 

  .set MASK_MOTOR_0_WRITE,    0b11111110000000111111111111111111
  .set MASK_MOTOR_1_WRITE,    0b00000001111111111111111111111111
  .set MASK_SONAR_MUX,        0b11111111111111111111111111000011
  .set MASK_SIG_HIGH_TRIGGER, 0b00000000000000000000000000000010
  .set MASK_SIG_LOW_TRIGGER,  0b11111111111111111111111111111101
  .set MASK_FLAG_READ,        0b00000000000000000000000000000001
  .set MASK_SONAR_DATA,       0b00000000000000111111111111000000

  @ Enderecos do TZIC
  .set TZIC_BASE,        0x0FFFC000
  .set TZIC_INTCTRL,     0x0
  .set TZIC_INTSEC1,     0x84 
  .set TZIC_ENSET1,      0x104
  .set TZIC_PRIOMASK,    0xC
  .set TZIC_PRIORITY9,   0x424

  @ Enderecos do GPT
  .set GPT_CR,           0x53FA0000
  .set GPT_PR,           0x53FA0004
  .set GPT_SR,           0x53FA0008
  .set GPT_OCR1,         0x53FA0010
  .set GPT_IR,           0x53FA000C

  @ Define valores das syscalls
  .set ID_INNER_BACK_TO_IRQ,   7
  .set ID_READ_SONAR,          8
  .set ID_SET_MOTOR_SPEED,     9
  .set ID_SET_MOTORS_SPEED,   10
  .set ID_GET_TIME,           11
  .set ID_SET_TIME,           12
  .set ID_SET_ALARM,          13

  @ Definicao de valores para o CPSR para cada modo de operacao
             @7    6    5    4    [3:0]   
  @ disabled IRQ   FIQ THUMB mode
  .set USER_MODE,             0x1F @(0001 1111)
  .set IRQ_MODE,              0xD2 @(1101 0010)
  .set SUPERVISOR_MODE,       0x13 @(0001 0011)
  .set LOCO_MODE,             0x10 @(0001 0000)

  @ Define frequencia para fazer a contagem (system time)
  .set TIME_SZ,               16

  @ Maximo de alarmes que o sistema suporta de uma vez
  .set MAX_ALARMS,            10
  .set MAX_ALARMS_ARRAY_SIZE, 20 @ tem que ser o dobro do anterior porque o 
  @ vetor de alarmes precisa de 2 bytes para cada elemento sendo o primeiro 
  @ para o endereco da funcao e o segundo para o tempo de disparo

  @ Valor maximo de velocidade (sao 6 bits = 0b111111 = 63)
  .set MAX_SPEED_MOTOR,       63

  @ Define valor de iteracoes para aguardar algo entre 10-15 ms
  .set LOOP_WAITING_VAL,      15000

_start:     

@ Configura o vetor de interrupcoes
interrupt_vector:
  b RESET_HANDLER
.org 0x04
  b DEFAULT_HANDLER
.org 0x08
  b SVC_HANDLER
.org 0x0C
  b DEFAULT_HANDLER
.org 0x10
  b DEFAULT_HANDLER
.org 0x18
  b IRQ_HANDLER
.org 0x1C
  b DEFAULT_HANDLER

@ Inicio do codigo do usuario
.org 0x100
@ Zera o contador de tempo (system time)
  ldr r2, =CONTADOR_TEMPO
  mov r0, #0
  str r0, [r2]
@ Zera o contador de alarmes
  ldr r2, =CONTADOR_ALARM
  str r0, [r2] 

RESET_HANDLER:
  @ Set interrupt table base address on coprocessor 15.
  ldr r0, =interrupt_vector
  mcr p15, 0, r0, c12, c0, 0

@ Configura os modos de supervisor, IRQ e de usuario (codigo do LoCo)
@   e suas respectivas pilhas.
SET_STACKS:  
  msr CPSR_c, #SUPERVISOR_MODE   @ Modo SUPERVISOR, IRQ/FIQ habilitados
  ldr sp, =SUPERVISOR_STACK

  msr CPSR_c, #IRQ_MODE          @ Modo IRQ, IRQ/FIQ desabilitados
  ldr sp, =IRQ_STACK
  
  msr CPSR_c, #LOCO_MODE         @ Modo USER, IRQ/FIQ habilitados
  ldr sp, =LOCO_STACK

  msr CPSR_c, #SUPERVISOR_MODE   @ Volta para o modo SUPERVISOR

@ Configura o GPT (enderecos encontrados no datasheet IMX53-gpt.pdf na pagina 
@   do lab08 (tabela da pag 06))
SET_GPT:
  ldr r3, =GPT_CR
  mov r4, #0x00000041    @ clock_src periferico
  str r4, [r3]

  ldr r3, =GPT_PR
  mov r4, #0             @ zera o prescaler
  str r4, [r3]

  ldr r3, =GPT_OCR1
  ldr r4, =TIME_SZ       @ conta ate a constante definida
  str r4, [r3]

  ldr r3, =GPT_IR
  mov r4, #1             @ habilita interrupcao do tipo Output Compare Channel 1
  str r4, [r3]

@ Configura o TZIC
SET_TZIC:
  @ Liga o controlador de interrupcoes
  ldr r1, =TZIC_BASE @ R1 <= TZIC_BASE

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

@ Configura o registrador GDIR do GPIO, para definir quais perifericos estarao
@   em modo de entrada ou saida.
SET_GPIO:
  ldr r0, =GPIO_GDIR
  ldr r1, =MASK_GDIR
  str r1, [r0]

@ Muda para o modo de usuario, carrega sua pilha e vai para o endereco de
@   memoria correspondente a seu codigo (LoCo).
  msr CPSR_c, #LOCO_MODE @ USER mode, IRQ/FIQ enabled
  ldr sp, =LOCO_STACK
  ldr r0, =LOCO_CODE
  bx r0

@ Codigo responsavel para redirecionar as chamadas de syscalls dependendo do 
@   valor de r7 passado
SVC_HANDLER:
  cmp r7, #ID_INNER_BACK_TO_IRQ
  beq INNER_BACK_TO_IRQ

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

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que le o valor de um dos sonares e o retorna.
@ Essa syscall lida com o GPIO para poder fazer a leitura. Eh uma chamada mais 
@   lenta devido as pausas necessarias para o circuito do sonar retornar sua 
@   leitura.
@  
@ Parametros:
@   r0: o id do sonar que se deseja ler (de 0 a 15)
@ Retorno:
@   -1 se o sonar passado como parametro esta dentro do intervalo valido [0-15]
@   senao, a distancia como um inteiro, que varia de 0 ate (2^12)-1
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
READ_SONAR:
  @ Guarda o lr na pilha para nao se perder por causa das chamadas internas (bl)
  stmfd sp!, {lr}

  cmp r0, #15                 @ Verifica se o sonar escolhido eh valido
  movhi r0, #-1
  bhi fim_read_sonar          @ ID de sonar invalido

  ldr r1, =GPIO_DR                 
  ldr r2, [r1]                @ Carrega o valor atual do registrador DR

  lsl r0, r0, #2              @ Desloca o numero do sonar para a posicao correta
  and r2, r2, #MASK_SONAR_MUX @ Aplica a mascara em DR
  @ Sobrescreve os bits referentes ao ID do sonar no DR com o valor passado
  @   por parametro
  orr r2, r2, r0              

  and r2, r2, #MASK_SIG_LOW_TRIGGER 
  str r2, [r1]                @ Zera o trigger

  @ A funcao LOOP_WAITING suja os registradores r0-r1, por isso os empilhamos
  stmfd sp!, {r0-r1}              
  bl LOOP_WAITING             @ Aguarda 10-15ms com o trigger zerado
  ldmfd sp!, {r0-r1}

  ldr r2, [r1]
  ldr r3, =MASK_SIG_HIGH_TRIGGER
  orr r2, r2, r3              @ Seta o trigger
  str r2, [r1]                @ Guarda o valor atualizado no GPIO_DR

  
  stmfd sp!, {r0-r1}            
  bl LOOP_WAITING             @ Aguarda 10-15ms com o trigger setado
  ldmfd sp!, {r0-r1}

  ldr r2, [r1]
  and r2, r2, #MASK_SIG_LOW_TRIGGER 
  str r2, [r1]                @ Zera o trigger

  @ Le a flag, e aguarda ela ser setada
  wait_flag:                  
    ldr r1, =GPIO_DR
    ldr r2, [r1]
    and r2, r2, #MASK_FLAG_READ
    cmp r2, #1 
    @ Quando estiver habilitada, le o valor do sonar 
    beq sonar_value
    
    @ A funcao LOOP_WAITING suja os registradores r0-r1, por isso os empilhamos
    stmfd sp!, {r0-r1}
    bl LOOP_WAITING @ Aguarda 10-15ms       
    ldmfd sp!, {r0-r1}

    @ O valor ainda nao esta disponivel
    b wait_flag 

  @ Recebe o valor lido do registrador
  sonar_value:                    
    ldr r1, =GPIO_DR
    ldr r2, [r1]
    ldr r3, =MASK_SONAR_DATA
    and r2, r2, r3
    @ Apos utilizar a mascara, desloca o valor e move para r0
    lsr r0, r2, #6             

  @ Recupera o valor de lr ao entrar na funcao
  fim_read_sonar:
    ldmfd sp!, {lr}
    movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que seta a velocidade de um dos motores.
@ Essa syscall lida com o GPIO para poder fazer a escrita. O valor modificado em
@   DR sera apenas referente aos bits do motor em questao.
@  
@ Parametros:
@   r0: o id do motor que se deseja modificar a velocidade (0 ou 1)
@   r1: a velocidade a ser definida no motor (de 0 a 63)
@ Retorno:
@   -1 se a velocidade passada como parametro esta acima do permitido
@   -2 se o id do motor eh invalido
@   senao, 0 (sucesso)
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SET_MOTOR_SPEED:
  cmp r1, #MAX_SPEED_MOTOR
  movhi r0, #-1
  bhi fim_set_motor @ Velocidade invalida

  cmp r0, #0
  beq set_motor_0
  cmp r0, #1
  beq set_motor_1
  mov r0, #-2
  b fim_set_motor   @ ID de motor invalido

  @ O motor escolhido eh o 0 (direita). Mudaremos os bits apenas dele no GPIO_DR
  set_motor_0:
    lsl r1, r1, #19             @ Move o sexto bit (MSB) 19 vezez para a esquerda
    ldr r0, =MASK_MOTOR_0_WRITE @ Carrega a mascara para ativar o motor 0

    ldr r2, =GPIO_DR            @ Carrega o endereco do DR
    ldr r3, [r2]                @ Carrega o valor de DR em r3

    and r3, r3, r0              @ Preserva todos os bits que nao sao 18:24 (motor0_x) do GPIO_DR
    orr r3, r3, r1              @ Combina a velocidade com o resultado anterior
    str r3, [r2]                @ Guarda do novo valor no endereco correspondente a DR

    mov r0, #0                  @ Velocidade do motor 0 OK
    b fim_set_motor

  @ O motor escolhido eh o 1 (esquerda). Mudaremos somente bits dele no GPIO_DR
  set_motor_1:
    lsl r1, r1, #26             @ Move o sexto bit (MSB) 26 vezes para a esquerda
    ldr r0, =MASK_MOTOR_1_WRITE @ Carrega a mascara para ativar o motor 1

    ldr r2, =GPIO_DR            @ Carrega o endereco do DR
    ldr r3, [r2]                @ Carrega o valor de DR em r3

    and r3, r3, r0              @ Preserva todos os bits que nao sao 25:31 (motor1_x) do GPIO_DR
    orr r3, r3, r1              @ Combina a velocidade com o resultado anterior

    str r3, [r2]                @ Guarda do novo valor no endereco correspondente a DR

    mov r0, #0                  @ Velocidade do motor 1 OK
    b fim_set_motor

  @ Volta para a proxima instrucao de quem chamou a syscall, modificando tambem
  @   o CPSR atual
  fim_set_motor:
    movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que seta a velocidade de ambos os motores.
@ Essa syscall lida com o GPIO para poder fazer a escrita. O valor modificado em
@   DR sera apenas referente aos bits dos dois motores [31:25].
@  
@ Parametros:
@   r0: a velocidade a ser definida no motor 0 (de 0 a 63)
@   r1: a velocidade a ser definida no motor 1 (de 0 a 63)
@ Retorno:
@   -1 se a velocidade desejada do motor 0 esta acima do permitido
@   -2 se a velocidade desejada do motor 1 esta acima do permitido
@   senao, 0 (sucesso)
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SET_MOTORS_SPEED:
  cmp r0, #MAX_SPEED_MOTOR
  movhi r0, #-1
  bhi fim_set_motors        @ Velocidade invalida para o motor 0

  cmp r1, #MAX_SPEED_MOTOR
  movhi r0, #-2
  bhi fim_set_motors        @ Velocidade invalida para o motor 1

  lsl r0, r0, #19           @ Move o sexto bit ate o 24 bit (velocidade 0)
  lsl r1, r1, #26           @ Move o sexto bit ate o 32 bit (velocidade 1)
  
  orr r3, r0, #0           @ Combina a velocidade dos dois motores  
  orr r3, r3, r1            @ Combina a velocidade dos dois motores
  
  ldr r2, =GPIO_DR
  str r3, [r2]              @ Guarda o novo valor em GPIO_DR

  mov r0, #0                @ Velocidade foi setada com sucesso

  @ Volta para a proxima instrucao de quem chamou a syscall, modificando tambem
  @   o CPSR atual
  fim_set_motors:
    movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que retorna o valor atual do contador de tempo do sistema.
@  
@ Parametros:
@   nenhum
@ Retorno:
@   o valor do contador de tempo do sistema
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
GET_TIME:
  ldr r1, =CONTADOR_TEMPO
  ldr r0, [r1]
  @ Volta para a proxima instrucao de quem chamou a syscall, modificando tambem
  @   o CPSR atual
  movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que define o valor atual do contador de tempo do sistema.
@  
@ Parametros:
@   r0: o tempo que se deseja definir
@ Retorno:
@   nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SET_TIME:
  ldr r1, =CONTADOR_TEMPO
  str r0, [r1]
  @ Volta para a proxima instrucao de quem chamou a syscall, modificando tambem
  @   o CPSR atual
  movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall que define um alarme para um tempo especifico do sistema.
@ Existe um vetor de alarmes, onde cada alarme ocupa 2 bytes na memoria.
@   O primeiro byte eh referente ao endereco da funcao a ser chamada.
@   O segundo armazena o tempo do sistema para se disparar o alarme.
@ Quando os alarmes sao executados, sao limpos do vetor, entao essa syscall
@   consegue reaproveitar os slots ja usados.
@  
@ Parametros:
@   r0: o endereco da funcao que devera ser executada no tempo desejado
@   r1: o tempo desejado para agendar a execucao da funcao
@ Retorno:
@   -1 se se o numero de alarmes ativos ja atingiu seu limite
@   -2 se o tempo eh menor do que o tempo atual do sistema
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SET_ALARM:
  @ Sujamos os registradores r4-r5 e lr, por isso devemos empilha-los no comeco
  stmfd sp!, {r4-r5, lr}

  @ Guarda os parametros em r4 e r5
  mov r4, r0
  mov r5, r1
  
  @ Recupera em r0 o tempo atual do sistema
  ldr r1, =CONTADOR_TEMPO
  ldr r0, [r1]
  
  cmp r0, r5
  movhs r0, #-2
  bhs fim_set_alarm @ Caso o tempo do alarme seja menor que o do sistema

  @ Recupera em r3 o numero de alarmes ativos
  ldr r2, =CONTADOR_ALARM
  ldr r3, [r2]

  cmp r3, #MAX_ALARMS
  movhi r0, #-1
  bhi fim_set_alarm @ Caso o numero de alarmes ativos ja esteja no limite

  @ Incrementa o contador de alarmes por considerar o alarme atual
  add r3, r3, #1
  str r3, [r2]

  @ Lida com o vetor de alarmes
  ldr r2, =VETOR_ALARM @ Carrega o endereco de memoria do vetor de alarmes
  percorre_vetor_alarm:
    ldr r3, [r2, #4]   @ Carrega o tempo de agendamento da posicao atual
    cmp r3, #0         @ As posicoes sao iniciadas com 0 -> 0 = posicao vazia
    
    beq guarda_alarm   @ Ja encontrou uma posicao disponivel no vetor
    add r2, r2, #8     @ Avanca com o cursor do vetor em uma posicao
    b percorre_vetor_alarm

  guarda_alarm:
    str r4, [r2]       @ Guarda o endereco do ponteiro da funcao
    str r5, [r2, #4]   @ Guarda o tempo em que o alarme deve ser acionado

  fim_set_alarm:
    @ Recupera os valoers originais de r4,r5 e lr da pilha
    ldmfd sp!, {r4-r5, lr}
    @ Volta para a proxima instrucao de quem chamou a syscall, modificando tambem
    @   o CPSR atual
    movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Syscall de uso interno que serve para mudar o modo de execucao de volta para o
@   IRQ.
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
INNER_BACK_TO_IRQ:
  @ Sujamso o r0 para guardar o valor de lr antes da troca de modo de execucao
  mov r0, lr  
  @ Volta para o modo IRQ
  msr CPSR_c, #IRQ_MODE 
  mov lr, r0  @ recupera o lr original
  mov pc, lr  @ Nao eh movs porque queremos manter o CPSR

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Trecho de codigo que trata as interrupcoes IRQ. No caso desse codigo, serao
@   disparadas pelo GPT.
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IRQ_HANDLER:
  stmfd sp!, {r0-r12, lr}
  
  @ informa que o processador esta ciente da interrupcao
  ldr r3, =GPT_SR
  mov r2, #0
  str r2, [r3]             

  @ carrega e atualiza o contador de tempo
  ldr r3, =CONTADOR_TEMPO  @ carrega em r3 a posicao de memoria do contador
  ldr r2, [r3]             @ carrega em r2 o conteudo que esta na posicao de memoria apontada por r3
  add r2, r2, #1           @ incrementa o contador em 1
  str r2, [r3]             @ guarda o valor atualizado na posicao de memoria do contador

  @ percorre o vetor de alarmes procurando alarmes setados para o horario atual
  ldr r3, =VETOR_ALARM
  mov r0, #0
  percorre_vetor_alarm_disparo:
    ldr r1, [r3, #4]         @ a struct eh: endereco da funcao, tempo do alarme
    cmp r1, r2               @ compara o tempo atual com o tempo do alarme do elemento do vetor
    stmfd sp!, {r0-r3}

    blls dispara_alarme      @ se o tempo for menor ou igual o atual, chamda dispara_alarme
    ldmfd sp!, {r0-r3}       @ o caso 'menor' só ocorrerá quando houver dois alarme nos mesmo momento
                             @ pois o set_alarm não possibilita insercao de alarmes com tempos menores que
                             @ o tempo atual
    add r3, r3, #8           @ incrementa o indice para avancar no vetor de alarmes
    add r0, r0, #1
    cmp r0, #MAX_ALARMS      @ comapara com o numero maximo de alarmes
    beq fim_irq_handler      @ se for igual, chegou ao fim do vetor, nao ha mais alarmes
    b percorre_vetor_alarm_disparo

  @ pega a funcao do vetor de alarme e chama ela em modo usuario
  dispara_alarme:
    cmp r1, #0               @ caso o tempo setado seja 0, (ou seja, nao ha alarme), retorna
    moveq pc, lr             @ e nao executa nada

    stmfd sp!, {lr}

    mrs r2, spsr @ precisa guardar o spsr do modo atual para nao perder na transicao depois da chamada de funcao
    
    @ esvazia essa posicao do vetor
    mov r0, #0
    str r0, [r3, #4]

    @ diminui contador de alarmes
    ldr r1, =CONTADOR_ALARM
    ldr r0, [r1]
    sub r0, r0, #1
    str r0, [r1]

    stmfd sp!, {r0-r3}

    msr CPSR_c, #LOCO_MODE @ o codigo de usuario deve ser executado no respectivo modo

    ldr r1, [r3]        @ carrega o endereco da funcao a ser chamada
    blx r1              @ invoca a funcao

    @ trap para voltar ao modo anterior (IRQ) a chamada da funcao
    mov r7, #ID_INNER_BACK_TO_IRQ
    svc 0x0

    @ retorna os valoeres dos registradores e volta spsr 
    ldmfd sp!, {r0-r3}
    msr spsr, r2
    @ retorna de dispara_alarme
    ldmfd sp!, {lr}
    mov pc, lr

  @ nao ha mais alarmes, recupera todos os registradores e volta para o codigo do usuario
  fim_irq_handler:
    ldmfd sp!, {r0-r12, lr}
    sub lr, lr, #4           @ correcao do valor de lr = pc + 8
    movs pc, lr

@ Handler para interrupcoes nao definidas
DEFAULT_HANDLER:
  movs pc, lr

@ Faz LOOP_WAITING_VAL iteracoes para alcancar um delay desejavel de 10-15ms
LOOP_WAITING:
    mov r0, #0
    ldr r1, =LOOP_WAITING_VAL

    do:
      add r0, r0, #1
      cmp r0, r1
      ble do
    mov pc, lr

.data
  CONTADOR_ALARM: .word 0                         @ contador de alarmes ativos
  CONTADOR_TEMPO: .word 0                         @ contador de tempo (incrementado a cada interrucao irq)
  VETOR_ALARM:    .space MAX_ALARMS_ARRAY_SIZE    @ vetor de alarmes armazenados com seus tempos
