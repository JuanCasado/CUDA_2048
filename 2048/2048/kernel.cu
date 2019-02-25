
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <iostream>
#include <time.h>
#include <stdio.h>
#include <ctime>
#include <cstdlib>
#include <string>
#include <sstream>
#include <curand_kernel.h>

__host__ void check_CUDA_Error(const char *mensaje) {
	cudaError_t error;
	cudaDeviceSynchronize();
	error = cudaGetLastError();
	if (error != cudaSuccess) {
		printf("ERROR %d: %s (%s)\n", error, cudaGetErrorString(error), mensaje); printf("\npulsa INTRO para finalizar...");
		fflush(stdin);
		char tecla = getchar();
		exit(-1);
	}
}

/*Función que gneera un número aleatorio, comprendido entre 0 y el n-1 filas o columas que tenga*/
__host__ void generate_random (int *result, int elements, int max) {
	std::srand(static_cast<int>(time(0)));
	int i = 0;
	bool repeat;
	do {
		repeat = false;
		result[i] = static_cast<int>(rand() % max);
		for (int j = 0; j < i; ++j) {
			repeat |= (result[i] == result[j]);
		}
		if (!repeat) {
			++i;
		}
	} while (i < elements);
}

__host__ void printTablero(float *tablero, int n_filas, int n_columnas) {
	//Resultado
	for (int i = 0; i < n_filas; i++) {
		for (int j = 0; j < n_columnas; j++) {
			std::cout << tablero[i*n_columnas + j] << ", ";
		}
		std::cout << std::endl;
	}
}

__global__ void fillMatrix(float *tablero, int *positions, int max_elements, int n_positions, int max_random) {
	int id = threadIdx.x;
	bool set = false;
	if (id < max_elements) {
		for (int i = 0; i < n_positions; ++i) {
			if (id == (positions[i])) {
				curandState state;
				curand_init((unsigned long long)clock() + id, 0, 0, &state);
				switch (static_cast<int>(curand(&state) % max_random)) {
				case 0:
					tablero[id] = 2;
					break;
				case 1:
					tablero[id] = 4;
					break;
				case 2:
					tablero[id] = 8;
					break;
				}
				set = true;
			}
		}
		if (!set) {
			tablero[id] = static_cast<float>(0);
		}
	}
}

__global__ void moverDeDerechaAIzquierda(float *tablero, int nc) {
	int id = threadIdx.x * nc;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco? 0:tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nc; ++e) {
		i = id + e;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion + 1;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco <= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					++ultimo_hueco;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}

__global__ void moverDeIzquierdaADerecha(float *tablero, int nc) {
	int id = threadIdx.x * nc + nc - 1;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nc; ++e) {
		i = id - e;
		printf("id: %d\n", i);
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion - 1;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco >= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					--ultimo_hueco;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}


__global__ void movimientoDerecha(float* tablero, int nc) {
	int id = threadIdx.x * nc;
	int posicion = nc - 1; //nos movemos a través de las columnas de la misma fila 
	int comparador = nc - 2;
	int cursor = nc - 1;
	while (posicion >= 0 && comparador > -1) {
		//si no se ha llegado al final y ambos números son iguales y distintos de 0 se suman 
		if (posicion > 0 && tablero[id + posicion] == tablero[id + comparador] && tablero[id + posicion] != 0
			&& tablero[id + comparador] != 0) {
			int suma = tablero[id + comparador] + tablero[id + posicion];
			tablero[id + posicion] = 0;
			tablero[id + comparador] = 0;
			tablero[id + cursor] = suma;
			cursor--;
			posicion = comparador - 1;
			comparador -= 2;
		}
		//si donde nos encontramos es 0
		else if (tablero[id + posicion] == 0) {
			posicion--;
			comparador--;
		} //si el contiguo es 0
		else if (tablero[id + comparador] == 0) {
			comparador--;
		}
		else { // Ambos son diferentes de cero y diferentes entre si
			int aux = tablero[id + posicion];
			tablero[id + posicion] = 0;
			tablero[id + cursor] = aux;
			cursor--;
			posicion = comparador;
			comparador--;
		}
	}
	if (posicion >= 0) {
		int aux = tablero[id + posicion];
		tablero[id + posicion] = 0;
		tablero[id + cursor] = aux;
	}
}


int main(int argc, char **argv) {
	float *tablero_h; //tablero de juego en el host 
	float *tablero_d; //tablero de juego en el device
	int n_filas; //numero de filas
	int n_columnas; //numro de  columnas
	int n_elementos;  //numero de elementos de la matriz (nc*nf)
	size_t size_elementos;
	int elementos_iniciales; //Nivel de juego, 8 o 15 semillas.
	char modo_ejecucion; //modo de ejecución, automático o manual 

	int *random_h; //vector que almacena posicion x 
	int *random_d; //vector donde se copian los puntos en el device

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
	size_elementos = sizeof(float) * n_elementos;
	int n_elementos_pow2 = static_cast<char>(pow(2,ceil(log2(n_elementos))));

	//incializamos las posiciones iniciales aleatoriamente
	random_h = (int*) malloc(sizeof(int) * elementos_iniciales);
	generate_random(random_h, elementos_iniciales, n_elementos);
	cudaMalloc((void **)&random_d, sizeof(int)*elementos_iniciales);
	cudaMemcpy(random_d, random_h, sizeof(int)*elementos_iniciales, cudaMemcpyHostToDevice);

	//iniciamos el tablero
	tablero_h = (float*)malloc(size_elementos);
	cudaMalloc((void **)&tablero_d, size_elementos);
	fillMatrix <<<1, n_elementos_pow2, 1>>> (tablero_d, random_d, n_elementos, elementos_iniciales, static_cast<int>(floor(elementos_iniciales/3)));
	cudaFree(random_d);
	check_CUDA_Error("FILL_MATRIX");

	char movement_to_perform;
	do {
		cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost);
		std::cout << "---------------------" << std::endl;
		printTablero(tablero_h, n_filas, n_columnas);
		std::cout << "{wasd->movement;e->exit}: ";
		std::cin >> movement_to_perform;
		switch (movement_to_perform){
		case 'w':
			
			break;
		case 'a':
			moverDeDerechaAIzquierda << <1, n_filas, 1 >> > (tablero_d, n_columnas);
			break;
		case 's':
			
			break;
		case 'd':
			moverDeIzquierdaADerecha <<<1, n_filas, 1 >>> (tablero_d, n_columnas);
			break;
		default:
			movement_to_perform = 'e';
			break;
		}
		check_CUDA_Error("MOVER");
	} while (movement_to_perform!='e');

	getchar(); //se cierra la ventana si no pongo esto. 
	free(tablero_h);
	cudaFree(tablero_d);
	return(0);
}

