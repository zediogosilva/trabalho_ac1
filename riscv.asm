.data
.align 2

# Strings para interface com o usuário
pede_ficheiro:   .asciz "Digite o nome do ficheiro: "
resultado_tam:   .asciz "\nTamanho original: "
resultado_comp:  .asciz " bytes\nTamanho comprimido (min): "
resultado_fim:   .asciz " bytes\n"
erro_abrir:     .asciz "ERRO: Não foi possível abrir o ficheiro!\n"
erro_vazio:     .asciz "AVISO: Ficheiro vazio!\n"

.align 2
nome_ficheiro:  .space 100       # Buffer para armazenar o nome do arquivo
.align 2
conteudo:       .space 100000    # Buffer para armazenar o conteúdo do arquivo
.align 2
contagens:      .space 512       # Array para contar ocorrências de caracteres (128 caracteres * 4 bytes cada)

.text
.globl main

main:
    # Solicita ao usuário o nome do arquivo
    la a0, pede_ficheiro
    li a7, 4
    ecall

    # Lê o nome do arquivo do usuário
    la a0, nome_ficheiro
    li a1, 99
    li a7, 8
    ecall

    # Remove a nova linha do final do nome do arquivo
    la t0, nome_ficheiro
    
rm_nl:
    lb t1, (t0)
    beqz t1, fim_rm_nl
    addi t0, t0, 1
    j rm_nl
    
fim_rm_nl:
    sb zero, -1(t0)

    # Abre o arquivo para leitura
    la a0, nome_ficheiro
    li a1, 0
    li a7, 1024
    ecall

    bltz a0, erro_abertura  # Se a0 < 0, erro ao abrir
    mv s0, a0               # Salva o descritor do arquivo em s0

    # Lê o conteúdo do arquivo
    la a1, conteudo
    li a2, 100000
    li a7, 63
    ecall

    mv s1, a0               # Salva o tamanho do arquivo em s1

    # Fecha o arquivo
    mv a0, s0
    li a7, 57
    ecall

    beqz s1, ficheiro_vazio  # Se tamanho = 0, arquivo vazio

    # Processa o arquivo
    jal conta_caracteres     # Conta ocorrências de cada caractere
    jal calcula_entropia     # Calcula a entropia do arquivo

    # Garante entropia mínima de 1 bit por símbolo
    li t0, 1
    blt a0, t0, ajusta_entropia
    j calcula_tamanho
ajusta_entropia:
    mv a0, t0
calcula_tamanho:
    mv s2, a0               # Salva a entropia em s2

    # Calcula tamanho comprimido: (tamanho * entropia + 7) / 8
    mv a0, s1               # Tamanho original
    mv a1, s2               # Entropia
    jal multiplica          # Multiplica tamanho por entropia
    addi a0, a0, 7          # Adiciona 7 para arredondar para cima
    srli a0, a0, 3          # Divide por 8 (shift right 3 bits)
    mv s3, a0               # Salva tamanho comprimido em s3

    # Exibe resultados
    la a0, resultado_tam
    li a7, 4
    ecall
    mv a0, s1               # Tamanho original
    li a7, 1
    ecall
    la a0, resultado_comp
    li a7, 4
    ecall
    mv a0, s3               # Tamanho comprimido
    li a7, 1
    ecall
    la a0, resultado_fim
    li a7, 4
    ecall
    j fim

erro_abertura:
    la a0, erro_abrir
    li a7, 4
    ecall
    j fim

ficheiro_vazio:
    la a0, erro_vazio
    li a7, 4
    ecall

fim:
    li a7, 10
    ecall

############################################
# Função: conta_caracteres
# Descrição: Conta a ocorrência de cada caractere no arquivo
# Argumentos: 
#   Usa os buffers globais conteudo e contagens
#   s1 contém o tamanho do arquivo
# Retorna:
#   Preenche o array contagens com as contagens
############################################
conta_caracteres:
    # Inicializa o array de contagens com zeros
    la t0, contagens
    li t1, 512
    li t2, 0
limpa_array:
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    blt t2, t1, limpa_array

    # Conta os caracteres
    la t0, conteudo         # Ponteiro para o conteúdo
    li t1, 0                # Contador de posição
    la t2, contagens        # Ponteiro para o array de contagens
    li t3, 100000           # Tamanho máximo do buffer

loop_conta_chars:
    bge t1, s1, fim_conta   # Se chegou ao final do arquivo
    bge t1, t3, fim_conta   # Se excedeu o buffer (segurança)

    lbu t4, 0(t0)          # Carrega um byte do conteúdo
    andi t4, t4, 0x7F      # Mantém apenas 7 bits (ASCII)

    # Calcula posição no array de contagens (4 bytes por caractere)
    slli t5, t4, 2         # Multiplica por 4 (shift left 2)
    add t5, t2, t5         # Endereço da contagem para este caractere
    
    # Verificação de segurança para não ultrapassar o array
    li t6, 512
    bge t5, t6, proximo_char

    # Incrementa a contagem para este caractere (32 bits)
    # Carrega o valor atual (4 bytes)
    lbu t6, 0(t5)
    lbu t4, 1(t5)
    slli t4, t4, 8
    or t6, t6, t4
    lbu t4, 2(t5)
    slli t4, t4, 16
    or t6, t6, t4
    lbu t4, 3(t5)
    slli t4, t4, 24
    or t6, t6, t4

    addi t6, t6, 1         # Incrementa a contagem

    # Armazena o novo valor (4 bytes)
    sb t6, 0(t5)
    srli t6, t6, 8
    sb t6, 1(t5)
    srli t6, t6, 8
    sb t6, 2(t5)
    srli t6, t6, 8
    sb t6, 3(t5)

