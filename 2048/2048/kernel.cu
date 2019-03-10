
#include "cuda.h"
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
#include <vector>
#include <curand_kernel.h>

#include "common/book.h"

#include <conio.h>
#define KEY_UP 72
#define KEY_DOWN 80
#define KEY_LEFT 75
#define KEY_RIGHT 77
#define LIVES 5

__global__ void rotate90(float *entrada, float *salida, int nc, int nf) {
	int id = threadIdx.x;
	int fila = id / nf;
	int columna = id - fila * nc;
	int id_out = columna * nf + nc;
	salida[id_out] = entrada[id];
}

__global__ void moverDeDerechaAIzquierda(float *tablero, int nc) {
	int id = threadIdx.x * nc;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
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

__global__ void moverDeAbajoAArriba(float *tablero, int nc, int nf) {
	int id = threadIdx.x;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nf; ++e) {
		i = id + nc * e;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion + nc;
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
					ultimo_hueco += nc;
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

__global__ void moverDeArribaAAbajo(float *tablero, int nc, int nf) {
	int id = nf * nc - threadIdx.x;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nf; ++e) {
		i = id - e * nc;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion - nc;
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
					ultimo_hueco -= nc;
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

template <class T>
__host__ std::string printTablero(T *tablero, int n_filas, int n_columnas) {
	std::stringstream ss;
	for (int i = 0; i < n_filas; i++) {
		for (int j = 0; j < n_columnas; j++) {
			ss << tablero[i*n_columnas + j] << ", ";
		}
		ss << "\n";
	}
	return ss.str();
}

/*Pone la cantidad de números aleatorios indicada en el tablero siempre que se pueda*/
template <class T>
__host__ void addRandom (T *tablero, int elements, int len) {
	std::vector<int> available_positions;
	available_positions.reserve(len);
	for (int i = 0; i < len; ++i) {
		if (tablero[i] == 0) {
			available_positions.emplace_back(i);
		}
	}
	if (available_positions.size() <= 0) return;
	int takes = ((elements < available_positions.size())? elements : available_positions.size());
	do {
		int random = static_cast<int>(std::rand() % available_positions.size());
		tablero[available_positions[random]] = (static_cast<int>(std::rand() % 1) + 1) * ((takes > 8) ? 2 : 4);
		available_positions.erase(available_positions.begin() + random, available_positions.begin() + random + 1);
		--takes;
	} while (takes > 0);
}

__host__ std::string replicateString(std::string str, int amount) {
	std::stringstream ss;
	for (int i = 0; i < amount*3; ++i) {
		ss << str;
	}
	return ss.str();
}

template <class T>
__host__ T sumArray(T *arr, int len) {
	T sum = 0;
	for (int i = 0; i < len * 3; ++i) {
		sum += arr[i];
	}
	return sum;
}

int main(int argc, char **argv) {
	std::srand(static_cast<int>(time(0)));
	float *tablero_h;
	float *tablero_d;
	int n_filas;
	int n_columnas;
	int n_elementos; 
	size_t size_elementos;
	int elementos_iniciales;
	char modo_ejecucion;

	cudaDeviceProp prop;
	HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
	std::cout << "Multiprocesor count: " << prop.multiProcessorCount << std::endl;
	std::cout << "Max Threads per multiprocesor: " << prop.maxThreadsPerMultiProcessor << std::endl;
	std::cout << "Max Threads per block: " << prop.maxThreadsPerBlock << std::endl << std::endl;

	if (argc < 4) {
		std::cout << "Modo de ejecucion [ a | m ]" << std::endl;
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
		n_filas = 4;
	}
	if (n_columnas < 4) {
		std::cout << "Columnas insuficientes" << std::endl;
		n_columnas = 4;
	}
	if ((modo_ejecucion != 'a') && (modo_ejecucion != 'm')) {
		std::cout << "Modo de ejecución incorrecto" << std::endl;
		modo_ejecucion = 'a';
	}
	if (elementos_iniciales < 0) {
		std::cout << "Elementos iniciales insuficientes" << std::endl;
		elementos_iniciales = 15;
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

	std::cout << "Columnas : " << n_columnas << " | Filas: " << n_filas << " -> Elementos: " << n_elementos << std::endl;
	std::cout << "Modo: " << ((modo_ejecucion == 'a') ? "automatico" : "manual") << " | Elementos iniciales: " << elementos_iniciales << std::endl;

	tablero_h = (float*)malloc(size_elementos);
	cudaMalloc((void **)&tablero_d, size_elementos);
	memset(tablero_h, 0, size_elementos);
	int round = 0;
	int lives = LIVES;
	int score [LIVES];
	memset(score, 0, sizeof(int)*LIVES);
	std::string sidebar = replicateString ("-", static_cast<int>(n_columnas*2.4));
	std::string spaces = replicateString (" ", n_columnas);
	char movement_to_perform;
	do {
		movement_to_perform = getch();
		if (movement_to_perform == 0 || static_cast<int>(movement_to_perform )== -32) {
			std::cout << sidebar << std::endl;
			std::cout << "Round: " << ++round << spaces << "Lives :" << lives << std::endl;
			std::cout << sidebar << std::endl;
			addRandom(tablero_h, elementos_iniciales ,n_elementos);
			std::cout << printTablero(tablero_h, n_filas, n_columnas) << std::endl;
			switch ((movement_to_perform = getch())) {
			case KEY_UP:
				moverDeAbajoAArriba << <1, n_columnas, 1 >> > (tablero_d, n_columnas, n_filas);
				break;
			case KEY_LEFT:
				moverDeDerechaAIzquierda << <1, n_filas, 1 >> > (tablero_d, n_columnas);
				break;
			case KEY_DOWN:
				moverDeArribaAAbajo << <1, n_columnas, 1 >> > (tablero_d, n_columnas, n_filas);
				break;
			case KEY_RIGHT:
				moverDeIzquierdaADerecha << <1, n_filas, 1 >> > (tablero_d, n_columnas);
				break;
			}
			check_CUDA_Error("MOVER");
		}
	} while (movement_to_perform!='e');

	std::cout << "Game over!!!" << std::endl;
	std::cout << "TotalScore: " << sumArray(score, LIVES) << std::endl;

	getchar(); //se cierra la ventana si no pongo esto. 
	free(tablero_h);
	cudaFree(tablero_d);
	return(0);
}

