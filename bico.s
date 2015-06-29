@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Descricao: camada BICo, a biblioteca de controle do robo UoLi.
@   Aqui estao as implementacoes de funcoes definidas pela API de controle 
@   'api_robot2.h'.
@   Essas funcoes serao expostas para a camada LoCo que podera se comunicar com 
@   diversos perifericos do robo para que possa executar a logica do programa.
@
@ Autores: Rafael Matheus Garcia RA 121295
@          Thiago Lugli          RA 157413
@ 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.text
.align 4
.globl set_motor_speed
.globl set_motors_speed
.globl read_sonar
.globl read_sonars
.globl get_time
.globl set_time
.globl add_alarm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que acessa o contador de tempo do sistema e retorna seu valor.
@
@ Parametros:
@       nenhum
@ Retorno:
@       r0: o tempo do sistema
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
get_time:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #11             @ Valor da syscall get_time
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que seta um valor para o contador de tempo do sistema.
@
@ Parametros:
@       r0: o tempo que se deseja inserir no sistema
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
set_time:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #12             @ Valor da syscall set_time
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

add_alarm:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #13             @ Valor da syscall set_time
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que seta uma velocidade para o motor com o id especificado.
@
@ Parametros:
@       r0: a velocidade do motor (so os 6 LSB sao usados)
@       r1: o id do motor (0 = motor da esquerda, 1 = motor da direita)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
set_motor_speed:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #9              @ Valor da syscall set_motor_speed
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que seta uma velocidade para cada um dos motores do robo.
@
@ Parametros:
@       r0: a velocidade do motor da esquerda (so os 6 LSB sao usados)
@       r1: a velocidade do motor da direita (so os 6 LSB sao usados)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
set_motors_speed:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #10             @ Valor da syscall set_motors_speed
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que le o valor de um dos sonares.
@
@ Parametros:
@       r0: o id do sonar que se deseja ler (de 0 a 15)
@ Retorno:
@       a distancia como um inteiro, que varia de 0 ate (2^12)-1
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
read_sonar:
    stmfd sp!, {r4-r11, lr} @ Salva regs
    mov r7, #8              @ Valor da syscall read_sonar
    svc 0x0
    ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ *** NAO SERA USADA NO TRABALHO *** 
@ Funcao que le o valor de todos os sonares.
@
@ Parametros:
@       r0: o endereco do comeco do array de distancia dos sonares (16 posicoes)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
read_sonars:
    stmfd sp!, {r0, r4-r11, lr} @ Salva regs
    mov r2, #0                  @ variavel auxiliar para indice do loop e dos sonares

loop:
    mov r0, r2                  @ parametro do id sonar precisa ser em r0
    bl read_sonar               @ le valor do sonar de id = r0 = r2
    ldr r3, [sp]                @ le r0 da pilha que contem o endereco inicial do array de distancias

    add r3, r3, r2, LSL #2      @ adiciona ao endereco inicial do vetor r2*4
    str r0, [r3]                @ r0 possui o valor da distancia do sonor lido, e eh guardado na posicao de memoria indicada por r3

    add r2, r2, #1              @ incrementa o indice
    cmp r2, #16
    blo loop

    ldmfd sp!, {r0, r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)
