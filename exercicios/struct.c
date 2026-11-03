#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int id_aluno;           // Identificador do aluno
    char nome[40];          // Nome do aluno (máx. 39 caracteres + '\0')
    char curso[30];         // Curso do aluno (máx. 29 caracteres + '\0')
    int idade;              // Idade do aluno
} aluno_t;

int main() {
    // Exemplo de uso:
    aluno_t aluno1;

    aluno1.id_aluno = 1;
    aluno1.idade = 20;
    snprintf(aluno1.nome, sizeof(aluno1.nome), "Maria Silva");
    snprintf(aluno1.curso, sizeof(aluno1.curso), "Engenharia");

    printf("ID: %d\n", aluno1.id_aluno);
    printf("Nome: %s\n", aluno1.nome);
    printf("Curso: %s\n", aluno1.curso);
    printf("Idade: %d\n", aluno1.idade);

    return 0;
}