proximo_char:
    addi t0, t0, 1         # Avança para próximo caractere
    addi t1, t1, 1         # Incrementa contador
    j loop_conta_chars

fim_conta:
    ret

############################################
# Função: calcula_entropia
# Descrição: Calcula a entropia do arquivo baseado nas contagens de caracteres
# Argumentos: 
#   Usa o array global contagens
# Retorna:
#   a0 - valor da entropia em bits (valor inteiro aproximado)
############################################
calcula_entropia:
    la t0, contagens
    li t1, 0       # Total de caracteres
    li t2, 0       # Contador
    li t3, 512     # Limite

# Calcula o total de caracteres no arquivo
calcula_total:
    li t6, 128
    bge t2, t6, fim_total  # Só considera 128 caracteres ASCII

    # Carrega a contagem para este caractere (4 bytes)
    lbu t4, 0(t0)
    lbu t5, 1(t0)
    slli t5, t5, 8
    or t4, t4, t5
    lbu t5, 2(t0)
    slli t5, t5, 16
    or t4, t4, t5
    lbu t5, 3(t0)
    slli t5, t5, 24
    or t4, t4, t5

    add t1, t1, t4         # Adiciona ao total
    addi t0, t0, 4         # Próximo caractere (4 bytes)
    addi t2, t2, 1         # Incrementa contador
    j calcula_total

fim_total:
    beqz t1, entropia_zero  # Se arquivo vazio, entropia zero

    # Prepara para calcular a entropia
    la t0, contagens
    li t2, 0       # Contador de caracteres
    li t3, 0       # Acumulador de entropia (em milésimos)
    li t4, 1000    # Fator de escala para precisão

loop_entropia:
    li t6, 128
    bge t2, t6, fim_entropia  # Só considera 128 caracteres ASCII

    # Carrega a contagem para este caractere
    lbu t5, 0(t0)
    lbu t6, 1(t0)
    slli t6, t6, 8
    or t5, t5, t6
    lbu t6, 2(t0)
    slli t6, t6, 16
    or t5, t5, t6
    lbu t6, 3(t0)
    slli t6, t6, 24
    or t5, t5, t6

    beqz t5, proximo_entropia  # Se contagem zero, pula

    # Calcula p = count/total (em milésimos)
    mv a0, t5      # Numerador (contagem)
    mv a1, t1      # Denominador (total)
    jal multiplica
    li a1, 1000
    jal divide     # a0 = (count * 1000) / total
    mv t6, a0      # p em milésimos

    # Calcula log2(p) aproximado
    mv a0, t5      # Numerador (contagem)
    mv a1, t1      # Denominador (total)
    jal aproxima_log2
    mv s5, a0      # log2(p) em milésimos

    # Calcula p * log2(p) (em milésimos^2)
    mv a0, t6      # p em milésimos
    mv a1, s5      # log2(p) em milésimos
    jal multiplica

    # Adiciona ao acumulador (já está negativo pois log2(p) é negativo)
    add t3, t3, a0

proximo_entropia:
    addi t0, t0, 4
    addi t2, t2, 1
    j loop_entropia

fim_entropia:
    # Converte de volta para escala normal (divide por 1000)
    mv a0, t3
    li a1, 1000
    jal divide
    ret

############################################
# Função: aproxima_log2
# Descrição: Aproxima o valor de log2(numer/denom) usando aritmética inteira
# Argumentos: 
#   a0 - numerador
#   a1 - denominador
# Retorna:
#   a0 - valor aproximado de log2(numer/denom) em milésimos
############################################
aproxima_log2:
    mv t0, a0  # numerador
    mv t1, a1  # denominador

    # Se numer == denom, log2(1) = 0
    beq t0, t1, log_zero

    # Se numer > denom (não deveria acontecer para p = count/total)
    bgt t0, t1, log_positivo

    # Caso numer < denom (o normal)
    # Aproximação: -log2(denom/numer) ≈ -((denom-numer)*1000)/(numer)
    sub t2, t1, t0
    li t3, 1000
    mul t2, t2, t3
    div a0, t2, t0
    neg a0, a0
    ret

log_positivo:
    sub t2, t0, t1
    li t3, 1000
    mul t2, t2, t3
    div a0, t2, t1
    ret

log_zero:
    li a0, 0
    ret

entropia_zero:
    li a0, 0
    ret

############################################
# Função: multiplica
# Descrição: Multiplica dois números inteiros
# Argumentos: 
#   a0 - primeiro número
#   a1 - segundo número
# Retorna:
#   a0 - resultado da multiplicação
############################################
multiplica:
    mul a0, a0, a1
    ret

############################################
# Função: divide
# Descrição: Divide dois números inteiros
# Argumentos: 
#   a0 - numerador
#   a1 - denominador
# Retorna:
#   a0 - resultado da divisão inteira
############################################
divide:
    li t0, 0       # Quociente
    mv t1, a0      # Resto
    mv t2, a1      # Divisor
loop_divide:
    blt t1, t2, fim_divide
    sub t1, t1, t2
    addi t0, t0, 1
    j loop_divide
fim_divide:
    mv a0, t0
    ret