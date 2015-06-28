.text
.align 4
.globl set_motor_speed
.globl set_motors_speed
.globl read_sonar
.globl read_sonars
.globl get_time
.globl set_time
.globl add_alarm

get_time:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r7, #11
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

set_time:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r7, #12
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

add_alarm:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r7, #13
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que seta uma velocidade para o motor com o id especificado.
@ Parametros:
@       r0: a velocidade do motor (so os 6 LSB sao usados)
@       r1: o id do motor (0 = motor da esquerda, 1 = motor da direita)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
set_motor_speed:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r2, r0              @ Guarda a velocidade
        mov r0, r1              @ inverte os parametros
        mov r1, r2              @ (o .h esta especificado de um jeito e a syscall de outro)

        mov r7, #9              @ faz o syscall (write_motors)
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que seta uma velocidade para cada um dos motores do robo.
@ Parametros:
@       r0: a velocidade do motor da esquerda (so os 6 LSB sao usados)
@       r1: a velocidade do motor da direita (so os 6 LSB sao usados)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
set_motors_speed:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r7, #10            @ faz o syscall (write_motors)
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que le o valor de um dos sonares.
@ Parametros:
@       r0: o id do sonar que se deseja ler (de 0 a 15)
@ Retorno:
@       a distancia como um inteiro, que varia de 0 ate (2^12)-1
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
read_sonar:
        stmfd sp!, {r4-r11, lr} @ Salva regs
        mov r7, #8            @ faz o syscall (read_sonar)
        svc 0x0
        ldmfd sp!, {r4-r11, pc} @ Recupera regs (valor de lr diretamente em pc)

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ Funcao que le o valor de todos os sonares.
@ Parametros:
@       r0: o endereco do comeco do array de distancia dos sonares (16 posicoes)
@ Retorno:
@       nulo
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
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
