
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <iostream>
#include <curand_kernel.h>
#include <time.h>

#define BLOCK_SIZE 4

/*Función que gneera un número aleatorio, comprendido entre 0 y el n-1 filas o columas que tenga*/
__global__ void generate_random (curandState* random_state, char *result, int cols, int rows, unsigned long seed) {
	int id = threadIdx.x + blockIdx.x * blockDim.x;
	int max = (id % 2) ? cols : rows;
	curand_init(seed, id, 0, &random_state[id]);
	curandState localState = random_state[id];
	char rx = curand(&localState) % max + 0;
	random_state[id] = localState;
	result[id] = rx;
}


int main(int argc, char **argv) {
	char *tablero_h; //tablero de juego en el host 
	char *tablero_d; //tablero de juego en el device
	int n_filas; //numero de filas
	int n_columnas; //numro de  columnas
	int n_elementos;  //numero de elementos de la matriz (nc*nf)
	size_t size_elementos;
	int elementos_iniciales; //Nivel de juego, 8 o 15 semillas.
	bool llenar_casilla = false; //variable que dirá si se llena o no la casilla 
	char modo_ejecucion; //modo de ejecución, automático o manual 

	char *random_h; //vector que almacena posicion x 
	curandState* random_state; //alamcena estados en el device 
	char *random_d; //vector donde se copian los puntos en el device

	if (argc < 4) {
		std::cout << "Modo de ejecucion [ a | m]" << std::endl;
		std::cin >> modo_ejecucion;
		std::cout << "Cuantos elementos iniciales quiere [ 1 = 8 | 2 = 15 ]" << std::endl;
		std::cin >> elementos_iniciales;
		std::cout << "Introduzca el numero de filas del tablero" << std::endl;
		std::cin >> n_filas;
		std::cout << "Introduzca el numero de columnas del tablero" << std::endl;
		std::cin >> n_columnas;
	} else {
		n_filas = std::atoi(argv[3]);
		n_columnas = std::atoi(argv[2]);
		modo_ejecucion = static_cast<char>(std::atoi(argv[1]));
		elementos_iniciales = std::atoi(argv[0]);
	}
	if (n_filas < 4) {
		std::cout << "Filas insuficientes" << std::endl;
		exit(-1);
	}
	if (n_columnas < 4) {
		std::cout << "Columnas insuficientes" << std::endl;
		exit(-2);
	}
	if ((modo_ejecucion != 'a') && (modo_ejecucion != 'm')) {
		std::cout << "Modo de ejecución incorrecto" << std::endl;
		exit(-3);
	}
	if (elementos_iniciales < 0) {
		std::cout << "Elementos iniciales insuficiente" << std::endl;
		exit(-4);
	}
	switch (elementos_iniciales) {
	case 0: {
		elementos_iniciales = 2;
	} break;
	case 1: {
		elementos_iniciales = 8;
	} break;
	case 2: {
		elementos_iniciales = 15;
	} break;
	}
	
	n_elementos = n_filas * n_columnas;
	size_elementos = sizeof(char) * n_elementos;
	dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE);
	dim3 dimGrid(n_elementos / BLOCK_SIZE, n_elementos / BLOCK_SIZE);

	//incializamos las posiciones iniciales aleatoriamente
	int random_pairs = elementos_iniciales * 2;
	random_h = (char*) malloc(sizeof(char) *random_pairs);
	cudaMalloc(&random_state, sizeof(curandState) * random_pairs);
	cudaMalloc((void**) &random_d, sizeof(char) * random_pairs);
	dim3 random_grid_dim (random_pairs, 1, 1);
	generate_random <<<1, random_grid_dim >>> (random_state, random_d, n_columnas, n_filas, time(0));
	cudaFree(random_state);

	//iniciamos el tablero
	tablero_h = (char*)malloc(size_elementos);
	memset(tablero_h, '0', size_elementos);
	cudaMalloc((void **)&tablero_d, size_elementos);
	cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice);
	cudaMemcpy(random_h, random_d, sizeof(char) * random_pairs, cudaMemcpyDeviceToHost);

	cudaFree(random_d);

	for (int i = 0; i < random_pairs; i+=2) {
		std::cout << "[" << (int)random_h[i] << ", " << (int)random_h[i + 1] << "]" << std::endl;
	}

	//Resultado
	for (int i = 0; i < n_filas; i++) {
		for (int j = 0; j < n_columnas; j++) {
			std::cout << tablero_h[i*n_columnas + j] << ", ";
		}
		std::cout << std::endl;
	}

	getchar(); //se cierra la ventana si no pongo esto. 
	free(tablero_h);
	cudaFree(tablero_d);
	return(0);
}

